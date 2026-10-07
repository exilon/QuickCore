unit Controller.Products;

{ RepositoryPattern Sample - S-21 }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Service.Product,
  Models;

type
  [Route('api/products')]
  [ApiController]
  TProductsController = class(THttpController)
  private
    fService : IProductService;
  public
    constructor Create(aService : IProductService);
  published
    [HttpGet]
    function List : IActionResult;

    [HttpGet('{id}')]
    function GetById(id : Integer) : IActionResult;

    [HttpPost]
    function AddProduct([FromBody] product : TProduct) : IActionResult;

    [HttpPut('{id}')]
    function Update(id : Integer; [FromBody] product : TProduct) : IActionResult;

    [HttpDelete('{id}')]
    function Delete(id : Integer) : IActionResult;

    // GET /api/products?maxprice=50.0
    [HttpGet('cheap')]
    function Cheap(maxprice : Double) : IActionResult;

    // GET /api/products/bycategory?category=Electronics
    [HttpGet('bycategory')]
    function ByCategory(category : string) : IActionResult;
  end;

implementation

uses
  System.SysUtils;

{ TProductsController }

constructor TProductsController.Create(aService : IProductService);
begin
  inherited Create;
  fService := aService;
end;

function TProductsController.List: IActionResult;
var
  list : TObject;
begin
  list := fService.GetAll;
  try
    Result := Json(list);
  finally
    list.Free;
  end;
end;

function TProductsController.GetById(id : Integer): IActionResult;
var
  p : TProduct;
begin
  p := fService.GetById(id);
  if p = nil then
    Result := NotFound
  else
    try
      Result := Json(p);
    finally
      p.Free;
    end;
end;

function TProductsController.AddProduct(product : TProduct): IActionResult;
begin
  if fService.Add(product) then
    Result := StatusCode(201, '{"created":true}')
  else
    Result := StatusCode(500, '{"error":"Could not create product"}');
end;

function TProductsController.Update(id : Integer; product : TProduct): IActionResult;
begin
  product.Id := id;
  if fService.Update(product) then
    Result := Json('{"updated":true}')
  else
    Result := NotFound;
end;

function TProductsController.Delete(id : Integer): IActionResult;
begin
  if fService.Delete(id) then
    Result := Json('{"deleted":true}')
  else
    Result := NotFound;
end;

function TProductsController.Cheap(maxprice : Double): IActionResult;
var
  list : TObject;
begin
  list := fService.GetCheap(maxprice);
  try
    Result := Json(list);
  finally
    list.Free;
  end;
end;

function TProductsController.ByCategory(category : string): IActionResult;
var
  list : TObject;
begin
  list := fService.GetByCategory(category);
  try
    Result := Json(list);
  finally
    list.Free;
  end;
end;

initialization
  RegisterController(TProductsController);

end.
