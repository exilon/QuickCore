# Tutorial 4 — Authentication with JWT

> **Estimated time:** 30 minutes  
> **Level:** Intermediate  
> **Reference sample:** `samples/delphi/WebApiWithJwt` (S-27)

In this tutorial you will implement **stateless** authentication with JSON Web Tokens (JWT). The client authenticates with a username and password, receives a token, and attaches it to every subsequent request in the `Authorization: Bearer <token>` header.

---

## Why JWT?

| API Key | JWT |
|---------|-----|
| Fixed key, never expires | Token with configurable expiration |
| No user information | Carries claims (name, role, etc.) |
| Simple for M2M | Standard for user-facing apps |
| No automatic revocation | Invalidated on expiry |

---

## Tutorial architecture

```
WebApiWithJwt/
├── WebApiWithJwt.dpr
├── Startup.pas              ← registers JWT + Authorization
├── Models.pas               ← DTOs TLoginRequest / TLoginResponse
└── controllers/
    ├── Controller.Auth.pas  ← POST /api/auth/login + GET /api/auth/me
    └── Controller.Products.pas  ← protected endpoints
```

---

## Step 1 — Request/response models

Create `Models.pas`:

```pascal
unit Models;

interface

type
  TLoginRequest = class
  private
    FUserName : string;
    FPassword : string;
  public
    property UserName : string read FUserName write FUserName;
    property Password : string read FPassword write FPassword;
  end;

implementation

end.
```

---

## Step 2 — Authentication controller

Create `controllers/Controller.Auth.pas`. This controller has two responsibilities:
- `POST /api/auth/login` — validates credentials and issues the token.
- `GET  /api/auth/me`    — returns the claims of the current token.

```pascal
unit Controller.Auth;

interface

uses
  System.SysUtils,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Security.Jwt,
  Quick.Core.Security.Claims,
  Quick.Core.Extensions.Authentication.Jwt,
  Models;

type
  [Route('api/auth')]
  [ApiController]
  TAuthController = class(THttpController)
  private
    fJwtService : IJwtTokenService;
    function TryGetUser(const aUserName, aPassword : string;
                        out aRole : string) : Boolean;
  public
    constructor Create(aJwtService : IJwtTokenService);
  published
    [HttpPost('login')]
    function Login([FromBody] body : TLoginRequest) : IActionResult;

    [HttpGet('me')]
    [Authorize]
    function Me : IActionResult;
  end;

implementation

constructor TAuthController.Create(aJwtService : IJwtTokenService);
begin
  inherited Create;
  fJwtService := aJwtService;
end;

function TAuthController.TryGetUser(const aUserName, aPassword : string;
                                    out aRole : string) : Boolean;
begin
  // Replace this with your real user database
  Result := True;
  if SameText(aUserName, 'admin') and (aPassword = 'admin123') then
    aRole := 'Admin'
  else if SameText(aUserName, 'user') and (aPassword = 'user123') then
    aRole := 'User'
  else
    Result := False;
end;

function TAuthController.Login(body : TLoginRequest) : IActionResult;
var
  role      : string;
  identity  : TClaimsIdentity;
  principal : TClaimsPrincipal;
  token     : string;
begin
  if body = nil then
  begin
    Result := BadRequest('{"error":"Body is required"}');
    Exit;
  end;

  if not TryGetUser(body.UserName, body.Password, role) then
  begin
    Result := StatusCode(401, '{"error":"Invalid credentials"}');
    Exit;
  end;

  // Build the ClaimsPrincipal that will be embedded in the token
  identity := TClaimsIdentity.Create;
  identity.AuthenticationType := JwtBearerDefaults_AuthenticationScheme;
  identity.AddClaim(TClaim.Create(TClaimTypes.Name, body.UserName));
  identity.AddClaim(TClaim.Create(TClaimTypes.Role, role));

  principal := TClaimsPrincipal.Create(identity);
  try
    token := fJwtService.GenerateToken(principal);
  finally
    principal.Free;
  end;

  Result := Json(Format(
    '{"token":"%s","userName":"%s","role":"%s","expiresIn":3600}',
    [token, body.UserName, role]));
end;

function TAuthController.Me : IActionResult;
var
  user, role : string;
begin
  user := HttpContext.User.Identity.Name;
  role := HttpContext.User.FindFirst(
    function(c : TClaim) : Boolean
    begin
      Result := c.&Type = TClaimTypes.Role;
    end).Value;

  Result := Json(Format(
    '{"userName":"%s","role":"%s","isAuthenticated":%s}',
    [user, role,
     BoolToStr(HttpContext.User.Identity.IsAuthenticated, True).ToLower]));
end;

initialization
  RegisterController(TAuthController);

end.
```

