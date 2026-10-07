unit Quick.Core.Entity.Tests;

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
  Quick.Core.Entity.QueryGenerator.MSSQL;

type
  [Table('entity_test_products')]
  TEntityTestProduct = class(TEntity)
  private
    FId: TAutoID;
    FName: string;
    FCategory: string;
    FPrice: Double;
    FStock: Integer;
    FActive: Boolean;
  published
    [Key]
    property Id: TAutoID read FId write FId;
    [MapField('product_name')]
    [StringLength(80)]
    property Name: string read FName write FName;
    [StringLength(40)]
    property Category: string read FCategory write FCategory;
    [MapField('unit_price')]
    [DecimalLength(10, 2)]
    property Price: Double read FPrice write FPrice;
    property Stock: Integer read FStock write FStock;
    property Active: Boolean read FActive write FActive;
  end;

  TEntityOrmTestContext = class(TDBContext)
  private
    FProducts: TDBSet<TEntityTestProduct>;
  public
    [&Index('product_name')]
    property Products: TDBSet<TEntityTestProduct> read FProducts write FProducts;
    function IsConnected: Boolean; override;
  end;

  [TestFixture]
  TQuickCoreEntityTests = class
  private
    FContext: TEntityOrmTestContext;
    FDatabasePath: string;
    procedure AddSeedProduct(const AName, ACategory: string; APrice: Double;
      AStock: Integer; AActive: Boolean; AId: TAutoID = 0);
    function ColumnExists(const ATableName, AColumnName: string): Boolean;
    function ColumnType(const ATableName, AColumnName: string): string;
    function CreateInspectionConnection: TFDConnection;
    function ExecuteScalarInt(const ASql: string): Int64;
    function ExecuteScalarString(const ASql: string): string;
    function IndexExists(const AIndexName: string): Boolean;
    function TableExists(const ATableName: string): Boolean;
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure T_EN_01_CreateTable;
    [Test]
    procedure T_EN_02_Add_Entity;
    [Test]
    procedure T_EN_03_AddOrUpdate_Entity;
    [Test]
    procedure T_EN_04_Delete_Entity;
    [Test]
    procedure T_EN_05_Where_Simple;
    [Test]
    procedure T_EN_06_Where_With_Multiple_Conditions;
    [Test]
    procedure T_EN_07_OrderBy_Ascending;
    [Test]
    procedure T_EN_08_OrderBy_Descending;
    [Test]
    procedure T_EN_09_SelectFirst;
    [Test]
    procedure T_EN_10_SelectTop;
    [Test]
    procedure T_EN_11_Count;
    [Test]
    procedure T_EN_12_Sum_Field;
    [Test]
    procedure T_EN_13_WithNoLock;
    [Test]
    procedure T_EN_14_Key_Attribute_AutoID;
    [Test]
    procedure T_EN_15_StringLength_Attribute;
    [Test]
    procedure T_EN_16_DecimalLength_Attribute;
    [Test]
    procedure T_EN_17_MapField_And_Table_Attribute;
    [Test]
    procedure T_EN_18_Index_Attribute;
  end;

implementation

{ TEntityOrmTestContext }

function TEntityOrmTestContext.IsConnected: Boolean;
begin
  Result := Database.IsConnected;
end;

{ TQuickCoreEntityTests }

procedure TQuickCoreEntityTests.AddSeedProduct(const AName, ACategory: string;
  APrice: Double; AStock: Integer; AActive: Boolean; AId: TAutoID = 0);
var
  product: TEntityTestProduct;
begin
  product := TEntityTestProduct.Create;
  try
    product.Id := AId;
    product.Name := AName;
    product.Category := ACategory;
    product.Price := APrice;
    product.Stock := AStock;
    product.Active := AActive;
    Assert.IsTrue(FContext.Products.Add(product));
  finally
    product.Free;
  end;
end;

function TQuickCoreEntityTests.ColumnExists(const ATableName,
  AColumnName: string): Boolean;
var
  conn: TFDConnection;
  qry: TFDQuery;
