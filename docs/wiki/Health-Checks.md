# Health Checks

> Modules: `Quick.Core.Extensions.HealthChecks`, `Quick.Core.Extensions.HealthChecks.SqlServer`, `Quick.Core.Extensions.HealthChecks.Redis`, `Quick.Core.Extensions.HealthChecks.Entity`, `Quick.Core.Extensions.HealthChecks.Memory`, `Quick.Core.Extensions.HealthChecks.DiskStorage`, `Quick.Core.Extensions.HealthChecks.MySQL`, `Quick.Core.Extensions.HealthChecks.RabbitMQ`  
> .NET equivalent: `Microsoft.Extensions.Diagnostics.HealthChecks`

QuickCore Health Checks monitors the health of system components (databases, Redis, external URLs) periodically and exposes a `/HealthChecks` endpoint with the status summary.

---

## Table of contents

1. [Basics](#basics)
2. [Register Health Checks (DI)](#register-health-checks-di)
3. [Available checks](#available-checks)
4. [Custom check](#custom-check)
5. [Expose HTTP endpoint](#expose-http-endpoint)
6. [Configuration options](#configuration-options)
7. [JSON response](#json-response)
8. [See also](#see-also)

---

## Basics

| Class / Interface | Role |
|-----------------|-----|
| `IHealthCheck` | Interface for an individual check |
| `THealthCheck` | Abstract base class; override `Check` |
| `IHealthChecksService` | Service that orchestrates all checks |
| `THealthStatus` | `hsNotChecked`, `hsPassed`, `hsFailed` |
| `THealthCheckMetric` | Status snapshot of a check (serializable to JSON) |

---

## Register Health Checks (DI)

```pascal
uses
  Quick.Core.Extensions.HealthChecks,
  Quick.Core.Extensions.HealthChecks.SqlServer,
  Quick.Core.Extensions.HealthChecks.Entity;

// In ConfigureServices
services.AddHealthChecks(procedure(opt: THealthCheckOptions)
begin
  opt.LogFails   := True;   // log failures
  opt.RetryTimes := 3;      // retry 3 times before marking Failed
  opt.MaxSize    := 100;    // max metric history entries
end)
// Built-in checks (fluent chaining)
.AddUrlCheck('ExternalAPI',
  'https://api.example.com/health',
  TTimeSpan.FromMinutes(1))

.AddSqlServerCheck<TShopContext>(
  'ShopDB',
  TTimeSpan.FromMinutes(5))

.AddEntityCheck<TShopContext>(
  'ShopDB-Entity',
  TTimeSpan.FromMinutes(5));
```

### C# equivalent

```csharp
builder.Services.AddHealthChecks()
    .AddUrlGroup(new Uri("https://api.example.com/health"), "ExternalAPI")
    .AddSqlServer(connectionString, name: "ShopDB");
```

---

## Available checks

| Check | Unit | What it verifies |
|-------|------|-----------------|
| `TUrlHealthCheck` | `Quick.Core.Extensions.HealthChecks` | HTTP GET to a URL → 2xx status code |
| `TSqlServerHealthCheck` | `Quick.Core.Extensions.HealthChecks.SqlServer` | Connectivity to SQL Server / any database |
| `TEntityHealthCheck` | `Quick.Core.Extensions.HealthChecks.Entity` | Connectivity via `TDBContext` |
| `TRedisHealthCheck` | `Quick.Core.Extensions.HealthChecks.Redis` | Ping to Redis server |
| `TMemoryHealthCheck` | `Quick.Core.Extensions.HealthChecks.Memory` | Process working-set ≤ `MaxUsedMB` MB |
| `TDiskStorageHealthCheck` | `Quick.Core.Extensions.HealthChecks.DiskStorage` | Free disk space ≥ `MinFreeGB` GB |
| `TMySQLHealthCheck` | `Quick.Core.Extensions.HealthChecks.MySQL` | ODBC connection to MySQL/MariaDB |
| `TRabbitMQHealthCheck` | `Quick.Core.Extensions.HealthChecks.RabbitMQ` | AMQP 0-9-1 handshake to broker |

### Add checks individually

```pascal
var hcSvc := services.Resolve<IHealthChecksService>();

// URL check — every 2 minutes
hcSvc.AddCheck(
  TUrlHealthCheck.Create('https://payment-gateway.com/ping',
                          TTimeSpan.FromMinutes(2)));

// SQL Server — every 5 minutes
hcSvc.AddCheck(
  TSqlServerHealthCheck.Create(shopContext.Database,
                                TTimeSpan.FromMinutes(5)));
```

---

## Infrastructure checks (v2.11.0)

### Memory Check

Monitors the working-set of the current process. Fails if it exceeds `MaxUsedMB`.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `MaxUsedMB` | `Int64` | `1024` | MB limit of the process working-set |

```pascal
uses Quick.Core.Extensions.HealthChecks.Memory;

services.AddHealthChecks(...)
  .Extension<TMemoryHealthChecksExtension>
    .AddMemoryCheck('ProcessMemory',
      procedure(o: TMemoryHealthCheckOptions) begin o.MaxUsedMB := 512 end,
      TTimeSpan.FromSeconds(30));
```

### DiskStorage Check

Fails if the free space on the specified path is less than `MinFreeGB`.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Path` | `string` | `'C:\'` | Drive/folder path to measure |
| `MinFreeGB` | `Double` | `1.0` | Minimum free space in gigabytes |

```pascal
uses Quick.Core.Extensions.HealthChecks.DiskStorage;

services.AddHealthChecks(...)
  .Extension<TDiskStorageHealthChecksExtension>
    .AddDiskStorageCheck('DataDisk',
      procedure(o: TDiskStorageHealthCheckOptions) begin
        o.Path      := 'D:\';
        o.MinFreeGB := 5.0;
      end,
      TTimeSpan.FromMinutes(5));
```

### MySQL Check

Connectivity to MySQL/MariaDB via ODBC. Requires a MySQL ODBC driver installed.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Host` | `string` | `'localhost'` | Server host |
| `Port` | `Integer` | `3306` | Port |
| `Database` | `string` | `''` | Database name |
| `Username` | `string` | `'root'` | Username |
| `Password` | `string` | `''` | Password |
| `Driver` | `string` | `'MySQL ODBC 8.0 ANSI Driver'` | ODBC driver name |
| `ConnectionTimeout` | `Integer` | `3` | Connection timeout (seconds) |

```pascal
uses Quick.Core.Extensions.HealthChecks.MySQL;

services.AddHealthChecks(...)
  .Extension<TMySQLHealthChecksExtension>
    .AddMySQLCheck('MySQLPrimary',
      procedure(o: TMySQLHealthCheckOptions) begin
        o.Host     := 'db.internal';
        o.Port     := 3306;
        o.Database := 'shop';
        o.Username := 'healthcheck';
        o.Password := 'secret';
      end,
      TTimeSpan.FromMinutes(1));
```

### RabbitMQ Check

Verifies broker availability by performing the AMQP 0-9-1 handshake.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Host` | `string` | `'localhost'` | Broker host |
| `Port` | `Integer` | `5672` | AMQP port |
| `ConnectionTimeout` | `Integer` | `3000` | Connection timeout (ms) |
| `ReadTimeout` | `Integer` | `3000` | Read timeout (ms) |

```pascal
uses Quick.Core.Extensions.HealthChecks.RabbitMQ;

services.AddHealthChecks(...)
  .Extension<TRabbitMQHealthChecksExtension>
    .AddRabbitMQCheck('RabbitMQ',
      procedure(o: TRabbitMQHealthCheckOptions) begin
        o.Host := 'mq.internal';
        o.Port := 5672;
      end,
      TTimeSpan.FromMinutes(1));
```

---

## Custom check

Implement your own logic by inheriting from `THealthCheck`:

```pascal
uses Quick.Core.Extensions.HealthChecks;

type
  TDiskSpaceHealthCheck = class(THealthCheck)
  private
    fMinFreeGB : Integer;
    fPath      : string;
  public
    constructor Create(const aPath: string; aMinFreeGB: Integer;
                       aTimeSpan: TTimeSpan);
    procedure Check; override;
  end;

constructor TDiskSpaceHealthCheck.Create(
  const aPath: string; aMinFreeGB: Integer; aTimeSpan: TTimeSpan);
begin
  inherited Create(aTimeSpan);
  fPath      := aPath;
  fMinFreeGB := aMinFreeGB;
  Name       := 'DiskSpace';
end;

procedure TDiskSpaceHealthCheck.Check;
var
  freeBytes : Int64;
begin
  inherited; // registers LastCheck and TimeElapsed
  GetDiskFreeSpaceEx(PChar(fPath), nil, nil, @freeBytes);
  if (freeBytes div (1024*1024*1024)) < fMinFreeGB then
    raise Exception.CreateFmt(
      'Disk space critical: only %d GB free (min: %d GB)',
      [freeBytes div (1024*1024*1024), fMinFreeGB]);
end;

// Register
hcSvc.AddCheck(TDiskSpaceHealthCheck.Create('C:\', 5, TTimeSpan.FromMinutes(10)));
```

---

## Expose HTTP endpoint

```pascal
uses Quick.Core.Mvc.Extensions.HealthChecks;

// In Configure (app: TMVCServer)
app.Extension<THealthChecksMVCServerExtension>
   .UseHealthChecks;
```

This automatically registers the `THealthChecksController` at the route:

```
GET /HealthChecks
```

---

## Configuration options

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `LogFails` | `Boolean` | `True` | Log failed checks |
| `RetryTimes` | `Integer` | `1` | Retries before marking `hsFailed` |
| `MaxSize` | `Integer` | `50` | Max entries in the in-memory history |

```pascal
services.AddHealthChecks(procedure(opt: THealthCheckOptions)
begin
  opt.LogFails   := True;
  opt.RetryTimes := 2;
  opt.MaxSize    := 200;
end);
```

---

## JSON response

The `/HealthChecks` endpoint returns an array with the status of each check:

```json
[
  {
    "Name": "ShopDB",
    "Status": 1,
    "LastCheck": "2026-04-29T10:30:00",
    "LastStatusChange": "2026-04-29T08:00:00",
    "TimeElapsed": "00:00:00.052",
    "ErrorMsg": ""
  },
  {
    "Name": "ExternalAPI",
    "Status": 2,
    "LastCheck": "2026-04-29T10:29:00",
    "LastStatusChange": "2026-04-29T10:29:00",
    "TimeElapsed": "00:00:01.234",
    "ErrorMsg": "Connection timeout"
  }
]
```

| `Status` | Value | Description |
|----------|-------|-------------|
| `hsNotChecked` | 0 | Not yet executed |
| `hsPassed` | 1 | OK |
| `hsFailed` | 2 | Error |

---

## See also

- [Dependency Injection](Dependency-Injection.md) — `AddHealthChecks`, registration
- [MVC](MVC.md) — `UseHealthChecks`, pipeline
- [Entity / ORM](Entity-ORM.md) — `AddEntityCheck`
- [Caching](Caching.md) — `AddRedisCheck`


---

## Tabla de contenidos

1. [Conceptos básicos](#conceptos-básicos)
2. [Registrar Health Checks (DI)](#registrar-health-checks-di)
3. [Checks disponibles](#checks-disponibles)
4. [Check personalizado](#check-personalizado)
5. [Exponer endpoint HTTP](#exponer-endpoint-http)
6. [Opciones de configuración](#opciones-de-configuración)
7. [Respuesta JSON](#respuesta-json)
8. [Ver también](#ver-también)

---

## Conceptos básicos

| Clase / Interfaz | Rol |
|-----------------|-----|
| `IHealthCheck` | Interfaz de un check individual |
| `THealthCheck` | Clase base abstracta; override `Check` |
| `IHealthChecksService` | Servicio que orquesta todos los checks |
| `THealthStatus` | `hsNotChecked`, `hsPassed`, `hsFailed` |
| `THealthCheckMetric` | Snapshot de estado de un check (serializable a JSON) |

---

## Registrar Health Checks (DI)

```pascal
uses
  Quick.Core.Extensions.HealthChecks,
  Quick.Core.Extensions.HealthChecks.SqlServer,
  Quick.Core.Extensions.HealthChecks.Entity;

// En ConfigureServices
services.AddHealthChecks(procedure(opt: THealthCheckOptions)
begin
  opt.LogFails   := True;   // loguear fallos
  opt.RetryTimes := 3;      // reintentar 3 veces antes de marcar Failed
  opt.MaxSize    := 100;    // historial máximo de métricas
end)
// Checks integrados (encadenado fluent)
.AddUrlCheck('ExternalAPI',
  'https://api.ejemplo.com/health',
  TTimeSpan.FromMinutes(1))

.AddSqlServerCheck<TShopContext>(
  'ShopDB',
  TTimeSpan.FromMinutes(5))

.AddEntityCheck<TShopContext>(
  'ShopDB-Entity',
  TTimeSpan.FromMinutes(5));
```

### Equivalente C#

```csharp
builder.Services.AddHealthChecks()
    .AddUrlGroup(new Uri("https://api.ejemplo.com/health"), "ExternalAPI")
    .AddSqlServer(connectionString, name: "ShopDB");
```

---

## Checks disponibles

| Check | Unidad | Qué verifica |
|-------|--------|-------------|
| `TUrlHealthCheck` | `Quick.Core.Extensions.HealthChecks` | HTTP GET a una URL → código 2xx |
| `TSqlServerHealthCheck` | `Quick.Core.Extensions.HealthChecks.SqlServer` | Conectividad a SQL Server / cualquier BD |
| `TEntityHealthCheck` | `Quick.Core.Extensions.HealthChecks.Entity` | Conectividad via `TDBContext` |
| `TRedisHealthCheck` | `Quick.Core.Extensions.HealthChecks.Redis` | Ping a servidor Redis |
| `TMemoryHealthCheck` | `Quick.Core.Extensions.HealthChecks.Memory` | Working-set del proceso ≤ `MaxUsedMB` MB |
| `TDiskStorageHealthCheck` | `Quick.Core.Extensions.HealthChecks.DiskStorage` | Espacio libre en disco ≥ `MinFreeGB` GB |
| `TMySQLHealthCheck` | `Quick.Core.Extensions.HealthChecks.MySQL` | Conexión ODBC a MySQL/MariaDB |
| `TRabbitMQHealthCheck` | `Quick.Core.Extensions.HealthChecks.RabbitMQ` | Handshake AMQP 0-9-1 al broker |

### Añadir checks individualmente

```pascal
var hcSvc := services.Resolve<IHealthChecksService>();

// URL check — cada 2 minutos
hcSvc.AddCheck(
  TUrlHealthCheck.Create('https://payment-gateway.com/ping',
                          TTimeSpan.FromMinutes(2)));

// SQL Server — cada 5 minutos
hcSvc.AddCheck(
  TSqlServerHealthCheck.Create(shopContext.Database,
                                TTimeSpan.FromMinutes(5)));
```

---

## Checks de infraestructura (v2.11.0)

### Memory Check

Monitoriza el working-set del proceso actual. Falla si supera `MaxUsedMB`.

| Propiedad | Tipo | Default | Descripción |
|-----------|------|---------|-------------|
| `MaxUsedMB` | `Int64` | `1024` | Límite en MB del working-set del proceso |

```pascal
uses Quick.Core.Extensions.HealthChecks.Memory;

services.AddHealthChecks(...)
  .Extension<TMemoryHealthChecksExtension>
    .AddMemoryCheck('ProcessMemory',
      procedure(o: TMemoryHealthCheckOptions) begin o.MaxUsedMB := 512 end,
      TTimeSpan.FromSeconds(30));
```

### DiskStorage Check

Falla si el espacio libre en la ruta indicada es inferior a `MinFreeGB`.

| Propiedad | Tipo | Default | Descripción |
|-----------|------|---------|-------------|
| `Path` | `string` | `'C:\'` | Ruta de la unidad / carpeta a medir |
| `MinFreeGB` | `Double` | `1.0` | Mínimo de espacio libre en gigabytes |

```pascal
uses Quick.Core.Extensions.HealthChecks.DiskStorage;

services.AddHealthChecks(...)
  .Extension<TDiskStorageHealthChecksExtension>
    .AddDiskStorageCheck('DataDisk',
      procedure(o: TDiskStorageHealthCheckOptions) begin
        o.Path      := 'D:\';
        o.MinFreeGB := 5.0;
      end,
      TTimeSpan.FromMinutes(5));
```

### MySQL Check

Conectividad a MySQL/MariaDB via ODBC. Requiere un driver MySQL ODBC instalado.

| Propiedad | Tipo | Default | Descripción |
|-----------|------|---------|-------------|
| `Host` | `string` | `'localhost'` | Host del servidor |
| `Port` | `Integer` | `3306` | Puerto |
| `Database` | `string` | `''` | Nombre de la base de datos |
| `Username` | `string` | `'root'` | Usuario |
| `Password` | `string` | `''` | Contraseña |
| `Driver` | `string` | `'MySQL ODBC 8.0 ANSI Driver'` | Nombre del driver ODBC |
| `ConnectionTimeout` | `Integer` | `3` | Timeout de conexión (segundos) |

```pascal
uses Quick.Core.Extensions.HealthChecks.MySQL;

services.AddHealthChecks(...)
  .Extension<TMySQLHealthChecksExtension>
    .AddMySQLCheck('MySQLPrimary',
      procedure(o: TMySQLHealthCheckOptions) begin
        o.Host     := 'db.internal';
        o.Port     := 3306;
        o.Database := 'shop';
        o.Username := 'healthcheck';
        o.Password := 'secret';
      end,
      TTimeSpan.FromMinutes(1));
```

### RabbitMQ Check

Verifica la disponibilidad del broker realizando el handshake AMQP 0-9-1.

| Propiedad | Tipo | Default | Descripción |
|-----------|------|---------|-------------|
| `Host` | `string` | `'localhost'` | Host del broker |
| `Port` | `Integer` | `5672` | Puerto AMQP |
| `ConnectionTimeout` | `Integer` | `3000` | Timeout de conexión (ms) |
| `ReadTimeout` | `Integer` | `3000` | Timeout de lectura (ms) |

```pascal
uses Quick.Core.Extensions.HealthChecks.RabbitMQ;

services.AddHealthChecks(...)
  .Extension<TRabbitMQHealthChecksExtension>
    .AddRabbitMQCheck('RabbitMQ',
      procedure(o: TRabbitMQHealthCheckOptions) begin
        o.Host := 'mq.internal';
        o.Port := 5672;
      end,
      TTimeSpan.FromMinutes(1));
```

---

## Check personalizado

Implementa tu propia lógica heredando de `THealthCheck`:

```pascal
uses Quick.Core.Extensions.HealthChecks;

type
  TDiskSpaceHealthCheck = class(THealthCheck)
  private
    fMinFreeGB : Integer;
    fPath      : string;
  public
    constructor Create(const aPath: string; aMinFreeGB: Integer;
                       aTimeSpan: TTimeSpan);
    procedure Check; override;
  end;

constructor TDiskSpaceHealthCheck.Create(
  const aPath: string; aMinFreeGB: Integer; aTimeSpan: TTimeSpan);
begin
  inherited Create(aTimeSpan);
  fPath      := aPath;
  fMinFreeGB := aMinFreeGB;
  Name       := 'DiskSpace';
end;

procedure TDiskSpaceHealthCheck.Check;
var
  freeBytes : Int64;
begin
  inherited; // registra LastCheck y TimeElapsed
  GetDiskFreeSpaceEx(PChar(fPath), nil, nil, @freeBytes);
  if (freeBytes div (1024*1024*1024)) < fMinFreeGB then
    raise Exception.CreateFmt(
      'Disk space critical: only %d GB free (min: %d GB)',
      [freeBytes div (1024*1024*1024), fMinFreeGB]);
end;

// Registrar
hcSvc.AddCheck(TDiskSpaceHealthCheck.Create('C:\', 5, TTimeSpan.FromMinutes(10)));
```

---

## Exponer endpoint HTTP

```pascal
uses Quick.Core.Mvc.Extensions.HealthChecks;

// En Configure (app: TMVCServer)
app.Extension<THealthChecksMVCServerExtension>
   .UseHealthChecks;
```

Esto registra automáticamente el controller `THealthChecksController` en la ruta:

```
GET /HealthChecks
```

---

## Opciones de configuración

| Propiedad | Tipo | Por defecto | Descripción |
|-----------|------|-------------|-------------|
| `LogFails` | `Boolean` | `True` | Loguea los checks fallidos |
| `RetryTimes` | `Integer` | `1` | Reintentos antes de marcar `hsFailed` |
| `MaxSize` | `Integer` | `50` | Máximo de entradas en el historial en memoria |

```pascal
services.AddHealthChecks(procedure(opt: THealthCheckOptions)
begin
  opt.LogFails   := True;
  opt.RetryTimes := 2;
  opt.MaxSize    := 200;
end);
```

---

## Respuesta JSON

El endpoint `/HealthChecks` devuelve un array con el estado de cada check:

```json
[
  {
    "Name": "ShopDB",
    "Status": 1,
    "LastCheck": "2026-04-29T10:30:00",
    "LastStatusChange": "2026-04-29T08:00:00",
    "TimeElapsed": "00:00:00.052",
    "ErrorMsg": ""
  },
  {
    "Name": "ExternalAPI",
    "Status": 2,
    "LastCheck": "2026-04-29T10:29:00",
    "LastStatusChange": "2026-04-29T10:29:00",
    "TimeElapsed": "00:00:01.234",
    "ErrorMsg": "Connection timeout"
  }
]
```

| `Status` | Valor | Descripción |
|----------|-------|-------------|
| `hsNotChecked` | 0 | Aún no se ha ejecutado |
| `hsPassed` | 1 | OK |
| `hsFailed` | 2 | Error |

---

## Ver también

- [Dependency Injection](Dependency-Injection.md) — `AddHealthChecks`, registro
- [MVC](MVC.md) — `UseHealthChecks`, pipeline
- [Entity / ORM](Entity-ORM.md) — `AddEntityCheck`
- [Caching](Caching.md) — `AddRedisCheck`
