{ ***************************************************************************

  Copyright (c) 2016-2021 Kike Pérez

  Unit        : Quick.Core.Caching.Redis
  Description : Core Caching Redis
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 24/02/2020
  Modified    : 17/05/2021

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

unit Quick.Core.Extensions.Caching.Redis;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.DateUtils,
  Quick.Commons,
  Quick.Options,
  Quick.Pooling,
  Quick.Data.Redis,
  Quick.Core.DependencyInjection,
  Quick.Core.Caching.Abstractions,
  Quick.Core.Serialization.Abstractions,
  Quick.Core.Serialization;

type

  TRedisCacheOptions = class(TOptions)
  private
    fPoolSize : Integer;
    fHost : string;
    fPort : Integer;
    fPassword : string;
    fDatabaseNumber : Integer;
    fConnectionTimeout: Integer;
    fReadTimeout: Integer;
    fMaxSize: Integer;
  public
    constructor Create; override;
  published
    property PoolSize : Integer read fPoolSize write fPoolSize;
    property Host : string read fHost write fHost;
    property Port : Integer read fPort write fPort;
    property Password : string read fPassword write fPassword;
    property DatabaseNumber : Integer read fDatabaseNumber write fDatabaseNumber;
    property MaxSize : Integer read fMaxSize write fMaxSize;
    property ConnectionTimeout : Integer read fConnectionTimeout write fConnectionTimeout;
    property ReadTimeout : Integer read fReadTimeout write fReadTimeout;
  end;

  TRedisCacheServiceExtension = class(TServiceCollectionExtension)
    class function AddDistributedRedisCache(aConfigureOptions : TConfigureOptionsProc<TRedisCacheOptions> = nil) : TServiceCollection;
  end;

  TRedisDistributedCache = class(TInterfacedObject,IDistributedCache)
  private
    fRedisPool : TObjectPool<TRedisClient>;
    fSerializer : ISerializers;
    fOptions : TRedisCacheOptions;
    fOwnsOptions : Boolean;
  public
    constructor Create(aOptions : TRedisCacheOptions; aOwnsOptions : Boolean = True);
    destructor Destroy; override;
    procedure SetValue(const aKey : string; aValue : TObject; aExpirationMilliseconds : Integer = 0); overload;
    procedure SetValue(const aKey : string; aValue : TObject; aExpirationDate : TDateTime); overload;
    procedure SetValue(const aKey, aValue : string; aExpirationMilliseconds : Integer = 0); overload;
    procedure SetValue(const aKey, aValue : string; aExpirationDate : TDateTime); overload;
    procedure SetValue(const aKey : string; aValue : TArray<string>; aExpirationMilliseconds : Integer = 0); overload;
    procedure SetValue(const aKey : string; aValue : TArray<string>; aExpirationDate : TDateTime); overload;
    procedure SetValue(const aKey : string; aValue : TArray<TObject>; aExpirationMilliseconds : Integer = 0); overload;
    procedure SetValue(const aKey : string; aValue : TArray<TObject>; aExpirationDate : TDateTime); overload;
    function GetValue(const aKey : string) : string; overload;
    function TryGetValue(const aKey : string; aValue : TObject) : Boolean; overload;
    function TryGetValue(const aKey : string; out oValue : string) : Boolean; overload;
    function TryGetValue(const aKey : string; out oValue : TArray<string>) : Boolean; overload;
    function TryGetValue(const aKey : string; out oValue : TArray<TObject>) : Boolean; overload;
    procedure Refresh(const aKey: string; aExpirationMilliseconds : Integer);
    procedure RemoveValue(const aKey : string);
    procedure Flush;
  end;

  ERedisOptionsError = class(Exception);

implementation

{ TRedisDistributedCache }

constructor TRedisDistributedCache.Create(aOptions : TRedisCacheOptions; aOwnsOptions : Boolean = True);
begin
  if aOptions = nil then raise ERedisOptionsError.Create('Redis options not defined');
  fOptions := aOptions;
  fOwnsOptions := aOwnsOptions;
  fRedisPool := TObjectPool<TRedisClient>.Create(fOptions.PoolSize,30000,procedure(var aRedis : TRedisClient)
      begin
        aRedis := TRedisClient.Create;
        aRedis.Host := fOptions.Host;
        aRedis.Port := fOptions.Port;
        aRedis.Password := fOptions.Password;
        aRedis.DataBaseNumber := fOptions.DatabaseNumber;
        aRedis.MaxSize := fOptions.MaxSize;
        aRedis.ConnectionTimeout := fOptions.ConnectionTimeout;
        aRedis.ReadTimeout := fOptions.ReadTimeout;
        aRedis.Connect;
      end);
  fSerializer := TSerializers.Create;
end;

destructor TRedisDistributedCache.Destroy;
begin
  if Assigned(fRedisPool) then fRedisPool.Free;
  if (fOwnsOptions) and (Assigned(fOptions)) then fOptions.Free;
  inherited;
end;

procedure TRedisDistributedCache.Flush;
begin
  //fRedisPool.Get.Item.RedisLTRIM(fOptions.fInstanceName,0,fOptions.MaxSize);
end;

function TRedisDistributedCache.GetValue(const aKey: string): string;
begin
  TryGetValue(aKey,Result);
end;

procedure TRedisDistributedCache.Refresh(const aKey: string; aExpirationMilliseconds : Integer);
begin
  fRedisPool.Get.Item.RedisExpire(aKey,aExpirationMilliseconds);
end;

procedure TRedisDistributedCache.RemoveValue(const aKey: string);
begin
  fRedisPool.Get.Item.RedisDEL(aKey);
end;

procedure TRedisDistributedCache.SetValue(const aKey, aValue: string; aExpirationMilliseconds: Integer);
begin
  fRedisPool.Get.Item.RedisSET(aKey,aValue,aExpirationMilliseconds);
end;

procedure TRedisDistributedCache.SetValue(const aKey, aValue: string; aExpirationDate: TDateTime);
begin
  SetValue(aKey,aValue,MilliSecondsBetween(Now(),aExpirationDate));
end;

procedure TRedisDistributedCache.SetValue(const aKey: string; aValue: TObject; aExpirationMilliseconds: Integer);
begin
  SetValue(aKey,fSerializer.Json.FromObject(aValue),aExpirationMilliseconds);
end;

procedure TRedisDistributedCache.SetValue(const aKey: string; aValue: TObject; aExpirationDate: TDateTime);
begin
  SetValue(aKey,aValue,MilliSecondsBetween(Now(),aExpirationDate));
end;

procedure TRedisDistributedCache.SetValue(const aKey: string; aValue: TArray<TObject>; aExpirationMilliseconds: Integer);
begin
  SetValue(aKey,fSerializer.Json.FromArray<TObject>(aValue),aExpirationMilliseconds);
end;

procedure TRedisDistributedCache.SetValue(const aKey: string; aValue: TArray<TObject>; aExpirationDate: TDateTime);
begin
  SetValue(aKey,aValue,MilliSecondsBetween(Now(),aExpirationDate));
end;

procedure TRedisDistributedCache.SetValue(const aKey: string; aValue: TArray<string>; aExpirationMilliseconds: Integer);
begin
  SetValue(aKey,fSerializer.Json.FromArray<string>(aValue),aExpirationMilliseconds);
end;

procedure TRedisDistributedCache.SetValue(const aKey: string; aValue: TArray<string>; aExpirationDate: TDateTime);
begin
  SetValue(aKey,aValue,MilliSecondsBetween(Now(),aExpirationDate));
end;

function TRedisDistributedCache.TryGetValue(const aKey: string; out oValue: TArray<TObject>): Boolean;
var
  json : string;
begin
  Result := TryGetValue(aKey,json);
  if Result then oValue := fSerializer.Json.ToArray<TObject>(json);
end;

function TRedisDistributedCache.TryGetValue(const aKey: string; out oValue: TArray<string>): Boolean;
var
  json : string;
begin
  Result := TryGetValue(aKey,json);
  if Result then oValue := fSerializer.Json.ToArray<string>(json);
end;

function TRedisDistributedCache.TryGetValue(const aKey: string; out oValue: string): Boolean;
begin
  Result := fRedisPool.Get.Item.RedisGET(aKey,oValue);
end;

function TRedisDistributedCache.TryGetValue(const aKey: string; aValue: TObject): Boolean;
var
  json : string;
begin
  Result := TryGetValue(aKey,json);
  if Result then fSerializer.Json.ToObject(aValue,json);
end;

{ TRedisCacheServiceExtension }

class function TRedisCacheServiceExtension.AddDistributedRedisCache(aConfigureOptions : TConfigureOptionsProc<TRedisCacheOptions> = nil) : TServiceCollection;
var
  options : TRedisCacheOptions;
begin
  Result := ServiceCollection;
  options := nil;
  if not Result.IsRegistered<IDistributedCache,TRedisDistributedCache> then
  begin
    if Assigned(aConfigureOptions) then
    begin
      options := TRedisCacheOptions.Create;
      aConfigureOptions(options);
    end;
    Result.AddSingleton<IDistributedCache>(TRedisDistributedCache.Create(options,True));
  end;
end;

{ TRedisCacheOptions }

constructor TRedisCacheOptions.Create;
begin
  inherited;
  fPoolSize := 30;
  fHost := '127.0.0.1';
  fPort := 6379;
  fPassword := '';
  fDatabaseNumber := 0;
  fMaxSize := 0;
  fConnectionTimeout := 30000;
  fReadTimeout := 30000;
end;

end.
