{ ***************************************************************************

  Copyright (c) 2016-2021 Kike Pérez

  Unit        : Quick.Core.Extensions.Service.Windows
  Description : Allow run app as Windows service
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

unit Quick.Core.Extensions.Service.Windows;

{$i QuickLib.inc}

interface

uses
  System.SysUtils,
  Windows,
  Quick.Console,
  {$IFNDEF FPC}
    WinSvc,
  {$ENDIF}
  Registry,
  Quick.Commons,
  Quick.Core.Commandline,
  Quick.Core.Extensions.Service.Abstractions;

const
  DEF_SERVICENAME = 'QuickCoreService';
  DEF_DISPLAYNAME = 'QuickCoreService';
  NUM_OF_SERVICES = 2;

type
  TSvcStatus = (ssStopped = SERVICE_STOPPED,
                  ssStopping = SERVICE_STOP_PENDING,
                  ssStartPending = SERVICE_START_PENDING,
                  ssRunning = SERVICE_RUNNING,
                  ssPaused = SERVICE_PAUSED);

  TSvcStartType = (stAuto = SERVICE_AUTO_START,
                    stManual = SERVICE_DEMAND_START,
                    stDisabled = SERVICE_DISABLED);

  TWindowsHostService = class(THostService)
  private
    fParameters : TServiceParameters;
    fSCMHandle : SC_HANDLE;
    fSvHandle : SC_HANDLE;
    fServiceName : string;
    fDisplayName : string;
    fWaitForKeyOnExit : Boolean;
    fLoadOrderGroup : string;
    fDependencies : string;
    fDesktopInteraction : Boolean;
    fUserName : string;
    fUserPass : string;
    fStartType : TSvcStartType;
    fFileName : string;
    fSilent : Boolean;
    fStatus : TSvcStatus;
    fCanInstallWithOtherName : Boolean;
    fAfterRemove : TSvcRemoveEvent;
    procedure Execute;
    procedure ReportSvcStatus(dwCurrentState, dwWin32ExitCode, dwWaitHint: DWORD);
    procedure AddServiceDescription;
  public
    constructor Create;
    destructor Destroy; override;
    property DisplayName : string read fDisplayName write fDisplayName;
    property LoadOrderGroup : string read fLoadOrderGroup write fLoadOrderGroup;
    property Dependencies : string read fDependencies write fDependencies;
    property DesktopInteraction : Boolean read fDesktopInteraction write fDesktopInteraction;
    property UserName : string read fUserName write fUserName;
    property UserPass : string read fUserPass write fUserPass;
    property StartType : TSvcStartType read fStartType write fStartType;
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
  ServiceStatus : TServiceStatus;
  StatusHandle  : SERVICE_STATUS_HANDLE;
  ServiceTable  : array [0..NUM_OF_SERVICES] of TServiceTableEntry;
  ghSvcStopEvent: Cardinal;
  AppService : TWindowsHostService;

implementation

constructor TWindowsHostService.Create;
var
  i : Integer;
  parm : string;
  parameters : string;
begin
  fParameters := TServiceParameters.Create(False);
  fServiceName := DEF_SERVICENAME;
  fDisplayName := DEF_DISPLAYNAME;
  fWaitForKeyOnExit := False;
  fLoadOrderGroup := '';
  fDependencies := '';
  fDesktopInteraction := False;
  UserName := '';
  fUserPass := '';
  fStartType := TSvcStartType.stAuto;
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

destructor TWindowsHostService.Destroy;
begin
  OnStart := nil;
  OnStop := nil;
  OnExecute := nil;
  if fSCMHandle <> 0 then CloseServiceHandle(fSCMHandle);
  if fSvHandle <> 0 then CloseServiceHandle(fSvHandle);
  if Assigned(fParameters) then fParameters.Free;
  fParameters := nil;
  inherited;
end;

procedure ServiceCtrlHandler(Control: DWORD); stdcall;
begin
  case Control of
    SERVICE_CONTROL_STOP:
      begin
        AppService.Status := TSvcStatus.ssStopping;
        SetEvent(ghSvcStopEvent);
        ServiceStatus.dwCurrentState := SERVICE_STOP_PENDING;
        SetServiceStatus(StatusHandle, ServiceStatus);
      end;
    SERVICE_CONTROL_PAUSE:
      begin
        AppService.Status := TSvcStatus.ssPaused;
        ServiceStatus.dwcurrentstate := SERVICE_PAUSED;
        SetServiceStatus(StatusHandle, ServiceStatus);
      end;
    SERVICE_CONTROL_CONTINUE:
      begin
        AppService.Status := TSvcStatus.ssRunning;
        ServiceStatus.dwCurrentState := SERVICE_RUNNING;
        SetServiceStatus(StatusHandle, ServiceStatus);
      end;
    SERVICE_CONTROL_INTERROGATE: SetServiceStatus(StatusHandle, ServiceStatus);
    SERVICE_CONTROL_SHUTDOWN:
      begin
        AppService.Status := TSvcStatus.ssStopped;
        AppService.Stop;
      end;
  end;
end;

procedure RegisterService(dwArgc: DWORD; var lpszArgv: PChar); stdcall;
begin
  ServiceStatus.dwServiceType := SERVICE_WIN32_OWN_PROCESS;
  ServiceStatus.dwCurrentState := SERVICE_START_PENDING;
  ServiceStatus.dwControlsAccepted := SERVICE_ACCEPT_STOP or SERVICE_ACCEPT_PAUSE_CONTINUE;
  ServiceStatus.dwServiceSpecificExitCode := 0;
  ServiceStatus.dwWin32ExitCode := 0;
  ServiceStatus.dwCheckPoint := 0;
  ServiceStatus.dwWaitHint := 0;

  StatusHandle := RegisterServiceCtrlHandler(PChar(AppService.ServiceName), @ServiceCtrlHandler);

  if StatusHandle <> 0 then
  begin
    AppService.ReportSvcStatus(SERVICE_RUNNING, NO_ERROR, 0);
    try
      AppService.Status := TSvcStatus.ssRunning;
      AppService.Execute;
    finally
      AppService.ReportSvcStatus(SERVICE_STOPPED, NO_ERROR, 0);
    end;
  end;
end;

procedure TWindowsHostService.ReportSvcStatus(dwCurrentState, dwWin32ExitCode, dwWaitHint: DWORD);
begin
  //fill in the SERVICE_STATUS structure
  ServiceStatus.dwCurrentState := dwCurrentState;
  ServiceStatus.dwWin32ExitCode := dwWin32ExitCode;
  ServiceStatus.dwWaitHint := dwWaitHint;

  if dwCurrentState = SERVICE_START_PENDING then ServiceStatus.dwControlsAccepted := 0
    else ServiceStatus.dwControlsAccepted := SERVICE_ACCEPT_STOP;

  case (dwCurrentState = SERVICE_RUNNING) or (dwCurrentState = SERVICE_STOPPED) of
    True: ServiceStatus.dwCheckPoint := 0;
    False: ServiceStatus.dwCheckPoint := 1;
  end;

  //report service status to SCM
  SetServiceStatus(StatusHandle,ServiceStatus);
end;

procedure TWindowsHostService.Start;
begin
  //initialize as console
  if not IsRunningAsService then
  begin
    if Assigned(OnInitialize) then OnInitialize;
    if Assigned(OnStart) then OnStart;
    if Assigned(OnExecute) then OnExecute;
    if WaitForKeyOnExit then ConsoleWaitForEnterKey;
  end
  else
  begin //initialize as a service
    if Assigned(OnInitialize) then OnInitialize;
    ServiceTable[0].lpServiceName := PChar(ServiceName);
    ServiceTable[0].lpServiceProc := @RegisterService;
    ServiceTable[1].lpServiceName := nil;
    ServiceTable[1].lpServiceProc := nil;
    {$IFDEF FPC}
    StartServiceCtrlDispatcher(@ServiceTable[0]);
    {$ELSE}
    StartServiceCtrlDispatcher(ServiceTable[0]);
    {$ENDIF}
  end;
end;

procedure TWindowsHostService.Stop;
begin
  if Assigned(OnStop) then OnStop;
end;

procedure TWindowsHostService.Execute;
begin
  //we have to do something or service will stop
  ghSvcStopEvent := CreateEvent(nil,True,False,nil);

  if ghSvcStopEvent = 0 then
  begin
    ReportSvcStatus(SERVICE_STOPPED,NO_ERROR,0);
    Exit;
  end;

  if Assigned(OnStart) then OnStart;

  //report running status when initialization is complete
  ReportSvcStatus(SERVICE_RUNNING,NO_ERROR,0);

  //perform work until service stops
  while True do
  begin
    //external callback process
    if Assigned(OnExecute) then OnExecute;
    //check whether to stop the service.
    WaitForSingleObject(ghSvcStopEvent,INFINITE);
    ReportSvcStatus(SERVICE_STOPPED,NO_ERROR,0);
    Exit;
  end;
end;

procedure TWindowsHostService.Remove;
const
  cRemoveMsg = 'Service "%s" removed successfully!';
var
  SCManager: SC_HANDLE;
  Service: SC_HANDLE;
begin
  SCManager := OpenSCManager(nil, nil, SC_MANAGER_ALL_ACCESS);
  if SCManager = 0 then
    Exit;
  try
    Service := OpenService(SCManager,PChar(ServiceName),SERVICE_ALL_ACCESS);
    ControlService(Service,SERVICE_CONTROL_STOP,ServiceStatus);
    DeleteService(Service);
    CloseServiceHandle(Service);
    if fSilent then Writeln(Format(cRemoveMsg,[ServiceName]))
      else MessageBox(0,PChar(Format(cRemoveMsg,[ServiceName])),PChar(ServiceName),MB_ICONINFORMATION or MB_OK or MB_TASKMODAL or MB_TOPMOST);
  finally
    CloseServiceHandle(SCManager);
    if Assigned(fAfterRemove) then fAfterRemove;
  end;
end;

procedure TWindowsHostService.Install;
const
  cInstallMsg = 'Service "%s" installed successfully!';
  cSCMError = 'Error trying to open SC Manager (you need admin permissions?)';
var
  servicetype : Cardinal;
  svcloadgroup : PChar;
  svcdependencies : PChar;
  svcusername : PChar;
  svcuserpass : PChar;
begin
  fSCMHandle := OpenSCManager(nil,nil,SC_MANAGER_ALL_ACCESS);

  if fSCMHandle = 0 then
  begin
    if fSilent then Writeln(cSCMError)
      else MessageBox(0,cSCMError,PChar(ServiceName),MB_ICONERROR or MB_OK or MB_TASKMODAL or MB_TOPMOST);
    Exit;
  end;
  //service interacts with desktop
  if fDesktopInteraction then servicetype := SERVICE_WIN32_OWN_PROCESS and SERVICE_INTERACTIVE_PROCESS
    else servicetype := SERVICE_WIN32_OWN_PROCESS;
  //service load order
  if fLoadOrderGroup.IsEmpty then svcloadgroup := nil
    else svcloadgroup := PChar(fLoadOrderGroup);
  //service dependencies
  if fDependencies.IsEmpty then svcdependencies := nil
    else svcdependencies := PChar(fDependencies);
  //service user name
  if UserName.IsEmpty then svcusername := nil
    else svcusername := PChar(UserName);
  //service user password
  if fUserPass.IsEmpty then svcuserpass := nil
    else svcuserpass := PChar(fUserPass);

  fSvHandle := CreateService(fSCMHandle,
                              PChar(ServiceName),
                              PChar(fDisplayName),
                              SERVICE_ALL_ACCESS,
                              servicetype,
                              Cardinal(fStartType),
                              SERVICE_ERROR_NORMAL,
                              PChar(fFileName),
                              svcloadgroup,
                              nil,
                              svcdependencies,
                              svcusername, //user
                              svcuserpass); //password

  if fSvHandle <> 0 then
  begin
    AddServiceDescription;
    if fSilent then Writeln(Format(cInstallMsg,[ServiceName]))
      else MessageBox(0,PChar(Format(cInstallMsg,[ServiceName])),PChar(ServiceName),MB_ICONINFORMATION or MB_OK or MB_TASKMODAL or MB_TOPMOST);
  end
  else
  begin
    if fSilent then Writeln(cSCMError)
      else MessageBox(0,cSCMError,PChar(ServiceName),MB_ICONERROR or MB_OK or MB_TASKMODAL or MB_TOPMOST);
    Exit;
  end;
end;

procedure TWindowsHostService.AddServiceDescription;
var
   reg : TRegistry;
begin
   reg := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    reg.RootKey := HKEY_LOCAL_MACHINE;
    if reg.OpenKey('\SYSTEM\CurrentControlSet\Services\' + ServiceName,False) then
    begin
      reg.WriteString('Description',Description);
      reg.CloseKey;
    end;
  finally
    reg.Free;
  end;
end;

function TWindowsHostService.CheckParams : Boolean;
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
//  else
//  begin
//    //Writeln('Unknow parameter specified!');
//  end;
  //if fSkipRun then
  //begin
  //  if Assigned(OnStop) then OnStop;
    //Halt;
  //end;
end;

function TWindowsHostService.ConsoleParamPresent : Boolean;
begin
  Result := fParameters.Console;
end;

function TWindowsHostService.InstallParamsPresent : Boolean;
begin
  Result := (fParameters.Install or fParameters.Remove or fParameters.Help);
end;

function TWindowsHostService.IsRunningAsService : Boolean;
begin
  Result := (IsService and not ConsoleParamPresent) and (not InstallParamsPresent);
end;

function TWindowsHostService.IsRunningAsConsole : Boolean;
begin
  Result := (not IsService) or (ConsoleParamPresent);
end;

initialization
  AppService := TWindowsHostService.Create;

finalization
  //if Assigned(AppService) then AppService.Free;

end.
