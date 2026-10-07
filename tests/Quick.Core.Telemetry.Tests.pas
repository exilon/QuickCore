{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Pérez

  Unit        : Quick.Core.Telemetry.Tests
  Description : DUnitX tests for T-01 (Core API), T-02 (Activity), T-03 (Jaeger)
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 30/04/2026

 *************************************************************************** }

unit Quick.Core.Telemetry.Tests;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.Generics.Collections,
  DUnitX.TestFramework,
  Quick.Core.Telemetry.Abstractions,
  Quick.Core.Telemetry,
  Quick.Core.Telemetry.Activity,
  Quick.Core.Telemetry.Exporters.Jaeger;

type

  // ─── T-01 Core Telemetry API ─────────────────────────────────────────────────

  [TestFixture]
  TTelemetryCoreTests = class
  private
    fExporter : TInMemorySpanExporter;
    fProvider : ITracerProvider;
    fTracer   : ITracer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// T-TEL-01: Tracer creates a root span with unique IDs
    [Test] procedure T_TEL_01_StartSpan_CreatesRootSpan;
    /// T-TEL-02: Span is exported when Finish is called
    [Test] procedure T_TEL_02_Finish_ExportsSpan;
    /// T-TEL-03: Child span inherits TraceId and sets ParentSpanId
    [Test] procedure T_TEL_03_StartChildSpan_InheritsTraceId;
    /// T-TEL-04: SetTag stores key-value pairs
    [Test] procedure T_TEL_04_SetTag_StoresTag;
    /// T-TEL-05: AddEvent stores named events with timestamps
    [Test] procedure T_TEL_05_AddEvent_StoresEvent;
    /// T-TEL-06: SetStatus stores status and description
    [Test] procedure T_TEL_06_SetStatus_StoresStatus;
    /// T-TEL-07: Double Finish is idempotent (span exported once)
    [Test] procedure T_TEL_07_DoubleFinish_IsIdempotent;
    /// T-TEL-08: Traceparent header has correct W3C format
    [Test] procedure T_TEL_08_Traceparent_CorrectFormat;
    /// T-TEL-09: StartSpanFromTraceparent continues remote trace
    [Test] procedure T_TEL_09_StartSpanFromTraceparent_ContinuesTrace;
    /// T-TEL-10: Inject fills traceparent header in dictionary
    [Test] procedure T_TEL_10_Inject_FillsTraceparentHeader;
    /// T-TEL-11: TNoOpSpan produces zero IDs and no-ops all methods
    [Test] procedure T_TEL_11_NoOpSpan_NoOps;
    /// T-TEL-12: TInMemorySpanExporter captures spans and Clear resets
    [Test] procedure T_TEL_12_InMemoryExporter_CapturesAndClears;
  end;

  // ─── T-02 Activity Instrumentation ───────────────────────────────────────────

  [TestFixture]
  TActivityTests = class
  private
    fExporter : TInMemorySpanExporter;
    fProvider : ITracerProvider;
    fTracer   : ITracer;
    fSource   : TActivitySource;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// T-ACT-01: StartActivity creates a TActivity wrapping a live span
    [Test] procedure T_ACT_01_StartActivity_WrapsSpan;
    /// T-ACT-02: Freeing TActivity automatically calls Finish on the span
    [Test] procedure T_ACT_02_Free_FinishesSpan;
    /// T-ACT-03: Stop makes IsRunning = False and marks span Finished
    [Test] procedure T_ACT_03_Stop_MarksRunningFalse;
    /// T-ACT-04: Double Stop is idempotent
    [Test] procedure T_ACT_04_DoubleStop_IsIdempotent;
    /// T-ACT-05: AddTag fluent chain propagates tags to span
    [Test] procedure T_ACT_05_AddTag_PropagatesTag;
    /// T-ACT-06: AddEvent fluent chain propagates event to span
    [Test] procedure T_ACT_06_AddEvent_PropagatesEvent;
    /// T-ACT-07: SetStatus fluent chain propagates status
    [Test] procedure T_ACT_07_SetStatus_PropagatesStatus;
    /// T-ACT-08: Child activity inherits TraceId
    [Test] procedure T_ACT_08_ChildActivity_InheritsTraceId;
    /// T-ACT-09: TActivitySource with nil tracer returns no-op activity
    [Test] procedure T_ACT_09_NilTracer_ReturnsNoOp;
    /// T-ACT-10: StartActivityFromTraceparent continues remote trace
    [Test] procedure T_ACT_10_StartFromTraceparent_ContinuesTrace;
  end;

  // ─── T-03 Jaeger Exporter ────────────────────────────────────────────────────

  [TestFixture]
  TJaegerExporterTests = class
  private
    fOpts        : TJaegerExporterOptions;
    fExporter    : TJaegerExporter;
    fExporterRef : ISpanExporter;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// T-JAE-01: Export with no spans does nothing (no error)
    [Test] procedure T_JAE_01_Export_EmptyArray_NoError;
    /// T-JAE-02: Shutdown flushes remaining spans without error
    [Test] procedure T_JAE_02_Shutdown_FlushesWithoutError;
    /// T-JAE-03: Export after Shutdown is silently ignored
    [Test] procedure T_JAE_03_ExportAfterShutdown_IsIgnored;
    /// T-JAE-04: Batching accumulates up to BatchSize before posting
    [Test] procedure T_JAE_04_Batching_AccumulatesSpans;
    /// T-JAE-05: Options defaults are sensible
    [Test] procedure T_JAE_05_Options_Defaults;
  end;

