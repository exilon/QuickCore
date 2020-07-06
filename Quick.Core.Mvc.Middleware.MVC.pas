{ ***************************************************************************

  Copyright (c) 2016-2019 Kike Pérez

  Unit        : Quick.Core.Mvc.Middleware.MVC
  Description : Core Mvc MVC Middleware
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 12/10/2019
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

unit Quick.Core.Mvc.Middleware.MVC;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Quick.HttpServer.Types,
  Quick.HttpServer.Request,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.Middleware,
  Quick.Core.Mvc.Context,
  Quick.Core.Mvc.Routing,
  Quick.Core.Mvc.Factory.Controller,
  Quick.Core.Mvc.ViewFeatures,
  Quick.Core.DependencyInjection;

type
  TMVCMiddleware = class(TRequestDelegate)
  private
    fControllerFactory : TControllerFactory;
    fDependencyInjector : TDependencyInjector;
    fViewEngine : IViewEngine;
  public
    constructor Create(aNext : TRequestDelegate; aDependencyInjector : TDependencyInjector; aViewEngine : IViewEngine);
    destructor Destroy; override;
    procedure Invoke(aContext : THttpContextBase); override;
  end;

implementation

{ TMVCMiddleware }

constructor TMVCMiddleware.Create(aNext : TRequestDelegate; aDependencyInjector : TDependencyInjector; aViewEngine : IViewEngine);
begin
  inherited Create(aNext);
  fDependencyInjector := aDependencyInjector;
  fControllerFactory := TControllerFactory.Create(fDependencyInjector);
  fViewEngine := aViewEngine;
end;

destructor TMVCMiddleware.Destroy;
begin
  fControllerFactory.Free;
  inherited;
end;

procedure TMVCMiddleware.Invoke(aContext: THttpContextBase);
var
  routedata : TRouteData;
  aRequestContext : TRequestContext;
  controller : THttpController;
begin
  inherited;
  //get route
  if aContext.Route = nil then
  begin
    aContext.RaiseHttpErrorNotFound(Self,'The page you requested was not found');
    //aContext.Response.StatusCode := 404;
    //aContext.Response.StatusText := 'Not found';
    //aContext.Response.ContentText := 'The page you requested was not found';
  end
  else
  begin
    controller := fControllerFactory.GetController(aContext);
    try
      routedata := aContext.Route.GetRouteData(aContext.Request);
      try
        aRequestContext := TRequestContext.Create(aContext,routedata);
        try
          controller.Execute(aRequestContext,fViewEngine);
        finally
          aRequestContext.Free;
        end;
      finally
        routedata.Free;
      end;
    finally
      controller.Free;
    end;
  end;
end;

end.
