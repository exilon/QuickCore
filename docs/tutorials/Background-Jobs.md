# Tutorial 8 — Background Jobs with TaskControl

> **Estimated time:** 25 minutes  
> **Level:** Intermediate  
> **Reference sample:** `samples/delphi/BackgroundJobsService` (S-16)

In real applications there are tasks that should not block the HTTP response: sending emails, processing files, cleaning up records, running reports. In this tutorial you will learn how to launch background jobs from an endpoint and query their status.

---

## What is `ITaskControl`?

`ITaskControl` exposes two independent engines:

| Engine | What it does | .NET equivalent |
|--------|-------------|----------------|
| `BackgroundTasks` | Thread pool for one-shot tasks | `IBackgroundTaskQueue` + `BackgroundService` |
| `ScheduledTasks` | Periodic tasks (cron-like) | `IHostedService` with `PeriodicTimer` |

Both are registered with a single DI line and can be injected into any controller or service.

---

## Tutorial architecture

```
BackgroundJobsService/
├── BackgroundJobsService.dpr
├── Startup.pas
└── controllers/
    └── Controller.Jobs.pas
```

---

## Step 1 — Jobs controller

Create `controllers/Controller.Jobs.pas`:

```pascal
unit Controller.Jobs;

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.TaskControl,
  Quick.Core.Logging.Abstractions,
  Quick.Threads;

type
  [Route('api/jobs')]
  [ApiController]
  TJobsController = class(THttpController)
  private
    fTaskControl : ITaskControl;
    fLogger      : ILogger;
  public
    constructor Create(aTaskControl : ITaskControl; aLogger : ILogger);
  published
    /// GET /api/jobs/status — worker pool status
    [HttpGet('status')]
    function Status : IActionResult;

    /// POST /api/jobs/cleanup — queue a cleanup task
    [HttpPost('cleanup')]
    function TriggerCleanup : IActionResult;

    /// POST /api/jobs/report — queue report generation
    [HttpPost('report')]
    function TriggerReport : IActionResult;

    /// POST /api/jobs/schedule — register a periodic task
    [HttpPost('schedule')]
    function ScheduleHeartbeat : IActionResult;
  end;

implementation

uses
  System.SysUtils;

constructor TJobsController.Create(aTaskControl : ITaskControl; aLogger : ILogger);
begin
  inherited Create;
  fTaskControl := aTaskControl;
  fLogger      := aLogger;
end;

function TJobsController.Status: IActionResult;
begin
  Result := Json(Format(
    '{"backgroundWorkers":%d,"scheduledTasks":%d,"queued":%d}',
    [fTaskControl.BackgroundTasks.ConcurrentWorkers,
     fTaskControl.ScheduledTasks.NumPushedTasks,
     fTaskControl.BackgroundTasks.NumTasksRunning]));
end;

function TJobsController.TriggerCleanup: IActionResult;
begin
  // AddTask queues the anonymous procedure in the thread pool
  fTaskControl.BackgroundTasks.AddTask(procedure(task : ITask)
    begin
      fLogger.Info('CleanupJob: starting cleanup...');
      Sleep(2000);   // simulates real work (e.g. delete temp files)
      fLogger.Info('CleanupJob: cleanup completed.');
    end);

  Result := Json('{"queued":true,"job":"CleanupJob"}');
  // The HTTP response is returned immediately,
  // while the job runs in a separate thread.
end;

function TJobsController.TriggerReport: IActionResult;
begin
  fTaskControl.BackgroundTasks.AddTask(procedure(task : ITask)
    var
      i : Integer;
    begin
      fLogger.Info('ReportJob: generating report...');
      for i := 1 to 5 do
      begin
        task.CheckCancelled;   // allows cancellation if the server stops
        fLogger.Info(Format('ReportJob: processing page %d/5', [i]));
        Sleep(500);
      end;
      fLogger.Info('ReportJob: report saved to ./report.pdf');
    end);

  Result := Json('{"queued":true,"job":"ReportJob","estimatedSeconds":3}');
end;

function TJobsController.ScheduleHeartbeat: IActionResult;
begin
  // Add a task that repeats every 30 seconds
  fTaskControl.ScheduledTasks.AddTask('HeartbeatJob', 30,
    procedure(task : ITask)
    begin
      fLogger.Info(Format('HeartbeatJob: server alive at %s',
        [FormatDateTime('hh:nn:ss', Now)]));
    end);

  Result := Json('{"scheduled":true,"job":"HeartbeatJob","intervalSeconds":30}');
end;

initialization
  RegisterController(TJobsController);

end.
```

