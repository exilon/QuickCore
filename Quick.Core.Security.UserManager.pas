{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Security.UserManager
  Description : Core Security User Manager
  Author      : Kike Perez
  Version     : 1.0
  Created     : 12/03/2020
  Modified    : 24/03/2020

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

unit Quick.Core.Security.UserManager;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Hash,
  System.NetEncoding,
  Quick.Value,
  Quick.Core.Linq.Abstractions,
  Quick.Core.DataProtection,
  Quick.Core.Identity.Store.Abstractions;

type
  IUserManager<TUser,TRole> = interface
  ['{7273A630-27CD-4CEF-B6AE-E8EF7E88E1E9}']
    function GetUserById(aId : TFlexValue) : TUser;
    function GetRolebyId(aId : TFlexValue) : TRole;
    procedure AddUser(aUser : TUser);
    function RemoveUser(aUser : TUser) : Boolean;
    procedure AddRole(aRole : TRole);
    function RemoveRole(aRole : TRole) : Boolean;
    function ValidateCredentials(const aUsername, aPassword : string) : Boolean;
    function Users : ILinq<TUser>;
    function Roles : ILinq<TRole>;
    // Extended methods
    function FindByName(const aUserName : string) : TUser;
    function FindByEmail(const aEmail : string) : TUser;
    function ChangePassword(aUser : TUser; const aCurrentPassword, aNewPassword : string) : Boolean;
    function AddToRole(aUser : TUser; const aRoleName : string) : Boolean;
    function RemoveFromRole(aUser : TUser; const aRoleName : string) : Boolean;
    function IsInRole(aUser : TUser; const aRoleName : string) : Boolean;
    function LockUser(aUser : TUser; aEnd : TDateTime) : Boolean;
    function UnlockUser(aUser : TUser) : Boolean;
    function IsLockedOut(aUser : TUser) : Boolean;
    function RefreshSecurityStamp(aUser : TUser) : string;
    function GetSecurityStamp(aUser : TUser) : string;
    function ValidateSecurityStamp(aUser : TUser; const aStamp : string) : Boolean;
  end;

  TUserManager<TUser,TRole : class, constructor> = class(TInterfacedObject,IUserManager<TUser,TRole>)
  private
    fIdentityStore : IIdentityStore<TUser,TRole>;
    function HashPassword(const aPassword : string) : string;
    function VerifyPasswordHash(const aPassword, aStoredHash : string) : Boolean;
  public
    constructor Create(aIdentityStore : IIdentityStore<TUser,TRole>);
    function GetUserById(aId : TFlexValue) : TUser;
    function GetRolebyId(aId : TFlexValue) : TRole;
    procedure AddUser(aUser : TUser);
    function RemoveUser(aUser : TUser) : Boolean;
    procedure AddRole(aRole : TRole);
    function RemoveRole(aRole : TRole) : Boolean;
    function ValidateCredentials(const aUsername, aPassword : string) : Boolean;
    function Users : ILinq<TUser>;
    function Roles : ILinq<TRole>;
    // Extended methods
    function FindByName(const aUserName : string) : TUser;
    function FindByEmail(const aEmail : string) : TUser;
    function ChangePassword(aUser : TUser; const aCurrentPassword, aNewPassword : string) : Boolean;
    function AddToRole(aUser : TUser; const aRoleName : string) : Boolean;
    function RemoveFromRole(aUser : TUser; const aRoleName : string) : Boolean;
    function IsInRole(aUser : TUser; const aRoleName : string) : Boolean;
    function LockUser(aUser : TUser; aEnd : TDateTime) : Boolean;
    function UnlockUser(aUser : TUser) : Boolean;
    function IsLockedOut(aUser : TUser) : Boolean;
    function RefreshSecurityStamp(aUser : TUser) : string;
    function GetSecurityStamp(aUser : TUser) : string;
    function ValidateSecurityStamp(aUser : TUser; const aStamp : string) : Boolean;
  end;

implementation

{ TUserManager<TUser, TRole> }

constructor TUserManager<TUser, TRole>.Create(aIdentityStore: IIdentityStore<TUser,TRole>);
begin
  fIdentityStore := aIdentityStore;
end;

function TUserManager<TUser, TRole>.HashPassword(const aPassword : string) : string;
const
  PBKDF2_ITERATIONS = 10000;
  SALT_SIZE         = 16;
var
  saltBytes    : TBytes;
  saltB64      : string;
  pwdBytes     : TBytes;
  block        : TBytes;
  u, xorBlock  : TBytes;
  j, iter      : Integer;
  blockNum     : Cardinal;
begin
  // SEC-02: PBKDF2-HMAC-SHA256 with random 16-byte salt
  // Format: "pbkdf2-sha256$10000$base64(salt)$base64(hash)"
  saltBytes := SecureRandomBytes(SALT_SIZE);
  saltB64 := TNetEncoding.Base64.EncodeBytesToString(saltBytes);

  // PBKDF2 with one block (PRF output = 32 bytes = exactly one SHA-256 block)
  pwdBytes := TEncoding.UTF8.GetBytes(aPassword);

  // Block index 1 big-endian
  blockNum := 1;
  SetLength(block, SALT_SIZE + 4);
  Move(saltBytes[0], block[0], SALT_SIZE);
  block[SALT_SIZE]     := Byte(blockNum shr 24);
  block[SALT_SIZE + 1] := Byte(blockNum shr 16);
  block[SALT_SIZE + 2] := Byte(blockNum shr 8);
  block[SALT_SIZE + 3] := Byte(blockNum);

  u := THashSHA2.GetHMACAsBytes(block, pwdBytes, SHA256);
  xorBlock := Copy(u);
  for iter := 2 to PBKDF2_ITERATIONS do
  begin
    u := THashSHA2.GetHMACAsBytes(u, pwdBytes, SHA256);
    for j := 0 to High(u) do
      xorBlock[j] := xorBlock[j] xor u[j];
  end;

  Result := 'pbkdf2-sha256$' + IntToStr(PBKDF2_ITERATIONS) + '$' + saltB64 + '$' +
            TNetEncoding.Base64.EncodeBytesToString(xorBlock);
end;

function TUserManager<TUser, TRole>.VerifyPasswordHash(const aPassword, aStoredHash : string) : Boolean;
var
  parts        : TArray<string>;
  iterations   : Integer;
  saltBytes    : TBytes;
  storedBytes  : TBytes;
  pwdBytes     : TBytes;
  block        : TBytes;
  u, xorBlock  : TBytes;
  j, iter      : Integer;
  blockNum     : Cardinal;
  i, diff      : Integer;
  legacyHash   : string;
begin
  Result := False;
  // Support legacy plain SHA-256 hashes (format has no '$')
  if not aStoredHash.Contains('$') then
  begin
    // Legacy path: plain SHA-256 — constant-time compare
    legacyHash := THashSHA2.GetHashString(aPassword, SHA256);
    if Length(legacyHash) <> Length(aStoredHash) then Exit;
    diff := 0;
    for i := 1 to Length(legacyHash) do
      diff := diff or (Ord(legacyHash[i]) xor Ord(aStoredHash[i]));
    Result := (diff = 0);
    Exit;
  end;

  parts := aStoredHash.Split(['$']);
  if Length(parts) <> 4 then Exit;
  if parts[0] <> 'pbkdf2-sha256' then Exit;
  iterations := StrToIntDef(parts[1], 0);
  if iterations <= 0 then Exit;

  saltBytes   := TNetEncoding.Base64.DecodeStringToBytes(parts[2]);
  storedBytes := TNetEncoding.Base64.DecodeStringToBytes(parts[3]);
  pwdBytes    := TEncoding.UTF8.GetBytes(aPassword);

  blockNum := 1;
  SetLength(block, Length(saltBytes) + 4);
  Move(saltBytes[0], block[0], Length(saltBytes));
  block[Length(saltBytes)]     := Byte(blockNum shr 24);
  block[Length(saltBytes) + 1] := Byte(blockNum shr 16);
  block[Length(saltBytes) + 2] := Byte(blockNum shr 8);
  block[Length(saltBytes) + 3] := Byte(blockNum);

  u := THashSHA2.GetHMACAsBytes(block, pwdBytes, SHA256);
  xorBlock := Copy(u);
  for iter := 2 to iterations do
  begin
    u := THashSHA2.GetHMACAsBytes(u, pwdBytes, SHA256);
    for j := 0 to High(u) do
      xorBlock[j] := xorBlock[j] xor u[j];
  end;

  if Length(xorBlock) <> Length(storedBytes) then Exit;
  diff := 0;
  for i := 0 to High(xorBlock) do
    diff := diff or (xorBlock[i] xor storedBytes[i]);
  Result := (diff = 0);
end;

procedure TUserManager<TUser, TRole>.AddUser(aUser: TUser);
begin
  fIdentityStore.AddUser(aUser);
end;

procedure TUserManager<TUser, TRole>.AddRole(aRole: TRole);
begin
  fIdentityStore.AddRole(aRole);
end;

function TUserManager<TUser, TRole>.GetRolebyId(aId: TFlexValue): TRole;
begin
  Result := fIdentityStore.GetRolebyId(aId);
end;

function TUserManager<TUser, TRole>.GetUserById(aId: TFlexValue): TUser;
begin
  Result := fIdentityStore.GetUserById(aId);
end;

function TUserManager<TUser, TRole>.RemoveRole(aRole: TRole): Boolean;
begin
  Result := fIdentityStore.RemoveRole(aRole);
end;

function TUserManager<TUser, TRole>.RemoveUser(aUser: TUser): Boolean;
begin
  Result := fIdentityStore.RemoveUser(aUser);
end;

function TUserManager<TUser, TRole>.Roles: ILinq<TRole>;
begin
  Result := fIdentityStore.Roles;
end;

function TUserManager<TUser, TRole>.Users: ILinq<TUser>;
begin
  Result := fIdentityStore.Users;
end;

function TUserManager<TUser, TRole>.ValidateCredentials(const aUsername, aPassword: string): Boolean;
begin
  Result := fIdentityStore.ValidateCredentials(aUserName,aPassword);
end;

function TUserManager<TUser, TRole>.FindByName(const aUserName : string) : TUser;
begin
  Result := fIdentityStore.FindByName(aUserName);
end;

function TUserManager<TUser, TRole>.FindByEmail(const aEmail : string) : TUser;
begin
  Result := fIdentityStore.FindByEmail(aEmail);
end;

function TUserManager<TUser, TRole>.ChangePassword(aUser : TUser;
  const aCurrentPassword, aNewPassword : string) : Boolean;
var
  currentHash : string;
  newHash     : string;
begin
  Result := False;
  // Verify current password
  currentHash := fIdentityStore.GetPasswordHash(aUser);
  // SEC-09: Use constant-time PBKDF2 verification to prevent timing oracle
  if not VerifyPasswordHash(aCurrentPassword, currentHash) then Exit;
  // Set new password hash
  newHash := HashPassword(aNewPassword);
  Result := fIdentityStore.SetPasswordHash(aUser, newHash);
  if Result then
    // Rotate security stamp on password change
    fIdentityStore.SetSecurityStamp(aUser, TGUID.NewGuid.ToString);
end;

function TUserManager<TUser, TRole>.AddToRole(aUser : TUser; const aRoleName : string) : Boolean;
begin
  Result := fIdentityStore.AddUserToRole(aUser, aRoleName);
end;

function TUserManager<TUser, TRole>.RemoveFromRole(aUser : TUser; const aRoleName : string) : Boolean;
begin
  Result := fIdentityStore.RemoveUserFromRole(aUser, aRoleName);
end;

function TUserManager<TUser, TRole>.IsInRole(aUser : TUser; const aRoleName : string) : Boolean;
var
  roles : TArray<string>;
  role  : string;
begin
  roles := fIdentityStore.GetRolesForUser(aUser);
  for role in roles do
    if SameText(role, aRoleName) then Exit(True);
  Result := False;
end;

function TUserManager<TUser, TRole>.LockUser(aUser : TUser; aEnd : TDateTime) : Boolean;
begin
  Result := fIdentityStore.SetLockoutEnd(aUser, aEnd);
end;

function TUserManager<TUser, TRole>.UnlockUser(aUser : TUser) : Boolean;
begin
  Result := fIdentityStore.SetLockoutEnd(aUser, 0);
end;

function TUserManager<TUser, TRole>.IsLockedOut(aUser : TUser) : Boolean;
begin
  Result := fIdentityStore.IsLockedOut(aUser);
end;

function TUserManager<TUser, TRole>.RefreshSecurityStamp(aUser : TUser) : string;
begin
  Result := TGUID.NewGuid.ToString;
  fIdentityStore.SetSecurityStamp(aUser, Result);
end;

function TUserManager<TUser, TRole>.GetSecurityStamp(aUser : TUser) : string;
begin
  Result := fIdentityStore.GetSecurityStamp(aUser);
end;

function TUserManager<TUser, TRole>.ValidateSecurityStamp(aUser : TUser;
  const aStamp : string) : Boolean;
begin
  Result := SameText(fIdentityStore.GetSecurityStamp(aUser), aStamp);
end;

end.
