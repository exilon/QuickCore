unit Controller.Home;

interface

uses
  System.SysUtils,
  Quick.HttpServer.Types,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Commons;

type
  THomeController = class(THttpController)
  published
    [HttpGet('Home'),ActionName('Index')]
    function Index : IActionResult;
  end;

implementation

{ THomeController }

function THomeController.Index: IActionResult;
begin
  Result := Content('Welcome to Home page!');
end;

initialization
  RegisterController(THomeController);

end.
