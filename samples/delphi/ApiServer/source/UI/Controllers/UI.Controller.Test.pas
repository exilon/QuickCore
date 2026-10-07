unit UI.Controller.Test;

interface

uses
  System.SysUtils,
  Quick.HttpServer.Types,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Logger.Intf,
  Quick.Commons,
  Quick.Options,
  Infra.Config.App;

type
  [Route('GrafanaAlert')]
  TTestController = class(THttpController)
  private
    fLogger : ILogger;
    fAppSettings : TAppSettings;
  public
    constructor Create(aLogger : ILogger; aAppSettings : IOptions<TAppSettings>);
  published
    [HttpPost('Send')]
    function Send([FromBody] alert : string): IActionResult;
  end;

implementation

{ TTestHttpController }

constructor TTestController.Create(aLogger : ILogger; aAppSettings : IOptions<TAppSettings>);
begin
  fLogger := aLogger;
  fAppSettings := aAppSettings.Value;
  //fLogger.Critical('Test');
end;


function TTestController.Send(alert: string): IActionResult;
begin
  fLogger.Info(alert);
end;

initialization
  RegisterController(TTestController);

end.
