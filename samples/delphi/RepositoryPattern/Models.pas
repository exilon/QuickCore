unit Models;

{ RepositoryPattern Sample - S-21
  Entity and DB context for the shop database. }

interface

uses
  Quick.Core.Entity,
  Quick.Core.Entity.Database,
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
  published
    [Key]
    property Id       : TAutoID read FId       write FId;
    property Name     : string  read FName     write FName;
    property Category : string  read FCategory write FCategory;
    property Price    : Double  read FPrice    write FPrice;
    property Stock    : Integer read FStock    write FStock;
  end;

  TShopContext = class(TDBContext)
  private
    FProducts : TDBSet<TProduct>;
  public
    property Products : TDBSet<TProduct> read FProducts write FProducts;
  end;

implementation

end.
