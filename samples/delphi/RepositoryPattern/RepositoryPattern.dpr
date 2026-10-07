program RepositoryPattern;

(* RepositoryPattern Sample - S-21
  Demonstrates the Generic Repository pattern with QuickCore.
  The controller only depends on IRepository<TProduct>; the concrete
  TEntityRepository<TProduct> is wired up via the DI container in Startup.

  .NET equivalent: IRepository<T> / EF Core generic repository.

  Endpoints:
    GET    http://localhost:8080/api/products        -> all products
    GET    http://localhost:8080/api/products/:id   -> by id
    POST   http://localhost:8080/api/products        -> create
    PUT    http://localhost:8080/api/products/:id   -> update
    DELETE http://localhost:8080/api/products/:id   -> delete
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  FireDAC.Phys.SQLite,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Models in 'Models.pas',
  Repository.Product in 'repositories\Repository.Product.pas',
  Service.Product in 'services\Service.Product.pas',
  Controller.Products in 'controllers\Controller.Products.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('Starting RepositoryPattern on http://localhost:8080 ...', etInfo);
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
      AppService.DisplayName := 'Repository Pattern Demo';
      AppService.ServiceName := 'RepositoryPatternSvc';
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
