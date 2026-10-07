# Distributed Tracing (OpenTelemetry)

QuickCore includes a complete implementation of the OpenTelemetry API for distributed tracing, equivalent to the `OpenTelemetry.Api` package for .NET. It lets you instrument applications with spans, export traces to Jaeger, and propagate context between services using the W3C Traceparent format.

**Files:** `Quick.Core.Telemetry.Abstractions.pas`, `Quick.Core.Telemetry.pas`, `Quick.Core.Telemetry.Activity.pas`, `Quick.Core.Telemetry.Exporters.Jaeger.pas`, `Quick.Core.Extensions.Telemetry.pas`

---

## Contents

1. [Basics](#basics)
2. [Types and enumerations](#types-and-enumerations)
3. [ISpan — unit of work](#ispan--unit-of-work)
4. [ITracer — span factory](#itracer--span-factory)
5. [ITracerProvider](#itracerprovider)
6. [TActivity — RAII wrapper](#tactivity--raii-wrapper)
7. [TActivitySource](#tactivitysource)
8. [Jaeger Exporter](#jaeger-exporter)
9. [DI registration](#di-registration)
10. [Use in controllers](#use-in-controllers)
11. [W3C context propagation](#w3c-context-propagation)
12. [.NET comparison](#net-comparison)
13. [See also](#see-also)

---

## Basics

```
Request ──► [Root span: HTTP GET /api/orders]
              │
              ├──► [Child span: DB SELECT orders]
              │
              └──► [Child span: Redis GET cache:orders]
                        │
                        └──► [Grandchild span: Redis pipeline]
```

Each span has a **TraceId** (32 hex, identifies the full trace) and a **SpanId** (16 hex, identifies the individual span). Spans form a tree connected by `ParentSpanId`.

---

## Types and enumerations

```pascal
uses Quick.Core.Telemetry.Abstractions;

// Span kind (relationship with the system)
type TSpanKind = (
  skInternal,   // internal operation — no remote calls
  skServer,     // incoming request (HTTP server, RPC server)
  skClient,     // outgoing request (HTTP client, DB call)
  skProducer,   // message producer (queue, event bus)
  skConsumer    // message consumer
);

// Final state of the span
type TSpanStatus = (
  ssUnset,      // not set (default value)
  ssOk,         // completed successfully
  ssError       // completed with error
);

// Key-value attributes
type TSpanAttributes = TDictionary<string, string>;

// Event with timestamp within a span
type TSpanEvent = record
  Name       : string;
  Timestamp  : TDateTime;     // UTC
  Attributes : TSpanAttributes; // may be nil
end;
```

---

## ISpan — unit of work

Equivalent to `System.Diagnostics.Activity` in .NET.

```pascal
ISpan = interface
  // Identity
  function TraceId      : string;    // 32 hex — identifies the full trace
  function SpanId       : string;    // 16 hex — identifies this span
  function ParentSpanId : string;    // 16 hex; empty in root spans

  // Metadata
  function OperationName : string;
  function Kind          : TSpanKind;
  function StartTime     : TDateTime;  // UTC
  function EndTime       : TDateTime;  // UTC; zero until Finish
  function IsFinished    : Boolean;

  // Tags (OpenTelemetry semantic conventions)
  procedure SetTag(const aKey, aValue : string);
  function  Tags : TSpanAttributes;

  // Events with timestamp
  procedure AddEvent(const aName : string); overload;
  procedure AddEvent(const aName : string; aAttributes : TSpanAttributes); overload;
  function  Events : TArray<TSpanEvent>;

  // Status
  procedure SetStatus(aStatus : TSpanStatus; const aDescription : string = '');
  function  Status        : TSpanStatus;
  function  StatusMessage : string;

  // W3C propagation
  function  Traceparent : string;  // "00-{traceId}-{spanId}-01"

  // Lifecycle
  procedure Finish; overload;
  procedure Finish(aEndTime : TDateTime); overload;
end;
```

### Basic usage

```pascal
var
  tracer : ITracer;
  span   : ISpan;
begin
  tracer := ServiceProvider.GetService<ITracer>;

  span := tracer.StartSpan('process-order', skServer);
  try
    span.SetTag('order.id', orderId.ToString);
    span.SetTag('order.total', total.ToString);
    span.AddEvent('order-validated');

    ProcessOrder(orderId);

    span.SetStatus(ssOk);
  except
    on E: Exception do
    begin
      span.SetStatus(ssError, E.Message);
      raise;
    end;
  end;
  span.Finish;
end;
```

---

## ITracer — span factory

Equivalent to `ActivitySource` in .NET.

```pascal
ITracer = interface
  // Root span (no parent)
  function StartSpan(const aOperationName : string;
    aKind : TSpanKind = skInternal) : ISpan; overload;

  // Child span of an existing parent
  function StartSpan(const aOperationName : string;
    const aParent : ISpan;
    aKind : TSpanKind = skInternal) : ISpan; overload;

  // Span that continues a remote trace (W3C Traceparent header)
  function StartSpanFromTraceparent(const aOperationName, aTraceparent : string;
    aKind : TSpanKind = skServer) : ISpan;

  // Context propagation
  procedure Inject(const aSpan : ISpan; aHeaders : TDictionary<string, string>);
  function  Extract(aHeaders : TDictionary<string, string>) : string; // traceparent or ''

  function ServiceName : string;
end;
```

---

## ITracerProvider

Root factory (one per application). Equivalent to `TracerProvider` in .NET.

```pascal
ITracerProvider = interface
  function GetTracer(const aName : string; const aVersion : string = '') : ITracer;
  procedure AddExporter(const aExporter : ISpanExporter);
  procedure Shutdown;
end;
```

---

## TActivity — RAII wrapper

`TActivity` wraps `ISpan` with guaranteed cleanup in the destructor. Equivalent to using `Activity` with `using` in C#.

```pascal
TActivity = class
  constructor Create(const aSpan : ISpan);
  destructor Destroy; override;                   // calls Stop automatically

  function AddTag(const aKey, aValue : string) : TActivity;   // chainable
  function AddEvent(const aName : string) : TActivity;        // chainable
  function SetStatus(aStatus : TSpanStatus; const aDescription : string = '') : TActivity;
  procedure Stop;

  property Span          : ISpan;
  property TraceId       : string;
  property SpanId        : string;
  property ParentSpanId  : string;
  property OperationName : string;
  property Traceparent   : string;
  property IsRunning     : Boolean;
end;
```

### Usage with TActivity

```pascal
var
  source   : TActivitySource;
  activity : TActivity;
begin
  source   := TActivitySource.Create('my-service', '1.0');
  activity := source.StartActivity('validate-user', skServer);
  try
    activity
      .AddTag('user.id', userId)
      .AddTag('http.method', 'POST')
      .AddEvent('validation-started');

    ValidateUser(userId);

    activity.SetStatus(ssOk);
  except
    on E: Exception do
    begin
      activity.SetStatus(ssError, E.Message);
      raise;
    end;
  end;
  activity.Free;   // Stop is called automatically in the destructor
end;
```

---

## TActivitySource

Factory for `TActivity`. Equivalent to `ActivitySource` in .NET.

```pascal
var source := TActivitySource.Create('my-service', '1.0');
var activity := source.StartActivity('operation', skClient);
```

---

## Jaeger Exporter

Exports spans to Jaeger via OTLP/HTTP (JSON) to the endpoint `http://localhost:4318/v1/traces`.

### Options

```pascal
TJaegerExporterOptions = class
  property Endpoint     : string;   // Default: 'http://localhost:4318'
  property TimeoutMs    : Integer;  // Default: 5000 ms
  property BatchSize    : Integer;  // Default: 100 spans per batch
  property ServiceName  : string;   // Default: 'unknown_service'
  property IgnoreErrors : Boolean;  // Default: True (HTTP errors discarded)
end;
```

### Start Jaeger with Docker

```bash
docker run -d -p 16686:16686 -p 4318:4318 jaegertracing/all-in-one:latest
# UI available at http://localhost:16686
```

---

## DI registration

```pascal
uses
  Quick.Core.Extensions.Telemetry,
  Quick.Core.Telemetry.Exporters.Jaeger;

// In Startup.ConfigureServices:
var jaegerOpts := TJaegerExporterOptions.Create;
jaegerOpts.Endpoint    := 'http://jaeger:4318';
jaegerOpts.ServiceName := 'orders-api';
jaegerOpts.BatchSize   := 50;

services
  .AddTelemetry('orders-api')
    .AddExporter(TJaegerExporter.Create(jaegerOpts))
    .SetAsGlobal       // sets as TTracerProvider.Global
    .Build;

// Inject as ITracer or ITracerProvider:
services.AddScoped<IOrderService, TOrderService>;
// TOrderService receives ITracer in its constructor
```

### Access in controller

```pascal
type
  TOrdersController = class(THttpController)
  private
    fTracer : ITracer;
  public
    constructor Create(aTracer : ITracer);
  published
    [HttpGet('{id}')]
    function GetOrder(id : Integer) : IActionResult;
  end;

function TOrdersController.GetOrder(id : Integer) : IActionResult;
var span : ISpan;
begin
  span := fTracer.StartSpan('GetOrder', skServer);
  try
    span.SetTag('order.id', id.ToString);
    // ...
    span.SetStatus(ssOk);
    Result := Ok(orderDto);
  finally
    span.Finish;
  end;
end;
```

---

## W3C context propagation

To propagate the trace to external services (HTTP client, message queue):

```pascal
// Outgoing: inject headers
var headers := TDictionary<string, string>.Create;
tracer.Inject(currentSpan, headers);
httpRequest.AddHeader('traceparent', headers['traceparent']);

// Incoming: extract context from request
var traceparent := Request.Headers.GetValue('traceparent');
var childSpan   := tracer.StartSpanFromTraceparent('process-request', traceparent, skServer);
```

---

## .NET comparison

| Concept | .NET (OpenTelemetry) | QuickCore |
|---------|---------------------|-----------|
| Individual trace | `Activity` | `ISpan` |
| RAII wrapper | `using (var activity = source.StartActivity(...))` | `TActivity` (destructor calls Stop) |
| Span factory | `ActivitySource` | `ITracer` / `TActivitySource` |
| Global factory | `TracerProvider` | `ITracerProvider` |
| Span state | `ActivityStatusCode` (Unset/Ok/Error) | `TSpanStatus` (ssUnset/ssOk/ssError) |
| Span kind | `ActivityKind` | `TSpanKind` |
| Tags | `activity.SetTag(key, value)` | `span.SetTag(key, value)` |
| Events | `activity.AddEvent(name)` | `span.AddEvent(name)` |
| Propagation | W3C Traceparent automatic | `Inject/Extract` + `Traceparent` |
| Jaeger exporter | `OtlpTraceExporter` | `TJaegerExporter` |
| DI registration | `services.AddOpenTelemetry().WithTracing(b => b.AddOtlpExporter())` | `services.AddTelemetry('svc').AddExporter(jaeger).Build` |

```csharp
// C# — .NET
builder.Services.AddOpenTelemetry()
    .WithTracing(b => b
        .AddSource("orders-api")
        .AddOtlpExporter(o => o.Endpoint = new Uri("http://jaeger:4318")));

// In controller:
using var activity = ActivitySource.StartActivity("GetOrder", ActivityKind.Server);
activity?.SetTag("order.id", id);
```

```pascal
// Delphi — QuickCore
services
  .AddTelemetry('orders-api')
    .AddExporter(TJaegerExporter.Create(jaegerOpts))
    .Build;

// In controller:
span := fTracer.StartSpan('GetOrder', skServer);
span.SetTag('order.id', id.ToString);
// ...
span.Finish;
```

---

## See also

- [Resilience.md](Resilience.md) — Circuit Breaker, Retry, Timeout
- [Background-Services.md](Background-Services.md) — IHostedService
- [docs/API-Reference.md](../API-Reference.md#27-distributed-tracing-opentelemetry) — full reference


**Archivos:** `Quick.Core.Telemetry.Abstractions.pas`, `Quick.Core.Telemetry.pas`, `Quick.Core.Telemetry.Activity.pas`, `Quick.Core.Telemetry.Exporters.Jaeger.pas`, `Quick.Core.Extensions.Telemetry.pas`

---

## Contenido

1. [Conceptos básicos](#conceptos-básicos)
2. [Tipos y enumeraciones](#tipos-y-enumeraciones)
3. [ISpan — unidad de trabajo](#ispan--unidad-de-trabajo)
4. [ITracer — fábrica de spans](#itracer--fábrica-de-spans)
5. [ITracerProvider](#itracerprovider)
6. [TActivity — wrapper RAII](#tactivity--wrapper-raii)
7. [TActivitySource](#tactivitysource)
8. [Jaeger Exporter](#jaeger-exporter)
9. [Registro en DI](#registro-en-di)
10. [Uso en controllers](#uso-en-controllers)
11. [Propagación de contexto W3C](#propagación-de-contexto-w3c)
12. [Comparativa .NET](#comparativa-net)
13. [Ver también](#ver-también)

---

## Conceptos básicos

```
Request ──► [Span raíz: HTTP GET /api/orders]
              │
              ├──► [Span hijo: DB SELECT orders]
              │
              └──► [Span hijo: Redis GET cache:orders]
                        │
                        └──► [Span nieto: Redis pipeline]
```

Cada span tiene un **TraceId** (32 hex, identifica la traza completa) y un **SpanId** (16 hex, identifica el span individual). Los spans forman un árbol conectado por `ParentSpanId`.

---

## Tipos y enumeraciones

```pascal
uses Quick.Core.Telemetry.Abstractions;

// Tipo de span (relación con el sistema)
type TSpanKind = (
  skInternal,   // operación interna — sin llamadas remotas
  skServer,     // petición entrante (HTTP server, RPC server)
  skClient,     // petición saliente (HTTP client, DB call)
  skProducer,   // productor de mensajes (queue, event bus)
  skConsumer    // consumidor de mensajes
);

// Estado final del span
type TSpanStatus = (
  ssUnset,      // no establecido (valor por defecto)
  ssOk,         // completado con éxito
  ssError       // completado con error
);

// Atributos clave-valor
type TSpanAttributes = TDictionary<string, string>;

// Evento con timestamp dentro de un span
type TSpanEvent = record
  Name       : string;
  Timestamp  : TDateTime;     // UTC
  Attributes : TSpanAttributes; // puede ser nil
end;
```

---

## ISpan — unidad de trabajo

Equivalente a `System.Diagnostics.Activity` en .NET.

```pascal
ISpan = interface
  // Identidad
  function TraceId      : string;    // 32 hex — identifica la traza completa
  function SpanId       : string;    // 16 hex — identifica este span
  function ParentSpanId : string;    // 16 hex; vacío en spans raíz

  // Metadatos
  function OperationName : string;
  function Kind          : TSpanKind;
  function StartTime     : TDateTime;  // UTC
  function EndTime       : TDateTime;  // UTC; cero hasta Finish
  function IsFinished    : Boolean;

  // Tags (semantic conventions OpenTelemetry)
  procedure SetTag(const aKey, aValue : string);
  function  Tags : TSpanAttributes;

  // Eventos con timestamp
  procedure AddEvent(const aName : string); overload;
  procedure AddEvent(const aName : string; aAttributes : TSpanAttributes); overload;
  function  Events : TArray<TSpanEvent>;

  // Estado
  procedure SetStatus(aStatus : TSpanStatus; const aDescription : string = '');
  function  Status        : TSpanStatus;
  function  StatusMessage : string;

  // Propagación W3C
  function  Traceparent : string;  // "00-{traceId}-{spanId}-01"

  // Ciclo de vida
  procedure Finish; overload;
  procedure Finish(aEndTime : TDateTime); overload;
end;
```

### Uso básico

```pascal
var
  tracer : ITracer;
  span   : ISpan;
begin
  tracer := ServiceProvider.GetService<ITracer>;

  span := tracer.StartSpan('process-order', skServer);
  try
    span.SetTag('order.id', orderId.ToString);
    span.SetTag('order.total', total.ToString);
    span.AddEvent('order-validated');

    ProcessOrder(orderId);

    span.SetStatus(ssOk);
  except
    on E: Exception do
    begin
      span.SetStatus(ssError, E.Message);
      raise;
    end;
  end;
  span.Finish;
end;
```

---

## ITracer — fábrica de spans

Equivalente a `ActivitySource` en .NET.

```pascal
ITracer = interface
  // Span raíz (sin padre)
  function StartSpan(const aOperationName : string;
    aKind : TSpanKind = skInternal) : ISpan; overload;

  // Span hijo de un padre existente
  function StartSpan(const aOperationName : string;
    const aParent : ISpan;
    aKind : TSpanKind = skInternal) : ISpan; overload;

  // Span que continúa una traza remota (W3C Traceparent header)
  function StartSpanFromTraceparent(const aOperationName, aTraceparent : string;
    aKind : TSpanKind = skServer) : ISpan;

  // Propagación de contexto
  procedure Inject(const aSpan : ISpan; aHeaders : TDictionary<string, string>);
  function  Extract(aHeaders : TDictionary<string, string>) : string; // traceparent o ''

  function ServiceName : string;
end;
```

---

## ITracerProvider

Fábrica raíz (una por aplicación). Equivalente a `TracerProvider` de .NET.

```pascal
ITracerProvider = interface
  function GetTracer(const aName : string; const aVersion : string = '') : ITracer;
  procedure AddExporter(const aExporter : ISpanExporter);
  procedure Shutdown;
end;
```

---

## TActivity — wrapper RAII

`TActivity` envuelve `ISpan` con limpieza garantizada en el destructor. Equivalente a usar `Activity` con `using` en C#.

```pascal
TActivity = class
  constructor Create(const aSpan : ISpan);
  destructor Destroy; override;                   // llama Stop automáticamente

  function AddTag(const aKey, aValue : string) : TActivity;   // chainable
  function AddEvent(const aName : string) : TActivity;        // chainable
  function SetStatus(aStatus : TSpanStatus; const aDescription : string = '') : TActivity;
  procedure Stop;

  property Span          : ISpan;
  property TraceId       : string;
  property SpanId        : string;
  property ParentSpanId  : string;
  property OperationName : string;
  property Traceparent   : string;
  property IsRunning     : Boolean;
end;
```

### Uso con TActivity

```pascal
var
  source   : TActivitySource;
  activity : TActivity;
begin
  source   := TActivitySource.Create('my-service', '1.0');
  activity := source.StartActivity('validate-user', skServer);
  try
    activity
      .AddTag('user.id', userId)
      .AddTag('http.method', 'POST')
      .AddEvent('validation-started');

    ValidateUser(userId);

    activity.SetStatus(ssOk);
  except
    on E: Exception do
    begin
      activity.SetStatus(ssError, E.Message);
      raise;
    end;
  end;
  activity.Free;   // Stop se llama automáticamente en el destructor
end;
```

---

## TActivitySource

Fábrica de `TActivity`. Equivalente a `ActivitySource` en .NET.

```pascal
var source := TActivitySource.Create('my-service', '1.0');
var activity := source.StartActivity('operation', skClient);
```

---

## Jaeger Exporter

Exporta spans a Jaeger vía OTLP/HTTP (JSON) al endpoint `http://localhost:4318/v1/traces`.

### Opciones

```pascal
TJaegerExporterOptions = class
  property Endpoint     : string;   // Default: 'http://localhost:4318'
  property TimeoutMs    : Integer;  // Default: 5000 ms
  property BatchSize    : Integer;  // Default: 100 spans por batch
  property ServiceName  : string;   // Default: 'unknown_service'
  property IgnoreErrors : Boolean;  // Default: True (HTTP errors descartados)
end;
```

### Iniciar Jaeger con Docker

```bash
docker run -d -p 16686:16686 -p 4318:4318 jaegertracing/all-in-one:latest
# UI disponible en http://localhost:16686
```

---

## Registro en DI

```pascal
uses
  Quick.Core.Extensions.Telemetry,
  Quick.Core.Telemetry.Exporters.Jaeger;

// En Startup.ConfigureServices:
var jaegerOpts := TJaegerExporterOptions.Create;
jaegerOpts.Endpoint    := 'http://jaeger:4318';
jaegerOpts.ServiceName := 'orders-api';
jaegerOpts.BatchSize   := 50;

services
  .AddTelemetry('orders-api')
    .AddExporter(TJaegerExporter.Create(jaegerOpts))
    .SetAsGlobal       // establece como TTracerProvider.Global
    .Build;

// Inyectar como ITracer o ITracerProvider:
services.AddScoped<IOrderService, TOrderService>;
// TOrderService recibe ITracer en su constructor
```

### Acceso en controller

```pascal
type
  TOrdersController = class(THttpController)
  private
    fTracer : ITracer;
  public
    constructor Create(aTracer : ITracer);
  published
    [HttpGet('{id}')]
    function GetOrder(id : Integer) : IActionResult;
  end;

function TOrdersController.GetOrder(id : Integer) : IActionResult;
var span : ISpan;
begin
  span := fTracer.StartSpan('GetOrder', skServer);
  try
    span.SetTag('order.id', id.ToString);
    // ...
    span.SetStatus(ssOk);
    Result := Ok(orderDto);
  finally
    span.Finish;
  end;
end;
```

---

## Propagación de contexto W3C

Para propagar la traza a servicios externos (HTTP client, message queue):

```pascal
// Saliente: inyectar headers
var headers := TDictionary<string, string>.Create;
tracer.Inject(currentSpan, headers);
httpRequest.AddHeader('traceparent', headers['traceparent']);

// Entrante: extraer contexto del request
var traceparent := Request.Headers.GetValue('traceparent');
var childSpan   := tracer.StartSpanFromTraceparent('process-request', traceparent, skServer);
```

---

## Comparativa .NET

| Concepto | .NET (OpenTelemetry) | QuickCore |
|---------|---------------------|-----------|
| Traza individual | `Activity` | `ISpan` |
| Wrapper RAII | `using (var activity = source.StartActivity(...))` | `TActivity` (destructor llama Stop) |
| Fábrica de spans | `ActivitySource` | `ITracer` / `TActivitySource` |
| Fábrica global | `TracerProvider` | `ITracerProvider` |
| Estado span | `ActivityStatusCode` (Unset/Ok/Error) | `TSpanStatus` (ssUnset/ssOk/ssError) |
| Tipo de span | `ActivityKind` | `TSpanKind` |
| Tags | `activity.SetTag(key, value)` | `span.SetTag(key, value)` |
| Eventos | `activity.AddEvent(name)` | `span.AddEvent(name)` |
| Propagación | W3C Traceparent automático | `Inject/Extract` + `Traceparent` |
| Exporter Jaeger | `OtlpTraceExporter` | `TJaegerExporter` |
| Registro DI | `services.AddOpenTelemetry().WithTracing(b => b.AddOtlpExporter())` | `services.AddTelemetry('svc').AddExporter(jaeger).Build` |

```csharp
// C# — .NET
builder.Services.AddOpenTelemetry()
    .WithTracing(b => b
        .AddSource("orders-api")
        .AddOtlpExporter(o => o.Endpoint = new Uri("http://jaeger:4318")));

// En controller:
using var activity = ActivitySource.StartActivity("GetOrder", ActivityKind.Server);
activity?.SetTag("order.id", id);
```

```pascal
// Delphi — QuickCore
services
  .AddTelemetry('orders-api')
    .AddExporter(TJaegerExporter.Create(jaegerOpts))
    .Build;

// En controller:
span := fTracer.StartSpan('GetOrder', skServer);
span.SetTag('order.id', id.ToString);
// ...
span.Finish;
```

---

## Ver también

- [Resilience.md](Resilience.md) — Circuit Breaker, Retry, Timeout
- [Background-Services.md](Background-Services.md) — IHostedService
- [docs/API-Reference.md](../API-Reference.md#27-distributed-tracing-opentelemetry) — referencia completa
