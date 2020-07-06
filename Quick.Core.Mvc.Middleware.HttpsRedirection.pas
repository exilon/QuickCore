{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Mvc.Middleware.HttpsRedirection
  Description : Core Mvc Https Redirection Middleware
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 22/02/2020
  Modified    : 22/02/2020

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

unit Quick.Core.Mvc.Middleware.HttpsRedirection;

{$i QuickCore.inc}

interface

uses
  Classes,
  System.SysUtils,
  System.Generics.Collections,
  Quick.Arrays,
  Quick.HttpServer.Types,
  Quick.HttpServer.Request,
  Quick.Core.Mvc.Middleware,
  Quick.Core.Mvc.Context,
  Quick.Core.Mvc.Routing,
  Quick.HttpServer.Response;

type
  THttpsRedirectionMiddleware = class(TRequestDelegate)
  private
    fResponseStatus : Integer;
  public
    constructor Create(aNext: TRequestDelegate; aResponseStatus : Integer );
    destructor Destroy; override;
    procedure Invoke(aContext : THttpContextBase); override;
  end;

implementation

{ THttpsRedirectionMiddleware }

constructor THttpsRedirectionMiddleware.Create(aNext: TRequestDelegate; aResponseStatus : Integer);
begin
  inherited Create(aNext);
  fResponseStatus := aResponseStatus;
end;

destructor THttpsRedirectionMiddleware.Destroy;
begin

  inherited;
end;

procedure THttpsRedirectionMiddleware.Invoke(aContext: THttpContextBase);
var
  url : string;
begin
  inherited;
  if aContext.Request.Port <> 443 then //only redirects if not 443 port...check if https better
  begin
    url := 'https://' + aContext.Request.Host + '/' + aContext.Request.URL + aContext.Request.UnparsedParams;
    aContext.Response.Headers.AddOrUpdate('Location',aContext.Request.UnparsedParams);
    aContext.Response.StatusCode := fResponseStatus;
  end
  else Next(aContext);
end;

end.

