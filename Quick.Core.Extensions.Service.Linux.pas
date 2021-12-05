{ ***************************************************************************

  Copyright (c) 2016-2021 Kike Pérez

  Unit        : Quick.Core.Extensions.Service.Linux
  Description : Allow run app as Linux daemon
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 01/07/2021
  Modified    : 02/08/2021

  This file is part of QuickLib: https://github.com/exilon/QuickCore

 ***************************************************************************

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

 *************************************************************************** }

unit Quick.Core.Extensions.Service.Linux;

{$i QuickLib.inc}

interface

uses
  System.Classes,
  System.SysUtils,
  Posix.Stdlib,
  Posix.SysStat,
  Posix.SysTypes,
  Posix.Unistd,
  Posix.Signal,
  Posix.Fcntl,
  Posix.SysLog,
  System.SyncObjs,
  Quick.Commons,
  Quick.Core.Logging.Abstractions,
  Quick.Core.Commandline,
  Quick.Core.Extensions.Service.Abstractions;

const
  DEF_SERVICENAME = 'QuickCoreService';
  DEF_DISPLAYNAME = 'QuickCoreService';
  NUM_OF_SERVICES = 2;

type
  TSvcStatus = (ssStopped = 1,
                  ssStopping = 2,
                  ssStartPending = 3,
                  ssRunning = 4,
                  ssPaused = 5);

  TLinuxHostService = class(THostService)
  private
    fParameters : TServiceParameters;
    fPid : pid_t;
    fSid : pid_t;
    fDisplayName : string;
    fWaitForKeyOnExit : Boolean;
    fFileName : string;
    fSilent : Boolean;
    fStatus : TSvcStatus;
    fCanInstallWithOtherName : Boolean;
    fWorkingDir : string;
    fAfterRemove : TSvcRemoveEvent;
    procedure Execute;
    procedure CreateServiceFile;
    property LastPid : pid_t read fPid write fPid;
  public
    constructor Create;
    destructor Destroy; override;
    property DisplayName : string read fDisplayName write fDisplayName;
    property WorkingDir : string read fWorkingDir write fWorkingDir;
    property FileName : string read fFileName;
    property Silent : Boolean read fSilent write fSilent;
    property CanInstallWithOtherName : Boolean read fCanInstallWithOtherName write fCanInstallWithOtherName;
    property Status : TSvcStatus read fStatus write fStatus;
    property AfterRemove : TSvcRemoveEvent read fAfterRemove write fAfterRemove;
    procedure Install; override;
    procedure Remove; override;
    function CheckParams : Boolean; override;
    function InstallParamsPresent : Boolean;
    function ConsoleParamPresent : Boolean;
    function IsRunningAsService : Boolean; override;
    function IsRunningAsConsole : Boolean;
    procedure Start; override;
    procedure Stop; override;
  end;

var
  AppService : TLinuxHostService;

implementation

var
  CloseEvent : TSimpleEvent;

const
  EXIT_FAILURE = 1;
  EXIT_SUCCESS = 0;

constructor TLinuxHostService.Create;
var
  i : Integer;
  parm : string;
  parameters : string;
begin
  openlog(nil, LOG_PID or LOG_NDELAY, LOG_DAEMON);
  fParameters := TServiceParameters.Create(False);
  ServiceName := DEF_SERVICENAME;
  fDisplayName := DEF_DISPLAYNAME;
  fWaitForKeyOnExit := False;
  User := '';
  Password := '';
  fFileName := ParamStr(0);
  parameters := '';
  for i := 1 to ParamCount - 1 do
  begin
    parm := ParamStr(i);
    if (parm.ToLower <> '/install')
    and (parm.ToLower <> '/remove')
    and (not parm.ToLower.StartsWith('/instance:')) then
    begin
      parameters := parameters + ' ' + parm;
    end;
  end;
  if not parameters.IsEmpty then fFileName := Format('"%s" %s',[fFilename,parameters]);

  fSilent := True;
  fStatus := TSvcStatus.ssStopped;
  fCanInstallWithOtherName := False;
  OnExecute := nil;
  IsQuickServiceApp := True;
end;

procedure TLinuxHostService.CreateServiceFile;
var
  sl : TStringList;
begin
  sl := TStringList.Create;
  try
    sl.Add('[Unit]');
    sl.Add(Format('Description=%s',[Description]));
    sl.Add('[Service]');
    sl.Add('Type=forking');
    sl.Add(Format('User=%s',[User]));
    sl.Add(Format('WorkingDirectory=%s',[WorkingDir]));
    sl.Add(Format('ExecStart=%s -d',[ExpandFileName(fFileName)]));
    sl.Add('KillMode=control-group');
    sl.Add('Restart=on-failure');
    sl.Add('[Install]');
    sl.Add('WantedBy=multi-user.target');
    sl.SaveToFile(Format('/etc/systemd/system/%s.service',[ServiceName]),TEncoding.UTF8);
    Writeln(Format('/etc/systemd/system/%s.service',[ServiceName]));
  finally
    sl.Free;
  end;
