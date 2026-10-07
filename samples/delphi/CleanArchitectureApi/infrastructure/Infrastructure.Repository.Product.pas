unit Infrastructure.Repository.Product;

{ CleanArchitectureApi Sample - S-15 — Infrastructure Layer
  Concrete implementation of IProductRepository using Entity ORM. }

interface

uses
  System.Generics.Collections,
  Quick.Core.Entity,
  Quick.Core.Entity.DAO,
  Domain.Product;

type
  TShopContext = class(TDBContext)
  private
    FProducts : TDBSet<TProduct>;
  public
    property Products : TDBSet<TProduct> read FProducts write FProducts;
  end;

  TProductRepository = class(TInterfacedObject, IProductRepository)
  private
    fContext : TShopContext;
  public
    constructor Create(aContext : TShopContext);
    function GetAll   : TList<TProduct>;
    function GetById  (const aId : TAutoID) : TProduct;
    function Add      (aProduct : TProduct) : Boolean;
    function Update   (aProduct : TProduct) : Boolean;
    function Delete   (const aId : TAutoID) : Boolean;
  end;

implementation

uses
  System.SysUtils;

{ TProductRepository }

constructor TProductRepository.Create(aContext : TShopContext);
begin
  inherited Create;
  fContext := aContext;
end;

function TProductRepository.GetAll: TList<TProduct>;
begin
  Result := TList<TProduct>.Create;
  fContext.Products.Where('').Select.ToList(Result);
end;

function TProductRepository.GetById(const aId : TAutoID): TProduct;
begin
  Result := fContext.Products.Where('Id = %d', [aId]).SelectFirst;
end;

function TProductRepository.Add(aProduct : TProduct): Boolean;
begin
  Result := fContext.Products.Add(aProduct);
end;

function TProductRepository.Update(aProduct : TProduct): Boolean;
begin
  Result := fContext.Products.Update(aProduct);
end;

function TProductRepository.Delete(const aId : TAutoID): Boolean;
begin
  Result := fContext.Products.Where('Id = %d', [aId]).Delete;
end;

end.