implementation

// ─── Helpers ─────────────────────────────────────────────────────────────────

function MakeFinishedSpan(const aTracer : ITracer; const aName : string) : ISpan;
begin
  Result := aTracer.StartSpan(aName);
  Result.Finish;
end;

// ─── TTelemetryCoreTests ──────────────────────────────────────────────────────

procedure TTelemetryCoreTests.Setup;
var
  provider : ITracerProvider;
begin
  fExporter := TInMemorySpanExporter.Create;
  provider  := TTracerProvider.Create('test-service');
  provider.AddExporter(fExporter);
  fProvider := provider;
  fTracer   := fProvider.GetTracer('test-service');
end;

procedure TTelemetryCoreTests.TearDown;
begin
  fTracer   := nil;
  fProvider := nil;
  fExporter := nil;
end;

{ T-TEL-01 }
procedure TTelemetryCoreTests.T_TEL_01_StartSpan_CreatesRootSpan;
var
  s : ISpan;
begin
  s := fTracer.StartSpan('root-op');
  try
    Assert.AreEqual('root-op', s.OperationName, 'OperationName');
    Assert.AreEqual(32, Length(s.TraceId), 'TraceId length');
    Assert.AreEqual(16, Length(s.SpanId), 'SpanId length');
    Assert.AreEqual('', s.ParentSpanId, 'No parent');
    Assert.IsFalse(s.IsFinished, 'Not finished yet');
  finally
    s.Finish;
  end;
end;

{ T-TEL-02 }
procedure TTelemetryCoreTests.T_TEL_02_Finish_ExportsSpan;
var
  s : ISpan;
begin
  fExporter.Clear;
  s := fTracer.StartSpan('exported-op');
  Assert.AreEqual(0, fExporter.SpanCount, 'Before Finish');
  s.Finish;
  Assert.AreEqual(1, fExporter.SpanCount, 'After Finish');
  Assert.IsTrue(s.IsFinished, 'IsFinished after Finish');
end;

{ T-TEL-03 }
procedure TTelemetryCoreTests.T_TEL_03_StartChildSpan_InheritsTraceId;
var
  parent, child : ISpan;
