unit Startup;

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Entity.Config,
  Quick.Core.Logging,
  Quick.Core.Mvc.Extensions.ResponseCaching,
  Quick.Core.Extensions.Caching.Redis,
  Controller.Home;

type
  TStartup = class(TStartupMvc)
  public
    class procedure ConfigureServices(services : TServiceCollection); override;
    class procedure Configure(app : TMVCServer); override;
  end;

implementation

class procedure TStartup.ConfigureServices(services : TServiceCollection);
begin
  services
   .AddLogging(TLoggerBuilder.GetBuilder
        .AddConsole(procedure(aOptions : TConsoleLoggerOptions)
            begin
              aOptions.LogLevel := LOG_DEBUG;
              aOptions.ShowEventColors := True;
              aOptions.ShowTimeStamp := True;
              aOptions.ShowEventType := False;
              aOptions.Enabled := True;
            end)
        .Build)
   .AddDebugger
  //add response caching
  .Extension<TRedisCacheServiceExtension>
    .AddDistributedRedisCache(procedure(aOptions : TRedisCacheOptions)
        begin
          aOptions.PoolSize := 100;
          aOptions.Host := '192.168.1.11';
          aOptions.Port := 6379;
          aOptions.Password := 'pass123';
          aOptions.DatabaseNumber := 1;
        end);
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
  .AddControllers
  .AddController(THomeController)
  .DefaultRoute(THomeController,'Home/Index')
  .UseWebRoot('.\wwwroot')
  .Extension<TResponseCachingMVCServerExtension>
    .UseResponseCaching
  .UseRouting
  .UseMVC;
end;

end.
