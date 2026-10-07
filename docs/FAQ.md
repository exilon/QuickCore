# FAQ — Preguntas Frecuentes

> Respuestas a las preguntas más comunes sobre QuickCore.

---

## Tabla de contenidos

- [Dependency Injection](#dependency-injection)
- [Routing y Controllers](#routing-y-controllers)
- [Middleware](#middleware)
- [Entity / ORM](#entity--orm)
- [Autenticación y Autorización](#autenticación-y-autorización)
- [Configuración y Opciones](#configuración-y-opciones)
- [Testing](#testing)
- [Despliegue](#despliegue)

---

## Dependency Injection

### ¿Cuál es la diferencia entre Singleton, Transient y Scoped?

| Vida útil | Instancias creadas | Cuándo usar |
|-----------|-------------------|-------------|
| **Singleton** | Una por aplicación | Servicios sin estado, caches, configuración |
| **Transient** | Una por cada resolución | Servicios ligeros, operaciones atómicas |
| **Scoped** | Una por scope (p. ej. petición HTTP) | Contextos de base de datos, servicios con estado de petición |

```pascal
services.AddSingleton<IMemoryCache, TMemoryCache>;    // una instancia global
services.AddTransient<IEmailSender, TSmtpSender>;     // nueva instancia cada vez
services.AddScoped<IUnitOfWork, TUnitOfWork>;         // una por petición HTTP
```

---

### ¿Por qué obtengo "Service not registered" al arrancar?

Causas frecuentes:

1. **No llamaste a `Build`** después de registrar servicios:
   ```pascal
   services.AddSingleton<IMyService, TMyService>;
   services.Build; // ← obligatorio
   ```

2. **El tipo no coincide** — comprueba que registras la interfaz exacta que luego resuelves:
   ```pascal
   // Registro:
   services.AddSingleton<IOrderService, TOrderService>;
   // Resolución (debe coincidir):
   svc := services.Resolve<IOrderService>;  // ✅
   svc := services.Resolve<TOrderService>;  // ❌ distinto tipo
   ```

3. **Unidad no incluida en `uses`** — el tipo debe estar visible en tiempo de compilación.

---

### ¿Cómo inyecto un servicio con un nombre (keyed service)?

```pascal
// Registro
services.AddKeyedSingleton<IRepository, TSqlRepository>('primary');
services.AddKeyedSingleton<IRepository, TRedisRepository>('cache');

// Resolución directa
var primary := services.GetKeyedService<IRepository>('primary');

// Inyección en controller
constructor TOrderController.Create(
  [FromKeyedServices('primary')] repo: IRepository);
```

---

### ¿Cómo uso opciones tipadas (`appsettings.json`)?

```json
{
  "Smtp": {
    "Host": "smtp.example.com",
    "Port": 587
  }
}
```

```pascal
type
  TSmtpOptions = class(TOptions)
  published
    property Host: string ...;
    property Port: Integer ...;
  end;

// Registro
services.Configure<TSmtpOptions>('Smtp');

// Uso
var opt := services.Resolve<IOptions<TSmtpOptions>>;
smtpHost := opt.Value.Host;
```

---

### ¿Cómo creo un scope para servicios Scoped fuera de una petición HTTP?

```pascal
var scope := services.CreateScope;
try
  var dbCtx := scope.ServiceProvider.GetService<IAppDbContext>;
  dbCtx.Orders.Add(newOrder);
finally
  scope := nil; // libera scope y sus instancias
end;
```

---

## Routing y Controllers

### ¿Cómo debug el routing cuando una URL devuelve 404?

1. Comprueba que el controller está registrado:
   ```pascal
   app.AddControllers;  // registra todos los controllers con [Route]
   // o explícitamente:
   app.AddController(TProductsController);
   ```

2. Verifica que `UseMVC` está en el pipeline y **después** de `UseRouting`:
   ```pascal
   app.UseRouting
      .UseAuthentication
      .UseAuthorization
      .UseMVC;   // ← al final
   ```

3. Comprueba la ruta: si el controller tiene `[Route('api/products')]` y la acción tiene `[HttpGet('{id}')]`, la URL esperada es `GET /api/products/5`.

4. Activa el log de peticiones para ver qué rutas se evalúan:
   ```pascal
   app.UseLogRequest;
   ```

---

### ¿Cómo añado parámetros de ruta (`{id}`)?

```pascal
[Route('api/products')]
type TProductsController = class(THttpController)
public
  [HttpGet('{id}')]
  function GetById(id: Integer): TStatusResult;

  [HttpPut('{id}')]
  function Update(id: Integer; [FromBody] dto: TProductDto): TStatusResult;
end;
```

---

### ¿Cómo devuelvo un objeto JSON desde una acción?

```pascal
function GetAll: TStatusResult;
begin
  var products := fRepo.GetAll;
  Result := Json(products);  // serializa automáticamente
end;
```

Para devolver solo propiedades `published`:
```pascal
Result := Json(product, True);
```

---

### ¿Cómo implemento un filtro de acción (como un `IActionFilter` de .NET)?

```pascal
type
  TLogActionFilter = class(TActionFilterAttribute)
  public
    procedure OnActionExecuting(ctx: TActionExecutingContext); override;
    procedure OnActionExecuted(ctx: TActionExecutedContext); override;
  end;

procedure TLogActionFilter.OnActionExecuting(ctx: TActionExecutingContext);
begin
  Logger.Info('Executing: ' + ctx.ActionName);
end;

// Aplicar en la acción o en el controller
[LogActionFilter]
function GetProducts: TStatusResult;
```

---

### ¿Cómo implemento versionado de API?

```pascal
// Controller v1
[ApiVersion('1.0')]
[Route('api/v1/products')]
type TProductsV1Controller = class(THttpController) ...

// Controller v2
[ApiVersion('2.0')]
[Route('api/v2/products')]
type TProductsV2Controller = class(THttpController) ...

// Pipeline
app.UseApiVersioning.UseMVC;
```

---

## Middleware

### ¿Cómo añado un middleware personalizado?

**Opción A — inline (func):**
```pascal
app.Use(function(ctx: THttpContextBase): string
  begin
    // ejecutar antes del siguiente middleware
    ctx.Response.Headers.Add('X-Custom', 'value');
    Result := '';  // continúa el pipeline
  end);
```

**Opción B — clase:**
```pascal
type
  TTimingMiddleware = class(TRequestDelegate)
  public
    procedure Execute(ctx: THttpContextBase); override;
  end;

procedure TTimingMiddleware.Execute(ctx: THttpContextBase);
var t := TStopwatch.StartNew;
begin
  Next.Execute(ctx);          // ejecuta el siguiente
  t.Stop;
  ctx.Response.Headers.Add('X-Duration-Ms', t.ElapsedMilliseconds.ToString);
end;

// En Configure:
app.UseMiddleware(TTimingMiddleware);
```

---

### ¿Cuál es el orden correcto del middleware?

El orden importa: cada middleware envuelve al siguiente. Orden recomendado:

```pascal
app.UseExceptionHandler       // 1. capturar excepciones de todo lo demás
   .UseHsts                   // 2. seguridad de transporte
   .UseHttpsRedirection       // 3. forzar HTTPS
   .UseStaticFiles            // 4. archivos estáticos (sin auth)
   .UseRouting                // 5. resolver la ruta
   .UseCors                   // 6. cabeceras CORS
   .UseAuthentication         // 7. identificar al usuario
   .UseAuthorization          // 8. verificar permisos
   .UseSession                // 9. adjuntar sesión
   .UseResponseCompression    // 10. comprimir respuesta
   .UseMVC;                   // 11. ejecutar controller/acción
```

---

### ¿Cómo manejo errores globalmente?

```pascal
// En Configure:
app.UseExceptionHandler(procedure(ctx: THttpContextBase; e: Exception)
  begin
    ctx.Response.StatusCode  := 500;
    ctx.Response.ContentType := 'application/problem+json';
    ctx.Response.ContentText := Format(
      '{"type":"error","title":"%s","status":500}', [e.Message]);
  end);
```

---

## Entity / ORM

### ¿Cómo configuro la conexión a la base de datos?

**vía código:**
```pascal
services.AddDBContext<TAppDbContext>(
  procedure(opt: IDBConnectionOptions)
  begin
    opt.Provider := dbSQLite;
    opt.Server   := 'data/app.db';
  end);
```

**vía `appsettings.json` (recomendado):**
```json
{
  "Database": {
    "Provider": "SQLite",
    "Server": "data/app.db"
  }
}
```
```pascal
services.Configure<TDBConnectionOptions>('Database');
services.AddDBContext<TAppDbContext>;
```

---

### ¿Cómo hago una consulta con filtro?

```pascal
// Por string SQL
var results := context.Products
  .Where('Price > 100 AND IsActive = 1')
  .OrderBy('Name')
  .Select;

// Con parámetros (evita SQL injection)
var results := context.Products
  .Where('Price > ? AND IsActive = ?', [100, True])
  .Select;

// Con predicate lambda (in-memory)
var results := context.Products
  .Where(function(p: TProduct): Boolean
    begin Result := (p.Price > 100) and p.IsActive; end)
  .Select;
```

---

### ¿Cómo cargo relaciones (navigation properties)?

```pascal
// Carga ansiosa (eager loading)
var orders := context.Orders
  .Include('Customer')
  .Include('OrderLines')
  .Where('Status = ?', [1])
  .Select;

// Acceder a la navegación
for order in orders do
  WriteLn(order.Customer.Name);
```

---

### ¿Cómo uso transacciones?

```pascal
// Opción A — manual
context.BeginTransaction;
try
  context.Orders.Add(order);
  context.Inventory.Update(item);
  context.CommitTransaction;
except
  context.RollbackTransaction;
  raise;
end;

// Opción B — Unit of Work (automático)
uow.Execute(procedure
  begin
    context.Orders.Add(order);
    context.Inventory.Update(item);
  end);
```

---

### ¿Cómo aplico las migraciones al arrancar?

```pascal
class procedure TMyStartup.ConfigureServices(services: TServiceCollection);
begin
  services.AddDBContext<TAppDbContext>(...);
end;

class procedure TMyStartup.Configure(app: TMVCServer);
var
  ctx : IAppDbContext;
  mgr : TMigrationsManager;
begin
  ctx := app.Services.Resolve<IAppDbContext>;
  mgr := TMigrationsManager.Create(ctx);
  mgr.ApplyMigrations;
  // ...
end;
```

---

## Autenticación y Autorización

### ¿Cómo protejo un endpoint con JWT?

```pascal
// ConfigureServices
services.AddAuthentication
  .AddJwtBearer(procedure(opt: TJwtOptions)
    begin
      opt.Secret := 'mi-secreto-de-al-menos-32-caracteres';
      opt.ValidateLifetime := True;
    end);

services.AddAuthorization;

// Configure
app.UseAuthentication.UseAuthorization.UseMVC;

// Controller
[Authorize]
[Route('api/profile')]
type TProfileController = class(THttpController)
public
  [HttpGet]
  function Get: TStatusResult;
end;
```

---

### ¿Cómo genero un token JWT?

```pascal
// El servicio IJwtTokenService se registra automáticamente con AddJwtBearer

type TAuthController = class(THttpController)
private
  fJwt: IJwtTokenService;
  fUsers: IUserRepository;
public
  constructor Create(jwt: IJwtTokenService; users: IUserRepository);

  [HttpPost('login')]
  [AllowAnonymous]
  function Login([FromBody] req: TLoginRequest): TStatusResult;
end;

function TAuthController.Login(req: TLoginRequest): TStatusResult;
var
  user   : TUser;
  claims : TList<TClaim>;
  token  : string;
begin
  user := fUsers.FindByName(req.UserName);
  if (user = nil) or not user.CheckPassword(req.Password) then
    Exit(Unauthorized('Invalid credentials'));

  claims := TList<TClaim>.Create;
  claims.Add(TClaim.Create(ClaimTypes.Name, user.UserName));
  claims.Add(TClaim.Create(ClaimTypes.Role, user.Role));
  token := fJwt.GenerateToken(claims);

  Result := Ok;
  Result.Value := TObject(TTokenResponse.Create(token));
end;
```

---

### ¿Cómo accedo al usuario autenticado desde un controller?

```pascal
// Nombre de usuario
var userName := User.FindFirstValue(ClaimTypes.Name);

// Rol
var isAdmin := User.IsInRole('Admin');

// Cualquier claim
var email := User.FindFirstValue(ClaimTypes.Email);

// ¿Está autenticado?
if User.Identity.IsAuthenticated then
  // ...
```

---

### ¿Cómo creo una política de autorización personalizada?

```pascal
// ConfigureServices
services.AddAuthorization(procedure(opt: TAuthorizationOptions)
  begin
    opt.AddPolicy('PremiumOnly',
      TAuthorizationPolicyBuilder.New
        .RequireAuthenticatedUser
        .RequireClaim('subscription', 'premium')
        .Build);
  end);

// En el controller
[AuthorizePolicy('PremiumOnly')]
function GetPremiumContent: TStatusResult;
```

---

## Configuración y Opciones

### ¿Cómo leo una sección del `appsettings.json`?

```json
{
  "Email": {
    "Host": "smtp.gmail.com",
    "Port": 587,
    "UseSsl": true
  }
}
```

```pascal
type
  TEmailOptions = class(TOptions)
  published
    property Host  : string  ...;
    property Port  : Integer ...;
    property UseSsl: Boolean ...;
  end;

// Registro
services.Configure<TEmailOptions>('Email');

// Uso en cualquier servicio
constructor TEmailSender.Create(opt: IOptions<TEmailOptions>);
begin
  fHost := opt.Value.Host;
end;
```

---

### ¿Cómo uso variables de entorno en la configuración?

```json
{
  "Database": {
    "ConnectionString": "${DB_CONNECTION_STRING}",
    "Password": "${DB_PASSWORD}"
  }
}
```

Las variables de entorno se resuelven automáticamente al llamar `AddOptions`. No requiere código adicional.

---

### ¿Cómo gestiono secretos sensibles?

Para credenciales y claves privadas usa `Quick.Core.Configuration.Secrets`:

```pascal
services.AddOptions
  .AddSecrets('secrets.json');  // fichero fuera del repositorio
```

El fichero `secrets.json` NO debe incluirse en control de versiones (añadir a `.gitignore`).

---

## Testing

### ¿Cómo hago tests unitarios con servicios de QuickCore?

```pascal
// Crear el contenedor DI para tests
var services := TServiceCollection.Create;
services.AddSingleton<IProductRepository, TFakeProductRepository>;
services.AddSingleton<IProductService, TProductService>;
services.Build;

// Resolver y probar
var svc := services.Resolve<IProductService>;
var products := svc.GetAll;
Assert(products.Count > 0);
```

---

### ¿Cómo reemplazo un servicio real por un mock en tests?

```pascal
var services := TServiceCollection.Create;
// Registrar el mock en lugar de la implementación real
services.AddSingleton<IEmailSender>(TFakeEmailSender.Create);
services.AddSingleton<IOrderService, TOrderService>;
services.Build;
```

---

## Despliegue

### ¿Cómo instalo la app como servicio Windows?

```pascal
// La clase TServiceParameters gestiona los flags de instalación
// myapp.exe --install
// myapp.exe --remove
// myapp.exe --console  (modo consola para debug)
```

```pascal
uses Quick.Core.Extensions.Service.Windows;

begin
  var args := TCommandline<TServiceParameters>.Create;
  if args.Value.Install then
    TWindowsServiceManager.Install('MyAppService', 'My Application')
  else if args.Value.Remove then
    TWindowsServiceManager.Remove('MyAppService')
  else if args.Value.Console then
    RunAsConsole
  else
    RunAsWindowsService;
end.
```

---

### ¿Cómo despliego en Linux?

```pascal
uses Quick.Core.Extensions.Service.Linux;

// myapp --install    instala el daemon (systemd)
// myapp --remove     elimina el daemon
// myapp --detach     ejecuta como daemon (background)
```

La unidad `Quick.Core.Extensions.Service.Linux` genera automáticamente el unit file de systemd.

---

### ¿Qué versiones de Delphi son compatibles?

| Versión Delphi | Nombre | Estado |
|----------------|--------|--------|
| 22 (10.0 Seattle) | Delphi 10 | ✅ Soportado |
| 23 (10.1 Berlin) | Delphi 10.1 | ✅ Soportado |
| 24 (10.2 Tokyo) | Delphi 10.2 | ✅ Soportado |
| 25 (10.3 Rio) | Delphi 10.3 | ✅ Soportado |
| 26 (10.4 Sydney) | Delphi 10.4 | ✅ Soportado |
| 28 (11.0 Alexandria) | Delphi 11 | ✅ Soportado |
| 35 (12.0 Athens) | Delphi 12 | ✅ Soportado |

---

### ¿Qué plataformas son compatibles?

| Plataforma | Estado |
|-----------|--------|
| Windows 32-bit | ✅ |
| Windows 64-bit | ✅ |
| Linux 64-bit | ✅ |
| macOS | ✅ |
| Android | ✅ |
| iOS Device (32/64 bit) | ✅ |

---

## Ver también

- [Dependency Injection](wiki/Dependency-Injection.md)
- [MVC](wiki/MVC.md)
- [Security](wiki/Security.md)
- [Entity / ORM](wiki/Entity-ORM.md)
- [Migration Guide](Migration-Guide.md)
- [API Reference](API-Reference.md)
