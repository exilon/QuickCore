{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Extensions.HttpClient
  Description : HttpClient factory with Polly-like resilience pipeline
  Author      : Kike Perez
  Version     : 1.0
  Created     : 08/05/2026
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

unit Quick.Core.Extensions.HttpClient;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.SyncObjs,
  Quick.Core.DependencyInjection,
  Quick.Core.Resilience.Abstractions,
  Quick.Core.Resilience.Retry,
  Quick.Core.Resilience.CircuitBreaker,
  Quick.Core.Resilience.Timeout;

type

  // ── Exceptions ──────────────────────────────────────────────────────────────

  /// <summary>
  /// Raised when an HTTP response carries a 5xx server-error status code.
  /// Used internally so the retry / circuit-breaker policies can treat it as
  /// a transient failure.
  /// </summary>
  EHttpException = class(Exception)
  private
    fStatusCode: Integer;
  public
    constructor Create(aStatusCode: Integer; const aMessage: string);
    property StatusCode: Integer read fStatusCode;
  end;

  // ── Response ────────────────────────────────────────────────────────────────

  /// <summary>
  /// HTTP response returned by IHttpClient methods.
  ///
  /// IsSuccess    : status code in [200..299]
  /// IsServerError: status code in [500..599] (triggers retries by default)
  /// ContentAsJson: parses Body as TJSONValue; nil if Body is not valid JSON.
  ///               Caller does NOT own the returned object — it is owned by
  ///               the THttpResponse instance.
  /// </summary>
  IHttpResponse = interface
  ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567891}']
    function StatusCode   : Integer;
    function StatusText   : string;
    function Body         : string;
    function IsSuccess    : Boolean;
    function IsServerError: Boolean;
    function ContentAsJson: TJSONValue;
  end;

  THttpResponse = class(TInterfacedObject, IHttpResponse)
  private
    fStatusCode: Integer;
    fStatusText: string;
    fBody      : string;
    fJsonCache : TJSONValue;
  public
    constructor Create(aStatusCode: Integer; const aStatusText, aBody: string);
    destructor  Destroy; override;
    function StatusCode   : Integer;
    function StatusText   : string;
    function Body         : string;
    function IsSuccess    : Boolean;
    function IsServerError: Boolean;
    function ContentAsJson: TJSONValue;
  end;

  // ── Client interface ────────────────────────────────────────────────────────

  /// <summary>
  /// Resilient HTTP client.  All methods combine the configured base URL with
  /// the supplied path/URL and apply the resilience pipeline (Timeout → Retry →
  /// CircuitBreaker).
  ///
  /// 5xx responses raise EHttpException, which is treated as a transient failure
  /// by the retry and circuit-breaker policies.
  /// 4xx responses are returned as-is (not retried).
  ///
  /// Equivalent to: IHttpClientFactory.CreateClient() in .NET + Polly handler.
  /// </summary>
  IHttpClient = interface
  ['{B2C3D4E5-F6A7-8901-BCDE-F12345678902}']
    function Get   (const aUrl: string): IHttpResponse;
    function Post  (const aUrl: string; const aBody: string): IHttpResponse; overload;
    function Post  (const aUrl: string; aJson: TJSONObject): IHttpResponse; overload;
    function Put   (const aUrl: string; const aBody: string): IHttpResponse;
    function Delete(const aUrl: string): IHttpResponse;
  end;

  // ── Options ─────────────────────────────────────────────────────────────────

  THttpClientOptions = class
  private
    fBaseUrl          : string;
    fResponseTimeout  : Integer;    // ms  (0 = RTL default)
    fConnectionTimeout: Integer;    // ms  (0 = RTL default)
    fUserAgent        : string;
    fHeaders          : TDictionary<string, string>;
  public
    constructor Create;
    destructor  Destroy; override;
    property BaseUrl          : string  read fBaseUrl           write fBaseUrl;
    property ResponseTimeout  : Integer read fResponseTimeout   write fResponseTimeout;
    property ConnectionTimeout: Integer read fConnectionTimeout write fConnectionTimeout;
    property UserAgent        : string  read fUserAgent         write fUserAgent;
    property Headers          : TDictionary<string, string> read fHeaders;
    procedure AddHeader(const aName, aValue: string);
  end;

  // ── Forward ─────────────────────────────────────────────────────────────────

  THttpClientServiceExtension = class;

  // ── Builder ─────────────────────────────────────────────────────────────────

  /// <summary>
  /// Fluent builder for a named HTTP client.  Returned by
  /// THttpClientServiceExtension.AddHttpClient.
  ///
  /// Usage:
  ///   services.Extension&lt;THttpClientServiceExtension&gt;
  ///     .AddHttpClient('github', procedure(o: THttpClientOptions)
  ///        begin o.BaseUrl := 'https://api.github.com' end)
  ///     .AddRetry(3, 500, btExponential)
  ///     .AddCircuitBreaker(5, 30000)
  ///     .AddTimeout(10000)
  ///     .Services
  ///     .AddHttpClient('stripe', ...)  // chain another client
  ///     ...;
  ///
  /// Then inject / resolve:
  ///   var factory := services.Resolve&lt;IHttpClientFactory&gt;;
  ///   var client  := factory.CreateClient('github');
  ///   var resp    := client.Get('/repos/exilon/QuickCore');
  /// </summary>
  THttpClientBuilder = class
  private
    fServices         : TServiceCollection;
    fName             : string;
    fOptions          : THttpClientOptions;  // owned
    // Retry
    fHasRetry         : Boolean;
    fRetryMax         : Integer;
    fRetryDelayMs     : Int64;
    fRetryBackoff     : TBackoffType;
    fRetryMaxDelayMs  : Int64;
    fRetryOnRetry     : TRetryEvent;
    // Circuit Breaker
    fHasCB            : Boolean;
    fCBThreshold      : Integer;
    fCBDurationMs     : Int64;
    fCBOnChange       : TCircuitStateChangeEvent;
    // Timeout
    fHasTimeout       : Boolean;
    fTimeoutMs        : Int64;
    fTimeoutOnTimeout : TTimeoutEvent;
  public
    constructor Create(aServices: TServiceCollection; const aName: string;
      aOptions: THttpClientOptions);
    destructor Destroy; override;

    function WithBaseUrl(const aUrl: string): THttpClientBuilder;
    function WithResponseTimeout(aMs: Integer): THttpClientBuilder;
    function WithConnectionTimeout(aMs: Integer): THttpClientBuilder;
    function WithUserAgent(const aAgent: string): THttpClientBuilder;
    function WithHeader(const aName, aValue: string): THttpClientBuilder;

    /// <summary>Add a retry policy.  Defaults: 3 retries, 500 ms initial delay,
    /// exponential backoff, 30 s cap.  Only retries on EHttpException (5xx) and
    /// network exceptions by default.</summary>
    function AddRetry(aMaxRetries: Integer = 3;
      aInitialDelayMs: Int64 = 500;
      aBackoffType: TBackoffType = btExponential;
      aMaxDelayMs: Int64 = 30000;
      aOnRetry: TRetryEvent = nil): THttpClientBuilder;

    /// <summary>Add a circuit breaker.  Defaults: opens after 5 consecutive
    /// failures, stays open for 30 seconds.</summary>
    function AddCircuitBreaker(aFailureThreshold: Integer = 5;
      aDurationOfBreakMs: Int64 = 30000;
      aOnStateChange: TCircuitStateChangeEvent = nil): THttpClientBuilder;

    /// <summary>Add a per-attempt timeout.  Defaults: 10 seconds.</summary>
    function AddTimeout(aTimeoutMs: Int64 = 10000;
      aOnTimeout: TTimeoutEvent = nil): THttpClientBuilder;

    /// <summary>Return the service collection for further chaining.</summary>
    function Services: TServiceCollection;

    // Accessors for the factory
    property Name   : string             read fName;
    property Options: THttpClientOptions read fOptions;
    property HasRetry       : Boolean read fHasRetry;
    property RetryMax       : Integer read fRetryMax;
    property RetryDelayMs   : Int64   read fRetryDelayMs;
    property RetryBackoff   : TBackoffType read fRetryBackoff;
    property RetryMaxDelayMs: Int64   read fRetryMaxDelayMs;
    property RetryOnRetry   : TRetryEvent read fRetryOnRetry;
    property HasCB          : Boolean read fHasCB;
    property CBThreshold    : Integer read fCBThreshold;
    property CBDurationMs   : Int64   read fCBDurationMs;
    property CBOnChange     : TCircuitStateChangeEvent read fCBOnChange;
    property HasTimeout     : Boolean read fHasTimeout;
    property TimeoutMs      : Int64   read fTimeoutMs;
    property TimeoutOnTimeout: TTimeoutEvent read fTimeoutOnTimeout;
  end;

  // ── Factory ──────────────────────────────────────────────────────────────────

  /// <summary>
  /// Creates named or default IHttpClient instances.
  /// Each named client keeps its circuit-breaker state alive between calls.
  ///
  /// Equivalent to: IHttpClientFactory in Microsoft.Extensions.Http.
  /// </summary>
  IHttpClientFactory = interface
  ['{C3D4E5F6-A7B8-9012-CDEF-123456789013}']
    /// <summary>Create a client using the default (unnamed) registration.</summary>
    function CreateClient: IHttpClient; overload;
    /// <summary>Create a client from the named registration.</summary>
    function CreateClient(const aName: string): IHttpClient; overload;
  end;

  // ── DI Extension ─────────────────────────────────────────────────────────────

  /// <summary>
  /// DI helper for registering named HTTP clients.
  ///
  /// Usage — in ConfigureServices:
  ///   services.Extension&lt;THttpClientServiceExtension&gt;
  ///     .AddHttpClient('payments', procedure(o: THttpClientOptions)
  ///        begin o.BaseUrl := 'https://pay.example.com'; end)
  ///     .AddRetry(3)
  ///     .AddCircuitBreaker(5, 10000)
  ///     .AddTimeout(8000);
  ///
  /// Registers IHttpClientFactory as a singleton automatically.
  /// </summary>
  THttpClientServiceExtension = class(TServiceCollectionExtension)
  private class var
    fBuilders: TObjectDictionary<string, THttpClientBuilder>;
    class function EnsureRegistry: TObjectDictionary<string, THttpClientBuilder>;
  public
    class function AddHttpClient(const aName: string = '';
      aConfigure: TProc<THttpClientOptions> = nil): THttpClientBuilder;
  end;

