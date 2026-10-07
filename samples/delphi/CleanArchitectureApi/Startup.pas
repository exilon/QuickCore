unit Startup;

{ CleanArchitectureApi Sample - S-15
  Wires all layers together via DI. Only Startup knows about Infrastructure. }

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Quick.Core.Extensions.Entity,
  Quick.Core.Entity.Config,
  Domain.Product,
  Application.Service.Product,
  Infrastructure.Repository.Product,
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
    // Infrastructure: DBContext
    .Extension<TEntityServiceExtension>
      .AddDBContext<TShopContext>(procedure(o : IDBConnectionOptions)
        begin
          o.UseSQLite;
          o.Database := '.\shop_clean.db';
        end);

  // Infrastructure -> Domain: Repository
  services.AddScoped<IProductRepository, TProductRepository>('',
    function : TProductRepository
    begin
      Result := TProductRepository.Create(services.Resolve<TShopContext>);
    end);

  // Application: Service
  services.AddScoped<IProductService, TProductAppService>;
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .UseSwagger('CleanArchitectureApi API', '1.0.0',
      'QuickCore CleanArchitectureApi sample API.')
    .UseRouting
    .UseMVC;
end;

end.
