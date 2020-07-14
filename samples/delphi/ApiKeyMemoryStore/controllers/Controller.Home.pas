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
  [Authorize]
  THomeController = class(THttpController)
  published
    [AllowAnonymous]
    [HttpGet('Home/Index')]
    function Index : IActionResult;

    [HttpGet('Sum/{number1:int}/{number2:int}')]
    function Sum(Number1, Number2 : Integer) : IActionResult;
  end;

implementation

{ THomeController }

function THomeController.Index: IActionResult;
begin
  Result := Content('Use /Sum/{number1}/{number2}');
end;

function THomeController.Sum(Number1, Number2 : Integer): IActionResult;
begin
  Result := Content(Format('Sum(%d + %d) = %d',[Number1,Number2,Number1 + Number2]));
end;

initialization
  RegisterController(THomeController);

end.
