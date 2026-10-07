{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Telemetry
  Description : OpenTelemetry Core implementation — TSpan, TTracer, TTracerProvider
  Author      : Kike Perez
  Version     : 1.0
  Created     : 30/04/2026
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

unit Quick.Core.Telemetry;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.SyncObjs,
  System.Hash,
  System.Generics.Collections,
  Quick.Core.Telemetry.Abstractions;

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// <summary>Generate a 32-hex-char trace ID (128-bit random).</summary>
function GenerateTraceId : string;
/// <summary>Generate a 16-hex-char span ID (64-bit random).</summary>
function GenerateSpanId : string;
/// <summary>Parse W3C traceparent "00-traceId-spanId-flags" → (traceId, spanId). Returns False on parse error.</summary>
function ParseTraceparent(const aTraceparent : string;
  out oTraceId, oParentSpanId : string) : Boolean;

type

  // ─── TSpan ──────────────────────────────────────────────────────────────────

  /// <summary>
  /// In-memory span. Thread-safe for SetTag / AddEvent / SetStatus / Finish.
  ///
  /// .NET equivalent: Activity (System.Diagnostics.Activity)
  /// </summary>
  TSpan = class(TInterfacedObject, ISpan)
  private
    fTraceId       : string;
    fSpanId        : string;
    fParentSpanId  : string;
    fOperationName : string;
    fKind          : TSpanKind;
    fStartTime     : TDateTime;
    fEndTime       : TDateTime;
    fIsFinished    : Boolean;
    fStatus        : TSpanStatus;
    fStatusMessage : string;
    fTags          : TSpanAttributes;
    fEvents        : TList<TSpanEvent>;
    fLock          : TCriticalSection;
    fExporter      : ISpanExporter;   // may be nil
  public
    constructor Create(const aOperationName, aTraceId, aParentSpanId : string;
      aKind : TSpanKind; const aExporter : ISpanExporter);
    destructor Destroy; override;
    function TraceId      : string;
    function SpanId       : string;
    function ParentSpanId : string;
    function OperationName: string;
    function Kind         : TSpanKind;
    function StartTime    : TDateTime;
    function EndTime      : TDateTime;
    function IsFinished   : Boolean;
    procedure SetTag(const aKey, aValue : string);
    function  Tags        : TSpanAttributes;
    procedure AddEvent(const aName : string); overload;
    procedure AddEvent(const aName : string; aAttributes : TSpanAttributes); overload;
    function  Events      : TArray<TSpanEvent>;
    procedure SetStatus(aStatus : TSpanStatus; const aDescription : string = '');
    function  Status      : TSpanStatus;
    function  StatusMessage : string;
    function  Traceparent : string;
    procedure Finish; overload;
    procedure Finish(aEndTime : TDateTime); overload;
  end;

  // ─── TTracer ────────────────────────────────────────────────────────────────

  /// <summary>
  /// Creates and manages spans for a named instrumentation scope.
  ///
  /// .NET equivalent: Tracer (OpenTelemetry.Api)
  ///
  /// Instantiate via TTracerProvider.GetTracer rather than directly.
  /// </summary>
  TTracer = class(TInterfacedObject, ITracer)
  private
    fServiceName : string;
    fExporter    : ISpanExporter;  // may be nil (e.g. composite or null)
  public
    constructor Create(const aServiceName : string; const aExporter : ISpanExporter);
    function StartSpan(const aOperationName : string;
      aKind : TSpanKind = skInternal) : ISpan; overload;
    function StartSpan(const aOperationName : string;
      const aParent : ISpan;
      aKind : TSpanKind = skInternal) : ISpan; overload;
    function StartSpanFromTraceparent(const aOperationName, aTraceparent : string;
      aKind : TSpanKind = skServer) : ISpan;
    procedure Inject(const aSpan : ISpan; aHeaders : TDictionary<string, string>);
    function Extract(aHeaders : TDictionary<string, string>) : string;
    function ServiceName : string;
  end;

  // ─── Composite exporter ──────────────────────────────────────────────────────

  /// <summary>
  /// Fans out Export calls to multiple exporters.
  /// Errors in one exporter do not prevent others from being called.
  /// </summary>
  TCompositeSpanExporter = class(TInterfacedObject, ISpanExporter)
  private
    fExporters : TList<ISpanExporter>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const aExporter : ISpanExporter);
    procedure Export(const aSpans : TArray<ISpan>);
    procedure Shutdown;
  end;

  // ─── TTracerProvider ────────────────────────────────────────────────────────

  /// <summary>
  /// Root factory for ITracer instances. Manages the composite exporter.
  ///
  /// .NET equivalent: TracerProvider (OpenTelemetry SDK)
  ///
  /// Usage:
  ///   provider := TTracerProvider.Create('my-service');
  ///   provider.AddExporter(TJaegerExporter.Create(opts));
  ///   tracer := provider.GetTracer('my-service');
  ///
  /// Static global instance:
  ///   TTracerProvider.SetGlobal(provider);
  ///   tracer := TTracerProvider.Global.GetTracer('scope');
  /// </summary>
  TTracerProvider = class(TInterfacedObject, ITracerProvider)
  private class var
    fGlobal : ITracerProvider;
  private
    fServiceName : string;
    fComposite   : TCompositeSpanExporter;
    fCompositeRef: ISpanExporter;
  public
    constructor Create(const aServiceName : string);
    destructor Destroy; override;
    function  GetTracer(const aName : string; const aVersion : string = '') : ITracer;
    procedure AddExporter(const aExporter : ISpanExporter);
    procedure Shutdown;
    class property Global : ITracerProvider read fGlobal;
    class procedure SetGlobal(const aProvider : ITracerProvider);
    class function  GetGlobal : ITracerProvider;
  end;

  // ─── Null exporter ───────────────────────────────────────────────────────────

  /// <summary>No-op exporter — discards all spans. Useful for testing.</summary>
  TNullSpanExporter = class(TInterfacedObject, ISpanExporter)
  public
    procedure Export(const aSpans : TArray<ISpan>);
    procedure Shutdown;
  end;

  // ─── In-memory exporter ──────────────────────────────────────────────────────

  /// <summary>
  /// Captures finished spans in memory. Primarily used for testing.
  ///
  /// Usage:
  ///   exporter := TInMemorySpanExporter.Create;
  ///   provider.AddExporter(exporter);
  ///   // ... run operations ...
  ///   Assert.AreEqual(1, exporter.SpanCount);
  /// </summary>
  TInMemorySpanExporter = class(TInterfacedObject, ISpanExporter)
  private
    fSpans : TList<ISpan>;
    fLock  : TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Export(const aSpans : TArray<ISpan>);
    procedure Shutdown;
    procedure Clear;
    function  SpanCount : Integer;
    function  GetSpans : TArray<ISpan>;
    function  GetSpanByName(const aName : string) : ISpan;
  end;

