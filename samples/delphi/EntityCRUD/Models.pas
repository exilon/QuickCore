unit Models;

interface

uses
  Quick.Core.Entity,
  Quick.Core.Entity.DAO;

type
  [Table('products')]
  TProduct = class(TEntity)
  private
    FId       : TAutoID;
    FName     : string;
    FCategory : string;
    FPrice    : Double;
    FStock    : Integer;
    FActive   : Boolean;
  published
    [Key]
    property Id       : TAutoID read FId       write FId;
    [StringLength(100)]
    property Name     : string  read FName     write FName;
    [StringLength(50)]
    property Category : string  read FCategory write FCategory;
    [DecimalLength(10, 2)]
    property Price    : Double  read FPrice    write FPrice;
    property Stock    : Integer read FStock    write FStock;
    property Active   : Boolean read FActive   write FActive;
  end;

implementation

end.
