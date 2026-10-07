unit Quick.Core.Security.Tests;

{ Tests: T-SEC-01..08
    T-SEC-01  TClaimsPrincipal can be created with an identity and Name is accessible
    T-SEC-02  TClaimsIdentity.AddClaim / HasClaim round-trip
    T-SEC-03  TClaimsPrincipal.IsInRole returns True for a role claim
    T-SEC-04  TClaimsPrincipal.FindFirst predicate finds the expected claim
    T-SEC-05  TJwtTokenService.GenerateToken produces a three-part dot-separated token
    T-SEC-06  ValidateToken returns True and a valid principal for a freshly generated token
    T-SEC-07  ValidateToken returns False for a token signed with a different secret
    T-SEC-08  GetUserFromToken decodes the subject (name) without signature check
}

interface

uses
  DUnitX.TestFramework,
  Quick.Options,
  Quick.Core.Security.Claims,
  Quick.Core.Security.Jwt;

type

  [TestFixture]
  TSecurityTests = class
  private
    function MakeOptions(const ASecret, AIssuer, AAudience: string;
      AExpiry: Integer = 60; AValidateLifetime: Boolean = True): IOptions<TJwtOptions>;
    function MakePrincipal(const AName, ARole: string): TClaimsPrincipal;
  public
    { Claims Tests }
    [Test]
    procedure T_SEC_01_Principal_Name;
    [Test]
    procedure T_SEC_02_ClaimsIdentity_HasClaim;
    [Test]
    procedure T_SEC_03_IsInRole;
    [Test]
    procedure T_SEC_04_FindFirst;

    { JWT Tests }
    [Test]
    procedure T_SEC_05_GenerateToken_ThreeParts;
    [Test]
    procedure T_SEC_06_ValidateToken_ValidToken;
    [Test]
    procedure T_SEC_07_ValidateToken_WrongSecret;
    [Test]
    procedure T_SEC_08_GetUserFromToken_DecodesSubject;
  end;

implementation

uses
  System.SysUtils;

{ TSecurityTests – helpers }

function TSecurityTests.MakeOptions(const ASecret, AIssuer, AAudience: string;
  AExpiry: Integer; AValidateLifetime: Boolean): IOptions<TJwtOptions>;
var
  opts: TJwtOptions;
begin
  opts := TJwtOptions.Create;
  opts.Secret := ASecret;
  opts.Issuer := AIssuer;
  opts.Audience := AAudience;
  opts.ExpiryMinutes := AExpiry;
  opts.ValidateLifetime := AValidateLifetime;
  opts.ValidateIssuer := AIssuer <> '';
  opts.ValidateAudience := AAudience <> '';
  Result := TOptionValue<TJwtOptions>.Create(opts);
end;

function TSecurityTests.MakePrincipal(const AName, ARole: string): TClaimsPrincipal;
var
  identity: TClaimsIdentity;
begin
  identity := TClaimsIdentity.Create;
  identity.AuthenticationType := TAuthenticationTypes.Password;
  identity.Name := AName;
  if ARole <> '' then
    identity.AddClaim(TClaim.Create(TClaimTypes.Role, ARole));
  Result := TClaimsPrincipal.Create(identity as IIdentity);
end;

{ T-SEC-01 }

procedure TSecurityTests.T_SEC_01_Principal_Name;
var
  principal: TClaimsPrincipal;
begin
  principal := MakePrincipal('alice', '');
  try
    Assert.AreEqual('alice', (principal.Identity as TClaimsIdentity).Name);
  finally
    principal.Free;
  end;
end;

{ T-SEC-02 }

procedure TSecurityTests.T_SEC_02_ClaimsIdentity_HasClaim;
var
  identity: TClaimsIdentity;
begin
  identity := TClaimsIdentity.Create;
  try
    identity.AddClaim(TClaim.Create(TClaimTypes.Email, 'alice@example.com'));
    Assert.IsTrue(identity.HasClaim(TClaimTypes.Email, 'alice@example.com'));
    Assert.IsFalse(identity.HasClaim(TClaimTypes.Email, 'other@example.com'));
  finally
    identity.Free;
  end;
end;

{ T-SEC-03 }

procedure TSecurityTests.T_SEC_03_IsInRole;
var
  principal: TClaimsPrincipal;
