program SessionSample;

(* SessionSample - S-32
  Demonstrates HTTP session state with QuickCore MVC.

  The session middleware stores data per-client (keyed by session cookie).
  Data persists across requests from the same browser session.

  Endpoints:
    GET  /api/counter       — reads & increments a visit counter in session
    POST /api/counter/reset — resets counter to 0
    GET  /api/counter/id    — returns current session ID

  Example curl (note: --cookie-jar keeps the session cookie between calls):
    curl -c cookies.txt -b cookies.txt http://localhost:8080/api/counter
    curl -c cookies.txt -b cookies.txt http://localhost:8080/api/counter
    curl -c cookies.txt -b cookies.txt -X POST http://localhost:8080/api/counter/reset

  .NET equivalent: ISession / HttpContext.Session in ASP.NET Core.
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Startup             in 'Startup.pas',
  Controller.Counter  in 'controllers\Controller.Counter.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('SessionSample (S-32) on http://localhost:8080 ...', etInfo);
      cout('', ccWhite);
      cout('  GET  /api/counter       — increment & return visit count', ccCyan);
      cout('  POST /api/counter/reset — reset counter to 0', ccCyan);
      cout('  GET  /api/counter/id    — show session ID', ccCyan);
      cout('', ccWhite);
      cout('  Tip: use -c cookies.txt -b cookies.txt in curl to keep session', ccYellow);

      ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
      try
        ApiServer.UseStartup<TStartup>;
        ApiServer.Start;
      finally
        ApiServer.Free;
      end;
    end
    else
    begin
      AppService.DisplayName := 'SessionSample';
      AppService.ServiceName := 'SessionSampleSvc';
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
    on E : Exception do
    begin
      cout('Fatal: ' + E.Message, etError);
      ExitCode := 1;
    end;
  end;
end.
