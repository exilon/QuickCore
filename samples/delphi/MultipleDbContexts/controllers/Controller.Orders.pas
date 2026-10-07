unit Controller.Orders;

{ MultipleDbContexts Sample - S-18
  Uses TOrdersContext (orders DB). }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Models;

type
  TPlaceOrderBody = class
  private
    FProductId   : Integer;
    FProductName : string;
    FQuantity    : Integer;
    FUnitPrice   : Double;
  published
    property ProductId   : Integer read FProductId   write FProductId;
    property ProductName : string  read FProductName write FProductName;
    property Quantity    : Integer read FQuantity    write FQuantity;
    property UnitPrice   : Double  read FUnitPrice   write FUnitPrice;
  end;

  [Route('api/orders')]
  [ApiController]
  TOrdersController = class(THttpController)
  private
    fOrders : TOrdersContext;
  public
    constructor Create(aOrders : TOrdersContext);
  published
    [HttpGet]
    function GetOrders : IActionResult;

    [HttpPost]
    function PlaceOrder([FromBody] body : TPlaceOrderBody) : IActionResult;
  end;

implementation

uses
  System.SysUtils,
  Quick.Core.Entity.DAO,
  Quick.JsonSerializer;

{ TOrdersController }

constructor TOrdersController.Create(aOrders : TOrdersContext);
begin
  inherited Create;
  fOrders := aOrders;
end;

function TOrdersController.GetOrders: IActionResult;
var
  res : IEntityResult<TOrder>;
  arr : TArray<TOrder>;
  sb  : TStringBuilder;
  i   : Integer;
  o   : TOrder;
begin
  res := fOrders.Orders.Where('').Select;
  arr := res.ToArray;
  sb  := TStringBuilder.Create;
  try
    sb.Append('[');
    for i := 0 to High(arr) do
    begin
      if i > 0 then sb.Append(',');
      o := arr[i];
      sb.AppendFormat('{"Id":%d,"ProductId":%d,"ProductName":"%s","Quantity":%d,"Total":%g}',
        [o.Id, o.ProductId, o.ProductName, o.Quantity, o.Total]);
    end;
    sb.Append(']');
    Result := Json(sb.ToString);
  finally
    sb.Free;
  end;
end;

function TOrdersController.PlaceOrder(body : TPlaceOrderBody): IActionResult;
var
  order : TOrder;
begin
  order             := TOrder.Create;
  order.ProductId   := body.ProductId;
  order.ProductName := body.ProductName;
  order.Quantity    := body.Quantity;
  order.Total       := body.Quantity * body.UnitPrice;
  order.CreatedAt   := Now;
  fOrders.Orders.Add(order);
  try
    Result := StatusCode(201, TJsonSerializer.Serialize(order));
  finally
    order.Free;
  end;
end;

initialization
  RegisterController(TOrdersController);

end.
