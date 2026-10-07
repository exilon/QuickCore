unit Models;

{ WebApiWithDatabase Sample - S-07
  Entity model and DBContext }

interface

uses
  Quick.Core.Entity,
  Quick.Core.Entity.DAO;

type
  [Table('products')]
  TProductEntity = class(TEntity)
  private
    FId       : TAutoID;
    FName     : string;
    FCategory : string;
    FPrice    : Double;
    FStock    : Integer;
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
  end;

  TShopContext = class(TDBContext)
  private
    FProducts : TDBSet<TProductEntity>;
  public
    property Products : TDBSet<TProductEntity> read FProducts write FProducts;
  end;

implementation

end.
