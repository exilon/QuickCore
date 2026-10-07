program MessageQueueRedis;

(* MessageQueueRedis Sample - S-19
  Producer/Consumer pattern using Redis-backed message queue.

  - TOrderTask    : message payload (producer sends, consumer processes)
  - POST /api/orders/enqueue  -> publishes a message to Redis queue
  - Worker in background automatically dequeues and processes messages.

  Requires: Redis server on localhost:6379

  .NET equivalent: MassTransit + Redis transport, or StackExchange.Redis ISubscriber.
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Task.Order in 'tasks\Task.Order.pas',
  Controller.Orders in 'controllers\Controller.Orders.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('Starting MessageQueueRedis on http://localhost:8080 ...', etInfo);
      cout('Requires: Redis on localhost:6379', ccYellow);
      ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
      try
        ApiServer.UseStartup<TStartup>;
        cout('Enqueue: POST http://localhost:8080/api/orders/enqueue', ccWhite);
        ApiServer.Start;
      finally
        ApiServer.Free;
      end;
    end
    else
    begin
      AppService.DisplayName := 'Message Queue Redis Demo';
      AppService.ServiceName := 'MessageQueueRedisSvc';
      AppService.CanInstallWithOtherName := True;
      AppService.OnStart := procedure
        begin
          ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
          ApiServer.UseStartup<TStartup>;
        end;
      AppService.OnExecute := ApiServer.Start;
      AppService.CheckParams;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
