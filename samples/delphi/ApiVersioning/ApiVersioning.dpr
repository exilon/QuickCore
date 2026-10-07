program ApiVersioning;

(* ApiVersioning Sample - S-30
  Demonstrates URL-based API versioning with two separate controller classes.

  v1: GET /api/v1/products        — basic fields (id, name)
  v2: GET /api/v2/products        — richer fields (price, stock, category)
      GET /api/v2/products/search?q=laptop  — search (v2-only endpoint)

  Both controllers are registered with [ApiVersion] attribute.
  UseApiVersioning() in the pipeline activates version-aware routing.

  .NET equivalent: Microsoft.AspNetCore.Mvc.Versioning + [ApiVersion] attribute.
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Startup               in 'Startup.pas',
  Controller.ProductsV1 in 'controllers\Controller.ProductsV1.pas',
  Controller.ProductsV2 in 'controllers\Controller.ProductsV2.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('ApiVersioning sample (S-30) on http://localhost:8080 ...', etInfo);
      cout('', ccWhite);
      cout('  v1 endpoints:', ccCyan);
      cout('    GET http://localhost:8080/api/v1/products', ccWhite);
      cout('    GET http://localhost:8080/api/v1/products/1', ccWhite);
      cout('', ccWhite);
      cout('  v2 endpoints (richer data + search):', ccCyan);
      cout('    GET http://localhost:8080/api/v2/products', ccWhite);
      cout('    GET http://localhost:8080/api/v2/products/1', ccWhite);
      cout('    GET http://localhost:8080/api/v2/products/search?q=laptop', ccWhite);

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
      AppService.DisplayName := 'ApiVersioning Sample';
      AppService.ServiceName := 'ApiVersioningSvc';
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
