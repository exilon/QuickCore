{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Entity.QueryGenerator.MSSQL
  Description : Core Entity MSSQL Query Generator
  Author      : Kike Pérez
  Version     : 1.1
  Created     : 22/06/2018
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

unit Quick.Core.Entity.QueryGenerator.MSSQL;

interface

{$i QuickCore.inc}

uses
  Classes,
  SysUtils,
  Quick.Commons,
  Quick.Core.Entity.DAO;

type

  TMSSQLQueryGenerator = class(TEntityQueryGenerator,IEntityQueryGenerator)
  public
    function Name : string;
    function CreateTable(const aTable : TEntityModel) : string;
    function ExistsTable(aModel: TEntityModel) : string;
    function ExistsColumn(aModel : TEntityModel; const aFieldName : string) : string;
    function AddColumn(aModel : TEntityModel; aField : TEntityField) : string;
    function SetPrimaryKey(aModel : TEntityModel) : string;
    function CreateIndex(aModel : TEntityModel; aIndex : TEntityIndex) : string;
    function Select(const aTableName, aFieldNames : string; aLimit : Integer; const aWhere : string; aOrderFields : string; aOrderAsc : Boolean) : string;
    function Sum(const aTableName, aFieldName, aWhere: string): string;
    function Count(const aTableName : string; const aWhere : string) : string;
    function Add(const aTableName: string; const aFieldNames, aFieldValues : string) : string;
    function AddOrUpdate(const aTableName: string; const aFieldNames, aFieldValues : string) : string;
    function Update(const aTableName, aFieldPairs, aWhere : string) : string;
    function Delete(const aTableName : string; const aWhere : string) : string;
    function DateTimeToDBField(aDateTime : TDateTime) : string;
    function DBFieldToDateTime(const aValue : string) : TDateTime;
    function QuotedStr(const aValue: string): string; override;
    function DBFieldToGUID(const aValue : string) : TGUID;
    function GUIDToDBField(aGuid : TGUID) : string;
  end;

implementation

const
  {$IFNDEF FPC}
  DBDATATYPES : array of string = ['varchar(%d)','varchar(max)','char(%d)','int','integer','bigint','decimal(%d,%d)','bit','date','time','datetime','datetime','datetime','uniqueidentifier'];
  {$ELSE}
  DBDATATYPES : array[0..10] of string = ('varchar(%d)','varchar(max)','char(%d)','int','integer','bigint','decimal(%d,%d)','bit','date','time','datetime','datetime','datetime','uniqueidentifier');
  {$ENDIF}

{ TMSSQLQueryGenerator }

function TMSSQLQueryGenerator.Add(const aTableName, aFieldNames, aFieldValues: string): string;
var
  querytext : TStringList;
begin
  querytext := TStringList.Create;
  try
    querytext.Add('BEGIN TRY');
    querytext.Add(Format('INSERT INTO [%s]',[aTableName]));
    querytext.Add(Format('(%s)',[aFieldNames]));
    querytext.Add(Format('VALUES(%s)',[aFieldValues]));
    querytext.Add('END TRY');
    querytext.Add('BEGIN CATCH');
        querytext.Add(Format('SET IDENTITY_INSERT [%s] ON',[aTableName]));
        querytext.Add(Format('INSERT INTO [%s]',[aTableName]));
        querytext.Add(Format('(%s)',[aFieldNames]));
        querytext.Add(Format('VALUES(%s)',[aFieldValues]));
        querytext.Add(Format('SET IDENTITY_INSERT [%s] OFF',[aTableName]));
    querytext.Add('END CATCH');
    Result := querytext.Text;
  finally
    querytext.Free;
  end;
end;

function TMSSQLQueryGenerator.AddColumn(aModel: TEntityModel; aField: TEntityField) : string;
var
  datatype : string;
  querytext : TStringList;
begin
  querytext := TStringList.Create;
  try
    querytext.Add(Format('ALTER TABLE [%s]',[aModel.TableName]));
    if aField.DataType = dtFloat then
    begin
      datatype := Format(DBDATATYPES[Integer(aField.DataType)],[aField.DataSize,aField.Precision])
    end
    else
    begin
      if aField.DataSize > 0 then datatype := Format(DBDATATYPES[Integer(aField.DataType)],[aField.DataSize])
        else datatype := DBDATATYPES[Integer(aField.DataType)];
    end;
    querytext.Add(Format('ADD [%s] %s',[aField.Name,datatype]));
    Result := querytext.Text;
  finally
    querytext.Free;
  end;
end;

function TMSSQLQueryGenerator.CreateIndex(aModel: TEntityModel; aIndex: TEntityIndex) : string;
var
  querytext : TStringList;
begin
  querytext := TStringList.Create;
  try
    querytext.Add(Format('IF NOT EXISTS(SELECT * FROM sys.indexes WHERE name = ''PK_%s'' AND object_id = OBJECT_ID(''%s''))',[aIndex.FieldNames[0],aModel.TableName]));
    querytext.Add('BEGIN');
    querytext.Add(Format('CREATE INDEX PK_%s ON [%s] (%s);',[aIndex.FieldNames[0],aModel.TableName,aIndex.FieldNames[0]]));
    querytext.Add('END');
    Result := querytext.Text;
  finally
    querytext.Free;
  end;
end;

function TMSSQLQueryGenerator.CreateTable(const aTable: TEntityModel) : string;
var
  field : TEntityField;
  datatype : string;
  querytext : TStringList;
begin
  querytext := TStringList.Create;
  try
    querytext.Add(Format('IF NOT EXISTS (SELECT name FROM sys.tables WHERE name = ''%s'')',[aTable.TableName]));
    querytext.Add(Format('CREATE TABLE [%s] (',[aTable.TableName]));

    for field in aTable.Fields do
    begin
      if field.DataType = dtFloat then
      begin
        datatype := Format(DBDATATYPES[Integer(field.DataType)],[field.DataSize,field.Precision])
      end
      else
      begin
        if field.DataSize > 0 then datatype := Format(DBDATATYPES[Integer(field.DataType)],[field.DataSize])
          else datatype := DBDATATYPES[Integer(field.DataType)];
      end;
      if (field.DataType = dtAutoID) and (field.IsPrimaryKey) then querytext.Add(Format('[%s] %s IDENTITY(1,1),',[field.Name,datatype]))
        else querytext.Add(Format('[%s] %s,',[field.Name,datatype]))
    end;
    if not aTable.PrimaryKey.Name.IsEmpty then
    begin
      querytext.Add(Format('PRIMARY KEY(%s)',[aTable.PrimaryKey.Name]));
    end
    else querytext[querytext.Count-1] := Copy(querytext[querytext.Count-1],1,querytext[querytext.Count-1].Length-1);
    querytext.Add(')');
    Result := querytext.Text;
  finally
    querytext.Free;
  end;
end;

function TMSSQLQueryGenerator.ExistsTable(aModel: TEntityModel) : string;
var
  querytext : TStringList;
begin
  querytext := TStringList.Create;
  try
    querytext.Add('SELECT Name FROM sys.tables');
    querytext.Add(Format('WHERE name = ''%s''',[aModel.TableName]));
    Result := querytext.Text;
  finally
    querytext.Free;
  end;
end;

function TMSSQLQueryGenerator.Name: string;
begin
  Result := 'MSSQL';
end;

function TMSSQLQueryGenerator.QuotedStr(const aValue: string): string;
begin
  Result := '''' + aValue + '''';
end;

function TMSSQLQueryGenerator.ExistsColumn(aModel: TEntityModel; const aFieldName: string) : string;
var
  querytext : TStringList;
begin
  querytext := TStringList.Create;
  try
    querytext.Add('SELECT Name FROM sys.columns');
    querytext.Add(Format('WHERE object_id = OBJECT_ID(''%s'')',[aModel.TableName]));
    Result := querytext.Text;
  finally
    querytext.Free;
  end;
end;

function TMSSQLQueryGenerator.SetPrimaryKey(aModel: TEntityModel) : string;
var
  querytext : TStringList;
begin
  querytext := TStringList.Create;
  try
    querytext.Add('IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS');
    querytext.Add(Format('WHERE CONSTRAINT_TYPE = ''PRIMARY KEY'' AND TABLE_NAME = ''%s'' AND TABLE_SCHEMA =''dbo'')',[aModel.TableName]));
    querytext.Add('BEGIN');
    querytext.Add(Format('ALTER TABLE [%s] ADD CONSTRAINT PK_%s PRIMARY KEY (%s)',[aModel.TableName,aModel.PrimaryKey.Name,aModel.PrimaryKey.Name]));
    querytext.Add('END');
    Result := querytext.Text;
  finally
    querytext.Free;
  end;
end;

function TMSSQLQueryGenerator.Sum(const aTableName, aFieldName, aWhere: string): string;
var
  querytext : TStringList;
begin
  querytext := TStringList.Create;
  try
    querytext.Add(Format('SELECT SUM (%s) FROM [%s] WHERE %s',[aTableName,aFieldName,aWhere]));
    Result := querytext.Text;
  finally
    querytext.Free;
  end;
end;

function TMSSQLQueryGenerator.Select(const aTableName, aFieldNames: string; aLimit: Integer;
  const aWhere: string; aOrderFields: string; aOrderAsc: Boolean) : string;
var
  orderdir : string;
  querytext : TStringList;
  toplimit : string;
begin
  querytext := TStringList.Create;
  try
    //define limited query clause
    if aLimit > 0 then toplimit := Format('TOP %d ',[aLimit])
      else toplimit := '';
    //define select-where clauses
    if aFieldNames.IsEmpty then querytext.Add(Format('SELECT %s* FROM [%s] WHERE %s',[toplimit,aTableName,aWhere]))
      else querytext.Add(Format('SELECT %s%s FROM [%s] WHERE %s',[toplimit,aFieldNames,aTableName,aWhere]));
    //define orderby clause
    if not aOrderFields.IsEmpty then
    begin
      if aOrderAsc then orderdir := 'ASC'
        else orderdir := 'DESC';
      querytext.Add(Format('ORDER BY %s %s',[aOrderFields,orderdir]));
    end;
    Result := querytext.Text;
  finally
    querytext.Free;
  end;
end;

function TMSSQLQueryGenerator.AddOrUpdate(const aTableName: string; const aFieldNames, aFieldValues : string) : string;
begin
  //no add or update
end;

function TMSSQLQueryGenerator.Update(const aTableName, aFieldPairs, aWhere : string) : string;
var
  querytext : TStringList;
begin
  querytext := TStringList.Create;
  try
    querytext.Add(Format('UPDATE [%s]',[aTableName]));
    querytext.Add(Format('SET %s',[aFieldPairs]));
    querytext.Add(Format('WHERE %s',[aWhere]));
    Result := querytext.Text;
  finally
    querytext.Free;
  end;
end;

function TMSSQLQueryGenerator.Count(const aTableName : string; const aWhere : string) : string;
begin
  Result := Format('SELECT COUNT(*) AS cnt FROM [%s] WHERE %s',[aTableName,aWhere]);
end;

function TMSSQLQueryGenerator.DateTimeToDBField(aDateTime: TDateTime): string;
begin
  Result := FormatDateTime('YYYYMMDD hh:nn:ss',aDateTime);
end;

function TMSSQLQueryGenerator.DBFieldToDateTime(const aValue: string): TDateTime;
begin
  Result := StrToDateTime(aValue);
end;

function TMSSQLQueryGenerator.Delete(const aTableName, aWhere: string) : string;
begin
  Result := Format('DELETE FROM [%s] WHERE %s',[aTableName,aWhere]);
end;

function TMSSQLQueryGenerator.DBFieldToGUID(const aValue: string): TGUID;
begin
  if aValue.Contains('{') then Result := StringToGUID(aValue)
    else  Result := StringToGUID('{' + aValue + '{');
end;

function TMSSQLQueryGenerator.GUIDToDBField(aGuid: TGUID): string;
begin
  Result := GUIDToString(aGuid);
  exit;
  SetLength(Result, 38);
  StrLFmt(PChar(Result), 38,'%.8x-%.4x-%.4x-%.2x%.2x-%.2x%.2x%.2x%.2x%.2x%.2x',   // do not localize
    [aGuid.D1, aGuid.D2, aGuid.D3, aGuid.D4[0], aGuid.D4[1], aGuid.D4[2], aGuid.D4[3],
    aGuid.D4[4], aGuid.D4[5], aGuid.D4[6], aGuid.D4[7]]);
end;

end.
