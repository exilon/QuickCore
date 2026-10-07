{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Extensions.Caching.Hybrid
  Description : DI extensions — AddHybridCache
  Author      : Kike Perez
  Version     : 1.0
  Created     : 30/04/2026
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

unit Quick.Core.Extensions.Caching.Hybrid;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Core.DependencyInjection,
  Quick.Core.Caching.Abstractions,
  Quick.Core.Caching.Hybrid,
  Quick.Core.Extensions.Caching.Memory;

type

  TConfigureHybridCacheOptionsProc = reference to procedure(aOptions: THybridCacheOptions);

  /// <summary>
  /// DI extension for IHybridCache.
  ///
  /// Usage (in ConfigureServices):
  ///
  ///   // Minimal — L1 only (no distributed cache):
  ///   services.Extension&lt;THybridCacheServiceExtension&gt;
  ///     .AddHybridCache;
  ///
  ///   // With options:
  ///   services.Extension&lt;THybridCacheServiceExtension&gt;
  ///     .AddHybridCache(procedure(o: THybridCacheOptions)
  ///       begin
  ///         o.DefaultLocalExpirationMs  := 60_000;   // 1 min L1
  ///         o.DefaultRemoteExpirationMs := 600_000;  // 10 min L2
  ///       end);
  ///
  ///   // Prerequisite: register IMemoryCache before calling AddHybridCache.
  ///   //   services.Extension&lt;TMemoryCacheServiceExtension&gt;.AddMemoryCache;
  ///   // Optionally register IDistributedCache for L2:
  ///   //   services.Extension&lt;TRedisCacheServiceExtension&gt;.AddRedisCache(...);
  ///
  /// Then inject:
  ///   hybridCache := services.GetService&lt;IHybridCache&gt;;
  ///
  /// .NET equivalent:
  ///   builder.Services.AddHybridCache(o => { o.DefaultEntryOptions = ...; });
  /// </summary>
  THybridCacheServiceExtension = class(TServiceCollectionExtension)
  public
    /// <summary>
    /// Registers IHybridCache as a singleton.
    /// Requires IMemoryCache to already be registered.
    /// If IDistributedCache is registered it is used as L2; otherwise L2 is skipped.
    /// </summary>
    class function AddHybridCache(
      aConfigureOptions: TConfigureHybridCacheOptionsProc = nil): TServiceCollection;
  end;

implementation

{ THybridCacheServiceExtension }

class function THybridCacheServiceExtension.AddHybridCache(
  aConfigureOptions: TConfigureHybridCacheOptionsProc = nil): TServiceCollection;
var
  options: THybridCacheOptions;
begin
  options := THybridCacheOptions.Create;
  if Assigned(aConfigureOptions) then
    aConfigureOptions(options);

  var l1 := ServiceCollection.Resolve<IMemoryCache>;
  var l2 : IDistributedCache := nil;
  if ServiceCollection.IsRegistered<IDistributedCache> then
    l2 := ServiceCollection.Resolve<IDistributedCache>;

  ServiceCollection.AddSingleton<IHybridCache>(
    THybridCache.Create(l1, l2, options) as IHybridCache
  );

  Result := ServiceCollection;
end;

end.
