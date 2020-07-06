{ ***************************************************************************

  Copyright (c) 2016-2019 Kike Pérez

  Unit        : Quick.Core.Mvc.Factory.Controller
  Description : Core Mvc Controller Factory
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 30/08/2019
  Modified    : 29/10/2019

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

unit Quick.Core.Mvc.Factory.Controller;

interface

{$i QuickCore.inc}

uses
  Quick.Core.Mvc.Context,
  Quick.Core.Mvc.Controller,
  Quick.Core.DependencyInjection;

type
  TControllerFactory = class
  private
    fDependencyInjector : TDependencyInjector;
  public
    constructor Create(aDependencyInjector : TDependencyInjector);
    function GetController(aContext : THttpContextBase) : THttpController;
  end;

implementation

{ TControllerFactory }

constructor TControllerFactory.Create(aDependencyInjector: TDependencyInjector);
begin
  fDependencyInjector := aDependencyInjector;
end;

function TControllerFactory.GetController(aContext: THttpContextBase): THttpController;
begin
  Result := fDependencyInjector.AbstractFactory<THttpController>(aContext.Route.ControllerClass);
  //Result := aContext.Route.ControllerClass.Create as THttpController;
end;

end.
