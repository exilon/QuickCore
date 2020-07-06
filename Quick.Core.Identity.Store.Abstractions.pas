{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Identity.Store.Abstractions
  Description : Core Identity Store Abstractions
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 12/03/2020
  Modified    : 14/04/2020

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

unit Quick.Core.Identity.Store.Abstractions;

{$i QuickCore.inc}

interface

uses
  Quick.Value,
  Quick.Core.Linq.Abstractions;

type

  IIdentityStore<TUser, TRole : class, constructor> = interface
  ['{4A0BDD68-01DA-47AB-A77E-214DD3F92DFA}']
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

end.
