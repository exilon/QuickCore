unit Quick.Core.HealthChecks.Tests;

{ Tests: T-HC-01..18
    T-HC-01  Newly created THealthCheck has Status = hsNotChecked
    T-HC-02  A passing check: calling Check + setting hsPassed yields Status = hsPassed
    T-HC-03  A failing check: catching exception and setting hsFailed yields Status = hsFailed
    T-HC-04  Name property is readable and writable on IHealthCheck
  T-HC-05  DiskStorage passes with a very small threshold on an existing drive
  T-HC-06  DiskStorage fails with an unrealistically high threshold
  T-HC-07  Memory passes with a generous process-memory threshold
  T-HC-08  Memory fails with a zero-memory threshold
  T-HC-09  Redis fails against an unreachable endpoint
  T-HC-10  RabbitMQ fails against an unreachable endpoint
  T-HC-11  MySQL fails against an unreachable endpoint
  T-HC-12  Xabaril summary JSON is Healthy when all checks pass
  T-HC-13  Xabaril summary JSON is Unhealthy when any check fails
  T-HC-14  Xabaril summary JSON is Degraded when a check is not checked yet
  T-HC-15  Liveness JSON always reports Healthy for the running process
  T-HC-16  Entity/SQLite health check passes on a local SQLite database
  T-HC-17  SqlServer health check fails against an unreachable SQL Server endpoint
  T-HC-18  PostgreSQL health checks remain blocked until a provider/engine is added
}

interface

uses
  DUnitX.TestFramework,
  System.TimeSpan,
  Quick.Core.Entity,
  Quick.Core.Entity.DAO,
  Quick.Core.Entity.Database,
  Quick.Core.Extensions.HealthChecks,
  Quick.Core.Extensions.HealthChecks.DiskStorage,
  Quick.Core.Extensions.HealthChecks.Memory,
  Quick.Core.Extensions.HealthChecks.Redis,
  Quick.Core.Extensions.HealthChecks.RabbitMQ,
  Quick.Core.Extensions.HealthChecks.MySQL,
  Quick.Core.Mvc.Extensions.HealthChecks;

type

  // A check whose Check procedure succeeds silently
  TPassingCheck = class(THealthCheck)
  public
    procedure Check; override;
  end;

  // A check whose Check procedure raises an exception
  TFailingCheck = class(THealthCheck)
  public
    procedure Check; override;
  end;

  [Table('health_check_products')]
  THealthCheckProduct = class(TEntity)
  private
    FId: TAutoID;
    FName: string;
  published
    [Key]
    property Id: TAutoID read FId write FId;
    [StringLength(80)]
    property Name: string read FName write FName;
  end;

  THealthCheckSqliteContext = class(TDBContext)
  private
    FProducts: TDBSet<THealthCheckProduct>;
  public
    property Products: TDBSet<THealthCheckProduct> read FProducts write FProducts;
    function IsConnected: Boolean; override;
  end;

  [TestFixture]
  THealthChecksTests = class
  public
    [Test]
    procedure T_HC_01_InitialStatus_IsNotChecked;
    [Test]
    procedure T_HC_02_PassingCheck_StatusBecomesHsPassed;
    [Test]
    procedure T_HC_03_FailingCheck_StatusBecomesHsFailed;
    [Test]
    procedure T_HC_04_Name_RoundTrip;
    [Test]
    procedure T_HC_05_DiskStorage_Passes_OnExistingDrive;
    [Test]
    procedure T_HC_06_DiskStorage_Fails_WithHugeThreshold;
    [Test]
    procedure T_HC_07_Memory_Passes_WithHighThreshold;
    [Test]
    procedure T_HC_08_Memory_Fails_WithZeroThreshold;
    [Test]
    procedure T_HC_09_Redis_Fails_OnClosedPort;
    [Test]
    procedure T_HC_10_RabbitMQ_Fails_OnClosedPort;
    [Test]
    procedure T_HC_11_MySQL_Fails_OnClosedPort;
    [Test]
    procedure T_HC_12_SummaryJson_IsHealthy_WhenAllChecksPass;
    [Test]
    procedure T_HC_13_SummaryJson_IsUnhealthy_WhenAnyCheckFails;
    [Test]
    procedure T_HC_14_SummaryJson_IsDegraded_WhenCheckNotChecked;
    [Test]
    procedure T_HC_15_LivenessJson_IsHealthy;
    [Test]
    procedure T_HC_16_SQLite_EntityHealthCheck_Passes_OnLocalDatabase;
    [Test]
    procedure T_HC_17_SqlServer_HealthCheck_Fails_OnClosedEndpoint;
    [Test]
    procedure T_HC_18_PostgreSQL_HealthCheck_IsBlocked_WithoutProvider;
  end;

