unit Startup;

{ LocalizationSample Sample - S-20 }

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Quick.Core.Extensions.Localization,
  Controller.Greet;

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
    .Extension<TLocalizationServiceExtension>
      .AddLocalization(procedure(o : TLocalizationOptions)
        begin
          o.AddCulture('en');
          o.AddCulture('es');
          o.AddCulture('fr');
          o.AddIfNotfound := True;  // fall back to key if no translation
        end);
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .UseSwagger('LocalizationSample API', '1.0.0',
      'QuickCore LocalizationSample sample API.')
    .UseRouting
    .UseMVC;
end;

end.
