{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Resilience.Abstractions
  Description : Resilience shared types, exceptions and interfaces
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

unit Quick.Core.Resilience.Abstractions;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.SyncObjs;

type
  // ── Exceptions ─────────────────────────────────────────────────────────────

  /// <summary>Base for all resilience-related exceptions.</summary>
  EResilienceError = class(Exception);

  /// <summary>Raised by TCircuitBreakerPolicy when the circuit is Open.
  /// Equivalent to BrokenCircuitException in Polly.</summary>
  ECircuitOpenException = class(EResilienceError);

  /// <summary>Raised by TTimeoutPolicy when the operation exceeds the configured
  /// timeout. Equivalent to TimeoutRejectedException in Polly.</summary>
  ETimeoutException = class(EResilienceError);

  /// <summary>Raised by TRetryPolicy when all retry attempts are exhausted.
  /// The message contains the last exception information.</summary>
  ERetryExhaustedException = class(EResilienceError);

  // ── Backoff strategy ───────────────────────────────────────────────────────

  /// <summary>Delay strategy used between retry attempts.
  /// - btConstant    : always wait InitialDelayMs
  /// - btExponential : wait InitialDelayMs * 2^(attempt-1), capped at MaxDelayMs
  /// - btDecorrelated: jitter between [InitialDelayMs, previousDelay * 3]
  ///                   (recommended for distributed systems — AWS jitter pattern)</summary>
  TBackoffType = (btConstant, btExponential, btDecorrelated);

  // ── Core policy types ──────────────────────────────────────────────────────

  /// <summary>Anonymous function delegate for resilience policy execution.</summary>
  TResilienceFunc<T> = reference to function: T;

  /// <summary>
  /// Core interface implemented by all resilience policies.
  /// Equivalent to ResiliencePipeline&lt;T&gt;.Execute in Polly v8.
  ///
  /// Usage:
  ///   policy.Execute(function: string begin Result := httpClient.Get(url) end);
  /// </summary>
  IResiliencePolicy<T> = interface
  ['{F1A2B3C4-D5E6-7890-ABCD-EF1234567890}']
    function Execute(aFunc: TResilienceFunc<T>): T;
  end;

  // ── Internal shared state for TTimeoutPolicy ───────────────────────────────

  /// <summary>Ref-counted shared state between TTimeoutPolicy&lt;T&gt; and its
  /// worker thread. TInterfacedObject ensures the state stays alive until
  /// both the main thread and worker thread have released their references.</summary>
  TTimeoutSharedState = class(TInterfacedObject)
  public
    ResultValueSet : Boolean;
    HasError       : Boolean;
    ErrorMessage   : string;
    Event          : TEvent;
    constructor Create;
    destructor Destroy; override;
  end;

implementation

{ TTimeoutSharedState }

constructor TTimeoutSharedState.Create;
begin
  inherited Create;
  Event := TEvent.Create(nil, False, False, '');
end;

destructor TTimeoutSharedState.Destroy;
begin
  Event.Free;
  inherited;
end;

end.
