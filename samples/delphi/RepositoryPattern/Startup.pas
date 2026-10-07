unit Startup;

{ RepositoryPattern Sample - S-21 }

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Quick.Core.Extensions.Entity,
  Quick.Core.Entity.Config,
  Quick.Core.Entity.Repository,
  Models,
  Repository.Product,
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
      .AddConsole(procedure(o : TConsoleLoggerOptions)
        begin
          o.LogLevel        := LOG_DEBUG;
          o.ShowEventColors := True;
          o.ShowTimeStamp   := True;
          o.Enabled         := True;
        end)
      .Build)
    .Extension<TEntityServiceExtension>
      .AddDBContext<TShopContext>(procedure(o : IDBConnectionOptions)
        begin
          o.UseSQLite;
          o.Database := '.\shop_repo.db';
        end);

  // Register concrete repository using a factory that captures services
  services.AddScoped<IProductRepository, TProductRepository>('',
    function: TProductRepository
    begin
      Result := TProductRepository.Create(
        services.Resolve<TShopContext>.Products, 'Id');
    end);

  services.AddScoped<IProductService, TProductService>;
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .UseSwagger('RepositoryPattern API', '1.0.0',
      'QuickCore RepositoryPattern sample API.')
    .UseRouting
    .UseMVC;
end;

end.
