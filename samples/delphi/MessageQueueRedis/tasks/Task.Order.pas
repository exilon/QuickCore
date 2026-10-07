unit Task.Order;

{ MessageQueueRedis Sample - S-19
  Message payload (DTO) for the order processing queue.
  TOrderMessage is the message class registered with IMessageQueue<TOrderMessage>.
  Producers call Push(msg, False); consumers call Pop(out msg). }

interface

type
  { Message payload — must be a simple class with published properties so
    the framework can JSON-serialise it to/from Redis. }
  TOrderMessage = class
  private
    FOrderId   : Integer;
    FProductId : Integer;
    FQuantity  : Integer;
    FCustomer  : string;
  published
    property OrderId   : Integer read FOrderId   write FOrderId;
    property ProductId : Integer read FProductId write FProductId;
    property Quantity  : Integer read FQuantity  write FQuantity;
    property Customer  : string  read FCustomer  write FCustomer;
  end;

implementation

end.
