program CustomMiddleware;

(* CustomMiddleware Sample - S-11
  Shows how to write and register custom ASP-style middleware that
  intercepts every HTTP request/response.

  Middleware chain (outermost -> innermost):
    TTimingMiddleware  -> measures request duration, adds X-Response-Time header
    TRequestIdMiddleware -> injects X-Request-ID header
    TLoggingMiddleware  -> logs method + path + status + duration
    Controller

  .NET equivalent: app.Use(async (ctx, next) => { ... await next(); ... })

  Endpoint: GET http://localhost:8080/api/ping
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Middleware.Timing in 'middleware\Middleware.Timing.pas',
  Middleware.RequestId in 'middleware\Middleware.RequestId.pas',
  Middleware.Logging in 'middleware\Middleware.Logging.pas',
  Controller.Ping in 'controllers\Controller.Ping.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('Starting CustomMiddleware sample on http://localhost:8080 ...', etInfo);
      ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
      try
        ApiServer.UseStartup<TStartup>;
        cout('Try: curl http://localhost:8080/api/ping', ccWhite);
        ApiServer.Start;
      finally
        ApiServer.Free;
      end;
    end
    else
    begin
      AppService.DisplayName := 'Custom Middleware Sample';
      AppService.ServiceName := 'CustomMiddlewareSvc';
      AppService.CanInstallWithOtherName := True;
      AppService.OnStart := procedure
        begin
          ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
          ApiServer.UseStartup<TStartup>;
        end;
      AppService.OnExecute := ApiServer.Start;
      AppService.CheckParams;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
