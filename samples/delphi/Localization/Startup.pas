unit Startup;

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Entity.Config,
  Quick.Core.Logging,
  quick.Core.Extensions.Localization,
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
   .Extension<TLocalizationServiceExtension>()
    .AddLocalization(procedure(aOptions : TLocalizationOptions)
                     begin

                     end)
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
  .AddControllers
  .DefaultRoute(THomeController,'Home/Index')
  .UseWebRoot('.\wwwroot')
  .UseSwagger('Localization API', '1.0.0',
    'QuickCore Localization sample API.')
  .UseRouting
  .UseMVC;
end;

end.
