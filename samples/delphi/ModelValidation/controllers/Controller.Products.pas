unit Controller.Products;

(* ModelValidation Sample - S-34
  Demonstrates automatic model validation using attribute-decorated DTOs.

  POST /api/products - validates request body via TModelValidator.
    Valid body:
      Name=Laptop, Price=999.99, Stock=5, ContactEmail=shop@example.com
    Invalid body (missing Name, negative Price):
      Price=-1, Stock=50000
    Returns 400 + JSON with per-field errors when invalid. *)

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Models;

type
  [Route('api/products')]
  [ApiController]
  TProductsController = class(THttpController)
  public
    constructor Create;
  published
    [HttpPost]
    function Create_([FromBody] aRequest : TCreateProductRequest) : IActionResult;

    [HttpGet('validation-rules')]
    function GetRules : IActionResult;
  end;

implementation

uses
  System.SysUtils,
  Quick.Core.Mvc.ModelValidation;

{ TProductsController }

constructor TProductsController.Create;
begin
  inherited Create;
end;

function TProductsController.Create_(aRequest : TCreateProductRequest) : IActionResult;
var
  state : TModelState;
begin
  if aRequest = nil then
    Exit(BadRequest('{"error":"Request body is required"}'));

  state := TModelValidator.Validate(aRequest);
  try
    if not state.IsValid then
      Exit(BadRequest(state.ToJsonString));

    // Model is valid — simulate saving and return 201
    Result := StatusCode(201,
      Format('{"success":true,"product":{"name":"%s","price":%.2f,"stock":%d}}',
        [aRequest.Name, aRequest.Price, aRequest.Stock]));
  finally
    state.Free;
  end;
end;

function TProductsController.GetRules : IActionResult;
begin
  Result := Json(
    '{"rules":{'  +
    '"Name":["Required","StringLength(3..100)"],' +
    '"Price":["Required","Range(0.01..999999.99)"],' +
    '"Stock":["Range(0..10000)"],' +
    '"ContactEmail":["EmailAddress"]' +
    '}}');
end;

initialization
  RegisterController(TProductsController);

end.
