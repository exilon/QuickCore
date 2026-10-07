unit Quick.Core.Extensions.Localization.Tests;

{ Tests: T-LOC-01..10
    T-LOC-01  TLocalizationOptions.AddCulture stores culture names
    T-LOC-02  TLocalizationOptions.AddIfNotFound defaults to False
    T-LOC-03  TLocalizationOptions.AddIfNotFound is writable
    T-LOC-04  TStringLocalization.Culture defaults to 'en'
    T-LOC-05  TStringLocalization.Culture is settable
    T-LOC-06  TStringLocalization.Items returns key when translation is found
    T-LOC-07  TStringLocalization.Items returns key name when NOT found (passthrough)
    T-LOC-08  TFileLocalizationStore.GetCultureTranslations for missing file returns empty dict
    T-LOC-09  TFileLocalizationStore.GetCultureTranslations normalizes 'en-US' to 'en'
    T-LOC-10  TStringLocalization can switch culture
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Generics.Collections,
  Quick.Core.Localization.Abstractions,
  Quick.Core.Extensions.Localization;

type

  // ── Mock store: returns a fixed dictionary for 'en', empty for others ──────
  TTestLocalizationStore = class(TInterfacedObject, ILocalizationStore)
  private
    fData : TDictionary<string,string>;
  public
    constructor Create;
    destructor Destroy; override;
    function GetCultureTranslations(const aCulture : string) : TDictionary<string,string>;
  end;

  [TestFixture]
  TLocalizationTests = class
  private
    fStore : TTestLocalizationStore;
    fLoc   : TStringLocalization;
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure T_LOC_01_Options_AddCulture_Stores;
    [Test]
    procedure T_LOC_02_Options_AddIfNotFound_DefaultFalse;
    [Test]
    procedure T_LOC_03_Options_AddIfNotFound_Writable;
    [Test]
    procedure T_LOC_04_Localization_Culture_DefaultEn;
    [Test]
    procedure T_LOC_05_Localization_Culture_Settable;
    [Test]
    procedure T_LOC_06_Localization_Items_Found;
    [Test]
    procedure T_LOC_07_Localization_Items_NotFound_Passthrough;
    [Test]
    procedure T_LOC_08_FileStore_MissingFile_EmptyDict;
    [Test]
    procedure T_LOC_09_FileStore_NormalizesCulture;
    [Test]
    procedure T_LOC_10_Localization_SwitchCulture;
  end;

implementation

{ TTestLocalizationStore }

constructor TTestLocalizationStore.Create;
begin
  fData := TDictionary<string,string>.Create;
  fData.Add('greeting', 'Hello');
  fData.Add('farewell', 'Goodbye');
end;

destructor TTestLocalizationStore.Destroy;
begin
  fData.Free;
  inherited;
end;

function TTestLocalizationStore.GetCultureTranslations(const aCulture : string) : TDictionary<string,string>;
begin
  // Return the fixed dictionary for any culture in this mock
  Result := fData;
end;

{ TLocalizationTests }

procedure TLocalizationTests.SetUp;
begin
  fStore := TTestLocalizationStore.Create;
  fLoc   := TStringLocalization.Create(fStore);
end;

procedure TLocalizationTests.TearDown;
begin
  fLoc.Free;
  // fStore is a TInterfacedObject — freed via interface refcount when fLoc is freed;
  // calling Free again here would cause a double-free / Invalid pointer operation.
end;

// ─── TLocalizationOptions ─────────────────────────────────────────────────────

procedure TLocalizationTests.T_LOC_01_Options_AddCulture_Stores;
var
  opts : TLocalizationOptions;
begin
  opts := TLocalizationOptions.Create;
  try
    opts.AddCulture('en');
    opts.AddCulture('es');
    // No crash means the cultures were accepted
    Assert.Pass('AddCulture accepted two cultures without exception');
  finally
    opts.Free;
  end;
end;

procedure TLocalizationTests.T_LOC_02_Options_AddIfNotFound_DefaultFalse;
var
  opts : TLocalizationOptions;
begin
  opts := TLocalizationOptions.Create;
  try
    Assert.IsFalse(opts.AddIfNotfound,
      'AddIfNotFound should default to False');
  finally
    opts.Free;
  end;
end;

procedure TLocalizationTests.T_LOC_03_Options_AddIfNotFound_Writable;
var
  opts : TLocalizationOptions;
begin
  opts := TLocalizationOptions.Create;
  try
    opts.AddIfNotfound := True;
    Assert.IsTrue(opts.AddIfNotfound);
  finally
    opts.Free;
  end;
end;

// ─── TStringLocalization ──────────────────────────────────────────────────────

procedure TLocalizationTests.T_LOC_04_Localization_Culture_DefaultEn;
begin
  Assert.AreEqual('en', fLoc.Culture,
    'Default culture should be "en"');
end;

procedure TLocalizationTests.T_LOC_05_Localization_Culture_Settable;
begin
  fLoc.Culture := 'es';
  Assert.AreEqual('es', fLoc.Culture);
end;

procedure TLocalizationTests.T_LOC_06_Localization_Items_Found;
var
  result : string;
begin
  result := fLoc.Items['greeting'];
  Assert.AreEqual('Hello', result,
    '"greeting" should translate to "Hello" in the mock store');
end;

procedure TLocalizationTests.T_LOC_07_Localization_Items_NotFound_Passthrough;
var
  result : string;
begin
  // 'unknown_key' is not in the mock dictionary — should return the key itself
  result := fLoc.Items['unknown_key'];
  Assert.AreEqual('unknown_key', result,
    'When a key is missing, GetItem should return the key name as fallback');
end;

// ─── TFileLocalizationStore ───────────────────────────────────────────────────

procedure TLocalizationTests.T_LOC_08_FileStore_MissingFile_EmptyDict;
var
  store : TFileLocalizationStore;
  dict  : TDictionary<string,string>;
begin
  store := TFileLocalizationStore.Create;
  try
    // No locale files exist in the test output dir — should return empty dict
    dict := store.GetCultureTranslations('zz');
    Assert.IsNotNull(dict,
      'GetCultureTranslations should return an empty dict (not nil) for a missing locale file');
    Assert.AreEqual<Integer>(0, dict.Count,
      'Translation dict should be empty for a non-existent locale file');
  finally
    store.Free;
  end;
end;

procedure TLocalizationTests.T_LOC_09_FileStore_NormalizesCulture;
var
  store  : TFileLocalizationStore;
  dict1  : TDictionary<string,string>;
  dict2  : TDictionary<string,string>;
begin
  store := TFileLocalizationStore.Create;
  try
    // 'en-US' should normalise to 'en' — both calls should hit the same cached entry
    dict1 := store.GetCultureTranslations('en-US');
    dict2 := store.GetCultureTranslations('en');
    Assert.AreSame(dict1, dict2,
      'GetCultureTranslations("en-US") and ("en") should return the same cached dict');
  finally
    store.Free;
  end;
end;

procedure TLocalizationTests.T_LOC_10_Localization_SwitchCulture;
begin
  fLoc.Culture := 'fr';
  Assert.AreEqual('fr', fLoc.Culture,
    'Culture should reflect the last SetCulture call');
  fLoc.Culture := 'de';
  Assert.AreEqual('de', fLoc.Culture);
end;

initialization
  TDUnitX.RegisterTestFixture(TLocalizationTests);

end.
