unit Controller.Jobs;

{ BackgroundJobsService Sample - S-16
  Controller to trigger background tasks and check status. }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.TaskControl,
  Quick.Core.Logging.Abstractions,
  Quick.Threads;

type
  [Route('api/jobs')]
  [ApiController]
  TJobsController = class(THttpController)
  private
    fTaskControl : ITaskControl;
    fLogger      : ILogger;
  public
    constructor Create(aTaskControl : ITaskControl; aLogger : ILogger);
  published
    // GET /api/jobs/status — returns running tasks JSON
    [HttpGet('status')]
    function Status : IActionResult;

    // POST /api/jobs/cleanup — queues a background cleanup task
    [HttpPost('cleanup')]
    function TriggerCleanup : IActionResult;
  end;

implementation

uses
  System.SysUtils;

{ TJobsController }

constructor TJobsController.Create(aTaskControl : ITaskControl; aLogger : ILogger);
begin
  inherited Create;
  fTaskControl := aTaskControl;
  fLogger      := aLogger;
end;

function TJobsController.Status: IActionResult;
begin
  Result := Json(
    Format('{"backgroundWorkers":%d,"scheduledTasks":%d}',
      [fTaskControl.BackgroundTasks.ConcurrentWorkers,
       fTaskControl.ScheduledTasks.NumPushedTasks]));
end;

function TJobsController.TriggerCleanup: IActionResult;
begin
  fTaskControl.BackgroundTasks.AddTask(procedure(task : ITask)
    begin
      fLogger.Info('CleanupJob: starting cleanup...');
      Sleep(2000);  // simulate work
      fLogger.Info('CleanupJob: cleanup complete.');
    end);
  Result := Json('{"queued":true,"job":"CleanupJob"}');
end;

initialization
  RegisterController(TJobsController);

end.
