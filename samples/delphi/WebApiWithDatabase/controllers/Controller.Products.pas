unit Controller.Products;

{ WebApiWithDatabase Sample - S-07
  CRUD controller backed by a SQLite DBContext via DI. }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Models;

type
  [Route('api/products')]
  [ApiController]
  TProductsController = class(THttpController)
  private
    fContext : TShopContext;
  public
    constructor Create(aContext : TShopContext);
  published
    [HttpGet]
    function GetAll : IActionResult;

    [HttpGet('{id}')]
    function GetById(id : Integer) : IActionResult;

    [HttpPost]
    function AddProduct([FromBody] body : TProductEntity) : IActionResult;

    [HttpDelete('{id}')]
    function Delete(id : Integer) : IActionResult;
  end;

implementation

uses
  System.SysUtils,
  Quick.Core.Entity.DAO,
  Quick.JsonSerializer;

{ TProductsController }

constructor TProductsController.Create(aContext : TShopContext);
begin
  inherited Create;
  fContext := aContext;
end;

function TProductsController.GetAll: IActionResult;
var
  res : IEntityResult<TProductEntity>;
  arr : TArray<TProductEntity>;
  sb  : TStringBuilder;
  i   : Integer;
  p   : TProductEntity;
begin
  res := fContext.Products.Where('').Select;
  arr := res.ToArray;
  sb  := TStringBuilder.Create;
  try
    sb.Append('[');
    for i := 0 to High(arr) do
    begin
      if i > 0 then sb.Append(',');
      p := arr[i];
      sb.AppendFormat('{"Id":%d,"Name":"%s","Category":"%s","Price":%g,"Stock":%d}',
        [p.Id, p.Name, p.Category, p.Price, p.Stock]);
    end;
    sb.Append(']');
    Result := Json(sb.ToString);
  finally
    sb.Free;
  end;
end;

function TProductsController.GetById(id: Integer): IActionResult;
var
  p : TProductEntity;
begin
  p := fContext.Products.Where('Id = %d', [id]).SelectFirst;
  if p = nil then
    Result := NotFound
  else
  try
    Result := Json(TJsonSerializer.Serialize(p));
  finally
    p.Free;
  end;
end;

function TProductsController.AddProduct(body : TProductEntity): IActionResult;
begin
  fContext.Products.Add(body);
  Result := StatusCode(201, TJsonSerializer.Serialize(body));
end;

function TProductsController.Delete(id: Integer): IActionResult;
begin
  fContext.Products.Where('Id = %d', [id]).Delete;
  Result := StatusCode(204);
end;

initialization
  RegisterController(TProductsController);

end.
