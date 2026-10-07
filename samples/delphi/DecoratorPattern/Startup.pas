unit Startup;

{ DecoratorPattern Sample - S-23
  Registers the decorator manually: TProductService is the "real" service and
  TCachedProductService wraps it. The controller only sees IProductService. }

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Quick.Core.Extensions.Caching.Memory,
  Quick.Core.Caching.Abstractions,
  Service.Product,
  Service.ProductCached,
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
    .Extension<TMemoryCacheServiceExtension>
      .AddMemoryCache;

  // Register the concrete (inner) service under its own type
  services.AddSingleton<TProductService>;

  // Register the *decorated* service as IProductService:
  //   TCachedProductService wraps TProductService + IMemoryCache
  services.AddSingleton<IProductService, TCachedProductService>('',
    function : TCachedProductService
    begin
      Result := TCachedProductService.Create(
        services.Resolve<TProductService>,
        services.Resolve<IMemoryCache>);
    end);
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .UseSwagger('DecoratorPattern API', '1.0.0',
      'QuickCore DecoratorPattern sample API.')
    .UseRouting
    .UseMVC;
end;

end.
