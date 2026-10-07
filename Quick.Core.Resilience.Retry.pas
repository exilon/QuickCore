{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Resilience.Retry
  Description : Retry policy (R-02) — constant / exponential / jitter backoff
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

unit Quick.Core.Resilience.Retry;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Core.Resilience.Abstractions;

type
  /// <summary>
  /// Callback fired before each retry attempt.
  /// aAttempt    : 1-based attempt number that just failed (so retry n°1 fires after the first failure)
  /// aDelayMs    : milliseconds the policy will wait before next attempt
  /// aException  : the exception that triggered the retry
  /// </summary>
  TRetryEvent = reference to procedure(aAttempt: Integer; aDelayMs: Int64;
    aException: Exception);

  /// <summary>Predicate that decides whether a given exception should trigger a retry.</summary>
  TShouldRetryFunc = reference to function(E: Exception): Boolean;

  /// <summary>
  /// Retry policy with configurable backoff. Retries the operation up to
  /// MaxRetries times on any exception (or a filtered subset via ShouldRetry).
  ///
  /// Equivalent to: Polly.Retry / ResiliencePipeline with RetryStrategyOptions
  ///
  /// Backoff strategies (TBackoffType):
  ///   btConstant    : sleep InitialDelayMs between every attempt
  ///   btExponential : sleep InitialDelayMs * 2^(attempt-1), capped at MaxDelayMs
  ///   btDecorrelated: AWS jitter — random in [InitialDelayMs, prev*3],
  ///                   naturally spreads thundering herd in distributed systems
  ///
  /// Usage:
  ///   retry := TRetryPolicy&lt;string&gt;.Create(3, 200, btExponential);
  ///   result := retry.Execute(function: string begin Result := httpGet(url) end);
  ///
  ///   // With OnRetry logging:
  ///   retry := TRetryPolicy&lt;string&gt;.Create(3, 200, btExponential,
  ///     procedure(attempt, delayMs: Integer; e: Exception)
  ///     begin logger.Warn('Retry %d after %dms: %s', [attempt, delayMs, e.Message]) end);
  ///
  /// Note: if all retries are exhausted the last exception is re-raised.
  /// Wrap in a circuit breaker to stop retrying when a service is persistently down.
  /// </summary>
  TRetryPolicy<T> = class(TInterfacedObject, IResiliencePolicy<T>)
  private
    fMaxRetries     : Integer;
    fInitialDelayMs : Int64;
    fMaxDelayMs     : Int64;
    fBackoffType    : TBackoffType;
    fOnRetry        : TRetryEvent;
    fShouldRetry    : TShouldRetryFunc;
    function ComputeDelayMs(aAttempt: Integer; aPrevDelayMs: Int64): Int64;
    procedure Sleep(aMs: Int64);
  public
    /// <summary>
    /// aMaxRetries     : total extra attempts after the first failure (0 = no retry, just execute once)
    /// aInitialDelayMs : base delay in milliseconds
    /// aBackoffType    : delay strategy (default: btConstant)
    /// aMaxDelayMs     : cap for exponential backoff (default: 30000 = 30s)
    /// aOnRetry        : optional callback before each retry sleep
    /// aShouldRetry    : optional predicate — return True to retry, False to propagate immediately
    /// </summary>
    constructor Create(aMaxRetries: Integer; aInitialDelayMs: Int64;
      aBackoffType: TBackoffType = btConstant;
      aMaxDelayMs: Int64 = 30000;
      aOnRetry: TRetryEvent = nil;
      aShouldRetry: TShouldRetryFunc = nil);

    /// <summary>Execute aFunc with retry. If all attempts fail,
    /// raises ERetryExhaustedException wrapping the last exception's message.</summary>
    function Execute(aFunc: TResilienceFunc<T>): T;

    property MaxRetries     : Integer read fMaxRetries;
    property InitialDelayMs : Int64   read fInitialDelayMs;
    property BackoffType    : TBackoffType read fBackoffType;
    property MaxDelayMs     : Int64   read fMaxDelayMs;
  end;

implementation

uses
  System.Classes,
  System.Math,
  System.Threading;

{ TRetryPolicy<T> }

constructor TRetryPolicy<T>.Create(aMaxRetries: Integer; aInitialDelayMs: Int64;
  aBackoffType: TBackoffType; aMaxDelayMs: Int64; aOnRetry: TRetryEvent;
  aShouldRetry: TShouldRetryFunc);
begin
  inherited Create;
  if aMaxRetries < 0 then
    raise EResilienceError.Create('RetryPolicy: MaxRetries must be >= 0');
  if aInitialDelayMs < 0 then
    raise EResilienceError.Create('RetryPolicy: InitialDelayMs must be >= 0');

  fMaxRetries     := aMaxRetries;
  fInitialDelayMs := aInitialDelayMs;
  fBackoffType    := aBackoffType;
  fMaxDelayMs     := aMaxDelayMs;
  fOnRetry        := aOnRetry;
  fShouldRetry    := aShouldRetry;
end;

function TRetryPolicy<T>.ComputeDelayMs(aAttempt: Integer; aPrevDelayMs: Int64): Int64;
var
  cap : Int64;
begin
  case fBackoffType of
    btConstant:
      Result := fInitialDelayMs;

    btExponential:
    begin
      // 2^(attempt-1) growth, capped at MaxDelayMs
      Result := Round(fInitialDelayMs * Power(2, aAttempt - 1));
      if Result > fMaxDelayMs then Result := fMaxDelayMs;
    end;

    btDecorrelated:
    begin
      // AWS full jitter: random in [InitialDelayMs, min(MaxDelayMs, prev*3)]
      cap := Min(fMaxDelayMs, aPrevDelayMs * 3);
      if cap < fInitialDelayMs then cap := fInitialDelayMs;
      Result := fInitialDelayMs + Random(cap - fInitialDelayMs + 1);
    end;

  else
    Result := fInitialDelayMs;
  end;
end;

procedure TRetryPolicy<T>.Sleep(aMs: Int64);
begin
  if aMs > 0 then
    TThread.Sleep(aMs);
end;

function TRetryPolicy<T>.Execute(aFunc: TResilienceFunc<T>): T;
var
  attempt    : Integer;
  prevDelay  : Int64;
  delayMs    : Int64;
  lastError  : string;
begin
  prevDelay := fInitialDelayMs;
  lastError := '';

  for attempt := 0 to fMaxRetries do
  begin
    try
      Result := aFunc();
      Exit; // success
    except
      on E: Exception do
      begin
        lastError := E.ClassName + ': ' + E.Message;

        // Check if we should retry this exception type
        if Assigned(fShouldRetry) and not fShouldRetry(E) then
          raise;

        // Last attempt — re-raise as exhausted
        if attempt = fMaxRetries then
          raise ERetryExhaustedException.CreateFmt(
            'RetryPolicy: all %d attempt(s) failed. Last error — %s',
            [fMaxRetries + 1, lastError]);

        // Compute delay and notify
        delayMs   := ComputeDelayMs(attempt + 1, prevDelay);
        prevDelay := delayMs;

        if Assigned(fOnRetry) then
          fOnRetry(attempt + 1, delayMs, E);

        Sleep(delayMs);
      end;
    end;
  end;

  // Unreachable — loop always exits via Exit or raise
  raise ERetryExhaustedException.CreateFmt(
    'RetryPolicy: all attempts failed. Last error — %s', [lastError]);
end;

end.
