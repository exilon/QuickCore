# Options Monitor

> Modules: `Quick.Core.Options.Monitor`, `Quick.Core.Extensions.OptionsMonitor`  
> .NET equivalent: `Microsoft.Extensions.Options` — `IOptionsMonitor<T>`, `IOptionsSnapshot<T>`

QuickCore Options Monitor allows reacting to configuration changes at runtime without restarting the process. When the file watcher detects a change in `appsettings.json`, all registered `IOptionsMonitor<T>` instances notify their callbacks.

---

## Table of contents

1. [Interfaces](#interfaces)
2. [DI registration](#di-registration)
3. [IOptionsMonitor — change subscription](#ioptionsmonitor--change-subscription)
4. [IOptionsSnapshot — point-in-time read](#ioptionssnapshot--point-in-time-read)
5. [IOptionsChangeToken — cancel subscription](#ioptionschangetoken--cancel-subscription)
6. [.NET comparison](#net-comparison)
7. [See also](#see-also)

---

## Interfaces

| Interface / Class | Role |
|-----------------|-----|
| `IOptionsMonitor<T>` | Current value + notification on config change. Singleton. |
| `IOptionsSnapshot<T>` | Read-only current value without notifications. Singleton. |
| `IOptionsChangeToken` | Handle returned by `OnChange`. Call `Unregister` to stop listening. |
| `TOptionsMonitor<T>` | Implementation; hooks into the container's `OnConfigReloaded` event. |
| `TOptionsMonitorServiceExtension` | DI extensions: `AddOptionsMonitor<T>`, `AddOptionsSnapshot<T>`. |

---

## DI registration

**Prerequisite:** the options section must be registered with `services.Configure<T>` before calling these methods.

```pascal
uses Quick.Core.Extensions.OptionsMonitor;

// Register options section:
services.Configure<TDatabaseOptions>('Database');

// Reactive monitor (with OnChange notifications):
services.Extension<TOptionsMonitorServiceExtension>
  .AddOptionsMonitor<TDatabaseOptions>;

// Snapshot (current value read-only):
services.Extension<TOptionsMonitorServiceExtension>
  .AddOptionsSnapshot<TFeatureFlags>;
```

---

## IOptionsMonitor — change subscription

```pascal
uses Quick.Core.Options.Monitor;

type
  TDatabaseService = class
  private
    fMonitor : IOptionsMonitor<TDatabaseOptions>;
    fToken   : IOptionsChangeToken;
    fConnStr : string;
    procedure OnOptionsChanged(aNewOpts: TDatabaseOptions);
  public
    constructor Create(aMonitor: IOptionsMonitor<TDatabaseOptions>);
    destructor Destroy; override;
  end;

constructor TDatabaseService.Create(aMonitor: IOptionsMonitor<TDatabaseOptions>);
begin
  fMonitor := aMonitor;
  // Read initial value
  fConnStr := fMonitor.CurrentValue.ConnectionString;
  // Subscribe to future changes
  fToken := fMonitor.OnChange(procedure(o: TDatabaseOptions)
    begin
      fConnStr := o.ConnectionString;
      Reconnect;
    end);
end;

destructor TDatabaseService.Destroy;
begin
  // Cancel subscription to avoid dangling references
  if Assigned(fToken) then
    fToken.Unregister;
  inherited;
end;
```

> **Important:** always store the `IOptionsChangeToken` and call `Unregister` in the destructor to avoid memory leaks.

---

## IOptionsSnapshot — point-in-time read

Suitable for short-lived consumers (e.g. an MVC controller) that only need the current value without subscribing to events.

```pascal
uses Quick.Core.Options.Monitor;

type
  TFeatureController = class(TControllerBase)
  private
    fFeatures : IOptionsSnapshot<TFeatureFlags>;
  public
    constructor Create(aFeatures: IOptionsSnapshot<TFeatureFlags>);
    function GetStatus: IActionResult;
  end;

constructor TFeatureController.Create(aFeatures: IOptionsSnapshot<TFeatureFlags>);
begin
  inherited Create;
  fFeatures := aFeatures;
end;

function TFeatureController.GetStatus: IActionResult;
begin
  if fFeatures.Value.NewCheckoutEnabled then
    Result := Ok('new-checkout')
  else
    Result := Ok('legacy-checkout');
end;
```

---

## IOptionsChangeToken — cancel subscription

`IOptionsChangeToken` is the interface returned by `IOptionsMonitor<T>.OnChange`. It is the equivalent of `IDisposable` in .NET.

```pascal
var token := monitor.OnChange(procedure(o: TMyOptions)
  begin
    // reaction to change
  end);

// Later, to stop listening:
token.Unregister;
// Idempotent — can be called multiple times without error.
```

---

## .NET comparison

| Feature | ASP.NET Core (.NET) | QuickCore |
|---------|---------------------|-----------|
| Current value | `IOptionsMonitor<T>.CurrentValue` | `IOptionsMonitor<T>.CurrentValue` |
| Subscription | `monitor.OnChange(Action<T>)` → `IDisposable` | `monitor.OnChange(TOptionsChangeCallback<T>)` → `IOptionsChangeToken` |
| Cancel subscription | `token.Dispose()` | `token.Unregister` |
| Read-only | `IOptionsSnapshot<T>.Value` | `IOptionsSnapshot<T>.Value` |
| DI registration | `services.AddOptions<T>().BindConfiguration(...)` | `services.Configure<T>('Section')` + `AddOptionsMonitor<T>` |
| Reload trigger | `IConfiguration` reload (file watcher) | `OnConfigReloaded` on the container (appsettings.json file watcher) |

---

## See also

- [Dependency Injection](Dependency-Injection.md) — `Configure<T>`, `IOptions<T>`
- [API Reference](../API-Reference.md)


---

## Tabla de contenidos

1. [Interfaces](#interfaces)
2. [Registro DI](#registro-di)
3. [IOptionsMonitor — suscripción a cambios](#ioptionsmonitor--suscripción-a-cambios)
4. [IOptionsSnapshot — lectura puntual](#isnapshot--lectura-puntual)
5. [IOptionsChangeToken — cancelar suscripción](#ioptionschangetoken--cancelar-suscripción)
6. [Comparativa .NET](#comparativa-net)
7. [Ver también](#ver-también)

---

## Interfaces

| Interfaz / Clase | Rol |
|-----------------|-----|
| `IOptionsMonitor<T>` | Valor actual + notificación en cambio de config. Singleton. |
| `IOptionsSnapshot<T>` | Lectura del valor actual sin notificaciones. Singleton. |
| `IOptionsChangeToken` | Handle devuelto por `OnChange`. Llama `Unregister` para dejar de escuchar. |
| `TOptionsMonitor<T>` | Implementación; se engancha al evento `OnConfigReloaded` del contenedor. |
| `TOptionsMonitorServiceExtension` | Extensiones DI: `AddOptionsMonitor<T>`, `AddOptionsSnapshot<T>`. |

---

## Registro DI

**Prerequisito:** la sección de opciones debe estar registrada con `services.Configure<T>` antes de llamar a estos métodos.

```pascal
uses Quick.Core.Extensions.OptionsMonitor;

// Registrar sección de opciones:
services.Configure<TDatabaseOptions>('Database');

// Monitor reactivo (con notificaciones OnChange):
services.Extension<TOptionsMonitorServiceExtension>
  .AddOptionsMonitor<TDatabaseOptions>;

// Snapshot (solo lectura del valor actual):
services.Extension<TOptionsMonitorServiceExtension>
  .AddOptionsSnapshot<TFeatureFlags>;
```

---

## IOptionsMonitor — suscripción a cambios

```pascal
uses Quick.Core.Options.Monitor;

type
  TDatabaseService = class
  private
    fMonitor : IOptionsMonitor<TDatabaseOptions>;
    fToken   : IOptionsChangeToken;
    fConnStr : string;
    procedure OnOptionsChanged(aNewOpts: TDatabaseOptions);
  public
    constructor Create(aMonitor: IOptionsMonitor<TDatabaseOptions>);
    destructor Destroy; override;
  end;

constructor TDatabaseService.Create(aMonitor: IOptionsMonitor<TDatabaseOptions>);
begin
  fMonitor := aMonitor;
  // Leer valor inicial
  fConnStr := fMonitor.CurrentValue.ConnectionString;
  // Suscribirse a cambios futuros
  fToken := fMonitor.OnChange(procedure(o: TDatabaseOptions)
    begin
      fConnStr := o.ConnectionString;
      Reconnect;
    end);
end;

destructor TDatabaseService.Destroy;
begin
  // Cancelar suscripción para evitar referencias colgantes
  if Assigned(fToken) then
    fToken.Unregister;
  inherited;
end;
```

> **Importante:** guarda siempre el `IOptionsChangeToken` y llama `Unregister` en el destructor para evitar fugas de memoria.

---

## IOptionsSnapshot — lectura puntual

Adecuado para consumers de corta vida (por ejemplo, un controller MVC) que solo necesitan el valor actual, sin suscribirse a eventos.

```pascal
uses Quick.Core.Options.Monitor;

type
  TFeatureController = class(TControllerBase)
  private
    fFeatures : IOptionsSnapshot<TFeatureFlags>;
  public
    constructor Create(aFeatures: IOptionsSnapshot<TFeatureFlags>);
    function GetStatus: IActionResult;
  end;

constructor TFeatureController.Create(aFeatures: IOptionsSnapshot<TFeatureFlags>);
begin
  inherited Create;
  fFeatures := aFeatures;
end;

function TFeatureController.GetStatus: IActionResult;
begin
  if fFeatures.Value.NewCheckoutEnabled then
    Result := Ok('new-checkout')
  else
    Result := Ok('legacy-checkout');
end;
```

---

## IOptionsChangeToken — cancelar suscripción

`IOptionsChangeToken` es la interfaz devuelta por `IOptionsMonitor<T>.OnChange`. Es el equivalente al `IDisposable` de .NET.

```pascal
var token := monitor.OnChange(procedure(o: TMyOptions)
  begin
    // reacción al cambio
  end);

// Más tarde, para dejar de escuchar:
token.Unregister;
// Idempotente — se puede llamar múltiples veces sin error.
```

---

## Comparativa .NET

| Feature | ASP.NET Core (.NET) | QuickCore |
|---------|---------------------|-----------|
| Valor actual | `IOptionsMonitor<T>.CurrentValue` | `IOptionsMonitor<T>.CurrentValue` |
| Suscripción | `monitor.OnChange(Action<T>)` → `IDisposable` | `monitor.OnChange(TOptionsChangeCallback<T>)` → `IOptionsChangeToken` |
| Cancelar suscripción | `token.Dispose()` | `token.Unregister` |
| Solo lectura | `IOptionsSnapshot<T>.Value` | `IOptionsSnapshot<T>.Value` |
| Registro DI | `services.AddOptions<T>().BindConfiguration(...)` | `services.Configure<T>('Section')` + `AddOptionsMonitor<T>` |
| Trigger de recarga | `IConfiguration` reload (file watcher) | `OnConfigReloaded` del contenedor (file watcher de appsettings.json) |

---

## Ver también

- [Dependency Injection](Dependency-Injection.md) — `Configure<T>`, `IOptions<T>`
- [API Reference](../API-Reference.md)