---

## Step 2 — Startup with AddTaskControl

```pascal
unit Startup;

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Quick.Core.TaskControl,
  Quick.Core.Mvc.Extensions.TaskControl,
  Controller.Jobs;

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
      .AddConsole(procedure(o : TConsoleLoggerOptions)
        begin
          o.LogLevel        := LOG_DEBUG;
          o.ShowEventColors := True;
          o.ShowTimeStamp   := True;
          o.Enabled         := True;
        end)
      .Build)
    // Registers ITaskControl as Singleton + starts the worker pool
    .Extension<TTaskControlServiceExtension>
      .AddTaskControl;
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .AddController(TJobsController)
    .UseRouting
    .UseMVC;
end;

end.
```

---

## Step 3 — Entry point

```pascal
program BackgroundJobsService;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Controller.Jobs in 'controllers\Controller.Jobs.pas';

var
  Server : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    cout('Starting BackgroundJobsService on http://localhost:8080 ...', etInfo);
    Server := TMvcServer.Create('127.0.0.1', 8080, False);
    try
      Server.UseStartup<TStartup>;
      cout('Press [Enter] to stop.', ccYellow);
      Server.Start;
    finally
      Server.Free;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
```

---

## Step 4 — Test

### Initial pool status

```bash
curl http://localhost:8080/api/jobs/status
# {"backgroundWorkers":4,"scheduledTasks":0,"queued":0}
```

### Launch cleanup task

```bash
curl -X POST http://localhost:8080/api/jobs/cleanup
# {"queued":true,"job":"CleanupJob"}
# ← IMMEDIATE response, the job continues in the background
```

Server console (2 seconds later):
```
[INFO] CleanupJob: starting cleanup...
[INFO] CleanupJob: cleanup completed.
```

### Launch report

```bash
curl -X POST http://localhost:8080/api/jobs/report
# {"queued":true,"job":"ReportJob","estimatedSeconds":3}
```

### Register periodic task

```bash
curl -X POST http://localhost:8080/api/jobs/schedule
# {"scheduled":true,"job":"HeartbeatJob","intervalSeconds":30}
```

Every 30 seconds the console will show:
```
[INFO] HeartbeatJob: server alive at 10:00:30
[INFO] HeartbeatJob: server alive at 10:01:00
```

---

## Step 5 — Background Service with `IHostedService`

For complex startup/shutdown logic, use `IHostedService` instead of `ITaskControl`:

```pascal
type
  TDataSyncService = class(TBackgroundService)
  private
    fLogger : ILogger;
  public
    constructor Create(aLogger : ILogger);
    procedure Execute; override;        // runs in its own thread at Start
    procedure OnStopping; override;     // called at server Stop
  end;

implementation

constructor TDataSyncService.Create(aLogger : ILogger);
begin
  inherited Create;
  fLogger := aLogger;
end;

procedure TDataSyncService.Execute;
begin
  fLogger.Info('DataSyncService: started');
  while not Stopped do
  begin
    fLogger.Info('DataSyncService: synchronizing...');
    // Your synchronization logic here
    Sleep(60000);  // every 1 minute
  end;
  fLogger.Info('DataSyncService: stopped');
end;

procedure TDataSyncService.OnStopping;
begin
  fLogger.Info('DataSyncService: stop signal received');
end;
```

Register in Startup:
```pascal
uses Quick.Core.Extensions.Hosting.BackgroundService;

class procedure TStartup.ConfigureServices(services : TServiceCollection);
begin
  services
    .Extension<THostedServiceExtension>
      .AddHostedService<TDataSyncService>;
end;
```

`TDataSyncService.Execute` will start automatically when the server starts and will stop cleanly on shutdown.

---

## When to use each option

| Situation | Recommended solution |
|-----------|---------------------|
| One-shot task triggered by an endpoint | `BackgroundTasks.AddTask(proc)` |
| Periodic task configurable at runtime | `ScheduledTasks.AddTask(name, secs, proc)` |
| Background process with its own lifecycle | `TBackgroundService` + `AddHostedService<T>` |
| Processing messages from a queue | `IMessageQueue` + `AddHostedService<TConsumer>` |

---

## See also

