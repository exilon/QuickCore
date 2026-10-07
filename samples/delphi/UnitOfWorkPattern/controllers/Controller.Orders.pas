unit Controller.Orders;

{ UnitOfWorkPattern Sample - S-22 }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Service.Order,
  Models;

type
  [Route('api/orders')]
  [ApiController]
  TOrdersController = class(THttpController)
  private
    fService : IOrderService;
  public
    constructor Create(aService : IOrderService);
  published
    [HttpGet]
    function List : IActionResult;

    [HttpPost]
    function Place([FromBody] req : TPlaceOrderRequest) : IActionResult;
  end;

implementation

uses
  System.SysUtils,
  Quick.Core.Entity;

{ TOrdersController }

constructor TOrdersController.Create(aService : IOrderService);
begin
  inherited Create;
  fService := aService;
end;

function TOrdersController.List: IActionResult;
var
  list : TObject;
begin
  list := fService.GetAll;
  try
    Result := Json(list);
  finally
    list.Free;
  end;
end;

function TOrdersController.Place(req : TPlaceOrderRequest): IActionResult;
var
  newId : TAutoID;
begin
  try
    newId  := fService.PlaceOrder(req);
    Result := StatusCode(201,
      Format('{"orderId":%d,"message":"Order placed successfully"}', [newId]));
  except
    on E: Exception do
      Result := StatusCode(500,
        Format('{"error":"%s"}', [E.Message]));
  end;
end;

initialization
  RegisterController(TOrdersController);

end.