end;

destructor TLinuxHostService.Destroy;
begin
  OnStart := nil;
  OnStop := nil;
  OnExecute := nil;
  if Assigned(fParameters) then fParameters.Free;
  fParameters := nil;
  closelog();
  inherited;
end;

procedure HandleSignals(SigNum: Integer); cdecl;
begin
  case SigNum of
    SIGTERM:
    begin
      //running := False;
      //GLogger.Debug('SIGTERM received!');
      syslog(LOG_NOTICE,Format('SIGTERM received! PID:%d/fpid:%d',[getpid(),AppService.LastPid]));
      if (AppService.Status = TSvcStatus.ssRunning) then
      begin
        syslog(LOG_NOTICE,'daemon: closing...');
        AppService.Stop;
        CloseEvent.SetEvent;
      end;
    end;
    SIGHUP:
    begin
      //GLogger.Debug('SIGHUP received!');
      syslog(LOG_NOTICE, 'daemon: reloading config');
      // Reload configuration
    end;
  end;
end;

procedure TLinuxHostService.Start;
var
  i : Integer;
  fid : Integer;
begin
  fStatus := TSvcStatus.ssStartPending;


  // If the parent process is the init process then the current process is already a daemon
  // Remarks: this check here
//	if getppid() = 1 then
//  begin
//    syslog(LOG_NOTICE, 'Nothing to do, I''m already a daemon');
//    Exit; // already a daemon
//  end;

  syslog(LOG_NOTICE, 'before 1st fork() - original process');
  // Call fork(), to create a background process.
  fPid := fork();
  syslog(LOG_NOTICE, 'after 1st fork() - the child is born');

  syslog(LOG_NOTICE, Format('PID: %d',[fPid]));

  if fPid < 0 then raise Exception.Create('Error forking the process');

  // Call exit() in the first child, so that only the second
  // child (the actual daemon process) stays around
  if fPid > 0 then
  begin
    syslog(LOG_NOTICE, 'killing parent process!');
    Halt(EXIT_SUCCESS);
  end;

  // This call will place the server in a new process group and session and
  // detaches its controlling terminal
  fSid := setsid();
  if fSid < 0 then raise Exception.Create('Impossible to create an independent session');
  syslog(LOG_NOTICE, 'session created and process group ID set');

  syslog(LOG_NOTICE, 'before 2nd fork() - child process');

  // Catch, ignore and handle signals
  signal(SIGCHLD, TSignalHandler(SIG_IGN));
  signal(SIGCONT, TSignalHandler(SIG_IGN));
  signal(SIGHUP, HandleSignals);
  signal(SIGTERM, HandleSignals);

  // Call fork() again, to be sure daemon can never re-acquire the terminal
  fPid := fork();

  syslog(LOG_NOTICE, 'after 2nd fork() - the grandchild is born');

  if fPid < 0 then raise Exception.Create('Error forking the process');

  // Call exit() in the first child, so that only the second child
  // (the actual daemon process) stays around. This ensures that the daemon
  // process is re-parented to init/PID 1, as all daemons should be.
  syslog(LOG_NOTICE, Format('PID: %d',[fPid]));
  if fPid > 0 then
  begin
    syslog(LOG_NOTICE, 'the 1st child is killed!');
    Halt(EXIT_SUCCESS);
  end;

  // Open descriptors are inherited to child process, this may cause the use
  // of resources unneccessarily. Unneccesarry descriptors should be closed
  // before fork() system call (so that they are not inherited) or close
  // all open descriptors as soon as the child process starts running

  // Close all opened file descriptors (stdin, stdout and stderr)
  for i := sysconf(_SC_OPEN_MAX) downto 0 do __close(i);
  syslog(LOG_NOTICE, 'file descriptors closed');

  // Route I/O connections to > dev/null

  // Open STDIN
  fid := __open('/dev/null', O_RDWR);
  // Dup STDOUT
  dup(fid);
  // Dup STDERR
  dup(fid);
  syslog(LOG_NOTICE, 'stdin, stdout, stderr redirected to /dev/null');

  // if you don't redirect the stdout the program hangs
  Writeln('Test writeln');
  syslog(LOG_NOTICE, 'if you see this message the daemon isn''t crashed writing on stdout!');

  // Set new file permissions:
  // most servers runs as super-user, for security reasons they should
  // protect files that they create, with unmask the mode passes to open(), mkdir()

  // Restrict file creation mode to 750
	umask(027);
  syslog(LOG_NOTICE, 'file permission changed to 750');

  // The current working directory should be changed to the root directory (/), in
  // order to avoid that the daemon involuntarily blocks mount points from being unmounted
  chdir(fWorkingDir);
  syslog(LOG_NOTICE, Format('changed directory to "%s"',[fWorkingDir]));
  // TODO: write the daemon PID (as returned by getpid()) to a PID file, for
  // example /run/delphid.pid to ensure that the daemon cannot be started more than once

  syslog(LOG_NOTICE, 'daemon started');

  // deamon main loop
  //running := True;
  try
