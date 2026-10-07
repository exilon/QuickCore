program TelemetrySample;

{$APPTYPE CONSOLE}
// {$R *.res}  — .res not generated for dcc32 console builds; omit to avoid linker error

(*
  TelemetrySample — QuickCore T-01/T-02/T-03 demo
  ================================================
  Shows OpenTelemetry-style distributed tracing with:
    1. Core API: TTracerProvider / ITracer / ISpan
    2. Activity instrumentation: TActivitySource / TActivity (RAII)
    3. W3C context propagation (Traceparent header)
    4. Jaeger OTLP exporter (set JAEGER=1 env var to enable)
    5. In-memory exporter for verification without Jaeger
    6. Global provider pattern

  To see live traces in Jaeger:
    docker run -d -p 16686:16686 -p 4318:4318 jaegertracing/all-in-one:latest
    set JAEGER=1
    TelemetrySample.exe
    open http://localhost:16686
*)

uses
  System.SysUtils,
  System.Generics.Collections,
  Quick.Core.Telemetry.Abstractions,
  Quick.Core.Telemetry,
  Quick.Core.Telemetry.Activity,
  Quick.Core.Telemetry.Exporters.Jaeger;

// ─── Helpers ─────────────────────────────────────────────────────────────────

procedure Separator(const aTitle : string);
begin
  WriteLn;
  WriteLn(StringOfChar('-', 60));
  WriteLn('  ' + aTitle);
  WriteLn(StringOfChar('-', 60));
end;

procedure PrintSpan(const s : ISpan; const indent : string = '');
var
  ev : TSpanEvent;
begin
  WriteLn(indent + 'Span: ' + s.OperationName);
  WriteLn(indent + '  TraceId      : ' + s.TraceId);
  WriteLn(indent + '  SpanId       : ' + s.SpanId);
  if s.ParentSpanId <> '' then
    WriteLn(indent + '  ParentSpanId : ' + s.ParentSpanId);
  WriteLn(indent + '  Kind         : ' + IntToStr(Ord(s.Kind)));
  case s.Status of
    ssOk    : WriteLn(indent + '  Status       : OK');
    ssError : WriteLn(indent + '  Status       : ERROR – ' + s.StatusMessage);
  else
    WriteLn(indent + '  Status       : Unset');
  end;
  for ev in s.Events do
    WriteLn(indent + '  Event        : ' + ev.Name);
end;

// ─── Demo 1: Core API — basic span lifecycle ─────────────────────────────────

procedure Demo1_BasicSpanLifecycle(const aTracer : ITracer; exporter : TInMemorySpanExporter);
var
  span : ISpan;
begin
  Separator('Demo 1: Core API — basic span lifecycle');
  exporter.Clear;

  span := aTracer.StartSpan('handle-user-login', skServer);
  span.SetTag('user.id', '42');
  span.SetTag('auth.method', 'password');
  span.AddEvent('password.verified');
  span.SetStatus(ssOk);
  span.Finish;

  PrintSpan(span);
  WriteLn('  Exported spans: ' + IntToStr(exporter.SpanCount));
end;

// ─── Demo 2: Nested spans — parent-child relationship ─────────────────────────

procedure Demo2_ParentChildSpans(const aTracer : ITracer; exporter : TInMemorySpanExporter);
var
  parent, child1, child2 : ISpan;
begin
  Separator('Demo 2: Nested spans — parent-child');
  exporter.Clear;

  parent := aTracer.StartSpan('HTTP POST /api/order', skServer);
  parent.SetTag('http.method', 'POST');
  parent.SetTag('http.url', '/api/order');

    child1 := aTracer.StartSpan('validate-order', parent, skInternal);
    child1.AddEvent('validation.start');
    child1.SetStatus(ssOk);
    child1.Finish;

    child2 := aTracer.StartSpan('insert-order', parent, skClient);
    child2.SetTag('db.system', 'postgresql');
    child2.SetTag('db.statement', 'INSERT INTO orders ...');
    child2.SetStatus(ssOk);
    child2.Finish;

  parent.SetStatus(ssOk);
  parent.Finish;

  PrintSpan(parent);
  PrintSpan(child1, '  ');
  PrintSpan(child2, '  ');
  WriteLn('Total exported: ' + IntToStr(exporter.SpanCount));
end;

// ─── Demo 3: TActivity — RAII wrapper ─────────────────────────────────────────

procedure Demo3_ActivityRAII(const aTracer : ITracer; exporter : TInMemorySpanExporter);
var
  source : TActivitySource;
  act    : TActivity;
begin
  Separator('Demo 3: TActivitySource / TActivity — RAII');
  exporter.Clear;
  source := TActivitySource.Create('MyApp.OrderService', '2.0', aTracer);
  try
    // Happy path
    act := source.StartActivity('process-payment', skClient);
    try
      act.AddTag('payment.provider', 'stripe')
         .AddTag('payment.amount', '99.90')
         .AddEvent('payment.initiated')
         .AddEvent('payment.confirmed')
         .SetStatus(ssOk);
    finally
      act.Free; // automatically calls Finish
    end;

    WriteLn('Exported: ' + IntToStr(exporter.SpanCount));
    PrintSpan(exporter.GetSpanByName('process-payment'));

    // Error path
    exporter.Clear;
    act := source.StartActivity('process-refund', skClient);
    try
      act.AddTag('payment.provider', 'stripe');
      raise Exception.Create('Stripe gateway timeout');
    except
      on E: Exception do
      begin
        act.SetStatus(ssError, E.Message);
        act.Free;
        WriteLn('Error span exported: ' + IntToStr(exporter.SpanCount));
        PrintSpan(exporter.GetSpanByName('process-refund'));
      end;
    end;
  finally
    source.Free;
  end;
