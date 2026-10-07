{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Extensions.Authentication.OAuth2
  Description : Core Extensions Authentication OAuth2 / OpenID Connect
  Author      : Kike Perez
  Version     : 1.0
  Created     : 13/04/2026
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

unit Quick.Core.Extensions.Authentication.OAuth2;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.NetEncoding,
  System.DateUtils,
  System.Net.HttpClient,
  System.Net.URLClient,
  Quick.Options,
  Quick.Core.DependencyInjection,
  Quick.Core.Security.Authentication,
  Quick.Core.Security.Claims,
  Quick.Core.Logging.Abstractions;

const
  OAuth2Defaults_AuthenticationScheme = 'OAuth2';

type
  /// <summary>Options for OAuth2 / OpenID Connect Bearer token validation.</summary>
  TOAuth2Options = class(TOptions)
  private
    fAuthority          : string;
    fClientId           : string;
    fAudience           : string;
    fValidateAudience   : Boolean;
    fValidateIssuer     : Boolean;
    fIntrospectionEndpoint : string;  // RFC 7662 – overrides auto-discovery
    fSaveTokens         : Boolean;
    fRequireHttpsMetadata : Boolean;
  published
    /// <summary>Base URL of the identity provider (e.g. https://accounts.google.com).</summary>
    property Authority : string read fAuthority write fAuthority;
    /// <summary>The OAuth2 client_id registered with the identity provider.</summary>
    property ClientId : string read fClientId write fClientId;
    /// <summary>Expected audience claim in the token.</summary>
    property Audience : string read fAudience write fAudience;
    /// <summary>Validate that the token audience matches Audience. Default True.</summary>
    property ValidateAudience : Boolean read fValidateAudience write fValidateAudience;
    /// <summary>Validate that the token issuer matches Authority. Default True.</summary>
    property ValidateIssuer : Boolean read fValidateIssuer write fValidateIssuer;
    /// <summary>Optional explicit token introspection endpoint (RFC 7662).
    ///  When empty, the handler decodes the JWT payload locally.</summary>
    property IntrospectionEndpoint : string read fIntrospectionEndpoint write fIntrospectionEndpoint;
    /// <summary>Save the raw access token as a Claim on the principal. Default False.</summary>
    property SaveTokens : Boolean read fSaveTokens write fSaveTokens;
    property RequireHttpsMetadata : Boolean read fRequireHttpsMetadata write fRequireHttpsMetadata;
  end;

  /// <summary>Authentication handler for OAuth2 / OpenID Connect tokens.
  ///
  ///  Two validation modes:
  ///  1. Introspection (IntrospectionEndpoint set): issues an RFC 7662 call and
  ///     maps the response JSON fields to claims.
  ///  2. Local decode (default): base64-decodes the JWT payload and maps its
  ///     JSON fields to claims — useful when the token was already verified by
  ///     an upstream API gateway or reverse proxy.
  /// </summary>
  TOAuth2AuthenticationHandler = class(TAuthenticationHandler<TOAuth2Options>, IAuthenticationHandler)
  private
    { Parse JWT payload (middle base64url segment) into a list of name=value pairs. }
    function DecodeJwtPayload(const aToken : string;
      out vClaims : TArray<TPair<string,string>>) : Boolean;
    { Call RFC 7662 introspection endpoint; returns active=true/false and claims. }
    function Introspect(const aToken : string;
      out vClaims : TArray<TPair<string,string>>) : Boolean;
    { Build a TClaimsPrincipal from claim pairs. }
    function BuildPrincipal(const aClaims : TArray<TPair<string,string>>;
      const aScheme : string) : TClaimsPrincipal;
    { Minimal JSON string → key/value flat map (top-level scalars only). }
    class function ParseJsonFlat(const aJson : string) : TArray<TPair<string,string>>;
  protected
    procedure DoInitialize; override;
  public
    constructor Create(aOptions : IOptions<TOAuth2Options>; aLogger : ILogger);
    function Authenticate : TAuthenticateResult; override;
  end;

  TOAuth2ServiceExtension = class(TServiceCollectionExtension)
  public
    class function AddOAuth2(aConfigureOptions : TConfigureOptionsProc<TOAuth2Options>) : TServiceCollection;
  end;

implementation

{ TOAuth2AuthenticationHandler }

constructor TOAuth2AuthenticationHandler.Create(aOptions: IOptions<TOAuth2Options>; aLogger: ILogger);
begin
  inherited Create(aOptions, aLogger);
end;

procedure TOAuth2AuthenticationHandler.DoInitialize;
begin
  // Nothing extra – base class sets fRequest / fContext / fResponse.
end;

class function TOAuth2AuthenticationHandler.ParseJsonFlat(
  const aJson : string) : TArray<TPair<string,string>>;
var
  i     : Integer;
  key   : string;
  value : string;
  s     : string;
  inStr : Boolean;
  depth : Integer;
  pairs : TStringList;
  p     : TStringList;
  name  : string;
  val   : string;
  raw   : string;
  pos1  : Integer;
  pos2  : Integer;
begin
  // Very compact hand-rolled JSON flat parser (no external dependency).
  // Only handles top-level string/number/bool scalar fields.
  SetLength(Result, 0);
  raw := Trim(aJson);
  if raw.IsEmpty or (raw[1] <> '{') then Exit;

  pairs := TStringList.Create;
  try
    // Iterate over the JSON looking for "key": value pairs at depth 1.
    depth  := 0;
    inStr  := False;
    i      := 1;
    key    := '';
    while i <= Length(raw) do
    begin
      case raw[i] of
        '"':
          begin
            inStr := not inStr;
            if inStr and (depth = 1) and (key = '') then
            begin
              // start of a key
              Inc(i);
              while (i <= Length(raw)) and not ((raw[i] = '"') and (raw[i-1] <> '\')) do
              begin
                key := key + raw[i];
                Inc(i);
              end;
              // i now points at closing "
            end
            else if inStr and (depth = 1) and (key <> '') then
            begin
              // start of a string value
              value := '';
              Inc(i);
              while (i <= Length(raw)) and not ((raw[i] = '"') and (raw[i-1] <> '\')) do
              begin
                value := value + raw[i];
                Inc(i);
              end;
              pairs.Add(key + '=' + value);
              key := '';
              value := '';
            end;
          end;
        '{', '[' : if not inStr then Inc(depth);
        '}', ']' : if not inStr then Dec(depth);
        ':' :
          if (not inStr) and (depth = 1) and (key <> '') then
          begin
            // read non-string scalar value (number, bool, null)
            Inc(i);
            while (i <= Length(raw)) and (raw[i] = ' ') do Inc(i);
            if (i <= Length(raw)) and (raw[i] <> '"') and (raw[i] <> '{') and (raw[i] <> '[') then
            begin
              value := '';
              while (i <= Length(raw)) and not (raw[i] in [',', '}', ']', #10, #13]) do
              begin
                value := value + raw[i];
                Inc(i);
              end;
              value := Trim(value);
              if (value <> '') and (value <> 'null') then
                pairs.Add(key + '=' + value);
              key := '';
              value := '';
              Continue; // skip the Inc(i) at bottom
            end;
          end;
      end;
      Inc(i);
    end;

    SetLength(Result, pairs.Count);
    for i := 0 to pairs.Count - 1 do
    begin
      pos1 := Pos('=', pairs[i]);
      Result[i] := TPair<string,string>.Create(
        Copy(pairs[i], 1, pos1 - 1),
        Copy(pairs[i], pos1 + 1, MaxInt));
    end;
  finally
    pairs.Free;
  end;
end;

function TOAuth2AuthenticationHandler.DecodeJwtPayload(const aToken : string;
  out vClaims : TArray<TPair<string,string>>) : Boolean;
var
  parts     : TArray<string>;
  payload   : string;
  decoded   : TBytes;
  json      : string;
  rem       : Integer;
  nowEpoch  : Int64;
  expFound  : Boolean;
  claimIdx  : Integer;
begin
  Result := False;
  SetLength(vClaims, 0);
  parts := aToken.Split(['.']);
  if Length(parts) <> 3 then Exit;
  payload := parts[1];
  // Base64url → standard Base64
  payload := StringReplace(payload, '-', '+', [rfReplaceAll]);
  payload := StringReplace(payload, '_', '/', [rfReplaceAll]);
  rem := Length(payload) mod 4;
  if rem = 2 then payload := payload + '=='
  else if rem = 3 then payload := payload + '=';
  try
    decoded := TNetEncoding.Base64.DecodeStringToBytes(payload);
    json := TEncoding.UTF8.GetString(decoded);
  except
    Exit;
  end;
  vClaims := ParseJsonFlat(json);
  if Length(vClaims) = 0 then Exit;

  // SEC-24: Validate token lifetime from payload claims (exp / nbf)
  nowEpoch := DateTimeToUnix(Now, False);
  expFound := False;
  for claimIdx := 0 to High(vClaims) do
  begin
    if SameText(vClaims[claimIdx].Key, 'exp') then
    begin
      expFound := True;
      if StrToInt64Def(vClaims[claimIdx].Value, 0) < nowEpoch then Exit;  // token expired
    end
    else if SameText(vClaims[claimIdx].Key, 'nbf') then
    begin
      if StrToInt64Def(vClaims[claimIdx].Value, 0) > nowEpoch then Exit;  // token not yet valid
    end;
  end;
  if not expFound then Exit;  // exp claim required

  Result := True;
end;

function TOAuth2AuthenticationHandler.Introspect(const aToken : string;
  out vClaims : TArray<TPair<string,string>>) : Boolean;
var
  http     : THTTPClient;
  resp     : IHTTPResponse;
  body     : string;
  postData : TStringStream;
  pair     : TPair<string,string>;
begin
  Result := False;
  SetLength(vClaims, 0);
  http := THTTPClient.Create;
  try
    postData := TStringStream.Create(
      'token=' + TNetEncoding.URL.Encode(aToken) +
      '&token_type_hint=access_token',
      TEncoding.UTF8);
    try
      http.ContentType := 'application/x-www-form-urlencoded';
      resp := http.Post(fOptions.IntrospectionEndpoint, postData);
      body := resp.ContentAsString(TEncoding.UTF8);
    finally
      postData.Free;
    end;
  finally
    http.Free;
  end;

  if body.IsEmpty then Exit;
  vClaims := ParseJsonFlat(body);
  // RFC 7662 requires "active": true
  for pair in vClaims do
    if SameText(pair.Key, 'active') and SameText(pair.Value.Trim, 'true') then
    begin
      Result := True;
      Break;
    end;
end;

function TOAuth2AuthenticationHandler.BuildPrincipal(
  const aClaims : TArray<TPair<string,string>>;
  const aScheme  : string) : TClaimsPrincipal;
var
  identity  : TClaimsIdentity;
  pair      : TPair<string,string>;
  issuer    : string;
  audience  : string;
  claimType : string;
begin
  issuer   := '';
  audience := '';
  identity := TClaimsIdentity.Create(aScheme);
  for pair in aClaims do
  begin
    if SameText(pair.Key, 'iss') then issuer   := pair.Value
    else if SameText(pair.Key, 'aud') then audience := pair.Value;
    claimType := pair.Key;
    // Map standard JWT claim names to well-known claim types
    if SameText(claimType, 'sub')   then claimType := 'sub'
    else if SameText(claimType, 'email') then claimType := 'email'
    else if SameText(claimType, 'name')  then claimType := 'name'
    else if SameText(claimType, 'role') or SameText(claimType, 'roles') then
      claimType := 'role';
    // SEC-20: Only add DefaultRoleClaimType when the claim is actually a role claim.
    // Adding it for every claim causes privilege escalation.
    if claimType = 'role' then
      identity.AddClaim(TClaimsIdentity.DefaultRoleClaimType, pair.Value);
    identity.AddClaim(claimType, pair.Value);
  end;

  // Optional issuer / audience validation
  if fOptions.ValidateIssuer and (not fOptions.Authority.IsEmpty) then
    if not SameText(issuer, fOptions.Authority) then
    begin
      identity.Free;
      Result := nil;
      Exit;
    end;
  if fOptions.ValidateAudience and (not fOptions.Audience.IsEmpty) then
    if not SameText(audience, fOptions.Audience) then
    begin
      identity.Free;
      Result := nil;
      Exit;
    end;

  Result := TClaimsPrincipal.Create(identity);
end;

function TOAuth2AuthenticationHandler.Authenticate : TAuthenticateResult;
var
  authHeader : string;
  token      : string;
  claims     : TArray<TPair<string,string>>;
  principal  : TClaimsPrincipal;
  ticket     : IAuthenticationTicket;
  ok         : Boolean;
begin
  authHeader := fRequest.Headers.GetValue('Authorization');
  if authHeader.IsEmpty then
  begin
    Result.NoResult;
    Exit;
  end;
  if not authHeader.StartsWith('Bearer ', True) then
  begin
    Result.NoResult;
    Exit;
  end;
  token := authHeader.Substring(7).Trim;
  if token.IsEmpty then
  begin
    Result.Fail(Exception.Create('Empty Bearer token'));
    Exit;
  end;

  if not fOptions.IntrospectionEndpoint.IsEmpty then
  begin
    // SEC-25: Enforce HTTPS on introspection endpoint when RequireHttpsMetadata=True
    if fOptions.RequireHttpsMetadata and
       not fOptions.IntrospectionEndpoint.ToLower.StartsWith('https://') then
    begin
      Result.Fail(Exception.Create('OAuth2: introspection endpoint must use HTTPS'));
      Exit;
    end;
    ok := Introspect(token, claims);
  end
  else
    ok := DecodeJwtPayload(token, claims);

  if not ok then
  begin
    Result.Fail(Exception.Create('OAuth2: token validation failed'));
    Exit;
  end;

  principal := BuildPrincipal(claims, fScheme.Name);
  if principal = nil then
  begin
    Result.Fail(Exception.Create('OAuth2: issuer or audience validation failed'));
    Exit;
  end;

  if fOptions.SaveTokens then
    principal.Identity.AddClaim('access_token', token);

  ticket := TAuthenticationTicket.Create(principal, fScheme.Name);
  Result.Success(ticket);
end;

{ TOAuth2ServiceExtension }

class function TOAuth2ServiceExtension.AddOAuth2(
  aConfigureOptions : TConfigureOptionsProc<TOAuth2Options>) : TServiceCollection;
var
  opts : TOAuth2Options;
begin
  Result := ServiceCollection;
  opts := TOAuth2Options.Create;
  opts.ValidateAudience := True;
  opts.ValidateIssuer   := True;
  opts.RequireHttpsMetadata := True;
  aConfigureOptions(opts);
  opts.HideOptions := True;
  Result.Configure<TOAuth2Options>(opts);
  Result.Configure<TAuthenticationOptions>(
    procedure(aOpts : TAuthenticationOptions)
    begin
      aOpts.AddScheme(OAuth2Defaults_AuthenticationScheme,
        TypeInfo(TOAuth2AuthenticationHandler));
      if aOpts.DefaultAuthenticateScheme = '' then
        aOpts.DefaultAuthenticateScheme := OAuth2Defaults_AuthenticationScheme;
    end);
end;

end.
