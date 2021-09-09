{ ***************************************************************************

  Copyright (c) 2016-2021 Kike Pérez

  Unit        : Quick.Core.App
  Description : Core App with Service Collection
  Author      : Kike Pérez
  Version     : 1.8
  Created     : 21/03/2021
  Modified    : 21/03/2021

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

unit Quick.Core.App;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Core.DependencyInjection;

type
  TCoreApp = class
  private
    fServiceCollection : TServiceCollection;
  public
    constructor Create(aStartupClass : TStartupClass); virtual;
    destructor Destroy; override;
    procedure Start; virtual;
    procedure Stop; virtual;
  end;

implementation

{ TCoreApp }

constructor TCoreApp.Create(aStartupClass : TStartupClass);
begin
  try
    fServiceCollection := TServiceCollection.Create;
    aStartupClass.ConfigureServices(fServiceCollection);
    fServiceCollection.Build;
  except
    on E : Exception do
    begin
      raise EServiceBuildError.CreateFmt('DependencyInjection: Failed to build services (%s)',[e.Message]);
    end;
  end;
end;

destructor TCoreApp.Destroy;
begin
  fServiceCollection.Free;
  inherited;
end;

procedure TCoreApp.Start;
begin

end;

procedure TCoreApp.Stop;
begin

end;

end.
