unit Controller.Health;

{ HealthChecksDashboard Sample - S-12
  Exposes /health/ping as a trivial liveness check. }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult;

type
  [Route('health')]
  [ApiController]
  THealthController = class(THttpController)
  published
    [HttpGet('ping')]
    function Ping : IActionResult;
  end;

implementation

uses
  System.SysUtils;

{ THealthController }

function THealthController.Ping: IActionResult;
begin
  Result := Json('{"status":"Healthy","check":"ping"}');
end;

initialization
  RegisterController(THealthController);

end.
