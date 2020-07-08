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

    [HttpGet('Random/{number:int?}'), OutputCache(5000)]
    function Random(Number : Integer = 10) : IActionResult;
  end;

implementation

{ THomeController }

function THomeController.Index: IActionResult;
begin
  Result := Content('Use /random/{number} return value will be cached for 5 seconds');
end;

function THomeController.Random(Number: Integer = 10): IActionResult;
begin
  if Number < 1 then Result := StatusCode(THttpStatusCode.BadRequest,'Number too low!')
    else Result := Content(Format('Random(%d) = %d (cached for 5s)',[Number,System.Random(Number)]));
end;

initialization
  RegisterController(THomeController);

end.
