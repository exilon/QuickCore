unit Repository.Product;

{ RepositoryPattern Sample - S-21
  Declares IProductRepository (domain interface) and its concrete
  implementation backed by TEntityRepository<TProduct>. }

interface

uses
  System.Generics.Collections,
  Quick.Core.Entity,
  Quick.Core.Entity.Repository,
  Models;

type
  IProductRepository = interface(IRepository<TProduct>)
  ['{6A92C5F3-14BB-4E28-B871-4FD20C9A7E53}']
    /// <summary>Find products whose price is at or below a given ceiling.</summary>
    function FindByMaxPrice(const aMaxPrice : Double) : TList<TProduct>;
    function FindByCategory(const aCategory : string) : TList<TProduct>;
  end;

  TProductRepository = class(TEntityRepository<TProduct>, IProductRepository)
  public
    function FindByMaxPrice(const aMaxPrice : Double) : TList<TProduct>;
    function FindByCategory(const aCategory : string) : TList<TProduct>;
  end;

implementation

{ TProductRepository }

function TProductRepository.FindByMaxPrice(const aMaxPrice : Double): TList<TProduct>;
begin
  Result := Find('Price <= ?', [aMaxPrice]);
end;

function TProductRepository.FindByCategory(const aCategory : string): TList<TProduct>;
begin
  Result := Find('Category = ?', [aCategory]);
end;

end.
