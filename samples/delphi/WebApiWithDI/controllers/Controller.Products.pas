unit Controller.Products;

{ WebApiWithDI Sample - S-06
  REST controller for products. IProductService is injected via DI. }

interface

uses
  System.SysUtils,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Service.Product;

type
  [Route('api/products')]
  [ApiController]
  TProductsController = class(THttpController)
  private
    fProductSvc : IProductService;
  public
    constructor Create(aProductSvc : IProductService);
  published
    /// GET /api/products
    [HttpGet]
    function GetAll : IActionResult;

    /// GET /api/products/{id}
    [HttpGet('{id}')]
    function GetById(id : Integer) : IActionResult;

    /// POST /api/products  body: {"Name":"...","Category":"...","Price":0.0}
    [HttpPost]
    function Post_([FromBody] body : string) : IActionResult;

    /// DELETE /api/products/{id}
    [HttpDelete('{id}')]
    function Delete(id : Integer) : IActionResult;
  end;

implementation

{ TProductsController }

constructor TProductsController.Create(aProductSvc: IProductService);
begin
  inherited Create;
  fProductSvc := aProductSvc;
end;

function TProductsController.GetAll: IActionResult;
var
  items : TArray<TProductItem>;
  sb    : TStringBuilder;
  i     : Integer;
begin
  items := fProductSvc.GetAll;
  sb := TStringBuilder.Create;
  try
    sb.Append('[');
    for i := 0 to High(items) do
    begin
      if i > 0 then sb.Append(',');
      sb.AppendFormat('{"Id":%d,"Name":"%s","Category":"%s","Price":%g}',
        [items[i].Id, items[i].Name, items[i].Category, items[i].Price]);
    end;
    sb.Append(']');
    Result := Json(sb.ToString);
  finally
    sb.Free;
  end;
end;

function TProductsController.GetById(id: Integer): IActionResult;
var
  p : TProductItem;
begin
  p := fProductSvc.GetById(id);
  if p.Id = 0 then
    Result := NotFound
  else
    Result := Json(Format('{"Id":%d,"Name":"%s","Category":"%s","Price":%g}',
      [p.Id, p.Name, p.Category, p.Price]));
end;

function TProductsController.Post_(body: string): IActionResult;
var
  p : TProductItem;
begin
  p := fProductSvc.Add('New Product', 'General', 0.0);
  Result := StatusCode(201, Format('{"Id":%d,"Name":"%s","Category":"%s","Price":%g}',
    [p.Id, p.Name, p.Category, p.Price]));
end;

function TProductsController.Delete(id: Integer): IActionResult;
begin
  fProductSvc.Delete(id);
  Result := StatusCode(204);
end;

initialization
  RegisterController(TProductsController);

end.
