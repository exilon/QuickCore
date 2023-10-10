{ ***************************************************************************

  Copyright (c) 2016-2021 Kike Pérez

  Unit        : Quick.Core.Extensions.HealthChecks
  Description : Core Extensions Health Checks
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

unit Quick.Core.Extensions.HealthChecks;

{$i QuickCore.inc}

interface

uses
  {$IFDEF DEBUG_HEALTHCHECKS}
    Quick.Debug.Utils,
  {$ENDIF}
  System.JSON,
  System.SysUtils,
  System.TimeSpan,
  System.Net.HttpClient,
  System.Generics.Collections,
  Quick.Collections,
  Quick.Core.Serialization.Abstractions,
  Quick.Options,
  Quick.Threads,
  Quick.Chrono,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging.Abstractions;

type
  THealthCheckOptions = class(TOptions)
  private
    fLogFails : Boolean;
    fRetryTimes : Integer;
    fMaxSize : Integer;
  published
    constructor Create; override;
    property LogFails : Boolean read fLogFails write fLogFails;
    property RetryTimes : Integer read fRetryTimes write fRetryTimes;
    property MaxSize : Integer read fMaxSize write fMaxSize;
  end;

  THealthStatus = (hsNotChecked, hsPassed, hsFailed);

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

  THealthCheck = class(TInterfacedObject,IHealthCheck)
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
    procedure Check; virtual;
  end;

  TUrlHealthCheck = class(THealthCheck)
  private
    fUrl : string;
  public
    constructor Create(const aUrl: string; aTimeSpan : TTimeSpan);
    destructor Destroy; override;
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
  published
    property Name : string read fName write fName;
    property LastCheck : TDateTime read fLastCheck write fLastCheck;
    property TimeElapsed : string read fTimeElapsed write fTimeElapsed;
    property Status : THealthStatus read fStatus write fStatus;
    property LastStatusChange : TDateTime read fLastStatusChange write fLastStatusChange;
    property ErrorMsg : string read fErrorMsg write fErrorMsg;
  end;
  {$M-}

  IHealthChecksService = interface
  ['{BC78D855-4E19-4DBD-869A-10B423B08076}']
    function GetMetrics : IList<THealthCheckMetric>;
  end;

  IHealthChecksStore = interface
  ['{9B16807B-FF16-4FBF-AB36-85D30364D70C}']
    procedure Add(aHealthCheck : IHealthCheck);
    function Last : IList<THealthCheckMetric>;
  end;

  THealthCheckStore = class(TInterfacedObject,IHealthChecksStore)
  protected
    function MapMetric(aHealthCheck : IHealthCheck) : THealthCheckMetric;
  public
    procedure Add(aHealthCheck : IHealthCheck); virtual; abstract;
    function Last : IList<THealthCheckMetric>; virtual; abstract;
  end;

  TMemoryHealthCheckStore = class(THealthCheckStore)
  private type
    THealthCheckMetrics = TObjectList<THealthCheckMetric>;
  private
    fCheckMetrics : TObjectDictionary<string,THealthCheckMetrics>;
  public
    constructor Create(aMaxSize : Integer);
    destructor Destroy; override;
    procedure Add(aHealthCheck : IHealthCheck); override;
    function Last : IList<THealthCheckMetric>; override;
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
    fNumChecks : Integer;
    function GetMetrics : IList<THealthCheckMetric>;
  public
    constructor Create(aServiceCollection : TServiceCollection; aOptions : THealthCheckOptions; aLogger : ILogger);
    destructor Destroy; override;
    property ServiceCollection : TServiceCollection read fServiceCollection;
    function OnCheckFail(aHealthFailProc : THealthCheckFailEvent) : THealthChecksService;
    function AddCheck(aHealthCheck : IHealthCheck) : THealthChecksService;
    function AddUrlCheck(const aName, aUrl : string; aTimeSpan : TTimeSpan) : THealthChecksService;
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
    begin
      {$IFDEF DEBUG_HEALTHCHECKS}
      TDebugger.Trace(Self,'HealthCheck %s...',[aHealthCheck.Name]);
      {$ENDIF}
        chrono := TChronometer.Create(True);
        try
          aHealthCheck.Check;
          aHealthCheck.Status := THealthStatus.hsPassed;
          chrono.Stop;
          aHealthCheck.TimeElapsed := chrono.ElapsedTime(False);
          {$IFDEF DEBUG_HEALTHCHECKS}
          TDebugger.Trace(Self,'HealthCheck %s status ok (%s)',[aHealthCheck.Name,aHealthCheck.TimeElapsed]);
          {$ENDIF}
        finally
          chrono.Free;
        end;
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
  .Retry(fOptions.RetryTimes)
  .StartInSeconds(5).RepeatEvery(aHealthCheck.CheckEveryMSecs,TTimeMeasure.tmMilliseconds);
end;

function THealthChecksService.AddInMemoryStorage: THealthChecksService;
begin
  Result := Self;
  fHistory := TMemoryHealthCheckStore.Create(fOptions.MaxSize);
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
//var
//  healthcheck : IHealthCheck;
begin
  {$IFDEF DEBUG_HEALTHCHECKS}
  TDebugger.TimeIt(Self,'GetMetrics','Getting HealthChecks Metric');
  {$ENDIF}
  Result := fHistory.Last;
//  jarr := TJSONArray.Create;
//  for healthcheck in fHealthCheckList do
//  begin
//    var json := TJsonObject.Create;
//    json.AddPair('Name',healthcheck.Name);
//    json.AddPair('Status',TJsonNumber.Create(Integer(healthcheck.Status)));
//    json.AddPair('LastCheck',DateTimeToStr(healthcheck.LastCheck));
//    json.AddPair('Error',healthcheck.ErrorMsg);
//    json.AddPair('TimeElapsed',healthcheck.TimeElapsed);
//    jarr.AddElement(json);
//  end;
//  Result := TJsonObject(jarr);
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

{ THealthCheckOptions }

constructor THealthCheckOptions.Create;
begin
  fLogFails := True;
  fRetryTimes := 0;
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
begin
  Result := THealthCheckMetric.Create;
  Result.Name := aHealthCheck.Name;
  Result.Status := aHealthCheck.Status;
  Result.LastStatusChange := aHealthCheck.LastStatusChange;
  Result.LastCheck := aHealthCheck.LastCheck;
  Result.TimeElapsed := aHealthCheck.TimeElapsed;
  Result.ErrorMsg := aHealthCheck.ErrorMsg;
end;

{ TMemoryHealthCheckStore }

constructor TMemoryHealthCheckStore.Create(aMaxSize: Integer);
begin
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

end.
