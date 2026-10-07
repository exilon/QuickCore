# Mediator / CQRS

> Module: `Quick.Core.Mediator.*`  
> Version: 2.9.0+  
> .NET equivalent: [MediatR](https://github.com/jbogard/MediatR)

---

## What is the Mediator pattern?

The Mediator decouples message senders from their receivers. Instead of a Controller calling a Service directly, it emits a **Request** (command or query) to the mediator, which dispatches it to the correct **Handler**.

```
Controller ──► IMediator.Send(TGetProductQuery) ──► TGetProductHandler.Handle ──► TProductDto
```

Advantages:
- **Decoupling**: the Controller does not know the Handler's implementation.  
- **Behavior pipeline**: logging, validation, caching are added as `IPipelineBehavior` without touching the handlers.  
- **Natural CQRS**: separates Commands (write) from Queries (read) using distinct types.

---

## Installation

```pascal
uses
  Quick.Core.Mediator.Abstractions,  // IMediator, IRequest<T>, INotification, handler bases...
  Quick.Core.Mediator,               // TMediator, TMediatorRegistry
  Quick.Core.Extensions.Mediator;    // AddMediatR, TMediatorBuilder
```

---

## Key concepts

### Request / Command / Query

A **Request** is a plain object representing what you want to do. Requests should be immutable.

```pascal
// Query (returns data)
type
  TGetProductQuery = class
    ProductId: Integer;
    constructor Create(aId: Integer);
  end;

// Command (writes / side-effect)
type
  TCreateOrderCommand = class
    CustomerId: Integer;
    Items: TArray<TOrderItem>;
  end;

// With optional typed marker (helps in documentation)
type
  TGetProductQuery = class(TInterfacedObject, IRequest<TProductDto>)
    ProductId: Integer;
  end;
```

### Notification / Event

A **Notification** is published to **multiple** handlers (fan-out). Ideal for domain events.

```pascal
type
  TOrderCreatedEvent = class(TInterfacedObject, INotification)
    OrderId: Integer;
    CustomerId: Integer;
  end;
```

---

## Request Handlers

Inherit from `TRequestHandler<TRequest, TResponse>` and implement `Handle`.

```pascal
type
  TGetProductHandler = class(TRequestHandler<TGetProductQuery, TProductDto>)
  private
    fRepository: IProductRepository;
  public
    constructor Create(aRepository: IProductRepository);
    function Handle(const aRequest: TGetProductQuery): TProductDto; override;
  end;

function TGetProductHandler.Handle(const aRequest: TGetProductQuery): TProductDto;
var
  product: TProduct;
begin
  product := fRepository.GetById(aRequest.ProductId);
  if product = nil then
    raise ENotFoundException.Create('Product not found');
  Result := TProductDto.FromEntity(product);
end;
```

For commands with no response, use `TRequestHandler<TCommand, Boolean>` and return `True`.

---

## Notification Handlers

Inherit from `TNotificationHandler<TNotification>` and implement `Handle`.  
**Multiple handlers** can be registered for the same notification.

```pascal
// Handler 1: send email
type
  TEmailOnOrderCreated = class(TNotificationHandler<TOrderCreatedEvent>)
  public
    procedure Handle(const aNotification: TOrderCreatedEvent); override;
  end;

procedure TEmailOnOrderCreated.Handle(const aNotification: TOrderCreatedEvent);
begin
  EmailService.Send('customer@example.com',
    Format('Order %d confirmed', [aNotification.OrderId]));
end;

// Handler 2: update inventory
type
  TInventoryOnOrderCreated = class(TNotificationHandler<TOrderCreatedEvent>)
  public
    procedure Handle(const aNotification: TOrderCreatedEvent); override;
  end;
```

> If one handler raises an exception, **the remaining handlers continue executing**.

---

## Pipeline Behaviors (Middleware)

`IPipelineBehavior` instances run in registration order, wrapping the handler like onion layers.

```
Request ──► Behavior1 ──► Behavior2 ──► Handler ──► Behavior2 ──► Behavior1 ──► Response
```

### Example: Logging

```pascal
type
  TLoggingBehavior<TReq: class; TResp> =
    class(TPipelineBehavior<TReq, TResp>)
  public
    function Handle(const aRequest: TReq;
                    aNext: TRequestHandlerDelegate<TResp>): TResp; override;
  end;

function TLoggingBehavior<TReq, TResp>.Handle(
  const aRequest: TReq;
  aNext: TRequestHandlerDelegate<TResp>): TResp;
var
  sw: TStopwatch;
begin
  sw := TStopwatch.StartNew;
  Logger.Info('[Mediator] Handling %s', [aRequest.ClassName]);
  Result := aNext();  // calls the next behavior or the final handler
  Logger.Info('[Mediator] Handled %s in %dms', [aRequest.ClassName, sw.ElapsedMilliseconds]);
end;
```

### Example: Validation

```pascal
type
  TValidationBehavior<TReq: class; TResp> =
    class(TPipelineBehavior<TReq, TResp>)
  public
    function Handle(const aRequest: TReq;
                    aNext: TRequestHandlerDelegate<TResp>): TResp; override;
  end;

function TValidationBehavior<TReq, TResp>.Handle(
  const aRequest: TReq;
  aNext: TRequestHandlerDelegate<TResp>): TResp;
var
  validator: IValidator<TReq>;
begin
  validator := ServiceProvider.GetService<IValidator<TReq>>;
  if (validator <> nil) and (not validator.Validate(aRequest).IsValid) then
    raise EValidationException.Create('Request validation failed');
  Result := aNext();
end;
```

---

## DI registration

Register all handlers in `ConfigureServices`:

```pascal
class procedure TMyStartup.ConfigureServices(services: TServiceCollection);
begin
  services.Extension<TMediatorServiceExtension>
    .AddMediatR

    // Queries
    .AddRequestHandler<TGetProductQuery, TProductDto, TGetProductHandler>
    .AddRequestHandler<TListProductsQuery, TArray<TProductDto>, TListProductsHandler>

    // Commands
    .AddRequestHandler<TCreateOrderCommand, Boolean, TCreateOrderHandler>
    .AddRequestHandler<TDeleteProductCommand, Boolean, TDeleteProductHandler>

    // Events
    .AddNotificationHandler<TOrderCreatedEvent, TEmailOnOrderCreated>
    .AddNotificationHandler<TOrderCreatedEvent, TInventoryOnOrderCreated>

    // Pipeline (registration = execution order, first = outermost)
    .AddPipelineBehavior<TGetProductQuery, TProductDto,
      TLoggingBehavior<TGetProductQuery, TProductDto>>
    .AddPipelineBehavior<TCreateOrderCommand, Boolean,
      TValidationBehavior<TCreateOrderCommand, Boolean>>

    .Build;
end;
```

---

## Use in Controller

```pascal
type
  TProductsController = class(THttpController)
  private
    fMediator: IMediator;
  public
    constructor Create(aMediator: IMediator);

    [HttpGet('{id:int}')]
    function GetProduct(id: Integer): IActionResult;

    [HttpPost]
    function CreateOrder([FromBody] command: TCreateOrderCommand): IActionResult;
  end;

constructor TProductsController.Create(aMediator: IMediator);
begin
  inherited Create;
  fMediator := aMediator;
end;

function TProductsController.GetProduct(id: Integer): IActionResult;
var
  dto: TProductDto;
begin
  dto := fMediator.Send(TGetProductQuery.Create(id)).AsType<TProductDto>;
  Result := Json(dto);
end;

function TProductsController.CreateOrder(command: TCreateOrderCommand): IActionResult;
begin
  fMediator.Send(command);
  // Publish domain event
  fMediator.Publish(TOrderCreatedEvent.Create(command.OrderId, command.CustomerId));
  Result := Accepted;
end;
```

---

## Type-safe usage (`SendRequest<T>`)

Inject `TMediator` instead of `IMediator` to avoid `TValue.AsType<T>`:

```pascal
type
  TProductsController = class(THttpController)
  private
    fMediator: TMediator;  // concrete for SendRequest<T>
  public
    constructor Create(aMediator: TMediator);

    [HttpGet('{id:int}')]
    function GetProduct(id: Integer): IActionResult;
  end;

function TProductsController.GetProduct(id: Integer): IActionResult;
var
  dto: TProductDto;
begin
  dto := fMediator.SendRequest<TProductDto>(TGetProductQuery.Create(id));
  Result := Json(dto);
end;
```

---

## Complete CQRS pattern

```
┌─────────────────────────────────────────────────────────┐
│                 CQRS with Mediator                       │
│                                                          │
│  HTTP Request                                            │
│       │                                                  │
│       ▼                                                  │
│  TController ──Send──► IMediator                        │
│                              │                           │
│              ┌───────────────┴─────────────────┐        │
│              │                                 │         │
│           Query                             Command      │
│              │                                 │         │
│       TQueryHandler                     TCommandHandler  │
│        (read-only)                      (write + event)  │
│              │                                 │         │
│           Read DB                          Write DB      │
│                                                │         │
│                                          Publish Event   │
│                                                │         │
│                                    TNotificationHandlerN │
│                                    (email, audit, cache) │
└─────────────────────────────────────────────────────────┘
```

---

## .NET MediatR comparison

```csharp
// C# — MediatR
// Request
public record GetProductQuery(int ProductId) : IRequest<ProductDto>;

// Handler
public class GetProductHandler : IRequestHandler<GetProductQuery, ProductDto>
{
    public Task<ProductDto> Handle(GetProductQuery request, CancellationToken ct)
        => Task.FromResult(_repo.GetById(request.ProductId));
}

// Controller
var dto = await _mediator.Send(new GetProductQuery(id));

// Pipeline behavior
public class LoggingBehavior<TRequest, TResponse> : IPipelineBehavior<TRequest, TResponse>
{
    public async Task<TResponse> Handle(TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        _logger.LogInformation("Handling {RequestType}", typeof(TRequest).Name);
        var result = await next();
        _logger.LogInformation("Handled {RequestType}", typeof(TRequest).Name);
        return result;
    }
}
```

```pascal
// Delphi — QuickCore Mediator
// Request
type TGetProductQuery = class
  ProductId: Integer;
  constructor Create(aId: Integer);
end;

// Handler
type TGetProductHandler = class(TRequestHandler<TGetProductQuery, TProductDto>)
  function Handle(const aRequest: TGetProductQuery): TProductDto; override;
end;

// Controller
dto := fMediator.SendRequest<TProductDto>(TGetProductQuery.Create(id));

// Pipeline behavior
type TLoggingBehavior<TReq: class; TResp> = class(TPipelineBehavior<TReq, TResp>)
  function Handle(const aRequest: TReq;
                  aNext: TRequestHandlerDelegate<TResp>): TResp; override;
end;
```

> Main difference: MediatR uses `async/await`; QuickCore is synchronous. For I/O-intensive operations, combine with `TBackgroundService` or `TBackgroundTasks`.

---

## See also

- [Dependency Injection](Dependency-Injection.md) — handler registration in DI
- [Background Services](Background-Services.md) — asynchronous command processing
- [Clean Architecture tutorial](../tutorials/Clean-Architecture.md) — Mediator as Application layer
- [API Reference — Mediator](../API-Reference.md#24-mediator--cqrs)


El Mediator desacopla a los emisores de mensajes de sus receptores. En lugar de que un Controller llame directamente a un Service, emite un **Request** (comando o query) al mediador, que lo despacha al **Handler** correcto.

```
Controller ──► IMediator.Send(TGetProductQuery) ──► TGetProductHandler.Handle ──► TProductDto
```

Ventajas:
- **Desacoplamiento**: el Controller no conoce la implementación del Handler.  
- **Pipeline de comportamientos**: logging, validación, caching se añaden como `IPipelineBehavior` sin tocar los handlers.  
- **CQRS natural**: separa Commands (escriben) de Queries (leen) usando tipos distintos.

---

## Instalación

```pascal
uses
  Quick.Core.Mediator.Abstractions,  // IMediator, IRequest<T>, INotification, handlers base...
  Quick.Core.Mediator,               // TMediator, TMediatorRegistry
  Quick.Core.Extensions.Mediator;    // AddMediatR, TMediatorBuilder
```

---

## Conceptos clave

### Request / Command / Query

Un **Request** es un objeto plain que representa lo que quieres hacer. Los requests deben ser inmutables.

```pascal
// Query (devuelve datos)
type
  TGetProductQuery = class
    ProductId: Integer;
    constructor Create(aId: Integer);
  end;

// Command (escribe / side-effect)
type
  TCreateOrderCommand = class
    CustomerId: Integer;
    Items: TArray<TOrderItem>;
  end;

// Con marcador tipado opcional (ayuda en documentación)
type
  TGetProductQuery = class(TInterfacedObject, IRequest<TProductDto>)
    ProductId: Integer;
  end;
```

### Notification / Event

Una **Notification** se publica a **múltiples** handlers (fan-out). Ideal para eventos de dominio.

```pascal
type
  TOrderCreatedEvent = class(TInterfacedObject, INotification)
    OrderId: Integer;
    CustomerId: Integer;
  end;
```

---

## Request Handlers

Hereda de `TRequestHandler<TRequest, TResponse>` e implementa `Handle`.

```pascal
type
  TGetProductHandler = class(TRequestHandler<TGetProductQuery, TProductDto>)
  private
    fRepository: IProductRepository;
  public
    constructor Create(aRepository: IProductRepository);
    function Handle(const aRequest: TGetProductQuery): TProductDto; override;
  end;

function TGetProductHandler.Handle(const aRequest: TGetProductQuery): TProductDto;
var
  product: TProduct;
begin
  product := fRepository.GetById(aRequest.ProductId);
  if product = nil then
    raise ENotFoundException.Create('Product not found');
  Result := TProductDto.FromEntity(product);
end;
```

Para commands sin respuesta, usa `TRequestHandler<TCommand, Boolean>` y devuelve `True`.

---

## Notification Handlers

Hereda de `TNotificationHandler<TNotification>` e implementa `Handle`.  
Se pueden registrar **múltiples handlers** para la misma notificación.

```pascal
// Handler 1: enviar email
type
  TEmailOnOrderCreated = class(TNotificationHandler<TOrderCreatedEvent>)
  public
    procedure Handle(const aNotification: TOrderCreatedEvent); override;
  end;

procedure TEmailOnOrderCreated.Handle(const aNotification: TOrderCreatedEvent);
begin
  EmailService.Send('customer@example.com',
    Format('Order %d confirmed', [aNotification.OrderId]));
end;

// Handler 2: actualizar inventario
type
  TInventoryOnOrderCreated = class(TNotificationHandler<TOrderCreatedEvent>)
  public
    procedure Handle(const aNotification: TOrderCreatedEvent); override;
  end;
```

> Si un handler lanza una excepción, **el resto de handlers siguen ejecutándose**.

---

## Pipeline Behaviors (Middleware)

Los `IPipelineBehavior` se ejecutan en orden de registro, envolviendo al handler como capas de cebolla.

```
Request ──► Behavior1 ──► Behavior2 ──► Handler ──► Behavior2 ──► Behavior1 ──► Response
```

### Ejemplo: Logging

```pascal
type
  TLoggingBehavior<TReq: class; TResp> =
    class(TPipelineBehavior<TReq, TResp>)
  public
    function Handle(const aRequest: TReq;
                    aNext: TRequestHandlerDelegate<TResp>): TResp; override;
  end;

function TLoggingBehavior<TReq, TResp>.Handle(
  const aRequest: TReq;
  aNext: TRequestHandlerDelegate<TResp>): TResp;
var
  sw: TStopwatch;
begin
  sw := TStopwatch.StartNew;
  Logger.Info('[Mediator] Handling %s', [aRequest.ClassName]);
  Result := aNext();  // llama al siguiente behavior o al handler final
  Logger.Info('[Mediator] Handled %s in %dms', [aRequest.ClassName, sw.ElapsedMilliseconds]);
end;
```

### Ejemplo: Validación

```pascal
type
  TValidationBehavior<TReq: class; TResp> =
    class(TPipelineBehavior<TReq, TResp>)
  public
    function Handle(const aRequest: TReq;
                    aNext: TRequestHandlerDelegate<TResp>): TResp; override;
  end;

function TValidationBehavior<TReq, TResp>.Handle(
  const aRequest: TReq;
  aNext: TRequestHandlerDelegate<TResp>): TResp;
var
  validator: IValidator<TReq>;
begin
  validator := ServiceProvider.GetService<IValidator<TReq>>;
  if (validator <> nil) and (not validator.Validate(aRequest).IsValid) then
    raise EValidationException.Create('Request validation failed');
  Result := aNext();
end;
```

---

## Registro en DI

Registra todos los handlers en `ConfigureServices`:

```pascal
class procedure TMyStartup.ConfigureServices(services: TServiceCollection);
begin
  services.Extension<TMediatorServiceExtension>
    .AddMediatR

    // Queries
    .AddRequestHandler<TGetProductQuery, TProductDto, TGetProductHandler>
    .AddRequestHandler<TListProductsQuery, TArray<TProductDto>, TListProductsHandler>

    // Commands
    .AddRequestHandler<TCreateOrderCommand, Boolean, TCreateOrderHandler>
    .AddRequestHandler<TDeleteProductCommand, Boolean, TDeleteProductHandler>

    // Events
    .AddNotificationHandler<TOrderCreatedEvent, TEmailOnOrderCreated>
    .AddNotificationHandler<TOrderCreatedEvent, TInventoryOnOrderCreated>

    // Pipeline (registro = orden de ejecución, primero = más exterior)
    .AddPipelineBehavior<TGetProductQuery, TProductDto,
      TLoggingBehavior<TGetProductQuery, TProductDto>>
    .AddPipelineBehavior<TCreateOrderCommand, Boolean,
      TValidationBehavior<TCreateOrderCommand, Boolean>>

    .Build;
end;
```

---

## Uso en Controller

```pascal
type
  TProductsController = class(THttpController)
  private
    fMediator: IMediator;
  public
    constructor Create(aMediator: IMediator);

    [HttpGet('{id:int}')]
    function GetProduct(id: Integer): IActionResult;

    [HttpPost]
    function CreateOrder([FromBody] command: TCreateOrderCommand): IActionResult;
  end;

constructor TProductsController.Create(aMediator: IMediator);
begin
  inherited Create;
  fMediator := aMediator;
end;

function TProductsController.GetProduct(id: Integer): IActionResult;
var
  dto: TProductDto;
begin
  dto := fMediator.Send(TGetProductQuery.Create(id)).AsType<TProductDto>;
  Result := Json(dto);
end;

function TProductsController.CreateOrder(command: TCreateOrderCommand): IActionResult;
begin
  fMediator.Send(command);
  // Publicar evento de dominio
  fMediator.Publish(TOrderCreatedEvent.Create(command.OrderId, command.CustomerId));
  Result := Accepted;
end;
```

---

## Uso con type-safety (`SendRequest<T>`)

Inyecta `TMediator` en lugar de `IMediator` para evitar `TValue.AsType<T>`:

```pascal
type
  TProductsController = class(THttpController)
  private
    fMediator: TMediator;  // concreto para SendRequest<T>
  public
    constructor Create(aMediator: TMediator);

    [HttpGet('{id:int}')]
    function GetProduct(id: Integer): IActionResult;
  end;

function TProductsController.GetProduct(id: Integer): IActionResult;
var
  dto: TProductDto;
begin
  dto := fMediator.SendRequest<TProductDto>(TGetProductQuery.Create(id));
  Result := Json(dto);
end;
```

---

## Patrón CQRS completo

```
┌─────────────────────────────────────────────────────────┐
│                    CQRS con Mediator                     │
│                                                          │
│  HTTP Request                                            │
│       │                                                  │
│       ▼                                                  │
│  TController ──Send──► IMediator                        │
│                              │                           │
│              ┌───────────────┴─────────────────┐        │
│              │                                 │         │
│           Query                             Command      │
│              │                                 │         │
│       TQueryHandler                     TCommandHandler  │
│        (read-only)                      (write + event)  │
│              │                                 │         │
│           Read DB                          Write DB      │
│                                                │         │
│                                          Publish Event   │
│                                                │         │
│                                    TNotificationHandlerN │
│                                    (email, audit, cache) │
└─────────────────────────────────────────────────────────┘
```

---

## Comparativa con .NET MediatR

```csharp
// C# — MediatR
// Request
public record GetProductQuery(int ProductId) : IRequest<ProductDto>;

// Handler
public class GetProductHandler : IRequestHandler<GetProductQuery, ProductDto>
{
    public Task<ProductDto> Handle(GetProductQuery request, CancellationToken ct)
        => Task.FromResult(_repo.GetById(request.ProductId));
}

// Controller
var dto = await _mediator.Send(new GetProductQuery(id));

// Pipeline behavior
public class LoggingBehavior<TRequest, TResponse> : IPipelineBehavior<TRequest, TResponse>
{
    public async Task<TResponse> Handle(TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        _logger.LogInformation("Handling {RequestType}", typeof(TRequest).Name);
        var result = await next();
        _logger.LogInformation("Handled {RequestType}", typeof(TRequest).Name);
        return result;
    }
}
```

```pascal
// Delphi — QuickCore Mediator
// Request
type TGetProductQuery = class
  ProductId: Integer;
  constructor Create(aId: Integer);
end;

// Handler
type TGetProductHandler = class(TRequestHandler<TGetProductQuery, TProductDto>)
  function Handle(const aRequest: TGetProductQuery): TProductDto; override;
end;

// Controller
dto := fMediator.SendRequest<TProductDto>(TGetProductQuery.Create(id));

// Pipeline behavior
type TLoggingBehavior<TReq: class; TResp> = class(TPipelineBehavior<TReq, TResp>)
  function Handle(const aRequest: TReq;
                  aNext: TRequestHandlerDelegate<TResp>): TResp; override;
end;
```

> Diferencia principal: MediatR usa `async/await`; QuickCore es síncrono. Para operaciones I/O intensivas, combina con `TBackgroundService` o `TBackgroundTasks`.

---

## Ver también

- [Dependency Injection](Dependency-Injection.md) — registro de handlers en DI
- [Background Services](Background-Services.md) — procesamiento asíncrono de commands
- [Clean Architecture tutorial](../tutorials/Clean-Architecture.md) — Mediator como capa de Application
- [API Reference — Mediator](../API-Reference.md#24-mediator--cqrs)
