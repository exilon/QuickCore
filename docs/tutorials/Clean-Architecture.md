# Tutorial 9 — Clean Architecture with QuickCore

> **Estimated time:** 45 minutes  
> **Level:** Advanced  
> **Reference sample:** `samples/delphi/CleanArchitectureApi` (S-15)

**Clean Architecture** (also known as Hexagonal Architecture or Ports & Adapters) organizes code into layers with strict dependency rules. In this tutorial you will build a complete API following this pattern, using QuickCore purely as infrastructure.

---

## Core principle

```
           ┌─────────────────────────────────────┐
           │         Presentation Layer           │  HTTP Controllers
           │  (knows Application, not Domain)     │
           └────────────────┬────────────────────┘
                            │ usa interfaces de ↓
           ┌────────────────▼────────────────────┐
           │          Application Layer           │  Use-cases / Services
           │   (knows Domain, not Infrastructure) │
           └────────────────┬────────────────────┘
                            │ define interfaces de ↓
           ┌────────────────▼────────────────────┐
           │            Domain Layer              │  Entities + contracts
           │     (knows no other layer)           │
           └─────────────────────────────────────┘
                            ▲ implementa ↑
           ┌────────────────┴────────────────────┐
           │        Infrastructure Layer          │  ORM, database
           │  (knows Domain, never Application)   │
           └─────────────────────────────────────┘
                            ▲ conecta todo ↑
           ┌────────────────┴────────────────────┐
           │              Startup.pas             │  Only this file
           │     (knows ALL layers)               │  connects layers via DI
           └─────────────────────────────────────┘
```

**Dependency rule:** inner layers never import outer layers. `Startup.pas` is the only exception and acts as the *composition root*.

---

## Project structure

```
CleanArchitectureApi/
├── CleanArchitectureApi.dpr
├── Startup.pas                      ← composition root
├── domain/
│   └── Domain.Product.pas           ← entity + IProductRepository
├── application/
│   └── Application.Service.Product.pas  ← use-cases + DTOs
├── infrastructure/
│   └── Infrastructure.Repository.Product.pas  ← Entity ORM
└── presentation/
  └── Controller.Products.pas      ← HTTP controllers
```

---

## Step 1 — Domain Layer (no external dependencies)

Create `domain/Domain.Product.pas`.

This layer defines **what exists** (entities) and **what can be done** (repository contracts), but does not know how they are implemented:

```pascal
unit Domain.Product;

{ Domain Layer — no framework dependencies.
  Only uses Quick.Core.Entity for ORM attributes,
  but the entity itself is a PODO (Plain Old Delphi Object). }

interface

uses
  System.Generics.Collections,
  Quick.Core.Entity,
  Quick.Core.Entity.DAO;

type
  { ── Domain entity ──────────────────────────────────────────────── }
  [Table('products')]
  TProduct = class(TEntity)
  private
    FId       : TAutoID;
    FName     : string;
    FCategory : string;
    FPrice    : Double;
  published
    [Key]
    property Id       : TAutoID read FId       write FId;
    [StringLength(100)]
    property Name     : string  read FName     write FName;
    [StringLength(50)]
    property Category : string  read FCategory write FCategory;
    [DecimalLength(10, 2)]
    property Price    : Double  read FPrice    write FPrice;
  end;

  { ── Repository contract (Port) ─────────────────────────────────── }
  // Defined in Domain → implemented in Infrastructure
  IProductRepository = interface
  ['{1A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}']
    function GetAll  : TList<TProduct>;
    function GetById (const aId : TAutoID) : TProduct;
    function Add     (aProduct : TProduct) : Boolean;
    function Update  (aProduct : TProduct) : Boolean;
    function Delete  (const aId : TAutoID) : Boolean;
  end;

implementation
end.
```

> **Why use GUIDs on interfaces:** allows Delphi to do `QueryInterface` and safe casting with `as` / `Supports()`.

---

## Step 2 — Application Layer (use-cases)

Create `application/Application.Service.Product.pas`.

This layer contains the **business logic** (use-cases). It depends on the Domain (for `IProductRepository`), but never on Infrastructure or Presentation:

