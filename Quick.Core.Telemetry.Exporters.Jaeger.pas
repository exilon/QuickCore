(* ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Telemetry.Exporters.Jaeger
  Description : OTLP HTTP/JSON exporter compatible with Jaeger >= 1.35
  Author      : Kike Perez
  Version     : 1.0
  Created     : 30/04/2026
  Modified    : 08/05/2026

  This file is part of QuickCore: https://github.com/exilon/QuickCore

  Equivalent .NET: OpenTelemetry.Exporter.Jaeger / OpenTelemetry.Exporter.OpenTelemetryProtocol

  Jaeger OTLP HTTP endpoint: POST http://localhost:4318/v1/traces
  (Jaeger 1.35+ accepts OTLP/HTTP on port 4318 by default)

  JSON payload structure:
  {
    "resourceSpans": [{
      "resource": { "attributes": [{"key":"service.name","value":{"stringValue":"..."}}] },
      "scopeSpans": [{
        "scope": { "name": "...", "version": "..." },
        "spans": [ <OTLP span objects> ]
      }]
    }]
  }

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

 *************************************************************************** *)

unit Quick.Core.Telemetry.Exporters.Jaeger;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  System.SyncObjs,
  System.Generics.Collections,
  System.Net.HttpClient,
  System.Net.URLClient,
  Quick.Core.Telemetry.Abstractions;

type

  // ─── Options ─────────────────────────────────────────────────────────────────

  /// <summary>
  /// Configuration for TJaegerExporter.
  ///
  /// .NET equivalent: OtlpExporterOptions / JaegerExporterOptions
  /// </summary>
  TJaegerExporterOptions = class
  private
    fEndpoint     : string;
    fTimeoutMs    : Integer;
    fBatchSize    : Integer;
    fServiceName  : string;
    fIgnoreErrors : Boolean;
  public
    constructor Create;
    /// <summary>Base URL of the Jaeger/OTLP receiver. Default: 'http://localhost:4318'.</summary>
    property Endpoint    : string  read fEndpoint    write fEndpoint;
    /// <summary>HTTP POST timeout in milliseconds. Default: 5000.</summary>
    property TimeoutMs   : Integer read fTimeoutMs   write fTimeoutMs;
    /// <summary>Maximum spans per HTTP batch. Default: 100.</summary>
    property BatchSize   : Integer read fBatchSize   write fBatchSize;
    /// <summary>value of service.name resource attribute. Default: 'unknown_service'.</summary>
    property ServiceName : string  read fServiceName write fServiceName;
    /// <summary>When True, HTTP errors are silently discarded. Default: True.</summary>
    property IgnoreErrors: Boolean read fIgnoreErrors write fIgnoreErrors;
  end;

  // ─── TJaegerExporter ─────────────────────────────────────────────────────────

  /// <summary>
  /// Exports spans to a Jaeger/OTLP HTTP receiver as OTLP JSON.
  ///
  /// Batching: when BatchSize > 1 (default 100), spans are accumulated in an
  /// internal queue and flushed either when the batch is full or when
  /// Shutdown is called. If BatchSize = 1, each span is posted immediately
  /// (simple mode, easier to debug).
  ///
  /// Thread-safety: Export / Shutdown are safe to call from multiple threads.
  ///
  /// .NET equivalent: OtlpTraceExporter / JaegerExporter
  ///
  /// Docker Quickstart:
  ///   docker run -d -p 16686:16686 -p 4318:4318 jaegertracing/all-in-one:latest
  ///   Then open http://localhost:16686 to view traces.
  /// </summary>
  TJaegerExporter = class(TInterfacedObject, ISpanExporter)
  private
    fOptions  : TJaegerExporterOptions;
    fOwnsOpts : Boolean;
    fBatch    : TList<ISpan>;
    fLock     : TCriticalSection;
    fShutdown : Boolean;

    function  BuildOtlpJson(const aSpans : TArray<ISpan>) : string;
    function  SpanKindToString(aKind : TSpanKind) : Integer;
    function  StatusCodeToInt(aStatus : TSpanStatus) : Integer;
    function  DateTimeToUnixNano(aDateTime : TDateTime) : Int64;
    function  JsonEscape(const s : string) : string;
    function  BuildAttributesJson(aDict : TDictionary<string, string>) : string;
    function  BuildEventsJson(const aEvents : TArray<TSpanEvent>) : string;
    function  HexToBytes(const hex : string) : string;  // returns JSON byte-array representation
    procedure PostJson(const aJson : string);
  public
    /// <param name="aOptions">Options object. TJaegerExporter takes ownership when aOwnsOptions=True.</param>
    constructor Create(aOptions : TJaegerExporterOptions = nil; aOwnsOptions : Boolean = True);
    destructor Destroy; override;

    procedure Export(const aSpans : TArray<ISpan>);
    procedure Shutdown;

    property Options : TJaegerExporterOptions read fOptions;
  end;

