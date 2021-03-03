{ ***************************************************************************

  Copyright (c) 2016-2021 Kike Pérez

  Unit        : Quick.Core.Mvc.Middleware.LogRequest
  Description : Core Mvc Log Request Middleware
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 23/02/2021
  Modified    : 23/02/2021

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

unit Quick.Core.Mvc.Middleware.LogRequest;

{$i QuickCore.inc}

interface

uses
  Classes,
  System.SysUtils,
  System.Generics.Collections,
  Quick.Arrays,
  Quick.HttpServer.Types,
  Quick.HttpServer.Request,
  Quick.Core.Logging.Abstractions,
  Quick.Core.Mvc.Middleware,
  Quick.Core.Mvc.Context,
  Quick.Core.Mvc.Routing,
  Quick.HttpServer.Response;

type
  TLogRequestMiddleware = class(TRequestDelegate)
  private
    fLogger : ILogger;
  public
    constructor Create(aNext: TRequestDelegate; aLogger : ILogger);
    destructor Destroy; override;
    procedure Invoke(aContext : THttpContextBase); override;
  end;

implementation

{ THstsMiddleware }

constructor TLogRequestMiddleware.Create(aNext: TRequestDelegate; aLogger : ILogger);
begin
  inherited Create(aNext);
  fLogger := aLogger;
end;

destructor TLogRequestMiddleware.Destroy;
begin

  inherited;
end;

procedure TLogRequestMiddleware.Invoke(aContext: THttpContextBase);
begin
  inherited;
  try
    Next(aContext);
  finally
    fLogger.Info('%s %d %s %s %s %s %s %d', [aContext.Request.Host,
                                             aContext.Request.Port,
                                             aContext.Request.GetMethodAsString,
                                             aContext.Request.URL,
                                             aContext.Request.UserAgent,
                                             aContext.Request.Referer,
                                             aContext.Request.ClientIP,
                                             aContext.Response.StatusCode
                                            ]);
  end;
end;

end.