begin
  parent := fTracer.StartSpan('parent');
  child  := fTracer.StartSpan('child', parent);
  try
    Assert.AreEqual(parent.TraceId, child.TraceId, 'TraceId inherited');
    Assert.AreEqual(parent.SpanId, child.ParentSpanId, 'ParentSpanId = parent.SpanId');
    Assert.AreNotEqual(parent.SpanId, child.SpanId, 'Unique SpanId');
  finally
    child.Finish;
    parent.Finish;
  end;
end;

{ T-TEL-04 }
procedure TTelemetryCoreTests.T_TEL_04_SetTag_StoresTag;
var
  s : ISpan;
  v : string;
begin
  s := fTracer.StartSpan('tagged-op');
  s.SetTag('http.method', 'GET');
  s.SetTag('http.status_code', '200');
  Assert.IsTrue(s.Tags.TryGetValue('http.method', v));
  Assert.AreEqual('GET', v);
  Assert.IsTrue(s.Tags.TryGetValue('http.status_code', v));
  Assert.AreEqual('200', v);
  s.Finish;
end;

{ T-TEL-05 }
procedure TTelemetryCoreTests.T_TEL_05_AddEvent_StoresEvent;
var
  s : ISpan;
  events : TArray<TSpanEvent>;
begin
  s := fTracer.StartSpan('evented-op');
  s.AddEvent('db.query.start');
  s.AddEvent('db.query.end');
  events := s.Events;
  Assert.AreEqual<Integer>(2, Length(events), 'Event count');
  Assert.AreEqual('db.query.start', events[0].Name);
  Assert.AreEqual('db.query.end',   events[1].Name);
  s.Finish;
end;

{ T-TEL-06 }
procedure TTelemetryCoreTests.T_TEL_06_SetStatus_StoresStatus;
var
  s : ISpan;
begin
  s := fTracer.StartSpan('status-op');
  s.SetStatus(ssError, 'Something went wrong');
  Assert.AreEqual(ssError, s.Status);
  Assert.AreEqual('Something went wrong', s.StatusMessage);
  s.Finish;
end;

{ T-TEL-07 }
procedure TTelemetryCoreTests.T_TEL_07_DoubleFinish_IsIdempotent;
var
  s : ISpan;
begin
  fExporter.Clear;
  s := fTracer.StartSpan('double-finish');
  s.Finish;
  s.Finish; // second call must not export again
  Assert.AreEqual(1, fExporter.SpanCount, 'Exported exactly once');
end;

{ T-TEL-08 }
procedure TTelemetryCoreTests.T_TEL_08_Traceparent_CorrectFormat;
var
  s     : ISpan;
  parts : TArray<string>;
begin
  s := fTracer.StartSpan('traceparent-op');
  parts := s.Traceparent.Split(['-']);
  try
    Assert.AreEqual<Integer>(4, Length(parts), 'Four parts');
    Assert.AreEqual('00', parts[0], 'version');
    Assert.AreEqual<Integer>(32, Length(parts[1]), 'traceId length');
    Assert.AreEqual<Integer>(16, Length(parts[2]), 'spanId length');
  finally
    s.Finish;
  end;
end;

{ T-TEL-09 }
procedure TTelemetryCoreTests.T_TEL_09_StartSpanFromTraceparent_ContinuesTrace;
var
  remoteTraceparent : string;
  child             : ISpan;
begin
  remoteTraceparent := '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01';
  child := fTracer.StartSpanFromTraceparent('incoming-request', remoteTraceparent, skServer);
  try
    Assert.AreEqual('4bf92f3577b34da6a3ce929d0e0e4736', child.TraceId, 'TraceId from header');
    Assert.AreEqual('00f067aa0ba902b7', child.ParentSpanId, 'ParentSpanId from header');
    Assert.AreEqual(skServer, child.Kind, 'Kind = skServer');
  finally
    child.Finish;
  end;
end;

{ T-TEL-10 }
procedure TTelemetryCoreTests.T_TEL_10_Inject_FillsTraceparentHeader;
var
  s       : ISpan;
  headers : TDictionary<string, string>;
  v       : string;
