{ ***************************************************************************

  Copyright (c) 2016-2019 Kike Pérez

  Unit        : Quick.Core.Entity.QueryGenerator
  Description : Core Entity Factory Query Generator
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 22/06/2018
  Modified    : 25/05/2020

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

unit Quick.Core.Entity.Factory.QueryGenerator;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Core.Entity.DAO,
  Quick.Core.Entity.QueryGenerator.MSSQL,
  Quick.Core.Entity.QueryGenerator.MSAccess,
  Quick.Core.Entity.QueryGenerator.SQLite,
  Quick.Core.Entity.QueryGenerator.MySQL;

type

  TEntityQueryGeneratorFactory = class
  public
    class function Create(aDBProvider : TDBProvider) : IEntityQueryGenerator;
  end;

  EEntityQueryGeneratorError = class(Exception);

implementation

{ TEntityQueryGeneratorFactory }

class function TEntityQueryGeneratorFactory.Create(aDBProvider : TDBProvider) : IEntityQueryGenerator;
begin
  case aDBProvider of
    TDBProvider.dbMSAccess2000 : Result := TMSAccessQueryGenerator.Create;
    TDBProvider.dbMSAccess2007 : Result := TMSAccessQueryGenerator.Create;
    TDBProvider.dbMSSQL : Result := TMSSQLQueryGenerator.Create;
    TDBProvider.dbMySQL : Result := TMySQLQueryGenerator.Create;
    TDBProvider.dbSQLite : Result := TSQLiteQueryGenerator.Create;
    TDBProvider.dbRestServer : Result := nil;
    //TDAODBType.daoFirebase : Result := TFireBaseQueryGenerator.Create;
    else raise EEntityQueryGeneratorError.Create('No valid QueryGenerator provider specified!');
  end;
end;

end.
