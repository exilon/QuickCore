{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Security.UserManager
  Description : Core Security User Manager
  Author      : Kike Pérez
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
  Quick.Value,
  Quick.Core.Linq.Abstractions,
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
  end;

  TUserManager<TUser,TRole : class, constructor> = class(TInterfacedObject,IUserManager<TUser,TRole>)
  private
    fIdentityStore : IIdentityStore<TUser,TRole>;
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
  end;

implementation

{ TUserManager<TUser, TRole> }

constructor TUserManager<TUser, TRole>.Create(aIdentityStore: IIdentityStore<TUser,TRole>);
begin
  fIdentityStore := aIdentityStore;
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

end.
