{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Serialization.Abstractions
  Description : Core Serialization Abstractions
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 22/02/2020
  Modified    : 11/09/2020

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

unit Quick.Core.Serialization.Abstractions;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Rtti;

type

  TSerializationLevel = (slPublicProperties, slPublishedProperties);

  ISerializer = interface
  ['{FDDE3E1B-2E2B-4189-9A89-619948D50A4A}']
    procedure SetSerializationLevel(const aLevel : TSerializationLevel);
    property SerializationLevel : TSerializationLevel write SetSerializationLevel;
    function FromObject(aObject : TObject): string;
    function FromValue(aValue : TValue) : string;
    //function FromArray<T>(aArray : TArray<T>; aIndent : Boolean = False) : string;
    function ToObject(aType : TClass; const aSerialized: string) : TObject; overload;
    function ToObject(aObject : TObject; const aSerialized: string) : TObject; overload;
    //function ToArray<T>(const aYaml : string) : TArray<T>;
  end;

implementation

end.