- [Background Services](../wiki/Background-Services.md)
- [Message Queue](../wiki/Message-Queue.md) — queues for decoupling producers and consumers
- [API Reference — TaskControl](../API-Reference.md#16-taskcontrol)


---

## ¿Qué es `ITaskControl`?

`ITaskControl` expone dos motores independientes:

| Motor | Qué hace | Equivalente .NET |
|-------|---------|-----------------|
| `BackgroundTasks` | Pool de hilos para tareas one-shot | `IBackgroundTaskQueue` + `BackgroundService` |
| `ScheduledTasks` | Tareas periódicas (cron-like) | `IHostedService` con `PeriodicTimer` |

Ambos se registran con una sola línea de DI y se inyectan en cualquier controller o servicio.

---

## Arquitectura del tutorial

```
BackgroundJobsService/
├── BackgroundJobsService.dpr
├── Startup.pas
└── controllers/
    └── Controller.Jobs.pas
```

---

## Paso 1 — Controller de jobs

Crea `controllers/Controller.Jobs.pas`:

```pascal
unit Controller.Jobs;

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.TaskControl,
  Quick.Core.Logging.Abstractions,
  Quick.Threads;

type
  [Route('api/jobs')]
  [ApiController]
  TJobsController = class(THttpController)
  private
    fTaskControl : ITaskControl;
    fLogger      : ILogger;
  public
    constructor Create(aTaskControl : ITaskControl; aLogger : ILogger);
  published
    /// GET /api/jobs/status — estado del pool de workers
    [HttpGet('status')]
    function Status : IActionResult;

    /// POST /api/jobs/cleanup — encola una tarea de limpieza
    [HttpPost('cleanup')]
    function TriggerCleanup : IActionResult;

    /// POST /api/jobs/report — encola generación de informe
    [HttpPost('report')]
    function TriggerReport : IActionResult;

    /// POST /api/jobs/schedule — registra una tarea periódica
    [HttpPost('schedule')]
    function ScheduleHeartbeat : IActionResult;
  end;

implementation

uses
  System.SysUtils;

constructor TJobsController.Create(aTaskControl : ITaskControl; aLogger : ILogger);
begin
  inherited Create;
  fTaskControl := aTaskControl;
  fLogger      := aLogger;
end;

function TJobsController.Status: IActionResult;
begin
  Result := Json(Format(
    '{"backgroundWorkers":%d,"scheduledTasks":%d,"queued":%d}',
    [fTaskControl.BackgroundTasks.ConcurrentWorkers,
     fTaskControl.ScheduledTasks.NumPushedTasks,
     fTaskControl.BackgroundTasks.NumTasksRunning]));
end;

function TJobsController.TriggerCleanup: IActionResult;
begin
  // AddTask encola el procedimiento anónimo en el pool de hilos
  fTaskControl.BackgroundTasks.AddTask(procedure(task : ITask)
    begin
      fLogger.Info('CleanupJob: iniciando limpieza...');
      Sleep(2000);   // simula trabajo real (ej: borrar archivos temporales)
      fLogger.Info('CleanupJob: limpieza completada.');
    end);

  Result := Json('{"queued":true,"job":"CleanupJob"}');
  // La respuesta HTTP se devuelve inmediatamente,
  // mientras el trabajo se ejecuta en un hilo separado.
end;

function TJobsController.TriggerReport: IActionResult;
begin
  fTaskControl.BackgroundTasks.AddTask(procedure(task : ITask)
    var
      i : Integer;
    begin
      fLogger.Info('ReportJob: generando informe...');
      for i := 1 to 5 do
      begin
        task.CheckCancelled;   // permite cancelar el job si el server se detiene
        fLogger.Info(Format('ReportJob: procesando página %d/5', [i]));
        Sleep(500);
      end;
      fLogger.Info('ReportJob: informe guardado en ./report.pdf');
    end);

  Result := Json('{"queued":true,"job":"ReportJob","estimatedSeconds":3}');
end;

function TJobsController.ScheduleHeartbeat: IActionResult;
begin
  // Añadir una tarea que se repite cada 30 segundos
  fTaskControl.ScheduledTasks.AddTask('HeartbeatJob', 30,
    procedure(task : ITask)
    begin
      fLogger.Info(Format('HeartbeatJob: server alive at %s',
        [FormatDateTime('hh:nn:ss', Now)]));
    end);

  Result := Json('{"scheduled":true,"job":"HeartbeatJob","intervalSeconds":30}');
end;

initialization
  RegisterController(TJobsController);

end.
```

---

## Paso 2 — Startup con AddTaskControl

```pascal
unit Startup;

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Quick.Core.TaskControl,
  Quick.Core.Mvc.Extensions.TaskControl,
  Controller.Jobs;

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
      .AddConsole(procedure(o : TConsoleLoggerOptions)
        begin
          o.LogLevel        := LOG_DEBUG;
          o.ShowEventColors := True;
          o.ShowTimeStamp   := True;
          o.Enabled         := True;
        end)
      .Build)
    // Registra ITaskControl como Singleton + inicia el pool de workers
    .Extension<TTaskControlServiceExtension>
      .AddTaskControl;
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .AddController(TJobsController)
    .UseRouting
    .UseMVC;
end;

end.
```

---

## Paso 3 — Punto de entrada

```pascal
program BackgroundJobsService;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Controller.Jobs in 'controllers\Controller.Jobs.pas';

var
  Server : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    cout('Starting BackgroundJobsService on http://localhost:8080 ...', etInfo);
    Server := TMvcServer.Create('127.0.0.1', 8080, False);
    try
      Server.UseStartup<TStartup>;
      cout('Press [Enter] to stop.', ccYellow);
      Server.Start;
    finally
      Server.Free;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
```

---

## Paso 4 — Probar

### Estado inicial del pool

```bash
curl http://localhost:8080/api/jobs/status
# {"backgroundWorkers":4,"scheduledTasks":0,"queued":0}
```

### Lanzar tarea de limpieza

```bash
curl -X POST http://localhost:8080/api/jobs/cleanup
# {"queued":true,"job":"CleanupJob"}
# ← respuesta INMEDIATA, el trabajo sigue en background
```

Consola del servidor (2 segundos después):
```
[INFO] CleanupJob: iniciando limpieza...
[INFO] CleanupJob: limpieza completada.
```

### Lanzar informe

```bash
curl -X POST http://localhost:8080/api/jobs/report
# {"queued":true,"job":"ReportJob","estimatedSeconds":3}
```

### Registrar tarea periódica

```bash
curl -X POST http://localhost:8080/api/jobs/schedule
# {"scheduled":true,"job":"HeartbeatJob","intervalSeconds":30}
```

Cada 30 segundos aparecerá en consola:
```
[INFO] HeartbeatJob: server alive at 10:00:30
[INFO] HeartbeatJob: server alive at 10:01:00
```

---

## Paso 5 — Background Service con `IHostedService`

Para lógica de startup/shutdown compleja, usa `IHostedService` en lugar de `ITaskControl`:

```pascal
type
  TDataSyncService = class(TBackgroundService)
  private
    fLogger : ILogger;
  public
    constructor Create(aLogger : ILogger);
    procedure Execute; override;        // ejecutado en hilo propio al Start
    procedure OnStopping; override;     // llamado al Stop del servidor
  end;

implementation

constructor TDataSyncService.Create(aLogger : ILogger);
begin
  inherited Create;
  fLogger := aLogger;
end;

procedure TDataSyncService.Execute;
begin
  fLogger.Info('DataSyncService: iniciado');
  while not Stopped do
  begin
    fLogger.Info('DataSyncService: sincronizando...');
    // Aquí tu lógica de sincronización
    Sleep(60000);  // cada 1 minuto
  end;
  fLogger.Info('DataSyncService: detenido');
end;

procedure TDataSyncService.OnStopping;
begin
  fLogger.Info('DataSyncService: señal de parada recibida');
end;
```

Registrarlo en Startup:
```pascal
uses Quick.Core.Extensions.Hosting.BackgroundService;

class procedure TStartup.ConfigureServices(services : TServiceCollection);
begin
  services
    .Extension<THostedServiceExtension>
      .AddHostedService<TDataSyncService>;
end;
```

`TDataSyncService.Execute` arrancará automáticamente cuando el servidor inicie y se detendrá limpiamente al parar.

---

## Cuándo usar cada opción

| Situación | Solución recomendada |
|-----------|---------------------|
| Tarea one-shot lanzada por un endpoint | `BackgroundTasks.AddTask(proc)` |
| Tarea periódica configurable en runtime | `ScheduledTasks.AddTask(name, secs, proc)` |
| Proceso de fondo con ciclo de vida propio | `TBackgroundService` + `AddHostedService<T>` |
| Procesamiento de mensajes de una cola | `IMessageQueue` + `AddHostedService<TConsumer>` |

---

## Ver también

- [Background Services](../wiki/Background-Services.md)
- [Message Queue](../wiki/MessageQueue.md) — colas para desacoplar productores y consumidores
- [API Reference — TaskControl](../API-Reference.md#16-taskcontrol)
