{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.App
  Description : Core App with Service Collection
  Author      : Kike Perez
  Version     : 1.8
  Created     : 21/03/2021
  Modified    : 08/05/2026

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

unit Quick.Core.App;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.Core.DependencyInjection,
  Quick.Core.Extensions.Hosting,
  Quick.Core.Extensions.Hosting.BackgroundService,
  Quick.Core.Hosting.Lifetime;

type
  TCoreApp = class
  private
    fServiceCollection : TServiceCollection;
  public
    constructor Create(aStartupClass : TStartupClass); virtual;
    destructor Destroy; override;
    procedure Start; virtual;
    procedure Stop; virtual;
  end;

  { THostBuilder: fluent builder for TGenericHost.
    Usage:
      THostBuilder.Create
        .ConfigureServices(procedure(services: TServiceCollection) begin
            services.AddSingleton<IMyService, TMyService>;
          end)
        .Build
        .Run; }
  TConfigureServicesProc = reference to procedure(services: TServiceCollection);

  TGenericHost = class;

  THostBuilder = class
  private
    fConfigureProcs : array of TConfigureServicesProc;
    function GetServicesCount: Integer;
  public
    constructor Create;
    function ConfigureServices(aConfigureProc: TConfigureServicesProc): THostBuilder;
    function Build: TGenericHost;
  end;

  { TGenericHost: a lightweight host that wires up DI, IHostedServices,
    and a simple run-loop.  Equivalent to calling Host.CreateDefaultBuilder()
    .Build().Run() in .NET. }
  TGenericHost = class(TInterfacedObject, IHost)
  private
    fServices    : TServiceCollection;
    fHostedMgr   : IHostedServiceManager;
    fLifetime    : IHostApplicationLifetime;
    fRunning     : Boolean;
  public
    constructor Create(aServices: TServiceCollection);
    destructor Destroy; override;
    { Starts all IHostedService instances and blocks until Stop is called or
      the user presses ENTER (console apps). }
    procedure Start;
    { Stops all IHostedService instances. }
    procedure Stop;
    property Services: TServiceCollection read fServices;
    { Shorthand helper: Start + then return. }
    procedure Run;
  end;

implementation

{ TCoreApp }

constructor TCoreApp.Create(aStartupClass : TStartupClass);
begin
  try
    fServiceCollection := TServiceCollection.Create;
    aStartupClass.ConfigureServices(fServiceCollection);
    fServiceCollection.Build;
  except
    on E : Exception do
    begin
      raise EServiceBuildError.CreateFmt('DependencyInjection: Failed to build services (%s)',[e.Message]);
    end;
  end;
end;

destructor TCoreApp.Destroy;
begin
  fServiceCollection.Free;
  inherited;
end;

procedure TCoreApp.Start;
begin

end;

procedure TCoreApp.Stop;
begin

end;

{ THostBuilder }

constructor THostBuilder.Create;
begin
  inherited Create;
  SetLength(fConfigureProcs, 0);
end;

function THostBuilder.ConfigureServices(aConfigureProc: TConfigureServicesProc): THostBuilder;
var
  n : Integer;
begin
  n := Length(fConfigureProcs);
  SetLength(fConfigureProcs, n + 1);
  fConfigureProcs[n] := aConfigureProc;
  Result := Self;
end;

function THostBuilder.GetServicesCount: Integer;
begin
  Result := Length(fConfigureProcs);
end;

function THostBuilder.Build: TGenericHost;
var
  services : TServiceCollection;
  proc     : TConfigureServicesProc;
begin
  services := TServiceCollection.Create;
  try
    for proc in fConfigureProcs do
      proc(services);
    // Register a global manager if at least one hosted service was added
    if not services.IsRegistered<IHostedServiceManager> then
      services.AddSingleton<IHostedServiceManager, THostedServiceManager>;
    // Always register IHostApplicationLifetime so any service can inject it
    if not services.IsRegistered<IHostApplicationLifetime> then
      services.AddSingleton<IHostApplicationLifetime, TApplicationLifetime>;
    services.Build;
    Result := TGenericHost.Create(services);
  except
    services.Free;
    raise;
  end;
end;

{ TGenericHost }

constructor TGenericHost.Create(aServices: TServiceCollection);
begin
  inherited Create;
  fServices := aServices;
  fRunning  := False;
  if fServices.IsRegistered<IHostedServiceManager> then
    fHostedMgr := fServices.Resolve<IHostedServiceManager>
  else
    fHostedMgr := nil;
  if fServices.IsRegistered<IHostApplicationLifetime> then
    fLifetime := fServices.Resolve<IHostApplicationLifetime>
  else
    fLifetime := nil;
end;

destructor TGenericHost.Destroy;
begin
  Stop;
  fServices.Free;
  inherited;
end;

procedure TGenericHost.Start;
begin
  if fRunning then Exit;
  fRunning := True;
  if fHostedMgr <> nil then
  begin
    fHostedMgr.Initialize(fServices);
    fHostedMgr.StartAll;
  end;
  if fLifetime <> nil then
    fLifetime.NotifyStarted;
end;

procedure TGenericHost.Stop;
begin
  if not fRunning then Exit;
  if fLifetime <> nil then
    fLifetime.NotifyStopping;
  if fHostedMgr <> nil then
    fHostedMgr.StopAll;
  fRunning := False;
  if fLifetime <> nil then
    fLifetime.NotifyStopped;
end;

procedure TGenericHost.Run;
begin
  Start;
  ConsoleWaitForEnterKey;
  Stop;
end;

end.

