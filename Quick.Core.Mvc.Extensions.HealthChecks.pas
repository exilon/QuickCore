{ ***************************************************************************

  Copyright (c) 2016-2021 Kike Pérez

  Unit        : Quick.Core.Mvc.Extensions.HealthChecks
  Description : Core MVC Extensions TaskControl
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 12/02/2021
  Modified    : 21/02/2021

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

unit Quick.Core.Mvc.Extensions.HealthChecks;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Core.Extensions.HealthChecks,
  Quick.Core.MVC,
  Quick.HttpServer.Types,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult;

type
  THealthChecksMVCServerExtension = class(TMVCServerExtension)
    class function UseHealthChecks : TMVCServer;
  end;

  [Route('HealthChecks')]
  THealthChecksController = class(THttpController)
  private
    fHealthChecksService : IHealthChecksService;
  public
    constructor Create(aHealthCheckService : IHealthChecksService);
  published
    [HttpGet]
    function Health : IActionResult;
  end;

implementation

{ THealthChecksMVCServerExtension }

class function THealthChecksMVCServerExtension.UseHealthChecks: TMVCServer;
begin
  Result := MVCServer;
  if MVCServer.Services.IsRegistered<IHealthChecksService>('') then
  begin
    MVCServer.AddController(THealthChecksController);
  end
  else raise Exception.Create('HealthChecks dependency not found. Need to be added before!');
end;

{ THealthChecksController }

constructor THealthChecksController.Create(aHealthCheckService : IHealthChecksService);
begin
  fHealthChecksService := aHealthCheckService;
end;

function THealthChecksController.Health: IActionResult;
begin
  Result := Json(fHealthChecksService.GetMetrics.ToList);
end;

end.
