{ ***************************************************************************

  Copyright (c) 2016-2019 Kike Pérez

  Unit        : Quick.Core.Extension.TaskControl
  Description : Core TaskControl Extension
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 19/10/2019
  Modified    : 08/12/2019

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

unit Quick.Core.TaskControl;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Threads,
  Quick.Options,
  Quick.Core.DependencyInjection;

type
  TTaskControlServiceExtension = class(TServiceCollectionExtension)
    class function AddTaskControl : TServiceCollection;
  end;

  TTaskControlSettings = class(TOptions)
  private
    fConcurrentWorkers : Integer;
  published
    [Range(1,1000)]
    property ConcurrentWorkers : Integer read fConcurrentWorkers write fConcurrentWorkers;
  end;

  ITaskControl = interface
  ['{0F283549-7AB1-4ACC-A398-66C8B5455EEA}']
    function BackgroundTasks : TBackgroundTasks;
    function ScheduledTasks : TScheduledTasks;
  end;

  TTaskControl = class(TInterfacedObject,ITaskControl)
  private
    fBackgroundTasks : TBackgroundTasks;
    fScheduledTasks : TScheduledTasks;
  public
    constructor Create(aOptions : IOptions<TTaskControlSettings>);
    destructor Destroy; override;
    function BackgroundTasks : TBackgroundTasks;
    function ScheduledTasks : TScheduledTasks;
    function GetCurrentRunningTasksJson : string;
  end;

implementation

{ TTaskControl }

function TTaskControl.BackgroundTasks: TBackgroundTasks;
begin
  Result := fBackgroundTasks;
end;

constructor TTaskControl.Create(aOptions : IOptions<TTaskControlSettings>);
var
  settings : TTaskControlSettings;
begin
  settings := aOptions.Value;
  fBackgroundTasks := TBackgroundTasks.Create(settings.ConcurrentWorkers);
  fScheduledTasks := TScheduledTasks.Create;
  fBackgroundTasks.Start;
  fScheduledTasks.Start;
end;

destructor TTaskControl.Destroy;
begin
  fBackgroundTasks.Free;
  fScheduledTasks.Stop;
  fScheduledTasks.Free;
  inherited;
end;

function TTaskControl.GetCurrentRunningTasksJson: string;
begin
  Result := 'json with tasks stats:' + BackgroundTasks.TaskQueued.ToString;
end;

function TTaskControl.ScheduledTasks: TScheduledTasks;
begin
  Result := fScheduledTasks;
end;

{ TTaskControlServiceExtension }

class function TTaskControlServiceExtension.AddTaskControl: TServiceCollection;
begin
  Result := ServiceCollection;
  ServiceCollection.Configure<TTaskControlSettings>('TaskControl', procedure(aOptions : TTaskControlSettings)
                                                   begin
                                                     aOptions.ConcurrentWorkers := 20;
                                                   end);
  ServiceCollection.AddSingleton<ITaskControl,TTaskControl>;
end;

end.