implementation

// ── THttpResponse ────────────────────────────────────────────────────────────

constructor THttpResponse.Create(aStatusCode: Integer;
  const aStatusText, aBody: string);
begin
  inherited Create;
  fStatusCode := aStatusCode;
  fStatusText := aStatusText;
  fBody       := aBody;
  fJsonCache  := nil;
end;

destructor THttpResponse.Destroy;
begin
  fJsonCache.Free;
  inherited;
end;

function THttpResponse.StatusCode   : Integer; begin Result := fStatusCode; end;
function THttpResponse.StatusText   : string;  begin Result := fStatusText; end;
function THttpResponse.Body         : string;  begin Result := fBody; end;
function THttpResponse.IsSuccess    : Boolean; begin Result := (fStatusCode >= 200) and (fStatusCode <= 299); end;
function THttpResponse.IsServerError: Boolean; begin Result := (fStatusCode >= 500) and (fStatusCode <= 599); end;

function THttpResponse.ContentAsJson: TJSONValue;
begin
  if (fJsonCache = nil) and (fBody <> '') then
    fJsonCache := TJSONObject.ParseJSONValue(fBody);
  Result := fJsonCache;
end;

// ── EHttpException ────────────────────────────────────────────────────────────

constructor EHttpException.Create(aStatusCode: Integer; const aMessage: string);
begin
  inherited Create(aMessage);
  fStatusCode := aStatusCode;
