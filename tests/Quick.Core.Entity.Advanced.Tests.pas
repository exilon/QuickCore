unit Quick.Core.Entity.Advanced.Tests;

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.Generics.Collections,
  System.IOUtils,
  System.SysUtils,
  FireDAC.Comp.Client,
  FireDAC.DApt,
  FireDAC.Phys.SQLite,
  FireDAC.Stan.Async,
  FireDAC.Stan.Def,
  Quick.Core.Entity,
  Quick.Core.Entity.DAO,
  Quick.Core.Entity.Database,
  Quick.Core.Entity.Factory.Database,
  Quick.Core.Entity.Repository,
  Quick.Core.Entity.UnitOfWork;

type

  // ---- Entity types for advanced tests ----

  [Table('adv_items')]
  TAdvItem = class(TEntity)
  private
    FId: TAutoID;
    FName: string;
    FQty: Integer;
  published
    [Key]
    property Id: TAutoID read FId write FId;
    [StringLength(80)]
    property Name: string read FName write FName;
    property Qty: Integer read FQty write FQty;
  end;

  [SoftDelete]
  [Table('adv_soft_items')]
  TAdvSoftItem = class(TEntitySD)
  private
    FId: TAutoID;
    FLabel: string;
  published
    [Key]
    property Id: TAutoID read FId write FId;
    [StringLength(80)]
    property &Label: string read FLabel write FLabel;
  end;

  [Table('adv_rv_items')]
  TAdvRvItem = class(TEntityRV)
  private
    FId: TAutoID;
    FTitle: string;
  published
    [Key]
    property Id: TAutoID read FId write FId;
    [StringLength(80)]
    property Title: string read FTitle write FTitle;
  end;

  // ---- DB Context ----

  TAdvancedEntityContext = class(TDBContext)
  private
    FItems: TDBSet<TAdvItem>;
    FSoftItems: TDBSet<TAdvSoftItem>;
    FRvItems: TDBSet<TAdvRvItem>;
  public
    property Items: TDBSet<TAdvItem> read FItems write FItems;
    property SoftItems: TDBSet<TAdvSoftItem> read FSoftItems write FSoftItems;
    property RvItems: TDBSet<TAdvRvItem> read FRvItems write FRvItems;
    function IsConnected: Boolean; override;
  end;

  // ---- Test fixture ----

  [TestFixture]
  TQuickCoreEntityAdvancedTests = class
  private
    FContext: TAdvancedEntityContext;
    FDatabasePath: string;
    function CreateInspectionConnection: TFDConnection;
    function ExecuteScalarInt(const ASql: string): Int64;
    procedure AddItem(const AName: string; AQty: Integer; AId: TAutoID = 0);
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    // Repository tests
    [Test]
    procedure T_EN_19_Repository_GetById;
    [Test]
    procedure T_EN_20_Repository_GetAll;
    [Test]
    procedure T_EN_21_Repository_Add;
    [Test]
    procedure T_EN_22_Repository_Delete;
    [Test]
    procedure T_EN_23_Repository_Count;
    [Test]
    procedure T_EN_24_Repository_Exists;
    [Test]
    procedure T_EN_25_Repository_Find;

    // Unit of Work tests
    [Test]
    procedure T_EN_26_UnitOfWork_Execute_Commits_On_Success;
    [Test]
    procedure T_EN_27_UnitOfWork_Execute_Rollback_On_Exception;

    // Soft Delete test
    [Test]
    procedure T_EN_28_SoftDelete_Hides_Deleted_Entities;

    // Optimistic Concurrency tests
    [Test]
    procedure T_EN_29_OptimisticConcurrency_RowVersion_Increments;
    [Test]
    procedure T_EN_30_OptimisticConcurrency_Conflict_Raises;
  end;

implementation

{ TAdvancedEntityContext }

function TAdvancedEntityContext.IsConnected: Boolean;
begin
  Result := Database.IsConnected;