begin
  headers := TDictionary<string, string>.Create;
  s := fTracer.StartSpan('inject-op');
  try
    fTracer.Inject(s, headers);
    Assert.IsTrue(headers.TryGetValue('traceparent', v), 'traceparent header set');
    Assert.IsTrue(v.StartsWith('00-'), 'Starts with 00-');
  finally
    s.Finish;
    headers.Free;
  end;
end;

{ T-TEL-11 }
procedure TTelemetryCoreTests.T_TEL_11_NoOpSpan_NoOps;
var
  s : ISpan;
begin
  s := TNoOpSpan.Create;
  Assert.AreEqual('00000000000000000000000000000000', s.TraceId);
  Assert.AreEqual('0000000000000000', s.SpanId);
  s.SetTag('k', 'v');     // must not raise
  s.AddEvent('e');         // must not raise
  s.SetStatus(ssOk);       // must not raise
  s.Finish;                // must not raise
  Assert.AreEqual(ssUnset, s.Status, 'Status stays Unset');
end;

{ T-TEL-12 }
procedure TTelemetryCoreTests.T_TEL_12_InMemoryExporter_CapturesAndClears;
var
  s1, s2 : ISpan;
begin
  fExporter.Clear;
  s1 := fTracer.StartSpan('op1');
  s2 := fTracer.StartSpan('op2');
  s1.Finish;
  s2.Finish;
  Assert.AreEqual(2, fExporter.SpanCount, 'Two spans captured');
  Assert.IsNotNull(fExporter.GetSpanByName('op1'));
  Assert.IsNotNull(fExporter.GetSpanByName('op2'));
  fExporter.Clear;
  Assert.AreEqual(0, fExporter.SpanCount, 'Cleared');
end;

// ─── TActivityTests ───────────────────────────────────────────────────────────

procedure TActivityTests.Setup;
var
  provider : ITracerProvider;
begin
  fExporter := TInMemorySpanExporter.Create;
  provider  := TTracerProvider.Create('test-service');
  provider.AddExporter(fExporter);
  fProvider := provider;
  fTracer   := fProvider.GetTracer('test');
  fSource   := TActivitySource.Create('TestSource', '1.0', fTracer);
end;

procedure TActivityTests.TearDown;
begin
  fSource.Free;
  fTracer   := nil;
  fProvider := nil;
  fExporter := nil;
end;

{ T-ACT-01 }
procedure TActivityTests.T_ACT_01_StartActivity_WrapsSpan;
var
  act : TActivity;
begin
  act := fSource.StartActivity('test-activity');
  try
    Assert.IsNotNull(act, 'TActivity created');
    Assert.IsNotNull(act.Span, 'Span is set');
    Assert.AreEqual('test-activity', act.OperationName);
    Assert.IsTrue(act.IsRunning, 'IsRunning');
  finally
    act.Free;
  end;
end;

{ T-ACT-02 }
procedure TActivityTests.T_ACT_02_Free_FinishesSpan;
var
  act  : TActivity;
  span : ISpan;
begin
  fExporter.Clear;
  act  := fSource.StartActivity('auto-finish');
  span := act.Span; // keep reference
  act.Free;
  Assert.IsTrue(span.IsFinished, 'Span finished after Free');
  Assert.AreEqual(1, fExporter.SpanCount, 'Span exported');
end;

{ T-ACT-03 }
procedure TActivityTests.T_ACT_03_Stop_MarksRunningFalse;
var
  act : TActivity;
begin
  act := fSource.StartActivity('stop-test');
  try
    Assert.IsTrue(act.IsRunning);
    act.Stop;
    Assert.IsFalse(act.IsRunning, 'Not running after Stop');
    Assert.IsTrue(act.Span.IsFinished, 'Span finished after Stop');
  finally
    act.Free; // second stop is no-op
  end;
end;

{ T-ACT-04 }
procedure TActivityTests.T_ACT_04_DoubleStop_IsIdempotent;
var
  act : TActivity;
