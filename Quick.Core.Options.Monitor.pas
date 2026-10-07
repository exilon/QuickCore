{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Options.Monitor
  Description : IOptionsMonitor<T> and IOptionsSnapshot<T>
  Author      : Kike Perez
  Version     : 1.0
  Created     : 30/04/2026
  Modified    : 08/05/2026

  This file is part of QuickCore: https://github.com/exilon/QuickCore

  Equivalent .NET: Microsoft.Extensions.Options / IOptionsMonitor<T>, IOptionsSnapshot<T>

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

unit Quick.Core.Options.Monitor;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.SyncObjs,
  Quick.Options;

type

  // ─── Change token (IDisposable / IChangeToken equivalent) ────────────────

  /// <summary>
  /// Handle returned by IOptionsMonitor.OnChange. Call Unregister to stop
  /// receiving notifications. Unregister is safe to call multiple times.
  ///
  /// .NET equivalent: IDisposable (returned by IOptionsMonitor.OnChange)
  /// </summary>
  IOptionsChangeToken = interface
  ['{B1C2D3E4-F5A6-7B8C-9D0E-F1A2B3C4D5E6}']
    procedure Unregister;
  end;

  TOptionsChangeToken = class(TInterfacedObject, IOptionsChangeToken)
  private
    fUnregisterProc : TProc;
    fUnregistered   : Boolean;
  public
    constructor Create(aUnregisterProc: TProc);
    /// <summary>Removes the callback. Idempotent — safe to call multiple times.</summary>
    procedure Unregister;
  end;

  // ─── IOptionsMonitor<T> ───────────────────────────────────────────────────

  TOptionsChangeCallback<T: TOptions> = reference to procedure(aNewValue: T);

  /// <summary>
  /// Reactive wrapper over TOptions. Notifies registered callbacks when the
  /// underlying configuration reloads (e.g. from a watched file).
  ///
  /// .NET equivalent: IOptionsMonitor&lt;T&gt;
  ///
  /// Usage:
  ///   monitor := services.GetService&lt;IOptionsMonitor&lt;TMyOptions&gt;&gt;;
  ///   token   := monitor.OnChange(procedure(o: TMyOptions)
  ///     begin
  ///       ApplyNewSettings(o);
  ///     end);
  ///   // Stop listening:
  ///   token.Unregister;
  ///
  /// The token should be stored and unregistered when the consumer is freed
  /// to prevent dangling references.
  /// </summary>
  IOptionsMonitor<T: TOptions> = interface
  ['{A2B3C4D5-E6F7-8A9B-C0D1-E2F3A4B5C6D7}']
    function GetCurrentValue: T;
    /// <summary>
    /// The live options value. Reflects the latest loaded configuration.
    /// Does NOT create a snapshot — the returned T is the shared instance.
    /// </summary>
    property CurrentValue: T read GetCurrentValue;
    /// <summary>
    /// Register a callback to be called on every configuration reload.
    /// Returns an IOptionsChangeToken; call Unregister on it to deregister.
    /// </summary>
    function OnChange(aCallback: TOptionsChangeCallback<T>): IOptionsChangeToken;
  end;

  // ─── IOptionsSnapshot<T> ─────────────────────────────────────────────────

  /// <summary>
  /// Per-resolution read of the current options value. Unlike IOptionsMonitor,
  /// there are no change notifications — suitable for short-lived consumers
  /// (e.g. per-request in MVC controllers).
  ///
  /// .NET equivalent: IOptionsSnapshot&lt;T&gt;
  ///
  /// Usage:
  ///   snapshot := services.GetService&lt;IOptionsSnapshot&lt;TMyOptions&gt;&gt;;
  ///   WriteLn(snapshot.Value.ConnectionString);
  /// </summary>
  IOptionsSnapshot<T: TOptions> = interface
  ['{C3D4E5F6-A7B8-9C0D-E1F2-A3B4C5D6E7F8}']
    function GetValue: T;
    property Value: T read GetValue;
  end;

  // ─── TOptionsMonitor<T> ──────────────────────────────────────────────────

  TOptionsMonitor<T: TOptions> = class(TInterfacedObject, IOptionsMonitor<T>)
  private type
    TCallbackMap = TDictionary<Integer, TOptionsChangeCallback<T>>;
  private
    fContainer : TOptionsContainer;
    fCallbacks : TCallbackMap;
    fNextId    : Integer;
    fLock      : TCriticalSection;
    procedure HookContainer;
    procedure RefreshAndNotify;
    procedure UnregisterCallback(aId: Integer);
    function GetCurrentValue: T;
  public
    /// <param name="aContainer">
    ///   The options container to monitor. Must already contain a section of
    ///   type T (populated via TServiceCollection.Configure&lt;T&gt;).
    /// </param>
    constructor Create(aContainer: TOptionsContainer);
    destructor Destroy; override;
    property CurrentValue: T read GetCurrentValue;
    function OnChange(aCallback: TOptionsChangeCallback<T>): IOptionsChangeToken;
  end;

  // ─── TOptionsSnapshot<T> ─────────────────────────────────────────────────

  TOptionsSnapshot<T: TOptions> = class(TInterfacedObject, IOptionsSnapshot<T>)
  private
    fContainer : TOptionsContainer;
    function GetValue: T;
  public
    constructor Create(aContainer: TOptionsContainer);
    property Value: T read GetValue;
  end;

implementation

// ─── TOptionsChangeToken ──────────────────────────────────────────────────────

constructor TOptionsChangeToken.Create(aUnregisterProc: TProc);
begin
  inherited Create;
  fUnregisterProc := aUnregisterProc;
  fUnregistered   := False;
end;

procedure TOptionsChangeToken.Unregister;
begin
  if not fUnregistered then
  begin
    fUnregistered := True;
    if Assigned(fUnregisterProc) then
      fUnregisterProc;
    fUnregisterProc := nil;
  end;
end;

// ─── TOptionsMonitor<T> ───────────────────────────────────────────────────────

constructor TOptionsMonitor<T>.Create(aContainer: TOptionsContainer);
begin
  inherited Create;
  if aContainer = nil then
    raise EArgumentNilException.Create('TOptionsMonitor: aContainer must not be nil');
  fContainer := aContainer;
  fCallbacks := TCallbackMap.Create;
  fNextId    := 0;
  fLock      := TCriticalSection.Create;
  HookContainer;
end;

destructor TOptionsMonitor<T>.Destroy;
begin
  fLock.Free;
  fCallbacks.Free;
  inherited;
end;

procedure TOptionsMonitor<T>.HookContainer;
var
  prev: TLoadConfigEvent;
begin
  // Chain: preserve the existing handler and call it first, then notify
  prev := fContainer.OnConfigReloaded;
  fContainer.OnConfigReloaded := procedure
    begin
      if Assigned(prev) then prev;
      RefreshAndNotify;
    end;
end;

function TOptionsMonitor<T>.GetCurrentValue: T;
begin
  Result := fContainer.GetSection<T>;
end;

procedure TOptionsMonitor<T>.RefreshAndNotify;
var
  current   : T;
  snapshots : TArray<TOptionsChangeCallback<T>>;
  cb        : TOptionsChangeCallback<T>;
begin
  current := GetCurrentValue;
  // Snapshot callback list under lock to prevent modification during iteration
  fLock.Enter;
  try
    snapshots := fCallbacks.Values.ToArray;
  finally
    fLock.Leave;
  end;
  // Invoke callbacks outside the lock to prevent deadlocks
  for cb in snapshots do
    if Assigned(cb) then
      cb(current);
end;

procedure TOptionsMonitor<T>.UnregisterCallback(aId: Integer);
begin
  fLock.Enter;
  try
    fCallbacks.Remove(aId);
  finally
    fLock.Leave;
  end;
end;

function TOptionsMonitor<T>.OnChange(aCallback: TOptionsChangeCallback<T>): IOptionsChangeToken;
var
  id: Integer;
begin
  if not Assigned(aCallback) then
    raise EArgumentNilException.Create('TOptionsMonitor.OnChange: aCallback must not be nil');
  fLock.Enter;
  try
    Inc(fNextId);
    id := fNextId;
    fCallbacks.Add(id, aCallback);
  finally
    fLock.Leave;
  end;
  // The closure captures id by value (each call to OnChange has its own id)
  Result := TOptionsChangeToken.Create(
    procedure begin UnregisterCallback(id) end
  );
end;

// ─── TOptionsSnapshot<T> ─────────────────────────────────────────────────────

constructor TOptionsSnapshot<T>.Create(aContainer: TOptionsContainer);
begin
  inherited Create;
  if aContainer = nil then
    raise EArgumentNilException.Create('TOptionsSnapshot: aContainer must not be nil');
  fContainer := aContainer;
end;

function TOptionsSnapshot<T>.GetValue: T;
begin
  Result := fContainer.GetSection<T>;
end;

end.
