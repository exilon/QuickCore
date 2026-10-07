unit Domain.Product;

{ CleanArchitectureApi Sample - S-15 — Domain Layer
  Pure domain model + repository contract.
  No framework dependencies here. }

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Quick.Core.Entity,
  Quick.Core.Entity.DAO;

type
  { Domain entity }
  [Table('products')]
  TProduct = class(TEntity)
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

  { Repository interface — defined in Domain, implemented in Infrastructure }
  IProductRepository = interface
  ['{1A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}']
    function GetAll   : TList<TProduct>;
    function GetById  (const aId : TAutoID) : TProduct;
    function Add      (aProduct : TProduct) : Boolean;
    function Update   (aProduct : TProduct) : Boolean;
    function Delete   (const aId : TAutoID) : Boolean;
  end;

implementation

end.
