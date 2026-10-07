unit Startup;

{ BackgroundJobsService Sample - S-16 }

interface

uses
  System.Classes,
  System.SysUtils,
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Quick.Core.TaskControl,
  Quick.Core.Mvc.Extensions.TaskControl,
  Quick.Core.Mvc.Middleware.TaskControlUI,
  Quick.Core.TaskControl.Persistence.Entity,
  Quick.Threads,
  Controller.Jobs;

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
    .AddOptions()
    .AddLogging(TLoggerBuilder.GetBuilder
      .AddConsole(procedure(o : TConsoleLoggerOptions)
        begin
          o.LogLevel        := LOG_DEBUG;
          o.ShowEventColors := True;
          o.ShowTimeStamp   := True;
          o.Enabled         := True;
        end)
      .Build)
    .Extension<TTaskControlServiceExtension>
      .AddTaskControl;
end;

class procedure TStartup.Configure(app : TMVCServer);
var
  taskControl : ITaskControl;
begin
  // Register some sample scheduled tasks so the dashboard has something to show
  taskControl := app.Services.Resolve<ITaskControl>;

  taskControl.ScheduledTasks
    .AddTask('HeartbeatCheck', procedure(task : ITask)
      begin
        // simulated heartbeat — runs every 10s
        Writeln('Doing HeartbeatCheck...' );
        TThread.Sleep(1000);
        var a := random(2);
        if a = 0 then
        begin
          Writeln('ERROR...');
          raise Exception.Create('Error doing job');
        end;


        Writeln('Finished HeartbeatCheck...' );
      end)
    .StartNow
    .RepeatEvery(10, tmSeconds);

  taskControl.ScheduledTasks
    .AddTask('DailyCleanup', procedure(task : ITask)
      begin
        // simulated daily cleanup — runs every 60s in this demo
        Writeln('Doing DailyCleanup...');
        TThread.Sleep(30000);
        var one := random(2);
        if one = 0 then
        begin
          Writeln('ERROR...');
          var res := 2 Div one;
        end;

        Writeln('Finished DailyCleanup...');
      end)
    .StartInSeconds(5)
    .RepeatEvery(60, tmSeconds);

  taskControl.ScheduledTasks
    .AddTask('MetricsSnapshot', procedure(task : ITask)
      begin
        // simulated metrics snapshot
        Writeln('Doing MetricsSnapshot...' );
        TThread.sleep(100);
        Writeln('Finished MetricsSnapshot...' );
      end)
    .StartNow
    .RepeatEvery(30, tmSeconds);

  // Flood the background worker pool every 20 seconds with a random batch of
  // short-lived jobs so the dashboard shows In Queue / Workers / Total Processed.
  taskControl.ScheduledTasks
    .AddTask('WorkerFlood', procedure(task : ITask)
      begin
        var batchSize := 5 + random(16); // 5..20 jobs
        Writeln(Format('WorkerFlood: dispatching %d background jobs...', [batchSize]));
        var i := 0;
        while i < batchSize do
        begin
          var jobNum := i + 1;
          taskControl.BackgroundTasks.AddTask(
            Format('SendEmail#%d', [taskControl.BackgroundTasks.NumPushedTasks + 1]),
            procedure(bgTask : ITask)
            begin
              var sleepMs := 500 + random(4500); // 0.5s..5s
              Writeln(Format('  [BG #%d] started (will run %dms)', [jobNum, sleepMs]));
              TThread.Sleep(sleepMs);
              if random(10) = 0 then
                raise Exception.CreateFmt('Simulated BG error in job #%d', [jobNum]);
              Writeln(Format('  [BG #%d] done', [jobNum]));
            end);
          Inc(i);
        end;
      end)
    .StartInSeconds(3)
    .RepeatEvery(20, tmSeconds);

  // Persist task stats to a local SQLite database via Quick.Core.Entity ORM.
  // On restart, executionTimes and lastExecution are restored automatically.
  taskControl.UseStorage(TEntityTaskStorage.CreateSQLite('data\tasks.db'));

  app
    .AddControllers
    .UseSwagger('BackgroundJobsService API', '1.0.0',
      'QuickCore BackgroundJobsService sample API.')
    .Extension<TTaskControlMVCServerExtension>.UseTaskControl
    .Extension<TTaskControlUIMVCServerExtension>.UseTaskControlUI(procedure(o : TTaskControlUIOptions)
      begin
        o.Title          := 'BackgroundJobsService';
        o.DefaultTheme   := 'dark';
        o.AutoRefreshMs  := 3000;
        o.FullWidthHeader:= True;
      end)
    .UseRouting
    .UseMVC;
end;

end.
