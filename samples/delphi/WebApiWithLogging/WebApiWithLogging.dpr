program WebApiWithLogging;

(* WebApiWithLogging Sample - S-08
  REST API demonstrating QuickCore logging: console + file output.
  ILogger is injected into controllers and used at different levels.

  .NET equivalent: Serilog/Microsoft.Extensions.Logging + ASP.NET Core.

  Log file: .\app.log
  Endpoint: GET http://localhost:8080/api/logs/test
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Controller.Logs in 'controllers\Controller.Logs.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('Starting WebApiWithLogging on http://localhost:8080 ...', etInfo);
      ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
      try
        ApiServer.UseStartup<TStartup>;
        cout('Log file: .\app.log', ccWhite);
        ApiServer.Start;
      finally
        ApiServer.Free;
      end;
    end
    else
    begin
      AppService.DisplayName := 'WebApi With Logging';
      AppService.ServiceName := 'WebApiWithLoggingSvc';
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
