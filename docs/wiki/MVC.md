# MVC / WebAPI

> Module: `Quick.Core.Mvc`  
> .NET equivalent: `Microsoft.AspNetCore.Mvc` + `Microsoft.AspNetCore.Builder`

QuickCore MVC provides an HTTP server with attribute-based routing, middleware pipeline, controllers, action filters, model validation, Swagger, and Minimal API.

---

## Table of contents

1. [Basic structure](#basic-structure)
2. [Controllers and routing](#controllers-and-routing)
3. [Action attributes](#action-attributes)
4. [Action parameters](#action-parameters)
5. [Action Results](#action-results)
6. [Model Validation](#model-validation)
7. [Action Filters](#action-filters)
8. [Middleware pipeline](#middleware-pipeline)
9. [Minimal API](#minimal-api)
10. [Swagger / OpenAPI](#swagger--openapi)
11. [Rate Limiting](#rate-limiting)
12. [CORS](#cors)
13. [Response compression](#response-compression)
14. [API versioning](#api-versioning)
15. [Sessions](#sessions)
16. [Static files](#static-files)
17. [See also](#see-also)

---

## Basic structure

```pascal
uses Quick.Core.Mvc;

type
  TMyStartup = class(TStartupMvc)
  public
    class procedure ConfigureServices(services: TServiceCollection); override;
    class procedure Configure(app: TMVCServer); override;
  end;

class procedure TMyStartup.ConfigureServices(services: TServiceCollection);
begin
  services.AddOptions(ofJSON);
  services.AddSingleton<IProductService, TProductService>;
end;

class procedure TMyStartup.Configure(app: TMVCServer);
begin
  app.UseExceptionHandler
     .UseRouting
     .UseAuthentication
     .UseAuthorization
     .UseMVC;
end;

// Startup
begin
  TMVCServer.Create('0.0.0.0', 8080, False)
    .UseStartup<TMyStartup>
    .AddControllers
    .Start;
end;
```

### C# equivalent

```csharp
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
var app = builder.Build();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.Run();
```

---

## Controllers and routing

Controllers inherit from `THttpController` and use attributes to declare routes.

```pascal
uses Quick.Core.Mvc.Controller;

type
  [Route('api/[controller]')]
  TProductsController = class(THttpController)
  private
    fService: IProductService;
  public
    constructor Create(aService: IProductService);

    [HttpGet]
    function GetAll: TActionResult;

    [HttpGet('{id}')]
    function GetById(id: Integer): TActionResult;

    [HttpPost]
    function Create([FromBody] aProduct: TProductDto): TActionResult;

    [HttpPut('{id}')]
    function Update(id: Integer; [FromBody] aProduct: TProductDto): TActionResult;

    [HttpDelete('{id}')]
    function Delete(id: Integer): TActionResult;
  end;
```

### Routing attributes

| Attribute | Description |
|-----------|-------------|
| `[Route('api/[controller]')]` | Route prefix; `[controller]` is replaced by the controller name |
| `[HttpGet]` | GET method, optional route |
| `[HttpPost]` | POST method |
| `[HttpPut('{id}')]` | PUT method with route parameter |
| `[HttpDelete('{id}')]` | DELETE method with route parameter |
| `[ActionName('name')]` | Custom action name |
| `[NonAction]` | Excludes the method from routing |
| `[AcceptVerbs([mvGET, mvPOST])]` | Multiple verbs on one action |

---

## Action attributes

| Attribute | Description | .NET equivalent |
|-----------|-------------|----------------|
| `[Authorize]` | Requires authenticated user | `[Authorize]` |
| `[Authorize('Admin')]` | Requires role | `[Authorize(Roles = "Admin")]` |
| `[AuthorizePolicy('PolicyName')]` | Requires named policy | `[Authorize(Policy = "...")]` |
| `[AllowAnonymous]` | Allows access without authentication | `[AllowAnonymous]` |
| `[OutputCache(5000)]` | Caches the response for N ms | `[OutputCache]` |
| `[RateLimit]` | Applies rate limiting to the action | `[EnableRateLimiting]` |
| `[ApiVersion('2.0')]` | API version | `[ApiVersion]` |

---

## Action parameters

| Attribute | Source | Description |
|-----------|--------|-------------|
| `[FromBody]` | JSON body | Deserializes the request body |
| `[FromQuery('name')]` | Query string | `?name=value` |
| `[FromHeader('X-Custom')]` | HTTP header | Reads a specific header |
| No attribute | URL route | Route parameter `{id}` |
| `[FromKeyedServices('key')]` | DI container | Named service injection |

```pascal
[HttpPost('search')]
function Search(
  [FromBody]  aFilter  : TSearchFilter;
  [FromQuery] aPage    : Integer;
  [FromHeader('X-Tenant')] aTenant : string
): TActionResult;
```

---

## Action Results

| Helper method | HTTP status | Description |
|--------------|-------------|-------------|
| `Ok()` | 200 | Successful response |
| `Accepted()` | 202 | Request accepted, processing |
| `Content(text)` | 200 | Plain text response |
| `Json(object)` | 200 | Serializes the object to JSON |
| `View()` | 200 | Renders Mustache/Liquid view |
| `BadRequest(msg)` | 400 | Invalid request |
| `Unauthorized()` | 401 | Not authenticated |
| `Forbid()` | 403 | No permissions |
| `NotFound()` | 404 | Resource not found |
| `StatusCode(n)` | n | Arbitrary status code |
| `Redirect(url)` | 302 | Temporary redirect |
| `RedirectPermanent(url)` | 301 | Permanent redirect |

```pascal
function TProductsController.GetById(id: Integer): TActionResult;
var
  product: TProduct;
begin
  product := fService.GetById(id);
  if product = nil then
    Result := NotFound('Product not found')
  else
    Result := Json(product);
end;
```

---

## Model Validation

DTO properties are validated automatically when using `[FromBody]`:

```pascal
uses Quick.Core.Mvc.ModelValidation;

type
  TCreateProductDto = class
  published
    [Required]
    [StringLength(100)]
    property Name  : string  read fName  write fName;

    [Range(0.01, 9999.99)]
    property Price : Double  read fPrice write fPrice;

    [Required]
    [EmailAddress]
    property ContactEmail : string read fEmail write fEmail;

    [RegularExpression('^[A-Z]{2}[0-9]{4}$')]
    property SKU : string read fSKU write fSKU;
  end;
```

If validation fails, the action automatically receives a `400 Bad Request` with a JSON error response before executing.

### C# equivalent

```csharp
public class CreateProductDto
{
    [Required, MaxLength(100)]
    public string Name { get; set; }

    [Range(0.01, 9999.99)]
    public double Price { get; set; }
}
```

---

## Action Filters

Intercept execution before and after an action:

```pascal
uses Quick.Core.Mvc.Filters;

type
  TLogActionFilter = class(TActionFilterAttribute)
  public
    procedure OnActionExecuting(aContext: TActionExecutingContext); override;
    procedure OnActionExecuted(aContext: TActionExecutingContext); override;
  end;

procedure TLogActionFilter.OnActionExecuting(aContext: TActionExecutingContext);
begin
  Logger.Info('Executing: ' + aContext.ActionName);
end;

procedure TLogActionFilter.OnActionExecuted(aContext: TActionExecutingContext);
begin
  Logger.Info('Executed: ' + aContext.ActionName);
end;

// Use on controller or action
[TLogActionFilter]
function TProductsController.GetAll: TActionResult;
```

> Set `aContext.Canceled := True` in `OnActionExecuting` to short-circuit execution.

---

## Middleware pipeline

The order of middlewares matters. Typical configuration:

```pascal
class procedure TMyStartup.Configure(app: TMVCServer);
begin
  app.UseExceptionHandler          // catch errors → 500 JSON
     .UseHttpsRedirection          // HTTP → HTTPS
     .UseHsts                      // Strict-Transport-Security header
     .UseStaticFiles               // static files (wwwroot/)
     .UseResponseCompression       // Gzip/Deflate
     .UseCors                      // CORS headers
     .UseRouting                   // resolve route
     .UseRateLimiting(100, 60)     // max 100 req/60 sec
     .UseAuthentication            // validate credentials
     .UseAuthorization             // verify permissions
     .UseSession                   // server-side session
     .UseSwagger('My API', '1.0')  // OpenAPI docs
     .UseLogRequest                // log each request
     .UseMVC;                      // execute controllers
end;
```

### Custom middleware

```pascal
// With a class
type
  TMyMiddleware = class(TRequestDelegate)
  public
    procedure Invoke(aContext: THttpContextBase); override;
  end;

app.UseMiddleware(TMyMiddleware);

// With inline delegate
app.Use(function(aContext: THttpContextBase; aNext: TRequestDelegate): Boolean
begin
  // pre-next logic
  aNext.Invoke(aContext);
  // post-next logic
  Result := True;
end);
```

---

## Minimal API

Lightweight endpoints without controllers:

```pascal
app.MapGet('/health', function(ctx: THttpContextBase): string
begin
  Result := '{"status":"ok"}';
end);

app.MapPost('/echo', function(ctx: THttpContextBase): string
begin
  Result := ctx.Request.Body;
end);

app.MapGet('/products/{id}', function(ctx: THttpContextBase): string
var
  id: Integer;
begin
  id := ctx.Request.RouteParams['id'].ToInteger;
  Result := fService.GetJson(id);
end);
```

### C# equivalent

```csharp
app.MapGet("/health", () => new { status = "ok" });
app.MapGet("/products/{id}", (int id, IProductService svc) => svc.Get(id));
```

---

## Swagger / OpenAPI

```pascal
// In Configure
app.UseSwagger('Products API', '1.0', 'Product CRUD');

// Decorate actions
[HttpGet]
[SwaggerOperation('ListProducts', 'Returns all products')]
[ProducesResponseType(200, TArray<TProduct>)]
[ProducesResponseType(401)]
function GetAll: TActionResult;
```

Generated routes:
- `/swagger/v1/swagger.json` — OpenAPI 3.0 document
- `/swagger` — interactive UI (Swagger UI via CDN)

---

## Rate Limiting

**Unit:** `Quick.Core.Mvc.Middleware.RateLimit`

Sliding-window, thread-safe. The default key is the client IP; it can be customized with `TRateLimitPolicy.KeySelector`.

| Class / Member | Description |
|----------------|-------------|
| `TRateLimitPolicy` | Configures `MaxRequests`, `WindowSecs` and optional `KeySelector` |
| `TRateLimitMiddleware` | Middleware that applies the policy globally |
| `RateLimit` (attribute) | Per-action override: `[RateLimit(10, 60)]` |

```pascal
uses Quick.Core.Mvc.Middleware.RateLimit;

// Global: 100 requests per 60 seconds per IP
app.UseRateLimiting(100, 60);

// Advanced policy — key by API-Key header instead of IP:
var policy := TRateLimitPolicy.Create(50, 60);
policy.KeySelector := function(ctx: THttpContextBase): string
  begin Result := ctx.Request.Headers['X-Api-Key'] end;
app.UseMiddleware<TRateLimitMiddleware>(policy);

// Per-action override — 10 req / 60 s:
[RateLimit(10, 60)]
function TAuthController.Login([FromBody] dto: TLoginDto): IActionResult;
```

When the limit is exceeded → `429 Too Many Requests` with `Retry-After` header and JSON body:
```json
{ "error": "Too Many Requests", "retryAfterSeconds": 42 }
```

---

## CORS

```pascal
uses Quick.Core.Extensions.Cors;

// Register
services.Extension<TCorsServiceExtension>
  .AddCors(procedure(opt: TCorsPolicyOptions)
  begin
    opt.AllowedOrigins.Add('https://myfrontend.com');
    opt.AllowedMethods.Add('GET');
    opt.AllowedMethods.Add('POST');
    opt.AllowCredentials := True;
  end);

// Enable in pipeline
app.UseCors;
```

---

## Response compression

```pascal
uses Quick.Core.Extensions.Compression;

services.Extension<TCompressionServiceExtension>
  .AddResponseCompression(procedure(opt: TCompressionOptions)
  begin
    opt.MinimumBytes := 1024;
  end);

app.UseResponseCompression;
```

Supports **Gzip** and **Deflate** based on the client's `Accept-Encoding` header.

---

## API versioning

```pascal
// In the controller
[ApiVersion('2.0')]
[Route('api/v2/[controller]')]
TProductsV2Controller = class(THttpController)
// ...
end;

// In Configure
app.UseApiVersioning;
```

---

## Sessions

```pascal
// In Configure
app.UseSession;

// In the controller
procedure TMyController.SomeAction;
begin
  // Store
  HttpContext.Session.SetString('userId', '42');

  // Read
  var userId := HttpContext.Session.GetString('userId');
end;
```

---

## Static files

```pascal
// Serves files from wwwroot/ (or configured path)
app.UseWebRoot('wwwroot')
   .UseStaticFiles;
```

---

## See also

- [Dependency Injection](Dependency-Injection.md) — `TStartupMvc`, `ConfigureServices`
- [Security](Security.md) — `UseAuthentication`, `UseAuthorization`, JWT
- [Entity / ORM](Entity-ORM.md) — `TDBContext` injection in controllers
- [Caching](Caching.md) — `[OutputCache]`, `IMemoryCache`


---

## Tabla de contenidos

1. [Estructura básica](#estructura-básica)
2. [Controllers y routing](#controllers-y-routing)
3. [Atributos de acción](#atributos-de-acción)
4. [Parámetros de acción](#parámetros-de-acción)
5. [Action Results](#action-results)
6. [Model Validation](#model-validation)
7. [Action Filters](#action-filters)
8. [Pipeline de middleware](#pipeline-de-middleware)
9. [Minimal API](#minimal-api)
10. [Swagger / OpenAPI](#swagger--openapi)
11. [Rate Limiting](#rate-limiting)
12. [CORS](#cors)
13. [Compresión de respuesta](#compresión-de-respuesta)
14. [Versionado de API](#versionado-de-api)
15. [Sesiones](#sesiones)
16. [Archivos estáticos](#archivos-estáticos)
17. [Ver también](#ver-también)

---

## Estructura básica

```pascal
uses Quick.Core.Mvc;

type
  TMyStartup = class(TStartupMvc)
  public
    class procedure ConfigureServices(services: TServiceCollection); override;
    class procedure Configure(app: TMVCServer); override;
  end;

class procedure TMyStartup.ConfigureServices(services: TServiceCollection);
begin
  services.AddOptions(ofJSON);
  services.AddSingleton<IProductService, TProductService>;
end;

class procedure TMyStartup.Configure(app: TMVCServer);
begin
  app.UseExceptionHandler
     .UseRouting
     .UseAuthentication
     .UseAuthorization
     .UseMVC;
end;

// Arranque
begin
  TMVCServer.Create('0.0.0.0', 8080, False)
    .UseStartup<TMyStartup>
    .AddControllers
    .Start;
end;
```

### Equivalente C#

```csharp
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
var app = builder.Build();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.Run();
```

---

## Controllers y routing

Los controllers heredan de `THttpController` y usan atributos para declarar rutas.

```pascal
uses Quick.Core.Mvc.Controller;

type
  [Route('api/[controller]')]
  TProductsController = class(THttpController)
  private
    fService: IProductService;
  public
    constructor Create(aService: IProductService);

    [HttpGet]
    function GetAll: TActionResult;

    [HttpGet('{id}')]
    function GetById(id: Integer): TActionResult;

    [HttpPost]
    function Create([FromBody] aProduct: TProductDto): TActionResult;

    [HttpPut('{id}')]
    function Update(id: Integer; [FromBody] aProduct: TProductDto): TActionResult;

    [HttpDelete('{id}')]
    function Delete(id: Integer): TActionResult;
  end;
```

### Atributos de routing

| Atributo | Descripción |
|----------|-------------|
| `[Route('api/[controller]')]` | Prefijo de ruta; `[controller]` se sustituye por el nombre |
| `[HttpGet]` | Método GET, ruta opcional |
| `[HttpPost]` | Método POST |
| `[HttpPut('{id}')]` | Método PUT con parámetro de ruta |
| `[HttpDelete('{id}')]` | Método DELETE con parámetro de ruta |
| `[ActionName('nombre')]` | Nombre de acción personalizado |
| `[NonAction]` | Excluye el método del routing |
| `[AcceptVerbs([mvGET, mvPOST])]` | Múltiples verbos en una acción |

---

## Atributos de acción

| Atributo | Descripción | .NET equivalente |
|----------|-------------|------------------|
| `[Authorize]` | Requiere usuario autenticado | `[Authorize]` |
| `[Authorize('Admin')]` | Requiere rol | `[Authorize(Roles = "Admin")]` |
| `[AuthorizePolicy('NombrePolicy')]` | Requiere política nombrada | `[Authorize(Policy = "...")]` |
| `[AllowAnonymous]` | Permite acceso sin autenticación | `[AllowAnonymous]` |
| `[OutputCache(5000)]` | Cachea la respuesta N ms | `[OutputCache]` |
| `[RateLimit]` | Aplica rate limiting a la acción | `[EnableRateLimiting]` |
| `[ApiVersion('2.0')]` | Versión de la API | `[ApiVersion]` |

---

## Parámetros de acción

| Atributo | Fuente | Descripción |
|----------|--------|-------------|
| `[FromBody]` | Body JSON | Deserializa el cuerpo de la petición |
| `[FromQuery('nombre')]` | Query string | `?nombre=valor` |
| `[FromHeader('X-Custom')]` | Header HTTP | Lee un header específico |
| Sin atributo | Ruta URL | Parámetro de ruta `{id}` |
| `[FromKeyedServices('key')]` | DI container | Inyección de servicio con nombre |

```pascal
[HttpPost('search')]
function Search(
  [FromBody]  aFilter  : TSearchFilter;
  [FromQuery] aPage    : Integer;
  [FromHeader('X-Tenant')] aTenant : string
): TActionResult;
```

---

## Action Results

| Método helper | HTTP status | Descripción |
|--------------|-------------|-------------|
| `Ok()` | 200 | Respuesta exitosa |
| `Accepted()` | 202 | Petición aceptada, procesando |
| `Content(texto)` | 200 | Respuesta de texto plano |
| `Json(objeto)` | 200 | Serializa el objeto a JSON |
| `View()` | 200 | Renderiza vista Mustache/Liquid |
| `BadRequest(msg)` | 400 | Petición inválida |
| `Unauthorized()` | 401 | No autenticado |
| `Forbid()` | 403 | Sin permisos |
| `NotFound()` | 404 | Recurso no encontrado |
| `StatusCode(n)` | n | Status code arbitrario |
| `Redirect(url)` | 302 | Redirección temporal |
| `RedirectPermanent(url)` | 301 | Redirección permanente |

```pascal
function TProductsController.GetById(id: Integer): TActionResult;
var
  product: TProduct;
begin
  product := fService.GetById(id);
  if product = nil then
    Result := NotFound('Product not found')
  else
    Result := Json(product);
end;
```

---

## Model Validation

Las propiedades del DTO se validan automáticamente al usar `[FromBody]`:

```pascal
uses Quick.Core.Mvc.ModelValidation;

type
  TCreateProductDto = class
  published
    [Required]
    [StringLength(100)]
    property Name  : string  read fName  write fName;

    [Range(0.01, 9999.99)]
    property Price : Double  read fPrice write fPrice;

    [Required]
    [EmailAddress]
    property ContactEmail : string read fEmail write fEmail;

    [RegularExpression('^[A-Z]{2}[0-9]{4}$')]
    property SKU : string read fSKU write fSKU;
  end;
```

Si la validación falla, la acción recibe automáticamente un `400 Bad Request` con un JSON de errores antes de ejecutarse.

### Equivalente C#

```csharp
public class CreateProductDto
{
    [Required, MaxLength(100)]
    public string Name { get; set; }

    [Range(0.01, 9999.99)]
    public double Price { get; set; }
}
```

---

## Action Filters

Interceptan la ejecución antes y después de una acción:

```pascal
uses Quick.Core.Mvc.Filters;

type
  TLogActionFilter = class(TActionFilterAttribute)
  public
    procedure OnActionExecuting(aContext: TActionExecutingContext); override;
    procedure OnActionExecuted(aContext: TActionExecutingContext); override;
  end;

procedure TLogActionFilter.OnActionExecuting(aContext: TActionExecutingContext);
begin
  Logger.Info('Executing: ' + aContext.ActionName);
end;

procedure TLogActionFilter.OnActionExecuted(aContext: TActionExecutingContext);
begin
  Logger.Info('Executed: ' + aContext.ActionName);
end;

// Uso en controller o acción
[TLogActionFilter]
function TProductsController.GetAll: TActionResult;
```

> Establece `aContext.Canceled := True` en `OnActionExecuting` para corto-circuitar la ejecución.

---

## Pipeline de middleware

El orden de los middlewares es importante. Configuración típica:

```pascal
class procedure TMyStartup.Configure(app: TMVCServer);
begin
  app.UseExceptionHandler          // captura errores → 500 JSON
     .UseHttpsRedirection          // HTTP → HTTPS
     .UseHsts                      // Strict-Transport-Security header
     .UseStaticFiles               // archivos estáticos (wwwroot/)
     .UseResponseCompression       // Gzip/Deflate
     .UseCors                      // cabeceras CORS
     .UseRouting                   // resuelve la ruta
     .UseRateLimiting(100, 60)     // max 100 req/60 seg
     .UseAuthentication            // valida credenciales
     .UseAuthorization             // verifica permisos
     .UseSession                   // sesión server-side
     .UseSwagger('Mi API', '1.0')  // docs OpenAPI
     .UseLogRequest                // log de cada request
     .UseMVC;                      // ejecuta controllers
end;
```

### Middleware personalizado

```pascal
// Con clase
type
  TMyMiddleware = class(TRequestDelegate)
  public
    procedure Invoke(aContext: THttpContextBase); override;
  end;

app.UseMiddleware(TMyMiddleware);

// Con delegado inline
app.Use(function(aContext: THttpContextBase; aNext: TRequestDelegate): Boolean
begin
  // lógica pre-next
  aNext.Invoke(aContext);
  // lógica post-next
  Result := True;
end);
```

---

## Minimal API

Endpoints ligeros sin necesidad de controllers:

```pascal
app.MapGet('/health', function(ctx: THttpContextBase): string
begin
  Result := '{"status":"ok"}';
end);

app.MapPost('/echo', function(ctx: THttpContextBase): string
begin
  Result := ctx.Request.Body;
end);

app.MapGet('/products/{id}', function(ctx: THttpContextBase): string
var
  id: Integer;
begin
  id := ctx.Request.RouteParams['id'].ToInteger;
  Result := fService.GetJson(id);
end);
```

### Equivalente C#

```csharp
app.MapGet("/health", () => new { status = "ok" });
app.MapGet("/products/{id}", (int id, IProductService svc) => svc.Get(id));
```

---

## Swagger / OpenAPI

```pascal
// En Configure
app.UseSwagger('Products API', '1.0', 'CRUD de productos');

// Decorar acciones
[HttpGet]
[SwaggerOperation('ListProducts', 'Devuelve todos los productos')]
[ProducesResponseType(200, TArray<TProduct>)]
[ProducesResponseType(401)]
function GetAll: TActionResult;
```

Rutas generadas:
- `/swagger/v1/swagger.json` — documento OpenAPI 3.0
- `/swagger` — UI interactiva (Swagger UI via CDN)

---

## Rate Limiting

**Unidad:** `Quick.Core.Mvc.Middleware.RateLimit`

Sliding-window, thread-safe. La clave por defecto es la IP del cliente; se puede personalizar con `TRateLimitPolicy.KeySelector`.

| Clase / Miembro | Descripción |
|----------------|-------------|
| `TRateLimitPolicy` | Configura `MaxRequests`, `WindowSecs` y `KeySelector` opcional |
| `TRateLimitMiddleware` | Middleware que aplica la política globalmente |
| `RateLimit` (atributo) | Override por acción: `[RateLimit(10, 60)]` |

```pascal
uses Quick.Core.Mvc.Middleware.RateLimit;

// Global: 100 peticiones por 60 segundos por IP
app.UseRateLimiting(100, 60);

// Política avanzada — clave por API-Key header en lugar de IP:
var policy := TRateLimitPolicy.Create(50, 60);
policy.KeySelector := function(ctx: THttpContextBase): string
  begin Result := ctx.Request.Headers['X-Api-Key'] end;
app.UseMiddleware<TRateLimitMiddleware>(policy);

// Override por acción — 10 req / 60 s:
[RateLimit(10, 60)]
function TAuthController.Login([FromBody] dto: TLoginDto): IActionResult;
```

Cuando se supera el límite → `429 Too Many Requests` con header `Retry-After` y body JSON:
```json
{ "error": "Too Many Requests", "retryAfterSeconds": 42 }
```

---

## CORS

```pascal
uses Quick.Core.Extensions.Cors;

// Registrar
services.Extension<TCorsServiceExtension>
  .AddCors(procedure(opt: TCorsPolicyOptions)
  begin
    opt.AllowedOrigins.Add('https://mifrontend.com');
    opt.AllowedMethods.Add('GET');
    opt.AllowedMethods.Add('POST');
    opt.AllowCredentials := True;
  end);

// Activar en pipeline
app.UseCors;
```

---

## Compresión de respuesta

```pascal
uses Quick.Core.Extensions.Compression;

services.Extension<TCompressionServiceExtension>
  .AddResponseCompression(procedure(opt: TCompressionOptions)
  begin
    opt.MinimumBytes := 1024;
  end);

app.UseResponseCompression;
```

Soporta **Gzip** y **Deflate** según el header `Accept-Encoding` del cliente.

---

## Versionado de API

```pascal
// En el controller
[ApiVersion('2.0')]
[Route('api/v2/[controller]')]
TProductsV2Controller = class(THttpController)
// ...
end;

// En Configure
app.UseApiVersioning;
```

---

## Sesiones

```pascal
// En Configure
app.UseSession;

// En el controller
procedure TMyController.SomeAction;
begin
  // Guardar
  HttpContext.Session.SetString('userId', '42');

  // Leer
  var userId := HttpContext.Session.GetString('userId');
end;
```

---

## Archivos estáticos

```pascal
// Sirve archivos desde wwwroot/ (o la ruta configurada)
app.UseWebRoot('wwwroot')
   .UseStaticFiles;
```

---

## Ver también

- [Dependency Injection](Dependency-Injection.md) — `TStartupMvc`, `ConfigureServices`
- [Security](Security.md) — `UseAuthentication`, `UseAuthorization`, JWT
- [Entity / ORM](Entity-ORM.md) — inyección de `TDBContext` en controllers
- [Caching](Caching.md) — `[OutputCache]`, `IMemoryCache`