implementation

// ─── Helpers ─────────────────────────────────────────────────────────────────

function GenerateTraceId : string;
var
  buf : TBytes;
  i   : Integer;
begin
  SetLength(buf, 16);
  for i := 0 to 15 do
    buf[i] := Random(256);
  Result := '';
  for i := 0 to 15 do
    Result := Result + IntToHex(buf[i], 2).ToLower;
end;

function GenerateSpanId : string;
var
  buf : TBytes;
  i   : Integer;
begin
  SetLength(buf, 8);
  for i := 0 to 7 do
    buf[i] := Random(256);
  Result := '';
  for i := 0 to 7 do
    Result := Result + IntToHex(buf[i], 2).ToLower;
end;

function ParseTraceparent(const aTraceparent : string;
  out oTraceId, oParentSpanId : string) : Boolean;
var
  parts : TArray<string>;
begin
  Result       := False;
  oTraceId     := '';
  oParentSpanId := '';
  // Format: "00-{32hex}-{16hex}-{2hex}"
  parts := aTraceparent.Split(['-']);
  if Length(parts) < 4 then Exit;
  if parts[0] <> '00' then Exit;
  if Length(parts[1]) <> 32 then Exit;
  if Length(parts[2]) <> 16 then Exit;
  oTraceId      := parts[1];
  oParentSpanId := parts[2];
  Result        := True;
end;

// ─── TSpan ───────────────────────────────────────────────────────────────────

constructor TSpan.Create(const aOperationName, aTraceId, aParentSpanId : string;
  aKind : TSpanKind; const aExporter : ISpanExporter);
begin
  inherited Create;
  fOperationName := aOperationName;
  fTraceId       := aTraceId;
  fParentSpanId  := aParentSpanId;
  fSpanId        := GenerateSpanId;
  fKind          := aKind;
  fStartTime     := TTimeZone.Local.ToUniversalTime(Now);
  fEndTime       := 0;
  fIsFinished    := False;
  fStatus        := ssUnset;
  fStatusMessage := '';
  fTags          := TSpanAttributes.Create;
  fEvents        := TList<TSpanEvent>.Create;
  fLock          := TCriticalSection.Create;
  fExporter      := aExporter;
end;

destructor TSpan.Destroy;
begin
  fLock.Free;
  fEvents.Free;
  fTags.Free;
  inherited;
end;

