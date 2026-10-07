unit Controller.Products;

{ WebApiWithJwt Sample - S-27
  Products controller — all endpoints require a valid JWT Bearer token.
  Admin-only endpoint uses [AuthorizePolicy]. }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult;

type
  [Route('api/products')]
  [ApiController]
  [Authorize]   // All actions require a valid Bearer token
  TProductsController = class(THttpController)
  public
    constructor Create;
  published
    /// GET /api/products  — any authenticated user
    [HttpGet]
    function GetAll : IActionResult;

    /// GET /api/products/{id}  — any authenticated user
    [HttpGet('{id}')]
    function GetById(id : Integer) : IActionResult;

    /// GET /api/products/admin  — Admin role only
    [HttpGet('admin')]
    [AuthorizePolicy('AdminOnly')]
    function AdminOnly : IActionResult;
  end;

implementation

uses
  System.SysUtils;

const
  PRODUCTS_JSON =
    '[' +
    '{"id":1,"name":"Laptop","price":999.99},' +
    '{"id":2,"name":"Keyboard","price":49.99},' +
    '{"id":3,"name":"Monitor","price":349.99}' +
    ']';

{ TProductsController }

constructor TProductsController.Create;
begin
  inherited Create;
end;

function TProductsController.GetAll : IActionResult;
begin
  Result := Json(PRODUCTS_JSON);
end;

function TProductsController.GetById(id : Integer) : IActionResult;
begin
  case id of
    1 : Result := Json('{"id":1,"name":"Laptop","price":999.99}');
    2 : Result := Json('{"id":2,"name":"Keyboard","price":49.99}');
    3 : Result := Json('{"id":3,"name":"Monitor","price":349.99}');
  else
    Result := NotFound;
  end;
end;

function TProductsController.AdminOnly : IActionResult;
var
  caller : string;
begin
  caller := HttpContext.User.Identity.Name;
  Result := Json(Format('{"message":"Admin panel","caller":"%s","secret":"42"}', [caller]));
end;

initialization
  RegisterController(TProductsController);

end.
