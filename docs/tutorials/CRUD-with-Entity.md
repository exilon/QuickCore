# Tutorial 2 — CRUD with Entity (SQLite)

> **Estimated time:** 25 minutes  
> **Level:** Intermediate  
> **Reference sample:** `samples/delphi/WebApiWithDatabase` (S-07)

In this tutorial you will add a SQLite database to your API using the QuickCore Entity ORM. You will build a products controller with all 4 complete CRUD operations.

---

## Prerequisites

- Tutorial 1 completed (or equivalent: knowing how to create a `TStartup` and a basic controller)
- Same dependencies as Tutorial 1

---

## Tutorial architecture

```
WebApiWithDatabase/
├── WebApiWithDatabase.dpr
├── Startup.pas
├── Models.pas             ← entity + DbContext
└── controllers/
    └── Controller.Products.pas
```

---

## Step 1 — Define the entity and DbContext

Create `Models.pas`:

```pascal
unit Models;

interface

uses
  Quick.Core.Entity,
  Quick.Core.Entity.DAO;

type
  [Table('products')]
  TProductEntity = class(TEntity)
  private
    FId       : TAutoID;
    FName     : string;
    FCategory : string;
    FPrice    : Double;
    FStock    : Integer;
  published
    [Key]
    property Id       : TAutoID read FId       write FId;
    [StringLength(100)]
    property Name     : string  read FName     write FName;
    [StringLength(50)]
    property Category : string  read FCategory write FCategory;
    [DecimalLength(10, 2)]
    property Price    : Double  read FPrice    write FPrice;
    property Stock    : Integer read FStock    write FStock;
  end;

  TShopContext = class(TDBContext)
  private
    FProducts : TDBSet<TProductEntity>;
  public
    property Products : TDBSet<TProductEntity> read FProducts write FProducts;
  end;

implementation

end.
```

**Most common column attributes:**

| Attribute | Description |
|-----------|-------------|
| `[Key]` | Primary key |
| `[Table('name')]` | Table name in the database |
| `[StringLength(n)]` | `VARCHAR(n)` |
| `[DecimalLength(p, s)]` | `DECIMAL(p, s)` |
| `[NotNull]` | NOT NULL column |
| `[Unique]` | UNIQUE constraint |
| `[MapColumn('col')]` | Maps to a different column name |

---

## Step 2 — Create the CRUD controller

Create `controllers/Controller.Products.pas`:

```pascal
unit Controller.Products;

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Models;

type
  [Route('api/products')]
  [ApiController]
  TProductsController = class(THttpController)
  private
    fContext: TShopContext;
  public
    constructor Create(aContext: TShopContext);
  published
    [HttpGet]
    function GetAll: IActionResult;

    [HttpGet('{id}')]
    function GetById(id: Integer): IActionResult;

    [HttpPost]
    function AddProduct([FromBody] body: TProductEntity): IActionResult;

    [HttpPut('{id}')]
    function UpdateProduct(id: Integer; [FromBody] body: TProductEntity): IActionResult;

    [HttpDelete('{id}')]
    function Delete(id: Integer): IActionResult;
  end;

implementation

uses
  System.SysUtils,
  Quick.Core.Entity.DAO,
  Quick.JsonSerializer;

constructor TProductsController.Create(aContext: TShopContext);
begin
  inherited Create;
  fContext := aContext;
end;

function TProductsController.GetAll: IActionResult;
var
  res : IEntityResult<TProductEntity>;
  arr : TArray<TProductEntity>;
  sb  : TStringBuilder;
  i   : Integer;
  p   : TProductEntity;
begin
  res := fContext.Products.Where('').Select;
  arr := res.ToArray;
  sb  := TStringBuilder.Create;
  try
    sb.Append('[');
    for i := 0 to High(arr) do
    begin
      if i > 0 then sb.Append(',');
      p := arr[i];
      sb.AppendFormat(
        '{"Id":%d,"Name":"%s","Category":"%s","Price":%g,"Stock":%d}',
        [p.Id, p.Name, p.Category, p.Price, p.Stock]);
    end;
    sb.Append(']');
    Result := Json(sb.ToString);
  finally
    sb.Free;
  end;
end;

function TProductsController.GetById(id: Integer): IActionResult;
var
  p: TProductEntity;
begin
  p := fContext.Products.Where('Id = %d', [id]).SelectFirst;
  if p = nil then
    Result := NotFound
  else
  try
    Result := Json(TJsonSerializer.Serialize(p));
  finally
    p.Free;
  end;
end;

function TProductsController.AddProduct(body: TProductEntity): IActionResult;
begin
  fContext.Products.Add(body);
  Result := StatusCode(201, TJsonSerializer.Serialize(body));
end;

function TProductsController.UpdateProduct(id: Integer; body: TProductEntity): IActionResult;
begin
  body.Id := id;
  fContext.Products.Update(body);
  Result := Ok(TJsonSerializer.Serialize(body));
end;

function TProductsController.Delete(id: Integer): IActionResult;
begin
  fContext.Products.Where('Id = %d', [id]).Delete;
  Result := StatusCode(204);
end;

initialization
  RegisterController(TProductsController);

end.
```

