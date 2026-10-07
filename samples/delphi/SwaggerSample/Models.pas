unit Models;

{ SwaggerSample — S-25
  In-memory product store shared between requests via a singleton service. }

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.SyncObjs;

type
  { -----------------------------------------------------------------
    Domain model — published properties are serialised to/from JSON.
    ----------------------------------------------------------------- }
  TProduct = class
  private
    fId       : Integer;
    fName     : string;
    fCategory : string;
    fPrice    : Double;
    fStock    : Integer;
  published
    property Id       : Integer read fId       write fId;
    property Name     : string  read fName     write fName;
    property Category : string  read fCategory write fCategory;
    property Price    : Double  read fPrice    write fPrice;
    property Stock    : Integer read fStock    write fStock;
  end;

  TNewProduct = class
  private
    fName     : string;
    fCategory : string;
    fPrice    : Double;
    fStock    : Integer;
  published
    property Name     : string  read fName     write fName;
    property Category : string  read fCategory write fCategory;
    property Price    : Double  read fPrice    write fPrice;
    property Stock    : Integer read fStock    write fStock;
  end;

  { -----------------------------------------------------------------
    IProductService — injected into the controller via DI.
    Thread-safe in-memory implementation.
    ----------------------------------------------------------------- }
  IProductService = interface
  ['{D1E2F3A4-B5C6-4D7E-8F9A-0B1C2D3E4F5A}']
    function  GetAll    : TArray<TProduct>;
    function  GetById   (aId : Integer) : TProduct;
    function  Add       (aDto : TNewProduct) : TProduct;
    function  Update    (aId : Integer; aDto : TNewProduct) : TProduct;
    procedure Delete    (aId : Integer);
  end;

  TProductService = class(TInterfacedObject, IProductService)
  private
    fItems  : TObjectList<TProduct>;
    fNextId : Integer;
    fLock   : TCriticalSection;
  public
    constructor Create;
    destructor  Destroy; override;
    function  GetAll  : TArray<TProduct>;
    function  GetById (aId : Integer) : TProduct;
    function  Add     (aDto : TNewProduct) : TProduct;
    function  Update  (aId : Integer; aDto : TNewProduct) : TProduct;
    procedure Delete  (aId : Integer);
  end;

implementation

{ TProductService }

constructor TProductService.Create;
var
  p : TProduct;
begin
  fItems  := TObjectList<TProduct>.Create(True);
  fNextId := 1;
  fLock   := TCriticalSection.Create;

  // Seed a few products
  p := TProduct.Create;
  p.Id := fNextId; Inc(fNextId);
  p.Name := 'Laptop Pro 15'; p.Category := 'Electronics'; p.Price := 1299.99; p.Stock := 10;
  fItems.Add(p);

  p := TProduct.Create;
  p.Id := fNextId; Inc(fNextId);
  p.Name := 'Wireless Mouse'; p.Category := 'Peripherals'; p.Price := 29.99; p.Stock := 50;
  fItems.Add(p);

  p := TProduct.Create;
  p.Id := fNextId; Inc(fNextId);
  p.Name := 'USB-C Hub 7-in-1'; p.Category := 'Accessories'; p.Price := 49.99; p.Stock := 30;
  fItems.Add(p);
end;

destructor TProductService.Destroy;
begin
  fLock.Free;
  fItems.Free;
  inherited;
end;

function TProductService.GetAll: TArray<TProduct>;
var
  i : Integer;
begin
  fLock.Enter;
  try
    SetLength(Result, fItems.Count);
    for i := 0 to fItems.Count - 1 do
      Result[i] := fItems[i];
  finally
    fLock.Leave;
  end;
end;

function TProductService.GetById(aId: Integer): TProduct;
var
  p : TProduct;
begin
  Result := nil;
  fLock.Enter;
  try
    for p in fItems do
      if p.Id = aId then
      begin
        Result := p;
        Break;
      end;
  finally
    fLock.Leave;
  end;
end;

function TProductService.Add(aDto: TNewProduct): TProduct;
begin
  Result := TProduct.Create;
  fLock.Enter;
  try
    Result.Id       := fNextId; Inc(fNextId);
    Result.Name     := aDto.Name;
    Result.Category := aDto.Category;
    Result.Price    := aDto.Price;
    Result.Stock    := aDto.Stock;
    fItems.Add(Result);
  finally
    fLock.Leave;
  end;
end;

function TProductService.Update(aId: Integer; aDto: TNewProduct): TProduct;
var
  p : TProduct;
begin
  Result := nil;
  fLock.Enter;
  try
    for p in fItems do
      if p.Id = aId then
      begin
        p.Name     := aDto.Name;
        p.Category := aDto.Category;
        p.Price    := aDto.Price;
        p.Stock    := aDto.Stock;
        Result := p;
        Break;
      end;
  finally
    fLock.Leave;
  end;
end;

procedure TProductService.Delete(aId: Integer);
var
  i : Integer;
begin
  fLock.Enter;
  try
    for i := 0 to fItems.Count - 1 do
      if fItems[i].Id = aId then
      begin
        fItems.Delete(i);
        Break;
      end;
  finally
    fLock.Leave;
  end;
end;

end.
