# Migration Guide

> Guía de migración para actualizar proyectos QuickCore entre versiones.

---

## Tabla de contenidos

1. [De 1.x a 2.x — Visión general](#1-de-1x-a-2x--visión-general)
2. [Dependency Injection](#2-dependency-injection)
3. [Entity / ORM](#3-entity--orm)
4. [Message Queue](#4-message-queue)
5. [Localization](#5-localization)
6. [Security / Claims](#6-security--claims)
7. [MVC / Controllers](#7-mvc--controllers)
8. [AutoMapper](#8-automapper)
9. [App Host](#9-app-host)
10. [Checklist de migración](#10-checklist-de-migración)

---

## 1. De 1.x a 2.x — Visión general

La versión 2.x introduce paridad sustancial con ASP.NET Core. Los cambios son mayoritariamente **aditivos**, pero hay **cambios breaking** en las siguientes áreas:

| Área | Tipo de cambio | Sección |
|------|---------------|---------|
| DI — `Quick.Core.Container` | ⚠️ Unidad eliminada | [§2.1](#21-unidad-quickcorecontainerpas-eliminada) |
| DI — `IServiceProvider` | ⚠️ Tipo renombrado | [§2.2](#22-iserviceprovider--tserviceprovider) |
| DI — `AddDBContext` | 🔄 Signatura cambiada | [§3.1](#31-adddbcontext--idbconnectionoptions) |
| Entity — `TDBContextOptions` | ⚠️ Tipo renombrado | [§3.1](#31-adddbcontext--idbconnectionoptions) |
| MessageQueue — `Enqueue` | ⚠️ Método renombrado | [§4.1](#41-enqueue--push) |
| MessageQueue — `TMessageQueueTask` | ⚠️ Tipo eliminado | [§4.2](#42-tmessagequeuetask-eliminado) |
| Localization — Store | 🔄 Registro obligatorio | [§5.1](#51-registro-obligatorio-de-tfilelocalizationstore) |
| Security — `fabel` typo | ⚠️ Propiedad renombrada | [§6.1](#61-tclaimsidentity--label-corregido) |

> **Convenciones**: ⚠️ Breaking · 🔄 Cambio de API · ✅ Compatible hacia atrás

---

## 2. Dependency Injection

### 2.1 Unidad `Quick.Core.Container.pas` eliminada

La unidad `Quick.Core.Container` era un alias legacy (`unit DependencyInjection_borrar`). Ha sido **eliminada** del proyecto.

**Antes (1.x):**
```pascal
uses Quick.Core.Container;
```

**Después (2.x):**
```pascal
uses Quick.Core.DependencyInjection;
```

Todos los tipos (`TServiceCollection`, `TStartupBase`, etc.) se encuentran exclusivamente en `Quick.Core.DependencyInjection`.

---

### 2.2 `IServiceProvider` → `TServiceProvider`

El tipo `IServiceProvider` fue eliminado. El proveedor de servicios es ahora la clase `TServiceProvider`.

**Antes (1.x):**
```pascal
var provider: IServiceProvider;
provider := services.BuildServiceProvider;
svc := provider.GetService<IMyService>;
```

**Después (2.x):**
```pascal
// Opción A: resolver directamente del contenedor
svc := services.Resolve<IMyService>;

// Opción B: a través de TServiceProvider
var provider: TServiceProvider;
provider := TServiceProvider.Create(services);
svc := provider.GetService<IMyService>;
```

En factories y delegados DI, cambia la firma:

**Antes (1.x):**
```pascal
services.AddScoped<IMyService, TMyService>(
  function(sp: IServiceProvider): TMyService
  begin
    Result := TMyService.Create(sp.GetService<ILogger>);
  end);
```

**Después (2.x):**
```pascal
services.AddScoped<IMyService, TMyService>(
  function(sp: TServiceCollection): TMyService
  begin
    Result := TMyService.Create(sp.Resolve<ILogger>);
  end);
```

---

### 2.3 Variables de entorno en Options (nuevo en 2.x)

Las opciones ahora admiten la sintaxis `${VAR_NAME}` para leer variables de entorno:

```json
{
  "Database": {
    "ConnectionString": "${DB_CONNECTION_STRING}"
  }
}
```

No requiere cambios en el código — `AddOptions` lo resuelve automáticamente.

---

### 2.4 `IServiceScope` (nuevo en 2.x)

Los servicios con vida útil Scoped ahora requieren un scope explícito:

```pascal
// 2.x — crear y liberar scope
var scope := services.CreateScope;
try
  svc := scope.ServiceProvider.GetService<IScopedService>;
  svc.DoWork;
finally
  scope := nil; // libera el scope y sus instancias
end;
```

---

## 3. Entity / ORM

### 3.1 `AddDBContext` — `IDBConnectionOptions`

La signatura de `AddDBContext` cambió. El parámetro `TDBContextOptions` fue reemplazado por `IDBConnectionOptions`.

**Antes (1.x):**
```pascal
services.AddDBContext<TAppDbContext>(
  procedure(opt: TDBContextOptions)
  begin
    opt.Provider := dbSQLite;
    opt.Server := 'app.db';
  end);
```

**Después (2.x):**
```pascal
services.AddDBContext<TAppDbContext>(
  procedure(opt: IDBConnectionOptions)
  begin
    opt.Provider := dbSQLite;
    opt.Server := 'app.db';
  end);
```

O mediante `appsettings.json` (forma recomendada):

```json
{
  "Database": {
    "Provider": "SQLite",
    "Server": "app.db"
  }
}
```

```pascal
services.Configure<TDBConnectionOptions>('Database');
services.AddDBContext<TAppDbContext>;
```

---

### 3.2 Migrations (nuevo en 2.x)

Las migraciones deben heredar de `TMigration` e implementar `Up`/`Down`. La tabla `__MigrationsHistory` se crea automáticamente.

```pascal
type
  TCreateProductsTable = class(TMigration)
  public
    procedure Up(context: IDBContext); override;
    procedure Down(context: IDBContext); override;
  end;

procedure TCreateProductsTable.Up(context: IDBContext);
begin
  context.ExecuteSQL(
    'CREATE TABLE Products (Id INTEGER PRIMARY KEY, Name TEXT NOT NULL)');
end;

procedure TCreateProductsTable.Down(context: IDBContext);
begin
  context.ExecuteSQL('DROP TABLE Products');
end;
```

Si en 1.x se usaba `EnsureCreated` (creación directa del esquema), migrar a:

```pascal
// 2.x — aplicar migraciones pendientes al arrancar
var mgr := TMigrationsManager.Create(dbContext);
mgr.ApplyMigrations;
```

---

### 3.3 Soft Delete — comportamiento de `Delete`

En 2.x, si la entidad tiene el atributo `[SoftDelete]`, `Delete` genera `UPDATE SET IsDeleted=1` en lugar de `DELETE FROM`. Si necesitas un borrado físico, usa `context.ExecuteSQL` directamente.

---

### 3.4 Concurrencia optimista — nueva excepción

```pascal
// 2.x — captura de conflicto de concurrencia
try
  context.Products.Update(product);
except
  on E: EOptimisticConcurrencyException do
    // resolver conflicto o informar al usuario
end;
```

En 1.x `Update` devolvía `False` silenciosamente. En 2.x **lanza excepción** para entidades `TEntityRV`.

---

## 4. Message Queue

### 4.1 `Enqueue` → `Push`

El método de encolar mensajes fue renombrado para alinearse con la API de .NET.

**Antes (1.x):**
```pascal
queue.Enqueue(myMessage);
```

**Después (2.x):**
```pascal
queue.Push(myMessage);
// Con prioridad:
queue.Push(myMessage, 1);
```

---

### 4.2 `TMessageQueueTask` eliminado

El wrapper `TMessageQueueTask<T>` fue eliminado. Las clases de mensajes son ahora POCOs simples.

**Antes (1.x):**
```pascal
type
  TOrderTask = class(TMessageQueueTask<TOrder>)
  public
    property Order: TOrder;
  end;

queue.Enqueue(TOrderTask.Create(myOrder));
```

**Después (2.x):**
```pascal
type
  TOrderMessage = class
  published
    property OrderId   : Integer read fOrderId write fOrderId;
    property Total     : Double  read fTotal   write fTotal;
  end;

queue.Push(orderMsg);
```

---

## 5. Localization

### 5.1 Registro obligatorio de `TFileLocalizationStore`

En 2.x, `AddLocalization` registra automáticamente `TFileLocalizationStore` como `ILocalizationStore`. En versiones anteriores este registro era manual y podía omitirse causando `EServiceConfigError: ILocalizationStore not registered`.

**Antes (1.x) — registro manual necesario:**
```pascal
services.AddSingleton<ILocalizationStore, TFileLocalizationStore>;
services.AddLocalization;
```

**Después (2.x) — solo necesitas:**
```pascal
services.AddLocalization(procedure(opt: TLocalizationOptions)
  begin
    opt.AddCulture('en-US');
    opt.AddCulture('es-ES');
  end);
```

---

### 5.2 `SetCulture` / `GetCulture` en `IStringLocalization`

En 2.x la interfaz expone `Culture` como propiedad de lectura/escritura, necesaria para soporte per-request vía `Accept-Language`:

```pascal
// En un action filter:
localization.Culture := request.Headers.GetValue('Accept-Language');
```

---

## 6. Security / Claims

### 6.1 `TClaimsIdentity` — `&Label` corregido

El typo `fabel` en la propiedad de `TClaimsIdentity` fue corregido a `&Label`.

**Antes (1.x):**
```pascal
identity.fabel := 'MyLabel';  // acceso interno incorrecto
```

**Después (2.x):**
```pascal
identity.&Label := 'MyLabel';
// o mediante el constructor:
identity := TClaimsIdentity.Create(claims, scheme, 'nameType', 'roleType');
```

---

### 6.2 JWT Bearer (nuevo en 2.x)

Si en 1.x validabas tokens manualmente, migra a `AddJwtBearer`:

**Antes (1.x) — validación manual:**
```pascal
// Código ad-hoc en middleware o filtro
var token := request.Headers.GetValue('Authorization').Replace('Bearer ', '');
if not ValidateJwt(token, secret) then
  response.StatusCode := 401;
```

**Después (2.x):**
```pascal
// ConfigureServices
services.AddAuthentication
  .AddJwtBearer(procedure(opt: TJwtOptions)
    begin
      opt.Secret          := config.GetValue('Jwt.Secret');
      opt.Issuer          := 'myapp';
      opt.ValidateLifetime := True;
    end);

// Configure
app.UseAuthentication;
app.UseAuthorization;

// En el controller
[Authorize]
function GetProfile: TStatusResult;
```

---

### 6.3 `TApiKeys` — constructor/destructor requerido

En 1.x `TApiKeys` podía usarse sin inicializar. En 2.x **requiere llamar a `Create`** antes de `Add`.

```pascal
// 2.x
var keys := TApiKeys.Create;
try
  keys.Add('my-key-value', 'ClientA');
  // ...
finally
  keys.Free;
end;
```

---

## 7. MVC / Controllers

### 7.1 `[FromBody]` — validación automática de modelos

En 2.x, si el parámetro `[FromBody]` falla la validación (`TModelValidator`), el framework devuelve automáticamente **HTTP 400** con JSON de errores sin ejecutar la acción. En 1.x esto debía hacerse manualmente.

Si tenías guardas manuales, pueden eliminarse:

**Antes (1.x):**
```pascal
function CreateProduct([FromBody] dto: TProductDto): TStatusResult;
begin
  if dto.Name = '' then
    Result := BadRequest('Name required')
  else
    // ...
end;
```

**Después (2.x) — con atributos de validación en el DTO:**
```pascal
type
  TProductDto = class
  published
    [Required]
    [StringLength(100)]
    property Name: string ...;
  end;

function CreateProduct([FromBody] dto: TProductDto): TStatusResult;
begin
  // Si llega aquí, dto ya pasó validación
end;
```

---

### 7.2 Minimal API (nuevo en 2.x)

Para endpoints sencillos sin controller:

```pascal
app.MapGet('/health', function(ctx: THttpContextBase): string
  begin
    Result := '{"status":"ok"}';
  end);
```

---

### 7.3 `UseExceptionHandler` reemplaza try/catch global

Si en 1.x tenías un `try/except` en el método `ProcessRequest` sobreescrito:

```pascal
// 2.x — en Configure
app.UseExceptionHandler(procedure(ctx: THttpContextBase; e: Exception)
  begin
    ctx.Response.StatusCode := 500;
    ctx.Response.ContentText := e.Message;
  end);
```

---

## 8. AutoMapper

### 8.1 `AssertConfigurationIsValid` recomendado

En 2.x se recomienda llamar a `AssertConfigurationIsValid` al arrancar para detectar mapeos incompletos:

```pascal
// En ConfigureServices, después de AddAutoMapper:
services.Resolve<IMapper>.AssertConfigurationIsValid;
```

En 1.x los errores de mapeo solo se descubrían en tiempo de ejecución.

---

### 8.2 `ReverseMap` — generación automática

Si en 1.x tenías dos `CreateMap` para el mapeo ida/vuelta:

**Antes (1.x):**
```pascal
CreateMap<TUser, TUserDto>;
CreateMap<TUserDto, TUser>;
```

**Después (2.x):**
```pascal
CreateMap<TUser, TUserDto>.ReverseMap;
```

---

## 9. App Host

### 9.1 `TCoreApp` sigue disponible

`TCoreApp` no cambió su API. Si usas el patrón Startup, no se requieren cambios.

---

### 9.2 `TGenericHost` / `THostBuilder` (nuevo en 2.x)

Para apps de consola/servicio sin MVC, reemplaza el bootstrapping manual:

**Antes (1.x) — bootstrapping manual:**
```pascal
var svc := TServiceCollection.Create;
MyStartup.ConfigureServices(svc);
svc.Build;
svc.Resolve<IHostedServiceManager>.StartAll;
ReadLn; // esperar
svc.Resolve<IHostedServiceManager>.StopAll;
svc.Free;
```

**Después (2.x):**
```pascal
THostBuilder.Create
  .ConfigureServices(procedure(s: TServiceCollection)
    begin
      s.AddHostedService<TMyWorker>;
    end)
  .Build
  .Run;
```

---

## 10. Checklist de migración

Usa esta lista para migrar un proyecto de 1.x a 2.x:

### Dependency Injection
- [ ] Reemplazar `uses Quick.Core.Container` → `uses Quick.Core.DependencyInjection`
- [ ] Cambiar `IServiceProvider` → `TServiceProvider` en factories y delegados
- [ ] Actualizar signaturas de factory delegates (`IServiceProvider` → `TServiceCollection`)

### Entity / ORM
- [ ] Cambiar `TDBContextOptions` → `IDBConnectionOptions` en `AddDBContext`
- [ ] Añadir `TMigrationsManager.ApplyMigrations` si se usaba `EnsureCreated`
- [ ] Envolver en `try/except EOptimisticConcurrencyException` los `Update` de entidades `TEntityRV`

### Message Queue
- [ ] Renombrar `Enqueue` → `Push` en todos los productores
- [ ] Reemplazar `TMessageQueueTask<T>` por clases de mensaje POCO simples

### Localization
- [ ] Eliminar el registro manual de `ILocalizationStore` (ya lo hace `AddLocalization`)
- [ ] Actualizar código que accedía a `IStringLocalization.SetCulture` por la propiedad `Culture`

### Security
- [ ] Si se usaba `fabel` directamente, cambiar a `&Label`
- [ ] Migrar validación JWT manual → `AddJwtBearer` + `UseAuthentication`
- [ ] Asegurarse de llamar a `TApiKeys.Create` antes de `Add`

### MVC
- [ ] Eliminar guardas manuales de validación en acciones con `[FromBody]` si el DTO tiene atributos de validación
- [ ] Reemplazar `try/except` global en `ProcessRequest` por `UseExceptionHandler`

### AutoMapper
- [ ] Añadir `AssertConfigurationIsValid` en el arranque
- [ ] Consolidar pares `CreateMap<A,B>` + `CreateMap<B,A>` en `CreateMap<A,B>.ReverseMap`

### App Host
- [ ] Evaluar migrar bootstrapping manual a `THostBuilder.Create...Build.Run`

---

## Ver también

- [Dependency Injection](wiki/Dependency-Injection.md)
- [Entity / ORM](wiki/Entity-ORM.md)
- [Security](wiki/Security.md)
- [API Reference](API-Reference.md)
- [CHANGELOG](CHANGELOG.md)
