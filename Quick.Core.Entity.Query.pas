{ ***************************************************************************

  Copyright (c) 2016-2021 Kike Pérez

  Unit        : Quick.Core.Entity.Query
  Description : Core Entity Query
  Author      : Kike Pérez
  Version     : 1.1
  Created     : 31/11/2019
  Modified    : 29/08/2021

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

unit Quick.Core.Entity.Query;

{$i QuickCore.inc}

interface

uses
  {$IFDEF DEBUG_ENTITY}
    Quick.Debug.Utils,
  {$ENDIF}
  Classes,
  RTTI,
  System.SysUtils,
  System.TypInfo,
  Json,
  System.Variants,
  System.Generics.Collections,
  System.Generics.Defaults,
  Quick.Commons,
  Quick.RTTI.Utils,
  Quick.Json.Serializer,
  Quick.Core.Entity.DAO,
  Quick.Core.Entity.Database;

type

  TEntityQuery<T : class, constructor>  = class(TInterfacedObject,IEntityQuery<T>,IEntityLinqQuery<T>)
  private
    {$IFDEF VALUE_FORMATPARAMS}
    function FormatParams(const aWhereClause : string; aWhereParams : array of TValue) : string;
    {$ELSE}
    function FormatParams(const aWhereClause : string; aWhereParams : array of const) : string;
    {$ENDIF}
  protected
    fWhereClause : string;
    fOrderClause : string;
    fOrderAsc : Boolean;
    fSelectedFields : TArray<string>;
    fEntityDataBase : TEntityDataBase;
    fModel : TEntityModel;
    fQueryGenerator : IEntityQueryGenerator;
    fHasResults : Boolean;
    fFirstIteration : Boolean;
    function BoolToSQLString(aBoolean : Boolean) : string; virtual;
    function MoveNext : Boolean; virtual; abstract;
    function GetCurrent : T; virtual; abstract;
    function GetFieldValue(const aName : string) : Variant; virtual; abstract;
    function GetFieldValues(aEntity : TEntity; aExcludeAutoIDFields : Boolean)  : TStringList;
    function FillRecordFromDB(aEntity : T) : T; virtual;
    function GetDBFieldValue(const aFieldName : string; aValue : TValue): TValue;
    function GetFieldsPairs(aEntity : TEntity): string; overload;
    function GetFieldsPairs(const aFieldNames : string; aFieldValues : array of const; aIsTimeStamped : Boolean): string; overload;
    function GetRecordValue(const aFieldName : string; aValue : TValue) : string;
    function GetModel : TEntityModel;
    function OpenQuery(const aQuery : string) : Integer; virtual; abstract;
    function ExecuteQuery(const aQuery : string) : Boolean; virtual; abstract;
  public
    constructor Create(aEntityDataBase : TEntityDataBase; aModel : TEntityModel; aQueryGenerator : IEntityQueryGenerator); virtual;
    property Model : TEntityModel read fModel write fModel;
    property HasResults : Boolean read fHasResults write fHasResults;
    function Eof : Boolean; virtual; abstract;
    function AddOrUpdate(aEntity : TEntity) : Boolean; virtual;
    function Add(aEntity : TEntity) : Boolean; virtual;
    function CountResults : Integer; virtual; abstract;
    function Update(aEntity : TEntity) : Boolean; overload; virtual;
    function Delete(aEntity : TEntity) : Boolean; overload; virtual;
    function Delete(const aWhere : string) : Boolean; overload; virtual;
    //LINQ queries
    {$IFDEF VALUE_FORMATPARAMS}
    function Where(const aFormatSQLWhere: string; const aValuesSQLWhere: array of TValue): IEntityLinqQuery<T>; overload;
    {$ELSE}
    function Where(const aFormatSQLWhere: string; const aValuesSQLWhere: array of const): IEntityLinqQuery<T>; overload;
    {$ENDIF}
    function Where(const aWhereClause : string) : IEntityLinqQuery<T>; overload;
    function SelectFirst : T; virtual;
    function SelectLast : T; virtual;
    function Select : IEntityResult<T>; overload; virtual;
    function Select(const aFieldNames : string) : IEntityResult<T>; overload; virtual;
    function SelectTop(aNumber : Integer) : IEntityResult<T>; virtual;
    function Sum(const aFieldName : string) : Int64; virtual;
    function Count : Int64; virtual;
    function Update(const aFieldNames : string; const aFieldValues : array of const) : Boolean; overload; virtual;
    function Delete : Boolean; overload; virtual;
    function OrderBy(const aFieldValues : string) : IEntityLinqQuery<T>;
    function OrderByDescending(const aFieldValues : string) : IEntityLinqQuery<T>;
  end;

implementation

{ TEntityQuery }

constructor TEntityQuery<T>.Create(aEntityDataBase : TEntityDataBase; aModel : TEntityModel; aQueryGenerator : IEntityQueryGenerator);
begin
  fFirstIteration := True;
  fEntityDataBase := aEntityDataBase;
  fModel := aModel;
  fWhereClause := '1=1';
  fSelectedFields := [];
  fQueryGenerator := aQueryGenerator;
  fHasResults := False;
end;

function TEntityQuery<T>.GetFieldValues(aEntity : TEntity; aExcludeAutoIDFields : Boolean) : TStringList;
var
  ctx: TRttiContext;
  attr : TCustomAttribute;
  rType: TRttiType;
  rProp: TRttiProperty;
  propertyname : string;
  propvalue : TValue;
  skip : Boolean;
begin
  Result := TStringList.Create;
  Result.Delimiter := ',';
  Result.StrictDelimiter := True;
  try
    rType := ctx.GetType(aEntity.ClassInfo);
    try
      for rProp in TRTTI.GetProperties(rType,roFirstBase) do
      begin
        propertyname := rProp.Name;
        if IsPublishedProp(aEntity,propertyname) then
        begin
          for attr in rProp.GetAttributes do
          begin
            if attr is MapField then propertyname := MapField(attr).Name;
          end;
          skip := False;
          propvalue := rProp.GetValue(aEntity);
          if CompareText(rProp.Name,fModel.PrimaryKey.Name) = 0 then
          begin
            if not aExcludeAutoIDFields then
            begin
              if (rProp.PropertyType.Name = 'TAutoID') and ((propvalue.IsEmpty) or (propvalue.AsInt64 = 0)) then skip := True;
            end
            else skip := True;
          end;
          if not skip then Result.Add(GetRecordValue(propertyname,propvalue));
        end;
      end;
    finally
      ctx.Free;
    end;
  except
    on E : Exception do
    begin
      raise Exception.CreateFmt('Error getting field values "%s" : %s',[Self.ClassName,e.Message]);
    end;
  end;
end;

function TEntityQuery<T>.GetModel: TEntityModel;
begin
  Result := fModel;
end;

function TEntityQuery<T>.GetRecordValue(const aFieldName: string; aValue: TValue): string;
var
  rttijson : TRTTIJson;
  json : TJSONObject;
  jpair : TJsonPair;
  //a : TTypeKind;
begin
  //a := aValue.Kind;
  case aValue.Kind of
    tkDynArray :
      begin
        rttijson := TRTTIJson.Create(TSerializeLevel.slPublishedProperty);
        try
          jpair := TJSONPair.Create(aFieldName,rttijson.SerializeValue(aValue));
          try
            Result := QuotedStr(jpair.JsonValue.ToJson);
          finally
            jpair.Free;
          end;
        finally
          rttijson.Free;
        end;
      end;
    tkString, tkLString, tkWString, tkUString : Result := QuotedStr(aValue.AsString);
    tkInteger : Result := aValue.AsInteger.ToString;
    tkInt64 : Result := aValue.AsInt64.ToString;
    tkFloat :
      begin
        if ((aValue.TypeInfo = TypeInfo(TDateTime)) or
           (aValue.TypeInfo = TypeInfo(TCreationDate)) or
           (aValue.TypeInfo = TypeInfo(TModifiedDate))) then
        begin
          if aValue.AsExtended = 0.0 then Result := 'null'
            else Result := QuotedStr(fQueryGenerator.DateTimeToDBField(aValue.AsExtended));
        end
        else if aValue.TypeInfo = TypeInfo(TDate) then
        begin
          Result := QuotedStr(aValue.AsExtended.ToString);
        end
        else if aValue.TypeInfo = TypeInfo(TTime) then
        begin
          Result := QuotedStr(aValue.AsExtended.ToString);
        end
        else Result := StringReplace(string(aValue.AsVariant),',','.',[]);
      end;
    tkEnumeration :
      begin
        if (aValue.TypeInfo = System.TypeInfo(Boolean)) then
        begin
          if CompareText(string(aValue.AsVariant),'true') = 0 then Result := '1'
            else Result := '0';
        end
        else
        begin
          Result := aValue.AsOrdinal.ToString;
        end;
      end;
    tkClass :
      begin
        rttijson := TRTTIJson.Create(TSerializeLevel.slPublishedProperty);
        try
          if aValue.IsEmpty then Exit('null');
          json := TJSONObject.Create;
          try
            json := rttijson.SerializeObject(aValue.AsObject);
            Result := QuotedStr(json.ToJSON);
          finally
            json.Free;
          end;
        finally
          rttijson.Free;
        end;
      end;
    tkRecord :
      begin
        if aValue.TypeInfo = System.TypeInfo(TGUID) then
        begin
          Result := QuotedStr(fQueryGenerator.GUIDToDBField(aValue.AsType<TGUID>));
        end
        else
        begin
          rttijson := TRTTIJson.Create(TSerializeLevel.slPublishedProperty);
          try
            if aValue.IsEmpty then Exit('null');
            jpair := TJSONPair.Create(aFieldName,rttijson.SerializeRecord(aValue));
            try
              Result := QuotedStr(jpair.ToJSON);
            finally
              jpair.Free;
            end;
          finally
            rttijson.Free;
          end;
        end;
      end;
    else Result := 'null';
  end;
end;

function TEntityQuery<T>.GetFieldsPairs(aEntity : TEntity): string;
var
  ctx: TRttiContext;
  attr : TCustomAttribute;
  rType: TRttiType;
  rProp: TRttiProperty;
  propertyname : string;
  propvalue : TValue;
  value : string;
begin
  Result := '';
  try
    rType := ctx.GetType(fModel.Table);
    try
      for rProp in TRTTI.GetProperties(rType,roFirstBase) do
      begin
        propertyname := rProp.Name;
        if IsPublishedProp(aEntity,propertyname) then
        begin
          for attr in rProp.GetAttributes do
          begin
            if  attr is MapField then propertyname := MapField(attr).Name;
          end;
          propvalue := rProp.GetValue(aEntity);
          value := GetRecordValue(propertyname,propvalue);
          if (propvalue.TypeInfo = TypeInfo(TCreationDate)) or (propvalue.TypeInfo = TypeInfo(TModifiedDate)) then
          begin
            if propvalue.AsExtended > 0 then Result := Result + Format('[%s]=%s,',[propertyname,value]);
          end
          else
          if not ((CompareText(propertyname,fModel.PrimaryKey.Name) = 0) and (rProp.PropertyType.Name = 'TAutoID')) then Result := Result + Format('[%s]=%s,',[propertyname,value]);
          //  else if propvalue.TypeInfo = TypeInfo(TModifiedDate) then value := fQueryGenerator.DateTimeToDBField(Now());

          //rProp.SetValue(Self,GetDBFieldValue(propertyname,rProp.GetValue(Self)));
        end;
      end;
      Result := RemoveLastChar(Result);
    finally
      ctx.Free;
    end;
  except
    on E : Exception do
    begin
      raise Exception.CreateFmt('Error getting fields "%s" : %s',[aEntity.ClassName,e.Message]);
    end;
  end;
end;

function TEntityQuery<T>.GetFieldsPairs(const aFieldNames : string; aFieldValues : array of const; aIsTimeStamped : Boolean): string;
var
  fieldname : string;
  value : string;
  i : Integer;
begin
  if aIsTimeStamped then Result := 'ModifiedDate = ' + fQueryGenerator.DateTimeToDBField(Now()) + ',';
  i := 0;
  for fieldname in aFieldNames.Split([',']) do
  begin
    case aFieldValues[i].VType of
      vtInteger : value := IntToStr(aFieldValues[i].VInteger);
      vtInt64 : value := IntToStr(aFieldValues[i].VInt64^);
      vtExtended : value := FloatToStr(aFieldValues[i].VExtended^);
      vtBoolean : value := BoolToStr(aFieldValues[i].VBoolean);
      vtWideString : value := DbQuotedStr(string(aFieldValues[i].VWideString^));
      {$IFNDEF NEXTGEN}
      vtAnsiString : value := DbQuotedStr(AnsiString(aFieldValues[i].VAnsiString));
      vtString : value := DbQuotedStr(aFieldValues[i].VString^);
      {$ENDIF}
      vtChar : value := DbQuotedStr(aFieldValues[i].VChar);
      vtPChar : value := string(aFieldValues[i].VPChar).QuotedString;
    else value := DbQuotedStr(string(aFieldValues[i].VUnicodeString));
    end;
    Result := Result + fieldname + '=' + value + ',';
    Inc(i);
  end;
  RemoveLastChar(Result);
end;

function TEntityQuery<T>.FillRecordFromDB(aEntity : T) : T;
var
  ctx: TRttiContext;
  attr : TCustomAttribute;
  rType: TRttiType;
  rProp: TRttiProperty;
  propertyname : string;
  rvalue : TValue;
  dbfield : TDBField;
  IsFilterSelect : Boolean;
  skip : Boolean;
begin
  try
    {$IFDEF DEBUG_ENTITY}
    if aEntity <> nil then TDebugger.TimeIt(Self,'FillRecordFromDB',aEntity.ClassName);
    {$ENDIF}

    if aEntity = nil then aEntity := T.Create;
    Result := aEntity;

    IsFilterSelect := not IsEmptyArray(fSelectedFields);
    rType := ctx.GetType(fModel.Table);
    try
      for rProp in TRTTI.GetProperties(rType,roFirstBase) do
      begin
        propertyname := rProp.Name;
        if IsPublishedProp(aEntity,propertyname) then
        begin
          for attr in rProp.GetAttributes do
          begin
            if  attr is MapField then propertyname := MapField(attr).Name;
          end;
          skip := False;
          if (IsFilterSelect) and (not StrInArray(propertyname,fSelectedFields)) then skip := True;
          if not skip then rvalue := GetDBFieldValue(propertyname,rProp.GetValue(TEntity(aEntity)))
            else rvalue := nil;
          if not rvalue.IsEmpty then rProp.SetValue(TEntity(aEntity),rvalue);
        end;
      end;
    finally
      ctx.Free;
    end;
  except
    on E : Exception do
    begin
      raise Exception.CreateFmt('Error filling Entity "%s" -> field "%s" : %s',[fModel.TableName,propertyname,e.Message]);
    end;
  end;
end;

function TEntityQuery<T>.GetDBFieldValue(const aFieldName : string; aValue : TValue): TValue;
var
  IsNull : Boolean;
  fieldvalue : variant;
  rttijson : TRTTIJson;
  json : TJsonObject;
  jArray : TJSONArray;
  //a : TTypeKind;
begin
  fieldvalue := GetFieldValue(aFieldName);
  IsNull := IsEmptyOrNull(fieldvalue);
  //a := aValue.Kind;
  try
    case aValue.Kind of
      tkDynArray :
        begin
          if IsNull then Exit(nil);
          rttijson := TRTTIJson.Create(TSerializeLevel.slPublishedProperty);
          try
            jArray := TJSONObject.ParseJSONValue(fieldvalue) as TJSONArray;
            try
              Result := rttijson.DeserializeDynArray(aValue.TypeInfo,Self,jArray);
            finally
              jArray.Free;
            end;
          finally
            rttijson.Free;
          end;
        end;
      tkString, tkLString, tkWString, tkUString :
        begin
          if not IsNull then Result := string(fieldvalue)
            else Result := '';
        end;
      tkChar, tkWChar :
        begin
          if not IsNull then Result := string(fieldvalue)
            else Result := '';
        end;
      tkInteger :
        begin
          if not IsNull then Result := Integer(fieldvalue)
            else Result := 0;
        end;
      tkInt64 :
        begin
          if not IsNull then Result := Int64(fieldvalue)
            else Result := 0;
        end;
      tkFloat :
        begin
          if ((aValue.TypeInfo = TypeInfo(TDateTime)) or
             (aValue.TypeInfo = TypeInfo(TCreationDate)) or
             (aValue.TypeInfo = TypeInfo(TModifiedDate))) then
          begin
            if not IsNull then
            begin
              if not Self.ClassName.StartsWith('TFireDACEntityQuery') then Result := fQueryGenerator.DBFieldToDateTime(fieldvalue)
                else Result := StrToDateTime(fieldvalue);
            end
            else Result := 0;
          end
          else if aValue.TypeInfo = TypeInfo(TDate) then
          begin
            if not IsNull then Result := TDate(fieldvalue)
              else Result := 0;
          end
          else if aValue.TypeInfo = TypeInfo(TTime) then
          begin
            if not IsNull then Result := TTime(fieldvalue)
              else Result := 0;
          end
          else if not IsNull then Result := Extended(fieldvalue)
            else Result := 0;
        end;
      tkEnumeration :
        begin
          if (aValue.TypeInfo = System.TypeInfo(Boolean)) then
          begin
            if not IsNull then Result := Boolean(fieldvalue)
              else Result := False;
          end
          else
          begin
            if not IsNull then TValue.Make(fieldvalue,aValue.TypeInfo,Result)
              else TValue.Make(0,aValue.TypeInfo, Result);
          end;
        end;
      tkSet :
        begin
          //Result.JsonValue := TJSONString.Create(aValue.ToString);
        end;
      tkClass :
        begin
          if IsNull then Exit(nil);
          rttijson := TRTTIJson.Create(TSerializeLevel.slPublishedProperty);
          try
            json := TJSONObject(TJSONObject.ParseJSONValue(fieldvalue)) ;
            try
              Result := rttijson.DeserializeObject(aValue.AsObject,json);
            finally
              json.Free;
            end;
          finally
            rttijson.Free;
          end;
        end;
      tkRecord :
        begin
          if IsNull then Exit(nil);

          if aValue.TypeInfo = System.TypeInfo(TGUID) then
          begin
            Result := TValue.From<TGUID>(fQueryGenerator.DBFieldToGUID(fieldvalue));
          end
          else
          begin
            rttijson := TRTTIJson.Create(TSerializeLevel.slPublishedProperty);
            try
              json := TJSONObject.ParseJSONValue('{'+fieldvalue+'}') as TJSONObject;
              try
                Result := rttijson.DeserializeRecord(aValue,Self,json.GetValue(aFieldName) as TJSONObject);
              finally
                json.Free;
              end;
            finally
              rttijson.Free;
            end;
          end;
        end;
      tkMethod, tkPointer, tkClassRef ,tkInterface, tkProcedure :
        begin
          //skip these properties
        end
    else
      begin
        raise Exception.Create(Format('Error %s %s',[aFieldName,GetTypeName(aValue.TypeInfo)]));
      end;
    end;
  except
    on E : Exception do
    begin
      if aValue.Kind = tkClass then raise Exception.CreateFmt('Serialize error class "%s.%s" : %s',[aFieldName,aValue.ToString,e.Message])
        else raise Exception.CreateFmt('Serialize error property "%s=%s" : %s',[aFieldName,aValue.ToString,e.Message]);
    end;
  end;
end;

function TEntityQuery<T>.Add(aEntity: TEntity): Boolean;
var
  sqlfields : TStringList;
  sqlvalues : TStringList;
begin
  {$IFDEF DEBUG_ENTITY}
    TDebugger.TimeIt(Self,'Add',aEntity.ClassName);
  {$ENDIF}
  Result := False;
  try
    if aEntity is TEntityTS then TEntityTS(aEntity).CreationDate := Now();
    sqlfields := fModel.GetFieldNames(aEntity,False);
    try
      sqlvalues := GetFieldValues(aEntity,False);
      try
        Result := ExecuteQuery(fQueryGenerator.Add(fModel.TableName,sqlfields.CommaText,CommaText(sqlvalues)));
      finally
        sqlvalues.Free;
      end;
    finally
      sqlfields.Free;
    end;
  except
    on E : Exception do raise EEntityCreationError.CreateFmt('Insert error: %s',[e.message]);
  end;
end;

function TEntityQuery<T>.AddOrUpdate(aEntity: TEntity): Boolean;
var
  sqlfields : TStringList;
  sqlvalues : TStringList;
  primarykey : Variant;
begin
  {$IFDEF DEBUG_ENTITY}
    TDebugger.TimeIt(Self,'AddOrUpdate',aEntity.ClassName);
  {$ENDIF}
  Result := False;
  try
      primarykey := aEntity.FieldByName(fModel.PrimaryKey.Name);
//    if fQueryGenerator.Name <> 'MSSQL' then
//    begin
      {$IFDEF VALUE_FORMATPARAMS}
      if (VarIsEmpty(primarykey)) or (Where(Format('%s = ?',[fModel.PrimaryKey.Name]),[TValue.FromVariant(primarykey)]).Count = 0) then
      {$ELSE}
      if (VarIsEmpty(primarykey)) or (Where(Format('%s = ?',[fModel.PrimaryKey.Name]),[primarykey]).Count = 0) then
      {$ENDIF}
      begin
        Result := Add(aEntity);
      end
      else
      begin
        Result := Update(aEntity);
      end;
//    end
//    else
//    begin
//      sqlfields := fModel.GetFieldNames(aDAORecord,False);
//      try
//        sqlvalues := GetFieldValues(aDAORecord,False);
//        try
//          Result := ExecuteQuery(fQueryGenerator.AddOrUpdate(fModel.TableName,sqlfields.CommaText,CommaText(sqlvalues)));
//        finally
//          sqlvalues.Free;
//        end;
//      finally
//        sqlfields.Free;
//      end;
//    end;
  except
    on E : Exception do raise EEntityCreationError.CreateFmt('AddOrUpdate error: %s',[e.message]);
  end;
end;


function TEntityQuery<T>.BoolToSQLString(aBoolean : Boolean) : string;
const
  boolstrs: array [boolean] of String = ('0', '1');
begin
  Result := boolstrs[Ord(aBoolean) <> 0];
end;

function TEntityQuery<T>.Delete(aEntity : TEntity): Boolean;
begin
  {$IFDEF DEBUG_ENTITY}
    TDebugger.TimeIt(Self,'Delete',aEntity.ClassName);
  {$ENDIF}
  try
    Result := ExecuteQuery(fQueryGenerator.Delete(fModel.TableName,Format('%s=%s',[fModel.PrimaryKey.Name,aEntity.FieldByName(fModel.PrimaryKey.Name)])));
  except
    on E : Exception do raise EEntityDeleteError.CreateFmt('Delete error: %s',[e.message]);
  end;
end;

function TEntityQuery<T>.Delete(const aWhere: string): Boolean;
var
  query : string;
begin
  try
    query := fQueryGenerator.Delete(fModel.TableName,aWhere);
    {$IFDEF DEBUG_ENTITY}
    TDebugger.TimeIt(Self,'Delete',query);
    {$ENDIF}
    Result := ExecuteQuery(query);
  except
    on E : Exception do raise EEntityDeleteError.CreateFmt('Delete error: %s',[e.message]);
  end;
end;

{ LINQ queries }

function TEntityQuery<T>.Count: Int64;
var
  query : string;
begin
  try
    query := fQueryGenerator.Count(fModel.TableName,fWhereClause);
    {$IFDEF DEBUG_ENTITY}
    TDebugger.TimeIt(Self,'Count',query);
    {$ENDIF}
    if OpenQuery(query) > 0 then Result := GetFieldValue('cnt')
      else Result := 0;
    HasResults := False;
  except
    on E : Exception do raise EEntitySelectError.CreateFmt('Select count error: %s',[e.message]);
  end;
end;

{$IFDEF VALUE_FORMATPARAMS}
function TEntityQuery<T>.FormatParams(const aWhereClause : string; aWhereParams : array of TValue) : string;
var
  i : Integer;
  value : string;
  vari : variant;
begin
  Result := aWhereClause;
  if aWhereClause = '' then
  begin
    Result := '1 = 1';
    Exit;
  end;
  for i := 0 to aWhereClause.CountChar('?') - 1 do
  begin
    case aWhereParams[i].Kind of
      tkInteger : value := aWhereParams[i].AsInteger.ToString;
      tkInt64 : value := aWhereParams[i].AsInt64.ToString;
      tkEnumeration :
        begin
          if (aWhereParams[i].TypeInfo = System.TypeInfo(Boolean)) then
          begin
            {$IFDEF DELPHIRX10_UP}
            value := BoolToSQLString(aWhereParams[i].AsBoolean);
            {$ELSE}
            if aWhereParams[i].AsBoolean then value := BoolToSQLString(True)
              else value := BoolToSQLString(False)
            {$ENDIF}
          end
          else
          begin
            //if fUseEnumNames then Result := TJSONString.Create(aValue.ToString)
            //  else Result := GetEnumValue(aWhereParams[i].TypeInfo,aWhereParams[i].AsString);
            value := aWhereParams[i].AsInteger.ToString;
          end;
        end;
      tkString, tkLString, tkWString, tkUString : value := fQueryGenerator.QuotedStr(aWhereParams[i].AsString);
      tkChar, tkWChar : value := fQueryGenerator.QuotedStr(aWhereParams[i].AsString);
      tkFloat :
        begin
          if aWhereParams[i].TypeInfo = TypeInfo(TDateTime) then
          begin
            if aWhereParams[i].AsExtended <> 0.0 then value := fQueryGenerator.DateTimeToDBField(aWhereParams[i].AsExtended);
          end
          else if aWhereParams[i].TypeInfo = TypeInfo(TDate) then
          begin
            if aWhereParams[i].AsExtended <> 0.0 then value := DateToStr(aWhereParams[i].AsExtended);
          end
          else if aWhereParams[i].TypeInfo = TypeInfo(TTime) then
          begin
            value := TimeToStr(aWhereParams[i].AsExtended);
          end
          else
          begin
            value := aWhereParams[i].AsExtended.ToString;
            value := StringReplace(value,',','.',[]);
          end;
        end;
      tkVariant :
      begin
        vari := aWhereParams[i].AsVariant;
        case VarType(vari) of
          varInteger,varInt64 : value := IntToStr(vari);
          varDouble : value := FloatToStr(vari);
          varDate : value := fQueryGenerator.DateTimeToDBField(vari);
          else value := string(vari);
        end;
      end
    else value := fQueryGenerator.QuotedStr(string(aWhereParams[i].AsString));
    end;
    Result := StringReplace(Result,'?',value,[]);
  end;
end;
{$ELSE}
function TEntityQuery<T>.FormatParams(const aWhereClause: string; aWhereParams: array of const): string;
var
  i : Integer;
  value : string;
  vari : variant;
begin
  Result := aWhereClause;
  if aWhereClause = '' then
  begin
    Result := '1 = 1';
    Exit;
  end;
  for i := 0 to aWhereClause.CountChar('?') - 1 do
  begin
    case aWhereParams[i].VType of
      vtInteger : value := IntToStr(aWhereParams[i].VInteger);
      vtInt64 : value := IntToStr(aWhereParams[i].VInt64^);
      vtExtended :
        begin
          value := FloatToStr(aWhereParams[i].VExtended^);
          value := StringReplace(value,',','.',[]);
        end;
      vtBoolean : value := BoolToSQLString(aWhereParams[i].VBoolean);
      vtWideString : value := fQueryGenerator.QuotedStr(string(aWhereParams[i].VWideString^));
      {$IFNDEF NEXTGEN}
      vtAnsiString : value := fQueryGenerator.QuotedStr(AnsiString(aWhereParams[i].VAnsiString));
      vtString : value := fQueryGenerator.QuotedStr(aWhereParams[i].VString^);
      {$ENDIF}
      vtChar : value := fQueryGenerator.QuotedStr(aWhereParams[i].VChar);
      vtPChar : value := fQueryGenerator.QuotedStr(string(aWhereParams[i].VPChar));
      vtWideChar : value := fQueryGenerator.QuotedStr(WideChar(aWhereParams[i].VWideChar));
      vtVariant :
      begin
        vari := aWhereParams[i].VVariant^;
        case VarType(vari) of
          varInteger,varInt64 : value := IntToStr(vari);
          varDouble : value := FloatToStr(vari);
          varDate : value := fQueryGenerator.DateTimeToDBField(vari);
          else value := string(vari);
        end;
      end
    else value := fQueryGenerator.QuotedStr(string(aWhereParams[i].VUnicodeString));
    end;
    Result := StringReplace(Result,'?',value,[]);
  end;
end;
{$ENDIF}

function TEntityQuery<T>.OrderBy(const aFieldValues: string): IEntityLinqQuery<T>;
begin
  Result := Self;
  fOrderClause := aFieldValues;
  fOrderAsc := True;
end;

function TEntityQuery<T>.OrderByDescending(const aFieldValues: string): IEntityLinqQuery<T>;
begin
  Result := Self;
  fOrderClause := aFieldValues;
  fOrderAsc := False;
end;

function TEntityQuery<T>.Select: IEntityResult<T>;
var
  query : string;
begin
  try
    query := fQueryGenerator.Select(fModel.TableName,'',0,fWhereClause,fOrderClause,fOrderAsc);
    {$IFDEF DEBUG_ENTITY}
    TDebugger.TimeIt(Self,'Select',query);
    {$ENDIF}
    OpenQuery(query);
    Result := TEntityResult<T>.Create(Self);
  except
    on E : Exception do raise EEntitySelectError.CreateFmt('Select error: %s',[e.message]);
  end;
end;

function TEntityQuery<T>.Select(const aFieldNames: string): IEntityResult<T>;
var
  query : string;
  filter : string;
begin
  try
    for filter in aFieldNames.Split([',']) do fSelectedFields := fSelectedFields + [filter];
    query := fQueryGenerator.Select(fModel.TableName,aFieldNames,0,fWhereClause,fOrderClause,fOrderAsc);
    {$IFDEF DEBUG_ENTITY}
    TDebugger.TimeIt(Self,'Select',query);
    {$ENDIF}
    OpenQuery(query);
    Result := TEntityResult<T>.Create(Self);
  except
    on E : Exception do raise EEntitySelectError.CreateFmt('Select error: %s',[e.message]);
  end;
end;

function TEntityQuery<T>.SelectFirst: T;
var
  query : string;
begin
  try
    query := fQueryGenerator.Select(fModel.TableName,'',1,fWhereClause,fOrderClause,fOrderAsc);
    {$IFDEF DEBUG_ENTITY}
    TDebugger.TimeIt(Self,'SelectFirst',query);
    {$ENDIF}
    OpenQuery(query);
    Self.Movenext;
    Result := Self.GetCurrent;
  except
    on E : Exception do raise EEntitySelectError.CreateFmt('Select error: %s',[e.message]);
  end;
end;

function TEntityQuery<T>.SelectLast: T;
var
  query : string;
begin
  try
    query := fQueryGenerator.Select(fModel.TableName,'',1,fWhereClause,fOrderClause,not fOrderAsc);
    {$IFDEF DEBUG_ENTITY}
    TDebugger.TimeIt(Self,'SelectLast',query);
    {$ENDIF}
    OpenQuery(query);
    Self.Movenext;
    Result := Self.GetCurrent;
  except
    on E : Exception do raise EEntitySelectError.CreateFmt('Select error: %s',[e.message]);
  end;
end;

function TEntityQuery<T>.SelectTop(aNumber: Integer): IEntityResult<T>;
var
  query : string;
begin
  try
    query := fQueryGenerator.Select(fModel.TableName,'',aNumber,fWhereClause,fOrderClause,fOrderAsc);
    {$IFDEF DEBUG_ENTITY}
    TDebugger.TimeIt(Self,'SelectTop',query);
    {$ENDIF}
    OpenQuery(query);
    Result := TEntityResult<T>.Create(Self);
  except
    on E : Exception do raise EEntitySelectError.CreateFmt('Select error: %s',[e.message]);
  end;
end;

function TEntityQuery<T>.Sum(const aFieldName: string): Int64;
var
  query : string;
begin
  try
    query := fQueryGenerator.Sum(fModel.TableName,aFieldName,fWhereClause);
    {$IFDEF DEBUG_ENTITY}
    TDebugger.TimeIt(Self,'Sum',query);
    {$ENDIF}
    if OpenQuery(query) > 0 then Result := GetFieldValue('cnt')
  except
    on E : Exception do raise EEntitySelectError.CreateFmt('Select error: %s',[e.message]);
  end;
end;

function TEntityQuery<T>.Update(aEntity: TEntity): Boolean;
var
  query : string;
begin
  try
    if aEntity is TEntityTS then TEntityTS(aEntity).ModifiedDate := Now();
    query := fQueryGenerator.Update(fModel.TableName,GetFieldsPairs(aEntity),
                           Format('%s=%s',[fModel.PrimaryKey.Name,aEntity.FieldByName(fModel.PrimaryKey.Name)]));
    {$IFDEF DEBUG_ENTITY}
    TDebugger.TimeIt(Self,'Update',query);
    {$ENDIF}
    Result := ExecuteQuery(query);
  except
    on E : Exception do raise EEntityUpdateError.CreateFmt('Update error: %s',[e.message]);
  end;
end;

function TEntityQuery<T>.Update(const aFieldNames: string; const aFieldValues: array of const): Boolean;
var
  stamped : Boolean;
  query : string;
begin
  try
    query := fQueryGenerator.Update(fModel.TableName,GetFieldsPairs(aFieldNames,aFieldValues,stamped),fWhereClause);
    {$IFDEF DEBUG_ENTITY}
    TDebugger.TimeIt(Self,'Update',query);
    {$ENDIF}
    if TypeInfo(T) = TypeInfo(TEntityTS) then stamped := True;
    Result := ExecuteQuery(query);
  except
    on E : Exception do raise EEntityUpdateError.CreateFmt('Update error: %s',[e.message]);
  end;
end;

function TEntityQuery<T>.Where(const aWhereClause: string): IEntityLinqQuery<T>;
begin
  Result := Self;
  fWhereClause := aWhereClause;
end;

{$IFDEF VALUE_FORMATPARAMS}
function TEntityQuery<T>.Where(const aFormatSQLWhere: string; const aValuesSQLWhere: array of TValue): IEntityLinqQuery<T>;
{$ELSE}
function TEntityQuery<T>.Where(const aFormatSQLWhere: string; const aValuesSQLWhere: array of const): IEntityLinqQuery<T>;
{$ENDIF}
begin
  Result := Self;
  fWhereClause := FormatParams(aFormatSQLWhere,aValuesSQLWhere);
end;

function TEntityQuery<T>.Delete: Boolean;
var
  query : string;
begin
  try
    query := fQueryGenerator.Delete(fModel.TableName,fWhereClause);
    {$IFDEF DEBUG_ENTITY}
    TDebugger.TimeIt(Self,'Delete',query);
    {$ENDIF}
    Result := ExecuteQuery(query);
  except
    on E : Exception do raise EEntityUpdateError.CreateFmt('Delete error: %s',[e.message]);
  end;
end;

end.
