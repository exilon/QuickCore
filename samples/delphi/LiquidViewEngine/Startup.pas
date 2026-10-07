unit Startup;

{ LiquidViewEngine Sample - S-36 }

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Controller.Catalog;

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
          o.ShowEventType   := False;
          o.Enabled         := True;
        end)
      .Build);
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .DefaultRoute(TCatalogController, 'Catalog')
    .UseWebRoot('.\wwwroot')
    .UseSwagger('LiquidViewEngine API', '1.0.0',
      'QuickCore LiquidViewEngine sample API.')
    .UseStaticFiles
    .UseRouting
    .UseLiquidPages       // ← Liquid instead of Mustache
    .UseMVC;
end;

end.
