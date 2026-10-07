{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Extension.TaskControl
  Description : Core TaskControl Extension
  Author      : Kike Perez
  Version     : 1.0
  Created     : 19/10/2019
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

unit Quick.Core.TaskControl;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  {$IFDEF MSWINDOWS}Winapi.ActiveX,{$ENDIF}
  Quick.Threads,
  Quick.Options,
  Quick.Core.DependencyInjection,
  Quick.Core.TaskControl.Persistence;

type
  TTaskControlServiceExtension = class(TServiceCollectionExtension)
    class function AddTaskControl : TServiceCollection;
  end;

  TTaskControlSettings = class(TOptions)
  private
    fConcurrentWorkers : Integer;
  published
    [Range(1,1000)]
    property ConcurrentWorkers : Integer read fConcurrentWorkers write fConcurrentWorkers;
  end;

  ITaskControl = interface
  ['{0F283549-7AB1-4ACC-A398-66C8B5455EEA}']
    function BackgroundTasks : TBackgroundTasks;
    function ScheduledTasks : TScheduledTasks;
    procedure RemoveTask(const aTaskName : string);
    procedure PauseAll;
    procedure ResumeAll;
    function IsPaused : Boolean;
    /// <summary>Configure JSON-file persistence. Call after registering all tasks.
    /// Stats (executionTimes, lastExecution) are restored immediately and saved
    /// automatically every 30 seconds.</summary>
    function UseStorage(const aFilePath : string) : ITaskControl; overload;
    /// <summary>Configure a custom persistence store. Call after registering all tasks.</summary>
    function UseStorage(aStore : ITaskPersistenceStore) : ITaskControl; overload;
    function GetCurrentRunningTasksJson : string;
    /// <summary>Returns persisted history for a task (newest first).
    /// Falls back to the in-memory ring buffer when no store is configured.</summary>
    function LoadTaskHistory(const aName : string; aMaxEntries : Integer = 100) : TArray<THistoryEntry>;
    /// <summary>Returns a page of execution history across ALL tasks (newest first).
    /// Pass aStatus='' for all, or 'Done'/'Exception'/'Skipped' to filter.
    /// Requires a persistence store; returns empty array otherwise.</summary>
    function LoadAllJobHistory(const aStatus : string; aPage, aPageSize : Integer) : TArray<THistoryEntryEx>;
    /// <summary>Counts total execution entries across all tasks, optionally filtered by status.</summary>
    function CountAllJobHistory(const aStatus : string) : Int64;
  end;

  /// <summary>One buffered history entry waiting to be flushed to the store.</summary>
  TPendingHistoryEntry = record
    TaskName : string;
    Entry    : THistoryEntry;
  end;

  TTaskControl = class(TInterfacedObject,ITaskControl)
  private
    fBackgroundTasks   : TBackgroundTasks;
    fScheduledTasks    : TScheduledTasks;
    fPersistenceStore  : ITaskPersistenceStore;
    fPersistThread     : TThread;
    fPendingHistory    : TList<TPendingHistoryEntry>;
    fPendingHistLock   : TCriticalSection;
    function  SnapshotFromTask(const aTask : IScheduledTask) : TTaskSnapshot;
    function  TimeMeasureStr(aMeasure : TTimeMeasure) : string;
    function  ScheduleModeStr(aMode : TScheduleMode) : string;
    procedure InternalSaveSnapshot;
    procedure InternalRestoreSnapshot;
    procedure HookHistoryCallback(const aTask : IScheduledTask);
  public
    constructor Create(aOptions : IOptions<TTaskControlSettings>);
    destructor Destroy; override;
    function BackgroundTasks : TBackgroundTasks;
    function ScheduledTasks : TScheduledTasks;
    procedure RemoveTask(const aTaskName : string);
    procedure PauseAll;
    procedure ResumeAll;
    function IsPaused : Boolean;
    function UseStorage(const aFilePath : string) : ITaskControl; overload;
    function UseStorage(aStore : ITaskPersistenceStore) : ITaskControl; overload;
    function GetCurrentRunningTasksJson : string;
    /// <summary>Returns persisted history for a task (newest first).
    /// Falls back to the in-memory ring buffer when no store is configured.</summary>
    function LoadTaskHistory(const aName : string; aMaxEntries : Integer = 100) : TArray<THistoryEntry>;
    /// <summary>Returns a page of execution history across ALL tasks (newest first).
    /// Pass aStatus='' for all, or 'Done'/'Exception'/'Skipped' to filter.
    /// Requires a persistence store; returns empty array otherwise.</summary>
    function LoadAllJobHistory(const aStatus : string; aPage, aPageSize : Integer) : TArray<THistoryEntryEx>;
    /// <summary>Counts total execution entries across all tasks, optionally filtered by status.</summary>
    function CountAllJobHistory(const aStatus : string) : Int64;
  end;

implementation

{ TTaskPersistThread — saves snapshots every N milliseconds }

type
  TTaskPersistThread = class(TThread)
  private
    fIntervalMs : Cardinal;
    fOnSave     : TProc;
  protected
    procedure Execute; override;
  public
    constructor Create(aIntervalMs : Cardinal; aOnSave : TProc);
  end;

constructor TTaskPersistThread.Create(aIntervalMs : Cardinal; aOnSave : TProc);
begin
  fIntervalMs      := aIntervalMs;
  fOnSave          := aOnSave;
  FreeOnTerminate  := False;
  inherited Create(False);
end;

procedure TTaskPersistThread.Execute;
var
  elapsed : Cardinal;
begin
  {$IFDEF MSWINDOWS}
  CoInitialize(nil);
  {$ENDIF}
  try
    elapsed := 0;
    while not Terminated do
    begin
      Sleep(100);
      Inc(elapsed, 100);
      if (elapsed >= fIntervalMs) and not Terminated then
      begin
        elapsed := 0;
        try
          fOnSave();
        except
          // Swallow errors to avoid crashing the persist thread
        end;
      end;
    end;
    // Final save on shutdown
    try
      fOnSave();
    except
    end;
  finally
    {$IFDEF MSWINDOWS}
    CoUninitialize;
    {$ENDIF}
  end;
end;

{ TTaskControl }

function TTaskControl.BackgroundTasks: TBackgroundTasks;
begin
  Result := fBackgroundTasks;
end;

constructor TTaskControl.Create(aOptions : IOptions<TTaskControlSettings>);
var
  settings : TTaskControlSettings;
begin
  settings := aOptions.Value;
  fBackgroundTasks := TBackgroundTasks.Create(settings.ConcurrentWorkers);
  fScheduledTasks := TScheduledTasks.Create;
  fPendingHistory  := TList<TPendingHistoryEntry>.Create;
  fPendingHistLock := TCriticalSection.Create;
  fBackgroundTasks.SetOnHistoryEntry(procedure(const aTaskName : string; const aEntry : THistoryEntry)
    var
      pending : TPendingHistoryEntry;
    begin
      pending.TaskName := aTaskName;
      pending.Entry    := aEntry;
      fPendingHistLock.Enter;
      try
        fPendingHistory.Add(pending);
      finally
        fPendingHistLock.Leave;
      end;
    end);
  fBackgroundTasks.Start;
  fScheduledTasks.Start;
end;

destructor TTaskControl.Destroy;
begin
  if fPersistThread <> nil then
  begin
    fPersistThread.Terminate;
    fPersistThread.WaitFor;
    fPersistThread.Free;
  end;
  fPendingHistLock.Free;
  fPendingHistory.Free;
  fBackgroundTasks.Free;
  fScheduledTasks.Stop;
  fScheduledTasks.Free;
  inherited;
end;

function TTaskControl.GetCurrentRunningTasksJson: string;
begin
  Result := Format('{"backgroundTasks":{"queued":%d,"workers":%d,"active":%d,"totalPushed":%d},"scheduledTasks":{"totalPushed":%d,"paused":%s}}',
    [BackgroundTasks.TaskQueued,
     BackgroundTasks.ConcurrentWorkers,
     BackgroundTasks.ActiveWorkers,
     BackgroundTasks.NumPushedTasks,
     ScheduledTasks.NumPushedTasks,
     LowerCase(BoolToStr(IsPaused, True))]);
end;

function TTaskControl.ScheduledTasks: TScheduledTasks;
begin
  Result := fScheduledTasks;
end;

procedure TTaskControl.RemoveTask(const aTaskName: string);
begin
  fScheduledTasks.RemoveTask(aTaskName);
  if fPersistenceStore <> nil then
    fPersistenceStore.Delete(aTaskName);
end;

procedure TTaskControl.PauseAll;
begin
  fScheduledTasks.PauseAll;
end;

procedure TTaskControl.ResumeAll;
begin
  fScheduledTasks.ResumeAll;
end;

function TTaskControl.IsPaused: Boolean;
begin
  Result := fScheduledTasks.IsPaused;
end;

function TTaskControl.TimeMeasureStr(aMeasure : TTimeMeasure) : string;
begin
  case aMeasure of
    tmDays:         Result := 'Days';
    tmHours:        Result := 'Hours';
    tmMinutes:      Result := 'Minutes';
    tmSeconds:      Result := 'Seconds';
    tmMilliseconds: Result := 'Milliseconds';
    else            Result := '';
  end;
end;

function TTaskControl.ScheduleModeStr(aMode : TScheduleMode) : string;
begin
  case aMode of
    smRunOnce:    Result := 'RunOnce';
    smRepeatMode: Result := 'Repeat';
    else          Result := '';
  end;
end;

function TTaskControl.SnapshotFromTask(const aTask : IScheduledTask) : TTaskSnapshot;
begin
  Result.Name            := aTask.Name;
  Result.LastExecution   := aTask.LastExecution;
  Result.NextExecution   := aTask.NextExecution;
  Result.ExecutionTimes  := aTask.ExecutionTimes;
  Result.ScheduleMode    := ScheduleModeStr(aTask.ScheduleMode);
  Result.TimeInterval    := aTask.TimeInterval;
  Result.TimeMeasure     := TimeMeasureStr(aTask.TimeMeasure);
  Result.MaxRetries      := aTask.MaxRetries;
  Result.RetryDelayMs    := aTask.RetryDelay;
  Result.RetryMultiplier := aTask.RetryMultiplier;
  Result.Enabled         := aTask.IsEnabled;
  Result.Finished        := aTask.IsFinished;
  Result.UpdatedAt       := Now;
end;

procedure TTaskControl.InternalSaveSnapshot;
var
  tasks   : TArray<IScheduledTask>;
  task    : IScheduledTask;
  pending : TList<TPendingHistoryEntry>;
  ph      : TPendingHistoryEntry;
begin
  if fPersistenceStore = nil then Exit;
  // Flush buffered history entries first (they were queued from task worker threads)
  fPendingHistLock.Enter;
  try
    if fPendingHistory.Count > 0 then
    begin
      pending := TList<TPendingHistoryEntry>.Create;
      try
        pending.AddRange(fPendingHistory);
        fPendingHistory.Clear;
      except
        pending.Free;
        raise;
      end;
    end
    else
      pending := nil;
  finally
    fPendingHistLock.Leave;
  end;
  if pending <> nil then
  try
    for ph in pending do
    begin
      try
        fPersistenceStore.SaveHistoryEntry(ph.TaskName, ph.Entry);
      except
        // Do not let one entry failure abort the rest
      end;
    end;
  finally
    pending.Free;
  end;
  // Save snapshots
  tasks := fScheduledTasks.GetAllTasks;
  for task in tasks do
  begin
    try
      fPersistenceStore.Save(SnapshotFromTask(task));
    except
      // Do not let a single task failure abort the snapshot loop
    end;
  end;
end;

procedure TTaskControl.InternalRestoreSnapshot;
var
  snapshots : TArray<TTaskSnapshot>;
  snap      : TTaskSnapshot;
  task      : IScheduledTask;
begin
  if fPersistenceStore = nil then Exit;
  snapshots := fPersistenceStore.LoadAll;
  for snap in snapshots do
  begin
    task := fScheduledTasks.GetTask(snap.Name);
    if task <> nil then
      task.RestoreStats(snap.ExecutionTimes, snap.LastExecution);
  end;
end;

function TTaskControl.UseStorage(const aFilePath : string) : ITaskControl;
begin
  Result := UseStorage(TJsonFileTaskStorage.Create(aFilePath));
end;

function TTaskControl.UseStorage(aStore : ITaskPersistenceStore) : ITaskControl;
var
  tasks : TArray<IScheduledTask>;
  task  : IScheduledTask;
begin
  fPersistenceStore := aStore;
  // Restore stats to any tasks already registered
  InternalRestoreSnapshot;
  // Hook history callback on all tasks already registered
  tasks := fScheduledTasks.GetAllTasks;
  for task in tasks do
    HookHistoryCallback(task);
  // Start periodic background save (every 30 seconds)
  if fPersistThread = nil then
    fPersistThread := TTaskPersistThread.Create(30000, procedure
                      begin
                        InternalSaveSnapshot;
                      end);
  Result := Self;
end;

{ TTaskControlServiceExtension }

class function TTaskControlServiceExtension.AddTaskControl: TServiceCollection;
begin
  Result := ServiceCollection;
  ServiceCollection.Configure<TTaskControlSettings>('TaskControl', procedure(aOptions : TTaskControlSettings)
                                                   begin
                                                     aOptions.ConcurrentWorkers := 20;
                                                   end);
  ServiceCollection.AddSingleton<ITaskControl,TTaskControl>;
end;

{ TTaskControl helpers }

procedure TTaskControl.HookHistoryCallback(const aTask : IScheduledTask);
begin
  aTask.SetOnHistoryEntry(
    procedure(const aTaskName : string; const aEntry : THistoryEntry)
    var
      pending : TPendingHistoryEntry;
    begin
      if fPersistenceStore = nil then Exit;
      // Buffer the entry - actual DB write happens in the persist thread
      // to avoid cross-thread FireDAC connection issues.
      pending.TaskName := aTaskName;
      pending.Entry    := aEntry;
      fPendingHistLock.Enter;
      try
        fPendingHistory.Add(pending);
      finally
        fPendingHistLock.Leave;
      end;
    end);
end;

function TTaskControl.LoadTaskHistory(const aName : string; aMaxEntries : Integer) : TArray<THistoryEntry>;
var
  task : IScheduledTask;
begin
  // If we have a persistent store, use it (survives restarts)
  if fPersistenceStore <> nil then
  begin
    Result := fPersistenceStore.LoadHistory(aName, aMaxEntries);
    Exit;
  end;
  // Fall back to in-memory ring buffer
  task := fScheduledTasks.GetTask(aName);
  if task <> nil then
    Result := task.History
  else
    Result := [];
end;

function TTaskControl.LoadAllJobHistory(const aStatus : string; aPage, aPageSize : Integer) : TArray<THistoryEntryEx>;
begin
  if fPersistenceStore <> nil then
    Result := fPersistenceStore.LoadAllHistory(aStatus, aPage, aPageSize)
  else
    Result := [];
end;

function TTaskControl.CountAllJobHistory(const aStatus : string) : Int64;
begin
  if fPersistenceStore <> nil then
    Result := fPersistenceStore.CountAllHistory(aStatus)
  else
    Result := 0;
end;

end.
