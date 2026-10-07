unit Domain.Models.Product;

interface

type
  TProduct = class
  private
    fId : Int64;
    fName : string;
    fPrice : Double;
  published
    property Id : Int64 read fId write fId;
    property Name : string read fName write fName;
    property Price : Double read fPrice write fPrice;
  end;

implementation

end.
