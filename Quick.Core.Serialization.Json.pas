{ ***************************************************************************

  Copyright (c) 2016-2022 Kike Pérez

  Unit        : Quick.Core.Serializer.Json
  Description : Core Json Serializer
  Author      : Kike Pérez
  Version     : 1.8
  Created     : 12/10/2019
  Modified    : 17/05/2022

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

unit Quick.Core.Serialization.Json;

{$i QuickCore.inc}

interface

uses
  RTTI,
  Quick.Json.Serializer,
  Quick.Core.Serialization.Abstractions;

type
  TJsonSerializer = class(TInterfacedObject,ISerializer)
  private
    fSerializer : Quick.Json.Serializer.TJsonSerializer;
    procedure SetSerializationLevel(const Value: TSerializationLevel);
  public
    constructor Create;
    destructor Destroy; override;
    property SerializationLevel : TSerializationLevel write SetSerializationLevel;
    function FromObject(aObject : TObject) : string; overload;
    function FromObject(aObject : TObject; aIndent : Boolean): string; overload;
    function FromValue(aValue : TValue) : string; overload;
    function FromValue(aValue : TValue; aIndent : Boolean) : string; overload;
    function FromArray<T>(aArray : TArray<T>) : string; overload;
    function FromArray<T>(aArray : TArray<T>; aIndent : Boolean) : string; overload;
    function ToObject(aType : TClass; const aJson: string) : TObject; overload;
    function ToObject(aObject : TObject; const aJson: string) : TObject; overload;
    function ToArray<T>(const aJson : string) : TArray<T>;
    function ToValue(const aJson : string) : TValue;
    function Options : TSerializerOptions;
  end;

implementation

{ TJsonSerializer }

constructor TJsonSerializer.Create;
begin
  fSerializer := Quick.Json.Serializer.TJsonSerializer.Create(TSerializeLevel.slPublicProperty,True);
  fSerializer.UseGUIDLowerCase := True;
end;

destructor TJsonSerializer.Destroy;
begin
  fSerializer.Free;
  inherited;
end;

function TJsonSerializer.FromArray<T>(aArray: TArray<T>; aIndent: Boolean): string;
begin
  Result := fSerializer.ArrayToJson<T>(aArray,aIndent);
end;

function TJsonSerializer.FromArray<T>(aArray: TArray<T>): string;
begin
  Result := fSerializer.ArrayToJson<T>(aArray,False);
end;

function TJsonSerializer.FromObject(aObject: TObject): string;
begin
  Result := fSerializer.ObjectToJson(aObject,False);
end;

function TJsonSerializer.FromObject(aObject: TObject; aIndent: Boolean): string;
begin
  Result := fSerializer.ObjectToJson(aObject,aIndent);
end;

function TJsonSerializer.FromValue(aValue: TValue): string;
begin
  Result := fSerializer.ValueToJson(aValue,False);
end;

function TJsonSerializer.FromValue(aValue: TValue; aIndent: Boolean): string;
begin
  Result := fSerializer.ValueToJson(aValue,aIndent);
end;

function TJsonSerializer.Options: TSerializerOptions;
begin
  Result := fSerializer.Options;
end;

procedure TJsonSerializer.SetSerializationLevel(const Value: TSerializationLevel);
begin
  fSerializer.SerializeLevel := Quick.Json.Serializer.TSerializeLevel(Integer(Value));
end;

function TJsonSerializer.ToArray<T>(const aJson: string): TArray<T>;
begin
  Result := fSerializer.JsonToArray<T>(aJson);
end;

function TJsonSerializer.ToObject(aType: TClass; const aJson: string): TObject;
begin
  Result := fSerializer.JsonToObject(aType,aJson);
end;

function TJsonSerializer.ToObject(aObject: TObject; const aJson: string): TObject;
begin
  Result := fSerializer.JsonToObject(aObject,aJson);
end;

function TJsonSerializer.ToValue(const aJson: string): TValue;
begin
  Result := fSerializer.JsonToValue(aJson);
end;



end.
