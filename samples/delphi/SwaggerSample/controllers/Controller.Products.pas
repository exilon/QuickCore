unit Controller.Products;

{ SwaggerSample — S-25
  Full Products CRUD decorated with [SwaggerOperation] and [ProducesResponseType]
  so the generated OpenAPI document is rich and readable in Swagger UI. }

interface

uses
  System.SysUtils,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Mvc.Middleware.Swagger,
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
    // GET /api/products
    [HttpGet]
    [SwaggerOperation('List all products', 'Returns the full in-memory product catalogue.', 'Products')]
    [ProducesResponseType(200, 'Array of TProduct')]
    function GetAll : IActionResult;

    // GET /api/products/{id}
    [HttpGet('{id:int}')]
    [SwaggerOperation('Get product by ID', 'Returns a single product by its integer ID.', 'Products')]
    [ProducesResponseType(200, 'TProduct')]
    [ProducesResponseType(404, 'Product not found')]
    function GetById(id : Integer) : IActionResult;

    // POST /api/products
    [HttpPost]
    [SwaggerOperation('Create product', 'Adds a new product to the catalogue.', 'Products')]
    [ProducesResponseType(201, 'Created TProduct')]
    [ProducesResponseType(400, 'Validation error')]
    function CreateProduct([FromBody] dto : TNewProduct) : IActionResult;

    // PUT /api/products/{id}
    [HttpPut('{id:int}')]
    [SwaggerOperation('Update product', 'Replaces an existing product''s data.', 'Products')]
    [ProducesResponseType(200, 'Updated TProduct')]
    [ProducesResponseType(404, 'Product not found')]
    function Update(id : Integer; [FromBody] dto : TNewProduct) : IActionResult;

    // DELETE /api/products/{id}
    [HttpDelete('{id:int}')]
    [SwaggerOperation('Delete product', 'Removes a product from the catalogue.', 'Products')]
    [ProducesResponseType(204, 'Deleted')]
    [ProducesResponseType(404, 'Product not found')]
    function DeleteProduct(id : Integer) : IActionResult;
  end;

implementation

uses
  Quick.Json.Serializer;

{ TProductsController }

constructor TProductsController.Create(aService : IProductService);
begin
  inherited Create;
  fService := aService;
end;

function TProductsController.GetAll: IActionResult;
var
  i          : Integer;
  products   : TArray<TProduct>;
  serializer : TJsonSerializer;
  sb         : TStringBuilder;
begin
  products   := fService.GetAll;
  serializer := TJsonSerializer.Create(TSerializeLevel.slPublishedProperty);
  sb         := TStringBuilder.Create;
  try
    sb.Append('[');
    for i := 0 to High(products) do
    begin
      if i > 0 then sb.Append(',');
      sb.Append(serializer.ObjectToJson(products[i]));
    end;
    sb.Append(']');
    Result := Json(sb.ToString);
  finally
    sb.Free;
    serializer.Free;
  end;
end;

function TProductsController.GetById(id: Integer): IActionResult;
var
  product : TProduct;
  serializer : TJsonSerializer;
begin
  product := fService.GetById(id);
  if product = nil then
    Result := NotFound(Format('Product %d not found', [id]))
  else
  begin
    serializer := TJsonSerializer.Create(TSerializeLevel.slPublishedProperty);
    try
      Result := Json(serializer.ObjectToJson(product));
    finally
      serializer.Free;
    end;
  end;
end;

function TProductsController.CreateProduct([FromBody] dto: TNewProduct): IActionResult;
var
  product : TProduct;
  serializer : TJsonSerializer;
begin
  if dto = nil then
  begin
    Result := BadRequest('Request body is required');
    Exit;
  end;
  if dto.Name.IsEmpty then
  begin
    Result := BadRequest('Name is required');
    Exit;
  end;
  product := fService.Add(dto);
  serializer := TJsonSerializer.Create(TSerializeLevel.slPublishedProperty);
  try
    Response.StatusCode := 201;
    Result := Json(serializer.ObjectToJson(product));
  finally
    serializer.Free;
  end;
end;

function TProductsController.Update(id: Integer; [FromBody] dto: TNewProduct): IActionResult;
var
  product : TProduct;
  serializer : TJsonSerializer;
begin
  if dto = nil then
  begin
    Result := BadRequest('Request body is required');
    Exit;
  end;
  product := fService.Update(id, dto);
  if product = nil then
    Result := NotFound(Format('Product %d not found', [id]))
  else
  begin
    serializer := TJsonSerializer.Create(TSerializeLevel.slPublishedProperty);
    try
      Result := Json(serializer.ObjectToJson(product));
    finally
      serializer.Free;
    end;
  end;
end;

function TProductsController.DeleteProduct(id: Integer): IActionResult;
var
  product : TProduct;
begin
  product := fService.GetById(id);
  if product = nil then
    Result := NotFound(Format('Product %d not found', [id]))
  else
  begin
    fService.Delete(id);
    Result := StatusCode(204);
  end;
end;

initialization
  RegisterController(TProductsController);

end.
