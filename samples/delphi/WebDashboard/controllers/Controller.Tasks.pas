unit Controller.Tasks;

//{ WebDashboard — S-26
//  JSON API for the task list.
//
//  GET    /api/tasks            → array of all tasks
//  GET    /api/tasks/{id}       → single task
//  POST   /api/tasks            → create task  body: {"title":"..."}
//  PUT    /api/tasks/{id}/complete → mark as done
//  DELETE /api/tasks/{id}       → remove task
//  GET    /api/stats            → server stats JSON
//}

interface

uses
  System.SysUtils,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Mvc.Middleware.Swagger,
  Service.Tasks;

type
  TAddTaskRequest = class
  private
    fTitle : string;
  published
    property Title : string read fTitle write fTitle;
  end;

  [Route('api')]
  [ApiController]
  TTasksController = class(THttpController)
  private
    fTasks : ITaskService;
    function TasksToJson(const aTasks : TArray<TTask>) : string;
  public
    constructor Create(aTasks : ITaskService);
  published
    // GET /api/tasks
    [HttpGet('tasks')]
    [SwaggerOperation('List all tasks', 'Returns the complete in-memory task list.', 'Tasks')]
    [ProducesResponseType(200, 'Array of TTask')]
    function GetAll : IActionResult;

    // GET /api/tasks/{id}
    [HttpGet('tasks/{id:int}')]
    [SwaggerOperation('Get task by ID', 'Returns a single task by its integer ID.', 'Tasks')]
    [ProducesResponseType(200, 'TTask')]
    [ProducesResponseType(404, 'Task not found')]
    function GetById(id : Integer) : IActionResult;

    // POST /api/tasks
    [HttpPost('tasks')]
    [SwaggerOperation('Create task', 'Adds a new pending task to the list.', 'Tasks')]
    [ProducesResponseType(201, 'Created TTask')]
    [ProducesResponseType(400, 'title is required')]
    function CreateTask([FromBody] req : TAddTaskRequest) : IActionResult;

    // PUT /api/tasks/{id}/complete
    [HttpPut('tasks/{id:int}/complete')]
    [SwaggerOperation('Complete task', 'Marks an existing task as done.', 'Tasks')]
    [ProducesResponseType(200, 'Task marked as done')]
    [ProducesResponseType(404, 'Task not found')]
    function Complete(id : Integer) : IActionResult;

    // DELETE /api/tasks/{id}
    [HttpDelete('tasks/{id:int}')]
    [SwaggerOperation('Delete task', 'Removes a task from the list.', 'Tasks')]
    [ProducesResponseType(204, 'Deleted')]
    [ProducesResponseType(404, 'Task not found')]
    function DeleteTask(id : Integer) : IActionResult;

    // GET /api/stats
    [HttpGet('stats')]
    [SwaggerOperation('Server stats', 'Returns uptime and total request count as JSON.', 'Stats')]
    [ProducesResponseType(200, 'Stats JSON')]
    function Stats : IActionResult;
  end;

implementation

{ TTasksController }

constructor TTasksController.Create(aTasks : ITaskService);
begin
  inherited Create;
  fTasks := aTasks;
end;

function TTasksController.TasksToJson(const aTasks: TArray<TTask>): string;
var
  sb : TStringBuilder;
  i  : Integer;
begin
  sb := TStringBuilder.Create;
  try
    sb.Append('[');
    for i := 0 to High(aTasks) do
    begin
      if i > 0 then sb.Append(',');
      sb.Append(aTasks[i].ToJson);
    end;
    sb.Append(']');
    Result := sb.ToString;
  finally
    sb.Free;
  end;
end;

function TTasksController.GetAll: IActionResult;
begin
  (fTasks as TTaskService).IncrementRequests;
  Result := Json(TasksToJson(fTasks.GetAll));
end;

function TTasksController.GetById(id: Integer): IActionResult;
var
  t : TTask;
begin
  (fTasks as TTaskService).IncrementRequests;
  t := fTasks.GetById(id);
  if t = nil then
    Result := NotFound(Format('Task %d not found', [id]))
  else
    Result := Json(t.ToJson);
end;

function TTasksController.CreateTask([FromBody] req: TAddTaskRequest): IActionResult;
var
  t : TTask;
begin
  (fTasks as TTaskService).IncrementRequests;
  if (req = nil) or req.Title.IsEmpty then
  begin
    Result := BadRequest('title is required');
    Exit;
  end;
  t := fTasks.Add(req.Title);
  Response.StatusCode := 201;
  Result := Json(t.ToJson);
end;

function TTasksController.Complete(id: Integer): IActionResult;
var
  t : TTask;
begin
  (fTasks as TTaskService).IncrementRequests;
  t := fTasks.GetById(id);
  if t = nil then
    Result := NotFound(Format('Task %d not found', [id]))
  else
  begin
    fTasks.Complete(id);
    Result := Ok('completed');
  end;
end;

function TTasksController.DeleteTask(id: Integer): IActionResult;
var
  t : TTask;
begin
  (fTasks as TTaskService).IncrementRequests;
  t := fTasks.GetById(id);
  if t = nil then
    Result := NotFound(Format('Task %d not found', [id]))
  else
  begin
    fTasks.Delete(id);
    Result := StatusCode(204);
  end;
end;

function TTasksController.Stats: IActionResult;
begin
  (fTasks as TTaskService).IncrementRequests;
  Result := Json(fTasks.GetStats);
end;

initialization
  RegisterController(TTasksController);

end.