//    while running do
//    begin
//      // deamon actual code
//      Sleep(1000);
//    end;
      fStatus := TSvcStatus.ssRunning;
      syslog(LOG_NOTICE, 'running service...');
      CloseEvent.ResetEvent;
      Execute;
      syslog(LOG_NOTICE, 'waiting for close event');
      if CloseEvent.WaitFor(INFINITE) <> wrSignaled then raise Exception.Create('Error waiting for finish daemon!');
      //ConsoleWaitForEnterKey;
      ExitCode := EXIT_SUCCESS;
  except
    on E: Exception do
    begin
      syslog(LOG_ERR, 'Error: ' + E.Message);
      ExitCode := EXIT_FAILURE;
    end;
  end;

  syslog(LOG_NOTICE, 'daemon stopped');
end;

procedure TLinuxHostService.Stop;
begin
  fStatus := TSvcStatus.ssStopping;
  if Assigned(OnStop) then OnStop;
  fStatus := TSvcStatus.ssStopped;
end;

procedure TLinuxHostService.Execute;
begin
  //Logger.Info('Initializating...');
  if Assigned(OnInitialize) then OnInitialize;
  if Assigned(OnStart) then OnStart;
end;

procedure TLinuxHostService.Install;
const
  cInstallMsg = 'Service "%s" installed successfully!';
  cSCMError = 'Error trying to create daemon file (you need root permissions?)';
begin
  try
    CreateServiceFile;
    Writeln(Format(cInstallMsg,[ServiceName]));
  except
    Writeln(cSCMError);
  end;
end;

procedure TLinuxHostService.Remove;
const
  cRemoveMsg = 'Service "%s" removed successfully!';
begin
  try
    //to do
    if not DeleteFile(Format('/etc/systemd/system/%s.service',[ServiceName])) then raise Exception.Create('Cannot remove .service file!');
    Writeln(Format(cRemoveMsg,[ServiceName]))
  except
    on E : Exception do raise Exception.CreateFmt('Error removing service: %s',[e.Message]);
  end;
  if Assigned(fAfterRemove) then fAfterRemove;
end;

function TLinuxHostService.CheckParams : Boolean;
var
  svcname : string;
begin
  Result := False;
  fParameters.Description := Description;
  if ParamCount > 0 then
  begin
    fSilent := fParameters.Silent;
//    if fParameters.Help then
//    begin
//      fParameters.ShowHelp;
//      Result := True;
//    end
//    else
    if fParameters.Install then
    begin
      if fCanInstallWithOtherName then
      begin
        if fParameters.ExistsParam('instance') then
        begin
          if fParameters.Instance.IsEmpty then raise Exception.Create('Service instance name not defined!');
          ServiceName := fParameters.Instance;
          fDisplayName := fParameters.Instance;
        end;
      end;
      Install;
      Result := True;
    end
    else if fParameters.Remove then
    begin
      if fCanInstallWithOtherName then
      begin
        if fParameters.ExistsParam('instance') then
        begin
          if fParameters.Instance.IsEmpty then raise Exception.Create('Service instance name not defined!');
          ServiceName := fParameters.Instance;
          fDisplayName := fParameters.Instance;
        end;
      end;
      Remove;
      Result := True;
    end
    else if fParameters.Console then Writeln('Forced console mode');
  end;
end;

function TLinuxHostService.ConsoleParamPresent : Boolean;
begin
  Result := fParameters.Console;
end;

function TLinuxHostService.InstallParamsPresent : Boolean;
begin
  Result := (fParameters.Install or fParameters.Remove or fParameters.Help);
end;

function TLinuxHostService.IsRunningAsService : Boolean;
begin
  Result := (fParameters.Detach) and (not ConsoleParamPresent) and (not InstallParamsPresent);
end;

function TLinuxHostService.IsRunningAsConsole : Boolean;
begin
  Result := (not fParameters.Detach) or (ConsoleParamPresent);
end;

initialization
  CloseEvent := TSimpleEvent.Create;
  AppService := TLinuxHostService.Create;

finalization
  //CloseEvent.Release;
  CloseEvent.Free;
  //if Assigned(AppService) then AppService.Free;

end.
