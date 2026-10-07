program EntityMigrations;

(* EntityMigrations Sample - S-28
  Demonstrates the QuickCore Entity Migrations system.

  Two migrations are defined:
    1. '20240101000000_InitialCreate'  — Creates the Products table
    2. '20240102000000_AddAuditFields' — Adds CreatedAt + IsActive columns

  Operations shown:
    - ApplyMigrations   : applies only pending migrations (idempotent)
    - GetAppliedMigrations : lists already-applied migration IDs
    - RollbackLast      : reverts the most recent migration

  .NET equivalent: EF Core Migrations — dotnet ef migrations add / database update.

  Requirements:
    - FireDAC components (included in Delphi)
    - SQLite driver (FireDAC.Phys.SQLite)
*)

{$APPTYPE CONSOLE}

uses
  system.Classes,
  System.SysUtils,
  System.IOUtils,
  FireDAC.Phys.SQLite,
  Quick.Commons,
  Quick.Console,
  Quick.Core.Entity,
  Quick.Core.Entity.DAO,
  Quick.Core.Entity.Database,
  Quick.Core.Entity.Config,
  Quick.Core.Entity.Factory.Database,
  Quick.Core.Entity.Migrations,
  Models in 'Models.pas';

// ── DBContext ─────────────────────────────────────────────────────────────────

type

  TShopContext = class(TDBContext)
  private
    FProducts : TDBSet<TProduct>;
  published
    property Products : TDBSet<TProduct> read FProducts write FProducts;
  end;

// ── Migration 1: create the initial table (Name + Price only) ─────────────────

  T20240101_InitialCreate = class(TMigration)
  public
    function GetMigrationId : string; override;
    function GetProductVersion : string; override;
    procedure Up(aDBContext : TDBContext); override;
    procedure Down(aDBContext : TDBContext); override;
  end;

// ── Migration 2: add CreatedAt and IsActive columns ───────────────────────────

  T20240102_AddAuditFields = class(TMigration)
  public
    function GetMigrationId : string; override;
    function GetProductVersion : string; override;
    procedure Up(aDBContext : TDBContext); override;
    procedure Down(aDBContext : TDBContext); override;
  end;

// ─────────────────────────────────────────────────────────────────────────────
// Migration 1
// ─────────────────────────────────────────────────────────────────────────────

function T20240101_InitialCreate.GetMigrationId : string;
begin
  Result := '20240101000000_InitialCreate';
end;

function T20240101_InitialCreate.GetProductVersion : string;
begin
  Result := '1.0.0';
end;

procedure T20240101_InitialCreate.Up(aDBContext : TDBContext);
begin
  aDBContext.Database.ExecuteSQLQuery(
    'CREATE TABLE IF NOT EXISTS products (' +
    '  Id    INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  Name  TEXT NOT NULL,' +
    '  Price REAL NOT NULL DEFAULT 0' +
    ')');
end;

procedure T20240101_InitialCreate.Down(aDBContext : TDBContext);
begin
  aDBContext.Database.ExecuteSQLQuery('DROP TABLE IF EXISTS products');
end;

// ─────────────────────────────────────────────────────────────────────────────
// Migration 2
// ─────────────────────────────────────────────────────────────────────────────

function T20240102_AddAuditFields.GetMigrationId : string;
begin
  Result := '20240102000000_AddAuditFields';
end;

function T20240102_AddAuditFields.GetProductVersion : string;
begin
  Result := '1.1.0';
end;

procedure T20240102_AddAuditFields.Up(aDBContext : TDBContext);
var
  fields : TArray<string>;
  f      : string;
  hasCreatedAt : Boolean;
  hasIsActive  : Boolean;
begin
  fields := aDBContext.GetFieldNames('products');
  hasCreatedAt := False;
  hasIsActive := False;

  for f in fields do
  begin
    if SameText(f, 'CreatedAt') then
      hasCreatedAt := True
    else if SameText(f, 'IsActive') then
      hasIsActive := True;
  end;

  if not hasCreatedAt then
    aDBContext.Database.ExecuteSQLQuery(
      'ALTER TABLE products ADD COLUMN CreatedAt REAL DEFAULT 0');
  if not hasIsActive then
    aDBContext.Database.ExecuteSQLQuery(
      'ALTER TABLE products ADD COLUMN IsActive INTEGER DEFAULT 1');
