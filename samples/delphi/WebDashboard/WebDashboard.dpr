program WebDashboard;

(* WebDashboard Sample — S-26
  A browser-accessible web application demonstrating QuickCore as a full web
  server (not just a JSON API).

  Features:
    · HTML dashboard page served at GET /
    · Real-time server stats (uptime, request count)
    · In-memory task list with Add / Complete / Delete operations
    · All mutations driven by JavaScript fetch() calls to JSON endpoints
    · No external files required — HTML is generated inline by the controller

  .NET equivalent: Razor Pages / Blazor Server (light version).

  Open in browser: http://localhost:8080/
*)

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Service.Tasks in 'Service.Tasks.pas',
  Controller.Home in 'controllers\Controller.Home.pas',
  Controller.Tasks in 'controllers\Controller.Tasks.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('Starting WebDashboard on http://localhost:8080 ...', etInfo);
      ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
      try
        ApiServer.UseStartup<TStartup>;
        cout('Open in browser:  http://localhost:8080/', ccCyan);
        cout('Swagger UI:       http://localhost:8080/swagger', ccCyan);
        cout('OpenAPI JSON:     http://localhost:8080/swagger/v1/swagger.json', ccWhite);
        ApiServer.Start;
      finally
        ApiServer.Free;
      end;
    end
    else
    begin
      AppService.DisplayName := 'WebDashboard';
      AppService.ServiceName := 'WebDashboardSvc';
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
