{ ***************************************************************************

  Copyright (c) 2016-2021 Kike Pérez

  Unit        : Quick.Core.Entity.Config
  Description : Core Entity DataBase Config
  Author      : Kike Pérez
  Version     : 1.8
  Created     : 02/11/2019
  Modified    : 21/08/2021

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

unit Quick.Core.Entity.Config;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Core.Entity.DAO,
  Quick.Core.Entity.Database,
  Quick.Options;

type

  TDBConnectionString = record
    Name : string;
    Provider : string;
    ConnectionString : string;
  end;

  TDbContextOptions = class(TOptions)
  private
    fDBProvider : TDBProvider;
    fDBEngine : TDatabaseEngine;
    fConnectionStringName: string;
  public
    constructor Create; override;
    property ConnectionStringName : string read fConnectionStringName write fConnectionStringName;
    property DBProvider : TDBProvider read fDBProvider write fDBProvider;
    property DBEngine : TDatabaseEngine read fDBEngine write fDBEngine;
  end;

  TConnectionStringSettings = class(TOptions)
  private
    fConnectionStrings : TArray<TDBConnectionString>;
  public
    function GetConnection(const aConnectionName : string) : string;
    procedure AddConnection(aDBContextOptions : TDbContextOptions);
    function ExistsConnection(const aConnectionName: string): Boolean;
  published
    property Connections : TArray<TDBConnectionString> read fConnectionStrings write fConnectionStrings;
  end;

  IDBContextOptionsBuilder = interface
  ['{55A6E06C-72CB-4A92-9096-8CD4163F0E82}']
    function UseMSSQL : IDBContextOptionsBuilder;
    function UseSQLite : IDBContextOptionsBuilder;
    function UseMySQL : IDBContextOptionsBuilder;
    function UseMSAccess : IDBContextOptionsBuilder;
    function UseRestServer : IDBContextOptionsBuilder;
    function ConnectionStringName(const aName : string): IDBContextOptionsBuilder;
    function Options : TDbContextOptions;
  end;

  TDBContextOptionsBuilder = class(TOptionsBuilder<TDbContextOptions>,IDBContextOptionsBuilder)
  protected
    function UseMSSQL : IDBContextOptionsBuilder;
    function UseSQLite : IDBContextOptionsBuilder;
    function UseMySQL : IDBContextOptionsBuilder;
    function UseMSAccess : IDBContextOptionsBuilder;
    function UseRestServer : IDBContextOptionsBuilder;
    function ConnectionStringName(const aName : string): IDBContextOptionsBuilder;
  public
    class function GetBuilder : IDBContextOptionsBuilder;
  end;

  IDBConnectionOptions = interface(IDBConnectionSettings)
    function GetDBEngine: TDatabaseEngine;
    property DBEngine : TDataBaseEngine read GetDBEngine;
    property Server : string read GetServer write SetServer;
    property Database : string read GetDatabase write SetDataBase;
    property UserName : string read GetUserName write SetUserName;
    property Password : string read GetPassword write SetPassword;
    function IsCustomConnectionString : Boolean;
    procedure FromConnectionString(aDBProviderID : Integer; const aConnectionString: string);
    function GetCustomConnectionString : string;
    procedure UseMSSQL;
    procedure UseSQLite;
    procedure UseMySQL;
    procedure UseMSAccess;
    procedure UseRestServer;
  end;

  TDBConnectionOptions = class(TDBConnectionSettings,IDBConnectionOptions)
  private
    fDBEngine : TDatabaseEngine;
    function GetDBEngine: TDatabaseEngine;
  public
    property DBEngine : TDatabaseEngine read GetDBEngine;
    procedure UseMSSQL;
    procedure UseSQLite;
    procedure UseMySQL;
    procedure UseMSAccess;
    procedure UseRestServer;
  end;

  TDBConnectionConfigureProc = reference to procedure(aOptions : IDBConnectionOptions);

  EEntityConnectionStringNotFound = class(Exception);

implementation

{ TConnectionStringSettings }

procedure TConnectionStringSettings.AddConnection(aDBContextOptions: TDbContextOptions);
var
  connection : TDBConnectionString;
begin
  connection.Name := aDBContextOptions.ConnectionStringName;
  if aDBContextOptions.DBProvider = TDBProvider.dbSQLite then
  begin
    connection.Provider := 'SQLITE';
    connection.ConnectionString := 'Database=.\\<database>.db';
  end
  else
  begin
    connection.Provider := '';
    connection.ConnectionString := 'Server=<server>;Database=<database>;User Id=<user>;Password=<password>;';
  end;
  //connection.Provider := aDBContextOptions.DBProvider;
  //connection.ConnectionString := '';
  fConnectionStrings := fConnectionStrings + [connection];
end;

function TConnectionStringSettings.GetConnection(const aConnectionName: string): string;
var
  connection : TDBConnectionString;
begin
  for connection in fConnectionStrings do
  begin
    if CompareText(connection.Name,aConnectionName) = 0 then Exit(connection.ConnectionString);
  end;
  raise EEntityConnectionStringNotFound.CreateFmt('ConnectionString "%s" not defined in AppSettings!',[aConnectionName]);
end;

function TConnectionStringSettings.ExistsConnection(const aConnectionName: string): Boolean;
var
  connection : TDBConnectionString;
begin
  for connection in fConnectionStrings do
  begin
    if CompareText(connection.Name,aConnectionName) = 0 then Exit(True);
  end;
  Result := False;
end;

{ TDbContextOptions }

constructor TDbContextOptions.Create;
begin
  fDBProvider := TDBProvider.dbSQLite;
  fDBEngine := TDatabaseEngine.deFireDAC;
end;

{ TDBContextOptionsBuilder }

class function TDBContextOptionsBuilder.GetBuilder: IDBContextOptionsBuilder;
begin
  Result := TDBContextOptionsBuilder.Create;
end;

function TDBContextOptionsBuilder.ConnectionStringName(const aName : string): IDBContextOptionsBuilder;
begin
  Result := Self;
  fOptions.ConnectionStringName := aName;
end;

function TDBContextOptionsBuilder.UseSQLite: IDBContextOptionsBuilder;
begin
  Result := Self;
  fOptions.DBProvider := TDBProvider.dbSQLite;
  fOptions.DBEngine := TDatabaseEngine.deFireDAC;
end;

function TDBContextOptionsBuilder.UseMSSQL: IDBContextOptionsBuilder;
begin
  Result := Self;
  fOptions.DBProvider := TDBProvider.dbMSSQL;
  fOptions.DBEngine := TDatabaseEngine.deADO;
end;

function TDBContextOptionsBuilder.UseMySQL: IDBContextOptionsBuilder;
begin
  Result := Self;
  fOptions.DBProvider := TDBProvider.dbMySQL;
  fOptions.DBEngine := TDatabaseEngine.deFireDAC;
end;

function TDBContextOptionsBuilder.UseMSAccess: IDBContextOptionsBuilder;
begin
  Result := Self;
  fOptions.DBProvider := TDBProvider.dbMSAccess2007;
  fOptions.DBEngine := TDatabaseEngine.deFireDAC;
end;

function TDBContextOptionsBuilder.UseRestServer: IDBContextOptionsBuilder;
begin
  Result := Self;
  fOptions.DBProvider := TDBProvider.dbSQLite;
  fOptions.DBEngine := TDatabaseEngine.deRestServer;
end;

{ TDBConnnectionOptions }

function TDBConnectionOptions.GetDBEngine: TDatabaseEngine;
begin
  Result := fDBEngine;
end;

procedure TDBConnectionOptions.UseMSAccess;
begin
  Provider := TDBProvider.dbMSAccess2007;
  fDBEngine := TDatabaseEngine.deFireDAC;
end;

procedure TDBConnectionOptions.UseMSSQL;
begin
  Provider := TDBProvider.dbMSSQL;
  fDBEngine := TDatabaseEngine.deADO;
end;

procedure TDBConnectionOptions.UseMySQL;
begin
  Provider := TDBProvider.dbMySQL;
  fDBEngine := TDatabaseEngine.deADO;
end;

procedure TDBConnectionOptions.UseRestServer;
begin
  Provider := TDBProvider.dbSQLite;
  fDBEngine := TDatabaseEngine.deRestServer;
end;

procedure TDBConnectionOptions.UseSQLite;
begin
  Provider := TDBProvider.dbSQLite;
  fDBEngine := TDatabaseEngine.deFireDAC;
end;

end.
