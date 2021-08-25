{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Extensions.Hosting
  Description : Core Services Hosting environment
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 01/03/2021
  Modified    : 03/03/2021

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

unit Quick.Core.Extensions.Hosting;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Commons;

type
  IHost = interface
  ['{7E5F7540-66F1-41F1-BBB7-59C114ADD7B0}']
    procedure Start;
    procedure Stop;
  end;

  IHostCore = interface(IHost)
    procedure SetOnStart(const Value: TProc);
    procedure SetOnStop(const Value: TProc);
    property OnStart : TProc write SetOnStart;
    property OnStop : TProc write SetOnStop;
  end;

  THostCore = class(TInterfacedObject,IHostCore)
  private
    fOnStop: TProc;
    fOnStart: TProc;
    procedure SetOnStart(const Value: TProc);
    procedure SetOnStop(const Value: TProc);
  public
    property OnStart : TProc read fOnStart write SetOnStart;
    property OnStop : TProc read fOnStop write SetOnStop;
    procedure Start; virtual;
    procedure Stop; virtual;
  end;

  IHostEnvironment =  interface
    function GetApplicationName: string;
    function GetContentRootPath: string;
    function GetEnvironmentName: string;
    property ApplicationName : string read GetApplicationName;
    property ContentRootPath : string read GetContentRootPath;
    property EnvironmentName : string read GetEnvironmentName;
    function IsDevelopment : Boolean;
    function IsStaging : Boolean;
    function IsProduction : Boolean;
    function IsEnvironment(const aName : string) : Boolean;
  end;

  THostEnvironment = class(TInterfacedObject,IHostEnvironment)
  private
    fApplicationName : string;
    fContentRootPath : string;
    fEnvironmentName : string;
    function GetApplicationName: string;
    function GetContentRootPath: string;
    function GetEnvironmentName: string;
    procedure SetApplicationName(const Value: string);
    procedure SetContentRootPath(const Value: string);
    procedure SetEnvironmentName(const Value: string);
    function GetCoreEnvironment : string;
  public
    constructor Create;
    property ApplicationName : string read GetApplicationName write SetApplicationName;
    property ContentRootPath : string read GetContentRootPath write SetContentRootPath;
    property EnvironmentName : string read GetEnvironmentName write SetEnvironmentName;
    function IsDevelopment : Boolean;
    function IsStaging : Boolean;
    function IsProduction : Boolean;
    function IsEnvironment(const aName : string) : Boolean;
  end;

implementation

{ THostingEnvironment }

constructor THostEnvironment.Create;
begin
  fApplicationName := Quick.Commons.GetAppName;
  fContentRootPath := Quick.Commons.path.EXEPATH;
  fEnvironmentName := GetCoreEnvironment;
end;

function THostEnvironment.GetApplicationName: string;
begin
  Result := fApplicationName;
end;

function THostEnvironment.GetContentRootPath: string;
begin
  Result := fContentRootPath;
end;

function THostEnvironment.GetCoreEnvironment: string;
begin
  Result := GetEnvironmentVariable('CORE_ENVIRONMENT');
end;

function THostEnvironment.GetEnvironmentName: string;
begin
  Result := fEnvironmentName;
end;

function THostEnvironment.IsDevelopment: Boolean;
begin
  Result := (CompareText(fEnvironmentName,'Development') = 0) or (CompareText(fEnvironmentName,'DEV') = 0);
end;

function THostEnvironment.IsEnvironment(const aName: string): Boolean;
begin
  Result := CompareText(fEnvironmentName,aName) = 0;
end;

function THostEnvironment.IsProduction: Boolean;
begin
  Result := (CompareText(fEnvironmentName,'Production') = 0) or (CompareText(fEnvironmentName,'PRO') = 0);
end;

function THostEnvironment.IsStaging: Boolean;
begin
  Result := (CompareText(fEnvironmentName,'Staging') = 0) or (CompareText(fEnvironmentName,'STAG') = 0);
end;

procedure THostEnvironment.SetApplicationName(const Value: string);
begin
  fApplicationName := Value;
end;

procedure THostEnvironment.SetContentRootPath(const Value: string);
begin
  fContentRootPath := Value;
end;

procedure THostEnvironment.SetEnvironmentName(const Value: string);
begin
  fEnvironmentName := Value;
end;

{ THostCore }

procedure THostCore.SetOnStart(const Value: TProc);
begin
  fOnStart := Value;
end;

procedure THostCore.SetOnStop(const Value: TProc);
begin
  fOnStop := Value;
end;

procedure THostCore.Start;
begin
  if Assigned(fOnStart) then fOnStart;
end;

procedure THostCore.Stop;
begin
  if Assigned(fOnStop) then fOnStop;
end;

end.
