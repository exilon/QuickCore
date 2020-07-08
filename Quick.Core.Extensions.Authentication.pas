{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Extensions.Authentication
  Description : Core Extensions Authentication
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 12/03/2020
  Modified    : 18/04/2020

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

unit Quick.Core.Extensions.Authentication;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.TypInfo,
  Quick.Options,
  Quick.Collections,
  Quick.Core.DependencyInjection,
  Quick.Core.Mvc.Middleware,
  Quick.Core.MVC,
  Quick.Core.Entity,
  Quick.Core.Identity,
  Quick.Core.Identity.Store.Abstractions,
  Quick.Core.Identity.Store.Entity,
  Quick.Core.Security.Authentication,
  Quick.Core.Security.UserManager;

type

  TAuthenticationOptions = Quick.Core.Security.Authentication.TAuthenticationOptions;

  TSetIdentityStore<TUser,TRole : class, constructor> = record
  private
    fOptions : TIdentityOptions;
    fServiceCollection : TServiceCollection;
  public
    constructor Create(aServiceCollection : TServiceCollection; aOptions : TIdentityOptions);
    procedure AddEntityStore<T : TDBContext>;
    procedure AddCustomStore(aInstance : IIdentityStore<TUser,TRole>);
  end;

  TAuthenticationServiceExtension = class(TServiceCollectionExtension)
    class function AddIdentity<TUser,TRole : class, constructor>(aConfigureOptions : TConfigureOptionsProc<TIdentityOptions> = nil) : TSetIdentityStore<TUser,TRole>;
    class function AddAuthentication(aConfigureOptions : TConfigureOptionsProc<TAuthenticationOptions> = nil) : TServiceCollection;
  end;

implementation

{ TAuthenticationServiceExtension }

class function TAuthenticationServiceExtension.AddIdentity<TUser,TRole>(aConfigureOptions : TConfigureOptionsProc<TIdentityOptions> = nil) : TSetIdentityStore<TUser,TRole>;
var
  idOptions : TIdentityOptions;
begin
  idOptions := TIdentityOptions.Create;
  if Assigned(aConfigureOptions) then aConfigureOptions(idOptions);
  //idOptions.HideOptions := True;
  ServiceCollection.Configure<TIdentityOptions>(idOptions);
  Result.Create(ServiceCollection,idOptions);
end;

class function TAuthenticationServiceExtension.AddAuthentication(aConfigureOptions : TConfigureOptionsProc<TAuthenticationOptions> = nil) : TServiceCollection;
var
  authOptions : TAuthenticationOptions;
  handlerlist : IList<IAuthenticationHandler>;
begin
  Result := ServiceCollection;
  //register Authentication Options
  authOptions := TAuthenticationOptions.Create;
  if Assigned(aConfigureOptions) then aConfigureOptions(authOptions);
  authOptions.HideOptions := True;
  ServiceCollection.Configure<TAuthenticationOptions>(authOptions);
  //register Authentication Scheme Provider
  ServiceCollection.AddSingleton<IAuthenticationSchemeProvider,TAuthenticationSchemeProvider>();
  //register Authentication Handler Provider
  ServiceCollection.AddSingleton<IAuthenticationHandlerProvider,TAuthenticationHandlerProvider>();
  //register Authentication Service
  ServiceCollection.AddSingleton<IAuthenticationService,TAuthenticationService>();
end;

{ TIdentityStore<TUser, TRole> }

constructor TSetIdentityStore<TUser, TRole>.Create(aServiceCollection : TServiceCollection; aOptions : TIdentityOptions);
begin
  fServiceCollection := aServiceCollection;
  fOptions := aOptions;
end;

procedure TSetIdentityStore<TUser, TRole>.AddCustomStore(aInstance : IIdentityStore<TUser,TRole>);
begin
  fServiceCollection.AddSingleton<IIdentityStore<TUser,TRole>>(aInstance);
  fServiceCollection.AddSingleton<IUserManager<TUser,TRole>,TUserManager<TUser,TRole>>();
  fServiceCollection.Resolve<IUserManager<TUser,TRole>>();
end;

procedure TSetIdentityStore<TUser, TRole>.AddEntityStore<T>;
var
  dbcontext : TDBContext;
  idcontext : TIdentityDbContext<TUser,TRole>;
begin
  dbcontext := fServiceCollection.Resolve<T>();
  fServiceCollection.AddSingleton<IIdentityStore<TUser,TRole>,TEntityIdentityStore<TUser,TRole>>('',function : TEntityIdentityStore<TUser,TRole>
    begin
      Result := TEntityIdentityStore<TUser,TRole>.Create(dbcontext.Database.Clone);
    end);
  fServiceCollection.AddSingleton<IUserManager<TUser,TRole>,TUserManager<TUser,TRole>>();
  fServiceCollection.Resolve<IUserManager<TUser,TRole>>();
end;

end.
