{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Security.Jwt
  Description : Core Security JWT Token Service
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

unit Quick.Core.Security.Jwt;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.StrUtils,
  System.DateUtils,
  System.NetEncoding,
  System.Hash,
  System.JSON,
  Quick.Options,
  Quick.Core.Security.Claims;

const
  JWT_DEFAULT_EXPIRY_MINUTES = 60;

type
  TJwtOptions = class(TOptions)
  private
    fSecret : string;
    fIssuer : string;
    fAudience : string;
    fExpiryMinutes : Integer;
    fValidateIssuer : Boolean;
    fValidateAudience : Boolean;
    fValidateLifetime : Boolean;
  public
    constructor Create; override;
  published
    property Secret : string read fSecret write fSecret;
    property Issuer : string read fIssuer write fIssuer;
    property Audience : string read fAudience write fAudience;
    property ExpiryMinutes : Integer read fExpiryMinutes write fExpiryMinutes;
    property ValidateIssuer : Boolean read fValidateIssuer write fValidateIssuer;
    property ValidateAudience : Boolean read fValidateAudience write fValidateAudience;
    property ValidateLifetime : Boolean read fValidateLifetime write fValidateLifetime;
  end;

  IJwtTokenService = interface
  ['{3F90C842-8ED2-47B9-9D1F-D4567F3A1C22}']
    /// <summary>Generate a signed JWT from a ClaimsPrincipal.</summary>
    function GenerateToken(aPrincipal : TClaimsPrincipal) : string;
    /// <summary>Validate token signature + lifetime + issuer/audience.
    ///  Returns True and a new ClaimsPrincipal on success.</summary>
    function ValidateToken(const aToken : string; out aPrincipal : TClaimsPrincipal) : Boolean;
    /// <summary>Decode payload without signature validation (for inspection).</summary>
    function GetUserFromToken(const aToken : string) : TClaimsPrincipal;
  end;

  TJwtTokenService = class(TInterfacedObject, IJwtTokenService)
  private
    fOptions : TJwtOptions;
    function Base64UrlEncode(const aInput : TBytes) : string;
    function Base64UrlDecode(const aInput : string) : TBytes;
    function CreateSignature(const aUnsignedToken : string) : string;
    function UnixEpoch(const aDateTime : TDateTime) : Int64;
    function BuildPrincipal(aPayload : TJSONObject) : TClaimsPrincipal;
  public
    constructor Create(aOptions : IOptions<TJwtOptions>);
    function GenerateToken(aPrincipal : TClaimsPrincipal) : string;
    function ValidateToken(const aToken : string; out aPrincipal : TClaimsPrincipal) : Boolean;
    function GetUserFromToken(const aToken : string) : TClaimsPrincipal;
  end;

  EJwtException = class(Exception);

implementation

{ TJwtOptions }

constructor TJwtOptions.Create;
begin
  inherited;
  fExpiryMinutes := JWT_DEFAULT_EXPIRY_MINUTES;
  fValidateIssuer := True;
  fValidateAudience := False;
  fValidateLifetime := True;
end;

{ TJwtTokenService }

constructor TJwtTokenService.Create(aOptions : IOptions<TJwtOptions>);
begin
  if aOptions = nil then raise EArgumentNilException.Create('JwtOptions cannot be nil');
  fOptions := aOptions.Value;
  if fOptions.Secret = '' then raise EJwtException.Create('JWT Secret must not be empty');
end;

function TJwtTokenService.Base64UrlEncode(const aInput : TBytes) : string;
var
  i : Integer;
begin
  Result := TNetEncoding.Base64Url.EncodeBytesToString(aInput);
  // Strip padding '='
  i := Result.Length;
  while (i > 0) and (Result.Chars[i - 1] = '=') do Dec(i);
  if i < Result.Length then Result := Result.Substring(0, i);
end;

function TJwtTokenService.Base64UrlDecode(const aInput : string) : TBytes;
var
  padded : string;
  rem : Integer;
begin
  padded := aInput;
  rem := padded.Length mod 4;
  if rem = 2 then padded := padded + '=='
  else if rem = 3 then padded := padded + '=';
  Result := TNetEncoding.Base64Url.DecodeStringToBytes(padded);
end;

function TJwtTokenService.UnixEpoch(const aDateTime : TDateTime) : Int64;
begin
  Result := DateTimeToUnix(aDateTime, False);
end;

function TJwtTokenService.CreateSignature(const aUnsignedToken : string) : string;
var
  keyBytes, dataBytes, hmacBytes : TBytes;
begin
  keyBytes  := TEncoding.UTF8.GetBytes(fOptions.Secret);
  dataBytes := TEncoding.UTF8.GetBytes(aUnsignedToken);
  hmacBytes := THashSHA2.GetHMACAsBytes(dataBytes, keyBytes, SHA256);
  Result := Base64UrlEncode(hmacBytes);
end;

function TJwtTokenService.GenerateToken(aPrincipal : TClaimsPrincipal) : string;
var
  headerJSON, payloadJSON : TJSONObject;
  headerStr, payloadStr, unsignedToken : string;
  identity : TClaimsIdentity;
  claim : TClaim;
  issuedAt, expireAt : Int64;
begin
  if aPrincipal = nil then raise EArgumentNilException.Create('Principal cannot be nil');

  // Header
  headerJSON := TJSONObject.Create;
  try
    headerJSON.AddPair('alg', 'HS256');
    headerJSON.AddPair('typ', 'JWT');
    headerStr := Base64UrlEncode(TEncoding.UTF8.GetBytes(headerJSON.ToJSON));
  finally
    headerJSON.Free;
  end;

  // Payload
  issuedAt := UnixEpoch(Now);
  expireAt := UnixEpoch(IncMinute(Now, fOptions.ExpiryMinutes));

  payloadJSON := TJSONObject.Create;
  try
    if fOptions.Issuer <> '' then
      payloadJSON.AddPair('iss', fOptions.Issuer);
    if fOptions.Audience <> '' then
      payloadJSON.AddPair('aud', fOptions.Audience);
    payloadJSON.AddPair('iat', TJSONNumber.Create(issuedAt));
    payloadJSON.AddPair('exp', TJSONNumber.Create(expireAt));

    // Copy claims from principal's first identity
    if (aPrincipal.Identities.Count > 0) and
       (aPrincipal.Identities[0] is TClaimsIdentity) then
    begin
      identity := aPrincipal.Identities[0];
      if identity.Name <> '' then
        payloadJSON.AddPair('sub', identity.Name);
      for claim in identity.Claims do
      begin
        if not claim.&Type.IsEmpty then
          payloadJSON.AddPair(claim.&Type, claim.Value);
      end;
    end;

    payloadStr := Base64UrlEncode(TEncoding.UTF8.GetBytes(payloadJSON.ToJSON));
  finally
    payloadJSON.Free;
  end;

  unsignedToken := headerStr + '.' + payloadStr;
  Result := unsignedToken + '.' + CreateSignature(unsignedToken);
end;

function TJwtTokenService.BuildPrincipal(aPayload : TJSONObject) : TClaimsPrincipal;
var
  identity : TClaimsIdentity;
  pair : TJSONPair;
  skipKeys : TArray<string>;
begin
  skipKeys := ['iss', 'aud', 'iat', 'exp', 'nbf', 'jti'];
  identity := TClaimsIdentity.Create;
  identity.AuthenticationType := TAuthenticationTypes.Signature;
  for pair in aPayload do
  begin
    if pair.JsonString.Value = 'sub' then
      identity.Name := pair.JsonValue.Value
    else if not MatchStr(pair.JsonString.Value, skipKeys) then
      identity.AddClaim(TClaim.Create(pair.JsonString.Value, pair.JsonValue.Value));
  end;
  Result := TClaimsPrincipal.Create(identity as IIdentity);
end;

function TJwtTokenService.ValidateToken(const aToken : string; out aPrincipal : TClaimsPrincipal) : Boolean;
var
  parts : TArray<string>;
  payloadBytes, headerBytes : TBytes;
  payloadJSON, headerJSON : TJSONObject;
  payloadStr, headerStr, unsignedToken, expectedSig : string;
  expValue, issValue, audValue, algValue : TJSONValue;
  expEpoch : Int64;
  sigExpected, sigActual : TBytes;
  i, diff : Integer;
begin
  aPrincipal := nil;
  Result := False;
  parts := aToken.Split(['.']);
  if Length(parts) <> 3 then Exit;

  // SEC-08: Decode and validate header — reject alg:none and non-HS256 algorithms
  headerBytes := Base64UrlDecode(parts[0]);
  headerStr := TEncoding.UTF8.GetString(headerBytes);
  headerJSON := TJSONObject.ParseJSONValue(headerStr) as TJSONObject;
  if headerJSON = nil then Exit;
  try
    algValue := headerJSON.GetValue('alg');
    if algValue = nil then Exit;
    if not SameText(algValue.Value, 'HS256') then Exit;
  finally
    headerJSON.Free;
  end;

  // Verify HMAC signature
  unsignedToken := parts[0] + '.' + parts[1];
  expectedSig := CreateSignature(unsignedToken);

  // SEC-07: Constant-time comparison to prevent timing oracle attacks
  sigExpected := TNetEncoding.Base64Url.DecodeStringToBytes(
    expectedSig + StringOfChar('=', (4 - Length(expectedSig) mod 4) mod 4));
  sigActual := TNetEncoding.Base64Url.DecodeStringToBytes(
    parts[2] + StringOfChar('=', (4 - Length(parts[2]) mod 4) mod 4));
  if Length(sigExpected) <> Length(sigActual) then Exit;
  diff := 0;
  for i := 0 to High(sigExpected) do
    diff := diff or (sigExpected[i] xor sigActual[i]);
  if diff <> 0 then Exit;

  // Decode payload
  payloadBytes := Base64UrlDecode(parts[1]);
  payloadStr := TEncoding.UTF8.GetString(payloadBytes);
  payloadJSON := TJSONObject.ParseJSONValue(payloadStr) as TJSONObject;
  if payloadJSON = nil then Exit;
  try
    // Validate lifetime
    if fOptions.ValidateLifetime then
    begin
      expValue := payloadJSON.GetValue('exp');
      if expValue = nil then Exit;
      expEpoch := (expValue as TJSONNumber).AsInt64;
      if UnixEpoch(Now) > expEpoch then Exit;
    end;

    // Validate issuer
    if fOptions.ValidateIssuer and (fOptions.Issuer <> '') then
    begin
      issValue := payloadJSON.GetValue('iss');
      if (issValue = nil) or (issValue.Value <> fOptions.Issuer) then Exit;
    end;

    // Validate audience
    if fOptions.ValidateAudience and (fOptions.Audience <> '') then
    begin
      audValue := payloadJSON.GetValue('aud');
      if (audValue = nil) or (audValue.Value <> fOptions.Audience) then Exit;
    end;

    aPrincipal := BuildPrincipal(payloadJSON);
    Result := True;
  finally
    payloadJSON.Free;
  end;
end;

function TJwtTokenService.GetUserFromToken(const aToken : string) : TClaimsPrincipal;
var
  parts : TArray<string>;
  payloadBytes : TBytes;
  payloadJSON : TJSONObject;
  payloadStr : string;
begin
  Result := nil;
  parts := aToken.Split(['.']);
  if Length(parts) <> 3 then Exit;
  payloadBytes := Base64UrlDecode(parts[1]);
  payloadStr := TEncoding.UTF8.GetString(payloadBytes);
  payloadJSON := TJSONObject.ParseJSONValue(payloadStr) as TJSONObject;
  if payloadJSON = nil then Exit;
  try
    Result := BuildPrincipal(payloadJSON);
  finally
    payloadJSON.Free;
  end;
end;

end.
