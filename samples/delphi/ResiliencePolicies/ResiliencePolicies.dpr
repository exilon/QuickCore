program ResiliencePolicies;

(* ResiliencePolicies Sample
  Demonstrates the three core Polly-equivalent resilience policies in QuickCore:
    - Circuit Breaker : TCircuitBreakerPolicy<T>  — Closed/Open/HalfOpen state machine
    - Retry           : TRetryPolicy<T>            — constant / exponential / jitter backoff
    - Timeout         : TTimeoutPolicy<T>          — deadline enforcement via TTask

  .NET equivalent: Polly v8 / Microsoft.Extensions.Resilience
    ResiliencePipelineBuilder
      .AddRetry(new RetryStrategyOptions { MaxRetryAttempts = 3, ... })
      .AddCircuitBreaker(new CircuitBreakerStrategyOptions { ... })
      .AddTimeout(TimeSpan.FromSeconds(5))
      .Build();
*)

{$APPTYPE CONSOLE}
// {$R *.res}  — .res not generated for dcc32 console builds; omit to avoid linker error

uses
  System.SysUtils,
  System.Classes,
  System.Threading,
  Quick.Console,
  Quick.Core.Resilience.Abstractions,
  Quick.Core.Resilience.CircuitBreaker,
  Quick.Core.Resilience.Retry,
  Quick.Core.Resilience.Timeout;

// ─────────────────────────────────────────────────────────────────────────────
// Simulated external service
// ─────────────────────────────────────────────────────────────────────────────

var
  GCallCount: Integer = 0;

function CallExternalApi(const aEndpoint: string): string;
begin
  Inc(GCallCount);
  WriteLn(Format('  → Calling %s (attempt %d)...', [aEndpoint, GCallCount]));

  // Simulate intermittent failure: fails first 2 calls, succeeds on 3rd
  if GCallCount < 3 then
    raise Exception.CreateFmt('Service unavailable (call %d)', [GCallCount]);

  Result := Format('{"status":"ok","call":%d}', [GCallCount]);
end;

function SlowExternalApi: string;
begin
  WriteLn('  → Calling slow endpoint...');
  TThread.Sleep(2000); // 2 seconds — will exceed 500ms timeout
  Result := 'never returned';
end;

// ─────────────────────────────────────────────────────────────────────────────
// Demo sections
// ─────────────────────────────────────────────────────────────────────────────

procedure DemoRetryConstant;
var
  retry : TRetryPolicy<string>;
  result: string;
begin
  WriteLn;
  WriteLn('─── 1. RETRY — Constant backoff (3 retries, 200ms) ───────────────');
  GCallCount := 0;

  retry := TRetryPolicy<string>.Create(3, 200, btConstant, 30000,
    procedure(aAttempt: Integer; aDelayMs: Int64; E: Exception)
    begin
      WriteLn(Format('  [OnRetry] attempt=%d delay=%dms error="%s"',
        [aAttempt, aDelayMs, E.Message]));
    end);
  try
    result := retry.Execute(function: string
      begin
        Result := CallExternalApi('/api/data');
      end);
    WriteLn('  ✅ Success: ' + result);
  finally
    retry.Free;
  end;
end;

procedure DemoRetryExponential;
var
  retry : TRetryPolicy<string>;
begin
  WriteLn;
  WriteLn('─── 2. RETRY — Exponential backoff (5 retries, base 100ms) ──────');
  GCallCount := 10; // force all calls to fail (always < 3 is false for this demo)

  retry := TRetryPolicy<string>.Create(3, 100, btExponential, 5000,
    procedure(aAttempt: Integer; aDelayMs: Int64; E: Exception)
    begin
      WriteLn(Format('  [OnRetry] attempt=%d delay=%dms (exponential)',
        [aAttempt, aDelayMs]));
    end);
  try
    try
      retry.Execute(function: string
        begin
          Inc(GCallCount);
          raise Exception.Create('always failing');
        end);
    except
      on E: ERetryExhaustedException do
        WriteLn('  ❌ ERetryExhaustedException: ' + E.Message.Substring(0, 70));
    end;
  finally
    retry.Free;
  end;
end;

procedure DemoCircuitBreaker;
var
  cb        : TCircuitBreakerPolicy<string>;
  i         : Integer;
  r         : string;
