unit Service.Product;

{ RepositoryPattern Sample - S-21
  Application-layer service that operates through IProductRepository,
  never touching the DB context directly. }

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Quick.Core.Entity,
  Models,
  Repository.Product;

type
  IProductService = interface
  ['{B2F7D9E1-5CC4-4AB0-9234-7C1A098F3B44}']
    function GetAll : TList<TProduct>;
    function GetById(const aId : TAutoID) : TProduct;
    function Add(aProduct : TProduct) : Boolean;
    function Update(aProduct : TProduct) : Boolean;
    function Delete(const aId : TAutoID) : Boolean;
    function GetCheap(const aMaxPrice : Double) : TList<TProduct>;
    function GetByCategory(const aCategory : string) : TList<TProduct>;
  end;

  TProductService = class(TInterfacedObject, IProductService)
  private
    fRepo : IProductRepository;
  public
    constructor Create(aRepo : IProductRepository);
    function GetAll : TList<TProduct>;
    function GetById(const aId : TAutoID) : TProduct;
    function Add(aProduct : TProduct) : Boolean;
    function Update(aProduct : TProduct) : Boolean;
    function Delete(const aId : TAutoID) : Boolean;
    function GetCheap(const aMaxPrice : Double) : TList<TProduct>;
    function GetByCategory(const aCategory : string) : TList<TProduct>;
  end;

implementation

{ TProductService }

constructor TProductService.Create(aRepo : IProductRepository);
begin
  inherited Create;
  fRepo := aRepo;
end;

function TProductService.GetAll: TList<TProduct>;
begin
  Result := fRepo.GetAll;
end;

function TProductService.GetById(const aId : TAutoID): TProduct;
begin
  Result := fRepo.GetById(aId);
end;

function TProductService.Add(aProduct : TProduct): Boolean;
begin
  Result := fRepo.Add(aProduct);
end;

function TProductService.Update(aProduct : TProduct): Boolean;
begin
  Result := fRepo.Update(aProduct);
end;

function TProductService.Delete(const aId : TAutoID): Boolean;
begin
  Result := fRepo.DeleteById(aId);
end;

function TProductService.GetCheap(const aMaxPrice : Double): TList<TProduct>;
begin
  Result := fRepo.FindByMaxPrice(aMaxPrice);
end;

function TProductService.GetByCategory(const aCategory : string): TList<TProduct>;
begin
  Result := fRepo.FindByCategory(aCategory);
end;

end.
