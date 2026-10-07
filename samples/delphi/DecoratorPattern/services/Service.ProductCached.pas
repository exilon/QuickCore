unit Service.ProductCached;

{ DecoratorPattern Sample - S-23
  Caching decorator for IProductService.
  Wraps any IProductService implementation and caches results in IMemoryCache.
  IMemoryCache / ICache stores values as JSON strings (string overloads). }

interface

uses
  System.SysUtils,
  System.JSON,
  Quick.Core.Caching.Abstractions,
  Service.Product;

type
  TCachedProductService = class(TInterfacedObject, IProductService)
  private
    const ALL_CACHE_KEY = 'products:all';
    const ITEM_KEY_FMT  = 'products:%d';
    const TTL_MS        = 60000;  // 60 s in milliseconds
    var
      fInner : IProductService;
      fCache : IMemoryCache;
    class function ProductToJson  (const p   : TProduct)        : string;
    class function JsonToProduct  (const s   : string)          : TProduct;
    class function ProductsToJson (const arr : TArray<TProduct>) : string;
    class function JsonToProducts (const s   : string)          : TArray<TProduct>;
  public
    constructor Create(aInner : IProductService; aCache : IMemoryCache);
    function GetAll    : TArray<TProduct>;
    function GetById(const aId : Integer) : TProduct;
    procedure InvalidateAll;
  end;

implementation

{ Helpers — serialise/deserialise TProduct record via System.JSON }

class function TCachedProductService.ProductToJson(const p: TProduct): string;
var
  obj : TJSONObject;
begin
  obj := TJSONObject.Create;
  try
    obj.AddPair('Id',       TJSONNumber.Create(p.Id));
    obj.AddPair('Name',     p.Name);
    obj.AddPair('Category', p.Category);
    obj.AddPair('Price',    TJSONNumber.Create(p.Price));
    Result := obj.ToJSON;
  finally
    obj.Free;
  end;
end;

class function TCachedProductService.JsonToProduct(const s: string): TProduct;
var
  obj : TJSONObject;
begin
  obj := TJSONObject.ParseJSONValue(s) as TJSONObject;
  if not Assigned(obj) then Exit;
  try
    Result.Id       := (obj.GetValue('Id')       as TJSONNumber).AsInt;
    Result.Name     :=  obj.GetValue('Name').Value;
    Result.Category :=  obj.GetValue('Category').Value;
    Result.Price    := (obj.GetValue('Price')     as TJSONNumber).AsDouble;
  finally
    obj.Free;
  end;
end;

class function TCachedProductService.ProductsToJson(const arr: TArray<TProduct>): string;
var
  jArr : TJSONArray;
  obj  : TJSONObject;
  p    : TProduct;
begin
  jArr := TJSONArray.Create;
  try
    for p in arr do
    begin
      obj := TJSONObject.Create;
      obj.AddPair('Id',       TJSONNumber.Create(p.Id));
      obj.AddPair('Name',     p.Name);
      obj.AddPair('Category', p.Category);
      obj.AddPair('Price',    TJSONNumber.Create(p.Price));
      jArr.AddElement(obj);
    end;
    Result := jArr.ToJSON;
  finally
    jArr.Free;
  end;
end;

class function TCachedProductService.JsonToProducts(const s: string): TArray<TProduct>;
var
  jArr : TJSONArray;
  obj  : TJSONObject;
  p    : TProduct;
  i    : Integer;
begin
  jArr := TJSONObject.ParseJSONValue(s) as TJSONArray;
  if not Assigned(jArr) then Exit;
  try
    SetLength(Result, jArr.Count);
    for i := 0 to jArr.Count - 1 do
    begin
      obj := jArr.Items[i] as TJSONObject;
      p.Id       := (obj.GetValue('Id')       as TJSONNumber).AsInt;
      p.Name     :=  obj.GetValue('Name').Value;
      p.Category :=  obj.GetValue('Category').Value;
      p.Price    := (obj.GetValue('Price')     as TJSONNumber).AsDouble;
      Result[i]  := p;
    end;
  finally
    jArr.Free;
  end;
end;

{ TCachedProductService }

constructor TCachedProductService.Create(aInner : IProductService; aCache : IMemoryCache);
begin
  inherited Create;
  fInner := aInner;
  fCache := aCache;
end;

function TCachedProductService.GetAll: TArray<TProduct>;
var
  json : string;
begin
  if fCache.TryGetValue(ALL_CACHE_KEY, json) then
    Result := JsonToProducts(json)
  else
  begin
    Result := fInner.GetAll;
    fCache.SetValue(ALL_CACHE_KEY, ProductsToJson(Result), TTL_MS);
  end;
end;

function TCachedProductService.GetById(const aId : Integer): TProduct;
var
  key  : string;
  json : string;
begin
  key := Format(ITEM_KEY_FMT, [aId]);
  if fCache.TryGetValue(key, json) then
    Result := JsonToProduct(json)
  else
  begin
    Result := fInner.GetById(aId);
    fCache.SetValue(key, ProductToJson(Result), TTL_MS);
  end;
end;

procedure TCachedProductService.InvalidateAll;
begin
  fCache.RemoveValue(ALL_CACHE_KEY);
end;

end.
