{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Extensions.AutoMapper
  Description : Core Extensions Memory Cache
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 02/02/2020
  Modified    : 08/02/2020

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

unit Quick.Core.Extensions.AutoMapper;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Core.DependencyInjection,
  Quick.Core.Mapping.Abstractions,
  Quick.Core.AutoMapper;

type
  TAutoMapperServiceExtension = class(TServiceCollectionExtension)
    class function AddAutoMapper : TServiceCollection; overload;
  end;

implementation

{ TAutoMapperServiceExtension }

class function TAutoMapperServiceExtension.AddAutoMapper : TServiceCollection;
begin
  Result := ServiceCollection;
  if not Result.IsRegistered<IMapper,TAutoMapper> then
  begin
    Result.AddSingleton<IMapper,TAutoMapper>;
  end;
end;

end.
