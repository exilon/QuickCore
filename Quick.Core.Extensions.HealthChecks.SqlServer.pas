{ ***************************************************************************

  Copyright (c) 2016-2021 Kike Pérez

  Unit        : Quick.Core.Extensions.HealthChecks.SqlServer
  Description : Core Extensions SqlServer Health Checks
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

unit Quick.Core.Extensions.HealthChecks.SqlServer;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.TimeSpan,
  Quick.Commons,
  Quick.Core.Entity,
  Quick.Core.DependencyInjection,
  Quick.Core.Extensions.HealthChecks;

type
  TSqlServerHealthCheck = class(THealthCheck)
  private
    fEntityDatabase : TEntityDatabase;
  public
    constructor Create(aDataBase : TEntityDatabase; aTimeSpan : TTimeSpan);
    destructor Destroy; override;
    procedure Check; override;
  end;

  TSqlServerHealthChecksExtension = class(THealthChecksExtension)
    class function AddSqlServerCheck<T : TDBContext>(const aName : string; aTimeSpan : TTimeSpan) : THealthChecksService;
  end;

implementation

{ TSqlServerHealthChecksExtension }

class function TSqlServerHealthChecksExtension.AddSqlServerCheck<T>(const aName : string; aTimeSpan : TTimeSpan) : THealthChecksService;
var
  check : IHealthCheck;
  db : TEntityDatabase;
begin
  check := TSqlServerHealthCheck.Create(db,aTimeSpan);
  check.Name := aName;
  Result := HealthChecksService.AddCheck(check);
end;

{ TSqlServerHealthCheck }

procedure TSqlServerHealthCheck.Check;
begin
  inherited;
  fEntityDatabase.Connect;
  if not fEntityDatabase.IsConnected then raise Exception.CreateFmt('Error connection to "%s" database!',[fEntityDatabase.Connection.Database]);
end;

constructor TSqlServerHealthCheck.Create(aDataBase : TEntityDatabase; aTimeSpan : TTimeSpan);
begin
  inherited Create(aTimeSpan);
  fName := 'SqlServer';
  fEntityDatabase := aDataBase.Clone;
end;

destructor TSqlServerHealthCheck.Destroy;
begin
  fEntityDatabase.Free;
  inherited;
end;

end.