```pascal
unit Application.Service.Product;

{ Application Layer — product use-cases.
  Depends ONLY on Domain.Product. }

interface

uses
  System.Generics.Collections,
  Domain.Product;

type
  { ── Output DTO (no TEntity, no ORM) ────────────────────────────── }
  TProductDto = record
    Id       : Integer;
    Name     : string;
    Category : string;
    Price    : Double;
  end;

  { ── Service contract (Port) ─────────────────────────────────────── }
  IProductService = interface
  ['{2B3C4D5E-6F7A-8B9C-0D1E-2F3A4B5C6D7E}']
    function GetAll  : TList<TProductDto>;
    function GetById (const aId : Integer) : TProductDto;
    procedure AddProduct   (const aName, aCategory : string; aPrice : Double);
    procedure UpdateProduct(const aId : Integer; const aName, aCategory : string; aPrice : Double);
    procedure DeleteProduct(const aId : Integer);
  end;

  { ── Use-case implementation ─────────────────────────────────────── }
  TProductAppService = class(TInterfacedObject, IProductService)
  private
    fRepo : IProductRepository;
    function ToDto(p : TProduct) : TProductDto;
  public
    constructor Create(aRepo : IProductRepository);
    function GetAll  : TList<TProductDto>;
    function GetById (const aId : Integer) : TProductDto;
    procedure AddProduct   (const aName, aCategory : string; aPrice : Double);
    procedure UpdateProduct(const aId : Integer; const aName, aCategory : string; aPrice : Double);
    procedure DeleteProduct(const aId : Integer);
  end;

implementation

uses System.SysUtils;

function TProductAppService.ToDto(p : TProduct) : TProductDto;
begin
  Result.Id       := p.Id;
  Result.Name     := p.Name;
  Result.Category := p.Category;
  Result.Price    := p.Price;
end;

constructor TProductAppService.Create(aRepo : IProductRepository);
begin
  inherited Create;
  fRepo := aRepo;
end;

function TProductAppService.GetAll : TList<TProductDto>;
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

function TProductAppService.GetById(const aId : Integer) : TProductDto;
var
  p : TProduct;
begin
  p := fRepo.GetById(aId);
  if p = nil then
    raise ENotFoundException.CreateFmt('Product %d not found', [aId]);
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
  if aName.IsEmpty then
    raise EValidationException.Create('Name is required');
  if aPrice <= 0 then
    raise EValidationException.Create('Price must be positive');

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

procedure TProductAppService.UpdateProduct(const aId : Integer;
  const aName, aCategory : string; aPrice : Double);
var
  p : TProduct;
begin
  p := fRepo.GetById(aId);
  if p = nil then
    raise ENotFoundException.CreateFmt('Product %d not found', [aId]);
  try
    p.Name     := aName;
    p.Category := aCategory;
    p.Price    := aPrice;
    fRepo.Update(p);
  finally
    p.Free;
  end;
end;

procedure TProductAppService.DeleteProduct(const aId : Integer);
begin
  if not fRepo.Delete(aId) then
    raise ENotFoundException.CreateFmt('Product %d not found', [aId]);
end;

end.
```

---

## Step 3 — Infrastructure Layer (Adapter)

Create `infrastructure/Infrastructure.Repository.Product.pas`.

This layer **implements** the repository contract using the QuickCore ORM. Only `Startup.pas` knows this class exists:

```pascal
unit Infrastructure.Repository.Product;

{ Infrastructure Layer — repository adapter with Entity ORM.
  Implements IProductRepository defined in Domain. }

interface

uses
  System.Generics.Collections,
  Quick.Core.Entity,
  Quick.Core.Entity.DAO,
  Domain.Product;

type
  { DbContext for this bounded context }
  TShopContext = class(TDBContext)
  private
    FProducts : TDBSet<TProduct>;
  public
    property Products : TDBSet<TProduct> read FProducts write FProducts;
  end;

  { Concrete repository implementation }
  TProductRepository = class(TInterfacedObject, IProductRepository)
  private
    fContext : TShopContext;
  public
    constructor Create(aContext : TShopContext);
    function GetAll  : TList<TProduct>;
    function GetById (const aId : TAutoID) : TProduct;
    function Add     (aProduct : TProduct) : Boolean;
    function Update  (aProduct : TProduct) : Boolean;
    function Delete  (const aId : TAutoID) : Boolean;
  end;

implementation

uses System.SysUtils;

constructor TProductRepository.Create(aContext : TShopContext);
begin
  inherited Create;
  fContext := aContext;
end;

function TProductRepository.GetAll : TList<TProduct>;
begin
  Result := TList<TProduct>.Create;
  fContext.Products.Where('').Select.ToList(Result);
end;

function TProductRepository.GetById(const aId : TAutoID) : TProduct;
begin
  Result := fContext.Products.Where('Id = %d', [aId]).SelectFirst;
end;

function TProductRepository.Add(aProduct : TProduct) : Boolean;
begin
  Result := fContext.Products.Add(aProduct);
end;

function TProductRepository.Update(aProduct : TProduct) : Boolean;
begin
  Result := fContext.Products.Update(aProduct);
end;

function TProductRepository.Delete(const aId : TAutoID) : Boolean;
begin
  Result := fContext.Products.Where('Id = %d', [aId]).Delete;
end;

end.
```

