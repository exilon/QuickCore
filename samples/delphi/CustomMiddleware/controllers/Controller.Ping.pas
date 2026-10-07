unit Controller.Ping;

{ CustomMiddleware Sample - S-11 }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult;

type
  [Route('api')]
  [ApiController]
  TPingController = class(THttpController)
  published
    [HttpGet('ping')]
    function Ping : IActionResult;
  end;

implementation

uses
  System.SysUtils;

{ TPingController }

function TPingController.Ping: IActionResult;
begin
  Result := Json(Format('{"pong":true,"time":"%s"}',
    [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)]));
end;

initialization
  RegisterController(TPingController);

end.
