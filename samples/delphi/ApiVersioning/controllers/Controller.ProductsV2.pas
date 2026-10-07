unit Controller.ProductsV2;

{ ApiVersioning Sample - S-30
  Version 2 of the Products API. Returns richer product data with price and stock. }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult;

type
  [Route('api/v2/products')]
  [ApiController]
  [ApiVersion('2.0')]
  TProductsV2Controller = class(THttpController)
  public
    constructor Create;
  published
    [HttpGet]
    function GetAll : IActionResult;

    [HttpGet('{id}')]
    function GetById(id : Integer) : IActionResult;

    /// v2-only: search by name fragment
    [HttpGet('search')]
    function Search([FromQuery] q : string) : IActionResult;
  end;

implementation

uses
  System.SysUtils;

{ TProductsV2Controller }

constructor TProductsV2Controller.Create;
begin
  inherited Create;
end;

function TProductsV2Controller.GetAll : IActionResult;
begin
  // v2: returns price, stock and category too
  Result := Json(
    '{"version":"2.0","products":[' +
    '{"id":1,"name":"Laptop","price":999.99,"stock":5,"category":"Electronics"},' +
    '{"id":2,"name":"Keyboard","price":49.99,"stock":42,"category":"Peripherals"},' +
    '{"id":3,"name":"Monitor","price":349.99,"stock":10,"category":"Electronics"}' +
    ']}');
end;

function TProductsV2Controller.GetById(id : Integer) : IActionResult;
begin
  case id of
    1 : Result := Json('{"version":"2.0","id":1,"name":"Laptop","price":999.99,"stock":5,"category":"Electronics"}');
    2 : Result := Json('{"version":"2.0","id":2,"name":"Keyboard","price":49.99,"stock":42,"category":"Peripherals"}');
    3 : Result := Json('{"version":"2.0","id":3,"name":"Monitor","price":349.99,"stock":10,"category":"Electronics"}');
  else
    Result := NotFound;
  end;
end;

function TProductsV2Controller.Search(q : string) : IActionResult;
begin
  if q.ToLower.Contains('laptop') then
    Result := Json('{"version":"2.0","results":[{"id":1,"name":"Laptop","price":999.99}]}')
  else if q.ToLower.Contains('key') then
    Result := Json('{"version":"2.0","results":[{"id":2,"name":"Keyboard","price":49.99}]}')
  else
    Result := Json('{"version":"2.0","results":[]}');
end;

initialization
  RegisterController(TProductsV2Controller);

end.
