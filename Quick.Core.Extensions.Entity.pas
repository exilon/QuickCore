{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Extensions.Entity
  Description : Core Extensions Entity Database
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 19/10/2019
  Modified    : 25/01/2020

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

unit Quick.Core.Extensions.Entity;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.TypInfo,
  Quick.Core.DependencyInjection,
  Quick.Core.Entity,
  Quick.Core.Entity.Database,
  Quick.Core.Entity.Factory.Database,
  Quick.Core.Entity.Config;

type
  TEntityServiceExtension = class(TServiceCollectionExtension)
    class function AddDBContext<T : TDBContext>(aDBContextOptions : TDbContextOptions): TServiceCollection;
  end;

implementation

{ TEntityServiceExtension }

class function TEntityServiceExtension.AddDBContext<T>(aDBContextOptions : TDbContextOptions): TServiceCollection;
begin
  Result := ServiceCollection;
  //add connection strings to config settings
  if not Result.AppServices.Options.ExistsSection<TConnectionStringSettings>('ConnectionStrings') then
  begin
    Result.Configure<TConnectionStringSettings>('ConnectionStrings');{,procedure(aOptions : TConnectionStringSettings)
      begin
        if not ServiceCollection.AppServices.Options.GetSection<TConnectionStringSettings>
            .ExistsConnection(aDBContextOptions.ConnectionStringName) then
        begin
          aOptions.AddConnection(aDBContextOptions);
        end;
      end);}
  end;

  aDBContextOptions.Name := aDBContextOptions.ConnectionStringName;
  aDBContextOptions.HideOptions := True;
  Result.AppServices.Options.AddOption(aDBContextOptions);
  Result.AddSingleton<T>('',function : T
    var
      opConnStrings : TConnectionStringSettings;
    begin
      Result := (PTypeInfo(TypeInfo(T)).TypeData.ClassType.Create) as T;
      TDBContext(Result).Database := TEntityDatabaseFactory.GetInstance(aDBContextOptions.DBEngine);
      opConnStrings := ServiceCollection.AppServices.Options.GetSection<TConnectionStringSettings>;
      TDBContext(Result).Connection.FromConnectionString(Integer(aDBContextOptions.DBProvider),opConnStrings.GetConnection(aDBContextOptions.ConnectionStringName));
      TDBContext(Result).Connect;
      //aDBContextOptions.Free;
    end);
end;

end.
