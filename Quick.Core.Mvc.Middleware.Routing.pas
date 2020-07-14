{ ***************************************************************************

  Copyright (c) 2016-2019 Kike Pérez

  Unit        : Quick.Core.Mvc.Middleware.Routing
  Description : Core Mvc Routing Middleware
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 12/10/2019
  Modified    : 01/07/2020

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

unit Quick.Core.Mvc.Middleware.Routing;

{$i QuickCore.inc}

interface

uses
  {$IFDEF DEBUG_ROUTING}
  Quick.Debug.Utils,
  {$ENDIF}
  System.SysUtils,
  RTTI,
  System.TypInfo,
  System.Generics.Collections,
  Quick.Commons,
  Quick.Value,
  Quick.Arrays,
  Quick.HttpServer.Types,
  Quick.HttpServer.Request,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.Middleware,
  Quick.Core.Mvc.Context,
  Quick.Core.Mvc.Routing;

type
  THttpRoutes = TObjectList<THttpRoute>;

  THttpRouting = class
  private
    fRoutes : TObjectDictionary<string,THttpRoutes>;
    fDefaultRoute : THttpRoute;
    function GetDefaultRoute : THttpRoute;
    function ReplaceTokens(aControllerClass : THttpControllerClass; const aRoute : string) : string;
  public
    constructor Create;
    destructor Destroy; override;
    property DefaultRoute : THttpRoute read GetDefaultRoute;
    procedure MapRoute(const aName : string; aController : THttpControllerClass; const aURL : string);
    procedure MapAttributeRoutes(aControllerClass : THttpControllerClass);
    function GetRoute(aRequest : IHttpRequest): THttpRoute;
    class function GetControllerByName(const aControllerName : string) : THttpControllerClass;
    class function GetControllerName(aControllerClass : THttpControllerclass) : string;
  end;


  TRoutingMiddleware = class(TRequestDelegate)
  private
    fHttpRouting : THttpRouting;
  public
    constructor Create(aNext : TRequestDelegate; aHttpRouting : THttpRouting);
    procedure Invoke(aContext : THttpContextBase); override;
  end;

implementation

{ THttpRouting }

constructor THttpRouting.Create;
begin
  fRoutes := TObjectDictionary<string,THttpRoutes>.Create([doOwnsValues]);
  fDefaultRoute := nil;
end;

function THttpRouting.GetDefaultRoute: THttpRoute;
begin
  Result := fDefaultRoute;
end;

destructor THttpRouting.Destroy;
begin
  fRoutes.Free;
  if Assigned(fDefaultRoute) then fDefaultRoute.Free;
  inherited;
end;

function THttpRouting.GetRoute(aRequest : IHttpRequest): THttpRoute;
var
  routes : THttpRoutes;
  nroute : THttpRoute;
begin
  Result := nil;
  //get controller matching url
  if aRequest.URL.IsEmpty then Exit(fDefaultRoute);

  //check controller segment in routes
  if fRoutes.TryGetValue(aRequest.PathSegment[0].ToLower,routes) then
  begin
    for nroute in routes do
    begin
      if nroute.HandlesRequest(aRequest) then
      begin
        {$IFDEF DEBUG_ROUTING}
        TDebugger.Trace('MVC Route: %s',[nroute.URL]);
        {$ENDIF}
        Exit(nroute);
      end;
    end;
  end
  else
  begin
    if fRoutes.TryGetValue('',routes) then
    begin
      for nroute in routes do
      begin
        if nroute.HandlesRequest(aRequest) then
        begin
          {$IFDEF DEBUG_ROUTING}
          TDebugger.Trace('MVC Route: %s',[nroute.URL]);
          {$ENDIF}
          Exit(nroute);
        end;
      end;
    end;
//    Exit;
//
//    if fDefaultRoute = nil then defcontroller := ''
//    else
//    begin
//      defcontroller := GetFirstPathSegment(fDefaultRoute.URL).ToLower;
//      defcontroller := StringReplace(defcontroller,' ','',[rfReplaceAll]);
//    end;
//    //check if default controller specified
//    if (defcontroller.Contains('{controller=')) then
//    begin
//      defcontroller := GetSubString(defcontroller,'=','}');
//    end;
//    if not fRoutes.TryGetValue(defcontroller,routes) then Exit(nil);
//    for nroute in routes do
//    begin
//      if nroute.HandlesRequest(defcontroller + '/' + aRequest.URL,aRequest.Method) then
//      begin
//        {$IFDEF DEBUG_ROUTING}
//        TDebugger.Trace('MVC Route: %s',[nroute.URL]);
//        {$ENDIF}
//        Exit(nroute);
//      end;
//    end;
  end;
end;

function THttpRouting.ReplaceTokens(aControllerClass : THttpControllerClass; const aRoute : string) : string;
begin
  Result := aRoute;
  if aRoute.ToLower.Contains('[controller]') then Result := StringReplace(aRoute,'[controller]',THttpRouting.GetControllerName(aControllerClass),[rfIgnoreCase,rfReplaceAll]);
end;

procedure THttpRouting.MapAttributeRoutes(aControllerClass: THttpControllerClass);
var
  ctx : TRttiContext;
  rmethod : TRttiMethod;
  rmethods : TArray<TRttiMethod>;
  attr: TCustomAttribute;
  nroute : THttpRoute;
  routes : THttpRoutes;
  rtype : TRttiType;
  globalroute : string;
begin
  globalroute := '.';
  routes := THttpRoutes.Create(True);
  //get global attributes
  rtype := ctx.GetType(aControllerClass);
  for attr in rtype.GetAttributes do
  begin
    if attr is Route then
    begin
      globalroute := ReplaceTokens(aControllerClass,Route(attr).URL);
    end;
  end;
  //get method attributes
  rmethods := rType.GetMethods;
  if rmethods = nil then Exit;
  //get methods
  for rmethod in rmethods do
  begin
    //only published methods
    if rmethod.Visibility = TMemberVisibility.mvpublished then
    begin
      nroute := THttpRoute.Create;
      nroute.ActionMethodName := rmethod.Name;
      //define route by custom attributes
      for attr in rmethod.GetAttributes do
      begin
        if attr is NonAction then Break
        else if attr is TMethodVerbAttribute then
        begin
          if attr is HttpGet then nroute.HttpMethods := nroute.HttpMethods + [TMethodVerb.mGET] + [TMethodVerb.mHEAD]
          else if attr is HttpPost then nroute.HttpMethods := nroute.HttpMethods + [TMethodVerb.mPOST]
          else if attr is HttpPut then nroute.HttpMethods := nroute.HttpMethods + [TMethodVerb.mPUT]
          else if attr is HttpDelete then nroute.HttpMethods := nroute.HttpMethods + [TMethodVerb.mDELETE];
          if not HttpGet(attr).Route.IsEmpty then nroute.URL := HttpGet(attr).Route;
        end
        else if attr is AcceptVerbs then nroute.HttpMethods := AcceptVerbs(attr).Verbs
        else if attr is Route then nroute.URL := Route(attr).URL
        else if attr is Authorize then nroute.Authorize := True
        else if attr is OutputCache then nroute.OutputCache := OutputCache(attr).Duration
        else if attr is ActionName then nroute.ActionName := ActionName(attr).Name;
      end;
      //route to controller routing
      if globalroute = '.' then nroute.ControllerName := THttpRouting.GetControllerName(aControllerClass)
      else
      begin
        if globalroute.Contains('/') then nroute.ControllerName := GetFirstPathSegment(globalroute).ToLower
          else nroute.ControllerName := globalroute.ToLower;
        if nroute.URL.IsEmpty then nroute.URL := globalroute
          else nroute.URL := globalroute + '/' + nroute.URL;
        nroute.URL := ReplaceTokens(aControllerClass,nroute.URL);
      end;
      //if no route get method name
      if nroute.URL.IsEmpty then nroute.URL := nroute.ControllerName + '/' + rmethod.Name;
      nroute.ControllerClass := aControllerClass;
      routes.Add(nroute)
    end;
  end;
  //add controller routes to main routing
  fRoutes.Add(nroute.ControllerName,routes);
end;

class function THttpRouting.GetControllerByName(const aControllerName : string) : THttpControllerClass;
var
  ctx : TRttiContext;
  rtype : TRttiType;
  controller : string;
begin
  if aControllerName.ToLower.EndsWith('controller') then controller := aControllerName
    else controller := aControllerName + 'controller';
  rtype := ctx.FindType(controller);
  if (rtype <> nil) and (rtype.IsInstance) then Result := THttpControllerClass(rtype.AsInstance.MetaClassType)
    else raise EControllerNotFound.Create('Controller not found');
end;

class function THttpRouting.GetControllerName(aControllerClass: THttpControllerclass): string;
var
  controllername : string;
begin
  controllername := aControllerClass.ClassName.ToLower;
  Result := Copy(controllername,2,controllername.IndexOf('controller')-1);
end;

procedure THttpRouting.MapRoute(const aName : string; aController : THttpControllerClass; const aURL : string);
var
  nRoute : THttpRoute;
  controllerRoutes : THttpRoutes;
begin
  //add manual defined route
  nRoute := THttpRoute.Create;
  nRoute.Name := aURL.ToLower;
  nRoute.URL := aURL;
  nRoute.ControllerName := THttpRouting.GetControllerName(aController);
  nRoute.ControllerClass := aController;
  //check if default route
  if CompareText(aName,'default') = 0 then
  begin
    if aURL.Split(['/']).Count > 1 then nRoute.ActionMethodName := aURL.Split(['/'])[1]
      else nRoute.ActionMethodName := aURL;
    nRoute.IsDefaultRoute := True;
    fDefaultRoute := nRoute;
    Exit;
  end;
  //set a normal route
  if aURL.Split(['/']).Count > 1 then nRoute.ActionMethodName := aURL.Split(['/'])[1]
    else raise Exception.CreateFmt('Not valid map route defined [%s]',[aURL]);
  //add map to existing controllers routes if already exists
  if fRoutes.TryGetValue(THttpRouting.GetControllerName(aController),controllerRoutes) then
  begin
    controllerRoutes.Add(nRoute);
  end
  else
  begin
    controllerRoutes := THttpRoutes.Create(True);
    controllerRoutes.Add(nRoute);
  end;
end;

{ TRoutingMiddleware }

constructor TRoutingMiddleware.Create(aNext : TRequestDelegate; aHttpRouting : THttpRouting);
begin
  inherited Create(aNext);
  fHttpRouting := aHttpRouting;
end;

procedure TRoutingMiddleware.Invoke(aContext: THttpContextBase);
var
  nroute : THttpRoute;
begin
  inherited;
  //get route
  nroute := fHttpRouting.GetRoute(aContext.Request);
  if nroute = nil then
  begin
    //default routing
    aContext.RaiseHttpErrorNotFound(Self,'The page you requested was not found');
    //aContext.Response.StatusCode := 404;
    //aContext.Response.StatusText := 'Not found';
    //aContext.Response.ContentText := 'The page you requested was not found';
  end
  else
  begin
    //match routing
    aContext.Route := nRoute;
    //send to next middleware
    Next(aContext);
  end;
end;

end.
