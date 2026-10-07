# Message Queue

> Modules: `Quick.Core.MessageQueue`, `Quick.Core.MessageQueue.Abstractions`, `Quick.Core.Extensions.MessageQueue.Redis`  
> .NET equivalent: MassTransit / NServiceBus (simplified)

QuickCore Message Queue provides a producer/consumer queue system over Redis with support for reliable queues, automatic retries, and failed messages.

---

## Table of contents

1. [Basics](#basics)
2. [Register Redis queue (DI)](#register-redis-queue-di)
3. [Publish messages (Producer)](#publish-messages-producer)
4. [Consume messages (Consumer)](#consume-messages-consumer)
5. [Reliable Queue — reliable messages](#reliable-queue--reliable-messages)
6. [Failed messages](#failed-messages)
7. [Complete pattern with Background Service](#complete-pattern-with-background-service)
8. [See also](#see-also)

---

## Basics

| Class / Interface | Role |
|-----------------|-----|
| `IMessageQueue<T>` | Main interface: `Push`, `Pop`, `Remove`, `Failed` |
| `TMessageQueue<T>` | Abstract base with built-in JSON serialization |
| `TRedisMessageQueue<T>` | Redis implementation with connection pool |
| `TMSQWaitResult` | Result: `wrOk`, `wrTimeout`, `wrError` |
| `TRedisMessageQueueOptions` | Connection and behavior options |
| `TRealiableMessageQueue` | Sub-options for reliable messages |

---

## Register Redis queue (DI)

```pascal
uses Quick.Core.Extensions.MessageQueue.Redis;

// Define the message type
type
  TOrderMessage = class
  published
    property OrderId    : Integer read fOrderId    write fOrderId;
    property CustomerId : Integer read fCustomerId write fCustomerId;
    property Total      : Double  read fTotal      write fTotal;
    property CreatedAt  : TDateTime read fCreatedAt write fCreatedAt;
  end;

// In ConfigureServices
services.Extension<TMessageQueueServiceExtension>
  .AddRedisMessageQueue<TOrderMessage>(procedure(opt: TRedisMessageQueueOptions)
  begin
    opt.Host              := 'localhost';
    opt.Port              := 6379;
    opt.Password          := '';
    opt.Database          := 0;
    opt.Key               := 'orders:queue';
    opt.MaxProducersPool  := 3;
    opt.MaxConsumersPool  := 3;
    opt.PopTimeoutSec     := 5;     // BLPOP timeout
    opt.ConnectionTimeout := 5000;
    opt.ReadTimeout       := 10000;
    opt.RetainDoneMessages := False;
  end);
```

---

## Publish messages (Producer)

```pascal
uses Quick.Core.MessageQueue.Abstractions;

type
  TOrderController = class(THttpController)
  private
    fQueue : IMessageQueue<TOrderMessage>;
  public
    constructor Create(aQueue: IMessageQueue<TOrderMessage>);

    [HttpPost]
    function PlaceOrder([FromBody] dto: TPlaceOrderDto): TActionResult;
  end;

function TOrderController.PlaceOrder(dto: TPlaceOrderDto): TActionResult;
var
  msg : TOrderMessage;
begin
  msg            := TOrderMessage.Create;
  msg.OrderId    := dto.OrderId;
  msg.CustomerId := dto.CustomerId;
  msg.Total      := dto.Total;
  msg.CreatedAt  := Now;

  case fQueue.Push(msg) of
    wrOk:    Result := Accepted('Order queued');
    wrError: Result := StatusCode(503, 'Queue unavailable');
  end;
end;
```

### Push with max priority

```pascal
// Enqueues the message at the front of the queue
fQueue.Push(urgentMsg, True {aMaxPriority});
```

---

## Consume messages (Consumer)

The consumer normally lives in a `TBackgroundService`:

```pascal
uses
  Quick.Core.MessageQueue.Abstractions,
  Quick.Core.Extensions.Hosting.BackgroundService;

type
  TOrderConsumerService = class(TBackgroundService)
  private
    fQueue    : IMessageQueue<TOrderMessage>;
    fOrderSvc : IOrderService;
  public
    constructor Create(
      aQueue    : IMessageQueue<TOrderMessage>;
      aOrderSvc : IOrderService);
  protected
    procedure ExecuteAsync; override;
  end;

procedure TOrderConsumerService.ExecuteAsync;
var
  msg : TOrderMessage;
begin
  while not CancelRequested do
  begin
    // Pop blocks up to PopTimeoutSec seconds
    case fQueue.Pop(msg) of
      wrOk:
        begin
          try
            fOrderSvc.Process(msg);
            // Confirm successful processing
            fQueue.Remove(msg);
          except
            on E: Exception do
            begin
              Logger.Error('Order processing failed: ' + E.Message);
              // Move to failed queue
              fQueue.Failed(msg);
            end;
          end;
        end;
      wrTimeout: ; // normal — keep waiting
      wrError:
        begin
          Logger.Error('Queue pop error');
          Sleep(5000); // wait before retrying
        end;
    end;
  end;
end;
```

---

## Reliable Queue — reliable messages

When `ReliableMessageQueue.Enabled = True`, the message is moved to a **working key** on `Pop` and is only permanently deleted when `Remove` is called. If the process dies before confirming, the message is automatically returned to the main queue.

```pascal
opt.ReliableMessageQueue.Enabled                        := True;
opt.ReliableMessageQueue.DetermineAsHangedAfterSec      := 300; // 5 min unconfirmed → hung
opt.ReliableMessageQueue.CheckHangedMessagesIntervalSec := 60;
opt.ReliableMessageQueue.RetryFailedMessages            := True;
opt.ReliableMessageQueue.RetryFailedMessageEverySec     := 600; // retry failed every 10 min
```

Processing flow with reliable queue:

```
[queue:key]  →  Pop()  →  [queue:key:working]  →  Remove()  →  [queue:key:done]
                                                  ↘  Failed()  →  [queue:key:failed]
```

---

## Failed messages

```pascal
// Mark as failed (moves to :failed)
fQueue.Failed(msg);

// Mark as failed with a different processed message
fQueue.Failed(originalMsg, processedMsg);

// Mark as failed with callback before saving
fQueue.Failed(msg, procedure(m: TOrderMessage)
begin
  m.ErrorCount := m.ErrorCount + 1;
  m.LastError  := 'Timeout connecting to payment gateway';
end);
```

---

## Complete pattern with Background Service

```pascal
// 1. Register in ConfigureServices
services.Extension<TMessageQueueServiceExtension>
  .AddRedisMessageQueue<TOrderMessage>(procedure(opt: TRedisMessageQueueOptions)
  begin
    opt.Host := 'localhost';
    opt.Key  := 'orders:queue';
    opt.ReliableMessageQueue.Enabled                   := True;
    opt.ReliableMessageQueue.DetermineAsHangedAfterSec := 120;
    opt.ReliableMessageQueue.RetryFailedMessages       := True;
  end);

services.Extension<THostedServiceExtension>
  .AddHostedService<TOrderConsumerService>;

// 2. The producer (controller, service, etc.) injects IMessageQueue<TOrderMessage>
// 3. The consumer (TOrderConsumerService) injects IMessageQueue<TOrderMessage>
// → Same interface, same registration → share the same Redis queue
```

### C# equivalent

```csharp
// With MassTransit over Redis Streams
builder.Services.AddMassTransit(x =>
{
    x.AddConsumer<OrderConsumer>();
    x.UsingRedis((ctx, cfg) => cfg.ConfigureEndpoints(ctx));
});
```

---

## See also

- [Background Services](Background-Services.md) — queue consumers
- [Dependency Injection](Dependency-Injection.md) — queue registration
- [Caching](Caching.md) — `AddDistributedRedisCache` (same Redis server)


---

## Tabla de contenidos

1. [Conceptos básicos](#conceptos-básicos)
2. [Registrar la cola Redis (DI)](#registrar-la-cola-redis-di)
3. [Publicar mensajes (Producer)](#publicar-mensajes-producer)
4. [Consumir mensajes (Consumer)](#consumir-mensajes-consumer)
5. [Reliable Queue — mensajes fiables](#reliable-queue--mensajes-fiables)
6. [Mensajes fallidos (Failed)](#mensajes-fallidos-failed)
7. [Patron completo con Background Service](#patrón-completo-con-background-service)
8. [Ver también](#ver-también)

---

## Conceptos básicos

| Clase / Interfaz | Rol |
|-----------------|-----|
| `IMessageQueue<T>` | Interfaz principal: `Push`, `Pop`, `Remove`, `Failed` |
| `TMessageQueue<T>` | Base abstracta con serialización JSON integrada |
| `TRedisMessageQueue<T>` | Implementación Redis con pool de conexiones |
| `TMSQWaitResult` | Resultado: `wrOk`, `wrTimeout`, `wrError` |
| `TRedisMessageQueueOptions` | Opciones de conexión y comportamiento |
| `TRealiableMessageQueue` | Sub-opciones para mensajes fiables |

---

## Registrar la cola Redis (DI)

```pascal
uses Quick.Core.Extensions.MessageQueue.Redis;

// Definir el tipo de mensaje
type
  TOrderMessage = class
  published
    property OrderId    : Integer read fOrderId    write fOrderId;
    property CustomerId : Integer read fCustomerId write fCustomerId;
    property Total      : Double  read fTotal      write fTotal;
    property CreatedAt  : TDateTime read fCreatedAt write fCreatedAt;
  end;

// En ConfigureServices
services.Extension<TMessageQueueServiceExtension>
  .AddRedisMessageQueue<TOrderMessage>(procedure(opt: TRedisMessageQueueOptions)
  begin
    opt.Host             := 'localhost';
    opt.Port             := 6379;
    opt.Password         := '';
    opt.Database         := 0;
    opt.Key              := 'orders:queue';
    opt.MaxProducersPool := 3;
    opt.MaxConsumersPool := 3;
    opt.PopTimeoutSec    := 5;     // BLPOP timeout
    opt.ConnectionTimeout := 5000;
    opt.ReadTimeout       := 10000;
    opt.RetainDoneMessages := False;
  end);
```

---

## Publicar mensajes (Producer)

```pascal
uses Quick.Core.MessageQueue.Abstractions;

type
  TOrderController = class(THttpController)
  private
    fQueue : IMessageQueue<TOrderMessage>;
  public
    constructor Create(aQueue: IMessageQueue<TOrderMessage>);

    [HttpPost]
    function PlaceOrder([FromBody] dto: TPlaceOrderDto): TActionResult;
  end;

function TOrderController.PlaceOrder(dto: TPlaceOrderDto): TActionResult;
var
  msg : TOrderMessage;
begin
  msg           := TOrderMessage.Create;
  msg.OrderId   := dto.OrderId;
  msg.CustomerId := dto.CustomerId;
  msg.Total     := dto.Total;
  msg.CreatedAt := Now;

  case fQueue.Push(msg) of
    wrOk:    Result := Accepted('Order queued');
    wrError: Result := StatusCode(503, 'Queue unavailable');
  end;
end;
```

### Push con máxima prioridad

```pascal
// Encola el mensaje al frente de la cola
fQueue.Push(urgentMsg, True {aMaxPriority});
```

---

## Consumir mensajes (Consumer)

El consumidor normalmente vive en un `TBackgroundService`:

```pascal
uses
  Quick.Core.MessageQueue.Abstractions,
  Quick.Core.Extensions.Hosting.BackgroundService;

type
  TOrderConsumerService = class(TBackgroundService)
  private
    fQueue    : IMessageQueue<TOrderMessage>;
    fOrderSvc : IOrderService;
  public
    constructor Create(
      aQueue    : IMessageQueue<TOrderMessage>;
      aOrderSvc : IOrderService);
  protected
    procedure ExecuteAsync; override;
  end;

procedure TOrderConsumerService.ExecuteAsync;
var
  msg : TOrderMessage;
begin
  while not CancelRequested do
  begin
    // Pop bloquea hasta PopTimeoutSec segundos
    case fQueue.Pop(msg) of
      wrOk:
        begin
          try
            fOrderSvc.Process(msg);
            // Confirmar procesamiento correcto
            fQueue.Remove(msg);
          except
            on E: Exception do
            begin
              Logger.Error('Order processing failed: ' + E.Message);
              // Mover a cola de fallidos
              fQueue.Failed(msg);
            end;
          end;
        end;
      wrTimeout: ; // normal — seguir esperando
      wrError:
        begin
          Logger.Error('Queue pop error');
          Sleep(5000); // esperar antes de reintentar
        end;
    end;
  end;
end;
```

---

## Reliable Queue — mensajes fiables

Cuando `ReliableMessageQueue.Enabled = True`, el mensaje se mueve a una **working key** al hacer `Pop` y solo se elimina definitivamente al llamar a `Remove`. Si el proceso muere antes de confirmar, el mensaje se devuelve automáticamente a la cola principal.

```pascal
opt.ReliableMessageQueue.Enabled                    := True;
opt.ReliableMessageQueue.DetermineAsHangedAfterSec  := 300; // 5 min sin confirmar → colgado
opt.ReliableMessageQueue.CheckHangedMessagesIntervalSec := 60;
opt.ReliableMessageQueue.RetryFailedMessages        := True;
opt.ReliableMessageQueue.RetryFailedMessageEverySec := 600; // reintentar fallidos cada 10 min
```

Flujo de procesamiento con reliable queue:

```
[queue:key]  →  Pop()  →  [queue:key:working]  →  Remove()  →  [queue:key:done]
                                                  ↘  Failed()  →  [queue:key:failed]
```

---

## Mensajes fallidos (Failed)

```pascal
// Marcar como fallido (mueve a :failed)
fQueue.Failed(msg);

// Marcar como fallido con mensaje procesado diferente
fQueue.Failed(originalMsg, processedMsg);

// Marcar como fallido con callback antes de guardar
fQueue.Failed(msg, procedure(m: TOrderMessage)
begin
  m.ErrorCount  := m.ErrorCount + 1;
  m.LastError   := 'Timeout connecting to payment gateway';
end);
```

---

## Patrón completo con Background Service

```pascal
// 1. Registrar en ConfigureServices
services.Extension<TMessageQueueServiceExtension>
  .AddRedisMessageQueue<TOrderMessage>(procedure(opt: TRedisMessageQueueOptions)
  begin
    opt.Host := 'localhost';
    opt.Key  := 'orders:queue';
    opt.ReliableMessageQueue.Enabled := True;
    opt.ReliableMessageQueue.DetermineAsHangedAfterSec := 120;
    opt.ReliableMessageQueue.RetryFailedMessages       := True;
  end);

services.Extension<THostedServiceExtension>
  .AddHostedService<TOrderConsumerService>;

// 2. El producer (controller, servicio, etc.) inyecta IMessageQueue<TOrderMessage>
// 3. El consumer (TOrderConsumerService) inyecta IMessageQueue<TOrderMessage>
// → Misma interfaz, mismo registro → comparten la misma cola Redis
```

### Equivalente C#

```csharp
// Con MassTransit sobre Redis Streams
builder.Services.AddMassTransit(x =>
{
    x.AddConsumer<OrderConsumer>();
    x.UsingRedis((ctx, cfg) => cfg.ConfigureEndpoints(ctx));
});
```

---

## Ver también

- [Background Services](Background-Services.md) — consumidores de cola
- [Dependency Injection](Dependency-Injection.md) — registro de la cola
- [Caching](Caching.md) — `AddDistributedRedisCache` (mismo servidor Redis)
