unit Startup;

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Entity.Config,
  Quick.Core.Logging,
  Quick.Core.Mvc.Extensions.ResponseCaching,
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
   .Extension<TResponseCachingServiceExtension>
     .AddResponseCaching
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
  .AddControllers
  .DefaultRoute(THomeController,'Home/Index')
  //.DefaultController(THomeController);
  //.MapRoute('default',TTestController,'{controller=Test}/{action=Index}/{id?}')
  .UseWebRoot('.\wwwroot')
  .Extension<TResponseCachingMVCServerExtension>
    .UseResponseCaching
  .UseRouting
  .UseMVC;
end;

end.
