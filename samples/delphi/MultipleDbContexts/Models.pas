unit Models;

{ MultipleDbContexts Sample - S-18
  Two separate entity models and DB contexts. }

interface

uses
  Quick.Core.Entity,
  Quick.Core.Entity.DAO;

type
  { Catalog DB — product definitions }
  [Table('products')]
  TCatalogProduct = class(TEntity)
  private
    FId       : TAutoID;
    FName     : string;
    FCategory : string;
    FPrice    : Double;
  published
    [Key]
    property Id       : TAutoID read FId       write FId;
    [StringLength(100)]
    property Name     : string  read FName     write FName;
    [StringLength(50)]
    property Category : string  read FCategory write FCategory;
    [DecimalLength(10, 2)]
    property Price    : Double  read FPrice    write FPrice;
  end;

  TCatalogContext = class(TDBContext)
  private
    FProducts : TDBSet<TCatalogProduct>;
  public
    property Products : TDBSet<TCatalogProduct> read FProducts write FProducts;
  end;

  { Orders DB — order records }
  [Table('orders')]
  TOrder = class(TEntity)
  private
    FId          : TAutoID;
    FProductId   : Integer;
    FProductName : string;
    FQuantity    : Integer;
    FTotal       : Double;
    FCreatedAt   : TDateTime;
  published
    [Key]
    property Id          : TAutoID  read FId          write FId;
    property ProductId   : Integer  read FProductId   write FProductId;
    [StringLength(100)]
    property ProductName : string   read FProductName write FProductName;
    property Quantity    : Integer  read FQuantity    write FQuantity;
    [DecimalLength(12, 2)]
    property Total       : Double   read FTotal       write FTotal;
    property CreatedAt   : TDateTime read FCreatedAt  write FCreatedAt;
  end;

  TOrdersContext = class(TDBContext)
  private
    FOrders : TDBSet<TOrder>;
  public
    property Orders : TDBSet<TOrder> read FOrders write FOrders;
  end;

implementation

end.