---

## Step 3 — Protected resources controller

Create `controllers/Controller.Products.pas`:

```pascal
unit Controller.Products;

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult;

type
  [Route('api/products')]
  [ApiController]
  [Authorize]   // All actions require a valid token
  TProductsController = class(THttpController)
  public
    constructor Create;
  published
    /// GET /api/products  — any authenticated user
    [HttpGet]
    function GetAll : IActionResult;

    /// GET /api/products/admin  — Admin role only
    [HttpGet('admin')]
    [AuthorizePolicy('AdminOnly')]
    function AdminOnly : IActionResult;
  end;

implementation

uses System.SysUtils;

constructor TProductsController.Create;
begin
  inherited Create;
end;

function TProductsController.GetAll : IActionResult;
begin
  Result := Json('[{"id":1,"name":"Laptop","price":999.99},' +
                  '{"id":2,"name":"Keyboard","price":49.99}]');
end;

function TProductsController.AdminOnly : IActionResult;
begin
  Result := Json('{"panel":"Admin only data","secret":"42"}');
end;

initialization
  RegisterController(TProductsController);

end.
```

---

## Step 4 — Configure Startup with JWT

Create `Startup.pas`:

```pascal
unit Startup;

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Quick.Core.Extensions.Authentication,
  Quick.Core.Extensions.Authentication.Jwt,
  Quick.Core.Extensions.Authorization,
  Quick.Core.Security.Authorization,
  Quick.Core.Security.Claims,
  Quick.Core.Security.Jwt,
  Controller.Auth,
  Controller.Products;

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
          o.ShowEventType   := False;
          o.Enabled         := True;
        end)
      .Build)

    // 1. Authentication infrastructure
    .Extension<TAuthenticationServiceExtension>
      .AddAuthentication(procedure(o : TAuthenticationOptions)
        begin
          // The Bearer scheme is set automatically by AddJwtBearer
        end);

  // 2. Configure JWT Bearer
  services.Extension<TJwtBearerServiceExtension>
    .AddJwtBearer(procedure(o : TJwtOptions)
      begin
        // IMPORTANT: in production, load the secret from environment variables
        o.Secret           := 'super-secret-key-change-in-production-32chars!';
        o.Issuer           := 'QuickCore';
        o.Audience         := 'QuickCoreClients';
        o.ExpiryMinutes    := 60;   // 1 hour
        o.ValidateIssuer   := True;
        o.ValidateAudience := False;
        o.ValidateLifetime := True;
      end);

  // 3. Authorization policies
  services.Extension<TAuthorizationServiceExtension>
    .AddAuthorization(procedure(o : TAuthorizationOptions)
      begin
        o.AddPolicy('AdminOnly',
          TAuthorizationPolicyBuilder.GetBuilder
            .RequireAuthenticatedUser
            .RequireClaim(TClaimTypes.Role, 'Admin')
            .Build);
      end);
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .AddController(TAuthController)
    .AddController(TProductsController)
    .UseRouting
    .UseAuthentication     // extracts and validates the Bearer token
    .UseAuthorization      // applies [Authorize] / [AuthorizePolicy]
    .UseMVC;
end;

end.
```

> **Security:** Never hard-code the `Secret` in source code. Use environment variables or `ISecretsManager`:
> ```pascal
> o.Secret := GetEnvironmentVariable('JWT_SECRET');
> ```

---

## Step 5 — Entry point