end;

{ TQuickCoreEntityAdvancedTests }

function TQuickCoreEntityAdvancedTests.CreateInspectionConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  Result.LoginPrompt := False;
  Result.Params.Clear;
  Result.Params.Add('DriverID=SQLite');
  Result.Params.Add('Database=' + FDatabasePath);
  Result.Connected := True;
end;

function TQuickCoreEntityAdvancedTests.ExecuteScalarInt(const ASql: string): Int64;
var
  conn: TFDConnection;
  qry: TFDQuery;
begin
  conn := CreateInspectionConnection;
  qry := TFDQuery.Create(nil);
  try
    qry.Connection := conn;
    qry.SQL.Text := ASql;
    qry.Open;
    Result := qry.Fields[0].AsLargeInt;
  finally
    qry.Free;
    conn.Free;
  end;
end;

procedure TQuickCoreEntityAdvancedTests.AddItem(const AName: string;
  AQty: Integer; AId: TAutoID);
var
  item: TAdvItem;
begin
  item := TAdvItem.Create;
  try
    item.Id := AId;
    item.Name := AName;
    item.Qty := AQty;
    Assert.IsTrue(FContext.Items.Add(item));
  finally
    item.Free;
  end;
end;

procedure TQuickCoreEntityAdvancedTests.SetUp;
var
  database: TEntityDatabase;
begin
  FDatabasePath := TPath.Combine(TPath.GetTempPath, TGuid.NewGuid.ToString + '.db');
  database := TEntityDatabaseFactory.GetInstance(TDatabaseEngine.deFireDAC);
  database.Connection.FromConnectionString(Integer(TDBProvider.dbSQLite), 'Database=' + FDatabasePath);
  FContext := TAdvancedEntityContext.Create(database);
  Assert.IsTrue(FContext.Connect);
end;

procedure TQuickCoreEntityAdvancedTests.TearDown;
begin
  FContext.Free;
  FContext := nil;
  if TFile.Exists(FDatabasePath) then
    TFile.Delete(FDatabasePath);
end;

{ --- Repository tests (T-EN-19..25) --- }

procedure TQuickCoreEntityAdvancedTests.T_EN_19_Repository_GetById;
var
  repo: IRepository<TAdvItem>;
  found: TAdvItem;
begin
  AddItem('ItemA', 10, 1);
  repo := TEntityRepository<TAdvItem>.Create(FContext.Items, 'Id');
  found := repo.GetById(1);
  try
    Assert.IsNotNull(found, 'GetById must return a non-nil entity for existing Id');
    Assert.AreEqual('ItemA', found.Name);
    Assert.AreEqual(10, found.Qty);
  finally
    found.Free;
  end;
end;

procedure TQuickCoreEntityAdvancedTests.T_EN_20_Repository_GetAll;
var
  repo: IRepository<TAdvItem>;
  list: TList<TAdvItem>;
begin
  AddItem('One', 1);
  AddItem('Two', 2);
  AddItem('Three', 3);
  repo := TEntityRepository<TAdvItem>.Create(FContext.Items, 'Id');
  list := repo.GetAll;
  try
    Assert.AreEqual(NativeInt(3), list.Count, 'GetAll must return all 3 entities');
  finally
    list.Free;
  end;
end;

procedure TQuickCoreEntityAdvancedTests.T_EN_21_Repository_Add;
var
  repo: IRepository<TAdvItem>;
  item: TAdvItem;
begin
  repo := TEntityRepository<TAdvItem>.Create(FContext.Items, 'Id');
  item := TAdvItem.Create;
  try
    item.Name := 'RepoAdded';
    item.Qty := 7;
    Assert.IsTrue(repo.Add(item), 'Repository.Add must return True');
  finally
    item.Free;
  end;
  Assert.AreEqual<Int64>(1, ExecuteScalarInt('SELECT COUNT(*) FROM adv_items'));
end;

