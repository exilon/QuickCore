{ ***************************************************************************

  Copyright (c) 2016-2019 Kike Pérez

  Unit        : Quick.Core.Mvc.Middleware.Hsts
  Description : Core Mvc Hsts Middleware
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 18/10/2019
  Modified    : 18/10/2019

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

unit Quick.Core.Mvc.Middleware.Hsts;

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
  THstsMiddleware = class(TRequestDelegate)
  private
    fMaxAge : Integer;
  public
    constructor Create(aNext: TRequestDelegate; aMaxAge : Integer);
    destructor Destroy; override;
    procedure Invoke(aContext : THttpContextBase); override;
  end;

implementation

{ THstsMiddleware }

constructor THstsMiddleware.Create(aNext: TRequestDelegate; aMaxAge : Integer);
begin
  inherited Create(aNext);
  fMaxAge := aMaxAge;
end;

destructor THstsMiddleware.Destroy;
begin

  inherited;
end;

procedure THstsMiddleware.Invoke(aContext: THttpContextBase);
begin
  inherited;
  aContext.Response.Headers.AddOrUpdate('Strict-Transport-Security','max-age=max-age=' + fMaxAge.ToString);
  Next(aContext);
end;

end.

