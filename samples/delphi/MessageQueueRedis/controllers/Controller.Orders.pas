unit Controller.Orders;

{ MessageQueueRedis Sample - S-19
  Producer: enqueues order messages into the Redis queue. }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.MessageQueue.Abstractions,
  Task.Order;

type
  TEnqueueOrderBody = class
  private
    FProductId : Integer;
    FQuantity  : Integer;
    FCustomer  : string;
  published
    property ProductId : Integer read FProductId write FProductId;
    property Quantity  : Integer read FQuantity  write FQuantity;
    property Customer  : string  read FCustomer  write FCustomer;
  end;

  [Route('api/orders')]
  [ApiController]
  TOrdersController = class(THttpController)
  private
    fQueue   : IMessageQueue<TOrderMessage>;
    fOrderId : Integer;
  public
    constructor Create(aQueue : IMessageQueue<TOrderMessage>);
  published
    [HttpPost('enqueue')]
    function Enqueue([FromBody] body : TEnqueueOrderBody) : IActionResult;
  end;

implementation

uses
  System.SysUtils,
  System.SyncObjs;

var
  gNextOrderId : Integer = 1;

{ TOrdersController }

constructor TOrdersController.Create(aQueue : IMessageQueue<TOrderMessage>);
begin
  inherited Create;
  fQueue := aQueue;
end;

function TOrdersController.Enqueue(body : TEnqueueOrderBody): IActionResult;
var
  msg : TOrderMessage;
  id  : Integer;
begin
  id := TInterlocked.Increment(gNextOrderId);
  msg            := TOrderMessage.Create;
  msg.OrderId    := id;
  msg.ProductId  := body.ProductId;
  msg.Quantity   := body.Quantity;
  msg.Customer   := body.Customer;
  try
    fQueue.Push(msg, False);
    Result := StatusCode(202,
      Format('{"accepted":true,"orderId":%d}', [id]));
  finally
    msg.Free;
  end;
end;

initialization
  RegisterController(TOrdersController);

end.