end;

// ── THttpClientOptions ────────────────────────────────────────────────────────

constructor THttpClientOptions.Create;
begin
  inherited Create;
  fResponseTimeout   := 30000;
  fConnectionTimeout := 10000;
  fUserAgent         := 'QuickCore-HttpClient/1.0';
  fHeaders           := TDictionary<string, string>.Create;
end;

destructor THttpClientOptions.Destroy;
begin
  fHeaders.Free;
  inherited;
end;

procedure THttpClientOptions.AddHeader(const aName, aValue: string);
begin
  fHeaders.AddOrSetValue(aName, aValue);
end;

// ── THttpClientBuilder ────────────────────────────────────────────────────────

constructor THttpClientBuilder.Create(aServices: TServiceCollection;
  const aName: string; aOptions: THttpClientOptions);
begin
  inherited Create;
  fServices := aServices;
  fName     := aName;
  fOptions  := aOptions;
  // Defaults
  fRetryMax        := 3;
  fRetryDelayMs    := 500;
  fRetryBackoff    := btExponential;
  fRetryMaxDelayMs := 30000;
  fCBThreshold     := 5;
  fCBDurationMs    := 30000;
  fTimeoutMs       := 10000;
end;

destructor THttpClientBuilder.Destroy;
begin
  fOptions.Free;
  inherited;
