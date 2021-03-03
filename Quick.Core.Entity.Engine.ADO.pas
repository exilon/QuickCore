{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Entity.Engine.ADO
  Description : Core Entity ADO Provider
  Author      : Kike Pérez
  Version     : 1.1
  Created     : 22/11/2019
  Modified    : 09/06/2020

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

unit Quick.Core.Entity.Engine.ADO;

{$i QuickCore.inc}

interface

uses
  Classes,
  SysUtils,
  {$IFDEF MSWINDOWS}
  Data.Win.ADODB,
  Winapi.ActiveX,
  {$ELSE}
  only Delphi/Firemonkey Windows compatible
  {$ENDIF}
  Quick.Commons,
  Quick.Core.Entity.DAO,
  Quick.Core.Entity.Database,
  Quick.Core.Entity.Query;

const

   db_MSAccess2000 = Cardinal(TDBProvider.dbMSAccess2000);
   db_MSAccess2007 = Cardinal(TDBProvider.dbMSAccess2007);
   db_MSSQL        = Cardinal(TDBProvider.dbMSSQL);
   db_MSSQLnc10    = Cardinal(TDBProvider.dbMSSQL) + 1;
   db_MSSQLnc11    = Cardinal(TDBProvider.dbMSSQL) + 2;
   db_IBM400       = Cardinal(TDBProvider.dbIBM400);

type

  TADOEntityDataBase = class(TEntityDatabase)
  private
    fADOConnection : TADOConnection;
    fInternalQuery : TADOQuery;
    function GetDBProviderName(aDBProvider: TDBProvider): string;
  protected
    function CreateConnectionString: string; override;
    procedure DoOpenSQLQuery(const aQueryText: string); override;
    procedure DoExecuteSQLQuery(const aQueryText: string); override;
    function ExistsTable(aModel : TEntityModel) : Boolean; override;
    function ExistsColumn(aModel: TEntityModel; const aFieldName: string): Boolean; override;
  public
    constructor Create; override;
    constructor CreateFromConnection(aConnection: TADOConnection; aOwnsConnection : Boolean);
    destructor Destroy; override;
    function CreateQuery(aModel : TEntityModel) : IEntityQuery<TEntity>; override;
    function Connect : Boolean; override;
    procedure Disconnect; override;
    function GetTableNames : TArray<string>; override;
    function GetFieldNames(const aTableName : string) : TArray<string>; override;
    function IsConnected : Boolean; override;
    function From<T : class, constructor> : IEntityLinqQuery<T>;
    function Clone : TEntityDatabase; override;
  end;

  TADOEntityQuery<T : class, constructor> = class(TEntityQuery<T>)
  private
    fConnection : TDBConnectionSettings;
    fQuery : TADOQuery;
  protected
    function GetCurrent : T; override;
    function MoveNext : Boolean; override;
    function GetFieldValue(const aName : string) : Variant; override;
    function OpenQuery(const aQuery : string) : Integer; override;
    function ExecuteQuery(const aQuery : string) : Boolean; override;
  public
    constructor Create(aEntityDataBase : TEntityDatabase; aModel : TEntityModel; aQueryGenerator : IEntityQueryGenerator); override;
    destructor Destroy; override;
    function CountResults : Integer; override;
    function Eof : Boolean; override;
  end;

implementation


{ TADOEntityDataBase }

constructor TADOEntityDataBase.Create;
begin
  inherited;
  CoInitialize(nil);
  fADOConnection := TADOConnection.Create(nil);
  fInternalQuery := TADOQuery.Create(nil);
end;

constructor TADOEntityDataBase.CreateFromConnection(aConnection: TADOConnection; aOwnsConnection: Boolean);
begin
  Create;
  if OwnsConnection then fADOConnection.Free;
  OwnsConnection := aOwnsConnection;
  fADOConnection := aConnection;
end;

destructor TADOEntityDataBase.Destroy;
begin
  if Assigned(fInternalQuery) then fInternalQuery.Free;
  if fADOConnection.Connected then fADOConnection.Connected := False;
  if OwnsConnection then fADOConnection.Free;
  CoUninitialize;
  inherited;
end;

function TADOEntityDataBase.Clone: TEntityDatabase;
begin
  Result := TADOEntityDataBase.CreateFromConnection(fADOConnection,False);
  Result.Connection.Free;
  Result.Connection := Connection.Clone;
end;

function TADOEntityDataBase.Connect: Boolean;
begin
  //creates connection string based on parameters of connection property
  inherited;
  fADOConnection.ConnectionString := CreateConnectionString;
  fADOConnection.Connected := True;
  fInternalQuery.Connection := fADOConnection;
  Result := IsConnected;
  CreateTables;
  CreateIndexes;
end;

function TADOEntityDataBase.CreateConnectionString: string;
var
  dbconn : string;
begin
  if Connection.IsCustomConnectionString then Result := Format('Provider=%s;%s',[GetDBProviderName(Connection.Provider),Connection.GetCustomConnectionString])
  else
  begin
    if (Connection.Server.IsEmpty) or
       (Connection.Database.IsEmpty) or
       (Connection.UserName.IsEmpty) then raise EEntityConnectionError.Create('Entity ConnectionString missing info!');


    if Connection.Server = '' then dbconn := 'Data Source=' + Connection.Database
      else dbconn := Format('Database=%s;Data Source=%s',[Connection.Database,Connection.Server]);

    Result := Format('Provider=%s;Persist Security Info=False;User ID=%s;Password=%s;%s',[
                              GetDBProviderName(Connection.Provider),
                              Connection.UserName,
                              Connection.Password,
                              dbconn]);
  end;
end;

function TADOEntityDataBase.CreateQuery(aModel : TEntityModel) : IEntityQuery<TEntity>;
begin
  Result := TADOEntityQuery<TEntity>.Create(Self,aModel,QueryGenerator);
end;

function TADOEntityDataBase.GetDBProviderName(aDBProvider: TDBProvider): string;
begin
  case aDBProvider of
    TDBProvider.dbMSAccess2000 : Result := 'Microsoft.Jet.OLEDB.4.0';
    TDBProvider.dbMSAccess2007 : Result := 'Microsoft.ACE.OLEDB.12.0';
    TDBProvider.dbMSSQL : Result := 'SQLOLEDB.1';
    TDBProvider.dbMSSQLnc10 : Result := 'SQLNCLI10';
    TDBProvider.dbMSSQLnc11 : Result := 'SQLNCLI11';
    TDBProvider.dbIBM400 : Result := 'IBMDA4000';
    else raise Exception.Create('Unknow DBProvider or not supported by this engine');
  end;
end;

function TADOEntityDataBase.GetFieldNames(const aTableName: string): TArray<string>;
var
  sl : TStrings;
begin
  sl := TStringList.Create;
  try
    fInternalQuery.Connection.GetFieldNames(aTableName,sl);
    Result := StringsToArray(sl);
  finally
    sl.Free;
  end;
end;

function TADOEntityDataBase.GetTableNames: TArray<string>;
var
  sl : TStrings;
begin
  sl := TStringList.Create;
  try
    fInternalQuery.Connection.GetTableNames(sl);
    Result := StringsToArray(sl);
  finally
    sl.Free;
  end;
end;

procedure TADOEntityDataBase.Disconnect;
begin
  inherited;
  fADOConnection.Connected := False;
end;

function TADOEntityDataBase.IsConnected: Boolean;
begin
  Result := fADOConnection.Connected;
end;

procedure TADOEntityDataBase.DoOpenSQLQuery(const aQueryText: string);
begin
  fInternalQuery.SQL.Text := aQueryText;
  fInternalQuery.Open;
end;

procedure TADOEntityDataBase.DoExecuteSQLQuery(const aQueryText: string);
begin
  fInternalQuery.SQL.Text := aQueryText;
  fInternalQuery.ExecSQL;
end;

function TADOEntityDataBase.ExistsColumn(aModel: TEntityModel; const aFieldName: string): Boolean;
var
  field : string;
begin
  Result := False;
  if (Connection.Provider = TDBProvider.dbMSAccess2000) or (Connection.Provider = TDBProvider.dbMSAccess2007)  then
  begin
    if (Connection.Provider = TDBProvider.dbMSAccess2000) or (Connection.Provider = TDBProvider.dbMSAccess2007)  then
    begin
      for field in GetFieldNames(aModel.TableName) do
      begin
        if CompareText(field,aFieldName) = 0 then Exit(True);
      end;
    end;
  end
  else
  begin
    DoOpenSQLQuery(QueryGenerator.ExistsColumn(aModel,aFieldName));
    while not fInternalQuery.Eof do
    begin
      if CompareText(fInternalQuery.FieldByName('name').AsString,aFieldName) = 0 then
      begin
        Result := True;
        Break;
      end;
      fInternalQuery.Next;
    end;
    fInternalQuery.SQL.Clear;
  end;
end;

function TADOEntityDataBase.ExistsTable(aModel: TEntityModel): Boolean;
var
  table : string;
begin
  Result := False;
  if (Connection.Provider = TDBProvider.dbMSAccess2000) or (Connection.Provider = TDBProvider.dbMSAccess2007)  then
  begin
    for table in GetTableNames do
    begin
      if CompareText(table,aModel.TableName) = 0 then Exit(True);
    end;
  end
  else
  begin
    DoOpenSQLQuery(QueryGenerator.ExistsTable(aModel));
    while not fInternalQuery.Eof do
    begin
      if CompareText(fInternalQuery.FieldByName('name').AsString,aModel.TableName) = 0 then
      begin
        Result := True;
        Break;
      end;
      fInternalQuery.Next;
    end;
    fInternalQuery.SQL.Clear;
  end;
end;

function TADOEntityDataBase.From<T>: IEntityLinqQuery<T>;
var
  entityClass : TEntityClass;
begin
  entityClass := TEntityClass(Pointer(T));
  Result := TADOEntityQuery<T>.Create(Self,Models.Get(entityClass),QueryGenerator);
end;

{ TADOEntityQuery<T> }

constructor TADOEntityQuery<T>.Create(aEntityDataBase : TEntityDatabase; aModel : TEntityModel; aQueryGenerator : IEntityQueryGenerator);
begin
  inherited;
  fQuery := TADOQuery.Create(nil);
  fQuery.Connection := TADOEntityDataBase(aEntityDataBase).fADOConnection;
  fConnection := aEntityDataBase.Connection;
end;

destructor TADOEntityQuery<T>.Destroy;
begin
  if Assigned(fQuery) then fQuery.Free;
  inherited;
end;

function TADOEntityQuery<T>.Eof: Boolean;
begin
  Result := fQuery.Eof;
end;

function TADOEntityQuery<T>.OpenQuery(const aQuery: string): Integer;
begin
  fFirstIteration := True;
  fQuery.Close;
  fQuery.SQL.Text := aQuery;
  fQuery.Open;
  fHasResults := fQuery.RecordCount > 0;
  Result := fQuery.RecordCount;
end;

function TADOEntityQuery<T>.ExecuteQuery(const aQuery: string): Boolean;
begin
  fQuery.SQL.Text := aQuery;
  fQuery.ExecSQL;
  fHasResults := False;
  Result := fQuery.RowsAffected > 0;
end;

function TADOEntityQuery<T>.GetFieldValue(const aName: string): Variant;
begin
  Result := fQuery.FieldByName(aName).AsVariant;
end;

function TADOEntityQuery<T>.CountResults: Integer;
begin
  Result := fQuery.RecordCount;
end;

function TADOEntityQuery<T>.GetCurrent: T;
begin
  if fQuery.Eof then Exit(nil);
  Result := fModel.NewEntity<T>;// fModel.Table.Create as T;
  Self.FillRecordFromDB(Result);
end;

function TADOEntityQuery<T>.MoveNext: Boolean;
begin
  if not fFirstIteration then fQuery.Next;
  fFirstIteration := False;
  Result := not fQuery.Eof;
end;

initialization
  if (IsConsole) or (IsService) then CoInitialize(nil);

finalization
  if (IsConsole) or (IsService) then CoUninitialize;



end.
