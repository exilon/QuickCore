unit Quick.Core.Mvc.Middleware.Tests;

{ Tests: T-MW-01..18
  CORS Policy Options (T-MW-01..10)
    T-MW-01  Default MaxAgeSeconds is 86400
    T-MW-02  Default AllowedMethods include GET and POST
    T-MW-03  AllowOrigin appends one origin to AllowedOrigins
    T-MW-04  AllowOrigins appends multiple origins
    T-MW-05  AllowAnyOrigin fluent call returns Self (chain)
    T-MW-06  AllowMethod appends an uppercase method
    T-MW-07  AllowAnyMethod fluent call returns Self
    T-MW-08  AllowHeader appends a header
    T-MW-09  WithCredentials sets AllowCredentials = True
    T-MW-10  MaxAge sets MaxAgeSeconds correctly

  Rate Limit Policy + Attribute (T-MW-11..18)
    T-MW-11  TRateLimitPolicy default MaxRequests = 100
    T-MW-12  TRateLimitPolicy default WindowSecs = 60
    T-MW-13  TRateLimitPolicy MaxRequests is writable
    T-MW-14  TRateLimitPolicy WindowSecs is writable
    T-MW-15  RateLimit attribute stores MaxRequests
    T-MW-16  RateLimit attribute stores WindowSecs
    T-MW-17  RateLimit attribute default WindowSecs = 60
    T-MW-18  TRateLimitPolicy KeySelector defaults to nil
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Quick.Core.Mvc.Middleware.Cors,
  Quick.Core.Mvc.Middleware.RateLimit;

type

  [TestFixture]
  TMiddlewareTests = class
  public

    // ── CORS ──────────────────────────────────────────────────────────────
    [Test]
    procedure T_MW_01_CORS_DefaultMaxAgeIs86400;
    [Test]
    procedure T_MW_02_CORS_DefaultMethodsInclude_GET_POST;
    [Test]
    procedure T_MW_03_CORS_AllowOrigin_AppendsOne;
    [Test]
    procedure T_MW_04_CORS_AllowOrigins_AppendsMultiple;
    [Test]
    procedure T_MW_05_CORS_AllowAnyOrigin_ReturnsSelf;
    [Test]
    procedure T_MW_06_CORS_AllowMethod_AppendsUppercase;
    [Test]
    procedure T_MW_07_CORS_AllowAnyMethod_ReturnsSelf;
    [Test]
    procedure T_MW_08_CORS_AllowHeader_AppendsHeader;
    [Test]
    procedure T_MW_09_CORS_WithCredentials_SetsFlag;
    [Test]
    procedure T_MW_10_CORS_MaxAge_SetsSeconds;

    // ── Rate Limit ────────────────────────────────────────────────────────
    [Test]
    procedure T_MW_11_RateLimit_Policy_DefaultMaxRequests;
    [Test]
    procedure T_MW_12_RateLimit_Policy_DefaultWindowSecs;
    [Test]
    procedure T_MW_13_RateLimit_Policy_MaxRequests_Writable;
    [Test]
    procedure T_MW_14_RateLimit_Policy_WindowSecs_Writable;
    [Test]
    procedure T_MW_15_RateLimit_Attr_StoresMaxRequests;
    [Test]
    procedure T_MW_16_RateLimit_Attr_StoresWindowSecs;
    [Test]
    procedure T_MW_17_RateLimit_Attr_DefaultWindowSecs;
    [Test]
    procedure T_MW_18_RateLimit_Policy_KeySelector_DefaultsNil;
  end;

implementation

// ─── CORS ─────────────────────────────────────────────────────────────────────

procedure TMiddlewareTests.T_MW_01_CORS_DefaultMaxAgeIs86400;
var
  opts : TCorsPolicyOptions;
begin
  opts := TCorsPolicyOptions.Create;
  try
    Assert.AreEqual(86400, opts.MaxAgeSeconds);
  finally
    opts.Free;
  end;
end;

procedure TMiddlewareTests.T_MW_02_CORS_DefaultMethodsInclude_GET_POST;
var
  opts    : TCorsPolicyOptions;
  methods : TArray<string>;
  hasGet, hasPost : Boolean;
  m : string;
begin
  opts := TCorsPolicyOptions.Create;
  try
    methods := opts.AllowedMethods;
    hasGet  := False;
    hasPost := False;
    for m in methods do
    begin
      if SameText(m, 'GET')  then hasGet  := True;
      if SameText(m, 'POST') then hasPost := True;
    end;
    Assert.IsTrue(hasGet,  'Default AllowedMethods should include GET');
    Assert.IsTrue(hasPost, 'Default AllowedMethods should include POST');
  finally
    opts.Free;
  end;
end;

procedure TMiddlewareTests.T_MW_03_CORS_AllowOrigin_AppendsOne;
var
  opts : TCorsPolicyOptions;
begin
  opts := TCorsPolicyOptions.Create;
  try
    opts.AllowOrigin('https://example.com');
    Assert.AreEqual<Integer>(1, Length(opts.AllowedOrigins));
    Assert.AreEqual('https://example.com', opts.AllowedOrigins[0]);
  finally
    opts.Free;
  end;
end;

procedure TMiddlewareTests.T_MW_04_CORS_AllowOrigins_AppendsMultiple;
var
  opts : TCorsPolicyOptions;
begin
  opts := TCorsPolicyOptions.Create;
  try
    opts.AllowOrigins(['https://a.com', 'https://b.com']);
    Assert.AreEqual<Integer>(2, Length(opts.AllowedOrigins));
  finally
    opts.Free;
  end;
end;

procedure TMiddlewareTests.T_MW_05_CORS_AllowAnyOrigin_ReturnsSelf;
var
  opts   : TCorsPolicyOptions;
  result : TCorsPolicyOptions;
begin
  opts := TCorsPolicyOptions.Create;
  try
    result := opts.AllowAnyOrigin;
    Assert.AreSame(opts, result, 'AllowAnyOrigin should return Self for chaining');
  finally
    opts.Free;
  end;
end;

procedure TMiddlewareTests.T_MW_06_CORS_AllowMethod_AppendsUppercase;
var
  opts   : TCorsPolicyOptions;
  before : Integer;
  after  : Integer;
  found  : Boolean;
  m : string;
begin
  opts := TCorsPolicyOptions.Create;
  try
    before := Length(opts.AllowedMethods);
    opts.AllowMethod('patch');
    after := Length(opts.AllowedMethods);
    Assert.AreEqual(before + 1, after, 'AllowMethod should add one entry');
    found := False;
    for m in opts.AllowedMethods do
      if m = 'PATCH' then found := True;
    Assert.IsTrue(found, 'Added method should be uppercased to PATCH');
  finally
    opts.Free;
  end;
end;

procedure TMiddlewareTests.T_MW_07_CORS_AllowAnyMethod_ReturnsSelf;
var
  opts   : TCorsPolicyOptions;
  result : TCorsPolicyOptions;
begin
  opts := TCorsPolicyOptions.Create;
  try
    result := opts.AllowAnyMethod;
    Assert.AreSame(opts, result, 'AllowAnyMethod should return Self');
  finally
    opts.Free;
  end;
end;

procedure TMiddlewareTests.T_MW_08_CORS_AllowHeader_AppendsHeader;
var
  opts   : TCorsPolicyOptions;
  before : Integer;
begin
  opts := TCorsPolicyOptions.Create;
  try
    before := Length(opts.AllowedHeaders);
    opts.AllowHeader('X-Custom-Header');
    Assert.AreEqual<Integer>(before + 1, Length(opts.AllowedHeaders));
    Assert.AreEqual('X-Custom-Header', opts.AllowedHeaders[Length(opts.AllowedHeaders) - 1]);
  finally
    opts.Free;
  end;
end;

procedure TMiddlewareTests.T_MW_09_CORS_WithCredentials_SetsFlag;
var
  opts : TCorsPolicyOptions;
begin
  opts := TCorsPolicyOptions.Create;
  try
    Assert.IsFalse(opts.AllowCredentials, 'AllowCredentials should default to False');
    opts.WithCredentials;
    Assert.IsTrue(opts.AllowCredentials, 'WithCredentials should set AllowCredentials = True');
  finally
    opts.Free;
  end;
end;

procedure TMiddlewareTests.T_MW_10_CORS_MaxAge_SetsSeconds;
var
  opts : TCorsPolicyOptions;
begin
  opts := TCorsPolicyOptions.Create;
  try
    opts.MaxAge(3600);
    Assert.AreEqual(3600, opts.MaxAgeSeconds);
  finally
    opts.Free;
  end;
end;

// ─── Rate Limit ───────────────────────────────────────────────────────────────

procedure TMiddlewareTests.T_MW_11_RateLimit_Policy_DefaultMaxRequests;
var
  p : TRateLimitPolicy;
begin
  p := TRateLimitPolicy.Create;
  try
    Assert.AreEqual(100, p.MaxRequests);
  finally
    p.Free;
  end;
end;

procedure TMiddlewareTests.T_MW_12_RateLimit_Policy_DefaultWindowSecs;
var
  p : TRateLimitPolicy;
begin
  p := TRateLimitPolicy.Create;
  try
    Assert.AreEqual(60, p.WindowSecs);
  finally
    p.Free;
  end;
end;

procedure TMiddlewareTests.T_MW_13_RateLimit_Policy_MaxRequests_Writable;
var
  p : TRateLimitPolicy;
begin
  p := TRateLimitPolicy.Create;
  try
    p.MaxRequests := 50;
    Assert.AreEqual(50, p.MaxRequests);
  finally
    p.Free;
  end;
end;

procedure TMiddlewareTests.T_MW_14_RateLimit_Policy_WindowSecs_Writable;
var
  p : TRateLimitPolicy;
begin
  p := TRateLimitPolicy.Create;
  try
    p.WindowSecs := 120;
    Assert.AreEqual(120, p.WindowSecs);
  finally
    p.Free;
  end;
end;

procedure TMiddlewareTests.T_MW_15_RateLimit_Attr_StoresMaxRequests;
var
  attr : RateLimit;
begin
  attr := RateLimit.Create(20, 30);
  try
    Assert.AreEqual(20, attr.MaxRequests);
  finally
    attr.Free;
  end;
end;

procedure TMiddlewareTests.T_MW_16_RateLimit_Attr_StoresWindowSecs;
var
  attr : RateLimit;
begin
  attr := RateLimit.Create(20, 30);
  try
    Assert.AreEqual(30, attr.WindowSecs);
  finally
    attr.Free;
  end;
end;

procedure TMiddlewareTests.T_MW_17_RateLimit_Attr_DefaultWindowSecs;
var
  attr : RateLimit;
begin
  attr := RateLimit.Create(10);  // default window = 60
  try
    Assert.AreEqual(60, attr.WindowSecs, 'Default WindowSecs should be 60');
  finally
    attr.Free;
  end;
end;

procedure TMiddlewareTests.T_MW_18_RateLimit_Policy_KeySelector_DefaultsNil;
var
  p : TRateLimitPolicy;
begin
  p := TRateLimitPolicy.Create;
  try
    Assert.IsFalse(Assigned(p.KeySelector),
      'KeySelector should default to nil (not assigned)');
  finally
    p.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TMiddlewareTests);

end.
