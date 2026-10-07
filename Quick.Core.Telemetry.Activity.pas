{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Telemetry.Activity
  Description : TActivity / TActivitySource — RAII wrappers over ISpan
  Author      : Kike Perez
  Version     : 1.0
  Created     : 30/04/2026
  Modified    : 08/05/2026

  This file is part of QuickCore: https://github.com/exilon/QuickCore

  Equivalent .NET: System.Diagnostics.Activity / ActivitySource

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

unit Quick.Core.Telemetry.Activity;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Core.Telemetry.Abstractions,
  Quick.Core.Telemetry;

type

  // ─── TActivity ───────────────────────────────────────────────────────────────

  /// <summary>
  /// RAII wrapper over ISpan. Automatically calls Finish in the destructor if
  /// the activity has not been stopped explicitly.
  ///
  /// Typical usage (try/finally — guaranteed cleanup):
  ///
  ///   activity := activitySource.StartActivity('HTTP GET /api/users', skServer);
  ///   try
  ///     activity.AddTag('http.method', 'GET').AddTag('http.url', '/api/users');
  ///     // ... do work ...
  ///     activity.SetStatus(ssOk);
  ///   except
  ///     on E: Exception do
  ///     begin
  ///       activity.SetStatus(ssError, E.Message);
  ///       raise;
  ///     end;
  ///   end;
  ///   activity.Free;  // calls Stop → Finish on the underlying ISpan
  ///
  /// .NET equivalent: System.Diagnostics.Activity
  ///   (ActivitySource.StartActivity returns an Activity; dispose it to stop)
  /// </summary>
  TActivity = class
  private
    fSpan       : ISpan;
    fStopped    : Boolean;
    function GetTraceId: string;
    function GetSpanId: string;
    function GetParentSpanId: string;
    function GetOperationName: string;
    function GetTraceparent: string;
    function GetIsRunning: Boolean;
  public
    constructor Create(const aSpan : ISpan);
    destructor Destroy; override;

    /// <summary>Add or update a tag on the underlying span. Returns Self for chaining.</summary>
    function AddTag(const aKey, aValue : string) : TActivity;
    /// <summary>Record a named event (timestamped). Returns Self for chaining.</summary>
    function AddEvent(const aName : string) : TActivity;
    /// <summary>Set the span outcome. Returns Self for chaining.</summary>
    function SetStatus(aStatus : TSpanStatus; const aDescription : string = '') : TActivity;
    /// <summary>Finish the underlying span and mark this activity as stopped.</summary>
    procedure Stop;

    // ── Properties ─────────────────────────────────────────────────────────────
    property Span          : ISpan    read fSpan;
    property TraceId       : string   read GetTraceId;
    property SpanId        : string   read GetSpanId;
    property ParentSpanId  : string   read GetParentSpanId;
    property OperationName : string   read GetOperationName;
    property Traceparent   : string   read GetTraceparent;
    property IsRunning     : Boolean  read GetIsRunning;
  end;

  // ─── TActivitySource ─────────────────────────────────────────────────────────

  /// <summary>
  /// Creates TActivity instances. Analogous to ActivitySource in .NET:
  /// each library / component creates its own ActivitySource with its name
  /// and version, then uses it to create activities.
  ///
  /// .NET equivalent: System.Diagnostics.ActivitySource
  ///
  /// Usage:
  ///   // Module level — create once per library
  ///   GDbSource := TActivitySource.Create('MyApp.Database', '1.0', tracer);
  ///
  ///   // Per operation
  ///   act := GDbSource.StartActivity('SELECT users');
  ///   try
  ///     act.AddTag('db.system', 'mssql').AddTag('db.statement', sql);
  ///     // ... run query ...
  ///     act.SetStatus(ssOk);
  ///   finally
  ///     act.Free;
  ///   end;
  /// </summary>
  TActivitySource = class
  private
    fName    : string;
    fVersion : string;
    fTracer  : ITracer;
  public
    /// <param name="aTracer">
    ///   ITracer to create spans with. May be nil — StartActivity returns a
    ///   no-op TActivity backed by TNoOpSpan so callers never have to nil-check.
    /// </param>
    constructor Create(const aName : string; const aVersion : string;
      const aTracer : ITracer);

    /// <summary>Start a new root activity.</summary>
    function StartActivity(const aName : string;
      aKind : TSpanKind = skInternal) : TActivity; overload;

    /// <summary>Start a child activity of the given parent span.</summary>
    function StartActivity(const aName : string;
      const aParent : ISpan;
      aKind : TSpanKind = skInternal) : TActivity; overload;

    /// <summary>Start an activity continuing a remote trace (from traceparent header).</summary>
    function StartActivityFromTraceparent(const aName, aTraceparent : string;
      aKind : TSpanKind = skServer) : TActivity;

    property Name    : string  read fName;
    property Version : string  read fVersion;
  end;

implementation

// ─── TActivity ────────────────────────────────────────────────────────────────

constructor TActivity.Create(const aSpan : ISpan);
begin
  inherited Create;
  if aSpan = nil then
    raise EArgumentNilException.Create('TActivity: aSpan must not be nil');
  fSpan    := aSpan;
  fStopped := False;
end;

destructor TActivity.Destroy;
begin
  Stop;
  inherited;
end;

function TActivity.AddTag(const aKey, aValue : string) : TActivity;
begin
  fSpan.SetTag(aKey, aValue);
  Result := Self;
end;

function TActivity.AddEvent(const aName : string) : TActivity;
begin
  fSpan.AddEvent(aName);
  Result := Self;
end;

function TActivity.SetStatus(aStatus : TSpanStatus;
  const aDescription : string = '') : TActivity;
begin
  fSpan.SetStatus(aStatus, aDescription);
  Result := Self;
end;

function TActivity.GetTraceId: string;
begin
  Result := fSpan.TraceId;
end;

function TActivity.GetSpanId: string;
begin
  Result := fSpan.SpanId;
end;

function TActivity.GetParentSpanId: string;
begin
  Result := fSpan.ParentSpanId;
end;

function TActivity.GetOperationName: string;
begin
  Result := fSpan.OperationName;
end;

function TActivity.GetTraceparent: string;
begin
  Result := fSpan.Traceparent;
end;

function TActivity.GetIsRunning: Boolean;
begin
  Result := not fStopped;
end;

procedure TActivity.Stop;
begin
  if not fStopped then
  begin
    fStopped := True;
    if not fSpan.IsFinished then
      fSpan.Finish;
  end;
end;

// ─── TActivitySource ─────────────────────────────────────────────────────────

constructor TActivitySource.Create(const aName, aVersion : string;
  const aTracer : ITracer);
begin
  inherited Create;
  fName    := aName;
  fVersion := aVersion;
  fTracer  := aTracer;
end;

function TActivitySource.StartActivity(const aName : string;
  aKind : TSpanKind = skInternal) : TActivity;
var
  span : ISpan;
begin
  if fTracer <> nil then
    span := fTracer.StartSpan(aName, aKind)
  else
    span := TNoOpSpan.Create;
  Result := TActivity.Create(span);
end;

function TActivitySource.StartActivity(const aName : string;
  const aParent : ISpan; aKind : TSpanKind = skInternal) : TActivity;
var
  span : ISpan;
begin
  if fTracer <> nil then
    span := fTracer.StartSpan(aName, aParent, aKind)
  else
    span := TNoOpSpan.Create;
  Result := TActivity.Create(span);
end;

function TActivitySource.StartActivityFromTraceparent(const aName,
  aTraceparent : string; aKind : TSpanKind = skServer) : TActivity;
var
  span : ISpan;
begin
  if fTracer <> nil then
    span := fTracer.StartSpanFromTraceparent(aName, aTraceparent, aKind)
  else
    span := TNoOpSpan.Create;
  Result := TActivity.Create(span);
end;

end.