end;

function THttpClientBuilder.WithBaseUrl(const aUrl: string): THttpClientBuilder;
begin
  fOptions.BaseUrl := aUrl;
  Result := Self;
end;

function THttpClientBuilder.WithResponseTimeout(aMs: Integer): THttpClientBuilder;
begin
  fOptions.ResponseTimeout := aMs;
  Result := Self;
end;

function THttpClientBuilder.WithConnectionTimeout(aMs: Integer): THttpClientBuilder;
begin
  fOptions.ConnectionTimeout := aMs;
  Result := Self;
end;

function THttpClientBuilder.WithUserAgent(const aAgent: string): THttpClientBuilder;
begin
  fOptions.UserAgent := aAgent;
  Result := Self;
end;

function THttpClientBuilder.WithHeader(const aName, aValue: string): THttpClientBuilder;
begin
  fOptions.AddHeader(aName, aValue);
  Result := Self;
end;

function THttpClientBuilder.AddRetry(aMaxRetries: Integer; aInitialDelayMs: Int64;
  aBackoffType: TBackoffType; aMaxDelayMs: Int64; aOnRetry: TRetryEvent): THttpClientBuilder;
begin
  fHasRetry        := True;
  fRetryMax        := aMaxRetries;
  fRetryDelayMs    := aInitialDelayMs;
  fRetryBackoff    := aBackoffType;
  fRetryMaxDelayMs := aMaxDelayMs;
  fRetryOnRetry    := aOnRetry;
  Result := Self;
end;

function THttpClientBuilder.AddCircuitBreaker(aFailureThreshold: Integer;
  aDurationOfBreakMs: Int64; aOnStateChange: TCircuitStateChangeEvent): THttpClientBuilder;
begin
  fHasCB        := True;
  fCBThreshold  := aFailureThreshold;
  fCBDurationMs := aDurationOfBreakMs;
  fCBOnChange   := aOnStateChange;
  Result := Self;
end;

function THttpClientBuilder.AddTimeout(aTimeoutMs: Int64;
  aOnTimeout: TTimeoutEvent): THttpClientBuilder;
begin
  fHasTimeout       := True;
  fTimeoutMs        := aTimeoutMs;
  fTimeoutOnTimeout := aOnTimeout;
  Result := Self;
end;

function THttpClientBuilder.Services: TServiceCollection;
begin
  Result := fServices;
end;

// ── TResilienceHttpClient ─────────────────────────────────────────────────────
// (internal — not exposed in the interface section)

type
  TResilienceHttpClient = class(TInterfacedObject, IHttpClient)
  private
    fHttp          : THTTPClient;
    fBaseUrl       : string;
    fCircuitBreaker: IResiliencePolicy<IHttpResponse>;
    fRetry         : IResiliencePolicy<IHttpResponse>;
    fTimeout       : IResiliencePolicy<IHttpResponse>;
    function BuildUrl(const aPath: string): string;
    function Execute(aFunc: TResilienceFunc<IHttpResponse>): IHttpResponse;
    function Perform(const aMethod, aUrl: string; aBody: TStream): IHttpResponse;
  public
    constructor Create(aOptions: THttpClientOptions;
      aCB     : IResiliencePolicy<IHttpResponse>;
      aRetry  : IResiliencePolicy<IHttpResponse>;
      aTimeout: IResiliencePolicy<IHttpResponse>);
    destructor Destroy; override;
    function Get   (const aUrl: string): IHttpResponse;
    function Post  (const aUrl: string; const aBody: string): IHttpResponse; overload;
    function Post  (const aUrl: string; aJson: TJSONObject): IHttpResponse; overload;
    function Put   (const aUrl: string; const aBody: string): IHttpResponse;
    function Delete(const aUrl: string): IHttpResponse;
  end;

constructor TResilienceHttpClient.Create(aOptions: THttpClientOptions;
  aCB: IResiliencePolicy<IHttpResponse>; aRetry: IResiliencePolicy<IHttpResponse>;
  aTimeout: IResiliencePolicy<IHttpResponse>);
var
  pair: TPair<string, string>;
