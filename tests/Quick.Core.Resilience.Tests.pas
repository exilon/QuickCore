unit Quick.Core.Resilience.Tests;

{ Tests: T-RES-01..14
  Circuit Breaker:
    T-RES-01  Execute succeeds when circuit is Closed
    T-RES-02  Circuit opens after FailureThreshold consecutive failures
    T-RES-03  ECircuitOpenException raised while circuit is Open
    T-RES-04  Circuit transitions to HalfOpen after break duration elapses
    T-RES-05  Successful probe in HalfOpen closes the circuit
    T-RES-06  Failed probe in HalfOpen re-opens the circuit
    T-RES-07  OnStateChange callback fires on each transition
  Retry:
    T-RES-08  Execute succeeds on first attempt — no retries
    T-RES-09  Retries up to MaxRetries and succeeds on last attempt
    T-RES-10  ERetryExhaustedException raised after all attempts fail
    T-RES-11  OnRetry callback fires with correct attempt numbers
    T-RES-12  ShouldRetry predicate can prevent retry for specific exceptions
    T-RES-13  Exponential backoff delay grows with each attempt
  Timeout:
    T-RES-14  Fast function completes within timeout (no exception)
    T-RES-15  Slow function raises ETimeoutException when deadline exceeded
}

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SysUtils,
  System.Threading,
  Quick.Core.Resilience.Abstractions,
  Quick.Core.Resilience.CircuitBreaker,
  Quick.Core.Resilience.Retry,
  Quick.Core.Resilience.Timeout;

type
  ETestException = class(Exception);
  EAnotherException = class(Exception);

  [TestFixture]
  TResilienceTests = class
  public
    // ── Circuit Breaker ──────────────────────────────────────────────────────
    [Test]
    procedure T_RES_01_CB_Execute_Success_ReturnsValue;
    [Test]
    procedure T_RES_02_CB_OpensAfterThreshold;
    [Test]
    procedure T_RES_03_CB_OpenCircuit_RaisesCircuitOpenException;
    [Test]
    procedure T_RES_04_CB_TransitionsToHalfOpen_AfterBreakDuration;
    [Test]
    procedure T_RES_05_CB_HalfOpen_SuccessfulProbe_ClosesCircuit;
    [Test]
    procedure T_RES_06_CB_HalfOpen_FailedProbe_ReOpens;
    [Test]
    procedure T_RES_07_CB_OnStateChange_FiresOnTransitions;

    // ── Retry ────────────────────────────────────────────────────────────────
    [Test]
    procedure T_RES_08_Retry_SuccessOnFirstAttempt_NoRetries;
    [Test]
    procedure T_RES_09_Retry_SucceedsOnLastAttempt;
    [Test]
    procedure T_RES_10_Retry_Exhausted_RaisesException;
    [Test]
    procedure T_RES_11_Retry_OnRetry_CorrectAttemptNumbers;
    [Test]
    procedure T_RES_12_Retry_ShouldRetry_PreventRetryForSpecificException;
    [Test]
    procedure T_RES_13_Retry_ExponentialBackoff_DelayGrows;

    // ── Timeout ──────────────────────────────────────────────────────────────
    [Test]
    procedure T_RES_14_Timeout_FastFunc_ReturnsResult;
    [Test]
    procedure T_RES_15_Timeout_SlowFunc_RaisesTimeoutException;
  end;

implementation

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function MakeFailingCB(aThreshold: Integer; aBreakMs: Int64 = 60000)
  : TCircuitBreakerPolicy<Integer>;
begin
  Result := TCircuitBreakerPolicy<Integer>.Create(aThreshold, aBreakMs);
end;

// ─────────────────────────────────────────────────────────────────────────────
// Circuit Breaker tests
// ─────────────────────────────────────────────────────────────────────────────

procedure TResilienceTests.T_RES_01_CB_Execute_Success_ReturnsValue;
var
  cb: TCircuitBreakerPolicy<Integer>;
