unit Service.Product;

{ DecoratorPattern Sample - S-23
  "Real" product service backed by an in-memory list.
  Deliberately contains a slight delay to demonstrate that the decorator
  skips this call when the result is already cached. }

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TProduct = record
    Id       : Integer;
    Name     : string;
    Category : string;
    Price    : Double;
  end;

  IProductService = interface
  ['{C3E7F1A2-58DB-4B91-BF46-7D0A29C3E814}']
    function GetAll    : TArray<TProduct>;
    function GetById(const aId : Integer) : TProduct;
    procedure InvalidateAll;
  end;

  TProductService = class(TInterfacedObject, IProductService)
  private
    fData : TArray<TProduct>;
  public
    constructor Create;
    function GetAll    : TArray<TProduct>;
    function GetById(const aId : Integer) : TProduct;
    procedure InvalidateAll;
  end;

implementation

uses
  Quick.Commons;

{ TProductService }

constructor TProductService.Create;
begin
  inherited Create;
  SetLength(fData, 5);
  fData[0].Id := 1; fData[0].Name := 'Laptop';     fData[0].Category := 'Electronics'; fData[0].Price := 999.99;
  fData[1].Id := 2; fData[1].Name := 'Desk Chair'; fData[1].Category := 'Furniture';   fData[1].Price := 299.00;
  fData[2].Id := 3; fData[2].Name := 'Monitor';    fData[2].Category := 'Electronics'; fData[2].Price := 549.50;
  fData[3].Id := 4; fData[3].Name := 'Bookshelf';  fData[3].Category := 'Furniture';   fData[3].Price :=  89.95;
  fData[4].Id := 5; fData[4].Name := 'Headphones'; fData[4].Category := 'Electronics'; fData[4].Price := 149.99;
end;

function TProductService.GetAll: TArray<TProduct>;
begin
  // Simulate a slow data-source (e.g. DB round-trip)
  Sleep(100);
  Result := fData;
end;

function TProductService.GetById(const aId : Integer): TProduct;
var
  p : TProduct;
begin
  Sleep(50);
  for p in fData do
    if p.Id = aId then
      Exit(p);
  raise EArgumentOutOfRangeException.CreateFmt('Product %d not found', [aId]);
end;

procedure TProductService.InvalidateAll;
begin
  // No-op: the real service has no cache to flush
end;

end.
