# Tutorial 3 — Authentication with API Key

> **Estimated time:** 20 minutes  
> **Level:** Intermediate  
> **Reference sample:** `samples/delphi/WebApiWithApiKeyAuth` (S-13)

In this tutorial you will protect a REST API with API Key authentication. You will learn to:
- Register valid keys (in memory)
- Configure the authentication and authorization middleware
- Use `[Authorize]`, `[AllowAnonymous]`, and role-based policies
- Pass the key from the client

---

## Prerequisites

- Tutorial 1 completed (basic pipeline with `TStartup`)
- Optional: Tutorial 2 for a controller with real data

---

## Tutorial architecture

```
WebApiWithApiKeyAuth/
├── WebApiWithApiKeyAuth.dpr
├── Startup.pas             ← configures ApiKey + Authorization
└── controllers/
    └── Controller.Products.pas
```

---

## How API Key authentication works

1. The client sends the key in the `X-API-Key: <key>` HTTP header.
2. The `UseAuthentication` middleware extracts the key and validates it against the store.
3. If valid, it creates a `ClaimsPrincipal` with the user's name and role.
4. The `UseAuthorization` middleware checks the `[Authorize]` attributes on the controller/action.

---

## Step 1 — Configure `Startup.pas`

```pascal
unit Startup;

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Quick.Core.Extensions.Authentication,
  Quick.Core.Extensions.Authentication.ApiKey,
  Quick.Core.Extensions.Authorization,
  Quick.Core.Security.Authorization,
  Controller.Products;

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
      .Build)

    // ── Step 1: authentication infrastructure ──────────────────────
    .Extension<TAuthenticationServiceExtension>
      .AddAuthentication(procedure(o: TAuthenticationOptions)
        begin
          // The default scheme is set automatically by AddApiKey
        end);

  // ── Step 2: register API Keys ────────────────────────────────
  // Format: AddApiKey(UserName, Role, SecretKey)
  services.Extension<TApiKeyAuthenticationServiceExtension>
    .AddApiKey
      .UseMemoryStore(procedure(o: TApiKeyMemoryStoreOptions)
        begin
          o.AddApiKey('Alice', 'Admin', 'admin-key-abc123');
          o.AddApiKey('Bob',   'User',  'user-key-xyz789');
        end);

  // ── Step 3: authorization policies ────────────────────────────
  services.Extension<TAuthorizationServiceExtension>
    .AddAuthorization(procedure(o: TAuthorizationOptions)
      begin
        // Any authenticated user
        o.AddPolicy('Authenticated',
          TAuthorizationPolicyBuilder.GetBuilder
            .RequireAuthenticatedUser
            .Build);

        // Administrators only
        o.AddPolicy('AdminOnly',
          TAuthorizationPolicyBuilder.GetBuilder
            .RequireAuthenticatedUser
            .RequireClaim('role', 'Admin')
            .Build);
      end);
end;

class procedure TStartup.Configure(app: TMVCServer);
begin
  app
    .AddControllers
    .AddController(TProductsController)
    .UseRouting
    .UseAuthentication    // extracts and identifies the API Key
    .UseAuthorization     // checks [Authorize] attributes
    .UseMVC;
end;

end.
```

> **Important:** `UseAuthentication` must come **before** `UseAuthorization` in the pipeline.

---

## Step 2 — Controller with mixed authentication

Create `controllers/Controller.Products.pas`:

```pascal
unit Controller.Products;

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Security.Claims;

type
  [Route('api/products')]
  [ApiController]
  [Authorize]   // All actions require authentication by default
  TProductsController = class(THttpController)
  public
    constructor Create;
  published
    // Any authenticated user (Admin or User)
    [HttpGet]
    function GetAll: IActionResult;

    // Administrators only
    [HttpGet('admin')]
    [AuthorizePolicy('AdminOnly')]
    function AdminPanel: IActionResult;

    // No authentication required
    [HttpGet('public')]
    [AllowAnonymous]
    function PublicCatalog: IActionResult;

    // Returns the authenticated user's name
    [HttpGet('me')]
    function WhoAmI: IActionResult;
  end;

implementation

uses System.SysUtils;

constructor TProductsController.Create;
begin
  inherited Create;
end;

function TProductsController.GetAll: IActionResult;
begin
  Result := Json('[{"id":1,"name":"Laptop"},{"id":2,"name":"Keyboard"}]');
end;

function TProductsController.AdminPanel: IActionResult;
begin
  Result := Json('{"panel":"Admin Dashboard","secret":"42"}');
end;

function TProductsController.PublicCatalog: IActionResult;
begin
  Result := Json('[{"id":1,"name":"Laptop","publicPrice":999}]');
end;

function TProductsController.WhoAmI: IActionResult;
var
  userName: string;
begin
  userName := HttpContext.User.Identity.Name;
  if userName.IsEmpty then userName := 'anonymous';
  Result := Json(Format('{"user":"%s"}', [userName]));
end;

initialization
  RegisterController(TProductsController);

end.
```

