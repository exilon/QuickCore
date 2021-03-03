{ ***************************************************************************

  Copyright (c) 2016-2019 Kike Pérez

  Unit        : Quick.Core.Entity.Database
  Description : Core Entity DataBase
  Author      : Kike Pérez
  Version     : 1.8
  Created     : 03/11/2019
  Modified    : 06/06/2020

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

unit Quick.Core.Entity.Database;

{$i QuickCore.inc}

interface

uses
  {$IFDEF DEBUG_ENTITY}
  Quick.Debug.Utils,
  {$ENDIF}
  System.SysUtils,
  Quick.Core.Entity.DAO,
  Quick.Core.Entity.Factory.QueryGenerator;

type
  TDatabaseEngine = (deADO, deFireDAC, deRestServer);

  IDBConnectionSettings = interface
  ['{B4AE214B-432F-409C-8A15-AEEEE39CBAB5}']
    function GetProvider : TDBProvider;
    function GetServer : string;
    function GetDatabase : string;
    function GetUserName : string;
    function GetPassword : string;
    property Provider : TDBProvider read GetProvider;
    property Server : string read GetServer;
    property Database : string read GetDatabase;
    property UserName : string read GetUserName;
    property Password : string read GetPassword;
    function IsCustomConnectionString : Boolean;
    procedure FromConnectionString(aDBProviderID : Integer; const aConnectionString: string);
    function GetCustomConnectionString : string;
  end;

  TDBConnectionSettings = class(TInterfacedObject,IDBConnectionSettings)
  private
    fDBProvider : TDBProvider;
    fServer : string;
    fDatabase : string;
    fUserName : string;
    fPassword : string;
    fCustomConnectionString : string;
    fIsCustomConnectionString : Boolean;
    function GetProvider : TDBProvider; virtual;
    function GetServer : string;
    function GetDatabase : string;
    function GetUserName : string;
    function GetPassword : string;
  public
    constructor Create;
    property Provider : TDBProvider read GetProvider write fDBProvider;
    property Server : string read fServer write fServer;
    property Database : string read fDatabase write fDatabase;
    property UserName : string read fUserName write fUserName;
    property Password : string read fPassword write fPassword;
    function IsCustomConnectionString : Boolean;
    procedure FromConnectionString(aDBProviderID : Integer; const aConnectionString: string);
    function GetCustomConnectionString : string;
    function Clone : TDBConnectionSettings;
  end;

  TConnectionFailureEvent = procedure(aException : Exception) of object;
  TQueryErrorEvent = procedure(aException : Exception) of object;

  TEntityDatabase = class
  private
    fDBConnection : TDBConnectionSettings;
    fOwnsConnection : Boolean;
    fQueryGenerator : IEntityQueryGenerator;
    fModels : TEntityModels;
    fIndexes : TEntityIndexes;
    fOnQueryError: TQueryErrorEvent;
    fOnConnectionFailure: TConnectionFailureEvent;
    procedure ExecuteSQLQuery(const aQueryText : string);
    procedure OpenSQLQuery(const aQueryText: string);
    function CheckIsConnectionError(aException : Exception) : Boolean;
  protected
    property OwnsConnection : Boolean read fOwnsConnection write fOwnsConnection;
    function CreateConnectionString : string; virtual; abstract;
    procedure DoExecuteSQLQuery(const aQueryText : string); virtual; abstract;
    procedure DoOpenSQLQuery(const aQueryText: string); virtual; abstract;
    function ExistsTable(aModel : TEntityModel) : Boolean; virtual; abstract;
    function CreateTable(const aModel : TEntityModel): Boolean; virtual;
    function ExistsColumn(aModel: TEntityModel; const aFieldName: string): Boolean; virtual; abstract;
    procedure AddColumnToTable(aModel : TEntityModel; aField : TEntityField); virtual;
    procedure CreateTables; virtual;
    procedure SetPrimaryKey(aModel : TEntityModel); virtual;
    procedure CreateIndexes; virtual;
    procedure CreateIndex(aModel : TEntityModel; aIndex : TEntityIndex); virtual;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    function QueryGenerator : IEntityQueryGenerator;
    property Connection : TDBConnectionSettings read fDBConnection write fDBConnection;
    property Models : TEntityModels read fModels write fModels;
    property Indexes : TEntityIndexes read fIndexes write fIndexes;
    property OnConnectionFailure : TConnectionFailureEvent read fOnConnectionFailure write fOnConnectionFailure;
    property OnQueryError : TQueryErrorEvent read fOnQueryError write fOnQueryError;
    function CreateQuery(aModel : TEntityModel) : IEntityQuery<TEntity>; virtual; abstract;
    function GetTableNames : TArray<string>; virtual; abstract;
    function GetFieldNames(const aTableName : string) : TArray<string>; virtual; abstract;
    function Connect : Boolean; virtual;
    procedure Disconnect; virtual; abstract;
    function IsConnected : Boolean; virtual; abstract;
    function AddOrUpdate(aEntity : TEntity) : Boolean; virtual;
    function Add(aEntity : TEntity) : Boolean; virtual;
    function Update(aEntity : TEntity) : Boolean; virtual;
    function Delete(aEntity : TEntity) : Boolean; overload; virtual;
    function Clone : TEntityDatabase; virtual; abstract;
  end;

implementation

{ TEntityDatabase }

constructor TEntityDatabase.Create;
begin
  fDBConnection := TDBConnectionSettings.Create;
  fOwnsConnection := True;
  fModels := TEntityModels.Create;
  fIndexes := TEntityIndexes.Create;
end;

destructor TEntityDatabase.Destroy;
begin
  fDBConnection.Free;
  fModels.Free;
  fIndexes.Free;
  inherited;
end;

function TEntityDatabase.CheckIsConnectionError(aException : Exception) : Boolean;
var
  emessage : string;
begin
  {$IFDEF DEBUG_ENTITY}
    TDebugger.Trace(Self,'Check is connection error...');
  {$ENDIF}
  emessage := aException.Message.ToLower;
  if (emessage.Contains('connection') or emessage.Contains('network') or emessage.Contains('server')) and
     (emessage.Contains('failure') or emessage.Contains('error')
      or emessage.Contains('refused') or emessage.Contains('closed')) then Exit(True);

  if emessage.Contains('not connection') or emessage.Contains('not connect') then Exit(True);
  Result := False;
end;

procedure TEntityDatabase.ExecuteSQLQuery(const aQueryText: string);
begin
  try
    DoExecuteSQLQuery(aQueryText);
  except
    on E : Exception do
    begin
      if Assigned(fOnQueryError) then fOnQueryError(e);
      //if connection failure, reconnects
      if CheckIsConnectionError(e) then
      begin
        {$IFDEF DEBUG_ENTITY}
        TDebugger.Trace(Self,'Connection error: Reconnecting...');
        {$ENDIF}
        Disconnect;
        Connect;
      end;
      raise E;
    end;
  end;
end;

procedure TEntityDatabase.OpenSQLQuery(const aQueryText: string);
begin
  try
    DoOpenSQLQuery(aQueryText);
  except
    on E : Exception do
    begin
      if Assigned(fOnQueryError) then fOnQueryError(e);
      //if connection failure, reconnects
      if CheckIsConnectionError(e) then
      begin
        {$IFDEF DEBUG_ENTITY}
        TDebugger.Trace(Self,'Connection error: Reconnecting...');
        {$ENDIF}
        Disconnect;
        Connect;
      end;
      raise E;
    end;
  end;
end;

procedure TEntityDatabase.CreateIndexes;
var
  entityindex : TEntityIndex;
  entitymodel : TEntityModel;
begin
  for entityindex in Indexes.List do
  begin
    if (Models.List.TryGetValue(entityindex.Table,entitymodel)) and (entitymodel.HasPrimaryKey) then CreateIndex(entitymodel,entityindex);
  end;
end;

procedure TEntityDatabase.CreateTables;
var
  entitymodel : TEntityModel;
  field : TEntityField;
begin
  for entitymodel in Models.List.Values do
  begin
    if not ExistsTable(entitymodel) then CreateTable(entitymodel)
    else
    begin
      //add new fields
      for field in entitymodel.Fields do
      begin
        if not ExistsColumn(entitymodel,field.Name) then AddColumnToTable(entitymodel,field);
      end;
    end;
    SetPrimaryKey(entitymodel);
  end;
end;

function TEntityDatabase.CreateTable(const aModel : TEntityModel): Boolean;
begin
  try
    DoExecuteSQLQuery(QueryGenerator.CreateTable(aModel));
    Result := True;
  except
    on E : Exception do raise EEntityCreationError.CreateFmt('Error creating table "%s" : %s!',[aModel.TableName,e.Message])
  end;
end;

function TEntityDatabase.Connect: Boolean;
begin
  {$IFDEF DEBUG_ENTITY}
    TDebugger.TimeIt(Self,'Connect','');
  {$ENDIF}
  Result := False;
  try
    fQueryGenerator := TEntityQueryGeneratorFactory.Create(fDBConnection.Provider);
  except
    on E : Exception do raise EEntityConnectionError.CreateFmt('Cannot connect to Entity Database! (%s)',[e.message]);
  end;
end;

procedure TEntityDatabase.AddColumnToTable(aModel : TEntityModel; aField : TEntityField);
begin
  try
    DoExecuteSQLQuery(QueryGenerator.AddColumn(aModel,aField));
  except
    on E : Exception do raise EEntityCreationError.CreateFmt('Error creating table "%s" fields',[aModel.TableName]);
  end;
end;

procedure TEntityDatabase.SetPrimaryKey(aModel : TEntityModel);
var
  query : string;
begin
  try
    query := QueryGenerator.SetPrimaryKey(aModel);
    if not query.IsEmpty then DoExecuteSQLQuery(query);
  except
    on E : Exception do raise EEntityCreationError.Create('Error modifying primary key field');
  end;
  if (fDBConnection.Provider = dbSQLite) and (aModel.HasPrimaryKey) then Indexes.Add(aModel.Table,[aModel.PrimaryKey.Name],TEntityIndexOrder.orAscending);
end;

procedure TEntityDatabase.CreateIndex(aModel : TEntityModel; aIndex : TEntityIndex);
var
  query : string;
begin
  try
    query := QueryGenerator.CreateIndex(aModel,aIndex);
    if query.IsEmpty then Exit;
    DoExecuteSQLQuery(query);
  except
    on E : Exception do raise EEntityCreationError.CreateFmt('Error creating index "%s" on table "%s"',[aIndex.FieldNames[0],aModel.TableName]);
  end;
end;

function TEntityDatabase.Add(aEntity : TEntity) : Boolean;
begin
  Result := CreateQuery(fModels.Get(aEntity)).Add(aEntity);
end;

function TEntityDatabase.AddOrUpdate(aEntity : TEntity) : Boolean;
begin
  Result := CreateQuery(fModels.Get(aEntity)).AddOrUpdate(aEntity);
end;

function TEntityDatabase.Delete(aEntity : TEntity) : Boolean;
begin
  Result := CreateQuery(fModels.Get(aEntity)).Delete(aEntity);
end;

function TEntityDatabase.Update(aEntity : TEntity) : Boolean;
begin
  Result := CreateQuery(fModels.Get(aEntity)).Update(aEntity);
end;

function TEntityDatabase.QueryGenerator: IEntityQueryGenerator;
begin
  Result := fQueryGenerator;
end;

{ TDBConnectionSettings }

function TDBConnectionSettings.Clone: TDBConnectionSettings;
begin
  Result := TDBConnectionSettings.Create;
  Result.Provider := fDBProvider;
  Result.Server := fServer;
  Result.Database := fDatabase;
  Result.UserName := fUserName;
  Result.Password := fPassword;
  Result.fIsCustomConnectionString := fIsCustomConnectionString;
  Result.fCustomConnectionString := fCustomConnectionString;
end;

constructor TDBConnectionSettings.Create;
begin
  fCustomConnectionString := '';
  fIsCustomConnectionString := False;
end;

procedure TDBConnectionSettings.FromConnectionString(aDBProviderID : Integer; const aConnectionString: string);
begin
  if aConnectionString.IsEmpty then fIsCustomConnectionString := False
  else
  begin
    fCustomConnectionString := aConnectionString;
    fIsCustomConnectionString := True;
  end;
  //get provider from connectionstring
  if aDBProviderID <> 0 then fDBProvider := TDBProvider(aDBProviderID)
  else
  begin
    if fCustomConnectionString.ToUpper.Contains('DRIVERID=SQLITE') then fDBProvider := TDBProvider.dbSQLite;
  end;
end;

function TDBConnectionSettings.GetCustomConnectionString: string;
begin
  Result := fCustomConnectionString;
end;

function TDBConnectionSettings.GetDatabase: string;
begin
  Result := fDatabase;
end;

function TDBConnectionSettings.GetProvider: TDBProvider;
begin
  Result := fDBProvider;
end;

function TDBConnectionSettings.GetServer: string;
begin
  Result := fServer;
end;

function TDBConnectionSettings.GetUserName: string;
begin
  Result := fUserName;
end;

function TDBConnectionSettings.IsCustomConnectionString: Boolean;
begin
  Result := fIsCustomConnectionString;
end;

function TDBConnectionSettings.GetPassword: string;
begin
  Result := fPassword;
end;

end.
