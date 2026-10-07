unit Quick.Core.Security.Authentication.Tests;

{ Tests: T-AUTH-01..10
    T-AUTH-01  TAuthenticationProperties.SetString / GetString round-trip
    T-AUTH-02  TAuthenticationProperties.SetBool / GetBool round-trip
    T-AUTH-03  TAuthenticationProperties.IsPersistent default = False
    T-AUTH-04  TAuthenticationProperties.IsPersistent := True persists
    T-AUTH-05  TAuthenticationProperties.AllowRefresh default = False
    T-AUTH-06  TAuthenticationProperties.AllowRefresh := True persists
    T-AUTH-07  TAuthenticationProperties.Items dictionary is non-nil
    T-AUTH-08  TAuthenticationTicket carries AuthenticationScheme
    T-AUTH-09  TAuthenticationTicket Principal matches supplied principal
    T-AUTH-10  TAuthenticationTicket (2-arg) Properties is non-nil
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Quick.Core.Security.Claims,
  Quick.Core.Security.Authentication;

type

  [TestFixture]
  TAuthenticationTests = class
  public
    [Test]
    procedure T_AUTH_01_SetString_GetString_RoundTrip;
    [Test]
    procedure T_AUTH_02_SetBool_GetBool_RoundTrip;
    [Test]
    procedure T_AUTH_03_IsPersistent_DefaultFalse;
    [Test]
    procedure T_AUTH_04_IsPersistent_SetTrue;
    [Test]
    procedure T_AUTH_05_AllowRefresh_DefaultFalse;
    [Test]
    procedure T_AUTH_06_AllowRefresh_SetTrue;
    [Test]
    procedure T_AUTH_07_Properties_Items_NotNil;
    [Test]
    procedure T_AUTH_08_Ticket_CarriesScheme;
    [Test]
    procedure T_AUTH_09_Ticket_PrincipalMatchesInput;
    [Test]
    procedure T_AUTH_10_Ticket_TwoArg_PropertiesNotNil;
  end;

implementation

{ TAuthenticationTests }

procedure TAuthenticationTests.T_AUTH_01_SetString_GetString_RoundTrip;
var
  props : TAuthenticationProperties;
begin
  props := TAuthenticationProperties.Create;
  try
    props.SetString('key1', 'hello');
    Assert.AreEqual('hello', props.GetString('key1'));
  finally
    props.Free;
  end;
end;

procedure TAuthenticationTests.T_AUTH_02_SetBool_GetBool_RoundTrip;
var
  props : TAuthenticationProperties;
begin
  props := TAuthenticationProperties.Create;
  try
    props.SetBool('flagA', True);
    Assert.IsTrue(props.GetBool('flagA'));
    props.SetBool('flagA', False);
    Assert.IsFalse(props.GetBool('flagA'));
  finally
    props.Free;
  end;
end;

procedure TAuthenticationTests.T_AUTH_03_IsPersistent_DefaultFalse;
var
  props : TAuthenticationProperties;
begin
  props := TAuthenticationProperties.Create;
  try
    Assert.IsFalse(props.IsPersistent, 'IsPersistent should default to False');
  finally
    props.Free;
  end;
end;

procedure TAuthenticationTests.T_AUTH_04_IsPersistent_SetTrue;
var
  props : TAuthenticationProperties;
begin
  props := TAuthenticationProperties.Create;
  try
    props.IsPersistent := True;
    Assert.IsTrue(props.IsPersistent);
  finally
    props.Free;
  end;
end;

procedure TAuthenticationTests.T_AUTH_05_AllowRefresh_DefaultFalse;
var
  props : TAuthenticationProperties;
begin
  props := TAuthenticationProperties.Create;
  try
    Assert.IsFalse(props.AllowRefresh, 'AllowRefresh should default to False');
  finally
    props.Free;
  end;
end;

procedure TAuthenticationTests.T_AUTH_06_AllowRefresh_SetTrue;
var
  props : TAuthenticationProperties;
begin
  props := TAuthenticationProperties.Create;
  try
    props.AllowRefresh := True;
    Assert.IsTrue(props.AllowRefresh);
  finally
    props.Free;
  end;
end;

procedure TAuthenticationTests.T_AUTH_07_Properties_Items_NotNil;
var
  props : TAuthenticationProperties;
begin
  props := TAuthenticationProperties.Create;
  try
    Assert.IsNotNull(props.Items, 'Items dictionary should not be nil');
  finally
    props.Free;
  end;
end;

procedure TAuthenticationTests.T_AUTH_08_Ticket_CarriesScheme;
var
  principal : TClaimsPrincipal;
  identity  : TClaimsIdentity;
  ticket    : TAuthenticationTicket;
begin
  identity  := TClaimsIdentity.Create;
  identity.AuthenticationType := 'Bearer';
  principal := TClaimsPrincipal.Create(identity);
  try
    ticket := TAuthenticationTicket.Create(principal, 'Bearer');
    try
      Assert.AreEqual('Bearer', ticket.AuthenticationScheme);
    finally
      ticket.Free;
    end;
  finally
    principal.Free;
  end;
end;

procedure TAuthenticationTests.T_AUTH_09_Ticket_PrincipalMatchesInput;
var
  principal : TClaimsPrincipal;
  identity  : TClaimsIdentity;
  ticket    : TAuthenticationTicket;
begin
  identity  := TClaimsIdentity.Create;
  identity.AuthenticationType := 'Cookie';
  principal := TClaimsPrincipal.Create(identity);
  try
    ticket := TAuthenticationTicket.Create(principal, 'Cookie');
    try
      Assert.AreSame(principal, ticket.Principal,
        'Ticket.Principal should be the same object passed to the constructor');
    finally
      ticket.Free;
    end;
  finally
    principal.Free;
  end;
end;

procedure TAuthenticationTests.T_AUTH_10_Ticket_TwoArg_PropertiesNotNil;
var
  principal  : TClaimsPrincipal;
  identity   : TClaimsIdentity;
  properties : TAuthenticationProperties;
  ticket     : TAuthenticationTicket;
begin
  identity   := TClaimsIdentity.Create;
  identity.AuthenticationType := 'Jwt';
  principal  := TClaimsPrincipal.Create(identity);
  properties := TAuthenticationProperties.Create;
  try
    ticket := TAuthenticationTicket.Create(principal, properties, 'Jwt');
    try
      Assert.IsNotNull(ticket.Properties,
        'Ticket.Properties should not be nil when supplied in constructor');
    finally
      ticket.Free;
    end;
  finally
    principal.Free;
    // properties is now owned by ticket (via destructor) — do not free here
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TAuthenticationTests);

end.