> **Security note:** Parameters in `Where('Id = %d', [id])` are safely formatted by the ORM. Never concatenate user values directly into the SQL string.

---

## Step 3 — Register the DbContext in Startup

Create `Startup.pas`:

```pascal
unit Startup;

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Extensions.Entity,
  Quick.Core.Entity.Config,
  Quick.Core.Logging,
  Models,
  Controller.Products;

type
  TStartup = class(TStartupMvc)
  public
    class procedure ConfigureServices(services: TServiceCollection); override;
    class procedure Configure(app: TMVCServer); override;
  end;

implementation

class procedure TStartup.ConfigureServices(services: TServiceCollection);
begin
  services
    .AddLogging(TLoggerBuilder.GetBuilder
      .AddConsole(procedure(o: TConsoleLoggerOptions)
        begin
          o.LogLevel        := LOG_DEBUG;
          o.ShowEventColors := True;
          o.ShowTimeStamp   := True;
          o.Enabled         := True;
        end)
      .Build)
    // Register the DbContext with SQLite
    .Extension<TEntityServiceExtension>
      .AddDBContext<TShopContext>(procedure(o: IDBConnectionOptions)
        begin
          o.UseSQLite;
          o.Database := '.\shop.db';   // relative path to the executable
        end);
end;

class procedure TStartup.Configure(app: TMVCServer);
begin
  app
    .AddControllers
    .AddController(TProductsController)
    .UseRouting
    .UseMVC;
end;

end.
```

When calling `AddDBContext<TShopContext>`, the framework:
1. Creates the database if it does not exist.
2. Creates the `products` table if it does not exist.
3. Registers `TShopContext` in the DI container with **Scoped** lifetime.

---

## Step 4 — Entry point

Create `WebApiWithDatabase.dpr`:

```pascal
program WebApiWithDatabase;

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
  Server: TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    cout('Starting WebApiWithDatabase on http://localhost:8080 ...', etInfo);
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

## Step 5 — Build and test

**Build:** Press `F9` in Delphi.

### List all products (empty initially)

```bash
curl http://localhost:8080/api/products
# []
```

### Create a product (POST)

```bash
curl -X POST http://localhost:8080/api/products \
  -H "Content-Type: application/json" \
  -d '{"Name":"Laptop","Category":"Electronics","Price":999.99,"Stock":10}'
# {"Id":1,"Name":"Laptop","Category":"Electronics","Price":999.99,"Stock":10}
```

### Get by ID (GET)

```bash
curl http://localhost:8080/api/products/1
# {"Id":1,"Name":"Laptop","Category":"Electronics","Price":999.99,"Stock":10}
```

### Update (PUT)

```bash
curl -X PUT http://localhost:8080/api/products/1 \
  -H "Content-Type: application/json" \
  -d '{"Name":"Laptop Pro","Category":"Electronics","Price":1299.99,"Stock":5}'