implementation

// ─── TJaegerExporterOptions ──────────────────────────────────────────────────

constructor TJaegerExporterOptions.Create;
begin
  inherited Create;
  fEndpoint     := 'http://localhost:4318';
  fTimeoutMs    := 5000;
  fBatchSize    := 100;
  fServiceName  := 'unknown_service';
  fIgnoreErrors := True;
end;

// ─── TJaegerExporter ─────────────────────────────────────────────────────────

constructor TJaegerExporter.Create(aOptions : TJaegerExporterOptions = nil;
  aOwnsOptions : Boolean = True);
begin
  inherited Create;
  if aOptions <> nil then
  begin
    fOptions  := aOptions;
    fOwnsOpts := aOwnsOptions;
  end
  else
  begin
    fOptions  := TJaegerExporterOptions.Create;
    fOwnsOpts := True;
  end;
  fBatch    := TList<ISpan>.Create;
  fLock     := TCriticalSection.Create;
  fShutdown := False;
end;

destructor TJaegerExporter.Destroy;
begin
  Shutdown;
  fLock.Free;
  fBatch.Free;
  if fOwnsOpts then
    fOptions.Free;
  inherited;
end;

procedure TJaegerExporter.Export(const aSpans : TArray<ISpan>);
var
  flushNow : Boolean;
  toFlush  : TArray<ISpan>;
begin
  if fShutdown then Exit;
  if Length(aSpans) = 0 then Exit;

  fLock.Enter;
  try
    if fShutdown then Exit;
    fBatch.AddRange(aSpans);
    flushNow := fBatch.Count >= fOptions.BatchSize;
    if flushNow then
    begin
      toFlush := fBatch.ToArray;
      fBatch.Clear;
    end;
  finally
    fLock.Leave;
  end;

  if flushNow then
    PostJson(BuildOtlpJson(toFlush));
end;

procedure TJaegerExporter.Shutdown;
var
  remaining : TArray<ISpan>;
begin
  fLock.Enter;
  try
    if fShutdown then Exit;
    fShutdown := True;
    remaining := fBatch.ToArray;
    fBatch.Clear;
  finally
    fLock.Leave;
  end;
  if Length(remaining) > 0 then
    PostJson(BuildOtlpJson(remaining));
end;

// ─── OTLP JSON serialisation ─────────────────────────────────────────────────

function TJaegerExporter.JsonEscape(const s : string) : string;
var
  i : Integer;
begin
  Result := '';
  for i := 1 to Length(s) do
    case s[i] of
      '"'  : Result := Result + '\"';
      '\'  : Result := Result + '\\';
      #8   : Result := Result + '\b';
      #9   : Result := Result + '\t';
      #10  : Result := Result + '\n';
      #12  : Result := Result + '\f';
      #13  : Result := Result + '\r';
    else
      Result := Result + s[i];
    end;
end;

function TJaegerExporter.DateTimeToUnixNano(aDateTime : TDateTime) : Int64;
begin
  // Convert TDateTime (UTC) → Unix nanoseconds
  Result := DateTimeToUnix(aDateTime, False) * Int64(1000000000);
end;

function TJaegerExporter.SpanKindToString(aKind : TSpanKind) : Integer;
begin
  // OTLP SpanKind values match our enum + 1 (INTERNAL=1, SERVER=2, CLIENT=3, PRODUCER=4, CONSUMER=5)
  Result := Ord(aKind) + 1;
end;

function TJaegerExporter.StatusCodeToInt(aStatus : TSpanStatus) : Integer;
begin
  // OTLP status: STATUS_CODE_UNSET=0, STATUS_CODE_OK=1, STATUS_CODE_ERROR=2
  case aStatus of
    ssUnset : Result := 0;
    ssOk    : Result := 1;
    ssError : Result := 2;
  else
    Result := 0;
  end;
end;

