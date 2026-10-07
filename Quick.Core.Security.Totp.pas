{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Security.Totp
  Description : Core Security TOTP (RFC 6238) - Time-based One-Time Passwords
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

unit Quick.Core.Security.Totp;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Hash,
  System.DateUtils,
  System.NetEncoding;

type
  ITotpService = interface
  ['{D8A3C5B2-F741-4E09-B3FA-2ECA19D60F87}']
    /// <summary>Generate a 6-digit TOTP code for the given Base32-encoded secret
    ///  at the current time.</summary>
    function GenerateCode(const aBase32Secret : string) : string;
    /// <summary>Validate a code against the secret. aWindow is the number of
    ///  30-second steps to check on either side (default 1 = ±30 s).</summary>
    function ValidateCode(const aBase32Secret, aCode : string;
      aWindow : Integer = 1) : Boolean;
    /// <summary>Build an otpauth:// URI for use in QR codes (Google Authenticator etc.).</summary>
    function GetProvisioningUri(const aBase32Secret, aAccountName,
      aIssuer : string) : string;
  end;

  TTotpService = class(TInterfacedObject, ITotpService)
  private
    class function Base32Decode(const aBase32 : string) : TBytes;
    class function HotpCode(const aKey : TBytes; aCounter : Int64) : string;
    class function UnixTime : Int64;
  public
    function GenerateCode(const aBase32Secret : string) : string;
    function ValidateCode(const aBase32Secret, aCode : string;
      aWindow : Integer = 1) : Boolean;
    function GetProvisioningUri(const aBase32Secret, aAccountName,
      aIssuer : string) : string;
  end;

implementation

const
  BASE32_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  TOTP_STEP    = 30;   // seconds per step (RFC 6238 default)
  TOTP_DIGITS  = 6;

{ TTotpService }

class function TTotpService.UnixTime : Int64;
begin
  Result := DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now));
end;

class function TTotpService.Base32Decode(const aBase32 : string) : TBytes;
var
  s         : string;
  bits      : Int64;
  bitsCount : Integer;
  i         : Integer;
  ch        : Char;
  idx       : Integer;
  outBytes  : TBytes;
  bytePos   : Integer;
begin
  s := UpperCase(aBase32);
  // Remove padding
  s := StringReplace(s, '=', '', [rfReplaceAll]);
  SetLength(outBytes, (Length(s) * 5) div 8);
  bits := 0;
  bitsCount := 0;
  bytePos := 0;
  for i := 1 to Length(s) do
  begin
    ch  := s[i];
    idx := Pos(ch, BASE32_CHARS) - 1;
    if idx < 0 then Continue;  // skip invalid chars
    bits      := (bits shl 5) or idx;
    Inc(bitsCount, 5);
    if bitsCount >= 8 then
    begin
      Dec(bitsCount, 8);
      if bytePos < Length(outBytes) then
      begin
        outBytes[bytePos] := Byte((bits shr bitsCount) and $FF);
        Inc(bytePos);
      end;
    end;
  end;
  SetLength(outBytes, bytePos);
  Result := outBytes;
end;

class function TTotpService.HotpCode(const aKey : TBytes; aCounter : Int64) : string;
var
  msg     : TBytes;
  i       : Integer;
  hmac    : TBytes;
  offset  : Integer;
  code    : Cardinal;
  divisor : Cardinal;
begin
  // Counter as 8-byte big-endian
  SetLength(msg, 8);
  for i := 7 downto 0 do
  begin
    msg[i] := Byte(aCounter and $FF);
    aCounter := aCounter shr 8;
  end;

  // HMAC-SHA1 via HOTP (RFC 4226)
  hmac := THashSHA1.GetHMACAsBytes(msg, aKey);

  // Dynamic truncation (RFC 4226 §5.4)
  offset := hmac[Length(hmac) - 1] and $0F;
  code := ((Cardinal(hmac[offset])   and $7F) shl 24) or
          ((Cardinal(hmac[offset+1]) and $FF) shl 16) or
          ((Cardinal(hmac[offset+2]) and $FF) shl 8)  or
           (Cardinal(hmac[offset+3]) and $FF);

  // Modulo 10^DIGITS
  divisor := 1;
  for i := 1 to TOTP_DIGITS do divisor := divisor * 10;
  code := code mod divisor;

  Result := Format('%.' + TOTP_DIGITS.ToString + 'd', [code]);
end;

function TTotpService.GenerateCode(const aBase32Secret : string) : string;
var
  key     : TBytes;
  counter : Int64;
begin
  key     := Base32Decode(aBase32Secret);
  counter := UnixTime div TOTP_STEP;
  Result  := HotpCode(key, counter);
end;

function TTotpService.ValidateCode(const aBase32Secret, aCode : string;
  aWindow : Integer = 1) : Boolean;
var
  key       : TBytes;
  counter   : Int64;
  step      : Integer;
  candidate : string;
  ctDiff    : Integer;
  ctIdx     : Integer;
begin
  Result  := False;
  key     := Base32Decode(aBase32Secret);
  counter := UnixTime div TOTP_STEP;
  for step := -aWindow to aWindow do
  begin
    // SEC-16: Constant-time string comparison to prevent timing oracle on TOTP codes
    candidate := HotpCode(key, counter + step);
    ctDiff := 0;
    if Length(candidate) = Length(aCode) then
    begin
      for ctIdx := 1 to Length(candidate) do
        ctDiff := ctDiff or (Ord(candidate[ctIdx]) xor Ord(aCode[ctIdx]));
      if ctDiff = 0 then
      begin
        Result := True;
        Exit;
      end;
    end;
  end;
end;

function TTotpService.GetProvisioningUri(const aBase32Secret, aAccountName,
  aIssuer : string) : string;
begin
  Result := Format('otpauth://totp/%s:%s?secret=%s&issuer=%s&algorithm=SHA1&digits=%d&period=%d',
    [TNetEncoding.URL.Encode(aIssuer),
     TNetEncoding.URL.Encode(aAccountName),
     aBase32Secret,
     TNetEncoding.URL.Encode(aIssuer),
     TOTP_DIGITS,
     TOTP_STEP]);
end;

end.
