{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Entity.Migrations
  Description : Core Entity Migrations
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

unit Quick.Core.Entity.Migrations;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Quick.Core.Entity,
  Quick.Core.Entity.DAO;

type

  { -----------------------------------------------------------------------
    TEntityMigrationsHistory
    Persisted tracking record for each applied migration.
    Table: __MigrationsHistory
    ----------------------------------------------------------------------- }
  {$M+}
  TEntityMigrationsHistory = class(TEntity)
  private
    fId             : TAutoID;
    fMigrationId    : string;
    fProductVersion : string;
    fAppliedAt      : TDateTime;
  published
    [Key]
    property Id             : TAutoID  read fId             write fId;
    [StringLength(200)]
    property MigrationId    : string   read fMigrationId    write fMigrationId;
    [StringLength(50)]
    property ProductVersion : string   read fProductVersion write fProductVersion;
    property AppliedAt      : TDateTime read fAppliedAt     write fAppliedAt;
  end;
  {$M-}

  { -----------------------------------------------------------------------
    TMigration — abstract base class for a single migration.

    Subclass and implement:
      function GetMigrationId : string  — unique, sortable name,
                                          e.g. '20240101000000_CreateUsers'
      procedure Up(aDBContext)          — apply the migration
      procedure Down(aDBContext)        — revert the migration

    Override GetProductVersion to tag the migration with an app version.
    ----------------------------------------------------------------------- }
  TMigration = class abstract
  public
    function  GetMigrationId     : string;   virtual; abstract;
    function  GetProductVersion  : string;   virtual;
    procedure Up(aDBContext   : TDBContext); virtual; abstract;
    procedure Down(aDBContext : TDBContext); virtual; abstract;
  end;

  TMigrationClass = class of TMigration;

  EMigrationsError = class(Exception);

  { -----------------------------------------------------------------------
    TMigrationsManager
    Applies / rolls back migrations and maintains the
    __MigrationsHistory table.

    Usage:
      var mgr := TMigrationsManager.Create(myDBContext);
      try
        mgr.ApplyMigrations([TCreateUsersTable, TAddEmailIndex]);
      finally
        mgr.Free;
      end;
    ----------------------------------------------------------------------- }
  TMigrationsManager = class
  private
    fDBContext    : TDBContext;
    fHistoryModel : TEntityModel;
    fTableName    : string;
    procedure EnsureHistoryTable;
    function  IsApplied(const aMigrationId : string) : Boolean;
    procedure RecordMigration(const aMigrationId, aProductVersion : string);
    procedure RemoveMigration(const aMigrationId : string);
    function  GetAppliedMigrationIds : TArray<string>;
  public
    constructor Create(aDBContext : TDBContext;
                       const aTableName : string = '__MigrationsHistory');
    destructor Destroy; override;
    { Apply all not-yet-applied migrations (in order). }
    procedure ApplyMigrations(const aMigrations : array of TMigrationClass);
    { Rollback the last applied migration (uses migration list to find Down). }
    procedure RollbackLast(const aMigrations : array of TMigrationClass);
    { Returns list of MigrationIds already applied to this database. }
    function  GetAppliedMigrations : TArray<string>;
  end;

implementation

{ TMigration }

function TMigration.GetProductVersion : string;
begin
  Result := '0.0.0';
end;

{ TMigrationsManager }

constructor TMigrationsManager.Create(aDBContext : TDBContext;
                                       const aTableName : string);
begin
  fDBContext    := aDBContext;
  fHistoryModel := nil;
  fTableName    := aTableName;
end;

destructor TMigrationsManager.Destroy;
begin
  inherited;
end;

procedure TMigrationsManager.EnsureHistoryTable;
var
  tableNames : TArray<string>;
  tableName  : string;
  tableExists : Boolean;
  createSQL  : string;
begin
  if fHistoryModel <> nil then Exit;

  // Register the entity model with the database if not already present
  if not fDBContext.Models.List.ContainsKey(TEntityMigrationsHistory) then
    fDBContext.Models.Add(TEntityMigrationsHistory, 'Id', fTableName);

  fHistoryModel := fDBContext.Models.Get(TEntityMigrationsHistory);

  // Check whether the history table already exists
  tableExists := False;
  tableNames  := fDBContext.GetTableNames;
  for tableName in tableNames do
  begin
    if SameText(tableName, fTableName) then
    begin
      tableExists := True;
      Break;
    end;
  end;

  if not tableExists then
  begin
    createSQL := fDBContext.Database.QueryGenerator.CreateTable(fHistoryModel);
    fDBContext.Database.ExecuteSQLQuery(createSQL);
  end;
end;

function TMigrationsManager.IsApplied(const aMigrationId : string) : Boolean;
var
  query  : IEntityQuery<TEntity>;
  linq   : IEntityLinqQuery<TEntity>;
begin
  Result := False;
  query  := fDBContext.Database.CreateQuery(fHistoryModel);
  if Supports(query, IEntityLinqQuery<TEntity>, linq) then
    Result := linq.Where('MigrationId = ' + QuotedStr(aMigrationId)).Count > 0;
end;

procedure TMigrationsManager.RecordMigration(const aMigrationId,
                                               aProductVersion : string);
var
  entry : TEntityMigrationsHistory;
begin
  entry := TEntityMigrationsHistory.Create;
  try
    entry.MigrationId    := aMigrationId;
    entry.ProductVersion := aProductVersion;
    entry.AppliedAt      := Now;
    fDBContext.Database.Add(entry);
  finally
    entry.Free;
  end;
end;

procedure TMigrationsManager.RemoveMigration(const aMigrationId : string);
var
  query : IEntityQuery<TEntity>;
  linq  : IEntityLinqQuery<TEntity>;
begin
  query := fDBContext.Database.CreateQuery(fHistoryModel);
  if Supports(query, IEntityLinqQuery<TEntity>, linq) then
    linq.Where('MigrationId = ' + QuotedStr(aMigrationId)).Delete;
end;

function TMigrationsManager.GetAppliedMigrationIds : TArray<string>;
var
  query   : IEntityQuery<TEntity>;
  linq    : IEntityLinqQuery<TEntity>;
  results : IEntityResult<TEntity>;
  entity  : TEntity;
  hist    : TEntityMigrationsHistory;
begin
  Result := [];
  query  := fDBContext.Database.CreateQuery(fHistoryModel);
  if Supports(query, IEntityLinqQuery<TEntity>, linq) then
  begin
    results := linq
      .OrderBy('AppliedAt')
      .Select;
    for entity in results do
    begin
      if entity is TEntityMigrationsHistory then
      begin
        hist   := TEntityMigrationsHistory(entity);
        Result := Result + [hist.MigrationId];
      end;
    end;
  end;
end;

procedure TMigrationsManager.ApplyMigrations(
  const aMigrations : array of TMigrationClass);
var
  migClass  : TMigrationClass;
  migration : TMigration;
begin
  EnsureHistoryTable;
  for migClass in aMigrations do
  begin
    migration := migClass.Create;
    try
      if not IsApplied(migration.GetMigrationId) then
      begin
        fDBContext.BeginTransaction;
        try
          migration.Up(fDBContext);
          RecordMigration(migration.GetMigrationId, migration.GetProductVersion);
          fDBContext.CommitTransaction;
        except
          fDBContext.RollbackTransaction;
          raise;
        end;
      end;
    finally
      migration.Free;
    end;
  end;
end;

procedure TMigrationsManager.RollbackLast(
  const aMigrations : array of TMigrationClass);
var
  applied   : TArray<string>;
  lastId    : string;
  migClass  : TMigrationClass;
  migration : TMigration;
begin
  EnsureHistoryTable;
  applied := GetAppliedMigrationIds;
  if Length(applied) = 0 then
    raise EMigrationsError.Create('No migrations have been applied');

  lastId := applied[High(applied)];

  for migClass in aMigrations do
  begin
    migration := migClass.Create;
    try
      if SameText(migration.GetMigrationId, lastId) then
      begin
        fDBContext.BeginTransaction;
        try
          migration.Down(fDBContext);
          RemoveMigration(lastId);
          fDBContext.CommitTransaction;
        except
          fDBContext.RollbackTransaction;
          raise;
        end;
        Exit;
      end;
    finally
      migration.Free;
    end;
  end;

  raise EMigrationsError.CreateFmt(
    'Migration class for "%s" not found in the provided list', [lastId]);
end;

function TMigrationsManager.GetAppliedMigrations : TArray<string>;
begin
  EnsureHistoryTable;
  Result := GetAppliedMigrationIds;
end;

end.
