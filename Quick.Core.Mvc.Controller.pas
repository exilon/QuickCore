{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Mvc.Controller
  Description : Core Mvc Controller
  Author      : Kike Perez
  Version     : 1.0
  Created     : 30/08/2019
  Modified    : 06/06/2020

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

unit Quick.Core.Mvc.Controller;

interface

{$i QuickCore.inc}

uses
  {$IFDEF DEBUG_ROUTING}
  Quick.Debug.Utils,
  {$ENDIF}
  System.SysUtils,
  Quick.Logger.Intf,
  Quick.HttpServer.Types,
  Quick.HttpServer.Request,
  Quick.HttpServer.Response,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Mvc.Context,
  Quick.Core.Mvc.Routing,
  Quick.Core.Mvc.ActionInvoker,
  Quick.Core.Mvc.ViewFeatures,
  Quick.Core.Security.Claims;

type
  IHttpController = interface
  ['{D2A3C605-360C-4B6C-844B-5745F97865D9}']
    procedure Execute(aRequestContext : TRequestContext; aViewEngine : IViewEngine);
  end;

  TExecuteEvent = procedure(aRequestContext : TRequestContext) of object;

  {$M+}
  THttpController = class(TController,IHttpController)
  private
    fHttpContext : THttpContextBase;
    fRequest : IHttpRequest;
    fResponse : IHttpResponse;
    fRoute : THttpRoute;
    fLogger : ILogger;
    fOnResultExecuting : TExecuteEvent;
    fOnResultExecuted : TExecuteEvent;
    fViewData : TViewDataDictionary;
    fViewEngine : IViewEngine;
    function GetContext: THttpContextBase;
    procedure SetContext(const Value: THttpContextBase);
    function GetUser: TClaimsPrincipal;
  protected
    function StatusCode(const aStatusCode : THttpStatusCode; const aStatusText : string = '') : TStatusResult; overload;
    function StatusCode(aStatusCode : Integer; const aStatusText : string = '') : TStatusResult; overload;
    function Ok(const aStatusText : string = '') : TStatusResult;
    function Accepted(const aStatusText : string = '') : TStatusResult;
    function BadRequest(const aStatusText : string = '') : TStatusResult;
    function NotFound(const aStatusText : string = '') : TStatusResult;
    function Forbid(const aStatusText : string = '') : TStatusResult;
    function Unauthorized(const aStatusText : string = '') : TStatusResult;
    function Redirect(const aURL : string) : TRedirectResult;
    function RedirectPermanent(const aURL : string) : TRedirectResult;
    function Content(const aContentText : string) : TContentResult;
    function Json(aObject: TObject; aOnlyPublishedProperties : Boolean = False): TJsonResult; overload;
    function Json(const aJsonText : string): TJsonResult; overload;
    function View(const aView : string = '') : TViewResult;
    { Resource-based authorization helper.
      Evaluates the named policy against the current User and the supplied
      resource object.  Returns True when the policy succeeds.
      Requires IAuthorizationService to be registered via AddAuthorization(). }
    function AuthorizeResource(aResource: TObject; const aPolicyName: string): Boolean; overload;
  public
    destructor Destroy; override;
    //property Resolver : IDependencyResolver read fResolver;
    property Route : THttpRoute read fRoute;
    property Request : IHttpRequest read fRequest;
    property Response : IHttpResponse read fResponse;
    property ViewData : TViewDataDictionary read fViewData write fViewData;
    property Logger : ILogger read fLogger;
    property HttpContext : THttpContextBase read GetContext write SetContext;
    property User : TClaimsPrincipal read GetUser;
    property OnResultExecuting : TExecuteEvent read fOnResultExecuting write fOnResultExecuting;
    property OnResultExecuted : TExecuteEvent read fOnResultExecuted write fOnResultExecuted;
    //property OnException
    //property OnAuthorization
    procedure Execute(aRequestContext : TRequestContext; aViewEngine : IViewEngine); virtual;
  end;
  {$M-}

  THttpControllerClass = class of THttpController;

  { Attributes }

  ActionName = class(TCustomAttribute)
  private
    fName : string;
  public
    constructor Create(const aName: string);
    property Name : string read fName;
  end;

  NonAction = class(TCustomAttribute);

  TMethodVerbAttribute = class(TCustomAttribute)
  private
    fRoute : string;
  public
    constructor Create(const aRoute : string = '');
    property Route : string read fRoute;
  end;

  HttpGet = class(TMethodVerbAttribute);

  HttpPost = class(TMethodVerbAttribute);

  HttpPut = class(TMethodVerbAttribute);

  HttpDelete = class(TMethodVerbAttribute);

  HttpMethod = class(TCustomAttribute)
  private
    fName : string;
  public
    constructor Create(const aName: string);
    property Name : string read fName;
  end;

  AcceptVerbs = class(TCustomAttribute)
    private
    fMethodVerbs : TMethodVerbs;
  public
    constructor Create(const aVerbs: TMethodVerbs);
    property Verbs : TMethodVerbs read fMethodVerbs;
  end;

  Route = class(TCustomAttribute)
  private
    fURL : string;
  public
    constructor Create(const aURL: string);
    property URL : string read fURL;
  end;

  Authorize = class(TCustomAttribute)
  private
    fRoles : string;
  public
    constructor Create(const aRoles : string = '');
    property Roles : string read fRoles;
  end;

  AuthorizePolicy = class(TCustomAttribute)
  private
    fName : string;
  public
    constructor Create(const aName : string);
    property Name : string read fName;
  end;

  AllowAnonymous = class(TCustomAttribute);

  OutputCache = class(TCustomAttribute)
  private
    fDuration : Integer;
  public
    constructor Create(aDurationMS : Integer);
    property Duration : Integer read fDuration;
  end;

  FromBody = class(TCustomAttribute);

  FromQuery = class(TCustomAttribute)
  private
    fName : string;
  public
    constructor Create(const aName : string = '');
    property Name : string read fName;
  end;

  FromHeader = class(TCustomAttribute)
  private
    fName : string;
  public
    constructor Create(const aName : string = '');
    property Name : string read fName;
  end;

  /// <summary>Bind a controller constructor parameter from a named (keyed) DI registration.
  /// Equivalent to .NET 8 [FromKeyedServices("key")].
  /// Example:  constructor Create([FromKeyedServices('secondary')] aRepo: IRepository);</summary>
  FromKeyedServices = class(TCustomAttribute)
  private
    fKey : string;
  public
    constructor Create(const aKey : string);
    property Key : string read fKey;
  end;

  ApiController = class(TCustomAttribute);

  (* Applied to a controller to declare which API version(s) it implements.
    Use with [Route('api/v<major>/[controller]')] for URL-based versioning. *)
  ApiVersion = class(TCustomAttribute)
  private
    fVersion : string;
    fDeprecated : Boolean;
  public
    constructor Create(const aVersion : string; aDeprecated : Boolean = False);
    property Version    : string  read fVersion;
    property Deprecated : Boolean read fDeprecated;
  end;

  procedure RegisterController(aHttpController : THttpControllerClass);

var
  RegisteredControllers : TArray<THttpControllerClass>;

implementation

uses
  RTTI,
  Quick.Core.Mvc.Filters,
  Quick.Core.Security.Authorization;


procedure RegisterController(aHttpController : THttpControllerClass);
begin
  RegisteredControllers := RegisteredControllers + [aHttpController];
end;

{ ApiVersion }

constructor ApiVersion.Create(const aVersion : string; aDeprecated : Boolean);
begin
  fVersion    := aVersion;
  fDeprecated := aDeprecated;
end;

{ FromQuery }

constructor FromQuery.Create(const aName : string);
begin
  fName := aName;
end;

{ FromHeader }

constructor FromHeader.Create(const aName : string);
begin
  fName := aName;
end;

{ FromKeyedServices }

constructor FromKeyedServices.Create(const aKey : string);
begin
  fKey := aKey;
end;

{ TMethodVerbAttribute }

constructor TMethodVerbAttribute.Create(const aRoute: string);
begin
  fRoute := aRoute;
end;

{ THttpMethod }

constructor HttpMethod.Create(const aName: string);
begin
  fName := Name;
end;

{ THttpPath }

constructor Route.Create(const aURL: string);
begin
  fURL := aURL;
end;

{ OutputCache }

constructor OutputCache.Create(aDurationMS: Integer);
begin
  fDuration := aDurationMS;
end;

{ ActionName }

constructor ActionName.Create(const aName: string);
begin
  fName := aName;
end;

{ AcceptVerbs }

constructor AcceptVerbs.Create(const aVerbs: TMethodVerbs);
begin
  fMethodVerbs := aVerbs;
end;

{ THttpController }

procedure THttpController.Execute(aRequestContext : TRequestContext; aViewEngine : IViewEngine);
var
  ctx          : TRttiContext;
  rtype        : TRttiType;
  rmethod      : TRttiMethod;
  attr         : TCustomAttribute;
  filterAttr   : TActionFilterAttribute;
  execCtx      : TActionExecutingContext;
  doneCtx      : TActionExecutedContext;
  actionError  : Exception;
  actionContext : TActionContext;
begin
  {$IFDEF DEBUG_ROUTING}
    TDebugger.Enter(Self,Format('Execute (%s)',[aRequestContext.HttpContext.Request.URL])).TimeIt;
  {$ENDIF}
  if Assigned(fOnResultExecuting) then fOnResultExecuting(aRequestContext);
  fRequest := aRequestContext.HttpContext.Request;
  fHttpContext := aRequestContext.HttpContext;
  fResponse := aRequestContext.HttpContext.Response;
  fRoute := aRequestContext.HttpContext.Route;
  fViewData := TViewDataDictionary.Create;
  fViewEngine := aViewEngine;

  // --- collect action filters from controller class + action method ---
  execCtx := TActionExecutingContext.Create(aRequestContext);
  doneCtx := nil;
  actionError := nil;
  rtype := nil;
  rmethod := nil;
  try
    rtype := ctx.GetType(aRequestContext.HttpContext.Route.ControllerClass);
    if rtype <> nil then
      rmethod := rtype.GetMethod(aRequestContext.HttpContext.Route.ActionMethodName);

    // OnActionExecuting: controller-level filters first, then method-level
    if rtype <> nil then
      for attr in rtype.GetAttributes do
        if attr is TActionFilterAttribute then
        begin
          filterAttr := TActionFilterAttribute(attr);
          filterAttr.OnActionExecuting(execCtx);
          if execCtx.Canceled then Break;
        end;
    if (not execCtx.Canceled) and (rmethod <> nil) then
      for attr in rmethod.GetAttributes do
        if attr is TActionFilterAttribute then
        begin
          filterAttr := TActionFilterAttribute(attr);
          filterAttr.OnActionExecuting(execCtx);
          if execCtx.Canceled then Break;
        end;

    if execCtx.Canceled then
    begin
      // short-circuit: execute the assigned result if any
      if Assigned(execCtx.Result) then
      begin
        actionContext := TActionContext.Create(aRequestContext.HttpContext, aRequestContext.RouteData);
        try
          execCtx.Result.ExecuteResult(actionContext);
        finally
          actionContext.Free;
        end;
      end;
    end
    else
    begin
      // execute controller action method
      try
        TActionInvoker.Invoke(Self, aRequestContext);
      except
        on E : Exception do
        begin
          actionError := E;
          raise;
        end;
      end;
    end;
  finally
    // OnActionExecuted: method-level first, then controller-level
    doneCtx := TActionExecutedContext.Create(aRequestContext, actionError);
    try
      if rmethod <> nil then
        for attr in rmethod.GetAttributes do
          if attr is TActionFilterAttribute then
            TActionFilterAttribute(attr).OnActionExecuted(doneCtx);
      if rtype <> nil then
        for attr in rtype.GetAttributes do
          if attr is TActionFilterAttribute then
            TActionFilterAttribute(attr).OnActionExecuted(doneCtx);
    finally
      doneCtx.Free;
      execCtx.Free;
    end;
  end;

  if Assigned(fOnResultExecuted) then fOnResultExecuted(aRequestContext);
end;

function THttpController.GetContext: THttpContextBase;
begin
  Result := fHttpContext;
end;

procedure THttpController.SetContext(const Value: THttpContextBase);
begin
  fHttpContext := Value;
end;

function THttpController.GetUser: TClaimsPrincipal;
begin
  if fHttpContext <> nil then Result := fHttpContext.User
    else Result := nil;
end;

function THttpController.AuthorizeResource(aResource: TObject; const aPolicyName: string): Boolean;
var
  authService : IAuthorizationService;
  authResult  : TAuthorizationResult;
begin
  if fHttpContext = nil then Exit(False);
  authService := fHttpContext.RequestServices.GetService<IAuthorizationService>;
  if authService = nil then
    raise EAuthorizationError.Create('IAuthorizationService is not registered. Call services.Extension<TAuthorizationServiceExtension>.AddAuthorization(...)');
  authResult := authService.Authorize(fHttpContext.User, aResource, aPolicyName);
  Result := authResult.Succeeded;
end;

function THttpController.Json(aObject: TObject; aOnlyPublishedProperties : Boolean = False): TJsonResult;
begin
  Result := TJsonResult.Create(aObject,aOnlyPublishedProperties);
end;

function THttpController.Json(const aJsonText: string): TJsonResult;
begin
  Result := TJsonResult.Create(aJsonText);
end;

function THttpController.StatusCode(const aStatusCode: THttpStatusCode; const aStatusText: string): TStatusResult;
begin
  Result := TStatusResult.Create(Integer(aStatusCode),aStatusText);
end;

function THttpController.StatusCode(aStatusCode: Integer; const aStatusText: string): TStatusResult;
begin
  Result := TStatusResult.Create(aStatusCode,aStatusText);
end;

function THttpController.Ok(const aStatusText: string): TStatusResult;
begin
  Result := TStatusResult.Create(200,aStatusText);
end;

function THttpController.Accepted(const aStatusText: string): TStatusResult;
begin
  Result := TStatusResult.Create(202,aStatusText);
end;

function THttpController.NotFound(const aStatusText: string): TStatusResult;
begin
  Result := TStatusResult.Create(404,aStatusText);
end;

function THttpController.BadRequest(const aStatusText: string): TStatusResult;
begin
  Result := TStatusResult.Create(400,aStatusText);
end;

function THttpController.Forbid(const aStatusText: string): TStatusResult;
begin
  Result := TStatusResult.Create(403,aStatusText);
end;

function THttpController.Unauthorized(const aStatusText: string): TStatusResult;
begin
  Result := TStatusResult.Create(401,aStatusText);
end;

function THttpController.Content(const aContentText: string): TContentResult;
begin
  Result := TContentResult.Create(aContentText);
end;

destructor THttpController.Destroy;
begin
  fViewData.Free;
  inherited;
end;

function THttpController.Redirect(const aURL: string): TRedirectResult;
begin
  Result := TRedirectResult.Create(302,aURL);
end;

function THttpController.RedirectPermanent(const aURL: string): TRedirectResult;
begin
  Result := TRedirectResult.Create(301,aURL);
end;

function THttpController.View(const aView: string = ''): TViewResult;
begin
  Result := TViewResult.Create(aView);
  Result.ViewData := fViewData;
  Result.ViewEngine := fViewEngine;
end;

{ Authorize }

constructor Authorize.Create(const aRoles: string = '');
begin
  fRoles := aRoles;
end;

{ AuthorizePolicy }

constructor AuthorizePolicy.Create(const aName: string);
begin
  fName := aName;
end;

end.
