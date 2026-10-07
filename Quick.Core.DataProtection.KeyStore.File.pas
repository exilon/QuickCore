{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.DataProtection.KeyStore.File
  Description : File-based key store for Data Protection (persistent keys)
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

unit Quick.Core.DataProtection.KeyStore.File;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.NetEncoding,
  Quick.Core.DataProtection;

type
  /// <summary>
  /// File-backed IDataProtectionProvider that persists the master key to disk.
  /// The key is stored as Base64 in a file at aKeyFilePath.
  /// If the file does not exist a new key is generated and saved.
  ///
  /// Equivalent to calling .PersistKeysToFileSystem(path) in ASP.NET Core
  /// DataProtection.
  ///
  /// Usage:
  ///   services.AddDataProtection('/var/app/keys/master.key', 'MyApp');
  /// </summary>
  TFileKeyStoreDataProtectionProvider = class(TDataProtectionProvider)
  private
    fKeyFilePath : string;
    procedure LoadOrCreateKey;
    function ReadKeyFromFile: TBytes;
    procedure WriteKeyToFile(const aKey: TBytes);
  public
    constructor Create(const aKeyFilePath: string; const aApplicationName: string = ''; aKeyLifetimeDays: Integer = 90);
  end;

implementation

{ TFileKeyStoreDataProtectionProvider }

constructor TFileKeyStoreDataProtectionProvider.Create(const aKeyFilePath: string;
  const aApplicationName: string; aKeyLifetimeDays: Integer);
var
  opts : TDataProtectionOptions;
begin
  opts := TDataProtectionOptions.Create;
  try
    opts.ApplicationName  := aApplicationName;
    opts.KeyLifetimeDays  := aKeyLifetimeDays;
    // Call parent with dummy key — will be overwritten by LoadOrCreateKey
    inherited Create(opts);
  finally
    opts.Free;
  end;
  fKeyFilePath := aKeyFilePath;
  LoadOrCreateKey;
end;

procedure TFileKeyStoreDataProtectionProvider.LoadOrCreateKey;
var
  key : TBytes;
begin
  if TFile.Exists(fKeyFilePath) then
    key := ReadKeyFromFile
  else
  begin
    // Use OS CSPRNG — never use Random() for cryptographic key material
    key := SecureRandomBytes(32);
    WriteKeyToFile(key);
  end;
  // Inject the loaded/generated key into the base class via the protected setter
  SetMasterKey(key);
end;

function TFileKeyStoreDataProtectionProvider.ReadKeyFromFile: TBytes;
var
  b64 : string;
begin
  b64    := TFile.ReadAllText(fKeyFilePath).Trim;
  Result := TNetEncoding.Base64.DecodeStringToBytes(b64);
  if Length(Result) <> 32 then
    raise EDataProtectionError.CreateFmt(
      'DataProtection: key file "%s" has invalid length (%d bytes, expected 32)',
      [fKeyFilePath, Length(Result)]);
end;

procedure TFileKeyStoreDataProtectionProvider.WriteKeyToFile(const aKey: TBytes);
var
  dir : string;
begin
  dir := TPath.GetDirectoryName(fKeyFilePath);
  if (dir <> '') and not TDirectory.Exists(dir) then
    TDirectory.CreateDirectory(dir);
  TFile.WriteAllText(fKeyFilePath, TNetEncoding.Base64.EncodeBytesToString(aKey));
end;

end.
