program WebApiWithCaching;

(* WebApiWithCaching Sample - S-09
  REST API demonstrating IMemoryCache (cache-aside pattern).
  The controller tries the cache first; on miss it "fetches" data and stores it.

  .NET equivalent: IMemoryCache + MemoryCache.TryGetValue / Set.

  Endpoints:
    GET http://localhost:8080/api/weather            - Returns cached weather data
    DELETE http://localhost:8080/api/weather/cache   - Clears the cache entry
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Controller.Weather in 'controllers\Controller.Weather.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('Starting WebApiWithCaching on http://localhost:8080 ...', etInfo);
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
      AppService.DisplayName := 'WebApi With Caching';
      AppService.ServiceName := 'WebApiWithCachingSvc';
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
