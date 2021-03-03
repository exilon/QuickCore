{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Entity
  Description : Core Entity DataBase
  Author      : Kike Pérez
  Version     : 1.8
  Created     : 02/11/2019
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

unit Quick.Core.Entity;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  RTTI,
  System.Generics.Collections,
  Quick.RTTI.Utils,
  System.TypInfo,
  Quick.Commons,
  Quick.Core.Entity.DAO,
  Quick.Core.Entity.Database,
  Quick.Core.Entity.Factory.Database,
  Quick.Core.Entity.Query,
  Quick.Core.Identity;

type
  TID = Int64;

  TAutoID = Quick.Core.Entity.DAO.TAutoID;

  IDBSetResult<T : class> = interface(IEntityResult<T>)
  ['{9F8B912D-EFCC-498F-A929-847C2E117A24}']
  end;

  TEntity = Quick.Core.Entity.DAO.TEntity;

  TEntityTS = Quick.Core.Entity.DAO.TEntityTS;

  TEntityDatabase = Quick.Core.Entity.Database.TEntityDataBase;

  TEntityModel = Quick.Core.Entity.DAO.TEntityModel;

  Key = class(TCustomAttribute);

  StringLength = Quick.Core.Entity.DAO.StringLength;

  DecimalLength = Quick.Core.Entity.DAO.DecimalLength;

  MapField = Quick.Core.Entity.DAO.MapField;

  MapName = Quick.Core.Entity.DAO.MapField;

  Table = Quick.Core.Entity.DAO.MapField;

  TFieldDataType = Quick.Core.Entity.DAO.TFieldDataType;

  &Index = class(TCustomAttribute)
  private
    fFieldnames : TFieldNamesArray;
    fIndexOrder : TEntityIndexOrder;
  public
    constructor Create(const aFieldname : string; aIndexOrder : TEntityIndexOrder = TEntityIndexOrder.orAscending); overload;
    constructor Create(aIndexOrder : TEntityIndexOrder = TEntityIndexOrder.orAscending); overload;
    constructor Create(aFieldnames : TFieldNamesArray; aIndexOrder : TEntityIndexOrder = TEntityIndexOrder.orAscending); overload;
    property FieldNames : TFieldNamesArray read fFieldnames write fFieldnames;
    property IndexOrder : TEntityIndexOrder read  fIndexOrder write fIndexOrder;
  end;

  IDBContext = interface
  ['{EC512E62-77BA-461D-A6D9-FFA8431FBF64}']
    function GetDBConnection : TDBConnectionSettings;
    procedure SetDBConnection(aValue : TDBConnectionSettings);
    function GetModels : TEntityModels;
    function GetIndexes : TEntityIndexes;
    procedure SetIndexes(aValue : TEntityIndexes);
    property Connection : TDBConnectionSettings read GetDBConnection write SetDBConnection;
    property Models : TEntityModels read GetModels;
    property Indexes : TEntityIndexes read GetIndexes write SetIndexes;
    function CreateQuery(aModel : TEntityModel) : IEntityQuery<TEntity>;
    function GetTableNames : TArray<string>;
    function GetFieldNames(const aTableName : string) : TArray<string>;
    function Connect : Boolean;
    function IsConnected : Boolean;
    function AddOrUpdate(aEntity : TEntity) : Boolean;
    function Add(aEntity : TEntity) : Boolean;
    function Update(aEntity : TEntity) : Boolean;
    function Delete(aEntity : TEntity) : Boolean; overload;
  end;

  TDBSet<T : class, constructor> = record
  private
    fDatabase : TEntityDatabase;
    fModel : TEntityModel;
    function NewQuery : IEntityQuery<T>;
    function NewLinQ : IEntityLinqQuery<T>;
  public
    property Model : TEntityModel read fModel;
    procedure SetDatabase(aEntityDatabase : TEntityDatabase; aModel : TEntityModel);
    function Eof : Boolean;
    function AddOrUpdate(aEntity : TEntity) : Boolean;
    function Add(aEntity : TEntity) : Boolean;
    function CountResults : Integer;
    function Update(aEntity : TEntity) : Boolean; overload;
    function Delete(aEntity : TEntity) : Boolean; overload;
    function Delete(const aWhere : string) : Boolean; overload;
    //LINQ queries
    function Where(const aFormatSQLWhere: string; const aValuesSQLWhere: array of const) : IEntityLinqQuery<T>; overload;
    function Where(const aWhereClause: string) : IEntityLinqQuery<T>; overload;
    function SelectFirst : T;
    function SelectLast : T;
    function Select : IDBSetResult<T>; overload;
    function Select(const aFieldNames : string) : IDBSetResult<T>; overload;
    function SelectTop(aNumber : Integer) : IDBSetResult<T>;
    function Sum(const aFieldName : string) : Int64;
    function Count : Int64;
    function Update(const aFieldNames : string; const aFieldValues : array of const) : Boolean; overload;
    function Delete : Boolean; overload;
    function OrderBy(const aFieldValues : string) : IEntityLinqQuery<T>;
    function OrderByDescending(const aFieldValues : string) : IEntityLinqQuery<T>;
  end;

  TDBContext = class(TInterfacedObject,IDBContext)
  private
    fDatabase : TEntityDatabase;
    fDBSets : TDictionary<string,TDBSet<TEntity>>;
    procedure GetEntityInfo(aCtx : TRttiContext; aEntityClass : TEntityClass);
  protected
    function GetDBConnection : TDBConnectionSettings;
    procedure SetDBConnection(aValue : TDBConnectionSettings);
    function GetModels : TEntityModels;
    procedure GetModelsFromContext;
    procedure InitializeEntities;
    function GetIndexes : TEntityIndexes;
    procedure SetIndexes(aValue : TEntityIndexes);
  public
    constructor Create; overload;
    constructor Create(aEntityDatabase : TEntityDatabase); overload;
    destructor Destroy; override;
    property Database : TEntityDatabase read fDatabase write fDatabase;
    property Connection : TDBConnectionSettings read GetDBConnection write SetDBConnection;
    property Models : TEntityModels read GetModels;
    property Indexes : TEntityIndexes read GetIndexes write SetIndexes;
    function CreateQuery(aModel : TEntityModel) : IEntityQuery<TEntity>; virtual; abstract;
    function GetTableNames : TArray<string>; virtual; abstract;
    function GetFieldNames(const aTableName : string) : TArray<string>; virtual; abstract;
    function GetDBSet(const aTableName : string) : TDBSet<TEntity>;
    function Connect : Boolean; virtual;
    function IsConnected : Boolean; virtual; abstract;
    function AddOrUpdate(aEntity : TEntity) : Boolean; virtual;
    function Add(aEntity : TEntity) : Boolean; virtual;
    function Update(aEntity : TEntity) : Boolean; virtual;
    function Delete(aEntity : TEntity) : Boolean; overload; virtual;
  end;

  TIdentityUser<TKey> = class
  private
    fId : TKey;
    fUserName : string;
    fPasswordHash : string;
    fOptions : TIdentityOptions;
    fRoleId: TKey;
  public
    property Options : TIdentityOptions read fOptions write fOptions;
  published
    [Key]
    property Id : TKey read fId write fId;
    property RoleId : TKey read fRoleId write fRoleId;
    [StringLength(50)]
    property UserName : string read fUserName write fUserName;
    [StringLength(100)]
    property PasswordHash : string read fPasswordHash write fPasswordHash;
  end;

  TIdentityRole<TKey> = class
  private
    fId : TKey;
    fName : string;
  published
    [Key]
    property Id : TKey read fId write fId;
    [StringLength(100)]
    property Name : string read fName write fName;
  end;

  TIdentityDbContext<TUser, TRole : class, constructor> = class(TDBContext)
  private
    fUsers : TDBSet<TUser>;
    fRoles : TDBSet<TRole>;
  public
    property Users : TDBSet<TUser> read fUsers write fUsers;
    property Roles : TDBSet<TRole> read fRoles write fRoles;
  end;

implementation

{ TDBContext }

constructor TDBContext.Create;
begin
  fDBSets := TDictionary<string,TDBSet<TEntity>>.Create;
end;

constructor TDBContext.Create(aEntityDatabase: TEntityDatabase);
begin
  Create;
  fDatabase := aEntityDatabase;
end;

destructor TDBContext.Destroy;
begin
  if Assigned(fDatabase) then fDatabase.Free;
  if Assigned(fDBSets) then fDBSets.Free;
  inherited;
end;

function TDBContext.GetDBConnection: TDBConnectionSettings;
begin
  Result := fDatabase.Connection;
end;

function TDBContext.GetDBSet(const aTableName: string): TDBSet<TEntity>;
begin
  if not fDBSets.TryGetValue(aTableName.ToLower,Result) then raise EEntityModelError.CreateFmt('Table "%s" not found in DataBase',[aTableName]);
end;

function TDBContext.GetIndexes: TEntityIndexes;
begin
  Result := fDatabase.Indexes;
end;

function TDBContext.GetModels: TEntityModels;
begin
  Result := fDatabase.Models;
end;

procedure TDBContext.SetDBConnection(aValue: TDBConnectionSettings);
begin
  fDatabase.Connection := aValue;
end;

procedure TDBContext.SetIndexes(aValue: TEntityIndexes);
begin
  fDatabase.Indexes := aValue;
end;

procedure TDBContext.GetModelsFromContext;
var
  ctx : TRttiContext;
  rtype : TRttiType;
  rprop : TRttiProperty;
  value : TValue;
  cname : string;
  entityclass : TEntityClass;
  attr : TCustomAttribute;
  rectype : string;
  numTables : Integer;
begin
  Models.Clear;
  numTables:= 0;
  rtype := ctx.GetType(Self.ClassInfo);
  if rtype <> nil then
  begin
    for rprop in rtype.GetProperties do
    begin
      if True then
      if rprop.PropertyType.TypeKind <> tkRecord then continue;
      value := rprop.GetValue(Self);
      rectype := GetTypeName(value.TypeInfo);
      if rectype.StartsWith('TDBSet') then
      begin
        cname := GetSubString(rectype,'<','>');
        entityclass := TEntityClass(TRTTI.FindClass(cname));
        //get complex indexes from DBSet
        for attr in rprop.GetAttributes do
        begin
          if attr is &Index then fDatabase.Indexes.Add(entityclass,Index(attr).FieldNames,Index(attr).IndexOrder);
        end;
        //get DBSet info
        GetEntityInfo(ctx,entityclass);
        Inc(NumTables);
      end;
    end;
  end;
  if numTables = 0 then raise EEntityModelError.Create('No valid models found in DBContext!');
end;

procedure TDBContext.InitializeEntities;
var
  ctx : TRttiContext;
  rtype : TRttiType;
  rprop : TRttiProperty;
  value : TValue;
  cname : string;
  entityclass : TEntityClass;
  rRec : TRttiRecordType;
  rectype : string;
  entityModel : TEntityModel;
  dbset : TDBSet<TEntity>;
begin
  if not Assigned(fDBSets) then fDBSets := TDictionary<string,TDBSet<TEntity>>.Create
    else fDBSets.Clear;
  rtype := ctx.GetType(Self.ClassInfo);
  if rtype <> nil then
  begin
    for rprop in rtype.GetProperties do
    begin
      if rprop.PropertyType.TypeKind <> tkRecord then continue;
      value := rprop.GetValue(Self);
      rectype := GetTypeName(value.TypeInfo);
      if rectype.StartsWith('TDBSet') then
      begin
        cname := GetSubString(rectype,'<','>');
        entityclass := TEntityClass(TRTTI.FindClass(cname));
        //create DBSet query
        rRec := ctx.GetType(value.TypeInfo).AsRecord;
        entityModel := Models.Get(entityclass);
        rRec.GetMethod('SetDatabase').Invoke(value,[fDatabase,entityModel]);
        rprop.SetValue(Self,value);
        //add to dbsets
        dbset := TDBSet<TEntity>(value.GetReferenceToRawData^);
        fDBSets.Add(entityModel.TableName.ToLower,dbset);
      end;
    end;
  end;
end;

procedure TDBContext.GetEntityInfo(aCtx : TRttiContext; aEntityClass : TEntityClass);
var
  rtype : TRttiType;
  rprop : TRttiProperty;
  attr : TCustomAttribute;
  tablename : string;
  entityModel : TEntityModel;
  numFields : Integer;
begin
  tablename := '';
  numFields := 0;
  rtype := aCtx.GetType(aEntityClass.ClassInfo);
  if rtype = nil then raise EEntityModelError.CreateFmt('Cannot get DBSet "%s" Info',[aEntityClass.ClassName]);
  //get entity attributes
  for attr in rtype.GetAttributes do
  begin
    if (attr is MapName) or (attr is Table) then tablename := MapField(attr).Name;
  end;
  fDatabase.Models.Add(aEntityClass,'',tablename);
  //get entity properties attributes
  for rprop in rtype.GetProperties do
  begin
    if (rprop.Visibility = TMemberVisibility.mvPublished) and (rprop.IsWritable) then Inc(numFields);
    for attr in rprop.GetAttributes do
    begin
      if attr is Key then
      begin
        entityModel := GetModels.Get(aEntityClass);
        entityModel.PrimaryKey := entityModel.GetFieldByName(rprop.Name);
      end
      else if attr is &Index then fDatabase.Indexes.Add(aEntityClass,[rprop.Name],index(attr).IndexOrder);
    end;
  end;
  if numFields = 0 then raise EEntityModelError.CreateFmt('No valid fields found in Entity "%s"!',[aEntityClass.ClassName]);
end;

function TDBContext.Add(aEntity: TEntity): Boolean;
begin
  Result := fDatabase.AddOrUpdate(aEntity);
end;

function TDBContext.AddOrUpdate(aEntity: TEntity): Boolean;
begin
  Result := fDatabase.AddOrUpdate(aEntity);
end;

function TDBContext.Connect: Boolean;
begin
  Result := fDatabase.IsConnected;
  if not Result then
  begin
    GetModelsFromContext;
    Result := fDatabase.Connect;
  end;
  InitializeEntities;
end;

function TDBContext.Update(aEntity: TEntity): Boolean;
begin
  Result := fDatabase.Update(aEntity);
end;

function TDBContext.Delete(aEntity: TEntity): Boolean;
begin
  Result := fDatabase.Delete(aEntity);
end;

{ Index }

constructor &Index.Create(const aFieldname : string; aIndexOrder : TEntityIndexOrder = TEntityIndexOrder.orAscending);
begin
  fFieldnames := [aFieldname];
  fIndexOrder := aIndexOrder;
end;

constructor &Index.Create(aFieldnames : TFieldNamesArray; aIndexOrder : TEntityIndexOrder = TEntityIndexOrder.orAscending);
begin
  fFieldnames := aFieldnames;
  fIndexOrder := aIndexOrder;
end;

constructor &Index.Create(aIndexOrder : TEntityIndexOrder = TEntityIndexOrder.orAscending);
begin
  fFieldNames := [];
  fIndexOrder := aIndexOrder;
end;

{ TDBSet<T> }

function TDBSet<T>.Add(aEntity: TEntity): Boolean;
begin
  Result := NewQuery.Add(aEntity);
end;

function TDBSet<T>.AddOrUpdate(aEntity: TEntity): Boolean;
begin
  Result := NewQuery.AddOrUpdate(aEntity);
end;

function TDBSet<T>.Count: Int64;
begin
  Result := NewLinQ.Count;
end;

function TDBSet<T>.CountResults: Integer;
begin
  Result := NewQuery.CountResults;
end;

procedure TDBSet<T>.SetDatabase(aEntityDatabase : TEntityDatabase; aModel : TEntityModel);
begin
  fDatabase := aEntityDatabase;
  fModel := aModel;
end;

function TDBSet<T>.Delete: Boolean;
begin
  Result := NewLinQ.Delete;
end;

function TDBSet<T>.Delete(const aWhere: string): Boolean;
begin
  Result := NewQuery.Delete(aWhere);
end;

function TDBSet<T>.Delete(aEntity: TEntity): Boolean;
begin
  Result := NewQuery.Delete(aEntity);
end;

function TDBSet<T>.Eof: Boolean;
begin
  Result := NewQuery.Eof;
end;

function TDBSet<T>.NewLinQ: IEntityLinqQuery<T>;
begin
  Result := TEntityDatabaseFactory.GetQueryInstance<T>(fDatabase,Self.Model);
end;

function TDBSet<T>.NewQuery: IEntityQuery<T>;
begin
  Result := TEntityDatabaseFactory.GetQueryInstance<T>(fDatabase,Self.Model);
end;

function TDBSet<T>.OrderBy(const aFieldValues: string): IEntityLinqQuery<T>;
begin
  Result := NewLinQ.OrderBy(aFieldValues);
end;

function TDBSet<T>.OrderByDescending(const aFieldValues: string): IEntityLinqQuery<T>;
begin
  Result := NewLinQ.OrderByDescending(aFieldValues);
end;

function TDBSet<T>.Select(const aFieldNames: string): IDBSetResult<T>;
begin
  Result := IDBSetResult<T>(NewLinQ.Select(aFieldNames));
end;

function TDBSet<T>.Select: IDBSetResult<T>;
begin
  Result := IDBSetResult<T>(NewLinQ.Select);
end;

function TDBSet<T>.SelectFirst: T;
begin
  Result := NewLinQ.SelectFirst;
end;

function TDBSet<T>.SelectLast: T;
begin
  Result := NewLinQ.SelectLast;
end;

function TDBSet<T>.SelectTop(aNumber: Integer): IDBSetResult<T>;
begin
  Result := IDBSetResult<T>(NewLinQ.SelectTop(aNumber));
end;

function TDBSet<T>.Sum(const aFieldName: string): Int64;
begin
  Result := NewLinQ.Sum(aFieldName);
end;

function TDBSet<T>.Update(const aFieldNames: string; const aFieldValues: array of const): Boolean;
begin
  Result := NewLinQ.Update(aFieldNames,aFieldValues);
end;

function TDBSet<T>.Where(const aWhereClause: string): IEntityLinqQuery<T>;
begin
  Result := NewLinQ.Where(aWhereClause);
end;

function TDBSet<T>.Update(aEntity: TEntity): Boolean;
begin
  Result := NewQuery.Update(aEntity);
end;

function TDBSet<T>.Where(const aFormatSQLWhere: string; const aValuesSQLWhere: array of const): IEntityLinqQuery<T>;
begin
  Result := NewLinQ.Where(aFormatSQLWhere,aValuesSQLWhere);
end;

end.