begin
  conn := CreateInspectionConnection;
  qry := TFDQuery.Create(nil);
  try
    qry.Connection := conn;
    qry.SQL.Text := Format('PRAGMA table_info(%s)', [ATableName]);
    qry.Open;
    Result := False;
    while not qry.Eof do
    begin
      if SameText(qry.FieldByName('name').AsString, AColumnName) then
        Exit(True);
      qry.Next;
    end;
  finally
    qry.Free;
    conn.Free;
  end;
end;

function TQuickCoreEntityTests.ColumnType(const ATableName,
  AColumnName: string): string;
var
  conn: TFDConnection;
  qry: TFDQuery;
begin
  conn := CreateInspectionConnection;
  qry := TFDQuery.Create(nil);
  try
    qry.Connection := conn;
    qry.SQL.Text := Format('PRAGMA table_info(%s)', [ATableName]);
    qry.Open;
    Result := '';
    while not qry.Eof do
    begin
      if SameText(qry.FieldByName('name').AsString, AColumnName) then
        Exit(qry.FieldByName('type').AsString);
      qry.Next;
    end;
  finally
    qry.Free;
    conn.Free;
  end;
end;

function TQuickCoreEntityTests.CreateInspectionConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  Result.LoginPrompt := False;
  Result.Params.Clear;
  Result.Params.Add('DriverID=SQLite');
  Result.Params.Add('Database=' + FDatabasePath);
  Result.Connected := True;
end;

function TQuickCoreEntityTests.ExecuteScalarInt(const ASql: string): Int64;
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

function TQuickCoreEntityTests.ExecuteScalarString(const ASql: string): string;
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
    Result := qry.Fields[0].AsString;
  finally
    qry.Free;
    conn.Free;
  end;
end;

function TQuickCoreEntityTests.IndexExists(const AIndexName: string): Boolean;
var
  conn: TFDConnection;
  qry: TFDQuery;
begin
  conn := CreateInspectionConnection;
  qry := TFDQuery.Create(nil);
  try
    qry.Connection := conn;
    qry.SQL.Text := 'SELECT name FROM sqlite_master WHERE type = ''index'' AND name = :name';
    qry.ParamByName('name').AsString := AIndexName;
    qry.Open;
    Result := not qry.Eof;
  finally
    qry.Free;
    conn.Free;
  end;
end;

procedure TQuickCoreEntityTests.SetUp;
var
  database: TEntityDatabase;
begin
  FDatabasePath := TPath.Combine(TPath.GetTempPath, TGuid.NewGuid.ToString + '.db');
  database := TEntityDatabaseFactory.GetInstance(TDatabaseEngine.deFireDAC);
  database.Connection.FromConnectionString(Integer(TDBProvider.dbSQLite), 'Database=' + FDatabasePath);
  FContext := TEntityOrmTestContext.Create(database);
  Assert.IsTrue(FContext.Connect);
end;

function TQuickCoreEntityTests.TableExists(const ATableName: string): Boolean;
var
  conn: TFDConnection;
  qry: TFDQuery;
begin
  conn := CreateInspectionConnection;
  qry := TFDQuery.Create(nil);
  try
    qry.Connection := conn;
    qry.SQL.Text := 'SELECT name FROM sqlite_master WHERE type = ''table'' AND name = :name';
    qry.ParamByName('name').AsString := ATableName;
    qry.Open;
    Result := not qry.Eof;
  finally
    qry.Free;
    conn.Free;
  end;
end;

procedure TQuickCoreEntityTests.TearDown;
begin
  FContext.Free;
  FContext := nil;
  if TFile.Exists(FDatabasePath) then
    TFile.Delete(FDatabasePath);
end;

procedure TQuickCoreEntityTests.T_EN_01_CreateTable;
begin
  Assert.IsTrue(TableExists('entity_test_products'));
end;

