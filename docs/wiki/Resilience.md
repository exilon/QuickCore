# Resilience — Circuit Breaker, Retry, Timeout

> Module: `Quick.Core.Resilience.*`  
> Version: 2.9.0+  
> .NET equivalent: [Polly](https://github.com/App-vNext/Polly) / `Microsoft.Extensions.Resilience`

---

## What is resilience?

Resilience patterns allow your application to tolerate transient failures in external services (HTTP APIs, databases, message queues). QuickCore implements three complementary policies:

| Policy | Purpose | Class |
|--------|---------|-------|
| **Circuit Breaker** | Stop calls when the service is down | `TCircuitBreakerPolicy<T>` |
| **Retry** | Automatically retry on transient failures | `TRetryPolicy<T>` |
| **Timeout** | Cancel calls that take too long | `TTimeoutPolicy<T>` |

All implement `IResiliencePolicy<T>` with a single `Execute(func)` method.

---

## Installation

Add the required units to your project:

```pascal
uses
  Quick.Core.Resilience.Abstractions,   // IResiliencePolicy<T>, exceptions, TBackoffType
  Quick.Core.Resilience.CircuitBreaker, // TCircuitBreakerPolicy<T>
  Quick.Core.Resilience.Retry,          // TRetryPolicy<T>
  Quick.Core.Resilience.Timeout,        // TTimeoutPolicy<T>
  Quick.Core.Extensions.Resilience;     // DI extensions (AddCircuitBreaker, AddRetry, AddTimeout)
```

---

## Circuit Breaker

### Concept

```
                    ┌──────────────────────────────────────────────────────┐
   FailureCount                                                              
   >= Threshold                                                              
        ┌─────────────────┐       DurationOfBreakMs        ┌────────────┐  
CLOSED  │ calls pass      │ ────────────────────────────► OPEN         │  
        │ normally        │                                 │ fail fast  │  
        └────────┬────────┘  ◄────────────────────────────└────────────┘  
                 │  probe OK              probe call                        
                 │◄───────── HALF-OPEN ──────────────────►                 
                                │  probe fails → OPEN                       
                                │  reset timer                              
```

### Basic usage

```pascal
uses
  Quick.Core.Resilience.CircuitBreaker,
  Quick.Core.Resilience.Abstractions;

var
  cb: TCircuitBreakerPolicy<string>;
  result: string;
begin
  cb := TCircuitBreakerPolicy<string>.Create(
    {FailureThreshold}  3,      // open after 3 consecutive failures
    {DurationOfBreakMs} 5000);  // stay open for 5 seconds
  try
    result := cb.Execute(function: string
      begin
        Result := HttpClient.Get('https://api.example.com/data');
      end);
  except
    on ECircuitOpenException do
      result := 'Service unavailable';  // fast fail: does not call the service
    on Exception do
      ; // real failure: CB increments the counter
  end;
end;
```

### With state-change callback

```pascal
cb := TCircuitBreakerPolicy<string>.Create(
  3, 5000,
  procedure(oldState, newState: TCircuitState)
  begin
    Logger.Warn('Circuit %s → %s', [
      GetEnumName(TypeInfo(TCircuitState), Ord(oldState)),
      GetEnumName(TypeInfo(TCircuitState), Ord(newState))]);
    // Here you could send an alert, update metrics, etc.
  end);
```

### Properties and methods

| Member | Description |
|--------|-------------|
| `State` | Current state: `cbClosed`, `cbOpen`, `cbHalfOpen`. |
| `FailureCount` | Current consecutive failure count. |
| `Reset` | Manually closes the circuit and resets the counter. |
| `Execute(func)` | Executes `func`; raises `ECircuitOpenException` if open. |

---

## Retry Policy

### Backoff strategies

| Strategy | Behavior | When to use |
|----------|----------|-------------|
| `btConstant` | Always waits `InitialDelayMs` | Predictable failures, slow but stable APIs |
| `btExponential` | `InitialDelayMs × 2^(attempt-1)`, max `MaxDelayMs` | Server overload, need time for recovery |
| `btDecorrelated` | AWS jitter: random in `[InitialDelayMs, prev×3]` | Distributed systems — avoids thundering herd |

### Basic usage

```pascal
uses
  Quick.Core.Resilience.Retry,
  Quick.Core.Resilience.Abstractions;

var
  retry: TRetryPolicy<string>;
begin
  retry := TRetryPolicy<string>.Create(
    {MaxRetries}     3,
    {InitialDelayMs} 200,
    btExponential,
    {MaxDelayMs}     5000);

  result := retry.Execute(function: string
    begin
      Result := HttpClient.Get('https://api.example.com/data');
    end);
  // If it fails 4 times → ERetryExhaustedException
end;
```

### With logging and filter

```pascal
retry := TRetryPolicy<string>.Create(
  3, 500, btDecorrelated, 10000,
  // OnRetry: log before each retry
  procedure(attempt, delayMs: Integer; e: Exception)
  begin
    Logger.Warn('Retry %d/%d after %dms. Error: %s', [attempt, 3, delayMs, e.Message]);
  end,
  // ShouldRetry: only retry on network errors, not 4xx
  function(e: Exception): Boolean
  begin
    Result := (e is EHTTPError) and (EHTTPError(e).StatusCode >= 500);
  end);
```

### Constructor parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `aMaxRetries` | `Integer` | Extra attempts after the first failure. 0 = only 1 attempt. |
| `aInitialDelayMs` | `Int64` | Base delay in ms. |
| `aBackoffType` | `TBackoffType` | Growth strategy. Default: `btConstant`. |
| `aMaxDelayMs` | `Int64` | Delay ceiling for `btExponential`. Default: 30000 ms. |
| `aOnRetry` | `TRetryEvent` | Callback before each sleep. Optional. |
| `aShouldRetry` | `function(E): Boolean` | Exception filter. Default: always retry. |

---

## Timeout Policy

### Basic usage

```pascal
uses
  Quick.Core.Resilience.Timeout,
  Quick.Core.Resilience.Abstractions;

var
  timeout: TTimeoutPolicy<string>;
begin
  timeout := TTimeoutPolicy<string>.Create(
    {TimeoutMs} 3000,  // cancel if it takes more than 3 seconds
    procedure(aTimeoutMs: Int64; e: ETimeoutException)
    begin
      Logger.Error('Operation timed out after %dms', [aTimeoutMs]);
    end);

  try
    result := timeout.Execute(function: string
      begin
        Result := HttpClient.Get('https://api.example.com/slow');
      end);
  except
    on ETimeoutException do
      result := 'timeout';
  end;
end;
```

> **Implementation:** `TTimeoutPolicy<T>` executes `func` on a separate thread and waits `TimeoutMs`. If the thread does not respond in time, it raises `ETimeoutException` on the main thread. The worker continues running until completion (no forced cancellation).

---

## Combining policies

The recommended order (outermost to innermost):

```
Timeout → Retry → Circuit Breaker → actual call
```

```pascal
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

**Why this order:**
- **Timeout** outermost: cancels the entire attempt if the total time budget is exceeded.
- **Retry** in the middle: retries within the time budget.
- **Circuit Breaker** innermost: avoids retrying if the service is already down (immediate fail fast).

---

## DI integration

For stateful policies (especially Circuit Breaker), register them as Singleton in DI to share state across all requests to the same downstream service.

```pascal
// ConfigureServices
services.Extension<TResilienceServiceExtension>
  .AddCircuitBreaker<string>('payments-cb',
    {FailureThreshold} 5,
    {DurationOfBreakMs} 15000,
    procedure(o, n: TCircuitState)
    begin Logger.Warn('Payments CB: %s', [GetEnumName(TypeInfo(TCircuitState), Ord(n))]) end)
  .AddRetry<string>('payments-retry',
    {MaxRetries} 3,
    {InitialDelayMs} 300,
    btExponential)
  .AddTimeout<string>('payments-timeout',
    {TimeoutMs} 5000);

// Usage in a service
type
  TPaymentService = class
  private
    fCb      : IResiliencePolicy<string>;
    fRetry   : IResiliencePolicy<string>;
    fTimeout : IResiliencePolicy<string>;
  public
    constructor Create(
      [FromKeyedServices('payments-cb')]      aCb: IResiliencePolicy<string>;
      [FromKeyedServices('payments-retry')]   aRetry: IResiliencePolicy<string>;
      [FromKeyedServices('payments-timeout')] aTimeout: IResiliencePolicy<string>);
  end;
```

---

## Exceptions

| Exception | When raised |
|-----------|-------------|
| `ECircuitOpenException` | The circuit is open and the call is blocked. |
| `ERetryExhaustedException` | All retries have been exhausted. |
| `ETimeoutException` | The operation exceeded the configured timeout. |
| `EResilienceError` | Base for all resilience exceptions. |

---

## .NET / Polly comparison

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
        SamplingDuration = TimeSpan.FromSeconds(30),
        MinimumThroughput = 5,
        BreakDuration = TimeSpan.FromSeconds(15)
    })
    .Build();
```

```pascal
// Delphi — QuickCore
timeout := TTimeoutPolicy<string>.Create(5000);
retry   := TRetryPolicy<string>.Create(3, 200, btExponential);
cb      := TCircuitBreakerPolicy<string>.Create(5, 15000);

result := timeout.Execute(function: string
  begin Result := retry.Execute(function: string
    begin Result := cb.Execute(func) end) end);
```

> The main difference: Polly v8 uses a unified `ResiliencePipeline`; QuickCore composes policies by nesting `Execute` calls. The result is functionally equivalent.

---

## See also

- [Caching](Caching.md) — in-memory and Redis cache
- [Background Services](Background-Services.md) — workers with failure handling
- [API Reference — Resilience](../API-Reference.md#23-resilience)


Los patrones de resiliencia permiten que tu aplicación tolere fallos transitorios en servicios externos (APIs HTTP, bases de datos, colas de mensajes). QuickCore implementa tres políticas complementarias:

| Política | Propósito | Clase |
|----------|-----------|-------|
| **Circuit Breaker** | Detener llamadas cuando el servicio está caído | `TCircuitBreakerPolicy<T>` |
| **Retry** | Reintentar automáticamente en fallos transitorios | `TRetryPolicy<T>` |
| **Timeout** | Cancelar llamadas que tardan demasiado | `TTimeoutPolicy<T>` |

Todas implementan `IResiliencePolicy<T>` con un único método `Execute(func)`.

---

## Instalación

Añade las unidades necesarias a tu proyecto:

```pascal
uses
  Quick.Core.Resilience.Abstractions,   // IResiliencePolicy<T>, excepciones, TBackoffType
  Quick.Core.Resilience.CircuitBreaker, // TCircuitBreakerPolicy<T>
  Quick.Core.Resilience.Retry,          // TRetryPolicy<T>
  Quick.Core.Resilience.Timeout,        // TTimeoutPolicy<T>
  Quick.Core.Extensions.Resilience;     // DI extensions (AddCircuitBreaker, AddRetry, AddTimeout)
```

---

## Circuit Breaker

### Concepto

```
                    ┌──────────────────────────────────────────────────────┐
   FailureCount                                                              
   >= Threshold                                                              
        ┌─────────────────┐       DurationOfBreakMs        ┌────────────┐  
CLOSED  │ llamadas pasan  │ ────────────────────────────► OPEN         │  
        │ normalmente     │                                 │ fail fast  │  
        └────────┬────────┘  ◄────────────────────────────└────────────┘  
                 │  probe OK              probe call                        
                 │◄───────── HALF-OPEN ──────────────────►                 
                                │  probe fails → OPEN                       
                                │  reset timer                              
```

### Uso básico

```pascal
uses
  Quick.Core.Resilience.CircuitBreaker,
  Quick.Core.Resilience.Abstractions;

var
  cb: TCircuitBreakerPolicy<string>;
  result: string;
begin
  cb := TCircuitBreakerPolicy<string>.Create(
    {FailureThreshold}  3,      // abrir tras 3 fallos consecutivos
    {DurationOfBreakMs} 5000);  // permanecer abierto 5 segundos
  try
    result := cb.Execute(function: string
      begin
        Result := HttpClient.Get('https://api.example.com/data');
      end);
  except
    on ECircuitOpenException do
      result := 'Service unavailable';  // fallo rápido: no llama al servicio
    on Exception do
      ; // fallo real: el CB incrementa el contador
  end;
end;
```

### Con callback de cambio de estado

```pascal
cb := TCircuitBreakerPolicy<string>.Create(
  3, 5000,
  procedure(oldState, newState: TCircuitState)
  begin
    Logger.Warn('Circuit %s → %s', [
      GetEnumName(TypeInfo(TCircuitState), Ord(oldState)),
      GetEnumName(TypeInfo(TCircuitState), Ord(newState))]);
    // Aquí podrías enviar una alerta, actualizar métricas, etc.
  end);
```

### Propiedades y métodos

| Miembro | Descripción |
|---------|-------------|
| `State` | Estado actual: `cbClosed`, `cbOpen`, `cbHalfOpen`. |
| `FailureCount` | Contador de fallos consecutivos actuales. |
| `Reset` | Cierra manualmente el circuito y resetea el contador. |
| `Execute(func)` | Ejecuta `func`; lanza `ECircuitOpenException` si está abierto. |

---

## Retry Policy

### Estrategias de backoff

| Estrategia | Comportamiento | Cuándo usar |
|------------|----------------|-------------|
| `btConstant` | Espera siempre `InitialDelayMs` | Fallos predecibles, APIs lentas pero estables |
| `btExponential` | `InitialDelayMs × 2^(intento-1)`, máx `MaxDelayMs` | Sobrecarga de servidor, necesitas dar tiempo de recuperación |
| `btDecorrelated` | Jitter AWS: aleatorio en `[InitialDelayMs, prev×3]` | Sistemas distribuidos — evita el "thundering herd" |

### Uso básico

```pascal
uses
  Quick.Core.Resilience.Retry,
  Quick.Core.Resilience.Abstractions;

var
  retry: TRetryPolicy<string>;
begin
  retry := TRetryPolicy<string>.Create(
    {MaxRetries}     3,
    {InitialDelayMs} 200,
    btExponential,
    {MaxDelayMs}     5000);

  result := retry.Execute(function: string
    begin
      Result := HttpClient.Get('https://api.example.com/data');
    end);
  // Si falla 4 veces → ERetryExhaustedException
end;
```

### Con logging y filtro

```pascal
retry := TRetryPolicy<string>.Create(
  3, 500, btDecorrelated, 10000,
  // OnRetry: log antes de cada reintento
  procedure(attempt, delayMs: Integer; e: Exception)
  begin
    Logger.Warn('Retry %d/%d after %dms. Error: %s', [attempt, 3, delayMs, e.Message]);
  end,
  // ShouldRetry: solo reintentar en errores de red, no en 4xx
  function(e: Exception): Boolean
  begin
    Result := (e is EHTTPError) and (EHTTPError(e).StatusCode >= 500);
  end);
```

### Parámetros del constructor

| Parámetro | Tipo | Descripción |
|-----------|------|-------------|
| `aMaxRetries` | `Integer` | Extra intentos tras el primer fallo. 0 = solo 1 intento. |
| `aInitialDelayMs` | `Int64` | Delay base en ms. |
| `aBackoffType` | `TBackoffType` | Estrategia de crecimiento. Default: `btConstant`. |
| `aMaxDelayMs` | `Int64` | Techo de delay para `btExponential`. Default: 30000 ms. |
| `aOnRetry` | `TRetryEvent` | Callback antes de cada sleep. Opcional. |
| `aShouldRetry` | `function(E): Boolean` | Filtro de excepciones. Default: reintentar siempre. |

---

## Timeout Policy

### Uso básico

```pascal
uses
  Quick.Core.Resilience.Timeout,
  Quick.Core.Resilience.Abstractions;

var
  timeout: TTimeoutPolicy<string>;
begin
  timeout := TTimeoutPolicy<string>.Create(
    {TimeoutMs} 3000,  // cancelar si tarda más de 3 segundos
    procedure(aTimeoutMs: Int64; e: ETimeoutException)
    begin
      Logger.Error('Operation timed out after %dms', [aTimeoutMs]);
    end);

  try
    result := timeout.Execute(function: string
      begin
        Result := HttpClient.Get('https://api.example.com/slow');
      end);
  except
    on ETimeoutException do
      result := 'timeout';
  end;
end;
```

> **Implementación:** `TTimeoutPolicy<T>` ejecuta `func` en un hilo separado y espera `TimeoutMs`. Si el hilo no responde a tiempo, lanza `ETimeoutException` en el hilo principal. El worker continúa ejecutándose hasta completarse (sin cancelación forzada).

---

## Combinación de políticas

El orden recomendado (de exterior a interior):

```
Timeout → Retry → Circuit Breaker → llamada real
```

```pascal
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

**Por qué este orden:**
- **Timeout** exterior: cancela todo el intento si se excede el tiempo total.
- **Retry** en el medio: reintenta dentro del presupuesto de tiempo.
- **Circuit Breaker** interior: evita reintentar si el servicio ya está caído (fail fast inmediato).

---

## Integración con DI

Para políticas stateful (especialmente Circuit Breaker), regístralas como Singleton en DI para compartir el estado entre todas las peticiones al mismo servicio downstream.

```pascal
// ConfigureServices
services.Extension<TResilienceServiceExtension>
  .AddCircuitBreaker<string>('payments-cb',
    {FailureThreshold} 5,
    {DurationOfBreakMs} 15000,
    procedure(o, n: TCircuitState)
    begin Logger.Warn('Payments CB: %s', [GetEnumName(TypeInfo(TCircuitState), Ord(n))]) end)
  .AddRetry<string>('payments-retry',
    {MaxRetries} 3,
    {InitialDelayMs} 300,
    btExponential)
  .AddTimeout<string>('payments-timeout',
    {TimeoutMs} 5000);

// Uso en servicio
type
  TPaymentService = class
  private
    fCb      : IResiliencePolicy<string>;
    fRetry   : IResiliencePolicy<string>;
    fTimeout : IResiliencePolicy<string>;
  public
    constructor Create(
      [FromKeyedServices('payments-cb')]      aCb: IResiliencePolicy<string>;
      [FromKeyedServices('payments-retry')]   aRetry: IResiliencePolicy<string>;
      [FromKeyedServices('payments-timeout')] aTimeout: IResiliencePolicy<string>);
  end;
```

---

## Excepciones

| Excepción | Cuándo se lanza |
|-----------|----------------|
| `ECircuitOpenException` | El circuito está abierto y la llamada se bloquea. |
| `ERetryExhaustedException` | Todos los reintentos se han agotado. |
| `ETimeoutException` | La operación superó el timeout configurado. |
| `EResilienceError` | Base de todas las excepciones de resiliencia. |

---

## Comparativa con .NET / Polly

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
        SamplingDuration = TimeSpan.FromSeconds(30),
        MinimumThroughput = 5,
        BreakDuration = TimeSpan.FromSeconds(15)
    })
    .Build();
```

```pascal
// Delphi — QuickCore
timeout := TTimeoutPolicy<string>.Create(5000);
retry   := TRetryPolicy<string>.Create(3, 200, btExponential);
cb      := TCircuitBreakerPolicy<string>.Create(5, 15000);

result := timeout.Execute(function: string
  begin Result := retry.Execute(function: string
    begin Result := cb.Execute(func) end) end);
```

> La principal diferencia: Polly v8 usa un `ResiliencePipeline` unificado; QuickCore compone políticas anidando `Execute`. El resultado es funcionalmente equivalente.

---

## Ver también

- [Caching](Caching.md) — caché en memoria y Redis
- [Background Services](Background-Services.md) — workers con manejo de fallos
- [API Reference — Resilience](../API-Reference.md#23-resilience)
