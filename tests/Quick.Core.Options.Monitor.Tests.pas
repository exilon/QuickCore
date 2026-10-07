unit Quick.Core.Options.Monitor.Tests;

{ Tests: T-OPT-01..08
    T-OPT-01  CurrentValue returns the registered options instance
    T-OPT-02  OnChange callback fires when OnConfigReloaded is triggered
    T-OPT-03  Callback receives the updated options value (modified before reload)
    T-OPT-04  Multiple OnChange callbacks are all invoked on reload
    T-OPT-05  Unregister stops the callback from being invoked
    T-OPT-06  Unregister is idempotent (no error on double call)
    T-OPT-07  IOptionsSnapshot.Value returns the current options value
    T-OPT-08  nil callback in OnChange raises EArgumentNilException
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Generics.Collections,
  Quick.Options,
  Quick.Core.Options.Monitor;

// ── Minimal null serializer ───────────────────────────────────────────────────

type
  TNullOptionsSerializer = class(TInterfacedObject, IOptionsSerializer)
  public
    function Load(aSections: TSectionList; aFailOnSectionNotExists: Boolean): Boolean;
    function LoadSection(aSections: TSectionList; aOptions: TOptions): Boolean;
    procedure Save(aSections: TSectionList);
    function GetFileSectionNames(out oSections: TArray<string>): Boolean;
    function ConfigExists: Boolean;
  end;

// ── Test options type ─────────────────────────────────────────────────────────

  {$M+}
  TDatabaseOptions = class(TOptions)
  private
    fConnectionString : string;
    fMaxPoolSize      : Integer;
  public
    constructor Create; override;
  published
    property ConnectionString : string  read fConnectionString write fConnectionString;
    property MaxPoolSize      : Integer read fMaxPoolSize      write fMaxPoolSize;
  end;
  {$M-}

// ── Test fixture ──────────────────────────────────────────────────────────────

  [TestFixture]
  TOptionsMonitorTests = class
  private
    FSerializer : IOptionsSerializer;
    FContainer  : TOptionsContainer;
    FOptions    : TDatabaseOptions;

    procedure TriggerReload;
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure T_OPT_01_CurrentValue_ReturnsRegisteredOptions;
    [Test]
    procedure T_OPT_02_OnChange_CallbackFiresOnReload;
    [Test]
    procedure T_OPT_03_OnChange_CallbackReceivesUpdatedValue;
    [Test]
    procedure T_OPT_04_MultipleCallbacks_AllFiredOnReload;
    [Test]
    procedure T_OPT_05_Unregister_StopsCallbackInvocation;
    [Test]
    procedure T_OPT_06_Unregister_IsIdempotent;
    [Test]
    procedure T_OPT_07_OptionsSnapshot_ReturnsCurrentValue;
    [Test]
    procedure T_OPT_08_OnChange_NilCallback_Raises;
  end;

implementation

// ── TNullOptionsSerializer ────────────────────────────────────────────────────

function TNullOptionsSerializer.Load(aSections: TSectionList; aFailOnSectionNotExists: Boolean): Boolean;
begin
  Result := True;
end;

function TNullOptionsSerializer.LoadSection(aSections: TSectionList; aOptions: TOptions): Boolean;
begin
  Result := True;
end;

procedure TNullOptionsSerializer.Save(aSections: TSectionList);
begin
end;

function TNullOptionsSerializer.GetFileSectionNames(out oSections: TArray<string>): Boolean;
begin
  oSections := [];
  Result    := False;
end;

function TNullOptionsSerializer.ConfigExists: Boolean;
begin
  Result := False;
end;

// ── TDatabaseOptions ──────────────────────────────────────────────────────────

constructor TDatabaseOptions.Create;
begin
  inherited;
  Name                := 'Database';
  fConnectionString   := 'Server=localhost;Database=test';
  fMaxPoolSize        := 10;
end;

// ── TOptionsMonitorTests ──────────────────────────────────────────────────────

procedure TOptionsMonitorTests.SetUp;
begin
  FSerializer := TNullOptionsSerializer.Create;
  FContainer  := TOptionsContainer.Create(FSerializer);

  FOptions := TDatabaseOptions.Create;
  FContainer.AddOption(FOptions);
end;

procedure TOptionsMonitorTests.TearDown;
begin
  FContainer.Free;
  FSerializer := nil;
end;

procedure TOptionsMonitorTests.TriggerReload;
var
  handler: TLoadConfigEvent;
begin
  // Simulate what TFileOptionsContainer does after detecting a changed file:
  // fire OnConfigReloaded so the monitor and all chained handlers run.
  handler := FContainer.OnConfigReloaded;
  if Assigned(handler) then
    handler;
end;

{ T-OPT-01 }
procedure TOptionsMonitorTests.T_OPT_01_CurrentValue_ReturnsRegisteredOptions;
var
  monitor : IOptionsMonitor<TDatabaseOptions>;
begin
  monitor := TOptionsMonitor<TDatabaseOptions>.Create(FContainer);
  Assert.IsNotNull(monitor.CurrentValue);
  Assert.AreEqual('Server=localhost;Database=test', monitor.CurrentValue.ConnectionString);
end;

{ T-OPT-02 }
procedure TOptionsMonitorTests.T_OPT_02_OnChange_CallbackFiresOnReload;
var
  monitor     : IOptionsMonitor<TDatabaseOptions>;
  callCount   : Integer;
begin
  monitor   := TOptionsMonitor<TDatabaseOptions>.Create(FContainer);
  callCount := 0;

  monitor.OnChange(procedure(o: TDatabaseOptions)
    begin
      Inc(callCount);
    end);

  TriggerReload;

  Assert.AreEqual(1, callCount, 'callback must be called exactly once per reload');
end;

{ T-OPT-03 }
procedure TOptionsMonitorTests.T_OPT_03_OnChange_CallbackReceivesUpdatedValue;
var
  monitor         : IOptionsMonitor<TDatabaseOptions>;
  capturedConnStr : string;
begin
  monitor := TOptionsMonitor<TDatabaseOptions>.Create(FContainer);

  monitor.OnChange(procedure(o: TDatabaseOptions)
    begin
      capturedConnStr := o.ConnectionString;
    end);

  // Simulate a config reload: update the options object then trigger reload
  FOptions.ConnectionString := 'Server=prod;Database=live';
  TriggerReload;

  Assert.AreEqual('Server=prod;Database=live', capturedConnStr,
    'callback must receive the updated connection string');
end;

{ T-OPT-04 }
procedure TOptionsMonitorTests.T_OPT_04_MultipleCallbacks_AllFiredOnReload;
var
  monitor  : IOptionsMonitor<TDatabaseOptions>;
  count1   : Integer;
  count2   : Integer;
  count3   : Integer;
begin
  monitor := TOptionsMonitor<TDatabaseOptions>.Create(FContainer);
  count1  := 0;
  count2  := 0;
  count3  := 0;

  monitor.OnChange(procedure(o: TDatabaseOptions) begin Inc(count1) end);
  monitor.OnChange(procedure(o: TDatabaseOptions) begin Inc(count2) end);
  monitor.OnChange(procedure(o: TDatabaseOptions) begin Inc(count3) end);

  TriggerReload;

  Assert.AreEqual(1, count1, 'callback 1 must fire');
  Assert.AreEqual(1, count2, 'callback 2 must fire');
  Assert.AreEqual(1, count3, 'callback 3 must fire');
end;

{ T-OPT-05 }
procedure TOptionsMonitorTests.T_OPT_05_Unregister_StopsCallbackInvocation;
var
  monitor   : IOptionsMonitor<TDatabaseOptions>;
  callCount : Integer;
  token     : IOptionsChangeToken;
begin
  monitor   := TOptionsMonitor<TDatabaseOptions>.Create(FContainer);
  callCount := 0;

  token := monitor.OnChange(procedure(o: TDatabaseOptions)
    begin
      Inc(callCount);
    end);

  TriggerReload;  // call 1 — should fire
  token.Unregister;
  TriggerReload;  // call 2 — must NOT fire

  Assert.AreEqual(1, callCount, 'callback must not be called after Unregister');
end;

{ T-OPT-06 }
procedure TOptionsMonitorTests.T_OPT_06_Unregister_IsIdempotent;
var
  monitor : IOptionsMonitor<TDatabaseOptions>;
  token   : IOptionsChangeToken;
begin
  monitor := TOptionsMonitor<TDatabaseOptions>.Create(FContainer);
  token   := monitor.OnChange(procedure(o: TDatabaseOptions) begin end);

  // Assert.WillNotRaise cannot match the anon-proc overload in this compiler;
  // calling directly: if it raises the test will fail automatically.
  token.Unregister;
  token.Unregister; // second call must not raise
end;

{ T-OPT-07 }
procedure TOptionsMonitorTests.T_OPT_07_OptionsSnapshot_ReturnsCurrentValue;
var
  snapshot : IOptionsSnapshot<TDatabaseOptions>;
begin
  snapshot := TOptionsSnapshot<TDatabaseOptions>.Create(FContainer);
  Assert.IsNotNull(snapshot.Value);
  Assert.AreEqual('Server=localhost;Database=test', snapshot.Value.ConnectionString);

  // Modify option and verify snapshot sees the change (live read)
  FOptions.ConnectionString := 'Server=updated;Database=new';
  Assert.AreEqual('Server=updated;Database=new', snapshot.Value.ConnectionString,
    'snapshot.Value must reflect updated options');
end;

{ T-OPT-08 }
procedure TOptionsMonitorTests.T_OPT_08_OnChange_NilCallback_Raises;
var
  monitor     : IOptionsMonitor<TDatabaseOptions>;
  nilCallback : TOptionsChangeCallback<TDatabaseOptions>;
begin
  monitor     := TOptionsMonitor<TDatabaseOptions>.Create(FContainer);
  nilCallback := nil;
  try
    monitor.OnChange(nilCallback);
    Assert.Fail('Expected EArgumentNilException was not raised');
  except
    on E: EArgumentNilException do ; // expected
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TOptionsMonitorTests);

end.
