{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Caching.Hybrid
  Description : HybridCache — L1 (IMemoryCache) + L2 (IDistributedCache)
  Author      : Kike Perez
  Version     : 1.0
  Created     : 30/04/2026
  Modified    : 08/05/2026

  This file is part of QuickCore: https://github.com/exilon/QuickCore

  Equivalent .NET: Microsoft.Extensions.Caching.Hybrid / IHybridCache (.NET 9)

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

unit Quick.Core.Caching.Hybrid;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.SyncObjs,
  Quick.Core.Caching.Abstractions;

type

  // ─── Options ─────────────────────────────────────────────────────────────────

  /// <summary>
  /// Configuration for THybridCache.
  ///
  ///   DefaultLocalExpirationMs  — TTL used for L1 (memory) when the caller
  ///                               does not pass an explicit value. 0 = no expiry.
  ///   DefaultRemoteExpirationMs — TTL used for L2 (distributed) when the caller
  ///                               does not pass an explicit value. 0 = no expiry.
  ///   LocalCacheEnabled         — When False the L1 tier is bypassed entirely
  ///                               (all reads go to L2). Useful for testing.
  ///   DistributedCacheEnabled   — When False the L2 tier is bypassed entirely
  ///                               (pure in-memory mode with no Redis dependency).
  ///
  /// .NET equivalent: HybridCacheOptions
  /// </summary>
  THybridCacheOptions = class
  private
    fDefaultLocalExpirationMs  : Integer;
    fDefaultRemoteExpirationMs : Integer;
    fLocalCacheEnabled         : Boolean;
    fDistributedCacheEnabled   : Boolean;
  public
    constructor Create;
    property DefaultLocalExpirationMs  : Integer read fDefaultLocalExpirationMs  write fDefaultLocalExpirationMs;
    property DefaultRemoteExpirationMs : Integer read fDefaultRemoteExpirationMs write fDefaultRemoteExpirationMs;
    /// <summary>When False, L1 (IMemoryCache) is bypassed. Default: True.</summary>
    property LocalCacheEnabled         : Boolean read fLocalCacheEnabled         write fLocalCacheEnabled;
    /// <summary>When False, L2 (IDistributedCache) is bypassed. Default: True when assigned.</summary>
    property DistributedCacheEnabled   : Boolean read fDistributedCacheEnabled   write fDistributedCacheEnabled;
  end;

  // ─── Interface ───────────────────────────────────────────────────────────────

  /// <summary>
  /// Two-level cache: L1 = IMemoryCache (in-process), L2 = IDistributedCache (Redis etc.).
  ///
  /// Read path (GetOrCreate):
  ///   1. Check L1.  Hit → return immediately.
  ///   2. Check L2.  Hit → populate L1, return.
  ///   3. Miss       → execute factory, write L1 + L2, return.
  ///
  /// Write path (SetValue): writes to L1 and L2 simultaneously.
  /// Remove: removes from L1 and L2 simultaneously.
  ///
  /// .NET equivalent: IHybridCache (Microsoft.Extensions.Caching.Hybrid)
  /// </summary>
  IHybridCache = interface
  ['{E3F4A5B6-C7D8-4E9F-B0A1-2C3D4E5F6708}']
    // GetOrCreate with explicit TTLs (milliseconds, 0 = use option default / no expiry)
    function GetOrCreate(const aKey: string; aFactory: TFunc<string>;
      aLocalExpirationMs: Integer = 0; aRemoteExpirationMs: Integer = 0): string;

    // Direct set — writes to both tiers
    procedure SetValue(const aKey, aValue: string;
      aLocalExpirationMs: Integer = 0; aRemoteExpirationMs: Integer = 0);

    // Retrieve without factory (returns empty string on miss)
    function TryGetValue(const aKey: string; out aValue: string): Boolean;

    // Remove from both tiers
    procedure Remove(const aKey: string);

    // Flush entire L1 (L2 flush is a no-op — Redis flush is an admin operation)
    procedure FlushLocal;
  end;

  // ─── Implementation ──────────────────────────────────────────────────────────

  /// <summary>
  /// Default implementation of IHybridCache.
  ///
  /// Thread-safety: A per-key critical section prevents simultaneous factory
  /// invocations for the same key (stampede protection). Global L1/L2 calls
  /// are protected by the respective cache implementations themselves.
  ///
  /// Instantiation (prefer DI via AddHybridCache):
  ///   cache := THybridCache.Create(l1, l2, options);
  /// </summary>
  THybridCache = class(TInterfacedObject, IHybridCache)
  private
    fL1      : IMemoryCache;
    fL2      : IDistributedCache;
    fOptions : THybridCacheOptions;
    fLock    : TCriticalSection;   // stampede-protection lock (lightweight — key-level would need a map)
    fOwnsOptions : Boolean;

    function  L1ExpirationMs(aOverride: Integer): Integer; inline;
    function  L2ExpirationMs(aOverride: Integer): Integer; inline;
    function  L1Enabled: Boolean; inline;
    function  L2Enabled: Boolean; inline;
    procedure WriteToL1(const aKey, aValue: string; aExpirationMs: Integer);
    procedure WriteToL2(const aKey, aValue: string; aExpirationMs: Integer);
  public
    /// <param name="aL1">In-process memory cache. Required.</param>
    /// <param name="aL2">Distributed cache (Redis, etc.). May be nil — L2 is skipped.</param>
    /// <param name="aOptions">Optional configuration. Owned and freed by this instance.</param>
    constructor Create(const aL1: IMemoryCache; const aL2: IDistributedCache;
      aOptions: THybridCacheOptions = nil);
    destructor Destroy; override;

    function GetOrCreate(const aKey: string; aFactory: TFunc<string>;
      aLocalExpirationMs: Integer = 0; aRemoteExpirationMs: Integer = 0): string;
    procedure SetValue(const aKey, aValue: string;
      aLocalExpirationMs: Integer = 0; aRemoteExpirationMs: Integer = 0);
    function TryGetValue(const aKey: string; out aValue: string): Boolean;
    procedure Remove(const aKey: string);
    procedure FlushLocal;
  end;

implementation

// ─── THybridCacheOptions ──────────────────────────────────────────────────────

constructor THybridCacheOptions.Create;
begin
  inherited Create;
  fDefaultLocalExpirationMs  := 0;
  fDefaultRemoteExpirationMs := 0;
  fLocalCacheEnabled         := True;
  fDistributedCacheEnabled   := True;
end;

// ─── THybridCache ─────────────────────────────────────────────────────────────

constructor THybridCache.Create(const aL1: IMemoryCache; const aL2: IDistributedCache;
  aOptions: THybridCacheOptions = nil);
begin
  inherited Create;
  if aL1 = nil then
    raise EArgumentNilException.Create('THybridCache: aL1 (IMemoryCache) must not be nil');
  fL1   := aL1;
  fL2   := aL2;
  fLock := TCriticalSection.Create;

  if aOptions <> nil then
  begin
    fOptions    := aOptions;
    fOwnsOptions := False;
  end
  else
  begin
    fOptions    := THybridCacheOptions.Create;
    fOwnsOptions := True;
  end;
end;

destructor THybridCache.Destroy;
begin
  fLock.Free;
  if fOwnsOptions then
    fOptions.Free;
  inherited;
end;

function THybridCache.L1ExpirationMs(aOverride: Integer): Integer;
begin
  if aOverride > 0 then Result := aOverride
  else Result := fOptions.DefaultLocalExpirationMs;
end;

function THybridCache.L2ExpirationMs(aOverride: Integer): Integer;
begin
  if aOverride > 0 then Result := aOverride
  else Result := fOptions.DefaultRemoteExpirationMs;
end;

function THybridCache.L1Enabled: Boolean;
begin
  Result := fOptions.LocalCacheEnabled;
end;

function THybridCache.L2Enabled: Boolean;
begin
  Result := (fL2 <> nil) and fOptions.DistributedCacheEnabled;
end;

procedure THybridCache.WriteToL1(const aKey, aValue: string; aExpirationMs: Integer);
begin
  if L1Enabled then
    fL1.SetValue(aKey, aValue, L1ExpirationMs(aExpirationMs));
end;

procedure THybridCache.WriteToL2(const aKey, aValue: string; aExpirationMs: Integer);
begin
  if L2Enabled then
    fL2.SetValue(aKey, aValue, L2ExpirationMs(aExpirationMs));
end;

// ─── IHybridCache impl ────────────────────────────────────────────────────────

function THybridCache.TryGetValue(const aKey: string; out aValue: string): Boolean;
begin
  aValue := '';
  // L1 check
  if L1Enabled then
  begin
    if fL1.TryGetValue(aKey, aValue) then
      Exit(True);
  end;
  // L2 check
  if L2Enabled then
  begin
    if fL2.TryGetValue(aKey, aValue) then
    begin
      // Backfill L1 (use default local TTL — we don't know original TTL from L2)
      WriteToL1(aKey, aValue, 0);
      Exit(True);
    end;
  end;
  Result := False;
end;

function THybridCache.GetOrCreate(const aKey: string; aFactory: TFunc<string>;
  aLocalExpirationMs: Integer = 0; aRemoteExpirationMs: Integer = 0): string;
var
  value: string;
begin
  if not Assigned(aFactory) then
    raise EArgumentNilException.Create('THybridCache.GetOrCreate: aFactory must not be nil');

  // Fast path: check L1 outside the lock
  if L1Enabled then
  begin
    if fL1.TryGetValue(aKey, value) then
      Exit(value);
  end;

  // Stampede protection: only one thread invokes factory + populates caches per key
  fLock.Enter;
  try
    // Double-check L1 inside the lock
    if L1Enabled then
    begin
      if fL1.TryGetValue(aKey, value) then
        Exit(value);
    end;

    // L2 check inside the lock
    if L2Enabled then
    begin
      if fL2.TryGetValue(aKey, value) then
      begin
        // Backfill L1 with the L2 value
        WriteToL1(aKey, value, aLocalExpirationMs);
        Exit(value);
      end;
    end;

    // Full miss: invoke factory
    value := aFactory();

    // Populate both tiers
    WriteToL1(aKey, value, aLocalExpirationMs);
    WriteToL2(aKey, value, aRemoteExpirationMs);

    Result := value;
  finally
    fLock.Leave;
  end;
end;

procedure THybridCache.SetValue(const aKey, aValue: string;
  aLocalExpirationMs: Integer = 0; aRemoteExpirationMs: Integer = 0);
begin
  WriteToL1(aKey, aValue, aLocalExpirationMs);
  WriteToL2(aKey, aValue, aRemoteExpirationMs);
end;

procedure THybridCache.Remove(const aKey: string);
begin
  if L1Enabled then
    fL1.RemoveValue(aKey);
  if L2Enabled then
    fL2.RemoveValue(aKey);
end;

procedure THybridCache.FlushLocal;
begin
  if L1Enabled then
    fL1.Flush;
end;

end.