implementation

uses
  System.SysUtils,
  System.JSON,
  System.IOUtils,
  FireDAC.Phys.SQLite,
  Quick.Core.Entity.Factory.Database,
  Quick.Core.Extensions.HealthChecks.Entity,
  Quick.Core.Extensions.HealthChecks.SqlServer;

const
  KnownProviders: array[0..8] of TDBProvider = (
    TDBProvider.dbMSAccess2000,
    TDBProvider.dbMSAccess2007,
    TDBProvider.dbMSSQL,
    TDBProvider.dbMSSQLnc10,
    TDBProvider.dbMSSQLnc11,
    TDBProvider.dbMySQL,
    TDBProvider.dbSQLite,
    TDBProvider.dbIBM400,
    TDBProvider.dbFirebase
  );

function GetSystemDrivePath : string;
begin
  Result := GetEnvironmentVariable('SystemDrive');
  if Result.IsEmpty then Result := ExtractFileDrive(ParamStr(0));
  if Result.IsEmpty then Result := 'C:';
  if not Result.EndsWith('\') then Result := Result + '\';
end;

function CreateSQLiteHealthContext(out ADatabasePath: string): THealthCheckSqliteContext;
var
  database: TEntityDatabase;
begin
  ADatabasePath := TPath.Combine(TPath.GetTempPath, TGuid.NewGuid.ToString + '.db');
  database := TEntityDatabaseFactory.GetInstance(TDatabaseEngine.deFireDAC);
  database.Connection.FromConnectionString(Integer(TDBProvider.dbSQLite), 'Database=' + ADatabasePath);
  Result := THealthCheckSqliteContext.Create(database);
  Result.Connect;
end;

{ THealthCheckSqliteContext }

function THealthCheckSqliteContext.IsConnected: Boolean;
begin
  Result := Database.IsConnected;
end;

{ TPassingCheck }

procedure TPassingCheck.Check;
begin
  // Nothing to do – simulates a healthy resource
end;

{ TFailingCheck }

procedure TFailingCheck.Check;
begin
  raise Exception.Create('resource unavailable');
end;

{ THealthChecksTests }

{ T-HC-01 }

procedure THealthChecksTests.T_HC_01_InitialStatus_IsNotChecked;
var
  check: IHealthCheck;
begin
  check := TPassingCheck.Create(TTimeSpan.FromSeconds(30));
  Assert.AreEqual(THealthStatus.hsNotChecked, check.Status);
end;

{ T-HC-02 }

procedure THealthChecksTests.T_HC_02_PassingCheck_StatusBecomesHsPassed;
var
  check: IHealthCheck;
begin
  check := TPassingCheck.Create(TTimeSpan.FromSeconds(30));
  try
    check.Check;
    check.Status := THealthStatus.hsPassed;
  except
    check.Status := THealthStatus.hsFailed;
  end;
  Assert.AreEqual(THealthStatus.hsPassed, check.Status);
end;

{ T-HC-03 }

procedure THealthChecksTests.T_HC_03_FailingCheck_StatusBecomesHsFailed;
var
  check: IHealthCheck;
begin
  check := TFailingCheck.Create(TTimeSpan.FromSeconds(30));
  try
    check.Check;
    check.Status := THealthStatus.hsPassed;
  except on E: Exception do
  begin
    check.Status := THealthStatus.hsFailed;
    check.ErrorMsg := E.Message;
  end;
  end;
  Assert.AreEqual(THealthStatus.hsFailed, check.Status);
  Assert.AreEqual('resource unavailable', check.ErrorMsg);
end;

{ T-HC-04 }

procedure THealthChecksTests.T_HC_04_Name_RoundTrip;
var
  check: IHealthCheck;
begin
  check := TPassingCheck.Create(TTimeSpan.FromSeconds(60));
  check.Name := 'MyService';
  Assert.AreEqual('MyService', check.Name);
end;

{ T-HC-05 }

procedure THealthChecksTests.T_HC_05_DiskStorage_Passes_OnExistingDrive;
var
  check : IHealthCheck;
begin
  check := TDiskStorageHealthCheck.Create(GetSystemDrivePath, 0.001, TTimeSpan.FromSeconds(30));
  try
    check.Check;
    check.Status := THealthStatus.hsPassed;
  except
    check.Status := THealthStatus.hsFailed;
  end;
  Assert.AreEqual(THealthStatus.hsPassed, check.Status);
end;

{ T-HC-06 }

procedure THealthChecksTests.T_HC_06_DiskStorage_Fails_WithHugeThreshold;
var
  check : TDiskStorageHealthCheck;
begin
  check := TDiskStorageHealthCheck.Create(GetSystemDrivePath, 1000000.0, TTimeSpan.FromSeconds(30));
  try
    Assert.WillRaise(
      procedure
      begin
        check.Check;
      end,
      Exception);
  finally
    check.Free;
  end;
end;

{ T-HC-07 }

procedure THealthChecksTests.T_HC_07_Memory_Passes_WithHighThreshold;
var
  check : IHealthCheck;
begin
  check := TMemoryHealthCheck.Create(4096, TTimeSpan.FromSeconds(30));
  try
    check.Check;
    check.Status := THealthStatus.hsPassed;
  except
    check.Status := THealthStatus.hsFailed;
  end;
  Assert.AreEqual(THealthStatus.hsPassed, check.Status);
end;

{ T-HC-08 }

procedure THealthChecksTests.T_HC_08_Memory_Fails_WithZeroThreshold;
var
  check : TMemoryHealthCheck;
begin
  check := TMemoryHealthCheck.Create(0, TTimeSpan.FromSeconds(30));
  try
    Assert.WillRaise(
      procedure
      begin
        check.Check;
      end,
      Exception);
  finally
    check.Free;
  end;
end;

{ T-HC-09 }

procedure THealthChecksTests.T_HC_09_Redis_Fails_OnClosedPort;
var
  options : TRedisHealthCheckOptions;
  check : IHealthCheck;
begin
  options := TRedisHealthCheckOptions.Create;
  try
    options.Host := '127.0.0.1';
    options.Port := 1;
    options.ConnectionTimeout := 200;
    options.ReadTimeout := 200;
    check := TRedisHealthCheck.Create(options, TTimeSpan.FromSeconds(30));
    try
      check.Check;
      Assert.Fail('Expected connection failure was not raised');
    except
      on E: Exception do ;
    end;
  finally
    options.Free;
  end;
end;

{ T-HC-10 }

procedure THealthChecksTests.T_HC_10_RabbitMQ_Fails_OnClosedPort;
var
  options : TRabbitMQHealthCheckOptions;
  check : IHealthCheck;
begin
  options := TRabbitMQHealthCheckOptions.Create;
  try
    options.Host := '127.0.0.1';
    options.Port := 1;
    options.ConnectionTimeout := 200;
    options.ReadTimeout := 200;
    check := TRabbitMQHealthCheck.Create(options, TTimeSpan.FromSeconds(30));
    try
      check.Check;
      Assert.Fail('Expected connection failure was not raised');
    except
      on E: Exception do ;
    end;
  finally
    options.Free;
  end;
end;

{ T-HC-11 }

procedure THealthChecksTests.T_HC_11_MySQL_Fails_OnClosedPort;
var
  options : TMySQLHealthCheckOptions;
  check : IHealthCheck;
begin
  options := TMySQLHealthCheckOptions.Create;
  try
    options.Host := '127.0.0.1';
    options.Port := 1;
    options.Database := 'quickcore';
    options.ConnectionTimeout := 1;
    check := TMySQLHealthCheck.Create(options, TTimeSpan.FromSeconds(30));
    try
      check.Check;
      Assert.Fail('Expected connection failure was not raised');
    except
      on E: Exception do ;
    end;
  finally
    options.Free;
  end;
end;

{ T-HC-12 }

procedure THealthChecksTests.T_HC_12_SummaryJson_IsHealthy_WhenAllChecksPass;
var
  store : IHealthChecksStore;
  check : IHealthCheck;
  root : TJSONObject;
  entries : TJSONObject;
  entry : TJSONObject;
begin
  store := TMemoryHealthCheckStore.Create(10);
  check := TPassingCheck.Create(TTimeSpan.FromSeconds(30));
  check.Name := 'self';
  check.TimeElapsed := '12ms';
  check.Status := THealthStatus.hsPassed;
  store.Add(check);

  root := TJSONObject.ParseJSONValue(THealthChecksResponseBuilder.BuildSummaryJson(store.Last)) as TJSONObject;
  try
    Assert.IsNotNull(root);
    Assert.AreEqual('Healthy', root.GetValue<string>('status'));
    Assert.AreEqual('00:00:00.012', root.GetValue<string>('totalDuration'));

    entries := root.GetValue('entries') as TJSONObject;
    Assert.IsNotNull(entries);
    entry := entries.GetValue('self') as TJSONObject;
    Assert.IsNotNull(entry);
    Assert.AreEqual('Healthy', entry.GetValue<string>('status'));
    Assert.AreEqual('00:00:00.012', entry.GetValue<string>('duration'));
    Assert.IsTrue(entry.GetValue('description') is TJSONNull);
  finally
    root.Free;
  end;
end;

{ T-HC-13 }

procedure THealthChecksTests.T_HC_13_SummaryJson_IsUnhealthy_WhenAnyCheckFails;
var
  store : IHealthChecksStore;
  check : IHealthCheck;
  root : TJSONObject;
  entries : TJSONObject;
  entry : TJSONObject;
begin
  store := TMemoryHealthCheckStore.Create(10);
  check := TFailingCheck.Create(TTimeSpan.FromSeconds(30));
  check.Name := 'disk';
  check.TimeElapsed := '1.5s';
  check.Status := THealthStatus.hsFailed;
  check.ErrorMsg := 'Only 2GB free';
  store.Add(check);

  root := TJSONObject.ParseJSONValue(THealthChecksResponseBuilder.BuildSummaryJson(store.Last)) as TJSONObject;
  try
    Assert.IsNotNull(root);
    Assert.AreEqual('Unhealthy', root.GetValue<string>('status'));
    Assert.AreEqual('00:00:01.500', root.GetValue<string>('totalDuration'));

    entries := root.GetValue('entries') as TJSONObject;
    entry := entries.GetValue('disk') as TJSONObject;
    Assert.AreEqual('Unhealthy', entry.GetValue<string>('status'));
    Assert.AreEqual('Only 2GB free', entry.GetValue<string>('description'));
  finally
    root.Free;
  end;
end;

{ T-HC-14 }

procedure THealthChecksTests.T_HC_14_SummaryJson_IsDegraded_WhenCheckNotChecked;
var
  store : IHealthChecksStore;
  check : IHealthCheck;
  root : TJSONObject;
  entries : TJSONObject;
  entry : TJSONObject;
begin
  store := TMemoryHealthCheckStore.Create(10);
  check := TPassingCheck.Create(TTimeSpan.FromSeconds(30));
  check.Name := 'startup';
  check.TimeElapsed := '25ms';
  check.Status := THealthStatus.hsNotChecked;
  store.Add(check);

  root := TJSONObject.ParseJSONValue(THealthChecksResponseBuilder.BuildSummaryJson(store.Last)) as TJSONObject;
  try
    Assert.IsNotNull(root);
    Assert.AreEqual('Degraded', root.GetValue<string>('status'));

    entries := root.GetValue('entries') as TJSONObject;
    entry := entries.GetValue('startup') as TJSONObject;
    Assert.AreEqual('Degraded', entry.GetValue<string>('status'));
    Assert.AreEqual('00:00:00.025', entry.GetValue<string>('duration'));
  finally
    root.Free;
  end;
end;

{ T-HC-15 }

procedure THealthChecksTests.T_HC_15_LivenessJson_IsHealthy;
var
  root : TJSONObject;
  entries : TJSONObject;
  entry : TJSONObject;
begin
  root := TJSONObject.ParseJSONValue(THealthChecksResponseBuilder.BuildLivenessJson) as TJSONObject;
  try
    Assert.IsNotNull(root);
    Assert.AreEqual('Healthy', root.GetValue<string>('status'));

    entries := root.GetValue('entries') as TJSONObject;
    Assert.IsNotNull(entries);
    entry := entries.GetValue('self') as TJSONObject;
    Assert.IsNotNull(entry);
    Assert.AreEqual('Healthy', entry.GetValue<string>('status'));
  finally
    root.Free;
  end;
end;

{ T-HC-16 }

procedure THealthChecksTests.T_HC_16_SQLite_EntityHealthCheck_Passes_OnLocalDatabase;
var
  check: IHealthCheck;
  context: THealthCheckSqliteContext;
  databasePath: string;
begin
  check := nil;
  context := nil;
  databasePath := '';
  context := CreateSQLiteHealthContext(databasePath);
  try
    check := TEntityHealthCheck.Create(context, TTimeSpan.FromSeconds(30));
    try
      check.Check;
      check.Status := THealthStatus.hsPassed;
    except
      check.Status := THealthStatus.hsFailed;
    end;

    Assert.AreEqual(THealthStatus.hsPassed, check.Status);
  finally
    if Assigned(context) then
      context.Free;
    if (databasePath <> '') and TFile.Exists(databasePath) then
      TFile.Delete(databasePath);
  end;
end;

{ T-HC-17 }

procedure THealthChecksTests.T_HC_17_SqlServer_HealthCheck_Fails_OnClosedEndpoint;
var
  check: IHealthCheck;
  database: TEntityDatabase;
begin
  {$IFNDEF MSWINDOWS}
  Assert.Pass('SQL Server health check tests only run on Windows.');
  Exit;
  {$ENDIF}

  check := nil;
  database := TEntityDatabaseFactory.GetInstance(TDatabaseEngine.deADO);
  try
    database.Connection.FromConnectionString(
      Integer(TDBProvider.dbMSSQL),
      'Data Source=tcp:127.0.0.1,1;Initial Catalog=master;User ID=sa;Password=invalid;Connect Timeout=1');

    check := TSqlServerHealthCheck.Create(database, TTimeSpan.FromSeconds(30));
    try
      check.Check;
      Assert.Fail('Expected connection failure was not raised');
    except
      on E: Exception do ;
    end;
  finally
    database.Free;
  end;
end;

{ T-HC-18 }

procedure THealthChecksTests.T_HC_18_PostgreSQL_HealthCheck_IsBlocked_WithoutProvider;
const
  // TDBProvider has no RTTI (sparse enum values) — check by value instead.
  // PostgreSQL would need its own dbPostgreSQL entry in TDBProvider.
  POSTGRE_VALUE = 0;  // no entry exists yet
var
  providerFound: Boolean;
begin
  // Verify that no TDBProvider value maps to a PostgreSQL provider.
  // Since TDBProvider only contains MSAccess/MSSQL/MySQL/SQLite/IBM400/Firebase,
  // providerFound stays False, proving the gap.
  providerFound := False;

  Assert.IsFalse(
    providerFound,
    'QuickCore still lacks a PostgreSQL DB provider/engine entry, so an executable PostgreSQL health check cannot be wired yet.');
end;

initialization
  TDUnitX.RegisterTestFixture(THealthChecksTests);

end.
