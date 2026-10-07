program NavigationProperties;

(* NavigationProperties Sample - S-29
  Demonstrates ORM navigation properties (eager loading) with QuickCore Entity.

  Entities:
    TOrder     — has many TOrderItem (via Items property with [HasMany])
    TOrderItem — belongs to TOrder   (via [ForeignKey('OrderId')])

  Operations shown:
    - Insert parent + children
    - Load with eager Include('Items') — one extra SELECT per parent
    - Load without Include — Items list is empty (lazy-not-loaded)

  .NET equivalent: EF Core Include() / Navigation Properties.

  Requirements:
    - FireDAC components (included in Delphi)
    - SQLite driver (FireDAC.Phys.SQLite)
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  FireDAC.Phys.SQLite,
  Quick.Commons,
  Quick.Console,
  Quick.Core.Entity,
  Quick.Core.Entity.DAO,
  Quick.Core.Entity.Database,
  Quick.Core.Entity.Config,
  Quick.Core.Entity.Factory.Database,
  Quick.Core.Entity.Navigation;

// ── Entities ──────────────────────────────────────────────────────────────────

type
  // Forward declaration needed for HasMany attribute
  TOrderItem = class;

  [Table('order_items')]
  TOrderItem = class(TEntity)
  private
    FId       : TAutoID;
    FOrderId  : Integer;
    FProduct  : string;
    FQty      : Integer;
    FUnitPrice: Double;
  published
    [Key]
    property Id        : TAutoID read FId        write FId;
    property OrderId   : Integer read FOrderId   write FOrderId;
    [StringLength(100)]
    property Product   : string  read FProduct   write FProduct;
    property Qty       : Integer read FQty       write FQty;
    [DecimalLength(10,2)]
    property UnitPrice : Double  read FUnitPrice write FUnitPrice;
  end;

  [Table('orders')]
  TOrder = class(TEntity)
  private
    FId         : TAutoID;
    FCustomer   : string;
    FOrderDate  : TDateTime;
    FItems      : TObjectList<TEntity>;
  public
    constructor Create;
    destructor Destroy; override;
  published
    [Key]
    property Id        : TAutoID  read FId        write FId;
    [StringLength(100)]
    property Customer  : string   read FCustomer  write FCustomer;
    property OrderDate : TDateTime read FOrderDate write FOrderDate;
    [HasMany(TOrderItem, 'OrderId')]
    property Items : TObjectList<TEntity> read FItems write FItems;
  end;

// ── DBContext ─────────────────────────────────────────────────────────────────

  TShopContext = class(TDBContext)
  private
    FOrders : TDBSet<TOrder>;
    FItems  : TDBSet<TOrderItem>;
  public
    property Orders : TDBSet<TOrder>     read FOrders write FOrders;
    property Items  : TDBSet<TOrderItem> read FItems  write FItems;
  end;

{ TOrder }

constructor TOrder.Create;
begin
  inherited;
  FItems := TObjectList<TEntity>.Create(True);
end;

destructor TOrder.Destroy;
begin
  FItems.Free;
  inherited;
end;

{ TShopContext }

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

const
  DB_FILE = '.\navprops_demo.db';

var
  db       : TEntityDatabase;
  ctx      : TShopContext;
  order    : TOrder;
  item     : TOrderItem;
  entity   : TEntity;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if TFile.Exists(DB_FILE) then TFile.Delete(DB_FILE);

    cout('NavigationProperties sample (S-29)', ccCyan);
    cout('=====================================', ccCyan);

    db := TEntityDatabaseFactory.GetInstance(TDatabaseEngine.deFireDAC);
    db.Connection.FromConnectionString(Integer(TDBProvider.dbSQLite),
      'Database=' + DB_FILE);

    ctx := TShopContext.Create(db);
    try
      ctx.Connect;
      // CreateTables is called automatically by Connect

      // ── Insert data ────────────────────────────────────────────────────
      cout('', ccWhite);
      cout('► Inserting orders and items', ccYellow);

      // Order 1 — 2 items
      order           := TOrder.Create;
      order.Customer  := 'Alice';
      order.OrderDate := Now;
      ctx.Orders.Add(order);
      order.Free;

      item           := TOrderItem.Create;
      item.OrderId   := 1;
      item.Product   := 'Laptop';
      item.Qty       := 1;
      item.UnitPrice := 999.99;
      ctx.Items.Add(item);
      item.Free;

      item           := TOrderItem.Create;
      item.OrderId   := 1;
      item.Product   := 'Mouse';
      item.Qty       := 2;
      item.UnitPrice := 19.99;
      ctx.Items.Add(item);
      item.Free;

      // Order 2 — 1 item
      order           := TOrder.Create;
      order.Customer  := 'Bob';
      order.OrderDate := Now;
      ctx.Orders.Add(order);
      order.Free;

      item           := TOrderItem.Create;
      item.OrderId   := 2;
      item.Product   := 'Keyboard';
      item.Qty       := 1;
      item.UnitPrice := 49.99;
      ctx.Items.Add(item);
      item.Free;

      cout('  Inserted 2 orders with 3 items total.', ccWhite);

      // ── Load WITH Include('Items') ─────────────────────────────────────
      cout('', ccWhite);
      cout('► SELECT orders WITH Include(''Items'')', ccYellow);
      for order in ctx.Orders.Where('').Include('Items').Select do
      begin
        cout(Format('  Order #%d  Customer=%s  Items=%d',
          [Int64(order.Id), order.Customer, order.Items.Count]), ccWhite);
        for entity in order.Items do
        begin
          item := TOrderItem(entity);
          cout(Format('    - %-12s  Qty=%d  @$%.2f',
            [item.Product, item.Qty, item.UnitPrice]), ccWhite);
        end;
        order.Free;
      end;

      // ── Load WITHOUT Include — Items list is empty ─────────────────────
      cout('', ccWhite);
      cout('► SELECT orders WITHOUT Include (Items not loaded)', ccYellow);
      for order in ctx.Orders.Where('').Select do
      begin
        cout(Format('  Order #%d  Customer=%s  Items.Count=%d (not loaded)',
          [Int64(order.Id), order.Customer, order.Items.Count]), ccWhite);
        order.Free;
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