procedure TQuickCoreEntityAdvancedTests.T_EN_22_Repository_Delete;
var
  repo: IRepository<TAdvItem>;
  item: TAdvItem;
begin
  AddItem('ToDelete', 5, 1);
  repo := TEntityRepository<TAdvItem>.Create(FContext.Items, 'Id');
  item := repo.GetById(1);
  try
    Assert.IsTrue(repo.Delete(item), 'Repository.Delete must return True');
  finally
    item.Free;
  end;
  Assert.AreEqual<Int64>(0, ExecuteScalarInt('SELECT COUNT(*) FROM adv_items'));
end;

procedure TQuickCoreEntityAdvancedTests.T_EN_23_Repository_Count;
var
  repo: IRepository<TAdvItem>;
begin
  AddItem('A', 1);
  AddItem('B', 2);
  AddItem('C', 3);
  repo := TEntityRepository<TAdvItem>.Create(FContext.Items, 'Id');
  Assert.AreEqual<Int64>(3, repo.Count, 'Count must return the total number of entities');
end;

procedure TQuickCoreEntityAdvancedTests.T_EN_24_Repository_Exists;
var
  repo: IRepository<TAdvItem>;
begin
  AddItem('Exist', 1, 42);
  repo := TEntityRepository<TAdvItem>.Create(FContext.Items, 'Id');
  Assert.IsTrue(repo.Exists(42), 'Exists must return True for an entity that was added');
  Assert.IsFalse(repo.Exists(999), 'Exists must return False for an entity that was not added');
end;

procedure TQuickCoreEntityAdvancedTests.T_EN_25_Repository_Find;
var
  repo: IRepository<TAdvItem>;
  list: TList<TAdvItem>;
begin
  AddItem('Alpha', 10);
  AddItem('Beta', 20);
  AddItem('Gamma', 10);
  repo := TEntityRepository<TAdvItem>.Create(FContext.Items, 'Id');
  list := repo.Find('Qty = %d', [10]);
  try
    Assert.AreEqual(NativeInt(2), list.Count, 'Find must return entities matching the WHERE clause');
  finally
    list.Free;
  end;
end;

{ --- Unit of Work tests (T-EN-26..27) --- }

procedure TQuickCoreEntityAdvancedTests.T_EN_26_UnitOfWork_Execute_Commits_On_Success;
var
  uow: IUnitOfWork;
  item: TAdvItem;
begin
  uow := TUnitOfWork.Create(FContext);
  Assert.IsTrue(
    uow.Execute(
      procedure
      begin
        item := TAdvItem.Create;
        try
          item.Name := 'UoWCommit';
          item.Qty := 3;
          FContext.Items.Add(item);
        finally
          item.Free;
        end;
      end),
    'Execute must return True when the procedure succeeds');
  Assert.AreEqual<Int64>(1, ExecuteScalarInt('SELECT COUNT(*) FROM adv_items'),
    'Entity added inside UoW.Execute must be visible after commit');
end;

procedure TQuickCoreEntityAdvancedTests.T_EN_27_UnitOfWork_Execute_Rollback_On_Exception;
var
  uow: IUnitOfWork;
  item: TAdvItem;
begin
  uow := TUnitOfWork.Create(FContext);
  Assert.IsFalse(
    uow.Execute(
      procedure
      begin
        item := TAdvItem.Create;
        try
          item.Name := 'ShouldRollback';
          item.Qty := 1;
          FContext.Items.Add(item);
        finally
          item.Free;
        end;
        raise Exception.Create('simulated failure');
      end),
    'Execute must return False when the procedure raises');
  Assert.AreEqual<Int64>(0, ExecuteScalarInt('SELECT COUNT(*) FROM adv_items'),
    'Entity added inside a rolled-back UoW.Execute must not be visible');
end;

{ --- Soft Delete test (T-EN-28) --- }

