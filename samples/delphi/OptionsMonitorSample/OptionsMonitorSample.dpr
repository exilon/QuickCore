program OptionsMonitorSample;

(* OptionsMonitorSample
  Demonstrates IOptionsMonitor<T> and IOptionsSnapshot<T> in QuickCore.

  .NET equivalent: IOptionsMonitor<T> / IOptionsSnapshot<T>
    (Microsoft.Extensions.Options)

  IOptionsMonitor<T>:
    — Singleton lifetime
    — Notifies subscribers via OnChange when config reloads
    — Suitable for long-lived services (caches, connection pools)

  IOptionsSnapshot<T>:
    — Per-resolution read (singleton here, transient in real usage)
    — No change notifications — just reads the current value
    — Suitable for per-request controllers / handlers
*)

{$APPTYPE CONSOLE}
// {$R *.res}  — .res not generated for dcc32 console builds; omit to avoid linker error

uses
  System.SysUtils,
  System.Threading,
  Quick.Console,
  Quick.Options,
  Quick.Core.Options.Monitor;

// ── Null serializer (no file I/O needed for this demo) ────────────────────────

type
  TNullSerializer = class(TInterfacedObject, IOptionsSerializer)
  public
    function Load(aSections: TSectionList; aFailOnSectionNotExists: Boolean): Boolean;
    function LoadSection(aSections: TSectionList; aOptions: TOptions): Boolean;
    procedure Save(aSections: TSectionList);
    function GetFileSectionNames(out oSections: TArray<string>): Boolean;
    function ConfigExists: Boolean;
  end;

function TNullSerializer.Load(aSections: TSectionList; aFailOnSectionNotExists: Boolean): Boolean;
begin Result := True; end;
function TNullSerializer.LoadSection(aSections: TSectionList; aOptions: TOptions): Boolean;
begin Result := True; end;
procedure TNullSerializer.Save(aSections: TSectionList); begin end;
function TNullSerializer.GetFileSectionNames(out oSections: TArray<string>): Boolean;
begin oSections := []; Result := False; end;
function TNullSerializer.ConfigExists: Boolean; begin Result := False; end;

// ── Application options ───────────────────────────────────────────────────────

type
  {$M+}
  TDatabaseOptions = class(TOptions)
  private
    fConnectionString : string;
    fMaxPoolSize      : Integer;
    fCommandTimeout   : Integer;
  public
    constructor Create; override;
  published
    property ConnectionString : string  read fConnectionString write fConnectionString;
    property MaxPoolSize      : Integer read fMaxPoolSize      write fMaxPoolSize;
    property CommandTimeout   : Integer read fCommandTimeout   write fCommandTimeout;
  end;

  TFeatureOptions = class(TOptions)
  private
    fEnableNewDashboard : Boolean;
    fBetaUsers          : string;
  public
    constructor Create; override;
  published
    property EnableNewDashboard : Boolean read fEnableNewDashboard write fEnableNewDashboard;
    property BetaUsers          : string  read fBetaUsers          write fBetaUsers;
  end;
  {$M-}

constructor TDatabaseOptions.Create;
begin
  inherited;
  Name               := 'Database';
  fConnectionString  := 'Server=localhost;Database=myapp;User=sa';
  fMaxPoolSize       := 10;
  fCommandTimeout    := 30;
end;

constructor TFeatureOptions.Create;
begin
  inherited;
  Name                := 'Features';
  fEnableNewDashboard := False;
  fBetaUsers          := 'user1,user2';
end;

// ── Simulated long-lived service using IOptionsMonitor ────────────────────────

type
  TConnectionPool = class
  private
    fMonitor    : IOptionsMonitor<TDatabaseOptions>;
    fToken      : IOptionsChangeToken;
    fPoolSize   : Integer;
    fConnString : string;
  public
    constructor Create(aMonitor: IOptionsMonitor<TDatabaseOptions>);
    destructor Destroy; override;
    procedure PrintStatus;
  end;

constructor TConnectionPool.Create(aMonitor: IOptionsMonitor<TDatabaseOptions>);
begin
  inherited Create;
  fMonitor    := aMonitor;
  fPoolSize   := aMonitor.CurrentValue.MaxPoolSize;
  fConnString := aMonitor.CurrentValue.ConnectionString;

  // Subscribe to future changes
  fToken := aMonitor.OnChange(procedure(o: TDatabaseOptions)
    begin
      WriteLn;
      WriteLn('  [ConnectionPool] Config changed! Reconnecting...');
      WriteLn(Format('    New ConnectionString : %s', [o.ConnectionString]));
      WriteLn(Format('    New MaxPoolSize      : %d', [o.MaxPoolSize]));
      fPoolSize   := o.MaxPoolSize;
      fConnString := o.ConnectionString;
    end);
end;

destructor TConnectionPool.Destroy;
begin
  fToken.Unregister; // Clean up subscription when service is freed
  inherited;
end;

procedure TConnectionPool.PrintStatus;
begin
  WriteLn(Format('  [Pool] ConnStr=%s  MaxSize=%d', [fConnString, fPoolSize]));
end;

