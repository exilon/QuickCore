{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Entity.Engine.RestServer
  Description : Core Entity RestServer Provider
  Author      : Kike Pérez
  Version     : 1.1
  Created     : 31/11/2019
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

 unit Quick.Core.Entity.Engine.RestServer;

{$i QuickCore.inc}

interface

uses
  {$IFDEF DEBUG_ENTITY}
  Quick.Debug.Utils,
  {$ENDIF}
  Classes,
  System.SysUtils,
  System.Net.HttpClient,
  System.Generics.Collections,
  Quick.Commons,
  Quick.RTTI.Utils,
  Quick.Json.Serializer,
  Quick.Core.Entity.DAO,
  Quick.Core.Entity.Database,
  Quick.Core.Entity.Query,
  Quick.Core.Entity.Request;

type

  TRestServerConnection = class
  private
    fHttpClient : THTTPClient;
    fConnected : Boolean;
    fHost : string;
    fUser : string;
    fPassword : string;
    fSessionId : string;
    procedure SetConnected(const Value: Boolean);
  public
    constructor Create;
    destructor Destroy; override;
    property Host : string read fHost write fHost;
    property User : string read fUser write fUser;
    property Password : string read fPassword write fPassword;
    property Connected : Boolean read fConnected write SetConnected;
    function GetTableNames : TArray<string>;
    function GetFieldNames(const aTableName : string) : TArray<string>;
  end;

  TRestServerQuery<T : class, constructor> = class
  private
    fHttpClient : THTTPClient;
    fConnection : TRestServerConnection;
    fModel : TEntityModel;
    fResults : TList<T>;
    fSerializer : TJsonSerializer;
    function RequestActionToStr(aRequestAction : TEntityRequestAction) : string;
  public
    constructor Create;
    destructor Destroy; override;
    property Connection : TRestServerConnection read fConnection write fConnection;
    property Model : TEntityModel read fModel write fModel;
    property Results : TList<T> read fResults write fResults;
    function ConnectRequest(aRequest : TEntityConnectRequest; out vResult : string) : Boolean;
    function SendRequest(aRequest: TEntityRequest): Boolean; overload;
    function SendRequest(aAction : TEntityRequestAction; aValue : TEntity) : Boolean; overload;
    function SendRequest(aRequest: TEntityRequest; out vResult : string): Boolean; overload;
  end;

  TRestServerEntityDataBase = class(TEntityDatabase)
  private
    fRestServerConnection : TRestServerConnection;
    fInternalQuery : TRestServerQuery<TEntity>;
    fDBProvider : TDBProvider;
    function GetDriverID(aDBProvider : TDBProvider) : string;
    function DoConnect(const aUser, aPassword : string): Boolean;
  protected
    function CreateConnectionString: string; override;
    procedure DoExecuteSQLQuery(const aQueryText : string); override;
    procedure DoOpenSQLQuery(const aQueryText: string); override;
    function ExistsTable(aModel : TEntityModel) : Boolean; override;
    function ExistsColumn(aModel: TEntityModel; const aFieldName: string): Boolean; override;
  public
    constructor Create; override;
    constructor CreateFromConnection(aConnection: TRestServerConnection; aOwnsConnection : Boolean);
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

  TRestServerEntityQuery<T : class, constructor> = class(TEntityQuery<T>)
  private
    fConnection : TDBConnectionSettings;
    fQuery : TRestServerQuery<T>;
    fCurrentIndex : Integer;
  protected
    function GetCurrent : T; override;
    function MoveNext : Boolean; override;
    function GetFieldValue(const aName : string) : Variant; override;
    function OpenQuery(const aQuery : string) : Integer; override;
    function ExecuteQuery(const aQuery : string) : Boolean; override;
    function FillRecordFromDB(aEntity : T) : T; override;
  public
    constructor Create(aEntityDataBase : TEntityDatabase; aModel : TEntityModel; aQueryGenerator : IEntityQueryGenerator); override;
    destructor Destroy; override;
    function CountResults : Integer; override;
    function Eof : Boolean; override;
    function AddOrUpdate(aEntity : TEntity) : Boolean; override;
    function Add(aEntity : TEntity) : Boolean; override;
    function Update(aEntity : TEntity) : Boolean; overload; override;
    function Delete(aEntity : TEntity) : Boolean; overload; override;
    function Delete(const aWhere : string) : Boolean; overload; override;
    //LINQ queries
    function SelectFirst : T; override;
    function SelectLast : T; override;
    function Select : IEntityResult<T>; overload; override;
    function Select(const aFieldNames : string) : IEntityResult<T>; overload; override;
    function SelectTop(aNumber : Integer) : IEntityResult<T>; override;
    function Sum(const aFieldName : string) : Int64; override;
    function Count : Int64; override;
    function Update(const aFieldNames : string; const aFieldValues : array of const) : Boolean; overload; override;
    function Delete : Boolean; overload; override;
  end;

implementation

{ TRestServerEntityDataBase }

constructor TRestServerEntityDataBase.Create;
begin
  inherited;
  fRestServerConnection := TRestServerConnection.Create;
  fInternalQuery := TRestServerQuery<TEntity>.Create;
end;

constructor TRestServerEntityDataBase.CreateFromConnection(aConnection: TRestServerConnection; aOwnsConnection : Boolean);
begin
  Create;
  if OwnsConnection then fRestServerConnection.Free;
  OwnsConnection := aOwnsConnection;
  fRestServerConnection := aConnection;
end;

destructor TRestServerEntityDataBase.Destroy;
begin
  if Assigned(fInternalQuery) then fInternalQuery.Free;
  if fRestServerConnection.Connected then fRestServerConnection.Connected := False;
  if OwnsConnection then fRestServerConnection.Free;
  inherited;
end;

function TRestServerEntityDataBase.Clone: TEntityDatabase;
begin
  Result := TRestServerEntityDataBase.CreateFromConnection(fRestServerConnection,False);
  Result.Connection.Free;
  Result.Connection := Connection.Clone;
end;

function TRestServerEntityDataBase.Connect: Boolean;
begin
  //creates connection string based on parameters of connection property
  {$IFDEF DEBUG_ENTITY}
    TDebugger.TimeIt(Self,'Connect','');
  {$ENDIF}
  Result := False;
  CreateConnectionString;
  fRestServerConnection.Host := Connection.Server;
  fRestServerConnection.User := Connection.UserName;
  fRestServerConnection.Password := Connection.Password;
  fInternalQuery.Connection := fRestServerConnection;
  try
    fRestServerConnection.Connected := DoConnect(Connection.UserName,Connection.Password);
  except
    on E : Exception do raise EEntityConnectionError.CreateFmt('Entity connection error: %s',[e.Message]);
  end;
  inherited;
  Result := IsConnected;
  //CreateTables;
  //CreateIndexes;
end;

function TRestServerEntityDataBase.CreateConnectionString: string;
var
  cs : string;
begin
  if Connection.IsCustomConnectionString then
  begin
    cs := Connection.GetCustomConnectionString;
    Connection.Server := GetSubString(cs,'Server=',';');
    Connection.UserName := GetSubString(cs,'UserName=',';');
    Connection.Password := GetSubString(cs,'Password=',';');
  end;
end;

function TRestServerEntityDataBase.CreateQuery(aModel: TEntityModel): IEntityQuery<TEntity>;
begin
  Result := TRestServerEntityQuery<TEntity>.Create(Self,aModel,QueryGenerator);
end;

procedure TRestServerEntityDataBase.Disconnect;
begin
  inherited;
  fRestServerConnection.Connected := False;
end;

function TRestServerEntityDataBase.DoConnect(const aUser, aPassword : string): Boolean;
var
  request : TEntityConnectRequest;
  response : string;
begin
  Result := False;
  request := TEntityConnectRequest.Create;
  try
    request.User := aUser;
    request.Password := aPassword;
    Result := fInternalQuery.ConnectRequest(request,response);
    if Result then
    begin
      fDBProvider := TDBProvider(response.ToInteger);
      Connection.Provider := fDBProvider;
    end;
  finally
    request.Free;
  end;
end;

procedure TRestServerEntityDataBase.DoExecuteSQLQuery(const aQueryText: string);
begin
  //Not needed: Theses operations were made on server part
  //fInternalQuery.SQL.Text := aQueryText;
  //fInternalQuery.ExecSQL;
end;

procedure TRestServerEntityDataBase.DoOpenSQLQuery(const aQueryText: string);
begin
  //Not needed: Theses operations were made on server part
  //fInternalQuery.SQL.Text := aQueryText;
  //fInternalQuery.Open;
end;

function TRestServerEntityDataBase.ExistsColumn(aModel: TEntityModel; const aFieldName: string): Boolean;
begin
  //Not needed: Theses operations were made on server part
end;

function TRestServerEntityDataBase.ExistsTable(aModel: TEntityModel): Boolean;
begin
  //Not needed: Theses operations were made on server part
end;

function TRestServerEntityDataBase.From<T>: IEntityLinqQuery<T>;
var
  Entityclass : TEntityClass;
begin
  Entityclass := TEntityClass(Pointer(T));
  Result := TRestServerEntityQuery<T>.Create(Self,Models.Get(Entityclass),QueryGenerator);
end;

function TRestServerEntityDataBase.GetDriverID(aDBProvider: TDBProvider): string;
begin
  case aDBProvider of
    TDBProvider.dbMSAccess2007 : Result := 'MSAcc';
    TDBProvider.dbMSSQL : Result := 'MSSQL';
    TDBProvider.dbMySQL : Result := 'MySQL';
    TDBProvider.dbSQLite : Result := 'SQLite';
    else raise EEntityProviderError.Create('Unknow DBProvider or not supported by this engine');
  end;
end;

function TRestServerEntityDataBase.GetFieldNames(const aTableName: string): TArray<string>;
begin
  Result := fInternalQuery.Connection.GetFieldNames(aTableName);
end;

function TRestServerEntityDataBase.GetTableNames: TArray<string>;
begin
  Result := fInternalQuery.Connection.GetTableNames;
end;

function TRestServerEntityDataBase.IsConnected: Boolean;
begin
  Result := fRestServerConnection.Connected;
end;

{ TRestServerEntityQuery<T> }

constructor TRestServerEntityQuery<T>.Create(aEntityDataBase : TEntityDatabase; aModel : TEntityModel; aQueryGenerator : IEntityQueryGenerator);
begin
  inherited;
  fQuery := TRestServerQuery<T>.Create;
  fQuery.Model := aModel;
  fQuery.Connection := TRestServerEntityDataBase(aEntityDataBase).fRestServerConnection;
  fConnection := aEntityDataBase.Connection;
end;

destructor TRestServerEntityQuery<T>.Destroy;
begin
  if Assigned(fQuery) then fQuery.Free;
  inherited;
end;

function TRestServerEntityQuery<T>.OpenQuery(const aQuery : string) : Integer;
begin
  fFirstIteration := True;
  raise ENotImplemented.Create('OpenQuery');
//  fQuery.Close;
//  fQuery.SQL.Text := aQuery;
//  fQuery.Open;
//  fHasResults := fQuery.RecordCount > 0;
//  Result := fQuery.RecordCount;
end;

function TRestServerEntityQuery<T>.ExecuteQuery(const aQuery : string) : Boolean;
begin
  raise ENotImplemented.Create('ExecuteQuery');
//  fQuery.SQL.Text := aQuery;
//  fQuery.ExecSQL;
//  fHasResults := False;
//  Result := fQuery.RowsAffected > 0;
end;

function TRestServerEntityQuery<T>.FillRecordFromDB(aEntity: T) : T;
var
  field : TDBField;
begin
  aEntity.Free;
  Result := fQuery.Results[fCurrentIndex];
end;

function TRestServerEntityQuery<T>.GetFieldValue(const aName: string): Variant;
begin
  //raise ENotImplemented.Create('GetFieldValue');
  Result := TRtti.GetPropertyValue(GetCurrent,aName).AsVariant;
  //Result := fQuery.FieldByName(aName).AsVariant;
  //Result := TRTTI.GetPropertyValue(fQuery.Results[0],aName).AsVariant;
end;

function TRestServerEntityQuery<T>.GetCurrent: T;
begin
  if Self.Eof then Exit(nil);
  Result := fQuery.Results[fCurrentIndex];
  fQuery.Results[fCurrentIndex] := nil;
end;

function TRestServerEntityQuery<T>.MoveNext: Boolean;
begin
  if not fFirstIteration then Inc(fCurrentIndex);
  fFirstIteration := False;
  Result := not Self.Eof;
end;

function TRestServerEntityQuery<T>.Add(aEntity: TEntity): Boolean;
begin
  Result := fQuery.SendRequest(TEntityRequestAction.raAdd,aEntity);
end;

function TRestServerEntityQuery<T>.AddOrUpdate(aEntity: TEntity): Boolean;
begin
  Result := fQuery.SendRequest(TEntityRequestAction.raAddOrUpdate,aEntity);
end;

function TRestServerEntityQuery<T>.Count: Int64;
var
  request : TEntityCountRequest;
  response : string;
begin
  request := TEntityCountRequest.Create;
  try
    request.Table := fModel.TableName;
    request.Action := TEntityRequestAction.raCount;
    request.WhereClause := fWhereClause;
    if fQuery.SendRequest(request,response) then Result := response.ToInt64;
  finally
    request.Free;
  end;
end;

function TRestServerEntityQuery<T>.CountResults: Integer;
begin
  Result := fQuery.Results.Count;
end;

function TRestServerEntityQuery<T>.Delete(aEntity: TEntity): Boolean;
begin
  raise ENotImplemented.Create('not implemented yet!');
end;

function TRestServerEntityQuery<T>.Delete: Boolean;
var
  request : TEntityDeleteRequest;
begin
  request := TEntityDeleteRequest.Create;
  try
    request.Table := fModel.TableName;
    request.Action := TEntityRequestAction.raDelete;
    request.WhereClause := fWhereClause;
    Result := fQuery.SendRequest(request);
  finally
    request.Free;
  end;
end;

function TRestServerEntityQuery<T>.Delete(const aWhere: string): Boolean;
var
  request : TEntityDeleteRequest;
begin
  request := TEntityDeleteRequest.Create;
  try
    request.Table := fModel.TableName;
    request.Action := TEntityRequestAction.raDelete;
    request.WhereClause := aWhere;
    Result := fQuery.SendRequest(request);
  finally
    request.Free;
  end;
end;

function TRestServerEntityQuery<T>.Eof: Boolean;
begin
  if fQuery.Results = nil then Exit(True);
  Result := (fQuery.Results.Count = 0) or ((fCurrentIndex + 1) > fQuery.Results.Count);
end;

function TRestServerEntityQuery<T>.Select(const aFieldNames: string): IEntityResult<T>;
var
  request : TEntitySelectRequest;
begin
  request := TEntitySelectRequest.Create;
  try
    request.Table := fModel.TableName;
    request.Action := TEntityRequestAction.raSelect;
    request.Fields := aFieldNames;
    request.Limit := 0;
    request.WhereClause := fWhereClause;
    request.Order := fOrderClause;
    request.OrderAsc := fOrderAsc;
    if fQuery.SendRequest(request) then Result := TEntityResult<T>.Create(Self);
  finally
    request.Free;
  end;
end;

function TRestServerEntityQuery<T>.Select: IEntityResult<T>;
var
  request : TEntitySelectRequest;
begin
  try
    request := TEntitySelectRequest.Create;
    try
      request.Table := fModel.TableName;
      request.Action := TEntityRequestAction.raSelect;
      request.Fields := '';
      request.Limit := 0;
      request.WhereClause := fWhereClause;
      request.Order := fOrderClause;
      request.OrderAsc := fOrderAsc;
      if fQuery.SendRequest(request) then Result := TEntityResult<T>.Create(Self);
    finally
      request.Free;
    end;
  except
    on E : Exception do raise EEntitySelectError.Create(e.message);
  end;
end;

function TRestServerEntityQuery<T>.SelectFirst: T;
var
  request : TEntitySelectRequest;
begin
  Result := nil;
  request := TEntitySelectRequest.Create;
  try
    request.Table := fModel.TableName;
    request.Action := TEntityRequestAction.raSelect;
    request.Fields := '*';
    request.Limit := 1;
    request.WhereClause := fWhereClause;
    request.Order := fOrderClause;
    request.OrderAsc := fOrderAsc;
    if fQuery.SendRequest(request) then
    begin
      Self.Movenext;
      Result := Self.GetCurrent;
    end;
  finally
    request.Free;
  end;
end;

function TRestServerEntityQuery<T>.SelectLast: T;
var
  request : TEntitySelectRequest;
begin
  Result := nil;
  request := TEntitySelectRequest.Create;
  try
    request.Table := fModel.TableName;
    request.Action := TEntityRequestAction.raSelect;
    request.Fields := '*';
    request.Limit := -1;
    request.WhereClause := fWhereClause;
    request.Order := fOrderClause;
    request.OrderAsc := not fOrderAsc;
    if fQuery.SendRequest(request) then
    begin
      Self.Movenext;
      Result := Self.GetCurrent;
    end;
  finally
    request.Free;
  end;
end;

function TRestServerEntityQuery<T>.SelectTop(aNumber: Integer): IEntityResult<T>;
var
  request : TEntitySelectRequest;
begin
  request := TEntitySelectRequest.Create;
  try
    request.Table := fModel.TableName;
    request.Action := TEntityRequestAction.raSelect;
    request.Fields := '*';
    request.Limit := aNumber;
    request.WhereClause := fWhereClause;
    request.Order := fOrderClause;
    request.OrderAsc := fOrderAsc;
    if fQuery.SendRequest(request) then Result := TEntityResult<T>.Create(Self);
  finally
    request.Free;
  end;
end;

function TRestServerEntityQuery<T>.Sum(const aFieldName: string): Int64;
begin
  raise ENotImplemented.Create('not implemented yet!');
end;

function TRestServerEntityQuery<T>.Update(aEntity: TEntity): Boolean;
begin
  Result := fQuery.SendRequest(TEntityRequestAction.raUpdate,aEntity);
end;

function TRestServerEntityQuery<T>.Update(const aFieldNames: string; const aFieldValues: array of const): Boolean;
begin
  raise ENotImplemented.Create('not implemented yet!');
end;

{ TRestServerConnection }

constructor TRestServerConnection.Create;
begin
  fConnected := False;
  fHttpClient := THTTPClient.Create;
end;

destructor TRestServerConnection.Destroy;
begin
  fHttpClient.Free;
  inherited;
end;

function TRestServerConnection.GetFieldNames(const aTableName: string): TArray<string>;
begin

end;

function TRestServerConnection.GetTableNames: TArray<string>;
begin

end;

procedure TRestServerConnection.SetConnected(const Value: Boolean);
begin
  if Value then
  begin
    //do connection to RestServer
    fConnected := True;
  end
  else
  begin
    //do disconnection from RestServer
    fConnected := False;
  end;
end;

{ TRestServerQuery<T> }

constructor TRestServerQuery<T>.Create;
begin
  fHttpClient := THTTPClient.Create;
  fHttpClient.UserAgent := 'Quick.Core.Entity.RestClient';
  fHttpClient.ContentType := 'application/json';
  fSerializer := TJsonSerializer.Create(TSerializeLevel.slPublishedProperty,True);
  fResults := TList<T>.Create;
end;

destructor TRestServerQuery<T>.Destroy;
begin
  fHttpClient.Free;
  fSerializer.Free;
  fResults.Free;
  inherited;
end;

function TRestServerQuery<T>.RequestActionToStr(aRequestAction: TEntityRequestAction): string;
begin
  Result := EntityRequestActionStr[aRequestAction];
end;

function TRestServerQuery<T>.SendRequest(aAction: TEntityRequestAction; aValue: TEntity): Boolean;
var
  response : IHTTPResponse;
  content : TStringStream;
begin
  content := TStringStream.Create(fSerializer.ObjectToJson(aValue));
  try
    {$IFDEF DEBUG_ENTITY}
    var crono := TDebugger.TimeIt(Self,'SendRequest',RequestActionToStr(aAction) + ' Entity');
    {$ENDIF}
    if aAction = TEntityRequestAction.raAdd then response := fHttpClient.Post(Format('%s/api/%s',[Connection.Host,fModel.TableName]),content)
    else if aAction = TEntityRequestAction.raAddOrUpdate then
    begin
      response := fHttpClient.Put(Format('%s/api/%s/AOU/%s',
                            [Connection.Host,fModel.TableName,aValue.FieldByName(fModel.PrimaryKey.Name)]),content);
    end
    else if aAction = TEntityRequestAction.raUpdate then
    begin
      response := fHttpClient.Put(Format('%s/api/%s/%s',
                            [Connection.Host,fModel.TableName,aValue.FieldByName(fModel.PrimaryKey.Name)]),content);
    end
    else raise EEntityRestRequestError.Create('Entity Method not allowed here');
    {$IFDEF DEBUG_ENTITY}
    crono.Stop;
    {$ENDIF}
  finally
    content.Free;
  end;
  Result := response.StatusCode in [200,201];
  if response.StatusCode in [200,201] then Result := True
    else if response.StatusCode <> 404 then raise EEntityRestRequestError.Create(response.StatusText);
end;

function TRestServerQuery<T>.SendRequest(aRequest: TEntityRequest): Boolean;
var
  response : IHTTPResponse;
  content : TStringStream;
  rescontent : TStringStream;
begin
  Result := False;
  content := TStringStream.Create(fSerializer.ObjectToJson(aRequest));
  try
    rescontent := TStringStream.Create;
    try
      {$IFDEF DEBUG_ENTITY}
      var crono := TDebugger.TimeIt(Self,'SendRequest', RequestActionToStr(aRequest.Action) + ' query');
      {$ENDIF}
      response := fHttpClient.Post(Format('%s/api/query/%s',[Connection.Host,RequestActionToStr(aRequest.Action)]),content,rescontent);
      {$IFDEF DEBUG_ENTITY}
      crono.Stop;
      {$ENDIF}
      if response.StatusCode in [200,201] then
      begin
        if aRequest.Action = TEntityRequestAction.raSelect then fSerializer.JsonToObject(fResults,rescontent.DataString);
        Result := True;
      end
      else if response.StatusCode <> 404 then
      begin
        raise EEntityRestRequestError.Create(response.StatusText);
      end;
    finally
      rescontent.Free;
    end;
  finally
    content.Free;
  end;
end;

function TRestServerQuery<T>.SendRequest(aRequest: TEntityRequest; out vResult : string): Boolean;
var
  response : IHTTPResponse;
  content : TStringStream;
  rescontent : TStringStream;
begin
  Result := False;
  content := TStringStream.Create(fSerializer.ObjectToJson(aRequest));
  try
    rescontent := TStringStream.Create;
    try
      {$IFDEF DEBUG_ENTITY}
      var crono := TDebugger.TimeIt(Self,'SendRequest', RequestActionToStr(aRequest.Action) + ' query');
      {$ENDIF}
      response := fHttpClient.Post(Format('%s/api/query/%s',[Connection.Host,RequestActionToStr(aRequest.Action)]),content,rescontent);
      {$IFDEF DEBUG_ENTITY}
      crono.Stop;
      {$ENDIF}
      if response.StatusCode in [200,201] then
      begin
        vResult := response.ContentAsString;
        Result := True;
      end
      else if response.StatusCode <> 404 then
      begin
        raise EEntityRestRequestError.Create(response.StatusText);
      end;
    finally
      rescontent.Free;
    end;
  finally
    content.Free;
  end;
end;

function TRestServerQuery<T>.ConnectRequest(aRequest: TEntityConnectRequest; out vResult : string): Boolean;
var
  response : IHTTPResponse;
  content : TStringStream;
  rescontent : TStringStream;
begin
  Result := False;
  content := TStringStream.Create(fSerializer.ObjectToJson(aRequest));
  try
    rescontent := TStringStream.Create;
    try
      {$IFDEF DEBUG_ENTITY}
      var crono := TDebugger.TimeIt(Self,'ConnectRequest', Format('Connecting to %s',[Connection.Host]));
      {$ENDIF}
      response := fHttpClient.Post(Format('%s/api/connect',[Connection.Host]),content,rescontent);
      {$IFDEF DEBUG_ENTITY}
      crono.Stop;
      {$ENDIF}
      if response.StatusCode in [200,201] then
      begin
        vResult := response.ContentAsString;
        Result := True;
      end
      else if response.StatusCode <> 404 then
      begin
        raise EEntityRestRequestError.Create(response.StatusText);
      end;
    finally
      rescontent.Free;
    end;
  finally
    content.Free;
  end;
end;

end.
