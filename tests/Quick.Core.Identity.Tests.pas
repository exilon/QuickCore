unit Quick.Core.Identity.Tests;

{ Tests: T-ID-01..12
    T-ID-01  TClaimsIdentityOptions RoleClaimType default is empty
    T-ID-02  TClaimsIdentityOptions RoleClaimType is writable
    T-ID-03  TClaimsIdentityOptions UserNameClaimType is writable
    T-ID-04  TClaimsIdentityOptions UserIdClaimType is writable
    T-ID-05  TLockOutOptions AllowedForNewUsers default is False
    T-ID-06  TLockOutOptions MaxFailedAccessAttempts default is 0
    T-ID-07  TLockOutOptions MaxFailedAccessAttempts is writable
    T-ID-08  TPasswordOptions RequireDigit default is False
    T-ID-09  TPasswordOptions RequiredLength default is 0
    T-ID-10  TPasswordOptions RequiredLength is writable
    T-ID-11  TPasswordOptions RequireUppercase is writable
    T-ID-12  TPasswordOptions RequireLowercase is writable
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Quick.Core.Identity;

type

  [TestFixture]
  TIdentityTests = class
  public
    [Test]
    procedure T_ID_01_ClaimsIdentityOptions_RoleClaimType_DefaultEmpty;
    [Test]
    procedure T_ID_02_ClaimsIdentityOptions_RoleClaimType_Writable;
    [Test]
    procedure T_ID_03_ClaimsIdentityOptions_UserNameClaimType_Writable;
    [Test]
    procedure T_ID_04_ClaimsIdentityOptions_UserIdClaimType_Writable;
    [Test]
    procedure T_ID_05_LockOutOptions_AllowedForNewUsers_DefaultFalse;
    [Test]
    procedure T_ID_06_LockOutOptions_MaxFailed_DefaultZero;
    [Test]
    procedure T_ID_07_LockOutOptions_MaxFailed_Writable;
    [Test]
    procedure T_ID_08_PasswordOptions_RequireDigit_DefaultFalse;
    [Test]
    procedure T_ID_09_PasswordOptions_RequiredLength_DefaultZero;
    [Test]
    procedure T_ID_10_PasswordOptions_RequiredLength_Writable;
    [Test]
    procedure T_ID_11_PasswordOptions_RequireUppercase_Writable;
    [Test]
    procedure T_ID_12_PasswordOptions_RequireLowercase_Writable;
  end;

implementation

{ TIdentityTests }

// ─── TClaimsIdentityOptions ───────────────────────────────────────────────────

procedure TIdentityTests.T_ID_01_ClaimsIdentityOptions_RoleClaimType_DefaultEmpty;
var
  opts : TClaimsIdentityOptions;
begin
  opts := TClaimsIdentityOptions.Create;
  try
    Assert.AreEqual('', opts.RoleClaimType,
      'RoleClaimType should be empty string by default');
  finally
    opts.Free;
  end;
end;

procedure TIdentityTests.T_ID_02_ClaimsIdentityOptions_RoleClaimType_Writable;
var
  opts : TClaimsIdentityOptions;
begin
  opts := TClaimsIdentityOptions.Create;
  try
    opts.RoleClaimType := 'http://schemas.microsoft.com/ws/2008/06/identity/claims/role';
    Assert.IsNotEmpty(opts.RoleClaimType);
  finally
    opts.Free;
  end;
end;

procedure TIdentityTests.T_ID_03_ClaimsIdentityOptions_UserNameClaimType_Writable;
var
  opts : TClaimsIdentityOptions;
begin
  opts := TClaimsIdentityOptions.Create;
  try
    opts.UserNameClaimType := 'name';
    Assert.AreEqual('name', opts.UserNameClaimType);
  finally
    opts.Free;
  end;
end;

procedure TIdentityTests.T_ID_04_ClaimsIdentityOptions_UserIdClaimType_Writable;
var
  opts : TClaimsIdentityOptions;
begin
  opts := TClaimsIdentityOptions.Create;
  try
    opts.UserIdClaimType := 'sub';
    Assert.AreEqual('sub', opts.UserIdClaimType);
  finally
    opts.Free;
  end;
end;

// ─── TLockOutOptions ──────────────────────────────────────────────────────────

procedure TIdentityTests.T_ID_05_LockOutOptions_AllowedForNewUsers_DefaultFalse;
var
  opts : TLockOutOptions;
begin
  opts := TLockOutOptions.Create;
  try
    Assert.IsFalse(opts.AllowedForNewUsers,
      'AllowedForNewUsers should default to False');
  finally
    opts.Free;
  end;
end;

procedure TIdentityTests.T_ID_06_LockOutOptions_MaxFailed_DefaultZero;
var
  opts : TLockOutOptions;
begin
  opts := TLockOutOptions.Create;
  try
    Assert.AreEqual(0, opts.MaxFailedAccessAttempts,
      'MaxFailedAccessAttempts should default to 0');
  finally
    opts.Free;
  end;
end;

procedure TIdentityTests.T_ID_07_LockOutOptions_MaxFailed_Writable;
var
  opts : TLockOutOptions;
begin
  opts := TLockOutOptions.Create;
  try
    opts.MaxFailedAccessAttempts := 5;
    Assert.AreEqual(5, opts.MaxFailedAccessAttempts);
  finally
    opts.Free;
  end;
end;

// ─── TPasswordOptions ─────────────────────────────────────────────────────────

procedure TIdentityTests.T_ID_08_PasswordOptions_RequireDigit_DefaultFalse;
var
  opts : TPasswordOptions;
begin
  opts := TPasswordOptions.Create;
  try
    Assert.IsFalse(opts.RequireDigit,
      'RequireDigit should default to False');
  finally
    opts.Free;
  end;
end;

procedure TIdentityTests.T_ID_09_PasswordOptions_RequiredLength_DefaultZero;
var
  opts : TPasswordOptions;
begin
  opts := TPasswordOptions.Create;
  try
    Assert.AreEqual(0, opts.RequiredLength,
      'RequiredLength should default to 0');
  finally
    opts.Free;
  end;
end;

procedure TIdentityTests.T_ID_10_PasswordOptions_RequiredLength_Writable;
var
  opts : TPasswordOptions;
begin
  opts := TPasswordOptions.Create;
  try
    opts.RequiredLength := 8;
    Assert.AreEqual(8, opts.RequiredLength);
  finally
    opts.Free;
  end;
end;

procedure TIdentityTests.T_ID_11_PasswordOptions_RequireUppercase_Writable;
var
  opts : TPasswordOptions;
begin
  opts := TPasswordOptions.Create;
  try
    opts.RequireUppercase := True;
    Assert.IsTrue(opts.RequireUppercase);
  finally
    opts.Free;
  end;
end;

procedure TIdentityTests.T_ID_12_PasswordOptions_RequireLowercase_Writable;
var
  opts : TPasswordOptions;
begin
  opts := TPasswordOptions.Create;
  try
    opts.RequireLowercase := True;
    Assert.IsTrue(opts.RequireLowercase);
  finally
    opts.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TIdentityTests);

end.
