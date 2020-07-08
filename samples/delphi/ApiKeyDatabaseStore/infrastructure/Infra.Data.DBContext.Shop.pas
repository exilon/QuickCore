unit Infra.Data.DBContext.Shop;

interface

uses
  Quick.Core.Entity,
  Infra.Data.Models.Product,
  Infra.Data.Models.Costumer;

type
  TShopContext = class(TDBContext)
  private
    fProducts : TDBSet<TDBProduct>;
    fCostumer : TDBSet<TDBCostumer>;
  public
    [&Index('Name')]
    property Products : TDBSet<TDBProduct> read fProducts write fProducts;
    //[&Index(['Last_Name','First_Name'])]
    property Costumers : TDBSet<TDBCostumer> read fCostumer write fCostumer;
  end;

implementation

end.
