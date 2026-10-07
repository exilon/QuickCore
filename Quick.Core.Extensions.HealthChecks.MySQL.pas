{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Extensions.HealthChecks.MySQL
  Description : Core Extensions MySQL Health Check
  Author      : Kike Perez
  Version     : 1.0
  Created     : 29/04/2026
  Modified    : 08/05/2026

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

unit Quick.Core.Extensions.HealthChecks.MySQL;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.TimeSpan,
  Data.Win.ADODB,
  Quick.Options,
  Quick.Core.DependencyInjection,
  Quick.Core.Extensions.HealthChecks;

type
  TMySQLHealthCheckOptions = class(TOptions)
  private
    fHost : string;
    fPort : Integer;
    fDatabase : string;
    fUsername : string;
    fPassword : string;
    fDriver : string;
    fConnectionTimeout : Integer;
  public
    constructor Create; override;
  published
    property Host : string read fHost write fHost;
    property Port : Integer read fPort write fPort;
    property Database : string read fDatabase write fDatabase;
    property Username : string read fUsername write fUsername;
    property Password : string read fPassword write fPassword;
    { ODBC driver name, e.g. "MySQL ODBC 8.0 ANSI Driver" or "MySQL ODBC 8.0 Unicode Driver" }
    property Driver : string read fDriver write fDriver;
    property ConnectionTimeout : Integer read fConnectionTimeout write fConnectionTimeout;
  end;

  TMySQLHealthCheck = class(THealthCheck)
  private
    fADOConnection : TADOConnection;
    fHost : string;
    fPort : Integer;
    fDatabase : string;
  public
    constructor Create(aOptions : TMySQLHealthCheckOptions; aTimeSpan : TTimeSpan);
    destructor Destroy; override;
    function GetCheckKind : string; override;
    function GetTags : string; override;
    procedure Check; override;
  end;

  TMySQLHealthChecksExtension = class(THealthChecksExtension)
    class function AddMySQLCheck(const aName : string; aOptionsProc : TConfigureOptionsProc<TMySQLHealthCheckOptions>; aTimeSpan : TTimeSpan) : THealthChecksService;
  end;

implementation

{ TMySQLHealthCheckOptions }

constructor TMySQLHealthCheckOptions.Create;
begin
  inherited;
  fHost := 'localhost';
  fPort := 3306;
  fDatabase := '';
  fUsername := 'root';
  fPassword := '';
  fDriver := 'MySQL ODBC 8.0 ANSI Driver';
  fConnectionTimeout := 3;
end;

{ TMySQLHealthCheck }

constructor TMySQLHealthCheck.Create(aOptions : TMySQLHealthCheckOptions; aTimeSpan : TTimeSpan);
begin
  inherited Create(aTimeSpan);
  fName := 'MySQL';
  fHost := aOptions.Host;
  fPort := aOptions.Port;
  fDatabase := aOptions.Database;
  fADOConnection := TADOConnection.Create(nil);
  fADOConnection.LoginPrompt := False;
  fADOConnection.ConnectionTimeout := aOptions.ConnectionTimeout;
  fADOConnection.Provider := 'MSDASQL.1';
  fADOConnection.ConnectionString := Format(
    'Provider=MSDASQL.1;Persist Security Info=False;Extended Properties="DRIVER={%s};SERVER=%s;PORT=%d;DATABASE=%s;UID=%s;PWD=%s;OPTION=3;"',
    [aOptions.Driver,
     aOptions.Host,
     aOptions.Port,
     aOptions.Database,
     aOptions.Username,
     aOptions.Password]);
end;

destructor TMySQLHealthCheck.Destroy;
begin
  if fADOConnection.Connected then fADOConnection.Close;
  fADOConnection.Free;
  inherited;
end;

function TMySQLHealthCheck.GetCheckKind: string;
begin
  Result := 'mysql';
end;

function TMySQLHealthCheck.GetTags: string;
begin
  Result := Format('{"host":"%s","port":%d,"database":"%s"}',[fHost, fPort, fDatabase]);
end;

procedure TMySQLHealthCheck.Check;
begin
  inherited;
  fADOConnection.Open;
  try
    if not fADOConnection.Connected then
      raise Exception.CreateFmt('Cannot connect to MySQL server "%s:%d" database "%s"',
        [fHost, fPort, fDatabase]);
  finally
    fADOConnection.Close;
  end;
end;

{ TMySQLHealthChecksExtension }

class function TMySQLHealthChecksExtension.AddMySQLCheck(const aName : string;
  aOptionsProc : TConfigureOptionsProc<TMySQLHealthCheckOptions>;
  aTimeSpan : TTimeSpan) : THealthChecksService;
var
  check : IHealthCheck;
  options : TMySQLHealthCheckOptions;
begin
  if not Assigned(aOptionsProc) then raise Exception.Create('MySQLOptions param cannot be nil!');
  options := TMySQLHealthCheckOptions.Create;
  try
    aOptionsProc(options);
    check := TMySQLHealthCheck.Create(options, aTimeSpan);
  finally
    options.Free;
  end;
  check.Name := aName;
  Result := HealthChecksService.AddCheck(check);
end;

end.
