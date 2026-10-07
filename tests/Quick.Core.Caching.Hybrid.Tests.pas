unit Quick.Core.Caching.Hybrid.Tests;

{ Tests: T-HYB-01..12
    T-HYB-01  GetOrCreate miss: factory invoked, value stored in L1
    T-HYB-02  GetOrCreate hit L1: factory NOT invoked on second call
    T-HYB-03  GetOrCreate miss L1, hit L2: value promoted to L1, factory NOT invoked
    T-HYB-04  GetOrCreate full miss: factory invoked, result written to L1 and L2
    T-HYB-05  SetValue writes to L1 and L2 simultaneously
    T-HYB-06  TryGetValue returns True on L1 hit
    T-HYB-07  TryGetValue returns True on L2 hit (L1 miss), and backfills L1
    T-HYB-08  TryGetValue returns False when both tiers are empty
    T-HYB-09  Remove evicts from L1 and L2
    T-HYB-10  FlushLocal clears L1 only; L2 remains intact
    T-HYB-11  LocalCacheEnabled=False bypasses L1 entirely
    T-HYB-12  GetOrCreate nil factory raises EArgumentNilException
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Quick.Core.Caching.Abstractions,
  Quick.Core.Caching.Hybrid,
  Quick.Core.Extensions.Caching.Memory;

// ── Fake IDistributedCache ────────────────────────────────────────────────────

type
  /// <summary>
  /// In-memory fake distributed cache backed by THttpMemoryCache.
  /// Used to isolate the L2 tier without a real Redis connection.
  /// </summary>
  TFakeDistributedCache = class(TInterfacedObject, IDistributedCache)
  private
    fInner : IMemoryCache;
  public
    constructor Create;
    procedure SetValue(const aKey : string; aValue : TObject; aExpirationMilliseconds : Integer = 0); overload;
    procedure SetValue(const aKey : string; aValue : TObject; aExpirationDate : TDateTime); overload;
    procedure SetValue(const aKey, aValue : string; aExpirationMilliseconds : Integer = 0); overload;
    procedure SetValue(const aKey, aValue : string; aExpirationDate : TDateTime); overload;
    procedure SetValue(const aKey : string; aValue : TArray<string>; aExpirationMilliseconds : Integer = 0); overload;
    procedure SetValue(const aKey : string; aValue : TArray<string>; aExpirationDate : TDateTime); overload;
    procedure SetValue(const aKey : string; aValue : TArray<TObject>; aExpirationMilliseconds : Integer = 0); overload;
    procedure SetValue(const aKey : string; aValue : TArray<TObject>; aExpirationDate : TDateTime); overload;
    function GetValue(const aKey : string) : string; overload;
    function TryGetValue(const aKey : string; aValue : TObject) : Boolean; overload;
    function TryGetValue(const aKey : string; out aValue : string) : Boolean; overload;
    function TryGetValue(const aKey : string; out aValue : TArray<string>) : Boolean; overload;
    function TryGetValue(const aKey : string; out aValue : TArray<TObject>) : Boolean; overload;
    procedure Refresh(const aKey: string; aExpirationMilliseconds : Integer);
    procedure RemoveValue(const aKey : string);
    procedure Flush;
  end;

// ── Test fixture ──────────────────────────────────────────────────────────────

  [TestFixture]
  THybridCacheTests = class
  private
    FL1    : IMemoryCache;
    FL2    : IDistributedCache;
    FCache : IHybridCache;
    FFactoryCallCount : Integer;

    function MakeFactory(const aValue: string): TFunc<string>;
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure T_HYB_01_GetOrCreate_FullMiss_FactoryInvoked;
    [Test]
    procedure T_HYB_02_GetOrCreate_L1Hit_FactoryNotInvoked;
    [Test]
    procedure T_HYB_03_GetOrCreate_L2Hit_PromotedToL1_FactoryNotInvoked;
    [Test]
    procedure T_HYB_04_GetOrCreate_FullMiss_WritesToBothTiers;
    [Test]
    procedure T_HYB_05_SetValue_WritesBothTiers;
    [Test]
    procedure T_HYB_06_TryGetValue_L1Hit_ReturnsTrue;
    [Test]
    procedure T_HYB_07_TryGetValue_L2Hit_BackfillsL1;
    [Test]
    procedure T_HYB_08_TryGetValue_BothMiss_ReturnsFalse;
    [Test]
    procedure T_HYB_09_Remove_EvictsFromBothTiers;
    [Test]
    procedure T_HYB_10_FlushLocal_ClearsL1_L2Intact;
    [Test]
    procedure T_HYB_11_LocalDisabled_BypassesL1;
    [Test]
    procedure T_HYB_12_GetOrCreate_NilFactory_Raises;
  end;

implementation

// ── TFakeDistributedCache ─────────────────────────────────────────────────────

constructor TFakeDistributedCache.Create;
begin
  inherited Create;
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
begin { no-op: IMemoryCache (ICache) does not expose Refresh } end;

procedure TFakeDistributedCache.RemoveValue(const aKey: string);
begin fInner.RemoveValue(aKey); end;

procedure TFakeDistributedCache.Flush;
begin fInner.Flush; end;

// ── Test fixture impl ─────────────────────────────────────────────────────────

procedure THybridCacheTests.SetUp;
begin
  FL1    := THttpMemoryCache.Create(nil);
  FL2    := TFakeDistributedCache.Create;
  FCache := THybridCache.Create(FL1, FL2);
  FFactoryCallCount := 0;
end;

procedure THybridCacheTests.TearDown;
begin
  FCache := nil;
  FL1    := nil;
  FL2    := nil;
end;

function THybridCacheTests.MakeFactory(const aValue: string): TFunc<string>;
begin
  Result := function: string
    begin
      Inc(FFactoryCallCount);
      Result := aValue;
    end;
end;

{ T-HYB-01: cold cache — factory runs once }
procedure THybridCacheTests.T_HYB_01_GetOrCreate_FullMiss_FactoryInvoked;
var
  r: string;
begin
  r := FCache.GetOrCreate('k1', MakeFactory('v1'));
  Assert.AreEqual('v1', r);
  Assert.AreEqual(1, FFactoryCallCount, 'factory must be called exactly once');
end;

{ T-HYB-02: L1 hit on second call — factory NOT called again }
procedure THybridCacheTests.T_HYB_02_GetOrCreate_L1Hit_FactoryNotInvoked;
begin
  FCache.GetOrCreate('k2', MakeFactory('v2'));   // populates L1
  FCache.GetOrCreate('k2', MakeFactory('v2'));   // should hit L1
  Assert.AreEqual(1, FFactoryCallCount, 'factory must not be called for L1 hit');
end;

{ T-HYB-03: L1 miss, L2 hit — factory NOT called, value promoted to L1 }
procedure THybridCacheTests.T_HYB_03_GetOrCreate_L2Hit_PromotedToL1_FactoryNotInvoked;
var
  r   : string;
  l1v : string;
begin
  // Seed L2 directly; L1 is empty
  FL2.SetValue('k3', 'fromL2', 0);

  r := FCache.GetOrCreate('k3', MakeFactory('should-not-be-used'));
  Assert.AreEqual('fromL2', r);
  Assert.AreEqual(0, FFactoryCallCount, 'factory must not run on L2 hit');

  // After L2 hit, L1 should have been backfilled
  Assert.IsTrue(FL1.TryGetValue('k3', l1v), 'L1 must be backfilled from L2');
  Assert.AreEqual('fromL2', l1v);
end;

{ T-HYB-04: full miss — writes to both tiers }
procedure THybridCacheTests.T_HYB_04_GetOrCreate_FullMiss_WritesToBothTiers;
var
  l1v, l2v : string;
begin
  FCache.GetOrCreate('k4', MakeFactory('v4'));

  Assert.IsTrue(FL1.TryGetValue('k4', l1v), 'L1 must contain the value');
  Assert.AreEqual('v4', l1v);

  Assert.IsTrue(FL2.TryGetValue('k4', l2v), 'L2 must contain the value');
  Assert.AreEqual('v4', l2v);
end;

{ T-HYB-05: SetValue writes to both tiers }
procedure THybridCacheTests.T_HYB_05_SetValue_WritesBothTiers;
var
  l1v, l2v : string;
begin
  FCache.SetValue('k5', 'v5');

  Assert.IsTrue(FL1.TryGetValue('k5', l1v));
  Assert.AreEqual('v5', l1v);

  Assert.IsTrue(FL2.TryGetValue('k5', l2v));
  Assert.AreEqual('v5', l2v);
end;

{ T-HYB-06: TryGetValue L1 hit }
procedure THybridCacheTests.T_HYB_06_TryGetValue_L1Hit_ReturnsTrue;
var
  v: string;
begin
  FL1.SetValue('k6', 'v6', 0);
  Assert.IsTrue(FCache.TryGetValue('k6', v));
  Assert.AreEqual('v6', v);
end;

{ T-HYB-07: TryGetValue L2 hit backfills L1 }
procedure THybridCacheTests.T_HYB_07_TryGetValue_L2Hit_BackfillsL1;
var
  v   : string;
  l1v : string;
begin
  FL2.SetValue('k7', 'v7', 0);

  Assert.IsTrue(FCache.TryGetValue('k7', v));
  Assert.AreEqual('v7', v);

  // L1 must now have the value too (promoted from L2)
  Assert.IsTrue(FL1.TryGetValue('k7', l1v), 'L1 backfill from L2');
  Assert.AreEqual('v7', l1v);
end;

{ T-HYB-08: TryGetValue both miss }
procedure THybridCacheTests.T_HYB_08_TryGetValue_BothMiss_ReturnsFalse;
var
  v: string;
begin
  Assert.IsFalse(FCache.TryGetValue('no-such-key', v));
  Assert.AreEqual('', v);
end;

{ T-HYB-09: Remove evicts from both tiers }
procedure THybridCacheTests.T_HYB_09_Remove_EvictsFromBothTiers;
var
  l1v, l2v : string;
begin
  FCache.SetValue('k9', 'v9');
  FCache.Remove('k9');

  Assert.IsFalse(FL1.TryGetValue('k9', l1v), 'L1 must be empty after Remove');
  Assert.IsFalse(FL2.TryGetValue('k9', l2v), 'L2 must be empty after Remove');
end;

{ T-HYB-10: FlushLocal clears L1, leaves L2 intact }
procedure THybridCacheTests.T_HYB_10_FlushLocal_ClearsL1_L2Intact;
var
  l1v, l2v : string;
begin
  FCache.SetValue('k10', 'v10');
  FCache.FlushLocal;

  Assert.IsFalse(FL1.TryGetValue('k10', l1v), 'L1 must be cleared by FlushLocal');
  Assert.IsTrue(FL2.TryGetValue('k10', l2v), 'L2 must not be affected by FlushLocal');
  Assert.AreEqual('v10', l2v);
end;

{ T-HYB-11: LocalCacheEnabled=False bypasses L1 }
procedure THybridCacheTests.T_HYB_11_LocalDisabled_BypassesL1;
var
  opts  : THybridCacheOptions;
  cache : IHybridCache;
  l1v   : string;
  l2v   : string;
begin
  opts := THybridCacheOptions.Create;
  opts.LocalCacheEnabled := False;
  cache := THybridCache.Create(FL1, FL2, opts);

  cache.SetValue('k11', 'v11');

  // L1 must be untouched because LocalCacheEnabled=False
  Assert.IsFalse(FL1.TryGetValue('k11', l1v), 'L1 must be bypassed');

  // L2 must have the value
  Assert.IsTrue(FL2.TryGetValue('k11', l2v));
  Assert.AreEqual('v11', l2v);
end;

{ T-HYB-12: nil factory raises EArgumentNilException }
procedure THybridCacheTests.T_HYB_12_GetOrCreate_NilFactory_Raises;
var
  nilFactory: TFunc<string>;
begin
  nilFactory := nil;
  try
    FCache.GetOrCreate('k12', nilFactory);
    Assert.Fail('Expected EArgumentNilException was not raised');
  except
    on E: EArgumentNilException do ; // expected
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(THybridCacheTests);

end.
