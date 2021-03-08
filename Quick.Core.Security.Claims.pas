{ ***************************************************************************

  Copyright (c) 2016-2021 Kike Pérez

  Unit        : Quick.Core.Security.Claims
  Description : Core Security Claims
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 07/03/2020
  Modified    : 05/03/2021

  This file is part of QuickCore: https://github.com/exilon/QuickCore

 ***************************************************************************

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

 *************************************************************************** }

unit Quick.Core.Security.Claims;

{$i QuickCore.inc}

interface

uses
  {$IFDEF DEBUG_AUTENTICATION}
    Quick.Debug.Utils,
  {$ENDIF}
  System.SysUtils,
  System.Generics.Collections,
  Quick.Collections;

type

  TAuthenticationTypes = class
  public const
    Basic = 'basic';
    Federation = 'federation';
    Kerberos = 'kerberos';
    Negotiate = 'negotiate';
    Password = 'password';
    Signature = 'signature';
    Windows = 'windows';
    X509 = 'x590';
  end;

  IIdentity = interface
  ['{B3F640B3-46C5-4767-831A-F1287BC97561}']
    function GetAuthenticationType : string;
    function GetIsAuthenticated : Boolean;
    function GetName : string;
    property AuthenticationType : string read GetAuthenticationType;
    property IsAuthenticated : Boolean read GetIsAuthenticated;
    property Name : string read GetName;
  end;

  IPrincipal = interface
  ['{62A83547-78F4-41A4-A146-3E82491462F7}']
    function GetIdentity : IIdentity;
    property Identity : IIdentity read GetIdentity;
    function IsInRole(const aRole : string) : Boolean;
  end;

  TClaim = class;

  TClaimsIdentity = class(TInterfacedObject,IIdentity)
  private
    fClaims : TObjectList<TClaim>;
    fActor : TClaimsIdentity;
    fAuthenticationType : string;
    fLabel : string;
    fName : string;
    fNameClaimType : string; //from TClaimTypes
    fRoleClaimType : string;
    function GetAuthenticationType : string;
    function GetIsAuthenticated : Boolean;
    function GetName : string;
  public
    constructor Create;
    destructor Destroy; override;
    property Actor : TClaimsIdentity read fActor write fActor;
    property AuthenticationType : string read GetAuthenticationType write fAuthenticationType;
    property IsAuthenticated : Boolean read GetIsAuthenticated;
    property fabel : string read fLabel write fLabel;
    property Name : string read GetName write fName;
    property NameClaimType : string read fNameClaimType write fNameClaimType;
    property RoleClaimType : string read fRoleClaimType write fRoleClaimType;
    property Claims : TObjectList<TClaim> read fClaims;
    procedure AddClaim(aClaim : TClaim);
    function HasClaim(const aClaimType, aValue : string) : Boolean;
  end;

  TClaim = class
  private
    fIssuer : string;
    fOriginalIssuer : string;
    fProperties : TDictionary<string,string>;
    fSubject : TClaimsIdentity;
    fType : string; //from TClaimTypes
    fValue : string;
    fValueType : string;
  public
    constructor Create; overload;
    constructor Create(const aClaimType, aValue : string); overload;
    destructor Destroy; override;
    property Issuer : string read fIssuer write fIssuer;
    property OriginalIssuer : string read fOriginalIssuer write fOriginalIssuer;
    property Properties : TDictionary<string,string> read fProperties write fProperties;
    property Subject : TClaimsIdentity read fSubject write fSubject;
    property &Type : string read fType write fType;
    property Value : string read fValue write fValue;
    property ValueType : string read fValueType write fValueType;
  end;

  TClaimsPrincipal = class(TInterfacedObject,IPrincipal)
  private
    fIdentities : IObjectList<TClaimsIdentity>;
    function GetIdentity : IIdentity;
    function GetClaims: IList<TClaim>;
  public
    constructor Create; overload;
    constructor Create(aIdentities : IList<IIdentity>); overload;
    constructor Create(aIdentity : IIdentity); overload;
    destructor Destroy; override;
    property Identity : IIdentity read GetIdentity;
    property Identities : IObjectList<TClaimsIdentity> read fIdentities write fIdentities;
    property Claims : IList<TClaim> read GetClaims;
    function IsInRole(const aRole : string) : Boolean;
    procedure AddIdentity(aIdentity : TClaimsIdentity);
    procedure AddIdentities(aIdentities : IList<TClaimsIdentity>);
    function FindFirst(aMatch : TPredicate<TClaim>) : TClaim;
    function FindAll(aMatch : TPredicate<TClaim>) : IList<TClaim>;
    //function HasClaim(
  end;

  TClaimTypes = class
  public const
    Actor = 'http://schemas.xmlsoap.org/ws/2009/09/identity/claims/actor';
    Anonymous = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/anonymous';
    Authentication = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/authenticated';
    AuthenticationInstant = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/authenticationinstant';
    AuthenticationMethod = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/authenticationmethod';
    AuthorizationDecision = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/authorizationdecision';
    CookiePath = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/cookiepath';
    Country = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/country';
    DateOfBirth = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/dateofbirth';
    DenyOnlyPrimaryGroupSid = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/denyonlyprimarygroupsid';
    DenyOnlyPrimarySid = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/denyonlyprimarysid';
    DenyOnlySid = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/denyonlysid';
    DenyOnlyWindowsDeviceGroup = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/denyonlywindowsdevicegroup';
    Dns = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/dns';
    Dsa = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/dsa';
    Email = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress';
    Expiration = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/expiration';
    Expired = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/expired';
    Gender = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/gender';
    GivenName = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname';
    GroupSid = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/groupsid';
    Hash = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/hash';
    HomePhone = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/homephone';
    IsPersistent = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/ispersistent';
    Locality = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/locality';
    MobilePhone = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/mobilephone';
    Name = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name';
    NameIdentifier = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier';
    OtherPhone = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/otherphone';
    PostalCode = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/postalcode';
    PrimaryGroupSid = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/primarygroupsid';
    PrimarySid = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/primarysid';
    Role = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/role';
    Rsa = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/rsa';
    SerialNumber = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/serialnumber';
    Sid = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/sid';
    Spn = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/spn';
    StateOrProvince = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/stateorprovince';
    StreetAddress = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/streetaddress';
    Surname = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname';
    System = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/system';
    Thumbprint = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/thumbprint';
    Upn = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn';
    Uri = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/uri';
    UserData = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/userdata';
    Version = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/version';
    Webpage = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/webpage';
    WindowsAccountName = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/windowsaccountname';
    WindowsDeviceClaim = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/windowsdeviceclaim';
    WindowsDeviceGroup = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/windowsdevicegroup';
    WindowsFqbnVersion = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/windowsfqbnversion';
    WindowsSubAuthority = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/windowssubauthority';
    WindowsUserClaim = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/windowsuserclaim';
    X500DistinguishedName = 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/x500distinguishedname';
  end;

