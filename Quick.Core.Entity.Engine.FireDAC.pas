{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Entity.Engine.FireDAC
  Description : Core Entity FireDAC Provider
  Author      : Kike Pérez
  Version     : 1.1
  Created     : 15/07/2020
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

 unit Quick.Core.Entity.Engine.FireDAC;

{$i QuickCore.inc}

interface

uses
  Classes,
  System.SysUtils,
  {$IFDEF DEBUG_ENTITY}
    Quick.Debug.Utils,
  {$ENDIF}
  //Winapi.ActiveX,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.DApt,
  FireDAC.Phys,
  FireDAC.Phys.Intf,
  FireDAC.Phys.SQLite,
  {$IFDEF MSWINDOWS}
  FireDAC.Phys.MSAcc,
  {$ENDIF}
  //FireDAC.Phys.MSSQL,
  {$IFDEF CONSOLE}
    FireDAC.ConsoleUI.Wait,
  {$ELSE}
    FireDAC.UI.Intf,
    {$IFDEF VCL}
    FireDAC.VCLUI.Wait,
    {$ELSE}
    FireDAC.FMXUI.Wait,
    {$ENDIF}
    FireDAC.Comp.UI,
  {$ENDIF}
  {$IFDEF DELPHIRX104_UP}
  FireDAC.Phys.SQLiteWrapper.Stat,
  {$ENDIF}
  Quick.Commons,
  Quick.Core.Entity.DAO,
  Quick.Core.Entity.Database,
  Quick.Core.Entity.Query;

type

  TFireDACEntityDataBase = class(TEntityDatabase)
  private
    fFireDACConnection : TFDConnection;
    fInternalQuery : TFDQuery;
    function GetDriverID(aDBProvider : TDBProvider) : string;
  protected
    function CreateConnectionString: string; override;
    procedure DoExecuteSQLQuery(const aQueryText : string); override;
    procedure DoOpenSQLQuery(const aQueryText: string); override;
    function ExistsTable(aModel : TEntityModel) : Boolean; override;
    function ExistsColumn(aModel: TEntityModel; const aFieldName: string): Boolean; override;
  public
    constructor Create; override;
    constructor CreateFromConnection(aConnection: TFDConnection; aOwnsConnection : Boolean);
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

  TFireDACEntityQuery<T : class, constructor> = class(TEntityQuery<T>)
  private
    fConnection : TDBConnectionSettings;
    fQuery : TFDQuery;
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

{$IFNDEF CONSOLE}
var
  FDGUIxWaitCursor : TFDGUIxWaitCursor;
{$ENDIF}

implementation

{ TFireDACEntityDataBase }

constructor TFireDACEntityDataBase.Create;
begin
  inherited;
  fFireDACConnection := TFDConnection.Create(nil);
  fInternalQuery := TFDQuery.Create(nil);
end;

constructor TFireDACEntityDataBase.CreateFromConnection(aConnection: TFDConnection; aOwnsConnection : Boolean);
begin
  Create;
  if OwnsConnection then fFireDACConnection.Free;
  OwnsConnection := aOwnsConnection;
  fFireDACConnection := aConnection;
end;

destructor TFireDACEntityDataBase.Destroy;
begin
  if Assigned(fInternalQuery) then fInternalQuery.Free;
  if fFireDACConnection.Connected then fFireDACConnection.Connected := False;
  if OwnsConnection then fFireDACConnection.Free;
  inherited;
end;

function TFireDACEntityDataBase.Clone: TEntityDatabase;
begin
  Result := TFireDACEntityDataBase.CreateFromConnection(fFireDACConnection,False);
  Result.Connection.Free;
  Result.Connection := Connection.Clone;
end;

function TFireDACEntityDataBase.Connect: Boolean;
begin
  //creates connection string based on parameters of connection property
  inherited;
  fFireDACConnection.ConnectionString := CreateConnectionString;
  fFireDACConnection.Connected := True;
  fInternalQuery.Connection := fFireDACConnection;
  Result := IsConnected;
  CreateTables;
  CreateIndexes;
end;

function TFireDACEntityDataBase.CreateConnectionString: string;
begin
  if Connection.IsCustomConnectionString then Result := Format('DriverID=%s;%s',[GetDriverID(Connection.Provider),Connection.GetCustomConnectionString])
  else
  begin
    Result := Format('DriverID=%s;User_Name=%s;Password=%s;Database=%s;Server=%s',[
                              GetDriverID(Connection.Provider),
                              Connection.UserName,
                              Connection.Password,
                              Connection.Database,
                              Connection.Server]);
  end;
end;

function TFireDACEntityDataBase.CreateQuery(aModel: TEntityModel): IEntityQuery<TEntity>;
begin
  Result := TFireDACEntityQuery<TEntity>.Create(Self,aModel,QueryGenerator);
end;

procedure TFireDACEntityDataBase.Disconnect;
begin
  inherited;
  fFireDACConnection.Connected := False;
end;

procedure TFireDACEntityDataBase.DoExecuteSQLQuery(const aQueryText: string);
begin
  fInternalQuery.SQL.Text := aQueryText;
  fInternalQuery.ExecSQL;
end;

procedure TFireDACEntityDataBase.DoOpenSQLQuery(const aQueryText: string);
begin
  fInternalQuery.SQL.Text := aQueryText;
  fInternalQuery.Open;
end;

function TFireDACEntityDataBase.ExistsColumn(aModel: TEntityModel; const aFieldName: string): Boolean;
begin
  Result := False;
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

function TFireDACEntityDataBase.ExistsTable(aModel: TEntityModel): Boolean;
begin
  Result := False;
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

function TFireDACEntityDataBase.From<T>: IEntityLinqQuery<T>;
var
  Entityclass : TEntityClass;
begin
  Entityclass := TEntityClass(Pointer(T));
  Result := TFireDACEntityQuery<T>.Create(Self,Models.Get(Entityclass),QueryGenerator);
end;

function TFireDACEntityDataBase.GetDriverID(aDBProvider: TDBProvider): string;
begin
  case aDBProvider of
    TDBProvider.dbMSAccess2007 : Result := 'MSAcc';
    TDBProvider.dbMSSQL : Result := 'MSSQL';
    TDBProvider.dbMySQL : Result := 'MySQL';
    TDBProvider.dbSQLite : Result := 'SQLite';
    else raise Exception.Create('Unknow DBProvider or not supported by this engine');
  end;
end;

function TFireDACEntityDataBase.GetFieldNames(const aTableName: string): TArray<string>;
var
  sl : TStrings;
begin
  sl := TStringList.Create;
  try
    fInternalQuery.Connection.GetFieldNames('','',aTableName,'',sl);
    Result := StringsToArray(sl);
  finally
    sl.Free;
  end;
end;

function TFireDACEntityDataBase.GetTableNames: TArray<string>;
var
  sl : TStrings;
begin
  sl := TStringList.Create;
  try
    fInternalQuery.Connection.GetTableNames(Connection.Database,'dbo','',sl,[osMy],[tkTable],True);
    Result := StringsToArray(sl);
  finally
    sl.Free;
  end;
end;

function TFireDACEntityDataBase.IsConnected: Boolean;
begin
  Result := fFireDACConnection.Connected;
end;

{ TFireDACEntityQuery<T> }

function TFireDACEntityQuery<T>.CountResults: Integer;
begin
  Result := fQuery.RecordCount;
end;

constructor TFireDACEntityQuery<T>.Create(aEntityDataBase : TEntityDatabase; aModel : TEntityModel; aQueryGenerator : IEntityQueryGenerator);
begin
  inherited;
  fQuery := TFDQuery.Create(nil);
  fQuery.Connection := TFireDACEntityDataBase(aEntityDataBase).fFireDACConnection;
  fConnection := aEntityDataBase.Connection;
end;

destructor TFireDACEntityQuery<T>.Destroy;
begin
  if Assigned(fQuery) then fQuery.Free;
  inherited;
end;

function TFireDACEntityQuery<T>.Eof: Boolean;
begin
  Result := fQuery.Eof;
end;

function TFireDACEntityQuery<T>.OpenQuery(const aQuery : string) : Integer;
begin
  fFirstIteration := True;
  fQuery.Close;
  fQuery.SQL.Text := aQuery;
  fQuery.Open;
  fHasResults := fQuery.RecordCount > 0;
  Result := fQuery.RecordCount;
end;

function TFireDACEntityQuery<T>.ExecuteQuery(const aQuery : string) : Boolean;
begin
  fQuery.SQL.Text := aQuery;
  fQuery.ExecSQL;
  fHasResults := False;
  Result := fQuery.RowsAffected > 0;
end;

function TFireDACEntityQuery<T>.GetFieldValue(const aName: string): Variant;
begin
  Result := fQuery.FieldByName(aName).AsVariant;
end;

function TFireDACEntityQuery<T>.GetCurrent: T;
begin
  if fQuery.Eof then Exit(nil);
  Result := fModel.NewEntity<T>; // TRTTI.CreateInstance(fModel.Table) as T;// fModel.Table.Create as T;
  Self.FillRecordFromDB(Result);
end;

function TFireDACEntityQuery<T>.MoveNext: Boolean;
begin
  if not fFirstIteration then fQuery.Next;
  fFirstIteration := False;
  Result := not fQuery.Eof;
end;

initialization
  //if (IsConsole) or (IsService) then CoInitialize(nil);
  {$IFNDEF CONSOLE}
  FDGUIxWaitCursor := TFDGUIxWaitCursor.Create(nil);
  {$ENDIF}

finalization
  //if (IsConsole) or (IsService) then CoUninitialize;
  {$IFNDEF CONSOLE}
  FDGUIxWaitCursor.Free;
  {$ENDIF}

end.
