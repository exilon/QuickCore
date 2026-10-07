# Tutorial 5 — Health Checks

> **Estimated time:** 20 minutes  
> **Level:** Beginner-Intermediate  
> **Reference sample:** `samples/delphi/HealthChecksDashboard` (S-12)

**Health Checks** allow external infrastructure (load balancers, Kubernetes, dashboards) to know if your service is operational. In this tutorial you will expose `/health`, `/health/live`, `/health/ready`, and an HTML UI at `/healthui` with multiple status checks.

---

## What are Health Checks for?

| Scenario | Example |
|----------|---------|
| Liveness probe (Kubernetes) | The process responds → `Healthy` |
| Readiness probe | The database is accessible |
| Monitoring dashboard | Visual interface of system status |
| Load balancer | Remove node from pool if `Unhealthy` |

---

## Tutorial architecture

```
HealthChecksApi/
├── HealthChecksApi.dpr
├── Startup.pas
└── controllers/
  ├── Controller.Health.pas   ← GET /health/ping
  └── Controller.Info.pas     ← GET /api/info
```

---

## Step 1 — Controllers

### Health controller (liveness check)

Create `controllers/Controller.Health.pas`:

```pascal
unit Controller.Health;

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult;

type
  [Route('health')]
  [ApiController]
  THealthController = class(THttpController)
  published
    /// GET /health/ping — always Healthy while the process is running
    [HttpGet('ping')]
    function Ping : IActionResult;

    /// GET /health — full report of all registered checks
    [HttpGet]
    function Status : IActionResult;
  end;

implementation

uses
  System.SysUtils;

function THealthController.Ping : IActionResult;
begin
  Result := Json('{"status":"Healthy","check":"ping","timestamp":"' +
    FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + '"}');
end;

function THealthController.Status : IActionResult;
begin
  // In a real implementation, you would query IHealthCheckService here
  // to get the status of all registered checks.
  Result := Json(
    '{' +
    '  "status": "Healthy",' +
    '  "checks": [' +
    '    {"name":"self",   "status":"Healthy", "duration":"0ms"},' +
    '    {"name":"memory", "status":"Healthy", "duration":"1ms"}' +
    '  ]' +
    '}'
  );
end;

initialization
  RegisterController(THealthController);

end.
```

### Application info controller

Create `controllers/Controller.Info.pas`:

```pascal
unit Controller.Info;

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult;

type
  [Route('api')]
  [ApiController]
  TInfoController = class(THttpController)
  published
    [HttpGet('info')]
    function GetInfo : IActionResult;
  end;

implementation

uses
  System.SysUtils;

function TInfoController.GetInfo : IActionResult;
begin
  Result := Json(Format(
    '{"app":"HealthChecksApi","version":"1.0.0","uptime":"%s"}',
    [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)]));
end;

initialization
  RegisterController(TInfoController);

end.
```

---

## Step 2 — Startup with AddHealthChecks

Create `Startup.pas`:

```pascal
unit Startup;

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  System.TimeSpan,
  Quick.Core.Extensions.HealthChecks,
  Controller.Health,
  Controller.Info;

type
  TStartup = class(TStartupMvc)
  public
    class procedure ConfigureServices(services : TServiceCollection); override;
    class procedure Configure(app : TMVCServer); override;
  end;

implementation

class procedure TStartup.ConfigureServices(services : TServiceCollection);
var
  selfCheck   : IHealthCheck;
  memCheck    : IHealthCheck;
  dbCheck     : IHealthCheck;
begin
  // ── Create health checks ────────────────────────────────────────────
  // TTimeSpan.FromMinutes(5) = cache result for 5 minutes
  selfCheck := THealthCheck.Create(TTimeSpan.FromMinutes(5));
  selfCheck.Status := THealthStatus.hsPassed;

  memCheck := THealthCheck.Create(TTimeSpan.FromMinutes(1));
  memCheck.Status := THealthStatus.hsPassed;

  // Simulates a database check — in production would do a real ping
  dbCheck := THealthCheck.Create(TTimeSpan.FromMinutes(2));
  dbCheck.Status := THealthStatus.hsPassed;

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
    // ── Register checks in the container ────────────────────────────
    .Extension<THealthChecksServiceExtension>
      .AddHealthChecks
      .AddCheck(selfCheck)     // process check
      .AddCheck(memCheck)      // memory check
      .AddCheck(dbCheck);      // database check
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .AddController(THealthController)
    .AddController(TInfoController)
    .UseRouting
    .UseMVC;
end;

end.
```