begin
  cb := MakeFailingCB(3);
  try
    var r := cb.Execute(function: Integer begin Result := 42 end);
    Assert.AreEqual(42, r);
    Assert.AreEqual(Ord(cbClosed), Ord(cb.State));
  finally
    cb.Free;
  end;
end;

procedure TResilienceTests.T_RES_02_CB_OpensAfterThreshold;
var
  cb: TCircuitBreakerPolicy<Integer>;
  i : Integer;
begin
  cb := MakeFailingCB(3);
  try
    for i := 1 to 3 do
    begin
      try
        cb.Execute(function: Integer begin raise ETestException.Create('fail') end);
      except
        on ETestException do ; // expected
      end;
    end;
    Assert.AreEqual(Ord(cbOpen), Ord(cb.State), 'Circuit should be Open after threshold');
  finally
    cb.Free;
  end;
end;

procedure TResilienceTests.T_RES_03_CB_OpenCircuit_RaisesCircuitOpenException;
var
  cb: TCircuitBreakerPolicy<Integer>;
  i : Integer;
begin
  cb := MakeFailingCB(2);
  try
    // Open the circuit
    for i := 1 to 2 do
      try cb.Execute(function: Integer begin raise ETestException.Create('x') end);
      except on ETestException do ; end;

    // Now it should fail fast
    Assert.WillRaise(
      procedure
      begin
        cb.Execute(function: Integer begin Result := 1 end);
      end,
      ECircuitOpenException);
  finally
    cb.Free;
  end;
end;

procedure TResilienceTests.T_RES_04_CB_TransitionsToHalfOpen_AfterBreakDuration;
var
  cb: TCircuitBreakerPolicy<Integer>;
  i : Integer;
begin
  // Short break duration so the test doesn't stall
  cb := TCircuitBreakerPolicy<Integer>.Create(2, 50 {ms});
  try
    for i := 1 to 2 do
      try cb.Execute(function: Integer begin raise ETestException.Create('x') end);
      except on ETestException do ; end;

    Assert.AreEqual(Ord(cbOpen), Ord(cb.State));

    // Wait for break duration
    TThread.Sleep(100);

    // First call should transition to HalfOpen and run the probe
    try
      cb.Execute(function: Integer begin Result := 0 end);
    except end;

    // After a successful probe the circuit closes; after failure it re-opens.
    // Here we just verify it is no longer Open (it's HalfOpen or Closed)
    Assert.AreNotEqual(Ord(cbOpen), Ord(cb.State),
      'Circuit should leave Open state after break duration');
  finally
    cb.Free;
  end;
end;

procedure TResilienceTests.T_RES_05_CB_HalfOpen_SuccessfulProbe_ClosesCircuit;
var
  cb: TCircuitBreakerPolicy<Integer>;
  i : Integer;
begin
  cb := TCircuitBreakerPolicy<Integer>.Create(2, 50);
  try
    for i := 1 to 2 do
      try cb.Execute(function: Integer begin raise ETestException.Create('x') end);
      except on ETestException do ; end;

    TThread.Sleep(100); // wait for Open→HalfOpen
    cb.Execute(function: Integer begin Result := 1 end); // successful probe
    Assert.AreEqual(Ord(cbClosed), Ord(cb.State), 'Successful probe should close circuit');
  finally
    cb.Free;
  end;
end;

procedure TResilienceTests.T_RES_06_CB_HalfOpen_FailedProbe_ReOpens;
var
  cb: TCircuitBreakerPolicy<Integer>;
  i : Integer;
begin
  cb := TCircuitBreakerPolicy<Integer>.Create(2, 50);
  try
    for i := 1 to 2 do
      try cb.Execute(function: Integer begin raise ETestException.Create('x') end);
      except on ETestException do ; end;

    TThread.Sleep(100);
    try cb.Execute(function: Integer begin raise ETestException.Create('probe fail') end);
    except on ETestException do ; end;

    Assert.AreEqual(Ord(cbOpen), Ord(cb.State), 'Failed probe should re-open circuit');
  finally
    cb.Free;
  end;
