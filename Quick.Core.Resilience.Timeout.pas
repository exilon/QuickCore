{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Resilience.Timeout
  Description : Timeout policy (R-03) — cancels operations that exceed deadline
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

unit Quick.Core.Resilience.Timeout;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.SyncObjs,
  System.Threading,
  System.Rtti,
  Quick.Core.Resilience.Abstractions;

type
  TTimeoutEvent = reference to procedure(aTimeoutMs: Int64);

  /// <summary>
  /// Timeout policy. Runs aFunc in a background thread and waits up to
  /// TimeoutMs milliseconds. If the operation does not complete in time,
  /// raises ETimeoutException.
  ///
  /// Equivalent to: Polly.Timeout / ResiliencePipeline with TimeoutStrategyOptions
  ///
  /// IMPORTANT: The background thread continues to run after the timeout
  /// is raised (Delphi has no cooperative cancellation). Design your
  /// functions to be short-lived or implement cancellation via a shared flag.
  ///
  /// Usage:
  ///   tp := TTimeoutPolicy&lt;string&gt;.Create(5000);  // 5 second timeout
  ///   result := tp.Execute(function: string
  ///     begin
  ///       Result := httpClient.Get(url);
  ///     end);
  ///
  ///   // With notification callback:
  ///   tp := TTimeoutPolicy&lt;string&gt;.Create(5000,
  ///     procedure(ms: Int64)
  ///     begin logger.Warn('Operation timed out after %dms', [ms]) end);
  /// </summary>
  TTimeoutPolicy<T> = class(TInterfacedObject, IResiliencePolicy<T>)
  private
    fTimeoutMs  : Int64;
    fOnTimeout  : TTimeoutEvent;
  public
    /// <summary>
    /// aTimeoutMs : maximum milliseconds to wait for aFunc (must be > 0)
    /// aOnTimeout : optional callback fired when a timeout occurs
    /// </summary>
    constructor Create(aTimeoutMs: Int64; aOnTimeout: TTimeoutEvent = nil);

    /// <summary>Executes aFunc in a background TTask. If it does not complete
    /// within TimeoutMs, raises ETimeoutException. If it raises an exception,
    /// that exception is re-raised on the calling thread.</summary>
    function Execute(aFunc: TResilienceFunc<T>): T;

    property TimeoutMs : Int64 read fTimeoutMs;
  end;

implementation

{ TTimeoutPolicy<T> }

constructor TTimeoutPolicy<T>.Create(aTimeoutMs: Int64; aOnTimeout: TTimeoutEvent);
begin
  inherited Create;
  if aTimeoutMs <= 0 then
    raise EResilienceError.Create('TimeoutPolicy: TimeoutMs must be > 0');
  fTimeoutMs := aTimeoutMs;
  fOnTimeout := aOnTimeout;
end;

function TTimeoutPolicy<T>.Execute(aFunc: TResilienceFunc<T>): T;
var
  // Shared state between the calling thread and the worker TTask
  // Using a record wrapper that we can capture by reference in both closures.
  resultHolder : T;
  hasResult    : Boolean;
  hasError     : Boolean;
  errorMsg     : string;
  errorClass   : string;
  doneSemaphore: TSemaphore;
  task         : ITask;
begin
  hasResult    := False;
  hasError     := False;
  errorMsg     := '';
  errorClass   := '';
  resultHolder := Default(T);
  doneSemaphore := TSemaphore.Create(nil, 0, 1, '');
  try
    task := TTask.Create(procedure
    begin
      try
        resultHolder := aFunc();
        hasResult    := True;
      except
        on E: Exception do
        begin
          hasError   := True;
          errorClass := E.ClassName;
          errorMsg   := E.Message;
        end;
      end;
      doneSemaphore.Release;
    end);

    task.Start;

    // Wait up to TimeoutMs
    if doneSemaphore.WaitFor(fTimeoutMs) = wrTimeout then
    begin
      // Task is still running — we cannot cancel it, but we surface the timeout
      if Assigned(fOnTimeout) then
        fOnTimeout(fTimeoutMs);
      raise ETimeoutException.CreateFmt(
        'TimeoutPolicy: operation did not complete within %dms.', [fTimeoutMs]);
    end;

    if hasError then
      raise EResilienceError.CreateFmt('[%s] %s', [errorClass, errorMsg]);

    Result := resultHolder;
  finally
    doneSemaphore.Free;
  end;
end;

end.
