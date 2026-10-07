unit Startup;

{ CustomMiddleware Sample - S-11 }

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Controller.Ping,
  Middleware.Timing,
  Middleware.RequestId,
  Middleware.Logging;

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
  services.AddLogging(
    TLoggerBuilder.GetBuilder
      .AddConsole(procedure(o : TConsoleLoggerOptions)
        begin
          o.LogLevel        := LOG_DEBUG;
          o.ShowEventColors := True;
          o.ShowTimeStamp   := True;
          o.Enabled         := True;
        end)
      .Build);
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .UseMiddleware(TTimingMiddleware)
    .UseMiddleware(TRequestIdMiddleware)
    .UseMiddleware(TLoggingMiddleware)
    .UseSwagger('CustomMiddleware API', '1.0.0',
      'QuickCore CustomMiddleware sample API.')
    .UseRouting
    .UseMVC;
end;

end.
