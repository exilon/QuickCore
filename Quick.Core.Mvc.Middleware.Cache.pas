{ ***************************************************************************

  Copyright (c) 2016-2019 Kike Pérez

  Unit        : Quick.Core.Mvc.Middleware.Cache
  Description : Core Mvc Cache Middleware
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

unit Quick.Core.Mvc.Middleware.Cache;

{$i QuickCore.inc}

interface

uses
  Classes,
  System.SysUtils,
  System.Generics.Collections,
  Quick.Commons,
  Quick.Core.Caching.Abstractions,
  Quick.HttpServer.Types,
  Quick.HttpServer.Request,
  Quick.Core.Mvc.Middleware,
  Quick.Core.Mvc.Context,
  Quick.Core.Mvc.Routing;

type
  TResponseCacheItem = class
  private
    fHeaders : TArray<TPairItem>;
    fContentText : string;
    fContentType : string;
  public
    property Headers : TArray<TPairItem> read fHeaders write fHeaders;
    property ContentText : string read fContentText write fContentText;
    property ContentType : string read fContentType write fContentType;
  end;

  TCacheMiddleware = class(TRequestDelegate)
  private
    fCacheService : IDistributedCache;
    function GetResponseFromCache(aContext : THttpContextBase) : Boolean;
    function SaveResponseToCache(aContext: THttpContextBase; aDurationMS : Integer): Boolean;
  public
    constructor Create(aNext: TRequestDelegate; aCacheService : IDistributedCache);
    destructor Destroy; override;
    procedure Invoke(aContext : THttpContextBase); override;
  end;

implementation

{ TCacheMiddleware }

constructor TCacheMiddleware.Create(aNext: TRequestDelegate; aCacheService : IDistributedCache);
begin
  inherited Create(aNext);
  fCacheService := aCacheService;
end;

destructor TCacheMiddleware.Destroy;
begin

  inherited;
end;

function TCacheMiddleware.GetResponseFromCache(aContext: THttpContextBase): Boolean;
var
  cacheitem : TResponseCacheItem;
begin
  cacheitem := TResponseCacheItem.Create;
  try
    Result := fCacheService.TryGetValue(aContext.Request.URL,cacheitem);
    if Result then
    begin
      aContext.Response.Headers.FromArray(cacheitem.Headers);
      aContext.Response.ContentText := cacheitem.ContentText;
      aContext.Response.ContentType := cacheitem.ContentType;
      aContext.Response.Headers.AddOrUpdate('Cache','HIT');
    end;
  finally
    cacheitem.Free;
  end;
end;

function TCacheMiddleware.SaveResponseToCache(aContext: THttpContextBase; aDurationMS : Integer): Boolean;
var
  cacheitem : TResponseCacheItem;
begin
  cacheitem := TResponseCacheItem.Create;
  try
    cacheitem.Headers := aContext.Response.Headers.ToArray;
    cacheitem.ContentText := aContext.Response.ContentText;
    cacheitem.ContentType := aContext.Response.ContentType;
    fCacheService.SetValue(aContext.Request.URL,cacheitem,aDurationMS);
  finally
    cacheitem.Free;
  end;
end;

procedure TCacheMiddleware.Invoke(aContext: THttpContextBase);
begin
  inherited;
  //get from cache if exists
  if not GetResponseFromCache(aContext) then
  begin
    Next(aContext);
    //save to cache if cache control not private
    if (aContext.Route <> nil) and (aContext.Route.OutputCache > 0) and (aContext.Response.StatusCode < 400) then SaveResponseToCache(aContext,aContext.Route.OutputCache);
  end;
end;

end.
