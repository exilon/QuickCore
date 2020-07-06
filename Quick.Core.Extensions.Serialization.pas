{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Extensions.Serialization
  Description : Core Extensions Serialization
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 02/02/2020
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

unit Quick.Core.Extensions.Serialization;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Core.DependencyInjection,
  Quick.Core.Serialization.Abstractions,
  Quick.Core.Serialization.Json,
  Quick.Core.Serialization.Yaml;

type
  TSerializationServiceExtension = class(TServiceCollectionExtension)
    class function AddJsonSerializer : TServiceCollection;
    class function AddYamlSerializer  : TServiceCollection;
  end;

implementation

{ TSerializationServiceExtension }

class function TSerializationServiceExtension.AddJsonSerializer : TServiceCollection;
begin
  Result := ServiceCollection;
  if not Result.IsRegistered<ISerializer,TJsonSerializer> then
  begin
    Result.AddSingleton<ISerializer,TJsonSerializer>;
  end;
end;

class function TSerializationServiceExtension.AddYamlSerializer : TServiceCollection;
begin
  Result := ServiceCollection;
  if not Result.IsRegistered<ISerializer,TYamlSerializer> then
  begin
    Result.AddSingleton<ISerializer,TYamlSerializer>;
  end;
end;

end.
