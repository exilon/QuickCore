{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Identity
  Description : Core Identity User Authentication
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 07/03/2020
  Modified    : 07/03/2020

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

unit Quick.Core.Identity;

{$i QuickCore.inc}

interface

uses
  Quick.Options;

type

  TClaimsIdentityOptions = class(TOptions)
  private
    fRoleClaimType : string;
    fSecurityStampClaimType : string;
    fUserIdClaimType : string;
    fUserNameClaimType : string;
  published
    property RoleClaimType : string read fRoleClaimType write fRoleClaimType;
    property SecurityStampClaimType : string read fSecurityStampClaimType write fSecurityStampClaimType;
    property UserIdClaimType : string read fUserIdClaimType write fUserIdClaimType;
    property UserNameClaimType : string read fUserNameClaimType write fUserNameClaimType;
  end;

  TLockOutOptions = class(TOptions)
  private
    fAllowedForNewUsers : Boolean;
    fDefaultLockoutTimeSpan : TDateTime;
    fMaxFailedAccessAttempts : Integer;
  published
    property AllowedForNewUsers : Boolean read fAllowedForNewUsers write fAllowedForNewUsers;
    property DefaultLockoutTimeSpan : TDateTime read fDefaultLockoutTimeSpan write fDefaultLockoutTimeSpan;
    property MaxFailedAccessAttempts : Integer read fMaxFailedAccessAttempts write fMaxFailedAccessAttempts;
  end;

  TPasswordOptions = class(TOptions)
  private
    fRequireDigit : Boolean;
    fRequiredLength  : Integer;
    fRequiredUniqueChars : Integer;
    fRequireLowercase : Boolean;
    fRequireNonAlphanumeric : Boolean;
    fRequireUppercase : Boolean;
  published
    property RequireDigit : Boolean read fRequireDigit write fRequireDigit;
    property RequiredLength : Integer read fRequiredLength write fRequiredLength;
    property RequiredUniqueChars : Integer read fRequiredUniqueChars write fRequiredUniqueChars;
    property RequireLowercase : Boolean read fRequireLowercase write fRequireLowercase;
    property RequireNonAlphanumeric : Boolean read fRequireNonAlphanumeric write fRequireNonAlphanumeric;
    property RequireUppercase : Boolean read fRequireUppercase write fRequireUppercase;
  end;

  TSignInOptions = class(TOptions)
  private
    fRequireConfirmedAccount : Boolean;
    fRequireConfirmedEmail : Boolean;
    fRequireConfirmedPhoneNumber : Boolean;
  published
    property RequireConfirmedAccount : Boolean read fRequireConfirmedAccount write fRequireConfirmedAccount;
    property RequireConfirmedEmail : Boolean read fRequireConfirmedEmail write fRequireConfirmedEmail;
    property RequireConfirmedPhoneNumber : Boolean read fRequireConfirmedPhoneNumber write fRequireConfirmedPhoneNumber;
  end;

  TStoreOptions = class(TOptions)
  private
    fMaxLengthForKeys : Integer;
    fProtectPersonalData : Boolean;
  published
    property MaxLengthForKeys : Integer read fMaxLengthForKeys write fMaxLengthForKeys;
    property ProtectPersonalData : Boolean read fProtectPersonalData write fProtectPersonalData;
  end;

  TTokenOptions = class(TOptions)
  private
    fDefaultAuthenticatorProvider : string;
    fDefaultEmailProvider : string;
    fDefaultPhoneProvider : string;
    fDefaultProvider : string;
  published
    property DefaultAuthenticatorProvider : string read fDefaultAuthenticatorProvider write fDefaultAuthenticatorProvider;
    property DefaultEmailProvider : string read fDefaultEmailProvider write fDefaultEmailProvider;
    property DefaultPhoneProvider : string read fDefaultPhoneProvider write fDefaultPhoneProvider;
    property DefaultProvider : string read fDefaultProvider write fDefaultProvider;
  end;

  TUserOptions = class(TOptions)
  private
    fAllowedUserNameCharacters : string;
    fRequireUniqueEmail : Boolean;
  published
    property AllowedUserNameCharacters : string read fAllowedUserNameCharacters write fAllowedUserNameCharacters;
    property RequireUniqueEmail : Boolean read fRequireUniqueEmail write fRequireUniqueEmail;
  end;

  TIdentityOptions = class(TOptions)
  private
    fClaimsIdentity : TClaimsIdentityOptions;
    fLockOut : TLockOutOptions;
    fPassword : TPasswordOptions;
    fSignIn : TSignInOptions;
    fStores : TStoreOptions;
    fTokens : TTokenOptions;
    fUser : TUserOptions;
  published
    constructor Create; override;
    destructor Destroy; override;
    property LockOut : TLockOutOptions read fLockOut write fLockOut;
    property Password : TPasswordOptions read fPassword write fPassword;
    property SignIn : TSignInOptions read fSignIn write fSignIn;
    property Stores : TStoreOptions read fStores write fStores;
    property Tokens : TTokenOptions read fTokens write fTokens;
    property User : TUserOptions read fUser write fUser;
  end;

implementation

{ TIdentityOptions }

constructor TIdentityOptions.Create;
begin
  fClaimsIdentity := TClaimsIdentityOptions.Create;
  fLockOut := TLockOutOptions.Create;
  fPassword := TPasswordOptions.Create;
  fSignIn := TSignInOptions.Create;
  fStores := TStoreOptions.Create;
  fTokens := TTokenOptions.Create;
  fUser := TUserOptions.Create;
end;

destructor TIdentityOptions.Destroy;
begin
  fClaimsIdentity.Free;
  fLockOut.Free;
  fPassword.Free;
  fSignIn.Free;
  fStores.Free;
  fTokens.Free;
  fUser.Free;
  inherited;
end;

end.