procedure TQuickCoreEntityTests.T_EN_02_Add_Entity;
begin
  AddSeedProduct('Notebook', 'Stationery', 10, 5, True);

  Assert.AreEqual<Int64>(1, ExecuteScalarInt('SELECT COUNT(*) FROM [entity_test_products]'));
  Assert.AreEqual('Notebook', ExecuteScalarString('SELECT product_name FROM [entity_test_products] LIMIT 1'));
end;

procedure TQuickCoreEntityTests.T_EN_03_AddOrUpdate_Entity;
var
  product: TEntityTestProduct;
begin
  product := TEntityTestProduct.Create;
  try
    product.Id := 100;
    product.Name := 'Phone';
    product.Category := 'Electronics';
    product.Price := 699;
    product.Stock := 3;
    product.Active := True;
    Assert.IsTrue(FContext.Products.AddOrUpdate(product));

    product.Name := 'Phone Pro';
    product.Price := 799;
    product.Stock := 4;
    Assert.IsTrue(FContext.Products.AddOrUpdate(product));
  finally
    product.Free;
  end;

  Assert.AreEqual<Int64>(1, ExecuteScalarInt('SELECT COUNT(*) FROM [entity_test_products] WHERE id = 100'));
  Assert.AreEqual('Phone Pro', ExecuteScalarString('SELECT product_name FROM [entity_test_products] WHERE id = 100'));
end;

procedure TQuickCoreEntityTests.T_EN_04_Delete_Entity;
var
  product: TEntityTestProduct;
begin
  AddSeedProduct('Delete Me', 'Temp', 1, 1, True, 200);

  product := TEntityTestProduct.Create;
  try
    product.Id := 200;
    Assert.IsTrue(FContext.Products.Delete(product));
  finally
    product.Free;
  end;

  Assert.AreEqual<Int64>(0, ExecuteScalarInt('SELECT COUNT(*) FROM [entity_test_products] WHERE id = 200'));
end;

procedure TQuickCoreEntityTests.T_EN_05_Where_Simple;
var
  product: TEntityTestProduct;
begin
  AddSeedProduct('Phone', 'Electronics', 300, 3, True);
  AddSeedProduct('Pen', 'Stationery', 2, 10, True);

  product := FContext.Products.Where('product_name = ?', ['Phone']).SelectFirst;
  try
    Assert.IsNotNull(product);
    Assert.AreEqual('Phone', product.Name);
  finally
    product.Free;
  end;
end;

procedure TQuickCoreEntityTests.T_EN_06_Where_With_Multiple_Conditions;
var
  results: IDBSetResult<TEntityTestProduct>;
begin
  AddSeedProduct('Phone', 'Electronics', 300, 3, True);
  AddSeedProduct('Phone', 'Accessories', 30, 8, True);

  results := IDBSetResult<TEntityTestProduct>(
    FContext.Products.Where('product_name = ? AND category = ?', ['Phone', 'Electronics']).Select);

  Assert.AreEqual(1, results.Count);
end;

procedure TQuickCoreEntityTests.T_EN_07_OrderBy_Ascending;
var
  product: TEntityTestProduct;
begin
  AddSeedProduct('Cable', 'Accessories', 20, 5, True);
  AddSeedProduct('Adapter', 'Accessories', 15, 5, True);
  AddSeedProduct('Battery', 'Accessories', 25, 5, True);

  product := FContext.Products.OrderBy('product_name').SelectFirst;
  try
    Assert.AreEqual('Adapter', product.Name);
  finally
    product.Free;
  end;
end;

procedure TQuickCoreEntityTests.T_EN_08_OrderBy_Descending;
var
  product: TEntityTestProduct;
begin
  AddSeedProduct('Cable', 'Accessories', 20, 5, True);
  AddSeedProduct('Adapter', 'Accessories', 15, 5, True);
  AddSeedProduct('Battery', 'Accessories', 25, 5, True);

  product := FContext.Products.OrderByDescending('product_name').SelectFirst;
  try
    Assert.AreEqual('Cable', product.Name);
  finally
    product.Free;
  end;
end;

procedure TQuickCoreEntityTests.T_EN_09_SelectFirst;
var
  product: TEntityTestProduct;
