{ ***************************************************************************

  Copyright (c) 2016-2019 Kike Pérez

  Unit        : Quick.Core.Mvc.Routing
  Description : Core Http Routing
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 30/08/2019
  Modified    : 01/07/2020

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

unit Quick.Core.Mvc.Routing;

interface

{$i QuickCore.inc}

uses
  {$IFDEF DEBUG_ROUTING}
    Quick.Debug.Utils,
    {.$DEFINE DEBUG_EXTRA}
  {$ENDIF}
  System.SysUtils,
  System.Generics.Defaults,
  System.Generics.Collections,
  Quick.Commons,
  Quick.Arrays,
  Quick.Value,
  Quick.HttpServer.Types,
  Quick.HttpServer.Request;

type

  PFlexPairArray = ^TFlexPairArray;

  TRouteData = class
  private
    fParamValues : TFlexPairArray;
  public
    property ParamValues : TFlexPairArray read fParamValues write fParamValues;
  end;

  THttpRoute = class
  private
    fName : string;
    fActionMethodName : string;
    fHttpMethods : TMethodVerbs;
    fControllerName : string;
    fControllerClass : TControllerClass;
    fURL : string;
    fHasParamValues : Boolean;
    fActionName : string;
    fAuthorize : Boolean;
    fOutputCache : Integer;
    fIsDefaultRoute : Boolean;
    procedure SetURL(const Value: string);
    function GetParamName(const aRawParam : string) : string;
  public
    constructor Create;
    property Name : string read fName write fName;
    property ActionMethodName : string read fActionMethodName write fActionMethodName;
    property HttpMethods : TMethodVerbs read fHttpMethods write fHttpMethods;
    property URL : string read fURL write SetURL;
    property HasParamValues : Boolean read fHasParamValues write fHasParamValues;
    property ActionName : string read fActionName write fActionName;
    property Authorize : Boolean read fAuthorize write fAuthorize;
    property OutputCache : Integer read fOutputCache write fOutputCache;
    property ControllerName : string read fControllerName write fControllerName;
    property ControllerClass : TControllerClass read fControllerClass write fControllerClass;
    property IsDefaultRoute : Boolean read fIsDefaultRoute write fIsDefaultRoute;
    function HandlesRequest(aRequest : IHttpRequest) : Boolean;
    function GetRouteData(aRequest : IHttpRequest): TRouteData;
  end;

  EControllerNotFound = class(Exception);
  EControllerNotDefined = class(Exception);
  ERouteNotHandled = class(Exception);


//{controller=Home}/{action=Index}/{id?}


implementation


{ THttpRoute }

constructor THttpRoute.Create;
begin
  fName := '';
  fURL := '';
  fOutputCache := 0;
  fControllerName := '';
  fURL := '';
  fActionName := '';
  fAuthorize := False;
  fHasParamValues := False;
  fActionMethodName := '';
  fIsDefaultRoute := False;
end;

function THttpRoute.HandlesRequest(aRequest: IHttpRequest): Boolean;
var
  routesegment : string;
  nseg : Integer;
  requestsegments : TArray<string>;
  kind : string;
begin
  //compare if method allowed
  if not (aRequest.Method in Self.HttpMethods) then Exit(False);
  {$IFDEF DEBUG_EXTRA}
  TDebugger.Trace(Self,Format('Compare (Route: %s) = (URL: %s)',[aRequest.URL,fURL]));
  {$ENDIF}
  //if simple route without required or optional values
  if not fHasParamValues then
  begin
    //compare route
    Result := CompareText(aRequest.URL,fURL) = 0;
  end
  else //has required or optional values
  begin
    requestsegments := aRequest.URL.Split(['/']);
    nseg := 0;
    for routesegment in fURL.Split(['/']) do
    begin
      //check if param value needed
      if routesegment.Contains('{') then
      begin
        //if less request segments and not optional param, not matches route
        if (nseg > High(requestsegments)) and (not routesegment.Contains('?}')) then Exit(False);
        if routesegment.Contains(':') then
        begin
          if routesegment.Contains('?') then kind := GetSubString(routesegment,':','?').Trim
            else kind := GetSubString(routesegment,':','}').Trim;
          if (kind = 'int') and (not IsInteger(requestsegments[nseg])) then Exit(False);
          if (kind = 'alpha') and (IsInteger(requestsegments[nseg])) then Exit(False);
        end;
      end  //if parameterless segment not equal to route, not matches route
      else if (nseg > High(requestsegments)) or (CompareText(requestsegments[nseg],routesegment) <> 0) then Exit(False);
      Inc(nseg);
    end;
    Result := True;
  end;
end;

function THttpRoute.GetParamName(const aRawParam: string): string;
begin
  //Result := aRawParam.Replace('?','');
  //Result := GetSubString(Result,'{','}');
  if aRawParam.Contains(':') then Result := GetSubString(aRawParam,'{',':')
    else Result := GetSubString(aRawParam,'{','}');
  Result := Result.Trim;
end;

function THttpRoute.GetRouteData(aRequest : IHttpRequest): TRouteData;
var
  nseg : Integer;
  maxreqseg : Integer;
  routesegment : string;
  requestsegments : TArray<string>;
begin
  Result := TRouteData.Create;
  if fIsDefaultRoute then requestsegments := (fURL.Substring(0,fURL.IndexOf('{')) + aRequest.URL).Split(['/'])
    else requestsegments := aRequest.URL.Split(['/']);
  maxreqseg := High(requestsegments);
  nseg := 0;

  for routesegment in fURL.Split(['/']) do
  begin
    //check if param value needed
    if routesegment.Contains('{') then
    begin
      //if less request segments and not optional param, not matches route
      if (nseg > maxreqseg) and (not routesegment.Contains('?}')) then raise Exception.Create('One or more URL parameters missing!');
      Result.ParamValues.Add(GetParamName(routesegment),requestsegments[nseg]);
    end  //if parameterless segment not equal to route, not matches route
    else if (maxreqseg > nseg) and (CompareText(requestsegments[nseg],routesegment) <> 0) then raise Exception.Create('One or more URL parameters missing!');
    Inc(nseg);
  end;
end;

procedure THttpRoute.SetURL(const Value: string);
begin
  if Value.StartsWith('/') then fURL := Value.Substring(1)
    else fURL := Value;
  fHasParamValues := Value.Contains('{');
end;

end.
