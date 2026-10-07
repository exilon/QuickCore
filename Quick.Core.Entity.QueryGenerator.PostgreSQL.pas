{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Entity.QueryGenerator.PostgreSQL
  Description : Core Entity PostgreSQL Query Generator
  Author      : Kike Perez
  Version     : 1.0
  Created     : 13/04/2026
  Modified    : 08/05/2026

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

unit Quick.Core.Entity.QueryGenerator.PostgreSQL;

{$i QuickCore.inc}

interface

uses
  Classes,
  SysUtils,
  Quick.Commons,
  Quick.Core.Entity.DAO;

type

  TPostgreSQLQueryGenerator = class(TEntityQueryGenerator, IEntityQueryGenerator)
  private
    fFormatSettings : TFormatSettings;
  public
    function Name : string;
    constructor Create;
    function CreateTable(const aTable : TEntityModel) : string;
    function ExistsTable(aModel : TEntityModel) : string;
    function ExistsColumn(aModel : TEntityModel; const aFieldName : string) : string;
    function AddColumn(aModel : TEntityModel; aField : TEntityField) : string;
    function SetPrimaryKey(aModel : TEntityModel) : string;
    function CreateIndex(aModel : TEntityModel; aIndex : TEntityIndex) : string;
    function Select(const aTableName, aFieldNames : string; aLimit : Integer;
      const aWhere : string; aOrderFields : string; aOrderAsc : Boolean;
      nolock : Boolean) : string;
    function Sum(const aTableName, aFieldName, aWhere : string) : string;
    function Count(const aTableName : string; const aWhere : string) : string;
    function Add(const aTableName : string; const aFieldNames, aFieldValues : string) : string;
    function AddOrUpdate(const aTableName : string; const aFieldNames, aFieldValues : string) : string;
    function Update(const aTableName, aFieldPairs, aWhere : string) : string;
    function Delete(const aTableName : string; const aWhere : string) : string;
    function DateTimeToDBField(aDateTime : TDateTime) : string;
    function DBFieldToDateTime(const aValue : string) : TDateTime;
    function QuotedStr(const aValue : string) : string; override;
    function DBFieldToGUID(const aValue : string) : TGUID;
    function GUIDToDBField(aGuid : TGUID) : string;
  end;

implementation

const
  {$IFNDEF FPC}
  DBDATATYPES : array of string = [
    'varchar(%d)',   // dtString
    'text',          // dtStringMax
    'char(%d)',      // dtChar
    'integer',       // dtInteger
    'bigserial',     // dtAutoID
    'bigint',        // dtInt64
    'decimal(%d,%d)',// dtFloat
    'boolean',       // dtBoolean
    'date',          // dtDate
    'time',          // dtTime
    'timestamp',     // dtDateTime
    'timestamp',     // dtCreationDate
    'timestamp',     // dtModifiedDate
    'uuid'           // dtGUID
  ];
  {$ELSE}
  DBDATATYPES : array[0..13] of string = (
    'varchar(%d)', 'text', 'char(%d)', 'integer', 'bigserial', 'bigint',
    'decimal(%d,%d)', 'boolean', 'date', 'time', 'timestamp',
    'timestamp', 'timestamp', 'uuid');
  {$ENDIF}

{ TPostgreSQLQueryGenerator }

constructor TPostgreSQLQueryGenerator.Create;
begin
  {$IFDEF DELPHIRX103_UP}
  fFormatSettings := TFormatSettings.Create;
  {$ELSE}
  GetLocaleFormatSettings(0, fFormatSettings);
  {$ENDIF}
  fFormatSettings.ShortDateFormat := 'YYYY-MM-DD';
  fFormatSettings.ShortTimeFormat := 'hh:nn:ss';
  fFormatSettings.DateSeparator   := '-';
  fFormatSettings.TimeSeparator   := ':';
end;

function TPostgreSQLQueryGenerator.Name : string;
begin
  Result := 'POSTGRESQL';
end;

function TPostgreSQLQueryGenerator.QuotedStr(const aValue : string) : string;
begin
  Result := QuotedStr(aValue);  // uses SysUtils.QuotedStr (single quotes)
end;

function TPostgreSQLQueryGenerator.CreateTable(const aTable : TEntityModel) : string;
var
  field     : TEntityField;
  datatype  : string;
  querytext : TStringList;
begin
  querytext := TStringList.Create;
  try
    querytext.Add(Format('CREATE TABLE IF NOT EXISTS "%s" (',[aTable.TableName]));
    for field in aTable.Fields do
    begin
      if field.DataType = dtFloat then
        datatype := Format(DBDATATYPES[Integer(field.DataType)],[field.DataSize, field.Precision])
      else if field.DataSize > 0 then
        datatype := Format(DBDATATYPES[Integer(field.DataType)],[field.DataSize])
      else
        datatype := DBDATATYPES[Integer(field.DataType)];

      if field.IsPrimaryKey then
      begin
        if field.DataType = dtAutoID then
          querytext.Add(Format('"%s" %s PRIMARY KEY,',[field.Name, datatype]))
        else
          querytext.Add(Format('"%s" %s PRIMARY KEY,',[field.Name, datatype]));
      end
      else
      begin
        if field.DataType = dtCreationDate then
          querytext.Add(Format('"%s" %s DEFAULT NOW(),',[field.Name, datatype]))
        else
          querytext.Add(Format('"%s" %s,',[field.Name, datatype]));
      end;
    end;
    // Remove trailing comma from last field line
    querytext[querytext.Count-1] :=
      Copy(querytext[querytext.Count-1], 1, querytext[querytext.Count-1].Length - 1);
    querytext.Add(')');
    Result := querytext.Text;
  finally
    querytext.Free;
  end;
end;

function TPostgreSQLQueryGenerator.ExistsTable(aModel : TEntityModel) : string;
begin
  Result := Format(
    'SELECT table_name FROM information_schema.tables ' +
    'WHERE table_schema = ''public'' AND table_name = ''%s''',
    [aModel.TableName]);
end;

function TPostgreSQLQueryGenerator.ExistsColumn(aModel : TEntityModel;
  const aFieldName : string) : string;
begin
  Result := Format(
    'SELECT column_name FROM information_schema.columns ' +
    'WHERE table_schema = ''public'' AND table_name = ''%s'' AND column_name = ''%s''',
    [aModel.TableName, aFieldName]);
end;

function TPostgreSQLQueryGenerator.AddColumn(aModel : TEntityModel;
  aField : TEntityField) : string;
var
  datatype : string;
begin
  if aField.DataType = dtFloat then
    datatype := Format(DBDATATYPES[Integer(aField.DataType)],[aField.DataSize, aField.Precision])
  else if aField.DataSize > 0 then
    datatype := Format(DBDATATYPES[Integer(aField.DataType)],[aField.DataSize])
  else
    datatype := DBDATATYPES[Integer(aField.DataType)];
  Result := Format('ALTER TABLE "%s" ADD COLUMN "%s" %s',
    [aModel.TableName, aField.Name, datatype]);
end;

function TPostgreSQLQueryGenerator.SetPrimaryKey(aModel : TEntityModel) : string;
begin
  // PostgreSQL sets primary key inline in CREATE TABLE
  Result := '';
end;

function TPostgreSQLQueryGenerator.CreateIndex(aModel : TEntityModel;
  aIndex : TEntityIndex) : string;
begin
  Result := Format('CREATE INDEX IF NOT EXISTS "idx_%s_%s" ON "%s" ("%s")',
    [aModel.TableName, aIndex.FieldNames[0], aModel.TableName, aIndex.FieldNames[0]]);
end;

function TPostgreSQLQueryGenerator.Select(const aTableName, aFieldNames : string;
  aLimit : Integer; const aWhere : string; aOrderFields : string;
  aOrderAsc : Boolean; nolock : Boolean) : string;
var
  orderdir  : string;
  querytext : TStringList;
begin
  querytext := TStringList.Create;
  try
    if aFieldNames.IsEmpty then
      querytext.Add(Format('SELECT * FROM "%s" WHERE %s', [aTableName, aWhere]))
    else
      querytext.Add(Format('SELECT %s FROM "%s" WHERE %s', [aFieldNames, aTableName, aWhere]));
    if not aOrderFields.IsEmpty then
    begin
      if aOrderAsc then orderdir := 'ASC' else orderdir := 'DESC';
      querytext.Add(Format('ORDER BY %s %s', [aOrderFields, orderdir]));
    end;
    if aLimit > 0 then querytext.Add('LIMIT ' + aLimit.ToString);
    Result := querytext.Text;
  finally
    querytext.Free;
  end;
end;

function TPostgreSQLQueryGenerator.Sum(const aTableName, aFieldName,
  aWhere: string): string;
begin
  Result := Format('SELECT COALESCE(SUM("%s"),0) AS cnt FROM "%s" WHERE %s',
    [aFieldName, aTableName, aWhere]);
end;

function TPostgreSQLQueryGenerator.Count(const aTableName : string;
  const aWhere : string) : string;
begin
  Result := Format('SELECT COUNT(*) AS cnt FROM "%s" WHERE %s', [aTableName, aWhere]);
end;

function TPostgreSQLQueryGenerator.Add(const aTableName : string;
  const aFieldNames, aFieldValues : string) : string;
var
  querytext : TStringList;
begin
  querytext := TStringList.Create;
  try
    querytext.Add(Format('INSERT INTO "%s"', [aTableName]));
    querytext.Add(Format('(%s)', [aFieldNames]));
    querytext.Add(Format('VALUES(%s)', [aFieldValues]));
    Result := querytext.Text;
  finally
    querytext.Free;
  end;
end;

function TPostgreSQLQueryGenerator.AddOrUpdate(const aTableName : string;
  const aFieldNames, aFieldValues : string) : string;
var
  querytext  : TStringList;
  fieldList  : TStringList;
  updatePart : TStringList;
  i          : Integer;
  fieldName  : string;
begin
  // Build UPDATE SET part for ON CONFLICT
  fieldList  := TStringList.Create;
  updatePart := TStringList.Create;
  querytext  := TStringList.Create;
  try
    fieldList.CommaText := aFieldNames;
    for i := 0 to fieldList.Count - 1 do
    begin
      fieldName := Trim(fieldList[i]);
      updatePart.Add(Format('"%s" = EXCLUDED."%s"', [fieldName, fieldName]));
    end;

    querytext.Add(Format('INSERT INTO "%s"', [aTableName]));
    querytext.Add(Format('(%s)', [aFieldNames]));
    querytext.Add(Format('VALUES(%s)', [aFieldValues]));
    querytext.Add('ON CONFLICT DO UPDATE SET');
    querytext.Add(updatePart.CommaText);
    Result := querytext.Text;
  finally
    fieldList.Free;
    updatePart.Free;
    querytext.Free;
  end;
end;

function TPostgreSQLQueryGenerator.Update(const aTableName, aFieldPairs,
  aWhere : string) : string;
var
  querytext : TStringList;
begin
  querytext := TStringList.Create;
  try
    querytext.Add(Format('UPDATE "%s"', [aTableName]));
    querytext.Add(Format('SET %s', [aFieldPairs]));
    querytext.Add(Format('WHERE %s', [aWhere]));
    Result := querytext.Text;
  finally
    querytext.Free;
  end;
end;

function TPostgreSQLQueryGenerator.Delete(const aTableName, aWhere : string) : string;
begin
  Result := Format('DELETE FROM "%s" WHERE %s', [aTableName, aWhere]);
end;

function TPostgreSQLQueryGenerator.DateTimeToDBField(aDateTime : TDateTime) : string;
begin
  if fISO8601DateTime then
    Result := FormatDateTime('YYYY-MM-DD"T"HH:NN:SS', aDateTime)
  else
    Result := FormatDateTime('YYYY-MM-DD HH:NN:SS', aDateTime);
end;

function TPostgreSQLQueryGenerator.DBFieldToDateTime(const aValue : string) : TDateTime;
var
  fmtdate : TFormatSettings;
begin
  if fISO8601DateTime then
  begin
    fmtdate := fFormatSettings;
    fmtdate.LongDateFormat := 'YYYY-MM-DDThh:nn:ss';
    Result := StrToDateTime(aValue, fmtdate);
  end
  else
    Result := StrToDateTime(aValue, fFormatSettings);
end;

function TPostgreSQLQueryGenerator.DBFieldToGUID(const aValue : string) : TGUID;
begin
  if aValue.Contains('{') then Result := StringToGUID(aValue)
    else Result := StringToGUID('{' + aValue + '}');
end;

function TPostgreSQLQueryGenerator.GUIDToDBField(aGuid : TGUID) : string;
begin
  // PostgreSQL accepts UUID literals without braces
  Result := Copy(aGuid.ToString, 2, 36);
end;

end.
