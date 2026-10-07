program WebApiWithDatabase;

(* WebApiWithDatabase Sample - S-07
  REST API backed by SQLite via QuickCore Entity ORM.
  TShopContext (DBContext) is injected into TProductsController via DI.

  .NET equivalent: ASP.NET Core WebAPI + EF Core + SQLite.

  Endpoints:
    GET    http://localhost:8080/api/products
    GET    http://localhost:8080/api/products/:id
    POST   http://localhost:8080/api/products   body: {"Name":"...","Category":"...","Price":0,"Stock":0}
    DELETE http://localhost:8080/api/products/:id
*)

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  FireDAC.Phys.SQLite,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Quick.Core.Entity,
  Quick.Core.Entity.Engine.FireDAC,
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
      cout('Starting WebApiWithDatabase on http://localhost:8080 ...', etInfo);
      ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
      try
        ApiServer.UseStartup<TStartup>;
        cout('Database: .\shop.db (SQLite)', ccWhite);
        ApiServer.Start;
      finally
        ApiServer.Free;
      end;
    end
    else
    begin
      AppService.DisplayName := 'WebApi With Database';
      AppService.ServiceName := 'WebApiWithDatabaseSvc';
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