implementation

{ TClaimsPrincipal }

constructor TClaimsPrincipal.Create;
begin
  fIdentities := TxObjectList<TClaimsIdentity>.Create(True);
end;

constructor TClaimsPrincipal.Create(aIdentity: IIdentity);
begin
  Create;
  if aIdentity = nil then raise EArgumentNilException.Create('Identity cannot be null');
  fIdentities.Add(TClaimsIdentity(aIdentity));
  //aIdentity._AddRef;
end;

destructor TClaimsPrincipal.Destroy;
begin
  {$IFDEF DEBUG_AUTENTICATION}
  TDebugger.Trace(Self,'Destroy');
  {$ENDIF}
  inherited;
end;

constructor TClaimsPrincipal.Create(aIdentities : IList<IIdentity>);
var
  id : IIdentity;
begin
  Create;
  if aIdentities = nil then raise EArgumentNilException.Create('Identities cannot be null');
  for id in aIdentities do fIdentities.Add(id as TClaimsIdentity);
end;

procedure TClaimsPrincipal.AddIdentities(aIdentities: IList<TClaimsIdentity>);
begin
  if aIdentities = nil then raise EArgumentNilException.Create('Identities cannot be null');
  fIdentities.FromArray(aIdentities.ToArray);
end;

procedure TClaimsPrincipal.AddIdentity(aIdentity: TClaimsIdentity);
begin
  if aIdentity = nil then raise EArgumentNilException.Create('Identity cannot be null');
  fIdentities.Add(aIdentity);
end;

function TClaimsPrincipal.FindAll(aMatch : TPredicate<TClaim>): IList<TClaim>;
var
  claim : TClaim;
begin
  Result := TxList<TClaim>.Create;
  for claim in Claims do
  begin
    if aMatch(claim) then Result.Add(claim);
  end;
end;

function TClaimsPrincipal.FindFirst(aMatch : TPredicate<TClaim>): TClaim;
var
  claim : TClaim;
begin
  Result := nil;
  for claim in Claims do
  begin
    if aMatch(claim) then Exit(claim);
  end;
end;

function TClaimsPrincipal.GetClaims: IList<TClaim>;
var
  identity : TClaimsIdentity;
  claim : TClaim;
begin
  Result := TxList<TClaim>.Create;
  for identity in fIdentities do
  begin
    for claim in Identity.Claims do Result.Add(claim);
  end;
end;

function TClaimsPrincipal.GetIdentity: IIdentity;
begin
  if not fIdentities.Any then Exit(nil);
  Result := fIdentities[0];
end;

function TClaimsPrincipal.IsInRole(const aRole: string): Boolean;
var
  claim : TClaim;
begin
  for claim in Claims do
  begin
    if (CompareText(claim.fType,TClaimTypes.Role) = 0) and (CompareText(claim.Value,aRole) = 0) then Exit(True);
  end;
  Result := False;
end;

{ TClaimsIdentity }

procedure TClaimsIdentity.AddClaim(aClaim: TClaim);
begin
  fClaims.Add(aClaim);
end;

constructor TClaimsIdentity.Create;
begin
  fClaims := TObjectList<TClaim>.Create(True);
end;

destructor TClaimsIdentity.Destroy;
begin
  fClaims.Free;
  inherited;
end;

function TClaimsIdentity.GetAuthenticationType: string;
begin
  Result := fAuthenticationType;
end;

function TClaimsIdentity.GetIsAuthenticated: Boolean;
begin
  Result := not fAuthenticationType.IsEmpty;
end;

function TClaimsIdentity.GetName: string;
begin
  Result := fName;
end;

function TClaimsIdentity.HasClaim(const aClaimType,aValue: string): Boolean;
var
  claim : TClaim;
begin
  for claim in fClaims do
  begin
    if (CompareText(claim.&Type,aClaimType) = 0) and (CompareText(claim.Value,aValue) = 0) then Exit(True);
  end;
  Result := False;
end;

{ TClaim }

constructor TClaim.Create(const aClaimType, aValue: string);
begin
  inherited Create;
  fType := aClaimType;
  fValue := aValue;
end;

destructor TClaim.Destroy;
begin
  fProperties.Free;
  inherited;
end;

constructor TClaim.Create;
begin
  fProperties := TDictionary<string,string>.Create;
end;

end.
