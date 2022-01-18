{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Entity.DAO
  Description : Core Entity DAO
  Author      : Kike Pérez
  Version     : 1.8
  Created     : 02/11/2019
  Modified    : 30/08/2020

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

unit Quick.Core.Entity.DAO;

{$i QuickCore.inc}

interface

uses
  Classes,
  SysUtils,
  Rtti,
  TypInfo,
  Generics.Collections,
  Variants,
  {$IFDEF DELPHIXE7_UP}
  System.Json,
  {$ENDIF}
  Quick.RTTI.Utils,
  Quick.Commons,
  Quick.Collections;

type
  MapField = class(TCustomAttribute)
  private
    fName : string;
  public
    constructor Create(const aName: string);
    property Name : string read fName;
  end;

  StringLength = class(TCustomAttribute)
  private
    fSize : Integer;
  public
    constructor Create(aSize : Integer);
    property Size : Integer read fSize;
  end;

  DecimalLength = class(TCustomAttribute)
  private
    fSize : Integer;
    fDecimals : Integer;
  public
    constructor Create(aSize, aDecimals : Integer);
    property Size : Integer read fSize;
    property Decimals : Integer read fdecimals;
  end;

  TDBProvider = (
    dbMSAccess2000 = $00010,
    dbMSAccess2007 = $00011,
    dbMSSQL        = $00020,
    dbMSSQLnc10    = $00021,
    dbMSSQLnc11    = $00022,
    dbMySQL        = $00030,
    dbSQLite       = $00040,
    dbIBM400       = $00050,
    dbFirebase     = $00060);

  TFieldDataType = (dtString, dtstringMax, dtChar, dtInteger, dtAutoID, dtInt64, dtFloat, dtBoolean, dtDate, dtTime, dtDateTime, dtCreationDate, dtModifiedDate, dtGUID);

  EEntityConnectionError = class(Exception);
  EEntityModelError = class(Exception);
  EEntityCreationError = class(Exception);
  EEntityUpdateError = class(Exception);
  EEntitySelectError = class(Exception);
  EEntityDeleteError = class(Exception);
  EEntityProviderError = class(Exception);
  EEntityRestRequestError = class(Exception);

  TEntity = class;

  TEntityArray = array of TEntity;

  TEntityClass = class of TEntity;

  TEntityClassArray = array of TEntityClass;

  TEntityIndexOrder = (orAscending, orDescending);

  TFieldNamesArray = array of string;

  TAutoID = type Int64;

  TEntityIndex = class
  private
    fTable : TEntityClass;
    fFieldNames : TFieldNamesArray;
    fOrder : TEntityIndexOrder;
  public
    property Table : TEntityClass read fTable write fTable;
    property FieldNames : TFieldNamesArray read fFieldNames write fFieldNames;
    property Order : TEntityIndexOrder read fOrder write fOrder;
  end;

  TEntityIndexes = class
  private
    fList : TObjectList<TEntityIndex>;
  public
    constructor Create;
    destructor Destroy; override;
    property List : TObjectList<TEntityIndex> read fList write fList;
    procedure Add(aEntityClass: TEntityClass; aFieldNames: TFieldNamesArray; aOrder : TEntityIndexOrder);
  end;

  TEntityField = class
  private
    fName : string;
    fDataType : TFieldDataType;
    fDataSize : Integer;
    fPrecision : Integer;
    fIsPrimaryKey : Boolean;
  public
    property Name : string read fName write fName;
    property DataType : TFieldDataType read fDataType write fDataType;
    property DataSize : Integer read fDataSize write fDataSize;
    property Precision : Integer read fPrecision write fPrecision;
    property IsPrimaryKey : Boolean read fIsPrimaryKey write fIsPrimaryKey;
  end;

  TEntityFields = TObjectList<TEntityField>;

  TDBField = record
    FieldName : string;
    Value : variant;
    function IsEmptyOrEmpty : Boolean;
  end;

  TEntityModel = class
  private
    fTable : TEntityClass;
    fTableName : string;
    fPrimaryKey : TEntityField;
    fFields : TEntityFields;
    fFieldsMap : TDictionary<string,TEntityField>;
    procedure GetFields;
    procedure SetTable(const Value: TEntityClass);
    procedure SetPrimaryKey(const Value: TEntityField);
  public
    constructor Create;
    destructor Destroy; override;
    property Table : TEntityClass read fTable write SetTable;
    property TableName : string read fTableName write fTableName;
    property PrimaryKey : TEntityField read fPrimaryKey write SetPrimaryKey;
    property Fields : TEntityFields read fFields;
    function GetFieldNames(aEntity : TEntity; aExcludeAutoIDFields : Boolean) : TStringList;
    function GetFieldByName(const aName : string) : TEntityField;
    function HasPrimaryKey : Boolean;
    function IsPrimaryKey(const aName : string) : Boolean;
    function NewEntity : TObject; overload;
    function NewEntity<T : class, constructor> : T; overload;
  end;

  TEntityModels = class
  private
    fList : TObjectDictionary<TEntityClass,TEntityModel>;
    fPluralizeTableNames : Boolean;
    function GetTableNameFromClass(aEntityClass : TEntityClass) : string;
  public
    constructor Create;
    destructor Destroy; override;
    property List : TObjectDictionary<TEntityClass,TEntityModel> read fList write fList;
    property PluralizeTableNames : Boolean read fPluralizeTableNames write fPluralizeTableNames;
    procedure Add(aEntityClass: TEntityClass; const aPrimaryKey: string; const aTableName : string = '');
    function GetPrimaryKey(aEntityClass : TEntityClass) : string;
    function Get(aEntityClass : TEntityClass) : TEntityModel; overload;
    function Get(aEntity : TEntity) : TEntityModel; overload;
    procedure Clear;
  end;

  IEntityResult<T : class> = interface
  ['{0506DF8C-2749-4DB0-A0E9-44793D4E6AB7}']
    function Count : Integer;
    function HasResults : Boolean;
    function GetEnumerator: TEnumerator<T>;
    function ToList : IList<T>; overload;
    procedure ToList(aList : TList<T>); overload;
    function ToObjectList : IObjectList<T>; overload;
    procedure ToObjectList(aList : TObjectList<T>); overload;
    function ToArray : TArray<T>;
    function GetOne(aEntity : T) : Boolean;
  end;

  IEntityQuery<T> = interface
  ['{6AA202B4-CBBC-48AA-9D5A-855748D02DCC}']
    function Eof : Boolean;
    function MoveNext : Boolean;
    function GetCurrent : T;
    function GetModel : TEntityModel;
    function FillRecordFromDB(aEntity : T) : T;
    function GetFieldValue(const aName : string) : Variant;
    function CountResults : Integer;
    function AddOrUpdate(aEntity : TEntity) : Boolean;
    function Add(aEntity : TEntity) : Boolean;
    function Update(aEntity : TEntity) : Boolean; overload;
    function Update(const aFieldNames : string; const aFieldValues : array of const) : Boolean; overload;
    function Delete(aEntity : TEntity) : Boolean; overload;
    function Delete(const aQuery : string) : Boolean; overload;
  end;

  IEntityQueryGenerator = interface
  ['{9FD0E61E-0568-49F4-A9D4-2D540BE72384}']
    function Name : string;
    function CreateTable(const aEntityClass : TEntityModel) : string;
    function ExistsTable(aModel : TEntityModel) : string;
    function ExistsColumn(aModel : TEntityModel; const aFieldName : string) : string;
    function AddColumn(aModel : TEntityModel; aField : TEntityField) : string;
    function SetPrimaryKey(aModel : TEntityModel) : string;
    function CreateIndex(aModel : TEntityModel; aIndex : TEntityIndex) : string;
    function Select(const aTableName, aFieldNames : string; aLimit : Integer; const aWhere : string; aOrderFields : string; aOrderAsc : Boolean) : string;
    function Sum(const aTableName, aFieldName, aWhere : string) : string;
    function Count(const aTableName : string; const aWhere : string) : string;
    function Add(const aTableName: string; const aFieldNames, aFieldValues : string) : string;
    function AddOrUpdate(const aTableName: string; const aFieldNames, aFieldValues : string) : string;
    function Update(const aTableName, aFieldPairs, aWhere : string) : string;
    function Delete(const aTableName : string; const aWhere : string) : string;
    function DateTimeToDBField(aDateTime : TDateTime) : string;
    function DBFieldToDateTime(const aValue : string) : TDateTime;
    function QuotedStr(const aValue : string) : string;
    function DBFieldToGUID(const aValue : string) : TGUID;
    function GUIDToDBField(aGuid : TGUID) : string;
    procedure UseISO8601DateTime;
  end;

  IEntityLinqQuery<T : class> = interface
  ['{5655FDD9-1D4C-4B67-81BB-7BDE2D2C860B}']
    {$IFDEF VALUE_FORMATPARAMS}
    function Where(const aFormatSQLWhere: string; const aValuesSQLWhere: array of TValue): IEntityLinqQuery<T>; overload;
    {$ELSE}
    function Where(const aFormatSQLWhere: string; const aValuesSQLWhere: array of const): IEntityLinqQuery<T>; overload;
    {$ENDIF}function Where(const aWhereClause: string) : IEntityLinqQuery<T>; overload;
    function Select : IEntityResult<T>; overload;
    function Select(const aFieldNames : string) : IEntityResult<T>; overload;
    function SelectFirst : T;
    function SelectLast : T;
    function SelectTop(aNumber : Integer) : IEntityResult<T>;
    function Sum(const aFieldName : string) : Int64;
    function Count : Int64;
    function Update(const aFieldNames : string; const aFieldValues : array of const) : Boolean;
    function Delete : Boolean;
    function OrderBy(const aFieldValues : string) : IEntityLinqQuery<T>;
    function OrderByDescending(const aFieldValues : string) : IEntityLinqQuery<T>;
  end;

  TEntityResult<T : class, constructor> = class(TInterfacedObject,IEntityResult<T>)
  type
    TEntityEnumerator = class(TEnumerator<T>)
    private
      fEntityQuery : IEntityQuery<T>;
      fModel : TEntityModel;
    protected
      function DoGetCurrent: T; override;
      function DoMoveNext: Boolean; override;
    public
      constructor Create(aEntityQuery: IEntityQuery<T>);
    end;
  private
    fEntityQuery : IEntityQuery<T>;
  public
    constructor Create(aEntityQuery : IEntityQuery<T>);
    function GetEnumerator: TEnumerator<T>; inline;
    function GetOne(aEntity : T) : Boolean;
    function ToList : IList<T>; overload;
    procedure ToList(aList : TList<T>); overload;
    function ToObjectList : IObjectList<T>; overload;
    procedure ToObjectList(aList : TObjectList<T>); overload;
    function ToArray : TArray<T>;
    function Count : Integer;
    function HasResults : Boolean;
  end;

  TEntityQueryGenerator = class(TInterfacedObject)
  protected
    fISO8601DateTime : Boolean;
  public
    function QuotedStr(const aValue: string): string; virtual;
    procedure UseISO8601DateTime;
  end;

  TEntity = class
  public
    {$IFDEF VALUE_FORMATPARAMS}
    function FieldByName(const aFieldName: string): TValue;
    {$ELSE}
    function FieldByName(const aFieldName : string) : Variant;
    {$ENDIF}
    function FieldValueByName(const aFieldName : string) : string;
    function FieldValueIsEmpty(const aFieldName : string) : Boolean;
  end;

  TCreationDate = type TDateTime;
  TModifiedDate = type TDateTime;

  TEntityTS = class(TEntity)
  private
    fCreationDate : TCreationDate;
    fModifiedDate : TModifiedDate;
  published
    property CreationDate : TCreationDate read fCreationDate write fCreationDate;
    property ModifiedDate : TModifiedDate read fModifiedDate write fModifiedDate;
  end;

  function QuotedStrEx(const aValue : string) : string;
  function FormatSQLParams(const aSQLClause : string; aSQLParams : array of const) : string;
  function IsEmptyOrNull(const Value: Variant): Boolean;

implementation

uses
  Quick.Core.Entity.Factory.QueryGenerator;

function QuotedStrEx(const aValue : string) : string;
var
  sb : TStringBuilder;
begin
  sb := TStringBuilder.Create;
  try
    sb.Append('''');
    sb.Append(aValue);
    sb.Append('''');
    Result := sb.ToString(0, sb.Length - 1);
  finally
    sb.Free;
  end;
end;

function FormatSQLParams(const aSQLClause : string; aSQLParams : array of const) : string;
var
  i : Integer;
begin
  Result := aSQLClause;
  if aSQLClause = '' then
  begin
    Result := '1=1';
    Exit;
  end;
  for i := 0 to aSQLClause.CountChar('?') - 1 do
  begin
    case aSQLParams[i].VType of
      vtInteger : Result := StringReplace(Result,'?',IntToStr(aSQLParams[i].VInteger),[]);
      vtInt64 : Result := StringReplace(Result,'?',IntToStr(aSQLParams[i].VInt64^),[]);
      vtExtended : Result := StringReplace(Result,'?',FloatToStr(aSQLParams[i].VExtended^),[]);
      vtBoolean : Result := StringReplace(Result,'?',BoolToStr(aSQLParams[i].VBoolean),[]);
      vtAnsiString : Result := StringReplace(Result,'?',string(aSQLParams[i].VAnsiString),[]);
      vtWideString : Result := StringReplace(Result,'?',string(aSQLParams[i].VWideString^),[]);
      {$IFNDEF NEXTGEN}
      vtString : Result := StringReplace(Result,'?',aSQLParams[i].VString^,[]);
      {$ENDIF}
      vtChar : Result := StringReplace(Result,'?',aSQLParams[i].VChar,[]);
      vtPChar : Result := StringReplace(Result,'?',aSQLParams[i].VPChar,[]);
    else Result := StringReplace(Result,'?', QuotedStr(string(aSQLParams[i].VUnicodeString)),[]);
    end;
  end;
end;

{ MapField }

{$IFNDEF FPC}
constructor MapField.Create(const aName: string);
begin
  fName := aName;
end;
{$ENDIF}

{ TEntity }

function IsEmptyOrNull(const Value: Variant): Boolean;
begin
  Result := VarIsClear(Value) or VarIsEmpty(Value) or VarIsNull(Value) or (VarCompareValue(Value, Unassigned) = vrEqual);
  if (not Result) and VarIsStr(Value) then
    Result := Value = '';
end;

{$IFDEF VALUE_FORMATPARAMS}
function TEntity.FieldByName(const aFieldName: string): TValue;
begin
  Result := TRTTI.GetPropertyValue(Self,aFieldName);
  if Result.Kind = tkRecord then
  begin
    if Result.IsType<TGUID> then Result := GetSubString(GUIDToString(Result.AsType<TGUID>),'{','}')
      else Result := Result.ToString;
  end;
end;
{$ELSE}
function TEntity.FieldByName(const aFieldName: string): Variant;
var
  value : TValue;
begin
  value := TRTTI.GetPropertyValue(Self,aFieldName);
  if value.Kind = tkRecord then
  begin
    if value.IsType<TGUID> then Result := GetSubString(GUIDToString(value.AsType<TGUID>),'{','}')
      else Result := value.ToString;
  end
  else Result := value.AsVariant;
end;
{$ENDIF}

function TEntity.FieldValueByName(const aFieldName: string): string;
var
  value : TValue;
begin
  value := TRTTI.GetPropertyValue(Self,aFieldName);
  if value.Kind = tkRecord then
  begin
    if value.IsType<TGUID> then Result := GetSubString(GUIDToString(value.AsType<TGUID>),'{','}')
      else Result := value.ToString;
  end
  else Result := value.ToString;
end;

function TEntity.FieldValueIsEmpty(const aFieldName: string): Boolean;
begin
  Result := TRTTI.GetPropertyValue(Self,aFieldName).IsEmpty;
end;

{ TEntityIndexes }

procedure TEntityIndexes.Add(aEntityClass: TEntityClass; aFieldNames: TFieldNamesArray; aOrder : TEntityIndexOrder);
var
  entityIndex : TEntityIndex;
begin
  entityIndex := TEntityIndex.Create;
  entityIndex.Table := aEntityClass;
  entityIndex.FieldNames := aFieldNames;
  entityIndex.Order := aOrder;
  fList.Add(entityIndex);
end;

constructor TEntityIndexes.Create;
begin
  fList := TObjectList<TEntityIndex>.Create(True);
end;

destructor TEntityIndexes.Destroy;
begin
  fList.Free;
  inherited;
end;

{ TEntityModels }

procedure TEntityModels.Add(aEntityClass: TEntityClass; const aPrimaryKey: string; const aTableName : string = '');
var
  entityModel : TEntityModel;
begin
  entityModel := TEntityModel.Create;
  entityModel.Table := aEntityClass;
  {$IFNDEF FPC}
  if aTableName = '' then entityModel.TableName := GetTableNameFromClass(aEntityClass)
  {$ELSE}
  if aTableName = '' then entityModel.TableName := GetTableNameFromClass(aEntityClass)
  {$ENDIF}
    else entityModel.TableName := aTableName;
  if not aPrimaryKey.IsEmpty then entityModel.PrimaryKey := entityModel.GetFieldByName(aPrimaryKey);
  fList.Add(aEntityClass,entityModel);
end;

procedure TEntityModels.Clear;
begin
  fList.Clear;
end;

constructor TEntityModels.Create;
begin
  fList := TObjectDictionary<TEntityClass,TEntityModel>.Create([doOwnsValues]);
  fPluralizeTableNames  := False;
end;

destructor TEntityModels.Destroy;
begin
  fList.Free;
  inherited;
end;

function TEntityModels.Get(aEntityClass: TEntityClass): TEntityModel;
begin
  if not fList.TryGetValue(aEntityClass,Result) then raise EEntityModelError.CreateFmt('Model "%s" not exists in database',[aEntityClass.ClassName]);
end;

function TEntityModels.Get(aEntity : TEntity) : TEntityModel;
begin
  if aEntity = nil then raise EEntityModelError.Create('Model is empty');
  Result := Get(TEntityClass(aEntity.ClassType));
end;

function TEntityModels.GetPrimaryKey(aEntityClass: TEntityClass): string;
begin
  Result := Get(aEntityClass).PrimaryKey.Name;
end;

function TEntityModels.GetTableNameFromClass(aEntityClass: TEntityClass): string;
begin
  Result := Copy(aEntityClass.ClassName,2,aEntityClass.ClassName.Length);
  if fPluralizeTableNames then Result := Result + 's';
end;

{$IFNDEF FPC}
{ StringLength }

constructor StringLength.Create(aSize: Integer);
begin
  fSize := aSize;
end;

{ DecimalLength }

constructor DecimalLength.Create(aSize, aDecimals: Integer);
begin
  fSize := aSize;
  fDecimals := aDecimals;
end;
{$ENDIF}

{ TEntityModel }

constructor TEntityModel.Create;
begin
  fFields := TObjectList<TEntityField>.Create(True);
  fFieldsMap := TDictionary<string,TEntityField>.Create;
end;

destructor TEntityModel.Destroy;
begin
  fFieldsMap.Free;
  fFields.Free;
  inherited;
end;

function TEntityModel.GetFieldByName(const aName: string): TEntityField;
begin
  if not fFieldsMap.TryGetValue(aName,Result) then raise EEntityModelError.CreateFmt('Field "%s" not found in table "%s"!',[aName,Self.TableName]);
end;

function TEntityModel.GetFieldNames(aEntity : TEntity; aExcludeAutoIDFields : Boolean) : TStringList;
var
  value : TValue;
  skip : Boolean;
  field : TEntityField;
begin
  Result := TStringList.Create;
  Result.Delimiter := ',';
  Result.StrictDelimiter := True;
  try
    for field in fFields do
    begin
      skip := False;
      if field.IsPrimaryKey then
      begin
        if (not aExcludeAutoIDFields) and (aEntity <> nil) then
        begin
          if field.DataType = dtAutoID then
          begin
            value := TRTTI.GetPropertyValue(aEntity,field.Name);
            if (value.IsEmpty) or (value.AsInt64 = 0) then skip := True;
          end;
        end
        else skip := True;
      end;
      if not skip then Result.Add(Format('[%s]',[field.Name]));
    end;
  except
    on E : Exception do
    begin
      raise Exception.CreateFmt('Error getting field names "%s" : %s',[Self.ClassName,e.Message]);
    end;
  end;
end;

procedure TEntityModel.GetFields;
var
  ctx: TRttiContext;
  {$IFNDEF FPC}
  attr : TCustomAttribute;
  {$ENDIF}
  rType: TRttiType;
  rProp: TRttiProperty;
  propertyname : string;
  entityField : TEntityField;
  value : TValue;
begin
  try
    rType := ctx.GetType(Self.Table.ClassInfo);
    for rProp in TRTTI.GetProperties(rType,roFirstBase) do
    begin
      propertyname := rProp.Name;
      if IsPublishedProp(Self.Table,propertyname) then
      begin
        entityField := TEntityField.Create;
        entityField.DataSize := 0;
        entityField.Precision := 0;
        {$IFNDEF FPC}
        //get datasize from attributes
        for attr in rProp.GetAttributes do
        begin
          if attr is MapField then propertyname := MapField(attr).Name;
          if attr is StringLength then entityField.DataSize := StringLength(attr).Size;
          if attr is DecimalLength then
          begin
            entityField.DataSize := DecimalLength(attr).Size;
            entityField.Precision := DecimalLength(attr).Decimals;
          end;
        end;
        {$ENDIF}
        entityField.Name := propertyname;

        //value := rProp.GetValue(Self.Table);
        //propType := rProp.PropertyType.TypeKind;
        case rProp.PropertyType.TypeKind of
          tkDynArray, tkArray, tkClass :
            begin
              entityField.DataType := dtstringMax;
            end;
          tkString, tkLString, tkWString, tkUString{$IFDEF FPC}, tkAnsiString{$ENDIF} :
            begin
              //get datasize from index
              {$IFNDEF FPC}
              if TRttiInstanceProperty(rProp).Index > 0 then entityField.DataSize := TRttiInstanceProperty(rProp).Index;
              {$ELSE}
              if GetPropInfo(Self.Table,propertyname).Index > 0 then entityField.DataSize := GetPropInfo(Self.Table,propertyname).Index;
              {$ENDIF}

              if entityField.DataSize = 0 then entityField.DataType := dtstringMax
                else entityField.DataType := dtString;
            end;
          tkChar, tkWChar :
            begin
              entityField.DataType := dtString;
              entityField.DataSize := 1;
            end;
          tkInteger : entityField.DataType := dtInteger;
          tkInt64 :
            begin
              if rProp.PropertyType.Name = 'TAutoID' then entityField.DataType := dtAutoId
                else entityField.DataType := dtInt64;
            end;
          {$IFDEF FPC}
          tkBool : entityField.DataType := dtBoolean;
          {$ENDIF}
          tkFloat :
            begin
              value := rProp.GetValue(Self.Table);
              if value.TypeInfo = TypeInfo(TCreationDate) then
              begin
                entityField.DataType := dtCreationDate;
              end
              else if value.TypeInfo = TypeInfo(TModifiedDate) then
              begin
                entityField.DataType := dtModifiedDate;
              end
              else if value.TypeInfo = TypeInfo(TDateTime) then
              begin
                entityField.DataType := dtDateTime;
              end
              else if value.TypeInfo = TypeInfo(TDate) then
              begin
                entityField.DataType := dtDate;
              end
              else if value.TypeInfo = TypeInfo(TTime) then
              begin
                entityField.DataType := dtTime;
              end
              else
              begin
                entityField.DataType := dtFloat;
                if entityField.DataSize = 0 then entityField.DataSize := 10;
                //get decimals from index
                {$IFNDEF FPC}
                if TRttiInstanceProperty(rProp).Index > 0 then entityField.Precision := TRttiInstanceProperty(rProp).Index;
                {$ELSE}
                if GetPropInfo(Self.Table,propertyname).Index > 0 then entityField.Precision := GetPropInfo(Self.Table,propertyname).Index;
                {$ENDIF}
                if entityField.Precision = 0 then entityField.Precision := 4;
              end;
            end;
          tkEnumeration :
            begin
              value := rProp.GetValue(Self.Table);
              if (value.TypeInfo = System.TypeInfo(Boolean)) then
              begin
                entityField.DataType := dtBoolean;
              end
              else
              begin
                entityField.DataType := dtInteger;
              end;
            end;
          tkRecord :
            begin
              value := rProp.GetValue(Self.Table);
              if (value.TypeInfo = System.TypeInfo(TGUID)) then
              begin
                entityField.DataType := dtGUID;
              end
              else
              begin
                entityField.DataType := dtstringMax;
              end;
            end;
        end;
        fFields.Add(entityField);
        fFieldsMap.Add(entityField.Name,entityField);
      end;
    end;
  except
    on E : Exception do
    begin
      raise Exception.CreateFmt('Error getting fields "%s" : %s',[Self.ClassName,e.Message]);
    end;
  end;
end;

function TEntityModel.HasPrimaryKey: Boolean;
begin
  Result := not fPrimaryKey.Name.IsEmpty;
end;

function TEntityModel.IsPrimaryKey(const aName: string): Boolean;
begin
  Result := HasPrimaryKey and (CompareText(PrimaryKey.Name,aName) = 0);
end;

function TEntityModel.NewEntity: TObject;
begin
  Result := TRTTI.CreateInstance(fTable);
end;

function TEntityModel.NewEntity<T>: T;
begin
  Result := TRTTI.CreateInstance(fTable) as T;
end;

procedure TEntityModel.SetPrimaryKey(const Value: TEntityField);
begin
  fPrimaryKey := Value;
  fPrimaryKey.IsPrimaryKey := True;
end;

procedure TEntityModel.SetTable(const Value: TEntityClass);
begin
  fTable := Value;
  GetFields;
end;

{ TEntityResult }

constructor TEntityResult<T>.Create(aEntityQuery: IEntityQuery<T>);
begin
  fEntityQuery := aEntityQuery;
end;

function TEntityResult<T>.GetEnumerator: TEnumerator<T>;
begin
  Result := TEntityEnumerator.Create(fEntityQuery);
end;

function TEntityResult<T>.GetOne(aEntity: T): Boolean;
begin
  //Result := not fEntityQuery.Eof;
  //if not Result then Exit;
  Result := fEntityQuery.MoveNext;
  if not Result then Exit;
  fEntityQuery.FillRecordFromDB(aEntity);
end;

function TEntityResult<T>.ToArray: TArray<T>;
var
  entity : T;
  i : Integer;
begin
  SetLength(Result,Self.Count);
  i := 0;
  for entity in Self do
  begin
    Result[i] := entity;
    Inc(i);
  end;
end;

function TEntityResult<T>.ToList: IList<T>;
var
  entity : T;
begin
  Result := TXList<T>.Create;
  Result.Capacity := Self.Count;
  for entity in Self do Result.Add(entity);
end;

procedure TEntityResult<T>.ToList(aList: TList<T>);
var
  entity : T;
begin
  aList.Capacity := Self.Count;
  for entity in Self do aList.Add(entity);
end;

function TEntityResult<T>.ToObjectList: IObjectList<T>;
var
  entity : T;
begin
  Result := TXObjectList<T>.Create(True);
  Result.Capacity := Self.Count;
  for entity in Self do Result.Add(entity);
end;

procedure TEntityResult<T>.ToObjectList(aList: TObjectList<T>);
var
  entity : T;
begin
  aList.Capacity := Self.Count;
  for entity in Self do aList.Add(entity);
end;

function TEntityResult<T>.Count: Integer;
begin
  Result := fEntityQuery.CountResults;
end;

function TEntityResult<T>.HasResults: Boolean;
begin
  Result := fEntityQuery.CountResults > 0;
end;

{ TEntityResult<T>.TEnumerator }

constructor TEntityResult<T>.TEntityEnumerator.Create(aEntityQuery: IEntityQuery<T>);
begin
  fEntityQuery := aEntityQuery;
  fModel := aEntityQuery.GetModel;
end;

function TEntityResult<T>.TEntityEnumerator.DoGetCurrent: T;
var
  entity : TEntity;
begin
  entity := TRTTI.CreateInstance(fEntityQuery.GetModel.Table) as TEntity;
  Result := fEntityQuery.FillRecordFromDB(entity);
  //Result := entity as T;

  //Result := fEntityQuery.FillRecordFromDB(entity) as T;

  //Result := fEntityQuery.GetCurrent;
end;

function TEntityResult<T>.TEntityEnumerator.DoMoveNext: Boolean;
begin
  Result := fEntityQuery.MoveNext;
end;

{ TEntityQueryGenerator }

function TEntityQueryGenerator.QuotedStr(const aValue: string): string;
begin
  Result := '''' + aValue + '''';
end;

procedure TEntityQueryGenerator.UseISO8601DateTime;
begin
  fISO8601DateTime := True;
end;

{ TDBField }

function TDBField.IsEmptyOrEmpty: Boolean;
begin
  Result := VarIsClear(Value) or VarIsEmpty(Value) or VarIsNull(Value) or (VarCompareValue(Value, Unassigned) = vrEqual);
  if (not Result) and VarIsStr(Value) then Result := Value = '';
end;

end.
