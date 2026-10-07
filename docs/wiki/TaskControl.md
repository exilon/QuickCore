# TaskControl

> Module: `Quick.Core.TaskControl`  
> .NET equivalent: `System.Threading.Tasks` + `Quartz.NET` (simplified)

QuickCore TaskControl provides two asynchronous execution engines: **`TBackgroundTasks`** for background tasks with a worker pool, and **`TScheduledTasks`** for scheduled tasks using time expressions (intervals, specific times).

---

## Table of contents

1. [Basics](#basics)
2. [Register TaskControl (DI)](#register-taskcontrol-di)
3. [Background Tasks](#background-tasks)
4. [Scheduled Tasks](#scheduled-tasks)
5. [Monitoring](#monitoring)
6. [See also](#see-also)

---

## Basics

| Class / Interface | Role |
|-----------------|-----|
| `ITaskControl` | Main interface; exposes `BackgroundTasks` and `ScheduledTasks` |
| `TTaskControl` | Concrete implementation |
| `TBackgroundTasks` | Worker pool for background tasks |
| `TScheduledTasks` | Scheduler for periodic/timed tasks |
| `TTaskControlSettings` | Options (number of concurrent workers) |

---

## Register TaskControl (DI)

```pascal
uses Quick.Core.TaskControl;

// In ConfigureServices
services.Extension<TTaskControlServiceExtension>
  .AddTaskControl;

// With options in appsettings.json:
// "TaskControl": { "ConcurrentWorkers": 4 }
```

Or configure directly:

```pascal
services.Configure<TTaskControlSettings>('TaskControl',
  procedure(opt: TTaskControlSettings)
  begin
    opt.ConcurrentWorkers := 4;  // parallel workers (1-1000)
  end);

services.Extension<TTaskControlServiceExtension>
  .AddTaskControl;
```

---

## Background Tasks

Enqueue anonymous tasks that execute on the worker pool:

```pascal
uses Quick.Core.TaskControl;

type
  TEmailService = class
  private
    fTaskControl : ITaskControl;
    fSmtp        : ISmtpClient;
  public
    constructor Create(aTaskControl: ITaskControl; aSmtp: ISmtpClient);
    procedure SendEmailAsync(const aTo, aSubject, aBody: string);
  end;

procedure TEmailService.SendEmailAsync(
  const aTo, aSubject, aBody: string);
begin
  // Enqueue and forget — does not block the current thread
  fTaskControl.BackgroundTasks.AddTask(
    procedure
    begin
      fSmtp.Send(aTo, aSubject, aBody);
    end);
end;
```

### With task name (for logging)

```pascal
fTaskControl.BackgroundTasks.AddTask(
  'GenerateReport',
  procedure
  begin
    var report := fReportSvc.Generate(dateRange);
    fStorage.Save(report);
  end);
```

### With completion callback

```pascal
fTaskControl.BackgroundTasks.AddTask(
  procedure
  begin
    ProcessHeavyComputation;
  end,
  procedure(aTaskResult: ITaskResult)
  begin
    if aTaskResult.IsError then
      Logger.Error('Task failed: ' + aTaskResult.ErrorMessage)
    else
      Logger.Info('Task completed');
  end);
```

### C# equivalent

```csharp
// Fire-and-forget
_ = Task.Run(async () => await _smtp.SendAsync(to, subject, body));

// With controlled pool (Hangfire)
BackgroundJob.Enqueue(() => GenerateReport(dateRange));
```

---

## Scheduled Tasks

Schedule tasks that run periodically:

```pascal
uses Quick.Core.TaskControl;

type
  TMaintenanceService = class
  private
    fTaskControl : ITaskControl;
    fRepo        : IProductRepository;
    fCache       : IMemoryCache;
  public
    constructor Create(aTaskControl: ITaskControl; ...);
    procedure RegisterScheduledTasks;
  end;

procedure TMaintenanceService.RegisterScheduledTasks;
begin
  // Every 30 minutes
  fTaskControl.ScheduledTasks.AddTask(
    'ClearExpiredCache',
    30 * 60 * 1000,  // interval in ms
    procedure
    begin
      fCache.Flush;
      Logger.Info('Cache cleared');
    end);

  // Every hour
  fTaskControl.ScheduledTasks.AddTask(
    'SyncProducts',
    60 * 60 * 1000,
    procedure
    begin
      fRepo.SyncWithExternalSource;
    end);

  // Every 24 hours (daily maintenance task)
  fTaskControl.ScheduledTasks.AddTask(
    'DailyCleanup',
    24 * 60 * 60 * 1000,
    procedure
    begin
      fRepo.DeleteExpiredOrders;
      fRepo.ArchiveOldLogs;
    end);
end;
```

### Example in a Background Service

The most common pattern is to register scheduled tasks inside a `TBackgroundService`:

```pascal
type
  TSchedulerService = class(TBackgroundService)
  private
    fTaskControl : ITaskControl;
    fCache       : IMemoryCache;
  public
    constructor Create(aTaskControl: ITaskControl; aCache: IMemoryCache);
  protected
    procedure ExecuteAsync; override;
  end;

procedure TSchedulerService.ExecuteAsync;
begin
  // Register scheduled tasks on startup
  fTaskControl.ScheduledTasks.AddTask(
    'CacheWarmup',
    5 * 60 * 1000,  // every 5 minutes
    procedure
    begin
      WarmupProductCache;
    end);

  // Service stays alive until CancelRequested is True
  while not CancelRequested do
    Sleep(1000);
end;
```

### C# equivalent

```csharp
// With Quartz.NET
services.AddQuartz(q => {
    q.AddJob<CacheWarmupJob>(j => j.WithIdentity("CacheWarmup"));
    q.AddTrigger(t => t
        .ForJob("CacheWarmup")
        .WithSimpleSchedule(s => s.WithIntervalInMinutes(5).RepeatForever()));
});
```

---

## Monitoring

```pascal
// Worker pool status
var taskControl := services.Resolve<ITaskControl>();

with taskControl.BackgroundTasks do
begin
  Logger.Info(Format(
    'Workers: %d | Queued: %d | Total pushed: %d',
    [ConcurrentWorkers, TaskQueued, NumPushedTasks]));
end;

// Full JSON status
var json := (taskControl as TTaskControl).GetCurrentRunningTasksJson;
// → {"backgroundTasks":{"queued":2,"workers":4,"totalPushed":150},"scheduledTasks":{"totalPushed":48}}
```

---

## See also

- [Dependency Injection](Dependency-Injection.md) — `AddTaskControl`
- [Background Services](Background-Services.md) — alternative for long-running tasks
- [Message Queue](Message-Queue.md) — combining with queue processing


---

## Tabla de contenidos

1. [Conceptos básicos](#conceptos-básicos)
2. [Registrar TaskControl (DI)](#registrar-taskcontrol-di)
3. [Background Tasks — tareas en segundo plano](#background-tasks--tareas-en-segundo-plano)
4. [Scheduled Tasks — tareas programadas](#scheduled-tasks--tareas-programadas)
5. [Monitorización](#monitorización)
6. [Ver también](#ver-también)

---

## Conceptos básicos

| Clase / Interfaz | Rol |
|-----------------|-----|
| `ITaskControl` | Interfaz principal; expone `BackgroundTasks` y `ScheduledTasks` |
| `TTaskControl` | Implementación concreta |
| `TBackgroundTasks` | Pool de workers para tareas en segundo plano |
| `TScheduledTasks` | Planificador de tareas periódicas/programadas |
| `TTaskControlSettings` | Opciones (número de workers concurrentes) |

---

## Registrar TaskControl (DI)

```pascal
uses Quick.Core.TaskControl;

// En ConfigureServices
services.Extension<TTaskControlServiceExtension>
  .AddTaskControl;

// Con opciones en appsettings.json:
// "TaskControl": { "ConcurrentWorkers": 4 }
```

O configurar directamente:

```pascal
services.Configure<TTaskControlSettings>('TaskControl',
  procedure(opt: TTaskControlSettings)
  begin
    opt.ConcurrentWorkers := 4;  // workers paralelos (1-1000)
  end);

services.Extension<TTaskControlServiceExtension>
  .AddTaskControl;
```

---

## Background Tasks — tareas en segundo plano

Encola tareas anónimas que se ejecutan en el pool de workers:

```pascal
uses Quick.Core.TaskControl;

type
  TEmailService = class
  private
    fTaskControl : ITaskControl;
    fSmtp        : ISmtpClient;
  public
    constructor Create(aTaskControl: ITaskControl; aSmtp: ISmtpClient);
    procedure SendEmailAsync(const aTo, aSubject, aBody: string);
  end;

procedure TEmailService.SendEmailAsync(
  const aTo, aSubject, aBody: string);
begin
  // Encolar y olvidar — no bloquea el hilo actual
  fTaskControl.BackgroundTasks.AddTask(
    procedure
    begin
      fSmtp.Send(aTo, aSubject, aBody);
    end);
end;
```

### Con nombre de tarea (para logging)

```pascal
fTaskControl.BackgroundTasks.AddTask(
  'GenerateReport',
  procedure
  begin
    var report := fReportSvc.Generate(dateRange);
    fStorage.Save(report);
  end);
```

### Con callback de completado

```pascal
fTaskControl.BackgroundTasks.AddTask(
  procedure
  begin
    ProcessHeavyComputation;
  end,
  procedure(aTaskResult: ITaskResult)
  begin
    if aTaskResult.IsError then
      Logger.Error('Task failed: ' + aTaskResult.ErrorMessage)
    else
      Logger.Info('Task completed');
  end);
```

### Equivalente C#

```csharp
// Fire-and-forget
_ = Task.Run(async () => await _smtp.SendAsync(to, subject, body));

// Con pool controlado (Hangfire)
BackgroundJob.Enqueue(() => GenerateReport(dateRange));
```

---

## Scheduled Tasks — tareas programadas

Programa tareas que se ejecutan de forma recurrente:

```pascal
uses Quick.Core.TaskControl;

type
  TMaintenanceService = class
  private
    fTaskControl : ITaskControl;
    fRepo        : IProductRepository;
    fCache       : IMemoryCache;
  public
    constructor Create(aTaskControl: ITaskControl; ...);
    procedure RegisterScheduledTasks;
  end;

procedure TMaintenanceService.RegisterScheduledTasks;
begin
  // Cada 30 minutos
  fTaskControl.ScheduledTasks.AddTask(
    'ClearExpiredCache',
    30 * 60 * 1000,  // intervalo en ms
    procedure
    begin
      fCache.Flush;
      Logger.Info('Cache cleared');
    end);

  // Cada hora
  fTaskControl.ScheduledTasks.AddTask(
    'SyncProducts',
    60 * 60 * 1000,
    procedure
    begin
      fRepo.SyncWithExternalSource;
    end);

  // Cada 24 horas (tarea de mantenimiento diaria)
  fTaskControl.ScheduledTasks.AddTask(
    'DailyCleanup',
    24 * 60 * 60 * 1000,
    procedure
    begin
      fRepo.DeleteExpiredOrders;
      fRepo.ArchiveOldLogs;
    end);
end;
```

### Ejemplo en un Background Service

Lo más habitual es registrar las tareas programadas dentro de un `TBackgroundService`:

```pascal
type
  TSchedulerService = class(TBackgroundService)
  private
    fTaskControl : ITaskControl;
    fCache       : IMemoryCache;
  public
    constructor Create(aTaskControl: ITaskControl; aCache: IMemoryCache);
  protected
    procedure ExecuteAsync; override;
  end;

procedure TSchedulerService.ExecuteAsync;
begin
  // Registrar las tareas programadas al arrancar
  fTaskControl.ScheduledTasks.AddTask(
    'CacheWarmup',
    5 * 60 * 1000,  // cada 5 minutos
    procedure
    begin
      WarmupProductCache;
    end);

  // El servicio queda vivo hasta que CancelRequested sea True
  while not CancelRequested do
    Sleep(1000);
end;
```

### Equivalente C#

```csharp
// Con Quartz.NET
services.AddQuartz(q => {
    q.AddJob<CacheWarmupJob>(j => j.WithIdentity("CacheWarmup"));
    q.AddTrigger(t => t
        .ForJob("CacheWarmup")
        .WithSimpleSchedule(s => s.WithIntervalInMinutes(5).RepeatForever()));
});
```

---

## Monitorización

```pascal
// Estado del pool de workers
var taskControl := services.Resolve<ITaskControl>();

with taskControl.BackgroundTasks do
begin
  Logger.Info(Format(
    'Workers: %d | Queued: %d | Total pushed: %d',
    [ConcurrentWorkers, TaskQueued, NumPushedTasks]));
end;

// JSON completo de estado
var json := (taskControl as TTaskControl).GetCurrentRunningTasksJson;
// → {"backgroundTasks":{"queued":2,"workers":4,"totalPushed":150},"scheduledTasks":{"totalPushed":48}}
```

---

## Ver también

- [Dependency Injection](Dependency-Injection.md) — `AddTaskControl`
- [Background Services](Background-Services.md) — alternativa para tareas de larga duración
- [Message Queue](Message-Queue.md) — combinación con procesamiento de colas
