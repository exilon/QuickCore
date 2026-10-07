{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.TaskControl.Persistence
  Description : TaskControl job persistence store (JSON file)
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

unit Quick.Core.TaskControl.Persistence;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.JSON,
  System.IOUtils,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.Math,
  Quick.Threads;

type
  /// <summary>Snapshot of a scheduled task's runtime state, suitable for
  /// serialization across process restarts.</summary>
  TTaskSnapshot = record
    Name            : string;
    LastExecution   : TDateTime;
    NextExecution   : TDateTime;
    ExecutionTimes  : Integer;
    ScheduleMode    : string;   // 'RunOnce' | 'Repeat'
    TimeInterval    : Integer;
    TimeMeasure     : string;   // 'Days' | 'Hours' | 'Minutes' | 'Seconds' | 'Milliseconds'
    MaxRetries      : Integer;
    RetryDelayMs    : Integer;
    RetryMultiplier : Double;
    Enabled         : Boolean;
    Finished        : Boolean;
    UpdatedAt       : TDateTime;
  end;

  THistoryEntry = Quick.Threads.THistoryEntry;

  /// <summary>Like THistoryEntry but includes the task name — used for
  /// the cross-task "Jobs" view (equivalent to Hangfire's Jobs panel).</summary>
  THistoryEntryEx = record
    TaskName      : string;
    ExecTime      : TDateTime;
    DurationMs    : Integer;
    Status        : string;
    ErrorMessage  : string;
    ExceptionType : string;
  end;

  /// <summary>Storage backend for task snapshots. Implement this interface
  /// to provide custom persistence (SQL Server, Redis, etc.).</summary>
  ITaskPersistenceStore = interface
  ['{9F3A1B2C-4D5E-6F7A-8B9C-0D1E2F3A4B5C}']
    /// <summary>Persist or update the snapshot for a task.</summary>
    procedure Save(const aSnapshot : TTaskSnapshot);
    /// <summary>Load a single snapshot by task name. Returns False if not found.</summary>
    function  Load(const aName : string; out aSnapshot : TTaskSnapshot) : Boolean;
    /// <summary>Load all persisted snapshots.</summary>
    function  LoadAll : TArray<TTaskSnapshot>;
    /// <summary>Remove the snapshot for a task.</summary>
    procedure Delete(const aName : string);
    /// <summary>Remove all persisted snapshots.</summary>
    procedure Clear;
    /// <summary>Persist a single execution history entry for a task.
    /// Called from the task worker thread after each run.</summary>
    procedure SaveHistoryEntry(const aTaskName : string; const aEntry : THistoryEntry);
    /// <summary>Load the last aMaxEntries history entries for a task,
    /// newest first. Returns empty array if not supported by the backend.</summary>
    function  LoadHistory(const aTaskName : string; aMaxEntries : Integer) : TArray<THistoryEntry>;
    /// <summary>Load a page of execution history across ALL tasks, newest first.
    /// Pass aStatus='' for all entries, or 'Done'/'Exception'/'Skipped' to filter.</summary>
    function  LoadAllHistory(const aStatus : string; aPage, aPageSize : Integer) : TArray<THistoryEntryEx>;
    /// <summary>Count total execution entries across all tasks, optionally filtered by status.</summary>
    function  CountAllHistory(const aStatus : string) : Int64;
  end;

  /// <summary>Persists task snapshots to a single JSON file.
  /// All snapshots are stored as a JSON object keyed by task name.
  /// Thread-safe via internal critical section.</summary>
  TJsonFileTaskStorage = class(TInterfacedObject, ITaskPersistenceStore)
  private
    fFilePath     : string;
    fHistFilePath : string;
    fLock         : TCriticalSection;
    function  InternalRead : TJSONObject;
    procedure InternalWrite(aRoot : TJSONObject);
    function  InternalReadHist : TJSONObject;
    procedure InternalWriteHist(aRoot : TJSONObject);
    function  SnapshotToJson(const aSnapshot : TTaskSnapshot) : TJSONObject;
    function  JsonToSnapshot(aObj : TJSONObject) : TTaskSnapshot;
    function  EntryToJson(const aEntry : THistoryEntry) : TJSONObject;
    function  JsonToEntry(aObj : TJSONObject) : THistoryEntry;
  public
    constructor Create(const aFilePath : string);
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

{ helpers }

function JsonStr(obj : TJSONObject; const key, def : string) : string;
var
  v : TJSONValue;
begin
  v := obj.GetValue(key);
  if v <> nil then Result := v.Value
  else Result := def;
end;

function JsonFloat(obj : TJSONObject; const key : string; def : Double) : Double;
var
  v : TJSONValue;
begin
  v := obj.GetValue(key);
  if (v <> nil) and (v is TJSONNumber) then Result := TJSONNumber(v).AsDouble
  else Result := def;
end;

function JsonInt(obj : TJSONObject; const key : string; def : Integer) : Integer;
var
  v : TJSONValue;
begin
  v := obj.GetValue(key);
  if (v <> nil) and (v is TJSONNumber) then Result := TJSONNumber(v).AsInt
  else Result := def;
end;

function JsonBool(obj : TJSONObject; const key : string; def : Boolean) : Boolean;
var
  v : TJSONValue;
begin
  v := obj.GetValue(key);
  if v <> nil then Result := LowerCase(v.Value) = 'true'
  else Result := def;
end;

{ TJsonFileTaskStorage }

constructor TJsonFileTaskStorage.Create(const aFilePath : string);
begin
  fFilePath     := aFilePath;
  fHistFilePath := TPath.ChangeExtension(aFilePath, '') + '.hist.json';
  fLock         := TCriticalSection.Create;
end;

destructor TJsonFileTaskStorage.Destroy;
begin
  fLock.Free;
  inherited;
end;

function TJsonFileTaskStorage.InternalRead : TJSONObject;
var
  raw  : string;
  parsed : TJSONValue;
begin
  if TFile.Exists(fFilePath) then
  begin
    raw    := TFile.ReadAllText(fFilePath, TEncoding.UTF8);
    parsed := TJSONObject.ParseJSONValue(raw);
    if parsed is TJSONObject then
      Result := parsed as TJSONObject
    else
    begin
      parsed.Free;
      Result := TJSONObject.Create;
    end;
  end
  else
    Result := TJSONObject.Create;
end;

procedure TJsonFileTaskStorage.InternalWrite(aRoot : TJSONObject);
var
  dir : string;
begin
  dir := TPath.GetDirectoryName(fFilePath);
  if (dir <> '') and not TDirectory.Exists(dir) then
    TDirectory.CreateDirectory(dir);
  TFile.WriteAllText(fFilePath, aRoot.ToJSON, TEncoding.UTF8);
end;

function TJsonFileTaskStorage.InternalReadHist : TJSONObject;
var
  raw    : string;
  parsed : TJSONValue;
begin
  if TFile.Exists(fHistFilePath) then
  begin
    raw    := TFile.ReadAllText(fHistFilePath, TEncoding.UTF8);
    parsed := TJSONObject.ParseJSONValue(raw);
    if parsed is TJSONObject then
      Result := parsed as TJSONObject
    else
    begin
      parsed.Free;
      Result := TJSONObject.Create;
    end;
  end
  else
    Result := TJSONObject.Create;
end;

procedure TJsonFileTaskStorage.InternalWriteHist(aRoot : TJSONObject);
var
  dir : string;
begin
  dir := TPath.GetDirectoryName(fHistFilePath);
  if (dir <> '') and not TDirectory.Exists(dir) then
    TDirectory.CreateDirectory(dir);
  TFile.WriteAllText(fHistFilePath, aRoot.ToJSON, TEncoding.UTF8);
end;

function TJsonFileTaskStorage.SnapshotToJson(const aSnapshot : TTaskSnapshot) : TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name',            aSnapshot.Name);
  Result.AddPair('lastExecution',   TJSONNumber.Create(aSnapshot.LastExecution));
  Result.AddPair('nextExecution',   TJSONNumber.Create(aSnapshot.NextExecution));
  Result.AddPair('executionTimes',  TJSONNumber.Create(aSnapshot.ExecutionTimes));
  Result.AddPair('scheduleMode',    aSnapshot.ScheduleMode);
  Result.AddPair('timeInterval',    TJSONNumber.Create(aSnapshot.TimeInterval));
  Result.AddPair('timeMeasure',     aSnapshot.TimeMeasure);
  Result.AddPair('maxRetries',      TJSONNumber.Create(aSnapshot.MaxRetries));
  Result.AddPair('retryDelayMs',    TJSONNumber.Create(aSnapshot.RetryDelayMs));
  Result.AddPair('retryMultiplier', TJSONNumber.Create(aSnapshot.RetryMultiplier));
  Result.AddPair('enabled',         TJSONBool.Create(aSnapshot.Enabled));
  Result.AddPair('finished',        TJSONBool.Create(aSnapshot.Finished));
  Result.AddPair('updatedAt',       TJSONNumber.Create(aSnapshot.UpdatedAt));
end;

function TJsonFileTaskStorage.JsonToSnapshot(aObj : TJSONObject) : TTaskSnapshot;
begin
  Result.Name            := JsonStr(aObj,   'name',            '');
  Result.LastExecution   := JsonFloat(aObj, 'lastExecution',   0);
  Result.NextExecution   := JsonFloat(aObj, 'nextExecution',   0);
  Result.ExecutionTimes  := JsonInt(aObj,   'executionTimes',  0);
  Result.ScheduleMode    := JsonStr(aObj,   'scheduleMode',    '');
  Result.TimeInterval    := JsonInt(aObj,   'timeInterval',    0);
  Result.TimeMeasure     := JsonStr(aObj,   'timeMeasure',     '');
  Result.MaxRetries      := JsonInt(aObj,   'maxRetries',      0);
  Result.RetryDelayMs    := JsonInt(aObj,   'retryDelayMs',    0);
  Result.RetryMultiplier := JsonFloat(aObj, 'retryMultiplier', 1.0);
  Result.Enabled         := JsonBool(aObj,  'enabled',         True);
  Result.Finished        := JsonBool(aObj,  'finished',        False);
  Result.UpdatedAt       := JsonFloat(aObj, 'updatedAt',       0);
end;

function TJsonFileTaskStorage.EntryToJson(const aEntry : THistoryEntry) : TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('execTime',      TJSONNumber.Create(aEntry.ExecTime));
  Result.AddPair('durationMs',    TJSONNumber.Create(aEntry.DurationMs));
  Result.AddPair('status',        aEntry.Status);
  Result.AddPair('errorMessage',  aEntry.ErrorMessage);
  Result.AddPair('exceptionType', aEntry.ExceptionType);
end;

function TJsonFileTaskStorage.JsonToEntry(aObj : TJSONObject) : THistoryEntry;
begin
  Result.ExecTime      := JsonFloat(aObj, 'execTime',      0);
  Result.DurationMs    := JsonInt(aObj,   'durationMs',    0);
  Result.Status        := JsonStr(aObj,   'status',        '');
  Result.ErrorMessage  := JsonStr(aObj,   'errorMessage',  '');
  Result.ExceptionType := JsonStr(aObj,   'exceptionType', '');
end;

procedure TJsonFileTaskStorage.Save(const aSnapshot : TTaskSnapshot);
var
  root     : TJSONObject;
  taskObj  : TJSONObject;
  existing : TJSONPair;
begin
  fLock.Enter;
  try
    root := InternalRead;
    try
      taskObj  := SnapshotToJson(aSnapshot);
      existing := root.RemovePair(aSnapshot.Name);
      if existing <> nil then
        existing.Free;
      root.AddPair(aSnapshot.Name, taskObj);
      InternalWrite(root);
    finally
      root.Free;
    end;
  finally
    fLock.Leave;
  end;
end;

function TJsonFileTaskStorage.Load(const aName : string; out aSnapshot : TTaskSnapshot) : Boolean;
var
  root    : TJSONObject;
  taskVal : TJSONValue;
begin
  Result := False;
  fLock.Enter;
  try
    root := InternalRead;
    try
      taskVal := root.GetValue(aName);
      if (taskVal <> nil) and (taskVal is TJSONObject) then
      begin
        aSnapshot := JsonToSnapshot(taskVal as TJSONObject);
        Result    := True;
      end;
    finally
      root.Free;
    end;
  finally
    fLock.Leave;
  end;
end;

function TJsonFileTaskStorage.LoadAll : TArray<TTaskSnapshot>;
var
  root : TJSONObject;
  pair : TJSONPair;
  list : TArray<TTaskSnapshot>;
  idx  : Integer;
begin
  fLock.Enter;
  try
    root := InternalRead;
    try
      SetLength(list, root.Count);
      idx := 0;
      for pair in root do
      begin
        if pair.JsonValue is TJSONObject then
        begin
          list[idx] := JsonToSnapshot(pair.JsonValue as TJSONObject);
          Inc(idx);
        end;
      end;
      SetLength(list, idx);
      Result := list;
    finally
      root.Free;
    end;
  finally
    fLock.Leave;
  end;
end;

procedure TJsonFileTaskStorage.Delete(const aName : string);
var
  root : TJSONObject;
  pair : TJSONPair;
begin
  fLock.Enter;
  try
    root := InternalRead;
    try
      pair := root.RemovePair(aName);
      if pair <> nil then
      begin
        pair.Free;
        InternalWrite(root);
      end;
    finally
      root.Free;
    end;
  finally
    fLock.Leave;
  end;
end;

procedure TJsonFileTaskStorage.Clear;
var
  root : TJSONObject;
begin
  fLock.Enter;
  try
    root := TJSONObject.Create;
    try
      InternalWrite(root);
    finally
      root.Free;
    end;
  finally
    fLock.Leave;
  end;
end;

procedure TJsonFileTaskStorage.SaveHistoryEntry(const aTaskName : string; const aEntry : THistoryEntry);
var
  root     : TJSONObject;
  arr      : TJSONArray;
  arrVal   : TJSONValue;
  existing : TJSONPair;
begin
  fLock.Enter;
  try
    root := InternalReadHist;
    try
      arrVal := root.GetValue(aTaskName);
      if (arrVal <> nil) and (arrVal is TJSONArray) then
        arr := arrVal as TJSONArray
      else
      begin
        existing := root.RemovePair(aTaskName);
        if existing <> nil then existing.Free;
        arr := TJSONArray.Create;
        root.AddPair(aTaskName, arr);
      end;
      // Append newest entry and cap at 500 entries (oldest removed from front)
      arr.AddElement(EntryToJson(aEntry));
      while arr.Count > 500 do
        arr.Remove(0);
      InternalWriteHist(root);
    finally
      root.Free;
    end;
  finally
    fLock.Leave;
  end;
end;

function TJsonFileTaskStorage.LoadHistory(const aTaskName : string; aMaxEntries : Integer) : TArray<THistoryEntry>;
var
  root    : TJSONObject;
  arrVal  : TJSONValue;
  arr     : TJSONArray;
  list    : TArray<THistoryEntry>;
  i, cnt  : Integer;
begin
  fLock.Enter;
  try
    root := InternalReadHist;
    try
      arrVal := root.GetValue(aTaskName);
      if (arrVal = nil) or not (arrVal is TJSONArray) then
      begin
        Result := [];
        Exit;
      end;
      arr := arrVal as TJSONArray;
      cnt := arr.Count;
      if cnt > aMaxEntries then cnt := aMaxEntries;
      SetLength(list, cnt);
      // Newest first: iterate from the end of the array
      for i := 0 to cnt - 1 do
      begin
        if arr.Items[arr.Count - 1 - i] is TJSONObject then
          list[i] := JsonToEntry(arr.Items[arr.Count - 1 - i] as TJSONObject);
      end;
      Result := list;
    finally
      root.Free;
    end;
  finally
    fLock.Leave;
  end;
end;

function TJsonFileTaskStorage.LoadAllHistory(const aStatus : string; aPage, aPageSize : Integer) : TArray<THistoryEntryEx>;
var
  root     : TJSONObject;
  pair     : TJSONPair;
  arr      : TJSONArray;
  obj      : TJSONObject;
  all      : TList<THistoryEntryEx>;
  ex       : THistoryEntryEx;
  i, skip  : Integer;
begin
  fLock.Enter;
  try
    root := InternalReadHist;
    try
      all := TList<THistoryEntryEx>.Create;
      try
        for pair in root do
        begin
          if not (pair.JsonValue is TJSONArray) then Continue;
          arr := pair.JsonValue as TJSONArray;
          for i := arr.Count - 1 downto 0 do
          begin
            if not (arr.Items[i] is TJSONObject) then Continue;
            obj := arr.Items[i] as TJSONObject;
            ex.TaskName      := pair.JsonString.Value;
            ex.ExecTime      := JsonFloat(obj, 'execTime',      0);
            ex.DurationMs    := JsonInt(obj,   'durationMs',    0);
            ex.Status        := JsonStr(obj,   'status',        '');
            ex.ErrorMessage  := JsonStr(obj,   'errorMessage',  '');
            ex.ExceptionType := JsonStr(obj,   'exceptionType', '');
            if (aStatus = '') or (ex.Status = aStatus) then
              all.Add(ex);
          end;
        end;
        // Sort all entries newest-first by ExecTime
        all.Sort(TComparer<THistoryEntryEx>.Construct(
          function(const L, R : THistoryEntryEx) : Integer
          begin
            if L.ExecTime > R.ExecTime then Result := -1
            else if L.ExecTime < R.ExecTime then Result := 1
            else Result := 0;
          end));
        skip := (aPage - 1) * aPageSize;
        if skip >= all.Count then
        begin
          Result := [];
          Exit;
        end;
        SetLength(Result, Min(aPageSize, all.Count - skip));
        for i := 0 to Length(Result) - 1 do
          Result[i] := all[skip + i];
      finally
        all.Free;
      end;
    finally
      root.Free;
    end;
  finally
    fLock.Leave;
  end;
end;

function TJsonFileTaskStorage.CountAllHistory(const aStatus : string) : Int64;
var
  root  : TJSONObject;
  pair  : TJSONPair;
  arr   : TJSONArray;
  obj   : TJSONObject;
  st    : string;
  i     : Integer;
begin
  Result := 0;
  fLock.Enter;
  try
    root := InternalReadHist;
    try
      for pair in root do
      begin
        if not (pair.JsonValue is TJSONArray) then Continue;
        arr := pair.JsonValue as TJSONArray;
        if aStatus = '' then
          Inc(Result, arr.Count)
        else
          for i := 0 to arr.Count - 1 do
          begin
            if not (arr.Items[i] is TJSONObject) then Continue;
            obj := arr.Items[i] as TJSONObject;
            st := JsonStr(obj, 'status', '');
            if st = aStatus then Inc(Result);
          end;
      end;
    finally
      root.Free;
    end;
  finally
    fLock.Leave;
  end;
end;

end.
