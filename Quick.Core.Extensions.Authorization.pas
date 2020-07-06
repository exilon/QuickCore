{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Extensions.Authorization
  Description : Core Extensions Authorization
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 07/03/2020
  Modified    : 20/03/2020

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

unit Quick.Core.Extensions.Authorization;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Options,
  Quick.Collections,
  Quick.Core.DependencyInjection,
  Quick.Core.Security.Authorization;

type
  TAuthorizationServiceExtension = class(TServiceCollectionExtension)
    class function AddAuthorization(aConfigureOptions : TConfigureOptionsProc<TAuthorizationOptions>) : TServiceCollection;
  end;

implementation

{ TAuthorizationServiceExtension }

class function TAuthorizationServiceExtension.AddAuthorization(aConfigureOptions : TConfigureOptionsProc<TAuthorizationOptions>) : TServiceCollection;
var
  authOptions : TAuthorizationOptions;
  handlerlist : IList<IAuthorizationHandler>;
begin
  Result := ServiceCollection;
  //register Authorization Options
  authOptions := TAuthorizationOptions.Create;
  aConfigureOptions(authOptions);
  authOptions.HideOptions := True;
  Result.Configure<TAuthorizationOptions>(authOptions);
  //register Authorization Evaluator
  Result.AddSingleton<IAuthorizationEvaluator,TDefaultAuthorizationEvaluator>();
  //get all Authorization Handlers
  handlerlist := TXList<IAuthorizationHandler>.Create;
  handlerlist.FromList(Result.AppServices.DependencyInjector.ResolveAll<IAuthorizationHandler>);
  if not handlerlist.Any then
  begin
    Result.AddSingleton<IAuthorizationHandler,TPassThroughAuthorizationHandler>();
    handlerlist.FromList(Result.AppServices.DependencyInjector.ResolveAll<IAuthorizationHandler>);
  end;
  //register Authorization Handler
  Result.AddSingleton<IList<IAuthorizationHandler>>(handlerlist);
  //register Authorization Handler Provider
  Result.AddSingleton<IAuthorizationHandlerProvider,TDefaultAuthorizationHandlerProvider>();
  //register Authorization Policy Provider
  Result.AddSingleton<IAuthorizationPolicyProvider,TDefaultAuthorizationPolicyProvider>();
  //register Authorization Service
  Result.AddSingleton<IAuthorizationService,TDefaultAuthorizationService>()
//  ('',function : TDefaultAuthorizationService
//    begin
//      Result := TDefaultAuthorizationService.Create(TDefaultAuthorizationPolicyProvider.Create(authOptions));
//    end);
end;

end.