```pascal
program WebApiWithJwt;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Models in 'Models.pas',
  Controller.Auth in 'controllers\Controller.Auth.pas',
  Controller.Products in 'controllers\Controller.Products.pas';

var
  Server : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    cout('Starting WebApiWithJwt on http://localhost:8080 ...', etInfo);
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

## Step 6 — Test the full flow

### 1. Login — obtain token

```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"userName":"admin","password":"admin123"}'
```

Response:
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "userName": "admin",
  "role": "Admin",
  "expiresIn": 3600
}
```

### 2. Use the token in requests

```bash
export TOKEN="eyJhbGci..."

# List products (user or admin)
curl -H "Authorization: Bearer $TOKEN" \
     http://localhost:8080/api/products

# Admin route (Admin only)
curl -H "Authorization: Bearer $TOKEN" \
     http://localhost:8080/api/products/admin

# View current token claims
curl -H "Authorization: Bearer $TOKEN" \
     http://localhost:8080/api/auth/me
```

### 3. Without token → 401

```bash
curl -i http://localhost:8080/api/products
# HTTP/1.1 401 Unauthorized
```

### 4. "User" token on Admin route → 403

```bash
# Login as user
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"userName":"user","password":"user123"}'

# Try to access the admin panel
curl -i -H "Authorization: Bearer $USER_TOKEN" \
     http://localhost:8080/api/products/admin
# HTTP/1.1 403 Forbidden
```

---

## JWT flow summary

```
Client                             Server
  │                                    │
  ├─ POST /api/auth/login ────────────►│
  │  {"userName":"admin","password":""}│
  │                                    │── Validates credentials
  │                                    │── Generates HMAC-SHA256 token
  │◄─ {"token":"eyJ...", ...} ─────────┤
  │                                    │
  ├─ GET /api/products ───────────────►│
  │  Authorization: Bearer eyJ...      │── Extracts and validates token
  │                                    │── Reconstructs ClaimsPrincipal
  │◄─ [...products...] ────────────────┤── Applies [Authorize]
```

---

## See also

