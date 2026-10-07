# QuickCore — API Reference

> Versión: 2.x · Actualización: Mayo 2026  
> Todas las clases e interfaces públicas organizadas por módulo.

---

## Tabla de contenidos

1. [Dependency Injection](#1-dependency-injection)
2. [App Host](#2-app-host)
3. [MVC / HTTP Server](#3-mvc--http-server)
4. [Controller](#4-controller)
5. [Action Attributes](#5-action-attributes)
6. [Action Results](#6-action-results)
7. [Entity / ORM](#7-entity--orm)
8. [Security — Authentication](#8-security--authentication)
9. [Security — Authorization](#9-security--authorization)
10. [Security — JWT](#10-security--jwt)
11. [Security — Identity](#11-security--identity)
12. [Caching](#12-caching)
13. [AutoMapper](#13-automapper)
14. [Background Services](#14-background-services)
15. [Health Checks](#15-health-checks)
16. [Message Queue](#16-message-queue)
17. [TaskControl](#17-taskcontrol)
18. [Localization](#18-localization)
19. [Commandline](#19-commandline)
20. [Serialization](#20-serialization)
21. [Logging](#21-logging)
22. [Excepciones](#22-excepciones)
23. [Resilience](#23-resilience)
24. [Mediator / CQRS](#24-mediator--cqrs)
25. [HybridCache](#25-hybridcache)
26. [FluentValidation Builder](#26-fluentvalidation-builder)
27. [Distributed Tracing (OpenTelemetry)](#27-distributed-tracing-opentelemetry)
28. [Data Protection](#28-data-protection)
29. [OptionsMonitor / OptionsSnapshot](#29-optionsmonitor--optionssnapshot)
30. [Rate Limiting](#30-rate-limiting)
31. [Entity Migrations](#31-entity-migrations)
32. [Repository Pattern](#32-repository-pattern)
33. [Unit of Work](#33-unit-of-work)

---

## 1. Dependency Injection

**Unidad:** `Quick.Core.DependencyInjection`

### `TServiceCollection`

Punto de entrada central para registrar servicios, opciones y extensiones.

| Miembro | Descripción |
|---------|-------------|
| `Create` | Constructor. Crea el contenedor DI y el servidor de opciones. |
| `CreateFromStartup<T>` | Alternativa estática: construye la colección ejecutando `T.ConfigureServices`. |
| `AddSingleton<I,T>([name])` | Registra `T` como `I` con vida útil Singleton. |
| `AddTransient<I,T>([name])` | Registra `T` como `I` con vida útil Transient. |
| `AddScoped<I,T>([name])` | Registra `T` como `I` con vida útil Scoped. |
| `AddSingleton<I>(instance)` | Registra una instancia ya creada como Singleton. |
| `AddKeyedSingleton<I,T>(key)` | Singleton con clave (named service). |
| `AddKeyedTransient<I,T>(key)` | Transient con clave. |
| `AddKeyedScoped<I,T>(key)` | Scoped con clave. |
| `GetKeyedService<T>(key)` | Resuelve un servicio por clave. |
| `AddTypedFactory<I,T>` | Registra una fábrica tipada (patrón Factory). |
| `AddSimpleFactory<I,T>` | Registra una fábrica simple (constructor sin parámetros). |
| `Configure<T>([section])` | Vincula una sección de `appsettings.json` con `TOptions<T>`. |
| `Configure<T>(proc)` | Configura opciones mediante un delegado. |
| `GetConfiguration<T>` | Obtiene la instancia configurada de opciones `T`. |
| `Resolve<T>([name])` | Resuelve un servicio registrado. |
| `CreateScope` | Crea un `IServiceScope` para servicios Scoped. |
| `AddOptions(...)` | Habilita el sistema de opciones (JSON o YAML). |
| `AddLogging(logger)` | Configura el servicio de logging. |
| `AddCommandline<T>` | Registra el parser de línea de comandos. |
| `Build` | Construye el contenedor. Debe llamarse antes de resolver. |
| `Extension<T>` | Accede a una extensión de DI (p. ej. `Extension<TEntityServiceCollectionExtension>`). |

### `IServiceScope` / `TServiceScope`

| Miembro | Descripción |
|---------|-------------|
| `ServiceProvider` | `TServiceProvider` con ciclo de vida de este scope. |
| `GetService<T>([name])` | Resuelve y cachea el servicio dentro del scope. |

### `TServiceProvider`

| Miembro | Descripción |
|---------|-------------|
| `GetService<T>` | Resuelve `T` del contenedor. |
| `GetService(typeInfo)` | Resuelve por `PTypeInfo`. |
| `CreateScope` | Crea un scope hijo. |
| `ActivatorUtilities` | Fabrica instancias con inyección de dependencias. |
| `Serializer` | Acceso al serializador configurado. |

### `TStartupBase`

Clase base para la configuración de servicios.

```pascal
type
  TMyStartup = class(TStartupBase)
  public
    class procedure ConfigureServices(services: TServiceCollection); override;
  end;
```

### `TAppServices`

Record de acceso rápido a los servicios del contenedor.

| Miembro | Descripción |
|---------|-------------|
| `DependencyInjector` | Contenedor IoC subyacente. |
| `Options` | Contenedor de opciones (`TOptionsContainer`). |
| `Serializer` | Serializador registrado (`ISerializers`). |
| `Logger` | Logger registrado (`ILogger`). |

### `TActivatorUtilities`

| Miembro | Descripción |
|---------|-------------|
| `CreateInstance<T>(class)` | Instancia una clase inyectando dependencias del contenedor. |
| `CreateInstance<T>` | Versión sin parámetros de clase (usa tipo inferido). |

---

## 2. App Host

**Unidades:** `Quick.Core.App`, `Quick.Core.Extensions.Hosting`

### `TCoreApp`

Host básico para aplicaciones con DI.

| Miembro | Descripción |
|---------|-------------|
| `Create(startupClass)` | Inicializa DI ejecutando `startupClass.ConfigureServices`. |
| `Start` | Arranca todos los `IHostedService` registrados. |
| `Stop` | Detiene todos los `IHostedService` registrados. |

### `THostBuilder`

Builder fluido para `TGenericHost`.

| Miembro | Descripción |
|---------|-------------|
| `ConfigureServices(proc)` | Añade un delegado de configuración de servicios. |
| `Build` | Construye el `TGenericHost`. |

### `TGenericHost`

Host genérico para consola/servicio con soporte de `IHostedService`.

| Miembro | Descripción |
|---------|-------------|
| `Start` | Inicia todos los hosted services y bloquea hasta `Stop`. |
| `Stop` | Detiene todos los hosted services. |
| `Run` | Equivalente a `Start` sin bloquear el hilo llamador. |
| `Services` | Acceso al `TServiceCollection`. |

---

## 3. MVC / HTTP Server

**Unidad:** `Quick.Core.Mvc`

### `TMVCServer`

Servidor HTTP con pipeline de middleware MVC.

| Miembro | Descripción |
|---------|-------------|
| `Create(httpServer)` | Constructor con servidor HTTP externo. |
| `Create(host, port, ssl)` | Constructor con parámetros de escucha. |
| `UseStartup<T>` | Aplica la clase Startup (`T : TStartupMvc`). |
| `AddController<T>` | Registra un controller explícitamente. |
| `AddControllers` | Registra todos los controllers anotados con `[Route]`. |
| `MapRoute(name, class, url)` | Mapeo manual de rutas. |
| `Use(delegFunc)` | Añade un middleware en línea (func). |
| `UseMiddleware<T>` | Añade un middleware tipado. |
| `UseRouting` | Habilita el enrutamiento por atributos. |
| `UseAuthentication` | Habilita el middleware de autenticación. |
| `UseAuthorization` | Habilita el middleware de autorización. |
| `UseCors` | Habilita CORS. |
| `UseStaticFiles` | Habilita archivos estáticos desde `wwwroot/`. |
| `UseSwagger(title, version, desc)` | Genera el endpoint `/swagger`. |
| `UseSession` | Habilita sesiones HTTP. |
| `UseRateLimiting(max, windowSecs)` | Limita peticiones por IP. |
| `UseResponseCompression` | Compresión gzip/deflate de respuestas. |
| `UseExceptionHandler([proc])` | Middleware de manejo global de excepciones. |
| `UseHttpsRedirection` | Redirige HTTP → HTTPS. |
| `UseHsts` | Añade la cabecera HSTS. |
| `UseLogRequest` | Loguea cada petición entrante. |
| `UseApiVersioning` | Soporte de versiones de API. |
| `UseMVC` | Habilita el pipeline MVC (router + controladores). |
| `UseMustachePages` / `UseLiquidPages` | Activa el motor de vistas. |
| `MapGet/Post/Put/Delete(url, handler)` | Minimal API: registra endpoints sin controller. |
| `MapVerbs(url, verbs, handler)` | Minimal API con verbos múltiples. |
| `UsePathBase(path)` | Prefijo de ruta base. |
| `UseWebRoot(path)` | Ruta del directorio web. |
| `Start` / `Stop` | Arranca/detiene el servidor HTTP. |
| `Services` | Acceso al `TServiceCollection` del servidor. |
| `Status` | `TMVCServerStatus`: `mvsStarting/mvsStarted/mvsStopping/mvsStopped`. |

### `TStartupMvc`

Clase base para la configuración del pipeline MVC.

```pascal
type
  TMyStartup = class(TStartupMvc)
  public
    class procedure ConfigureServices(services: TServiceCollection); override;
    class procedure Configure(app: TMVCServer); override;
  end;
```

---

## 4. Controller

**Unidad:** `Quick.Core.Mvc.Controller`

### `THttpController`

Clase base para todos los controllers MVC.

| Miembro | Tipo | Descripción |
|---------|------|-------------|
| `HttpContext` | `THttpContextBase` | Contexto HTTP de la petición actual. |
| `Request` | `IHttpRequest` | Petición HTTP. |
| `Response` | `IHttpResponse` | Respuesta HTTP. |
| `User` | `TClaimsPrincipal` | Principal del usuario autenticado. |
| `Logger` | `ILogger` | Logger inyectado. |
| `ViewData` | `TViewDataDictionary` | Datos para la vista. |
| `Route` | `THttpRoute` | Ruta que activó esta acción. |
| `Ok([msg])` | `TStatusResult` | Respuesta 200. |
| `Accepted([msg])` | `TStatusResult` | Respuesta 202. |
| `BadRequest([msg])` | `TStatusResult` | Respuesta 400. |
| `Unauthorized([msg])` | `TStatusResult` | Respuesta 401. |
| `Forbid([msg])` | `TStatusResult` | Respuesta 403. |
| `NotFound([msg])` | `TStatusResult` | Respuesta 404. |
| `StatusCode(code, [msg])` | `TStatusResult` | Respuesta con código personalizado. |
| `Json(obj, [onlyPublished])` | `TJsonResult` | Serializa objeto a JSON. |
| `Json(jsonText)` | `TJsonResult` | Respuesta con texto JSON literal. |
| `Content(text)` | `TContentResult` | Respuesta con texto plano. |
| `View([name])` | `TViewResult` | Renderiza una vista. |
| `Redirect(url)` | `TRedirectResult` | Redirección 302. |
| `RedirectPermanent(url)` | `TRedirectResult` | Redirección 301. |
| `AuthorizeResource(obj, policy)` | `Boolean` | Autorización basada en recurso. |

---

## 5. Action Attributes

**Unidad:** `Quick.Core.Mvc.Controller`

### Routing

| Atributo | Descripción |
|----------|-------------|
| `[Route('url')]` | Ruta del controller o de la acción. Soporta `[controller]` y `[action]`. |
| `[HttpGet('url')]` | Mapea la acción a GET. |
| `[HttpPost('url')]` | Mapea la acción a POST. |
| `[HttpPut('url')]` | Mapea la acción a PUT. |
| `[HttpDelete('url')]` | Mapea la acción a DELETE. |
| `[AcceptVerbs(verbs)]` | Acepta múltiples verbos HTTP. |
| `[ActionName('name')]` | Nombre de acción personalizado. |
| `[NonAction]` | Excluye el método del enrutamiento MVC. |
| `[ApiController]` | Marca la clase como API controller. |
| `[ApiVersion('v', deprecated)]` | Declara la versión de API. |

### Autorización

| Atributo | Descripción |
|----------|-------------|
| `[Authorize([roles])]` | Requiere autenticación; opcionalmente uno o más roles. |
| `[AuthorizePolicy('name')]` | Aplica una política de autorización con nombre. |
| `[AllowAnonymous]` | Permite acceso sin autenticación. |

### Rendimiento y comportamiento

| Atributo | Descripción |
|----------|-------------|
| `[OutputCache(durationMs)]` | Cachea la respuesta durante N milisegundos. |
| `[RateLimit]` | Aplica rate limiting a esta acción. |

### Binding de parámetros

| Atributo | Descripción |
|----------|-------------|
| `[FromBody]` | Deserializa el body JSON al parámetro. |
| `[FromQuery('name')]` | Lee el parámetro del query string. |
| `[FromHeader('name')]` | Lee el parámetro de la cabecera HTTP. |
| `[FromKeyedServices('key')]` | Inyecta un servicio con clave desde DI. |

### Documentación Swagger

| Atributo | Descripción |
|----------|-------------|
| `[SwaggerOperation('summary')]` | Descripción de la operación en Swagger. |
| `[ProducesResponseType(type, code)]` | Documenta un tipo de respuesta en Swagger. |

---

## 6. Action Results

**Unidad:** `Quick.Core.Mvc.ActionResult`

| Clase | Código HTTP | Uso en controller |
|-------|-------------|-------------------|
| `TStatusResult` | configurable | `Ok()`, `Accepted()`, `BadRequest()`, etc. |
| `TJsonResult` | 200 | `Json(obj)` |
| `TContentResult` | 200 | `Content('texto')` |
| `TViewResult` | 200 | `View([name])` |
| `TRedirectResult` | 302/301 | `Redirect(url)`, `RedirectPermanent(url)` |

---

## 7. Entity / ORM

**Unidades:** `Quick.Core.Entity`, `Quick.Core.Entity.DAO`, `Quick.Core.Entity.Database`, `Quick.Core.Entity.Repository`, `Quick.Core.Entity.UnitOfWork`, `Quick.Core.Entity.Migrations`

### Clases base de entidades

| Clase | Propiedades extra | Descripción |
|-------|-------------------|-------------|
| `TEntity` | — | Base mínima con `Id: TAutoID`. |
| `TEntityTS` | `CreatedAt`, `UpdatedAt` | Con timestamps automáticos. |
| `TEntitySD` | `IsDeleted: Boolean` | Con Soft Delete. |
| `TEntityTSSD` | `CreatedAt`, `UpdatedAt`, `IsDeleted` | Timestamps + Soft Delete. |
| `TEntityRV` | `RowVersion: Integer` | Con concurrencia optimista. |
| `TEntityAudit` | `CreatedBy`, `ModifiedBy`, `CreatedAt`, `UpdatedAt` | Con auditoría completa. |

### Atributos de entidad

| Atributo | Nivel | Descripción |
|----------|-------|-------------|
| `[Table('nombre')]` / `[MapField('nombre')]` | Clase | Nombre de tabla en DB. |
| `[Key]` | Propiedad | Clave primaria. |
| `[StringLength(n)]` | Propiedad | Longitud máxima del campo `VARCHAR`. |
| `[DecimalLength(p,s)]` | Propiedad | Precisión y escala `DECIMAL`. |
| `[Index(['campo1','campo2'])]` | Propiedad/Clase | Índice de base de datos. |
| `[SoftDelete]` | Clase | Activa borrado lógico (`IsDeleted`). |
| `[ForeignKey('campo')]` | Propiedad | Define clave foránea. |
| `[HasMany(T)]` | Propiedad | Relación 1-N (colección de navegación). |
| `[HasOne(T)]` | Propiedad | Relación 1-1 (entidad de navegación). |
| `[MapName('nombre')]` | Propiedad | Alias del nombre de columna. |

### `IDBContext` / `TDBContext`

| Miembro | Descripción |
|---------|-------------|
| `Connection` | `TDBConnectionSettings` — cadena de conexión y proveedor. |
| `Models` | Lista de modelos registrados (`TEntityModels`). |
| `Indexes` | Índices del esquema (`TEntityIndexes`). |
| `Connect` | Abre la conexión a la base de datos. |
| `IsConnected` | Indica si la conexión está activa. |
| `Add(entity)` | INSERT de la entidad. |
| `Update(entity)` | UPDATE de la entidad. |
| `AddOrUpdate(entity)` | INSERT OR UPDATE (upsert). |
| `Delete(entity)` | DELETE (o soft-delete si aplica). |
| `BeginTransaction` | Inicia una transacción. |
| `CommitTransaction` | Confirma la transacción. |
| `RollbackTransaction` | Revierte la transacción. |
| `Seed(proc)` | Ejecuta `proc` para insertar datos semilla. |
| `GetTableNames` | Lista de tablas en la base de datos. |
| `GetFieldNames(table)` | Columnas de una tabla. |

### `TDBSet<T>`

Conjunto de datos de una entidad; accesible como propiedad de `TDBContext`.

| Miembro | Descripción |
|---------|-------------|
| `Add(entity)` | INSERT. |
| `AddOrUpdate(entity)` | Upsert. |
| `Update(entity)` | UPDATE. |
| `Delete(entity)` | DELETE. |
| `Where(clause)` | Filtro SQL libre. |
| `Where(format, values)` | Filtro SQL con parámetros. |
| `Where(predicate)` | Filtro lambda in-memory (`TPredicate<T>`). |
| `Include(propName)` | Carga ansiosa (eager loading) de navegación. |
| `SelectFirst` | Primera fila o `nil`. |
| `SelectLast` | Última fila o `nil`. |
| `Select` | Devuelve `IDBSetResult<T>` (enumerable). |
| `SelectTop(n)` | Devuelve las primeras N filas. |
| `OrderBy(fields)` | Orden ascendente. |
| `OrderByDescending(fields)` | Orden descendente. |
| `Count` | Número de registros. |
| `Sum(field)` | Suma de un campo numérico. |

### `IRepository<T>` / `TEntityRepository<T>`

| Miembro | Descripción |
|---------|-------------|
| `GetById(id)` | Busca por clave primaria. |
| `GetAll` | Devuelve todas las entidades. |
| `Add(entity)` | INSERT. |
| `Update(entity)` | UPDATE. |
| `AddOrUpdate(entity)` | Upsert. |
| `Delete(entity)` | DELETE. |
| `DeleteById(id)` | DELETE por clave primaria. |
| `Count` | Total de registros. |
| `Exists(id)` | Comprueba existencia por ID. |
| `Find(where)` | Lista filtrada por cláusula WHERE. |
| `FindFirst(where)` | Primera entidad del filtro. |
| `Query` | Acceso al `TDBSet<T>` subyacente para LINQ. |

### `IUnitOfWork` / `TUnitOfWork`

```pascal
uow.Execute(procedure
  begin
    context.Products.Add(product);
    context.Orders.Add(order);
  end);  // commit automático; rollback si hay excepción
```

### Migraciones

**Unidad:** `Quick.Core.Entity.Migrations`

| Clase / Miembro | Descripción |
|-----------------|-------------|
| `TMigration` | Clase base: `Up` (aplicar) / `Down` (revertir). |
| `TMigrationsManager` | Gestiona la tabla `__MigrationsHistory`. |
| `ApplyMigrations` | Ejecuta migraciones pendientes en orden. |
| `RollbackLast` | Revierte la última migración aplicada. |
| `GetAppliedMigrations` | Lista de migraciones ya aplicadas. |
| `TEntityMigrationsHistory` | Entidad interna de la tabla de historial. |

---

## 8. Security — Authentication

**Unidades:** `Quick.Core.Security.Authentication`, `Quick.Core.Security.Claims`, `Quick.Core.Extensions.Authentication.*`

### Interfaces principales

| Interfaz | Descripción |
|----------|-------------|
| `IAuthenticationHandler` | `Initialize`, `Authenticate`, `Challenge`, `Forbid`. |
| `IAuthenticationSignInHandler` | Extiende con `SignIn`. |
| `IAuthenticationSignOutHandler` | Extiende con `SignOut`. |
| `IAuthenticationService` | Orquesta todos los handlers: `Authenticate/Challenge/Forbid/SignIn/SignOut`. |
| `IAuthenticationSchemeProvider` | Registra y recupera esquemas por nombre. |
| `IAuthenticationHandlerProvider` | Resuelve el handler para un esquema dado. |

### `TAuthenticateResult`

Record de resultado de autenticación.

| Miembro | Descripción |
|---------|-------------|
| `Succeeded` | `True` si la autenticación fue exitosa. |
| `Principal` | `TClaimsPrincipal` del usuario autenticado. |
| `Ticket` | `IAuthenticationTicket` con claims y propiedades. |
| `Success(ticket)` | Crea un resultado exitoso. |
| `Fail(exception)` | Crea un resultado fallido. |
| `NoResult` | Resultado neutro (no manejado). |

### `TAuthenticationProperties`

| Miembro | Descripción |
|---------|-------------|
| `IsPersistent` | Cookie persistente (recordarme). |
| `ExpiresUtc` | Expiración UTC. |
| `IssuedUtc` | Emisión UTC. |
| `RedirectUri` | URI de redirección post-login. |
| `AllowRefresh` | Permite renovar el ticket. |
| `Items` | Diccionario de propiedades adicionales. |

### Claims

**Unidad:** `Quick.Core.Security.Claims`

| Clase / Miembro | Descripción |
|-----------------|-------------|
| `TClaim` | Par `Type: string` / `Value: string`. |
| `TClaimsIdentity` | Colección de claims + `AuthenticationType`. |
| `TClaimsPrincipal` | Colección de `TClaimsIdentity`. |
| `User.FindFirstValue(type)` | Obtiene el primer valor del claim indicado. |
| `User.IsInRole(role)` | Comprueba si el usuario tiene el rol. |
| `User.Identity.IsAuthenticated` | `True` si hay una identidad autenticada. |

### Handlers disponibles

| Handler | Esquema | Unidad |
|---------|---------|--------|
| `TJwtBearerHandler` | `Bearer` | `Quick.Core.Extensions.Authentication.Jwt` |
| `TApiKeyHandler` | `ApiKey` | `Quick.Core.Extensions.Authentication.ApiKey` |
| `TCookieAuthenticationHandler` | `Cookies` | `Quick.Core.Extensions.Authentication.Cookie` |
| `TOAuth2Handler` | `OAuth2` | `Quick.Core.Extensions.Authentication.OAuth2` |

### Registro de esquemas (DI)

```pascal
services.AddAuthentication
  .AddJwtBearer(procedure(opt: TJwtOptions)
    begin opt.Secret := '...'; end)
  .AddApiKey(procedure(opt: TApiKeyOptions)
    begin opt.HeaderName := 'X-Api-Key'; end)
  .AddCookie;
```

---

## 9. Security — Authorization

**Unidades:** `Quick.Core.Security.Authorization`, `Quick.Core.Extensions.Authorization`

### Interfaces

| Interfaz | Descripción |
|----------|-------------|
| `IAuthorizationService` | `Authorize(user, resource, policy)` / `Authorize(user, policy)`. |
| `IAuthorizationHandler<T>` | Handler de recurso: `HandleRequirement(ctx, resource)`. |

### `TAuthorizationPolicy` / `TAuthorizationPolicyBuilder`

| Miembro | Descripción |
|---------|-------------|
| `RequireAuthenticatedUser` | El usuario debe estar autenticado. |
| `RequireRole(roles)` | Requiere uno o más roles. |
| `RequireClaim(type, [values])` | Requiere un claim específico. |
| `Build` | Construye el objeto `TAuthorizationPolicy`. |

### Registro de políticas

```pascal
services.AddAuthorization(procedure(opt: TAuthorizationOptions)
  begin
    opt.AddPolicy('AdminOnly',
      TAuthorizationPolicyBuilder.New
        .RequireRole('Admin')
        .Build);
  end);
```

---

## 10. Security — JWT

**Unidades:** `Quick.Core.Security.Jwt`, `Quick.Core.Extensions.Authentication.Jwt`

### `TJwtOptions` (hereda de `TOptions`)

| Propiedad | Tipo | Descripción |
|-----------|------|-------------|
| `Secret` | `string` | Clave HMAC-SHA256. |
| `Issuer` | `string` | Emisor del token. |
| `Audience` | `string` | Audiencia del token. |
| `ExpiryMinutes` | `Integer` | Minutos de validez (0 = sin expiración). |
| `ValidateIssuer` | `Boolean` | Valida el campo `iss`. |
| `ValidateAudience` | `Boolean` | Valida el campo `aud`. |
| `ValidateLifetime` | `Boolean` | Valida `exp`. |

### `IJwtTokenService` / `TJwtTokenService`

| Miembro | Descripción |
|---------|-------------|
| `GenerateToken(claims)` | Genera un JWT firmado con los claims dados. |
| `ValidateToken(token)` | Valida la firma y las opciones; devuelve `TClaimsPrincipal` o `nil`. |
| `GetUserFromToken(token)` | Extrae el principal del token sin validar expiración. |

---

## 11. Security — Identity

**Unidades:** `Quick.Core.Identity`, `Quick.Core.Security.UserManager`, `Quick.Core.Security.Totp`, `Quick.Core.Identity.Store.Entity`

### Clases

| Clase | Descripción |
|-------|-------------|
| `TIdentityUser<TKey>` | Entidad de usuario con `Id`, `UserName`, `PasswordHash`, `Email`, `SecurityStamp`, etc. |
| `TIdentityRole<TKey>` | Entidad de rol con `Id` y `Name`. |
| `TIdentityOptions` | Opciones globales. Contiene `PasswordOptions`, `LockoutOptions`, `UserOptions`. |
| `TPasswordOptions` | `RequireDigit`, `RequireLowercase`, `RequireUppercase`, `RequireNonAlphanumeric`, `MinLength`. |
| `TLockoutOptions` | `AllowedForNewUsers`, `MaxFailedAttempts`, `DefaultLockoutTimeSpan`. |
| `TUserManager<T>` | `CreateUser/FindById/FindByName/CheckPassword/ChangePassword/LockoutUser`, etc. |
| `TTotpService` | Genera y valida códigos TOTP (2FA). |

### Registro

```pascal
services.AddIdentity<TUser, TRole>
  .AddEntityStore<TAppDbContext>;
```

---

## 12. Caching

**Unidades:** `Quick.Core.Caching.Abstractions`, `Quick.Core.Extensions.Caching.Memory`, `Quick.Core.Extensions.Caching.Redis`

### `IMemoryCache` / `IDistributedCache`

| Método | Descripción |
|--------|-------------|
| `SetValue<T>(key, value, [ttlSecs])` | Guarda un valor (con TTL opcional). |
| `GetValue<T>(key)` | Recupera un valor; lanza si no existe. |
| `TryGetValue<T>(key, out value)` | Recupera un valor; devuelve `False` si no existe. |
| `RemoveValue(key)` | Elimina una entrada. |
| `Flush` | Limpia toda la caché. |
| `Refresh(key)` | Renueva el TTL de una entrada. |

### Opciones

| Clase | Propiedades clave |
|-------|-------------------|
| `TMemoryCacheOptions` | `Compression`, `MaxSize`, `PurgeInterval`. |
| `TRedisCacheOptions` | `Host`, `Port`, `Password`, `DatabaseNumber`, `PoolSize`, `ConnectionTimeout`, `MaxSize`. |

### Registro

```pascal
// In-Memory
services.AddMemoryCache;
services.AddDistributedMemoryCache;

// Redis
services.AddDistributedRedisCache(procedure(opt: TRedisCacheOptions)
  begin
    opt.Host := 'localhost';
    opt.Port := 6379;
  end);
```

### HybridCache (L1 + L2)

> Ver sección [25. HybridCache](#25-hybridcache) para la API completa.

```pascal
// Registro rápido
services.Extension<TMemoryCacheServiceExtension>.AddMemoryCache;
services.Extension<THybridCacheServiceExtension>.AddHybridCache(procedure(o: THybridCacheOptions)
  begin
    o.DefaultLocalExpirationMs  := 60_000;   // 1 min L1
    o.DefaultRemoteExpirationMs := 600_000;  // 10 min L2
  end);
```

---

## 13. AutoMapper

**Unidades:** `Quick.Core.AutoMapper`, `Quick.Core.Extensions.AutoMapper`

### Tipos principales

| Tipo | Descripción |
|------|-------------|
| `IMapper` | Interfaz del mapeador (`Map<T>(src)`, `Map(src, dst)`). |
| `TAutoMapper` | Implementación del mapeador. |
| `TProfile` | Clase base para definir mapeos. |
| `TProfileMap` | Mapeo de un par de tipos. |
| `TMapProc` | Delegado `procedure(src, dst)`. |
| `TValueConverterFunc` | Delegado `function(value): TValue`. |

### Métodos de `IMapper`

| Método | Descripción |
|--------|-------------|
| `Map<TDest>(source)` | Crea una instancia de `TDest` mapeando desde `source`. |
| `Map(source, dest)` | Mapea sobre una instancia destino existente. |
| `AssertConfigurationIsValid` | Comprueba que todos los mapeos tienen propiedades coincidentes. |

### Métodos de `TProfile.Configure`

```pascal
CreateMap<TSource, TDest>
  .ForMember('DestProp', 'SrcProp')     // renombrar
  .ReverseMap                            // mapeo inverso automático
  .Condition(func)                       // saltar si predicate = False
  .ConvertUsing('Prop', func)            // transformar valor
  .NullSubstitute('Prop', value)         // valor si nil/vacío
  .BeforeMap(proc)                       // hook pre-mapeo
  .AfterMap(proc);                       // hook post-mapeo
```

### Registro

```pascal
services.AddAutoMapper(procedure(cfg: TAutoMapper)
  begin
    cfg.AddProfile<TMyProfile>;
  end);
```

---

## 14. Background Services

**Unidad:** `Quick.Core.Extensions.Hosting.BackgroundService`

### Interfaces / Clases

| Tipo | Descripción |
|------|-------------|
| `IHostedService` | `StartAsync` / `StopAsync`. |
| `TBackgroundService` | Clase base; implementa `ExecuteAsync(cancelToken)`. |
| `IHostedServiceManager` | `Initialize(services)`, `StartAll`, `StopAll`. |

### `TBackgroundService`

```pascal
type
  TMyWorker = class(TBackgroundService)
  protected
    procedure ExecuteAsync; override;
  end;

procedure TMyWorker.ExecuteAsync;
begin
  while not CancelRequested do
  begin
    DoWork;
    Sleep(1000);
  end;
end;
```

### Registro

```pascal
services.AddHostedService<TMyWorker>;
```

---

## 15. Health Checks

**Unidades:** `Quick.Core.Extensions.HealthChecks`, `Quick.Core.Extensions.HealthChecks.*`, `Quick.Core.Mvc.Extensions.HealthChecks`

### Tipos

| Tipo | Descripción |
|------|-------------|
| `IHealthCheck` | Interfaz: `CheckHealth → THealthCheckMetric`. |
| `THealthStatus` | Enum: `hcsNotChecked`, `hcsPassed`, `hcsFailed`. |
| `THealthCheckMetric` | Resultado: `Status`, `Name`, `Description`. |
| `IHealthChecksService` | Ejecuta todos los checks registrados. |

### Checks integrados

| Check | Unidad |
|-------|--------|
| `TUrlHealthCheck` | `Quick.Core.Extensions.HealthChecks` |
| `TSqlServerHealthCheck` | `Quick.Core.Extensions.HealthChecks.SqlServer` |
| `TEntityHealthCheck` | `Quick.Core.Extensions.HealthChecks.Entity` |
| `TRedisHealthCheck` | `Quick.Core.Extensions.HealthChecks.Redis` |

### Registro y endpoint

```pascal
// ConfigureServices
services.AddHealthChecks
  .AddUrlCheck('API', 'https://api.example.com/ping')
  .AddEntityCheck<TAppDbContext>('Database');

// Configure
app.UseHealthChecks;   // GET /HealthChecks → JSON
```

---

## 16. Message Queue

**Unidades:** `Quick.Core.MessageQueue.Abstractions`, `Quick.Core.MessageQueue`, `Quick.Core.Extensions.MessageQueue.Redis`

### `IMessageQueue<T>`

| Método | Descripción |
|--------|-------------|
| `Push(msg, [priority])` | Encola un mensaje. |
| `Pop(timeout)` | Desencola; devuelve `TMSQWaitResult`. |
| `Remove(msg)` | Confirma el procesamiento (elimina de la cola de trabajo). |
| `Failed(msg, [reason])` | Mueve el mensaje a la cola de errores. |

### `TMSQWaitResult`

| Valor | Descripción |
|-------|-------------|
| `wrOk` | Mensaje recibido. |
| `wrTimeout` | Timeout sin mensaje. |
| `wrError` | Error durante la espera. |

### Registro (Redis)

```pascal
services.AddRedisMessageQueue<TOrderMessage>(procedure(opt: TRedisMessageQueueOptions)
  begin
    opt.Host := 'localhost';
    opt.QueueName := 'orders';
    opt.ReliableQueue := True;
  end);
```

---

## 17. TaskControl

**Unidad:** `Quick.Core.TaskControl`

### `ITaskControl`

| Miembro | Descripción |
|---------|-------------|
| `BackgroundTasks` | Pool de workers (`TBackgroundTasks`). |
| `ScheduledTasks` | Tareas periódicas (`TScheduledTasks`). |

### `TBackgroundTasks`

| Método | Descripción |
|--------|-------------|
| `AddTask(proc, [name], [callback])` | Encola una tarea anónima o nombrada. |
| `GetCurrentRunningTasksJson` | JSON con las tareas en ejecución. |

### `TScheduledTasks`

| Método | Descripción |
|--------|-------------|
| `AddTask(intervalMs, proc, [name])` | Registra una tarea periódica con intervalo en ms. |

### `TTaskControlSettings`

| Propiedad | Tipo | Descripción |
|-----------|------|-------------|
| `ConcurrentWorkers` | `Integer` [1..1000] | Número de workers paralelos. |

### Registro

```pascal
services.AddTaskControl(procedure(opt: TTaskControlSettings)
  begin
    opt.ConcurrentWorkers := 4;
  end);
```

---

## 18. Localization

**Unidades:** `Quick.Core.Localization.Abstractions`, `Quick.Core.Extensions.Localization`

### Tipos

| Tipo | Descripción |
|------|-------------|
| `IStringLocalization` | `Items[key]`, `Items[key, params]`, `Culture`. |
| `TStringLocalization` | Implementación con `TFileLocalizationStore`. |
| `ILocalizationStore` | Carga traducciones para una cultura. |
| `TFileLocalizationStore` | Carga desde archivos JSON en `locales/`. |

### `TLocalizationOptions`

| Propiedad | Descripción |
|-----------|-------------|
| `AddCulture(code)` | Añade una cultura soportada (p. ej. `es-ES`). |
| `AddIfNotFound` | Devuelve la clave tal cual si no hay traducción. |

### Registro

```pascal
services.AddLocalization(procedure(opt: TLocalizationOptions)
  begin
    opt.AddCulture('en-US');
    opt.AddCulture('es-ES');
    opt.AddIfNotFound := True;
  end);
```

### Formato de archivos (`locales/es-ES.json`)

```json
{
  "Hello": "Hola",
  "Welcome": "Bienvenido, {0}"
}
```

---

## 19. Commandline

**Unidad:** `Quick.Core.Commandline`

### Tipos

| Tipo | Descripción |
|------|-------------|
| `TParameters` | Clase base para definir argumentos de la app. |
| `TServiceParameters` | Parámetros predefinidos para servicios/daemons. |
| `ICommandline<T>` | Interfaz: `Value: T` con los parámetros parseados. |
| `TCommandline<T>` | Implementación; parsea `ParamStr` al construirse. |

### `TServiceParameters`

| Propiedad | Flag CLI | Descripción |
|-----------|----------|-------------|
| `Install` | `--install` | Instala el servicio. |
| `Remove` | `--remove` | Desinstala el servicio. |
| `Console` | `--console` | Ejecuta en consola (no como servicio). |
| `Instance` | `--instance` | Nombre de instancia. |
| `Silent` | `--silent` | Modo silencioso. |
| `Detach` *(Linux)* | `--detach` | Daemonize. |

### Atributos de parámetros

| Atributo | Descripción |
|----------|-------------|
| `[ParamName('n')]` | Nombre del argumento en CLI. |
| `[ParamHelp('texto', 'default')]` | Texto de ayuda y valor por defecto. |
| `[ParamRequired]` | Parámetro obligatorio. |
| `[ParamValueIsNextParam]` | El valor está en el siguiente token. |
| `[ParamSwitchChar('/')]` | Carácter de switch alternativo. |
| `[ParamCommand]` | El parámetro es un subcomando. |
| `[CommandDescription('texto')]` | Descripción del comando. |

### Registro

```pascal
services.AddCommandline<TMyParams>;
```

---

## 20. Serialization

**Unidades:** `Quick.Core.Serialization.Abstractions`, `Quick.Core.Serialization.Json`, `Quick.Core.Serialization.Yaml`

### `ISerializer`

| Método | Descripción |
|--------|-------------|
| `Serialize<T>(obj)` | Objeto → string. |
| `Deserialize<T>(str)` | String → `T`. |
| `SerializeToFile<T>(obj, path)` | Escribe a fichero. |
| `DeserializeFromFile<T>(path)` | Lee desde fichero. |

### Implementaciones disponibles

| Clase | Formato |
|-------|---------|
| `TJsonSerializer` | JSON |
| `TYamlSerializer` | YAML |

---

## 21. Logging

**Unidades:** `Quick.Core.Logging.Abstractions`, `Quick.Core.Logging`

### `ILogger`

| Método | Nivel |
|--------|-------|
| `Debug(msg)` | Debug |
| `Info(msg)` | Information |
| `Warn(msg)` | Warning |
| `Error(msg)` | Error |
| `Critical(msg)` | Critical |

Registro mediante `services.AddLogging(loggerInstance)`.

---

## 22. Excepciones

| Excepción | Módulo | Descripción |
|-----------|--------|-------------|
| `EServiceConfigError` | DI | Error de configuración de servicios. |
| `EServiceBuildError` | DI | Fallo al construir el contenedor. |
| `EOptimisticConcurrencyException` | Entity | Conflicto de concurrencia optimista. |
| `EAuthenticacionScheme` | Auth | Esquema de autenticación no válido. |
| `EAuthenticationProperty` | Auth | Propiedad de autenticación inválida. |
| `EAuthenticationHandler` | Auth | Error en el handler de autenticación. |
| `EResilienceError` | Resilience | Base de todas las excepciones de resiliencia. |
| `ECircuitOpenException` | Resilience | Circuito abierto — llamada bloqueada por Circuit Breaker. |
| `ETimeoutException` | Resilience | Timeout de política de timeout. |
| `ERetryExhaustedException` | Resilience | Todos los reintentos agotados. |
| `EMediatorError` | Mediator | Handler no registrado o error de dispatch. |

---

## 23. Resilience

**Unidades:** `Quick.Core.Resilience.Abstractions`, `Quick.Core.Resilience.CircuitBreaker`, `Quick.Core.Resilience.Retry`, `Quick.Core.Resilience.Timeout`, `Quick.Core.Extensions.Resilience`

> Equivalente .NET: [Polly](https://github.com/App-vNext/Polly) / `Microsoft.Extensions.Resilience`

### `IResiliencePolicy<T>`

Interfaz implementada por todas las políticas.

| Método | Descripción |
|--------|-------------|
| `Execute(func)` | Ejecuta `func: TResilienceFunc<T>` aplicando la política. |

### `TCircuitBreakerPolicy<T>`

Implementa el patrón Circuit Breaker con máquina de estados Cerrado / Abierto / Semi-Abierto.

| Miembro | Descripción |
|---------|-------------|
| `Create(failureThreshold, durationOfBreakMs, [onStateChange])` | Constructor. `failureThreshold`: fallos consecutivos antes de abrir. `durationOfBreakMs`: ms que el circuito permanece abierto. |
| `Execute(func)` | Ejecuta `func`; lanza `ECircuitOpenException` si el circuito está abierto. |
| `State` | `TCircuitState`: `cbClosed`, `cbOpen`, `cbHalfOpen`. |
| `FailureCount` | Contador actual de fallos. |
| `Reset` | Cierra el circuito y resetea el contador. |

**Estados:**

| Transición | Descripción |
|-----------|-------------|
| Closed → Open | Al alcanzar `FailureThreshold` fallos consecutivos. |
| Open → HalfOpen | Tras expirar `DurationOfBreakMs`. |
| HalfOpen → Closed | Si la llamada de sonda tiene éxito. |
| HalfOpen → Open | Si la llamada de sonda falla (reinicia el timer). |

```pascal
cb := TCircuitBreakerPolicy<string>.Create(
  {FailureThreshold} 3,
  {DurationOfBreakMs} 5000,
  procedure(oldState, newState: TCircuitState)
  begin
    Logger.Info('Circuit: %s → %s', [GetEnumName(TypeInfo(TCircuitState), Ord(oldState)),
                                      GetEnumName(TypeInfo(TCircuitState), Ord(newState))]);
  end);

try
  result := cb.Execute(function: string begin Result := HttpClient.Get(url) end);
except
  on ECircuitOpenException do
    result := 'Service unavailable (circuit open)';
end;
```

### `TRetryPolicy<T>`

Reintentos con estrategia de backoff configurable.

| Miembro | Descripción |
|---------|-------------|
| `Create(maxRetries, initialDelayMs, [backoffType], [maxDelayMs], [onRetry], [shouldRetry])` | Constructor. |
| `Execute(func)` | Ejecuta con reintentos; lanza `ERetryExhaustedException` si se agotan. |
| `MaxRetries` | Total de reintentos tras el primer fallo. |
| `BackoffType` | `TBackoffType`: `btConstant`, `btExponential`, `btDecorrelated`. |

**Estrategias de backoff:**

| Valor | Comportamiento |
|-------|----------------|
| `btConstant` | Espera siempre `InitialDelayMs`. |
| `btExponential` | Espera `InitialDelayMs × 2^(intento-1)`, capped a `MaxDelayMs`. |
| `btDecorrelated` | Jitter AWS: aleatorio en `[InitialDelayMs, prev×3]`. Ideal para sistemas distribuidos. |

```pascal
retry := TRetryPolicy<string>.Create(
  {MaxRetries} 3,
  {InitialDelayMs} 200,
  btExponential,
  {MaxDelayMs} 5000,
  procedure(attempt, delayMs: Integer; e: Exception)
  begin
    Logger.Warn('Retry %d after %dms: %s', [attempt, delayMs, e.Message]);
  end);

result := retry.Execute(function: string begin Result := HttpClient.Get(url) end);
```

### `TTimeoutPolicy<T>`

Cancela la operación si supera el tiempo límite.

| Miembro | Descripción |
|---------|-------------|
| `Create(timeoutMs, [onTimeout])` | Constructor. `timeoutMs`: tiempo máximo en ms. |
| `Execute(func)` | Ejecuta en hilo separado; lanza `ETimeoutException` si supera `timeoutMs`. |

```pascal
timeout := TTimeoutPolicy<string>.Create(3000);
try
  result := timeout.Execute(function: string begin Result := HttpClient.Get(url) end);
except
  on ETimeoutException do
    result := 'Request timed out';
end;
```

### Combinación de políticas

```pascal
// Orden recomendado: Timeout (exterior) → Retry → Circuit Breaker (interior)
result := timeout.Execute(function: string
  begin
    Result := retry.Execute(function: string
      begin
        Result := cb.Execute(function: string
          begin
            Result := HttpClient.Get(url);
          end);
      end);
  end);
```

### `TResilienceServiceExtension` (DI)

```pascal
// ConfigureServices
services.Extension<TResilienceServiceExtension>
  .AddCircuitBreaker<string>('http-cb',  {threshold} 5, {breakMs} 10000)
  .AddRetry<string>('http-retry',        {maxRetries} 3, {delayMs} 500, btExponential)
  .AddTimeout<string>('http-timeout',    {timeoutMs} 5000);

// Inyección
cb      := services.Resolve<IResiliencePolicy<string>>('http-cb');
retry   := services.Resolve<IResiliencePolicy<string>>('http-retry');
timeout := services.Resolve<IResiliencePolicy<string>>('http-timeout');
```

> **Nota:** Para políticas stateful (Circuit Breaker), regístralas como Singleton para que el estado se comparta entre todas las llamadas al mismo servicio downstream.

---

## 24. Mediator / CQRS

**Unidades:** `Quick.Core.Mediator.Abstractions`, `Quick.Core.Mediator`, `Quick.Core.Extensions.Mediator`

> Equivalente .NET: [MediatR](https://github.com/jbogard/MediatR)

### Interfaces de abstracción

| Interfaz | Descripción |
|----------|-------------|
| `IRequest<TResponse>` | Marcador opcional para requests con respuesta tipada. |
| `IRequest` | Marcador opcional para commands sin respuesta (void). |
| `INotification` | Marcador para eventos/notificaciones (fan-out). |
| `IRequestHandler<TRequest, TResponse>` | Handler de un request → devuelve `TResponse`. |
| `INotificationHandler<TNotification>` | Handler de una notificación (múltiples por evento). |
| `IPipelineBehavior<TRequest, TResponse>` | Middleware de pipeline (cross-cutting: logging, validación...). |
| `IMediator` | `Send(request): TValue` / `Publish(notification)`. |

### `TMediator`

Dispatcher central registrado como singleton en DI.

| Método | Descripción |
|--------|-------------|
| `Send(request)` | Despacha al handler registrado; aplica pipeline behaviors. Devuelve `TValue`. |
| `Publish(notification)` | Publica a todos los handlers registrados. Un fallo no cancela el resto. |
| `SendRequest<TResponse>(request)` | Type-safe: devuelve `TResponse` directamente (inyecta `TMediator` en lugar de `IMediator`). |

### `TRequestHandler<TRequest, TResponse>`

Clase base para handlers de request.

```pascal
type
  TGetProductHandler = class(TRequestHandler<TGetProductQuery, TProductDto>)
  public
    function Handle(const aRequest: TGetProductQuery): TProductDto; override;
  end;

function TGetProductHandler.Handle(const aRequest: TGetProductQuery): TProductDto;
begin
  Result := fRepository.GetById(aRequest.ProductId);
end;
```

### `TNotificationHandler<TNotification>`

Clase base para handlers de notificación (puede haber N por evento).

```pascal
type
  TEmailOnOrderCreated = class(TNotificationHandler<TOrderCreatedEvent>)
  public
    procedure Handle(const aNotification: TOrderCreatedEvent); override;
  end;
```

### `TPipelineBehavior<TRequest, TResponse>`

Middleware aplicado antes/después de cada handler. Los behaviors se ejecutan en orden de registro.

```pascal
type
  TLoggingBehavior<TRequest: class; TResponse> =
    class(TPipelineBehavior<TRequest, TResponse>)
  public
    function Handle(const aRequest: TRequest;
                    aNext: TRequestHandlerDelegate<TResponse>): TResponse; override;
  end;

function TLoggingBehavior<TRequest, TResponse>.Handle(
  const aRequest: TRequest;
  aNext: TRequestHandlerDelegate<TResponse>): TResponse;
begin
  Logger.Info('Handling %s', [aRequest.ClassName]);
  Result := aNext();              // llama al siguiente behavior o al handler final
  Logger.Info('Handled %s', [aRequest.ClassName]);
end;
```

### `TMediatorBuilder` (DI)

```pascal
// ConfigureServices
services.Extension<TMediatorServiceExtension>
  .AddMediatR
  .AddRequestHandler<TGetProductQuery, TProductDto, TGetProductHandler>
  .AddNotificationHandler<TOrderCreatedEvent, TEmailOnOrderCreated>
  .AddPipelineBehavior<TGetProductQuery, TProductDto, TLoggingBehavior<TGetProductQuery, TProductDto>>
  .Build;

// Controller / Service (inyectar IMediator)
constructor TProductsController.Create(aMediator: IMediator);

function TProductsController.GetProduct(id: Integer): IActionResult;
var
  dto: TProductDto;
begin
  dto := fMediator.Send(TGetProductQuery.Create(id)).AsType<TProductDto>;
  Result := Json(dto);
end;
```

> **Nota:** Para dispatch type-safe sin `TValue.AsType<T>`, inyectar `TMediator` directamente y usar `SendRequest<TResponse>`.

---

## 25. HybridCache

**Unidades:** `Quick.Core.Caching.Hybrid`, `Quick.Core.Extensions.Caching.Hybrid`

> Equivalente .NET: `IHybridCache` (Microsoft.Extensions.Caching.Hybrid, .NET 9)

### Arquitectura

```
GetOrCreate(key)
  ├─ L1: IMemoryCache (in-process, microsegundos)
  │      Hit → return
  ├─ L2: IDistributedCache (Redis, red)
  │      Hit → populate L1 → return
  └─ Miss → factory() → write L1 + L2 → return
```

### `THybridCacheOptions`

| Propiedad | Tipo | Descripción |
|-----------|------|-------------|
| `DefaultLocalExpirationMs` | `Integer` | TTL L1 en ms (0 = sin expiración). |
| `DefaultRemoteExpirationMs` | `Integer` | TTL L2 en ms (0 = sin expiración). |
| `LocalCacheEnabled` | `Boolean` | `False` = bypass L1. Default: `True`. |
| `DistributedCacheEnabled` | `Boolean` | `False` = bypass L2. Default: `True` si `IDistributedCache` registrado. |

### `IHybridCache`

| Método | Descripción |
|--------|-------------|
| `GetOrCreate(key, factory, [localMs], [remoteMs])` | Obtiene del cache o ejecuta `factory` y cachea. |
| `SetValue(key, value, [localMs], [remoteMs])` | Escribe en L1 y L2 simultáneamente. |
| `Remove(key)` | Elimina la clave de L1 y L2. |

```pascal
// ConfigureServices
services.Extension<TMemoryCacheServiceExtension>.AddMemoryCache;
services.Extension<TRedisCacheServiceExtension>.AddDistributedRedisCache(...);
services.Extension<THybridCacheServiceExtension>
  .AddHybridCache(procedure(o: THybridCacheOptions)
    begin
      o.DefaultLocalExpirationMs  := 60_000;   // 1 min L1
      o.DefaultRemoteExpirationMs := 600_000;  // 10 min L2
    end);

// Controller / Service
constructor TProductsController.Create(aCache: IHybridCache);

function TProductsController.GetProduct(id: Integer): IActionResult;
var
  product: string;
begin
  product := fCache.GetOrCreate(
    Format('product:%d', [id]),
    function: string
    begin
      Result := ObjectToJson(fRepository.GetById(id));
    end,
    {localMs} 60_000,
    {remoteMs} 600_000);
  Result := Json(product);
end;
```

> **Prerequisito:** registrar `IMemoryCache` antes de `AddHybridCache`. `IDistributedCache` (Redis) es opcional para usar solo L1.

---

## Ver también

- [Dependency Injection](wiki/Dependency-Injection.md)
- [Entity / ORM](wiki/Entity-ORM.md)
- [MVC](wiki/MVC.md)
- [Security](wiki/Security.md)
- [Caching](wiki/Caching.md)
- [AutoMapper](wiki/AutoMapper.md)
- [Background Services](wiki/Background-Services.md)
- [Health Checks](wiki/Health-Checks.md)
- [Message Queue](wiki/Message-Queue.md)
- [TaskControl](wiki/TaskControl.md)
- [Localization](wiki/Localization.md)
- [Commandline](wiki/Commandline.md)
- [Resilience](wiki/Resilience.md)
- [Mediator / CQRS](wiki/Mediator.md)
- [FluentValidation](wiki/FluentValidation.md)
- [Telemetry](wiki/Telemetry.md)

---

## 26. FluentValidation Builder

**Unidad:** `Quick.Core.Mvc.Validation.Builder`

> Equivalente .NET: `FluentValidation` — `AbstractValidator<T>`, `IRuleBuilder<T,P>`

### `TValidationResult`

| Miembro | Descripción |
|---------|-------------|
| `IsValid` | `True` si no hay errores de validación. |
| `Errors` | `TList<TValidationError>` con todos los errores. |
| `AddError(propName, msg)` | Añade un error manualmente. |

`TValidationError` es un record con `PropertyName : string` y `ErrorMessage : string`.

### `TPropertyRuleBuilder`

Builder fluent devuelto por `RuleFor`. Todas las reglas devuelven `Self`.

| Método | Equivalente .NET | Descripción |
|--------|-----------------|-------------|
| `NotEmpty` | `NotEmpty()` | No vacío / no cero |
| `Empty` | `Empty()` | Vacío / cero |
| `Length(min, max)` | `Length(min, max)` | Longitud de string |
| `MaxLength(max)` | `MaximumLength(max)` | Longitud máxima |
| `MinLength(min)` | `MinimumLength(min)` | Longitud mínima |
| `Matches(pattern)` | `Matches(pattern)` | Regex |
| `EmailAddress` | `EmailAddress()` | Formato e-mail |
| `GreaterThan(v)` | `GreaterThan(v)` | Mayor que |
| `GreaterThanOrEqualTo(v)` | `GreaterThanOrEqualTo(v)` | Mayor o igual |
| `LessThan(v)` | `LessThan(v)` | Menor que |
| `LessThanOrEqualTo(v)` | `LessThanOrEqualTo(v)` | Menor o igual |
| `InclusiveBetween(min, max)` | `InclusiveBetween(min, max)` | Rango inclusivo |
| `NotNull` | `NotNull()` | No nil |
| `Must(pred)` | `Must(pred)` | Predicado custom (`TValuePredicate`) |
| `MustBeString(pred)` | `Must(x => ...)` | Predicado sobre string |
| `WithMessage(msg)` | `WithMessage(msg)` | Mensaje para la última regla |

### `TAbstractValidator<T>`

| Miembro | Descripción |
|---------|-------------|
| `RuleFor(propertyName)` | Inicia cadena de reglas para la propiedad publicada. |
| `Validate(model)` | Ejecuta todas las reglas. Devuelve `TValidationResult` (caller libera). |

### `IValidator<T>` / `TValidatorAdapter<T>`

`IValidator<T>` es la interfaz DI. `TValidatorAdapter<T>` envuelve cualquier `TAbstractValidator<T>` para registrarlo en el contenedor.

```pascal
uses Quick.Core.Mvc.Validation.Builder;

type
  TOrderValidator = class(TAbstractValidator<TCreateOrderRequest>)
  public
    constructor Create; override;
  end;

constructor TOrderValidator.Create;
begin
  inherited;
  RuleFor('CustomerId').GreaterThan(0);
  RuleFor('Email').NotEmpty.EmailAddress;
  RuleFor('TotalAmount').GreaterThan(0).WithMessage('Amount must be positive');
end;

// Registro DI:
services.AddSingleton<IValidator<TCreateOrderRequest>>(
  TValidatorAdapter<TCreateOrderRequest>.Create(TOrderValidator.Create));
```

---

## 27. Distributed Tracing (OpenTelemetry)

**Unidades:** `Quick.Core.Telemetry.Abstractions`, `Quick.Core.Telemetry`, `Quick.Core.Telemetry.Activity`, `Quick.Core.Telemetry.Exporters.Jaeger`, `Quick.Core.Extensions.Telemetry`

> Equivalente .NET: `OpenTelemetry.Api` — `Activity`, `ActivitySource`, `TracerProvider`

### Enumeraciones

**`TSpanKind`:** `skInternal` · `skServer` · `skClient` · `skProducer` · `skConsumer`  
**`TSpanStatus`:** `ssUnset` · `ssOk` · `ssError`

### `ISpan`

| Método / Propiedad | Descripción |
|--------------------|-------------|
| `TraceId` | 32 hex — identificador de la traza completa. |
| `SpanId` | 16 hex — identificador del span. |
| `ParentSpanId` | 16 hex; vacío en spans raíz. |
| `OperationName` | Nombre de la operación. |
| `Kind` | `TSpanKind`. |
| `StartTime / EndTime` | UTC. `EndTime` = cero hasta `Finish`. |
| `SetTag(key, value)` | Añade/actualiza un tag. Thread-safe. |
| `Tags` | `TSpanAttributes` (dict string→string). |
| `AddEvent(name)` | Registra un evento con timestamp. |
| `SetStatus(status, [desc])` | Establece el estado final. |
| `Traceparent` | Header W3C: `"00-{traceId}-{spanId}-01"`. |
| `Finish([endTime])` | Finaliza y envía al exporter. |

### `ISpanExporter`

| Método | Descripción |
|--------|-------------|
| `Export(spans)` | Exporta spans finalizados. |
| `Shutdown` | Flush y libera recursos. |

### `ITracer`

| Método | Descripción |
|--------|-------------|
| `StartSpan(name, [kind])` | Span raíz. |
| `StartSpan(name, parent, [kind])` | Span hijo. |
| `StartSpanFromTraceparent(name, traceparent, [kind])` | Continúa traza remota. |
| `Inject(span, headers)` | Inyecta Traceparent en headers. |
| `Extract(headers)` | Extrae Traceparent de headers entrantes. |
| `ServiceName` | Nombre del servicio. |

### `ITracerProvider`

| Método | Descripción |
|--------|-------------|
| `GetTracer(name, [version])` | Devuelve `ITracer` para el scope indicado. |
| `AddExporter(exporter)` | Añade exporter en caliente. |
| `Shutdown` | Flush de todos los exporters. |

### `TActivity`

Wrapper RAII sobre `ISpan`. El destructor llama `Stop` automáticamente.

| Método | Descripción |
|--------|-------------|
| `AddTag(key, value)` | Chainable — devuelve `Self`. |
| `AddEvent(name)` | Chainable. |
| `SetStatus(status, [desc])` | Chainable. |
| `Stop` | Finaliza el span. |
| `Traceparent` | Header W3C del span subyacente. |
| `IsRunning` | `True` mientras no se haya llamado `Stop`. |

### `TJaegerExporterOptions`

| Propiedad | Tipo | Default |
|-----------|------|---------|
| `Endpoint` | `string` | `'http://localhost:4318'` |
| `TimeoutMs` | `Integer` | `5000` |
| `BatchSize` | `Integer` | `100` |
| `ServiceName` | `string` | `'unknown_service'` |
| `IgnoreErrors` | `Boolean` | `True` |

### `TTelemetryServiceExtension`

```pascal
uses Quick.Core.Extensions.Telemetry, Quick.Core.Telemetry.Exporters.Jaeger;

var jaegerOpts := TJaegerExporterOptions.Create;
jaegerOpts.Endpoint    := 'http://jaeger:4318';
jaegerOpts.ServiceName := 'my-service';

services
  .AddTelemetry('my-service')
    .AddExporter(TJaegerExporter.Create(jaegerOpts))
    .SetAsGlobal
    .Build;
```

---

## 28. Data Protection

**Units:** `Quick.Core.DataProtection`, `Quick.Core.DataProtection.KeyStore.File`, `Quick.Core.Extensions.DataProtection`

> .NET equivalent: `Microsoft.AspNetCore.DataProtection` — `IDataProtector`, `IDataProtectionProvider`

### `IDataProtector`

| Method / Property | Description |
|-------------------|-------------|
| `Protect(plainText)` | Encrypts and authenticates the payload. Returns Base64 cipher text. |
| `Unprotect(cipherText)` | Decrypts and verifies. Raises exception if tampered. |
| `CreateProtector(purpose)` | Returns a child protector scoped to `purpose`. |
| `Purpose` | String purpose that isolates this protector's key material. |

### `IDataProtectionProvider`

| Method | Description |
|--------|-------------|
| `CreateProtector(purpose)` | Returns an `IDataProtector` for the given purpose. |

### `TDataProtectionOptions`

| Property | Type | Default |
|----------|------|---------|
| `ApplicationName` | `string` | `''` |
| `KeyLifetimeDays` | `Integer` | `90` |

### `TDataProtectionProvider`

In-memory key ring. Keys are lost on process restart.

```pascal
uses Quick.Core.DataProtection;

var provider := TDataProtectionProvider.Create('MyApp');
var protector := provider.CreateProtector('cookies');
var cipher    := protector.Protect('secret value');
var plain     := protector.Unprotect(cipher);
```

### `TFileKeyStoreDataProtectionProvider`

File-backed key ring. Keys are persisted to disk, surviving restarts.

| Factory | Description |
|---------|-------------|
| `Create(keyFilePath, [appName], [keyLifetimeDays])` | Loads or creates the key ring at `keyFilePath`. |

### `TDataProtectionServiceExtension`

```pascal
uses Quick.Core.Extensions.DataProtection;

// In-memory key ring
services.AddDataProtection('MyApp', 90);

// File-backed key ring
services.AddDataProtectionWithFileStore('keys/keyring.json', 'MyApp', 90);
```

### `SecureRandomBytes`

```pascal
function SecureRandomBytes(aCount: Integer): TBytes;
```

Generates `aCount` cryptographically secure random bytes using the OS CSPRNG (`CryptGenRandom` on Windows, `/dev/urandom` on Linux/macOS).

---

## 29. OptionsMonitor / OptionsSnapshot

**Units:** `Quick.Core.Options.Monitor`, `Quick.Core.Extensions.OptionsMonitor`

> .NET equivalent: `IOptionsMonitor<T>`, `IOptionsSnapshot<T>` (`Microsoft.Extensions.Options`)

### `IOptionsChangeToken`

| Method | Description |
|--------|-------------|
| `Unregister` | Cancels the OnChange subscription. |

### `IOptionsMonitor<T>`

| Method / Property | Description |
|-------------------|-------------|
| `CurrentValue` | Returns the latest options instance. |
| `OnChange(callback)` | Registers a change callback; returns `IOptionsChangeToken`. |

### `IOptionsSnapshot<T>`

| Property | Description |
|----------|-------------|
| `Value` | Returns the options instance (read-only, scoped). |

### `TOptionsMonitorServiceExtension`

```pascal
uses Quick.Core.Extensions.OptionsMonitor;

services.AddOptionsMonitor<TMyOptions>;   // registers IOptionsMonitor<TMyOptions>
services.AddOptionsSnapshot<TMyOptions>;  // registers IOptionsSnapshot<TMyOptions>
```

**Usage:**
```pascal
var monitor : IOptionsMonitor<TMyOptions>;
monitor := services.GetService<IOptionsMonitor<TMyOptions>>;
var token := monitor.OnChange(procedure(opts: TMyOptions)
  begin
    // react to config change
  end);
// later...
token.Unregister;
```

---

## 30. Rate Limiting

**Unit:** `Quick.Core.Mvc.Middleware.RateLimit`

> .NET equivalent: `Microsoft.AspNetCore.RateLimiting` — `AddRateLimiter`, `[EnableRateLimiting]`

### `TRateLimitPolicy`

| Property / Method | Type | Default | Description |
|-------------------|------|---------|-------------|
| `MaxRequests` | `Integer` | `100` | Maximum requests allowed in the window. |
| `WindowSecs` | `Integer` | `60` | Sliding window length in seconds. |
| `KeySelector` | `TFunc<IHttpRequest, string>` | Client IP | Function that produces the rate-limit key per request. |

### `TRateLimitMiddleware`

Sliding window algorithm. Thread-safe via `TCriticalSection`.

- Returns **429 Too Many Requests** when the limit is exceeded.
- Adds `Retry-After` header with seconds until next allowed request.
- Returns a JSON error body: `{"error":"rate limit exceeded","retryAfter":N}`.

### `[RateLimit]` Attribute

Per-action override of the global policy:

```pascal
[HttpGet]
[RateLimit(10, 60)]   // 10 req / 60 sec for this action only
function GetSensitiveData : IActionResult;
```

| Constructor | Parameters |
|-------------|-----------|
| `Create(maxRequests, [windowSecs=60])` | `maxRequests: Integer; windowSecs: Integer` |

### Registration

```pascal
app
  .UseRateLimiting(100, 60)   // global: 100 req / 60 sec
  .UseRouting
  .UseMVC;
```

---

## 31. Entity Migrations

**Unit:** `Quick.Core.Entity.Migrations`

> .NET equivalent: `Microsoft.EntityFrameworkCore.Migrations` — `IMigration`, `MigrationBuilder`

### `TMigration` (abstract)

| Method | Description |
|--------|-------------|
| `GetMigrationId` | Returns a unique string ID (e.g. `'20260101_AddUsersTable'`). |
| `GetProductVersion` | Returns the framework version this migration targets. |
| `Up(aDBContext)` | Applies the migration (DDL forward). |
| `Down(aDBContext)` | Rolls back the migration (DDL reverse). |

```pascal
type
  TAddUsersTable = class(TMigration)
  public
    function GetMigrationId    : string; override;
    function GetProductVersion : string; override;
    procedure Up  (aDBContext : IDBContext); override;
    procedure Down(aDBContext : IDBContext); override;
  end;

function TAddUsersTable.GetMigrationId    : string; begin Result := '20260101_AddUsersTable'; end;
function TAddUsersTable.GetProductVersion : string; begin Result := '2.11.0'; end;
procedure TAddUsersTable.Up(aDBContext: IDBContext);   begin aDBContext.ExecuteSQL('CREATE TABLE users (...)'); end;
procedure TAddUsersTable.Down(aDBContext: IDBContext); begin aDBContext.ExecuteSQL('DROP TABLE users'); end;
```

### `TMigrationsManager`

| Method | Description |
|--------|-------------|
| `Create(dbContext, [tableName])` | Creates the manager. Default table: `__MigrationsHistory`. |
| `ApplyMigrations(classes)` | Runs pending migrations in order. Each migration is transactional. |
| `RollbackLast(classes)` | Rolls back the last applied migration. |
| `GetAppliedMigrations` | Returns a `TArray<string>` of applied migration IDs. |

### `TEntityMigrationsHistory`

Internal entity that maps to the `__MigrationsHistory` table (auto-created on first run).

| Column | Type | Description |
|--------|------|-------------|
| `MigrationId` | `string` | Unique migration identifier. |
| `ProductVersion` | `string` | Framework version. |
| `AppliedAt` | `TDateTime` | UTC timestamp of application. |

---

## 32. Repository Pattern

**Unit:** `Quick.Core.Entity.Repository`

> .NET equivalent: Generic Repository pattern over `DbContext` / `IRepository<T>`

### `IRepository<T>`

| Method | Description |
|--------|-------------|
| `GetById(id)` | Returns the entity with the given primary key, or `nil`. |
| `GetAll` | Returns `TArray<T>` with all entities. |
| `Add(entity)` | Inserts a new entity. |
| `AddOrUpdate(entity)` | Inserts or updates by primary key. |
| `Update(entity)` | Updates an existing entity. |
| `Delete(entity)` | Deletes the entity. |
| `DeleteById(id)` | Deletes by primary key. |
| `Count` | Returns the total row count. |
| `Exists(id)` | Returns `True` if a row with that PK exists. |
| `Find(predicate)` | Returns `TArray<T>` matching the LINQ predicate. |
| `FindFirst(predicate)` | Returns the first matching entity, or `nil`. |
| `Query` | Returns the underlying `IEntityQuery<T>` for fluent queries. |

### `TEntityRepository<T>`

| Constructor | Description |
|-------------|-------------|
| `Create(dbSet, [primaryKeyName='Id'])` | Wraps an `IEntitySet<T>` from the DbContext. |

```pascal
uses Quick.Core.Entity.Repository;

var repo : IRepository<TUser>;
repo := TEntityRepository<TUser>.Create(dbContext.Users);

var user := repo.GetById(42);
repo.Add(TUser.Create('alice@example.com'));
var admins := repo.Find(function(u: TUser): Boolean begin Result := u.IsAdmin; end);
```

---

## 33. Unit of Work

**Unit:** `Quick.Core.Entity.UnitOfWork`

> .NET equivalent: `IUnitOfWork` / `DbContext.SaveChanges` transactional pattern

### `IUnitOfWork`

| Method | Description |
|--------|-------------|
| `BeginTransaction` | Starts a database transaction. |
| `Commit` | Commits the current transaction. |
| `Rollback` | Rolls back the current transaction. |
| `Execute(proc)` | Runs `proc` inside a transaction; returns `True` on commit, `False` on rollback/exception. |

### `TUnitOfWork`

| Constructor | Description |
|-------------|-------------|
| `Create(aContext: IDBContext)` | Wraps the given database context. |

```pascal
uses Quick.Core.Entity.UnitOfWork;

var uow : IUnitOfWork;
uow := TUnitOfWork.Create(dbContext);

uow.Execute(procedure
  begin
    orderRepo.Add(newOrder);
    inventoryRepo.Update(product);
    // auto-committed if no exception, auto-rolled-back otherwise
  end);
```
