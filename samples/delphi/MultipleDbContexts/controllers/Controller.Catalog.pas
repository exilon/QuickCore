unit Controller.Catalog;

{ MultipleDbContexts Sample - S-18
  Uses TCatalogContext (products DB). }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Models;

type
  [Route('api/catalog')]
  [ApiController]
  TCatalogController = class(THttpController)
  private
    fCatalog : TCatalogContext;
  public
    constructor Create(aCatalog : TCatalogContext);
  published
    [HttpGet]
    function GetProducts : IActionResult;

    [HttpPost]
    function AddProduct([FromBody] body : TCatalogProduct) : IActionResult;
  end;

implementation

uses
  System.SysUtils,
  Quick.Core.Entity.DAO;

{ TCatalogController }

constructor TCatalogController.Create(aCatalog : TCatalogContext);
begin
  inherited Create;
  fCatalog := aCatalog;
end;

function TCatalogController.GetProducts: IActionResult;
var
  res  : IEntityResult<TCatalogProduct>;
  arr  : TArray<TCatalogProduct>;
  sb   : TStringBuilder;
  i    : Integer;
  p    : TCatalogProduct;
begin
  res := fCatalog.Products.Where('').Select;
  arr := res.ToArray;
  sb  := TStringBuilder.Create;
  try
    sb.Append('[');
    for i := 0 to High(arr) do
    begin
      if i > 0 then sb.Append(',');
      p := arr[i];
      sb.AppendFormat('{"Id":%d,"Name":"%s","Category":"%s","Price":%g}',
        [p.Id, p.Name, p.Category, p.Price]);
    end;
    sb.Append(']');
    Result := Json(sb.ToString);
  finally
    sb.Free;
  end;
end;

function TCatalogController.AddProduct(body : TCatalogProduct): IActionResult;
begin
  fCatalog.Products.Add(body);
  Result := StatusCode(201, Format('{"Id":%d,"Name":"%s","Category":"%s","Price":%g}',
    [body.Id, body.Name, body.Category, body.Price]));
end;

initialization
  RegisterController(TCatalogController);

end.
