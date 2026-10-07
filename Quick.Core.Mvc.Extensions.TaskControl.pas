{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Mvc.Extensions.TaskControl
  Description : Core MVC Extensions TaskControl
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

unit Quick.Core.Mvc.Extensions.TaskControl;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  Quick.Threads,
  Quick.Core.TaskControl,
  Quick.Core.TaskControl.Persistence,
  Quick.Core.MVC,
  Quick.HttpServer.Types,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult;

type
  TTaskControlMVCServerExtension = class(TMVCServerExtension)
    class function UseTaskControl : TMVCServer;
  end;

  [Route('TaskControl')]
  TTaskControlController = class(THttpController)
  private
    fTaskControl : ITaskControl;
    function TaskStatusToStr(aStatus : TWorkTaskStatus) : string;
    function TimeMeasureToStr(aMeasure : TTimeMeasure) : string;
    function ScheduleModeToStr(aMode : TScheduleMode) : string;
    function DateTimeToISO(aDateTime : TDateTime) : string;
  public
    constructor Create(aTaskControl : ITaskControl);
  published
    [HttpGet('Stats'),ActionName('Index')]
    function Stats : IActionResult;
    [HttpGet('Tasks')]
    function Tasks : IActionResult;
    [HttpPost('Tasks/{name}/enable')]
    function EnableTask(const name : string) : IActionResult;
    [HttpPost('Tasks/{name}/disable')]
    function DisableTask(const name : string) : IActionResult;
    [HttpPost('Tasks/{name}/trigger')]
    function TriggerTask(const name : string) : IActionResult;
    [HttpPost('Tasks/{name}/cancel')]
    function CancelTask(const name : string) : IActionResult;
    [HttpGet('Tasks/{name}/history')]
    function TaskHistory(const name : string) : IActionResult;
    [HttpDelete('Tasks/{name}')]
    function DeleteTask(const name : string) : IActionResult;
    [HttpPost('Tasks/pauseAll')]
    function PauseAll : IActionResult;
    [HttpPost('Tasks/resumeAll')]
    function ResumeAll : IActionResult;
    [HttpGet('Jobs')]
    function Jobs : IActionResult;
  end;

implementation

{ TTaskControlMVCServerExtension }

class function TTaskControlMVCServerExtension.UseTaskControl: TMVCServer;
begin
  Result := MVCServer;
  if MVCServer.Services.IsRegistered<ITaskControl,TTaskControl>('') then
  begin
    MVCServer.AddController(TTaskControlController);
  end
  else raise Exception.Create('TaskControl dependency not found. Need to be added before!');
end;

{ TTaskControlController }

constructor TTaskControlController.Create(aTaskControl: ITaskControl);
begin
  fTaskControl := aTaskControl;
end;

function TTaskControlController.Stats: IActionResult;
begin
  Result := Content(TTaskControl(fTaskControl).GetCurrentRunningTasksJson);
end;

function TTaskControlController.TaskStatusToStr(aStatus: TWorkTaskStatus): string;
begin
  case aStatus of
    wtsPending:   Result := 'Pending';
    wtsAssigned:  Result := 'Assigned';
    wtsRunning:   Result := 'Running';
    wtsDone:      Result := 'Done';
    wtsException: Result := 'Exception';
    wtsSkipped:   Result := 'Skipped';
    wtsDeleted:   Result := 'Deleted';
    else          Result := 'Unknown';
  end;
end;

function TTaskControlController.TimeMeasureToStr(aMeasure: TTimeMeasure): string;
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

function TTaskControlController.ScheduleModeToStr(aMode: TScheduleMode): string;
begin
  case aMode of
    smRunOnce:    Result := 'RunOnce';
    smRepeatMode: Result := 'Repeat';
    else          Result := '';
  end;
end;

function TTaskControlController.DateTimeToISO(aDateTime: TDateTime): string;
begin
  if aDateTime = 0 then Result := ''
  else Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', aDateTime);
end;

function TTaskControlController.Tasks: IActionResult;
var
  allTasks   : TArray<IScheduledTask>;
  task       : IScheduledTask;
  sb         : TStringBuilder;
  first      : Boolean;
  tc         : TTaskControl;
  bgRunning  : TArray<TBgRunningInfo>;
  bgInfo     : TBgRunningInfo;
begin
  tc := TTaskControl(fTaskControl);
  sb := TStringBuilder.Create;
  try
    sb.Append('{"scheduled":[');
    allTasks := tc.ScheduledTasks.GetAllTasks;
    first := True;
    for task in allTasks do
    begin
      if not first then sb.Append(',');
      first := False;
      sb.Append(Format('{"id":%d,"name":"%s","status":"%s","scheduleMode":"%s",' +
                       '"interval":%d,"timeMeasure":"%s","lastExecution":"%s",' +
                       '"nextExecution":"%s","executionTimes":%d,"numRetries":%d,' +
                       '"maxRetries":%d,"retryDelay":%d,"retryMultiplier":%s,' +
                       '"enabled":%s,"finished":%s,"noOverlap":%s}',
        [task.IdTask,
         task.Name,
         TaskStatusToStr(task.TaskStatus),
         ScheduleModeToStr(task.ScheduleMode),
         task.TimeInterval,
         TimeMeasureToStr(task.TimeMeasure),
         DateTimeToISO(task.LastExecution),
         DateTimeToISO(task.NextExecution),
         task.ExecutionTimes,
         task.NumRetries,
         task.MaxRetries,
         task.RetryDelay,
         StringReplace(Format('%.2f', [task.RetryMultiplier]), FormatSettings.DecimalSeparator, '.', [rfReplaceAll]),
         LowerCase(BoolToStr(task.IsEnabled, True)),
         LowerCase(BoolToStr(task.IsFinished, True)),
         LowerCase(BoolToStr(not task.IsOverlapAllowed, True))]));
    end;
    // background_running: live list of BG tasks currently executing
    sb.Append('],"background_running":[');
    bgRunning := tc.BackgroundTasks.GetRunningTaskInfos;
    first := True;
    for bgInfo in bgRunning do
    begin
      if not first then sb.Append(',');
      first := False;
      sb.Append(Format('{"name":"%s","startTime":"%s"}',
        [bgInfo.Name, DateTimeToISO(bgInfo.StartTime)]));
    end;
    sb.Append(Format('],"background":{"queued":%d,"workers":%d,"active":%d,"totalPushed":%d},"paused":%s}',
      [tc.BackgroundTasks.TaskQueued,
       tc.BackgroundTasks.ConcurrentWorkers,
       tc.BackgroundTasks.ActiveWorkers,
       tc.BackgroundTasks.NumPushedTasks,
       LowerCase(BoolToStr(tc.IsPaused, True))]));
    Result := Content(sb.ToString);
  finally
    sb.Free;
  end;
end;

function TTaskControlController.EnableTask(const name : string): IActionResult;
var
  task : IScheduledTask;
begin
  task := TTaskControl(fTaskControl).ScheduledTasks.GetTask(name);
  if task = nil then
  begin
    StatusCode(404, 'Task not found');
    Result := Content('{"error":"Task not found"}');
  end
  else
  begin
    task.Enable;
    Result := Content('{"ok":true}');
  end;
end;

function TTaskControlController.DisableTask(const name : string): IActionResult;
var
  task : IScheduledTask;
begin
  task := TTaskControl(fTaskControl).ScheduledTasks.GetTask(name);
  if task = nil then
  begin
    StatusCode(404, 'Task not found');
    Result := Content('{"error":"Task not found"}');
  end
  else
  begin
    task.Disable;
    Result := Content('{"ok":true}');
  end;
end;

function TTaskControlController.TriggerTask(const name : string): IActionResult;
var
  task : IScheduledTask;
begin
  task := TTaskControl(fTaskControl).ScheduledTasks.GetTask(name);
  if task = nil then
  begin
    StatusCode(404, 'Task not found');
    Result := Content('{"error":"Task not found"}');
  end
  else
  begin
    task.TriggerNow;
    Result := Content('{"ok":true}');
  end;
end;

function TTaskControlController.CancelTask(const name : string): IActionResult;
var
  task : IScheduledTask;
begin
  task := TTaskControl(fTaskControl).ScheduledTasks.GetTask(name);
  if task = nil then
  begin
    StatusCode(404, 'Task not found');
    Result := Content('{"error":"Task not found"}');
  end
  else
  begin
    task.Cancel;
    Result := Content('{"ok":true}');
  end;
end;

function TTaskControlController.TaskHistory(const name : string): IActionResult;
var
  ctrl    : TTaskControl;
  hist    : TArray<THistoryEntry>;
  entry   : THistoryEntry;
  sb      : TStringBuilder;
  first   : Boolean;
begin
  ctrl := TTaskControl(fTaskControl);
  // Verify the task exists
  if ctrl.ScheduledTasks.GetTask(name) = nil then
  begin
    StatusCode(404, 'Task not found');
    Result := Content('{"error":"Task not found"}');
    Exit;
  end;
  // Use persistent store when available (survives restarts), otherwise ring buffer
  hist := ctrl.LoadTaskHistory(name, 100);
  sb := TStringBuilder.Create;
  try
    sb.Append('[');
    first := True;
    for entry in hist do
    begin
      if not first then sb.Append(',');
      first := False;
      sb.Append(Format('{"execTime":"%s","durationMs":%d,"status":"%s","errorMessage":"%s","exceptionType":"%s"}',
        [DateTimeToISO(entry.ExecTime), entry.DurationMs, entry.Status,
         StringReplace(entry.ErrorMessage, '"', '\"', [rfReplaceAll]),
         entry.ExceptionType]));
    end;
    sb.Append(']');
    Result := Content(sb.ToString);
  finally
    sb.Free;
  end;
end;

function TTaskControlController.DeleteTask(const name: string): IActionResult;
var
  task : IScheduledTask;
begin
  task := TTaskControl(fTaskControl).ScheduledTasks.GetTask(name);
  if task = nil then
  begin
    StatusCode(404, 'Task not found');
    Result := Content('{"error":"Task not found"}');
  end
  else
  begin
    fTaskControl.RemoveTask(name);
    Result := Content('{"ok":true}');
  end;
end;

function TTaskControlController.PauseAll: IActionResult;
begin
  fTaskControl.PauseAll;
  Result := Content('{"ok":true,"paused":true}');
end;

function TTaskControlController.ResumeAll: IActionResult;
begin
  fTaskControl.ResumeAll;
  Result := Content('{"ok":true,"paused":false}');
end;

function TTaskControlController.Jobs: IActionResult;
var
  statusFilter : string;
  page         : Integer;
  pageSize     : Integer;
  items        : TArray<THistoryEntryEx>;
  total        : Int64;
  sb           : TStringBuilder;
  ex           : THistoryEntryEx;
  first        : Boolean;
begin
  statusFilter := Request.Query['status'].AsString;
  page         := StrToIntDef(Request.Query['page'].AsString, 1);
  pageSize     := StrToIntDef(Request.Query['pageSize'].AsString, 50);
  if page < 1 then page := 1;
  if pageSize < 1 then pageSize := 1;
  if pageSize > 200 then pageSize := 200;

  total := fTaskControl.CountAllJobHistory(statusFilter);
  items := fTaskControl.LoadAllJobHistory(statusFilter, page, pageSize);

  sb := TStringBuilder.Create;
  try
    sb.Append(Format('{"total":%d,"page":%d,"pageSize":%d,"items":[', [total, page, pageSize]));
    first := True;
    for ex in items do
    begin
      if not first then sb.Append(',');
      first := False;
      sb.Append(Format('{"taskName":"%s","execTime":"%s","durationMs":%d,"status":"%s","errorMessage":"%s","exceptionType":"%s"}',
        [StringReplace(ex.TaskName, '"', '\"', [rfReplaceAll]),
         DateTimeToISO(ex.ExecTime),
         ex.DurationMs,
         ex.Status,
         StringReplace(ex.ErrorMessage, '"', '\"', [rfReplaceAll]),
         StringReplace(ex.ExceptionType, '"', '\"', [rfReplaceAll])]));
    end;
    sb.Append(']}');
    Result := Content(sb.ToString);
  finally
    sb.Free;
  end;
end;

end.