# {"Id":1,"Name":"Laptop Pro","Category":"Electronics","Price":1299.99,"Stock":5}
```

### Delete (DELETE)

```bash
curl -X DELETE http://localhost:8080/api/products/1
# HTTP 204 No Content
```

---

## Step 6 (optional) — Add WHERE filter

To filter products by category:

```pascal
[HttpGet('by-category/{category}')]
function GetByCategory(category: string): IActionResult;
```

```pascal
function TProductsController.GetByCategory(category: string): IActionResult;
var
  res : IEntityResult<TProductEntity>;
  arr : TArray<TProductEntity>;
begin
  // The '%s' parameter is passed safely through the value array
  res := fContext.Products
           .Where('Category = %s', [category])
           .Select;
  arr := res.ToArray;
  // ... serialize and return
  Result := Ok(TJsonSerializer.Serialize(arr));
end;
```

---

## Endpoint summary

| Endpoint | Method | Description |
|----------|--------|-------------|
| `GET /api/products` | GET | List all |
| `GET /api/products/{id}` | GET | Get by ID (404 if not found) |
| `POST /api/products` | POST | Create new (201 Created) |
| `PUT /api/products/{id}` | PUT | Update existing |
| `DELETE /api/products/{id}` | DELETE | Delete (204 No Content) |
| `GET /api/products/by-category/{cat}` | GET | Filter by category |

---

**Next step:** [Tutorial 3 — Auth with ApiKey](Auth-with-ApiKey.md) — protect these endpoints with authentication.

---

## See also

- [Entity ORM](../wiki/Entity-ORM.md)
- [Dependency Injection](../wiki/Dependency-Injection.md)
- [API Reference — Entity](../API-Reference.md#7-entity-orm)


---

## Requisitos previos

- Tutorial 1 completado (o equivalente: saber crear un `TStartup` y un controller básico)
- Las mismas dependencias del Tutorial 1

---

## Arquitectura del tutorial

```
WebApiWithDatabase/
├── WebApiWithDatabase.dpr
├── Startup.pas
├── Models.pas             ← entidad + DbContext
└── controllers/
    └── Controller.Products.pas
```

---

## Paso 1 — Definir la entidad y el DbContext

Crea `Models.pas`:

```pascal
unit Models;

interface

uses
  Quick.Core.Entity,
  Quick.Core.Entity.DAO;

type
  [Table('products')]
  TProductEntity = class(TEntity)
  private
    FId       : TAutoID;
    FName     : string;
    FCategory : string;
    FPrice    : Double;
    FStock    : Integer;
  published
    [Key]
    property Id       : TAutoID read FId       write FId;
    [StringLength(100)]
    property Name     : string  read FName     write FName;
    [StringLength(50)]
    property Category : string  read FCategory write FCategory;
    [DecimalLength(10, 2)]
    property Price    : Double  read FPrice    write FPrice;
    property Stock    : Integer read FStock    write FStock;
  end;

  TShopContext = class(TDBContext)
  private
    FProducts : TDBSet<TProductEntity>;
  public
    property Products : TDBSet<TProductEntity> read FProducts write FProducts;
  end;

implementation

end.
```

**Atributos de columna más usados:**

| Atributo | Descripción |
|----------|-------------|
| `[Key]` | Clave primaria |
| `[Table('nombre')]` | Nombre de la tabla en la base de datos |
| `[StringLength(n)]` | `VARCHAR(n)` |
| `[DecimalLength(p, s)]` | `DECIMAL(p, s)` |
| `[NotNull]` | Columna NOT NULL |
| `[Unique]` | Restricción UNIQUE |
| `[MapColumn('col')]` | Mapea a un nombre de columna diferente |

---

## Paso 2 — Crear el controller CRUD

Crea `controllers/Controller.Products.pas`:

```pascal
unit Controller.Products;

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Models;

