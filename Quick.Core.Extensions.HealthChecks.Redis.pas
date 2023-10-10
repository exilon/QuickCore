{ ***************************************************************************

  Copyright (c) 2016-2021 Kike Pérez

  Unit        : Quick.Core.Extensions.HealthChecks.Redis
  Description : Core Extensions Entity Health Checks
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 14/02/2021
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

unit Quick.Core.Extensions.HealthChecks.Redis;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.TypInfo,
  System.TimeSpan,
  Quick.Commons,
  Quick.Options,
  Quick.Data.Redis,
  Quick.Core.DependencyInjection,
  Quick.Core.Extensions.HealthChecks;

type
  TRedisHealthCheckOptions = class(TOptions)
  private
    fHost : string;
    fPort : Integer;
    fPassword : string;
    fDatabaseNumber : Integer;
    fConnectionTimeout: Integer;
    fReadTimeout: Integer;
  public
    constructor Create; override;
  published
    property Host : string read fHost write fHost;
    property Port : Integer read fPort write fPort;
    property Password : string read fPassword write fPassword;
    property DatabaseNumber : Integer read fDatabaseNumber write fDatabaseNumber;
    property ConnectionTimeout : Integer read fConnectionTimeout write fConnectionTimeout;
    property ReadTimeout : Integer read fReadTimeout write fReadTimeout;
  end;

  TRedisHealthCheck = class(THealthCheck)
  private
    fRedisClient : TRedisClient;
    fRedisOptions : TRedisHealthCheckOptions;
  public
    constructor Create(aRedisOptions : TRedisHealthCheckOptions; aTimeSpan : TTimeSpan);
    destructor Destroy; override;
    procedure Check; override;
  end;

  TRedisHealthChecksExtension = class(THealthChecksExtension)
    class function AddRedisCheck(const aName : string; aRedisOptionsProc : TConfigureOptionsProc<TRedisHealthCheckOptions>; aTimeSpan : TTimeSpan) : THealthChecksService;
  end;

implementation

{ TRedisHealthChecksExtension }

class function TRedisHealthChecksExtension.AddRedisCheck(const aName : string; aRedisOptionsProc : TConfigureOptionsProc<TRedisHealthCheckOptions>; aTimeSpan : TTimeSpan) : THealthChecksService;
var
  check : IHealthCheck;
begin
  if not Assigned(aRedisOptionsProc) then raise Exception.Create('RedisOptions param cannot be nil!');

  var redisOptions := TRedisHealthCheckOptions.Create;
  aRedisOptionsProc(redisOptions);
  check := TRedisHealthCheck.Create(redisOptions,aTimeSpan);
  check.Name := aName;
  Result := HealthChecksService.AddCheck(check);
end;

{ TEntityHealthCheck }

procedure TRedisHealthCheck.Check;
begin
  inherited;
  fRedisClient.Disconnect;
  try
    fRedisClient.Connect;
  finally
    fRedisClient.Disconnect;
  end;
end;

constructor TRedisHealthCheck.Create(aRedisOptions : TRedisHealthCheckOptions; aTimeSpan : TTimeSpan);
begin
  inherited Create(aTimeSpan);
  fName := 'Redis';
  fRedisOptions := aRedisOptions;
  fRedisClient := TRedisClient.Create;
  fRedisClient.Host := aRedisOptions.Host;
  fRedisClient.Port := aRedisOptions.Port;
  fRedisClient.DataBaseNumber := aRedisOptions.DatabaseNumber;
  fRedisClient.Password := aRedisOptions.Password;
  fRedisClient.ConnectionTimeout := aRedisOptions.ConnectionTimeout;
  fRedisClient.ReadTimeout := aRedisOptions.ReadTimeout;
end;

destructor TRedisHealthCheck.Destroy;
begin
  fRedisClient.Free;
  inherited;
end;

{ TRedisHealthCheckOptions }

constructor TRedisHealthCheckOptions.Create;
begin
  inherited;
  fReadTimeout := 3000;
  fConnectionTimeout := 2000;
end;

end.

