program DependencyInjection;

(* DependencyInjection Sample - S-02
  Demonstrates the three service lifetimes in QuickCore DI:
    - Singleton  : same instance for the whole app lifetime
    - Transient  : new instance on every Resolve
    - Scoped     : same instance within a scope, different across scopes

  .NET equivalent: Console app with Microsoft.Extensions.DependencyInjection
*)

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Quick.Console,
  Quick.Core.DependencyInjection;

// ── Interfaces & implementations ────────────────────────────────────────────

type
  ICounterService = interface
  ['{B1C2D3E4-F5A6-47B8-C9D0-E1F2A3B4C5D6}']
    function InstanceId : Integer;
    procedure Increment;
    function Count : Integer;
  end;

  TCounterService = class(TInterfacedObject, ICounterService)
  private
    class var FNextId : Integer;
    FId    : Integer;
    FCount : Integer;
  public
    constructor Create;
    function InstanceId : Integer;
    procedure Increment;
    function Count : Integer;
  end;

{ TCounterService }

constructor TCounterService.Create;
begin
  Inc(FNextId);
  FId := FNextId;
  FCount := 0;
end;

function TCounterService.InstanceId: Integer;
begin
  Result := FId;
end;

procedure TCounterService.Increment;
begin
  Inc(FCount);
end;

function TCounterService.Count: Integer;
begin
  Result := FCount;
end;

// ── Main program ─────────────────────────────────────────────────────────────

var
  services : TServiceCollection;
  sA, sB   : ICounterService;
  tA, tB   : ICounterService;
  scope1, scope2 : IServiceScope;
  sc1A, sc1B, sc2A : ICounterService;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    services := TServiceCollection.Create;
    try
      services
        .AddSingleton<ICounterService, TCounterService>
        .AddTransient<ICounterService, TCounterService>('transient')
        .AddScoped<ICounterService, TCounterService>('scoped');
      services.Build;

      // ── SINGLETON ──────────────────────────────────────────────────────
      cout('=== SINGLETON ===', ccLightCyan);
      sA := services.Resolve<ICounterService>;
      sB := services.Resolve<ICounterService>;
      sA.Increment;
      cout(Format('  sA (id=%d) count=%d', [sA.InstanceId, sA.Count]), ccWhite);
      cout(Format('  sB (id=%d) count=%d', [sB.InstanceId, sB.Count]), ccWhite);
      cout('  sA and sB are the SAME instance: ' + BoolToStr(sA.InstanceId = sB.InstanceId, True), ccGreen);

      // ── TRANSIENT ──────────────────────────────────────────────────────
      cout('', ccWhite);
      cout('=== TRANSIENT ===', ccLightCyan);
      tA := services.Resolve<ICounterService>('transient');
      tB := services.Resolve<ICounterService>('transient');
      tA.Increment;
      cout(Format('  tA (id=%d) count=%d', [tA.InstanceId, tA.Count]), ccWhite);
      cout(Format('  tB (id=%d) count=%d', [tB.InstanceId, tB.Count]), ccWhite);
      cout('  tA and tB are DIFFERENT instances: ' + BoolToStr(tA.InstanceId <> tB.InstanceId, True), ccGreen);

      // ── SCOPED ─────────────────────────────────────────────────────────
      cout('', ccWhite);
      cout('=== SCOPED ===', ccLightCyan);
      scope1 := services.CreateScope;
      scope2 := services.CreateScope;
      try
        sc1A := scope1.ServiceProvider.GetService<ICounterService>('scoped');
        sc1B := scope1.ServiceProvider.GetService<ICounterService>('scoped');
        sc2A := scope2.ServiceProvider.GetService<ICounterService>('scoped');
        sc1A.Increment;
        cout(Format('  scope1-A (id=%d) count=%d', [sc1A.InstanceId, sc1A.Count]), ccWhite);
        cout(Format('  scope1-B (id=%d) count=%d', [sc1B.InstanceId, sc1B.Count]), ccWhite);
        cout(Format('  scope2-A (id=%d) count=%d', [sc2A.InstanceId, sc2A.Count]), ccWhite);
        cout('  scope1-A and scope1-B SAME instance: ' + BoolToStr(sc1A.InstanceId = sc1B.InstanceId, True), ccGreen);
        cout('  scope1-A and scope2-A DIFFERENT: ' + BoolToStr(sc1A.InstanceId <> sc2A.InstanceId, True), ccGreen);
      finally
        scope1 := nil;
        scope2 := nil;
      end;

    finally
      services.Free;
    end;

    cout('', ccWhite);
    cout('Press [Enter] to exit.', ccYellow);
    ConsoleWaitForEnterKey;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
