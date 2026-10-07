unit Application.Service.Product;

{ CleanArchitectureApi Sample - S-15 — Application Layer
  Use-cases / application service.
  Depends on domain interfaces only — not on infrastructure. }

interface

uses
  System.Generics.Collections,
  Domain.Product;

type
  TProductDto = record
    Id       : Integer;
    Name     : string;
    Category : string;
    Price    : Double;
  end;

  IProductService = interface
  ['{2B3C4D5E-6F7A-8B9C-0D1E-2F3A4B5C6D7E}']
    function GetAll   : TList<TProductDto>;
    function GetById  (const aId : Integer) : TProductDto;
    procedure AddProduct(const aName, aCategory : string; aPrice : Double);
    procedure DeleteProduct(const aId : Integer);
  end;

  TProductAppService = class(TInterfacedObject, IProductService)
  private
    fRepo : IProductRepository;
  public
    constructor Create(aRepo : IProductRepository);
    function GetAll   : TList<TProductDto>;
    function GetById  (const aId : Integer) : TProductDto;
    procedure AddProduct(const aName, aCategory : string; aPrice : Double);
    procedure DeleteProduct(const aId : Integer);
  end;

implementation

uses
  System.SysUtils;

function ToDto(p : TProduct) : TProductDto;
begin
  Result.Id       := p.Id;
  Result.Name     := p.Name;
  Result.Category := p.Category;
  Result.Price    := p.Price;
end;

{ TProductAppService }

constructor TProductAppService.Create(aRepo : IProductRepository);
begin
  inherited Create;
  fRepo := aRepo;
end;

function TProductAppService.GetAll: TList<TProductDto>;
var
  products : TList<TProduct>;
  p        : TProduct;
begin
  Result   := TList<TProductDto>.Create;
  products := fRepo.GetAll;
  try
    for p in products do
      Result.Add(ToDto(p));
  finally
    products.Free;
  end;
end;

function TProductAppService.GetById(const aId : Integer): TProductDto;
var
  p : TProduct;
begin
  p := fRepo.GetById(aId);
  if p = nil then
    raise Exception.CreateFmt('Product %d not found', [aId]);
  try
    Result := ToDto(p);
  finally
    p.Free;
  end;
end;

procedure TProductAppService.AddProduct(const aName, aCategory : string; aPrice : Double);
var
  p : TProduct;
begin
  p          := TProduct.Create;
  p.Name     := aName;
  p.Category := aCategory;
  p.Price    := aPrice;
  try
    fRepo.Add(p);
  finally
    p.Free;
  end;
end;

procedure TProductAppService.DeleteProduct(const aId : Integer);
begin
  fRepo.Delete(aId);
end;

end.
