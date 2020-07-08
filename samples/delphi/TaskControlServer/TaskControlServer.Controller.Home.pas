unit TaskControlServer.Controller.Home;

interface

uses
  System.SysUtils,
  Quick.HttpServer.Types,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.TaskControl,
  Quick.Threads,
  Quick.Commons;

type
  THomeController = class(THttpController)
  private
    fTaskControl : ITaskControl;
  public
    constructor Create(aTaskControl : ITaskControl);
  published
    [HttpGet('Home'),ActionName('Index')]
    function Index : IActionResult;
  end;

implementation

{ THomeController }

constructor THomeController.Create(aTaskControl: ITaskControl);
begin
  fTaskControl := aTaskControl;
end;

function THomeController.Index: IActionResult;
var
  i : Integer;
begin
  for i := 0 to 1000 do
  begin
    fTaskControl.BackgroundTasks.AddTask(procedure(aTask : ITask)
                                       begin
                                         Sleep(2000);
                                       end);
  end;

  Result := Content('Doing tasks!');
end;

initialization
  RegisterController(THomeController);

end.
