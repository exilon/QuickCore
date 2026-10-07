program HybridCacheSample;

(* HybridCacheSample
  Demonstrates IHybridCache — two-level cache in QuickCore.

  .NET equivalent: IHybridCache (.NET 9, Microsoft.Extensions.Caching.Hybrid)
    builder.Services.AddHybridCache(o =>
    {
        o.DefaultEntryOptions = new HybridCacheEntryOptions
        {
            Expiration = TimeSpan.FromMinutes(5),
            LocalCacheExpiration = TimeSpan.FromMinutes(1)
        };
    });

  Levels:
    L1 = IMemoryCache  — fast, in-process, lost on restart
    L2 = IDistributedCache — slower, shared across instances (here: fake in-memory)

  Read path (GetOrCreate):
    1. Check L1 → hit → return (fastest)
    2. Check L2 → hit → backfill L1, return
    3. Full miss → invoke factory, write L1 + L2, return
*)

{$APPTYPE CONSOLE}
// {$R *.res}  — .res not generated for dcc32 console builds; omit to avoid linker error

uses
  System.SysUtils,
  System.Classes,
  System.Threading,
  Quick.Console,
  Quick.Core.Caching.Abstractions,
  Quick.Core.Caching.Hybrid,
  Quick.Core.Extensions.Caching.Memory;

// ── Fake distributed cache (same as in tests — wraps IMemoryCache) ───────────

type
  TFakeDistributedCache = class(TInterfacedObject, IDistributedCache)
  private
    fInner: IMemoryCache;
  public
    constructor Create;
    procedure SetValue(const aKey: string; aValue: TObject; aExpirationMilliseconds: Integer = 0); overload;
    procedure SetValue(const aKey: string; aValue: TObject; aExpirationDate: TDateTime); overload;
    procedure SetValue(const aKey, aValue: string; aExpirationMilliseconds: Integer = 0); overload;
    procedure SetValue(const aKey, aValue: string; aExpirationDate: TDateTime); overload;
    procedure SetValue(const aKey: string; aValue: TArray<string>; aExpirationMilliseconds: Integer = 0); overload;
    procedure SetValue(const aKey: string; aValue: TArray<string>; aExpirationDate: TDateTime); overload;
    procedure SetValue(const aKey: string; aValue: TArray<TObject>; aExpirationMilliseconds: Integer = 0); overload;
    procedure SetValue(const aKey: string; aValue: TArray<TObject>; aExpirationDate: TDateTime); overload;
    function GetValue(const aKey: string): string; overload;
    function TryGetValue(const aKey: string; aValue: TObject): Boolean; overload;
    function TryGetValue(const aKey: string; out aValue: string): Boolean; overload;
    function TryGetValue(const aKey: string; out aValue: TArray<string>): Boolean; overload;
    function TryGetValue(const aKey: string; out aValue: TArray<TObject>): Boolean; overload;
    procedure Refresh(const aKey: string; aExpirationMilliseconds: Integer);
    procedure RemoveValue(const aKey: string);
    procedure Flush;
  end;

constructor TFakeDistributedCache.Create;
begin
  inherited;
  fInner := THttpMemoryCache.Create(nil);
end;

procedure TFakeDistributedCache.SetValue(const aKey: string; aValue: TObject; aExpirationMilliseconds: Integer);
begin fInner.SetValue(aKey, aValue, aExpirationMilliseconds); end;
procedure TFakeDistributedCache.SetValue(const aKey: string; aValue: TObject; aExpirationDate: TDateTime);
begin fInner.SetValue(aKey, aValue, aExpirationDate); end;
procedure TFakeDistributedCache.SetValue(const aKey, aValue: string; aExpirationMilliseconds: Integer);
begin fInner.SetValue(aKey, aValue, aExpirationMilliseconds); end;
procedure TFakeDistributedCache.SetValue(const aKey, aValue: string; aExpirationDate: TDateTime);
begin fInner.SetValue(aKey, aValue, aExpirationDate); end;
procedure TFakeDistributedCache.SetValue(const aKey: string; aValue: TArray<string>; aExpirationMilliseconds: Integer);
begin fInner.SetValue(aKey, aValue, aExpirationMilliseconds); end;
procedure TFakeDistributedCache.SetValue(const aKey: string; aValue: TArray<string>; aExpirationDate: TDateTime);
begin fInner.SetValue(aKey, aValue, aExpirationDate); end;
procedure TFakeDistributedCache.SetValue(const aKey: string; aValue: TArray<TObject>; aExpirationMilliseconds: Integer);
begin fInner.SetValue(aKey, aValue, aExpirationMilliseconds); end;
procedure TFakeDistributedCache.SetValue(const aKey: string; aValue: TArray<TObject>; aExpirationDate: TDateTime);
begin fInner.SetValue(aKey, aValue, aExpirationDate); end;
function TFakeDistributedCache.GetValue(const aKey: string): string;
begin Result := fInner.GetValue(aKey); end;
function TFakeDistributedCache.TryGetValue(const aKey: string; aValue: TObject): Boolean;
begin Result := fInner.TryGetValue(aKey, aValue); end;
function TFakeDistributedCache.TryGetValue(const aKey: string; out aValue: string): Boolean;
begin Result := fInner.TryGetValue(aKey, aValue); end;
function TFakeDistributedCache.TryGetValue(const aKey: string; out aValue: TArray<string>): Boolean;
begin Result := fInner.TryGetValue(aKey, aValue); end;
function TFakeDistributedCache.TryGetValue(const aKey: string; out aValue: TArray<TObject>): Boolean;
begin Result := fInner.TryGetValue(aKey, aValue); end;
procedure TFakeDistributedCache.Refresh(const aKey: string; aExpirationMilliseconds: Integer);
begin
  // IMemoryCache wraps a plain in-memory store that does not support TTL refresh;
  // no-op is acceptable for this demo.