procedure TQuickCoreEntityAdvancedTests.T_EN_28_SoftDelete_Hides_Deleted_Entities;
var
  item: TAdvSoftItem;
  found: TObjectList<TAdvSoftItem>;
begin
  // Add a soft-deletable entity
  item := TAdvSoftItem.Create;
  try
    item.&Label := 'Visible';
    Assert.IsTrue(FContext.SoftItems.Add(item));
  finally
    item.Free;
  end;
  // Verify it's returned before deletion
  found := TObjectList<TAdvSoftItem>.Create(True);
  try
    FContext.SoftItems.Where('').Select.ToObjectList(found);
    Assert.AreEqual(NativeInt(1), found.Count, 'One entity must be visible before soft-delete');
  finally
    found.Free;
  end;
  // Soft-delete: Delete sets IsDeleted=1 instead of removing the row
  item := TAdvSoftItem.Create;
  try
    item.Id := 1;
    FContext.SoftItems.Delete(item);
  finally
    item.Free;
  end;
  // After soft-delete: query auto-filters IsDeleted=0, returns nothing
  found := TObjectList<TAdvSoftItem>.Create(True);
  try
    FContext.SoftItems.Where('').Select.ToObjectList(found);
    Assert.AreEqual(NativeInt(0), found.Count,
      'Soft-deleted entity must not appear in a filtered query');
  finally
    found.Free;
  end;
  // But the row still physically exists in the DB
  Assert.AreEqual<Int64>(1,
    ExecuteScalarInt('SELECT COUNT(*) FROM adv_soft_items'),
    'Soft-deleted row must still exist in the database');
end;

{ --- Optimistic Concurrency tests (T-EN-29..30) --- }

procedure TQuickCoreEntityAdvancedTests.T_EN_29_OptimisticConcurrency_RowVersion_Increments;
var
  item: TAdvRvItem;
  loaded: TObjectList<TAdvRvItem>;
begin
  // Add item with RowVersion=0 (initial)
  item := TAdvRvItem.Create;
  try
    item.Title := 'RV Test';
    Assert.IsTrue(FContext.RvItems.Add(item));
  finally
    item.Free;
  end;
  // Load and update
  loaded := TObjectList<TAdvRvItem>.Create(True);
  try
    FContext.RvItems.Where('').Select.ToObjectList(loaded);
    Assert.AreEqual(NativeInt(1), loaded.Count);
    item := loaded[0];
    item.Title := 'Updated';
    Assert.IsTrue(FContext.RvItems.Update(item),
      'First Update must succeed when RowVersion matches');
    Assert.AreEqual(1, item.RowVersion,
      'RowVersion must be incremented to 1 after the first update');
  finally
    loaded.Free;
  end;
end;

procedure TQuickCoreEntityAdvancedTests.T_EN_30_OptimisticConcurrency_Conflict_Raises;
var
  item: TAdvRvItem;
  loaded: TObjectList<TAdvRvItem>;
begin
  // Add and update once to set RowVersion=1
  item := TAdvRvItem.Create;
  try
    item.Title := 'OCC Test';
    FContext.RvItems.Add(item);
  finally
    item.Free;
  end;
  loaded := TObjectList<TAdvRvItem>.Create(True);
  try
    FContext.RvItems.Where('').Select.ToObjectList(loaded);
    Assert.AreEqual(NativeInt(1), loaded.Count);
    item := loaded[0];
    item.Title := 'First Update';
    FContext.RvItems.Update(item); // RowVersion: 0 → 1
    // Simulate stale update: rewind RowVersion to simulate another caller
    item.RowVersion := 0;
    item.Title := 'Stale Update';
    Assert.WillRaise(
      procedure
      begin
        FContext.RvItems.Update(item);
      end,
      ExceptClass(EOptimisticConcurrencyException),
      'Update with stale RowVersion must raise EOptimisticConcurrencyException');
  finally
    loaded.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TQuickCoreEntityAdvancedTests);

end.
