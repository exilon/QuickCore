{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Mvc.WebApi
  Description : Http WebApi Server
  Author      : Kike Perez
  Version     : 1.8
  Created     : 30/09/2019
  Modified    : 31/10/2019

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

unit Quick.Core.Mvc.WebApi;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Quick.Commons,
  Quick.Logger.Intf,
  Quick.Core.Mvc;

type
  TApiKey = class
  private
    fName : string;
    fKey : string;
    fEnabled : Boolean;
  public
    constructor Create(const aName, aKey: string; aEnabled: Boolean = True);
    property Name : string read fName write fName;
    property Key : string read fKey write fKey;
    property Enabled : Boolean read fEnabled write fEnabled;
  end;

  TApiKeys = class
  private
    fItems : TObjectDictionary<string,TApiKey>;
    function GetApiKey(const aKey: string): TApiKey;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const aName, aKey: string; aEnabled: Boolean = True);
    function Exists(const aApiKey : string) : Boolean;
    property Items[const aKey: string]: TApiKey read GetApiKey; default;
  end;

  TWebApiServer = class(TMVCServer)
  private
    fApiKeys : TApiKeys;
    function GetApiKeys: TApiKeys;
  public
    destructor Destroy; override;
    property ApiKeys : TApiKeys read GetApiKeys write fApiKeys;
  end;


implementation


{ TApiKey }

constructor TApiKey.Create(const aName, aKey: string; aEnabled: Boolean = True);
begin
  inherited Create;
  fName := aName;
  fKey := aKey;
  fEnabled := aEnabled;
end;

{ TApiKeys }

constructor TApiKeys.Create;
begin
  inherited Create;
  fItems := TObjectDictionary<string,TApiKey>.Create([doOwnsValues]);
end;

destructor TApiKeys.Destroy;
begin
  fItems.Free;
  inherited;
end;

procedure TApiKeys.Add(const aName, aKey: string; aEnabled: Boolean = True);
begin
  fItems.AddOrSetValue(aKey, TApiKey.Create(aName, aKey, aEnabled));
end;

function TApiKeys.Exists(const aApiKey: string): Boolean;
begin
  Result := fItems.ContainsKey(aApiKey);
end;

function TApiKeys.GetApiKey(const aKey: string): TApiKey;
begin
  if not fItems.TryGetValue(aKey, Result) then
    Result := nil;
end;

{ TWebApiServer }

function TWebApiServer.GetApiKeys: TApiKeys;
begin
  if fApiKeys = nil then
    fApiKeys := TApiKeys.Create;
  Result := fApiKeys;
end;

destructor TWebApiServer.Destroy;
begin
  fApiKeys.Free;
  inherited;
end;

end.
