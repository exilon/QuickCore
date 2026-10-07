# Background Services

> Module: `Quick.Core.Extensions.Hosting.BackgroundService`  
> .NET equivalent: `Microsoft.Extensions.Hosting.BackgroundService` + `IHostedService`

QuickCore allows running long-running tasks in the background using `IHostedService` and the `TBackgroundService` base class. Services are started and stopped together with the application host.

---

## Table of contents

1. [Basics](#basics)
2. [Implement IHostedService](#implement-ihostedservice)
3. [TBackgroundService — base class](#tbackgroundservice--base-class)
4. [Register and start](#register-and-start)
5. [Practical examples](#practical-examples)
6. [TGenericHost — console applications](#tgenerichost--console-applications)
7. [See also](#see-also)

---

## Basics

| Class / Interface | Role |
|-----------------|-----|
| `IHostedService` | Interface with `StartAsync` / `StopAsync` |
| `TBackgroundService` | Abstract base class; manages the internal thread |
| `IHostedServiceManager` | Manages the lifecycle of all registered services |
| `THostedServiceExtension` | Extension method `AddHostedService<T>` for DI |

---

## Implement IHostedService

For full control over the lifecycle:

```pascal
uses Quick.Core.Extensions.Hosting.BackgroundService;

type
  TEmailNotificationService = class(TInterfacedObject, IHostedService)
  private
    fTimer   : TTimer;
    fQueue   : IMessageQueue<TEmailMessage>;
  public
    constructor Create(aQueue: IMessageQueue<TEmailMessage>);
    procedure StartAsync;
    procedure StopAsync;
  end;

procedure TEmailNotificationService.StartAsync;
begin
  // Start notification logic
  fTimer := TTimer.Create(nil);
  fTimer.Interval := 5000;
  fTimer.OnTimer  := ProcessQueue;
  fTimer.Enabled  := True;
end;

procedure TEmailNotificationService.StopAsync;
begin
  fTimer.Enabled := False;
  fTimer.Free;
end;
```

### C# equivalent

```csharp
public class EmailNotificationService : IHostedService
{
    public Task StartAsync(CancellationToken ct) { ... return Task.CompletedTask; }
    public Task StopAsync(CancellationToken ct)  { ... return Task.CompletedTask; }
}
```

---

## TBackgroundService — base class

The most common pattern. Override `ExecuteAsync`, which runs in a **separate thread**. Use `CancelRequested` to detect the stop signal.

```pascal
uses Quick.Core.Extensions.Hosting.BackgroundService;

type
  TOrderProcessorService = class(TBackgroundService)
  private
    fOrderQueue : IMessageQueue<TOrder>;
    fOrderSvc   : IOrderService;
  public
    constructor Create(
      aQueue  : IMessageQueue<TOrder>;
      aOrderSvc : IOrderService);
  protected
    procedure ExecuteAsync; override;
  end;

procedure TOrderProcessorService.ExecuteAsync;
var
  order : TOrder;
begin
  while not CancelRequested do
  begin
    // Try to pop an order from the queue (blocks N seconds)
    if fOrderQueue.Pop(order) = wrOk then
    begin
      try
        fOrderSvc.Process(order);
        fOrderQueue.Remove(order);
      except
        on E: Exception do
          fOrderQueue.Failed(order);
      end;
    end;
  end;
end;
```

### Periodic loop with sleep

```pascal
procedure TMetricsCollectorService.ExecuteAsync;
begin
  while not CancelRequested do
  begin
    CollectAndSendMetrics;
    // Wait 30 seconds before the next iteration
    var elapsed := 0;
    while (elapsed < 30000) and not CancelRequested do
    begin
      Sleep(100);
      Inc(elapsed, 100);
    end;
  end;
end;
```

---

## Register and start

```pascal
uses
  Quick.Core.Extensions.Hosting.BackgroundService,
  Quick.Core.DependencyInjection;

// In ConfigureServices
services.Extension<THostedServiceExtension>
  .AddHostedService<TOrderProcessorService>;

services.Extension<THostedServiceExtension>
  .AddHostedService<TMetricsCollectorService>;
```

> Services start automatically when the host calls `Start` and stop on `Stop`. No additional code is needed.

### With TCoreApp (service applications)

```pascal
uses Quick.Core.App;

type
  TMyAppStartup = class(TStartupBase)
  public
    class procedure ConfigureServices(services: TServiceCollection); override;
  end;

class procedure TMyAppStartup.ConfigureServices(services: TServiceCollection);
begin
  services.AddSingleton<IOrderService, TOrderService>;
  services.Extension<THostedServiceExtension>
    .AddHostedService<TOrderProcessorService>;
end;

begin
  TCoreApp.Create(TMyAppStartup).Start;
end.
```

---

## Practical examples

### Periodic cleanup of expired sessions

```pascal
type
  TSessionCleanupService = class(TBackgroundService)
  private
    fSessionStore : ISessionStore;
  public
    constructor Create(aStore: ISessionStore);
  protected
    procedure ExecuteAsync; override;
  end;

procedure TSessionCleanupService.ExecuteAsync;
begin
  while not CancelRequested do
  begin
    fSessionStore.DeleteExpired;
    // Run every hour
    var waited := 0;
    while (waited < 3600000) and not CancelRequested do
    begin
      Sleep(1000);
      Inc(waited, 1000);
    end;
  end;
end;
```

### Data sync with external system

```pascal
type
  TSyncService = class(TBackgroundService)
  private
    fApiClient : IExternalApiClient;
    fRepo      : IProductRepository;
  protected
    procedure ExecuteAsync; override;
  end;

procedure TSyncService.ExecuteAsync;
var
  products : TList<TProduct>;
begin
  while not CancelRequested do
  begin
    try
      products := fApiClient.FetchUpdates;
      for var p in products do
        fRepo.AddOrUpdate(p);
    except
      on E: Exception do
        Logger.Error('Sync failed: ' + E.Message);
    end;
    Sleep(60000); // every minute
  end;
end;
```

---

## TGenericHost — console applications

For console apps or daemons without MVC:

```pascal
uses Quick.Core.App;

begin
  THostBuilder.Create
    .ConfigureServices(procedure(services: TServiceCollection)
    begin
      services.AddOptions(ofJSON);
      services.AddSingleton<IOrderService, TOrderService>;
      services.Extension<THostedServiceExtension>
        .AddHostedService<TOrderProcessorService>;
    end)
    .Build
    .Run;  // Blocks until Ctrl+C or Stop
end.
```

### C# equivalent

```csharp
Host.CreateDefaultBuilder()
    .ConfigureServices(services =>
    {
        services.AddHostedService<OrderProcessorService>();
    })
    .Build()
    .Run();
```

---

## See also

- [Dependency Injection](Dependency-Injection.md) — `AddHostedService`, lifetimes
- [TaskControl](TaskControl.md) — background and scheduled tasks
- [Message Queue](Message-Queue.md) — queue processing in background services


---

## Tabla de contenidos

1. [Conceptos básicos](#conceptos-básicos)
2. [Implementar IHostedService](#implementar-ihostedservice)
3. [TBackgroundService — clase base](#tbackgroundservice--clase-base)
4. [Registrar y arrancar](#registrar-y-arrancar)
5. [Ejemplos prácticos](#ejemplos-prácticos)
6. [TGenericHost — aplicaciones de consola](#tgenerichost--aplicaciones-de-consola)
7. [Ver también](#ver-también)

---

## Conceptos básicos

| Clase / Interfaz | Rol |
|-----------------|-----|
| `IHostedService` | Interfaz con `StartAsync` / `StopAsync` |
| `TBackgroundService` | Clase base abstracta; implementa el hilo interno |
| `IHostedServiceManager` | Gestiona el ciclo de vida de todos los servicios registrados |
| `THostedServiceExtension` | Extension method `AddHostedService<T>` para DI |

---

## Implementar IHostedService

Para control total sobre el ciclo de vida:

```pascal
uses Quick.Core.Extensions.Hosting.BackgroundService;

type
  TEmailNotificationService = class(TInterfacedObject, IHostedService)
  private
    fTimer   : TTimer;
    fQueue   : IMessageQueue<TEmailMessage>;
  public
    constructor Create(aQueue: IMessageQueue<TEmailMessage>);
    procedure StartAsync;
    procedure StopAsync;
  end;

procedure TEmailNotificationService.StartAsync;
begin
  // Arrancar lógica de notificaciones
  fTimer := TTimer.Create(nil);
  fTimer.Interval := 5000;
  fTimer.OnTimer  := ProcessQueue;
  fTimer.Enabled  := True;
end;

procedure TEmailNotificationService.StopAsync;
begin
  fTimer.Enabled := False;
  fTimer.Free;
end;
```

### Equivalente C#

```csharp
public class EmailNotificationService : IHostedService
{
    public Task StartAsync(CancellationToken ct) { ... return Task.CompletedTask; }
    public Task StopAsync(CancellationToken ct)  { ... return Task.CompletedTask; }
}
```

---

## TBackgroundService — clase base

La forma más común. Override `ExecuteAsync`, que corre en un **hilo separado**. Usa `CancelRequested` para detectar la señal de parada.

```pascal
uses Quick.Core.Extensions.Hosting.BackgroundService;

type
  TOrderProcessorService = class(TBackgroundService)
  private
    fOrderQueue : IMessageQueue<TOrder>;
    fOrderSvc   : IOrderService;
  public
    constructor Create(
      aQueue  : IMessageQueue<TOrder>;
      aOrderSvc : IOrderService);
  protected
    procedure ExecuteAsync; override;
  end;

procedure TOrderProcessorService.ExecuteAsync;
var
  order : TOrder;
begin
  while not CancelRequested do
  begin
    // Intentar sacar un pedido de la cola (bloquea N segundos)
    if fOrderQueue.Pop(order) = wrOk then
    begin
      try
        fOrderSvc.Process(order);
        fOrderQueue.Remove(order);
      except
        on E: Exception do
          fOrderQueue.Failed(order);
      end;
    end;
  end;
end;
```

### Bucle periódico con sleep

```pascal
procedure TMetricsCollectorService.ExecuteAsync;
begin
  while not CancelRequested do
  begin
    CollectAndSendMetrics;
    // Esperar 30 segundos antes de la siguiente iteración
    var elapsed := 0;
    while (elapsed < 30000) and not CancelRequested do
    begin
      Sleep(100);
      Inc(elapsed, 100);
    end;
  end;
end;
```

---

## Registrar y arrancar

```pascal
uses
  Quick.Core.Extensions.Hosting.BackgroundService,
  Quick.Core.DependencyInjection;

// En ConfigureServices
services.Extension<THostedServiceExtension>
  .AddHostedService<TOrderProcessorService>;

services.Extension<THostedServiceExtension>
  .AddHostedService<TMetricsCollectorService>;
```

> Los servicios se arrancan automáticamente cuando el host llama a `Start` y se detienen en `Stop`. No es necesario ningún código adicional.

### Con TCoreApp (aplicaciones de servicio)

```pascal
uses Quick.Core.App;

type
  TMyAppStartup = class(TStartupBase)
  public
    class procedure ConfigureServices(services: TServiceCollection); override;
  end;

class procedure TMyAppStartup.ConfigureServices(services: TServiceCollection);
begin
  services.AddSingleton<IOrderService, TOrderService>;
  services.Extension<THostedServiceExtension>
    .AddHostedService<TOrderProcessorService>;
end;

begin
  TCoreApp.Create(TMyAppStartup).Start;
end.
```

---

## Ejemplos prácticos

### Limpieza periódica de sesiones expiradas

```pascal
type
  TSessionCleanupService = class(TBackgroundService)
  private
    fSessionStore : ISessionStore;
  public
    constructor Create(aStore: ISessionStore);
  protected
    procedure ExecuteAsync; override;
  end;

procedure TSessionCleanupService.ExecuteAsync;
begin
  while not CancelRequested do
  begin
    fSessionStore.DeleteExpired;
    // Ejecutar cada hora
    var waited := 0;
    while (waited < 3600000) and not CancelRequested do
    begin
      Sleep(1000);
      Inc(waited, 1000);
    end;
  end;
end;
```

### Sincronización de datos con sistema externo

```pascal
type
  TSyncService = class(TBackgroundService)
  private
    fApiClient : IExternalApiClient;
    fRepo      : IProductRepository;
  protected
    procedure ExecuteAsync; override;
  end;

procedure TSyncService.ExecuteAsync;
var
  products : TList<TProduct>;
begin
  while not CancelRequested do
  begin
    try
      products := fApiClient.FetchUpdates;
      for var p in products do
        fRepo.AddOrUpdate(p);
    except
      on E: Exception do
        Logger.Error('Sync failed: ' + E.Message);
    end;
    Sleep(60000); // cada minuto
  end;
end;
```

---

## TGenericHost — aplicaciones de consola

Para apps de consola o daemons sin MVC:

```pascal
uses Quick.Core.App;

begin
  THostBuilder.Create
    .ConfigureServices(procedure(services: TServiceCollection)
    begin
      services.AddOptions(ofJSON);
      services.AddSingleton<IOrderService, TOrderService>;
      services.Extension<THostedServiceExtension>
        .AddHostedService<TOrderProcessorService>;
    end)
    .Build
    .Run;  // Bloquea hasta Ctrl+C o Stop
end.
```

### Equivalente C#

```csharp
Host.CreateDefaultBuilder()
    .ConfigureServices(services =>
    {
        services.AddHostedService<OrderProcessorService>();
    })
    .Build()
    .Run();
```

---

## Ver también

- [Dependency Injection](Dependency-Injection.md) — `AddHostedService`, lifetimes
- [TaskControl](TaskControl.md) — tareas en segundo plano y tareas programadas
- [Message Queue](Message-Queue.md) — procesamiento de colas en background services