type
  [Route('api/products')]
  [ApiController]
  TProductsController = class(THttpController)
  private
    fContext: TShopContext;
  public
    constructor Create(aContext: TShopContext);
  published
    [HttpGet]
    function GetAll: IActionResult;

    [HttpGet('{id}')]
    function GetById(id: Integer): IActionResult;

    [HttpPost]
    function AddProduct([FromBody] body: TProductEntity): IActionResult;

    [HttpPut('{id}')]
    function UpdateProduct(id: Integer; [FromBody] body: TProductEntity): IActionResult;

    [HttpDelete('{id}')]
    function Delete(id: Integer): IActionResult;
  end;

implementation

uses
  System.SysUtils,
  Quick.Core.Entity.DAO,
  Quick.JsonSerializer;

constructor TProductsController.Create(aContext: TShopContext);
begin
  inherited Create;
  fContext := aContext;
end;

function TProductsController.GetAll: IActionResult;
var
  res : IEntityResult<TProductEntity>;
  arr : TArray<TProductEntity>;
  sb  : TStringBuilder;
  i   : Integer;
  p   : TProductEntity;
begin
  res := fContext.Products.Where('').Select;
  arr := res.ToArray;
  sb  := TStringBuilder.Create;
  try
    sb.Append('[');
    for i := 0 to High(arr) do
    begin
      if i > 0 then sb.Append(',');
      p := arr[i];
      sb.AppendFormat(
        '{"Id":%d,"Name":"%s","Category":"%s","Price":%g,"Stock":%d}',
        [p.Id, p.Name, p.Category, p.Price, p.Stock]);
    end;
    sb.Append(']');
    Result := Json(sb.ToString);
  finally
    sb.Free;
  end;
end;

function TProductsController.GetById(id: Integer): IActionResult;
var
  p: TProductEntity;
begin
  p := fContext.Products.Where('Id = %d', [id]).SelectFirst;
  if p = nil then
    Result := NotFound
  else
  try
    Result := Json(TJsonSerializer.Serialize(p));
  finally
    p.Free;
  end;
end;

function TProductsController.AddProduct(body: TProductEntity): IActionResult;
begin
  fContext.Products.Add(body);
  Result := StatusCode(201, TJsonSerializer.Serialize(body));
end;

function TProductsController.UpdateProduct(id: Integer; body: TProductEntity): IActionResult;
begin
  body.Id := id;
  fContext.Products.Update(body);
  Result := Ok(TJsonSerializer.Serialize(body));
end;

function TProductsController.Delete(id: Integer): IActionResult;
begin
  fContext.Products.Where('Id = %d', [id]).Delete;
  Result := StatusCode(204);
end;

initialization
  RegisterController(TProductsController);

end.
```

> **Nota de seguridad:** Los parámetros en `Where('Id = %d', [id])` se formatean de forma segura por el ORM. Nunca concatenes valores de usuario directamente en la cadena SQL.

---

## Paso 3 — Registrar el DbContext en Startup

Crea `Startup.pas`:

```pascal
unit Startup;

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Extensions.Entity,
  Quick.Core.Entity.Config,
  Quick.Core.Logging,
  Models,
  Controller.Products;

type
  TStartup = class(TStartupMvc)
  public
    class procedure ConfigureServices(services: TServiceCollection); override;
    class procedure Configure(app: TMVCServer); override;
  end;

implementation

