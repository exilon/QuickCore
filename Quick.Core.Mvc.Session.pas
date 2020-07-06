{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Mvc.Session
  Description : Core Mvc Sessions
  Author      : Kike Pérez
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
  System.Generics.Collections,
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

end.