---

## Step 3 — Entry point

```pascal
program HealthChecksApi;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Controller.Health in 'controllers\Controller.Health.pas',
  Controller.Info   in 'controllers\Controller.Info.pas';

var
  Server : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    cout('Starting HealthChecksApi on http://localhost:8080 ...', etInfo);
    cout('Liveness: http://localhost:8080/health/ping', ccWhite);
    cout('Status  : http://localhost:8080/health', ccWhite);
    cout('Info    : http://localhost:8080/api/info', ccWhite);
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

```bash
# Liveness probe — always responds while the process is alive
curl http://localhost:8080/health/ping
# {"status":"Healthy","check":"ping","timestamp":"2026-04-30 10:00:00"}

# Full status of all checks
curl http://localhost:8080/health
# {"status":"Healthy","checks":[{"name":"self","status":"Healthy",...},...]}

# Application info
curl http://localhost:8080/api/info
# {"app":"HealthChecksApi","version":"1.0.0","uptime":"2026-04-30 10:00:00"}
```

---

## Step 5 — Specialized checks

QuickCore includes ready-to-use checks:

### SQL Server check

```pascal
uses Quick.Core.Extensions.HealthChecks.SqlServer;

services.Extension<THealthChecksServiceExtension>
  .AddHealthChecks
  .AddSqlServer('Server=localhost;Database=mydb;User=sa;Password=pass');
```

### Redis check

```pascal
uses Quick.Core.Extensions.HealthChecks.Redis;

services.Extension<THealthChecksServiceExtension>
  .AddHealthChecks
  .AddRedis('localhost:6379');
```

### Entity (DbContext) check

```pascal
uses Quick.Core.Extensions.HealthChecks.Entity;

services.Extension<THealthChecksServiceExtension>
  .AddHealthChecks
  .AddDbContext<TMyDbContext>;
```

---

## Step 6 — Custom Health Check

Implement `IHealthCheck` to create your own logic:

```pascal
type
  TDiskSpaceCheck = class(TInterfacedObject, IHealthCheck)
  public
    function CheckHealth : THealthCheckResult;
  end;

function TDiskSpaceCheck.CheckHealth : THealthCheckResult;
var
  freeSpace : Int64;
begin
  // Get free disk space (simplified)
  freeSpace := DiskFree(0);
  if freeSpace > 1024 * 1024 * 100 then  // > 100 MB free
    Result := THealthCheckResult.Healthy('Disk OK')
  else
    Result := THealthCheckResult.Degraded('Low disk space');
end;
```

Register it:
```pascal
var
  diskCheck : IHealthCheck;
begin
  diskCheck := TDiskSpaceCheck.Create(TTimeSpan.FromMinutes(5));
  services.Extension<THealthChecksServiceExtension>
    .AddHealthChecks
    .AddCheck(diskCheck);
end;
```

---

## Kubernetes integration

Configure the probes in your `deployment.yaml`:

```yaml
livenessProbe:
  httpGet:
    path: /health/ping
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 30

readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
```

---

## Summary

| Endpoint | Purpose | .NET equivalent |
|----------|---------|----------------|
| `GET /health/live` | Liveness — the process responds | `MapHealthChecks("/health/live")` |
| `GET /health/ready` | Readiness — all checks | `MapHealthChecks("/health/ready")` |
| `GET /health` | Full Xabaril-style summary | `MapHealthChecks("/health")` |
| `GET /healthui` | HTML dashboard with polling | HealthChecks UI |
| `GET /api/info` | App metadata | Custom endpoint |

**Registration flow:**
```
ConfigureServices → AddHealthChecks → AddCheck(x) → AddInMemoryStorage
Configure         → UseHealthChecksUI → UseRouting → UseMVC
                    (the extension registers /health* and /healthui)
```

---

## See also

- [Background Services](../wiki/Background-Services.md) — checks that run in the background
- [API Reference — Health Checks](../API-Reference.md#13-health-checks)
- [FAQ — Deployment](../FAQ.md#8-deployment-and-platforms)
