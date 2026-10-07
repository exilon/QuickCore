unit Controller.Products;

{ CleanArchitectureApi Sample - S-15 — Presentation Layer
  Depends only on Application interfaces, not on Infrastructure or Domain directly. }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Application.Service.Product;

type
  TCreateProductBody = class
  private
    FName     : string;
    FCategory : string;
    FPrice    : Double;
  published
    property Name     : string read FName     write FName;
    property Category : string read FCategory write FCategory;
    property Price    : Double read FPrice    write FPrice;
  end;

  [Route('api/products')]
  [ApiController]
  TProductsController = class(THttpController)
  private
    fService : IProductService;
  public
    constructor Create(aService : IProductService);
  published
    [HttpGet]
    function GetAll : IActionResult;

    [HttpGet('{id}')]
    function GetById(id : Integer) : IActionResult;

    [HttpPost]
    function Create_([FromBody] body : TCreateProductBody) : IActionResult;

    [HttpDelete('{id}')]
    function Delete(id : Integer) : IActionResult;
  end;

implementation

uses
  System.SysUtils,
  Quick.JsonSerializer;

{ TProductsController }

constructor TProductsController.Create(aService : IProductService);
begin
  inherited Create;
  fService := aService;
end;

function TProductsController.GetAll: IActionResult;
var
  dtos : TObject;
begin
  dtos := TObject(fService.GetAll);
  try
    Result := Json(TJsonSerializer.Serialize(dtos));
  finally
    dtos.Free;
  end;
end;

function TProductsController.GetById(id : Integer): IActionResult;
var
  dto : TProductDto;
begin
  dto := fService.GetById(id);
  Result := Json(Format('{"id":%d,"name":"%s","category":"%s","price":%g}',
    [dto.Id, dto.Name, dto.Category, dto.Price]));
end;

function TProductsController.Create_(body : TCreateProductBody): IActionResult;
begin
  fService.AddProduct(body.Name, body.Category, body.Price);
  Result := StatusCode(201, '{"created":true}');
end;

function TProductsController.Delete(id : Integer): IActionResult;
begin
  fService.DeleteProduct(id);
  Result := StatusCode(204);
end;

initialization
  RegisterController(TProductsController);

end.
