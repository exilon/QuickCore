{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.TaskControl.Persistence.ADO
  Description : TaskControl ADO (SQL Server / SQLite / Access) persistence
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

unit Quick.Core.TaskControl.Persistence.ADO;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.SyncObjs,
  Data.DB,
  ADODB,
  Quick.Threads,
  Quick.Core.TaskControl.Persistence;

type
  /// <summary>Persists task snapshots to any ADO-compatible database
  /// (SQL Server, SQLite via ODBC, MS Access, etc.).
  /// The table TC_TASKS is created automatically on first connection.
  ///
  /// Usage:
  ///   taskControl.UseStorage(
  ///     TADOTaskStorage.Create('Provider=SQLOLEDB;Server=.;Database=MyDB;Trusted_Connection=yes;'));
  ///
  /// Note: ADO requires COM to be initialized on any thread that calls Save.
  /// The periodic save thread in TTaskControl initialises COM automatically on Windows.
  /// </summary>
  TADOTaskStorage = class(TInterfacedObject, ITaskPersistenceStore)
  private
    fConnection : TADOConnection;
    fLock       : TCriticalSection;
    procedure ExecCmd(const aSQL : string);
    procedure EnsureTable;
    function  SnapshotFromQuery(aQuery : TADOQuery) : TTaskSnapshot;
  public
    constructor Create(const aConnectionString : string);
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

const
  SQL_TABLE_NAME = 'TC_TASKS';
  SQL_HIST_TABLE = 'TC_TASK_HISTORY';

  // Portable CREATE TABLE — works with SQL Server 2016+, SQLite, Access.
  // For SQL Server 2014 and below, use the IF NOT EXISTS form manually.
  SQL_CREATE_MSSQL =
    'IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = ''' + SQL_TABLE_NAME + ''') ' +
    'CREATE TABLE ' + SQL_TABLE_NAME + ' (' +
    '  Name            NVARCHAR(255) NOT NULL PRIMARY KEY,' +
    '  LastExecution   FLOAT         NOT NULL DEFAULT 0,' +
    '  NextExecution   FLOAT         NOT NULL DEFAULT 0,' +
    '  ExecutionTimes  INT           NOT NULL DEFAULT 0,' +
    '  ScheduleMode    NVARCHAR(50)  NOT NULL DEFAULT '''',' +
    '  TimeInterval    INT           NOT NULL DEFAULT 0,' +
    '  TimeMeasure     NVARCHAR(50)  NOT NULL DEFAULT '''',' +
    '  MaxRetries      INT           NOT NULL DEFAULT 0,' +
    '  RetryDelayMs    INT           NOT NULL DEFAULT 0,' +
    '  RetryMultiplier FLOAT         NOT NULL DEFAULT 1,' +
    '  Enabled         SMALLINT      NOT NULL DEFAULT 1,' +
    '  Finished        SMALLINT      NOT NULL DEFAULT 0,' +
    '  UpdatedAt       FLOAT         NOT NULL DEFAULT 0' +
    ')';

  SQL_CREATE_HIST_MSSQL =
    'IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = ''' + SQL_HIST_TABLE + ''') ' +
    'CREATE TABLE ' + SQL_HIST_TABLE + ' (' +
    '  Id            BIGINT        NOT NULL IDENTITY(1,1) PRIMARY KEY,' +
    '  TaskName      NVARCHAR(255) NOT NULL,' +
    '  ExecTime      FLOAT         NOT NULL DEFAULT 0,' +
    '  DurationMs    INT           NOT NULL DEFAULT 0,' +
    '  Status        NVARCHAR(50)  NOT NULL DEFAULT '''',' +
    '  ErrorMessage  NVARCHAR(2000) NOT NULL DEFAULT '''',' +
    '  ExceptionType NVARCHAR(500) NOT NULL DEFAULT '''''' +
    ')';

  SQL_CREATE_HIST_GENERIC =
    'CREATE TABLE ' + SQL_HIST_TABLE + ' (' +
    '  Id            INTEGER      NOT NULL PRIMARY KEY AUTOINCREMENT,' +
    '  TaskName      VARCHAR(255) NOT NULL,' +
    '  ExecTime      FLOAT        NOT NULL DEFAULT 0,' +
    '  DurationMs    INTEGER      NOT NULL DEFAULT 0,' +
    '  Status        VARCHAR(50)  NOT NULL DEFAULT '''',' +
    '  ErrorMessage  VARCHAR(2000) NOT NULL DEFAULT '''',' +
    '  ExceptionType VARCHAR(500) NOT NULL DEFAULT '''''' +
    ')';

  SQL_CREATE_GENERIC =
    'CREATE TABLE ' + SQL_TABLE_NAME + ' (' +
    '  Name            VARCHAR(255) NOT NULL PRIMARY KEY,' +
    '  LastExecution   FLOAT        NOT NULL DEFAULT 0,' +
    '  NextExecution   FLOAT        NOT NULL DEFAULT 0,' +
    '  ExecutionTimes  INTEGER      NOT NULL DEFAULT 0,' +
    '  ScheduleMode    VARCHAR(50)  NOT NULL DEFAULT '''',' +
    '  TimeInterval    INTEGER      NOT NULL DEFAULT 0,' +
    '  TimeMeasure     VARCHAR(50)  NOT NULL DEFAULT '''',' +
    '  MaxRetries      INTEGER      NOT NULL DEFAULT 0,' +
    '  RetryDelayMs    INTEGER      NOT NULL DEFAULT 0,' +
    '  RetryMultiplier FLOAT        NOT NULL DEFAULT 1,' +
    '  Enabled         SMALLINT     NOT NULL DEFAULT 0,' +
    '  Finished        SMALLINT     NOT NULL DEFAULT 0,' +
    '  UpdatedAt       FLOAT        NOT NULL DEFAULT 0' +
    ')';

{ TADOTaskStorage }

constructor TADOTaskStorage.Create(const aConnectionString : string);
begin
  fLock             := TCriticalSection.Create;
  fConnection       := TADOConnection.Create(nil);
  fConnection.LoginPrompt      := False;
  fConnection.ConnectionString := aConnectionString;
  fConnection.Open;
  EnsureTable;
end;

destructor TADOTaskStorage.Destroy;
begin
  if fConnection.Connected then
    fConnection.Close;
  fConnection.Free;
  fLock.Free;
  inherited;
end;

procedure TADOTaskStorage.ExecCmd(const aSQL : string);
var
  cmd : TADOCommand;
begin
  cmd := TADOCommand.Create(nil);
  try
    cmd.Connection  := fConnection;
    cmd.CommandText := aSQL;
    cmd.Execute;
  finally
    cmd.Free;
  end;
end;

procedure TADOTaskStorage.EnsureTable;
begin
  // Try SQL Server syntax first; fall back to generic CREATE TABLE.
  // Swallow "table already exists" errors from other providers.
  try
    ExecCmd(SQL_CREATE_MSSQL);
  except
    try
      ExecCmd(SQL_CREATE_GENERIC);
    except
      // Table already exists — ignore
    end;
  end;
  // History table
  try
    ExecCmd(SQL_CREATE_HIST_MSSQL);
  except
    try
      ExecCmd(SQL_CREATE_HIST_GENERIC);
    except
      // Already exists
    end;
  end;
end;

function TADOTaskStorage.SnapshotFromQuery(aQuery : TADOQuery) : TTaskSnapshot;
begin
  Result.Name            := aQuery.FieldByName('Name').AsString;
  Result.LastExecution   := aQuery.FieldByName('LastExecution').AsFloat;
  Result.NextExecution   := aQuery.FieldByName('NextExecution').AsFloat;
  Result.ExecutionTimes  := aQuery.FieldByName('ExecutionTimes').AsInteger;
  Result.ScheduleMode    := aQuery.FieldByName('ScheduleMode').AsString;
  Result.TimeInterval    := aQuery.FieldByName('TimeInterval').AsInteger;
  Result.TimeMeasure     := aQuery.FieldByName('TimeMeasure').AsString;
  Result.MaxRetries      := aQuery.FieldByName('MaxRetries').AsInteger;
  Result.RetryDelayMs    := aQuery.FieldByName('RetryDelayMs').AsInteger;
  Result.RetryMultiplier := aQuery.FieldByName('RetryMultiplier').AsFloat;
  Result.Enabled         := aQuery.FieldByName('Enabled').AsInteger <> 0;
  Result.Finished        := aQuery.FieldByName('Finished').AsInteger <> 0;
  Result.UpdatedAt       := aQuery.FieldByName('UpdatedAt').AsFloat;
end;

procedure TADOTaskStorage.Save(const aSnapshot : TTaskSnapshot);
var
  qry : TADOQuery;
begin
  fLock.Enter;
  try
    qry := TADOQuery.Create(nil);
    try
      qry.Connection := fConnection;

      // DELETE existing row first (portable UPSERT across all engines)
      qry.SQL.Text := 'DELETE FROM ' + SQL_TABLE_NAME + ' WHERE Name = :Name';
      qry.Parameters.ParamByName('Name').Value := aSnapshot.Name;
      qry.ExecSQL;

      // INSERT new row
      qry.SQL.Text :=
        'INSERT INTO ' + SQL_TABLE_NAME +
        ' (Name,LastExecution,NextExecution,ExecutionTimes,' +
        'ScheduleMode,TimeInterval,TimeMeasure,MaxRetries,RetryDelayMs,' +
        'RetryMultiplier,Enabled,Finished,UpdatedAt) VALUES ' +
        '(:Name,:LastExecution,:NextExecution,:ExecutionTimes,' +
        ':ScheduleMode,:TimeInterval,:TimeMeasure,:MaxRetries,:RetryDelayMs,' +
        ':RetryMultiplier,:Enabled,:Finished,:UpdatedAt)';
      qry.Parameters.ParamByName('Name').Value            := aSnapshot.Name;
      qry.Parameters.ParamByName('LastExecution').Value   := aSnapshot.LastExecution;
      qry.Parameters.ParamByName('NextExecution').Value   := aSnapshot.NextExecution;
      qry.Parameters.ParamByName('ExecutionTimes').Value  := aSnapshot.ExecutionTimes;
      qry.Parameters.ParamByName('ScheduleMode').Value    := aSnapshot.ScheduleMode;
      qry.Parameters.ParamByName('TimeInterval').Value    := aSnapshot.TimeInterval;
      qry.Parameters.ParamByName('TimeMeasure').Value     := aSnapshot.TimeMeasure;
      qry.Parameters.ParamByName('MaxRetries').Value      := aSnapshot.MaxRetries;
      qry.Parameters.ParamByName('RetryDelayMs').Value    := aSnapshot.RetryDelayMs;
      qry.Parameters.ParamByName('RetryMultiplier').Value := aSnapshot.RetryMultiplier;
      qry.Parameters.ParamByName('Enabled').Value         := Integer(aSnapshot.Enabled);
      qry.Parameters.ParamByName('Finished').Value        := Integer(aSnapshot.Finished);
      qry.Parameters.ParamByName('UpdatedAt').Value       := aSnapshot.UpdatedAt;
      qry.ExecSQL;
    finally
      qry.Free;
    end;
  finally
    fLock.Leave;
  end;
end;

function TADOTaskStorage.Load(const aName : string; out aSnapshot : TTaskSnapshot) : Boolean;
var
  qry : TADOQuery;
begin
  Result := False;
  fLock.Enter;
  try
    qry := TADOQuery.Create(nil);
    try
      qry.Connection := fConnection;
      qry.SQL.Text   := 'SELECT * FROM ' + SQL_TABLE_NAME + ' WHERE Name = :Name';
      qry.Parameters.ParamByName('Name').Value := aName;
      qry.Open;
      if not qry.IsEmpty then
      begin
        aSnapshot := SnapshotFromQuery(qry);
        Result    := True;
      end;
    finally
      qry.Free;
    end;
  finally
    fLock.Leave;
  end;
end;

function TADOTaskStorage.LoadAll : TArray<TTaskSnapshot>;
var
  qry  : TADOQuery;
  list : TArray<TTaskSnapshot>;
  idx  : Integer;
begin
  fLock.Enter;
  try
    qry := TADOQuery.Create(nil);
    try
      qry.Connection := fConnection;
      qry.SQL.Text   := 'SELECT * FROM ' + SQL_TABLE_NAME;
      qry.Open;
      SetLength(list, 256);
      idx := 0;
      while not qry.Eof do
      begin
        if idx >= Length(list) then
          SetLength(list, Length(list) * 2);
        list[idx] := SnapshotFromQuery(qry);
        Inc(idx);
        qry.Next;
      end;
      SetLength(list, idx);
      Result := list;
    finally
      qry.Free;
    end;
  finally
    fLock.Leave;
  end;
end;

procedure TADOTaskStorage.Delete(const aName : string);
var
  qry : TADOQuery;
begin
  fLock.Enter;
  try
    qry := TADOQuery.Create(nil);
    try
      qry.Connection := fConnection;
      qry.SQL.Text   := 'DELETE FROM ' + SQL_TABLE_NAME + ' WHERE Name = :Name';
      qry.Parameters.ParamByName('Name').Value := aName;
      qry.ExecSQL;
    finally
      qry.Free;
    end;
  finally
    fLock.Leave;
  end;
end;

procedure TADOTaskStorage.Clear;
begin
  fLock.Enter;
  try
    ExecCmd('DELETE FROM ' + SQL_TABLE_NAME);
  finally
    fLock.Leave;
  end;
end;

procedure TADOTaskStorage.SaveHistoryEntry(const aTaskName : string; const aEntry : THistoryEntry);
var
  qry : TADOQuery;
begin
  fLock.Enter;
  try
    qry := TADOQuery.Create(nil);
    try
      qry.Connection := fConnection;
      qry.SQL.Text :=
        'INSERT INTO ' + SQL_HIST_TABLE +
        ' (TaskName,ExecTime,DurationMs,Status,ErrorMessage,ExceptionType) VALUES ' +
        '(:TaskName,:ExecTime,:DurationMs,:Status,:ErrorMessage,:ExceptionType)';
      qry.Parameters.ParamByName('TaskName').Value      := aTaskName;
      qry.Parameters.ParamByName('ExecTime').Value      := aEntry.ExecTime;
      qry.Parameters.ParamByName('DurationMs').Value    := aEntry.DurationMs;
      qry.Parameters.ParamByName('Status').Value        := aEntry.Status;
      qry.Parameters.ParamByName('ErrorMessage').Value  := aEntry.ErrorMessage;
      qry.Parameters.ParamByName('ExceptionType').Value := aEntry.ExceptionType;
      qry.ExecSQL;
    finally
      qry.Free;
    end;
  finally
    fLock.Leave;
  end;
end;

function TADOTaskStorage.LoadHistory(const aTaskName : string; aMaxEntries : Integer) : TArray<THistoryEntry>;
var
  qry  : TADOQuery;
  list : TArray<THistoryEntry>;
  idx  : Integer;
  e    : THistoryEntry;
begin
  fLock.Enter;
  try
    qry := TADOQuery.Create(nil);
    try
      qry.Connection := fConnection;
      // Newest first; TOP syntax works for SQL Server. SQLite via ODBC may vary.
      qry.SQL.Text   :=
        'SELECT TOP ' + IntToStr(aMaxEntries) + ' * FROM ' + SQL_HIST_TABLE +
        ' WHERE TaskName = :TaskName ORDER BY Id DESC';
      qry.Parameters.ParamByName('TaskName').Value := aTaskName;
      qry.Open;
      SetLength(list, aMaxEntries);
      idx := 0;
      while not qry.Eof do
      begin
        e.ExecTime      := qry.FieldByName('ExecTime').AsFloat;
        e.DurationMs    := qry.FieldByName('DurationMs').AsInteger;
        e.Status        := qry.FieldByName('Status').AsString;
        e.ErrorMessage  := qry.FieldByName('ErrorMessage').AsString;
        e.ExceptionType := qry.FieldByName('ExceptionType').AsString;
        list[idx] := e;
        Inc(idx);
        qry.Next;
      end;
      SetLength(list, idx);
      Result := list;
    finally
      qry.Free;
    end;
  finally
    fLock.Leave;
  end;
end;

function TADOTaskStorage.LoadAllHistory(const aStatus : string; aPage, aPageSize : Integer) : TArray<THistoryEntryEx>;
var
  qry       : TADOQuery;
  list      : TList<THistoryEntryEx>;
  ex        : THistoryEntryEx;
  whereClau : string;
begin
  fLock.Enter;
  try
    qry := TADOQuery.Create(nil);
    try
      qry.Connection := fConnection;
      if aStatus <> '' then
        whereClau := ' WHERE Status = :Status'
      else
        whereClau := '';
      qry.SQL.Text :=
        'SELECT TOP ' + IntToStr(aPage * aPageSize) +
        ' TaskName,ExecTime,DurationMs,Status,ErrorMessage,ExceptionType' +
        ' FROM ' + SQL_HIST_TABLE + whereClau + ' ORDER BY Id DESC';
      if aStatus <> '' then
        qry.Parameters.ParamByName('Status').Value := aStatus;
      qry.Open;
      // Skip the first (aPage-1)*aPageSize rows
      var skip := (aPage - 1) * aPageSize;
      var cnt  := 0;
      while (cnt < skip) and not qry.Eof do begin qry.Next; Inc(cnt); end;
      list := TList<THistoryEntryEx>.Create;
      try
        while not qry.Eof do
        begin
          ex.TaskName      := qry.FieldByName('TaskName').AsString;
          ex.ExecTime      := qry.FieldByName('ExecTime').AsFloat;
          ex.DurationMs    := qry.FieldByName('DurationMs').AsInteger;
          ex.Status        := qry.FieldByName('Status').AsString;
          ex.ErrorMessage  := qry.FieldByName('ErrorMessage').AsString;
          ex.ExceptionType := qry.FieldByName('ExceptionType').AsString;
          list.Add(ex);
          qry.Next;
        end;
        Result := list.ToArray;
      finally
        list.Free;
      end;
    finally
      qry.Free;
    end;
  finally
    fLock.Leave;
  end;
end;

function TADOTaskStorage.CountAllHistory(const aStatus : string) : Int64;
var
  qry : TADOQuery;
begin
  Result := 0;
  fLock.Enter;
  try
    qry := TADOQuery.Create(nil);
    try
      qry.Connection := fConnection;
      if aStatus <> '' then
      begin
        qry.SQL.Text := 'SELECT COUNT(*) AS N FROM ' + SQL_HIST_TABLE + ' WHERE Status = :Status';
        qry.Parameters.ParamByName('Status').Value := aStatus;
      end
      else
        qry.SQL.Text := 'SELECT COUNT(*) AS N FROM ' + SQL_HIST_TABLE;
      qry.Open;
      if not qry.Eof then
        Result := qry.Fields[0].AsInteger;
    finally
      qry.Free;
    end;
  finally
    fLock.Leave;
  end;
end;

end.
