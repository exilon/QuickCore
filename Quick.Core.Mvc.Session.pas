{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Mvc.Session
  Description : Core Mvc Sessions
  Author      : Kike Perez
  Version     : 1.8
  Created     : 23/02/2020
  Modified    : 23/02/2020

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

unit Quick.Core.Mvc.Session;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.Generics.Collections,
  System.SyncObjs,
  Quick.Options,
  Quick.Core.Caching.Abstractions;

type

  TCookie = class
  private
    fName : string;
    fPath : string;
    fSameSite : Boolean;
    fHttpOnly : Boolean;
    fIsEssential : Boolean;
  public
    property Name : string read fName write fName;
    property Path : string read fPath write fPath;
    property SameSite : Boolean read fSameSite write fSameSite;
    property HttpOnly : Boolean read fHttpOnly write fHttpOnly;
    property IsEssential : Boolean read fIsEssential write fIsEssential;
  end;

  TSessionOptions = class(TOptions)
  private
    fCookie : TCookie;
  public
    property Cookie : TCookie read fCookie write fCookie;
  end;

  ISession = interface
  ['{AC19179A-0E41-4DBB-A34A-88EBADCB7072}']
    function GetId : string;
    function GetIsAvailable : Boolean;
    procedure SetString(const aKey : string; const aValue : string);
    procedure SetInteger(const aKey : string; const aValue : Int64);
    procedure SetFloat(const aKey : string; const aValue : Extended);
    function GetString(const aKey : string) : string;
    function GetInteger(const aKey : string) : Int64;
    function GetFloat(const aKey : string) : Extended;
    procedure Remove(const aValue : string);
    procedure Load;
    procedure Commit;
    procedure Clear;
    property Id : string read GetId;
    property IsAvailable : Boolean read GetIsAvailable;
    //property Keys : IEnumerable<String> read GetKeys;
  end;

  ISessionStore = interface
  ['{C38662D7-BC04-4FEF-B6B0-A5E3926992D8}']
    function CreateSession(const aSessionKey : string; aIdleTimeOut : Integer; aIsNewSessionKey : Boolean) : ISession;
  end;

  IDistributedSessionStore = interface(ISessionStore)
  ['{E07C37F4-EA90-4724-8A29-71AAC06F60BA}']
    function CreateSession(const aSessionKey : string; aIdleTimeOut : Integer; aIsNewSessionKey : Boolean) : ISession;
  end;

  TDistributedSession = class(TInterfacedObject,ISession)
  private
    fId : string;
    fIsAvailable : Boolean;
    fDictionary : TDictionary<string,string>;
    function GetId : string;
    function GetIsAvailable : Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    property Id : string read GetId write fId;
    property IsAvailable : Boolean read GetIsAvailable write fIsAvailable;
    procedure SetString(const aKey : string; const aValue : string);
    procedure SetInteger(const aKey : string; const aValue : Int64);
    procedure SetFloat(const aKey : string; const aValue : Extended);
    function GetString(const aKey : string) : string;
    function GetInteger(const aKey : string) : Int64;
    function GetFloat(const aKey : string) : Extended;
    procedure Remove(const aValue : string);
    procedure Load;
    procedure Commit;
    procedure Clear;
  end;

  TDistributedSessionStore = class(TInterfacedObject,IDistributedSessionStore)
  private
    fDistributedCache : IDistributedCache;
  public
    constructor Create(aDistributedCache : IDistributedCache); virtual;
    function CreateSession(const aSessionKey : string; aIdleTimeOut : Integer; aIsNewSessionKey : Boolean) : ISession; virtual;
  end;

  { Forward declaration }
  TInMemorySessionStore = class;

  { TInMemorySession — ISession backed by TInMemorySessionStore }
  TInMemorySession = class(TInterfacedObject, ISession)
  private
    fId              : string;
    fIsAvailable     : Boolean;
    fData            : TDictionary<string, string>; // reference — owned by store
    fStore           : TInMemorySessionStore;       // not owned
    fIdleTimeoutSecs : Integer;
    function GetId            : string;
    function GetIsAvailable   : Boolean;
  public
    constructor Create(const aId : string; aData : TDictionary<string, string>;
                       aStore : TInMemorySessionStore; aIdleTimeoutSecs : Integer);
    property Id          : string  read GetId;
    property IsAvailable : Boolean read GetIsAvailable;
    procedure SetString(const aKey : string; const aValue : string);
    procedure SetInteger(const aKey : string; const aValue : Int64);
    procedure SetFloat(const aKey : string; const aValue : Extended);
    function  GetString(const aKey : string) : string;
    function  GetInteger(const aKey : string) : Int64;
    function  GetFloat(const aKey : string) : Extended;
    procedure Remove(const aValue : string);
    procedure Load;
    procedure Commit;
    procedure Clear;
  end;

  { TInMemorySessionStore — thread-safe in-process session store }
  TInMemorySessionStore = class(TInterfacedObject, ISessionStore)
  private
    fSessions            : TObjectDictionary<string, TDictionary<string, string>>;
    fExpiry              : TDictionary<string, TDateTime>;
    fLock                : TCriticalSection;
    fDefaultIdleTimeout  : Integer;  // seconds
    procedure CleanExpired;
  public
    constructor Create(aDefaultIdleTimeoutSecs : Integer = 1200);
    destructor Destroy; override;
    function  CreateSession(const aSessionKey : string; aIdleTimeOut : Integer;
                             aIsNewSessionKey : Boolean) : ISession;
    function  SessionExists(const aSessionKey : string) : Boolean;
    procedure UpdateExpiry(const aSessionKey : string; aIdleTimeoutSecs : Integer);
  end;

implementation

{ TDistributedSessionStore }

constructor TDistributedSessionStore.Create(aDistributedCache: IDistributedCache);
begin
  fDistributedCache := aDistributedCache;
end;

function TDistributedSessionStore.CreateSession(const aSessionKey: string; aIdleTimeOut: Integer; aIsNewSessionKey: Boolean): ISession;
begin

end;

{ TDistributedSession }

constructor TDistributedSession.Create;
begin
  fDictionary := TDictionary<string,string>.Create;
end;

destructor TDistributedSession.Destroy;
begin
  fDictionary.Free;
  inherited;
end;

function TDistributedSession.GetFloat(const aKey: string): Extended;
var
  value : string;
begin
  Result := 0.0;
  if fDictionary.TryGetValue(aKey,value) then Result := value.ToExtended;
end;

function TDistributedSession.GetId: string;
begin
  Result := fId;
end;

function TDistributedSession.GetInteger(const aKey: string): Int64;
var
  value : string;
begin
  Result := 0;
  if fDictionary.TryGetValue(aKey,value) then Result := value.ToInt64;
end;

function TDistributedSession.GetIsAvailable: Boolean;
begin
  Result := fIsAvailable;
end;

function TDistributedSession.GetString(const aKey: string): string;
begin
  fDictionary.TryGetValue(aKey,Result);
end;

procedure TDistributedSession.SetFloat(const aKey: string; const aValue: Extended);
begin
  fDictionary.Add(aKey,aValue.ToString);
end;

procedure TDistributedSession.SetInteger(const aKey: string; const aValue: Int64);
begin
  fDictionary.Add(aKey,aValue.ToString);
end;

procedure TDistributedSession.SetString(const aKey, aValue: string);
begin
  fDictionary.Add(aKey,aValue);
end;

procedure TDistributedSession.Load;
begin

end;

procedure TDistributedSession.Remove(const aValue: string);
begin

end;

procedure TDistributedSession.Clear;
begin

end;

procedure TDistributedSession.Commit;
begin

end;

{ TInMemorySession }

constructor TInMemorySession.Create(const aId : string; aData : TDictionary<string, string>;
                                    aStore : TInMemorySessionStore; aIdleTimeoutSecs : Integer);
begin
  fId              := aId;
  fData            := aData;
  fStore           := aStore;
  fIdleTimeoutSecs := aIdleTimeoutSecs;
  fIsAvailable     := True;
end;

function TInMemorySession.GetId : string;
begin
  Result := fId;
end;

function TInMemorySession.GetIsAvailable : Boolean;
begin
  Result := fIsAvailable;
end;

procedure TInMemorySession.SetString(const aKey : string; const aValue : string);
begin
  fData.AddOrSetValue(aKey, aValue);
end;

procedure TInMemorySession.SetInteger(const aKey : string; const aValue : Int64);
begin
  fData.AddOrSetValue(aKey, aValue.ToString);
end;

procedure TInMemorySession.SetFloat(const aKey : string; const aValue : Extended);
begin
  fData.AddOrSetValue(aKey, aValue.ToString);
end;

function TInMemorySession.GetString(const aKey : string) : string;
begin
  fData.TryGetValue(aKey, Result);
end;

function TInMemorySession.GetInteger(const aKey : string) : Int64;
var
  s : string;
begin
  Result := 0;
  if fData.TryGetValue(aKey, s) then Result := StrToInt64Def(s, 0);
end;

function TInMemorySession.GetFloat(const aKey : string) : Extended;
var
  s : string;
begin
  Result := 0.0;
  if fData.TryGetValue(aKey, s) then Result := StrToFloatDef(s, 0.0);
end;

procedure TInMemorySession.Remove(const aValue : string);
begin
  fData.Remove(aValue);
end;

procedure TInMemorySession.Load;
begin
  // Data is already loaded from the store — no-op for in-memory sessions
end;

procedure TInMemorySession.Commit;
begin
  // Data dict is shared with the store — just refresh the expiry TTL
  if fStore <> nil then
    fStore.UpdateExpiry(fId, fIdleTimeoutSecs);
end;

procedure TInMemorySession.Clear;
begin
  fData.Clear;
end;

{ TInMemorySessionStore }

constructor TInMemorySessionStore.Create(aDefaultIdleTimeoutSecs : Integer = 1200);
begin
  fDefaultIdleTimeout := aDefaultIdleTimeoutSecs;
  fSessions := TObjectDictionary<string, TDictionary<string, string>>.Create([doOwnsValues]);
  fExpiry   := TDictionary<string, TDateTime>.Create;
  fLock     := TCriticalSection.Create;
end;

destructor TInMemorySessionStore.Destroy;
begin
  fLock.Free;
  fExpiry.Free;
  fSessions.Free;
  inherited;
end;

procedure TInMemorySessionStore.CleanExpired;
var
  id       : string;
  expired  : TArray<string>;
  expireAt : TDateTime;
  currentTime : TDateTime;
  i        : Integer;
begin
  // Called while fLock is held
  currentTime := Now;
  expired := [];
  for id in fExpiry.Keys do
  begin
    if fExpiry.TryGetValue(id, expireAt) and (currentTime > expireAt) then
      expired := expired + [id];
  end;
  for i := 0 to High(expired) do
  begin
    fExpiry.Remove(expired[i]);
    fSessions.Remove(expired[i]);
  end;
end;

function TInMemorySessionStore.CreateSession(const aSessionKey : string;
                                              aIdleTimeOut : Integer;
                                              aIsNewSessionKey : Boolean) : ISession;
var
  data    : TDictionary<string, string>;
  timeout : Integer;
begin
  timeout := aIdleTimeOut;
  if timeout <= 0 then timeout := fDefaultIdleTimeout;

  fLock.Enter;
  try
    CleanExpired;

    if aIsNewSessionKey or not fSessions.TryGetValue(aSessionKey, data) then
    begin
      // New session — create fresh data dict
      data := TDictionary<string, string>.Create;
      fSessions.AddOrSetValue(aSessionKey, data);
    end;
    fExpiry.AddOrSetValue(aSessionKey, IncSecond(Now, timeout));
  finally
    fLock.Leave;
  end;

  Result := TInMemorySession.Create(aSessionKey, data, Self, timeout);
end;

function TInMemorySessionStore.SessionExists(const aSessionKey : string) : Boolean;
var
  expireAt : TDateTime;
begin
  fLock.Enter;
  try
    Result := fSessions.ContainsKey(aSessionKey) and
              fExpiry.TryGetValue(aSessionKey, expireAt) and
              (Now <= expireAt);
  finally
    fLock.Leave;
  end;
end;

procedure TInMemorySessionStore.UpdateExpiry(const aSessionKey : string; aIdleTimeoutSecs : Integer);
begin
  fLock.Enter;
  try
    if fSessions.ContainsKey(aSessionKey) then
      fExpiry.AddOrSetValue(aSessionKey, IncSecond(Now, aIdleTimeoutSecs));
  finally
    fLock.Leave;
  end;
end;

end.
