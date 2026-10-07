program MultipleDbContexts;

(* MultipleDbContexts Sample - S-18
  Demonstrates two separate DBContexts in the same application.
  - TCatalogContext  : products catalog (SQLite, read-heavy)
  - TOrdersContext   : order data (SQLite, could be MSSQL in production)
  Both are registered in DI and injected into separate controllers.

  .NET equivalent: Multiple DbContext classes in EF Core.

  Endpoints:
    GET http://localhost:8080/api/catalog        — list products
    GET http://localhost:8080/api/orders         — list orders
    POST http://localhost:8080/api/catalog       — add product
    POST http://localhost:8080/api/orders        — place order
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
  Models in 'Models.pas',
  Controller.Catalog in 'controllers\Controller.Catalog.pas',
  Controller.Orders in 'controllers\Controller.Orders.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('Starting MultipleDbContexts on http://localhost:8080 ...', etInfo);
      ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
      try
        ApiServer.UseStartup<TStartup>;
        cout('Catalog DB : .\catalog.db', ccWhite);
        cout('Orders DB  : .\orders.db', ccWhite);
        ApiServer.Start;
      finally
        ApiServer.Free;
      end;
    end
    else
    begin
      AppService.DisplayName := 'Multiple DbContexts Demo';
      AppService.ServiceName := 'MultipleDbContextsSvc';
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
