program EntityCRUD;

(* EntityCRUD Sample - S-05
  Demonstrates full CRUD operations with QuickCore Entity ORM and SQLite.
  Uses FireDAC as the database engine.

  .NET equivalent: EF Core + SQLite — Add/Update/Delete/Select/LINQ queries.

  Requirements:
    - FireDAC components (included in Delphi)
    - SQLite driver (FireDAC.Phys.SQLite)
*)

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  FireDAC.Phys.SQLite,
  Quick.Console,
  Quick.Core.Entity,
  Quick.Core.Entity.DAO,
  Quick.Core.Entity.Database,
  Quick.Core.Entity.Factory.Database,
  Quick.Core.Entity.Repository,
  Models in 'Models.pas';

// ── DBContext ─────────────────────────────────────────────────────────────────

type

  TShopContext = class(TDBContext)
  private
    FProducts : TDBSet<TProduct>;
  public
    property Products : TDBSet<TProduct> read FProducts write FProducts;
  end;

// ── Helpers ──────────────────────────────────────────────────────────────────

procedure PrintProduct(p : TProduct);
begin
  cout(Format('  [%d] %-20s | %-12s | $%6.2f | stock=%d | active=%s',
    [p.Id, p.Name, p.Category, p.Price, p.Stock, BoolToStr(p.Active, True)]), ccWhite);
end;

procedure PrintProducts(list : TList<TProduct>);
begin
  for var p in list do
    PrintProduct(p);
end;

// ── Main program ─────────────────────────────────────────────────────────────

var
  dbPath  : string;
  db      : TEntityDatabase;
  context : TShopContext;
  repo    : TEntityRepository<TProduct>;
  p       : TProduct;
  list    : TList<TProduct>;
  id1, id2, id3 : TAutoID;

begin
  ReportMemoryLeaksOnShutdown := True;
  dbPath := TPath.Combine(TPath.GetTempPath, 'entitycrud_sample.db');
  try
    // ── Setup ──────────────────────────────────────────────────────────
    cout('=== SETUP ===', ccLightCyan);
    db := TEntityDatabaseFactory.GetInstance(TDatabaseEngine.deFireDAC);
    db.Connection.FromConnectionString(Integer(TDBProvider.dbSQLite),
      'Database=' + dbPath);
    context := TShopContext.Create(db);
    try
      if not context.Connect then
        raise Exception.Create('Cannot connect to SQLite database');
      repo := TEntityRepository<TProduct>.Create(context.Products);
      cout('  Connected to ' + dbPath, ccGreen);

      // ── CREATE ─────────────────────────────────────────────────────
      cout('', ccWhite);
      cout('=== CREATE ===', ccLightCyan);

      p := TProduct.Create;
      p.Name     := 'Widget Pro';
      p.Category := 'Hardware';
      p.Price    := 29.99;
      p.Stock    := 100;
      p.Active   := True;
      repo.Add(p);
      id1 := p.Id;
      p.Free;

      p := TProduct.Create;
      p.Name     := 'Gadget Lite';
      p.Category := 'Electronics';
      p.Price    := 9.99;
      p.Stock    := 250;
      p.Active   := True;
      repo.Add(p);
      id2 := p.Id;
      p.Free;

      p := TProduct.Create;
      p.Name     := 'OldStuff';
      p.Category := 'Hardware';
      p.Price    := 1.00;
      p.Stock    := 5;
      p.Active   := False;
      repo.Add(p);
      id3 := p.Id;
      p.Free;

      cout(Format('  Added 3 products. IDs: %d, %d, %d', [id1, id2, id3]), ccGreen);

      // ── READ ALL ───────────────────────────────────────────────────
      cout('', ccWhite);
      cout('=== READ ALL ===', ccLightCyan);
      list := repo.GetAll;
      try
        PrintProducts(list);
      finally
        list.Free;
      end;

      // ── READ BY ID ─────────────────────────────────────────────────
      cout('', ccWhite);
      cout('=== GET BY ID (id=' + IntToStr(id1) + ') ===', ccLightCyan);
      p := repo.GetById(id1);
      try
        if p <> nil then
          PrintProduct(p)
        else
          cout('  Not found!', ccRed);
      finally
        p.Free;
      end;

      // ── UPDATE ─────────────────────────────────────────────────────
      cout('', ccWhite);
      cout('=== UPDATE (id=' + IntToStr(id2) + ', Price=14.99, Stock=300) ===', ccLightCyan);
      p := repo.GetById(id2);
      try
        if p <> nil then
        begin
          p.Price := 14.99;
          p.Stock := 300;
          repo.Update(p);
          cout('  Updated.', ccGreen);
        end
        else
          cout('  Not found, update skipped.', ccYellow);
      finally
        if p <> nil then
          p.Free;
      end;

      // ── FIND (FILTER) ──────────────────────────────────────────────
      cout('', ccWhite);
      cout('=== FIND where Category = "Hardware" ===', ccLightCyan);
      list := repo.Find('Category = %s', ['Hardware']);
      try
        PrintProducts(list);
      finally
        list.Free;
      end;

      // ── WHERE + ORDER BY ───────────────────────────────────────────
      cout('', ccWhite);
      cout('=== WHERE Active = 1 ORDER BY Price DESC ===', ccLightCyan);
      for p in context.Products
        .Where('Active = 1')
        .OrderByDescending('Price')
        .Select do
        PrintProduct(p);

      // ── COUNT ──────────────────────────────────────────────────────
      cout('', ccWhite);
      cout('=== COUNT ===', ccLightCyan);
      cout(Format('  Total products : %d', [repo.Count]), ccWhite);
      cout(Format('  Active only    : %d', [context.Products.Where('Active = 1').Count]), ccWhite);

      // ── DELETE ─────────────────────────────────────────────────────
      cout('', ccWhite);
      cout('=== DELETE (id=' + IntToStr(id3) + ') ===', ccLightCyan);
      repo.DeleteById(id3);
      cout(Format('  Deleted. Remaining: %d', [repo.Count]), ccGreen);

    finally
      repo.Free;
      context.Free;
    end;

    // Cleanup temp file
    if TFile.Exists(dbPath) then
      TFile.Delete(dbPath);

    cout('', ccWhite);
    cout('Press [Enter] to exit.', ccYellow);
    ConsoleWaitForEnterKey;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