end;
procedure TFakeDistributedCache.RemoveValue(const aKey: string);
begin fInner.RemoveValue(aKey); end;
procedure TFakeDistributedCache.Flush;
begin fInner.Flush; end;

// ── Simulated DB ──────────────────────────────────────────────────────────────

var
  GDbCallCount: Integer = 0;

function FetchFromDatabase(const aProductId: string): string;
begin
  Inc(GDbCallCount);
  TThread.Sleep(50); // simulate latency
  Result := Format('{"id":"%s","name":"Product %s","price":%.2f}',
    [aProductId, aProductId, 9.99 * GDbCallCount]);
  WriteLn(Format('  [DB] Query #%d for product "%s"', [GDbCallCount, aProductId]));
end;

// ─────────────────────────────────────────────────────────────────────────────
// Demo sections
// ─────────────────────────────────────────────────────────────────────────────

procedure DemoReadPath(const aCache: IHybridCache);
var
  v1, v2 : string;
begin
  WriteLn;
  WriteLn('─── 1. READ PATH — Cold → L2 hit → L1 hit ───────────────────────');

  // Call 1: full miss → DB called, written to L1 + L2
  WriteLn('  Call 1 (cold cache):');
  v1 := aCache.GetOrCreate('product:42',
    function: string begin Result := FetchFromDatabase('42') end);
  WriteLn('  Result: ' + v1);

  // Call 2: L1 hit → no DB
  WriteLn('  Call 2 (L1 hit expected — no DB call):');
  v2 := aCache.GetOrCreate('product:42',
    function: string begin Result := FetchFromDatabase('42') end);
  WriteLn('  Result: ' + v2);
end;

procedure DemoL2Promotion(aL1: IMemoryCache; aL2: IDistributedCache; const aCache: IHybridCache);
var
  v   : string;
  l1v : string;
begin
  WriteLn;
  WriteLn('─── 2. L2 PROMOTION — L1 evicted, backfill from L2 ──────────────');

  // Populate via cache (goes to L1 + L2)
  aCache.SetValue('product:99', '{"id":"99","name":"Widget","price":1.99}');
  WriteLn('  Seeded product:99 into L1 + L2.');

  // Simulate L1 eviction (e.g. process restart or memory pressure)
  aL1.RemoveValue('product:99');
  WriteLn('  Evicted product:99 from L1 (simulates memory pressure).');

  // Next call should hit L2 and promote back to L1
  WriteLn('  GetOrCreate after L1 eviction:');
  v := aCache.GetOrCreate('product:99',
    function: string begin Result := FetchFromDatabase('99') end);
  WriteLn('  Result: ' + v);

  // Verify L1 was backfilled
  if aL1.TryGetValue('product:99', l1v) then
    WriteLn('  L1 backfilled: ' + l1v)
  else
    WriteLn('  L1 was NOT backfilled (unexpected)');
end;

procedure DemoInvalidation(const aCache: IHybridCache);
var
  v : string;
begin
  WriteLn;
  WriteLn('─── 3. INVALIDATION — Remove from both tiers ────────────────────');

  aCache.SetValue('product:7', 'old-value');
  WriteLn('  Set product:7 = "old-value"');

  aCache.Remove('product:7');
  WriteLn('  Removed product:7.');

  if not aCache.TryGetValue('product:7', v) then
    WriteLn('  Key not found in any tier after Remove (correct)')
  else
    WriteLn('  Key still found: ' + v);
end;

procedure DemoOptions;
var
  opts  : THybridCacheOptions;
  l1    : IMemoryCache;
  cache : IHybridCache;
  v     : string;
begin
  WriteLn;
  WriteLn('─── 4. OPTIONS — Default TTLs and L1-only mode ──────────────────');

  opts := THybridCacheOptions.Create;
  opts.DefaultLocalExpirationMs  := 30000;  // 30s L1 TTL
  opts.DefaultRemoteExpirationMs := 300000; // 5min L2 TTL
  opts.DistributedCacheEnabled   := False;   // L1-only (no L2 for this demo)

  l1    := THttpMemoryCache.Create(nil);
  cache := THybridCache.Create(l1, nil, opts);

  cache.SetValue('k', 'in-memory-only');
  if cache.TryGetValue('k', v) then
    WriteLn('  L1-only mode works: ' + v)
  else
    WriteLn('  L1-only value not found');

  WriteLn('  Options: LocalTTL=30s, RemoteTTL=5min, DistributedEnabled=False');
end;

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────
var
  l1    : IMemoryCache;
  l2    : IDistributedCache;
  cache : IHybridCache;
begin
  try
    WriteLn('QuickCore — HybridCache sample (IHybridCache)');
    WriteLn('══════════════════════════════════════════════');

    l1 := THttpMemoryCache.Create(nil);
    l2 := TFakeDistributedCache.Create;
    cache := THybridCache.Create(l1, l2);

    DemoReadPath(cache);
    DemoL2Promotion(l1, l2, cache);
    DemoInvalidation(cache);
    DemoOptions;

    WriteLn;
    WriteLn(Format('Total DB calls: %d (should be 1 — first GetOrCreate only)', [GDbCallCount]));
    WriteLn('Sample completed successfully.');
  except
    on E: Exception do
    begin
      WriteLn('FATAL: ' + E.Message);
      ExitCode := 1;
    end;
  end;

  {$IFDEF DEBUG}
  WriteLn;
  Write('Press Enter to exit...');
  ReadLn;
  {$ENDIF}
end.
