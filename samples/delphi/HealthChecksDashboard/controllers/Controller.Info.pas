unit Controller.Info;

{ HealthChecksDashboard Sample - S-12 }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult;

type
  [Route('api')]
  [ApiController]
  TInfoController = class(THttpController)
  published
    [HttpGet('info')]
    function GetInfo : IActionResult;
  end;

implementation

uses
  System.SysUtils;

{ TInfoController }

function TInfoController.GetInfo: IActionResult;
begin
  Result := Json(Format('{"app":"HealthChecksDashboard","version":"1.0.0","time":"%s"}',
    [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)]));
end;

initialization
  RegisterController(TInfoController);

end.
