unit Controller.Products;

{ DecoratorPattern Sample - S-23
  The controller only knows about IProductService — it has no idea whether
  the caching decorator or the real service is being used. }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Logging.Abstractions,
  Service.Product;

type
  [Route('api/products')]
  [ApiController]
  TProductsController = class(THttpController)
  private
    fService : IProductService;
    fLogger  : ILogger;
    class function ProductToJson (const p   : TProduct)        : string;
    class function ProductsToJson(const arr : TArray<TProduct>) : string;
  public
    constructor Create(aService : IProductService; aLogger : ILogger);
  published
    [HttpGet]
    function List : IActionResult;

    [HttpGet('{id}')]
    function GetById(id : Integer) : IActionResult;

    // Flush the whole-list cache to force a fresh fetch on next GET
    [HttpDelete('cache')]
    function Invalidate : IActionResult;
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils,
  System.JSON;

{ TProductsController }

constructor TProductsController.Create(aService : IProductService; aLogger : ILogger);
begin
  inherited Create;
  fService := aService;
  fLogger  := aLogger;
end;

class function TProductsController.ProductToJson(const p: TProduct): string;
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

class function TProductsController.ProductsToJson(const arr: TArray<TProduct>): string;
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

function TProductsController.List: IActionResult;
var
  products : TArray<TProduct>;
  t0       : TDateTime;
begin
  t0       := Now;
  products := fService.GetAll;
  fLogger.Info('GET /api/products took %d ms', [MilliSecondsBetween(Now, t0)]);
  Result   := Json(ProductsToJson(products));
end;

function TProductsController.GetById(id : Integer): IActionResult;
begin
  try
    Result := Json(ProductToJson(fService.GetById(id)));
  except
    on E: EArgumentOutOfRangeException do
      Result := NotFound;
  end;
end;

function TProductsController.Invalidate: IActionResult;
begin
  fService.InvalidateAll;
  Result := Json('{"message":"Cache cleared"}');
end;

initialization
  RegisterController(TProductsController);

end.
