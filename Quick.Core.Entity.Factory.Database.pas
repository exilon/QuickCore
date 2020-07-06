{ ***************************************************************************

  Copyright (c) 2016-2019 Kike Pérez

  Unit        : Quick.Core.Entity.Database
  Description : Core Entity DataBase Factory
  Author      : Kike Pérez
  Version     : 1.8
  Created     : 03/11/2019
  Modified    : 26/05/2020

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

unit Quick.Core.Entity.Factory.Database;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Core.Entity.DAO,
  Quick.Core.Entity.Query,
  Quick.Core.Entity.Database,
  {$IFDEF MSWINDOWS}
  Quick.Core.Entity.Engine.ADO,
  {$ENDIF}
  Quick.Core.Entity.Engine.FireDAC,
  Quick.Core.Entity.Engine.RestServer;

type
  TEntityDatabaseFactory = class
  public
    class function GetInstance(aDatabaseEngine : TDatabaseEngine) : TEntityDatabase;
    class function GetQueryInstance<T : class, constructor>(aDatabase: TEntityDatabase; aModel : TEntityModel): TEntityQuery<T>; overload;
    class function GetQueryInstance<T : class, constructor>(aDatabase: TEntityDatabase): TEntityQuery<T>; overload;
  end;

  EEntityDatabaseFactoryError = class(Exception);

implementation

{ TEntityDatabaseFactory }

class function TEntityDatabaseFactory.GetInstance(aDatabaseEngine: TDatabaseEngine): TEntityDatabase;
begin
  case aDatabaseEngine of
    {$IFDEF MSWINDOWS}
    deADO : Result := TADOEntityDataBase.Create;
    {$ENDIF}
    deFireDAC : Result := TFireDACEntityDataBase.Create;
    deRestServer : Result := TRestServerEntityDataBase.Create;
  else
    raise EEntityDatabaseFactoryError.Create('Unknown database engine specified!');
  end;
  Result.Models.PluralizeTableNames := True;
end;

class function TEntityDatabaseFactory.GetQueryInstance<T>(aDatabase: TEntityDatabase; aModel : TEntityModel): TEntityQuery<T>;
begin
  if aDatabase is TFireDACEntityDataBase then Result := TFireDACEntityQuery<T>.Create(aDatabase,aModel{aDatabase.Models.Get(TDAORecordClass(T))},aDatabase.QueryGenerator)
  {$IFDEF MSWINDOWS}
  else if aDatabase is TADOEntityDataBase then Result := TADOEntityQuery<T>.Create(aDatabase,aModel{aDatabase.Models.Get(TDAORecordClass(T))},aDatabase.QueryGenerator)
  {$ENDIF}
  else if aDatabase is TRestServerEntityDataBase then Result := TRestServerEntityQuery<T>.Create(aDatabase,aModel,aDatabase.QueryGenerator);
end;

class function TEntityDatabaseFactory.GetQueryInstance<T>(aDatabase: TEntityDatabase): TEntityQuery<T>;
begin
  if aDatabase is TFireDACEntityDataBase then Result := TFireDACEntityQuery<T>.Create(aDatabase,aDatabase.Models.Get(TEntityClass(T)),aDatabase.QueryGenerator)
  {$IFDEF MSWINDOWS}
  else if aDatabase is TADOEntityDataBase then Result := TADOEntityQuery<T>.Create(aDatabase,aDatabase.Models.Get(TEntityClass(T)),aDatabase.QueryGenerator)
  {$ENDIF}
  else if aDatabase is TRestServerEntityDataBase then Result := TRestServerEntityQuery<T>.Create(aDatabase,aDatabase.Models.Get(TEntityClass(T)),aDatabase.QueryGenerator);
end;

end.
