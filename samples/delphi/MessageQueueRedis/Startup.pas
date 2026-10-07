unit Startup;

{ MessageQueueRedis Sample - S-19 }

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Quick.Core.Extensions.MessageQueue.Redis,
  Task.Order,
  Controller.Orders;

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
      .Build)
    .Extension<TMessageQueueServiceExtension>
      .AddRedisMessageQueue<TOrderMessage>(procedure(o : TRedisMessageQueueOptions)
        begin
          o.Host                := 'localhost';
          o.Port                := 6379;
          o.DataBase            := 0;
          o.Key                 := 'orders';
          o.PopTimeoutSec       := 30;
          o.MaxProducersPool    := 5;
          o.MaxConsumersPool    := 3;
          o.ReliableMessageQueue.Enabled                        := True;
          o.ReliableMessageQueue.CheckHangedMessagesIntervalSec := 60;
          o.ReliableMessageQueue.DetermineAsHangedAfterSec      := 120;
        end);
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .UseSwagger('MessageQueueRedis API', '1.0.0',
      'QuickCore MessageQueueRedis sample API.')
    .UseRouting
    .UseMVC;
end;

end.
