unit Service.Product;

{ WebApiWithDI Sample - S-06
  IProductService + TProductService (in-memory store) }

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TProductItem = record
    Id       : Integer;
    Name     : string;
    Category : string;
    Price    : Double;
  end;

  IProductService = interface
  ['{F1A2B3C4-D5E6-4F7A-8B9C-0D1E2F3A4B5C}']
    function GetAll : TArray<TProductItem>;
    function GetById(aId : Integer) : TProductItem;
    function Add(const aName, aCategory : string; aPrice : Double) : TProductItem;
    procedure Delete(aId : Integer);
  end;

  TProductService = class(TInterfacedObject, IProductService)
  private
    FItems    : TList<TProductItem>;
    FNextId   : Integer;
  public
    constructor Create;
    destructor Destroy; override;
    function GetAll : TArray<TProductItem>;
    function GetById(aId : Integer) : TProductItem;
    function Add(const aName, aCategory : string; aPrice : Double) : TProductItem;
    procedure Delete(aId : Integer);
  end;

implementation

{ TProductService }

constructor TProductService.Create;
var
  p : TProductItem;
begin
  FItems  := TList<TProductItem>.Create;
  FNextId := 1;
  // Seed some products
  p.Id := FNextId; Inc(FNextId); p.Name := 'Widget Pro'; p.Category := 'Hardware'; p.Price := 29.99; FItems.Add(p);
  p.Id := FNextId; Inc(FNextId); p.Name := 'Gadget Lite'; p.Category := 'Electronics'; p.Price := 9.99; FItems.Add(p);
  p.Id := FNextId; Inc(FNextId); p.Name := 'SuperTool'; p.Category := 'Tools'; p.Price := 49.99; FItems.Add(p);
end;

destructor TProductService.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TProductService.GetAll: TArray<TProductItem>;
begin
  Result := FItems.ToArray;
end;

function TProductService.GetById(aId: Integer): TProductItem;
var
  p : TProductItem;
begin
  Result := Default(TProductItem);
  for p in FItems do
    if p.Id = aId then
    begin
      Result := p;
      Exit;
    end;
end;

function TProductService.Add(const aName, aCategory: string; aPrice: Double): TProductItem;
begin
  Result.Id       := FNextId;
  Result.Name     := aName;
  Result.Category := aCategory;
  Result.Price    := aPrice;
  Inc(FNextId);
  FItems.Add(Result);
end;

procedure TProductService.Delete(aId: Integer);
var
  i : Integer;
begin
  for i := 0 to FItems.Count - 1 do
    if FItems[i].Id = aId then
    begin
      FItems.Delete(i);
      Exit;
    end;
end;

end.
