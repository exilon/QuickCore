{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Mvc
  Description : Core MVC Server
  Author      : Kike Perez
  Version     : 1.8
  Created     : 30/09/2019
  Modified    : 08/05/2026

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

unit Quick.Core.Mvc;

{$i QuickCore.inc}

interface

uses
  {$IFDEF DEBUG_ROUTING}
  Quick.Debug.Utils,
  {$ENDIF}
  System.SysUtils,
  System.Generics.Collections,
  RTTI,
  Quick.Commons,
  Quick.Console,
  Quick.Core.Extensions.Hosting,
  Quick.Core.Logging.Abstractions,
  Quick.Core.Extensions.Service.Abstractions,
  Quick.HttpServer,
  Quick.HttpServer.Types,
  Quick.Options,
  Quick.Core.DependencyInjection,
  Quick.Core.Security.Authentication,
  Quick.Core.Security.Authorization,
  Quick.HttpServer.Request,
  Quick.HttpServer.Response,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.Context,
  Quick.Core.Mvc.Middleware,
  Quick.Core.Mvc.Middleware.Cache,
  Quick.Core.Mvc.Middleware.Routing,
  Quick.Core.Mvc.Routing,
  Quick.Core.Mvc.Middleware.StaticFiles,
  Quick.Core.Mvc.Middleware.Hsts,
  Quick.Core.Mvc.Middleware.HttpsRedirection,
  Quick.Core.Mvc.Middleware.MVC,
  Quick.Core.Mvc.Middleware.LogRequest,
  Quick.Core.Mvc.Middleware.Authentication,
  Quick.Core.Mvc.Middleware.Authorization,
  Quick.Core.Mvc.Middleware.Compression,
  Quick.Core.Mvc.Middleware.Cors,
  Quick.Core.Mvc.Middleware.ExceptionHandler,
  Quick.Core.Mvc.Middleware.RateLimit,
  Quick.Core.Mvc.Middleware.Session,
  Quick.Core.Mvc.Middleware.Swagger,
  Quick.Core.Mvc.Session,
  Quick.Core.Extensions.Hosting.BackgroundService,
  Quick.Core.Mvc.ViewFeatures,
  Quick.Core.Mvc.ViewEngine.Mustache,
  Quick.Core.Mvc.ViewEngine.Liquid;

type
  IMVCServer = interface
  ['{4ACF6E69-D600-4447-959E-C4BD20DE6A89}']
    function Services : TServiceCollection;
    procedure Start;
    procedure Stop;
  end;

  TStartupMvc = class;

  TStatupMvcClass = class of TStartupMvc;

  TMVCServerStatus = (mvsStarting, mvsStarted, mvsStopping, mvsStopped);

  { Minimal-API handler: receives the request context and returns a string
    body.  Return '' to skip body writing (e.g. response already written). }
  TMinimalEndpointHandler = reference to function(aContext: THttpContextBase): string;

  TMinimalEndpoint = class
  private
    fRoute   : THttpRoute;
    fHandler : TMinimalEndpointHandler;
  public
    constructor Create(const aURL: string; aMethods: TMethodVerbs;
                       aHandler: TMinimalEndpointHandler);
    destructor Destroy; override;
    property Route   : THttpRoute           read fRoute;
    property Handler : TMinimalEndpointHandler read fHandler;
  end;

  TMVCServer = class(TInterfacedObject,IMVCServer)
  private
    fHttpServer : IHttpServer;
    fHttpRouting : THttpRouting;
    fHost : string;
    fPort : Integer;
    fServices : TServiceCollection;
    fAppServices : TAppServices;
    fMiddlewares : TObjectList<TRequestDelegate>;
    fIsInitialized : Boolean;
    fPathBase : string;
    fWebRoot : string;
    fStartupClass : TStatupMvcClass;
    fStatus : TMVCServerStatus;
    fAfterStart : TProc;
    fMinimalEndpoints : TObjectList<TMinimalEndpoint>;
    fHttpsEnabled : Boolean;
    procedure Initialize;
    procedure GetAttributeRouting;
    procedure GenerateRequestPipeline;
    function Logger : ILogger;
    procedure ConfigureStartupServices;
  protected
    fHttpControllers : TList<THttpControllerClass>;
    fViewEngine : IViewEngine;
    procedure ProcessRequest(aRequest : IHttpRequest; aResponse : IHttpResponse); virtual;
  public
    constructor Create(aHttpServer : IHttpServer); overload; virtual;
    constructor Create(const aHost : string; aPort : Integer; aSSLEnabled : Boolean); overload; virtual;
    destructor Destroy; override;
    property Status : TMVCServerStatus read fStatus write fStatus;
    property AfterStart : TProc read fAfterStart write fAfterStart;
    function MapRoute(const aName : string; aController : THttpControllerClass; const aURL : string) : TMVCServer;
    function AddController(aHttpController : THttpControllerClass) : TMVCServer;
    function AddControllers : TMVCServer;
    function Services : TServiceCollection;
    function UseStartup<T : TStartupMvc> : TMVCServer;
    function UsePathBase(const aPath : string) : TMVCServer;
    function UseWebRoot(const aPath : string) : TMVCServer;
    function UseCustomErrorPages(aUseDynamicPages : Boolean = False) : TMVCServer;
    function UseHttpsRedirection : TMVCServer;
    function UseHsts : TMVCServer;
    function DefaultRoute(aDefaultController : THttpControllerClass; const aRouteURL: string): TMVCServer;
    function UseMiddleware(aCustomMiddlewareClass: TRequestDelegateClass): TMVCServer; overload;
    function UseMiddleware(aCustomMiddleware: TRequestDelegate): TMVCServer; overload;
    function Use(aDelegateFunction : TRequestDelegateFunc) : TMVCServer;
    function UseStaticFiles : TMVCServer;
    function UseRouting : TMVCServer;
    function UseAuthentication : TMVCServer;
    function UseAuthorization : TMVCServer;
    function UseCors : TMVCServer;
    function UseExceptionHandler(aOnException : TExceptionHandlerProc = nil) : TMVCServer;
    function UseRateLimiting(aMaxRequests : Integer = 100; aWindowSecs : Integer = 60) : TMVCServer;
    function UseResponseCompression : TMVCServer;
    function UseApiVersioning : TMVCServer;
    function UseSession : TMVCServer;
    function UseSwagger(const aTitle : string = 'API';
                        const aVersion : string = '1.0.0';
                        const aDescription : string = '') : TMVCServer;
    function UseMVC : TMVCServer;
    function UseMustachePages : TMVCServer;
    function UseLiquidPages : TMVCServer;
    function UseLogRequest : TMVCServer; overload;
    function UseLogRequest(aLoggerService : ILogger) : TMVCServer; overload;
    { Minimal API — register lightweight endpoints without controllers }
    function MapGet(const aURL: string; aHandler: TMinimalEndpointHandler): TMVCServer;
    function MapPost(const aURL: string; aHandler: TMinimalEndpointHandler): TMVCServer;
    function MapPut(const aURL: string; aHandler: TMinimalEndpointHandler): TMVCServer;
    function MapDelete(const aURL: string; aHandler: TMinimalEndpointHandler): TMVCServer;
    function MapVerbs(const aURL: string; aMethods: TMethodVerbs; aHandler: TMinimalEndpointHandler): TMVCServer;
    //function Run(aDelegateFunction : TRequestDelegateFunc);
    procedure Start; virtual;
    procedure Stop; virtual;
  end;

  TStartupMvc = class(TStartupBase)
  public
    class procedure Configure(app : TMVCServer); virtual; abstract;
  end;

  TConfigureAppProc = procedure(app : TMVCServer);

  TMVCServerExtension = class
  private class var
    fMVCServer : TMVCServer;
    class function SetServer(aMVCServcer : TMVCServer) : TMVCServerExtension;
  public
    class property MVCServer : TMVCServer read fMVCServer;
  end;

  TMVCServerHelper = class helper for TMVCServer
    function ConfigureApp(aConfigureProc: TConfigureAppProc): TMVCServer;
    function Extension<T : TMVCServerExtension> : T;
  end;


implementation

{ TMVCServer }

constructor TMVCServer.Create(aHttpServer: IHttpServer);
begin
  fStatus := TMVCServerStatus.mvsStopped;
  fStartupClass := nil;
  fIsInitialized := False;
  fServices :=  TServiceCollection.Create;
  fAppServices := fServices.AppServices;
  fHttpRouting := THttpRouting.Create;
  fHttpControllers := TList<THttpControllerClass>.Create;
  fHttpServer := aHttpServer;
  fHttpServer.OnNewRequest := ProcessRequest;
  fMiddlewares := TObjectList<TRequestDelegate>.Create(True);
  fMinimalEndpoints := TObjectList<TMinimalEndpoint>.Create(True);
  fPathBase := '/';
  fWebRoot := './wwwroot/';
  fHost := fHttpServer.Host;
  fPort := fHttpServer.Port;
  fHttpsEnabled := False;
end;

procedure TMVCServer.ConfigureStartupServices;
begin
  if fStartupClass = nil then Exit;

  try
    fStartupClass.ConfigureServices(fServices);
    fServices.Build;
    fStartupClass.Configure(Self);
  except
    on E : Exception do
    begin
      if fServices.AppServices.Logger <> nil then fServices.AppServices.Logger.Critical(e.Message);
      raise Exception.CreateFmt('Configure Services error: %s',[e.Message]);
    end;
  end;
end;

constructor TMVCServer.Create(const aHost : string; aPort : Integer; aSSLEnabled : Boolean);
var
  port : Integer;
begin
  port := aPort;
  //check if dynamic port provided
  if ParamCount > 0 then
  begin
    if not Integer.TryParse(ParamStr(1),port) then port := aPort;
  end;
  Create(THttpServer.Create(aHost,port,aSSLEnabled));
  fHttpsEnabled := aSSLEnabled;
end;

function TMVCServer.DefaultRoute(aDefaultController : THttpControllerClass; const aRouteURL: string): TMVCServer;
begin
  Result := Self;
  fHttpRouting.MapRoute('default',aDefaultController,aRouteURL);
end;

destructor TMVCServer.Destroy;
begin
  Stop;
  fHttpControllers.Free;
  fHttpRouting.Free;
  fMiddlewares.Free;
  fMinimalEndpoints.Free;
  fServices.Free;
  fHttpServer := nil;
  inherited;
end;

{ TMinimalEndpoint }

constructor TMinimalEndpoint.Create(const aURL: string; aMethods: TMethodVerbs;
  aHandler: TMinimalEndpointHandler);
begin
  inherited Create;
  fRoute := THttpRoute.Create;
  fRoute.URL := aURL;
  fRoute.HttpMethods := aMethods;
  fHandler := aHandler;
end;

destructor TMinimalEndpoint.Destroy;
begin
  fRoute.Free;
  inherited;
end;

{ TMVCServer.Map* helpers }

function TMVCServer.MapVerbs(const aURL: string; aMethods: TMethodVerbs;
  aHandler: TMinimalEndpointHandler): TMVCServer;
begin
  Result := Self;
  fMinimalEndpoints.Add(TMinimalEndpoint.Create(aURL, aMethods, aHandler));
end;

function TMVCServer.MapGet(const aURL: string; aHandler: TMinimalEndpointHandler): TMVCServer;
begin
  Result := MapVerbs(aURL, [mGET], aHandler);
end;

function TMVCServer.MapPost(const aURL: string; aHandler: TMinimalEndpointHandler): TMVCServer;
begin
  Result := MapVerbs(aURL, [mPOST], aHandler);
end;

function TMVCServer.MapPut(const aURL: string; aHandler: TMinimalEndpointHandler): TMVCServer;
begin
  Result := MapVerbs(aURL, [mPUT], aHandler);
end;

function TMVCServer.MapDelete(const aURL: string; aHandler: TMinimalEndpointHandler): TMVCServer;
begin
  Result := MapVerbs(aURL, [mDELETE], aHandler);
end;

procedure TMVCServer.GenerateRequestPipeline;
var
  i : Integer;
begin
  //set middleware pipeline
  if fMiddlewares.Count = 1 then Exit;

  Logger.Debug('Middleware pipeline:');
  for i := 0 to fMiddlewares.Count - 2 do
  begin
    Logger.Debug('%d. %s',[i + 1, fMiddlewares[i].ClassName]);
    fMiddlewares[i].SetNextInvoker(fMiddlewares[i + 1]);
  end;
end;

procedure TMVCServer.GetAttributeRouting;
var
  controller : THttpControllerClass;
begin
  //get routing from controller custom attributes
  for controller in fHttpControllers do
  begin
    fHttpRouting.MapAttributeRoutes(controller);
  end;
end;

procedure TMVCServer.Initialize;
begin
  ConfigureStartupServices;
  //generate request middleware pipeline
  GenerateRequestPipeline;
  Logger.Debug('Request Pipeline ready');
  //get routing from controllers custom attributes
  GetAttributeRouting;
  Logger.Debug('Attribute Routing ready');
  fIsInitialized := True;
  fHttpServer.Logger := Logger;
end;

function TMVCServer.Logger: ILogger;
begin
  Result := fAppServices.Logger;
end;

function TMVCServer.MapRoute(const aName: string; aController: THttpControllerClass; const aURL: string): TMVCServer;
begin
  Result := Self;
  fHttpRouting.MapRoute(aName,aController,aURL);
end;

procedure TMVCServer.ProcessRequest(aRequest: IHttpRequest; aResponse: IHttpResponse);
var
  context  : THttpContextBase;
  endpoint : TMinimalEndpoint;
  body     : string;
begin
  {$IFDEF DEBUG_ROUTING}
    TDebugger.Enter(Self,Format('ProcessRequest (%s)',[aRequest.URL])).TimeIt;
  {$ENDIF}

  // --- Minimal API endpoints ---
  for endpoint in fMinimalEndpoints do
  begin
    if endpoint.Route.HandlesRequest(aRequest) then
    begin
      context := THttpContextBase.Create(aRequest, aResponse);
      try
        context.WebRoot := fWebRoot;
        context.RequestServices := TServiceProvider.Create(fServices);
        body := endpoint.Handler(context);
        context.Response.StatusCode := 200;
        if not body.IsEmpty then
        begin
          if (body[1] = '{') or (body[1] = '[') then
            context.Response.ContentType := 'application/json'
          else
            context.Response.ContentType := 'text/plain';
          context.Response.ContentText := body;
        end;
      finally
        context.Free;
      end;
      Exit;
    end;
  end;

  // --- Regular middleware pipeline ---
  context := THttpContextBase.Create(aRequest,aResponse);
  try
    context.WebRoot := fWebRoot;
    context.RequestServices := TServiceProvider.Create(fServices);
    //middleware request pipeline flow
    if fMiddlewares.Count = 0 then raise Exception.Create('Not Middlewares defined');
    fMiddlewares[0].Invoke(context);
  finally
    context.Free;
  end;
end;

function TMVCServer.Services: TServiceCollection;
begin
  Result := fServices;
end;

procedure TMVCServer.Start;
var
  hostservice : IHostService;
  hostcore : IHostCore;
  hostedMgr : IHostedServiceManager;
  i : Integer;
  hasSwagger : Boolean;
  scheme : string;
  displayHost : string;
begin
  if fStatus = TMVCServerStatus.mvsStopping then Exit;
  if (Services.IsRegistered<IHostService>) then hostservice := Services.Resolve<IHostService>
    else hostservice := nil;
  if fStatus = TMVCServerStatus.mvsStopped then
  begin
    fStatus := TMVCServerStatus.mvsStarting;
    if hostservice <> nil then
    begin
      if hostservice.IsRunningAsService then
      begin
        //if not fIsInitialized then Initialize;
        //Logger.Info('Running as a service');
        hostservice.Start;
        Exit;
      end
      else
      begin
        if hostservice.CheckParams then Exit;
      end;
    end
    else
    begin
      hostcore := THostCore.Create;
      hostcore.OnStart := Start;
      hostcore.OnStop := Stop;
      hostcore.Start;
      Exit;
    end;
  end;
  //run from ihost or ihostservice
  if not fIsInitialized then Initialize;
  // start any registered IHostedService instances
  if fServices.IsRegistered<IHostedServiceManager> then
  begin
    hostedMgr := fServices.Resolve<IHostedServiceManager>;
    hostedMgr.Initialize(fServices);
    hostedMgr.StartAll;
  end;
  fHttpServer.Start;
  fStatus := mvsStarted;
  Logger.Info('%s listening on %s:%d',[fServices.Environment.ApplicationName,fHost,fPort]);
  hasSwagger := False;
  for i := 0 to fMiddlewares.Count - 1 do
    if fMiddlewares[i] is TSwaggerMiddleware then
    begin
      hasSwagger := True;
      Break;
    end;
  if hasSwagger then
  begin
    if fHttpsEnabled then scheme := 'https' else scheme := 'http';
    displayHost := fHost;
    if (displayHost = '') or (displayHost = '0.0.0.0') or (displayHost = '*') then
      displayHost := 'localhost';
    Logger.Info('Swagger UI available at %s://%s:%d/swagger', [scheme, displayHost, fPort]);
  end;
  if Assigned(fAfterStart) then fAfterStart;
  if (hostservice = nil) or ((hostservice <> nil) and (not hostservice.IsRunningAsService)) then
  begin
    Logger.Info('< Wait for ENTER key pressed >');
    ConsoleWaitForEnterKey;
  end;
  Logger.Debug('TMVCServer.Start=Exited!');
  //Free;
end;

procedure TMVCServer.Stop;
begin
  if (fStatus = TMVCServerStatus.mvsStopping) or (fStatus = TMVCServerStatus.mvsStopped) then Exit;

  Logger.Info('%s stopping...',[fServices.Environment.ApplicationName]);
  // stop any registered IHostedService instances
  if fServices.IsRegistered<IHostedServiceManager> then
    fServices.Resolve<IHostedServiceManager>.StopAll;
  fHttpServer.Stop;
  fStatus := TMVCServerStatus.mvsStopped;
  Logger.Info('%s stopped',[fServices.Environment.ApplicationName]);
end;

function TMVCServer.UseAuthentication: TMVCServer;
var
  middleware : TRequestDelegate;
begin
  Result := Self;
  //use IAuthenticationService
  if Self.Services.IsRegistered<IAuthenticationService> then
  begin
    middleware := TAuthenticationMiddleware.Create(nil,Self.Services.Resolve<IAuthenticationService>,Self.Services.AppServices.Options.GetSection<TAuthenticationOptions>);
    Self.UseMiddleware(middleware);
  end
  else
  begin
    raise Exception.Create('Authentication dependency not found. Need to be added before!');
  end;
end;

function TMVCServer.UseAuthorization: TMVCServer;
var
  middleware : TRequestDelegate;
begin
  Result := Self;
  //use first IAutorizationService found
  if Self.Services.IsRegistered<IAuthorizationService> then
  begin
    middleware := TAuthorizationMiddleware.Create(nil,Self.Services.Resolve<IAuthorizationService>);
    Self.UseMiddleware(middleware);
  end
  else
  begin
    raise Exception.Create('Authorization dependency not found. Need to be added before!');
  end;
end;

function TMVCServer.UseCors : TMVCServer;
var
  corsOptions : IOptions<TCorsPolicyOptions>;
begin
  Result := Self;
  if Self.Services.IsRegistered<IOptions<TCorsPolicyOptions>> then
    corsOptions := Self.Services.Resolve<IOptions<TCorsPolicyOptions>>
  else
    corsOptions := nil;
  Self.UseMiddleware(TCorsMiddleware.Create(nil, corsOptions));
end;

function TMVCServer.UseExceptionHandler(aOnException : TExceptionHandlerProc = nil) : TMVCServer;
begin
  Result := Self;
  Self.UseMiddleware(TExceptionHandlerMiddleware.Create(nil, aOnException));
end;

function TMVCServer.UseRateLimiting(aMaxRequests : Integer = 100; aWindowSecs : Integer = 60) : TMVCServer;
var
  policy : TRateLimitPolicy;
begin
  Result := Self;
  policy := TRateLimitPolicy.Create(aMaxRequests, aWindowSecs);
  Self.UseMiddleware(TRateLimitMiddleware.Create(nil, policy));
end;

function TMVCServer.UseResponseCompression : TMVCServer;
var
  comprOpts : IOptions<TCompressionOptions>;
begin
  Result := Self;
  if Self.Services.IsRegistered<IOptions<TCompressionOptions>> then
    comprOpts := Self.Services.Resolve<IOptions<TCompressionOptions>>
  else
    comprOpts := nil;
  Self.UseMiddleware(TCompressionMiddleware.Create(nil, comprOpts));
end;

function TMVCServer.UseApiVersioning : TMVCServer;
begin
  { API versioning is enforced through [ApiVersion] and [Route] attributes on
    controllers. Calling this method opts the application into versioned routing,
    which correctly merges multiple controllers that share the same URL prefix
    (e.g. 'api'). No extra middleware is required for URL-segment versioning.
    Extend this method for header-based or query-string-based versioning. }
  Result := Self;
end;

function TMVCServer.UseCustomErrorPages(aUseDynamicPages: Boolean = False): TMVCServer;
begin
  Result := Self;
  fHttpServer.CustomErrorPages.DynamicErrorPage := aUseDynamicPages;
  fHttpServer.CustomErrorPages.Enabled := True;
end;

function TMVCServer.UseHttpsRedirection: TMVCServer;
begin
  Result := Self;
  fMiddlewares.Add(THttpsRedirectionMiddleware.Create(nil,307));
end;

function TMVCServer.UseLogRequest(aLoggerService: ILogger): TMVCServer;
begin
  Result := Self;
  if aLoggerService = nil then raise Exception.Create('UseLogRequest Logger cannot be nil!');
  fMiddlewares.Add(TLogRequestMiddleware.Create(nil,aLoggerService));
end;

function TMVCServer.UseLogRequest: TMVCServer;
begin
  Result := Self;
  UseLogRequest(Logger);
end;

function TMVCServer.UseMiddleware(aCustomMiddlewareClass: TRequestDelegateClass): TMVCServer;
begin
  Result := Self;
  fMiddlewares.Add(aCustomMiddlewareClass.Create(nil));
end;

function TMVCServer.UseMiddleware(aCustomMiddleware: TRequestDelegate): TMVCServer;
begin
  Result := Self;
  fMiddlewares.Add(aCustomMiddleware);
end;

function TMVCServer.UseMustachePages: TMVCServer;
begin
  Result := Self;
  fViewEngine := TMustacheViewEngine.Create;
end;

function TMVCServer.UseLiquidPages: TMVCServer;
begin
  Result := Self;
  fViewEngine := TLiquidViewEngine.Create;
end;

function TMVCServer.Use(aDelegateFunction: TRequestDelegateFunc): TMVCServer;
begin
  Result := Self;
  fMiddlewares.Add(TCustomRequestDelegate.Create(nil,aDelegateFunction));
end;

function TMVCServer.UseMVC: TMVCServer;
begin
  Result := Self;
  fMiddlewares.Add(TMVCMiddleware.Create(nil,fAppServices.DependencyInjector,fViewEngine));
end;

function TMVCServer.UsePathBase(const aPath: string): TMVCServer;
begin
  Result := Self;
  fPathBase := aPath;
end;

function TMVCServer.UseHsts: TMVCServer;
begin
  Result := Self;
  fMiddlewares.Add(THstsMiddleware.Create(nil,31536000));
end;

function TMVCServer.UseRouting: TMVCServer;
begin
  Result := Self;
  fMiddlewares.Add(TRoutingMiddleware.Create(nil,fHttpRouting));
end;

function TMVCServer.UseSession: TMVCServer;
var
  store : ISessionStore;
begin
  Result := Self;
  store := TInMemorySessionStore.Create;
  UseMiddleware(TSessionMiddleware.Create(nil, store));
end;

function TMVCServer.UseSwagger(const aTitle, aVersion, aDescription : string) : TMVCServer;
var
  info : TSwaggerInfo;
begin
  Result := Self;
  info := TSwaggerInfo.Create(aTitle, aVersion, aDescription);
  // Pass the protected fHttpControllers list to the middleware
  UseMiddleware(TSwaggerMiddleware.Create(nil, fHttpControllers, info));
end;

function TMVCServer.UseStartup<T>: TMVCServer;
begin
  fStartupClass := T;
  Result := Self;
end;

function TMVCServer.UseStaticFiles: TMVCServer;
begin
  Result := Self;
  fMiddlewares.Add(TStaticFilesMiddleware.Create(nil));
end;

function TMVCServer.UseWebRoot(const aPath: string): TMVCServer;
begin
  Result := Self;
  fWebRoot := IncludeTrailingPathDelimiter(aPath);
  if not DirectoryExists(fWebRoot) then Logger.Warn('Error accessing WebRoot "%s": Directory not found!',[fWebRoot]);
end;

function TMVCServer.AddController(aHttpController: THttpControllerClass) : TMVCServer;
begin
  Result := Self;
  if not fHttpControllers.Contains(aHttpController) then
  begin
    fHttpControllers.Add(aHttpController);
    Logger.done('Added controller "%s"',[aHttpController.ClassName]);
  end
  else Logger.Warn('Already added controller "%s"',[aHttpController.ClassName]);
end;

function TMVCServer.AddControllers: TMVCServer;
var
  controller : THttpControllerClass;
begin
  Result := Self;
  //add registered controllers
  for controller in RegisteredControllers do AddController(controller);
end;

{ TMVCServerExtension }

class function TMVCServerExtension.SetServer(aMVCServcer: TMVCServer): TMVCServerExtension;
begin
  Result := TMVCServerExtension(Self);
  fMVCServer := aMVCServcer;
end;

{ TMVCServerHelper }

function TMVCServerHelper.Extension<T>: T;
begin
  //TMVCServerExtension(Result).SetServer(Self);
  Result := T(TMVCServerExtension.SetServer(Self));
end;

function TMVCServerHelper.ConfigureApp(aConfigureProc: TConfigureAppProc): TMVCServer;
begin
  Result := Self;
  aConfigureProc(Self);
end;

end.
