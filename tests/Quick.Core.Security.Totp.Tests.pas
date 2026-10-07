unit Quick.Core.Security.Totp.Tests;

{ Tests: T-TOTP-01..08
    T-TOTP-01  TTotpService.GenerateCode returns a 6-character string
    T-TOTP-02  TTotpService.GenerateCode returns only digits
    T-TOTP-03  TTotpService.ValidateCode returns True for a freshly generated code
    T-TOTP-04  TTotpService.ValidateCode returns False for "000000" (very unlikely to match)
    T-TOTP-05  TTotpService.ValidateCode returns False for a wrong secret
    T-TOTP-06  TTotpService.GetProvisioningUri starts with "otpauth://totp/"
    T-TOTP-07  TTotpService.GetProvisioningUri contains the account name
    T-TOTP-08  TTotpService.GetProvisioningUri contains the issuer
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Quick.Core.Security.Totp;

const
  // RFC 6238 well-known test secret (Base32 of "Hello!")
  TEST_SECRET = 'JBSWY3DPEHPK3PXP';

type

  [TestFixture]
  TTotpTests = class
  private
    fTotp : ITotpService;
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure T_TOTP_01_GenerateCode_Returns6Chars;
    [Test]
    procedure T_TOTP_02_GenerateCode_OnlyDigits;
    [Test]
    procedure T_TOTP_03_ValidateCode_FreshCode_True;
    [Test]
    procedure T_TOTP_04_ValidateCode_WrongCode_False;
    [Test]
    procedure T_TOTP_05_ValidateCode_WrongSecret_False;
    [Test]
    procedure T_TOTP_06_ProvisioningUri_StartsCorrectly;
    [Test]
    procedure T_TOTP_07_ProvisioningUri_ContainsAccount;
    [Test]
    procedure T_TOTP_08_ProvisioningUri_ContainsIssuer;
  end;

implementation

procedure TTotpTests.SetUp;
begin
  fTotp := TTotpService.Create;
end;

procedure TTotpTests.TearDown;
begin
  fTotp := nil;
end;

{ helpers }

function AllDigits(const s : string) : Boolean;
var c : Char;
begin
  Result := True;
  for c in s do
    if not CharInSet(c, ['0'..'9']) then Exit(False);
end;

// ─── T-TOTP-01 ───────────────────────────────────────────────────────────────

procedure TTotpTests.T_TOTP_01_GenerateCode_Returns6Chars;
var
  code : string;
begin
  code := fTotp.GenerateCode(TEST_SECRET);
  Assert.AreEqual<Integer>(6, Length(code),
    'GenerateCode should always return exactly 6 characters');
end;

// ─── T-TOTP-02 ───────────────────────────────────────────────────────────────

procedure TTotpTests.T_TOTP_02_GenerateCode_OnlyDigits;
var
  code : string;
begin
  code := fTotp.GenerateCode(TEST_SECRET);
  Assert.IsTrue(AllDigits(code), 'TOTP code must contain only digits 0-9');
end;

// ─── T-TOTP-03 ───────────────────────────────────────────────────────────────

procedure TTotpTests.T_TOTP_03_ValidateCode_FreshCode_True;
var
  code : string;
begin
  // Generate and immediately validate within the same 30-second window
  code := fTotp.GenerateCode(TEST_SECRET);
  Assert.IsTrue(fTotp.ValidateCode(TEST_SECRET, code, 1),
    'A freshly generated code should validate successfully (window = 1)');
end;

// ─── T-TOTP-04 ───────────────────────────────────────────────────────────────

procedure TTotpTests.T_TOTP_04_ValidateCode_WrongCode_False;
begin
  // '000000' is astronomically unlikely to match the real current code
  Assert.IsFalse(fTotp.ValidateCode(TEST_SECRET, '000000', 0),
    '"000000" with window=0 should not validate');
end;

// ─── T-TOTP-05 ───────────────────────────────────────────────────────────────

procedure TTotpTests.T_TOTP_05_ValidateCode_WrongSecret_False;
var
  code : string;
begin
  // Generate with one secret, validate against another
  code := fTotp.GenerateCode(TEST_SECRET);
  Assert.IsFalse(fTotp.ValidateCode('AAAAAAAAAAAAAAAA', code, 0),
    'A code generated with one secret should not validate against a different secret');
end;

// ─── T-TOTP-06 ───────────────────────────────────────────────────────────────

procedure TTotpTests.T_TOTP_06_ProvisioningUri_StartsCorrectly;
var
  uri : string;
begin
  uri := fTotp.GetProvisioningUri(TEST_SECRET, 'alice@example.com', 'MyApp');
  Assert.IsTrue(uri.StartsWith('otpauth://totp/', True),
    'Provisioning URI must start with "otpauth://totp/"');
end;

// ─── T-TOTP-07 ───────────────────────────────────────────────────────────────

procedure TTotpTests.T_TOTP_07_ProvisioningUri_ContainsAccount;
var
  uri : string;
begin
  uri := fTotp.GetProvisioningUri(TEST_SECRET, 'alice', 'MyApp');
  Assert.IsTrue(uri.Contains('alice'),
    'Provisioning URI should contain the account name');
end;

// ─── T-TOTP-08 ───────────────────────────────────────────────────────────────

procedure TTotpTests.T_TOTP_08_ProvisioningUri_ContainsIssuer;
var
  uri : string;
begin
  uri := fTotp.GetProvisioningUri(TEST_SECRET, 'alice', 'MyApp');
  Assert.IsTrue(uri.Contains('MyApp'),
    'Provisioning URI should contain the issuer name');
end;

initialization
  TDUnitX.RegisterTestFixture(TTotpTests);

end.