function TSpan.TraceId       : string;    begin Result := fTraceId;        end;
function TSpan.SpanId        : string;    begin Result := fSpanId;         end;
function TSpan.ParentSpanId  : string;    begin Result := fParentSpanId;   end;
function TSpan.OperationName : string;    begin Result := fOperationName;  end;
function TSpan.Kind          : TSpanKind; begin Result := fKind;           end;
function TSpan.StartTime     : TDateTime; begin Result := fStartTime;      end;
function TSpan.StatusMessage : string;    begin Result := fStatusMessage;  end;

function TSpan.EndTime : TDateTime;
begin
  fLock.Enter;
  try
    Result := fEndTime;
  finally
    fLock.Leave;
  end;
end;

function TSpan.IsFinished : Boolean;
begin
  fLock.Enter;
  try
    Result := fIsFinished;
  finally
    fLock.Leave;
  end;
end;

procedure TSpan.SetTag(const aKey, aValue : string);
begin
  fLock.Enter;
  try
    fTags.AddOrSetValue(aKey, aValue);
  finally
    fLock.Leave;
  end;
end;

function TSpan.Tags : TSpanAttributes;
begin
  Result := fTags;  // caller should not modify concurrently with SetTag
end;

procedure TSpan.AddEvent(const aName : string);
var
  ev : TSpanEvent;
begin
  ev.Name       := aName;
  ev.Timestamp  := TTimeZone.Local.ToUniversalTime(Now);
  ev.Attributes := nil;
  fLock.Enter;
  try
    fEvents.Add(ev);
  finally
    fLock.Leave;
  end;
end;

procedure TSpan.AddEvent(const aName : string; aAttributes : TSpanAttributes);
var
  ev : TSpanEvent;
begin
  ev.Name       := aName;
  ev.Timestamp  := TTimeZone.Local.ToUniversalTime(Now);
  ev.Attributes := aAttributes;
  fLock.Enter;
  try
    fEvents.Add(ev);
  finally
    fLock.Leave;
  end;
end;

function TSpan.Events : TArray<TSpanEvent>;
begin
  fLock.Enter;
  try
    Result := fEvents.ToArray;
  finally
    fLock.Leave;
  end;
end;

procedure TSpan.SetStatus(aStatus : TSpanStatus; const aDescription : string = '');
begin
  fLock.Enter;
  try
    fStatus        := aStatus;
    fStatusMessage := aDescription;
  finally
    fLock.Leave;
  end;
end;

function TSpan.Status : TSpanStatus;
begin
  fLock.Enter;
  try
    Result := fStatus;
  finally
    fLock.Leave;
  end;
end;

function TSpan.Traceparent : string;
begin
  Result := Format('00-%s-%s-01', [fTraceId, fSpanId]);
end;

procedure TSpan.Finish;
begin
  Finish(TTimeZone.Local.ToUniversalTime(Now));
end;

procedure TSpan.Finish(aEndTime : TDateTime);
var
  exporter : ISpanExporter;
begin
  fLock.Enter;
  try
    if fIsFinished then Exit;
    fEndTime    := aEndTime;
    fIsFinished := True;
    exporter    := fExporter;
    fExporter   := nil;
  finally
    fLock.Leave;
  end;
  // Export outside the lock
  if exporter <> nil then
    exporter.Export([Self]);
end;

// ─── TTracer ─────────────────────────────────────────────────────────────────

constructor TTracer.Create(const aServiceName : string; const aExporter : ISpanExporter);
begin
  inherited Create;
  fServiceName := aServiceName;
  fExporter    := aExporter;
end;

function TTracer.ServiceName : string;
begin
  Result := fServiceName;
end;

function TTracer.StartSpan(const aOperationName : string;
  aKind : TSpanKind = skInternal) : ISpan;
begin
  Result := TSpan.Create(aOperationName, GenerateTraceId, '', aKind, fExporter);
end;

function TTracer.StartSpan(const aOperationName : string;
  const aParent : ISpan; aKind : TSpanKind = skInternal) : ISpan;
var
  traceId      : string;
  parentSpanId : string;
begin
  if aParent <> nil then
  begin
    traceId      := aParent.TraceId;
    parentSpanId := aParent.SpanId;
  end
  else
  begin
    traceId      := GenerateTraceId;
    parentSpanId := '';
  end;
  Result := TSpan.Create(aOperationName, traceId, parentSpanId, aKind, fExporter);
end;

function TTracer.StartSpanFromTraceparent(const aOperationName, aTraceparent : string;
  aKind : TSpanKind = skServer) : ISpan;
var
  traceId, parentSpanId : string;
