{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Mvc.Extensions.HealthChecks
  Description : Core MVC Extensions TaskControl
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

unit Quick.Core.Mvc.Extensions.HealthChecks;

{$i QuickCore.inc}

interface

uses
  System.JSON,
  System.SysUtils,
  System.NetEncoding,
  Quick.Collections,
  Quick.Core.Extensions.HealthChecks,
  Quick.Core.MVC,
  Quick.HttpServer.Types,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult;

type
  THealthChecksResponseBuilder = class
  private
    class function FormatDuration(const aMilliseconds : Double) : string; static;
    class function NormalizeDuration(const aDuration : string; out aMilliseconds : Double) : string; static;
    class function StatusToText(aStatus : THealthStatus) : string; static;
    class function TryParseFloatInvariant(const aValue : string; out aNumber : Double) : Boolean; static;
    class function TryParseDurationMs(const aValue : string; out aMilliseconds : Double) : Boolean; static;
  public
    class function AggregateStatus(aMetrics : IList<THealthCheckMetric>) : string; static;
    class function BuildLivenessJson : string; static;
    class function BuildSummaryJson(aMetrics : IList<THealthCheckMetric>; aService : IHealthChecksService = nil) : string; static;
    class function BuildHistoryJson(const aName : string; aMetrics : IList<THealthCheckMetric>) : string; static;
  end;

  THealthChecksMVCServerExtension = class(TMVCServerExtension)
    class function UseHealthChecks : TMVCServer;
  end;

  [Route('health')]
  THealthChecksEndpointController = class(THttpController)
  private
    fHealthChecksService : IHealthChecksService;
    procedure ApplySummaryStatusCode(aMetrics : IList<THealthCheckMetric>);
  public
    constructor Create(aHealthCheckService : IHealthChecksService);
  published
    [HttpGet]
    function Health : IActionResult;
    [HttpGet('detail')]
    function Detail : IActionResult;
    [HttpGet('history/{name}')]
    function History(const name : string) : IActionResult;
    [HttpGet('ready')]
    function Ready : IActionResult;
    [HttpGet('live')]
    function Live : IActionResult;
  end;

  [Route('HealthChecks')]
  THealthChecksController = class(THttpController)
  private
    fHealthChecksService : IHealthChecksService;
  public
    constructor Create(aHealthCheckService : IHealthChecksService);
  published
    [HttpGet]
    function Health : IActionResult;
  end;

implementation

class function THealthChecksResponseBuilder.AggregateStatus(aMetrics : IList<THealthCheckMetric>) : string;
var
  metric : THealthCheckMetric;
  hasNotChecked : Boolean;
  hasDegraded : Boolean;
begin
  if (aMetrics = nil) or (aMetrics.Count = 0) then Exit('Healthy');

  hasNotChecked := False;
  hasDegraded := False;
  for metric in aMetrics do
  begin
    case metric.Status of
      hsFailed:     Exit('Unhealthy');
      hsNotChecked: hasNotChecked := True;
      hsDegraded:   hasDegraded := True;
    end;
  end;

  if hasNotChecked then Result := 'Pending'
  else if hasDegraded then Result := 'Degraded'
  else Result := 'Healthy';
end;

class function THealthChecksResponseBuilder.BuildLivenessJson : string;
var
  root : TJSONObject;
  entries : TJSONObject;
  entry : TJSONObject;
begin
  root := TJSONObject.Create;
  try
    root.AddPair('status', 'Healthy');
    root.AddPair('totalDuration', '00:00:00.000');

    entries := TJSONObject.Create;
    entry := TJSONObject.Create;
    entry.AddPair('status', 'Healthy');
    entry.AddPair('duration', '00:00:00.000');
    entry.AddPair('description', TJSONNull.Create);
    entries.AddPair('self', entry);

    root.AddPair('entries', entries);
    Result := root.ToJSON;
  finally
    root.Free;
  end;
end;

class function THealthChecksResponseBuilder.BuildSummaryJson(aMetrics : IList<THealthCheckMetric>; aService : IHealthChecksService = nil) : string;
var
  root : TJSONObject;
  entries : TJSONObject;
  entry : TJSONObject;
  metric : THealthCheckMetric;
  histMetric : THealthCheckMetric;
  durationMs : Double;
  totalDurationMs : Double;
  history : IList<THealthCheckMetric>;
  histArray : TJSONArray;
  histEntry : TJSONObject;
begin
  root := TJSONObject.Create;
  try
    root.AddPair('status', AggregateStatus(aMetrics));

    entries := TJSONObject.Create;
    totalDurationMs := 0;

    if aMetrics <> nil then
    begin
      for metric in aMetrics do
      begin
        entry := TJSONObject.Create;
        entry.AddPair('status', StatusToText(metric.Status));
        entry.AddPair('duration', NormalizeDuration(metric.TimeElapsed, durationMs));
        if metric.ErrorMsg.Trim.IsEmpty then entry.AddPair('description', TJSONNull.Create)
          else entry.AddPair('description', metric.ErrorMsg);
        if not metric.CheckKind.IsEmpty then entry.AddPair('kind', metric.CheckKind);
        if not metric.Tags.IsEmpty then
        begin
          var tagsObj := TJSONObject.ParseJSONValue(metric.Tags);
          if tagsObj <> nil then entry.AddPair('tags', tagsObj)
            else entry.AddPair('tags', TJSONObject.Create);
        end;
        entry.AddPair('checkEveryMs', TJSONNumber.Create(metric.CheckEveryMSecs));
        if metric.LastCheck > 0 then
          entry.AddPair('lastCheckUtc', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', metric.LastCheck))
        else
          entry.AddPair('lastCheckUtc', TJSONNull.Create);

        // history (last 10 runs, most recent last)
        histArray := TJSONArray.Create;
        if aService <> nil then
        begin
          history := aService.GetCheckHistory(metric.Name, 10);
          for histMetric in history do
          begin
            histEntry := TJSONObject.Create;
            histEntry.AddPair('status', StatusToText(histMetric.Status));
            histEntry.AddPair('duration', NormalizeDuration(histMetric.TimeElapsed, durationMs));
            histEntry.AddPair('durationMs', TJSONNumber.Create(Round(durationMs)));
            if histMetric.LastCheck > 0 then
              histEntry.AddPair('ts', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', histMetric.LastCheck))
            else
              histEntry.AddPair('ts', TJSONNull.Create);
            if not histMetric.ErrorMsg.Trim.IsEmpty then
              histEntry.AddPair('error', histMetric.ErrorMsg);
            histArray.AddElement(histEntry);
          end;
        end;
        entry.AddPair('history', histArray);

        entries.AddPair(metric.Name, entry);
        totalDurationMs := totalDurationMs + durationMs;
      end;
    end;

    root.AddPair('totalDuration', FormatDuration(totalDurationMs));
    root.AddPair('entries', entries);
    Result := root.ToJSON;
  finally
    root.Free;
  end;
end;

class function THealthChecksResponseBuilder.BuildHistoryJson(const aName : string; aMetrics : IList<THealthCheckMetric>) : string;
var
  root : TJSONObject;
  histArray : TJSONArray;
  histEntry : TJSONObject;
  metric : THealthCheckMetric;
  durationMs : Double;
begin
  root := TJSONObject.Create;
  try
    root.AddPair('name', aName);
    histArray := TJSONArray.Create;
    if aMetrics <> nil then
    begin
      for metric in aMetrics do
      begin
        histEntry := TJSONObject.Create;
        histEntry.AddPair('status', StatusToText(metric.Status));
        histEntry.AddPair('duration', NormalizeDuration(metric.TimeElapsed, durationMs));
        histEntry.AddPair('durationMs', TJSONNumber.Create(Round(durationMs)));
        if metric.LastCheck > 0 then
          histEntry.AddPair('ts', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', metric.LastCheck))
        else
          histEntry.AddPair('ts', TJSONNull.Create);
        if not metric.ErrorMsg.Trim.IsEmpty then
          histEntry.AddPair('error', metric.ErrorMsg);
        histArray.AddElement(histEntry);
      end;
    end;
    root.AddPair('history', histArray);
    Result := root.ToJSON;
  finally
    root.Free;
  end;
end;

class function THealthChecksResponseBuilder.FormatDuration(const aMilliseconds : Double) : string;
var
  totalMs : Int64;
  hours : Int64;
  minutes : Int64;
  seconds : Int64;
  milliseconds : Int64;
begin
  totalMs := Round(aMilliseconds);
  if totalMs < 0 then totalMs := 0;

  hours        := totalMs div 3600000;
  minutes      := (totalMs mod 3600000) div 60000;
  seconds      := (totalMs mod 60000) div 1000;
  milliseconds := totalMs mod 1000;

  // Keep Xabaril-like fixed format expected by tests and UI parsing.
  Result := Format('%.2d:%.2d:%.2d.%.3d', [hours, minutes, seconds, milliseconds]);
end;

class function THealthChecksResponseBuilder.NormalizeDuration(const aDuration : string; out aMilliseconds : Double) : string;
begin
  if TryParseDurationMs(aDuration, aMilliseconds) then Result := FormatDuration(aMilliseconds)
  else
  begin
    aMilliseconds := 0;
    if aDuration.Trim.IsEmpty then Result := '00:00:00.000'
      else Result := aDuration;
  end;
end;

class function THealthChecksResponseBuilder.StatusToText(aStatus : THealthStatus) : string;
begin
  case aStatus of
    hsPassed:     Result := 'Healthy';
    hsDegraded:   Result := 'Degraded';
    hsFailed:     Result := 'Unhealthy';
    hsNotChecked: Result := 'Pending';
  else
    Result := 'Pending';
  end;
end;

class function THealthChecksResponseBuilder.TryParseDurationMs(const aValue : string; out aMilliseconds : Double) : Boolean;
var
  durationText : string;
  numberText : string;
  numericValue : Double;
  parts : TArray<string>;
  secondParts : TArray<string>;
  hours : Integer;
  minutes : Integer;
  seconds : Integer;
  milliseconds : Integer;
  paddedMilliseconds : string;
begin
  Result := False;
  aMilliseconds := 0;
  durationText := aValue.Trim.ToLower.Replace('μs', 'us').Replace(',', '.');
  if durationText.IsEmpty then Exit(False);

  if durationText.Contains(':') then
  begin
    parts := durationText.Split([':']);
    if Length(parts) <> 3 then Exit(False);

    secondParts := parts[2].Split(['.']);
    if not TryStrToInt(parts[0], hours) then Exit(False);
    if not TryStrToInt(parts[1], minutes) then Exit(False);
    if not TryStrToInt(secondParts[0], seconds) then Exit(False);

    milliseconds := 0;
    if Length(secondParts) > 1 then
    begin
      paddedMilliseconds := secondParts[1];
      while Length(paddedMilliseconds) < 3 do paddedMilliseconds := paddedMilliseconds + '0';
      if Length(paddedMilliseconds) > 3 then SetLength(paddedMilliseconds, 3);
      if not TryStrToInt(paddedMilliseconds, milliseconds) then Exit(False);
    end;

    aMilliseconds := (((hours * 60) + minutes) * 60 + seconds) * 1000 + milliseconds;
    Exit(True);
  end;

  if durationText.EndsWith('ns') then
  begin
    numberText := durationText.Substring(0, durationText.Length - 2);
    if not TryParseFloatInvariant(numberText, numericValue) then Exit(False);
    aMilliseconds := numericValue / 1000000;
    Exit(True);
  end;

  if durationText.EndsWith('us') then
  begin
    numberText := durationText.Substring(0, durationText.Length - 2);
    if not TryParseFloatInvariant(numberText, numericValue) then Exit(False);
    aMilliseconds := numericValue / 1000;
    Exit(True);
  end;

  if durationText.EndsWith('ms') then
  begin
    numberText := durationText.Substring(0, durationText.Length - 2);
    if not TryParseFloatInvariant(numberText, numericValue) then Exit(False);
    aMilliseconds := numericValue;
    Exit(True);
  end;

  if durationText.EndsWith('s') then
  begin
    numberText := durationText.Substring(0, durationText.Length - 1);
    if not TryParseFloatInvariant(numberText, numericValue) then Exit(False);
    aMilliseconds := numericValue * 1000;
    Exit(True);
  end;

  if durationText.EndsWith('m') then
  begin
    numberText := durationText.Substring(0, durationText.Length - 1);
    if not TryParseFloatInvariant(numberText, numericValue) then Exit(False);
    aMilliseconds := numericValue * 60000;
    Exit(True);
  end;

  if durationText.EndsWith('h') then
  begin
    numberText := durationText.Substring(0, durationText.Length - 1);
    if not TryParseFloatInvariant(numberText, numericValue) then Exit(False);
    aMilliseconds := numericValue * 3600000;
    Exit(True);
  end;

  if durationText.EndsWith('d') then
  begin
    numberText := durationText.Substring(0, durationText.Length - 1);
    if not TryParseFloatInvariant(numberText, numericValue) then Exit(False);
    aMilliseconds := numericValue * 86400000;
    Exit(True);
  end;
end;

class function THealthChecksResponseBuilder.TryParseFloatInvariant(const aValue : string; out aNumber : Double) : Boolean;
var
  formatSettings : TFormatSettings;
begin
  formatSettings := TFormatSettings.Create;
  formatSettings.DecimalSeparator := '.';
  Result := TryStrToFloat(aValue.Replace(',', '.'), aNumber, formatSettings);
end;

{ THealthChecksMVCServerExtension }

class function THealthChecksMVCServerExtension.UseHealthChecks: TMVCServer;
begin
  Result := MVCServer;
  if MVCServer.Services.IsRegistered<IHealthChecksService>('') then
  begin
    MVCServer.AddController(THealthChecksEndpointController);
    MVCServer.AddController(THealthChecksController);
  end
  else raise Exception.Create('HealthChecks dependency not found. Need to be added before!');
end;

{ THealthChecksEndpointController }

procedure THealthChecksEndpointController.ApplySummaryStatusCode(aMetrics : IList<THealthCheckMetric>);
begin
  if SameText(THealthChecksResponseBuilder.AggregateStatus(aMetrics), 'Unhealthy') then
  begin
    Response.StatusCode := Integer(THttpStatusCode.ServiceUnavailable);
    Response.StatusText := 'Service Unavailable';
  end
  else
  begin
    Response.StatusCode := Integer(THttpStatusCode.OK);
    Response.StatusText := 'OK';
  end;
end;

constructor THealthChecksEndpointController.Create(aHealthCheckService : IHealthChecksService);
begin
  fHealthChecksService := aHealthCheckService;
end;

function THealthChecksEndpointController.Health : IActionResult;
var
  metrics : IList<THealthCheckMetric>;
begin
  metrics := fHealthChecksService.GetMetrics;
  Response.StatusCode := Integer(THttpStatusCode.OK);
  Response.StatusText := 'OK';
  Result := Json(THealthChecksResponseBuilder.BuildSummaryJson(metrics));
end;

function THealthChecksEndpointController.Detail : IActionResult;
var
  metrics : IList<THealthCheckMetric>;
begin
  metrics := fHealthChecksService.GetMetrics;
  Response.StatusCode := Integer(THttpStatusCode.OK);
  Response.StatusText := 'OK';
  Result := Json(THealthChecksResponseBuilder.BuildSummaryJson(metrics, fHealthChecksService));
end;

function THealthChecksEndpointController.History(const name : string) : IActionResult;
var
  history : IList<THealthCheckMetric>;
  decodedName : string;
begin
  decodedName := TNetEncoding.URL.Decode(name);
  history := fHealthChecksService.GetCheckHistory(decodedName, MaxInt);
  Response.StatusCode := Integer(THttpStatusCode.OK);
  Response.StatusText := 'OK';
  Result := Json(THealthChecksResponseBuilder.BuildHistoryJson(decodedName, history));
end;

function THealthChecksEndpointController.Live : IActionResult;
begin
  Response.StatusCode := Integer(THttpStatusCode.OK);
  Response.StatusText := 'OK';
  Result := Json(THealthChecksResponseBuilder.BuildLivenessJson);
end;

function THealthChecksEndpointController.Ready : IActionResult;
var
  metrics : IList<THealthCheckMetric>;
begin
  metrics := fHealthChecksService.GetMetrics;
  ApplySummaryStatusCode(metrics);
  Result := Json(THealthChecksResponseBuilder.BuildSummaryJson(metrics, fHealthChecksService));
end;

{ THealthChecksController }

constructor THealthChecksController.Create(aHealthCheckService : IHealthChecksService);
begin
  fHealthChecksService := aHealthCheckService;
end;

function THealthChecksController.Health: IActionResult;
begin
  Result := Json(fHealthChecksService.GetMetrics.ToList);
end;

end.
