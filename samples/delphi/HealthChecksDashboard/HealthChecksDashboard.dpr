program HealthChecksDashboard;

(* HealthChecksDashboard Sample - S-12
  REST API with /health endpoint that reports status of multiple subsystems.

  .NET equivalent: services.AddHealthChecks() + app.MapHealthChecks("/health")

  Endpoints:
    GET http://localhost:8080/health          - JSON health report
    GET http://localhost:8080/health/ready    - Readiness report
    GET http://localhost:8080/health/live     - Liveness report
    GET http://localhost:8080/healthui        - HTML dashboard UI
    GET http://localhost:8080/api/info        - App info
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Controller.Info in 'controllers\Controller.Info.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('Starting HealthChecksDashboard on http://localhost:8080 ...', etInfo);
      ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
      try
        ApiServer.UseStartup<TStartup>;
        cout('Health endpoint: http://localhost:8080/health', ccWhite);
        cout('Readiness endpoint: http://localhost:8080/health/ready', ccWhite);
        cout('Liveness endpoint: http://localhost:8080/health/live', ccWhite);
        cout('Dashboard UI: http://localhost:8080/healthui', ccWhite);
        ApiServer.Start;
      finally
        ApiServer.Free;
      end;
    end
    else
    begin
      AppService.DisplayName := 'Health Checks Dashboard';
      AppService.ServiceName := 'HealthChecksDashboardSvc';
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