function TJaegerExporter.BuildAttributesJson(aDict : TDictionary<string, string>) : string;
var
  first : Boolean;
  pair  : TPair<string, string>;
begin
  Result := '[';
  if (aDict = nil) or (aDict.Count = 0) then
  begin
    Result := Result + ']';
    Exit;
  end;
  first := True;
  for pair in aDict do
  begin
    if not first then Result := Result + ',';
    Result := Result + Format('{"key":"%s","value":{"stringValue":"%s"}}',
      [JsonEscape(pair.Key), JsonEscape(pair.Value)]);
    first := False;
  end;
  Result := Result + ']';
end;

function TJaegerExporter.BuildEventsJson(const aEvents : TArray<TSpanEvent>) : string;
var
  first : Boolean;
  ev    : TSpanEvent;
begin
  Result := '[';
  first  := True;
  for ev in aEvents do
  begin
    if not first then Result := Result + ',';
    Result := Result + Format('{"timeUnixNano":"%d","name":"%s","attributes":%s}',
      [DateTimeToUnixNano(ev.Timestamp),
       JsonEscape(ev.Name),
       BuildAttributesJson(ev.Attributes)]);
    first := False;
  end;
  Result := Result + ']';
end;

function TJaegerExporter.HexToBytes(const hex : string) : string;
// OTLP uses base64-encoded bytes for traceId / spanId in JSON.
// For simplicity we pass them as hex strings using the "as stringValue" form
// which Jaeger also accepts when configured with OTLP JSON.
begin
  Result := hex;
end;

function TJaegerExporter.BuildOtlpJson(const aSpans : TArray<ISpan>) : string;
var
  spansJson  : string;
  first      : Boolean;
  s          : ISpan;
  parentStr  : string;
  statusJson : string;
begin
  spansJson := '';
  first     := True;
  for s in aSpans do
  begin
    if not first then spansJson := spansJson + ',';

    if s.ParentSpanId <> '' then
      parentStr := Format('"parentSpanId":"%s",', [s.ParentSpanId])
    else
      parentStr := '';

    statusJson := Format('"status":{"message":"%s","code":%d}',
      [JsonEscape(s.StatusMessage), StatusCodeToInt(s.Status)]);

    spansJson := spansJson + Format(
      '{"traceId":"%s","spanId":"%s",%s"name":"%s","kind":%d,' +
      '"startTimeUnixNano":"%d","endTimeUnixNano":"%d",' +
      '"attributes":%s,"events":%s,%s}',
      [HexToBytes(s.TraceId),
       HexToBytes(s.SpanId),
       parentStr,
       JsonEscape(s.OperationName),
       SpanKindToString(s.Kind),
       DateTimeToUnixNano(s.StartTime),
       DateTimeToUnixNano(s.EndTime),
       BuildAttributesJson(s.Tags),
       BuildEventsJson(s.Events),
       statusJson]);
    first := False;
  end;

  // Resource attribute: service.name
  Result := Format(
    '{"resourceSpans":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"%s"}}]},' +
    '"scopeSpans":[{"scope":{"name":"QuickCore.Telemetry","version":"1.0"},' +
    '"spans":[%s]}]}]}',
    [JsonEscape(fOptions.ServiceName), spansJson]);
end;

// ─── HTTP post ────────────────────────────────────────────────────────────────

procedure TJaegerExporter.PostJson(const aJson : string);
var
  http     : THTTPClient;
  content  : TStringStream;
  url      : string;
  response : IHTTPResponse;
begin
  if aJson = '' then Exit;
  url := fOptions.Endpoint.TrimRight(['/']) + '/v1/traces';
  http := THTTPClient.Create;
  try
    http.ResponseTimeout := fOptions.TimeoutMs;
    content := TStringStream.Create(aJson, TEncoding.UTF8);
    try
      try
        response := http.Post(url, content, nil,
          [TNameValuePair.Create('Content-Type', 'application/json')]);
        // 200/202 are success; anything else is a server-side error
        if (not fOptions.IgnoreErrors) and
           (response.StatusCode < 200) or (response.StatusCode >= 300) then
          raise Exception.CreateFmt('Jaeger OTLP export failed: HTTP %d — %s',
            [response.StatusCode, response.StatusText]);
      except
        if not fOptions.IgnoreErrors then raise;
        // else: silently discard (backend may be unavailable)
      end;
    finally
      content.Free;
    end;
  finally
    http.Free;
  end;
end;

end.
