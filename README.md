![alt text](docs/QuickCore.png "QuickCore")

> **Delphi framework inspired by ASP.NET Core** for building high-performance, scalable desktop, service and web applications. Windows · Linux · Android · macOS · iOS. Delphi 10 to 12 Athens.

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE.txt)
[![Delphi](https://img.shields.io/badge/Delphi-10..12%20Athens-red.svg)](https://www.embarcadero.com/products/delphi)
[![Tests](https://img.shields.io/badge/tests-85%20passing-brightgreen.svg)](tests/)

---

## ⭐ Give it a star
Please "star" this project in GitHub! It costs nothing but helps to reference the code.

[![Star History Chart](https://api.star-history.com/svg?repos=exilon/quickcore&type=Date)](https://star-history.com/#exilon/quickcore&Date)

## 💖 Support
If you find this project useful, please consider making a donation.

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate/?hosted_button_id=BKLKPNEYKSBKL)

---

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Dependency Injection](#dependency-injection)
- [Configuration & Options](#configuration--options)
- [Entity ORM](#entity-orm)
- [MVC / WebAPI](#mvc--webapi)
- [Authentication & Authorization](#authentication--authorization)
- [AutoMapper](#automapper)
- [Caching](#caching)
- [Localization](#localization)
- [Background Services](#background-services)
- [Health Checks](#health-checks)
- [Message Queue](#message-queue)
- [Samples](#samples)
- [Running Tests](#running-tests)
- [Unit Reference](#unit-reference)

---

## Features

| Area | Feature |
|------|---------|
| **DI / IoC** | Singleton · Transient · Scoped · Named services · Keyed services · Factory delegates · `IOptions<T>` · `IServiceScope` |
| **Entity ORM** | SQLite · SQL Server · MySQL · MS Access · PostgreSQL · CRUD · LINQ · Migrations · Navigation properties · Soft delete · Optimistic concurrency · Repository · Unit of Work · Seeding |
| **MVC / WebAPI** | Attribute routing · `[FromBody]` · `[FromQuery]` · `[FromHeader]` · `[FromForm]` · Model validation · Action filters · Exception handler · Rate limiting · CORS · Compression · API versioning · Swagger/OpenAPI · Minimal API · Content negotiation |
| **Auth** | JWT Bearer · API Key · Cookie · OAuth2 / OpenID Connect · ASP.NET-style Identity · 2FA/TOTP · Resource-based authorization · Policies |
| **AutoMapper** | Profile maps · `ForMember` · `ReverseMap` · `Condition` · `ConvertUsing` · `BeforeMap` · `AfterMap` · `NullSubstitute` · Map context · `AssertConfigurationIsValid` |
| **Caching** | In-memory · Redis |
| **Localization** | `IStringLocalization` · Culture files · `Accept-Language` header |
| **Background** | `IHostedService` · `IBackgroundService` · `ITaskControl` (background + scheduled tasks) |
| **Health Checks** | URL · SQL Server · Redis · Entity DB · Dashboard |
| **Message Queue** | Redis producer/consumer · Reliable queue · Configurable pool |
| **View Engine** | Mustache templates · Layouts · Partials · Custom helpers |
| **Session** | In-memory session store · Session middleware · Cookie-based session ID |

---

## Requirements

- **Delphi** 10 (Seattle) through 12 Athens
- **[QuickLib](https://github.com/exilon/QuickLib)** — core utilities (required)
- **[QuickLogger](https://github.com/exilon/QuickLogger)** — logging backend (required)
- **FireDAC** — for Entity engines (included with Delphi)
- **Redis** — only for Redis caching / message queue samples

---

## Installation

### Via Delphinus Package Manager (recommended)
1. Open Delphinus in the Delphi IDE.
2. Search for **QuickCore** and click *Install*.
3. Delphinus will resolve and install QuickLib and QuickLogger automatically.

### Manual (GitHub)
```
git clone https://github.com/exilon/QuickCore
git clone https://github.com/exilon/QuickLib
git clone https://github.com/exilon/QuickLogger
```
Add all three folders to **Tools → Options → Library path** in the Delphi IDE.

---

## Quick Start

Create a minimal REST API in under 30 lines:

**`HelloWorld.dpr`**
```delphi
program HelloWorld;
{$APPTYPE CONSOLE}
uses Quick.Core.Mvc, Startup in 'Startup.pas';
var Server : TMvcServer;
begin
  Server := TMvcServer.Create('127.0.0.1', 8080, False);
  Server.UseStartup<TStartup>;
  Server.Start;
  Readln;
  Server.Free;
end.
```

**`Startup.pas`**
```delphi
unit Startup;
interface
uses Quick.Core.Mvc, Quick.Core.DependencyInjection, Controller.Home;
type
  TStartup = class(TStartupMvc)
  public
    class procedure ConfigureServices(services : TServiceCollection); override;
    class procedure Configure(app : TMVCServer); override;
  end;
implementation
class procedure TStartup.ConfigureServices(services : TServiceCollection);
begin
  services.AddLogging(TLoggerBuilder.GetBuilder.AddConsole.Build);
end;
class procedure TStartup.Configure(app : TMVCServer);
begin
  app.AddControllers.AddController(THomeController).UseRouting.UseMVC;
end;
end.
```

**`Controller.Home.pas`**
```delphi
unit Controller.Home;
interface
uses Quick.Core.Mvc.Controller, Quick.Core.Mvc.ActionResult;
type
  [Route('api')]
  [ApiController]
  THomeController = class(THttpController)
  published
    [HttpGet('hello')]
    function Hello : IActionResult;
  end;
implementation
function THomeController.Hello: IActionResult;
begin
  Result := Json('{"message":"Hello, World!"}');
end;
initialization
  RegisterController(THomeController);
end.
```

```
GET http://localhost:8080/api/hello
→ {"message":"Hello, World!"}
```

---

## Dependency Injection

QuickCore's built-in IoC container supports constructor injection, three lifetimes, named/keyed services and factory delegates.

### Lifetimes

```delphi
// Singleton — same instance for the whole app lifetime
services.AddSingleton<IMyService, TMyService>;

// Transient — new instance on every resolution
services.AddTransient<IMyService, TMyService>;

// Scoped — one instance per request scope
services.AddScoped<IMyService, TMyService>;
```

### Factory delegate

```delphi
services.AddSingleton<IMyService, TMyService>('',
  function : TMyService
  begin
    Result := TMyService.Create('some-param');
  end);
```

### Named / Keyed services

```delphi
services.AddSingleton<ICache, TRedisCache>('redis');
services.AddSingleton<ICache, TMemoryCache>('memory');

// Resolve by name
var cache := provider.GetService<ICache>('redis');

// Inject by name in a controller action parameter
function MyAction([FromKeyedServices('redis')] cache : ICache) : IActionResult;
```

### IOptions\<T\>

```delphi
// Register with defaults
services.Configure<TSmtpOptions>(procedure(o : TSmtpOptions)
begin
  o.Host := 'localhost';
  o.Port := 25;
end);

// Inject
constructor TMailService.Create(opts : IOptions<TSmtpOptions>);
begin
  fHost := opts.Value.Host;
end;
```

---

## Configuration & Options

Options are persisted to a YAML (or JSON) file. Use the `CORE_ENVIRONMENT` environment variable to select environment-specific files (`QuickCore.production.yaml`, etc.).

```delphi
services
  .AddOptions(TOptionsFileFormat.ofYAML, True)
  .Configure<TAppSettings>(procedure(o : TAppSettings)
    begin
      o.Smtp   := 'mail.domain.com';
      o.ApiUrl := 'https://api.example.com';
    end);
```

Environment variable expansion inside config files is supported: `${MY_SECRET_KEY}`.

---

## Entity ORM

QuickCore includes a lightweight ORM similar to EF Core.

### Define entities

```delphi
[Table('products')]
TProduct = class(TEntity)
private
  FId    : TAutoID;
  FName  : string;
  FPrice : Double;
public
  [Key]
  property Id    : TAutoID read FId    write FId;
  property Name  : string  read FName  write FName;
  property Price : Double  read FPrice write FPrice;
end;
```

### Define a DB context

```delphi
TShopContext = class(TDBContext)
private
  FProducts : TDBSet<TProduct>;
public
  property Products : TDBSet<TProduct> read FProducts write FProducts;
  constructor Create(aConn : TDBConnectionModel); override;
end;
```

### Register in Startup

```delphi
services.Extension<TEntityServiceExtension>
  .AddDBContext<TShopContext>(procedure(o : TDBContextOptionsBuilder)
    begin
      o.UseSQLite.UseDatabase('shop.db');
    end);
```

### CRUD

```delphi
// Inject context
constructor TProductsController.Create(ctx : TShopContext);

// Add
ctx.Products.Add(product);

// Query
var list := ctx.Products.Where('Price < ?', [100.0]).OrderBy('Name').Select;

// Update / Delete
ctx.Products.Update(product);
ctx.Products.Delete(product);
```

### Migrations

```delphi
type
  TAddCategoryMigration = class(TMigration)
  public
    procedure Up; override;
    procedure Down; override;
  end;

procedure TAddCategoryMigration.Up;
begin
  ExecuteSQL('ALTER TABLE products ADD COLUMN Category VARCHAR(100)');
end;
```

### Repository pattern

```delphi
// IRepository<T> is included — register via factory
services.AddScoped<IRepository<TProduct>, TEntityRepository<TProduct>>('',
  function : TEntityRepository<TProduct>
  begin
    Result := TEntityRepository<TProduct>.Create(
      services.Resolve<TShopContext>.Products, 'Id');
  end);
```

### Unit of Work (transactions)

```delphi
ctx.Database.BeginTransaction;
try
  ctx.Orders.Add(order);
  ctx.OrderItems.Add(item);
  ctx.Database.CommitTransaction;
except
  ctx.Database.RollbackTransaction;
  raise;
end;
```

### Soft Delete & Optimistic Concurrency

```delphi
// Soft delete — inherit from TEntitySD; deleted rows are filtered automatically
[SoftDelete]
TPost = class(TEntitySD) ...

// Optimistic concurrency — inherit from TEntityRV; conflict raises EOptimisticConcurrencyException
TProduct = class(TEntityRV) ...
```

---

## MVC / WebAPI

### Routing attributes

```delphi
[Route('api/products')]
[ApiController]
TProductsController = class(THttpController)
published
  [HttpGet]
  function List : IActionResult;

  [HttpGet('{id}')]
  function GetById(id : Integer) : IActionResult;

  [HttpPost]
  function Create([FromBody] product : TProduct) : IActionResult;

  [HttpPut('{id}')]
  function Update(id : Integer; [FromBody] product : TProduct) : IActionResult;

  [HttpDelete('{id}')]
  function Delete(id : Integer) : IActionResult;
end;
```

### Parameter binding

| Attribute | Source |
|-----------|--------|
| `[FromBody]` | JSON request body (auto-deserialized) |
| `[FromQuery]` | Query string: `?name=value` |
| `[FromHeader]` | Request header |
| `[FromForm]` | Multipart form / file upload |
| *(path segment)* | URL path parameter `{id}` |

### Model Validation

```delphi
TCreateProductDto = class
  [Required]
  [StringLength(100)]
  property Name  : string read ... write ...;

  [Range(0.01, 1000000)]
  property Price : Double read ... write ...;
end;
// Validation is automatic — returns HTTP 400 + JSON errors on failure
```

### Action Results

```delphi
Result := Ok;                          // 200
Result := Json(obj);                   // 200 + serialized JSON
Result := StatusCode(201, '...');      // custom status
Result := BadRequest('invalid input'); // 400
Result := NotFound;                    // 404
Result := Unauthorized;               // 401
Result := Redirect('https://...');    // 302
Result := View('home');               // render Mustache view
```

### Middlewares

```delphi
app
  .UseExceptionHandler              // global 500 handler
  .UseCors(procedure(o : TCorsPolicyOptions) begin
      o.AllowAnyOrigin.AllowAnyMethod.AllowAnyHeader;
    end)
  .UseRateLimiting(100, 60)         // 100 req / 60 s
  .UseResponseCompression
  .UseAuthentication
  .UseAuthorization
  .UseSession
  .UseSwagger                       // /swagger + /swagger/v1/swagger.json
  .UseStaticFiles
  .UseRouting
  .UseMVC;
```

### Swagger / OpenAPI

```delphi
app.UseSwagger;
// Browse: http://localhost:8080/swagger
```

Enrich operations with attributes:
```delphi
[SwaggerOperation('List all products')]
[ProducesResponseType(200)]
[ProducesResponseType(401)]
function List : IActionResult;
```

### Minimal API

```delphi
server.MapGet('/ping', function(ctx : THttpContext) : string
  begin
    Result := '{"pong":true}';
  end);
```

---

## Authentication & Authorization

### JWT Bearer

```delphi
services.Extension<TAuthenticationServiceExtension>
  .AddAuthentication
  .AddJwtBearer(procedure(o : TJwtOptions)
    begin
      o.Secret         := 'my-256-bit-secret';
      o.Issuer         := 'my-app';
      o.ExpiryMinutes  := 60;
    end);

app.UseAuthentication.UseAuthorization;
```

Generate a token:
```delphi
// Inject IJwtTokenService
var token := fJwt.GenerateToken(userId, username, ['Admin']);
```

### API Key

```delphi
services.Extension<TApiKeyAuthenticationServiceExtension>
  .AddApiKey
  .UseMemoryStore(procedure(o : TApiKeyMemoryStoreOptions)
    begin
      o.AddApiKey('Alice', 'Admin', 'secret-key-abc');
      o.AddApiKey('Bob',   'User',  'secret-key-xyz');
    end);
```

### Authorization Policies

```delphi
services.Extension<TAuthorizationServiceExtension>
  .AddAuthorization(procedure(o : TAuthorizationOptions)
    begin
      o.AddPolicy('AdminOnly',
        TAuthorizationPolicyBuilder.GetBuilder
          .RequireAuthenticatedUser
          .RequireClaim(TClaimTypes.Role, 'Admin')
          .Build);
    end);

// In controller
[Authorize]                         // any authenticated user
[Authorize(Policy='AdminOnly')]     // admin only
[AllowAnonymous]                    // bypass auth
```

### ASP.NET-style Identity

```delphi
services.Extension<TAuthenticationServiceExtension>
  .AddIdentity<TAppUser, TAppRole>(procedure(o : TIdentityOptions)
    begin
      o.Password.RequiredLength  := 8;
      o.User.RequireUniqueEmail  := True;
    end)
  .AddEntityStore<TIdentityContext>;

// Inject IUserManager<TUser, TRole>
fUserManager.CreateUser(user, password);
fUserManager.ValidateCredentials(username, password);
fUserManager.AddToRole(userId, 'Admin');
```

---

## AutoMapper

```delphi
// Define a profile
constructor TMyProfile.Create;
begin
  CreateMap<TDBProduct, TProductDto>
    .ForMember('Name', 'FullName')   // rename property
    .ReverseMap;                     // also maps TProductDto → TDBProduct
end;

initialization
  TAutoMapper.RegisterProfile<TMyProfile>;
```

### Advanced mapping

```delphi
CreateMap<TDBProduct, TProductDto>
  .Condition('Price', function(src : TObject) : Boolean  // skip when condition false
    begin Result := (src as TDBProduct).Price > 0; end)
  .ConvertUsing('Category', function(v : TValue) : TValue  // transform value
    begin Result := TValue.From(v.AsString.ToUpper); end)
  .BeforeMap(procedure(src, dst : TObject) begin ... end)
  .AfterMap(procedure(src, dst : TObject)  begin ... end)
  .NullSubstitute('(none)')
  .IgnoreOtherMembers;

// Validate all maps at startup
TAutoMapper.AssertConfigurationIsValid;
```

### Inject and use

```delphi
constructor TController.Create(mapper : IMapper);
...
var dto := fMapper.Map<TProductDto>(dbProduct);
```

---

## Caching

### Memory Cache

```delphi
services.Extension<TMemoryCacheServiceExtension>.AddMemoryCache;

// Inject IMemoryCache
if not fCache.TryGetValue<TList<TProduct>>('products', list) then
begin
  list := GetFromDB;
  fCache.SetValue<TList<TProduct>>('products', list, 60); // TTL 60 s
end;
```

### Redis Cache

```delphi
services.Extension<TRedisCacheServiceExtension>
  .AddRedisCache(procedure(o : TRedisCacheOptions)
    begin
      o.Host     := 'localhost';
      o.Port     := 6379;
      o.DataBase := 0;
    end);
```

---

## Localization

```delphi
services.Extension<TLocalizationServiceExtension>
  .AddLocalization(procedure(o : TLocalizationOptions)
    begin
      o.AddCulture('en');
      o.AddCulture('es');
      o.AddCulture('fr');
      o.AddIfNotfound := True;
    end);

// Inject IStringLocalization — culture selected from Accept-Language header
var msg := fL10n.GetItemFmt('greeting', [userName]);
```

Place locale files in `locales/` next to the executable:
```
locales/en.lng   →  greeting=Hello, %s!
locales/es.lng   →  greeting=¡Hola, %s!
locales/fr.lng   →  greeting=Bonjour, %s!
```

---

## Background Services

### IHostedService

```delphi
type
  TMyWorker = class(TBackgroundService)
  protected
    procedure Execute; override;
  end;

// Register
services.Extension<THostedServiceExtension>.AddHostedService<TMyWorker>;
```

### Task Control (background + scheduled)

```delphi
services.Extension<TTaskControlServiceExtension>.AddTaskControl;

// After build — queue an ad-hoc task
fTaskControl.BackgroundTasks.QueueTask(procedure begin
  DoSomeWork;
end);

// Schedule a recurring task
fTaskControl.ScheduledTasks.AddTask('CleanUp')
  .RunEvery(3600000)  // every hour
  .OnExecute(procedure begin CleanOldRecords; end);
```

---

## Health Checks

```delphi
services
  .Extension<THealthChecksServiceExtension>
    .AddHealthChecks
    .AddUrlCheck('google', 'https://www.google.com', TTimeSpan.FromSeconds(5))
    .AddDBContextCheck<TShopContext>('db', TTimeSpan.FromSeconds(5))
    .AddMemoryCheck('memory', 512, TTimeSpan.FromSeconds(30))
    .AddInMemoryStorage;

app.Extension<THealthChecksUIMVCServerExtension>
  .UseHealthChecksUI;
// GET /health      → Xabaril-style summary JSON
// GET /health/live → liveness
// GET /healthui    → HTML dashboard
```

---

## Message Queue

Redis-backed reliable producer/consumer queue:

```delphi
services.Extension<TMessageQueueServiceExtension>
  .AddRedisMessageQueue<TOrderProcessor>(procedure(o : TRedisMessageQueueOptions)
    begin
      o.Host                := 'localhost';
      o.Port                := 6379;
      o.Key                 := 'orders';
      o.MaxConsumersPool    := 3;
      o.ReliableMessageQueue.Enabled := True;
    end);

// Produce (inject IMessageQueue<TOrderMessage>)
fQueue.Enqueue(msg);

// Consume (TOrderProcessor extends TMessageQueueTask<TOrderMessage>)
procedure TOrderProcessor.ProcessMessage(aMessage : TOrderMessage);
begin
  // called automatically for each dequeued message
end;
```

---

## Samples

24 ready-to-compile projects in `samples/delphi/`:

### Basic
| # | Project | Description |
|---|---------|-------------|
| S-01 | `HelloWorldApi` | Minimal API — one controller, one GET endpoint |
| S-02 | `DependencyInjection` | Singleton / Transient / Scoped lifetimes demo |
| S-03 | `OptionsPattern` | `TMyOptions`, YAML config, `IOptions<T>` injection |
| S-04 | `AutoMapperBasic` | Profile, `CreateMap`, `ForMember`, `Map<T>` |
| S-05 | `EntityCRUD` | SQLite CRUD with `TDBContext` + `TDBSet<T>` |

### Intermediate
| # | Project | Description |
|---|---------|-------------|
| S-06 | `WebApiWithDI` | REST API with `IProductService` injected in controller |
| S-07 | `WebApiWithDatabase` | REST API + SQLite, YAML config |
| S-08 | `WebApiWithLogging` | Console + file logging, `ILogger` injection |
| S-09 | `WebApiWithCaching` | Cache-aside pattern with `IMemoryCache` |
| S-10 | `WebApiWithAutoMapper` | DTO ↔ entity mapping in a REST pipeline |
| S-11 | `CustomMiddleware` | Custom middleware class + inline `Use(func)` |
| S-12 | `HealthChecksDashboard` | `/health`, `/health/live`, `/health/ready` and `/healthui` dashboard |

### Advanced
| # | Project | Description |
|---|---------|-------------|
| S-13 | `WebApiWithApiKeyAuth` | API Key auth, `AdminOnly` policy, `[Authorize]` / `[AllowAnonymous]` |
| S-14 | `WebApiWithIdentity` | Full Identity: register/login, `IUserManager`, SQLite store |
| S-15 | `CleanArchitectureApi` | Domain / Application / Infrastructure / Presentation layers |
| S-16 | `BackgroundJobsService` | `ITaskControl`: background + scheduled tasks |
| S-17 | `WindowsServiceApp` | `--install` / `--remove` as a Windows Service |
| S-18 | `MultipleDbContexts` | Two independent SQLite `TDBContext` in one app |
| S-19 | `MessageQueueRedis` | Redis producer/consumer with reliable queue |
| S-20 | `LocalizationSample` | `IStringLocalization` + `Accept-Language` header |

### Design Patterns
| # | Project | Description |
|---|---------|-------------|
| S-21 | `RepositoryPattern` | `IRepository<T>` + `TEntityRepository<T>` wired via DI |
| S-22 | `UnitOfWorkPattern` | Multi-entity atomic operation with `BeginTransaction` |
| S-23 | `DecoratorPattern` | Caching decorator for `IProductService` via DI factory |
| S-24 | `ChainOfResponsibility` | Pure validation pipeline: `NotEmpty → Length → Price` |

---

## Running Tests

85 DUnitX tests covering DI, AutoMapper, Entity ORM, Security, MVC, and Caching:

```
tests/bin/Win64/Debug/QuickCore.Tests.exe
```

Or compile and run `tests/QuickCore.Tests.dproj` from the Delphi IDE.

---

## Unit Reference

### Abstractions
| Unit | Description |
|------|-------------|
| `Quick.Core.Logging.Abstractions` | `ILogger` interface |
| `Quick.Core.Caching.Abstractions` | `IMemoryCache` / `ICache` interfaces |
| `Quick.Core.Mapping.Abstractions` | `IMapper` interface |
| `Quick.Core.Localization.Abstractions` | `IStringLocalization` interface |
| `Quick.Core.MessageQueue.Abstractions` | `IMessageQueue<T>` · `TMessageQueueTask<T>` |
| `Quick.Core.Entity.Repository` | `IRepository<T>` · `TEntityRepository<T>` |

### Services
| Unit | Description |
|------|-------------|
| `Quick.Core.DependencyInjection` | `TServiceCollection` · `TActivatorDelegate<T>` · `IOptions<T>` · `IServiceScope` |
| `Quick.Core.AutoMapper` | `TAutoMapper` · `TProfileMap` |
| `Quick.Core.Entity` | `TEntity` · `TDBContext` · `TDBSet<T>` · `TEntitySD` · `TEntityRV` |
| `Quick.Core.Entity.Migrations` | `TMigration` · `TMigrationsManager` |
| `Quick.Core.Entity.UnitOfWork` | `IUnitOfWork` · `TUnitOfWork` |
| `Quick.Core.Logging` | `TLoggerBuilder` |
| `Quick.Core.Identity` | `TIdentityOptions` · `TIdentityDbContext<TUser,TRole>` |
| `Quick.Core.Security.UserManager` | `IUserManager<TUser,TRole>` |
| `Quick.Core.Security.Jwt` | `IJwtTokenService` · `TJwtOptions` |
| `Quick.Core.TaskControl` | `ITaskControl` · `TBackgroundTasks` · `TScheduledTasks` |

### MVC
| Unit | Description |
|------|-------------|
| `Quick.Core.Mvc` | `TMvcServer` · `TStartupMvc` · middleware chain |
| `Quick.Core.Mvc.Controller` | `THttpController` · routing/auth attributes |
| `Quick.Core.Mvc.ActionResult` | `IActionResult` · `Ok` · `Json` · `NotFound` etc. |
| `Quick.Core.Mvc.ActionInvoker` | Parameter binding · model validation |
| `Quick.Core.Mvc.ModelValidation` | `[Required]` · `[Range]` · `[StringLength]` · `TModelState` |
| `Quick.Core.Mvc.Filters` | `TActionFilterAttribute` |
| `Quick.Core.Mvc.Middleware.Cors` | `TCorsMiddleware` |
| `Quick.Core.Mvc.Middleware.Swagger` | `TSwaggerMiddleware` · OpenAPI 3.0 |
| `Quick.Core.Mvc.Middleware.RateLimit` | `TRateLimitMiddleware` |
| `Quick.Core.Mvc.Middleware.Compression` | Gzip / Deflate response compression |
| `Quick.Core.Mvc.Middleware.ExceptionHandler` | Global 500 handler |
| `Quick.Core.Mvc.Middleware.Session` | `TSessionMiddleware` · `TInMemorySessionStore` |
| `Quick.Core.Mvc.ViewEngine.Mustache` | Mustache templates · layouts · partials |

### Extensions (DI registration helpers)
| Unit | Description |
|------|-------------|
| `Quick.Core.Extensions.Entity` | `AddDBContext<T>` |
| `Quick.Core.Extensions.Authentication` | `AddAuthentication` · `AddIdentity<TUser,TRole>` |
| `Quick.Core.Extensions.Authentication.Jwt` | `AddJwtBearer` |
| `Quick.Core.Extensions.Authentication.ApiKey` | `AddApiKey` · `UseMemoryStore` |
| `Quick.Core.Extensions.Authentication.Cookie` | `AddCookie` |
| `Quick.Core.Extensions.Authentication.OAuth2` | `AddOpenIdConnect` |
| `Quick.Core.Extensions.Authorization` | `AddAuthorization` |
| `Quick.Core.Extensions.AutoMapper` | `AddAutoMapper` |
| `Quick.Core.Extensions.Caching.Memory` | `AddMemoryCache` |
| `Quick.Core.Extensions.Caching.Redis` | `AddRedisCache` |
| `Quick.Core.Extensions.Localization` | `AddLocalization` |
| `Quick.Core.Extensions.Hosting` | `AddHostedService<T>` |
| `Quick.Core.Extensions.HealthChecks` | `AddHealthChecks` |
| `Quick.Core.Extensions.MessageQueue.Redis` | `AddRedisMessageQueue<T>` |
| `Quick.Core.Extensions.Compression` | `AddResponseCompression` |
| `Quick.Core.Extensions.Serialization` | `AddSerialization` |

---

> Do you want to learn Delphi or improve your skills? [learndelphi.org](https://learndelphi.org)

*Last updated: April 2026 — QuickCore v2.0 · 85 tests passing · 24 samples*

