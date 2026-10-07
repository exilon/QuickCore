# Tutorial 7 — Custom Middleware Pipeline

> **Estimated time:** 25 minutes  
> **Level:** Intermediate  
> **Reference sample:** `samples/delphi/CustomMiddleware` (S-11)

The **middleware pipeline** is the heart of QuickCore: every HTTP request travels through a chain of components, each with the ability to inspect, modify, or short-circuit the flow. In this tutorial you will build three custom middlewares from scratch and understand exactly how the pipeline works.

---

## What is a middleware?

```
Request  →  [Middleware A]  →  [Middleware B]  →  [MVC / Controller]
            ↓               ↓                ↓
Response ←  [Middleware A] ←  [Middleware B] ←  [MVC / Controller]
```

Each middleware:
1. Receives the HTTP context.
2. Does its work **before** calling `Next(aContext)`.
3. Calls `Next(aContext)` → passes control to the next middleware.
4. Does its work **after** (a response already exists).

If a middleware **does not call `Next`**, it short-circuits the pipeline (useful for auth, rate limiting, etc.).

---

## Tutorial architecture

```
CustomMiddleware/
├── CustomMiddleware.dpr
├── Startup.pas
├── controllers/
│   └── Controller.Ping.pas
└── middleware/
  ├── Middleware.Timing.pas     ← measures request duration
  ├── Middleware.RequestId.pas  ← adds unique ID to each request
  └── Middleware.Logging.pas    ← logs METHOD path → status
```

---

## Step 1 — The test controller

Create `controllers/Controller.Ping.pas`:

```pascal
unit Controller.Ping;

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult;

type
  [Route('api')]
  [ApiController]
  TPingController = class(THttpController)
  published
    [HttpGet('ping')]
    function Ping : IActionResult;
  end;

implementation

uses System.SysUtils;

function TPingController.Ping: IActionResult;
begin
  Result := Json(Format('{"pong":true,"time":"%s"}',
    [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)]));
end;

initialization
  RegisterController(TPingController);

end.
```

---

## Step 2 — Timing measurement middleware

Create `middleware/Middleware.Timing.pas`.

The class inherits from `TRequestDelegate`. The key method is `Invoke`:

```pascal
unit Middleware.Timing;

interface

uses
  Quick.Core.Mvc.Middleware,
  Quick.Core.Mvc.Context;

type
  TTimingMiddleware = class(TRequestDelegate)
  public
    procedure Invoke(aContext : THttpContextBase); override;
  end;

implementation

uses
  System.SysUtils,
  System.Diagnostics;

procedure TTimingMiddleware.Invoke(aContext : THttpContextBase);
var
  sw : TStopwatch;
begin
  sw := TStopwatch.StartNew;

  Next(aContext);           // ← the rest of the pipeline runs here

  sw.Stop;
  // Add the timing header to the already-generated response
  aContext.Response.Headers.Add(
    'X-Response-Time',
    Format('%d ms', [sw.ElapsedMilliseconds]));
end;

end.
```

**Before/after pattern:** Everything before `Next` happens on the way in (request). Everything after happens on the way out (response already written).

---

## Step 3 — Request ID middleware

Create `middleware/Middleware.RequestId.pas`:

```pascal
unit Middleware.RequestId;

interface

uses
  Quick.Core.Mvc.Middleware,
  Quick.Core.Mvc.Context;

type
  TRequestIdMiddleware = class(TRequestDelegate)
  public
    procedure Invoke(aContext : THttpContextBase); override;
  end;

implementation

uses System.SysUtils;

procedure TRequestIdMiddleware.Invoke(aContext : THttpContextBase);
var
  reqId : string;
begin
  // Generate a unique ID per request
  reqId := GUIDToString(TGuid.NewGuid);

  // Propagate it in the request (available to other middlewares and controllers)
  aContext.Request.Headers.Add('X-Request-ID', reqId);

  Next(aContext);

  // Also send it back to the client in the response
  aContext.Response.Headers.Add('X-Request-ID', reqId);
end;

end.
```

---

## Step 4 — Structured logging middleware

Create `middleware/Middleware.Logging.pas`:

```pascal
unit Middleware.Logging;

interface

uses
  Quick.Core.Mvc.Middleware,
  Quick.Core.Mvc.Context,
  Quick.HttpServer.Types;

type
  TLoggingMiddleware = class(TRequestDelegate)
  public
    procedure Invoke(aContext : THttpContextBase); override;
  end;

implementation

uses System.SysUtils;

procedure TLoggingMiddleware.Invoke(aContext : THttpContextBase);
begin
  Next(aContext);   // let the pipeline generate the response

  // Log once we have the status code
  WriteLn(Format('[%s] %s → %d',
    [MethodVerbStr[Ord(aContext.Request.Method)],
     aContext.Request.URL,
     aContext.Response.StatusCode]));
end;

end.
```

---

