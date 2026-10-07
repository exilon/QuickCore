unit Controller.Status;

{ WindowsServiceApp Sample - S-17
  Simple status endpoint to verify the service is alive. }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult;

type
  [Route('api')]
  [ApiController]
  TStatusController = class(THttpController)
  published
    [HttpGet('status')]
    function Status : IActionResult;
  end;

implementation

uses
  System.SysUtils,
  Winapi.Windows;

{ TStatusController }

function TStatusController.Status: IActionResult;
begin
  Result := Json(Format(
    '{"status":"running","serverTime":"%s","pid":%d}',
    [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), GetCurrentProcessId]));
end;

initialization
  RegisterController(TStatusController);

end.
