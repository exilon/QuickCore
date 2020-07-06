{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Mvc.Extensions.TaskControl
  Description : Core MVC Extensions TaskControl
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 19/10/2019
  Modified    : 11/01/2020

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

unit Quick.Core.Mvc.Extensions.TaskControl;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Core.TaskControl,
  Quick.Core.MVC,
  Quick.HttpServer.Types,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult;

type
  TTaskControlMVCServerExtension = class(TMVCServerExtension)
    class function UseTaskControl : TMVCServer;
  end;

  [Route('TaskControl')]
  TTaskControlController = class(THttpController)
  private
    fTaskControl : ITaskControl;
  public
    constructor Create(aTaskControl : ITaskControl);
  published
    [HttpGet('Stats'),ActionName('Index')]
    function Stats : IActionResult;
  end;

implementation

{ TTaskControlMVCServerExtension }

class function TTaskControlMVCServerExtension.UseTaskControl: TMVCServer;
begin
  Result := MVCServer;
  if MVCServer.Services.IsRegistered<ITaskControl,TTaskControl>('') then
  begin
    MVCServer.AddController(TTaskControlController);
  end
  else raise Exception.Create('TaskControl dependency not found. Need to be added before!');
end;

{ TTaskControlController }

constructor TTaskControlController.Create(aTaskControl: ITaskControl);
begin
  fTaskControl := aTaskControl;
end;

function TTaskControlController.Stats: IActionResult;
begin
  Result := Content(TTaskControl(fTaskControl).GetCurrentRunningTasksJson);
end;

end.
