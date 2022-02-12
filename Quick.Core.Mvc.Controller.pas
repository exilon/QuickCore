{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Mvc.Controller
  Description : Core Mvc Controller
  Author      : Kike Pérez
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
  Quick.Core.Mvc.ViewFeatures;

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
  protected
    function StatusCode(const aStatusCode : THttpStatusCode; const aStatusText : string = '') : TStatusResult;
    function Ok(const aStatusText : string = '') : TStatusResult;
    function Accepted(const aStatusText : string = '') : TStatusResult;
    function BadRequest(const aStatusText : string = '') : TStatusResult;
    function NotFound(const aStatusText : string = '') : TStatusResult;
    function Forbid(const aStatusText : string = '') : TStatusResult;
    function Unauthorized(const aStatusText : string = '') : TStatusResult;
    function Redirect(const aURL : string) : TRedirectResult;
    function RedirectPermanent(const aURL : string) : TRedirectResult;
    function Content(const aContentText : string) : TContentResult;
    function Json(aObject: TObject; aOnlyPublishedProperties : Boolean = False): TJsonResult;
    function View(const aView : string = '') : TViewResult;
  public
    destructor Destroy; override;
    //property Resolver : IDependencyResolver read fResolver;
    property Route : THttpRoute read fRoute;
    property Request : IHttpRequest read fRequest;
    property Response : IHttpResponse read fResponse;
    property ViewData : TViewDataDictionary read fViewData write fViewData;
    property Logger : ILogger read fLogger;
    property HttpContext : THttpContextBase read GetContext write SetContext;
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

  ApiController = class(TCustomAttribute);

  procedure RegisterController(aHttpController : THttpControllerClass);

var
  RegisteredControllers : TArray<THttpControllerClass>;

implementation


procedure RegisterController(aHttpController : THttpControllerClass);
begin
  RegisteredControllers := RegisteredControllers + [aHttpController];
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
  //execute controller action method
  TActionInvoker.Invoke(Self,aRequestContext);
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

function THttpController.Json(aObject: TObject; aOnlyPublishedProperties : Boolean = False): TJsonResult;
begin
  Result := TJsonResult.Create(aObject,aOnlyPublishedProperties);
end;

function THttpController.StatusCode(const aStatusCode: THttpStatusCode; const aStatusText: string): TStatusResult;
begin
  Result := TStatusResult.Create(Integer(aStatusCode),aStatusText);
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
