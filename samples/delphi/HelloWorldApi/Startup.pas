unit Startup;

{ HelloWorldApi Sample - S-01
  Minimal MVC server: one controller, logging to console, routing. }

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Controller.Hello;

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
      .AddConsole(procedure(aOptions : TConsoleLoggerOptions)
        begin
          aOptions.LogLevel := LOG_DEBUG;
          aOptions.ShowEventColors := True;
          aOptions.ShowTimeStamp := True;
          aOptions.ShowEventType := False;
          aOptions.Enabled := True;
        end)
      .Build);
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .UseSwagger('HelloWorldApi API', '1.0.0',
      'QuickCore HelloWorldApi sample API.')
    .UseRouting
    .UseMVC;
end;

end.
