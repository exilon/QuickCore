{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Extensions.HealthChecks.DiskStorage
  Description : Core Extensions DiskStorage Health Check
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

unit Quick.Core.Extensions.HealthChecks.DiskStorage;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.TimeSpan,
  Winapi.Windows,
  Quick.Options,
  Quick.Core.DependencyInjection,
  Quick.Core.Extensions.HealthChecks;

type
  TDiskStorageHealthCheckOptions = class(TOptions)
  private
    fPath : string;
    fMinFreeGB : Double;
  public
    constructor Create; override;
  published
    property Path : string read fPath write fPath;
    property MinFreeGB : Double read fMinFreeGB write fMinFreeGB;
  end;

  TDiskStorageHealthCheck = class(THealthCheck)
  private
    fPath : string;
    fMinFreeGB : Double;
  public
    constructor Create(const aPath : string; aMinFreeGB : Double; aTimeSpan : TTimeSpan);
    function GetCheckKind : string; override;
    function GetTags : string; override;
    procedure Check; override;
  end;

  TDiskStorageHealthChecksExtension = class(THealthChecksExtension)
    class function AddDiskStorageCheck(const aName : string; aOptionsProc : TConfigureOptionsProc<TDiskStorageHealthCheckOptions>; aTimeSpan : TTimeSpan) : THealthChecksService;
  end;

implementation

{ TDiskStorageHealthCheckOptions }

constructor TDiskStorageHealthCheckOptions.Create;
begin
  inherited;
  fPath := 'C:\';
  fMinFreeGB := 1.0;
end;

{ TDiskStorageHealthCheck }

constructor TDiskStorageHealthCheck.Create(const aPath : string; aMinFreeGB : Double; aTimeSpan : TTimeSpan);
begin
  inherited Create(aTimeSpan);
  fName := 'DiskStorage';
  fPath := aPath;
  fMinFreeGB := aMinFreeGB;
end;

function TDiskStorageHealthCheck.GetCheckKind: string;
begin
  Result := 'disk';
end;

function TDiskStorageHealthCheck.GetTags: string;
begin
  Result := Format('{"path":"%s","minFreeGB":%.2f}',[fPath.Replace('\','\\'), fMinFreeGB]);
end;

procedure TDiskStorageHealthCheck.Check;
var
  freeAvail : ULARGE_INTEGER;
  totalBytes : ULARGE_INTEGER;
  freeGB : Double;
begin
  inherited;
  if not GetDiskFreeSpaceEx(PChar(fPath), @freeAvail, @totalBytes, nil) then
    raise Exception.CreateFmt('Cannot query disk space for path "%s" (error %d)', [fPath, GetLastError]);
  freeGB := freeAvail.QuadPart / 1073741824.0;
  if freeGB < fMinFreeGB then
    raise Exception.CreateFmt('Disk "%s" has only %.2f GB free (minimum required: %.2f GB)',
      [fPath, freeGB, fMinFreeGB]);
end;

{ TDiskStorageHealthChecksExtension }

class function TDiskStorageHealthChecksExtension.AddDiskStorageCheck(const aName : string;
  aOptionsProc : TConfigureOptionsProc<TDiskStorageHealthCheckOptions>;
  aTimeSpan : TTimeSpan) : THealthChecksService;
var
  check : IHealthCheck;
  options : TDiskStorageHealthCheckOptions;
begin
  if not Assigned(aOptionsProc) then raise Exception.Create('DiskStorageOptions param cannot be nil!');
  options := TDiskStorageHealthCheckOptions.Create;
  try
    aOptionsProc(options);
    check := TDiskStorageHealthCheck.Create(options.Path, options.MinFreeGB, aTimeSpan);
  finally
    options.Free;
  end;
  check.Name := aName;
  Result := HealthChecksService.AddCheck(check);
end;

end.
