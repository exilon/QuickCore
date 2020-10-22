{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Entity.QueryGenerator.MySQL
  Description : Core Entity MySQL Query Generator
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 22/11/2019
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

unit Quick.Core.Entity.QueryGenerator.MySQL;

{$i QuickCore.inc}

interface

uses
  Classes,
  SysUtils,
  Quick.Commons,
  Quick.Core.Entity.DAO;

type

  TMySQLQueryGenerator = class(TEntityQueryGenerator,IEntityQueryGenerator)
  public
    function Name : string;
    function CreateTable(const aTable : TEntityModel) : string;
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
    function DBFieldToGUID(const aValue : string) : TGUID;
    function GUIDToDBField(aGuid : TGUID) : string;
  end;

implementation

const
  {$IFNDEF FPC}
  DBDATATYPES : array of string = ['varchar(%d)','text','char(%d)','int','integer','bigint','decimal(%d,%d)','bit','date','time','datetime','datetime','datetime','varchar(38)'];
  {$ELSE}
  DBDATATYPES : array[0..10] of string = ('varchar(%d)','text','char(%d)','int','integer','bigint','decimal(%d,%d)','bit','date','time','datetime','datetime','datetime','varchar(38)');
  {$ENDIF}

{ TSQLiteQueryGenerator }

function TMySQLQueryGenerator.AddColumn(aModel: TEntityModel; aField: TEntityField) : string;
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

function TMySQLQueryGenerator.CreateIndex(aModel: TEntityModel; aIndex: TEntityIndex) : string;
begin
  Result := Format('CREATE INDEX IF NOT EXISTS PK_%s ON %s (%s)',[aIndex.FieldNames[0],aModel.TableName,aIndex.FieldNames[0]]);
end;

function TMySQLQueryGenerator.CreateTable(const aTable: TEntityModel) : string;
var
  field : TEntityField;
  datatype : string;
  querytext : TStringList;
begin
  querytext := TStringList.Create;
  try
    querytext.Add(Format('CREATE TABLE IF NOT EXISTS [%s] (',[aTable.TableName]));

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
      querytext.Add(Format('[%s] %s,',[field.Name,datatype]));
    end;
    if not aTable.PrimaryKey.Name.IsEmpty then
    begin
      if aTable.PrimaryKey.DataType = dtAutoID then querytext.Add(Format('PRIMARY KEY(%s) AUTOINCREMENT',[aTable.PrimaryKey.Name]))
        else querytext.Add(Format('PRIMARY KEY(%s)',[aTable.PrimaryKey.Name]));
    end
    else querytext[querytext.Count-1] := Copy(querytext[querytext.Count-1],1,querytext[querytext.Count-1].Length-1);
    querytext.Add(')');
    Result := querytext.Text;
  finally
    querytext.Free;
  end;
end;

function TMySQLQueryGenerator.ExistsTable(aModel: TEntityModel): string;
begin
  Result := Format('SHOW TABLES LIKE ''%s''',[aModel.TableName]);
end;

function TMySQLQueryGenerator.Name: string;
begin
  Result := 'MYSQL';
end;

function TMySQLQueryGenerator.ExistsColumn(aModel : TEntityModel; const aFieldName : string) : string;
begin
  Result := Format('PRAGMA table_info(%s)',[aModel.TableName]);
end;

function TMySQLQueryGenerator.SetPrimaryKey(aModel: TEntityModel) : string;
begin
  Result := '';
  Exit;
end;

function TMySQLQueryGenerator.Sum(const aTableName, aFieldName, aWhere: string): string;
var
  querytext : TStringList;
begin
  querytext := TStringList.Create;
  try
    querytext.Add(Format('SELECT SUM(%s) as cnt FROM [%s] WHERE %s',[aTableName,aFieldName,aWhere]));
    Result := querytext.Text;
  finally
    querytext.Free;
  end;
end;

function TMySQLQueryGenerator.Select(const aTableName, aFieldNames: string; aLimit: Integer;
  const aWhere: string; aOrderFields: string; aOrderAsc: Boolean) : string;
var
  orderdir : string;
  querytext : TStringList;
begin
  querytext := TStringList.Create;
  try
    //define select-where clauses
    if aFieldNames.IsEmpty then querytext.Add(Format('SELECT * FROM [%s] WHERE %s',[aTableName,aWhere]))
      else querytext.Add(Format('SELECT %s FROM [%s] WHERE %s',[aFieldNames,aTableName,aWhere]));
    //define orderby clause
    if not aOrderFields.IsEmpty then
    begin
      if aOrderAsc then orderdir := 'ASC'
        else orderdir := 'DESC';
      querytext.Add(Format('ORDER BY %s %s',[aOrderFields,orderdir]));
    end;
    //define limited query clause
    if aLimit > 0 then querytext.Add('LIMIT ' + aLimit.ToString);
    Result := querytext.Text;
  finally
    querytext.Free;
  end;
end;

function TMySQLQueryGenerator.Add(const aTableName: string; const aFieldNames, aFieldValues : string) : string;
var
  querytext : TStringList;
begin
  querytext := TStringList.Create;
  try
    querytext.Add(Format('INSERT INTO [%s]',[aTableName]));
    querytext.Add(Format('(%s)',[aFieldNames]));
    querytext.Add(Format('VALUES(%s)',[aFieldValues]));
  finally
    querytext.Free;
  end;
end;

function TMySQLQueryGenerator.AddOrUpdate(const aTableName: string; const aFieldNames, aFieldValues : string) : string;
var
  querytext : TStringList;
begin
  querytext := TStringList.Create;
  try
    querytext.Add(Format('INSERT OR REPLACE INTO [%s]',[aTableName]));
    querytext.Add(Format('(%s)',[aFieldNames]));
    querytext.Add(Format('VALUES(%s)',[aFieldValues]));
    Result := querytext.Text;
  finally
    querytext.Free;
  end;
end;

function TMySQLQueryGenerator.Update(const aTableName, aFieldPairs, aWhere : string) : string;
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

function TMySQLQueryGenerator.Count(const aTableName : string; const aWhere : string) : string;
begin
  Result := Format('SELECT COUNT(*) AS cnt FROM [%s] WHERE %s',[aTableName,aWhere]);
end;

function TMySQLQueryGenerator.DateTimeToDBField(aDateTime: TDateTime): string;
begin
  Result := FormatDateTime('YYYYMMDD hh:nn:ss',aDateTime);
end;

function TMySQLQueryGenerator.DBFieldToDateTime(const aValue: string): TDateTime;
begin
  Result := StrToDateTime(aValue);
end;

function TMySQLQueryGenerator.Delete(const aTableName, aWhere: string) : string;
begin
  Result := Format('DELETE FROM [%s] WHERE %s',[aTableName,aWhere]);
end;

function TMySQLQueryGenerator.DBFieldToGUID(const aValue: string): TGUID;
begin
  Result := StringToGUID(aValue);
end;

function TMySQLQueryGenerator.GUIDToDBField(aGuid: TGUID): string;
begin
  Result := aGuid.ToString;
end;

end.