end;

// ─── Demo 4: W3C context propagation ─────────────────────────────────────────

procedure Demo4_ContextPropagation(const aTracer : ITracer; exporter : TInMemorySpanExporter);
var
  outgoing  : ISpan;
  headers   : TDictionary<string, string>;
  incoming  : ISpan;
  extracted : string;
  kv        : TPair<string, string>;
begin
  Separator('Demo 4: W3C context propagation (Inject / Extract)');
  exporter.Clear;
  headers := TDictionary<string, string>.Create;
  try
    // Service A: inject into outgoing HTTP headers
    outgoing := aTracer.StartSpan('service-A-call', skClient);
    outgoing.SetTag('http.url', 'http://service-b/api/items');
    aTracer.Inject(outgoing, headers);
    outgoing.Finish;

    WriteLn('Outgoing headers:');
    for kv in headers do
      WriteLn('  ' + kv.Key + ': ' + kv.Value);

    // Service B: extract and continue
    extracted := aTracer.Extract(headers);
    WriteLn('Extracted traceparent: ' + extracted);

    incoming := aTracer.StartSpanFromTraceparent('service-B-handle', extracted, skServer);
    incoming.SetTag('http.method', 'GET');
    incoming.SetStatus(ssOk);
    incoming.Finish;

    PrintSpan(incoming);
    if incoming.ParentSpanId <> outgoing.SpanId then
      WriteLn('WARNING: parent span ID mismatch');
    WriteLn('Same trace? ' + BoolToStr(incoming.TraceId = outgoing.TraceId, True));
  finally
    headers.Free;
  end;
end;

// ─── Demo 5: Jaeger / OTLP exporter ──────────────────────────────────────────

procedure Demo5_JaegerExporter;
var
  opts       : TJaegerExporterOptions;
  jaeger     : TJaegerExporter;
  provider   : TTracerProvider;
  tracer     : ITracer;
  source     : TActivitySource;
  act, child : TActivity;
begin
  Separator('Demo 5: Jaeger OTLP exporter (requires Jaeger on localhost:4318)');

  opts := TJaegerExporterOptions.Create;
  opts.ServiceName  := 'TelemetrySample';
  opts.IgnoreErrors := True;  // silent when Jaeger not running
  opts.BatchSize    := 10;

  jaeger   := TJaegerExporter.Create(opts, True);
  provider := TTracerProvider.Create('TelemetrySample');
  provider.AddExporter(jaeger);
  TTracerProvider.SetGlobal(provider);

  try
    tracer := provider.GetTracer('demo');
    source := TActivitySource.Create('TelemetrySample.Checkout', '1.0', tracer);
    try
      act := source.StartActivity('checkout', skServer);
      try
        act.AddTag('user.id', '123').AddTag('cart.items', '5');

        child := source.StartActivity('charge-card', act.Span, skClient);
        child.AddTag('payment.method', 'visa_xxxx_1234');
        child.SetStatus(ssOk);
        child.Free;

        child := source.StartActivity('send-confirmation-email', act.Span, skProducer);
        child.AddTag('email.to', 'user@example.com');
        child.SetStatus(ssOk);
        child.Free;

        act.SetStatus(ssOk);
      finally
        act.Free;
      end;
      provider.Shutdown; // flushes remaining batch
      WriteLn('Spans sent to Jaeger (if running). Check http://localhost:16686');
    finally
      source.Free;
    end;
  finally
    provider.Free;
  end;
end;

// ─── Demo 6: Nil tracer (no-op) — safe when tracing disabled ─────────────────

procedure Demo6_NoOpActivitySource;
var
  source : TActivitySource;
  act    : TActivity;
begin
  Separator('Demo 6: TActivitySource with nil tracer — no-op (safe)');
  source := TActivitySource.Create('disabled-module', '1.0', nil {no tracer});
  try
    act := source.StartActivity('background-job');
    try
      act.AddTag('job', 'cleanup').SetStatus(ssOk);
      // All calls are no-ops; no spans produced, no errors raised
      WriteLn('No-op activity completed. SpanId: ' + act.SpanId);
    finally
      act.Free;
    end;
  finally
    source.Free;
  end;
end;

// ─── Main ─────────────────────────────────────────────────────────────────────

var
  exporter : TInMemorySpanExporter;
  provider : TTracerProvider;
  tracer   : ITracer;
begin
  ReportMemoryLeaksOnShutdown := True;
  try
    WriteLn('QuickCore — Telemetry Sample (T-01 / T-02 / T-03)');
    WriteLn('Equivalent .NET: System.Diagnostics.Activity + OpenTelemetry SDK');
    WriteLn;

    // Set up provider with in-memory exporter
    exporter := TInMemorySpanExporter.Create;
    provider := TTracerProvider.Create('TelemetrySample');
    provider.AddExporter(exporter);

    try
      tracer := provider.GetTracer('main');

      Demo1_BasicSpanLifecycle(tracer, exporter);
      Demo2_ParentChildSpans(tracer, exporter);
      Demo3_ActivityRAII(tracer, exporter);
      Demo4_ContextPropagation(tracer, exporter);
      Demo6_NoOpActivitySource;
      Demo5_JaegerExporter;

      WriteLn;
      WriteLn('All demos completed successfully.');
    finally
      tracer   := nil;
      provider.Free;
      exporter := nil;
    end;
  except
    on E: Exception do
    begin
      WriteLn('ERROR: ' + E.Message);
      ExitCode := 1;
    end;
  end;
  WriteLn;
  Write('Press Enter to exit...');
  ReadLn;
end.