begin
  AddSeedProduct('Book A', 'Books', 15, 10, True, 301);
  AddSeedProduct('Book B', 'Books', 25, 10, True, 302);

  product := FContext.Products.Where('category = ?', ['Books']).OrderBy('unit_price').SelectFirst;
  try
    Assert.AreEqual<TAutoID>(301, product.Id);
    Assert.AreEqual('Book A', product.Name);
  finally
    product.Free;
  end;
end;

procedure TQuickCoreEntityTests.T_EN_10_SelectTop;
var
  list: TObjectList<TEntityTestProduct>;
  results: IEntityResult<TEntityTestProduct>;
begin
  AddSeedProduct('Cable', 'Accessories', 20, 5, True);
  AddSeedProduct('Adapter', 'Accessories', 15, 5, True);
  AddSeedProduct('Battery', 'Accessories', 25, 5, True);

  results := FContext.Products.OrderBy('product_name').SelectTop(2);
  list := TObjectList<TEntityTestProduct>.Create(True);
  try
    results.ToObjectList(list);
    Assert.AreEqual(NativeInt(2), list.Count);
    Assert.AreEqual('Adapter', list[0].Name);
    Assert.AreEqual('Battery', list[1].Name);
  finally
    list.Free;
  end;
end;

procedure TQuickCoreEntityTests.T_EN_11_Count;
begin
  AddSeedProduct('Phone', 'Electronics', 300, 3, True);
  AddSeedProduct('Tablet', 'Electronics', 500, 2, True);
  AddSeedProduct('Pen', 'Stationery', 2, 10, True);

  Assert.AreEqual<Int64>(2, FContext.Products.Where('category = ?', ['Electronics']).Count);
end;

procedure TQuickCoreEntityTests.T_EN_12_Sum_Field;
begin
  AddSeedProduct('Phone', 'Electronics', 10, 3, True);
  AddSeedProduct('Tablet', 'Electronics', 20, 2, True);
  AddSeedProduct('Pen', 'Stationery', 2, 10, True);

  Assert.AreEqual<Int64>(30, FContext.Products.Where('category = ?', ['Electronics']).Sum('unit_price'));
end;

procedure TQuickCoreEntityTests.T_EN_13_WithNoLock;
var
  generator: TMSSQLQueryGenerator;
  sql: string;
begin
  generator := TMSSQLQueryGenerator.Create;
  try
    sql := generator.Select('Products', '', 0, '1=1', '', True, True);
    Assert.IsTrue(sql.Contains('WITH(NOLOCK)'));
  finally
    generator.Free;
  end;
end;

procedure TQuickCoreEntityTests.T_EN_14_Key_Attribute_AutoID;
begin
  AddSeedProduct('Auto Product', 'Generated', 5, 1, True);

  Assert.IsTrue(ExecuteScalarInt('SELECT id FROM [entity_test_products] WHERE product_name = ''Auto Product'' LIMIT 1') > 0);
end;

procedure TQuickCoreEntityTests.T_EN_15_StringLength_Attribute;
begin
  Assert.IsTrue(LowerCase(ColumnType('entity_test_products', 'product_name')).Contains('varchar(80)'));
end;

procedure TQuickCoreEntityTests.T_EN_16_DecimalLength_Attribute;
begin
  Assert.IsTrue(LowerCase(ColumnType('entity_test_products', 'unit_price')).Contains('decimal(10,2)'));
end;

procedure TQuickCoreEntityTests.T_EN_17_MapField_And_Table_Attribute;
begin
  Assert.IsTrue(TableExists('entity_test_products'));
  Assert.IsTrue(ColumnExists('entity_test_products', 'product_name'));
  Assert.IsTrue(ColumnExists('entity_test_products', 'unit_price'));
end;

procedure TQuickCoreEntityTests.T_EN_18_Index_Attribute;
begin
  Assert.IsTrue(IndexExists('PK_product_name'));
end;

initialization
  TDUnitX.RegisterTestFixture(TQuickCoreEntityTests);

end.