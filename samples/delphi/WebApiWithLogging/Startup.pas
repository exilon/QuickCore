unit Startup;

{ WebApiWithLogging Sample - S-08 }

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Controller.Logs;

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
      // Console: show all levels with color
      .AddConsole(procedure(o : TConsoleLoggerOptions)
        begin
          o.LogLevel        := LOG_DEBUG;
          o.ShowEventColors := True;
          o.ShowTimeStamp   := True;
          o.ShowEventType   := True;
          o.Enabled         := True;
        end)
      // File: rotate at 10 MB
      .AddFile(procedure(o : TFileLoggerOptions)
        begin
          o.FileName        := '.\app.log';
          o.MaxFileSizeInMB := 10;
          o.Enabled         := True;
        end)
      .Build);
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .UseSwagger('WebApiWithLogging API', '1.0.0',
      'QuickCore WebApiWithLogging sample API.')
    .UseRouting
    .UseMVC;
end;

end.
