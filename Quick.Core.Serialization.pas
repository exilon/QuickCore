{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Serialization
  Description : Core Serialization
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

unit Quick.Core.Serialization;

{$i QuickCore.inc}

interface

uses
  RTTI,
  Quick.Core.Serialization.Abstractions,
  Quick.Core.Serialization.Json,
  Quick.Core.Serialization.Yaml;

type

  ISerializers = interface
  ['{C4816EB9-0AD2-4989-A825-D30963E8AAA4}']
    function Json : TJsonSerializer;
    function Yaml : TYamlSerializer;
  end;

  TSerializers = class(TInterfacedObject,ISerializers)
  private
    fJsonSerializer : TJsonSerializer;
    fYamlSerializer : TYamlSerializer;
  public
    constructor Create;
    destructor Destroy; override;
    function Json : TJsonSerializer;
    function Yaml : TYamlSerializer;
  end;

implementation


{ TSerializers }

constructor TSerializers.Create;
begin
  fJsonSerializer := TJsonSerializer.Create;
  fYamlSerializer := TYamlSerializer.Create;
end;

destructor TSerializers.Destroy;
begin
  fJsonSerializer.Free;
  fYamlSerializer.Free;
  inherited;
end;

function TSerializers.Json: TJsonSerializer;
begin
  Result := fJsonSerializer;
end;

function TSerializers.Yaml: TYamlSerializer;
begin
  Result := fYamlSerializer;
end;


end.
