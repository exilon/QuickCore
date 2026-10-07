# Tutorial 6 — Documentation with Swagger / OpenAPI

> **Estimated time:** 20 minutes  
> **Level:** Beginner-Intermediate  
> **Reference sample:** `samples/delphi/SwaggerSample` (S-25)

Swagger integrates an **interactive visual interface** into your API: it documents all endpoints, allows testing them from the browser, and generates an OpenAPI 3.0 document in JSON. In this tutorial you will add it to an existing API with a single line, then enrich the documentation with attributes.

---

## What does Swagger provide in QuickCore?

| URL | Content |
|-----|---------|
| `GET /swagger` | Swagger UI (interactive HTML) |
| `GET /swagger/v1/swagger.json` | OpenAPI 3.0 document in JSON |

The generator reads `[Route]`, `[HttpGet]`, `[HttpPost]`, `[FromBody]`, `[FromQuery]`, `[ProducesResponseType]`, and `[SwaggerOperation]` attributes via RTTI at startup.

---

## Tutorial architecture

```
SwaggerApi/
├── SwaggerApi.dpr
├── Startup.pas
├── Models.pas              ← DTOs with published properties
└── controllers/
  └── Controller.Products.pas  ← CRUD with Swagger attributes
```

---

## Step 1 — Models

Create `Models.pas`. `published` properties appear in the OpenAPI document schema:

```pascal
unit Models;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.SyncObjs;

type
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

  // In-memory data service (injectable via DI)
  IProductService = interface
  ['{D1E2F3A4-B5C6-4D7E-8F9A-0B1C2D3E4F5A}']
    function GetAll   : TArray<TProduct>;
    function GetById  (aId : Integer) : TProduct;
    function Add      (aDto : TNewProduct) : TProduct;
    function Update   (aId : Integer; aDto : TNewProduct) : TProduct;
    procedure Delete  (aId : Integer);
  end;

implementation

end.
```

---

## Step 2 — Controller with Swagger attributes

The `[SwaggerOperation]` and `[ProducesResponseType]` attributes enrich the generated document:

```pascal
unit Controller.Products;

interface

uses
  System.SysUtils,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Mvc.Middleware.Swagger,
  Models;

type
  [Route('api/products')]
  [ApiController]
  TProductsController = class(THttpController)
  private
    fService : IProductService;
  public
    constructor Create(aService : IProductService);
  published
    // ── GET /api/products ─────────────────────────────────────────────
    [HttpGet]
    [SwaggerOperation(
      'List all products',
      'Returns the full product catalog.',
      'Products')]
    [ProducesResponseType(200, 'Array of TProduct')]
    function GetAll : IActionResult;

    // ── GET /api/products/{id} ─────────────────────────────────────────
      // ── GET /api/products/{id} ────────────────────────────────────────
    [HttpGet('{id:int}')]
    [SwaggerOperation(
      'Get product by ID',
      'Returns a single product by its integer ID.',
      'Products')]
    [ProducesResponseType(200, 'TProduct')]
    [ProducesResponseType(404, 'Product not found')]
    function GetById(id : Integer) : IActionResult;

    // ── POST /api/products ─────────────────────────────────────────────
      // ── POST /api/products ────────────────────────────────────────────
    [HttpPost]
    [SwaggerOperation(
      'Create product',
      'Adds a new product. Name is required.',
      'Products')]
    [ProducesResponseType(201, 'Created TProduct')]
    [ProducesResponseType(400, 'Validation error')]
    function CreateProduct([FromBody] dto : TNewProduct) : IActionResult;

    // ── PUT /api/products/{id} ─────────────────────────────────────────
      // ── PUT /api/products/{id} ────────────────────────────────────────
    [HttpPut('{id:int}')]
    [SwaggerOperation(
      'Update product',
      'Replaces an existing product''s data.',
      'Products')]
    [ProducesResponseType(200, 'Updated TProduct')]
    [ProducesResponseType(404, 'Product not found')]
    function Update(id : Integer; [FromBody] dto : TNewProduct) : IActionResult;

    // ── DELETE /api/products/{id} ──────────────────────────────────────
      // ── DELETE /api/products/{id} ─────────────────────────────────────
    [HttpDelete('{id:int}')]
    [SwaggerOperation(
      'Delete product',
      'Removes a product from the catalogue.',
      'Products')]
    [ProducesResponseType(204, 'Deleted')]
    [ProducesResponseType(404, 'Product not found')]
    function DeleteProduct(id : Integer) : IActionResult;
  end;

implementation

{ TProductsController }

constructor TProductsController.Create(aService : IProductService);
begin
  inherited Create;
  fService := aService;
end;

function TProductsController.GetAll : IActionResult;
begin
  // Real serialization: use TJsonSerializer over fService.GetAll
  Result := Json('[{"id":1,"name":"Laptop","price":999.99}]');
end;

function TProductsController.GetById(id : Integer) : IActionResult;
var
  product : TProduct;
begin
  product := fService.GetById(id);
  if product = nil then
    Result := NotFound(Format('Product %d not found', [id]))
  else
    Result := Json(Format(
      '{"id":%d,"name":"%s","price":%g}',
      [product.Id, product.Name, product.Price]));
end;

function TProductsController.CreateProduct(dto : TNewProduct) : IActionResult;
begin
  if (dto = nil) or dto.Name.IsEmpty then
  begin
    Result := BadRequest('{"error":"Name is required"}');
    Exit;
  end;
  // fService.Add(dto) → returns TProduct with assigned Id
  Result := StatusCode(201, Format(
    '{"id":1,"name":"%s","price":%g}',
    [dto.Name, dto.Price]));
end;

function TProductsController.Update(id : Integer; dto : TNewProduct) : IActionResult;
var
  product : TProduct;
begin
  product := fService.GetById(id);
  if product = nil then
    Result := NotFound(Format('Product %d not found', [id]))
  else
    Result := Ok(Format(
      '{"id":%d,"name":"%s","price":%g}',
      [id, dto.Name, dto.Price]));
end;

function TProductsController.DeleteProduct(id : Integer) : IActionResult;
begin
  fService.Delete(id);
  Result := StatusCode(204);
end;

initialization
  RegisterController(TProductsController);

end.
```

