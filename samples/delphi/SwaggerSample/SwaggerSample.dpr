program SwaggerSample;

(* SwaggerSample — S-25
  Demonstrates the built-in Swagger / OpenAPI 3.0 support.

  UseSwagger() registers two middleware routes:
    GET /swagger                  → Swagger UI (HTML, loads from CDN)
    GET /swagger/v1/swagger.json  → OpenAPI 3.0 JSON document

  The spec is generated at startup from RTTI: controller [Route], [HttpGet/Post/Put/Delete],
  [SwaggerOperation] summary/description, and [ProducesResponseType] status codes.

  .NET equivalent: Swashbuckle / NSwag in ASP.NET Core.

  Open in browser: http://localhost:8080/swagger
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
  Models in 'Models.pas',
  Controller.Products in 'controllers\Controller.Products.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('Starting SwaggerSample on http://localhost:8080 ...', etInfo);
      ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
      try
        ApiServer.UseStartup<TStartup>;
        cout('Open in browser: http://localhost:8080/swagger', ccCyan);
        cout('OpenAPI JSON:    http://localhost:8080/swagger/v1/swagger.json', ccWhite);
        ApiServer.Start;
      finally
        ApiServer.Free;
      end;
    end
    else
    begin
      AppService.DisplayName := 'Swagger Sample';
      AppService.ServiceName := 'SwaggerSampleSvc';
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
