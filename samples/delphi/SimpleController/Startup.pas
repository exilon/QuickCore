unit Startup;

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Entity.Config,
  Quick.Core.Logging,
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
   .AddDebugger;
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
  .AddControllers
  .DefaultRoute(THomeController,'Home/Index')
  .UseWebRoot('.\wwwroot')
  .UseSwagger('SimpleController API', '1.0.0',
    'QuickCore SimpleController sample API.')
  .UseRouting
  .UseMVC;
end;

end.
