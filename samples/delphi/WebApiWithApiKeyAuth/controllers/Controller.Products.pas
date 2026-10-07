unit Controller.Products;

{ WebApiWithApiKeyAuth Sample - S-13
  Controller demonstrating [Authorize], [AllowAnonymous], and policy-based access. }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Security.Claims;

type
  [Route('api/products')]
  [ApiController]
  [Authorize]   // All actions require authentication by default
  TProductsController = class(THttpController)
  public
    constructor Create;
  published
    // Any authenticated caller (Admin or User)
    [HttpGet]
    function GetAll : IActionResult;

    // Admin only
    [HttpGet('admin')]
    [AuthorizePolicy('AdminOnly')]
    function AdminPanel : IActionResult;

    // No authentication required
    [HttpGet('public')]
    [AllowAnonymous]
    function PublicCatalog : IActionResult;

    // Shows who is calling (their name from claims)
    [HttpGet('me')]
    function WhoAmI : IActionResult;
  end;

implementation

uses
  System.SysUtils;

{ TProductsController }

constructor TProductsController.Create;
begin
  inherited Create;
end;

function TProductsController.GetAll: IActionResult;
begin
  Result := Json('[{"id":1,"name":"Laptop"},{"id":2,"name":"Keyboard"}]');
end;

function TProductsController.AdminPanel: IActionResult;
begin
  Result := Json('{"panel":"Admin Dashboard","secret":"42"}');
end;

function TProductsController.PublicCatalog: IActionResult;
begin
  Result := Json('[{"id":1,"name":"Laptop","publicPrice":999}]');
end;

function TProductsController.WhoAmI: IActionResult;
var
  userName : string;
begin
  userName := HttpContext.User.Identity.Name;
  if userName.IsEmpty then userName := 'anonymous';
  Result := Json(Format('{"user":"%s"}', [userName]));
end;

initialization
  RegisterController(TProductsController);

end.