- [Tutorial 3 — Auth with ApiKey](Auth-with-ApiKey.md) — stateless alternative
- [Security](../wiki/Security.md)
- [API Reference — JWT](../API-Reference.md#10-jwt)


---

## ¿Por qué JWT?

| API Key | JWT |
|---------|-----|
| Clave fija, nunca expira | Token con expiración configurable |
| Sin información de usuario | Lleva claims (nombre, rol, etc.) |
| Sencillo para M2M | Estándar para apps de usuario |
| Sin revocación automática | Se invalida al expirar |

---

## Arquitectura del tutorial

```
WebApiWithJwt/
├── WebApiWithJwt.dpr
├── Startup.pas              ← registra JWT + Authorization
├── Models.pas               ← DTOs TLoginRequest / TLoginResponse
└── controllers/
    ├── Controller.Auth.pas  ← POST /api/auth/login + GET /api/auth/me
    └── Controller.Products.pas  ← endpoints protegidos
```

---

## Paso 1 — Modelos de request/response

Crea `Models.pas`:

```pascal
unit Models;

interface

type
  TLoginRequest = class
  private
    FUserName : string;
    FPassword : string;
  public
    property UserName : string read FUserName write FUserName;
    property Password : string read FPassword write FPassword;
  end;

implementation

end.
```

---

## Paso 2 — Controller de autenticación

Crea `controllers/Controller.Auth.pas`. Este controller tiene dos responsabilidades:
- `POST /api/auth/login` — valida credenciales y emite el token.
- `GET  /api/auth/me`    — devuelve los claims del token actual.

```pascal
unit Controller.Auth;

interface

uses
  System.SysUtils,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Security.Jwt,
  Quick.Core.Security.Claims,
  Quick.Core.Extensions.Authentication.Jwt,
  Models;

type
  [Route('api/auth')]
  [ApiController]
  TAuthController = class(THttpController)
  private
    fJwtService : IJwtTokenService;
    function TryGetUser(const aUserName, aPassword : string;
                        out aRole : string) : Boolean;
  public
    constructor Create(aJwtService : IJwtTokenService);
  published
    [HttpPost('login')]
    function Login([FromBody] body : TLoginRequest) : IActionResult;

    [HttpGet('me')]
    [Authorize]
    function Me : IActionResult;
  end;

implementation

constructor TAuthController.Create(aJwtService : IJwtTokenService);
begin
  inherited Create;
  fJwtService := aJwtService;
end;

function TAuthController.TryGetUser(const aUserName, aPassword : string;
                                    out aRole : string) : Boolean;
begin
  // Reemplaza esto con tu base de datos de usuarios
  Result := True;
  if SameText(aUserName, 'admin') and (aPassword = 'admin123') then
    aRole := 'Admin'
  else if SameText(aUserName, 'user') and (aPassword = 'user123') then
    aRole := 'User'
  else
    Result := False;
end;

function TAuthController.Login(body : TLoginRequest) : IActionResult;
var
  role      : string;
  identity  : TClaimsIdentity;
  principal : TClaimsPrincipal;
  token     : string;
begin
  if body = nil then
  begin
    Result := BadRequest('{"error":"Body is required"}');
    Exit;
  end;

  if not TryGetUser(body.UserName, body.Password, role) then
  begin
    Result := StatusCode(401, '{"error":"Invalid credentials"}');
    Exit;
  end;

  // Construir el ClaimsPrincipal que se incluirá en el token
  identity := TClaimsIdentity.Create;
  identity.AuthenticationType := JwtBearerDefaults_AuthenticationScheme;
  identity.AddClaim(TClaim.Create(TClaimTypes.Name, body.UserName));
  identity.AddClaim(TClaim.Create(TClaimTypes.Role, role));

  principal := TClaimsPrincipal.Create(identity);
  try
    token := fJwtService.GenerateToken(principal);
  finally
    principal.Free;
  end;

  Result := Json(Format(
    '{"token":"%s","userName":"%s","role":"%s","expiresIn":3600}',
    [token, body.UserName, role]));
end;

function TAuthController.Me : IActionResult;
var
  user, role : string;
begin
  user := HttpContext.User.Identity.Name;
  role := HttpContext.User.FindFirst(
    function(c : TClaim) : Boolean
    begin
      Result := c.&Type = TClaimTypes.Role;
    end).Value;

  Result := Json(Format(
    '{"userName":"%s","role":"%s","isAuthenticated":%s}',
    [user, role,
     BoolToStr(HttpContext.User.Identity.IsAuthenticated, True).ToLower]));
end;

initialization
  RegisterController(TAuthController);

end.
```

---

## Paso 3 — Controller de recursos protegidos

Crea `controllers/Controller.Products.pas`:

```pascal
unit Controller.Products;

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult;

type
  [Route('api/products')]
  [ApiController]
  [Authorize]   // Todas las acciones requieren token válido
  TProductsController = class(THttpController)
  public
    constructor Create;
  published
    /// GET /api/products  — cualquier usuario autenticado
    [HttpGet]
    function GetAll : IActionResult;

    /// GET /api/products/admin  — solo rol Admin
    [HttpGet('admin')]
    [AuthorizePolicy('AdminOnly')]
    function AdminOnly : IActionResult;
  end;

implementation

uses System.SysUtils;

constructor TProductsController.Create;
begin
  inherited Create;
end;

function TProductsController.GetAll : IActionResult;
begin
  Result := Json('[{"id":1,"name":"Laptop","price":999.99},' +
                  '{"id":2,"name":"Keyboard","price":49.99}]');
end;

function TProductsController.AdminOnly : IActionResult;
begin
  Result := Json('{"panel":"Admin only data","secret":"42"}');
end;

initialization
  RegisterController(TProductsController);

end.
```

---

## Paso 4 — Configurar Startup con JWT

Crea `Startup.pas`:

```pascal
unit Startup;

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Quick.Core.Extensions.Authentication,
  Quick.Core.Extensions.Authentication.Jwt,
  Quick.Core.Extensions.Authorization,
  Quick.Core.Security.Authorization,
  Quick.Core.Security.Claims,
  Quick.Core.Security.Jwt,
  Controller.Auth,
  Controller.Products;

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
          o.ShowEventType   := False;
          o.Enabled         := True;
        end)
      .Build)

    // 1. Infraestructura de autenticación
    .Extension<TAuthenticationServiceExtension>
      .AddAuthentication(procedure(o : TAuthenticationOptions)
        begin
          // El esquema Bearer lo establece AddJwtBearer automáticamente
        end);

  // 2. Configurar JWT Bearer
  services.Extension<TJwtBearerServiceExtension>
    .AddJwtBearer(procedure(o : TJwtOptions)
      begin
        // IMPORTANTE: en producción, carga el secret desde variables de entorno
        o.Secret           := 'super-secret-key-change-in-production-32chars!';
        o.Issuer           := 'QuickCore';
        o.Audience         := 'QuickCoreClients';
        o.ExpiryMinutes    := 60;   // 1 hora
        o.ValidateIssuer   := True;
        o.ValidateAudience := False;
        o.ValidateLifetime := True;
      end);

  // 3. Políticas de autorización
  services.Extension<TAuthorizationServiceExtension>
    .AddAuthorization(procedure(o : TAuthorizationOptions)
      begin
        o.AddPolicy('AdminOnly',
          TAuthorizationPolicyBuilder.GetBuilder
            .RequireAuthenticatedUser
            .RequireClaim(TClaimTypes.Role, 'Admin')
            .Build);
      end);
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .AddController(TAuthController)
    .AddController(TProductsController)
    .UseRouting
    .UseAuthentication     // extrae y valida el Bearer token
    .UseAuthorization      // aplica [Authorize] / [AuthorizePolicy]
    .UseMVC;
end;

end.
```

> **Seguridad:** Nunca escribas el `Secret` en el código fuente. Usa variables de entorno o `ISecretsManager`:
> ```pascal
> o.Secret := GetEnvironmentVariable('JWT_SECRET');
> ```

---

## Paso 5 — Punto de entrada

```pascal
program WebApiWithJwt;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Models in 'Models.pas',
  Controller.Auth in 'controllers\Controller.Auth.pas',
  Controller.Products in 'controllers\Controller.Products.pas';

var
  Server : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    cout('Starting WebApiWithJwt on http://localhost:8080 ...', etInfo);
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

## Paso 6 — Probar el flujo completo

### 1. Login — obtener token

```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"userName":"admin","password":"admin123"}'
```

Respuesta:
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "userName": "admin",
  "role": "Admin",
  "expiresIn": 3600
}
```

