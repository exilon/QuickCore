unit Infra.Data.Models.Product;

interface

uses
  Quick.Core.Entity;

type
  [Table('Products')]
  TDBProduct = class(TEntity)
  private
    fId : TAutoID;
    fName : string;
    fPrice : Double;
  published
    [Key]
    property Id : TAutoID read fId write fId;
    [StringLength(50)]
    property Name : string read fName write fName;
    [DecimalLength(10,2)]
    property Price : Double read fPrice write fPrice;
  end;

implementation

end.
