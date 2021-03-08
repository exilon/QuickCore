{ ***************************************************************************

  Copyright (c) 2016-2019 Kike Pérez

  Unit        : Quick.Core.Mvc.Context
  Description : Core Http Mvc Context
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 11/10/2019
  Modified    : 11/10/2019

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

unit Quick.Core.Mvc.Context;

{$i QuickCore.inc}

interface

uses
  {$IFDEF DEBUG_HTTPCONTEXT}
    Quick.Debug.Utils,
  {$ENDIF}
  System.SysUtils,
  Quick.Arrays,
  Quick.Cache.Intf,
  Quick.HttpServer.Types,
  Quick.HttpServer.Request,
  Quick.HttpServer.Response,
  Quick.Core.Mvc.Routing,
  Quick.Core.DependencyInjection,
  Quick.Core.Security.Claims;

type

  IHttpContext = interface
  ['{A6646215-7260-4AC2-BC26-C238AB77C153}']
    function GetWebRoot: string;
    procedure SetWebRoot(const Value: string);
    function GetRoute : THttpRoute;
    property WebRoot : string read GetWebRoot write SetWebRoot;
    property Route : THttpRoute read GetRoute;
    function Request : IHttpRequest;
    function Response : IHttpResponse;
  end;

  THttpContextBase = class(TInterfacedObject,IHttpContext)
  private
    fWebRoot : string;
    fRequest : IHttpRequest;
    fResponse : IHttpResponse;
    fRoute : THttpRoute;
    fRequestServices : TServiceProvider;
    fUser : TClaimsPrincipal;
    function GetRoute: THttpRoute;
    function GetWebRoot: string;
    procedure SetWebRoot(const Value: string);
    procedure RaiseHttpError(aCaller : TObject; aStatusCode : Integer; const aStatusText, aMessage : string);
    procedure SetUser(const Value: TClaimsPrincipal);
  public
    constructor Create(aRequest : IHttpRequest; aResponse : IHttpResponse);
    destructor Destroy; override;
    property WebRoot : string read GetWebRoot write SetWebRoot;
    property Route : THttpRoute read GetRoute write fRoute;
    property User : TClaimsPrincipal read fUser write SetUser;
    property RequestServices : TServiceProvider read fRequestServices write fRequestServices;
    function Request : IHttpRequest; inline;
    function Response : IHttpResponse; inline;
    procedure RaiseHttpErrorNotFound(aCaller : TObject; const aMessage : string = '');
    procedure RaiseHttpUnauthorized(aCaller : TObject; const aMessage : string = '');
    procedure RaiseHttpErrorBadRequest(aCaller : TObject; const aMessage : string = '');
    procedure RaiseHttpErrorInternalError(aCaller : TObject; const aMessage : string = '');
  end;

  IRequestContext = interface
  ['{60C5DCB6-F835-4FDC-B424-4E4C690C02BA}']
    function HttpContext : THttpContextBase;
    function RouteData : TRouteData;
  end;

  TRequestContext = class(TInterfacedObject,IRequestContext)
  private
    fHttpContext : THttpContextBase;
    fRouteData : TRouteData;
  public
    constructor Create(aHttpContext : THttpContextBase; aRouteData : TRouteData);
    function HttpContext : THttpContextBase;
    function RouteData : TRouteData;
  end;

implementation

{ THttpContextBase }

constructor THttpContextBase.Create(aRequest : IHttpRequest; aResponse : IHttpResponse);
begin
  fRequest := aRequest;
  fResponse := aResponse;
  fUser := TClaimsPrincipal.Create;
end;

destructor THttpContextBase.Destroy;
begin
  {$IFDEF DEBUG_HTTPCONTEXT}
  TDebugger.Trace(Self,'Destroy');
  {$ENDIF}
  fUser.Free;
  if Assigned(fRequestServices) then fRequestServices.Free;
  inherited;
end;

function THttpContextBase.GetRoute: THttpRoute;
begin
  Result := fRoute;
end;

function THttpContextBase.GetWebRoot: string;
begin
  Result := fWebRoot;
end;

procedure THttpContextBase.RaiseHttpError(aCaller: TObject; aStatusCode: Integer; const aStatusText, aMessage: string);
var
 msg : string;
begin
  fResponse.StatusCode := aStatusCode;
  if aStatusText <> '' then fResponse.StatusText := aStatusText;
  if aMessage <> '' then
  begin
    fResponse.ContentText := aMessage;
    msg := aMessage;
  end
  else msg := Format('%d : %s',[aStatusCode,aStatusText]);
  if aCaller <> nil then raise EControlledException.Create(aCaller,Format('Raised from: %s (%s)',[aCaller.ClassName,msg]))
    else raise EControlledException.Create(nil,msg);
end;

procedure THttpContextBase.RaiseHttpErrorBadRequest(aCaller : TObject; const aMessage : string = '');
begin
  RaiseHttpError(aCaller,400,'Bad Request',aMessage);
end;

procedure THttpContextBase.RaiseHttpErrorInternalError(aCaller : TObject; const aMessage : string = '');
begin
  RaiseHttpError(aCaller,500,'Internal Error',aMessage);
end;

procedure THttpContextBase.RaiseHttpErrorNotFound(aCaller : TObject; const aMessage : string = '');
begin
  RaiseHttpError(aCaller,404,'Not Found',aMessage);
end;

procedure THttpContextBase.RaiseHttpUnauthorized(aCaller : TObject; const aMessage : string = '');
begin
  RaiseHttpError(aCaller,401,'Unauthorized',aMessage);
end;

function THttpContextBase.Request: IHttpRequest;
begin
  Result := fRequest;
end;

function THttpContextBase.Response: IHttpResponse;
begin
  Result := fResponse;
end;

procedure THttpContextBase.SetUser(const Value: TClaimsPrincipal);
begin
  if Assigned(fUser) then fUser.Free;
  fUser := Value;
end;

procedure THttpContextBase.SetWebRoot(const Value: string);
begin
  fWebRoot := Value;
end;

{ TRequestContext }

constructor TRequestContext.Create(aHttpContext : THttpContextBase; aRouteData : TRouteData);
begin
  fHttpContext := aHttpContext;
  fRouteData := aRouteData;
end;

function TRequestContext.HttpContext: THttpContextBase;
begin
  Result := fHttpContext;
end;

function TRequestContext.RouteData: TRouteData;
begin
  Result := fRouteData;
end;

end.