### 2. Usar el token en peticiones

```bash
export TOKEN="eyJhbGci..."

# Listar productos (usuario o admin)
curl -H "Authorization: Bearer $TOKEN" \
     http://localhost:8080/api/products

# Ruta admin (solo Admin)
curl -H "Authorization: Bearer $TOKEN" \
     http://localhost:8080/api/products/admin

# Ver claims del token actual
curl -H "Authorization: Bearer $TOKEN" \
     http://localhost:8080/api/auth/me
```

### 3. Sin token → 401

```bash
curl -i http://localhost:8080/api/products
# HTTP/1.1 401 Unauthorized
```

### 4. Token de "User" en ruta Admin → 403

```bash
# Login como user
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"userName":"user","password":"user123"}'

# Intentar acceder al panel admin
curl -i -H "Authorization: Bearer $USER_TOKEN" \
     http://localhost:8080/api/products/admin
# HTTP/1.1 403 Forbidden
```

---

## Resumen del flujo JWT

```
Cliente                            Servidor
  │                                    │
  ├─ POST /api/auth/login ────────────►│
  │  {"userName":"admin","password":""}│
  │                                    │── Valida credenciales
  │                                    │── Genera token HMAC-SHA256
  │◄─ {"token":"eyJ...", ...} ─────────┤
  │                                    │
  ├─ GET /api/products ───────────────►│
  │  Authorization: Bearer eyJ...      │── Extrae y valida token
  │                                    │── Reconstruye ClaimsPrincipal
  │◄─ [...productos...] ───────────────┤── Aplica [Authorize]
```

---

## Ver también

- [Tutorial 3 — Auth con ApiKey](Auth-with-ApiKey.md) — alternativa sin estado de sesión
- [Security](../wiki/Security.md)
- [API Reference — JWT](../API-Reference.md#10-jwt)
