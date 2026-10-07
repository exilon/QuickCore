unit UI.Controller.Flakey;

{ ApiServer Sample - Flakey endpoint to test Degraded/Unhealthy HealthChecks.
  GET /flakey/ping  → 200 OK ~50% of the time, 503 the other 50%. }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult;

type
  [Route('flakey')]
  [ApiController]
  TFlakeyController = class(THttpController)
  published
    [HttpGet('ping')]
    function Ping : IActionResult;
  end;

implementation

uses
  System.SysUtils;

{ TFlakeyController }

function TFlakeyController.Ping : IActionResult;
begin
  if Random(2) = 0 then
    Result := StatusCode(503, '{"status":"Unhealthy","reason":"Simulated transient failure"}')
  else
    Result := Json('{"status":"Healthy"}');
end;

initialization
  RegisterController(TFlakeyController);

end.
