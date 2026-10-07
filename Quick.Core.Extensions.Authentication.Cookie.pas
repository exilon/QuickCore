{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Extensions.Authentication.Cookie
  Description : Core Extensions Cookie Authentication
  Author      : Kike Perez
  Version     : 1.0
  Created     : 01/01/2024
  Modified    : 08/05/2026

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

unit Quick.Core.Extensions.Authentication.Cookie;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.DateUtils,
  Quick.Commons,
  Quick.Options,
  Quick.Core.DependencyInjection,
  Quick.Core.Mvc.Context,
  Quick.Core.Mvc.Session,
  Quick.Core.Security.Claims,
  Quick.Core.Security.Authentication;

const
  COOKIE_AUTH_SCHEME     = 'Cookie';
  COOKIE_AUTH_SESSION_KEY = '__cookie_auth_principal__';

type
  TCookieAuthenticationOptions = class(TOptions)
  private
    fCookieName        : string;
    fCookiePath        : string;
    fHttpOnly          : Boolean;
    fExpireSeconds     : Integer;
    fSlidingExpiration : Boolean;
    fLoginPath         : string;
    fLogoutPath        : string;
  public
    constructor Create; override;
  published
    { Name of the cookie. Defaults to ".auth" }
    property CookieName        : string  read fCookieName        write fCookieName;
    { URL path scope for the cookie. Defaults to "/" }
    property CookiePath        : string  read fCookiePath        write fCookiePath;
    { Mark the cookie as HttpOnly (recommended). Defaults to True }
    property HttpOnly          : Boolean read fHttpOnly          write fHttpOnly;
    { Session lifetime in seconds. 0 = browser session cookie. Defaults to 0 }
    property ExpireSeconds     : Integer read fExpireSeconds     write fExpireSeconds;
    { Renew the expiry on each authenticated request. Defaults to True }
    property SlidingExpiration : Boolean read fSlidingExpiration write fSlidingExpiration;
    { Path to redirect to when authentication is required. Default "/login" }
    property LoginPath  : string read fLoginPath  write fLoginPath;
    { Path to redirect to after sign-out. Default "/logout" }
    property LogoutPath : string read fLogoutPath write fLogoutPath;
  end;

  { TCookieAuthenticationHandler
    Implements IAuthenticationSignInHandler and IAuthenticationSignOutHandler.

    SignIn  — serializes the ClaimsPrincipal into the server-side session and
              sets a browser cookie whose value is the session Id.
    Authenticate — reads the session Id from the cookie, retrieves the
              serialized principal and reconstructs it.
    SignOut — invalidates the session and clears the cookie. }
  TCookieAuthenticationHandler = class(TAuthenticationHandler<TCookieAuthenticationOptions>,
                                       IAuthenticationSignInHandler,
                                       IAuthenticationSignOutHandler)
  private
    function GetCookieValue: string;
    function SerializePrincipal(aPrincipal: TClaimsPrincipal): string;
    function DeserializePrincipal(const aData: string): TClaimsPrincipal;
    procedure SetCookieHeader(const aCookieValue: string; aMaxAge: Integer = -1);
  protected
    procedure DoInitialize; override;
  public
    function Authenticate: TAuthenticateResult; override;
    procedure SignIn(aPrincipal: TClaimsPrincipal; aProperties: TAuthenticationProperties);
    procedure SignOut(aProperties: TAuthenticationProperties);
  end;

  TSetCookieStore = record
  private
    fServiceCollection: TServiceCollection;
  public
    constructor Create(aServiceCollection: TServiceCollection);
    function WithOptions(aConfigureOptions: TConfigureOptionsProc<TCookieAuthenticationOptions>): TSetCookieStore;
  end;

  TCookieAuthenticationServiceExtension = class(TServiceCollectionExtension)
    class function AddCookie(aConfigureOptions: TConfigureOptionsProc<TCookieAuthenticationOptions> = nil): TServiceCollection;
  end;

implementation

{ TCookieAuthenticationOptions }

constructor TCookieAuthenticationOptions.Create;
begin
  inherited;
  fCookieName        := '.auth';
  fCookiePath        := '/';
  fHttpOnly          := True;
  fExpireSeconds     := 0;
  fSlidingExpiration := True;
  fLoginPath         := '/login';
  fLogoutPath        := '/logout';
end;

{ TCookieAuthenticationHandler }

procedure TCookieAuthenticationHandler.DoInitialize;
begin
  // nothing to pre-resolve — options are injected via constructor
end;

function TCookieAuthenticationHandler.GetCookieValue: string;
var
  cookieHeader : string;
  parts        : TArray<string>;
  part         : string;
  kv           : TArray<string>;
begin
  Result := '';
  cookieHeader := fRequest.Headers.GetValue('Cookie');
  if cookieHeader.IsEmpty then Exit;

  parts := cookieHeader.Split([';']);
  for part in parts do
  begin
    kv := part.Trim.Split(['='], 2);
    if (Length(kv) = 2) and (kv[0].Trim = fOptions.CookieName) then
    begin
      Result := kv[1].Trim;
      Exit;
    end;
  end;
end;

{ Serialization format (plain text):
  Line 1 : authType|nameClaimType|roleClaimType
  Lines 2+: <claimType>|<claimValue>
  Fields are separated by '|'. Newline is LF.
  This avoids a JSON dependency inside the handler. }
function TCookieAuthenticationHandler.SerializePrincipal(aPrincipal: TClaimsPrincipal): string;
var
  sb        : TStringBuilder;
  identity  : TClaimsIdentity;
  claim     : TClaim;
  safeValue : string;
begin
  sb := TStringBuilder.Create;
  try
    for identity in aPrincipal.Identities do
    begin
      sb.Append(StringReplace(identity.AuthenticationType, '|', '', [rfReplaceAll]));
      sb.Append('|');
      sb.Append(StringReplace(identity.NameClaimType, '|', '', [rfReplaceAll]));
      sb.Append('|');
      sb.Append(StringReplace(identity.RoleClaimType, '|', '', [rfReplaceAll]));
      sb.AppendLine;
      for claim in identity.Claims do
      begin
        sb.Append(StringReplace(claim.&Type,  '|', '', [rfReplaceAll]));
        sb.Append('|');
        // SEC-27: Escape backslash and pipe in claim values to prevent header injection
        safeValue := StringReplace(claim.Value, '\', '\\', [rfReplaceAll]);
        safeValue := StringReplace(safeValue, '|',  '\p',  [rfReplaceAll]);
        safeValue := StringReplace(safeValue, #10, '',   [rfReplaceAll]);
        sb.Append(safeValue);
        sb.AppendLine;
      end;
      // blank line separates identities
      sb.AppendLine;
    end;
    Result := sb.ToString;
  finally
    sb.Free;
  end;
end;

function TCookieAuthenticationHandler.DeserializePrincipal(const aData: string): TClaimsPrincipal;
var
  lines     : TArray<string>;
  line      : string;
  parts     : TArray<string>;
  principal : TClaimsPrincipal;
  identity  : TClaimsIdentity;
  i         : Integer;
  unescVal  : string;
begin
  principal := TClaimsPrincipal.Create;
  identity  := nil;
  lines := aData.Split([#10]);
  i := 0;
  while i < Length(lines) do
  begin
    line := Trim(lines[i]);
    Inc(i);
    if line.IsEmpty then
    begin
      identity := nil;  // blank line = end of current identity
      Continue;
    end;
    parts := line.Split(['|'], 3);
    if (identity = nil) and (Length(parts) = 3) then
    begin
      // header line: authType|nameClaimType|roleClaimType
      identity := TClaimsIdentity.Create;
      identity.AuthenticationType := parts[0];
      identity.NameClaimType      := parts[1];
      identity.RoleClaimType      := parts[2];
      principal.AddIdentity(identity);
    end
    else if (identity <> nil) and (Length(parts) = 2) then
    begin
      // Unescape SEC-27 escaping: \p -> | and \\ -> \
      unescVal := StringReplace(parts[1], '\p', '|',  [rfReplaceAll]);
      unescVal := StringReplace(unescVal, '\\', '\', [rfReplaceAll]);
      identity.AddClaim(TClaim.Create(parts[0], unescVal));
    end;
  end;
  Result := principal;
end;

procedure TCookieAuthenticationHandler.SetCookieHeader(const aCookieValue: string; aMaxAge: Integer = -1);
var
  cookieParts : TStringBuilder;
begin
  cookieParts := TStringBuilder.Create;
  try
    cookieParts.Append(fOptions.CookieName);
    cookieParts.Append('=');
    cookieParts.Append(aCookieValue);
    cookieParts.Append('; Path=');
    cookieParts.Append(fOptions.CookiePath);
    if fOptions.HttpOnly then cookieParts.Append('; HttpOnly');
    // SEC-28: Always include Secure and SameSite=Strict attributes
    cookieParts.Append('; Secure; SameSite=Strict');
    if aMaxAge >= 0 then
    begin
      cookieParts.Append('; Max-Age=');
      cookieParts.Append(aMaxAge.ToString);
    end
    else if fOptions.ExpireSeconds > 0 then
    begin
      cookieParts.Append('; Max-Age=');
      cookieParts.Append(fOptions.ExpireSeconds.ToString);
    end;
    fResponse.Headers.Add('Set-Cookie', cookieParts.ToString);
  finally
    cookieParts.Free;
  end;
end;

function TCookieAuthenticationHandler.Authenticate: TAuthenticateResult;
var
  sessionId : string;
  data      : string;
  principal : TClaimsPrincipal;
  ticket    : IAuthenticationTicket;
begin
  sessionId := GetCookieValue;
  if sessionId.IsEmpty then
  begin
    Result.NoResult;
    Exit;
  end;

  if fContext.Session = nil then
  begin
    Result.NoResult;
    Exit;
  end;

  // renew idle timeout if sliding expiration is enabled
  fContext.Session.Load;
  data := fContext.Session.GetString(COOKIE_AUTH_SESSION_KEY);
  if data.IsEmpty then
  begin
    Result.NoResult;
    Exit;
  end;

  try
    principal := DeserializePrincipal(data);
    ticket    := TAuthenticationTicket.Create(principal, fScheme.Name);
    Result.Success(ticket);
    // renew cookie lifetime when sliding expiration is on
    if fOptions.SlidingExpiration and (fOptions.ExpireSeconds > 0) then
      SetCookieHeader(sessionId);
  except
    on E: Exception do
      Result.Fail(Exception.CreateFmt('Cookie auth deserialization error: %s', [E.Message]));
  end;
end;

procedure TCookieAuthenticationHandler.SignIn(aPrincipal: TClaimsPrincipal;
  aProperties: TAuthenticationProperties);
var
  sessionId : string;
  data      : string;
begin
  sessionId := CreateGUID.ToString.Trim(['{', '}']);
  data      := SerializePrincipal(aPrincipal);

  if fContext.Session <> nil then
  begin
    fContext.Session.SetString(COOKIE_AUTH_SESSION_KEY, data);
    fContext.Session.Commit;
  end;

  SetCookieHeader(sessionId);
end;

procedure TCookieAuthenticationHandler.SignOut(aProperties: TAuthenticationProperties);
begin
  if fContext.Session <> nil then
  begin
    fContext.Session.Remove(COOKIE_AUTH_SESSION_KEY);
    fContext.Session.Commit;
  end;
  // Clear the cookie by setting Max-Age=0
  SetCookieHeader('', 0);
end;

{ TSetCookieStore }

constructor TSetCookieStore.Create(aServiceCollection: TServiceCollection);
begin
  fServiceCollection := aServiceCollection;
end;

function TSetCookieStore.WithOptions(aConfigureOptions: TConfigureOptionsProc<TCookieAuthenticationOptions>): TSetCookieStore;
var
  options: TCookieAuthenticationOptions;
begin
  Result := Self;
  options := TCookieAuthenticationOptions.Create;
  options.Name := COOKIE_AUTH_SCHEME;
  if Assigned(aConfigureOptions) then aConfigureOptions(options);
  fServiceCollection.Configure<TCookieAuthenticationOptions>(options);
end;

{ TCookieAuthenticationServiceExtension }

class function TCookieAuthenticationServiceExtension.AddCookie(
  aConfigureOptions: TConfigureOptionsProc<TCookieAuthenticationOptions> = nil): TServiceCollection;
var
  authOptions : TAuthenticationOptions;
  options     : TCookieAuthenticationOptions;
begin
  Result := ServiceCollection;

  options := TCookieAuthenticationOptions.Create;
  options.Name := COOKIE_AUTH_SCHEME;
  if Assigned(aConfigureOptions) then aConfigureOptions(options);
  ServiceCollection.Configure<TCookieAuthenticationOptions>(options);

  // Register the handler and add the scheme
  authOptions := ServiceCollection.Resolve<IOptions<TAuthenticationOptions>>.Value;
  ServiceCollection.AddTransient<TCookieAuthenticationHandler>;
  authOptions.AddScheme(COOKIE_AUTH_SCHEME, TypeInfo(TCookieAuthenticationHandler));

  // Set as default sign-in/sign-out scheme if none already set
  if authOptions.DefaultSignInScheme.IsEmpty then
    authOptions.DefaultSignInScheme := COOKIE_AUTH_SCHEME;
  if authOptions.DefaultSignOutScheme.IsEmpty then
    authOptions.DefaultSignOutScheme := COOKIE_AUTH_SCHEME;
  if authOptions.DefaultAuthenticateScheme.IsEmpty then
    authOptions.DefaultAuthenticateScheme := COOKIE_AUTH_SCHEME;
end;

end.