begin
  principal := MakePrincipal('bob', 'admin');
  try
    Assert.IsTrue(principal.IsInRole('admin'));
    Assert.IsFalse(principal.IsInRole('user'));
  finally
    principal.Free;
  end;
end;

{ T-SEC-04 }

procedure TSecurityTests.T_SEC_04_FindFirst;
var
  principal: TClaimsPrincipal;
  claim: TClaim;
begin
  principal := MakePrincipal('carol', 'editor');
  try
    principal.Identities[0].AddClaim(TClaim.Create(TClaimTypes.Email, 'carol@example.com'));
    claim := principal.FindFirst(
      function(c: TClaim): Boolean
      begin
        Result := c.&Type = TClaimTypes.Email;
      end);
    Assert.IsNotNull(claim);
    Assert.AreEqual('carol@example.com', claim.Value);
  finally
    principal.Free;
  end;
end;

{ T-SEC-05 }

procedure TSecurityTests.T_SEC_05_GenerateToken_ThreeParts;
var
  svc: TJwtTokenService;
  principal: TClaimsPrincipal;
  token: string;
  parts: TArray<string>;
begin
  svc := TJwtTokenService.Create(MakeOptions('supersecret', '', ''));
  principal := MakePrincipal('dave', '');
  try
    token := svc.GenerateToken(principal);
    parts := token.Split(['.']);
    Assert.AreEqual(NativeInt(3), NativeInt(Length(parts)), 'JWT must have 3 dot-separated parts');
    Assert.IsTrue(parts[0] <> '', 'Header must not be empty');
    Assert.IsTrue(parts[1] <> '', 'Payload must not be empty');
    Assert.IsTrue(parts[2] <> '', 'Signature must not be empty');
  finally
    principal.Free;
    svc.Free;
  end;
end;

{ T-SEC-06 }

procedure TSecurityTests.T_SEC_06_ValidateToken_ValidToken;
var
  svc: TJwtTokenService;
  principal, outPrincipal: TClaimsPrincipal;
  token: string;
  ok: Boolean;
begin
  svc := TJwtTokenService.Create(MakeOptions('mysecret42', 'myapp', ''));
  principal := MakePrincipal('eve', 'user');
  try
    token := svc.GenerateToken(principal);
    ok := svc.ValidateToken(token, outPrincipal);
    try
      Assert.IsTrue(ok, 'ValidateToken must return True for a freshly-issued token');
      Assert.IsNotNull(outPrincipal);
      Assert.AreEqual('eve', (outPrincipal.Identity as TClaimsIdentity).Name);
    finally
      if ok then outPrincipal.Free;
    end;
  finally
    principal.Free;
    svc.Free;
  end;
end;

{ T-SEC-07 }

procedure TSecurityTests.T_SEC_07_ValidateToken_WrongSecret;
var
  svcIssuer, svcValidator: TJwtTokenService;
  principal, outPrincipal: TClaimsPrincipal;
  token: string;
begin
  svcIssuer    := TJwtTokenService.Create(MakeOptions('correctsecret', '', ''));
  svcValidator := TJwtTokenService.Create(MakeOptions('wrongsecret',   '', ''));
  principal    := MakePrincipal('frank', '');
  try
    token := svcIssuer.GenerateToken(principal);
    Assert.IsFalse(svcValidator.ValidateToken(token, outPrincipal),
      'ValidateToken must return False when secret does not match');
    Assert.IsNull(outPrincipal);
  finally
    principal.Free;
    svcIssuer.Free;
    svcValidator.Free;
  end;
end;

{ T-SEC-08 }

procedure TSecurityTests.T_SEC_08_GetUserFromToken_DecodesSubject;
var
  svc: TJwtTokenService;
  principal, decoded: TClaimsPrincipal;
  token: string;
begin
  svc := TJwtTokenService.Create(MakeOptions('anysecret', '', ''));
  principal := MakePrincipal('grace', '');
  try
    token := svc.GenerateToken(principal);
    decoded := svc.GetUserFromToken(token);
    try
      Assert.IsNotNull(decoded);
      Assert.AreEqual('grace', (decoded.Identity as TClaimsIdentity).Name);
    finally
      decoded.Free;
    end;
  finally
    principal.Free;
    svc.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSecurityTests);

end.
