# Caching

> Modules: `Quick.Core.Caching.Abstractions`, `Quick.Core.Extensions.Caching.Memory`, `Quick.Core.Extensions.Caching.Redis`  
> .NET equivalent: `Microsoft.Extensions.Caching.Memory` + `Microsoft.Extensions.Caching.StackExchangeRedis`

QuickCore offers two cache implementations: **in-memory** (local process) and **Redis distributed** (shared between instances). Both implement the `IMemoryCache` / `IDistributedCache` interfaces and are registered via DI.

---

## Table of contents

1. [Cache interfaces](#cache-interfaces)
2. [In-Memory Cache](#in-memory-cache)
3. [Redis Distributed Cache](#redis-distributed-cache)
4. [Response Caching](#response-caching)
5. [[OutputCache] attribute](#outputcache-attribute)
6. [Usage patterns](#usage-patterns)
7. [See also](#see-also)

---

## Cache interfaces

| Interface | In-memory implementation | Redis implementation | .NET equivalent |
|----------|------------------------|---------------------|----------------|
| `IMemoryCache` | `THttpMemoryCache` | — | `IMemoryCache` |
| `IDistributedCache` | `TMemoryDistributedCache` | `TRedisDistributedCache` | `IDistributedCache` |

Both interfaces share the same methods:

| Method | Description |
|--------|-------------|
| `SetValue(key, value, expirationMs)` | Stores a value with expiration in milliseconds |
| `SetValue(key, value, expirationDate)` | Stores with an absolute expiration date |
| `GetValue(key)` | Returns the value as `string` |
| `TryGetValue(key, out value)` | Safe read attempt (returns `False` if not found) |
| `RemoveValue(key)` | Removes an entry |
| `Refresh(key, expirationMs)` | Renews the TTL of an existing entry |
| `Flush` | Clears the entire cache |

Supported types: `string`, `TObject`, `TArray<string>`, `TArray<TObject>`.

---

## In-Memory Cache

Process-local cache, ideal for single-server data.

### Register

```pascal
uses Quick.Core.Extensions.Caching.Memory;

// In ConfigureServices — with default options
services.Extension<TMemoryCacheServiceExtension>
  .AddMemoryCache;

// With custom options
services.Extension<TMemoryCacheServiceExtension>
  .AddMemoryCache(procedure(opt: TMemoryCacheOptions)
  begin
    opt.MaxSize       := 1000;   // maximum entries
    opt.PurgeInterval := 60000;  // purge every 60 sec (ms)
    opt.Compression   := False;
  end);

// As distributed in-memory cache (useful for development)
services.Extension<TMemoryCacheServiceExtension>
  .AddDistributedMemoryCache;
```

### Use in a service

```pascal
uses Quick.Core.Caching.Abstractions;

type
  TProductService = class
  private
    fCache : IMemoryCache;
  public
    constructor Create(aCache: IMemoryCache);
    function GetProduct(aId: Integer): TProduct;
  end;

function TProductService.GetProduct(aId: Integer): TProduct;
var
  cacheKey : string;
begin
  cacheKey := 'product_' + aId.ToString;

  if not fCache.TryGetValue(cacheKey, Result) then
  begin
    Result := fRepo.GetById(aId);
    fCache.SetValue(cacheKey, Result, 300000); // 5 minutes
  end;
end;
```

### C# equivalent

```csharp
builder.Services.AddMemoryCache();

// Usage
public TProductService(IMemoryCache cache) { _cache = cache; }

public Product GetProduct(int id)
{
    if (!_cache.TryGetValue($"product_{id}", out Product product))
    {
        product = _repo.GetById(id);
        _cache.Set($"product_{id}", product, TimeSpan.FromMinutes(5));
    }
    return product;
}
```

---

## Redis Distributed Cache

Cache shared across multiple service instances.

### Register

```pascal
uses Quick.Core.Extensions.Caching.Redis;

services.Extension<TRedisCacheServiceExtension>
  .AddDistributedRedisCache(procedure(opt: TRedisCacheOptions)
  begin
    opt.Host              := 'localhost';
    opt.Port              := 6379;
    opt.Password          := 'my-redis-password'; // empty if none
    opt.DatabaseNumber    := 0;
    opt.PoolSize          := 5;
    opt.ConnectionTimeout := 5000;  // ms
    opt.ReadTimeout       := 3000;  // ms
    opt.MaxSize           := 10000;
  end);
```

### Use in a service

```pascal
uses Quick.Core.Caching.Abstractions;

type
  TSessionService = class
  private
    fCache : IDistributedCache;
  public
    constructor Create(aCache: IDistributedCache);

    procedure SaveSession(const aToken: string; aUserId: Integer);
    function  GetUserId(const aToken: string): Integer;
    procedure InvalidateSession(const aToken: string);
  end;

procedure TSessionService.SaveSession(const aToken: string; aUserId: Integer);
begin
  // Expires in 30 minutes
  fCache.SetValue('session_' + aToken, aUserId.ToString, 1800000);
end;

function TSessionService.GetUserId(const aToken: string): Integer;
var
  value : string;
begin
  if fCache.TryGetValue('session_' + aToken, value) then
    Result := value.ToInteger
  else
    Result := 0;
end;

procedure TSessionService.InvalidateSession(const aToken: string);
begin
  fCache.RemoveValue('session_' + aToken);
end;
```

### Cache serialized objects

```pascal
var
  product : TProduct;
  cached  : TProduct;
begin
  // Store object
  fCache.SetValue('product_42', product, 300000);

  // Retrieve object
  cached := TProduct.Create;
  if fCache.TryGetValue('product_42', TObject(cached)) then
    // cached has the object data
  else
    cached.Free;
end;
```

### Renew TTL

```pascal
// Extend expiration by 10 more minutes
fCache.Refresh('session_' + token, 600000);
```

### C# equivalent

```csharp
builder.Services.AddStackExchangeRedisCache(opt => {
    opt.Configuration = "localhost:6379,password=my-redis-password";
    opt.InstanceName  = "myapp_";
});
```

---

## Response Caching

Caches complete HTTP responses (headers + body) at the middleware level. Equivalent to `[ResponseCache]` in ASP.NET Core.

### Register

```pascal
uses Quick.Core.Mvc.Extensions.ResponseCaching;

// With in-memory cache (development)
services.Extension<TResponseCachingServiceExtension>
  .AddResponseCaching;

// With Redis (production)
services.Extension<TResponseCachingServiceExtension>
  .AddCustomResponseCaching(TRedisDistributedCache.Create(redisOptions));
```

### Enable in the pipeline

```pascal
// In Configure — must come before UseRouting
app.UseResponseCaching
   .UseRouting
   .UseMVC;
```

> **Note:** The response caching middleware must be placed **before** routing in the pipeline so it can intercept the request.

---

## [OutputCache] attribute

Caches the response of a specific action for N milliseconds:

```pascal
uses Quick.Core.Mvc.Controller;

// 60-second cache (60 000 ms)
[HttpGet]
[OutputCache(60000)]
function TProductsController.GetAll: TActionResult;
begin
  Result := Json(fService.GetAll);
end;

// 5-minute cache per action
[HttpGet('{id}')]
[OutputCache(300000)]
function TProductsController.GetById(id: Integer): TActionResult;
begin
  Result := Json(fService.GetById(id));
end;
```

### C# equivalent

```csharp
[HttpGet]
[OutputCache(Duration = 60)]
public IActionResult GetAll() => Ok(_service.GetAll());
```

---

## Usage patterns

### Cache-aside (manual)

The most common pattern: try to read from cache, if not found query the database and store.

```pascal
function TProductService.GetCatalog: TList<TProduct>;
const
  CACHE_KEY = 'product_catalog';
  TTL_MS    = 600000; // 10 minutes
begin
  if not fCache.TryGetValue(CACHE_KEY, TObject(Result)) then
  begin
    Result := fRepo.GetAll;
    fCache.SetValue(CACHE_KEY, TObject(Result), TTL_MS);
  end;
end;

procedure TProductService.UpdateProduct(aProduct: TProduct);
begin
  fRepo.Update(aProduct);
  // Invalidate cache on data change
  fCache.RemoveValue('product_catalog');
  fCache.RemoveValue('product_' + aProduct.Id.ToString);
end;
```

### Cache with absolute expiration

```pascal
// Expires at midnight (daily data)
var midnight := Tomorrow; // TDateTime
fCache.SetValue('daily_stats', stats, midnight);
```

### Expiration options summary

| Overload | Expiration type |
|----------|-----------------| 
| `SetValue(key, val, 300000)` | Relative — 300 000 ms from now |
| `SetValue(key, val, expirationDate)` | Absolute — specific date/time |
| No expiration (`0`) | No TTL — persists until `Flush` or `RemoveValue` |

---

## See also

- [Dependency Injection](Dependency-Injection.md) — cache service registration
- [MVC](MVC.md) — `[OutputCache]`, `UseResponseCaching`
- [Entity / ORM](Entity-ORM.md) — combining cache + repository


---

## Tabla de contenidos

1. [Interfaces de caché](#interfaces-de-caché)
2. [In-Memory Cache](#in-memory-cache)
3. [Redis Distributed Cache](#redis-distributed-cache)
4. [Response Caching](#response-caching)
5. [Atributo \[OutputCache\]](#atributo-outputcache)
6. [Patrones de uso](#patrones-de-uso)
7. [Ver también](#ver-también)

---

## Interfaces de caché

| Interfaz | Implementación memoria | Implementación Redis | .NET equivalente |
|----------|----------------------|---------------------|-----------------|
| `IMemoryCache` | `THttpMemoryCache` | — | `IMemoryCache` |
| `IDistributedCache` | `TMemoryDistributedCache` | `TRedisDistributedCache` | `IDistributedCache` |

Ambas interfaces comparten los mismos métodos:

| Método | Descripción |
|--------|-------------|
| `SetValue(key, value, expirationMs)` | Almacena un valor con expiración en milisegundos |
| `SetValue(key, value, expirationDate)` | Almacena con fecha de expiración absoluta |
| `GetValue(key)` | Devuelve el valor como `string` |
| `TryGetValue(key, out value)` | Intento seguro de lectura (devuelve `False` si no existe) |
| `RemoveValue(key)` | Elimina una entrada |
| `Refresh(key, expirationMs)` | Renueva el TTL de una entrada existente |
| `Flush` | Vacía toda la caché |

Tipos soportados: `string`, `TObject`, `TArray<string>`, `TArray<TObject>`.

---

## In-Memory Cache

Caché local al proceso, ideal para datos de un único servidor.

### Registrar

```pascal
uses Quick.Core.Extensions.Caching.Memory;

// En ConfigureServices — con opciones por defecto
services.Extension<TMemoryCacheServiceExtension>
  .AddMemoryCache;

// Con opciones personalizadas
services.Extension<TMemoryCacheServiceExtension>
  .AddMemoryCache(procedure(opt: TMemoryCacheOptions)
  begin
    opt.MaxSize      := 1000;    // máximo de entradas
    opt.PurgeInterval := 60000; // purga cada 60 seg (ms)
    opt.Compression  := False;
  end);

// Como caché distribuida en memoria (útil para desarrollo)
services.Extension<TMemoryCacheServiceExtension>
  .AddDistributedMemoryCache;
```

### Usar en un servicio

```pascal
uses Quick.Core.Caching.Abstractions;

type
  TProductService = class
  private
    fCache : IMemoryCache;
  public
    constructor Create(aCache: IMemoryCache);
    function GetProduct(aId: Integer): TProduct;
  end;

function TProductService.GetProduct(aId: Integer): TProduct;
var
  cacheKey : string;
begin
  cacheKey := 'product_' + aId.ToString;

  if not fCache.TryGetValue(cacheKey, Result) then
  begin
    Result := fRepo.GetById(aId);
    fCache.SetValue(cacheKey, Result, 300000); // 5 minutos
  end;
end;
```

### Equivalente C#

```csharp
builder.Services.AddMemoryCache();

// Uso
public TProductService(IMemoryCache cache) { _cache = cache; }

public Product GetProduct(int id)
{
    if (!_cache.TryGetValue($"product_{id}", out Product product))
    {
        product = _repo.GetById(id);
        _cache.Set($"product_{id}", product, TimeSpan.FromMinutes(5));
    }
    return product;
}
```

---

## Redis Distributed Cache

Caché compartida entre múltiples instancias del servicio.

### Registrar

```pascal
uses Quick.Core.Extensions.Caching.Redis;

services.Extension<TRedisCacheServiceExtension>
  .AddDistributedRedisCache(procedure(opt: TRedisCacheOptions)
  begin
    opt.Host             := 'localhost';
    opt.Port             := 6379;
    opt.Password         := 'mi-redis-password'; // vacío si no hay
    opt.DatabaseNumber   := 0;
    opt.PoolSize         := 5;
    opt.ConnectionTimeout := 5000;  // ms
    opt.ReadTimeout      := 3000;   // ms
    opt.MaxSize          := 10000;
  end);
```

### Usar en un servicio

```pascal
uses Quick.Core.Caching.Abstractions;

type
  TSessionService = class
  private
    fCache : IDistributedCache;
  public
    constructor Create(aCache: IDistributedCache);

    procedure SaveSession(const aToken: string; aUserId: Integer);
    function  GetUserId(const aToken: string): Integer;
    procedure InvalidateSession(const aToken: string);
  end;

procedure TSessionService.SaveSession(const aToken: string; aUserId: Integer);
begin
  // Expira en 30 minutos
  fCache.SetValue('session_' + aToken, aUserId.ToString, 1800000);
end;

function TSessionService.GetUserId(const aToken: string): Integer;
var
  value : string;
begin
  if fCache.TryGetValue('session_' + aToken, value) then
    Result := value.ToInteger
  else
    Result := 0;
end;

procedure TSessionService.InvalidateSession(const aToken: string);
begin
  fCache.RemoveValue('session_' + aToken);
end;
```

### Cachear objetos serializados

```pascal
var
  product : TProduct;
  cached  : TProduct;
begin
  // Guardar objeto
  fCache.SetValue('product_42', product, 300000);

  // Recuperar objeto
  cached := TProduct.Create;
  if fCache.TryGetValue('product_42', TObject(cached)) then
    // cached tiene los datos del objeto
  else
    cached.Free;
end;
```

### Renovar TTL

```pascal
// Ampliar expiración 10 minutos más
fCache.Refresh('session_' + token, 600000);
```

### Equivalente C#

```csharp
builder.Services.AddStackExchangeRedisCache(opt => {
    opt.Configuration = "localhost:6379,password=mi-redis-password";
    opt.InstanceName  = "myapp_";
});
```

---

## Response Caching

Cachea respuestas HTTP completas (headers + body) a nivel de middleware. Equivalente al `[ResponseCache]` de ASP.NET Core.

### Registrar

```pascal
uses Quick.Core.Mvc.Extensions.ResponseCaching;

// Con caché en memoria (desarrollo)
services.Extension<TResponseCachingServiceExtension>
  .AddResponseCaching;

// Con Redis (producción)
services.Extension<TResponseCachingServiceExtension>
  .AddCustomResponseCaching(TRedisDistributedCache.Create(redisOptions));
```

### Activar en el pipeline

```pascal
// En Configure — debe ir antes de UseRouting
app.UseResponseCaching
   .UseRouting
   .UseMVC;
```

> **Atención:** El middleware de response caching debe colocarse **antes** del routing en el pipeline para que pueda interceptar la petición.

---

## Atributo [OutputCache]

Cachea la respuesta de una acción específica durante N milisegundos:

```pascal
uses Quick.Core.Mvc.Controller;

// Cache de 60 segundos (60 000 ms)
[HttpGet]
[OutputCache(60000)]
function TProductsController.GetAll: TActionResult;
begin
  Result := Json(fService.GetAll);
end;

// Cache de 5 minutos por acción
[HttpGet('{id}')]
[OutputCache(300000)]
function TProductsController.GetById(id: Integer): TActionResult;
begin
  Result := Json(fService.GetById(id));
end;
```

### Equivalente C#

```csharp
[HttpGet]
[OutputCache(Duration = 60)]
public IActionResult GetAll() => Ok(_service.GetAll());
```

---

## Patrones de uso

### Cache-aside (manual)

El patrón más común: intentar leer de caché, si no existe buscar en BD y guardar.

```pascal
function TProductService.GetCatalog: TList<TProduct>;
const
  CACHE_KEY = 'product_catalog';
  TTL_MS    = 600000; // 10 minutos
begin
  if not fCache.TryGetValue(CACHE_KEY, TObject(Result)) then
  begin
    Result := fRepo.GetAll;
    fCache.SetValue(CACHE_KEY, TObject(Result), TTL_MS);
  end;
end;

procedure TProductService.UpdateProduct(aProduct: TProduct);
begin
  fRepo.Update(aProduct);
  // Invalidar caché al modificar datos
  fCache.RemoveValue('product_catalog');
  fCache.RemoveValue('product_' + aProduct.Id.ToString);
end;
```

### Caché con expiración absoluta

```pascal
// Expira a medianoche (datos diarios)
var midnight := Tomorrow; // TDateTime
fCache.SetValue('daily_stats', stats, midnight);
```

### Resumen de opciones de expiración

| Sobrecarga | Tipo de expiración |
|------------|-------------------|
| `SetValue(key, val, 300000)` | Relativa — 300 000 ms desde ahora |
| `SetValue(key, val, expirationDate)` | Absoluta — fecha/hora concreta |
| Sin expiración (`0`) | Sin TTL — persiste hasta `Flush` o `RemoveValue` |

---

## Ver también

- [Dependency Injection](Dependency-Injection.md) — registro de servicios de caché
- [MVC](MVC.md) — `[OutputCache]`, `UseResponseCaching`
- [Entity / ORM](Entity-ORM.md) — combinar caché + repositorio
