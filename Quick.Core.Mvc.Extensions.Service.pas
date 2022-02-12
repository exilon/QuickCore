{ ***************************************************************************

  Copyright (c) 2016-2021 Kike Pérez

  Unit        : Quick.Core.Mvc.Extensions.Service
  Description : Core Service Mvc runs as console or service/daemon
  Author      : Kike Pérez
  Version     : 1.8
  Created     : 21/03/2021
  Modified    : 12/07/2021

  This file is part of QuickCore: https://github.com/exilon/QuickCore

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

unit Quick.Core.Mvc.Extensions.Service;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Core.Extensions.Service.Abstractions,
  Quick.Core.Extensions.Service,
  Quick.Core.Extensions.Hosting,
  {$IFDEF MSWINDOWS}
  WinSvc,
  Quick.Core.Extensions.Service.Windows,
  {$ELSE}
    {$IFDEF LINUX}
    Quick.Core.Logging.Abstractions,
    Quick.Core.Logging,
    Quick.Core.Extensions.Service.Linux,
    {$ELSE}
    Only compatible with Windows/Linux
    {$ENDIF}
  {$ENDIF}
  Quick.Parameters,
  Quick.Core.Mvc,
  Quick.Options,
  Quick.Core.DependencyInjection;

type
  TCoreServiceStartType = Quick.Core.Extensions.Service.TCoreServiceStartType;

  TWindowsCoreServiceOptions = Quick.Core.Extensions.Service.TWindowsCoreServiceOptions;

  TSystemdCoreServiceOptions = Quick.Core.Extensions.Service.TSystemdCoreServiceOptions;

  TParameters = Quick.Parameters.TParameters;

  {$IFNDEF MSWINDOWS}
  TSvcStartType = (stAuto = 0,
                   stManual = 1,
                   stDisabled = 2);
  {$ENDIF}

  TMVCCoreServiceExtension = class helper for TMVCServer
  private
    function GetStartType(aStartType : TCoreServiceStartType) : TSvcStartType;
    procedure DoStop;
  public
    function UseWindowsService : TMVCServer; overload;
    function UseWindowsService(const aServiceName : string) : TMVCServer; overload;
    function UseWindowsService(aOptions : TConfigureOptionsProc<TWindowsCoreServiceOptions>) : TMVCServer; overload;
    function UseSystemd : TMVCServer; overload;
    function UseSystemd(const aServiceName : string) : TMVCServer; overload;
    function UseSystemd(aOptions : TConfigureOptionsProc<TSystemdCoreServiceOptions>) : TMVCServer; overload;
  end;

  ECoreServiceError = class(Exception);

implementation

{ TMVCCoreServiceExtension }

procedure TMVCCoreServiceExtension.DoStop;
begin
  //Self.Status := TMVCServerStatus.mvsStopping;
  Self.Stop;
  //Self.Free;
end;

function TMVCCoreServiceExtension.GetStartType(aStartType: TCoreServiceStartType): TSvcStartType;
begin
  {$IFDEF MSWINDOWS}
  case aStartType of
    csAuto : Result := TSvcStartType.stAuto;
    csManual : Result := TSvcStartType.stManual;
    csDisabled : Result := TSvcStartType.stDisabled;
    else raise Exception.Create('ServiceType not supported!');
  end;
  {$ELSE}
  Result := TSvcStartType.stAuto;
  {$ENDIF}
end;

function TMVCCoreServiceExtension.UseWindowsService: TMVCServer;
begin
  Result := UseWindowsService('QuickCoreService');
end;

function TMVCCoreServiceExtension.UseWindowsService(const aServiceName: string): TMVCServer;
begin
  Result := UseWindowsService(procedure(aOptions : TWindowsCoreServiceOptions)
    begin
      aOptions.ServiceName := aServiceName;
    end);
end;

function TMVCCoreServiceExtension.UseWindowsService(aOptions: TConfigureOptionsProc<TWindowsCoreServiceOptions>): TMVCServer;
var
  options : TWindowsCoreServiceOptions;
begin
  Result := Self;
  {$IFDEF MSWINDOWS}
  if not Assigned(aOptions) then raise ECoreServiceError.Create('Options cannot be nil!');
  AppService.OnStart := Start;
  AppService.OnStop := DoStop;
  AppService.WaitForKeyOnExit := True;
  options := TWindowsCoreServiceOptions.Create;
  try
    aOptions(options);
    AppService.ServiceName := options.ServiceName;
    AppService.DisplayName := options.DisplayName;
    AppService.UserName := options.Username;
    AppService.UserPass := options.Password;
    AppService.Description := options.Description;
    AppService.DesktopInteraction := options.DesktopInteraction;
    AppService.LoadOrderGroup := options.LoadOrderGroup;
    AppService.Dependencies := options.Dependencies;
    AppService.StartType := GetStartType(options.StartType);
    AppService.Silent := options.Silent;
    AppService.CanInstallWithOtherName := options.CanInstallWithOtherName;
  finally
    options.Free;
  end;
  Services.AddSingleton<IHostService,TWindowsHostService>('',
                                   function : TWindowsHostService
                                   begin
                                     Result := AppService;
                                   end);
  {$ENDIF}
end;

function TMVCCoreServiceExtension.UseSystemd: TMVCServer;
begin
  Result := UseSystemd('QuickCoreService');
end;

function TMVCCoreServiceExtension.UseSystemd(const aServiceName: string): TMVCServer;
begin
  Result := UseSystemd(procedure(aOptions : TSystemdCoreServiceOptions)
    begin
      aOptions.ServiceName := aServiceName;
    end);
end;

function TMVCCoreServiceExtension.UseSystemd(aOptions: TConfigureOptionsProc<TSystemdCoreServiceOptions>): TMVCServer;
{$IFNDEF MSWINDOWS}
var
  options : TSystemdCoreServiceOptions;
{$ENDIF}
begin
  Result := Self;
  {$IFNDEF MSWINDOWS}
  if not Assigned(aOptions) then raise ECoreServiceError.Create('Options cannot be nil!');
  AppService.OnStart := Start;
  AppService.OnStop := DoStop;
  AppService.WaitForKeyOnExit := True;
  options := TSystemdCoreServiceOptions.Create;
  try
    aOptions(options);
    AppService.ServiceName := options.ServiceName;
    AppService.Description := options.Description;
    if options.User.IsEmpty then AppService.User := 'root'
      else AppService.User := options.User;
    if options.WorkingDir.IsEmpty then AppService.WorkingDir := GetCurrentDir
      else AppService.WorkingDir := options.WorkingDir;
  finally
    options.Free;
  end;
  //register hostservice
  Services.AddSingleton<IHostService,TLinuxHostService>('',
                                      function : TLinuxHostService
                                      begin
                                        Result := AppService;
                                        Result.Logger := TLoggerBuilder.GetBuilder(False)
                                                .AddSysLog(procedure(aOptions : TSysLogLoggerOptions)
                                                  begin
                                                    aOptions.Host := 'unix:/dev/log';// '127.0.0.1';
                                                    aOptions.Port := 514;
                                                    aOptions.Enabled := True;
                                                  end)
                                                .Build;
                                        //Result.Logger.Info('Setting syslog...');
                                      end);
  //AppService.Start;
  {$ENDIF}
end;

end.
