unit Service.Order;

{ UnitOfWorkPattern Sample - S-22
  Demonstrates the Unit-of-Work pattern: all INSERT operations for a single
  "place order" business action are wrapped in one database transaction. }

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Quick.Core.Entity.DAO,
  Models;

type
  IOrderService = interface
  ['{8D4F2C9A-B17E-4E56-A935-0F2B7CAE5D11}']
    function PlaceOrder(aRequest : TPlaceOrderRequest) : TAutoID;
    function GetAll : TList<TOrder>;
  end;

  TOrderService = class(TInterfacedObject, IOrderService)
  private
    fCtx : TOrderingContext;
  public
    constructor Create(aCtx : TOrderingContext);
    function PlaceOrder(aRequest : TPlaceOrderRequest) : TAutoID;
    function GetAll : TList<TOrder>;
  end;

implementation

{ TOrderService }

constructor TOrderService.Create(aCtx : TOrderingContext);
begin
  inherited Create;
  fCtx := aCtx;
end;

function TOrderService.PlaceOrder(aRequest : TPlaceOrderRequest) : TAutoID;
var
  order    : TOrder;
  item     : TOrderItem;
  line     : TOrderItemLine;
  total    : Double;
begin
  { ---- Unit of Work: begin ---- }
  fCtx.Database.BeginTransaction;
  try
    order            := TOrder.Create;
    order.CustomerId := aRequest.CustomerId;
    order.OrderDate  := Now;

    // Calculate total from request lines
    total := 0;
    for line in aRequest.Items do
      total := total + line.Qty * line.UnitPrice;
    order.Total := total;

    if not fCtx.Orders.Add(order) then
      raise Exception.Create('Failed to insert order header');

    // Insert each line item using the auto-generated order id
    for line in aRequest.Items do
    begin
      item           := TOrderItem.Create;
      item.OrderId   := order.Id;
      item.ProductId := line.ProductId;
      item.Qty       := line.Qty;
      item.UnitPrice := line.UnitPrice;
      try
        if not fCtx.OrderItems.Add(item) then
          raise Exception.CreateFmt('Failed to insert order item for product %d', [line.ProductId]);
      finally
        item.Free;
      end;
    end;

    Result := order.Id;
    order.Free;

    { ---- Unit of Work: commit ---- }
    fCtx.Database.CommitTransaction;
  except
    { ---- Unit of Work: rollback on any error ---- }
    fCtx.Database.RollbackTransaction;
    raise;
  end;
end;

function TOrderService.GetAll: TList<TOrder>;
var
  resultSet : IEntityResult<TOrder>;
  item      : TOrder;
begin
  Result := TList<TOrder>.Create;
  resultSet := fCtx.Orders.Where('').Select;
  for item in resultSet do
    Result.Add(item);
end;

end.
