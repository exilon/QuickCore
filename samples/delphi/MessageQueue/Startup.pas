unit Startup;

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Entity.Config,
  Quick.Core.Logging,
  Quick.Core.Extensions.MessageQueue.Redis,
  Controller.Home,
  PingTask;

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
        .AddFile(procedure(aOptions : TFileLoggerOptions)
          begin
            aOptions.LogLevel := LOG_DEBUG;
            aOptions.Enabled := True;
          end)
        .Build)
   .AddDebugger
   .AddOptions(TOptionsFileFormat.ofYAML,True);
    services.Extension<TMessageQueueServiceExtension>
    .AddRedisMessageQueue<TPingTask>(procedure(aOptions : TRedisMessageQueueOptions)
                           begin
                             aOptions.Host := 'klingon';
                             aOptions.Port := 6379;
                             aOptions.DataBase := 2;
                             aOptions.Key := 'mailqueue';
                             aOptions.Password := 'pass123';
                             aOptions.PopTimeoutSec := 40;
                             aOptions.MaxProducersPool := 10;
                             aOptions.MaxConsumersPool := 10;
                             aOptions.ReliableMessageQueue.CheckHangedMessagesIntervalSec := 30;
                             aOptions.ReliableMessageQueue.DetermineAsHangedAfterSec := 60;
                             aOptions.ReliableMessageQueue.Enabled := True;
                           end);
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
  .AddControllers
  .AddController(THomeController)
  .DefaultRoute(THomeController,'Home/Index')
  .UseWebRoot('.\wwwroot')
  .UseRouting
  .UseMVC;
end;

end.