begin
  if ParseTraceparent(aTraceparent, traceId, parentSpanId) then
    Result := TSpan.Create(aOperationName, traceId, parentSpanId, aKind, fExporter)
  else
    Result := StartSpan(aOperationName, aKind); // fallback: new root span
end;

procedure TTracer.Inject(const aSpan : ISpan; aHeaders : TDictionary<string, string>);
begin
  if (aSpan = nil) or (aHeaders = nil) then Exit;
  aHeaders.AddOrSetValue('traceparent', aSpan.Traceparent);
end;

function TTracer.Extract(aHeaders : TDictionary<string, string>) : string;
var
  v : string;
begin
  Result := '';
  if aHeaders = nil then Exit;
  if aHeaders.TryGetValue('traceparent', v) then
    Result := v;
end;

// ─── TCompositeSpanExporter ──────────────────────────────────────────────────

constructor TCompositeSpanExporter.Create;
begin
  inherited Create;
  fExporters := TList<ISpanExporter>.Create;
end;

destructor TCompositeSpanExporter.Destroy;
begin
  fExporters.Free;
  inherited;
end;

procedure TCompositeSpanExporter.Add(const aExporter : ISpanExporter);
begin
  fExporters.Add(aExporter);
end;

procedure TCompositeSpanExporter.Export(const aSpans : TArray<ISpan>);
var
  exp : ISpanExporter;
begin
  for exp in fExporters do
  try
    exp.Export(aSpans);
  except
    // Don't let one exporter failure block others
  end;
end;

procedure TCompositeSpanExporter.Shutdown;
var
  exp : ISpanExporter;
begin
  for exp in fExporters do
  try
    exp.Shutdown;
  except
  end;
end;

// ─── TTracerProvider ─────────────────────────────────────────────────────────

constructor TTracerProvider.Create(const aServiceName : string);
begin
  inherited Create;
  fServiceName := aServiceName;
  fComposite   := TCompositeSpanExporter.Create;
  fCompositeRef := fComposite;
end;

destructor TTracerProvider.Destroy;
begin
  fComposite := nil;
  fCompositeRef := nil;
  inherited;
end;

function TTracerProvider.GetTracer(const aName : string;
  const aVersion : string = '') : ITracer;
begin
  Result := TTracer.Create(fServiceName, fCompositeRef);
end;

procedure TTracerProvider.AddExporter(const aExporter : ISpanExporter);
begin
  fComposite.Add(aExporter);
end;

procedure TTracerProvider.Shutdown;
begin
  fComposite.Shutdown;
end;

class procedure TTracerProvider.SetGlobal(const aProvider : ITracerProvider);
begin
  fGlobal := aProvider;
end;

class function TTracerProvider.GetGlobal : ITracerProvider;
begin
  Result := fGlobal;
end;

// ─── TNullSpanExporter ────────────────────────────────────────────────────────

procedure TNullSpanExporter.Export(const aSpans : TArray<ISpan>);
begin
  // discard
end;

procedure TNullSpanExporter.Shutdown;
begin
  // nothing
end;

// ─── TInMemorySpanExporter ────────────────────────────────────────────────────

constructor TInMemorySpanExporter.Create;
begin
  inherited Create;
  fSpans := TList<ISpan>.Create;
  fLock  := TCriticalSection.Create;
end;

destructor TInMemorySpanExporter.Destroy;
begin
  fLock.Free;
  fSpans.Free;
  inherited;
end;

procedure TInMemorySpanExporter.Export(const aSpans : TArray<ISpan>);
var
  s : ISpan;
begin
  fLock.Enter;
  try
    for s in aSpans do
      fSpans.Add(s);
  finally
    fLock.Leave;
  end;
end;

procedure TInMemorySpanExporter.Shutdown;
begin
  // nothing — used for testing only
end;

procedure TInMemorySpanExporter.Clear;
begin
  fLock.Enter;
  try
    fSpans.Clear;
  finally
    fLock.Leave;
  end;
end;

function TInMemorySpanExporter.SpanCount : Integer;
begin
  fLock.Enter;
  try
    Result := fSpans.Count;
  finally
    fLock.Leave;
  end;
end;

function TInMemorySpanExporter.GetSpans : TArray<ISpan>;
begin
  fLock.Enter;
  try
    Result := fSpans.ToArray;
  finally
    fLock.Leave;
  end;
end;

function TInMemorySpanExporter.GetSpanByName(const aName : string) : ISpan;
var
  s : ISpan;
begin
  Result := nil;
  fLock.Enter;
  try
    for s in fSpans do
      if SameText(s.OperationName, aName) then
        Exit(s);
  finally
    fLock.Leave;
  end;
end;

initialization
  Randomize;

end.
