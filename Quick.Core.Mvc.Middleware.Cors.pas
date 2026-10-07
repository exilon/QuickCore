{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Mvc.Middleware.Cors
  Description : Core Mvc CORS Middleware
  Author      : Kike Perez
  Version     : 1.0
  Created     : 13/04/2026
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

unit Quick.Core.Mvc.Middleware.Cors;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Quick.Options,
  Quick.HttpServer.Response,
  Quick.Core.Mvc.Middleware,
  Quick.Core.Mvc.Context;

type
  TCorsPolicyOptions = class(TOptions)
  private
    fAllowedOrigins : TArray<string>;
    fAllowedMethods : TArray<string>;
    fAllowedHeaders : TArray<string>;
    fExposedHeaders : TArray<string>;
    fAllowCredentials : Boolean;
    fMaxAgeSeconds : Integer;
    fAllowAnyOrigin : Boolean;
    fAllowAnyMethod : Boolean;
    fAllowAnyHeader : Boolean;
  public
    constructor Create; override;
    function AllowOrigin(const aOrigin : string) : TCorsPolicyOptions;
    function AllowOrigins(const aOrigins : TArray<string>) : TCorsPolicyOptions;
    function AllowAnyOrigin : TCorsPolicyOptions;
    function AllowMethod(const aMethod : string) : TCorsPolicyOptions;
    function AllowMethods(const aMethods : TArray<string>) : TCorsPolicyOptions;
    function AllowAnyMethod : TCorsPolicyOptions;
    function AllowHeader(const aHeader : string) : TCorsPolicyOptions;
    function AllowHeaders(const aHeaders : TArray<string>) : TCorsPolicyOptions;
    function AllowAnyHeader : TCorsPolicyOptions;
    function ExposeHeaders(const aHeaders : TArray<string>) : TCorsPolicyOptions;
    function WithCredentials : TCorsPolicyOptions;
    function MaxAge(aSeconds : Integer) : TCorsPolicyOptions;
  published
    property AllowedOrigins : TArray<string> read fAllowedOrigins write fAllowedOrigins;
    property AllowedMethods : TArray<string> read fAllowedMethods write fAllowedMethods;
    property AllowedHeaders : TArray<string> read fAllowedHeaders write fAllowedHeaders;
    property ExposedHeaders : TArray<string> read fExposedHeaders write fExposedHeaders;
    property AllowCredentials : Boolean read fAllowCredentials write fAllowCredentials;
    property MaxAgeSeconds : Integer read fMaxAgeSeconds write fMaxAgeSeconds;
  end;

  TCorsMiddleware = class(TRequestDelegate)
  private
    fOptions : TCorsPolicyOptions;
    function IsOriginAllowed(const aOrigin : string) : Boolean;
    function ConcatArray(const aArr : TArray<string>) : string;
  public
    constructor Create(aNext : TRequestDelegate; aOptions : IOptions<TCorsPolicyOptions>);
    destructor Destroy; override;
    procedure Invoke(aContext : THttpContextBase); override;
  end;

implementation

const
  CORS_ORIGIN_HEADER            = 'Origin';
  CORS_REQUEST_METHOD_HEADER    = 'Access-Control-Request-Method';
  CORS_REQUEST_HEADERS_HEADER   = 'Access-Control-Request-Headers';
  CORS_ALLOW_ORIGIN_HEADER      = 'Access-Control-Allow-Origin';
  CORS_ALLOW_METHODS_HEADER     = 'Access-Control-Allow-Methods';
  CORS_ALLOW_HEADERS_HEADER     = 'Access-Control-Allow-Headers';
  CORS_EXPOSE_HEADERS_HEADER    = 'Access-Control-Expose-Headers';
  CORS_ALLOW_CREDENTIALS_HEADER = 'Access-Control-Allow-Credentials';
  CORS_MAX_AGE_HEADER           = 'Access-Control-Max-Age';
  HTTP_METHOD_OPTIONS           = 'OPTIONS';

{ TCorsPolicyOptions }

constructor TCorsPolicyOptions.Create;
begin
  inherited;
  fAllowedMethods := ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD'];
  fAllowedHeaders := ['Content-Type', 'Authorization', 'Accept'];
  fMaxAgeSeconds := 86400; // 24 h
end;

function TCorsPolicyOptions.AllowOrigin(const aOrigin : string) : TCorsPolicyOptions;
begin
  fAllowedOrigins := fAllowedOrigins + [aOrigin];
  Result := Self;
end;

function TCorsPolicyOptions.AllowOrigins(const aOrigins : TArray<string>) : TCorsPolicyOptions;
begin
  fAllowedOrigins := fAllowedOrigins + aOrigins;
  Result := Self;
end;

function TCorsPolicyOptions.AllowAnyOrigin : TCorsPolicyOptions;
begin
  fAllowAnyOrigin := True;
  Result := Self;
end;

function TCorsPolicyOptions.AllowMethod(const aMethod : string) : TCorsPolicyOptions;
begin
  fAllowedMethods := fAllowedMethods + [aMethod.ToUpper];
  Result := Self;
end;

function TCorsPolicyOptions.AllowMethods(const aMethods : TArray<string>) : TCorsPolicyOptions;
begin
  fAllowedMethods := fAllowedMethods + aMethods;
  Result := Self;
end;

function TCorsPolicyOptions.AllowAnyMethod : TCorsPolicyOptions;
begin
  fAllowAnyMethod := True;
  Result := Self;
end;

function TCorsPolicyOptions.AllowHeader(const aHeader : string) : TCorsPolicyOptions;
begin
  fAllowedHeaders := fAllowedHeaders + [aHeader];
  Result := Self;
end;

function TCorsPolicyOptions.AllowHeaders(const aHeaders : TArray<string>) : TCorsPolicyOptions;
begin
  fAllowedHeaders := fAllowedHeaders + aHeaders;
  Result := Self;
end;

function TCorsPolicyOptions.AllowAnyHeader : TCorsPolicyOptions;
begin
  fAllowAnyHeader := True;
  Result := Self;
end;

function TCorsPolicyOptions.ExposeHeaders(const aHeaders : TArray<string>) : TCorsPolicyOptions;
begin
  fExposedHeaders := fExposedHeaders + aHeaders;
  Result := Self;
end;

function TCorsPolicyOptions.WithCredentials : TCorsPolicyOptions;
begin
  fAllowCredentials := True;
  Result := Self;
end;

function TCorsPolicyOptions.MaxAge(aSeconds : Integer) : TCorsPolicyOptions;
begin
  fMaxAgeSeconds := aSeconds;
  Result := Self;
end;

{ TCorsMiddleware }

constructor TCorsMiddleware.Create(aNext : TRequestDelegate; aOptions : IOptions<TCorsPolicyOptions>);
begin
  inherited Create(aNext);
  if aOptions <> nil then
    fOptions := aOptions.Value
  else
    fOptions := TCorsPolicyOptions.Create;
end;

destructor TCorsMiddleware.Destroy;
begin
  inherited;
end;

function TCorsMiddleware.ConcatArray(const aArr : TArray<string>) : string;
var
  s : string;
begin
  Result := '';
  for s in aArr do
  begin
    if Result <> '' then Result := Result + ', ';
    Result := Result + s;
  end;
end;

function TCorsMiddleware.IsOriginAllowed(const aOrigin : string) : Boolean;
var
  allowed : string;
begin
  if fOptions.fAllowAnyOrigin then Exit(True);
  for allowed in fOptions.AllowedOrigins do
    if SameText(allowed, aOrigin) then Exit(True);
  Result := False;
end;

procedure TCorsMiddleware.Invoke(aContext : THttpContextBase);
var
  origin : string;
  isPreflight : Boolean;
  response : IHttpResponse;
begin
  inherited;
  response := aContext.Response;
  origin := aContext.Request.Headers.GetValue(CORS_ORIGIN_HEADER);

  if origin = '' then
  begin
    Next(aContext);
    Exit;
  end;

  if not IsOriginAllowed(origin) then
  begin
    Next(aContext);
    Exit;
  end;

  // Set Allow-Origin
  // SEC-10: '*' and credentials=true cannot coexist (RFC 6454).
  // When credentials are required, reflect the specific request origin instead of '*'.
  if fOptions.fAllowAnyOrigin and fOptions.AllowCredentials then
    response.Headers.Add(CORS_ALLOW_ORIGIN_HEADER, origin)
  else if fOptions.fAllowAnyOrigin then
    response.Headers.Add(CORS_ALLOW_ORIGIN_HEADER, '*')
  else
    response.Headers.Add(CORS_ALLOW_ORIGIN_HEADER, origin);

  if fOptions.AllowCredentials then
    response.Headers.Add(CORS_ALLOW_CREDENTIALS_HEADER, 'true');

  if Length(fOptions.ExposedHeaders) > 0 then
    response.Headers.Add(CORS_EXPOSE_HEADERS_HEADER, ConcatArray(fOptions.ExposedHeaders));

  // Preflight (OPTIONS)
  isPreflight := SameText(aContext.Request.GetMethodAsString, HTTP_METHOD_OPTIONS) and
                 (aContext.Request.Headers.GetValue(CORS_REQUEST_METHOD_HEADER) <> '');

  if isPreflight then
  begin
    if fOptions.fAllowAnyMethod then
      response.Headers.Add(CORS_ALLOW_METHODS_HEADER, '*')
    else
      response.Headers.Add(CORS_ALLOW_METHODS_HEADER, ConcatArray(fOptions.AllowedMethods));

    if fOptions.fAllowAnyHeader then
      response.Headers.Add(CORS_ALLOW_HEADERS_HEADER, '*')
    else
      response.Headers.Add(CORS_ALLOW_HEADERS_HEADER, ConcatArray(fOptions.AllowedHeaders));

    if fOptions.MaxAgeSeconds > 0 then
      response.Headers.Add(CORS_MAX_AGE_HEADER, IntToStr(fOptions.MaxAgeSeconds));

    response.StatusCode := 204;
    // Do NOT call Next for preflight — terminate here
    Exit;
  end;

  Next(aContext);
end;

end.
