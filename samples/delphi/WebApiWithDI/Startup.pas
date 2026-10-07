unit Startup;

{ WebApiWithDI Sample - S-06
  Shows constructor injection of IProductService into TProductsController. }

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Service.Product,
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
      .AddConsole(procedure(aOptions : TConsoleLoggerOptions)
        begin
          aOptions.LogLevel := LOG_DEBUG;
          aOptions.ShowEventColors := True;
          aOptions.ShowTimeStamp := True;
          aOptions.Enabled := True;
        end)
      .Build)
    // Register the service as singleton (in-memory store — one per app lifetime)
    .AddSingleton<IProductService, TProductService>;
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .UseSwagger('WebApiWithDI API', '1.0.0',
      'QuickCore WebApiWithDI sample API.')
    .UseRouting
    .UseMVC;
end;

end.