class procedure TStartup.ConfigureServices(services: TServiceCollection);
begin
  services
    .AddLogging(TLoggerBuilder.GetBuilder
      .AddConsole(procedure(o: TConsoleLoggerOptions)
        begin
          o.LogLevel        := LOG_DEBUG;
          o.ShowEventColors := True;
          o.ShowTimeStamp   := True;
          o.Enabled         := True;
        end)
      .Build)
    // Registrar el DbContext con SQLite
    .Extension<TEntityServiceExtension>
      .AddDBContext<TShopContext>(procedure(o: IDBConnectionOptions)
        begin
          o.UseSQLite;
          o.Database := '.\shop.db';   // ruta relativa al ejecutable
        end);
end;

class procedure TStartup.Configure(app: TMVCServer);
begin
  app
    .AddControllers
    .AddController(TProductsController)
    .UseRouting
    .UseMVC;
end;

end.
```

Al llamar a `AddDBContext<TShopContext>`, el framework:
1. Crea la base de datos si no existe.
2. Crea la tabla `products` si no existe.
3. Registra `TShopContext` en el contenedor DI con ciclo de vida **Scoped**.

---

## Paso 4 — Punto de entrada

Crea `WebApiWithDatabase.dpr`:

```pascal
program WebApiWithDatabase;

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
  Server: TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    cout('Starting WebApiWithDatabase on http://localhost:8080 ...', etInfo);
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

## Paso 5 — Compilar y probar

**Compilar:** `F9` en Delphi.

### Listar todos los productos (vacío inicialmente)

```bash
curl http://localhost:8080/api/products
# []
```

### Crear un producto (POST)

```bash
curl -X POST http://localhost:8080/api/products \
  -H "Content-Type: application/json" \
  -d '{"Name":"Laptop","Category":"Electronics","Price":999.99,"Stock":10}'
# {"Id":1,"Name":"Laptop","Category":"Electronics","Price":999.99,"Stock":10}
```

### Obtener por ID (GET)

```bash
curl http://localhost:8080/api/products/1
# {"Id":1,"Name":"Laptop","Category":"Electronics","Price":999.99,"Stock":10}
```

### Actualizar (PUT)

```bash
curl -X PUT http://localhost:8080/api/products/1 \
  -H "Content-Type: application/json" \
  -d '{"Name":"Laptop Pro","Category":"Electronics","Price":1299.99,"Stock":5}'
# {"Id":1,"Name":"Laptop Pro","Category":"Electronics","Price":1299.99,"Stock":5}
```

### Eliminar (DELETE)

```bash
curl -X DELETE http://localhost:8080/api/products/1
# HTTP 204 No Content
```

---

## Paso 6 (opcional) — Añadir filtro WHERE

Para filtrar productos por categoría:

```pascal
[HttpGet('by-category/{category}')]
function GetByCategory(category: string): IActionResult;
```

```pascal
function TProductsController.GetByCategory(category: string): IActionResult;
var
  res : IEntityResult<TProductEntity>;
  arr : TArray<TProductEntity>;
begin
  // El parámetro '%s' se pasa de forma segura a través del array de valores
  res := fContext.Products
           .Where('Category = %s', [category])
           .Select;
  arr := res.ToArray;
  // ... serializar y devolver
  Result := Ok(TJsonSerializer.Serialize(arr));
end;
```

---

## Resumen de endpoints

| Endpoint | Método | Descripción |
|----------|--------|-------------|
| `GET /api/products` | GET | Listar todos |
| `GET /api/products/{id}` | GET | Obtener por ID (404 si no existe) |
| `POST /api/products` | POST | Crear nuevo (201 Created) |
| `PUT /api/products/{id}` | PUT | Actualizar existente |
| `DELETE /api/products/{id}` | DELETE | Eliminar (204 No Content) |
| `GET /api/products/by-category/{cat}` | GET | Filtrar por categoría |

---

**Siguiente paso:** [Tutorial 3 — Auth con ApiKey](Auth-with-ApiKey.md) — proteger estos endpoints con autenticación.

---

## Ver también

- [Entity ORM](../wiki/Entity.md)
- [Dependency Injection](../wiki/Dependency-Injection.md)
- [API Reference — Entity](../API-Reference.md#7-entity-orm)
