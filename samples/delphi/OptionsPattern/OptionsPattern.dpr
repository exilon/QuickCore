program OptionsPattern;

(* OptionsPattern Sample - S-03
  Demonstrates the Options pattern in QuickCore DI.
  Equivalent to IOptions<T> + appsettings.json in .NET.

  Key concepts:
    - TMyOptions : TOptions   — strongly-typed options class
    - services.Configure<T>(proc) — configure programmatically
    - services.Resolve<IOptions<T>> — inject anywhere via IOptions<T>
    - Constructor injection of IOptions<T> in services
*)

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Quick.Console,
  Quick.Options,
  Quick.Core.DependencyInjection;

// ── Options classes ──────────────────────────────────────────────────────────

type
  TDatabaseOptions = class(TOptions)
  private
    FHost     : string;
    FPort     : Integer;
    FDatabase : string;
    FPoolSize : Integer;
  published
    property Host     : string  read FHost     write FHost;
    property Port     : Integer read FPort     write FPort;
    property Database : string  read FDatabase write FDatabase;
    property PoolSize : Integer read FPoolSize write FPoolSize;
  end;

  TEmailOptions = class(TOptions)
  private
    FSmtpHost : string;
    FSmtpPort : Integer;
    FFromAddr : string;
  published
    property SmtpHost : string  read FSmtpHost write FSmtpHost;
    property SmtpPort : Integer read FSmtpPort write FSmtpPort;
    property FromAddr : string  read FFromAddr write FFromAddr;
  end;

// ── Services that consume options ────────────────────────────────────────────

  IConnectionStringBuilder = interface
  ['{C3D4E5F6-A7B8-4C9D-0E1F-2A3B4C5D6E7F}']
    function Build : string;
  end;

  TConnectionStringBuilder = class(TInterfacedObject, IConnectionStringBuilder)
  private
    fDbOpts : IOptions<TDatabaseOptions>;
  public
    constructor Create(aDbOpts : IOptions<TDatabaseOptions>);
    function Build : string;
  end;

constructor TConnectionStringBuilder.Create(aDbOpts : IOptions<TDatabaseOptions>);
begin
  fDbOpts := aDbOpts;
end;

function TConnectionStringBuilder.Build: string;
begin
  Result := Format('Host=%s;Port=%d;Database=%s;MaxPoolSize=%d',
    [fDbOpts.Value.Host, fDbOpts.Value.Port,
     fDbOpts.Value.Database, fDbOpts.Value.PoolSize]);
end;

// ── Main program ─────────────────────────────────────────────────────────────

var
  services : TServiceCollection;
  builder  : IConnectionStringBuilder;
  dbOpts   : IOptions<TDatabaseOptions>;
  emailOpts: IOptions<TEmailOptions>;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    services := TServiceCollection.Create;
    try
      services
        // Configure database options programmatically
        .Configure<TDatabaseOptions>(procedure(o : TDatabaseOptions)
          begin
            o.Host     := 'localhost';
            o.Port     := 5432;
            o.Database := 'myapp_db';
            o.PoolSize := 10;
          end)
        // Configure email options programmatically
        .Configure<TEmailOptions>(procedure(o : TEmailOptions)
          begin
            o.SmtpHost := 'smtp.example.com';
            o.SmtpPort := 587;
            o.FromAddr := 'noreply@example.com';
          end)
        // Register a service that takes IOptions<TDatabaseOptions> via ctor injection
        .AddSingleton<IConnectionStringBuilder, TConnectionStringBuilder>;
      services.Build;

      // ── Resolve and use options ──────────────────────────────────────
      cout('=== DATABASE OPTIONS ===', ccLightCyan);
      dbOpts := services.Resolve<IOptions<TDatabaseOptions>>;
      cout(Format('  Host     : %s', [dbOpts.Value.Host]), ccWhite);
      cout(Format('  Port     : %d', [dbOpts.Value.Port]), ccWhite);
      cout(Format('  Database : %s', [dbOpts.Value.Database]), ccWhite);
      cout(Format('  PoolSize : %d', [dbOpts.Value.PoolSize]), ccWhite);

      cout('', ccWhite);
      cout('=== EMAIL OPTIONS ===', ccLightCyan);
      emailOpts := services.Resolve<IOptions<TEmailOptions>>;
      cout(Format('  SmtpHost : %s', [emailOpts.Value.SmtpHost]), ccWhite);
      cout(Format('  SmtpPort : %d', [emailOpts.Value.SmtpPort]), ccWhite);
      cout(Format('  FromAddr : %s', [emailOpts.Value.FromAddr]), ccWhite);

      cout('', ccWhite);
      cout('=== SERVICE WITH INJECTED OPTIONS ===', ccLightCyan);
      // IConnectionStringBuilder gets IOptions<TDatabaseOptions> injected automatically
      builder := services.Resolve<IConnectionStringBuilder>;
      cout('  Connection string: ' + builder.Build, ccGreen);

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