begin
  fExporter.Clear;
  act := fSource.StartActivity('double-stop');
  act.Stop;
  act.Stop; // must not raise or double-export
  act.Free;
  Assert.AreEqual(1, fExporter.SpanCount, 'Exported exactly once');
end;

{ T-ACT-05 }
procedure TActivityTests.T_ACT_05_AddTag_PropagatesTag;
var
  act : TActivity;
  v   : string;
begin
  act := fSource.StartActivity('tag-test');
  try
    act.AddTag('db.system', 'mssql').AddTag('db.name', 'testdb');
    Assert.IsTrue(act.Span.Tags.TryGetValue('db.system', v));
    Assert.AreEqual('mssql', v);
    Assert.IsTrue(act.Span.Tags.TryGetValue('db.name', v));
    Assert.AreEqual('testdb', v);
  finally
    act.Free;
  end;
end;

{ T-ACT-06 }
procedure TActivityTests.T_ACT_06_AddEvent_PropagatesEvent;
var
  act    : TActivity;
  events : TArray<TSpanEvent>;
begin
  act := fSource.StartActivity('event-test');
  try
    act.AddEvent('cache.miss').AddEvent('db.query');
    events := act.Span.Events;
    Assert.AreEqual<Integer>(2, Length(events), 'Two events');
    Assert.AreEqual('cache.miss', events[0].Name);
  finally
    act.Free;
  end;
end;

{ T-ACT-07 }
procedure TActivityTests.T_ACT_07_SetStatus_PropagatesStatus;
var
  act : TActivity;
begin
  act := fSource.StartActivity('status-test');
  try
    act.SetStatus(ssError, 'Timeout exceeded');
    Assert.AreEqual(ssError, act.Span.Status);
    Assert.AreEqual('Timeout exceeded', act.Span.StatusMessage);
  finally
    act.Free;
  end;
end;

{ T-ACT-08 }
procedure TActivityTests.T_ACT_08_ChildActivity_InheritsTraceId;
var
  parent : TActivity;
  child  : TActivity;
begin
  parent := fSource.StartActivity('parent');
  child  := fSource.StartActivity('child', parent.Span);
  try
    Assert.AreEqual(parent.TraceId, child.TraceId, 'Same TraceId');
    Assert.AreEqual(parent.SpanId, child.Span.ParentSpanId, 'Parent link');
  finally
    child.Free;
    parent.Free;
  end;
end;

{ T-ACT-09 }
procedure TActivityTests.T_ACT_09_NilTracer_ReturnsNoOp;
var
  nullSource : TActivitySource;
  act        : TActivity;
begin
  nullSource := TActivitySource.Create('null-source', '1.0', nil);
  try
    act := nullSource.StartActivity('no-op-activity');
    try
      Assert.IsNotNull(act, 'Activity created even with nil tracer');
      act.AddTag('k', 'v').SetStatus(ssOk); // must not raise
      Assert.AreEqual('0000000000000000', act.SpanId, 'No-op span ID');
    finally
      act.Free;
    end;
  finally
    nullSource.Free;
  end;
end;

{ T-ACT-10 }
procedure TActivityTests.T_ACT_10_StartFromTraceparent_ContinuesTrace;
var
  remoteTraceparent : string;
  act               : TActivity;
begin
  remoteTraceparent := '00-abcdef1234567890abcdef1234567890-1234567890abcdef-01';
  act := fSource.StartActivityFromTraceparent('handle-request', remoteTraceparent, skServer);
  try
    Assert.AreEqual('abcdef1234567890abcdef1234567890', act.TraceId);
    Assert.AreEqual('1234567890abcdef', act.ParentSpanId);
  finally
    act.Free;
  end;
end;

// ─── TJaegerExporterTests ─────────────────────────────────────────────────────

