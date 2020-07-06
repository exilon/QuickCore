{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Extensions.Caching.Memory
  Description : Core Caching Memory
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 12/10/2019
  Modified    : 26/02/2020

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

unit Quick.Core.Extensions.Caching.Memory;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Options,
  Quick.Core.DependencyInjection,
  Quick.MemoryCache,
  Quick.Core.Caching.Abstractions;

type

  TMemoryCacheOptions = class(TOptions)
  private
    fCompression : Boolean;
    fMaxSize : Integer;
    fPurgerInterval : Integer;
  public
    constructor Create; override;
  published
    property Compression : Boolean read fCompression write fCompression;
    property MaxSize : Integer read fMaxSize write fMaxSize;
    property PurgeInterval : Integer read fPurgerInterval write fPurgerInterval;
  end;

  TMemoryCacheServiceExtension = class(TServiceCollectionExtension)
    class function AddMemoryCache(aConfigureOptions : TConfigureOptionsProc<TMemoryCacheOptions> = nil) : TServiceCollection;
    class function AddDistributedMemoryCache(aConfigureOptions : TConfigureOptionsProc<TMemoryCacheOptions> = nil) : TServiceCollection;
  end;

  THttpMemoryCache = class(TInterfacedObject,IMemoryCache)
  protected
    fMemoryCache : TMemoryCache;
  public
    constructor Create(aOptions : TMemoryCacheOptions = nil);
    destructor Destroy; override;
    function GetCompression: Boolean; inline;
    procedure SetCompression(const Value: Boolean); inline;
    function GetCachedObjects: Integer; inline;
    function GetCacheSize: Integer; inline;
    property Compression : Boolean read GetCompression write SetCompression;
    property CachedObjects : Integer read GetCachedObjects;
    property CacheSize : Integer read GetCacheSize;
    procedure SetValue(const aKey : string; aValue : TObject; aExpirationMilliseconds : Integer = 0); overload; inline;
    procedure SetValue(const aKey : string; aValue : TObject; aExpirationDate : TDateTime); overload; inline;
    procedure SetValue(const aKey, aValue : string; aExpirationMilliseconds : Integer = 0); overload; inline;
    procedure SetValue(const aKey, aValue : string; aExpirationDate : TDateTime); overload; inline;
    procedure SetValue(const aKey : string; aValue : TArray<string>; aExpirationMilliseconds : Integer = 0); overload; inline;
    procedure SetValue(const aKey : string; aValue : TArray<string>; aExpirationDate : TDateTime); overload; inline;
    procedure SetValue(const aKey : string; aValue : TArray<TObject>; aExpirationMilliseconds : Integer = 0); overload; inline;
    procedure SetValue(const aKey : string; aValue : TArray<TObject>; aExpirationDate : TDateTime); overload; inline;
    function GetValue(const aKey : string) : string; overload; inline;
    function TryGetValue(const aKey : string; aValue : TObject) : Boolean; overload; inline;
    function TryGetValue(const aKey : string; out aValue : string) : Boolean; overload; inline;
    function TryGetValue(const aKey : string; out aValue : TArray<string>) : Boolean; overload; inline;
    function TryGetValue(const aKey : string; out aValue : TArray<TObject>) : Boolean; overload; inline;
    procedure RemoveValue(const aKey : string); inline;
    procedure Refresh(const aKey: string; aExpirationMilliseconds : Integer); inline;
    procedure Flush; inline;
  end;

  TMemoryDistributedCache = class(THttpMemoryCache,IDistributedCache);

implementation

{ THttpMemoryCache }

constructor THttpMemoryCache.Create(aOptions : TMemoryCacheOptions = nil);
begin
  if aOptions = nil then fMemoryCache := TMemoryCache.Create(20)
  else
  begin
    fMemoryCache := TMemoryCache.Create(aOptions.PurgeInterval);
    fMemoryCache.Compression := aOptions.Compression;
    fMemoryCache.MaxSize := aOptions.MaxSize;
  end;
end;

destructor THttpMemoryCache.Destroy;
begin
  fMemoryCache.Free;
  inherited;
end;

procedure THttpMemoryCache.Flush;
begin
  fMemoryCache.Flush;
end;

function THttpMemoryCache.GetCachedObjects: Integer;
begin
  Result := fMemoryCache.CachedObjects;
end;

function THttpMemoryCache.GetCacheSize: Integer;
begin
  Result := fMemoryCache.CacheSize;
end;

function THttpMemoryCache.GetCompression: Boolean;
begin
  Result := fMemoryCache.Compression;
end;

function THttpMemoryCache.GetValue(const aKey: string): string;
begin
  Result := fMemoryCache.GetValue(aKey);
end;

procedure THttpMemoryCache.Refresh(const aKey: string; aExpirationMilliseconds : Integer);
begin
  fMemoryCache.Refresh(aKey,aExpirationMilliseconds);
end;

procedure THttpMemoryCache.RemoveValue(const aKey: string);
begin
  fMemoryCache.RemoveValue(aKey);
end;

procedure THttpMemoryCache.SetCompression(const Value: Boolean);
begin
  fMemoryCache.Compression := Value;
end;

procedure THttpMemoryCache.SetValue(const aKey, aValue: string; aExpirationMilliseconds: Integer);
begin
  fMemoryCache.SetValue(aKey,aValue,aExpirationMilliseconds);
end;

procedure THttpMemoryCache.SetValue(const aKey: string; aValue: TObject; aExpirationDate: TDateTime);
begin
  fMemoryCache.SetValue(aKey,aValue,aExpirationDate);
end;

procedure THttpMemoryCache.SetValue(const aKey: string; aValue: TObject; aExpirationMilliseconds: Integer);
begin
  fMemoryCache.SetValue(aKey,aValue,aExpirationMilliseconds);
end;

procedure THttpMemoryCache.SetValue(const aKey, aValue: string; aExpirationDate: TDateTime);
begin
  fMemoryCache.SetValue(aKey,aValue,aExpirationDate);
end;

procedure THttpMemoryCache.SetValue(const aKey: string; aValue: TArray<TObject>; aExpirationMilliseconds: Integer);
begin
  fMemoryCache.SetValue(aKey,aValue,aExpirationMilliseconds);
end;

procedure THttpMemoryCache.SetValue(const aKey: string; aValue: TArray<string>; aExpirationDate: TDateTime);
begin
  fMemoryCache.SetValue(aKey,aValue,aExpirationDate);
end;

procedure THttpMemoryCache.SetValue(const aKey: string; aValue: TArray<string>; aExpirationMilliseconds: Integer);
begin
  fMemoryCache.SetValue(aKey,aValue,aExpirationMilliseconds);
end;

procedure THttpMemoryCache.SetValue(const aKey: string; aValue: TArray<TObject>; aExpirationDate: TDateTime);
begin
  fMemoryCache.SetValue(aKey,aValue,aExpirationDate);
end;

function THttpMemoryCache.TryGetValue(const aKey: string; out aValue: string): Boolean;
begin
  Result := fMemoryCache.TryGetValue(aKey,aValue);
end;

function THttpMemoryCache.TryGetValue(const aKey: string; aValue: TObject): Boolean;
begin
  Result := fMemoryCache.TryGetValue(aKey,aValue);
end;

function THttpMemoryCache.TryGetValue(const aKey: string; out aValue: TArray<TObject>): Boolean;
begin
  Result := fMemoryCache.TryGetValue(aKey,aValue);
end;

function THttpMemoryCache.TryGetValue(const aKey: string; out aValue: TArray<string>): Boolean;
begin
  Result := fMemoryCache.TryGetValue(aKey,aValue);
end;

{ TMemoryCacheServiceExtension }

class function TMemoryCacheServiceExtension.AddMemoryCache(aConfigureOptions : TConfigureOptionsProc<TMemoryCacheOptions> = nil) : TServiceCollection;
var
  options : TMemoryCacheOptions;
begin
  Result := ServiceCollection;
  options := nil;
  try
    if Assigned(aConfigureOptions) then
    begin
      options := TMemoryCacheOptions.Create;
      aConfigureOptions(options);
    end;
    if not Result.IsRegistered<IMemoryCache,THttpMemoryCache> then
    begin
      Result.AddSingleton<IMemoryCache>(THttpMemoryCache.Create(options));
    end;
  finally
    options.Free;
  end;
end;

class function TMemoryCacheServiceExtension.AddDistributedMemoryCache(aConfigureOptions : TConfigureOptionsProc<TMemoryCacheOptions> = nil) : TServiceCollection;
var
  options : TMemoryCacheOptions;
begin
  Result := ServiceCollection;
  options := nil;
  try
    if Assigned(aConfigureOptions) then
    begin
      options := TMemoryCacheOptions.Create;
      aConfigureOptions(options);
    end;
    if not Result.IsRegistered<IDistributedCache,TMemoryDistributedCache> then
    begin
      Result.AddSingleton<IDistributedCache>(TMemoryDistributedCache.Create(options));
    end;
  finally
    options.Free;
  end;
end;

{ TMemoryCacheOptions }

constructor TMemoryCacheOptions.Create;
begin
  inherited;
  fCompression := True;
  fPurgerInterval := 20;
  fMaxSize := 0;
end;

end.
