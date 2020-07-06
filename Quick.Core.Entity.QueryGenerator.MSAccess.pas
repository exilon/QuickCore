{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Entity.QueryGenerator.MSAccess
  Description : Core Entity MSAccess Query Generator
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 22/11/2019
  Modified    : 25/05/2020

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

unit Quick.Core.Entity.QueryGenerator.MSAccess;

interface

{$i QuickCore.inc}

uses
  Classes,
  SysUtils,
  Quick.Commons,
  Quick.Core.Entity.DAO;

type

  TMSAccessQueryGenerator = class(TEntityQueryGenerator,IEntityQueryGenerator)
  public
    function Name : string;
    function CreateTable(const aTable : TEntityModel) : string;
    function ExistsTable(aModel : TEntityModel) : string;
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
  end;

implementation

const
  {$IFNDEF FPC}
  DBDATATYPES : array of string = ['text(%d)','text','char(%d)','int','integer','bigint','decimal(%d,%d)','bit','date','time','datetime','datetime','datetime'];
  {$ELSE}
  DBDATATYPES : array[0..10] of string = ('text(%d)','text','char(%d)','int','integer','bigint','decimal(%d,%d)','bit','date','time','datetime','datetime','datetime');
  {$ENDIF}

{ TMSSQLQueryGenerator }

function TMSAccessQueryGenerator.Add(const aTableName, aFieldNames, aFieldValues: string): string;
var
  querytext : TStringList;
begin
  querytext := TStringList.Create;
  try
    querytext.Add(Format('INSERT INTO [%s]',[aTableName]));
    querytext.Add(Format('(%s)',[aFieldNames]));
    querytext.Add(Format('VALUES(%s)',[aFieldValues]));
    Result := querytext.Text;
  finally
    querytext.Free;
  end;
end;

function TMSAccessQueryGenerator.AddColumn(aModel: TEntityModel; aField: TEntityField) : string;
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

function TMSAccessQueryGenerator.CreateIndex(aModel: TEntityModel; aIndex: TEntityIndex) : string;
var
  querytext : TStringList;
begin
  Exit;
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

function TMSAccessQueryGenerator.CreateTable(const aTable: TEntityModel) : string;
var
  field : TEntityField;
  datatype : string;
  querytext : TStringList;
begin
  querytext := TStringList.Create;
  try
    //querytext.Add(Format('IF NOT EXISTS (SELECT Count(MSysObjects.Id) AS CountOfId FROM MSysObjects WHERE MSysObjects.Type IN (1,4,6) AND MSysObjects.name = ''%s'')',[aTable.TableName]));
    //querytext.Add('BEGIN');
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
      if field.DataType = dtAutoID then querytext.Add(Format('[%s] %s IDENTITY(1,1),',[field.Name,datatype]))
        else querytext.Add(Format('[%s] %s,',[field.Name,datatype]))
    end;
    if not aTable.PrimaryKey.Name.IsEmpty then
    begin
      querytext.Add(Format('PRIMARY KEY(%s)',[aTable.PrimaryKey.Name]));
    end
    else querytext[querytext.Count-1] := Copy(querytext[querytext.Count-1],1,querytext[querytext.Count-1].Length-1);
    //querytext.Add('END');
    Result := querytext.Text;
  finally
    querytext.Free;
  end;
end;

function TMSAccessQueryGenerator.ExistsColumn(aModel: TEntityModel; const aFieldName: string) : string;
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

function TMSAccessQueryGenerator.ExistsTable(aModel: TEntityModel): string;
var
  querytext : TStringList;
begin
  querytext := TStringList.Create;
  try
    querytext.Add('GRANT SELECT ON MSysObjects TO Admin;');
    //querytext.Add(Format('SELECT name FROM MSysObjects WHERE MSysObjects.Type IN (1,4,6) AND MSysObjects.name = ''%s''',[aModel.TableName]));
    Result := querytext.Text;
  finally
    querytext.Free;
  end;
end;

function TMSAccessQueryGenerator.Name: string;
begin
  Result := 'MSACCESS';
end;

function TMSAccessQueryGenerator.SetPrimaryKey(aModel: TEntityModel) : string;
var
  querytext : TStringList;
begin
  querytext := TStringList.Create;
  try
    //querytext.Add('IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS');
    //querytext.Add(Format('WHERE CONSTRAINT_TYPE = ''PRIMARY KEY'' AND TABLE_NAME = ''%s'' AND TABLE_SCHEMA =''dbo'')',[aModel.TableName]));
    //querytext.Add('BEGIN');
    //querytext.Add(Format('ALTER TABLE [%s] ADD CONSTRAINT PK_%s PRIMARY KEY (%s)',[aModel.TableName,aModel.PrimaryKey,aModel.PrimaryKey]));
    //querytext.Add('END');
    Result := querytext.Text;
  finally
    querytext.Free;
  end;
end;

function TMSAccessQueryGenerator.Sum(const aTableName, aFieldName, aWhere: string): string;
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

function TMSAccessQueryGenerator.Select(const aTableName, aFieldNames: string; aLimit: Integer;
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

function TMSAccessQueryGenerator.AddOrUpdate(const aTableName: string; const aFieldNames, aFieldValues : string) : string;
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

function TMSAccessQueryGenerator.Update(const aTableName, aFieldPairs, aWhere : string) : string;
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

function TMSAccessQueryGenerator.Count(const aTableName : string; const aWhere : string) : string;
begin
  Result := Format('SELECT COUNT(*) AS cnt FROM [%s] WHERE %s',[aTableName,aWhere]);
end;

function TMSAccessQueryGenerator.DateTimeToDBField(aDateTime: TDateTime): string;
begin
  Result := FormatDateTime('YYYY/MM/DD hh:nn:ss',aDateTime);
end;

function TMSAccessQueryGenerator.DBFieldToDateTime(const aValue: string): TDateTime;
begin
  Result := StrToDateTime(aValue);
end;

function TMSAccessQueryGenerator.Delete(const aTableName, aWhere: string) : string;
begin
  Result := Format('SELECT COUNT(*) AS cnt FROM [%s] WHERE %s',[aTableName,aWhere]);
end;

end.
