unit Startup;

{ MultipleDbContexts Sample - S-18
  Registers two independent DBContexts, each with its own SQLite file. }

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Quick.Core.Extensions.Entity,
  Quick.Core.Entity.Config,
  Models,
  Controller.Catalog,
  Controller.Orders;

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
    // First context: catalog (product definitions)
    .Extension<TEntityServiceExtension>
      .AddDBContext<TCatalogContext>(procedure(o : IDBConnectionOptions)
        begin
          o.UseSQLite;
          o.Database := '.\catalog.db';
        end)
    // Second context: orders (could be MSSQL in prod — just change provider)
    .Extension<TEntityServiceExtension>
      .AddDBContext<TOrdersContext>(procedure(o : IDBConnectionOptions)
        begin
          o.UseSQLite;
          o.Database := '.\orders.db';
        end);
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .UseSwagger('MultipleDbContexts API', '1.0.0',
      'QuickCore MultipleDbContexts sample API.')
    .UseRouting
    .UseMVC;
end;

end.