**Available authorization attributes:**

| Attribute | Description |
|-----------|-------------|
| `[Authorize]` | Requires any authenticated user |
| `[AuthorizePolicy('PolicyName')]` | Requires the named policy to be satisfied |
| `[AllowAnonymous]` | Overrides `[Authorize]` for that specific action |

---

## Step 3 — Entry point

```pascal
program WebApiWithApiKeyAuth;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Controller.Products in 'controllers\Controller.Products.pas';

var
  Server: TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    cout('Starting WebApiWithApiKeyAuth on http://localhost:8080 ...', etInfo);
    cout('Admin key : admin-key-abc123', ccWhite);
    cout('User key  : user-key-xyz789', ccWhite);
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

## Step 4 — Test the endpoints

### Without key → 401 Unauthorized

```bash
curl -i http://localhost:8080/api/products
# HTTP/1.1 401 Unauthorized
```

### With user key → 200 OK

```bash
curl -H "X-API-Key: user-key-xyz789" \
     http://localhost:8080/api/products
# [{"id":1,"name":"Laptop"},{"id":2,"name":"Keyboard"}]
```

### With user key on Admin route → 403 Forbidden

```bash
curl -i -H "X-API-Key: user-key-xyz789" \
     http://localhost:8080/api/products/admin
# HTTP/1.1 403 Forbidden
```

### With Admin key → 200 OK

```bash
curl -H "X-API-Key: admin-key-abc123" \
     http://localhost:8080/api/products/admin
# {"panel":"Admin Dashboard","secret":"42"}
```

### Public route without key → 200 OK

```bash
curl http://localhost:8080/api/products/public
# [{"id":1,"name":"Laptop","publicPrice":999}]
```

### Who are you

```bash
curl -H "X-API-Key: admin-key-abc123" \
     http://localhost:8080/api/products/me
# {"user":"Alice"}
```

---

## Step 5 (optional) — Key store in database

For production environments, keys should not be hard-coded. Use the database store:

```pascal
// In ConfigureServices, instead of UseMemoryStore:
services.Extension<TApiKeyAuthenticationServiceExtension>
  .AddApiKey
    .UseDatabaseStore<TApiKeyEntity>(procedure(o: TApiKeyDatabaseStoreOptions)
      begin
        // Keys are loaded from the api_keys table in the DbContext
      end);
```

See sample `samples/delphi/ApiKeyDatabaseStore` for the full example.

---

## Summary

You have configured API Key authentication with three access levels:

| Endpoint | Authentication | Required role |
|----------|----------------|--------------|
| `GET /api/products` | Yes | Any |
| `GET /api/products/admin` | Yes | Admin |
| `GET /api/products/public` | No | — |
| `GET /api/products/me` | Yes | Any |

**Protection flow:**
```
Request
  └─► UseAuthentication ─► validates X-API-Key ─► creates ClaimsPrincipal
        └─► UseAuthorization ─► [Authorize] / [AuthorizePolicy] ─► 200 / 401 / 403
```

---

## Next level

- [Tutorial — JWT Authentication](../wiki/Security.md) — stateless JWT tokens
- [Migration Guide](../Migration-Guide.md) — if you are coming from an older version
- [FAQ — Auth](../FAQ.md#5-authentication-and-authorization) — frequently asked questions

---

## See also

- [Security](../wiki/Security.md)
- [Dependency Injection](../wiki/Dependency-Injection.md)
- [API Reference — Security](../API-Reference.md#8-security--authentication)

- Registrar claves válidas (en memoria)
- Configurar el middleware de autenticación y autorización
- Usar `[Authorize]`, `[AllowAnonymous]` y políticas por rol
- Pasar la clave desde el cliente

---

## Requisitos previos

- Tutorial 1 completado (pipeline básico con `TStartup`)
- Opcional: Tutorial 2 para tener un controller con datos reales

---

## Arquitectura del tutorial

```
WebApiWithApiKeyAuth/
├── WebApiWithApiKeyAuth.dpr
├── Startup.pas             ← configura ApiKey + Authorization
└── controllers/
    └── Controller.Products.pas
