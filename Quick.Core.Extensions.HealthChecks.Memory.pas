{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Extensions.HealthChecks.Memory
  Description : Core Extensions Memory Health Check
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

unit Quick.Core.Extensions.HealthChecks.Memory;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.TimeSpan,
  Winapi.Windows,
  Winapi.PsAPI,
  Quick.Options,
  Quick.Core.DependencyInjection,
  Quick.Core.Extensions.HealthChecks;

type
  TMemoryHealthCheckOptions = class(TOptions)
  private
    fMaxAllowedMB : Int64;
  public
    constructor Create; override;
  published
    { Maximum allowed working-set memory for the current process in megabytes. }
    property MaxAllowedMB : Int64 read fMaxAllowedMB write fMaxAllowedMB;
  end;

  TMemoryHealthCheck = class(THealthCheck)
  private
    fMaxAllowedMB : Int64;
  public
    constructor Create(aMaxAllowedMB : Int64; aTimeSpan : TTimeSpan);
    function GetCheckKind : string; override;
    function GetTags : string; override;
    procedure Check; override;
  end;

  TMemoryHealthChecksExtension = class(THealthChecksExtension)
    class function AddMemoryCheck(const aName : string; aOptionsProc : TConfigureOptionsProc<TMemoryHealthCheckOptions>; aTimeSpan : TTimeSpan) : THealthChecksService;
  end;

implementation

{ TMemoryHealthCheckOptions }

constructor TMemoryHealthCheckOptions.Create;
begin
  inherited;
  fMaxAllowedMB := 1024; // 1 GB default threshold
end;

{ TMemoryHealthCheck }

constructor TMemoryHealthCheck.Create(aMaxAllowedMB : Int64; aTimeSpan : TTimeSpan);
begin
  inherited Create(aTimeSpan);
  fName := 'Memory';
  fMaxAllowedMB := aMaxAllowedMB;
end;

function TMemoryHealthCheck.GetCheckKind: string;
begin
  Result := 'memory';
end;

function TMemoryHealthCheck.GetTags: string;
begin
  Result := Format('{"maxAllowedMB":%d}',[fMaxAllowedMB]);
end;

procedure TMemoryHealthCheck.Check;
var
  memoryCounters : PROCESS_MEMORY_COUNTERS;
  usedMB : Int64;
begin
  inherited;
  ZeroMemory(@memoryCounters, SizeOf(memoryCounters));
  if not GetProcessMemoryInfo(GetCurrentProcess, @memoryCounters, SizeOf(memoryCounters)) then
    raise Exception.Create('Cannot query current process memory usage');
  usedMB := memoryCounters.WorkingSetSize div (1024 * 1024);
  if usedMB > fMaxAllowedMB then
    raise Exception.CreateFmt('Memory used %d MB exceeds the allowed limit of %d MB',
      [usedMB, fMaxAllowedMB]);
end;

{ TMemoryHealthChecksExtension }

class function TMemoryHealthChecksExtension.AddMemoryCheck(const aName : string;
  aOptionsProc : TConfigureOptionsProc<TMemoryHealthCheckOptions>;
  aTimeSpan : TTimeSpan) : THealthChecksService;
var
  check : IHealthCheck;
  options : TMemoryHealthCheckOptions;
begin
  if not Assigned(aOptionsProc) then raise Exception.Create('MemoryOptions param cannot be nil!');
  options := TMemoryHealthCheckOptions.Create;
  try
    aOptionsProc(options);
    check := TMemoryHealthCheck.Create(options.MaxAllowedMB, aTimeSpan);
  finally
    options.Free;
  end;
  check.Name := aName;
  Result := HealthChecksService.AddCheck(check);
end;

end.
