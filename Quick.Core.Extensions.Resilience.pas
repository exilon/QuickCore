{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Extensions.Resilience
  Description : DI extensions for Resilience policies
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

unit Quick.Core.Extensions.Resilience;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Core.DependencyInjection,
  Quick.Core.Resilience.Abstractions,
  Quick.Core.Resilience.CircuitBreaker,
  Quick.Core.Resilience.Retry,
  Quick.Core.Resilience.Timeout;

type
  /// <summary>
  /// DI extension methods for Resilience policies.
  ///
  /// Usage in ConfigureServices (register named policies for injection):
  ///
  ///   services.Extension&lt;TResilienceServiceExtension&gt;
  ///     .AddCircuitBreaker&lt;string&gt;('http-cb', {threshold} 5, {breakMs} 10000)
  ///     .AddRetry&lt;string&gt;('http-retry', {maxRetries} 3, {delayMs} 500, btExponential)
  ///     .AddTimeout&lt;string&gt;('http-timeout', {timeoutMs} 5000);
  ///
  /// Then inject by name:
  ///   cb      := services.Resolve&lt;IResiliencePolicy&lt;string&gt;&gt;('http-cb');
  ///   retry   := services.Resolve&lt;IResiliencePolicy&lt;string&gt;&gt;('http-retry');
  ///   timeout := services.Resolve&lt;IResiliencePolicy&lt;string&gt;&gt;('http-timeout');
  ///
  /// NOTE: For most use cases, create policies directly (they are lightweight)
  /// rather than registering them in DI. DI registration is useful when you
  /// need to share a stateful policy (e.g., a circuit breaker) across multiple
  /// services that all talk to the same downstream dependency.
  /// </summary>
  TResilienceServiceExtension = class(TServiceCollectionExtension)
  public
    /// <summary>Register a named singleton CircuitBreaker&lt;T&gt; in DI.</summary>
    class function AddCircuitBreaker<T>(const aName: string;
      aFailureThreshold: Integer; aDurationOfBreakMs: Int64;
      aOnStateChange: TCircuitStateChangeEvent = nil): TServiceCollection;

    /// <summary>Register a named singleton RetryPolicy&lt;T&gt; in DI.</summary>
    class function AddRetry<T>(const aName: string;
      aMaxRetries: Integer; aInitialDelayMs: Int64;
      aBackoffType: TBackoffType = btConstant;
      aMaxDelayMs: Int64 = 30000;
      aOnRetry: TRetryEvent = nil): TServiceCollection;

    /// <summary>Register a named singleton TimeoutPolicy&lt;T&gt; in DI.</summary>
    class function AddTimeout<T>(const aName: string;
      aTimeoutMs: Int64;
      aOnTimeout: TTimeoutEvent = nil): TServiceCollection;
  end;

implementation

{ TResilienceServiceExtension }

class function TResilienceServiceExtension.AddCircuitBreaker<T>(
  const aName: string; aFailureThreshold: Integer; aDurationOfBreakMs: Int64;
  aOnStateChange: TCircuitStateChangeEvent): TServiceCollection;
var
  policy: IResiliencePolicy<T>;
begin
  policy := TCircuitBreakerPolicy<T>.Create(aFailureThreshold, aDurationOfBreakMs, aOnStateChange);
  ServiceCollection.AddSingleton<IResiliencePolicy<T>>(policy, aName);
  Result := ServiceCollection;
end;

class function TResilienceServiceExtension.AddRetry<T>(const aName: string;
  aMaxRetries: Integer; aInitialDelayMs: Int64; aBackoffType: TBackoffType;
  aMaxDelayMs: Int64; aOnRetry: TRetryEvent): TServiceCollection;
var
  policy: IResiliencePolicy<T>;
begin
  policy := TRetryPolicy<T>.Create(aMaxRetries, aInitialDelayMs, aBackoffType, aMaxDelayMs, aOnRetry);
  ServiceCollection.AddSingleton<IResiliencePolicy<T>>(policy, aName);
  Result := ServiceCollection;
end;

class function TResilienceServiceExtension.AddTimeout<T>(const aName: string;
  aTimeoutMs: Int64; aOnTimeout: TTimeoutEvent): TServiceCollection;
var
  policy: IResiliencePolicy<T>;
begin
  policy := TTimeoutPolicy<T>.Create(aTimeoutMs, aOnTimeout);
  ServiceCollection.AddSingleton<IResiliencePolicy<T>>(policy, aName);
  Result := ServiceCollection;
end;

end.
