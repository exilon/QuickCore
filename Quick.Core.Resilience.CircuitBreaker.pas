{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Resilience.CircuitBreaker
  Description : Circuit Breaker policy (R-01) — Closed/Open/Half-Open state machine
  Author      : Kike Perez
  Version     : 1.0
  Created     : 29/04/2026
  Modified    : 08/05/2026

  This file is part of QuickCore: https://github.com/exilon/QuickCore

 ***************************************************************************

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

 *************************************************************************** }

unit Quick.Core.Resilience.CircuitBreaker;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.SyncObjs,
  Quick.Core.Resilience.Abstractions;

type
  /// <summary>
  /// Current state of the circuit breaker.
  /// - cbClosed   : normal operation — calls are allowed through
  /// - cbOpen     : circuit is broken — calls fail fast with ECircuitOpenException
  /// - cbHalfOpen : probe state — one call allowed through to test recovery
  /// </summary>
  TCircuitState = (cbClosed, cbOpen, cbHalfOpen);

  TCircuitStateChangeEvent = reference to procedure(aOldState, aNewState: TCircuitState);

  /// <summary>
  /// Circuit Breaker policy. Monitors failures and opens the circuit when the
  /// failure count reaches the threshold, blocking calls for a configurable
  /// duration before trying again.
  ///
  /// Equivalent to: Polly.CircuitBreaker / ResiliencePipeline with CircuitBreakerStrategyOptions
  ///
  /// States:
  ///   Closed   → (failures >= FailureThreshold)    → Open
  ///   Open     → (DurationOfBreakMs elapsed)        → HalfOpen
  ///   HalfOpen → (probe call succeeds)             → Closed
  ///   HalfOpen → (probe call fails)                → Open (reset timer)
  ///
  /// Usage:
  ///   cb := TCircuitBreakerPolicy&lt;string&gt;.Create(
  ///     {FailureThreshold} 3,
  ///     {DurationOfBreakMs} 5000);
  ///   result := cb.Execute(function: string begin Result := httpGet(url) end);
  ///
  /// Thread-safe: all state transitions are protected by a TCriticalSection.
  /// </summary>
  TCircuitBreakerPolicy<T> = class(TInterfacedObject, IResiliencePolicy<T>)
  private
    fLock              : TCriticalSection;
    fState             : TCircuitState;
    fFailureCount      : Integer;
    fFailureThreshold  : Integer;
    fDurationOfBreakMs : Int64;
    fOpenedAt          : TDateTime;
    fOnStateChange     : TCircuitStateChangeEvent;
    procedure TransitionTo(aNewState: TCircuitState);
    procedure RecordSuccess;
    procedure RecordFailure;
    function IsHalfOpenProbeAllowed: Boolean;
    function MsSince(aDateTime: TDateTime): Int64;
  public
    /// <summary>
    /// Creates a circuit breaker.
    /// aFailureThreshold  : consecutive failures before opening the circuit.
    /// aDurationOfBreakMs : milliseconds the circuit stays Open before trying
    ///                      a probe call (transitioning to HalfOpen).
    /// aOnStateChange     : optional callback fired on every state transition.
    /// </summary>
    constructor Create(aFailureThreshold: Integer; aDurationOfBreakMs: Int64;
      aOnStateChange: TCircuitStateChangeEvent = nil);
    destructor Destroy; override;

    /// <summary>Executes aFunc through the circuit breaker.
    /// - If Closed: runs aFunc; on exception increments failure count.
    /// - If Open and break duration not elapsed: raises ECircuitOpenException immediately.
    /// - If HalfOpen: runs aFunc as a probe; success→Closed, failure→Open.
    /// </summary>
    function Execute(aFunc: TResilienceFunc<T>): T;

    property State            : TCircuitState read fState;
    property FailureCount     : Integer       read fFailureCount;
    property FailureThreshold : Integer       read fFailureThreshold;
    property DurationOfBreakMs: Int64         read fDurationOfBreakMs;
  end;

implementation

uses
  System.DateUtils;

{ TCircuitBreakerPolicy<T> }

constructor TCircuitBreakerPolicy<T>.Create(aFailureThreshold: Integer;
  aDurationOfBreakMs: Int64; aOnStateChange: TCircuitStateChangeEvent);
begin
  inherited Create;
  if aFailureThreshold < 1 then
    raise EResilienceError.Create('CircuitBreaker: FailureThreshold must be >= 1');
  if aDurationOfBreakMs < 0 then
    raise EResilienceError.Create('CircuitBreaker: DurationOfBreakMs must be >= 0');

  fLock              := TCriticalSection.Create;
  fState             := cbClosed;
  fFailureCount      := 0;
  fFailureThreshold  := aFailureThreshold;
  fDurationOfBreakMs := aDurationOfBreakMs;
  fOnStateChange     := aOnStateChange;
end;

destructor TCircuitBreakerPolicy<T>.Destroy;
begin
  fLock.Free;
  inherited;
end;

function TCircuitBreakerPolicy<T>.MsSince(aDateTime: TDateTime): Int64;
begin
  Result := MilliSecondsBetween(Now, aDateTime);
end;

procedure TCircuitBreakerPolicy<T>.TransitionTo(aNewState: TCircuitState);
var
  old: TCircuitState;
begin
  // Caller must hold fLock
  old    := fState;
  fState := aNewState;
  if aNewState = cbOpen then
    fOpenedAt := Now;
  if Assigned(fOnStateChange) and (old <> aNewState) then
  begin
    fLock.Leave;
    try
      fOnStateChange(old, aNewState);
    finally
      fLock.Enter;
    end;
  end;
end;

procedure TCircuitBreakerPolicy<T>.RecordSuccess;
begin
  // Caller must hold fLock
  fFailureCount := 0;
  if fState = cbHalfOpen then
    TransitionTo(cbClosed);
end;

procedure TCircuitBreakerPolicy<T>.RecordFailure;
begin
  // Caller must hold fLock
  Inc(fFailureCount);
  if (fState = cbHalfOpen) or (fFailureCount >= fFailureThreshold) then
  begin
    fFailureCount := fFailureThreshold; // cap
    TransitionTo(cbOpen);
  end;
end;

function TCircuitBreakerPolicy<T>.IsHalfOpenProbeAllowed: Boolean;
begin
  // Caller must hold fLock; state is Open
  if MsSince(fOpenedAt) >= fDurationOfBreakMs then
  begin
    TransitionTo(cbHalfOpen);
    Result := True;
  end
  else
    Result := False;
end;

function TCircuitBreakerPolicy<T>.Execute(aFunc: TResilienceFunc<T>): T;
var
  currentState : TCircuitState;
  allowProbe   : Boolean;
begin
  fLock.Enter;
  try
    currentState := fState;
    allowProbe   := False;
    if currentState = cbOpen then
    begin
      allowProbe := IsHalfOpenProbeAllowed;
      if not allowProbe then
        raise ECircuitOpenException.CreateFmt(
          'CircuitBreaker: circuit is OPEN. Retry in %dms.',
          [fDurationOfBreakMs - MsSince(fOpenedAt)]);
    end;
  finally
    fLock.Leave;
  end;

  // Execute outside lock to avoid deadlock with callbacks
  try
    Result := aFunc();
    fLock.Enter;
    try
      RecordSuccess;
    finally
      fLock.Leave;
    end;
  except
    on E: Exception do
    begin
      fLock.Enter;
      try
        RecordFailure;
      finally
        fLock.Leave;
      end;
      raise;
    end;
  end;
end;

end.
