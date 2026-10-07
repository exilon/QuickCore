{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Extensions.HealthChecks
  Description : Core Extensions Health Checks
  Author      : Kike Perez
  Version     : 1.0
  Created     : 12/02/2021
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

unit Quick.Core.Extensions.HealthChecks;

{$i QuickCore.inc}

interface

uses
  {$IFDEF DEBUG_HEALTHCHECKS}
    Quick.Debug.Utils,
  {$ENDIF}
  System.JSON,
  System.Classes,
  System.SysUtils,
  System.TimeSpan,
  System.Net.HttpClient,
  System.Generics.Collections,
  Quick.Collections,
  Quick.Core.Serialization.Abstractions,
  Quick.Options,
  Quick.Threads,
  Quick.Chrono,
  Quick.Core.Entity,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging.Abstractions;

type
  THealthCheckOptions = class(TOptions)
  private
    fLogFails : Boolean;
    fRetryTimes : Integer;
    fMaxSize : Integer;
    fDegradedIfSlowerThanMs : Integer;
  published
    constructor Create; override;
    property LogFails : Boolean read fLogFails write fLogFails;
    property RetryTimes : Integer read fRetryTimes write fRetryTimes;
    property MaxSize : Integer read fMaxSize write fMaxSize;
    // If check passes but took longer than this threshold (ms), mark as Degraded. 0 = disabled.
    property DegradedIfSlowerThanMs : Integer read fDegradedIfSlowerThanMs write fDegradedIfSlowerThanMs;
  end;

  THealthStatus = (hsNotChecked, hsPassed, hsDegraded, hsFailed);

  IHealthCheck = interface
  ['{7FA7D505-1C60-443C-A126-3103B69BA3CC}']
    function GetStatus: THealthStatus;
    procedure SetStatus(const Value: THealthStatus);
    function GetLastCheck: TDateTime;
    function GetName: string;
    procedure SetName(const Value: string);
    function GetTimeElapsed: string;
    procedure SetTimeElapsed(const Value: string);
    function GetErrorMsg: string;
    procedure SetErrorMsg(const Value: string);
    function GetLastStatusChange: TDateTime;
    function GetCheckEveryMSecs : Int64;
    //public
    property Name : string read GetName write SetName;
    property LastCheck : TDateTime read GetLastCheck;
    property LastStatusChange : TDateTime read GetLastStatusChange;
    property TimeElapsed : string read GetTimeElapsed write SetTimeElapsed;
    property Status : THealthStatus read GetStatus write SetStatus;
    property CheckEveryMSecs : Int64 read GetCheckEveryMSecs;
    property ErrorMsg : string read GetErrorMsg write SetErrorMsg;
    procedure Check;
  end;

  IHealthCheckInfo = interface
  ['{A3F1C820-9D4B-4E7A-BC12-05E7B4D9F312}']
    function GetCheckKind : string;
    function GetTags : string;
    property CheckKind : string read GetCheckKind;
    property Tags : string read GetTags;
  end;

  THealthCheck = class(TInterfacedObject, IHealthCheck, IHealthCheckInfo)
  private
    function GetStatus: THealthStatus;
    procedure SetStatus(const Value: THealthStatus);
    function GetLastCheck: TDateTime;
    function GetName: string;
    procedure SetName(const Value: string);
    function GetTimeElapsed: string;
    procedure SetTimeElapsed(const Value: string);
    function GetErrorMsg: string;
    procedure SetErrorMsg(const Value: string);
    function GetLastStatusChange: TDateTime;
    function GetCheckEveryMSecs : Int64;
  protected
    fName : string;
    fLastCheck : TDateTime;
    fLastStatusChange : TDateTime;
    fTimeElapsed : string;
    fCheckEveryMSecs : Int64;
    fStatus : THealthStatus;
    fErrorMsg : string;
  public
    constructor Create(aTimeSpan : TTimeSpan);
    property Name : string read GetName write SetName;
    property LastCheck : TDateTime read GetLastCheck;
    property TimeElapsed : string read GetTimeElapsed write SetTimeElapsed;
    property Status : THealthStatus read GetStatus;
    property LastStatusChange : TDateTime read GetLastStatusChange;
    property CheckEveryMSecs : Int64 read GetCheckEveryMSecs;
    property ErrorMsg : string read GetErrorMsg write SetErrorMsg;
    function GetCheckKind : string; virtual;
    function GetTags : string; virtual;
    procedure Check; virtual;
  end;

  TUrlHealthCheck = class(THealthCheck)
  private
    fUrl : string;
  public
    constructor Create(const aUrl: string; aTimeSpan : TTimeSpan);
    destructor Destroy; override;
    function GetCheckKind : string; override;
    function GetTags : string; override;
    procedure Check; override;
  end;

  THealthCheckFailEvent = reference to procedure(aHealtCheck : IHealthCheck);

  {$M+}
  THealthCheckMetric = class
  private
    fName : string;
    fLastCheck : TDateTime;
    fTimeElapsed : string;
    fCheckEveryMSecs : Int64;
    fStatus : THealthStatus;
    fLastStatusChange : TDateTime;
    fErrorMsg : string;
    fCheckKind : string;
    fTags : string;
  published
    property Name : string read fName write fName;
    property LastCheck : TDateTime read fLastCheck write fLastCheck;
    property TimeElapsed : string read fTimeElapsed write fTimeElapsed;
    property CheckEveryMSecs : Int64 read fCheckEveryMSecs write fCheckEveryMSecs;
    property Status : THealthStatus read fStatus write fStatus;
    property LastStatusChange : TDateTime read fLastStatusChange write fLastStatusChange;
    property ErrorMsg : string read fErrorMsg write fErrorMsg;
    property CheckKind : string read fCheckKind write fCheckKind;
    property Tags : string read fTags write fTags;
  end;
  {$M-}

  IHealthChecksService = interface
  ['{BC78D855-4E19-4DBD-869A-10B423B08076}']
    function GetMetrics : IList<THealthCheckMetric>;
    function GetCheckHistory(const aName : string; aCount : Integer) : IList<THealthCheckMetric>;
  end;

  IHealthChecksStore = interface
  ['{9B16807B-FF16-4FBF-AB36-85D30364D70C}']
    procedure Add(aHealthCheck : IHealthCheck);
    function Last : IList<THealthCheckMetric>;
    function GetHistory(const aName : string; aCount : Integer) : IList<THealthCheckMetric>;
  end;

  THealthCheckStore = class(TInterfacedObject,IHealthChecksStore)
  protected
    function MapMetric(aHealthCheck : IHealthCheck) : THealthCheckMetric;
  public
    class function MapMetricStatic(aHealthCheck : IHealthCheck) : THealthCheckMetric; static;
    procedure Add(aHealthCheck : IHealthCheck); virtual; abstract;
    function Last : IList<THealthCheckMetric>; virtual; abstract;
    function GetHistory(const aName : string; aCount : Integer) : IList<THealthCheckMetric>; virtual; abstract;
  end;

  TMemoryHealthCheckStore = class(THealthCheckStore)
  private type
    THealthCheckMetrics = TObjectList<THealthCheckMetric>;
  private
    fCheckMetrics : TObjectDictionary<string,THealthCheckMetrics>;
    fMaxSize : Integer;
  public
    constructor Create(aMaxSize : Integer);
    destructor Destroy; override;
    procedure Add(aHealthCheck : IHealthCheck); override;
    function Last : IList<THealthCheckMetric>; override;
    function GetHistory(const aName : string; aCount : Integer) : IList<THealthCheckMetric>; override;
  end;

  THealthChecksService = class(TInterfacedObject,IHealthChecksService)
  private
    fServiceCollection : TServiceCollection;
    fHistory : IHealthChecksStore;
    fOptions : THealthCheckOptions;
    fLogger : ILogger;
    fHealthCheckList : TList<IHealthCheck>;
    fScheduler : TScheduledTasks;
    fHealthCheckFailEvent : THealthCheckFailEvent;
    function GetMetrics : IList<THealthCheckMetric>;
    function GetCheckHistory(const aName : string; aCount : Integer) : IList<THealthCheckMetric>;
  public
    constructor Create(aServiceCollection : TServiceCollection; aOptions : THealthCheckOptions; aLogger : ILogger);
    destructor Destroy; override;
    property ServiceCollection : TServiceCollection read fServiceCollection;
    function OnCheckFail(aHealthFailProc : THealthCheckFailEvent) : THealthChecksService;
    function AddCheck(aHealthCheck : IHealthCheck) : THealthChecksService;
    function AddDBContextCheck<T : TDBContext>(const aName : string; aTimeSpan : TTimeSpan) : THealthChecksService;
    function AddUrlCheck(const aName, aUrl : string; aTimeSpan : TTimeSpan) : THealthChecksService;
    function AddDiskStorageCheck(const aName, aPath : string; aMinFreeGB : Double; aTimeSpan : TTimeSpan) : THealthChecksService;
    function AddMemoryCheck(const aName : string; aMaxUsedMB : Int64; aTimeSpan : TTimeSpan) : THealthChecksService;
    function AddInMemoryStorage : THealthChecksService;
  end;

  THealthChecksServiceExtension = class(TServiceCollectionExtension)
    class function AddHealthChecks(aConfigureOptions : TConfigureOptionsProc<THealthCheckOptions> = nil) : THealthChecksService;
  end;

  THealthChecksExtension = class
  private class var
    fHealthChecksService : THealthChecksService;
    class function SetService(aHealthChecksService : THealthChecksService) : THealthChecksExtension;
  public
    class property HealthChecksService : THealthChecksService read fHealthChecksService;
  end;

  THealthChecksHelper = class helper for THealthChecksService
    function Extension<T : THealthChecksExtension> : T;
  end;

implementation

uses
  Quick.Core.Extensions.HealthChecks.Entity,
  Quick.Core.Extensions.HealthChecks.DiskStorage,
  Quick.Core.Extensions.HealthChecks.Memory;

{ THealthChecksServiceExtension }

class function THealthChecksServiceExtension.AddHealthChecks(aConfigureOptions : TConfigureOptionsProc<THealthCheckOptions>) : THealthChecksService;
var
  options : THealthCheckOptions;
begin
  if not ServiceCollection.IsRegistered<THealthChecksService> then
  begin
    options := THealthCheckOptions.Create;
    if Assigned(aConfigureOptions) then
    begin
      aConfigureOptions(options);
    end;
    Result := THealthChecksService.Create(ServiceCollection, options,ServiceCollection.AppServices.Logger);
    ServiceCollection.AddSingleton<IHealthChecksService>(Result);
  end
  else raise Exception.Create('Already registered HealthChecks extension!');
end;

{ THealthChecksService }

constructor THealthChecksService.Create(aServiceCollection : TServiceCollection; aOptions : THealthCheckOptions; aLogger : ILogger);
begin
  fServiceCollection := aServiceCollection;
  fOptions := aOptions;
  fLogger := aLogger;
  fHealthCheckList := TList<IHealthCheck>.Create;
  fScheduler := TScheduledTasks.Create;
  fScheduler.Start;
end;

destructor THealthChecksService.Destroy;
begin
  fScheduler.Stop;
  fScheduler.Free;
  fHealthCheckList.Free;
  inherited;
end;

function THealthChecksService.AddCheck(aHealthCheck: IHealthCheck) : THealthChecksService;
begin
  Result := Self;
  fHealthCheckList.Add(aHealthCheck);
  fScheduler.AddTask('',procedure(task : ITask)
    var
      chrono : TChronometer;
      retryCount : Integer;
      lastErrMsg : string;
      succeeded : Boolean;
      waitMs : Integer;
    begin
      {$IFDEF DEBUG_HEALTHCHECKS}
      TDebugger.Trace(Self,'HealthCheck %s...',[aHealthCheck.Name]);
      {$ENDIF}
      retryCount := 0;
      lastErrMsg := '';
      succeeded := False;
      repeat
        // delay before each retry: 100ms on 1st, 200ms on subsequent
        if retryCount > 0 then
        begin
          if retryCount = 1 then waitMs := 100 else waitMs := 200;
          TThread.Sleep(waitMs);
        end;
        chrono := TChronometer.Create(True);
        try
          try
            aHealthCheck.Check;
            chrono.Stop;
            aHealthCheck.TimeElapsed := chrono.ElapsedTime(False);
            aHealthCheck.ErrorMsg := '';
            if (retryCount > 0) or
               ((fOptions.DegradedIfSlowerThanMs > 0) and
                (chrono.ElapsedMilliseconds >= fOptions.DegradedIfSlowerThanMs)) then
              aHealthCheck.Status := THealthStatus.hsDegraded
            else
              aHealthCheck.Status := THealthStatus.hsPassed;
            {$IFDEF DEBUG_HEALTHCHECKS}
            TDebugger.Trace(Self,'HealthCheck %s status ok (%s, retries=%d)',[aHealthCheck.Name,aHealthCheck.TimeElapsed,retryCount]);
            {$ENDIF}
            succeeded := True;
          except
            on E : Exception do
            begin
              chrono.Stop;
              lastErrMsg := E.Message;
              Inc(retryCount);
            end;
          end;
        finally
          chrono.Free;
        end;
      until succeeded or (retryCount > fOptions.RetryTimes);
      // all attempts exhausted - raise to trigger OnException
      if not succeeded then raise Exception.Create(lastErrMsg);
    end)
  .OnException(procedure(task : ITask; aException : Exception)
    begin
      //mark health as failed
      aHealthCheck.Status := THealthStatus.hsFailed;
      aHealthCheck.ErrorMsg := aException.Message;
      {$IFDEF DEBUG_HEALTHCHECKS}
      TDebugger.Trace(Self,'HealthCheck %s status failed (%s)',[aHealthCheck.Name,aHealthCheck.ErrorMsg]);
      {$ENDIF}
      if fOptions.LogFails then fLogger.Critical('HealthCheck %s status failed (%s)',[aHealthCheck.Name,aHealthCheck.ErrorMsg]);
      if Assigned(fHealthCheckFailEvent) then fHealthCheckFailEvent(aHealthCheck);
    end)
  .OnTerminated(procedure(task : ITask)
    begin
      if fHistory <> nil then fHistory.Add(aHealthCheck);
    end)
  .StartInSeconds(5).RepeatEvery(aHealthCheck.CheckEveryMSecs,TTimeMeasure.tmMilliseconds);
end;

function THealthChecksService.AddDBContextCheck<T>(const aName : string; aTimeSpan : TTimeSpan) : THealthChecksService;
begin
  Result := Extension<TEntityHealthChecksExtension>.AddDBContextCheck<T>(aName, aTimeSpan);
end;

function THealthChecksService.AddInMemoryStorage: THealthChecksService;
begin
  Result := Self;
  fHistory := TMemoryHealthCheckStore.Create(fOptions.MaxSize);
end;

function THealthChecksService.AddDiskStorageCheck(const aName, aPath : string; aMinFreeGB : Double; aTimeSpan : TTimeSpan) : THealthChecksService;
var
  check : IHealthCheck;
begin
  Result := Self;
  check := TDiskStorageHealthCheck.Create(aPath, aMinFreeGB, aTimeSpan);
  check.Name := aName;
  AddCheck(check);
end;

function THealthChecksService.AddMemoryCheck(const aName : string; aMaxUsedMB : Int64; aTimeSpan : TTimeSpan) : THealthChecksService;
var
  check : IHealthCheck;
begin
  Result := Self;
  check := TMemoryHealthCheck.Create(aMaxUsedMB, aTimeSpan);
  check.Name := aName;
  AddCheck(check);
end;

function THealthChecksService.AddUrlCheck(const aName, aUrl : string; aTimeSpan : TTimeSpan) : THealthChecksService;
var
  check : IHealthCheck;
begin
  Result := Self;
  check := TUrlHealthCheck.Create(aUrl,aTimeSpan);
  check.Name := aName;
  AddCheck(check);
end;

function THealthChecksService.GetMetrics : IList<THealthCheckMetric>;
var
  healthcheck : IHealthCheck;
  lastMetrics : IList<THealthCheckMetric>;
begin
  {$IFDEF DEBUG_HEALTHCHECKS}
  TDebugger.TimeIt(Self,'GetMetrics','Getting HealthChecks Metric');
  {$ENDIF}
  if fHistory <> nil then lastMetrics := fHistory.Last
    else lastMetrics := nil;

  // If we have history results, return them
  if (lastMetrics <> nil) and (lastMetrics.Count > 0) then
  begin
    Result := lastMetrics;
    Exit;
  end;

  // No checks have run yet — return all registered checks as Pending
  Result := TxList<THealthCheckMetric>.Create;
  for healthcheck in fHealthCheckList do
  begin
    var metric := THealthCheckStore.MapMetricStatic(healthcheck);
    Result.Add(metric);
  end;
end;

function THealthChecksService.GetCheckHistory(const aName : string; aCount : Integer) : IList<THealthCheckMetric>;
begin
  if fHistory <> nil then Result := fHistory.GetHistory(aName, aCount)
    else Result := TxList<THealthCheckMetric>.Create;
end;

function THealthChecksService.OnCheckFail(aHealthFailProc: THealthCheckFailEvent): THealthChecksService;
begin
  Result := Self;
  fHealthCheckFailEvent := aHealthFailProc;
end;

{ THealthCheck }

procedure THealthCheck.Check;
begin
  fLastCheck := Now();
end;

function THealthCheck.GetCheckEveryMSecs: Int64;
begin
  Result := fCheckEveryMSecs;
end;

constructor THealthCheck.Create(aTimeSpan: TTimeSpan);
begin
  fName := '';
  fStatus := THealthStatus.hsNotChecked;
  fCheckEveryMSecs := Round(aTimeSpan.TotalMilliseconds);
end;

function THealthCheck.GetErrorMsg: string;
begin
  Result := fErrorMsg;
end;

function THealthCheck.GetLastCheck: TDateTime;
begin
  Result := fLastCheck;
end;

function THealthCheck.GetLastStatusChange: TDateTime;
begin
  Result := fLastStatusChange;
end;

function THealthCheck.GetName: string;
begin
  if not fName.IsEmpty then Result := fName
    else Result := Self.ClassName.Substring(1);
end;

function THealthCheck.GetStatus: THealthStatus;
begin
  Result := fStatus;
end;

function THealthCheck.GetTimeElapsed: string;
begin
  Result := fTimeElapsed;
end;

procedure THealthCheck.SetErrorMsg(const Value: string);
begin
  fErrorMsg := Value;
end;

procedure THealthCheck.SetName(const Value: string);
begin
  fName := Value;
end;

procedure THealthCheck.SetStatus(const Value: THealthStatus);
begin
  if fStatus <> Value then fLastStatusChange := Now();
  fStatus := Value;
end;

procedure THealthCheck.SetTimeElapsed(const Value: string);
begin
  fTimeElapsed := Value;
end;

function THealthCheck.GetCheckKind: string;
begin
  Result := 'custom';
end;

function THealthCheck.GetTags: string;
begin
  Result := '{}';
end;

{ TUrlHealthCheck }

procedure TUrlHealthCheck.Check;
var
  http : THttpClient;
  statuscode : Integer;
begin
  inherited;
  http := THTTPClient.Create;
  try
    statuscode := http.Get(fUrl).StatusCode;
    if (statuscode  < 200) or (statuscode > 299) then raise Exception.CreateFmt('Url returned %d StatusCode',[statuscode]);
  finally
    http.Free;
  end;
end;

constructor TUrlHealthCheck.Create(const aUrl: string; aTimeSpan : TTimeSpan);
begin
  inherited Create(aTimeSpan);
  fName := 'Url';
  fUrl := aUrl;
end;

destructor TUrlHealthCheck.Destroy;
begin

  inherited;
end;

function TUrlHealthCheck.GetCheckKind: string;
begin
  Result := 'http';
end;

function TUrlHealthCheck.GetTags: string;
begin
  Result := Format('{"url":"%s"}',[fUrl]);
end;

{ THealthCheckOptions }

constructor THealthCheckOptions.Create;
begin
  fLogFails := True;
  fRetryTimes := 0;
  fMaxSize := 100;
  fDegradedIfSlowerThanMs := 0;
end;

{ THealthChecksExtension }

class function THealthChecksExtension.SetService(aHealthChecksService: THealthChecksService): THealthChecksExtension;
begin
  Result := THealthChecksExtension(Self);
  fHealthChecksService := aHealthChecksService;
end;

{ THealthChecksHelper }

function THealthChecksHelper.Extension<T>: T;
begin
  Result := T(THealthChecksExtension.SetService(Self));
end;

{ THealthCheckStore }

function THealthCheckStore.MapMetric(aHealthCheck: IHealthCheck): THealthCheckMetric;
var
  info : IHealthCheckInfo;
begin
  Result := THealthCheckMetric.Create;
  Result.Name := aHealthCheck.Name;
  Result.Status := aHealthCheck.Status;
  Result.LastStatusChange := aHealthCheck.LastStatusChange;
  Result.LastCheck := aHealthCheck.LastCheck;
  Result.TimeElapsed := aHealthCheck.TimeElapsed;
  Result.ErrorMsg := aHealthCheck.ErrorMsg;
  Result.CheckEveryMSecs := aHealthCheck.CheckEveryMSecs;
  if Supports(aHealthCheck, IHealthCheckInfo, info) then
  begin
    Result.CheckKind := info.GetCheckKind;
    Result.Tags := info.GetTags;
  end;
end;

class function THealthCheckStore.MapMetricStatic(aHealthCheck: IHealthCheck): THealthCheckMetric;
var
  info : IHealthCheckInfo;
begin
  Result := THealthCheckMetric.Create;
  Result.Name := aHealthCheck.Name;
  Result.Status := aHealthCheck.Status;
  Result.LastStatusChange := aHealthCheck.LastStatusChange;
  Result.LastCheck := aHealthCheck.LastCheck;
  Result.TimeElapsed := aHealthCheck.TimeElapsed;
  Result.ErrorMsg := aHealthCheck.ErrorMsg;
  Result.CheckEveryMSecs := aHealthCheck.CheckEveryMSecs;
  if Supports(aHealthCheck, IHealthCheckInfo, info) then
  begin
    Result.CheckKind := info.GetCheckKind;
    Result.Tags := info.GetTags;
  end;
end;

{ TMemoryHealthCheckStore }

constructor TMemoryHealthCheckStore.Create(aMaxSize: Integer);
begin
  fMaxSize := aMaxSize;
  fCheckMetrics := TObjectDictionary<string,THealthCheckMetrics>.Create([doOwnsValues]);
end;

destructor TMemoryHealthCheckStore.Destroy;
begin
  fCheckMetrics.Free;
  inherited;
end;

procedure TMemoryHealthCheckStore.Add(aHealthCheck: IHealthCheck);
var
  metrics : THealthCheckMetrics;
  metric : THealthCheckMetric;
begin
  if not fCheckMetrics.TryGetValue(aHealthCheck.Name,metrics) then
  begin
    metrics := THealthCheckMetrics.Create(True);
    fCheckMetrics.Add(aHealthCheck.Name,metrics)
  end;
  metric := MapMetric(aHealthCheck);
  metrics.Add(metric);
  if (fMaxSize > 0) and (metrics.Count > fMaxSize) then
    metrics.Delete(0);
end;

function TMemoryHealthCheckStore.Last: IList<THealthCheckMetric>;
var
  metrics : THealthCheckMetrics;
begin
  Result := TxList<THealthCheckMetric>.Create;
  for metrics in fCheckMetrics.Values do
  begin
    Result.Add(metrics.Last);
  end;
end;

function TMemoryHealthCheckStore.GetHistory(const aName : string; aCount : Integer) : IList<THealthCheckMetric>;
var
  metrics : THealthCheckMetrics;
  i : Integer;
  startIdx : Integer;
begin
  Result := TxList<THealthCheckMetric>.Create;
  if fCheckMetrics.TryGetValue(aName, metrics) then
  begin
    startIdx := metrics.Count - aCount;
    if startIdx < 0 then startIdx := 0;
    for i := startIdx to metrics.Count - 1 do
      Result.Add(metrics[i]);
  end;
end;

end.
