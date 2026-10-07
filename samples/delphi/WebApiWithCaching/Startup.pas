unit Startup;

{ WebApiWithCaching Sample - S-09 }

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Quick.Core.Extensions.Caching.Memory,
  Controller.Weather;

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
      .AddMemoryCache(procedure(o : TMemoryCacheOptions)
        begin
          o.PurgeInterval := 60;  // seconds
        end);
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .UseSwagger('WebApiWithCaching API', '1.0.0',
      'QuickCore WebApiWithCaching sample API.')
    .UseRouting
    .UseMVC;
end;

end.
