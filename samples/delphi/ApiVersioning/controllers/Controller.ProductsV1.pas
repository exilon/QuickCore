unit Controller.ProductsV1;

{ ApiVersioning Sample - S-30
  Version 1 of the Products API. Returns minimal product data. }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult;

type
  [Route('api/v1/products')]
  [ApiController]
  [ApiVersion('1.0')]
  TProductsV1Controller = class(THttpController)
  public
    constructor Create;
  published
    [HttpGet]
    function GetAll : IActionResult;

    [HttpGet('{id}')]
    function GetById(id : Integer) : IActionResult;
  end;

implementation

uses
  System.SysUtils;

{ TProductsV1Controller }

constructor TProductsV1Controller.Create;
begin
  inherited Create;
end;

function TProductsV1Controller.GetAll : IActionResult;
begin
  // v1: returns basic fields only
  Result := Json(
    '{"version":"1.0","products":[' +
    '{"id":1,"name":"Laptop"},' +
    '{"id":2,"name":"Keyboard"},' +
    '{"id":3,"name":"Monitor"}' +
    ']}');
end;

function TProductsV1Controller.GetById(id : Integer) : IActionResult;
begin
  case id of
    1 : Result := Json('{"version":"1.0","id":1,"name":"Laptop"}');
    2 : Result := Json('{"version":"1.0","id":2,"name":"Keyboard"}');
    3 : Result := Json('{"version":"1.0","id":3,"name":"Monitor"}');
  else
    Result := NotFound;
  end;
end;

initialization
  RegisterController(TProductsV1Controller);

end.
