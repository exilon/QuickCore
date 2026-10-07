{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Telemetry.Abstractions
  Description : OpenTelemetry Core API — interfaces and shared types
  Author      : Kike Perez
  Version     : 1.0
  Created     : 30/04/2026
  Modified    : 08/05/2026

  This file is part of QuickCore: https://github.com/exilon/QuickCore

  Equivalent .NET: OpenTelemetry.Api
    ActivitySource, Activity, Tracer, TracerProvider, ISpanExporter

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

unit Quick.Core.Telemetry.Abstractions;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.Generics.Collections;

type

  // ─── Enums ───────────────────────────────────────────────────────────────────

  /// <summary>
  /// Describes the relationship between the span and the calling system.
  /// .NET equivalent: ActivityKind
  /// </summary>
  TSpanKind = (
    skInternal,   // Default — internal span, no remote calls
    skServer,     // Incoming remote request (HTTP server, RPC server)
    skClient,     // Outgoing remote request (HTTP client, DB call)
    skProducer,   // Message producer (queue, event bus)
    skConsumer    // Message consumer
  );

  /// <summary>
  /// The outcome status of a span.
  /// .NET equivalent: ActivityStatusCode
  /// </summary>
  TSpanStatus = (
    ssUnset,   // Default — status has not been set
    ssOk,      // Span completed successfully
    ssError    // Span completed with an error
  );

  // ─── Span event ──────────────────────────────────────────────────────────────

  TSpanAttributes = TDictionary<string, string>;

  TSpanEvent = record
    Name       : string;
    Timestamp  : TDateTime;    // UTC
    Attributes : TSpanAttributes;  // optional — may be nil
  end;

  // ─── ISpan ───────────────────────────────────────────────────────────────────

  /// <summary>
  /// Represents a single unit of work in a distributed trace.
  ///
  /// .NET equivalent: Activity (System.Diagnostics.Activity)
  ///
  /// Lifecycle:
  ///   span := tracer.StartSpan('my-operation');
  ///   try
  ///     span.SetTag('db.system', 'postgresql');
  ///     span.SetTag('db.statement', 'SELECT ...');
  ///     // do work ...
  ///     span.SetStatus(ssOk);
  ///   except
  ///     on E: Exception do
  ///     begin
  ///       span.SetStatus(ssError, E.Message);
  ///       raise;
  ///     end;
  ///   end;
  ///   span.Finish;
  /// </summary>
  ISpan = interface
  ['{F1A2B3C4-D5E6-F7A8-B9C0-D1E2F3A4B5C6}']
    // ── Identity ──────────────────────────────────────────────────────────────
    function TraceId     : string;   // 32 hex chars (W3C traceparent format)
    function SpanId      : string;   // 16 hex chars
    function ParentSpanId: string;   // 16 hex chars; empty for root spans

    // ── Metadata ──────────────────────────────────────────────────────────────
    function OperationName : string;
    function Kind          : TSpanKind;
    function StartTime     : TDateTime;   // UTC
    function EndTime       : TDateTime;   // UTC; zero until Finish is called
    function IsFinished    : Boolean;

    // ── Tags (semantic conventions) ──────────────────────────────────────────
    /// <summary>Add or update a tag. String key-value pair. Thread-safe.</summary>
    procedure SetTag(const aKey, aValue : string);
    function  Tags : TSpanAttributes;

    // ── Events ────────────────────────────────────────────────────────────────
    /// <summary>Record a timestamped event. .NET: Activity.AddEvent.</summary>
    procedure AddEvent(const aName : string); overload;
    procedure AddEvent(const aName : string; aAttributes : TSpanAttributes); overload;
    function Events : TArray<TSpanEvent>;

    // ── Status ────────────────────────────────────────────────────────────────
    procedure SetStatus(aStatus : TSpanStatus; const aDescription : string = '');
    function  Status        : TSpanStatus;
    function  StatusMessage : string;

    // ── W3C context propagation ───────────────────────────────────────────────
    /// <summary>Traceparent header value: "00-{traceId}-{spanId}-{flags}".</summary>
    function  Traceparent : string;

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    procedure Finish; overload;
    procedure Finish(aEndTime : TDateTime); overload;
  end;

  // ─── ISpanExporter ────────────────────────────────────────────────────────────

  /// <summary>
  /// Receives finished spans for export (to Jaeger, Zipkin, OTLP, etc.).
  /// Called by the tracer after span.Finish.
  ///
  /// .NET equivalent: BaseExporter&lt;Activity&gt; / ISpanExporter
  /// </summary>
  ISpanExporter = interface
  ['{A2B3C4D5-E6F7-A8B9-C0D1-E2F3A4B5C6D7}']
    /// <summary>Export the given finished spans. Must be non-blocking or fast.</summary>
    procedure Export(const aSpans : TArray<ISpan>);
    /// <summary>Flush pending exports and release resources.</summary>
    procedure Shutdown;
  end;

  // ─── ITracer ─────────────────────────────────────────────────────────────────

  /// <summary>
  /// Factory for creating spans.
  ///
  /// .NET equivalent: Tracer (OpenTelemetry.Api) / ActivitySource
  ///
  /// Usage:
  ///   tracer := provider.GetTracer('my-service', '1.0');
  ///   span   := tracer.StartSpan('operation', skServer);
  ///   ...
  ///   span.Finish;
  /// </summary>
  ITracer = interface
  ['{B3C4D5E6-F7A8-B9C0-D1E2-F3A4B5C6D7E8}']
    /// <summary>Start a new root span (no parent).</summary>
    function StartSpan(const aOperationName : string;
      aKind : TSpanKind = skInternal) : ISpan; overload;
    /// <summary>Start a child span of the given parent.</summary>
    function StartSpan(const aOperationName : string;
      const aParent : ISpan;
      aKind : TSpanKind = skInternal) : ISpan; overload;
    /// <summary>Start a span continuing a remote trace (from W3C Traceparent header).</summary>
    function StartSpanFromTraceparent(const aOperationName, aTraceparent : string;
      aKind : TSpanKind = skServer) : ISpan;
    /// <summary>Inject trace context into outgoing headers (W3C format).</summary>
    procedure Inject(const aSpan : ISpan; aHeaders : TDictionary<string, string>);
    /// <summary>Extract trace context from incoming headers; returns nil if no valid context.</summary>
    function Extract(aHeaders : TDictionary<string, string>) : string; // returns traceparent or ''
    function ServiceName : string;
  end;

  // ─── ITracerProvider ─────────────────────────────────────────────────────────

  /// <summary>
  /// Root factory for ITracer instances. One per application.
  ///
  /// .NET equivalent: TracerProvider (OpenTelemetry.Api) / ITracerProvider
  ///
  /// Usage:
  ///   provider := TTracerProviderBuilder.Create
  ///     .AddExporter(TJaegerExporter.Create(options))
  ///     .Build('my-service');
  ///   tracer := provider.GetTracer('my-service');
  /// </summary>
  ITracerProvider = interface
  ['{C4D5E6F7-A8B9-C0D1-E2F3-A4B5C6D7E8F9}']
    function GetTracer(const aName : string; const aVersion : string = '') : ITracer;
    procedure AddExporter(const aExporter : ISpanExporter);
    procedure Shutdown;
  end;

  // ─── No-op span ───────────────────────────────────────────────────────────────

  /// <summary>
  /// A span that does nothing. Used when tracing is disabled or not configured.
  /// Implements the Null Object pattern.
  /// </summary>
  TNoOpSpan = class(TInterfacedObject, ISpan)
  private
    fEmptyTags   : TSpanAttributes;
    fEmptyEvents : TArray<TSpanEvent>;
  public
    constructor Create;
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

implementation

// ─── TNoOpSpan ────────────────────────────────────────────────────────────────

constructor TNoOpSpan.Create;
begin
  inherited Create;
  fEmptyTags   := TSpanAttributes.Create;
  fEmptyEvents := [];
end;

destructor TNoOpSpan.Destroy;
begin
  fEmptyTags.Free;
  inherited;
end;

function TNoOpSpan.TraceId       : string;  begin Result := '00000000000000000000000000000000'; end;
function TNoOpSpan.SpanId        : string;  begin Result := '0000000000000000'; end;
function TNoOpSpan.ParentSpanId  : string;  begin Result := ''; end;
function TNoOpSpan.OperationName : string;  begin Result := ''; end;
function TNoOpSpan.Kind          : TSpanKind; begin Result := skInternal; end;
function TNoOpSpan.StartTime     : TDateTime; begin Result := 0; end;
function TNoOpSpan.EndTime       : TDateTime; begin Result := 0; end;
function TNoOpSpan.IsFinished    : Boolean;   begin Result := False; end;
procedure TNoOpSpan.SetTag(const aKey, aValue : string); begin end;
function TNoOpSpan.Tags          : TSpanAttributes; begin Result := fEmptyTags; end;
procedure TNoOpSpan.AddEvent(const aName : string); begin end;
procedure TNoOpSpan.AddEvent(const aName : string; aAttributes : TSpanAttributes); begin end;
function TNoOpSpan.Events        : TArray<TSpanEvent>; begin Result := fEmptyEvents; end;
procedure TNoOpSpan.SetStatus(aStatus : TSpanStatus; const aDescription : string); begin end;
function TNoOpSpan.Status        : TSpanStatus; begin Result := ssUnset; end;
function TNoOpSpan.StatusMessage : string; begin Result := ''; end;
function TNoOpSpan.Traceparent   : string; begin Result := '00-00000000000000000000000000000000-0000000000000000-00'; end;
procedure TNoOpSpan.Finish; begin end;
procedure TNoOpSpan.Finish(aEndTime : TDateTime); begin end;

end.
