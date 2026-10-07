program CleanArchitectureApi;

(* CleanArchitectureApi Sample - S-15
  Demonstrates Clean Architecture layering in a QuickCore REST API.

  Layer dependency rule (outermost depends on innermost only):
    Presentation  ->  Application
    Application   ->  Domain
    Infrastructure -> Domain
    Startup wires all layers via DI

  .NET equivalent: Clean Architecture template (Jason Taylor) for ASP.NET Core.

  Endpoints:
    GET    http://localhost:8080/api/products
    GET    http://localhost:8080/api/products/:id
    POST   http://localhost:8080/api/products   body: {"Name":"...","Category":"...","Price":0}
    DELETE http://localhost:8080/api/products/:id
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  FireDAC.Phys.SQLite,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Quick.Core.Entity.Engine.FireDAC,
  Startup in 'Startup.pas',
  Domain.Product in 'domain\Domain.Product.pas',
  Application.Service.Product in 'application\Application.Service.Product.pas',
  Infrastructure.Repository.Product in 'infrastructure\Infrastructure.Repository.Product.pas',
  Controller.Products in 'presentation\Controller.Products.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('Starting CleanArchitectureApi on http://localhost:8080 ...', etInfo);
      ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
      try
        ApiServer.UseStartup<TStartup>;
        cout('DB: .\shop_clean.db (SQLite)', ccWhite);
        ApiServer.Start;
      finally
        ApiServer.Free;
      end;
    end
    else
    begin
      AppService.DisplayName := 'Clean Architecture API';
      AppService.ServiceName := 'CleanArchitectureApiSvc';
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