begin
  inherited Create;
  fBaseUrl       := aOptions.BaseUrl;
  fCircuitBreaker := aCB;
  fRetry          := aRetry;
  fTimeout        := aTimeout;

  fHttp := THTTPClient.Create;
  fHttp.ContentType := 'application/json';
  fHttp.UserAgent   := aOptions.UserAgent;
  if aOptions.ResponseTimeout   > 0 then fHttp.ResponseTimeout   := aOptions.ResponseTimeout;
  if aOptions.ConnectionTimeout > 0 then fHttp.ConnectionTimeout := aOptions.ConnectionTimeout;
  for pair in aOptions.Headers do
    fHttp.CustomHeaders[pair.Key] := pair.Value;
end;

destructor TResilienceHttpClient.Destroy;
begin
  fHttp.Free;
  inherited;
end;

function TResilienceHttpClient.BuildUrl(const aPath: string): string;
begin
  if (fBaseUrl = '') or aPath.StartsWith('http://', True) or aPath.StartsWith('https://', True) then
    Result := aPath
  else
    Result := fBaseUrl.TrimRight(['/']) + '/' + aPath.TrimLeft(['/']);
end;

function TResilienceHttpClient.Execute(aFunc: TResilienceFunc<IHttpResponse>): IHttpResponse;
var
  f: TResilienceFunc<IHttpResponse>;
begin
  f := aFunc;
  // Build pipeline innermost first: Timeout → Retry → CircuitBreaker
  if Assigned(fTimeout) then
  begin
    var inner := f;
    f := function: IHttpResponse begin Result := fTimeout.Execute(inner) end;
  end;
  if Assigned(fRetry) then
  begin
    var inner := f;
    f := function: IHttpResponse begin Result := fRetry.Execute(inner) end;
  end;
  if Assigned(fCircuitBreaker) then
  begin
    var inner := f;
    f := function: IHttpResponse begin Result := fCircuitBreaker.Execute(inner) end;
  end;
  Result := f();
end;

function TResilienceHttpClient.Perform(const aMethod, aUrl: string;
  aBody: TStream): IHttpResponse;
var
  respStream: TStringStream;
  resp      : IHTTPResponse;
begin
  respStream := TStringStream.Create('', TEncoding.UTF8);
  try
    if aMethod = 'GET' then
      resp := fHttp.Get(aUrl, respStream)
    else if aMethod = 'DELETE' then
      resp := fHttp.Delete(aUrl, respStream)
    else if aMethod = 'POST' then
      resp := fHttp.Post(aUrl, aBody, respStream)
    else if aMethod = 'PUT' then
      resp := fHttp.Put(aUrl, aBody, respStream)
    else
      raise EHttpException.Create(0, 'Unsupported HTTP method: ' + aMethod);

    Result := THttpResponse.Create(resp.StatusCode, resp.StatusText,
                                    respStream.DataString);
    if Result.IsServerError then
      raise EHttpException.Create(Result.StatusCode,
        Format('HTTP %d %s', [Result.StatusCode, Result.StatusText]));
  finally
    respStream.Free;
  end;
end;

function TResilienceHttpClient.Get(const aUrl: string): IHttpResponse;
var
  url: string;
begin
  url := BuildUrl(aUrl);
  Result := Execute(function: IHttpResponse begin Result := Perform('GET', url, nil) end);
end;

function TResilienceHttpClient.Post(const aUrl: string; const aBody: string): IHttpResponse;
var
  url : string;
  body: TStringStream;
begin
  url  := BuildUrl(aUrl);
  body := TStringStream.Create(aBody, TEncoding.UTF8);
  try
    Result := Execute(function: IHttpResponse begin Result := Perform('POST', url, body) end);
  finally
    body.Free;
  end;
end;

function TResilienceHttpClient.Post(const aUrl: string; aJson: TJSONObject): IHttpResponse;
begin
  Result := Post(aUrl, aJson.ToJSON);
end;

function TResilienceHttpClient.Put(const aUrl: string; const aBody: string): IHttpResponse;
var
  url : string;
  body: TStringStream;
begin
  url  := BuildUrl(aUrl);
  body := TStringStream.Create(aBody, TEncoding.UTF8);
  try
    Result := Execute(function: IHttpResponse begin Result := Perform('PUT', url, body) end);
  finally
    body.Free;
  end;
end;

function TResilienceHttpClient.Delete(const aUrl: string): IHttpResponse;
var
  url: string;
begin
  url := BuildUrl(aUrl);
  Result := Execute(function: IHttpResponse begin Result := Perform('DELETE', url, nil) end);
end;

