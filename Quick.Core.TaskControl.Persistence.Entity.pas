{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.TaskControl.Persistence.Entity
  Description : TaskControl persistence store via Quick.Core.Entity ORM
  Author      : Kike Perez
  Version     : 1.0
  Created     : 04/05/2026
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

unit Quick.Core.TaskControl.Persistence.Entity;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.SyncObjs,
  System.Generics.Collections,
  Quick.Collections,
  Quick.Threads,
  Quick.Core.Entity,
  Quick.Core.Entity.DAO,
  Quick.Core.Entity.Database,
  Quick.Core.Entity.Factory.Database,
  Quick.Core.TaskControl.Persistence;

type
  {$M+}
  /// <summary>ORM entity that maps to the TC_TASKS table.
  /// Uses a string primary key (task name) — no AutoID needed.</summary>
  [Table('TC_TASKS')]
  TTaskRecord = class(TEntity)
  private
    FName            : string;
    FLastExecution   : Double;
    FNextExecution   : Double;
    FExecutionTimes  : Integer;
    FScheduleMode    : string;
    FTimeInterval    : Integer;
    FTimeMeasure     : string;
    FMaxRetries      : Integer;
    FRetryDelayMs    : Integer;
    FRetryMultiplier : Double;
    FEnabled         : Boolean;
    FFinished        : Boolean;
    FUpdatedAt       : Double;
  published
    [Key]
    [StringLength(255)]
    property Name            : string  read FName            write FName;
    property LastExecution   : Double  read FLastExecution   write FLastExecution;
    property NextExecution   : Double  read FNextExecution   write FNextExecution;
    property ExecutionTimes  : Integer read FExecutionTimes  write FExecutionTimes;
    [StringLength(50)]
    property ScheduleMode    : string  read FScheduleMode    write FScheduleMode;
    property TimeInterval    : Integer read FTimeInterval    write FTimeInterval;
    [StringLength(50)]
    property TimeMeasure     : string  read FTimeMeasure     write FTimeMeasure;
    property MaxRetries      : Integer read FMaxRetries      write FMaxRetries;
    property RetryDelayMs    : Integer read FRetryDelayMs    write FRetryDelayMs;
    property RetryMultiplier : Double  read FRetryMultiplier write FRetryMultiplier;
    property Enabled         : Boolean read FEnabled         write FEnabled;
    property Finished        : Boolean read FFinished        write FFinished;
    property UpdatedAt       : Double  read FUpdatedAt       write FUpdatedAt;
  end;
  {$M-}

  {$M+}
  /// <summary>ORM entity for individual execution history rows (TC_TASK_HISTORY).
  /// Id is TAutoID so the engine generates the PK automatically.</summary>
  [Table('TC_TASK_HISTORY')]
  TTaskHistoryRecord = class(TEntity)
  private
    FId            : TAutoID;
    FTaskName      : string;
    FExecTime      : Double;
    FDurationMs    : Integer;
    FStatus        : string;
    FErrorMessage  : string;
    FExceptionType : string;
  published
    [Key]
    property Id            : TAutoID read FId            write FId;
    [StringLength(255)]
    property TaskName      : string  read FTaskName      write FTaskName;
    property ExecTime      : Double  read FExecTime      write FExecTime;
    property DurationMs    : Integer read FDurationMs    write FDurationMs;
    [StringLength(50)]
    property Status        : string  read FStatus        write FStatus;
    [StringLength(2000)]
    property ErrorMessage  : string  read FErrorMessage  write FErrorMessage;
    [StringLength(500)]
    property ExceptionType : string  read FExceptionType write FExceptionType;
  end;
  {$M-}

  /// <summary>DBContext that exposes the TC_TASKS and TC_TASK_HISTORY tables via TDBSet.</summary>
  TTaskControlContext = class(TDBContext)
  private
    FTasks   : TDBSet<TTaskRecord>;
    FHistory : TDBSet<TTaskHistoryRecord>;
  public
    property Tasks   : TDBSet<TTaskRecord>          read FTasks   write FTasks;
    property History : TDBSet<TTaskHistoryRecord>   read FHistory write FHistory;
    function IsConnected : Boolean; override;
  end;

  /// <summary>Persistence store built on top of Quick.Core.Entity.
  /// Supports any engine available via TEntityDatabaseFactory
  /// (FireDAC/SQLite, FireDAC/MSAccess, ADO/SQL Server, …).
  ///
  /// Usage — SQLite:
  ///   taskControl.UseStorage(
  ///     TEntityTaskStorage.CreateSQLite('data\tasks.db'));
  ///
  /// Usage — custom engine:
  ///   var db := TEntityDatabaseFactory.GetInstance(TDatabaseEngine.deFireDAC);
  ///   db.Connection.FromConnectionString(Integer(TDBProvider.dbSQLite),
  ///     'Database=tasks.db');
  ///   taskControl.UseStorage(TEntityTaskStorage.Create(db));
  /// </summary>
  TEntityTaskStorage = class(TInterfacedObject, ITaskPersistenceStore)
  private
    fContext : TTaskControlContext;
    fLock    : TCriticalSection;
    function  RecordToSnapshot(aRec : TTaskRecord) : TTaskSnapshot;
    function  SnapshotToRecord(const aSnap : TTaskSnapshot) : TTaskRecord;
  public
    constructor Create(aDatabase : TEntityDatabase);
    /// <summary>Shortcut: creates a FireDAC SQLite store at aDbPath.</summary>
    class function CreateSQLite(const aDbPath : string) : TEntityTaskStorage;
    destructor  Destroy; override;
    procedure Save(const aSnapshot : TTaskSnapshot);
    function  Load(const aName : string; out aSnapshot : TTaskSnapshot) : Boolean;
    function  LoadAll : TArray<TTaskSnapshot>;
    procedure Delete(const aName : string);
    procedure Clear;
    procedure SaveHistoryEntry(const aTaskName : string; const aEntry : THistoryEntry);
    function  LoadHistory(const aTaskName : string; aMaxEntries : Integer) : TArray<THistoryEntry>;
    function  LoadAllHistory(const aStatus : string; aPage, aPageSize : Integer) : TArray<THistoryEntryEx>;
    function  CountAllHistory(const aStatus : string) : Int64;
  end;

implementation

uses
  System.IOUtils,
  Quick.Core.Entity.Engine.FireDAC;

{ TEntityTaskStorage }

function TTaskControlContext.IsConnected: Boolean;
begin
  Result := Assigned(Database) and Database.IsConnected;
end;

constructor TEntityTaskStorage.Create(aDatabase : TEntityDatabase);
begin
  fLock    := TCriticalSection.Create;
  fContext := TTaskControlContext.Create(aDatabase);
  if not fContext.Connect then
    raise Exception.Create('TEntityTaskStorage: cannot connect to database');
end;

class function TEntityTaskStorage.CreateSQLite(const aDbPath : string) : TEntityTaskStorage;
var
  db  : TEntityDatabase;
  dir : string;
begin
  dir := TPath.GetDirectoryName(ExpandFileName(aDbPath));
  if (dir <> '') and not TDirectory.Exists(dir) then
    TDirectory.CreateDirectory(dir);

  db := TEntityDatabaseFactory.GetInstance(TDatabaseEngine.deFireDAC);
  db.Connection.FromConnectionString(
    Integer(TDBProvider.dbSQLite),
    'Database=' + ExpandFileName(aDbPath));
  Result := TEntityTaskStorage.Create(db);
end;

destructor TEntityTaskStorage.Destroy;
begin
  fContext.Free;
  fLock.Free;
  inherited;
end;

function TEntityTaskStorage.RecordToSnapshot(aRec : TTaskRecord) : TTaskSnapshot;
begin
  Result.Name            := aRec.Name;
  Result.LastExecution   := aRec.LastExecution;
  Result.NextExecution   := aRec.NextExecution;
  Result.ExecutionTimes  := aRec.ExecutionTimes;
  Result.ScheduleMode    := aRec.ScheduleMode;
  Result.TimeInterval    := aRec.TimeInterval;
  Result.TimeMeasure     := aRec.TimeMeasure;
  Result.MaxRetries      := aRec.MaxRetries;
  Result.RetryDelayMs    := aRec.RetryDelayMs;
  Result.RetryMultiplier := aRec.RetryMultiplier;
  Result.Enabled         := aRec.Enabled;
  Result.Finished        := aRec.Finished;
  Result.UpdatedAt       := aRec.UpdatedAt;
end;

function TEntityTaskStorage.SnapshotToRecord(const aSnap : TTaskSnapshot) : TTaskRecord;
begin
  Result := TTaskRecord.Create;
  Result.Name            := aSnap.Name;
  Result.LastExecution   := aSnap.LastExecution;
  Result.NextExecution   := aSnap.NextExecution;
  Result.ExecutionTimes  := aSnap.ExecutionTimes;
  Result.ScheduleMode    := aSnap.ScheduleMode;
  Result.TimeInterval    := aSnap.TimeInterval;
  Result.TimeMeasure     := aSnap.TimeMeasure;
  Result.MaxRetries      := aSnap.MaxRetries;
  Result.RetryDelayMs    := aSnap.RetryDelayMs;
  Result.RetryMultiplier := aSnap.RetryMultiplier;
  Result.Enabled         := aSnap.Enabled;
  Result.Finished        := aSnap.Finished;
  Result.UpdatedAt       := aSnap.UpdatedAt;
end;

procedure TEntityTaskStorage.Save(const aSnapshot : TTaskSnapshot);
var
  rec : TTaskRecord;
begin
  fLock.Enter;
  try
    rec := SnapshotToRecord(aSnapshot);
    try
      fContext.Tasks.AddOrUpdate(rec);
    finally
      rec.Free;
    end;
  finally
    fLock.Leave;
  end;
end;

function TEntityTaskStorage.Load(const aName : string; out aSnapshot : TTaskSnapshot) : Boolean;
var
  rec : TTaskRecord;
begin
  Result := False;
  fLock.Enter;
  try
    rec := fContext.Tasks
             .Where('Name = %s', [aName])
             .SelectFirst;
    if rec <> nil then
    begin
      try
        aSnapshot := RecordToSnapshot(rec);
        Result    := True;
      finally
        rec.Free;
      end;
    end;
  finally
    fLock.Leave;
  end;
end;

function TEntityTaskStorage.LoadAll : TArray<TTaskSnapshot>;
var
  results : IDBSetResult<TTaskRecord>;
  recs    : IList<TTaskRecord>;
  list    : TList<TTaskSnapshot>;
  rec     : TTaskRecord;
begin
  fLock.Enter;
  try
    list := TList<TTaskSnapshot>.Create;
    try
      results := fContext.Tasks.Select;
      recs    := results.ToList;
      for rec in recs do
        list.Add(RecordToSnapshot(rec));
      Result := list.ToArray;
    finally
      list.Free;
    end;
  finally
    fLock.Leave;
  end;
end;

procedure TEntityTaskStorage.Delete(const aName : string);
begin
  fLock.Enter;
  try
    fContext.Tasks.Delete('Name = ''' + aName.Replace('''', '''''') + '''');
  finally
    fLock.Leave;
  end;
end;

procedure TEntityTaskStorage.Clear;
begin
  fLock.Enter;
  try
    fContext.Tasks.Delete;
  finally
    fLock.Leave;
  end;
end;

procedure TEntityTaskStorage.SaveHistoryEntry(const aTaskName : string; const aEntry : THistoryEntry);
var
  rec : TTaskHistoryRecord;
begin
  fLock.Enter;
  try
    rec := TTaskHistoryRecord.Create;
    try
      rec.TaskName      := aTaskName;
      rec.ExecTime      := aEntry.ExecTime;
      rec.DurationMs    := aEntry.DurationMs;
      rec.Status        := aEntry.Status;
      rec.ErrorMessage  := aEntry.ErrorMessage;
      rec.ExceptionType := aEntry.ExceptionType;
      fContext.History.Add(rec);
    finally
      rec.Free;
    end;
  finally
    fLock.Leave;
  end;
end;

function TEntityTaskStorage.LoadHistory(const aTaskName : string; aMaxEntries : Integer) : TArray<THistoryEntry>;
var
  results : IEntityResult<TTaskHistoryRecord>;
  recs    : IList<TTaskHistoryRecord>;
  list    : TList<THistoryEntry>;
  rec     : TTaskHistoryRecord;
  entry   : THistoryEntry;
begin
  fLock.Enter;
  try
    list := TList<THistoryEntry>.Create;
    try
      results := fContext.History
                   .Where('TaskName = %s', [aTaskName])
                   .OrderByDescending('Id')
                   .SelectTop(aMaxEntries);
      recs := results.ToList;
      for rec in recs do
      begin
        entry.ExecTime      := rec.ExecTime;
        entry.DurationMs    := rec.DurationMs;
        entry.Status        := rec.Status;
        entry.ErrorMessage  := rec.ErrorMessage;
        entry.ExceptionType := rec.ExceptionType;
        list.Add(entry);
      end;
      Result := list.ToArray;
    finally
      list.Free;
    end;
  finally
    fLock.Leave;
  end;
end;

function TEntityTaskStorage.LoadAllHistory(const aStatus : string; aPage, aPageSize : Integer) : TArray<THistoryEntryEx>;
var
  linq    : IEntityLinqQuery<TTaskHistoryRecord>;
  results : IEntityResult<TTaskHistoryRecord>;
  recs    : IList<TTaskHistoryRecord>;
  list    : TList<THistoryEntryEx>;
  rec     : TTaskHistoryRecord;
  ex      : THistoryEntryEx;
  i, skip : Integer;
begin
  fLock.Enter;
  try
    list := TList<THistoryEntryEx>.Create;
    try
      // Build query: filter by status if given, order newest-first, take page window
      linq := fContext.History.OrderByDescending('Id');
      if aStatus <> '' then
        linq := linq.Where('Status = %s', [aStatus]);
      // SelectTop takes the first N from the ordered result
      // We load up to page*pageSize and skip in memory (no native OFFSET support)
      results := linq.SelectTop(aPage * aPageSize);
      recs := results.ToList;
      skip := (aPage - 1) * aPageSize;
      for i := skip to recs.Count - 1 do
      begin
        rec := recs[i];
        ex.TaskName      := rec.TaskName;
        ex.ExecTime      := rec.ExecTime;
        ex.DurationMs    := rec.DurationMs;
        ex.Status        := rec.Status;
        ex.ErrorMessage  := rec.ErrorMessage;
        ex.ExceptionType := rec.ExceptionType;
        list.Add(ex);
      end;
      Result := list.ToArray;
    finally
      list.Free;
    end;
  finally
    fLock.Leave;
  end;
end;

function TEntityTaskStorage.CountAllHistory(const aStatus : string) : Int64;
begin
  fLock.Enter;
  try
    if aStatus <> '' then
      Result := fContext.History.Where('Status = %s', [aStatus]).Count
    else
      Result := fContext.History.Count;
  finally
    fLock.Leave;
  end;
end;

end.
