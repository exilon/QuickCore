# Tutorial 1 — Hello World API

> **Estimated time:** 15 minutes  
> **Level:** Beginner  
> **Reference sample:** `samples/delphi/HelloWorldApi` (S-01)

In this tutorial you will build your first REST API with QuickCore from scratch: a console project that responds to HTTP requests with a controller and a minimal endpoint.

---

## Prerequisites

- Delphi 10.x or higher (Delphi 12 Athens recommended)
- [QuickLib](https://github.com/exilon/QuickLib) installed
- [QuickCore](https://github.com/exilon/QuickCore) installed
- [QuickLogger](https://github.com/exilon/QuickLogger) installed

All can be installed via **Delphinus** or manually by adding the paths in the *Library Path*.

---

## Step 1 — Create the project

1. In Delphi, **File → New → Console Application**.
2. Save the project as `HelloWorldApi.dpr` in a new folder, e.g. `HelloWorldApi/`.
3. Create the subfolders:
   ```
   HelloWorldApi/
   ├── HelloWorldApi.dpr
   ├── Startup.pas          ← you will create in step 3
   └── controllers/
       └── Controller.Hello.pas   ← you will create in step 2
   ```

---

## Step 2 — Define the controller

Create `controllers/Controller.Hello.pas`:

```pascal
unit Controller.Hello;

interface

uses
  System.SysUtils,
  Quick.HttpServer.Types,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult;

type
  [Route('hello')]
  [ApiController]
  THelloController = class(THttpController)
  published
    /// GET /hello  ->  {"Message":"Hello, World!","Timestamp":"..."}
    [HttpGet]
    function Index: IActionResult;

    /// GET /hello/greet/{name}  ->  "Hello, {name}!"
    [HttpGet('greet/{name}')]
    function Greet(name: string): IActionResult;
  end;

implementation

function THelloController.Index: IActionResult;
begin
  Result := Json(Format(
    '{"Message":"Hello, World!","Timestamp":"%s"}',
    [DateTimeToStr(Now)]));
end;

function THelloController.Greet(name: string): IActionResult;
begin
  Result := Ok(Format('Hello, %s!', [name]));
end;

initialization
  RegisterController(THelloController);

end.
```

**Key points:**
- `[Route('hello')]` — controller route prefix.
- `[HttpGet]` without argument → `GET /hello`.
- `[HttpGet('greet/{name}')]` → `GET /hello/greet/Ana`; the `{name}` parameter is injected automatically.
- `RegisterController` registers the controller in the global array used by `AddControllers`.

---

## Step 3 — Configure the pipeline (Startup)

Create `Startup.pas`:

```pascal
unit Startup;

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Controller.Hello;

type
  TStartup = class(TStartupMvc)
  public
    class procedure ConfigureServices(services: TServiceCollection); override;
    class procedure Configure(app: TMVCServer); override;
  end;

implementation

class procedure TStartup.ConfigureServices(services: TServiceCollection);
begin
  services
    .AddLogging(TLoggerBuilder.GetBuilder
      .AddConsole(procedure(o: TConsoleLoggerOptions)
        begin
          o.LogLevel        := LOG_DEBUG;
          o.ShowEventColors := True;
          o.ShowTimeStamp   := True;
          o.ShowEventType   := False;
          o.Enabled         := True;
        end)
      .Build);
end;

class procedure TStartup.Configure(app: TMVCServer);
begin
  app
    .AddControllers          // register all controllers via RegisterController
    .AddController(THelloController)  // or explicitly: just this controller
    .UseRouting              // enable attribute-based routing
    .UseMVC;                 // execute controllers
end;

end.
```

**`ConfigureServices`** — registers services in the DI container (here only the logger).  
**`Configure`** — builds the middleware pipeline left to right.

---

## Step 4 — Entry point (`.dpr`)

Edit `HelloWorldApi.dpr`:

```pascal
program HelloWorldApi;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Controller.Hello in 'controllers\Controller.Hello.pas';

var
  Server: TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    cout('Starting Hello World API on http://localhost:8080 ...', etInfo);
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

## Step 5 — Build and run

1. Press **F9** (Run).
2. You will see in the console:
   ```
   [INFO] Starting Hello World API on http://localhost:8080 ...
   [INFO] Press [Enter] to stop.
   ```

---

## Step 6 — Test the endpoints

Open a terminal and test with `curl` or any HTTP client:

```bash
# GET /hello  →  JSON with message and timestamp
curl http://localhost:8080/hello

# Response:
# {"Message":"Hello, World!","Timestamp":"29/04/2026 10:30:00"}

# GET /hello/greet/Ana  →  personalized greeting
curl http://localhost:8080/hello/greet/Ana

# Response:
# Hello, Ana!
```

---

## Step 7 (optional) — Add a Minimal API endpoint

Without creating a controller, you can add inline endpoints in `Startup.Configure`:

```pascal
class procedure TStartup.Configure(app: TMVCServer);
begin
  app
    .AddControllers
    .UseRouting
    // Minimal endpoint: GET /ping
    .MapGet('/ping', function(ctx: THttpContextBase): string
      begin
        Result := '"pong"';
      end)
    .UseMVC;
end;
```

```bash
curl http://localhost:8080/ping
# "pong"
```

---

## Summary

You have built a minimal REST API with QuickCore that:

| Endpoint | Method | Response |
|----------|--------|----------|
| `/hello` | GET | JSON with message and timestamp |
| `/hello/greet/{name}` | GET | Personalized greeting |
| `/ping` | GET | `"pong"` (Minimal API) |

**Next step:** [Tutorial 2 — CRUD with Entity](CRUD-with-Entity.md) — add a SQLite database.

---

## See also

- [MVC](../wiki/MVC.md)
- [Dependency Injection](../wiki/Dependency-Injection.md)
- [API Reference](../API-Reference.md)


---

## Requisitos previos

- Delphi 10.x o superior (recomendado Delphi 12 Athens)
- [QuickLib](https://github.com/exilon/QuickLib) instalado
- [QuickCore](https://github.com/exilon/QuickCore) instalado
- [QuickLogger](https://github.com/exilon/QuickLogger) instalado

Todos se pueden instalar via **Delphinus** o manualmente añadiendo las rutas en *Library Path*.

---

## Paso 1 — Crear el proyecto

1. En Delphi, **File → New → Console Application**.
2. Guarda el proyecto como `HelloWorldApi.dpr` en una carpeta nueva, p. ej. `HelloWorldApi/`.
3. Crea las subcarpetas:
   ```
   HelloWorldApi/
   ├── HelloWorldApi.dpr
   ├── Startup.pas          ← crearás en el paso 3
   └── controllers/
       └── Controller.Hello.pas   ← crearás en el paso 2
   ```

---

## Paso 2 — Definir el controller

Crea `controllers/Controller.Hello.pas`:

```pascal
unit Controller.Hello;

interface

uses
  System.SysUtils,
  Quick.HttpServer.Types,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult;

type
  [Route('hello')]
  [ApiController]
  THelloController = class(THttpController)
  published
    /// GET /hello  ->  {"Message":"Hello, World!","Timestamp":"..."}
    [HttpGet]
    function Index: IActionResult;

    /// GET /hello/greet/{name}  ->  "Hello, {name}!"
    [HttpGet('greet/{name}')]
    function Greet(name: string): IActionResult;
  end;

implementation

function THelloController.Index: IActionResult;
begin
  Result := Json(Format(
    '{"Message":"Hello, World!","Timestamp":"%s"}',
    [DateTimeToStr(Now)]));
end;

function THelloController.Greet(name: string): IActionResult;
begin
  Result := Ok(Format('Hello, %s!', [name]));
end;

initialization
  RegisterController(THelloController);

end.
```

**Puntos clave:**
- `[Route('hello')]` — prefijo de ruta del controller.
- `[HttpGet]` sin argumento → `GET /hello`.
- `[HttpGet('greet/{name}')]` → `GET /hello/greet/Ana`; el parámetro `{name}` se inyecta automáticamente.
- `RegisterController` registra el controller en el array global que usa `AddControllers`.

---

## Paso 3 — Configurar el pipeline (Startup)

Crea `Startup.pas`:

```pascal
unit Startup;

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Controller.Hello;

type
  TStartup = class(TStartupMvc)
  public
    class procedure ConfigureServices(services: TServiceCollection); override;
    class procedure Configure(app: TMVCServer); override;
  end;

implementation

class procedure TStartup.ConfigureServices(services: TServiceCollection);
begin
  services
    .AddLogging(TLoggerBuilder.GetBuilder
      .AddConsole(procedure(o: TConsoleLoggerOptions)
        begin
          o.LogLevel        := LOG_DEBUG;
          o.ShowEventColors := True;
          o.ShowTimeStamp   := True;
          o.ShowEventType   := False;
          o.Enabled         := True;
        end)
      .Build);
end;

class procedure TStartup.Configure(app: TMVCServer);
begin
  app
    .AddControllers          // registra todos los controllers con RegisterController
    .AddController(THelloController)  // o explícito: solo este controller
    .UseRouting              // habilita el enrutamiento por atributos
    .UseMVC;                 // ejecuta los controllers
end;

end.
```

**`ConfigureServices`** — registra servicios en el contenedor DI (aquí solo el logger).  
**`Configure`** — construye el pipeline de middleware de izquierda a derecha.

---

## Paso 4 — Punto de entrada (`.dpr`)

Edita `HelloWorldApi.dpr`:

```pascal
program HelloWorldApi;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Controller.Hello in 'controllers\Controller.Hello.pas';

var
  Server: TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    cout('Starting Hello World API on http://localhost:8080 ...', etInfo);
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

## Paso 5 — Compilar y ejecutar

1. Pulsa **F9** (Run).
2. Verás en la consola:
   ```
   [INFO] Starting Hello World API on http://localhost:8080 ...
   [INFO] Press [Enter] to stop.
   ```

---

## Paso 6 — Probar los endpoints

Abre un terminal y prueba con `curl` o cualquier cliente HTTP:

```bash
# GET /hello  →  JSON con mensaje y timestamp
curl http://localhost:8080/hello

# Respuesta:
# {"Message":"Hello, World!","Timestamp":"29/04/2026 10:30:00"}

# GET /hello/greet/Ana  →  saludo personalizado
curl http://localhost:8080/hello/greet/Ana

# Respuesta:
# Hello, Ana!
```

---

## Paso 7 (opcional) — Añadir un Minimal API endpoint

Sin necesidad de crear un controller, puedes añadir endpoints inline en `Startup.Configure`:

```pascal
class procedure TStartup.Configure(app: TMVCServer);
begin
  app
    .AddControllers
    .UseRouting
    // Minimal endpoint: GET /ping
    .MapGet('/ping', function(ctx: THttpContextBase): string
      begin
        Result := '"pong"';
      end)
    .UseMVC;
end;
```

```bash
curl http://localhost:8080/ping
# "pong"
```

---

## Resumen

Has creado una API REST mínima con QuickCore que:

| Endpoint | Método | Respuesta |
|----------|--------|-----------|
| `/hello` | GET | JSON con mensaje y timestamp |
| `/hello/greet/{name}` | GET | Saludo personalizado |
| `/ping` | GET | `"pong"` (Minimal API) |

**Siguiente paso:** [Tutorial 2 — CRUD con Entity](CRUD-with-Entity.md) — añadir una base de datos SQLite.

---

## Ver también

- [MVC](../wiki/MVC.md)
- [Dependency Injection](../wiki/Dependency-Injection.md)
- [API Reference](../API-Reference.md)