```

---

## Cómo funciona la autenticación por API Key

1. El cliente envía la clave en la cabecera HTTP `X-API-Key: <key>`.
2. El middleware `UseAuthentication` extrae la clave y la valida contra el store.
3. Si es válida, crea un `ClaimsPrincipal` con el nombre y rol del usuario.
4. El middleware `UseAuthorization` comprueba los atributos `[Authorize]` del controller/acción.

---

## Paso 1 — Configurar `Startup.pas`

```pascal
unit Startup;

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Quick.Core.Extensions.Authentication,
  Quick.Core.Extensions.Authentication.ApiKey,
  Quick.Core.Extensions.Authorization,
  Quick.Core.Security.Authorization,
  Controller.Products;

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
      .Build)

    // ── Paso 1: infraestructura de autenticación ──────────────────────
    .Extension<TAuthenticationServiceExtension>
      .AddAuthentication(procedure(o: TAuthenticationOptions)
        begin
          // El esquema por defecto lo establece AddApiKey automáticamente
        end);

  // ── Paso 2: registrar las API Keys ────────────────────────────────
  // Formato: AddApiKey(NombreUsuario, Rol, ClaveSecreta)
  services.Extension<TApiKeyAuthenticationServiceExtension>
    .AddApiKey
      .UseMemoryStore(procedure(o: TApiKeyMemoryStoreOptions)
        begin
          o.AddApiKey('Alice', 'Admin', 'admin-key-abc123');
          o.AddApiKey('Bob',   'User',  'user-key-xyz789');
        end);

  // ── Paso 3: políticas de autorización ────────────────────────────
  services.Extension<TAuthorizationServiceExtension>
    .AddAuthorization(procedure(o: TAuthorizationOptions)
      begin
        // Cualquier usuario autenticado
        o.AddPolicy('Authenticated',
          TAuthorizationPolicyBuilder.GetBuilder
            .RequireAuthenticatedUser
            .Build);

        // Solo administradores
        o.AddPolicy('AdminOnly',
          TAuthorizationPolicyBuilder.GetBuilder
            .RequireAuthenticatedUser
            .RequireClaim('role', 'Admin')
            .Build);
      end);
end;

class procedure TStartup.Configure(app: TMVCServer);
begin
  app
    .AddControllers
    .AddController(TProductsController)
    .UseRouting
    .UseAuthentication    // extrae e identifica la API Key
    .UseAuthorization     // comprueba los atributos [Authorize]
    .UseMVC;
end;

end.
```

> **Importante:** `UseAuthentication` debe ir **antes** de `UseAuthorization` en el pipeline.

---

## Paso 2 — Controller con autenticación mixta

Crea `controllers/Controller.Products.pas`:

```pascal
unit Controller.Products;

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Security.Claims;

type
  [Route('api/products')]
  [ApiController]
  [Authorize]   // Todas las acciones requieren autenticación por defecto
  TProductsController = class(THttpController)
  public
    constructor Create;
  published
    // Cualquier usuario autenticado (Admin o User)
    [HttpGet]
    function GetAll: IActionResult;

    // Solo administradores
    [HttpGet('admin')]
    [AuthorizePolicy('AdminOnly')]
    function AdminPanel: IActionResult;

    // Sin autenticación
    [HttpGet('public')]
    [AllowAnonymous]
    function PublicCatalog: IActionResult;

    // Devuelve el nombre del usuario autenticado
    [HttpGet('me')]
    function WhoAmI: IActionResult;
  end;

implementation

uses System.SysUtils;

constructor TProductsController.Create;
begin
  inherited Create;
end;

function TProductsController.GetAll: IActionResult;
begin
  Result := Json('[{"id":1,"name":"Laptop"},{"id":2,"name":"Keyboard"}]');
end;

function TProductsController.AdminPanel: IActionResult;
begin
  Result := Json('{"panel":"Admin Dashboard","secret":"42"}');
