# Comparativa QuickCore vs ASP.NET Core

> Guía feature-by-feature con código paralelo C# / Delphi.  
> Cobertura estimada: **80-85 %** de ASP.NET Core.

---

## Tabla de contenidos

1. [Dependency Injection](#1-dependency-injection)
2. [App Host y Startup](#2-app-host-y-startup)
3. [MVC — Controllers](#3-mvc--controllers)
4. [MVC — Routing](#4-mvc--routing)
5. [MVC — Binding de parámetros](#5-mvc--binding-de-parámetros)
6. [MVC — Middleware pipeline](#6-mvc--middleware-pipeline)
7. [MVC — Minimal API](#7-mvc--minimal-api)
8. [Entity / ORM](#8-entity--orm)
9. [Migrations](#9-migrations)
10. [Security — Authentication](#10-security--authentication)
11. [Security — Authorization](#11-security--authorization)
12. [Security — JWT](#12-security--jwt)
13. [Identity](#13-identity)
14. [Caching](#14-caching)
15. [AutoMapper](#15-automapper)
16. [Background Services](#16-background-services)
17. [Health Checks](#17-health-checks)
18. [Message Queue](#18-message-queue)
19. [Localization](#19-localization)
20. [Commandline](#20-commandline)
21. [Serialization](#21-serialization)
22. [Resumen de cobertura](#22-resumen-de-cobertura)
23. [Resilience (Polly)](#23-resilience-polly)
24. [Mediator / CQRS (MediatR)](#24-mediator--cqrs-mediatR)
25. [HybridCache](#25-hybridcache)
26. [FluentValidation Builder](#26-fluentvalidation-builder)
27. [Distributed Tracing (OpenTelemetry)](#27-distributed-tracing-opentelemetry)

---

## 1. Dependency Injection

| Feature | ASP.NET Core | QuickCore |
|---------|-------------|-----------|
| Singleton | `AddSingleton<I,T>()` | `AddSingleton<I,T>` |
| Transient | `AddTransient<I,T>()` | `AddTransient<I,T>` |
| Scoped | `AddScoped<I,T>()` | `AddScoped<I,T>` |
| Named/Keyed | `AddKeyedSingleton<I,T>(key)` (.NET 8) | `AddKeyedSingleton<I,T>(key)` |
| Factory delegate | `AddSingleton<I>(sp => new T(...))` | `AddSingleton<I,T>(name, func)` |
| Opciones tipadas | `Configure<T>(section)` | `Configure<T>(section)` |
| Scopes explícitos | `IServiceScope` | `IServiceScope` |
| Inyección en constructor | automática vía reflection | automática vía RTTI |

```csharp
// C#
builder.Services.AddSingleton<IMyService, MyService>();
builder.Services.Configure<DatabaseOptions>(
    builder.Configuration.GetSection("Database"));
```

```pascal
// Delphi
services.AddSingleton<IMyService, TMyService>;
services.Configure<TDatabaseOptions>('Database');
```

---

## 2. App Host y Startup

| Feature | ASP.NET Core | QuickCore |
|---------|-------------|-----------|
| Host genérico | `Host.CreateDefaultBuilder().Build().Run()` | `THostBuilder.Create...Build.Run` |
| Startup class | `IStartup` / `WebApplicationFactory` | `TStartupBase` / `TStartupMvc` |
| ConfigureServices | `Startup.ConfigureServices(IServiceCollection)` | `TStartup.ConfigureServices(TServiceCollection)` |
| Configure pipeline | `Startup.Configure(IApplicationBuilder)` | `TStartup.Configure(TMVCServer)` |
| Web app | `WebApplication.CreateBuilder()` | `TMVCServer.Create(host, port, ssl)` |

```csharp
// C#
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
var app = builder.Build();
app.UseRouting();
app.MapControllers();
app.Run();
```

```pascal
// Delphi
TMVCServer.Create('0.0.0.0', 8080, False)
  .UseStartup<TMyStartup>
  .Start;
```

---

## 3. MVC — Controllers

| Feature | ASP.NET Core | QuickCore |
|---------|-------------|-----------|
| Clase base | `ControllerBase` | `THttpController` |
| Contexto HTTP | `HttpContext` | `HttpContext: THttpContextBase` |
| Usuario actual | `User` (`ClaimsPrincipal`) | `User: TClaimsPrincipal` |
| Request/Response | `Request` / `Response` | `Request: IHttpRequest` / `Response: IHttpResponse` |
| Logger inyectado | `ILogger<T>` vía DI | `Logger: ILogger` (automático) |
| DI en constructor | automático | automático vía RTTI |

```csharp
// C#
[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    private readonly IProductService _svc;
    public ProductsController(IProductService svc) => _svc = svc;

    [HttpGet]
    public IActionResult GetAll() => Ok(_svc.GetAll());
}
```

```pascal
// Delphi
[ApiController]
[Route('api/[controller]')]
type TProductsController = class(THttpController)
private
  fSvc: IProductService;
public
  constructor Create(aSvc: IProductService);
  [HttpGet]
  function GetAll: TStatusResult;
end;

function TProductsController.GetAll: TStatusResult;
begin
  Result := Ok;
  Result.Value := fSvc.GetAll;
end;
```

---

## 4. MVC — Routing

| Feature | ASP.NET Core | QuickCore |
|---------|-------------|-----------|
| Ruta de controller | `[Route("api/[controller]")]` | `[Route('api/[controller]')]` |
| Token `[controller]` | Nombre de clase sin sufijo | Nombre de clase sin sufijo |
| Token `[action]` | Nombre del método | Nombre del método |
| Parámetros en ruta | `[HttpGet("{id}")]` | `[HttpGet('{id}')]` |
| Nombre de acción | `[ActionName("list")]` | `[ActionName('list')]` |
| Verbos múltiples | `[AcceptVerbs("GET","POST")]` | `[AcceptVerbs([mvGET,mvPOST])]` |
| Excluir del routing | `[NonAction]` | `[NonAction]` |

```csharp
// C#
[HttpGet("{id:int}")]
public IActionResult GetById(int id) { ... }
```

```pascal
// Delphi
[HttpGet('{id}')]
function GetById(id: Integer): TStatusResult;
```

---

## 5. MVC — Binding de parámetros

| Feature | ASP.NET Core | QuickCore |
|---------|-------------|-----------|
| Body JSON | `[FromBody]` | `[FromBody]` |
| Query string | `[FromQuery]` / `[FromQuery(Name="n")]` | `[FromQuery]` / `[FromQuery('n')]` |
| Header | `[FromHeader]` / `[FromHeader(Name="X-Key")]` | `[FromHeader]` / `[FromHeader('X-Key')]` |
| Ruta | `[FromRoute]` | Implícito por nombre en `[Route]` |
| Servicio keyed | `[FromKeyedServices("key")]` (.NET 8) | `[FromKeyedServices('key')]` |
| Validación automática | `ModelState.IsValid` + `[ApiController]` | `TModelValidator` + atributos |

```csharp
// C#
public IActionResult Search(
    [FromQuery] string term,
    [FromHeader(Name = "X-Client")] string client,
    [FromBody] SearchFilter filter) { ... }
```

```pascal
// Delphi
function Search(
  [FromQuery('term')] term: string;
  [FromHeader('X-Client')] client: string;
  [FromBody] filter: TSearchFilter): TStatusResult;
```

### Atributos de validación de modelo

| Atributo | C# | Delphi |
|----------|----|--------|
| Requerido | `[Required]` | `[Required]` |
| Rango | `[Range(1,100)]` | `[Range(1,100)]` |
| Longitud | `[StringLength(50)]` | `[StringLength(50)]` |
| Email | `[EmailAddress]` | `[EmailAddress]` |
| Regex | `[RegularExpression("pattern")]` | `[RegularExpression('pattern')]` |

---

## 6. MVC — Middleware pipeline

| Middleware | ASP.NET Core | QuickCore |
|-----------|-------------|-----------|
| Enrutamiento | `UseRouting()` | `UseRouting` |
| Autenticación | `UseAuthentication()` | `UseAuthentication` |
| Autorización | `UseAuthorization()` | `UseAuthorization` |
| CORS | `UseCors()` | `UseCors` |
| Archivos estáticos | `UseStaticFiles()` | `UseStaticFiles` |
| Swagger | `UseSwagger()` + `UseSwaggerUI()` | `UseSwagger(title, version, desc)` |
| Sesiones | `UseSession()` | `UseSession` |
| Rate limiting | `UseRateLimiter()` (.NET 7) | `UseRateLimiting(max, secs)` |
| Compresión | `UseResponseCompression()` | `UseResponseCompression` |
| HTTPS redirection | `UseHttpsRedirection()` | `UseHttpsRedirection` |
| HSTS | `UseHsts()` | `UseHsts` |
| Excepciones | `UseExceptionHandler(opts)` | `UseExceptionHandler([proc])` |
| Versioning API | `AddApiVersioning()` | `UseApiVersioning` |
| Log de peticiones | `UseHttpLogging()` | `UseLogRequest` |
| Middleware inline | `app.Use(async (ctx, next) => {...})` | `app.Use(func(ctx): string)` |
| Middleware tipado | `app.UseMiddleware<T>()` | `app.UseMiddleware(TMyMiddleware)` |

```csharp
// C# — orden estándar del pipeline
app.UseExceptionHandler("/error");
app.UseHsts();
app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.UseSession();
app.MapControllers();
```

```pascal
// Delphi — orden equivalente
app.UseExceptionHandler
   .UseHsts
   .UseHttpsRedirection
   .UseStaticFiles
   .UseRouting
   .UseCors
   .UseAuthentication
   .UseAuthorization
   .UseSession
   .UseMVC;
```

---

## 7. MVC — Minimal API

| Feature | ASP.NET Core | QuickCore |
|---------|-------------|-----------|
| GET | `app.MapGet("/path", handler)` | `app.MapGet('/path', handler)` |
| POST | `app.MapPost(...)` | `app.MapPost(...)` |
| PUT | `app.MapPut(...)` | `app.MapPut(...)` |
| DELETE | `app.MapDelete(...)` | `app.MapDelete(...)` |
| Varios verbos | `app.MapMethods(path, methods, handler)` | `app.MapVerbs(path, verbs, handler)` |

```csharp
// C#
app.MapGet("/hello", () => "Hello World!");
app.MapPost("/echo", (string body) => body);
```

```pascal
// Delphi
app.MapGet('/hello',
  function(ctx: THttpContextBase): string
  begin Result := '"Hello World!"'; end);

app.MapPost('/echo',
  function(ctx: THttpContextBase): string
  begin Result := ctx.Request.Body; end);
```

---

## 8. Entity / ORM

| Feature | EF Core | QuickCore Entity |
|---------|---------|-----------------|
| DbContext | `DbContext` | `TDBContext` |
| DbSet | `DbSet<T>` | `TDBSet<T>` |
| Configurar conexión | `OnConfiguring` + `UseSqlServer(...)` | `Connection.Provider` + `Connection.Server` |
| Migrations | `dotnet ef migrations add` | `TMigration` + `TMigrationsManager` |
| LINQ | `context.Products.Where(p => p.Active)` | `Products.Where('Active = 1')` o `Where(p => p.Active)` |
| Incluir navegación | `.Include(p => p.Category)` | `.Include('Category')` |
| Transacción | `using var tx = context.Database.BeginTransaction()` | `context.BeginTransaction` / `CommitTransaction` |
| Unit of Work | implícito en `SaveChanges` | `IUnitOfWork.Execute(proc)` |
| Repository | patrón manual | `IRepository<T>` / `TEntityRepository<T>` |
| Soft delete | filtro global personalizado | atributo `[SoftDelete]` + `TEntitySD` |
| Concurrencia | `[Timestamp]` / `DbUpdateConcurrencyException` | `TEntityRV` + `EOptimisticConcurrencyException` |
| Seeding | `modelBuilder.Entity<T>().HasData(...)` | `context.Seed(proc)` |
| Auditoría | interceptores personalizados | `TEntityAudit` (base class) |

### Atributos de entidad

| EF Core (atributo) | QuickCore (atributo) |
|--------------------|----------------------|
| `[Table("name")]` | `[Table('name')]` |
| `[Key]` | `[Key]` |
| `[MaxLength(n)]` | `[StringLength(n)]` |
| `[Column("col")]` | `[MapName('col')]` |
| `[ForeignKey("field")]` | `[ForeignKey('field')]` |
| `[Index]` (Fluent API) | `[Index(['field'])]` |
| — | `[SoftDelete]` |

```csharp
// C# — EF Core
public class Product
{
    [Key]
    public int Id { get; set; }
    [MaxLength(100)]
    public string Name { get; set; }
    public bool IsActive { get; set; }
}

// LINQ
var active = await context.Products
    .Where(p => p.IsActive)
    .OrderBy(p => p.Name)
    .ToListAsync();
```

```pascal
// Delphi — QuickCore Entity
type
  [Table('Products')]
  TProduct = class(TEntity)
  published
    [Key]
    property Id: TAutoID ...;
    [StringLength(100)]
    property Name: string ...;
    property IsActive: Boolean ...;
  end;

// LINQ
var result := context.Products
  .Where('IsActive = 1')
  .OrderBy('Name')
  .Select;
```

---

## 9. Migrations

| Feature | EF Core | QuickCore |
|---------|---------|-----------|
| Clase base | `Migration` | `TMigration` |
| Método Up | `Up(MigrationBuilder mb)` | `Up(context: IDBContext)` |
| Método Down | `Down(MigrationBuilder mb)` | `Down(context: IDBContext)` |
| Aplicar todas | `dotnet ef database update` | `TMigrationsManager.ApplyMigrations` |
| Revertir última | `dotnet ef database update PrevMigration` | `TMigrationsManager.RollbackLast` |
| Historial | tabla `__EFMigrationsHistory` | tabla `__MigrationsHistory` |

---

## 10. Security — Authentication

| Feature | ASP.NET Core | QuickCore |
|---------|-------------|-----------|
| Registrar auth | `AddAuthentication()` | `services.AddAuthentication` |
| JWT Bearer | `.AddJwtBearer(opts => ...)` | `.AddJwtBearer(proc)` |
| Cookie | `.AddCookie(opts => ...)` | `.AddCookie` |
| API Key | custom handler | `.AddApiKey(proc)` |
| OAuth2/OIDC | `.AddOpenIdConnect(...)` | `.AddOAuth2(proc)` |
| Múltiples esquemas | sí | sí |
| `IAuthenticationService` | sí | sí |
| Claims principal | `ClaimsPrincipal` | `TClaimsPrincipal` |
| Ticket | `AuthenticationTicket` | `IAuthenticationTicket` |

```csharp
// C#
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opt => {
        opt.TokenValidationParameters = new() {
            ValidateIssuer = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret))
        };
    });
```

```pascal
// Delphi
services.AddAuthentication
  .AddJwtBearer(procedure(opt: TJwtOptions)
    begin
      opt.Secret          := secret;
      opt.ValidateIssuer  := True;
      opt.ValidateLifetime := True;
    end);
```

---

## 11. Security — Authorization

| Feature | ASP.NET Core | QuickCore |
|---------|-------------|-----------|
| Requerir auth | `[Authorize]` | `[Authorize]` |
| Por roles | `[Authorize(Roles="Admin")]` | `[Authorize('Admin')]` |
| Por política | `[Authorize(Policy="p")]` | `[AuthorizePolicy('p')]` |
| Anónimo | `[AllowAnonymous]` | `[AllowAnonymous]` |
| Políticas | `AddAuthorization(opt => opt.AddPolicy(...))` | `AddAuthorization(proc)` |
| `IAuthorizationService` | sí | sí |
| Recurso | `AuthorizeAsync(user, resource, policy)` | `AuthorizeResource(obj, policy)` |

```csharp
// C# — política personalizada
builder.Services.AddAuthorization(opt =>
    opt.AddPolicy("SeniorDev", policy =>
        policy.RequireRole("Developer")
              .RequireClaim("experience", "senior")));
```

```pascal
// Delphi
services.AddAuthorization(procedure(opt: TAuthorizationOptions)
  begin
    opt.AddPolicy('SeniorDev',
      TAuthorizationPolicyBuilder.New
        .RequireRole('Developer')
        .RequireClaim('experience', 'senior')
        .Build);
  end);
```

---

## 12. Security — JWT

| Feature | ASP.NET Core | QuickCore |
|---------|-------------|-----------|
| Servicio de tokens | `IJwtSecurityTokenHandler` (manual) | `IJwtTokenService` |
| Generar token | `new JwtSecurityTokenHandler().WriteToken(...)` | `jwtSvc.GenerateToken(claims)` |
| Validar token | `tokenHandler.ValidateToken(...)` | `jwtSvc.ValidateToken(token)` |
| Extraer usuario | parsear claims manualmente | `jwtSvc.GetUserFromToken(token)` |
| Algoritmo | configurable (`HS256`, `RS256`, ...) | HMAC-SHA256 (`HS256`) |

```csharp
// C# — generar token
var claims = new[] { new Claim(ClaimTypes.Name, user.UserName) };
var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));
var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
var token = new JwtSecurityToken(issuer, audience,
    claims, expires: DateTime.UtcNow.AddHours(1), signingCredentials: creds);
return new JwtSecurityTokenHandler().WriteToken(token);
```

```pascal
// Delphi
var claims := TList<TClaim>.Create;
claims.Add(TClaim.Create(ClaimTypes.Name, user.UserName));
var token := jwtSvc.GenerateToken(claims);
```

---

## 13. Identity

| Feature | ASP.NET Core Identity | QuickCore Identity |
|---------|----------------------|-------------------|
| Usuario base | `IdentityUser` | `TIdentityUser<TKey>` |
| Rol base | `IdentityRole` | `TIdentityRole<TKey>` |
| UserManager | `UserManager<T>` | `TUserManager<T>` |
| Store EF | `.AddEntityFrameworkStores<TContext>()` | `.AddEntityStore<TContext>` |
| Password options | `PasswordOptions` | `TPasswordOptions` |
| Lockout options | `LockoutOptions` | `TLockoutOptions` |
| 2FA TOTP | `IUserTwoFactorTokenProvider<T>` | `TTotpService` |
| Security stamp | `ISecurityStampValidator` | `TSecurityStampValidator` |

---

## 14. Caching

| Feature | ASP.NET Core | QuickCore |
|---------|-------------|-----------|
| In-memory cache | `IMemoryCache` | `IMemoryCache` |
| Distributed cache | `IDistributedCache` | `IDistributedCache` |
| Redis distributed | `AddStackExchangeRedisCache(...)` | `AddDistributedRedisCache(proc)` |
| Memory distributed | `AddDistributedMemoryCache()` | `AddDistributedMemoryCache` |
| Hybrid cache (L1+L2) | `IHybridCache` (.NET 9) | `IHybridCache` (`AddHybridCache`) |
| Response caching | `AddResponseCaching()` + `UseResponseCaching()` | `AddResponseCaching` + `UseResponseCaching` |
| Output cache | `[OutputCache(Duration=60)]` (.NET 7) | `[OutputCache(60000)]` (ms) |

```csharp
// C#
var cached = await cache.GetStringAsync("key");
if (cached == null)
{
    cached = expensiveOp();
    await cache.SetStringAsync("key", cached,
        new() { AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(5) });
}
```

```pascal
// Delphi
var value: string;
if not cache.TryGetValue<string>('key', value) then
begin
  value := ExpensiveOp;
  cache.SetValue<string>('key', value, 300); // 300 seg
end;
```

---

## 15. AutoMapper

| Feature | AutoMapper (.NET) | QuickCore AutoMapper |
|---------|------------------|---------------------|
| Perfil | `Profile` | `TProfile` |
| Mapeo | `CreateMap<Src,Dst>()` | `CreateMap<TSrc,TDst>` |
| Renombrar | `.ForMember(dst=>dst.X, opt=>opt.MapFrom(src=>src.Y))` | `.ForMember('X','Y')` |
| Inverso | `.ReverseMap()` | `.ReverseMap` |
| Condición | `.ForMember(..., opt=>opt.Condition(src=>...))` | `.Condition(predicate)` |
| Conversor | `.ConvertUsing(converter)` | `.ConvertUsing('prop', func)` |
| Sustituto nulo | `.NullSubstitute(val)` | `.NullSubstitute('prop', val)` |
| Before/After | `.BeforeMap((src,dst)=>{...})` | `.BeforeMap(proc)` |
| Validar config | `mapper.ConfigurationProvider.AssertConfigurationIsValid()` | `mapper.AssertConfigurationIsValid` |
| Registrar DI | `services.AddAutoMapper(typeof(MyProfile))` | `services.AddAutoMapper(proc)` |

```csharp
// C#
public class UserProfile : Profile
{
    public UserProfile()
    {
        CreateMap<User, UserDto>()
            .ForMember(d => d.FullName, o => o.MapFrom(s => s.FirstName + " " + s.LastName))
            .ReverseMap();
    }
}
```

```pascal
// Delphi
type
  TUserProfile = class(TProfile)
  public
    procedure Configure; override;
  end;

procedure TUserProfile.Configure;
begin
  CreateMap<TUser, TUserDto>
    .ForMember('FullName', 'FirstName')  // simplificado
    .ReverseMap;
end;
```

---

## 16. Background Services

| Feature | ASP.NET Core | QuickCore |
|---------|-------------|-----------|
| Interfaz base | `IHostedService` | `IHostedService` |
| Clase base | `BackgroundService` | `TBackgroundService` |
| Método ejecutar | `ExecuteAsync(CancellationToken)` | `ExecuteAsync` + `CancelRequested: Boolean` |
| Registrar | `services.AddHostedService<T>()` | `services.AddHostedService<T>` |
| Arranque | automático en `IHost.Run()` | automático en `TCoreApp.Start` / `TGenericHost.Run` |

```csharp
// C#
public class OrderProcessor : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            await ProcessNextOrder();
            await Task.Delay(1000, ct);
        }
    }
}
```

```pascal
// Delphi
type
  TOrderProcessor = class(TBackgroundService)
  protected
    procedure ExecuteAsync; override;
  end;

procedure TOrderProcessor.ExecuteAsync;
begin
  while not CancelRequested do
  begin
    ProcessNextOrder;
    Sleep(1000);
  end;
end;
```

---

## 17. Health Checks

| Feature | ASP.NET Core | QuickCore |
|---------|-------------|-----------|
| Registrar | `services.AddHealthChecks()` | `services.AddHealthChecks` |
| Check URL | `.AddUrlGroup(uri, "name")` | `.AddUrlCheck('name', url)` |
| Check SQL Server | `.AddSqlServer(conn)` | `.AddSqlServerCheck('name', conn)` |
| Check Redis | `.AddRedis(conn)` | (via TRedisHealthCheck) |
| Check DB context | `.AddDbContextCheck<T>()` | `.AddEntityCheck<T>('name')` |
| Endpoint | `.MapHealthChecks("/health")` | `app.UseHealthChecks` → `/HealthChecks` |
| Respuesta JSON | sí (personalizable) | sí (Status + checks array) |
| Custom check | `IHealthCheck.CheckHealthAsync(...)` | `IHealthCheck.CheckHealth` |

```csharp
// C#
builder.Services.AddHealthChecks()
    .AddSqlServer(connString, name: "sqlserver")
    .AddRedis(redisConn, name: "redis");
app.MapHealthChecks("/health");
```

```pascal
// Delphi
services.AddHealthChecks
  .AddSqlServerCheck('sqlserver', connString)
  .AddUrlCheck('api-ping', 'http://internal/ping');
// ...
app.UseHealthChecks;
```

---

## 18. Message Queue

| Feature | MassTransit / Azure SB (.NET) | QuickCore MessageQueue |
|---------|-------------------------------|----------------------|
| Publicar | `await bus.Publish(msg)` | `queue.Push(msg)` |
| Consumir | `IConsumer<T>.Consume(ctx)` | `queue.Pop(timeout)` |
| Confirmar | implícito en el consumer | `queue.Remove(msg)` |
| Fallido | dead-letter automático | `queue.Failed(msg)` |
| Backend Redis | `AddMassTransitRedis(...)` | `AddRedisMessageQueue<T>(proc)` |
| Cola fiable | Service Bus Sessions | `ReliableQueue := True` |

---

## 19. Localization

| Feature | ASP.NET Core | QuickCore |
|---------|-------------|-----------|
| Servicio | `IStringLocalizer<T>` | `IStringLocalization` |
| Acceso | `localizer["Key"]` | `localization.Items['Key']` |
| Con formato | `localizer["Hello {0}", name]` | `localization.Items['Hello', [name]]` |
| Cambiar cultura | `CultureInfo.CurrentCulture` | `localization.Culture := 'es-ES'` |
| Ficheros | `.resx` | `.json` en `locales/` |
| Registro | `AddLocalization(opt => opt.ResourcesPath = "Resources")` | `AddLocalization(proc)` |

```csharp
// C#
// locales/Resources/es-ES.resx → key "Welcome" = "Bienvenido {0}"
string msg = localizer["Welcome", user.Name];
```

```pascal
// Delphi
// locales/es-ES.json → { "Welcome": "Bienvenido {0}" }
localization.Culture := 'es-ES';
msg := localization.Items['Welcome', [user.Name]];
```

---

## 20. Commandline

| Feature | System.CommandLine (.NET) | QuickCore Commandline |
|---------|--------------------------|----------------------|
| Parámetros tipados | `Option<T>` / `Argument<T>` | clase derivada de `TParameters` |
| Descripción | `.Description` | `[ParamHelp('texto')]` |
| Requerido | `.IsRequired = true` | `[ParamRequired]` |
| Nombre de opción | `new Option<T>("--name")` | `[ParamName('name')]` |
| Siguiente token | — | `[ParamValueIsNextParam]` |
| Registrar DI | — | `services.AddCommandline<T>` |
| Servicio params | — | `TServiceParameters` (Install/Remove/Console) |

```csharp
// C#
var portOpt = new Option<int>("--port", getDefaultValue: () => 8080);
var root = new RootCommand { portOpt };
root.SetHandler(port => RunServer(port), portOpt);
root.Invoke(args);
```

```pascal
// Delphi
type
  TMyParams = class(TParameters)
  published
    [ParamName('port')]
    [ParamHelp('HTTP port.', '8080')]
    property Port: Integer ...;
  end;

var cmd := services.Resolve<ICommandline<TMyParams>>;
RunServer(cmd.Value.Port);
```

---

## 21. Serialization

| Feature | System.Text.Json (.NET) | QuickCore Serialization |
|---------|------------------------|------------------------|
| Serializar | `JsonSerializer.Serialize(obj)` | `serializer.Serialize<T>(obj)` |
| Deserializar | `JsonSerializer.Deserialize<T>(json)` | `serializer.Deserialize<T>(json)` |
| A fichero | `File.WriteAllText(...)` | `serializer.SerializeToFile<T>(obj, path)` |
| Desde fichero | `JsonSerializer.Deserialize<T>(File.ReadAllText(...))` | `serializer.DeserializeFromFile<T>(path)` |
| YAML | NuGet `YamlDotNet` | `TYamlSerializer` (integrado) |

---

## 22. Resumen de cobertura

| Módulo | Cobertura | Notas |
|--------|-----------|-------|
| Dependency Injection | ✅ 95% | Falta: `IOptions<T>` reactivo (`IOptionsMonitor`) |
| App Host | ✅ 90% | Falta: `IHostApplicationLifetime` |
| MVC Controllers | ✅ 95% | Falta: `[Produces]` / Content Negotiation avanzada |
| MVC Routing | ✅ 90% | Falta: route constraints tipados (`{id:int}`) |
| MVC Middleware | ✅ 95% | Completo |
| Minimal API | ✅ 85% | Falta: grupos de endpoints, filtros |
| Entity / ORM | ✅ 85% | Falta: eager loading multi-nivel, proyecciones `Select` |
| Migrations | ✅ 80% | Falta: generación automática de scripts SQL |
| Security Auth | ✅ 90% | Falta: políticas de refresco de tokens |
| Security Authz | ✅ 85% | Falta: `IAuthorizationRequirement` extensible |
| JWT | ✅ 90% | Solo HS256; falta RS256 |
| Identity | ✅ 75% | `UserManager` incompleto vs .NET |
| Caching | ✅ 95% | `IHybridCache` (L1+L2) implementado |
| Resilience / Polly | ✅ 85% | Circuit Breaker, Retry, Timeout. Falta: Bulkhead, Policy Registry |
| Mediator / MediatR | ✅ 90% | `IMediator`, `Send`, `Publish`, `IPipelineBehavior`. Falta: `async/await` |
| AutoMapper | ✅ 95% | Prácticamente paridad total |
| Background Services | ✅ 90% | Falta: `IHostedLifecycleService` |
| Health Checks | ✅ 85% | Falta: checks de liveness/readiness separados |
| Message Queue | ✅ 80% | Solo Redis; falta RabbitMQ/Kafka |
| Localization | ✅ 80% | Solo JSON; falta pluralización |
| Commandline | ✅ 75% | Falta: subcomandos, help automático |
| Serialization | ✅ 85% | Falta: source generators |
| **Total estimado** | **~85%** | |

---

## 23. Resilience (Polly)

| Feature | Polly (.NET) | QuickCore Resilience |
|---------|-------------|---------------------|
| Circuit Breaker | `AddCircuitBreaker<T>(opts)` | `TCircuitBreakerPolicy<T>.Create(threshold, breakMs)` |
| Retry | `AddRetry<T>(opts)` | `TRetryPolicy<T>.Create(maxRetries, delayMs, backoffType)` |
| Timeout | `AddTimeout<T>(opts)` | `TTimeoutPolicy<T>.Create(timeoutMs)` |
| Backoff constante | `DelayBackoffType.Constant` | `btConstant` |
| Backoff exponencial | `DelayBackoffType.Exponential` | `btExponential` |
| Backoff jitter | `DelayBackoffType.Exponential` + jitter | `btDecorrelated` (AWS full jitter) |
| Callback onRetry | `OnRetry(args => ...)` | `TRetryEvent` en constructor |
| Callback onStateChange | `OnOpened/OnClosed/OnHalfOpened` | `TCircuitStateChangeEvent` |
| Política nombrada (DI) | `AddResilienceHandler("name", builder => ...)` | `AddCircuitBreaker<T>("name", ...)` (keyed) |
| Excepción open circuit | `BrokenCircuitException` | `ECircuitOpenException` |
| Excepción timeout | `TimeoutRejectedException` | `ETimeoutException` |
| Excepción retry exhausted | — | `ERetryExhaustedException` |
| Composición de políticas | `ResiliencePipelineBuilder` (fluent) | anidado manual: `timeout.Execute(→ retry.Execute(→ cb.Execute(...)))` |

```csharp
// C# — Polly v8
var pipeline = new ResiliencePipelineBuilder<string>()
    .AddTimeout(TimeSpan.FromSeconds(5))
    .AddRetry(new RetryStrategyOptions<string>
    {
        MaxRetryAttempts = 3,
        Delay = TimeSpan.FromMilliseconds(200),
        BackoffType = DelayBackoffType.Exponential
    })
    .AddCircuitBreaker(new CircuitBreakerStrategyOptions<string>
    {
        FailureRatio = 0.5,
        BreakDuration = TimeSpan.FromSeconds(10)
    })
    .Build();

var result = await pipeline.ExecuteAsync(async ct => await httpClient.GetStringAsync(url, ct));
```

```pascal
// Delphi — QuickCore
timeout := TTimeoutPolicy<string>.Create(5000);
retry   := TRetryPolicy<string>.Create(3, 200, btExponential);
cb      := TCircuitBreakerPolicy<string>.Create(5, 10000);

result := timeout.Execute(function: string
  begin
    Result := retry.Execute(function: string
      begin
        Result := cb.Execute(function: string
          begin Result := HttpClient.Get(url) end);
      end);
  end);
```

> **Diferencia clave:** Polly v8 usa un `ResiliencePipeline` unificado con `async/await`; QuickCore compone políticas anidando `Execute` de forma síncrona.

---

## 24. Mediator / CQRS (MediatR)

| Feature | MediatR (.NET) | QuickCore Mediator |
|---------|---------------|-------------------|
| Interfaz | `IMediator` | `IMediator` |
| Enviar request | `await mediator.Send(request, ct)` | `mediator.Send(request)` |
| Publicar notificación | `await mediator.Publish(event, ct)` | `mediator.Publish(notification)` |
| Request con respuesta | `IRequest<TResponse>` | `IRequest<TResponse>` (marcador) |
| Request sin respuesta | `IRequest` (Unit) | `IRequest` (marcador) |
| Notificación | `INotification` | `INotification` |
| Handler request | `IRequestHandler<TReq, TRes>` | `IRequestHandler<TReq, TRes>` / `TRequestHandler<TReq, TRes>` |
| Handler notificación | `INotificationHandler<T>` | `INotificationHandler<T>` / `TNotificationHandler<T>` |
| Pipeline behavior | `IPipelineBehavior<TReq, TRes>` | `IPipelineBehavior<TReq, TRes>` / `TPipelineBehavior<TReq, TRes>` |
| Registro DI | `services.AddMediatR(cfg => cfg.RegisterServicesFromAssembly(...))` | `services.Extension<TMediatorServiceExtension>.AddMediatR.AddRequestHandler<...>...` |
| Type-safe dispatch | implícito (`await mediator.Send<TRes>(req)`) | `mediator.SendRequest<TRes>(req)` (inyectar `TMediator`) |
| Async | sí (`Task<TResponse>`) | no (síncrono) |

```csharp
// C# — MediatR
public record GetProductQuery(int Id) : IRequest<ProductDto>;

public class GetProductHandler : IRequestHandler<GetProductQuery, ProductDto>
{
    public Task<ProductDto> Handle(GetProductQuery req, CancellationToken ct)
        => Task.FromResult(_repo.GetById(req.Id));
}

// Registro
services.AddMediatR(cfg => cfg.RegisterServicesFromAssembly(Assembly.GetExecutingAssembly()));

// Uso
var dto = await _mediator.Send(new GetProductQuery(id));
```

```pascal
// Delphi — QuickCore Mediator
type
  TGetProductQuery = class
    ProductId: Integer;
  end;

  TGetProductHandler = class(TRequestHandler<TGetProductQuery, TProductDto>)
    function Handle(const aRequest: TGetProductQuery): TProductDto; override;
  end;

// Registro
services.Extension<TMediatorServiceExtension>
  .AddMediatR
  .AddRequestHandler<TGetProductQuery, TProductDto, TGetProductHandler>
  .Build;

// Uso
dto := fMediator.SendRequest<TProductDto>(TGetProductQuery.Create(id));
```

---

## 25. HybridCache

| Feature | ASP.NET Core (.NET 9) | QuickCore |
|---------|----------------------|-----------|
| Interfaz | `IHybridCache` | `IHybridCache` |
| GetOrCreate | `hybridCache.GetOrCreateAsync(key, factory, opts)` | `hybridCache.GetOrCreate(key, factory, localMs, remoteMs)` |
| Set directo | `hybridCache.SetAsync(key, value, opts)` | `hybridCache.SetValue(key, value, localMs, remoteMs)` |
| Eliminar | `hybridCache.RemoveAsync(key)` | `hybridCache.Remove(key)` |
| L1 (local) | `IMemoryCache` | `IMemoryCache` |
| L2 (distribuido) | `IDistributedCache` (Redis, etc.) | `IDistributedCache` (Redis) |
| Registro | `services.AddHybridCache(opts => ...)` | `services.Extension<THybridCacheServiceExtension>.AddHybridCache(proc)` |
| Opciones TTL L1 | `HybridCacheEntryOptions.LocalCacheExpiration` | `DefaultLocalExpirationMs` |
| Opciones TTL L2 | `HybridCacheEntryOptions.Expiration` | `DefaultRemoteExpirationMs` |
| Bypass L1 | `LocalCacheMode.Disabled` | `LocalCacheEnabled := False` |
| Async | sí (`ValueTask<T>`) | no (síncrono) |

```csharp
// C# (.NET 9)
var value = await hybridCache.GetOrCreateAsync(
    $"product:{id}",
    async ct => await repo.GetByIdAsync(id, ct),
    new HybridCacheEntryOptions
    {
        LocalCacheExpiration = TimeSpan.FromMinutes(1),
        Expiration = TimeSpan.FromMinutes(10)
    });
```

```pascal
// Delphi
var value := hybridCache.GetOrCreate(
  Format('product:%d', [id]),
  function: string begin Result := ObjectToJson(repo.GetById(id)) end,
  {localMs} 60_000,
  {remoteMs} 600_000);
```

---

## 26. FluentValidation Builder

| Feature | FluentValidation (.NET) | QuickCore |
|---------|------------------------|----------|
| Clase base | `AbstractValidator<T>` | `TAbstractValidator<T>` |
| Definir regla | `RuleFor(x => x.Prop)` | `RuleFor('PropName')` (RTTI) |
| Reglas string | `NotEmpty()`, `Length(min,max)`, `EmailAddress()`, `Matches(re)` | `NotEmpty`, `Length(min,max)`, `EmailAddress`, `Matches(re)` |
| Reglas numéricas | `GreaterThan(v)`, `InclusiveBetween(a,b)` | `GreaterThan(v)`, `InclusiveBetween(a,b)` |
| Predicado custom | `.Must(pred)` | `.Must(TValuePredicate)` |
| Mensaje custom | `.WithMessage('msg')` | `.WithMessage('msg')` |
| Resultado | `ValidationResult.IsValid` | `TValidationResult.IsValid` |
| Errores | `IList<ValidationFailure>` | `TList<TValidationError>` |
| DI | `IValidator<T>` | `IValidator<T>` + `TValidatorAdapter<T>` |
| Registro | `services.AddValidatorsFromAssemblyContaining<T>()` | `services.AddSingleton<IValidator<T>>(TValidatorAdapter<T>.Create(...))` |

```csharp
// C# — FluentValidation
public class CreateUserValidator : AbstractValidator<CreateUserRequest>
{
    public CreateUserValidator()
    {
        RuleFor(x => x.Name).NotEmpty().Length(2, 100);
        RuleFor(x => x.Email).NotEmpty().EmailAddress();
        RuleFor(x => x.Age).GreaterThanOrEqualTo(18);
    }
}
var result = validator.Validate(request);
if (!result.IsValid)
    return BadRequest(result.Errors);
```

```pascal
// Delphi — QuickCore
constructor TCreateUserValidator.Create;
begin
  inherited;
  RuleFor('Name').NotEmpty.Length(2, 100);
  RuleFor('Email').NotEmpty.EmailAddress;
  RuleFor('Age').GreaterThanOrEqualTo(18);
end;

vResult := validator.Validate(request);
if not vResult.IsValid then
  Exit(BadRequest(vResult.Errors));
```

---

## 27. Distributed Tracing (OpenTelemetry)

| Feature | .NET (OpenTelemetry.Api) | QuickCore |
|---------|--------------------------|----------|
| Unidad de trabajo | `Activity` | `ISpan` |
| Wrapper RAII | `using var a = source.StartActivity(...)` | `TActivity` (destructor llama Stop) |
| Fábrica de spans | `ActivitySource` | `ITracer` / `TActivitySource` |
| Proveedor global | `TracerProvider` | `ITracerProvider` |
| Estado | `ActivityStatusCode` (Unset/Ok/Error) | `TSpanStatus` (ssUnset/ssOk/ssError) |
| Tipo de span | `ActivityKind` | `TSpanKind` |
| Tags | `activity.SetTag(key, value)` | `span.SetTag(key, value)` |
| Eventos | `activity.AddEvent(name)` | `span.AddEvent(name)` |
| Propagación W3C | Automática (middleware) | `Inject/Extract` + propiedad `Traceparent` |
| Exporter | `OtlpTraceExporter` | `TJaegerExporter` (OTLP/HTTP, puerto 4318) |
| Registro DI | `services.AddOpenTelemetry().WithTracing(b => ...)` | `services.AddTelemetry('svc').AddExporter(exp).Build` |

```csharp
// C# — .NET OpenTelemetry
builder.Services.AddOpenTelemetry()
    .WithTracing(b => b
        .AddSource("orders-api")
        .AddOtlpExporter(o => o.Endpoint = new Uri("http://jaeger:4318")));

using var activity = _activitySource.StartActivity("ProcessOrder", ActivityKind.Server);
activity?.SetTag("order.id", orderId);
activity?.SetStatus(ActivityStatusCode.Ok);
```

```pascal
// Delphi — QuickCore
var jaegerOpts := TJaegerExporterOptions.Create;
jaegerOpts.Endpoint := 'http://jaeger:4318';
services
  .AddTelemetry('orders-api')
    .AddExporter(TJaegerExporter.Create(jaegerOpts))
    .SetAsGlobal.Build;

// En controller:
span := fTracer.StartSpan('ProcessOrder', skServer);
span.SetTag('order.id', orderId.ToString);
span.SetStatus(ssOk);
span.Finish;
```

---

## Ver también

- [Dependency Injection](wiki/Dependency-Injection.md)
- [Entity / ORM](wiki/Entity-ORM.md)
- [MVC](wiki/MVC.md)
- [Security](wiki/Security.md)
- [Resilience](wiki/Resilience.md)
- [Mediator / CQRS](wiki/Mediator.md)
- [FluentValidation](wiki/FluentValidation.md)
- [Telemetry](wiki/Telemetry.md)
- [API Reference](API-Reference.md)
- [Migration Guide](Migration-Guide.md)
