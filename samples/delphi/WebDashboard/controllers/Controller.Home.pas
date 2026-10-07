unit Controller.Home;

{ WebDashboard — S-26
  Serves the HTML dashboard from wwwroot/index.html (next to the executable).
  The page uses vanilla JavaScript fetch() to call the Tasks JSON API. }

interface

uses
  System.SysUtils,
  System.IOUtils,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Service.Tasks;

type
  [Route('')]
  THomeController = class(THttpController)
  private
    fTasks : ITaskService;
  public
    constructor Create(aTasks : ITaskService);
  published
    [HttpGet, ActionName('Index')]
    function Index : IActionResult;
  end;

implementation

{ THomeController }

constructor THomeController.Create(aTasks : ITaskService);
begin
  inherited Create;
  fTasks := aTasks;
end;

function THomeController.Index: IActionResult;
var
  htmlFile : string;
begin
  if Assigned(fTasks) then
    (fTasks as TTaskService).IncrementRequests;
  // HttpContext.WebRoot = '.\wwwroot\' (CWD-relative, set by UseWebRoot in Startup).
  // Using it avoids a wrong path when the EXE lives in a bin\Win64\Debug\ subdirectory.
  htmlFile := HttpContext.WebRoot + 'index.html';
  Response.ContentType := 'text/html; charset=utf-8';
  Result := Content(TFile.ReadAllText(htmlFile, TEncoding.UTF8));
end;

initialization
  RegisterController(THomeController);

end.
