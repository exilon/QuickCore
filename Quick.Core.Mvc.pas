{ ***************************************************************************

  Copyright (c) 2016-2021 Kike Pérez

  Unit        : Quick.Core.Mvc
  Description : Core MVC Server
  Author      : Kike Pérez
  Version     : 1.8
  Created     : 30/09/2019
  Modified    : 23/02/2021

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
  Quick.Core.Logging.Abstractions,
  Quick.HttpServer,
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
  Quick.Core.Mvc.Middleware.StaticFiles,
  Quick.Core.Mvc.Middleware.Hsts,
  Quick.Core.Mvc.Middleware.HttpsRedirection,
  Quick.Core.Mvc.Middleware.MVC,
  Quick.Core.Mvc.Middleware.LogRequest,
  Quick.Core.Mvc.Middleware.Authentication,
  Quick.Core.Mvc.Middleware.Authorization,
  Quick.Core.Mvc.ViewFeatures,
  Quick.Core.Mvc.ViewEngine.Mustache;

type
  IMVCServer = interface
  ['{4ACF6E69-D600-4447-959E-C4BD20DE6A89}']
    function Services : TServiceCollection;
    procedure Start;
    procedure Stop;
  end;

  TStartupMvc = class;

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
    procedure Initialize;
    procedure GetAttributeRouting;
    procedure GenerateRequestPipeline;
    function Logger : ILogger;
  protected
    fHttpControllers : TList<THttpControllerClass>;
    fViewEngine : IViewEngine;
    procedure ProcessRequest(aRequest : IHttpRequest; aResponse : IHttpResponse); virtual;
  public
    constructor Create(aHttpServer : IHttpServer); overload; virtual;
    constructor Create(const aHost : string; aPort : Integer; aSSLEnabled : Boolean); overload; virtual;
    destructor Destroy; override;
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
    function UseSession : TMVCServer;
    function UseMVC : TMVCServer;
    function UseMustachePages : TMVCServer;
    function UseLogRequest : TMVCServer; overload;
    function UseLogRequest(aLoggerService : ILogger) : TMVCServer; overload;
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
  fIsInitialized := False;
  fServices :=  TServiceCollection.Create;
  fAppServices := fServices.AppServices;
  fHttpRouting := THttpRouting.Create;
  fHttpControllers := TList<THttpControllerClass>.Create;
  fHttpServer := aHttpServer;
  fHttpServer.OnNewRequest := ProcessRequest;
  fMiddlewares := TObjectList<TRequestDelegate>.Create(True);
  fPathBase := '/';
  fWebRoot := './wwwroot/';
  fHost := fHttpServer.Host;
  fPort := fHttpServer.Port;
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
end;

function TMVCServer.DefaultRoute(aDefaultController : THttpControllerClass; const aRouteURL: string): TMVCServer;
begin
  Result := Self;
  fHttpRouting.MapRoute('default',aDefaultController,aRouteURL);
end;

destructor TMVCServer.Destroy;
begin
  fHttpServer.Stop;
  fHttpControllers.Free;
  fHttpRouting.Free;
  fMiddlewares.Free;
  fServices.Free;
  fHttpServer := nil;
  inherited;
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
  //generate request middleware pipeline
  GenerateRequestPipeline;
  Logger.Debug('Request Pipeline ready');
  //get routing from controllers custom attributes
  GetAttributeRouting;
  Logger.Debug('Attribute Routing ready');
  fIsInitialized := True;
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
  context : THttpContextBase;
begin
  {$IFDEF DEBUG_ROUTING}
    TDebugger.Enter(Self,Format('ProcessRequest (%s)',[aRequest.URL])).TimeIt;
  {$ENDIF}
  context := THttpContextBase.Create(aRequest,aResponse);
  try
    context.WebRoot := fWebRoot;
    context.RequestServices := TServiceProvider.Create(fServices);
    //middleware request pipeline flow
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
begin
  if not fIsInitialized then Initialize;
  fHttpServer.Start;
  Logger.Info('%s listening on %s:%d',[fServices.Environment.ApplicationName,fHost,fPort]);
end;

procedure TMVCServer.Stop;
begin
  Logger.Info('%s stopping...',[fServices.Environment.ApplicationName]);
  fHttpServer.Stop;
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
begin
  Result := Self;
end;

function TMVCServer.UseStartup<T>: TMVCServer;
begin
  T.ConfigureServices(fServices);
  T.Configure(Self);
  fServices.Build;
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