end;

procedure TResilienceTests.T_RES_07_CB_OnStateChange_FiresOnTransitions;
var
  cb        : TCircuitBreakerPolicy<Integer>;
  changes   : TArray<string>;
  i         : Integer;
begin
  changes := nil;
  cb := TCircuitBreakerPolicy<Integer>.Create(2, 50,
    procedure(aOld, aNew: TCircuitState)
    begin
      SetLength(changes, Length(changes) + 1);
      changes[High(changes)] := Format('%d→%d', [Ord(aOld), Ord(aNew)]);
    end);
  try
    // Trigger Open
    for i := 1 to 2 do
      try cb.Execute(function: Integer begin raise ETestException.Create('x') end);
      except on ETestException do ; end;

    // Wait and trigger HalfOpen, then close
    TThread.Sleep(100);
    cb.Execute(function: Integer begin Result := 1 end);

    Assert.IsTrue(Length(changes) >= 2, 'Should have at least 2 state transitions');
  finally
    cb.Free;
  end;
end;

// ─────────────────────────────────────────────────────────────────────────────
// Retry tests
// ─────────────────────────────────────────────────────────────────────────────

procedure TResilienceTests.T_RES_08_Retry_SuccessOnFirstAttempt_NoRetries;
var
  retry    : TRetryPolicy<Integer>;
  callCount: Integer;
begin
  retry     := TRetryPolicy<Integer>.Create(3, 0);
  callCount := 0;
  try
    var r := retry.Execute(function: Integer
      begin
        Inc(callCount);
        Result := 99;
      end);
    Assert.AreEqual(99, r);
    Assert.AreEqual(1, callCount, 'Should call func exactly once on success');
  finally
    retry.Free;
  end;
end;

procedure TResilienceTests.T_RES_09_Retry_SucceedsOnLastAttempt;
var
  retry    : TRetryPolicy<Integer>;
  callCount: Integer;
begin
  retry     := TRetryPolicy<Integer>.Create(3, 0); // 3 retries = 4 total attempts
  callCount := 0;
  try
    var r := retry.Execute(function: Integer
      begin
        Inc(callCount);
        if callCount < 4 then
          raise ETestException.Create('not yet');
        Result := 7;
      end);
    Assert.AreEqual(7, r);
    Assert.AreEqual(4, callCount);
  finally
    retry.Free;
  end;
end;

procedure TResilienceTests.T_RES_10_Retry_Exhausted_RaisesException;
var
  retry: TRetryPolicy<Integer>;
begin
  retry := TRetryPolicy<Integer>.Create(2, 0);
  try
    try
      retry.Execute(function: Integer begin raise ETestException.Create('always fail') end);
      Assert.Fail('Expected ERetryExhaustedException');
    except
      on ERetryExhaustedException do ; // expected
      on E: Exception do
        Assert.Fail('Expected ERetryExhaustedException but got: ' + E.ClassName);
    end;
  finally
    retry.Free;
  end;
end;

procedure TResilienceTests.T_RES_11_Retry_OnRetry_CorrectAttemptNumbers;
var
  retry      : TRetryPolicy<Integer>;
  attempts   : TArray<Integer>;
begin
  attempts := nil;
  retry    := TRetryPolicy<Integer>.Create(3, 0, btConstant, 30000,
    procedure(aAttempt: Integer; aDelayMs: Int64; E: Exception)
    begin
      SetLength(attempts, Length(attempts) + 1);
      attempts[High(attempts)] := aAttempt;
    end);
  try
    try
      retry.Execute(function: Integer begin raise ETestException.Create('x') end);
    except
      on ERetryExhaustedException do ; // expected
    end;
    Assert.AreEqual<Integer>(3, Length(attempts), 'OnRetry should fire 3 times for 3 retries');
    Assert.AreEqual<Integer>(1, attempts[0]);
    Assert.AreEqual<Integer>(2, attempts[1]);
    Assert.AreEqual<Integer>(3, attempts[2]);
  finally
    retry.Free;
  end;
