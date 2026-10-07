program DecoratorPattern;

(* DecoratorPattern Sample - S-23
  Shows how to apply the Decorator pattern via the DI container to transparently
  add cross-cutting concerns (here: caching) without modifying the original service.

  Architecture:
    IProductService
      |-- TProductService (real implementation — reads from an in-memory list)
      |-- TCachedProductService (decorator — checks IMemoryCache before delegating)

  The container registers TCachedProductService as the IProductService, injecting
  TProductService as its inner "real" service.

  .NET equivalent: Scrutor AddDecorator<IService, TDecorator>.

  Endpoints:
    GET http://localhost:8080/api/products        -> served from cache after first call
    GET http://localhost:8080/api/products/:id   -> by id (individual cache keys)
    DELETE http://localhost:8080/api/products/cache -> flush the cache
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Service.Product in 'services\Service.Product.pas',
  Service.ProductCached in 'services\Service.ProductCached.pas',
  Controller.Products in 'controllers\Controller.Products.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('Starting DecoratorPattern on http://localhost:8080 ...', etInfo);
      ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
      try
        ApiServer.UseStartup<TStartup>;
        cout('GET http://localhost:8080/api/products  (first: real, next: cache)', ccWhite);
        cout('DELETE http://localhost:8080/api/products/cache  (flush cache)', ccWhite);
        ApiServer.Start;
      finally
        ApiServer.Free;
      end;
    end
    else
    begin
      AppService.DisplayName := 'Decorator Pattern Demo';
      AppService.ServiceName := 'DecoratorPatternSvc';
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