// ── THttpClientFactory ────────────────────────────────────────────────────────

type
  TClientState = record
    CircuitBreaker: IResiliencePolicy<IHttpResponse>;
  end;

  THttpClientFactory = class(TInterfacedObject, IHttpClientFactory)
  private
    fBuilders   : TObjectDictionary<string, THttpClientBuilder>;  // not owned
    fLock       : TCriticalSection;
    fStates     : TDictionary<string, TClientState>;
    function GetOrCreateState(const aName: string;
      aBuilder: THttpClientBuilder): TClientState;
  public
    constructor Create(aBuilders: TObjectDictionary<string, THttpClientBuilder>);
    destructor Destroy; override;
    function CreateClient: IHttpClient; overload;
    function CreateClient(const aName: string): IHttpClient; overload;
  end;

constructor THttpClientFactory.Create(
  aBuilders: TObjectDictionary<string, THttpClientBuilder>);
begin
  inherited Create;
  fBuilders := aBuilders;
  fLock     := TCriticalSection.Create;
  fStates   := TDictionary<string, TClientState>.Create;
end;

destructor THttpClientFactory.Destroy;
begin
  fStates.Free;
  fLock.Free;
  inherited;
end;

function THttpClientFactory.GetOrCreateState(const aName: string;
  aBuilder: THttpClientBuilder): TClientState;
begin
  fLock.Enter;
  try
    if not fStates.TryGetValue(aName, Result) then
    begin
      // Circuit breaker is stateful — created once per named client
      if aBuilder.HasCB then
        Result.CircuitBreaker := TCircuitBreakerPolicy<IHttpResponse>.Create(
          aBuilder.CBThreshold, aBuilder.CBDurationMs, aBuilder.CBOnChange);
      fStates.Add(aName, Result);
    end;
  finally
    fLock.Leave;
  end;
end;

function THttpClientFactory.CreateClient: IHttpClient;
begin
  Result := CreateClient('');
end;

function THttpClientFactory.CreateClient(const aName: string): IHttpClient;
var
  builder: THttpClientBuilder;
  state  : TClientState;
  retry  : IResiliencePolicy<IHttpResponse>;
  timeout: IResiliencePolicy<IHttpResponse>;
begin
  if not fBuilders.TryGetValue(aName, builder) then
    raise EArgumentException.CreateFmt(
      'HttpClientFactory: no client registered with name "%s"', [aName]);

  state := GetOrCreateState(aName, builder);

  // Retry and Timeout: stateless, created fresh each time (lightweight)
  retry   := nil;
  timeout := nil;
  if builder.HasRetry then
    retry := TRetryPolicy<IHttpResponse>.Create(builder.RetryMax,
      builder.RetryDelayMs, builder.RetryBackoff, builder.RetryMaxDelayMs,
      builder.RetryOnRetry);
  if builder.HasTimeout then
    timeout := TTimeoutPolicy<IHttpResponse>.Create(builder.TimeoutMs,
      builder.TimeoutOnTimeout);

  Result := TResilienceHttpClient.Create(builder.Options,
    state.CircuitBreaker, retry, timeout);
end;

// ── THttpClientServiceExtension ───────────────────────────────────────────────

class function THttpClientServiceExtension.EnsureRegistry: TObjectDictionary<string, THttpClientBuilder>;
begin
  if not Assigned(fBuilders) then
    fBuilders := TObjectDictionary<string, THttpClientBuilder>.Create([doOwnsValues]);
  Result := fBuilders;
end;

class function THttpClientServiceExtension.AddHttpClient(const aName: string;
  aConfigure: TProc<THttpClientOptions>): THttpClientBuilder;
var
  opts   : THttpClientOptions;
  builder: THttpClientBuilder;
  reg    : TObjectDictionary<string, THttpClientBuilder>;
begin
  reg  := EnsureRegistry;
  opts := THttpClientOptions.Create;
  if Assigned(aConfigure) then
    aConfigure(opts);

  builder := THttpClientBuilder.Create(ServiceCollection, aName, opts);
  reg.AddOrSetValue(aName, builder);

  // Register IHttpClientFactory as singleton (lazy, only once)
  if not ServiceCollection.IsRegistered<IHttpClientFactory> then
    ServiceCollection.AddSingleton<IHttpClientFactory>(
      function: IHttpClientFactory
      begin
        Result := THttpClientFactory.Create(fBuilders);
      end);

  Result := builder;
end;

end.