end;

procedure TResilienceTests.T_RES_12_Retry_ShouldRetry_PreventRetryForSpecificException;
var
  retry    : TRetryPolicy<Integer>;
  callCount: Integer;
begin
  callCount := 0;
  retry := TRetryPolicy<Integer>.Create(5, 0, btConstant, 30000, nil,
    function(E: Exception): Boolean
    begin
      // Only retry ETestException, not EAnotherException
      Result := E is ETestException;
    end);
  try
    try
      retry.Execute(function: Integer
        begin
          Inc(callCount);
          raise EAnotherException.Create('do not retry this');
        end);
      Assert.Fail('Expected EAnotherException');
    except
      on EAnotherException do ; // expected — ShouldRetry=False prevents retries
      on E: Exception do
        Assert.Fail('Expected EAnotherException but got: ' + E.ClassName);
    end;
    // Should have called the func exactly once (no retry for EAnotherException)
    Assert.AreEqual(1, callCount, 'ShouldRetry=False must not retry');
  finally
    retry.Free;
  end;
end;

procedure TResilienceTests.T_RES_13_Retry_ExponentialBackoff_DelayGrows;
var
  retry  : TRetryPolicy<Integer>;
  delays : TArray<Int64>;
begin
  delays := nil;
  retry  := TRetryPolicy<Integer>.Create(3, 100, btExponential, 30000,
    procedure(aAttempt: Integer; aDelayMs: Int64; E: Exception)
    begin
      SetLength(delays, Length(delays) + 1);
      delays[High(delays)] := aDelayMs;
    end);
  try
    try
      retry.Execute(function: Integer begin raise ETestException.Create('x') end);
    except on ERetryExhaustedException do ; end;

    // Delays should grow: 100, 200, 400 (2^n growth)
    Assert.AreEqual<Integer>(3, Length(delays));
    Assert.IsTrue(delays[1] > delays[0], 'Exponential: second delay must be > first');
    Assert.IsTrue(delays[2] > delays[1], 'Exponential: third delay must be > second');
    Assert.AreEqual<Int64>(100, delays[0], 'First delay should be InitialDelayMs');
    Assert.AreEqual<Int64>(200, delays[1]);
    Assert.AreEqual<Int64>(400, delays[2]);
  finally
    retry.Free;
  end;
end;

// ─────────────────────────────────────────────────────────────────────────────
// Timeout tests
// ─────────────────────────────────────────────────────────────────────────────

procedure TResilienceTests.T_RES_14_Timeout_FastFunc_ReturnsResult;
var
  tp: TTimeoutPolicy<Integer>;
begin
  tp := TTimeoutPolicy<Integer>.Create(2000); // 2 second timeout
  try
    var r := tp.Execute(function: Integer begin Result := 123 end);
    Assert.AreEqual(123, r);
  finally
    tp.Free;
  end;
end;

procedure TResilienceTests.T_RES_15_Timeout_SlowFunc_RaisesTimeoutException;
var
  tp: TTimeoutPolicy<Integer>;
begin
  tp := TTimeoutPolicy<Integer>.Create(100); // 100ms timeout
  try
    try
      tp.Execute(function: Integer
        begin
          TThread.Sleep(500); // deliberately longer than timeout
          Result := 0;
        end);
      Assert.Fail('Expected ETimeoutException');
    except
      on ETimeoutException do ; // expected
      on E: Exception do
        Assert.Fail('Expected ETimeoutException but got: ' + E.ClassName);
    end;
  finally
    tp.Free;
    TThread.Sleep(600); // give background thread time to finish before test cleanup
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TResilienceTests);

end.