---

## Step 4 — Presentation Layer (Controllers)

Create `presentation/Controller.Products.pas`.

The controller **only knows `IProductService`** — it knows nothing about the database or how products are stored:

```pascal
unit Controller.Products;

{ Presentation Layer — HTTP controller.
  Depends ONLY on Application.Service.Product (IProductService). }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Application.Service.Product;

type
  TCreateBody = class
  private
    FName     : string;
    FCategory : string;
    FPrice    : Double;
  public
    property Name     : string read FName     write FName;
    property Category : string read FCategory write FCategory;
    property Price    : Double read FPrice    write FPrice;
  end;

  [Route('api/products')]
  [ApiController]
  TProductsController = class(THttpController)
  private
    fService : IProductService;
  public
    constructor Create(aService : IProductService);
  published
    [HttpGet]
    function GetAll : IActionResult;

    [HttpGet('{id}')]
    function GetById(id : Integer) : IActionResult;

    [HttpPost]
    function CreateProduct([FromBody] body : TCreateBody) : IActionResult;

    [HttpPut('{id}')]
    function UpdateProduct(id : Integer; [FromBody] body : TCreateBody) : IActionResult;

    [HttpDelete('{id}')]
    function Delete(id : Integer) : IActionResult;
  end;

implementation

uses
  System.SysUtils;

constructor TProductsController.Create(aService : IProductService);
begin
  inherited Create;
  fService := aService;
end;

function TProductsController.GetAll : IActionResult;
var
  dtos : TList<TProductDto>;
  sb   : TStringBuilder;
  dto  : TProductDto;
  i    : Integer;
begin
  dtos := fService.GetAll;
  sb   := TStringBuilder.Create;
  try
    sb.Append('[');
    for i := 0 to dtos.Count - 1 do
    begin
      dto := dtos[i];
      if i > 0 then sb.Append(',');
      sb.AppendFormat('{"id":%d,"name":"%s","category":"%s","price":%g}',
        [dto.Id, dto.Name, dto.Category, dto.Price]);
    end;
    sb.Append(']');
    Result := Json(sb.ToString);
  finally
    sb.Free;
    dtos.Free;
  end;
end;

function TProductsController.GetById(id : Integer) : IActionResult;
var
  dto : TProductDto;
begin
  try
    dto := fService.GetById(id);
    Result := Json(Format('{"id":%d,"name":"%s","category":"%s","price":%g}',
      [dto.Id, dto.Name, dto.Category, dto.Price]));
  except
    on E : ENotFoundException do
      Result := NotFound(E.Message);
  end;
end;

function TProductsController.CreateProduct(body : TCreateBody) : IActionResult;
begin
  if body = nil then
  begin
    Result := BadRequest('{"error":"Body required"}');
    Exit;
  end;
  try
    fService.AddProduct(body.Name, body.Category, body.Price);
    Result := StatusCode(201, '{"created":true}');
  except
    on E : EValidationException do
      Result := BadRequest(Format('{"error":"%s"}', [E.Message]));
  end;
end;

function TProductsController.UpdateProduct(id : Integer; body : TCreateBody) : IActionResult;
begin
  if body = nil then
  begin
    Result := BadRequest('{"error":"Body required"}');
    Exit;
  end;
  try
    fService.UpdateProduct(id, body.Name, body.Category, body.Price);
    Result := Ok('{"updated":true}');
  except
    on E : ENotFoundException do Result := NotFound(E.Message);
    on E : EValidationException do Result := BadRequest(E.Message);
  end;
end;

function TProductsController.Delete(id : Integer) : IActionResult;
begin
  try
    fService.DeleteProduct(id);
    Result := StatusCode(204);
  except
    on E : ENotFoundException do
      Result := NotFound(E.Message);
  end;
end;

initialization
  RegisterController(TProductsController);

end.
```

---

## Step 5 — Startup (Composition Root)

`Startup.pas` is **the only file that imports all layers**. Everything is wired here via DI:

