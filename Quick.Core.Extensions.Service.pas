{ ***************************************************************************

  Copyright (c) 2016-2021 Kike Pérez

  Unit        : Quick.Core.Extensions.Service
  Description : Core Service with Service Collection
  Author      : Kike Pérez
  Version     : 1.8
  Created     : 01/07/2021
  Modified    : 23/07/2021

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

unit Quick.Core.Extensions.Service;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Parameters,
  {$IFDEF MSWINDOWS}
    WinSvc,
    Quick.Core.Extensions.Service.Windows,
  {$ELSE}
    Quick.Core.Extensions.Service.Linux,
  {$ENDIF}
  Quick.Core.App,
  Quick.Options,
  Quick.Core.DependencyInjection;

type
  TParameters = Quick.Parameters.TParameters;
  TServiceParameters = Quick.Parameters.TServiceParameters;

  TCoreServiceStartType = (csAuto = 0,
                           csManual = 1,
                           csDisabled = 2);

  TWindowsCoreServiceOptions = class(TOptions)
  private
    fDisplayName : string;
    fServiceName : string;
    fDescription : string;
    fDesktopInteractive : Boolean;
    fPassword: string;
    fUsername: string;
    fLoadOrderGroup: string;
    fDependencies: string;
    fStartType: TCoreServiceStartType;
    fCanInstallWithOtherName: Boolean;
    fSilent: Boolean;
  published
    property DisplayName : string read fDisplayName write fDisplayName;
    property ServiceName : string read fServiceName write fServiceName;
    property Description : string read fDescription write fDescription;
    property Username : string read fUsername write fUsername;
    property Password : string read fPassword write fPassword;
    property LoadOrderGroup : string read fLoadOrderGroup write fLoadOrderGroup;
    property Dependencies : string read fDependencies write fDependencies;
    property DesktopInteraction : Boolean read fDesktopInteractive write fDesktopInteractive;
    property StartType : TCoreServiceStartType read fStartType write fStartType;
    property Silent : Boolean read fSilent write fSilent;
    property CanInstallWithOtherName : Boolean read fCanInstallWithOtherName write fCanInstallWithOtherName;
  end;

  TSystemdCoreServiceOptions = class(TOptions)
  private
    fServiceName : string;
    fDescription : string;
    fUser : string;
    fWorkingDir: string;
  published
    property ServiceName : string read fServiceName write fServiceName;
    property Description : string read fDescription write fDescription;
    property User : string read fUser write fUser;
    property WorkingDir : string read fWorkingDir write fWorkingDir;
  end;

  {$IFNDEF MSWINDOWS}
  TSvcStartType = (stAuto = 0,
                   stManual = 1,
                   stDisabled = 2);
  {$ENDIF}

  TCoreService = class(TCoreApp)
  private
    function GetStartType(aStartType : TCoreServiceStartType) : TSvcStartType;
  public
    constructor Create(aStartupClass : TStartupClass); override;
    destructor Destroy; override;
    function UseWindowsService : TCoreService; overload;
    function UseWindowsService(const aServiceName : string) : TCoreService; overload;
    function UseWindowsService(aOptions : TConfigureOptionsProc<TWindowsCoreServiceOptions>) : TCoreService; overload;
    function UseSystemd : TCoreService; overload;
    function UseSystemd(const aServiceName : string) : TCoreService; overload;
    function UseSystemd(aOptions : TConfigureOptionsProc<TSystemdCoreServiceOptions>) : TCoreService; overload;
  end;

  ECoreServiceError = class(Exception);

implementation

{ TCoreService }

constructor TCoreService.Create(aStartupClass: TStartupClass);
begin
  inherited;
  AppService.OnStart := Start;
  AppService.OnStop := Stop;
  AppService.WaitForKeyOnExit := True;
end;

destructor TCoreService.Destroy;
begin

  inherited;
end;

function TCoreService.GetStartType(aStartType: TCoreServiceStartType): TSvcStartType;
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

function TCoreService.UseWindowsService: TCoreService;
begin
  Result := UseWindowsService('QuickCoreService');
end;

function TCoreService.UseWindowsService(const aServiceName: string): TCoreService;
begin
  Result := UseWindowsService(procedure(aOptions : TWindowsCoreServiceOptions)
    begin
      aOptions.ServiceName := aServiceName;
    end);
end;

function TCoreService.UseWindowsService(aOptions: TConfigureOptionsProc<TWindowsCoreServiceOptions>): TCoreService;
var
  options : TWindowsCoreServiceOptions;
begin
  Result := Self;
  {$IFDEF MSWINDOWS}
  if not Assigned(aOptions) then raise ECoreServiceError.Create('Options cannot be nil!');
  options := TWindowsCoreServiceOptions.Create;
  try
    aOptions(options);
    AppService.ServiceName := options.ServiceName;
    AppService.DisplayName := options.DisplayName;
    AppService.UserName := options.Username;
    AppService.UserPass := options.Password;
    AppService.DesktopInteraction := options.DesktopInteraction;
    AppService.Description := options.Description;
    AppService.LoadOrderGroup := options.LoadOrderGroup;
    AppService.Dependencies := options.Dependencies;
    AppService.StartType := GetStartType(options.StartType);
    AppService.Silent := options.Silent;
    AppService.CanInstallWithOtherName := options.CanInstallWithOtherName;
  finally
    options.Free;
  end;
  AppService.Start;
  {$ENDIF}
end;

function TCoreService.UseSystemd: TCoreService;
begin
  Result := UseSystemd('QuickCoreService');
end;

function TCoreService.UseSystemd(const aServiceName: string): TCoreService;
begin
  Result := UseSystemd(procedure(aOptions : TSystemdCoreServiceOptions)
    begin
      aOptions.ServiceName := aServiceName;
    end);
end;

function TCoreService.UseSystemd(aOptions: TConfigureOptionsProc<TSystemdCoreServiceOptions>): TCoreService;
{$IFNDEF MSWINDOWS}
var
  options : TSystemdCoreServiceOptions;
{$ENDIF}
begin
  Result := Self;
  {$IFNDEF MSWINDOWS}
  if not Assigned(aOptions) then raise ECoreServiceError.Create('Options cannot be nil!');
  options := TSystemdCoreServiceOptions.Create;
  try
    aOptions(options);
    AppService.ServiceName := options.ServiceName;
    AppService.Description := options.Description;
    AppService.User := options.User;
    AppService.WorkingDir := options.WorkingDir;
  finally
    options.Free;
  end;
  AppService.Start;
  {$ENDIF}
end;

end.
