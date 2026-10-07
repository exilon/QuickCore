program LocalizationSample;

(* LocalizationSample Sample - S-20
  Multilingual REST API using QuickCore IStringLocalization.
  Language is selected via the Accept-Language header (es, en, fr).

  .NET equivalent: IStringLocalizer<T> + RequestLocalizationMiddleware.

  Endpoint: GET http://localhost:8080/api/greet?name=Alice
    With header: Accept-Language: es  ->  "Hola, Alice!"
    With header: Accept-Language: fr  ->  "Bonjour, Alice!"
    Default (en)                      ->  "Hello, Alice!"
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Controller.Greet in 'controllers\Controller.Greet.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('Starting LocalizationSample on http://localhost:8080 ...', etInfo);
      ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
      try
        ApiServer.UseStartup<TStartup>;
        cout('Try: curl -H "Accept-Language: es" http://localhost:8080/api/greet?name=Alice', ccWhite);
        cout('Try: curl -H "Accept-Language: fr" http://localhost:8080/api/greet?name=Alice', ccWhite);
        ApiServer.Start;
      finally
        ApiServer.Free;
      end;
    end
    else
    begin
      AppService.DisplayName := 'Localization Sample';
      AppService.ServiceName := 'LocalizationSampleSvc';
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
