{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.DataProtection
  Description : Data Protection API — IDataProtector, IDataProtectionProvider
  Author      : Kike Perez
  Version     : 1.0
  Created     : 29/04/2026
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

unit Quick.Core.DataProtection;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.NetEncoding,
  System.Hash,
  System.Generics.Collections,
  Quick.Commons;

/// <summary>Generate cryptographically secure random bytes using the OS CSPRNG.
/// Uses CryptGenRandom (Windows) or /dev/urandom (POSIX).
/// Safe for use as cryptographic key material, salts, and IVs.</summary>
function SecureRandomBytes(aLength: Integer): TBytes;

type
  EDataProtectionError = class(Exception);

  /// <summary>
  /// Provides data protection (encrypt/decrypt) for a specific purpose string.
  /// Equivalent to IDataProtector in ASP.NET Core DataProtection.
  ///
  /// Usage:
  ///   protector := provider.CreateProtector('MyApp.Cookies');
  ///   encrypted := protector.Protect('sensitive-value');
  ///   plain     := protector.Unprotect(encrypted);
  /// </summary>
  IDataProtector = interface
  ['{D7B3F241-8E94-4C6A-A10F-5D23E97B8C12}']
    /// <summary>Encrypts and signs plaintext. Returns Base64-encoded ciphertext.</summary>
    function Protect(const aPlaintext: string): string;
    /// <summary>Decrypts and verifies ciphertext. Raises EDataProtectionError on tamper/key-miss.</summary>
    function Unprotect(const aCiphertext: string): string;
    /// <summary>Returns a child protector scoped to an additional purpose.</summary>
    function CreateProtector(const aPurpose: string): IDataProtector;
    /// <summary>The purpose chain that identifies this protector.</summary>
    function Purpose: string;
  end;

  /// <summary>
  /// Creates IDataProtector instances scoped to a purpose string.
  /// Equivalent to IDataProtectionProvider in ASP.NET Core.
  ///
  /// Usage:
  ///   provider := services.Resolve<IDataProtectionProvider>;
  ///   protector := provider.CreateProtector('CookieAuth');
  /// </summary>
  IDataProtectionProvider = interface
  ['{A9C4E857-3F12-4B8D-C021-6E74A39D5F16}']
    function CreateProtector(const aPurpose: string): IDataProtector;
  end;

  TDataProtectionOptions = class
  private
    fApplicationName  : string;
    fKeyLifetimeDays  : Integer;
  public
    constructor Create;
    /// <summary>Logical name of the application — baked into every key so
    /// keys cannot be shared across different apps.</summary>
    property ApplicationName: string read fApplicationName write fApplicationName;
    /// <summary>How long a generated key is considered valid (default: 90 days).</summary>
    property KeyLifetimeDays: Integer read fKeyLifetimeDays write fKeyLifetimeDays;
  end;

  /// <summary>
  /// HMAC-SHA256-based protector. The key is derived from the master secret +
  /// purpose chain using HKDF (simplified: PBKDF2/SHA256 stretch). The
  /// ciphertext is Base64(XOR-stream(plaintext, keystream) + HMAC).
  ///
  /// SECURITY NOTE: This implementation uses XOR with a SHA256-derived keystream
  /// for simplicity on all Delphi targets. For production deployments handling
  /// PCI/HIPAA data, replace TDataProtector.EncryptBytes/DecryptBytes with a
  /// proper AES-256-CBC or AES-256-GCM implementation available in your Delphi
  /// version or via OpenSSL.
  /// </summary>
  TDataProtector = class(TInterfacedObject, IDataProtector)
  private
    fMasterKey  : TBytes;
    fPurpose    : string;
    function DeriveKey(const aSalt: TBytes; aLength: Integer): TBytes;
    function ComputeHmac(const aData, aKey: TBytes): TBytes;
    function EncryptBytes(const aPlain: TBytes): TBytes;
    function DecryptBytes(const aPayload: TBytes): TBytes;
  public
    constructor Create(const aMasterKey: TBytes; const aPurpose: string);
    function Protect(const aPlaintext: string): string;
    function Unprotect(const aCiphertext: string): string;
    function CreateProtector(const aPurpose: string): IDataProtector;
    function Purpose: string;
  end;

  /// <summary>Default in-memory key ring. Master key is generated once per
  /// application lifetime and stored in memory. For persistence across restarts
  /// use TFileKeyStoreDataProtectionProvider (Quick.Core.DataProtection.KeyStore.File).</summary>
  TDataProtectionProvider = class(TInterfacedObject, IDataProtectionProvider)
  private
    fMasterKey       : TBytes;
    fApplicationName : string;
    procedure GenerateMasterKey;
  protected
    /// <summary>Injects a loaded key into the base class after construction.
    /// Used by TFileKeyStoreDataProtectionProvider to apply the persisted key.</summary>
    procedure SetMasterKey(const aKey: TBytes);
  public
    constructor Create(aOptions: TDataProtectionOptions); overload;
    constructor Create(const aMasterKey: TBytes; const aApplicationName: string = ''); overload;
    function CreateProtector(const aPurpose: string): IDataProtector;
  end;

implementation

{$IFDEF MSWINDOWS}
uses
  Winapi.Windows;
{$ENDIF}

function SecureRandomBytes(aLength: Integer): TBytes;
{$IFDEF MSWINDOWS}
type
  TCryptAcquireContext = function(var phProv: THandle; szContainer: Pointer;
    szProvider: Pointer; dwProvType: DWORD; dwFlags: DWORD): BOOL; stdcall;
  TCryptGenRandom     = function(hProv: THandle; dwLen: DWORD; pbBuffer: Pointer): BOOL; stdcall;
  TCryptReleaseContext = function(hProv: THandle; dwFlags: DWORD): BOOL; stdcall;
const
  PROV_RSA_FULL       = 1;
  CRYPT_VERIFYCONTEXT = $F0000040;
var
  hLib     : HMODULE;
  hProv    : THandle;
  fnAcquire: TCryptAcquireContext;
  fnGenRand: TCryptGenRandom;
  fnRelease: TCryptReleaseContext;
{$ELSE}
var
  f : TFileStream;
{$ENDIF}
begin
  SetLength(Result, aLength);
  if aLength = 0 then Exit;
{$IFDEF MSWINDOWS}
  hLib := LoadLibrary('advapi32.dll');
  if hLib = 0 then
    raise EDataProtectionError.Create('DataProtection: cannot load advapi32.dll');
  try
    @fnAcquire := GetProcAddress(hLib, 'CryptAcquireContextW');
    @fnGenRand := GetProcAddress(hLib, 'CryptGenRandom');
    @fnRelease := GetProcAddress(hLib, 'CryptReleaseContext');
    if not (Assigned(fnAcquire) and Assigned(fnGenRand) and Assigned(fnRelease)) then
      raise EDataProtectionError.Create('DataProtection: CryptGenRandom not available');
    hProv := 0;
    if not fnAcquire(hProv, nil, nil, PROV_RSA_FULL, CRYPT_VERIFYCONTEXT) then
      raise EDataProtectionError.Create('DataProtection: CryptAcquireContext failed');
    try
      if not fnGenRand(hProv, DWORD(aLength), @Result[0]) then
        raise EDataProtectionError.Create('DataProtection: CryptGenRandom failed');
    finally
      fnRelease(hProv, 0);
    end;
  finally
    FreeLibrary(hLib);
  end;
{$ELSE}
  f := TFileStream.Create('/dev/urandom', fmOpenRead or fmShareDenyNone);
  try
    f.ReadBuffer(Result[0], aLength);
  finally
    f.Free;
  end;
{$ENDIF}
end;

/// <summary>SHA-256 hash of a byte array using the instance API (compatible with
/// all Delphi 10.x versions — the THashSHA2.GetHashBytes(TBytes) class-method
/// overload was only added in later IDE updates).</summary>
function SHA256Bytes(const aData: TBytes): TBytes;
var
  h : THashSHA2;
begin
  h := THashSHA2.Create(THashSHA2.TSHA2Version.SHA256);
  h.Update(aData);
  Result := h.HashAsBytes;
end;

/// <summary>RFC 2104 HMAC-SHA256: H(K⊕opad || H(K⊕ipad || message)).
/// Provides authentication with a secret key — not just a hash of the data.</summary>
function HmacSha256(const aKey, aData: TBytes): TBytes;
const
  BLOCK_SIZE = 64;  // SHA-256 block size in bytes
var
  keyBlock  : TBytes;
  keyHash   : TBytes;
  ipadData  : TBytes;
  opadData  : TBytes;
  innerHash : TBytes;
  i         : Integer;
begin
  // Normalise key: hash if longer than block, zero-pad if shorter
  SetLength(keyBlock, BLOCK_SIZE);
  FillChar(keyBlock[0], BLOCK_SIZE, 0);
  if Length(aKey) > BLOCK_SIZE then
  begin
    keyHash := SHA256Bytes(aKey);
    Move(keyHash[0], keyBlock[0], 32);
  end
  else if Length(aKey) > 0 then
    Move(aKey[0], keyBlock[0], Length(aKey));

  // ipad = keyBlock XOR 0x36 (inner padding)
  // opad = keyBlock XOR 0x5C (outer padding)
  SetLength(ipadData, BLOCK_SIZE + Length(aData));
  SetLength(opadData, BLOCK_SIZE + 32);
  for i := 0 to BLOCK_SIZE - 1 do
  begin
    ipadData[i] := keyBlock[i] xor $36;
    opadData[i] := keyBlock[i] xor $5C;
  end;

  if Length(aData) > 0 then
    Move(aData[0], ipadData[BLOCK_SIZE], Length(aData));

  // inner = SHA256(ipad || message)
  innerHash := SHA256Bytes(ipadData);
  // outer = SHA256(opad || inner)
  Move(innerHash[0], opadData[BLOCK_SIZE], 32);
  Result := SHA256Bytes(opadData);
end;

{ TDataProtectionOptions }

constructor TDataProtectionOptions.Create;
begin
  fApplicationName := 'QuickCore';
  fKeyLifetimeDays := 90;
end;

{ TDataProtector }

constructor TDataProtector.Create(const aMasterKey: TBytes; const aPurpose: string);
begin
  inherited Create;
  fMasterKey := aMasterKey;
  fPurpose   := aPurpose;
end;

function TDataProtector.Purpose: string;
begin
  Result := fPurpose;
end;

function TDataProtector.CreateProtector(const aPurpose: string): IDataProtector;
begin
  Result := TDataProtector.Create(fMasterKey, fPurpose + ':' + aPurpose);
end;

function TDataProtector.DeriveKey(const aSalt: TBytes; aLength: Integer): TBytes;
// HKDF-Expand: block_i = HMAC-SHA256(masterKey, purpose || salt || counter)
// The masterKey participates in EVERY block — no key material lost after round 1.
var
  purposeBytes : TBytes;
  input        : TBytes;
  block        : TBytes;
  counter      : Byte;
  pos, copyLen : Integer;
begin
  purposeBytes := TEncoding.UTF8.GetBytes(fPurpose);
  SetLength(Result, aLength);
  pos     := 0;
  counter := 0;
  while pos < aLength do
  begin
    Inc(counter);
    // input = purpose || salt || counter (counter ensures unique block per iteration)
    SetLength(input, Length(purposeBytes) + Length(aSalt) + 1);
    if Length(purposeBytes) > 0 then
      Move(purposeBytes[0], input[0], Length(purposeBytes));
    if Length(aSalt) > 0 then
      Move(aSalt[0], input[Length(purposeBytes)], Length(aSalt));
    input[Length(purposeBytes) + Length(aSalt)] := counter;
    // HMAC-SHA256(masterKey, input) — masterKey binds every block to the secret
    block := HmacSha256(fMasterKey, input);
    copyLen := aLength - pos;
    if copyLen > 32 then copyLen := 32;
    Move(block[0], Result[pos], copyLen);
    Inc(pos, copyLen);
  end;
end;

function TDataProtector.ComputeHmac(const aData, aKey: TBytes): TBytes;
begin
  // Delegate to proper RFC 2104 HMAC-SHA256 (no Base64 encoding — raw bytes only)
  Result := HmacSha256(aKey, aData);
end;

function TDataProtector.EncryptBytes(const aPlain: TBytes): TBytes;
var
  salt   : TBytes;
  ks     : TBytes;
  cipher : TBytes;
  hmac   : TBytes;
  i      : Integer;
begin
  // Use OS CSPRNG for salt — never use Random() for cryptographic material
  salt := SecureRandomBytes(16);
  ks   := DeriveKey(salt, Length(aPlain));

  SetLength(cipher, Length(aPlain));
  for i := 0 to High(aPlain) do
    cipher[i] := aPlain[i] xor ks[i];

  // Assemble: [16 salt][n cipher]
  SetLength(Result, 16 + Length(cipher));
  Move(salt[0], Result[0], 16);
  if Length(cipher) > 0 then
    Move(cipher[0], Result[16], Length(cipher));

  // Append 32-byte HMAC authenticating the entire [salt + ciphertext]
  hmac := ComputeHmac(Result, fMasterKey);
  SetLength(Result, Length(Result) + 32);
  Move(hmac[0], Result[16 + Length(cipher)], 32);
end;

function TDataProtector.DecryptBytes(const aPayload: TBytes): TBytes;
var
  salt       : TBytes;
  cipher     : TBytes;
  ks         : TBytes;
  storedHmac : TBytes;
  calcHmac   : TBytes;
  dataLen    : Integer;
  diff       : Byte;
  i          : Integer;
begin
  if Length(aPayload) < 16 + 32 then
    raise EDataProtectionError.Create('DataProtection: payload too short');

  dataLen := Length(aPayload) - 16 - 32;

  SetLength(salt, 16);
  Move(aPayload[0], salt[0], 16);

  SetLength(cipher, dataLen);
  if dataLen > 0 then
    Move(aPayload[16], cipher[0], dataLen);

  SetLength(storedHmac, 32);
  Move(aPayload[16 + dataLen], storedHmac[0], 32);

  // Constant-time HMAC comparison — accumulate ALL diffs before raising exception.
  // An early-exit loop would be a timing oracle allowing byte-by-byte HMAC forgery.
  calcHmac := ComputeHmac(Copy(aPayload, 0, 16 + dataLen), fMasterKey);
  diff := 0;
  for i := 0 to 31 do
    diff := diff or (storedHmac[i] xor calcHmac[i]);
  if diff <> 0 then
    raise EDataProtectionError.Create(
      'DataProtection: HMAC verification failed — payload tampered or wrong key');

  ks := DeriveKey(salt, dataLen);
  SetLength(Result, dataLen);
  for i := 0 to dataLen - 1 do
    Result[i] := cipher[i] xor ks[i];
end;

function TDataProtector.Protect(const aPlaintext: string): string;
var
  plainBytes  : TBytes;
  cipherBytes : TBytes;
begin
  plainBytes  := TEncoding.UTF8.GetBytes(aPlaintext);
  cipherBytes := EncryptBytes(plainBytes);
  Result      := TNetEncoding.Base64URL.EncodeBytesToString(cipherBytes);
end;

function TDataProtector.Unprotect(const aCiphertext: string): string;
var
  cipherBytes : TBytes;
  plainBytes  : TBytes;
begin
  cipherBytes := TNetEncoding.Base64URL.DecodeStringToBytes(aCiphertext);
  plainBytes  := DecryptBytes(cipherBytes);
  Result      := TEncoding.UTF8.GetString(plainBytes);
end;

{ TDataProtectionProvider }

constructor TDataProtectionProvider.Create(aOptions: TDataProtectionOptions);
begin
  inherited Create;
  fApplicationName := aOptions.ApplicationName;
  GenerateMasterKey;
end;

constructor TDataProtectionProvider.Create(const aMasterKey: TBytes; const aApplicationName: string);
begin
  inherited Create;
  fMasterKey       := aMasterKey;
  fApplicationName := aApplicationName;
end;

procedure TDataProtectionProvider.GenerateMasterKey;
begin
  // Use OS CSPRNG — never use Random() for cryptographic key material
  fMasterKey := SecureRandomBytes(32);
end;

procedure TDataProtectionProvider.SetMasterKey(const aKey: TBytes);
begin
  if Length(aKey) <> 32 then
    raise EDataProtectionError.CreateFmt(
      'DataProtection: master key must be 32 bytes (got %d)', [Length(aKey)]);
  fMasterKey := aKey;
end;

function TDataProtectionProvider.CreateProtector(const aPurpose: string): IDataProtector;
var
  fullPurpose : string;
begin
  if fApplicationName.IsEmpty then
    fullPurpose := aPurpose
  else
    fullPurpose := fApplicationName + ':' + aPurpose;
  Result := TDataProtector.Create(fMasterKey, fullPurpose);
end;

end.
