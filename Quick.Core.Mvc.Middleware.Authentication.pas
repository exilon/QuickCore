{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Mvc.Middleware.Authentication
  Description : Core Mvc Authentication Middleware
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 17/03/2020
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

unit Quick.Core.Mvc.Middleware.Authentication;

{$i QuickCore.inc}

interface

uses
  Classes,
  System.SysUtils,
  System.Rtti,
  System.Generics.Collections,
  Quick.Arrays,
  Quick.HttpServer.Types,
  Quick.HttpServer.Request,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.Middleware,
  Quick.Core.Mvc.Context,
  Quick.Core.Mvc.Routing,
  Quick.HttpServer.Response,
  Quick.Core.Security.Claims,
  Quick.Core.Security.Authentication;

type
  TAuthenticationMiddleware = class(TRequestDelegate)
  private
    fAuthenticationService : IAuthenticationService;
    fAuthOptions : TAuthenticationOptions;
  public
    constructor Create(aNext: TRequestDelegate; aAuthenticationService : IAuthenticationService; aOptions : TAuthenticationOptions);
    destructor Destroy; override;
    procedure Invoke(aContext : THttpContextBase); override;
  end;

implementation

{ TAuthenticationMiddleware }

constructor TAuthenticationMiddleware.Create(aNext: TRequestDelegate; aAuthenticationService : IAuthenticationService; aOptions : TAuthenticationOptions);
begin
  inherited Create(aNext);
  fAuthenticationService := aAuthenticationService;
  fAuthOptions := aOptions;
end;

destructor TAuthenticationMiddleware.Destroy;
begin

  inherited;
end;

procedure TAuthenticationMiddleware.Invoke(aContext: THttpContextBase);
var
  scheme : TAuthenticationScheme;
  result : TAuthenticateResult;
begin
  inherited;
  for scheme in fAuthOptions.Schemes do
  begin
    result := fAuthenticationService.Authenticate(aContext,scheme.Name);
    if result.Succeeded then
    begin
      if result.Principal <> nil then
      begin
        aContext.User := result.Principal;
        Break;
      end;
    end;
  end;

  Next(aContext);
end;


end.

