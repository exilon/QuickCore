{ ***************************************************************************

  Copyright (c) 2016-2021 Kike Pérez

  Unit        : Quick.Core.Identity.Store.Entity
  Description : Core Identity Store Database
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 12/03/2020
  Modified    : 29/08/2021

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

unit Quick.Core.Identity.Store.Entity;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  {$IFDEF VALUE_FORMATPARAMS}
  System.Rtti,
  {$ENDIF}
  Quick.Commons,
  Quick.Collections,
  Quick.Value,
  Quick.Core.Entity.DAO,
  Quick.Core.Linq.Abstractions,
  Quick.Core.Identity,
  Quick.Core.Entity,
  Quick.Core.Entity.Database,
  Quick.Core.Entity.Factory.Database,
  Quick.Core.Identity.Store.Abstractions;

type
  TEntityStoreLinq<T : class, constructor> = class(TInterfacedObject,ILinq<T>)
  private
    fLinq : IEntityLinqQuery<T>;
  public
    constructor Create(aLinq : IEntityLinqQuery<T>);
    {$IFDEF VALUE_FORMATPARAMS}
    function Where(const aWhereClause : string; aWhereValues : array of TValue) : ILinq<T>; overload;
    {$ELSE}
    function Where(const aWhereClause : string; aWhereValues : array of const) : ILinq<T>; overload;
    {$ENDIF}
    function Where(const aWhereClause: string): ILinq<T>; overload;
    function Where(aPredicate : TPredicate<T>) : ILinq<T>; overload;
    function OrderBy(const aFieldNames : string) : ILinq<T>;
    function OrderByDescending(const aFieldNames : string) : ILinq<T>;
    function SelectFirst : T;
    function SelectLast : T;
    function SelectTop(aLimit : Integer) : IList<T>;
    function Select : IList<T>; overload;
    function Select(const aPropertyName : string) : IList<TFlexValue>; overload;
    function Count : Integer;
    function Update(const aFields : TArray<string>; aValues : array of const) : Boolean;
    function Delete : Boolean;
  end;

  TEntityIdentityStore<TUser,TRole : class, constructor> = class(TInterfacedObject,IIdentityStore<TUser,TRole>)
  private
    fDBContext : TIdentityDbContext<TUser,TRole>;
    function NewLinQ<T : class, constructor>: IEntityLinqQuery<T>;
    function NewQuery<T : class, constructor>: IEntityQuery<T>;
  public
    constructor Create(aDataBase : TEntityDatabase);
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

{ TEntityIdentityStore<TUser, TRole> }

constructor TEntityIdentityStore<TUser, TRole>.Create(aDataBase: TEntityDatabase);
begin
  fDBContext := TIdentityDbContext<TUser,TRole>.Create(aDataBase);
  if aDataBase.IsConnected then aDataBase.Disconnect;
  fDBContext.Models.PluralizeTableNames := True;
  fDBContext.Connect;
end;

function TEntityIdentityStore<TUser, TRole>.NewLinQ<T>: IEntityLinqQuery<T>;
begin
  Result := TEntityDatabaseFactory.GetQueryInstance<T>(fDBContext.Database,fDBContext.Database.Models.Get(TEntityClass(T)));
end;

function TEntityIdentityStore<TUser, TRole>.NewQuery<T>: IEntityQuery<T>;
begin
  Result := TEntityDatabaseFactory.GetQueryInstance<T>(fDBContext.Database,fDBContext.Database.Models.Get(TEntityClass(T)));
end;

procedure TEntityIdentityStore<TUser, TRole>.AddRole(aRole: TRole);
begin
  fDBContext.Roles.AddOrUpdate(TEntity(aRole));
end;

procedure TEntityIdentityStore<TUser, TRole>.AddUser(aUser: TUser);
begin
  fDBContext.Users.AddOrUpdate(TEntity(aUser));
end;

function TEntityIdentityStore<TUser, TRole>.GetUserById(aId: TFlexValue): TUser;
begin
  Result := fDBContext.Users.Where('Id = ?',[aId.AsString]).SelectFirst;
end;

function TEntityIdentityStore<TUser, TRole>.GetRolebyId(aId: TFlexValue): TRole;
begin
  Result := fDBContext.Roles.Where('Id = ?',[aId.AsString]).SelectFirst;
end;

function TEntityIdentityStore<TUser, TRole>.RemoveUser(aUser: TUser) : Boolean;
begin
  Result := fDBContext.Roles.Delete(TEntity(aUser));
end;

function TEntityIdentityStore<TUser, TRole>.RemoveRole(aRole: TRole) : Boolean;
begin
  Result := fDBContext.Roles.Delete(TEntity(aRole));
end;

function TEntityIdentityStore<TUser, TRole>.Roles: ILinq<TRole>;
begin
  Result := TEntityStoreLinq<TRole>.Create(NewLinq<TRole>);
end;

function TEntityIdentityStore<TUser, TRole>.Users: ILinq<TUser>;
begin
  Result := TEntityStoreLinq<TUser>.Create(NewLinq<TUser>);
end;

function TEntityIdentityStore<TUser, TRole>.ValidateCredentials(const aUsername, aPassword: string): Boolean;
begin
  Result := fDBContext.Users.Where('UserName = ? AND PasswordHash = ?',[aUserName,aPassword]).Count > 0;
end;

{ TEntityStoreLinq<T> }

constructor TEntityStoreLinq<T>.Create(aLinq : IEntityLinqQuery<T>);
begin
  fLinq := aLinq;
end;

function TEntityStoreLinq<T>.Count: Integer;
begin
  Result := fLinq.Count;
end;

function TEntityStoreLinq<T>.Delete: Boolean;
begin
  Result := fLinq.Delete;
end;

function TEntityStoreLinq<T>.OrderBy(const aFieldNames: string): ILinq<T>;
begin
  Result := Self;
  fLinq.OrderBy(aFieldNames);
end;

function TEntityStoreLinq<T>.OrderByDescending(const aFieldNames: string): ILinq<T>;
begin
  Result := Self;
  fLinq.OrderByDescending(aFieldNames);
end;

function TEntityStoreLinq<T>.Select(const aPropertyName: string): IList<TFlexValue>;
begin
  raise ENotImplemented.Create('Feature not implemented yet!');
end;

function TEntityStoreLinq<T>.Select: IList<T>;
begin
  Result := TXList<T>.Create;
  Result.FromArray(fLinq.Select.ToArray);
end;

function TEntityStoreLinq<T>.SelectFirst: T;
begin
  Result := fLinq.SelectFirst;
end;

function TEntityStoreLinq<T>.SelectLast: T;
begin
  Result := fLinq.SelectLast;
end;

function TEntityStoreLinq<T>.SelectTop(aLimit: Integer): IList<T>;
begin
  Result := TXList<T>.Create;
  Result.FromArray(fLinq.SelectTop(aLimit).ToArray);
end;

function TEntityStoreLinq<T>.Update(const aFields: TArray<string>; aValues: array of const): Boolean;
begin
  Result := fLinq.Update(CommaText(aFields),aValues);
end;

function TEntityStoreLinq<T>.Where(aPredicate: TPredicate<T>): ILinq<T>;
begin
  raise ENotImplemented.Create('Feature not implemented yet!');
end;

function TEntityStoreLinq<T>.Where(const aWhereClause: string): ILinq<T>;
begin
  Result := Self;
  fLinq.Where(aWhereClause);
end;

{$IFDEF VALUE_FORMATPARAMS}
function TEntityStoreLinq<T>.Where(const aWhereClause: string; aWhereValues: array of TValue): ILinq<T>;
{$ELSE}
function TEntityStoreLinq<T>.Where(const aWhereClause: string; aWhereValues: array of const): ILinq<T>;
{$ENDIF}
begin
  Result := Self;
  fLinq.Where(aWhereClause,aWhereValues);
end;

end.
