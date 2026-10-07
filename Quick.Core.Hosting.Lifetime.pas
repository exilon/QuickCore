{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Hosting.Lifetime
  Description : IHostApplicationLifetime — application lifetime events
  Author      : Kike Perez
  Version     : 1.0
  Created     : 29/04/2026
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

unit Quick.Core.Hosting.Lifetime;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  /// <summary>Callback registered for a lifetime event.</summary>
  TLifetimeCallback = reference to procedure;

  /// <summary>
  /// Provides notifications about the application host lifetime.
  /// Equivalent to IHostApplicationLifetime in .NET.
  ///
  /// Usage (from a hosted service or controller):
  ///   lifetime := services.Resolve<IHostApplicationLifetime>;
  ///   lifetime.ApplicationStarted.Register(procedure begin ... end);
  ///   lifetime.ApplicationStopping.Register(procedure begin ... end);
  /// </summary>
  IHostApplicationLifetime = interface
  ['{C4A17B3E-9F82-4D56-B0C1-2E85F69A3D07}']
    /// <summary>Triggered after the host has fully started.</summary>
    procedure NotifyStarted;
    /// <summary>Triggered when a graceful stop has been requested.</summary>
    procedure NotifyStopping;
    /// <summary>Triggered after the host has completed a graceful shutdown.</summary>
    procedure NotifyStopped;
    /// <summary>Register a callback invoked when the application has started.</summary>
    procedure RegisterStarted(aCallback: TLifetimeCallback);
    /// <summary>Register a callback invoked when graceful stop is requested.</summary>
    procedure RegisterStopping(aCallback: TLifetimeCallback);
    /// <summary>Register a callback invoked after the application has stopped.</summary>
    procedure RegisterStopped(aCallback: TLifetimeCallback);
    /// <summary>Request a graceful stop of the host.</summary>
    procedure StopApplication;
    /// <summary>True once StopApplication has been called.</summary>
    function ApplicationStopping: Boolean;
  end;

  /// <summary>Default implementation of IHostApplicationLifetime.</summary>
  TApplicationLifetime = class(TInterfacedObject, IHostApplicationLifetime)
  private
    fStartedCallbacks   : TList<TLifetimeCallback>;
    fStoppingCallbacks  : TList<TLifetimeCallback>;
    fStoppedCallbacks   : TList<TLifetimeCallback>;
    fApplicationStopping: Boolean;
    procedure InvokeCallbacks(aList: TList<TLifetimeCallback>);
  public
    constructor Create;
    destructor Destroy; override;
    procedure NotifyStarted;
    procedure NotifyStopping;
    procedure NotifyStopped;
    procedure RegisterStarted(aCallback: TLifetimeCallback);
    procedure RegisterStopping(aCallback: TLifetimeCallback);
    procedure RegisterStopped(aCallback: TLifetimeCallback);
    procedure StopApplication;
    function ApplicationStopping: Boolean;
  end;

implementation

{ TApplicationLifetime }

constructor TApplicationLifetime.Create;
begin
  inherited Create;
  fStartedCallbacks   := TList<TLifetimeCallback>.Create;
  fStoppingCallbacks  := TList<TLifetimeCallback>.Create;
  fStoppedCallbacks   := TList<TLifetimeCallback>.Create;
  fApplicationStopping := False;
end;

destructor TApplicationLifetime.Destroy;
begin
  fStartedCallbacks.Free;
  fStoppingCallbacks.Free;
  fStoppedCallbacks.Free;
  inherited;
end;

procedure TApplicationLifetime.InvokeCallbacks(aList: TList<TLifetimeCallback>);
var
  cb: TLifetimeCallback;
begin
  for cb in aList do
    cb();
end;

procedure TApplicationLifetime.NotifyStarted;
begin
  InvokeCallbacks(fStartedCallbacks);
end;

procedure TApplicationLifetime.NotifyStopping;
begin
  fApplicationStopping := True;
  InvokeCallbacks(fStoppingCallbacks);
end;

procedure TApplicationLifetime.NotifyStopped;
begin
  InvokeCallbacks(fStoppedCallbacks);
end;

procedure TApplicationLifetime.RegisterStarted(aCallback: TLifetimeCallback);
begin
  fStartedCallbacks.Add(aCallback);
end;

procedure TApplicationLifetime.RegisterStopping(aCallback: TLifetimeCallback);
begin
  fStoppingCallbacks.Add(aCallback);
end;

procedure TApplicationLifetime.RegisterStopped(aCallback: TLifetimeCallback);
begin
  fStoppedCallbacks.Add(aCallback);
end;

procedure TApplicationLifetime.StopApplication;
begin
  NotifyStopping;
end;

function TApplicationLifetime.ApplicationStopping: Boolean;
begin
  Result := fApplicationStopping;
end;

end.