```pascal
unit Startup;

{ Composition Root — single point that knows all layers.
  Registers: Infrastructure → Domain → Application → Presentation. }

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Quick.Core.Extensions.Entity,
  Quick.Core.Entity.Config,
  // Domain
  Domain.Product,
  // Application
  Application.Service.Product,
  // Infrastructure
  Infrastructure.Repository.Product,
  // Presentation
  Controller.Products;

type
  TStartup = class(TStartupMvc)
  public
    class procedure ConfigureServices(services : TServiceCollection); override;
    class procedure Configure(app : TMVCServer); override;
  end;

implementation

class procedure TStartup.ConfigureServices(services : TServiceCollection);
begin
  services
    .AddLogging(TLoggerBuilder.GetBuilder
      .AddConsole(procedure(o : TConsoleLoggerOptions)
        begin
          o.LogLevel        := LOG_DEBUG;
          o.ShowEventColors := True;
          o.ShowTimeStamp   := True;
          o.Enabled         := True;
        end)
      .Build)

    // ── Infrastructure Layer ──────────────────────────────────────────
    // DBContext (Scoped — one instance per HTTP request)
    .Extension<TEntityServiceExtension>
      .AddDBContext<TShopContext>(procedure(o : IDBConnectionOptions)
        begin
          o.UseSQLite;
          o.Database := '.\shop_clean.db';
        end);

  // Repository: IProductRepository → TProductRepository (Scoped)
  // The factory injects TShopContext from the container
  services.AddScoped<IProductRepository, TProductRepository>('',
    function : TProductRepository
    begin
      Result := TProductRepository.Create(
        services.Resolve<TShopContext>);
    end);

  // ── Application Layer ─────────────────────────────────────────────
  // Service: IProductService → TProductAppService (Scoped)
  // DI injects IProductRepository automatically
  services.AddScoped<IProductService, TProductAppService>;
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .AddController(TProductsController)
    .UseRouting
    .UseMVC;
end;

end.
```

---

## Step 6 — Entry point and tests

```pascal
program CleanArchitectureApi;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Domain.Product in 'domain\Domain.Product.pas',
  Application.Service.Product in 'application\Application.Service.Product.pas',
  Infrastructure.Repository.Product in 'infrastructure\Infrastructure.Repository.Product.pas',
  Controller.Products in 'presentation\Controller.Products.pas';

var
  Server : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    cout('Starting CleanArchitectureApi on http://localhost:8080 ...', etInfo);
    Server := TMvcServer.Create('127.0.0.1', 8080, False);
    try
      Server.UseStartup<TStartup>;
      cout('Press [Enter] to stop.', ccYellow);
      Server.Start;
    finally
      Server.Free;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
```

```bash
# Create product
curl -X POST http://localhost:8080/api/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Laptop","category":"Electronics","price":999.99}'

# List
curl http://localhost:8080/api/products

# Update
curl -X PUT http://localhost:8080/api/products/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"Laptop Pro","category":"Electronics","price":1299.99}'

# Delete
curl -X DELETE http://localhost:8080/api/products/1
```

---

## Benefits of this architecture

| Benefit | How it achieves it |
|---------|-------------------|
| **Testability** | `TProductAppService` is tested with an in-memory mock repository without a database |
| **Replaceability** | Switching SQLite → PostgreSQL only affects `Infrastructure.Repository` |
| **Framework independence** | Domain and Application do not import QuickCore.Mvc |
| **Separation of concerns** | Validation in Application, HTTP in Presentation, SQL in Infrastructure |
| **Evolvability** | Adding a new use-case does not touch the controller or database |

---

## Testing the Application Layer in isolation

```pascal
// Test without a database — in-memory repository
type
  TInMemoryProductRepository = class(TInterfacedObject, IProductRepository)
  private
    fItems : TList<TProduct>;
  public
    constructor Create;
    destructor Destroy; override;
    function GetAll  : TList<TProduct>;
    function GetById (const aId : TAutoID) : TProduct;
    function Add     (aProduct : TProduct) : Boolean;
    function Update  (aProduct : TProduct) : Boolean;
    function Delete  (const aId : TAutoID) : Boolean;
  end;

// En el test:
var
  repo    : IProductRepository;
  service : IProductService;
begin
  repo    := TInMemoryProductRepository.Create;
  service := TProductAppService.Create(repo);

  service.AddProduct('Laptop', 'Electronics', 999.99);
  Assert(service.GetAll.Count = 1);
  Assert(service.GetAll[0].Name = 'Laptop');
end;
```

---

## See also

- [Tutorial 2 — CRUD with Entity](CRUD-with-Entity.md) — ORM without layers (simpler)
- [Dependency Injection](../wiki/Dependency-Injection.md) — Scoped/Singleton lifetimes
- [API Reference — Entity](../API-Reference.md#7-entity-orm)
- [ANALYSIS.md](../../ANALYSIS.md) — framework architecture analysis
