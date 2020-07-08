unit Controller.Products;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Quick.HttpServer.Types,
  Quick.Collections,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Entity,
  Infra.Data.DBContext.Shop,
  Infra.Data.Models.Product,
  Quick.Core.Mapping.Abstractions;

type
  [Route('Product')]
  [Authorize('Admin')]
  TProductsController = class(THttpController)
  private
    fdbcontext : TShopContext;
  public
    constructor Create(dbcontext : TShopContext);
  published
    [HttpGet('Add/{productname}/{price}')]
    function Add(const ProductName : string; Price : Integer): IActionResult;
    [HttpGet]
    function GetAll : IActionResult;
    [HttpPost]
    function Post([FromBody] aProduct : TDBProduct) : IActionResult;
    [HttpGet('{id}')]
    function GetById(id : Integer) : IActionResult;
  end;

implementation

{ TProductsController }

constructor TProductsController.Create(dbcontext : TShopContext);
begin
  fdbcontext := dbcontext;
end;

function TProductsController.GetById(id: Integer): IActionResult;
var
  dbproduct : TDBProduct;
begin
  dbproduct := fdbcontext.Products.Where('Id=?',[id]).SelectFirst;
  try
    Result := Json(dbproduct,True);
  finally
    dbproduct.Free;
  end;
end;

function TProductsController.Post(aProduct: TDBProduct): IActionResult;
begin
  fdbcontext.Products.AddOrUpdate(aProduct);
  aProduct.Free;
  Result := Content('Record added to database');
end;

function TProductsController.Add(const ProductName : string; Price : Integer): IActionResult;
var
  product : TDBProduct;
begin
  product := TDBProduct.Create;
  try
    product.Name := ProductName;
    product.Price := Price;
    fdbcontext.Products.Add(product);
  finally
    product.Free;
  end;
  Result := Content('Record added to database');
end;

function TProductsController.GetAll: IActionResult;
var
  products : TObjectList<TDBProduct>;
begin
  products := TObjectList<TDBProduct>.Create(True);
  try
    fdbcontext.Products.Select.ToObjectList(products);
    Result := Json(products,True);
  finally
    products.Free;
  end;
end;

initialization
  RegisterController(TProductsController);

end.
