unit Controller.Logs;

{ WebApiWithLogging Sample - S-08
  Controller that emits log entries at all severity levels. }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Logging.Abstractions;

type
  [Route('api/logs')]
  [ApiController]
  TLogsController = class(THttpController)
  private
    fLogger : ILogger;
  public
    constructor Create(aLogger : ILogger);
  published
    [HttpGet('test')]
    function Test : IActionResult;
  end;

implementation

uses
  System.SysUtils;

{ TLogsController }

constructor TLogsController.Create(aLogger : ILogger);
begin
  inherited Create;
  fLogger := aLogger;
end;

function TLogsController.Test: IActionResult;
begin
  fLogger.Debug('This is a DEBUG message');
  fLogger.Info('This is an INFO message');
  fLogger.Warn('This is a WARN message');
  fLogger.Error('This is an ERROR message (simulated)');
  Result := Json('{"message":"Log entries written. Check console and app.log"}');
end;

initialization
  RegisterController(TLogsController);

end.
