program WindowsServiceApp;

(* WindowsServiceApp Sample - S-17
  Demonstrates how to package a QuickCore app as a Windows Service.
  Run with no args: starts interactively.
  Run with --install  : installs as Windows Service (requires admin).
  Run with --remove   : removes the Windows Service.
  Run with --start    : starts the installed service.
  Run with --stop     : stops the installed service.

  .NET equivalent: Worker Service (net6+ Worker template) with sc.exe or
                   BackgroundService + UseWindowsService().
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Controller.Status in 'controllers\Controller.Status.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    AppService.DisplayName            := 'QuickCore Windows Service Demo';
    AppService.ServiceName            := 'QuickCoreWinSvcDemo';
    AppService.CanInstallWithOtherName := True;

    AppService.OnStart := procedure
      begin
        ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
        ApiServer.UseStartup<TStartup>;
        ApiServer.Start;
      end;

    AppService.OnStop := procedure
      begin
        if Assigned(ApiServer) then
        begin
          ApiServer.Stop;
          FreeAndNil(ApiServer);
        end;
      end;

    AppService.OnExecute := ApiServer.Start;

    if AppService.IsRunningAsService then
      AppService.CheckParams
    else
    begin
      // Interactive console mode
      if ParamCount > 0 then
      begin
        // Let AppService handle --install / --remove / --start / --stop
        AppService.CheckParams;
      end
      else
      begin
        cout('Starting WindowsServiceApp interactively on http://localhost:8080 ...', etInfo);
        cout('Run with --install  to install as Windows Service', ccWhite);
        cout('Run with --remove   to uninstall the service', ccWhite);
        ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
        try
          ApiServer.UseStartup<TStartup>;
          ApiServer.Start;
          cout('Press [Enter] to stop.', ccYellow);
          ConsoleWaitForEnterKey;
        finally
          ApiServer.Free;
        end;
      end;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
