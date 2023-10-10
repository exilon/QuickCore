{ ***************************************************************************

  Copyright (c) 2016-2021 Kike Pérez

  Unit        : Quick.Core.Extensions.HealthChecks.Entity
  Description : Core Extensions Entity Health Checks
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

unit Quick.Core.Extensions.HealthChecks.Entity;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.TypInfo,
  System.TimeSpan,
  Quick.Commons,
  Quick.Core.Entity,
  Quick.Core.DependencyInjection,
  Quick.Core.Extensions.HealthChecks;

type
  TEntityHealthCheck = class(THealthCheck)
  private
    fDBContext : TDBContext;
  public
    constructor Create(aDBContext : TDBContext; aTimeSpan : TTimeSpan);
    destructor Destroy; override;
    procedure Check; override;
  end;

  TEntityHealthChecksExtension = class(THealthChecksExtension)
    class function AddDBContextCheck<T : TDBContext>(const aName : string; aTimeSpan : TTimeSpan) : THealthChecksService;
  end;

implementation

{ TEntityHealthChecksExtension }

class function TEntityHealthChecksExtension.AddDBContextCheck<T>(const aName : string; aTimeSpan : TTimeSpan) : THealthChecksService;
var
  check : IHealthCheck;
  db : T;
begin
  Result := HealthChecksService;
  db := HealthChecksService.ServiceCollection.Resolve<T>();
  //db := (PTypeInfo(TypeInfo(T)).TypeData.ClassType.Create) as T;
  //TDBContext(db).Database := HealthChecksService.ServiceCollection.Resolve<T>().Database.Clone;
  //TDBContext(db).Connection.FromConnectionString(Integer(TDBContext(db).Connection.Provider),TDBContext(db).Connection.GetCustomConnectionString);
  //TDBContext(db).Connect;
  check := TEntityHealthCheck.Create(db,aTimeSpan);
  check.Name := aName;
  Result := HealthChecksService.AddCheck(check);
end;

{ TEntityHealthCheck }

procedure TEntityHealthCheck.Check;
begin
  inherited;
  try
    fDBContext.Database.GetTableNames;
  except
    on E : Exception do raise Exception.CreateFmt('Error connection to "%s" database!',[fDBContext.Connection.Database]);
  end;
end;

constructor TEntityHealthCheck.Create(aDBContext : TDBContext; aTimeSpan : TTimeSpan);
begin
  inherited Create(aTimeSpan);
  fName := 'Entity';
  fDBContext := aDBContext;
end;

destructor TEntityHealthCheck.Destroy;
begin
  inherited;
end;

end.

