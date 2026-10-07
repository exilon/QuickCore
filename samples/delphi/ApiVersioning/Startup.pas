unit Startup;

{ ApiVersioning Sample - S-30 }

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Controller.ProductsV1,
  Controller.ProductsV2;

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
    .UseSwagger('ApiVersioning API', '1.0.0',
      'QuickCore ApiVersioning sample API.')
    .UseRouting
    .UseApiVersioning
    .UseMVC;
end;

end.
