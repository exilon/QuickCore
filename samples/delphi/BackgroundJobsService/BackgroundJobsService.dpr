program BackgroundJobsService;

(* BackgroundJobsService Sample - S-16
  Demonstrates background tasks and scheduled (recurring) tasks via ITaskControl.

  - TCleanupJob  : runs on demand (background task)
  - TReportJob   : scheduled every 60 seconds

  .NET equivalent: IHostedService / BackgroundService + IRecurringJob (Hangfire).

  Endpoint: GET http://localhost:8080/api/jobs/status
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Controller.Jobs in 'controllers\Controller.Jobs.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('Starting BackgroundJobsService on http://localhost:8080 ...', etInfo);
      ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
      try
        ApiServer.UseStartup<TStartup>;
        cout('Check status: http://localhost:8080/api/jobs/status', ccWhite);
        cout('Trigger job:  POST http://localhost:8080/api/jobs/cleanup', ccWhite);
        ApiServer.Start;
      finally
        ApiServer.Free;
      end;
    end
    else
    begin
      AppService.DisplayName := 'Background Jobs Service';
      AppService.ServiceName := 'BackgroundJobsSvc';
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
