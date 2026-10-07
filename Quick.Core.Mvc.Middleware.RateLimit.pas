{ **************************** }
{      Quick.Core Library      }
{     Rate Limiting Middleware  }
{ **************************** }
{ Author: QuickCore Team       }
{ **************************** }
unit Quick.Core.Mvc.Middleware.RateLimit;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Math,
  System.DateUtils,
  System.Generics.Collections,
  System.SyncObjs,
  Quick.Core.Mvc.Context,
  Quick.Core.Mvc.Middleware;

type
  { Rate limit policy.
    Window: sliding window duration in seconds.
    MaxRequests: maximum requests allowed within that window.
    KeySelector: optional function to derive the limit key from the request
      (default: ClientIP). }
  TRateLimitPolicy = class
  private
    fMaxRequests  : Integer;
    fWindowSecs   : Integer;
    fKeySelector  : TFunc<THttpContextBase, string>;
  public
    constructor Create(aMaxRequests : Integer = 100; aWindowSecs : Integer = 60);
    property MaxRequests : Integer read fMaxRequests write fMaxRequests;
    property WindowSecs  : Integer read fWindowSecs  write fWindowSecs;
    { Override default IP-based key with any custom key (e.g. API key header). }
    property KeySelector : TFunc<THttpContextBase, string> read fKeySelector write fKeySelector;
  end;

  TRateLimitEntry = record
    Count     : Integer;
    WindowEnd : TDateTime;
  end;

  TRateLimitMiddleware = class(TRequestDelegate)
  private
    fPolicy         : TRateLimitPolicy;
    fStore          : TDictionary<string, TRateLimitEntry>;
    fLock           : TCriticalSection;
    fRequestCount   : Integer;
    function GetKey(aContext : THttpContextBase) : string;
    function IsAllowed(const aKey : string) : Boolean;
    function BuildErrorJson(aRetryAfter : Integer) : string;
    procedure PurgeExpiredEntries;
  public
    constructor Create(aNext : TRequestDelegate; aPolicy : TRateLimitPolicy);
    destructor Destroy; override;
    procedure Invoke(aContext : THttpContextBase); override;
  end;

  { Attribute for per-action rate limit override. }
  RateLimit = class(TCustomAttribute)
  private
    fMaxRequests : Integer;
    fWindowSecs  : Integer;
  public
    constructor Create(aMaxRequests : Integer; aWindowSecs : Integer = 60);
    property MaxRequests : Integer read fMaxRequests;
    property WindowSecs  : Integer read fWindowSecs;
  end;

implementation

{ TRateLimitPolicy }

constructor TRateLimitPolicy.Create(aMaxRequests : Integer = 100; aWindowSecs : Integer = 60);
begin
  fMaxRequests := aMaxRequests;
  fWindowSecs  := aWindowSecs;
  fKeySelector := nil;
end;

{ RateLimit attribute }

constructor RateLimit.Create(aMaxRequests : Integer; aWindowSecs : Integer = 60);
begin
  fMaxRequests := aMaxRequests;
  fWindowSecs  := aWindowSecs;
end;

{ TRateLimitMiddleware }

constructor TRateLimitMiddleware.Create(aNext : TRequestDelegate; aPolicy : TRateLimitPolicy);
begin
  inherited Create(aNext);
  fPolicy        := aPolicy;
  fStore         := TDictionary<string, TRateLimitEntry>.Create;
  fLock          := TCriticalSection.Create;
  fRequestCount  := 0;
end;

procedure TRateLimitMiddleware.PurgeExpiredEntries;
var
  expiredKeys : TArray<string>;
  key         : string;
  entry       : TRateLimitEntry;
  grace       : TDateTime;
begin
  // Called under fLock — remove entries expired more than 2 windows ago
  grace := IncSecond(Now, -(fPolicy.WindowSecs * 2));
  SetLength(expiredKeys, 0);
  for key in fStore.Keys do
  begin
    if fStore.TryGetValue(key, entry) and (entry.WindowEnd < grace) then
    begin
      SetLength(expiredKeys, Length(expiredKeys) + 1);
      expiredKeys[High(expiredKeys)] := key;
    end;
  end;
  for key in expiredKeys do
    fStore.Remove(key);
end;

destructor TRateLimitMiddleware.Destroy;
begin
  fStore.Free;
  fLock.Free;
  fPolicy.Free;
  inherited;
end;

function TRateLimitMiddleware.GetKey(aContext : THttpContextBase) : string;
begin
  if Assigned(fPolicy.KeySelector) then
    Result := fPolicy.KeySelector(aContext)
  else
    Result := aContext.Request.ClientIP;
  if Result = '' then Result := 'unknown';
end;

function TRateLimitMiddleware.IsAllowed(const aKey : string) : Boolean;
var
  entry    : TRateLimitEntry;
  currentTime : TDateTime;
begin
  currentTime := Now;
  fLock.Enter;
  try
    // SEC-18: Periodic cleanup every 500 requests to remove orphaned entries
    Inc(fRequestCount);
    if fRequestCount >= 500 then
    begin
      PurgeExpiredEntries;
      fRequestCount := 0;
    end;
    if fStore.TryGetValue(aKey, entry) then
    begin
      if currentTime > entry.WindowEnd then
      begin
        // Window expired — reset counter
        entry.Count    := 1;
        entry.WindowEnd := IncSecond(currentTime, fPolicy.WindowSecs);
        fStore[aKey]   := entry;
        Result := True;
      end
      else if entry.Count < fPolicy.MaxRequests then
      begin
        Inc(entry.Count);
        fStore[aKey] := entry;
        Result := True;
      end
      else
        Result := False; // over limit
    end
    else
    begin
      // First request for this key
      entry.Count    := 1;
      entry.WindowEnd := IncSecond(currentTime, fPolicy.WindowSecs);
      fStore.Add(aKey, entry);
      Result := True;
    end;
  finally
    fLock.Leave;
  end;
end;

function TRateLimitMiddleware.BuildErrorJson(aRetryAfter : Integer) : string;
begin
  Result := Format('{"error":{"status":429,"message":"Too Many Requests","retryAfterSeconds":%d}}', [aRetryAfter]);
end;

procedure TRateLimitMiddleware.Invoke(aContext : THttpContextBase);
var
  key         : string;
  entry       : TRateLimitEntry;
  retryAfter  : Integer;
begin
  inherited;
  key := GetKey(aContext);
  if IsAllowed(key) then
  begin
    Next(aContext);
  end
  else
  begin
    // Calculate retry-after seconds
    retryAfter := fPolicy.WindowSecs;
    fLock.Enter;
    try
      if fStore.TryGetValue(key, entry) then
        retryAfter := Max(0, SecondsBetween(entry.WindowEnd, Now));
    finally
      fLock.Leave;
    end;
    aContext.Response.StatusCode := 429;
    aContext.Response.ContentType := 'application/json';
    aContext.Response.ContentText := BuildErrorJson(retryAfter);
    aContext.Response.Headers.Add('Retry-After', IntToStr(retryAfter));
  end;
end;

end.
