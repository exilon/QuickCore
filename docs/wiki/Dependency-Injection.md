# Dependency Injection (DI)

> Module: `Quick.Core.DependencyInjection`  
> .NET equivalent: `Microsoft.Extensions.DependencyInjection`

QuickCore implements a full IoC container with the same three lifetimes as ASP.NET Core: **Singleton**, **Transient**, and **Scoped**.

---

## Table of contents

1. [Basics](#basics)
2. [Register services](#register-services)
3. [Lifetimes](#lifetimes)
4. [Resolve services](#resolve-services)
5. [Options Pattern](#options-pattern)
6. [Startup Pattern](#startup-pattern)
7. [Factory Delegates](#factory-delegates)
8. [Named / Keyed Services](#named--keyed-services)
9. [Scoped Services (IServiceScope)](#scoped-services-iservicescope)
10. [Typed Factories](#typed-factories)
11. [See also](#see-also)

---

## Basics

| Class / Interface | Role |
|-----------------|-----|
| `TServiceCollection` | Service registration (equivalent to `IServiceCollection`) |
| `TServiceProvider` | Service resolution (equivalent to `IServiceProvider`) |
| `IServiceScope` | Explicit scope for scoped services |
| `TStartupBase` | Base class for the Startup pattern |
| `TOptions<T>` / `IOptions<T>` | Typed access to configuration |

---

## Register services

```pascal
uses Quick.Core.DependencyInjection;

var
  services: TServiceCollection;
begin
  services := TServiceCollection.Create;

  // Interface → Implementation
  services.AddSingleton<IMyService, TMyService>;
  services.AddTransient<IMyRepo, TMyRepo>;
  services.AddScoped<IUnitOfWork, TUnitOfWork>;
end;
```

---

## Lifetimes

| Lifetime | Method | Behavior | .NET equivalent |
|----------|--------|----------|----------------|
| **Singleton** | `AddSingleton<I,T>` | Single instance per container | `AddSingleton` |
| **Transient** | `AddTransient<I,T>` | New instance on each `Resolve` | `AddTransient` |
| **Scoped** | `AddScoped<I,T>` | One instance per `IServiceScope` | `AddScoped` |

```pascal
// Singleton — same instance always
services.AddSingleton<ICache, TMemoryCache>;

// Transient — new instance on each injection
services.AddTransient<IEmailSender, TSmtpEmailSender>;

// Scoped — same instance within a scope (e.g. per HTTP request)
services.AddScoped<IDbContext, TShopContext>;
```

---

## Resolve services

Services are normally injected via **constructor** automatically:

```pascal
type
  TOrderController = class(THttpController)
  private
    fOrderService: IOrderService;
  public
    constructor Create(aOrderService: IOrderService);  // ← QuickCore injects it
  end;
```

You can also resolve manually from the container:

```pascal
var
  svc: IOrderService;
begin
  svc := services.Resolve<IOrderService>();
end;
```

---

## Options Pattern

Load typed configuration from a JSON/YAML file:

```pascal
type
  TDatabaseOptions = class(TOptions)
  published
    property ConnectionString: string read fConnStr write fConnStr;
    property MaxConnections: Integer read fMax write fMax;
  end;

// Registration
services.AddOptions(ofJSON);
services.Configure<TDatabaseOptions>('Database');

// Injection
type
  TMyService = class
  private
    fOptions: IOptions<TDatabaseOptions>;
  public
    constructor Create(aOptions: IOptions<TDatabaseOptions>);
  end;
```

`appsettings.json`:
```json
{
  "Database": {
    "ConnectionString": "data source=mydb.sqlite",
    "MaxConnections": 10
  }
}
```

### Configure with lambda

```pascal
services.Configure<TSmtpOptions>(procedure(opts: TSmtpOptions)
begin
  opts.Host := 'smtp.example.com';
  opts.Port := 587;
end);
```

---

## Startup Pattern

The recommended pattern for organizing registration:

```pascal
type
  TMyStartup = class(TStartupBase)
  public
    class procedure ConfigureServices(services: TServiceCollection); override;
  end;

class procedure TMyStartup.ConfigureServices(services: TServiceCollection);
begin
  services.AddOptions(ofJSON);
  services.AddSingleton<IProductService, TProductService>;
  services.AddScoped<IOrderRepo, TOrderRepo>;
end;

// Startup
var
  sc: TServiceCollection;
begin
  sc := TServiceCollection.CreateFromStartup<TMyStartup>;
  sc.Build;
end;
```

---

## Factory Delegates

When service construction requires custom logic:

```pascal
services.AddSingleton<IDbContext, TShopContext>('',
  function: TShopContext
  begin
    Result := TShopContext.Create;
    Result.Connection.Server := 'localhost';
    Result.Connection.Database := 'shop';
  end);
```

---

## Named / Keyed Services

Register multiple implementations of the same interface with a name:

```pascal
// Registration
services.AddKeyedSingleton<IPaymentGateway, TStripeGateway>('stripe');
services.AddKeyedSingleton<IPaymentGateway, TPayPalGateway>('paypal');

// Resolution
var gateway: IPaymentGateway;
gateway := services.GetKeyedService<IPaymentGateway>('stripe');
```

In controllers, use the `[FromKeyedServices]` attribute:

```pascal
constructor TCheckoutController.Create(
  [FromKeyedServices('stripe')] aGateway: IPaymentGateway);
```

---

## Scoped Services (IServiceScope)

Create an explicit scope:

```pascal
var
  scope: IServiceScope;
  db: IDbContext;
begin
  scope := services.CreateScope;
  try
    db := scope.ServiceProvider.GetService<IDbContext>();
    // db lives while the scope is open
    db.Products.Add(product);
  finally
    scope := nil; // releases the scope and scoped services
  end;
end;
```

---

## Typed Factories

Allows creating instances with runtime parameters:

```pascal
services.AddTypedFactory<IOrderFactory, TOrderFactory>;

// Usage
type
  IOrderFactory = interface
    function CreateOrder(aCustomerId: Integer): TOrder;
  end;
```

---

## See also

- [Entity / ORM](Entity-ORM.md) — `AddDBContext`, repositories
- [MVC](MVC.md) — `TStartupMvc`, injection in controllers
- [Security](Security.md) — `AddAuthentication`, `AddAuthorization`
- [Caching](Caching.md) — `AddMemoryCache`, `AddDistributedCache`


---

## Tabla de contenidos

1. [Conceptos básicos](#conceptos-básicos)
2. [Registrar servicios](#registrar-servicios)
3. [Lifetimes](#lifetimes)
4. [Resolver servicios](#resolver-servicios)
5. [Options Pattern](#options-pattern)
6. [Startup Pattern](#startup-pattern)
7. [Factory Delegates](#factory-delegates)
8. [Named / Keyed Services](#named--keyed-services)
9. [Scoped Services (IServiceScope)](#scoped-services-iservicescope)
10. [Typed Factories](#typed-factories)
11. [Ver también](#ver-también)

---

## Conceptos básicos

| Clase / Interfaz | Rol |
|-----------------|-----|
| `TServiceCollection` | Registro de servicios (equivale a `IServiceCollection`) |
| `TServiceProvider` | Resolución de servicios (equivale a `IServiceProvider`) |
| `IServiceScope` | Scope explícito de vida para servicios scoped |
| `TStartupBase` | Clase base para el patrón Startup |
| `TOptions<T>` / `IOptions<T>` | Acceso tipado a configuración |

---

## Registrar servicios

```pascal
uses Quick.Core.DependencyInjection;

var
  services: TServiceCollection;
begin
  services := TServiceCollection.Create;

  // Interface → Implementación
  services.AddSingleton<IMyService, TMyService>;
  services.AddTransient<IMyRepo, TMyRepo>;
  services.AddScoped<IUnitOfWork, TUnitOfWork>;
end;
```

---

## Lifetimes

| Lifetime | Método | Comportamiento | .NET equivalente |
|----------|--------|---------------|-----------------|
| **Singleton** | `AddSingleton<I,T>` | Una sola instancia por contenedor | `AddSingleton` |
| **Transient** | `AddTransient<I,T>` | Nueva instancia en cada `Resolve` | `AddTransient` |
| **Scoped** | `AddScoped<I,T>` | Una instancia por `IServiceScope` | `AddScoped` |

```pascal
// Singleton — misma instancia siempre
services.AddSingleton<ICache, TMemoryCache>;

// Transient — instancia nueva en cada inyección
services.AddTransient<IEmailSender, TSmtpEmailSender>;

// Scoped — misma instancia dentro de un scope (p.ej. por request HTTP)
services.AddScoped<IDbContext, TShopContext>;
```

---

## Resolver servicios

Normalmente los servicios se inyectan vía **constructor** de forma automática:

```pascal
type
  TOrderController = class(THttpController)
  private
    fOrderService: IOrderService;
  public
    constructor Create(aOrderService: IOrderService);  // ← QuickCore lo inyecta
  end;
```

También puedes resolver manualmente desde el contenedor:

```pascal
var
  svc: IOrderService;
begin
  svc := services.Resolve<IOrderService>();
end;
```

---

## Options Pattern

Carga configuración tipada desde un archivo JSON/YAML:

```pascal
type
  TDatabaseOptions = class(TOptions)
  published
    property ConnectionString: string read fConnStr write fConnStr;
    property MaxConnections: Integer read fMax write fMax;
  end;

// Registro
services.AddOptions(ofJSON);
services.Configure<TDatabaseOptions>('Database');

// Inyección
type
  TMyService = class
  private
    fOptions: IOptions<TDatabaseOptions>;
  public
    constructor Create(aOptions: IOptions<TDatabaseOptions>);
  end;
```

Archivo `appsettings.json`:
```json
{
  "Database": {
    "ConnectionString": "data source=mydb.sqlite",
    "MaxConnections": 10
  }
}
```

### Configure con lambda

```pascal
services.Configure<TSmtpOptions>(procedure(opts: TSmtpOptions)
begin
  opts.Host := 'smtp.example.com';
  opts.Port := 587;
end);
```

---

## Startup Pattern

El patrón recomendado para organizar el registro:

```pascal
type
  TMyStartup = class(TStartupBase)
  public
    class procedure ConfigureServices(services: TServiceCollection); override;
  end;

class procedure TMyStartup.ConfigureServices(services: TServiceCollection);
begin
  services.AddOptions(ofJSON);
  services.AddSingleton<IProductService, TProductService>;
  services.AddScoped<IOrderRepo, TOrderRepo>;
end;

// Arranque
var
  sc: TServiceCollection;
begin
  sc := TServiceCollection.CreateFromStartup<TMyStartup>;
  sc.Build;
end;
```

---

## Factory Delegates

Cuando la construcción del servicio requiere lógica personalizada:

```pascal
services.AddSingleton<IDbContext, TShopContext>('',
  function: TShopContext
  begin
    Result := TShopContext.Create;
    Result.Connection.Server := 'localhost';
    Result.Connection.Database := 'shop';
  end);
```

---

## Named / Keyed Services

Registra múltiples implementaciones de la misma interfaz con nombre:

```pascal
// Registro
services.AddKeyedSingleton<IPaymentGateway, TStripeGateway>('stripe');
services.AddKeyedSingleton<IPaymentGateway, TPayPalGateway>('paypal');

// Resolución
var gateway: IPaymentGateway;
gateway := services.GetKeyedService<IPaymentGateway>('stripe');
```

En controllers, usa el atributo `[FromKeyedServices]`:

```pascal
constructor TCheckoutController.Create(
  [FromKeyedServices('stripe')] aGateway: IPaymentGateway);
```

---

## Scoped Services (IServiceScope)

Crea un scope de vida explícito:

```pascal
var
  scope: IServiceScope;
  db: IDbContext;
begin
  scope := services.CreateScope;
  try
    db := scope.ServiceProvider.GetService<IDbContext>();
    // db vive mientras el scope esté abierto
    db.Products.Add(product);
  finally
    scope := nil; // libera el scope y los servicios scoped
  end;
end;
```

---

## Typed Factories

Permite crear instancias con parámetros en tiempo de ejecución:

```pascal
services.AddTypedFactory<IOrderFactory, TOrderFactory>;

// Uso
type
  IOrderFactory = interface
    function CreateOrder(aCustomerId: Integer): TOrder;
  end;
```

---

## Ver también

- [Entity / ORM](Entity-ORM.md) — `AddDBContext`, repositorios
- [MVC](MVC.md) — `TStartupMvc`, inyección en controllers
- [Security](Security.md) — `AddAuthentication`, `AddAuthorization`
- [Caching](Caching.md) — `AddMemoryCache`, `AddDistributedCache`