end;

procedure T20240102_AddAuditFields.Down(aDBContext : TDBContext);
begin
  // SQLite does not support DROP COLUMN directly — recreate without the columns
  aDBContext.Database.ExecuteSQLQuery(
    'CREATE TABLE products_backup AS SELECT Id, Name, Price FROM products');
  aDBContext.Database.ExecuteSQLQuery('DROP TABLE products');
  aDBContext.Database.ExecuteSQLQuery(
    'ALTER TABLE products_backup RENAME TO products');
end;

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

const
  DB_FILE = '.\migrations_demo.db';

var
  db       : TEntityDatabase;
  ctx      : TShopContext;
  mgr      : TMigrationsManager;
  applied  : TArray<string>;
  id       : string;
  p        : TProduct;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    // Clean start — remove DB from previous run
    if TFile.Exists(DB_FILE) then TFile.Delete(DB_FILE);

    cout('EntityMigrations sample (S-28)', ccCyan);
    cout('=================================', ccCyan);

    // ── Build connection ───────────────────────────────────────────────────
    db := TEntityDatabaseFactory.GetInstance(TDatabaseEngine.deFireDAC);
    db.Connection.FromConnectionString(Integer(TDBProvider.dbSQLite),
      'Database=' + DB_FILE);

    ctx := TShopContext.Create(db);
    try
      ctx.Connect;

      // ── Apply all pending migrations ───────────────────────────────────
      cout('', ccWhite);
      cout('► ApplyMigrations (all)', ccYellow);
      mgr := TMigrationsManager.Create(ctx);
      try
        mgr.ApplyMigrations([T20240101_InitialCreate, T20240102_AddAuditFields]);

        applied := mgr.GetAppliedMigrations;
        cout(Format('  Applied migrations (%d):', [Length(applied)]), ccWhite);
        for id in applied do
          cout('    ✔ ' + id, ccGreen);

        // ── Insert some data ───────────────────────────────────────────
        cout('', ccWhite);
        cout('► Insert test data', ccYellow);
        p           := TProduct.Create;
        p.Name      := 'Laptop';
        p.Price     := 999.99;
        p.CreatedAt := Now;
        p.IsActive  := True;
        ctx.Products.Add(p);
        p.Free;

        p           := TProduct.Create;
        p.Name      := 'Keyboard';
        p.Price     := 49.99;
        p.CreatedAt := Now;
        p.IsActive  := True;
        ctx.Products.Add(p);
        p.Free;

        cout('  Inserted 2 products', ccWhite);

        // ── Show current rows ──────────────────────────────────────────
        cout('', ccWhite);
        cout('► Products in DB:', ccYellow);
        for p in ctx.Products.Where('').Select do
        begin
          cout(Format('  [%d] %s  $%.2f  Active=%s',
            [Int64(p.Id), p.Name, p.Price, BoolToStr(p.IsActive, True)]), ccWhite);
          p.Free;
        end;

        // ── Call ApplyMigrations again → idempotent, nothing happens ───
        cout('', ccWhite);
        cout('► ApplyMigrations again (idempotent — nothing should change)', ccYellow);
        mgr.ApplyMigrations([T20240101_InitialCreate, T20240102_AddAuditFields]);
        applied := mgr.GetAppliedMigrations;
        cout(Format('  Applied migrations still (%d):', [Length(applied)]), ccWhite);
        for id in applied do
          cout('    ✔ ' + id, ccGreen);

        // ── RollbackLast ───────────────────────────────────────────────
        cout('', ccWhite);
        cout('► RollbackLast (reverts AddAuditFields)', ccYellow);
        mgr.RollbackLast([T20240101_InitialCreate, T20240102_AddAuditFields]);
        applied := mgr.GetAppliedMigrations;
        cout(Format('  Applied migrations after rollback (%d):', [Length(applied)]), ccWhite);
        for id in applied do
          cout('    ✔ ' + id, ccGreen);

      finally
        mgr.Free;
      end;

    finally
      ctx.Free;
    end;

    cout('', ccWhite);
    cout('Done! Press Enter to exit.', ccCyan);
    Readln;
  except
    on E : Exception do
    begin
      cout('Error: ' + E.Message, etError);
      Readln;
    end;
  end;
end.