---

## Step 3 — Enable Swagger in Startup

The key is **a single call** `.UseSwagger(...)` **before** `.UseRouting`:

```pascal
unit Startup;

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Models,
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
    // Register the product service as Singleton via DI
    .AddSingleton<IProductService, TProductService>;
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .AddController(TProductsController)
    // UseSwagger must come BEFORE UseRouting to intercept /swagger*
    .UseSwagger(
      'Products API',   // título
      '1.0.0',          // versión
      'QuickCore CRUD API with OpenAPI 3.0 documentation')
    .UseRouting
    .UseMVC;
end;

end.
```

---

## Step 4 — Entry point

```pascal
program SwaggerApi;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Models in 'Models.pas',
  Controller.Products in 'controllers\Controller.Products.pas';

var
  Server : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    cout('Starting SwaggerApi on http://localhost:8080 ...', etInfo);
    cout('Swagger UI   : http://localhost:8080/swagger', ccCyan);
    cout('OpenAPI JSON: http://localhost:8080/swagger/v1/swagger.json', ccCyan);
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

---

## Step 5 — View and test

### Swagger UI (browser)

Open `http://localhost:8080/swagger`:

- You will see all endpoints grouped by tag (`Products`).
- Each endpoint shows parameters, request body, and possible responses.
- You can execute them directly with **Try it out**.

### OpenAPI document (JSON)

```bash
curl http://localhost:8080/swagger/v1/swagger.json | python -m json.tool
```

Abbreviated response:
```json
{
  "openapi": "3.0.0",
  "info": {
    "title": "Products API",
    "version": "1.0.0",
    "description": "QuickCore CRUD API with OpenAPI 3.0 documentation"
  },
  "paths": {
    "/api/products": {
      "get": {
        "summary": "List all products",
        "tags": ["Products"],
        "responses": { "200": { "description": "Array of TProduct" } }
      },
      "post": { ... }
    },
    "/api/products/{id}": { ... }
  }
}
```

---

## Swagger attribute reference

| Attribute | Parameters | Description |
|-----------|-----------|-------------|
| `[SwaggerOperation(summary, description, tag)]` | 3 strings | Documents the action |
| `[ProducesResponseType(statusCode, description)]` | int + string | Documents a possible response |
| `[ApiController]` | — | Marks the controller as API (excludes from views) |
| `[Route('path')]` | string | Route prefix; appears in the OpenAPI path |
| `[HttpGet('sub/{id}')]` | string | Sub-route + HTTP method |
| `[FromBody]` | — | Parameter comes from the body → generates `requestBody` |
| `[FromQuery('name')]` | string | Query string parameter |
| `[FromHeader('name')]` | string | HTTP header parameter |

---

## Combining with JWT (protecting Swagger UI)

If your API uses JWT, you can add the **Authorize** button to Swagger:

```pascal
// In Startup.Configure, chain AddSecurityDefinition after UseSwagger:
app
  .UseSwagger('My API', '1.0.0', 'Description')
  .UseSwaggerBearerAuth   // adds Authorize button + Bearer scheme
  .UseRouting
  .UseAuthentication
  .UseAuthorization
  .UseMVC;
```

You will then be able to paste your JWT into the UI and test protected endpoints directly.

---

## Summary

With **a single line** `.UseSwagger(title, version, description)` you get:

- OpenAPI 3.0 document at `/swagger/v1/swagger.json`
- Interactive UI at `/swagger`
- Documentation generated automatically by RTTI
- Optional enrichment with `[SwaggerOperation]` and `[ProducesResponseType]`

---

## See also

- [Tutorial 2 — CRUD with Entity](CRUD-with-Entity.md) — add real persistence
- [Tutorial 4 — Auth with JWT](Auth-with-JWT.md) — combine Swagger with authentication
- [API Reference — MVC](../API-Reference.md#3-mvc--http-server)
