{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Serialization.Yaml
  Description : Core Yaml Serializer
  Author      : Kike Pérez
  Version     : 1.8
  Created     : 12/10/2019
  Modified    : 18/06/2020

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

unit Quick.Core.Serialization.Yaml;

{$i QuickCore.inc}

interface

uses
  RTTI,
  Quick.Yaml.Serializer,
  Quick.Core.Serialization.Abstractions;

type
  TYamlSerializer = class
  private
    fSerializer : Quick.Yaml.Serializer.TYamlSerializer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetSerializationLevel(const Value: TSerializationLevel);
    function FromObject(aObject : TObject): string; inline;
    //function FromValue(aValue : TValue) : string; inline;
    //function FromArray<T>(aArray : TArray<T>; aIndent : Boolean = False) : string; inline;
    function ToObject(aType : TClass; const aYaml: string) : TObject; overload; inline;
    function ToObject(aObject : TObject; const aYaml: string) : TObject; overload; inline;
    //function ToArray<T>(const aYaml : string) : TArray<T>; inline;
  end;

implementation

{ TYamlSerializer }

constructor TYamlSerializer.Create;
begin
  fSerializer := Quick.Yaml.Serializer.TYamlSerializer.Create(Quick.Yaml.Serializer.TSerializeLevel.slPublicProperty,True);
end;

destructor TYamlSerializer.Destroy;
begin
  fSerializer.Free;
  inherited;
end;

//function TYamlSerializerProvider.FromArray<T>(aArray: TArray<T>; aIndent: Boolean): string;
//begin
//  Result := fSerializer.ArrayToYaml<T>(aArray,aIndent);
//end;

function TYamlSerializer.FromObject(aObject: TObject): string;
begin
  Result := fSerializer.ObjectToYaml(aObject);
end;

procedure TYamlSerializer.SetSerializationLevel(const Value: TSerializationLevel);
begin
  fSerializer.SerializeLevel := Quick.Yaml.Serializer.TSerializeLevel(Integer(Value));
end;

//function TYamlSerializerProvider.FromValue(aValue: TValue; aIndent: Boolean): string;
//begin
//  Result := fSerializer.ValueToYaml(aValue,aIndent);
//end;

//function TYamlSerializerProvider.ToArray<T>(const aJson: string): TArray<T>;
//begin
//  Result := fSerializer.YamlToArray<T>(aJson);
//end;

function TYamlSerializer.ToObject(aType: TClass; const aYaml: string): TObject;
begin
  Result := fSerializer.YamlToObject(aType,aYaml);
end;

function TYamlSerializer.ToObject(aObject: TObject; const aYaml: string): TObject;
begin
  Result := fSerializer.YamlToObject(aObject,aYaml);
end;

end.