// ─────────────────────────────────────────────────────────────────────────────
// Demo sections
// ─────────────────────────────────────────────────────────────────────────────

procedure DemoOptionsMonitor(
  const aContainer : TOptionsContainer;
  const aDbOpts    : TDatabaseOptions);
var
  monitor : IOptionsMonitor<TDatabaseOptions>;
  pool    : TConnectionPool;
  handler : TLoadConfigEvent;
begin
  WriteLn;
  WriteLn('─── 1. IOptionsMonitor<T> — Long-lived service ──────────────────');

  monitor := TOptionsMonitor<TDatabaseOptions>.Create(aContainer);
  pool    := TConnectionPool.Create(monitor);
  try
    WriteLn('  Initial state:');
    pool.PrintStatus;

    // Simulate appsettings.json reload: update options object + fire event
    WriteLn;
    WriteLn('  Simulating config file change...');
    aDbOpts.ConnectionString := 'Server=prod-db;Database=myapp;User=app_user';
    aDbOpts.MaxPoolSize      := 50;

    // TFileOptionsContainer would fire this automatically via TFileMonitor
    handler := aContainer.OnConfigReloaded;
    if Assigned(handler) then
      handler;

    WriteLn;
    WriteLn('  State after reload:');
    pool.PrintStatus;
  finally
    pool.Free;
  end;
end;

procedure DemoMultipleCallbacks(
  const aContainer : TOptionsContainer;
  const aDbOpts    : TDatabaseOptions);
var
  monitor  : IOptionsMonitor<TDatabaseOptions>;
  token1   : IOptionsChangeToken;
  token2   : IOptionsChangeToken;
  handler  : TLoadConfigEvent;
begin
  WriteLn;
  WriteLn('─── 2. Multiple subscribers + selective Unregister ──────────────');

  monitor := TOptionsMonitor<TDatabaseOptions>.Create(aContainer);

  token1 := monitor.OnChange(procedure(o: TDatabaseOptions)
    begin WriteLn('  [Subscriber A] Received change: ' + o.ConnectionString) end);

  token2 := monitor.OnChange(procedure(o: TDatabaseOptions)
    begin WriteLn('  [Subscriber B] Received change: MaxPoolSize=' + o.MaxPoolSize.ToString) end);

  WriteLn('  Reload 1 — both subscribers fire:');
  aDbOpts.CommandTimeout := 60;
  handler := aContainer.OnConfigReloaded;
  if Assigned(handler) then handler;

  // Unregister A — only B should fire next
  token1.Unregister;
  WriteLn;
  WriteLn('  Reload 2 — only subscriber B fires (A unregistered):');
  aDbOpts.MaxPoolSize := 100;
  handler := aContainer.OnConfigReloaded;
  if Assigned(handler) then handler;

  token2.Unregister;
end;

procedure DemoOptionsSnapshot(
  const aContainer : TOptionsContainer;
  const aFeatures  : TFeatureOptions);
var
  snapshot : IOptionsSnapshot<TFeatureOptions>;
begin
  WriteLn;
  WriteLn('─── 3. IOptionsSnapshot<T> — Per-resolution read ────────────────');

  snapshot := TOptionsSnapshot<TFeatureOptions>.Create(aContainer);

  WriteLn(Format('  EnableNewDashboard = %s', [BoolToStr(snapshot.Value.EnableNewDashboard, True)]));
  WriteLn(Format('  BetaUsers          = %s', [snapshot.Value.BetaUsers]));

  // Snapshot always reads the live value — no subscription needed
  aFeatures.EnableNewDashboard := True;
  aFeatures.BetaUsers          := 'user1,user2,user3,user4';

  WriteLn('  (config updated without firing OnConfigReloaded)');
  WriteLn(Format('  EnableNewDashboard = %s (live read)', [BoolToStr(snapshot.Value.EnableNewDashboard, True)]));
  WriteLn(Format('  BetaUsers          = %s (live read)', [snapshot.Value.BetaUsers]));
end;

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────
var
  container : TOptionsContainer;
  serializer: IOptionsSerializer;
  dbOpts    : TDatabaseOptions;
  features  : TFeatureOptions;
begin
  try
    WriteLn('QuickCore — IOptionsMonitor<T> / IOptionsSnapshot<T> sample');
    WriteLn('═════════════════════════════════════════════════════════════');

    serializer := TNullSerializer.Create;
    container  := TOptionsContainer.Create(serializer);
    try
      // Register option sections (in real apps done via services.Configure<T>)
      dbOpts   := TDatabaseOptions.Create;
      features := TFeatureOptions.Create;
      container.AddOption(dbOpts);
      container.AddOption(features);

      DemoOptionsMonitor(container, dbOpts);
      DemoMultipleCallbacks(container, dbOpts);
      DemoOptionsSnapshot(container, features);

      WriteLn;
      WriteLn('Sample completed successfully.');
    finally
      container.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLn('FATAL: ' + E.Message);
      ExitCode := 1;
    end;
  end;

  {$IFDEF DEBUG}
  WriteLn;
  Write('Press Enter to exit...');
  ReadLn;
  {$ENDIF}
end.
