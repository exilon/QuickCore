program HelloWorldApi;

(* HelloWorldApi Sample - S-01
  Equivalent to .NET Minimal API: app.MapGet("/hello", ...) + one controller.

  Run and test:
    GET http://localhost:8080/hello          -> {"Message":"Hello, World!","Timestamp":"..."}
    GET http://localhost:8080/hello/greet/Ana -> Hello, Ana!
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
  Controller.Hello in 'controllers\Controller.Hello.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('Starting HelloWorldApi on http://localhost:8080 ...', etInfo);
      ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
      try
        ApiServer.UseStartup<TStartup>;
        cout('Server running. Press [Enter] to stop.', ccYellow);
        ApiServer.Start;
      finally
        ApiServer.Free;
      end;
    end
    else
    begin
      AppService.DisplayName := 'Hello World API';
      AppService.ServiceName := 'HelloWorldApiSvc';
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
