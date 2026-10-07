unit Quick.Core.Entity.QueryGenerators.Tests;

{ Tests: T-QG-01..18
  MySQL (T-QG-01..06)
    T-QG-01  TMySQLQueryGenerator.Name returns 'MySQL'
    T-QG-02  TMySQLQueryGenerator.Select contains table name
    T-QG-03  TMySQLQueryGenerator.Select contains WHERE clause
    T-QG-04  TMySQLQueryGenerator.Add contains INSERT keyword
    T-QG-05  TMySQLQueryGenerator.Update contains UPDATE keyword
    T-QG-06  TMySQLQueryGenerator.Delete contains DELETE keyword

  PostgreSQL (T-QG-07..12)
    T-QG-07  TPostgreSQLQueryGenerator.Name returns 'PostgreSQL'
    T-QG-08  TPostgreSQLQueryGenerator.Select contains table name
    T-QG-09  TPostgreSQLQueryGenerator.Select with LIMIT adds LIMIT clause
    T-QG-10  TPostgreSQLQueryGenerator.Add contains INSERT keyword
    T-QG-11  TPostgreSQLQueryGenerator.Update contains UPDATE keyword
    T-QG-12  TPostgreSQLQueryGenerator.Delete contains DELETE keyword

  MSAccess (T-QG-13..18)
    T-QG-13  TMSAccessQueryGenerator.Name returns non-empty
    T-QG-14  TMSAccessQueryGenerator.Select contains table name
    T-QG-15  TMSAccessQueryGenerator.Select contains WHERE clause
    T-QG-16  TMSAccessQueryGenerator.Add contains INSERT keyword
    T-QG-17  TMSAccessQueryGenerator.Update contains UPDATE keyword
    T-QG-18  TMSAccessQueryGenerator.Delete contains DELETE keyword
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Quick.Core.Entity.QueryGenerator.MySQL,
  Quick.Core.Entity.QueryGenerator.PostgreSQL,
  Quick.Core.Entity.QueryGenerator.MSAccess;

type

  [TestFixture]
  TQueryGeneratorsTests = class
  private
    fMySQL    : TMySQLQueryGenerator;
    fPostgre  : TPostgreSQLQueryGenerator;
    fMSAccess : TMSAccessQueryGenerator;
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    // ── MySQL ──────────────────────────────────────────────────────────────
    [Test]
    procedure T_QG_01_MySQL_Name;
    [Test]
    procedure T_QG_02_MySQL_Select_ContainsTable;
    [Test]
    procedure T_QG_03_MySQL_Select_ContainsWhere;
    [Test]
    procedure T_QG_04_MySQL_Add_ContainsInsert;
    [Test]
    procedure T_QG_05_MySQL_Update_ContainsUpdate;
    [Test]
    procedure T_QG_06_MySQL_Delete_ContainsDelete;

    // ── PostgreSQL ─────────────────────────────────────────────────────────
    [Test]
    procedure T_QG_07_PostgreSQL_Name;
    [Test]
    procedure T_QG_08_PostgreSQL_Select_ContainsTable;
    [Test]
    procedure T_QG_09_PostgreSQL_Select_WithLimit;
    [Test]
    procedure T_QG_10_PostgreSQL_Add_ContainsInsert;
    [Test]
    procedure T_QG_11_PostgreSQL_Update_ContainsUpdate;
    [Test]
    procedure T_QG_12_PostgreSQL_Delete_ContainsDelete;

    // ── MSAccess ───────────────────────────────────────────────────────────
    [Test]
    procedure T_QG_13_MSAccess_Name_NonEmpty;
    [Test]
    procedure T_QG_14_MSAccess_Select_ContainsTable;
    [Test]
    procedure T_QG_15_MSAccess_Select_ContainsWhere;
    [Test]
    procedure T_QG_16_MSAccess_Add_ContainsInsert;
    [Test]
    procedure T_QG_17_MSAccess_Update_ContainsUpdate;
    [Test]
    procedure T_QG_18_MSAccess_Delete_ContainsDelete;
  end;

implementation

{ TQueryGeneratorsTests }

procedure TQueryGeneratorsTests.SetUp;
begin
  fMySQL    := TMySQLQueryGenerator.Create;
  fPostgre  := TPostgreSQLQueryGenerator.Create;
  fMSAccess := TMSAccessQueryGenerator.Create;
end;

procedure TQueryGeneratorsTests.TearDown;
begin
  fMSAccess.Free;
  fPostgre.Free;
  fMySQL.Free;
end;

// ─── MySQL ────────────────────────────────────────────────────────────────────

procedure TQueryGeneratorsTests.T_QG_01_MySQL_Name;
begin
  Assert.AreEqual('MySQL', fMySQL.Name);
end;

procedure TQueryGeneratorsTests.T_QG_02_MySQL_Select_ContainsTable;
var
  sql : string;
begin
  sql := fMySQL.Select('products', '*', 0, '', '', True, False);
  Assert.IsTrue(sql.ToLower.Contains('products'),
    'MySQL SELECT should contain the table name');
end;

procedure TQueryGeneratorsTests.T_QG_03_MySQL_Select_ContainsWhere;
var
  sql : string;
begin
  sql := fMySQL.Select('orders', 'id', 0, 'status=1', '', True, False);
  Assert.IsTrue(sql.Contains('status=1'),
    'MySQL SELECT should include the WHERE predicate');
end;

procedure TQueryGeneratorsTests.T_QG_04_MySQL_Add_ContainsInsert;
var
  sql : string;
begin
  sql := fMySQL.Add('users', 'name,age', '''Alice'',30');
  Assert.IsTrue(sql.ToLower.Contains('insert'),
    'MySQL Add should generate an INSERT statement');
end;

procedure TQueryGeneratorsTests.T_QG_05_MySQL_Update_ContainsUpdate;
var
  sql : string;
begin
  sql := fMySQL.Update('users', 'name=''Bob''', 'id=1');
  Assert.IsTrue(sql.ToLower.Contains('update'),
    'MySQL Update should generate an UPDATE statement');
end;

procedure TQueryGeneratorsTests.T_QG_06_MySQL_Delete_ContainsDelete;
var
  sql : string;
begin
  sql := fMySQL.Delete('users', 'id=1');
  Assert.IsTrue(sql.ToLower.Contains('delete'),
    'MySQL Delete should generate a DELETE statement');
end;

// ─── PostgreSQL ───────────────────────────────────────────────────────────────

procedure TQueryGeneratorsTests.T_QG_07_PostgreSQL_Name;
begin
  Assert.AreEqual('PostgreSQL', fPostgre.Name);
end;

procedure TQueryGeneratorsTests.T_QG_08_PostgreSQL_Select_ContainsTable;
var
  sql : string;
begin
  sql := fPostgre.Select('products', '*', 0, '', '', True, False);
  Assert.IsTrue(sql.ToLower.Contains('products'),
    'PostgreSQL SELECT should contain the table name');
end;

procedure TQueryGeneratorsTests.T_QG_09_PostgreSQL_Select_WithLimit;
var
  sql : string;
begin
  sql := fPostgre.Select('products', '*', 10, '', '', True, False);
  Assert.IsTrue(sql.ToLower.Contains('limit'),
    'PostgreSQL SELECT with limit > 0 should include LIMIT clause');
end;

procedure TQueryGeneratorsTests.T_QG_10_PostgreSQL_Add_ContainsInsert;
var
  sql : string;
begin
  sql := fPostgre.Add('users', 'name,age', '''Carol'',25');
  Assert.IsTrue(sql.ToLower.Contains('insert'),
    'PostgreSQL Add should generate an INSERT statement');
end;

procedure TQueryGeneratorsTests.T_QG_11_PostgreSQL_Update_ContainsUpdate;
var
  sql : string;
begin
  sql := fPostgre.Update('users', 'name=''Dan''', 'id=2');
  Assert.IsTrue(sql.ToLower.Contains('update'),
    'PostgreSQL Update should generate an UPDATE statement');
end;

procedure TQueryGeneratorsTests.T_QG_12_PostgreSQL_Delete_ContainsDelete;
var
  sql : string;
begin
  sql := fPostgre.Delete('orders', 'id=5');
  Assert.IsTrue(sql.ToLower.Contains('delete'),
    'PostgreSQL Delete should generate a DELETE statement');
end;

// ─── MSAccess ─────────────────────────────────────────────────────────────────

procedure TQueryGeneratorsTests.T_QG_13_MSAccess_Name_NonEmpty;
begin
  Assert.IsNotEmpty(fMSAccess.Name, 'MSAccess generator Name should not be empty');
end;

procedure TQueryGeneratorsTests.T_QG_14_MSAccess_Select_ContainsTable;
var
  sql : string;
begin
  sql := fMSAccess.Select('products', '*', 0, '', '', True, False);
  Assert.IsTrue(sql.ToLower.Contains('products'),
    'MSAccess SELECT should contain the table name');
end;

procedure TQueryGeneratorsTests.T_QG_15_MSAccess_Select_ContainsWhere;
var
  sql : string;
begin
  sql := fMSAccess.Select('orders', 'id', 0, 'paid=1', '', True, False);
  Assert.IsTrue(sql.Contains('paid=1'),
    'MSAccess SELECT should include the WHERE predicate');
end;

procedure TQueryGeneratorsTests.T_QG_16_MSAccess_Add_ContainsInsert;
var
  sql : string;
begin
  sql := fMSAccess.Add('customers', 'name', '''Eve''');
  Assert.IsTrue(sql.ToLower.Contains('insert'),
    'MSAccess Add should generate an INSERT statement');
end;

procedure TQueryGeneratorsTests.T_QG_17_MSAccess_Update_ContainsUpdate;
var
  sql : string;
begin
  sql := fMSAccess.Update('customers', 'name=''Frank''', 'id=3');
  Assert.IsTrue(sql.ToLower.Contains('update'),
    'MSAccess Update should generate an UPDATE statement');
end;

procedure TQueryGeneratorsTests.T_QG_18_MSAccess_Delete_ContainsDelete;
var
  sql : string;
begin
  sql := fMSAccess.Delete('customers', 'id=3');
  Assert.IsTrue(sql.ToLower.Contains('delete'),
    'MSAccess Delete should generate a DELETE statement');
end;

initialization
  TDUnitX.RegisterTestFixture(TQueryGeneratorsTests);

end.