## Step 5 — Assemble the pipeline in Startup

The **registration order** determines the execution order:

```pascal
unit Startup;

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Controller.Ping,
  Middleware.Timing,
  Middleware.RequestId,
  Middleware.Logging;

type
  TStartup = class(TStartupMvc)
  public
    class procedure ConfigureServices(services : TServiceCollection); override;
    class procedure Configure(app : TMVCServer); override;
  end;

implementation

class procedure TStartup.ConfigureServices(services : TServiceCollection);
begin
  services.AddLogging(TLoggerBuilder.GetBuilder
    .AddConsole(procedure(o : TConsoleLoggerOptions)
      begin
        o.LogLevel        := LOG_DEBUG;
        o.ShowEventColors := True;
        o.ShowTimeStamp   := True;
        o.Enabled         := True;
      end)
    .Build);
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .AddController(TPingController)
    // Execution order: Timing → RequestId → Logging → [MVC]
    .UseMiddleware(TTimingMiddleware)
    .UseMiddleware(TRequestIdMiddleware)
    .UseMiddleware(TLoggingMiddleware)
    .UseRouting
    .UseMVC;
end;

end.
```

### Execution diagram

```
Request
  │
  ▼
TTimingMiddleware.Invoke  ← starts stopwatch
  │ Next →
  ▼
TRequestIdMiddleware.Invoke  ← generates X-Request-ID on request
  │ Next →
  ▼
TLoggingMiddleware.Invoke
  │ Next →
  ▼
[UseRouting + UseMVC]  ← controller runs, generates response
  │ ← return
  ▼
TLoggingMiddleware  ← logs "GET /api/ping → 200"
  │ ← return
  ▼
TRequestIdMiddleware  ← adds X-Request-ID to response
  │ ← return
  ▼
TTimingMiddleware  ← adds X-Response-Time to response
  │
  ▼
Response sent to client
```

---

## Step 6 — Entry point

```pascal
program CustomMiddleware;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Controller.Ping     in 'controllers\Controller.Ping.pas',
  Middleware.Timing   in 'middleware\Middleware.Timing.pas',
  Middleware.RequestId in 'middleware\Middleware.RequestId.pas',
  Middleware.Logging  in 'middleware\Middleware.Logging.pas';

var
  Server : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    cout('Starting CustomMiddleware on http://localhost:8080 ...', etInfo);
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

## Step 7 — Test

```bash
curl -i http://localhost:8080/api/ping
```

Response:
```
HTTP/1.1 200 OK
X-Request-ID: {A1B2C3D4-...}
X-Response-Time: 2 ms
Content-Type: application/json

{"pong":true,"time":"2026-04-30 10:00:00"}
```

Server console:
```
[GET] /api/ping → 200
```

---

## Step 8 — Short-circuiting middleware

A middleware can **skip calling `Next`** to stop the pipeline. Example: block requests during maintenance mode:

```pascal
type
  TMaintenanceModeMiddleware = class(TRequestDelegate)
  public
    procedure Invoke(aContext : THttpContextBase); override;
  end;

procedure TMaintenanceModeMiddleware.Invoke(aContext : THttpContextBase);
begin
  // If maintenance mode is active, return 503 without continuing
  if GetEnvironmentVariable('MAINTENANCE_MODE') = '1' then
  begin
    aContext.Response.StatusCode := 503;
    aContext.Response.Body := '{"error":"Service under maintenance"}';
    // Next is not called → the pipeline stops here
    Exit;
  end;

  Next(aContext);  // normal operation
end;
```

---

## Reference: QuickCore built-in middlewares

| Method in `Configure` | Middleware | Function |
|----------------------|-----------|----------|
| `UseAuthentication` | `TAuthenticationMiddleware` | Validates credentials, creates ClaimsPrincipal |
| `UseAuthorization` | `TAuthorizationMiddleware` | Checks `[Authorize]` |
| `UseExceptionHandler` | `TExceptionHandlerMiddleware` | Catches exceptions → 500 JSON |
| `UseRateLimiting` | `TRateLimitMiddleware` | Request limit per time window |
| `UseResponseCaching` | `TResponseCacheMiddleware` | Response caching |
| `UseCompression` | `TCompressionMiddleware` | Automatic Gzip/Deflate |
| `UseStaticFiles` | `TStaticFilesMiddleware` | Serves static files |
| `UseSession` | `TSessionMiddleware` | Server-side sessions |
| `UseRouting` | `TRoutingMiddleware` | Maps URL → controller/action |
| `UseMVC` | `TMvcMiddleware` | Executes the controller |

---

## See also

- [Tutorial 4 — Auth with JWT](Auth-with-JWT.md) — `UseAuthentication` in detail
- [Tutorial 5 — Health Checks](Health-Checks.md) — pipeline usage in production
- [API Reference — MVC](../API-Reference.md#3-mvc--http-server)
- [Wiki — MVC](../wiki/MVC.md)
