{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Mvc.Extensions.ResponseCaching
  Description : Core MVC Extensions Response Caching
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 19/10/2019
  Modified    : 25/01/2020

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

unit Quick.Core.Mvc.Extensions.ResponseCaching;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Core.DependencyInjection,
  Quick.Core.Mvc.Middleware,
  Quick.Core.MVC,
  Quick.Core.Caching.Abstractions,
  Quick.Core.Extensions.Caching.Memory,
  Quick.Core.Mvc.Middleware.Cache;

type
  TResponseCachingServiceExtension = class(TServiceCollectionExtension)
    class function AddResponseCaching : TServiceCollection;
    class function AddCustomResponseCaching(aCache : IDistributedCache) : TServiceCollection;
  end;

  TResponseCachingMVCServerExtension = class(TMVCServerExtension)
    class function UseResponseCaching : TMVCServer;
  end;

implementation

{ TResponseCachingServiceExtension }

class function TResponseCachingServiceExtension.AddResponseCaching : TServiceCollection;
begin
  Result := ServiceCollection;
  if not Result.IsRegistered<IDistributedCache> then
  begin
    Result.AddSingleton<IDistributedCache>(TMemoryDistributedCache.Create);
  end;
end;

class function TResponseCachingServiceExtension.AddCustomResponseCaching(aCache: IDistributedCache): TServiceCollection;
begin
  Result := ServiceCollection;
  Result.AddSingleton<IDistributedCache>(aCache);
end;

{ TResponseCachingMVCServerExtension }

class function TResponseCachingMVCServerExtension.UseResponseCaching: TMVCServer;
var
  middleware : TRequestDelegate;
begin
  Result := MVCServer;
  //use first IDistributedCache found or create default DistributedMemoryCache
  if MVCServer.Services.IsRegistered<IDistributedCache> then
  begin
    middleware := TCacheMiddleware.Create(nil,MVCServer.Services.Resolve<IDistributedCache>);
    MVCServer.UseMiddleware(middleware);
  end
  else
  begin
    raise Exception.Create('ResponseCaching dependency not found. Need to be added before!');
  end;
end;

end.