begin
  WriteLn;
  WriteLn('─── 3. CIRCUIT BREAKER — threshold=3, break=500ms ───────────────');
  GCallCount := 0;

  cb := TCircuitBreakerPolicy<string>.Create(3, 500,
    procedure(aOld, aNew: TCircuitState)
    const
      NAMES: array[TCircuitState] of string = ('Closed','Open','HalfOpen');
    begin
      WriteLn(Format('  [StateChange] %s → %s', [NAMES[aOld], NAMES[aNew]]));
    end);
  try
    // Provoke 3 failures → Open
    for i := 1 to 3 do
    begin
      try
        cb.Execute(function: string
          begin
            raise Exception.CreateFmt('downstream error #%d', [i]);
          end);
      except
        on E: Exception do
          if not (E is ECircuitOpenException) then
            WriteLn(Format('  Failure %d: %s', [i, E.Message]));
      end;
    end;

    // 4th call should fail-fast
    WriteLn('  Attempting call while circuit is OPEN...');
    try
      cb.Execute(function: string begin Result := 'ok' end);
    except
      on E: ECircuitOpenException do
        WriteLn('  ❌ ECircuitOpenException (expected): circuit is open');
    end;

    // Wait for break duration → HalfOpen
    WriteLn('  Waiting 600ms for break duration to elapse...');
    TThread.Sleep(600);

    // Probe call — should succeed and close circuit
    GCallCount := 5; // success condition
    try
      r := cb.Execute(function: string begin Result := 'probe ok' end);
      WriteLn('  Probe succeeded, circuit closed. Result: ' + r);
    except
      on E: Exception do WriteLn('  Probe failed: ' + E.Message);
    end;

    WriteLn(Format('  Final state: %d (0=Closed)', [Ord(cb.State)]));
  finally
    cb.Free;
  end;
end;

procedure DemoTimeout;
var
  tp : TTimeoutPolicy<string>;
  r  : string;
begin
  WriteLn;
  WriteLn('─── 4. TIMEOUT — 500ms deadline ─────────────────────────────────');

  // Fast call — should succeed
  tp := TTimeoutPolicy<string>.Create(1000);
  try
    r := tp.Execute(function: string begin Result := 'fast response' end);
    WriteLn('  Fast call completed: ' + r);
  finally
    tp.Free;
  end;

  // Slow call — should timeout
  tp := TTimeoutPolicy<string>.Create(500,
    procedure(aMs: Int64)
    begin
      WriteLn(Format('  [OnTimeout] Operation exceeded %dms deadline', [aMs]));
    end);
  try
    try
      tp.Execute(function: string begin Result := SlowExternalApi end);
    except
      on E: ETimeoutException do
        WriteLn('  ❌ ETimeoutException (expected): ' + E.Message);
    end;
    TThread.Sleep(2100); // let background thread finish before cleanup
  finally
    tp.Free;
  end;
end;

procedure DemoComposed;
var
  cb    : TCircuitBreakerPolicy<string>;
  retry : TRetryPolicy<string>;
  r     : string;
begin
  WriteLn;
  WriteLn('─── 5. COMPOSED — Retry wrapping CircuitBreaker ──────────────────');
  WriteLn('      (Classic Polly composition pattern)');
  GCallCount := 0;

  cb := TCircuitBreakerPolicy<string>.Create(2, 2000);
  retry := TRetryPolicy<string>.Create(5, 50, btConstant, 5000,
    procedure(aAttempt: Integer; aDelayMs: Int64; E: Exception)
    begin
      if E is ECircuitOpenException then
        WriteLn(Format('  [Retry %d] Circuit is open — waiting %dms', [aAttempt, aDelayMs]))
      else
        WriteLn(Format('  [Retry %d] Error: %s', [aAttempt, E.Message]));
    end);
  try
    try
      r := retry.Execute(function: string
        begin
          Result := cb.Execute(function: string
            begin
              Result := CallExternalApi('/api/composed');
            end);
        end);
      WriteLn('  Composed result: ' + r);
    except
      on E: ERetryExhaustedException do
        WriteLn('  ❌ All retries exhausted: ' + E.Message.Substring(0, 80));
      on E: Exception do
        WriteLn('  ❌ ' + E.ClassName + ': ' + E.Message);
    end;
  finally
    retry.Free;
    cb.Free;
  end;
end;

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────
begin
  try
    WriteLn('QuickCore — Resilience Policies sample (Polly equivalent)');
    WriteLn('══════════════════════════════════════════════════════════');

    DemoRetryConstant;
    DemoRetryExponential;
    DemoCircuitBreaker;
    DemoTimeout;
    DemoComposed;

    WriteLn;
    WriteLn('Sample completed successfully.');
  except
    on E: Exception do
    begin
      WriteLn('FATAL: ' + E.Message);
      ExitCode := 1;
    end;
  end;

  {$IFDEF DEBUG}
  WriteLn;
  Write('Press Enter to exit...');
  ReadLn;
  {$ENDIF}
end.
