unit Startup;

{ HealthChecksDashboard Sample - S-12 }

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  System.TimeSpan,
  Quick.Core.Extensions.HealthChecks,
  Quick.Core.Mvc.Middleware.HealthChecksUI,
  Controller.Info;

type
  TStartup = class(TStartupMvc)
  public
    class procedure ConfigureServices(services : TServiceCollection); override;
    class procedure Configure(app : TMVCServer); override;
  end;

implementation

{ TStartup }

class procedure TStartup.ConfigureServices(services : TServiceCollection);
var
  selfCheck : IHealthCheck;
begin
  selfCheck := THealthCheck.Create(TTimeSpan.FromMinutes(5));
  selfCheck.Name := 'self';

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
    .Extension<THealthChecksServiceExtension>
      .AddHealthChecks
      .AddCheck(selfCheck)
      .AddMemoryCheck('memory', 512, TTimeSpan.FromMinutes(5))
      .AddInMemoryStorage;
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .Extension<THealthChecksUIMVCServerExtension>
      .UseHealthChecksUI
    .UseSwagger('HealthChecksDashboard API', '1.0.0',
      'QuickCore HealthChecksDashboard sample API.')
    .UseRouting
    .UseMVC;
end;

end.
