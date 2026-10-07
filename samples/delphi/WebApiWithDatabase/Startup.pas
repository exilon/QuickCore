unit Startup;

{ WebApiWithDatabase Sample - S-07
  REST API with SQLite database via QuickCore Entity ORM + DI.
  DBContext is injected into the controller. }

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Extensions.Entity,
  Quick.Core.Entity.Config,
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
      .AddConsole(procedure(aOptions : TConsoleLoggerOptions)
        begin
          aOptions.LogLevel := LOG_DEBUG;
          aOptions.ShowEventColors := True;
          aOptions.ShowTimeStamp := True;
          aOptions.Enabled := True;
        end)
      .Build)
    .Extension<TEntityServiceExtension>
      .AddDBContext<TShopContext>(procedure(aOptions : IDBConnectionOptions)
        begin
          aOptions.UseSQLite;
          aOptions.Database := '.\shop.db';
        end);
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .UseSwagger('WebApiWithDatabase API', '1.0.0',
      'QuickCore WebApiWithDatabase sample API.')
    .UseRouting
    .UseMVC;
end;

end.