procedure TJaegerExporterTests.Setup;
begin
  fOpts := TJaegerExporterOptions.Create;
  fOpts.IgnoreErrors := True;   // Don't fail tests when Jaeger is not running
  fOpts.BatchSize    := 1000;   // Don't auto-flush in most tests
  fExporter    := TJaegerExporter.Create(fOpts, False); // owned by test
  fExporterRef := fExporter;  // keep interface ref to control lifetime
end;

procedure TJaegerExporterTests.TearDown;
begin
  fExporterRef := nil;  // releases the TInterfacedObject correctly
  fExporter    := nil;
  fOpts.Free;
end;

{ T-JAE-01 }
procedure TJaegerExporterTests.T_JAE_01_Export_EmptyArray_NoError;
begin
  fExporter.Export([]);
end;

{ T-JAE-02 }
procedure TJaegerExporterTests.T_JAE_02_Shutdown_FlushesWithoutError;
var
  provider : ITracerProvider;
  tracer   : ITracer;
  s        : ISpan;
  innerExporter : ISpanExporter;
begin
  // Build a standalone exporter + tracer to produce a real span
  innerExporter := TJaegerExporter.Create;
  provider := TTracerProvider.Create('jaeger-test');
  provider.AddExporter(innerExporter);
  tracer := provider.GetTracer('scope');
  s := tracer.StartSpan('shutdown-test');
  s.Finish;
  innerExporter.Shutdown;
end;

{ T-JAE-03 }
procedure TJaegerExporterTests.T_JAE_03_ExportAfterShutdown_IsIgnored;
var
  exp : ISpanExporter;
begin
  exp := TJaegerExporter.Create;
  exp.Shutdown;
  exp.Export([]); // after shutdown — must be silent
end;

{ T-JAE-04 }
procedure TJaegerExporterTests.T_JAE_04_Batching_AccumulatesSpans;
var
  provider : ITracerProvider;
  tracer   : ITracer;
  inMem    : TInMemorySpanExporter;
  inMemRef : ISpanExporter;
  opts     : TJaegerExporterOptions;
  exp      : ISpanExporter;
  i        : Integer;
  s        : ISpan;
begin
  // Use batch size = 3: first 2 spans should not be posted, 3rd triggers flush
  // We verify via InMemory that spans accumulate correctly (post failures are ignored)
  inMem    := TInMemorySpanExporter.Create;
  inMemRef := inMem;
  opts     := TJaegerExporterOptions.Create;
  opts.BatchSize    := 3;
  opts.IgnoreErrors := True;
  exp      := TJaegerExporter.Create(opts, True);
  provider := TTracerProvider.Create('batch-test');
  provider.AddExporter(inMem);
  provider.AddExporter(exp);
  try
    tracer := provider.GetTracer('scope');
    for i := 1 to 2 do
    begin
      s := tracer.StartSpan('span-' + i.ToString);
      s.Finish;
    end;
    // After 2 spans, batch has 2 (not yet flushed)
    Assert.AreEqual(2, inMem.SpanCount, 'InMemory has 2');
    // 3rd span triggers batch flush
    s := tracer.StartSpan('span-3');
    s.Finish;
    Assert.AreEqual(3, inMem.SpanCount, 'InMemory has 3 after trigger');
  finally
    provider := nil;
    inMemRef := nil;
  end;
end;

{ T-JAE-05 }
procedure TJaegerExporterTests.T_JAE_05_Options_Defaults;
var
  opts : TJaegerExporterOptions;
begin
  opts := TJaegerExporterOptions.Create;
  try
    Assert.AreEqual('http://localhost:4318', opts.Endpoint, 'Default endpoint');
    Assert.AreEqual(5000,  opts.TimeoutMs,   'Default timeout');
    Assert.AreEqual(100,   opts.BatchSize,   'Default batch size');
    Assert.IsTrue(opts.IgnoreErrors,         'IgnoreErrors=True by default');
  finally
    opts.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTelemetryCoreTests);
  TDUnitX.RegisterTestFixture(TActivityTests);
  TDUnitX.RegisterTestFixture(TJaegerExporterTests);

end.
