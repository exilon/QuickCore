unit Models;

{ UnitOfWorkPattern Sample - S-22
  Domain entities and the DB context used across the sample. }

interface

uses
  Quick.Core.Entity,
  Quick.Core.Entity.DAO;

type
  [Table('orders')]
  TOrder = class(TEntity)
  private
    FId         : TAutoID;
    FCustomerId : Integer;
    FOrderDate  : TDateTime;
    FTotal      : Double;
  public
    [Key]
    property Id         : TAutoID  read FId         write FId;
    property CustomerId : Integer  read FCustomerId write FCustomerId;
    property OrderDate  : TDateTime read FOrderDate write FOrderDate;
    property Total      : Double   read FTotal      write FTotal;
  end;

  [Table('order_items')]
  TOrderItem = class(TEntity)
  private
    FId        : TAutoID;
    FOrderId   : TAutoID;
    FProductId : Integer;
    FQty       : Integer;
    FUnitPrice : Double;
  public
    [Key]
    property Id        : TAutoID read FId        write FId;
    property OrderId   : TAutoID read FOrderId   write FOrderId;
    property ProductId : Integer read FProductId write FProductId;
    property Qty       : Integer read FQty       write FQty;
    property UnitPrice : Double  read FUnitPrice write FUnitPrice;
  end;

  TOrderingContext = class(TDBContext)
  private
    FOrders     : TDBSet<TOrder>;
    FOrderItems : TDBSet<TOrderItem>;
  public
    property Orders     : TDBSet<TOrder>     read FOrders     write FOrders;
    property OrderItems : TDBSet<TOrderItem> read FOrderItems write FOrderItems;
  end;

  { DTO used when parsing a POST body }
  TOrderItemLine = class
  private
    FProductId : Integer;
    FQty       : Integer;
    FUnitPrice : Double;
  published
    property ProductId : Integer read FProductId write FProductId;
    property Qty       : Integer read FQty       write FQty;
    property UnitPrice : Double  read FUnitPrice write FUnitPrice;
  end;

  TPlaceOrderRequest = class
  private
    FCustomerId : Integer;
    FItems      : TArray<TOrderItemLine>;
  published
    property CustomerId : Integer           read FCustomerId write FCustomerId;
    property Items      : TArray<TOrderItemLine> read FItems write FItems;
    destructor Destroy; override;
  end;

implementation

{ TPlaceOrderRequest }

destructor TPlaceOrderRequest.Destroy;
var
  line : TOrderItemLine;
begin
  for line in FItems do
    line.Free;
  inherited;
end;

end.
