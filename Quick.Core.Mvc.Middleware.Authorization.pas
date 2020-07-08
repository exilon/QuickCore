{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Mvc.Middleware.Authorization
  Description : Core Mvc Authorization Middleware
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 07/03/2020
  Modified    : 16/04/2020

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

unit Quick.Core.Mvc.Middleware.Authorization;

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
  Quick.Core.Security.Authorization,
  Quick.Core.Security.Claims;

type
  TAuthorizationMiddleware = class(TRequestDelegate)
  private
    fAuthorizationService : IAuthorizationService;
    function ValidateAuthorization(aContext: THttpContextBase) : Boolean;
    function IsValidRole(aContext : THttpContextBase; aAuthorize : Authorize) : Boolean;
    function IsValidPolicy(aContext : THttpContextBase; const aPolicyName : string) : Boolean;
  public
    constructor Create(aNext: TRequestDelegate; aAuthorizationService : IAuthorizationService);
    destructor Destroy; override;
    procedure Invoke(aContext : THttpContextBase); override;
  end;

implementation

{ TAuthorizationMiddleware }

constructor TAuthorizationMiddleware.Create(aNext: TRequestDelegate; aAuthorizationService : IAuthorizationService);
begin
  inherited Create(aNext);
  fAuthorizationService := aAuthorizationService;
end;

destructor TAuthorizationMiddleware.Destroy;
begin

  inherited;
end;

procedure TAuthorizationMiddleware.Invoke(aContext: THttpContextBase);
begin
  inherited;
  //var a := aContext.Route.ActionMethodName;
  ValidateAuthorization(aContext);

  Next(aContext);
end;

function TAuthorizationMiddleware.ValidateAuthorization(aContext: THttpContextBase) : Boolean;
var
  controller : TControllerClass;
  methodname : string;
  isAuthorized : Boolean;
  ctx : TRttiContext;
  rtype : TRttiType;
  attr : TCustomAttribute;
  role : string;
begin
  isAuthorized := False;
  controller := aContext.Route.ControllerClass;
  methodname := aContext.Route.ActionMethodName;
  //get global attributes
  rtype := ctx.GetType(controller);
  for attr in rtype.GetAttributes do
  begin
    if (attr is Authorize) then
    begin
      if IsValidRole(aContext,Authorize(attr)) then isAuthorized := True
        else aContext.RaiseHttpUnauthorized(nil,'');
    end
    else if (attr is AuthorizePolicy) then
    begin
      if IsValidPolicy(aContext,AuthorizePolicy(attr).Name) then isAuthorized := True
        else aContext.RaisehttpUnauthorized(nil,'');
    end;
  end;
  Result := isAuthorized;
  //fAuthorizationService.Authorize(aContext.User,nil,nil);
end;

function TAuthorizationMiddleware.IsValidRole(aContext: THttpContextBase; aAuthorize: Authorize): Boolean;
var
  role : string;
begin
  Result := False;
  if aAuthorize.Roles.IsEmpty then
  begin
    if (aContext.User = nil) or (aContext.User.Identity = nil) then Exit(False);
    Result := aContext.User.Identity.IsAuthenticated;
  end
  else
  begin
    for role in aAuthorize.Roles.Split([',']) do
    begin
      if aContext.User.IsInRole(role) then Exit(True);
    end;
  end;
end;

function TAuthorizationMiddleware.IsValidPolicy(aContext : THttpContextBase; const aPolicyName : string) : Boolean;
var
  authResult : TAuthorizationResult;
begin
  Result := False;
  if (aContext.User = nil) or (aContext.User.Identity = nil) then Exit(True);
  authResult := fAuthorizationService.Authorize(aContext.User,nil,aPolicyName);
  Result := authResult.Succeeded;
end;

end.