end;

function TProductsController.PublicCatalog: IActionResult;
begin
  Result := Json('[{"id":1,"name":"Laptop","publicPrice":999}]');
end;

function TProductsController.WhoAmI: IActionResult;
var
  userName: string;
begin
  userName := HttpContext.User.Identity.Name;
  if userName.IsEmpty then userName := 'anonymous';
  Result := Json(Format('{"user":"%s"}', [userName]));
end;

initialization
  RegisterController(TProductsController);

end.
```

**Atributos de autorización disponibles:**

| Atributo | Descripción |
|----------|-------------|
| `[Authorize]` | Requiere cualquier usuario autenticado |
| `[AuthorizePolicy('NombrePolicy')]` | Requiere que se cumpla la política indicada |
| `[AllowAnonymous]` | Anula `[Authorize]` en esa acción específica |

---

## Paso 3 — Punto de entrada

```pascal
program WebApiWithApiKeyAuth;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Controller.Products in 'controllers\Controller.Products.pas';

var
  Server: TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    cout('Starting WebApiWithApiKeyAuth on http://localhost:8080 ...', etInfo);
    cout('Admin key : admin-key-abc123', ccWhite);
    cout('User key  : user-key-xyz789', ccWhite);
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

## Paso 4 — Probar los endpoints

### Sin clave → 401 Unauthorized

```bash
curl -i http://localhost:8080/api/products
# HTTP/1.1 401 Unauthorized
```

### Con clave de usuario → 200 OK

```bash
curl -H "X-API-Key: user-key-xyz789" \
     http://localhost:8080/api/products
# [{"id":1,"name":"Laptop"},{"id":2,"name":"Keyboard"}]
```

### Con clave de usuario en ruta Admin → 403 Forbidden

```bash
curl -i -H "X-API-Key: user-key-xyz789" \
     http://localhost:8080/api/products/admin
# HTTP/1.1 403 Forbidden
```

### Con clave de Admin → 200 OK

```bash
curl -H "X-API-Key: admin-key-abc123" \
     http://localhost:8080/api/products/admin
# {"panel":"Admin Dashboard","secret":"42"}
```

### Ruta pública sin clave → 200 OK

```bash
curl http://localhost:8080/api/products/public
# [{"id":1,"name":"Laptop","publicPrice":999}]
```

### Saber quién eres

```bash
curl -H "X-API-Key: admin-key-abc123" \
     http://localhost:8080/api/products/me
# {"user":"Alice"}
```

---

## Paso 5 (opcional) — Almacén de claves en base de datos

Para entornos de producción, las claves no deben estar hardcodeadas. Usa el store de base de datos:

```pascal
// En ConfigureServices, en lugar de UseMemoryStore:
services.Extension<TApiKeyAuthenticationServiceExtension>
  .AddApiKey
    .UseDatabaseStore<TApiKeyEntity>(procedure(o: TApiKeyDatabaseStoreOptions)
      begin
        // Las claves se cargan desde la tabla api_keys del DbContext
      end);
```

Consulta el sample `samples/delphi/ApiKeyDatabaseStore` para el ejemplo completo.

---

## Resumen

Has configurado autenticación por API Key con tres niveles de acceso:

| Endpoint | Autenticación | Rol requerido |
|----------|---------------|---------------|
| `GET /api/products` | Sí | Cualquiera |
| `GET /api/products/admin` | Sí | Admin |
| `GET /api/products/public` | No | — |
| `GET /api/products/me` | Sí | Cualquiera |

**Flujo de protección:**
```
Request
  └─► UseAuthentication ─► valida X-API-Key ─► crea ClaimsPrincipal
        └─► UseAuthorization ─► [Authorize] / [AuthorizePolicy] ─► 200 / 401 / 403
```

---

## Siguiente nivel

- [Tutorial — JWT Authentication](../wiki/Security.md) — tokens JWT stateless
- [Guía de migración](../Migration-Guide.md) — si vienes de una versión anterior
- [FAQ — Auth](../FAQ.md#5-autenticación-y-autorización) — preguntas frecuentes

---

## Ver también

- [Security](../wiki/Security.md)
- [Dependency Injection](../wiki/Dependency-Injection.md)
- [API Reference — Security](../API-Reference.md#8-security--authentication)
