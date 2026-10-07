program WebApiWithDI;

(* WebApiWithDI Sample - S-06
  REST API with Dependency Injection.
  IProductService (in-memory store) is registered as Singleton and
  automatically injected into TProductsController via constructor injection.

  .NET equivalent: ASP.NET Core WebAPI with services.AddSingleton<I,T>()
                   and constructor injection in controllers.

  Endpoints:
    GET    http://localhost:8080/api/products
    GET    http://localhost:8080/api/products/:id
    POST   http://localhost:8080/api/products
    DELETE http://localhost:8080/api/products/:id
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
  Service.Product in 'services\Service.Product.pas',
  Controller.Products in 'controllers\Controller.Products.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('Starting WebApiWithDI on http://localhost:8080 ...', etInfo);
      ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
      try
        ApiServer.UseStartup<TStartup>;
        cout('', ccWhite);
        cout('Try:', ccYellow);
        cout('  GET  http://localhost:8080/api/products', ccWhite);
        cout('  GET  http://localhost:8080/api/products/1', ccWhite);
        cout('', ccWhite);
        ApiServer.Start;
      finally
        ApiServer.Free;
      end;
    end
    else
    begin
      AppService.DisplayName := 'WebApi With DI';
      AppService.ServiceName := 'WebApiWithDISvc';
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
