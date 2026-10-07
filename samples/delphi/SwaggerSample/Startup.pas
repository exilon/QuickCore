unit Startup;

{ SwaggerSample — S-25
  Registers IProductService as singleton and wires up UseSwagger(). }

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Models,
  Controller.Products;

type
  TStartup = class(TStartupMvc)
  public
    class procedure ConfigureServices(services : TServiceCollection); override;
    class procedure Configure(app : TMVCServer); override;
  end;

implementation

{ TStartup }

class procedure TStartup.ConfigureServices(services : TServiceCollection);
begin
  services
    .AddLogging(TLoggerBuilder.GetBuilder
      .AddConsole(procedure(o : TConsoleLoggerOptions)
        begin
          o.LogLevel        := LOG_DEBUG;
          o.ShowEventColors := True;
          o.ShowTimeStamp   := True;
          o.Enabled         := True;
        end)
      .Build)
    .AddSingleton<IProductService, TProductService>;
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    // Register Swagger middleware BEFORE UseRouting so /swagger* URLs are
    // intercepted by TSwaggerMiddleware and never reach the MVC pipeline.
    .UseSwagger('Products API', '1.0.0',
      'QuickCore SwaggerSample — in-memory Products CRUD with OpenAPI 3.0 docs')
    .UseRouting
    .UseMVC;
end;

end.
