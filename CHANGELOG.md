# Changelog

> Historial de cambios de QuickCore siguiendo [Semantic Versioning](https://semver.org) (MAJOR.MINOR.PATCH).  
> Formato basado en [Keep a Changelog](https://keepachangelog.com).

---

## [2.11.0] — 2026-04-30

### Added
- **HealthChecks — DiskStorage**: `TDiskStorageHealthCheck`, `TDiskStorageHealthCheckOptions` (Path, MinFreeGB), `AddDiskStorageCheck`.
- **HealthChecks — Memory**: `TMemoryHealthCheck`, `TMemoryHealthCheckOptions` (MaxUsedMB), `AddMemoryCheck`.
- **HealthChecks — MySQL**: `TMySQLHealthCheck` via ODBC, `TMySQLHealthCheckOptions` (Host/Port/Database/Username/Password/Driver/ConnectionTimeout), `AddMySQLCheck`.
- **HealthChecks — RabbitMQ**: `TRabbitMQHealthCheck` via AMQP 0-9-1 handshake, `TRabbitMQHealthCheckOptions` (Host/Port/ConnectionTimeout/ReadTimeout), `AddRabbitMQCheck`.
- **Data Protection**: `IDataProtector` (Protect/Unprotect/CreateProtector), `IDataProtectionProvider`, `TDataProtectionProvider` (in-memory), `TFileKeyStoreDataProtectionProvider` (file-backed), `SecureRandomBytes` (OS CSPRNG). DI: `AddDataProtection`, `AddDataProtectionWithFileStore`.
- **Entity Migrations**: `TMigration` abstract (Up/Down with TDBContext), `TMigrationsManager` (ApplyMigrations/RollbackLast/GetAppliedMigrations), `TEntityMigrationsHistory` entity, `__MigrationsHistory` table auto-created. Transactional per migration.
- **Repository Pattern**: `IRepository<T>` with full CRUD + LINQ, `TEntityRepository<T>`.
- **Unit of Work**: `IUnitOfWork` + `TUnitOfWork` with BeginTransaction/Commit/Rollback and `Execute(TProc):Boolean`.
- **TOTP / 2FA**: `ITotpService` + `TTotpService` (RFC 6238): GenerateCode, ValidateCode (±window steps), GetProvisioningUri (otpauth:// for QR codes).
- **Rate Limiting Middleware**: `TRateLimitMiddleware` + `TRateLimitPolicy` (sliding window, per-IP or custom KeySelector). `[RateLimit]` attribute for per-action override. 429 + Retry-After + JSON error body. Thread-safe. `UseRateLimiting(maxReq, winSecs)`.
- **OptionsMonitor / OptionsSnapshot**: `IOptionsMonitor<T>` with OnChange callback + `IOptionsChangeToken` (Unregister), `IOptionsSnapshot<T>` for read-only. DI: `AddOptionsMonitor<T>`, `AddOptionsSnapshot<T>`.

---

## [2.10.0] — 2026-05-02

### Added
- **FluentValidation Builder** (V-05) — `TAbstractValidator<T>` con `RuleFor` chainable; `TPropertyRuleBuilder` con 15+ reglas integradas (`NotEmpty`, `EmailAddress`, `Matches`, `GreaterThan`, `InclusiveBetween`, `Must`…); `IValidator<T>` para DI; `TValidatorAdapter<T>` para registrar cualquier `TAbstractValidator<T>` como `IValidator<T>`. Equivalente a `FluentValidation` (.NET).
- **OpenTelemetry Core API** (T-01) — Abstracciones: `ISpan`, `ITracer`, `ITracerProvider`, `ISpanExporter`, `TSpanKind`, `TSpanStatus`, `TSpanAttributes`, `TSpanEvent`. Propagación W3C Trace Context (cabecera `traceparent`). Null object `TNoOpSpan`. Equivalente a `OpenTelemetry.Api`.
- **Activity Instrumentation** (T-02) — `TActivity`: wrapper RAII sobre `ISpan` con API fluent chainable (`AddTag`, `AddEvent`, `SetStatus`); destructor llama `Stop` automáticamente. `TActivitySource`: fábrica de `TActivity`. Equivalente a `System.Diagnostics.Activity` / `ActivitySource`.
- **Jaeger Exporter** (T-03) — `TJaegerExporter`: envío OTLP/HTTP JSON a Jaeger (puerto 4318) con batching configurable, timeout y `TCriticalSection` thread-safe. `TJaegerExporterOptions`: `Endpoint`, `TimeoutMs`, `BatchSize`, `ServiceName`, `IgnoreErrors`. Equivalente a `OpenTelemetry.Exporter.Jaeger`.
- **Telemetry DI Extensions** — `TTelemetryServiceExtension.AddTelemetry(serviceName)` → `TTracerProviderBuilder` con `AddExporter`, `SetAsGlobal`, `Build`. Registro del `ITracerProvider` en el contenedor de DI.
- **HealthChecksUI Dashboard** — `THealthChecksUIController` (`[Route('healthui')]`) devuelve página HTML con dashboard de estado. `THealthChecksUIMVCServerExtension.UseHealthChecksUI` registra el controller en el pipeline MVC.

---

## [2.9.0] — 2026-05-01

### Added
- **Resilience — Circuit Breaker** (`TCircuitBreakerPolicy<T>`, `ECircuitOpenException`). Estados Closed/Open/HalfOpen, callback `TCircuitStateChangeEvent`, thread-safe con `TCriticalSection`. Equivalente a `Polly.CircuitBreaker`.
- **Resilience — Retry** (`TRetryPolicy<T>`, `ERetryExhaustedException`). Estrategias `btConstant`, `btExponential`, `btDecorrelated` (AWS full jitter). Callback `TRetryEvent`, filtro `ShouldRetry`. Equivalente a `Polly.Retry`.
- **Resilience — Timeout** (`TTimeoutPolicy<T>`, `ETimeoutException`). Ejecuta en worker thread; lanza en hilo principal si supera `TimeoutMs`. Callback `TTimeoutEvent`. Equivalente a `Polly.Timeout`.
- **Resilience — DI Extensions** (`TResilienceServiceExtension`: `AddCircuitBreaker<T>`, `AddRetry<T>`, `AddTimeout<T>` con nombre/keyed para `IResiliencePolicy<T>`).
- **Mediator / CQRS** (`TMediator`, `IMediator`). Dispatch de requests (`Send`), publicación fan-out de notificaciones (`Publish`), pipeline behaviors (`IPipelineBehavior<TReq,TRes>`). Equivalente a `MediatR`.
- **Mediator — Abstractions** (`IRequest<TResponse>`, `IRequest`, `INotification`, `IRequestHandler<TReq,TRes>`, `INotificationHandler<T>`, `IPipelineBehavior<TReq,TRes>`).
- **Mediator — Base classes** (`TRequestHandler<TReq,TRes>`, `TNotificationHandler<T>`, `TPipelineBehavior<TReq,TRes>`).
- **Mediator — DI Extensions** (`TMediatorServiceExtension.AddMediatR`, `TMediatorBuilder.AddRequestHandler/AddNotificationHandler/AddPipelineBehavior`).
- **HybridCache L1+L2** (`IHybridCache`, `THybridCache`, `THybridCacheOptions`). Lectura: L1 (IMemoryCache) → L2 (IDistributedCache) → factory. Escritura y borrado coordinados en ambos tiers. Equivalente a `IHybridCache` (.NET 9).
- **HybridCache — DI Extensions** (`THybridCacheServiceExtension.AddHybridCache`, opcionalmente con `THybridCacheOptions`).

---

## [2.8.0] — 2026-04-29

### Added
- **Views** — Motor de plantillas Liquid (`TLiquidViewEngine`, `UseLiquidPages`).
- **Views** — Motor Mustache: layouts/master pages con `{{> layout "base.qhtml"}}`, partials con `{{> partial}}`, helpers custom.
- **Auth** — Cookie Authentication handler (`TCookieAuthenticationHandler`, `AddCookie`).
- **Auth** — OAuth2 / OpenID Connect handler básico (`AddOAuth2`).
- **Auth** — Security Stamp Validation (`TSecurityStampValidator`).
- **Auth** — 2FA / TOTP (`TTotpService`, Google Authenticator compatible).
- **MVC** — Content Negotiation (`Accept: application/json` vs `application/xml`).
- **MVC** — File Upload via `[FromForm]` y `multipart/form-data`.
- **MVC** — Problem Details RFC 7807 (`application/problem+json`).
- **MVC** — Response Compression middleware (Gzip + Deflate, `AddResponseCompression`, `UseResponseCompression`).
- **Entity** — Seeding de datos (`TDBContext.Seed(proc)`).
- **Entity** — PostgreSQL support (`Quick.Core.Entity.QueryGenerator.PostgreSQL`).
- **Entity** — Audit Fields automáticos (`TEntityAudit`: `CreatedAt/UpdatedAt/CreatedBy/ModifiedBy`).
- **Entity** — Sistema de Migrations (`TMigration`, `TMigrationsManager`, tabla `__MigrationsHistory`).
- **DI** — Generic Host (`THostBuilder.Create...Build.Run`, `TGenericHost`).
- **DI** — Variables de entorno en opciones (`${VAR_NAME}` en `appsettings.json`).
- **DI** — Secrets Management (`Quick.Core.Configuration.Secrets`).
- **JWT** — `TJwtBearerHandler`, `IJwtTokenService`, `TJwtTokenService` (HMAC-SHA256), `AddJwtBearer`.
- **Samples** — S-27 a S-36 + S-36 LiquidViewEngine.

### Fixed
- **WebDashboard (S-26)** — `GET /` devolvía 404; corregido con `MapGet('/', handler)` en Startup.
- **SwaggerSample** — `ObjArrayToJson<T>` reemplazado por loop `ObjectToJson` + `TStringBuilder`.
- **WebDashboard** — `THttpStatusCode.NoContent` no en scope; reemplazado por `StatusCode(204)`.

---

## [2.7.0] — 2026-03-15

### Added
- **MVC** — Swagger / OpenAPI 3.0 Generator (`TSwaggerGenerator` via RTTI, `TSwaggerMiddleware`).
  - Endpoint `/swagger/v1/swagger.json` (OpenAPI JSON).
  - Endpoint `/swagger` (Swagger UI via CDN).
  - Atributos `[SwaggerOperation]`, `[ProducesResponseType]`.
  - `UseSwagger(title, version, description)` en `TMVCServer`.
- **MVC** — WebDashboard sample (S-26): dashboard HTML + API REST + Swagger integrado.
- **Localization** — `TFileLocalizationStore` registrado automáticamente en `AddLocalization`.
  - `SetCulture`/`GetCulture` añadidos a `IStringLocalization` para soporte per-request.
  - Soporte de `Accept-Language` header.

### Fixed
- **S-14 WebApiWithIdentity** — `EServiceConfigError: Cannot Configure TIdentityOptions before AddOptions`; resuelto añadiendo `.AddOptions(ofJSON, True)` antes de `AddIdentity`.
- **S-20 LocalizationSample** — crash `ILocalizationStore not registered`; resuelto con `TFileLocalizationStore`.

---

## [2.6.0] — 2026-02-20

### Added
- **DI** — Keyed Services (`AddKeyedSingleton/Transient/Scoped<I,T>(key)`, `GetKeyedService<T>(key)`, `[FromKeyedServices('key')]`).
- **DI** — `IServiceScope` / `TServiceScope` para servicios Scoped con ciclo de vida explícito.
- **MVC** — API Versioning (`[ApiVersion('1.0')]`, `UseApiVersioning`).
- **MVC** — Rate Limiting middleware (`TRateLimitMiddleware`, `UseRateLimiting(max, secs)`, `[RateLimit]`, HTTP 429 + `Retry-After`).
- **MVC** — Session completa (`TInMemorySession`, `TSessionMiddleware`, `UseSession`, `HttpContext.Session`).
- **MVC** — Minimal API (`MapGet/Post/Put/Delete/Verbs`, `TMinimalEndpointHandler`).
- **AutoMapper** — Mapping con contexto (`IMapper.Map<T>(src, opts => opts.Items['key'])`).
- **AutoMapper** — `AssertConfigurationIsValid` (detecta mapeos incompletos al arrancar).
- **AutoMapper** — `NullSubstitute` (valor por defecto cuando la propiedad origen es nil/vacía).
- **AutoMapper** — `BeforeMap` / `AfterMap` hooks.
- **AutoMapper** — `Condition` (predicado por miembro destino).
- **AutoMapper** — `ConvertUsing` (transformador de valor `TValue → TValue`).
- **AutoMapper** — `ReverseMap` (mapeo inverso automático).
- **Entity** — Navigation Properties (`[ForeignKey]`, `[HasMany]`, `[HasOne]`, `Include(propName)`, `TNavigationLoader`).
- **Entity** — Typed LINQ (`Where(TPredicate<T>)`, filtro lambda in-memory).
- **Entity** — Soft Delete (`[SoftDelete]`, `TEntitySD`, `TEntityTSSD`, auto-filter `WHERE IsDeleted=0`, `Delete` → UPDATE).
- **Entity** — Optimistic Concurrency (`TEntityRV`, `RowVersion`, `EOptimisticConcurrencyException`).

---

## [2.5.0] — 2026-01-25

### Added
- **MVC** — Action Filters (`TActionFilterAttribute`, `OnActionExecuting/OnActionExecuted`, `TActionExecutingContext.Canceled`).
- **MVC** — Global Exception Handler (`TExceptionHandlerMiddleware`, `UseExceptionHandler`, `TExceptionHandlerProc`).
- **Services** — Background Services (`IHostedService`, `TBackgroundService.ExecuteAsync`, `AddHostedService<T>`, `IHostedServiceManager`).
- **Samples** — S-08 a S-24.

---

## [2.4.0] — 2025-12-10

### Added
- **Entity** — Repository Pattern base (`IRepository<T>`, `TEntityRepository<T>`: `GetById/GetAll/Add/Update/Delete/Find/Count/Exists/Query`).
- **Entity** — Unit of Work / Transactions (`IUnitOfWork`, `TUnitOfWork.Execute`, `BeginTransaction/CommitTransaction/RollbackTransaction` en `TDBContext`).
- **MVC** — `[FromQuery]` y `[FromHeader]` con nombre opcional.
- **MVC** — `[FromBody]` mejorado: null guard, soporte arrays JSON, auto-validación (HTTP 400 + JSON de errores).
- **MVC** — CORS Middleware (`TCorsMiddleware`, `TCorsPolicyOptions`, preflight 204, `AddCors`, `UseCors`).

### Fixed
- **B-03** — `TApiKeys` sin constructor/destructor; implementados `Create/Destroy/Add`.

---

## [2.3.0] — 2025-11-05

### Added
- **Entity** — Migrations (`TMigration Up/Down`, `TMigrationsManager`, `TEntityMigrationsHistory`, tabla `__MigrationsHistory`, transaccional por migración).
- **MVC** — Model Validation Pipeline (`[Required]`, `[Range]`, `[StringLength]`, `[RegularExpression]`, `[EmailAddress]`, `TModelValidator`, `TModelState`).
- **Auth** — JWT Authentication Handler (`TJwtBearerHandler`, esquema `Bearer`, `AddJwtBearer`).
- **Auth** — JWT Token Service (`IJwtTokenService`, `TJwtTokenService`, HMAC-SHA256, `TJwtOptions`).

---

## [2.2.0] — 2025-09-20

### Added
- **DI** — `IServiceScope` / `TServiceScope` (scopes explícitos para servicios Scoped).
- **MVC** — Swagger básico: `[SwaggerOperation]`, `[ProducesResponseType]`, endpoint `/swagger`.
- **Auth** — Resource-based Authorization (`AuthorizeResource(obj, policy)` en `THttpController`, `IAuthorizationHandler<T>`).
- **Auth** — `User: TClaimsPrincipal` expuesto en `THttpController`.
- **Samples** — S-01 a S-07.

### Fixed
- **B-02** — Typo `fabel` → `&Label` en `TClaimsIdentity`.
- **B-04** — `TTaskControl.GetCurrentRunningTasksJson` devuelve ahora JSON real con `queued/workers/totalPushed`.

---

## [2.1.0] — 2025-07-15

### Added
- **DI** — `CreateScope` / `IServiceScope` en `TServiceCollection` y `TServiceProvider`.
- **DI** — Variables de entorno en opciones (`${VAR_NAME}`).
- **MVC** — Rate Limiting por IP básico.
- **Security** — `TIdentityUser`, `TIdentityRole`, `TUserManager`, `AddIdentity`, `AddEntityStore`.
- **Security** — Password options (`TPasswordOptions`), lockout (`TLockoutOptions`).
- **AutoMapper** — `TProfile`, `CreateMap<S,D>`, `ForMember`, `Map<T>`.
- **Caching** — `IMemoryCache`, `IDistributedCache`, `AddMemoryCache`, `AddDistributedMemoryCache`, `AddDistributedRedisCache`.
- **HealthChecks** — `AddHealthChecks`, `TUrlHealthCheck`, `TSqlServerHealthCheck`, `TEntityHealthCheck`, `TRedisHealthCheck`, `UseHealthChecks`.
- **MessageQueue** — `IMessageQueue<T>`, `TRedisMessageQueue<T>`, `AddRedisMessageQueue<T>`, `Push/Pop/Remove/Failed`.
- **Localization** — `IStringLocalization`, `TLocalizationOptions`, `AddLocalization`, archivos JSON de cultura.
- **TaskControl** — `ITaskControl`, `TBackgroundTasks`, `TScheduledTasks`, `AddTaskControl`.
- **Commandline** — `ICommandline<T>`, `TCommandline<T>`, `TServiceParameters`, `AddCommandline<T>`, atributos de parámetros.

### Breaking Changes
- **MessageQueue** — `Enqueue` renombrado a `Push`.
- **MessageQueue** — `TMessageQueueTask<T>` eliminado; usar clases POCO directamente.

---

## [2.0.0] — 2025-05-01

### Breaking Changes
- **DI** — `Quick.Core.Container.pas` eliminado. Usar `Quick.Core.DependencyInjection` en su lugar.
- **DI** — `IServiceProvider` eliminado. Usar `TServiceCollection.Resolve<T>` o `TServiceProvider`.
- **Entity** — `TDBContextOptions` renombrado a `IDBConnectionOptions`. Actualizar todas las llamadas a `AddDBContext`.
- **DI** — Signaturas de factory delegates actualizadas: el parámetro `IServiceProvider` → `TServiceCollection`.

### Added
- **Entity** — `TDBSet<T>` como record de acceso a conjuntos de datos.
- **Entity** — Soporte completo de LINQ con `Where/OrderBy/OrderByDescending/Select/SelectFirst/SelectLast/SelectTop/Count/Sum`.
- **MVC** — Pipeline de middleware completo (`UseRouting`, `UseAuthentication`, `UseAuthorization`, etc.).
- **MVC** — Attribute routing (`[Route]`, `[HttpGet/Post/Put/Delete]`, `[AcceptVerbs]`).
- **MVC** — `[Authorize]`, `[AuthorizePolicy]`, `[AllowAnonymous]`.
- **MVC** — `[OutputCache]`, `[ApiController]`, `[ApiVersion]`.
- **MVC** — `[FromBody]`, `[FromQuery]`, `[FromHeader]`.
- **Security** — `TAuthenticationService`, `IAuthenticationHandler`, esquemas múltiples.
- **Security** — `TClaimsPrincipal`, `TClaimsIdentity`, `TClaim`.
- **Security** — `IAuthorizationService`, `TAuthorizationPolicy`, `TAuthorizationPolicyBuilder`.

---

## [1.8.0] — 2024-12-01

### Added
- **DI** — `TServiceCollection` con lifetimes Singleton/Transient/Scoped.
- **DI** — `TStartupBase` para configuración estructurada.
- **DI** — `Configure<T>` para opciones tipadas desde JSON.
- **DI** — Factory delegates (`AddSingleton<I,T>(name, func)`).
- **App** — `TCoreApp` como host básico.
- **Entity** — `TDBContext` con `TDBSet<T>`, proveedores SQLite/MSSQL/MySQL/MSAccess.
- **Entity** — Atributos `[Table]`, `[Key]`, `[StringLength]`, `[DecimalLength]`, `[Index]`.
- **Entity** — Clases base `TEntity`, `TEntityTS`, `TEntitySD`, `TEntityRV`, `TEntityAudit`.
- **MVC** — `TMVCServer` con `UseStartup<T>`, `AddControllers`, `UseMVC`.
- **MVC** — `THttpController` con `Ok/BadRequest/NotFound/Json/View/Redirect`.
- **AutoMapper** — Mapeo automático por RTTI.
- **Logging** — Integración con QuickLogger (`ILogger`, `AddLogging`).
- **Serialization** — `TJsonSerializer`, `TYamlSerializer`.

---

## Ver también

- [Migration Guide](Migration-Guide.md)
- [API Reference](API-Reference.md)
- [Comparativa .NET](DotNet-Comparison.md)
