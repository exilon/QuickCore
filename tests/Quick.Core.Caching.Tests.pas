unit Quick.Core.Caching.Tests;

{ Tests: T-CA-01..07
    T-CA-01  SetValue / TryGetValue (string) round-trip returns the stored value
    T-CA-02  TryGetValue for an unknown key returns False and empty string
    T-CA-03  RemoveValue makes the key unavailable
    T-CA-04  Overwriting an existing key returns the latest value
    T-CA-05  Multiple keys are stored independently
    T-CA-06  SetValue with TArray<string> / TryGetValue round-trip
    T-CA-07  Flush removes all cached entries
}

interface

uses
  DUnitX.TestFramework,
  Quick.Core.Extensions.Caching.Memory,
  Quick.Core.Caching.Abstractions;

type

  [TestFixture]
  TCachingTests = class
  private
    FCache: IMemoryCache;
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure T_CA_01_SetGetString_HitReturnsValue;
    [Test]
    procedure T_CA_02_GetString_MissReturnsFalse;
    [Test]
    procedure T_CA_03_Remove_KeyUnavailableAfterRemoval;
    [Test]
    procedure T_CA_04_Overwrite_ReturnsLatestValue;
    [Test]
    procedure T_CA_05_MultipleKeys_StoredIndependently;
    [Test]
    procedure T_CA_06_SetGetStringArray_RoundTrip;
    [Test]
    procedure T_CA_07_Flush_RemovesAllEntries;
  end;

implementation

{ TCachingTests }

procedure TCachingTests.SetUp;
begin
  FCache := THttpMemoryCache.Create(nil);
end;

procedure TCachingTests.TearDown;
begin
  FCache := nil;
end;

{ T-CA-01 }

procedure TCachingTests.T_CA_01_SetGetString_HitReturnsValue;
var
  value: string;
begin
  FCache.SetValue('key1', 'hello', 0);
  Assert.IsTrue(FCache.TryGetValue('key1', value));
  Assert.AreEqual('hello', value);
end;

{ T-CA-02 }

procedure TCachingTests.T_CA_02_GetString_MissReturnsFalse;
var
  value: string;
begin
  Assert.IsFalse(FCache.TryGetValue('nonexistent', value));
end;

{ T-CA-03 }

procedure TCachingTests.T_CA_03_Remove_KeyUnavailableAfterRemoval;
var
  value: string;
begin
  FCache.SetValue('toremove', 'data', 0);
  FCache.RemoveValue('toremove');
  Assert.IsFalse(FCache.TryGetValue('toremove', value));
end;

{ T-CA-04 }

procedure TCachingTests.T_CA_04_Overwrite_ReturnsLatestValue;
var
  value: string;
begin
  FCache.SetValue('k', 'first', 0);
  FCache.SetValue('k', 'second', 0);
  FCache.TryGetValue('k', value);
  Assert.AreEqual('second', value);
end;

{ T-CA-05 }

procedure TCachingTests.T_CA_05_MultipleKeys_StoredIndependently;
var
  v1, v2: string;
begin
  FCache.SetValue('a', 'alpha', 0);
  FCache.SetValue('b', 'beta', 0);
  FCache.TryGetValue('a', v1);
  FCache.TryGetValue('b', v2);
  Assert.AreEqual('alpha', v1);
  Assert.AreEqual('beta', v2);
end;

{ T-CA-06 }

procedure TCachingTests.T_CA_06_SetGetStringArray_RoundTrip;
var
  stored: TArray<string>;
begin
  FCache.SetValue('arr', TArray<string>.Create('x', 'y', 'z'), 0);
  Assert.IsTrue(FCache.TryGetValue('arr', stored));
  Assert.AreEqual(NativeInt(3), NativeInt(Length(stored)));
  Assert.AreEqual('x', stored[0]);
  Assert.AreEqual('z', stored[2]);
end;

{ T-CA-07 }

procedure TCachingTests.T_CA_07_Flush_RemovesAllEntries;
var
  value: string;
begin
  FCache.SetValue('x', 'a', 0);
  FCache.SetValue('y', 'b', 0);
  FCache.Flush;
  Assert.IsFalse(FCache.TryGetValue('x', value));
  Assert.IsFalse(FCache.TryGetValue('y', value));
end;

initialization
  TDUnitX.RegisterTestFixture(TCachingTests);

end.
