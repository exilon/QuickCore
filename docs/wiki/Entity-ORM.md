# Entity / ORM

> Modules: `Quick.Core.Entity`, `Quick.Core.Entity.DAO`, `Quick.Core.Entity.Database`  
> .NET equivalent: `Microsoft.EntityFrameworkCore`

QuickCore includes a full RTTI-based ORM with support for multiple database providers, LINQ, migrations, navigation properties, soft delete, and more.

---

## Table of contents

1. [Supported providers](#supported-providers)
2. [Defining entities](#defining-entities)
3. [Entity base classes](#entity-base-classes)
4. [Mapping attributes](#mapping-attributes)
5. [DbContext](#dbcontext)
6. [Register the context (DI)](#register-the-context-di)
7. [CRUD operations](#crud-operations)
8. [LINQ queries](#linq-queries)
9. [Migrations](#migrations)
10. [Navigation properties](#navigation-properties)
11. [Repository Pattern](#repository-pattern)
12. [Unit of Work](#unit-of-work)
13. [Soft Delete](#soft-delete)
14. [Optimistic Concurrency](#optimistic-concurrency)
15. [Data seeding](#data-seeding)
16. [See also](#see-also)

---

## Supported providers

| Provider | `TDBProvider` | Engine unit |
|----------|--------------|-------------|
| SQLite | `dbSQLite` | `Quick.Core.Entity.Engine.ADO` / FireDAC |
| SQL Server | `dbMSSQL` | `Quick.Core.Entity.Engine.ADO` / FireDAC |
| MySQL | `dbMySQL` | `Quick.Core.Entity.Engine.FireDAC` |
| MS Access | `dbMSAccess2007` | `Quick.Core.Entity.Engine.ADO` |
| PostgreSQL | `dbPostgreSQL` | `Quick.Core.Entity.Engine.FireDAC` |

---

## Defining entities

An entity is a class that inherits from `TEntity` (or one of its variants). `published` properties are automatically mapped to columns.

```pascal
uses Quick.Core.Entity;

type
  [Table('products')]
  TProduct = class(TEntity)
  private
    fId       : TAutoID;
    fName     : string;
    fPrice    : Double;
    fStock    : Integer;
  published
    [Key]
    property Id    : TAutoID read fId    write fId;
    [StringLength(100)]
    property Name  : string  read fName  write fName;
    [DecimalLength(10, 2)]
    property Price : Double  read fPrice write fPrice;
    property Stock : Integer read fStock write fStock;
  end;
```

> **Note:** `TAutoID` is an alias for `Int64` indicating an auto-increment column.

---

## Entity base classes

| Class | Extra fields | Recommended use |
|-------|-------------|----------------|
| `TEntity` | — | Basic entity |
| `TEntityTS` | `CreatedAt`, `UpdatedAt` | With automatic timestamps |
| `TEntitySD` | `IsDeleted` | Soft delete |
| `TEntityTSSD` | `CreatedAt`, `UpdatedAt`, `IsDeleted` | Timestamps + soft delete |
| `TEntityRV` | `RowVersion` | Optimistic concurrency |
| `TEntityAudit` | `CreatedBy`, `UpdatedBy` | Audit fields |

```pascal
// Entity with timestamps and soft delete
type
  TOrder = class(TEntityTSSD)
  published
    property CustomerId : Integer read fCustomerId write fCustomerId;
    property Total      : Double  read fTotal      write fTotal;
  end;
```

---

## Mapping attributes

| Attribute | Description | EF Core equivalent |
|-----------|-------------|-------------------|
| `[Table('name')]` | Custom table name | `[Table]` |
| `[MapField('col')]` | Custom column name | `[Column]` |
| `[Key]` | Primary key | `[Key]` |
| `[StringLength(n)]` | Maximum string length | `[MaxLength(n)]` |
| `[DecimalLength(p, s)]` | Decimal precision and scale | `[Precision(p, s)]` |
| `[SoftDelete]` | Enables logical deletion | `HasQueryFilter` |
| `[Index('field')]` | Column index | `HasIndex` |
| `[ForeignKey('field')]` | Foreign key | `[ForeignKey]` |
| `[HasMany]` | 1:N relationship | `HasMany` |
| `[HasOne]` | 1:1 relationship | `HasOne` |

---

## DbContext

The context inherits from `TDBContext` and exposes a `TDBSet<T>` for each entity:

```pascal
uses Quick.Core.Entity;

type
  TShopContext = class(TDBContext)
  private
    fProducts : TDBSet<TProduct>;
    fOrders   : TDBSet<TOrder>;
  public
    property Products : TDBSet<TProduct> read fProducts write fProducts;
    property Orders   : TDBSet<TOrder>   read fOrders   write fOrders;
  end;
```

### Configure the connection

```pascal
var
  ctx : TShopContext;
begin
  ctx := TShopContext.Create;
  ctx.Connection.Provider := dbSQLite;
  ctx.Connection.Database := 'shop.db';
  ctx.Connect;
end;
```

---

## Register the context (DI)

```pascal
uses Quick.Core.Extensions.Entity;

// In ConfigureServices:
services.Extension<TEntityServiceExtension>
  .AddDBContext<TShopContext>(procedure(opt: TDbContextOptions)
  begin
    opt.Provider  := dbSQLite;
    opt.Database  := 'shop.db';
  end);
```

### C# equivalent (EF Core)

```csharp
builder.Services.AddDbContext<ShopContext>(opt =>
    opt.UseSqlite("Data Source=shop.db"));
```

Injection in the controller or service constructor:

```pascal
constructor TProductService.Create(aContext: TShopContext);
begin
  fContext := aContext;
end;
```

---

## CRUD operations

```pascal
var
  p : TProduct;
  list : IDBSetResult<TProduct>;
begin
  p := TProduct.Create;
  p.Name  := 'Widget';
  p.Price := 9.99;

  // Insert
  fContext.Products.Add(p);

  // Insert or update
  fContext.Products.AddOrUpdate(p);

  // Update
  p.Price := 12.50;
  fContext.Products.Update(p);

  // Delete
  fContext.Products.Delete(p);

  // Count
  var total := fContext.Products.CountResults;
end;
```

---

## LINQ queries

```pascal
// WHERE with SQL format
var list := fContext.Products
  .Where('Price > ? AND Stock > ?', [10.0, 0])
  .OrderBy('Name')
  .Select;

// WHERE with lambda (in-memory post-filter)
var cheap := fContext.Products
  .Where(function(p: TProduct): Boolean
  begin
    Result := p.Price < 5.0;
  end)
  .Select;

// Top N
var top5 := fContext.Products
  .OrderByDescending('Price')
  .SelectTop(5);

// First record
var first := fContext.Products
  .Where('Name = ?', ['Widget'])
  .SelectFirst;

// Count
var count := fContext.Products
  .Where('Stock > ?', [0])
  .Count;

// Sum
var total := fContext.Products
  .Sum('Price');
```

### C# equivalent

```csharp
var list = context.Products
    .Where(p => p.Price > 10 && p.Stock > 0)
    .OrderBy(p => p.Name)
    .ToList();

var first = context.Products
    .FirstOrDefault(p => p.Name == "Widget");
```

---

## Migrations

**Unit:** `Quick.Core.Entity.Migrations`

Manages database schema evolution transactionally. The `__MigrationsHistory` table is created automatically to record applied migrations.

| Class / Method | Description |
|---------------|-------------|
| `TMigration` | Abstract base class |
| `GetMigrationId` | Unique sortable name, e.g. `'20240101_CreateUsers'` |
| `Up(aDBContext)` | Applies schema changes |
| `Down(aDBContext)` | Reverts schema changes |
| `GetProductVersion` | App version (optional override) |
| `TMigrationsManager.ApplyMigrations(migrations[])` | Applies all pending migrations in order |
| `TMigrationsManager.RollbackLast(migrations[])` | Reverts the last applied migration |
| `TMigrationsManager.GetAppliedMigrations` | List of already-applied IDs |
| `TEntityMigrationsHistory` | Tracking entity (`__MigrationsHistory` table) |

```pascal
uses Quick.Core.Entity.Migrations;

type
  T20260101_CreateProducts = class(TMigration)
  public
    function GetMigrationId: string; override;
    procedure Up(aDBContext: TDBContext); override;
    procedure Down(aDBContext: TDBContext); override;
  end;

function T20260101_CreateProducts.GetMigrationId: string;
begin
  Result := '20260101_CreateProducts';
end;

procedure T20260101_CreateProducts.Up(aDBContext: TDBContext);
begin
  aDBContext.ExecuteSQL(
    'CREATE TABLE products (Id INTEGER PRIMARY KEY, Name VARCHAR(200), Price FLOAT)');
end;

procedure T20260101_CreateProducts.Down(aDBContext: TDBContext);
begin
  aDBContext.ExecuteSQL('DROP TABLE products');
end;

// Apply at startup:
var mgr := TMigrationsManager.Create(myDBContext);
try
  mgr.ApplyMigrations([T20260101_CreateProducts]);
finally
  mgr.Free;
end;
```

### C# equivalent

```csharp
public class CreateProducts : Migration
{
    protected override void Up(MigrationBuilder mb)
        => mb.CreateTable("Products", t => new { ... });
    protected override void Down(MigrationBuilder mb)
        => mb.DropTable("Products");
}
// dotnet ef database update
```

---

## Navigation properties

Automatically loads relationships with `Include`:

```pascal
type
  TOrderLine = class(TEntity)
  published
    [ForeignKey('OrderId')]
    property OrderId   : Integer   read fOrderId   write fOrderId;
    property ProductId : Integer   read fProductId write fProductId;
    property Quantity  : Integer   read fQuantity  write fQuantity;
  end;

  TOrder = class(TEntity)
  published
    property CustomerId : Integer read fCustomerId write fCustomerId;
    [HasMany]
    property Lines : TObjectList<TOrderLine> read fLines write fLines;
  end;

// Query with eager loading
var order := fContext.Orders
  .Include('Lines')
  .Where('Id = ?', [42])
  .SelectFirst;
```

---

## Repository Pattern

**Unit:** `Quick.Core.Entity.Repository`

Abstracts data access behind `IRepository<T>`. The type `T` must inherit from `TEntity`.

| Method | Description |
|--------|-------------|
| `GetById(id)` | Load by primary key (returns nil if not found) |
| `GetAll` | Full list |
| `Add(entity)` | Insert |
| `AddOrUpdate(entity)` | Upsert |
| `Update(entity)` | Update |
| `Delete(entity)` / `DeleteById(id)` | Delete |
| `Count` | Total number of records |
| `Exists(id)` | Check existence |
| `Find(where, params[])` | Parameterized SQL filter → list |
| `FindFirst(where)` | First result or nil |
| `Query` | `IEntityLinqQuery<T>` for fluent queries |

```pascal
uses Quick.Core.Entity.Repository;

// Concrete repository adding domain-specific methods:
type
  IProductRepository = interface(IRepository<TProduct>)
  ['{GUID}']
    function FindByCategory(const aCategory: string): TList<TProduct>;
  end;

  TProductRepository = class(TEntityRepository<TProduct>, IProductRepository)
  public
    constructor Create(aDBSet: TDBSet<TProduct>);
    function FindByCategory(const aCategory: string): TList<TProduct>;
  end;

constructor TProductRepository.Create(aDBSet: TDBSet<TProduct>);
begin
  inherited Create(aDBSet, 'Id');
end;

function TProductRepository.FindByCategory(const aCategory: string): TList<TProduct>;
begin
  Result := Find('Category = ?', [aCategory]);
end;

// DI registration:
services.AddScoped<IProductRepository>(function(sp: IServiceProvider): IProductRepository
begin
  Result := TProductRepository.Create(sp.Resolve<TShopContext>.Products);
end);
```

---

## Unit of Work

**Unit:** `Quick.Core.Entity.UnitOfWork`

Groups operations into an atomic transaction. `Execute` commits if the block completes without exceptions; rolls back and returns `False` if an exception is raised.

| Method | Description |
|--------|-------------|
| `BeginTransaction` | Starts an explicit transaction |
| `Commit` | Commits |
| `Rollback` | Rolls back |
| `Execute(TProc): Boolean` | Runs the block in a transaction; returns True if completed |

```pascal
uses Quick.Core.Entity.UnitOfWork;

// Option A — Execute (more concise):
var uow := TUnitOfWork.Create(fContext);
try
  if not uow.Execute(procedure
    begin
      fContext.Orders.Add(order);
      fContext.Products.Update(product);
    end) then
    LogError('Transaction failed');
finally
  uow.Free;
end;

// Option B — manual transactions directly on the context:
fContext.BeginTransaction;
try
  fContext.Orders.Add(order);
  fContext.Products.Update(product);
  fContext.CommitTransaction;
except
  fContext.RollbackTransaction;
  raise;
end;
```

---

## Soft Delete

Marks records as deleted without physically removing them:

```pascal
[SoftDelete]
type
  TProduct = class(TEntitySD)
  // ...
  end;
```

Once enabled:
- `Delete(entity)` executes `UPDATE SET IsDeleted = 1` instead of `DELETE`
- All `WHERE` queries automatically append `AND IsDeleted = 0`

---

## Optimistic Concurrency

Prevents conflicting updates using `RowVersion`:

```pascal
type
  TProduct = class(TEntityRV)  // inherits RowVersion: Integer
  published
    property Name : string read fName write fName;
  end;

// If another process modified the record first → EOptimisticConcurrencyException
try
  fContext.Products.Update(product);
except
  on E: EOptimisticConcurrencyException do
    ShowMessage('Record was modified by another process');
end;
```

---

## Data seeding

Inserts initial data when the database is first created:

```pascal
ctx.Seed(procedure(context: IDBContext)
begin
  var p := TProduct.Create;
  p.Name  := 'Default Product';
  p.Price := 0.0;
  context.AddOrUpdate(p);
end);
```

---

## See also

- [Dependency Injection](Dependency-Injection.md) — `AddDBContext`, lifetimes
- [MVC](MVC.md) — context injection in controllers
- [Security](Security.md) — `Identity` and `UserManager` use Entity internally


---

## Tabla de contenidos

1. [Proveedores soportados](#proveedores-soportados)
2. [Definir entidades](#definir-entidades)
3. [Clases base de entidad](#clases-base-de-entidad)
4. [Atributos de mapeo](#atributos-de-mapeo)
5. [DbContext](#dbcontext)
6. [Registrar el contexto (DI)](#registrar-el-contexto-di)
7. [Operaciones CRUD](#operaciones-crud)
8. [Consultas LINQ](#consultas-linq)
9. [Migrations](#migrations)
10. [Navegación (Navigation Properties)](#navegación-navigation-properties)
11. [Repository Pattern](#repository-pattern)
12. [Unit of Work](#unit-of-work)
13. [Soft Delete](#soft-delete)
14. [Optimistic Concurrency](#optimistic-concurrency)
15. [Seeding de datos](#seeding-de-datos)
16. [Ver también](#ver-también)

---

## Proveedores soportados

| Provider | `TDBProvider` | Unidad del motor |
|----------|--------------|-----------------|
| SQLite | `dbSQLite` | `Quick.Core.Entity.Engine.ADO` / FireDAC |
| SQL Server | `dbMSSQL` | `Quick.Core.Entity.Engine.ADO` / FireDAC |
| MySQL | `dbMySQL` | `Quick.Core.Entity.Engine.FireDAC` |
| MS Access | `dbMSAccess2007` | `Quick.Core.Entity.Engine.ADO` |
| PostgreSQL | `dbPostgreSQL` | `Quick.Core.Entity.Engine.FireDAC` |

---

## Definir entidades

Una entidad es una clase que hereda de `TEntity` (o una de sus variantes). Las propiedades `published` se mapean automáticamente a columnas.

```pascal
uses Quick.Core.Entity;

type
  [Table('products')]
  TProduct = class(TEntity)
  private
    fId       : TAutoID;
    fName     : string;
    fPrice    : Double;
    fStock    : Integer;
  published
    [Key]
    property Id    : TAutoID read fId    write fId;
    [StringLength(100)]
    property Name  : string  read fName  write fName;
    [DecimalLength(10, 2)]
    property Price : Double  read fPrice write fPrice;
    property Stock : Integer read fStock write fStock;
  end;
```

> **Nota:** `TAutoID` es un alias de `Int64` que indica columna autoincremental.

---

## Clases base de entidad

| Clase | Campos extra | Uso recomendado |
|-------|-------------|-----------------|
| `TEntity` | — | Entidad básica |
| `TEntityTS` | `CreatedAt`, `UpdatedAt` | Con timestamps automáticos |
| `TEntitySD` | `IsDeleted` | Soft delete |
| `TEntityTSSD` | `CreatedAt`, `UpdatedAt`, `IsDeleted` | Timestamps + soft delete |
| `TEntityRV` | `RowVersion` | Optimistic concurrency |
| `TEntityAudit` | `CreatedBy`, `UpdatedBy` | Campos de auditoría |

```pascal
// Entidad con timestamps y soft delete
type
  TOrder = class(TEntityTSSD)
  published
    property CustomerId : Integer read fCustomerId write fCustomerId;
    property Total      : Double  read fTotal      write fTotal;
  end;
```

---

## Atributos de mapeo

| Atributo | Descripción | Equivalente EF Core |
|----------|-------------|---------------------|
| `[Table('nombre')]` | Nombre de tabla personalizado | `[Table]` |
| `[MapField('col')]` | Nombre de columna personalizado | `[Column]` |
| `[Key]` | Clave primaria | `[Key]` |
| `[StringLength(n)]` | Longitud máxima de string | `[MaxLength(n)]` |
| `[DecimalLength(p, s)]` | Precisión y escala decimal | `[Precision(p, s)]` |
| `[SoftDelete]` | Habilita borrado lógico | `HasQueryFilter` |
| `[Index('campo')]` | Índice en columna | `HasIndex` |
| `[ForeignKey('campo')]` | Clave foránea | `[ForeignKey]` |
| `[HasMany]` | Relación 1:N | `HasMany` |
| `[HasOne]` | Relación 1:1 | `HasOne` |

---

## DbContext

El contexto hereda de `TDBContext` y expone `TDBSet<T>` para cada entidad:

```pascal
uses Quick.Core.Entity;

type
  TShopContext = class(TDBContext)
  private
    fProducts : TDBSet<TProduct>;
    fOrders   : TDBSet<TOrder>;
  public
    property Products : TDBSet<TProduct> read fProducts write fProducts;
    property Orders   : TDBSet<TOrder>   read fOrders   write fOrders;
  end;
```

### Configurar la conexión

```pascal
var
  ctx : TShopContext;
begin
  ctx := TShopContext.Create;
  ctx.Connection.Provider := dbSQLite;
  ctx.Connection.Database := 'shop.db';
  ctx.Connect;
end;
```

---

## Registrar el contexto (DI)

```pascal
uses Quick.Core.Extensions.Entity;

// En ConfigureServices:
services.Extension<TEntityServiceExtension>
  .AddDBContext<TShopContext>(procedure(opt: TDbContextOptions)
  begin
    opt.Provider  := dbSQLite;
    opt.Database  := 'shop.db';
  end);
```

### Equivalente C# (EF Core)

```csharp
builder.Services.AddDbContext<ShopContext>(opt =>
    opt.UseSqlite("Data Source=shop.db"));
```

Inyección en el constructor del controller o servicio:

```pascal
constructor TProductService.Create(aContext: TShopContext);
begin
  fContext := aContext;
end;
```

---

## Operaciones CRUD

```pascal
var
  p : TProduct;
  list : IDBSetResult<TProduct>;
begin
  p := TProduct.Create;
  p.Name  := 'Widget';
  p.Price := 9.99;

  // Insertar
  fContext.Products.Add(p);

  // Insertar o actualizar
  fContext.Products.AddOrUpdate(p);

  // Actualizar
  p.Price := 12.50;
  fContext.Products.Update(p);

  // Eliminar
  fContext.Products.Delete(p);

  // Contar
  var total := fContext.Products.CountResults;
end;
```

---

## Consultas LINQ

```pascal
// WHERE con formato SQL
var list := fContext.Products
  .Where('Price > ? AND Stock > ?', [10.0, 0])
  .OrderBy('Name')
  .Select;

// WHERE con lambda (post-filter en memoria)
var cheap := fContext.Products
  .Where(function(p: TProduct): Boolean
  begin
    Result := p.Price < 5.0;
  end)
  .Select;

// Top N
var top5 := fContext.Products
  .OrderByDescending('Price')
  .SelectTop(5);

// Primer registro
var first := fContext.Products
  .Where('Name = ?', ['Widget'])
  .SelectFirst;

// Contar
var count := fContext.Products
  .Where('Stock > ?', [0])
  .Count;

// Suma
var total := fContext.Products
  .Sum('Price');
```

### Equivalente C#

```csharp
var list = context.Products
    .Where(p => p.Price > 10 && p.Stock > 0)
    .OrderBy(p => p.Name)
    .ToList();

var first = context.Products
    .FirstOrDefault(p => p.Name == "Widget");
```

---

## Migrations

**Unidad:** `Quick.Core.Entity.Migrations`

Gestiona la evolución del esquema de base de datos de forma transaccional. La tabla `__MigrationsHistory` se crea automáticamente para registrar las migraciones ya aplicadas.

| Clase / Método | Descripción |
|---------------|-------------|
| `TMigration` | Clase base abstracta |
| `GetMigrationId` | Nombre único sortable, p.ej. `'20240101_CreateUsers'` |
| `Up(aDBContext)` | Aplica los cambios al esquema |
| `Down(aDBContext)` | Revierte los cambios |
| `GetProductVersion` | Versión de app (override opcional) |
| `TMigrationsManager.ApplyMigrations(migrations[])` | Aplica todas las pendientes en orden |
| `TMigrationsManager.RollbackLast(migrations[])` | Revierte la última migración aplicada |
| `TMigrationsManager.GetAppliedMigrations` | Lista de IDs ya aplicados |
| `TEntityMigrationsHistory` | Entidad de seguimiento (tabla `__MigrationsHistory`) |

```pascal
uses Quick.Core.Entity.Migrations;

type
  T20260101_CreateProducts = class(TMigration)
  public
    function GetMigrationId: string; override;
    procedure Up(aDBContext: TDBContext); override;
    procedure Down(aDBContext: TDBContext); override;
  end;

function T20260101_CreateProducts.GetMigrationId: string;
begin
  Result := '20260101_CreateProducts';
end;

procedure T20260101_CreateProducts.Up(aDBContext: TDBContext);
begin
  aDBContext.ExecuteSQL(
    'CREATE TABLE products (Id INTEGER PRIMARY KEY, Name VARCHAR(200), Price FLOAT)');
end;

procedure T20260101_CreateProducts.Down(aDBContext: TDBContext);
begin
  aDBContext.ExecuteSQL('DROP TABLE products');
end;

// Aplicar en startup:
var mgr := TMigrationsManager.Create(myDBContext);
try
  mgr.ApplyMigrations([T20260101_CreateProducts]);
finally
  mgr.Free;
end;
```

### Equivalente C#

```csharp
public class CreateProducts : Migration
{
    protected override void Up(MigrationBuilder mb)
        => mb.CreateTable("Products", t => new { ... });
    protected override void Down(MigrationBuilder mb)
        => mb.DropTable("Products");
}
// dotnet ef database update
```

---

## Navegación (Navigation Properties)

Carga relaciones automáticamente con `Include`:

```pascal
type
  TOrderLine = class(TEntity)
  published
    [ForeignKey('OrderId')]
    property OrderId   : Integer   read fOrderId   write fOrderId;
    property ProductId : Integer   read fProductId write fProductId;
    property Quantity  : Integer   read fQuantity  write fQuantity;
  end;

  TOrder = class(TEntity)
  published
    property CustomerId : Integer read fCustomerId write fCustomerId;
    [HasMany]
    property Lines : TObjectList<TOrderLine> read fLines write fLines;
  end;

// Consulta con eager loading
var order := fContext.Orders
  .Include('Lines')
  .Where('Id = ?', [42])
  .SelectFirst;
```

---

## Repository Pattern

**Unidad:** `Quick.Core.Entity.Repository`

Abstrae el acceso a datos detrás de `IRepository<T>`. El tipo `T` debe heredar de `TEntity`.

| Método | Descripción |
|--------|-------------|
| `GetById(id)` | Carga por clave primaria (devuelve nil si no existe) |
| `GetAll` | Lista completa |
| `Add(entity)` | Insert |
| `AddOrUpdate(entity)` | Upsert |
| `Update(entity)` | Update |
| `Delete(entity)` / `DeleteById(id)` | Delete |
| `Count` | Número total de registros |
| `Exists(id)` | Comprueba existencia |
| `Find(where, params[])` | Filtro SQL parametrizado → lista |
| `FindFirst(where)` | Primer resultado o nil |
| `Query` | `IEntityLinqQuery<T>` para consultas fluent |

```pascal
uses Quick.Core.Entity.Repository;

// Repositorio concreto que añade métodos específicos:
type
  IProductRepository = interface(IRepository<TProduct>)
  ['{GUID}']
    function FindByCategory(const aCategory: string): TList<TProduct>;
  end;

  TProductRepository = class(TEntityRepository<TProduct>, IProductRepository)
  public
    constructor Create(aDBSet: TDBSet<TProduct>);
    function FindByCategory(const aCategory: string): TList<TProduct>;
  end;

constructor TProductRepository.Create(aDBSet: TDBSet<TProduct>);
begin
  inherited Create(aDBSet, 'Id');
end;

function TProductRepository.FindByCategory(const aCategory: string): TList<TProduct>;
begin
  Result := Find('Category = ?', [aCategory]);
end;

// Registro DI:
services.AddScoped<IProductRepository>(function(sp: IServiceProvider): IProductRepository
begin
  Result := TProductRepository.Create(sp.Resolve<TShopContext>.Products);
end);
```

---

## Unit of Work

**Unidad:** `Quick.Core.Entity.UnitOfWork`

Agrupa operaciones en una transacción atómica. `Execute` hace commit si el bloque termina sin excepciones; rollback y retorna `False` si lanza una.

| Método | Descripción |
|--------|-------------|
| `BeginTransaction` | Inicia transacción explícita |
| `Commit` | Confirma |
| `Rollback` | Revierte |
| `Execute(TProc): Boolean` | Ejecuta el bloque en transacción; retorna True si se completó |

```pascal
uses Quick.Core.Entity.UnitOfWork;

// Opción A — Execute (más conciso):
var uow := TUnitOfWork.Create(fContext);
try
  if not uow.Execute(procedure
    begin
      fContext.Orders.Add(order);
      fContext.Products.Update(product);
    end) then
    LogError('Transaction failed');
finally
  uow.Free;
end;

// Opción B — transacciones manuales directas sobre el contexto:
fContext.BeginTransaction;
try
  fContext.Orders.Add(order);
  fContext.Products.Update(product);
  fContext.CommitTransaction;
except
  fContext.RollbackTransaction;
  raise;
end;
```

---

## Soft Delete

Marca registros como eliminados sin borrarlos físicamente:

```pascal
[SoftDelete]
type
  TProduct = class(TEntitySD)
  // ...
  end;
```

A partir de ese momento:
- `Delete(entity)` ejecuta `UPDATE SET IsDeleted = 1` en lugar de `DELETE`
- Todas las consultas `WHERE` añaden automáticamente `AND IsDeleted = 0`

---

## Optimistic Concurrency

Previene actualizaciones conflictivas con `RowVersion`:

```pascal
type
  TProduct = class(TEntityRV)  // hereda RowVersion: Integer
  published
    property Name : string read fName write fName;
  end;

// Si otro proceso modificó el registro antes → EOptimisticConcurrencyException
try
  fContext.Products.Update(product);
except
  on E: EOptimisticConcurrencyException do
    ShowMessage('El registro fue modificado por otro proceso');
end;
```

---

## Seeding de datos

Inserta datos iniciales cuando la base de datos se crea:

```pascal
ctx.Seed(procedure(context: IDBContext)
begin
  var p := TProduct.Create;
  p.Name  := 'Default Product';
  p.Price := 0.0;
  context.AddOrUpdate(p);
end);
```

---

## Ver también

- [Dependency Injection](Dependency-Injection.md) — `AddDBContext`, lifetimes
- [MVC](MVC.md) — inyección del contexto en controllers
- [Security](Security.md) — `Identity` y `UserManager` usan Entity internamente
