unit Controller.Home;

interface

uses
  System.SysUtils,
  Quick.HttpServer.Types,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Commons;

type
  [Route('')]
  THomeController = class(THttpController)
  published
    [HttpGet,ActionName('Index')]
    function Index : IActionResult;
  end;

implementation

{ THomeController }

function THomeController.Index: IActionResult;
begin
  Result := Content('Use /Product CRUD');
end;

initialization
  RegisterController(THomeController);

end.
