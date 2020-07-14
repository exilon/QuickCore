unit Controller.Home;

interface

uses
  System.SysUtils,
  Quick.HttpServer.Types,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.MessageQueue.Abstractions,
  Quick.Commons,
  PingTask;

type
  [Route('')]
  THomeController = class(THttpController)
  private
    fMessageQueue : IMessageQueue<TPingTask>;
  public
    constructor Create(aMessageQueue : IMessageQueue<TPingTask>);
  published
    [HttpGet('Home'),ActionName('Index')]
    function Index : IActionResult;

    [HttpGet('Push/{host}')]
    function Push(const host : string) : IActionResult;

    [HttpGet('Pop')]
    function Pop : IActionResult;

  end;

implementation

{ THomeController }

constructor THomeController.Create(aMessageQueue: IMessageQueue<TPingTask>);
begin
  fMessageQueue := aMessageQueue;
end;

function THomeController.Index: IActionResult;
begin
  Result := Content('Use /Push/{hostname} to add to queue and /Pop to retrieve from queue');
end;

function THomeController.Push(const host: string): IActionResult;
var
  pingtask : TPingTask;
begin
  PingTask := TPingTask.Create;
  try
    PingTask.Id := NewGuidStr;
    PingTask.Host := host;
    fMessageQueue.Push(pingtask);
  finally
    PingTask.Free;
  end;
  Result := Content('Add task to Redis Message Queue');
end;

function THomeController.Pop: IActionResult;
var
  pingtask : TPingTask;
begin
  if fMessageQueue.Pop(PingTask) = TMSQWaitResult.wrTimeout then Exit(Content('No more tasks found!'));
  try
    Result := Content(PingTask.Host);
  finally
    PingTask.Free;
  end;
end;

initialization
  RegisterController(THomeController);

end.
