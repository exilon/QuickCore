unit Quick.Core.DependencyInjection.Tests;

interface

uses
  DUnitX.TestFramework,
  System.IOUtils,
  System.SysUtils,
  Quick.IoC,
  Quick.Options,
  Quick.Core.DependencyInjection;

type
  IFoo = interface
  ['{9368EAE4-BC59-4D62-B25D-673AB6B6E63A}']
    function Kind: string;
  end;

  IBar = interface
  ['{3EF7872B-921A-4EFF-B412-E42B63E11E3F}']
    function Kind: string;
  end;

  IBaz = interface
  ['{9462B035-5BA2-4F20-90AC-146F9DDC5B81}']
    function Kind: string;
  end;

  IOneDepService = interface
  ['{18A8D5A5-4EC1-45C1-A8C7-558777EC08C2}']
    function HasFoo: Boolean;
    function FooKind: string;
  end;

  IThreeDepService = interface
  ['{F12F987D-B85E-4AA8-8CCF-E77C87928CB6}']
    function HasAllDependencies: Boolean;
  end;

  IThreeDepFactory = interface
  ['{0B526C43-CB35-490E-B33D-351E1B8F49E8}']
    function New: TObject;
  end;

  TDiTestOptions = class(TOptions)
  private
    FAppName: string;
    FRetryCount: Integer;
  published
    property AppName: string read FAppName write FAppName;
    property RetryCount: Integer read FRetryCount write FRetryCount;
  end;

  TFoo = class(TInterfacedObject, IFoo)
  private
    FKind: string;
  public
    constructor Create; overload;
    constructor Create(const AKind: string); overload;
    function Kind: string;
  end;

  TNamedFoo = class(TInterfacedObject, IFoo)
  public
    function Kind: string;
  end;

  TBar = class(TInterfacedObject, IBar)
  public
    function Kind: string;
  end;

  TBaz = class(TInterfacedObject, IBaz)
  public
    function Kind: string;
  end;

  TOneDepService = class(TInterfacedObject, IOneDepService)
  private
    FFoo: IFoo;
  public
    constructor Create(aFoo: IFoo);
    function HasFoo: Boolean;
    function FooKind: string;
  end;

  TThreeDepService = class(TInterfacedObject, IThreeDepService)
  private
    FFoo: IFoo;
    FBar: IBar;
    FBaz: IBaz;
  public
    constructor Create(aFoo: IFoo; aBar: IBar; aBaz: IBaz);
    function HasAllDependencies: Boolean;
  end;

  TThreeDepConsumer = class
  private
    FFoo: IFoo;
    FBar: IBar;
    FBaz: IBaz;
  public
    constructor Create(aFoo: IFoo; aBar: IBar; aBaz: IBaz);
    function HasAllDependencies: Boolean;
  end;

  TDependencyInjectionTestStartup = class(TStartupBase)
  public
    class var ConfigureServicesCalled: Boolean;
    class procedure ConfigureServices(services: TServiceCollection); override;
  end;

  [TestFixture]
  TQuickCoreDependencyInjectionTests = class
  private
    function CreateServices: TServiceCollection;
    function CreateTempJsonFile: string;
  public
    [Test]
    procedure T_DI_01_Singleton_Returns_Same_Instance;
    [Test]
    procedure T_DI_02_Transient_Returns_Different_Instances;
    [Test]
    procedure T_DI_03_Constructor_Injection_With_One_Dependency;
    [Test]
    procedure T_DI_04_Constructor_Injection_With_Three_Dependencies;
    [Test]
    procedure T_DI_05_Named_Registrations;
    [Test]
    procedure T_DI_06_Factory_Delegate;
    [Test]
    procedure T_DI_07_IsRegistered_Check;
    [Test]
    procedure T_DI_08_Options_Configure;
    [Test]
    procedure T_DI_09_AddTypedFactory;
    [Test]
    procedure T_DI_10_Startup_Pattern;
  end;

implementation

{ Removed IThreeDepObjectFactory — TVirtualInterface is broken on Win64.
  Test now uses IFactory<TThreeDepConsumer> which has a compiler-generated vtable. }

{ TFoo }

constructor TFoo.Create;
begin
  inherited Create;
  FKind := 'foo';
end;

constructor TFoo.Create(const AKind: string);
begin
  inherited Create;
  FKind := AKind;
end;

function TFoo.Kind: string;
begin
  Result := FKind;
end;

{ TNamedFoo }

function TNamedFoo.Kind: string;
begin
  Result := 'named-foo';
end;

{ TBar }

function TBar.Kind: string;
begin
  Result := 'bar';
end;

{ TBaz }

function TBaz.Kind: string;
begin
  Result := 'baz';
end;

{ TOneDepService }

constructor TOneDepService.Create(aFoo: IFoo);
begin
  inherited Create;
  FFoo := aFoo;
end;

function TOneDepService.FooKind: string;
begin
  if FFoo = nil then
    Exit('');
  Result := FFoo.Kind;
end;

function TOneDepService.HasFoo: Boolean;
begin
  Result := FFoo <> nil;
end;

{ TThreeDepService }

constructor TThreeDepService.Create(aFoo: IFoo; aBar: IBar; aBaz: IBaz);
begin
  inherited Create;
  FFoo := aFoo;
  FBar := aBar;
  FBaz := aBaz;
end;

function TThreeDepService.HasAllDependencies: Boolean;
begin
  Result := (FFoo <> nil) and (FBar <> nil) and (FBaz <> nil);
end;

{ TThreeDepConsumer }

constructor TThreeDepConsumer.Create(aFoo: IFoo; aBar: IBar; aBaz: IBaz);
begin
  inherited Create;
  FFoo := aFoo;
  FBar := aBar;
  FBaz := aBaz;
end;

function TThreeDepConsumer.HasAllDependencies: Boolean;
begin
  Result := (FFoo <> nil) and (FBar <> nil) and (FBaz <> nil);
end;

{ TDependencyInjectionTestStartup }

class procedure TDependencyInjectionTestStartup.ConfigureServices(services: TServiceCollection);
begin
  ConfigureServicesCalled := True;
  services.AddSingleton<IFoo, TFoo>;
end;

{ TQuickCoreDependencyInjectionTests }

function TQuickCoreDependencyInjectionTests.CreateServices: TServiceCollection;
begin
  Result := TServiceCollection.Create;
end;

function TQuickCoreDependencyInjectionTests.CreateTempJsonFile: string;
begin
  Result := TPath.Combine(TPath.GetTempPath, TGuid.NewGuid.ToString + '.json');
  TFile.WriteAllText(Result, '{}');
end;

procedure TQuickCoreDependencyInjectionTests.T_DI_01_Singleton_Returns_Same_Instance;
var
  services: TServiceCollection;
  foo1: IFoo;
  foo2: IFoo;
begin
  services := CreateServices;
  try
    services.AddSingleton<IFoo, TFoo>;

    foo1 := services.Resolve<IFoo>;
    foo2 := services.Resolve<IFoo>;

    Assert.AreSame(TObject(foo1), TObject(foo2));
  finally
    services.Free;
  end;
end;

procedure TQuickCoreDependencyInjectionTests.T_DI_02_Transient_Returns_Different_Instances;
var
  services: TServiceCollection;
  foo1: IFoo;
  foo2: IFoo;
begin
  services := CreateServices;
  try
    services.AddTransient<IFoo, TFoo>;

    foo1 := services.Resolve<IFoo>;
    foo2 := services.Resolve<IFoo>;

    Assert.AreNotSame(TObject(foo1), TObject(foo2));
  finally
    services.Free;
  end;
end;

procedure TQuickCoreDependencyInjectionTests.T_DI_03_Constructor_Injection_With_One_Dependency;
var
  services: TServiceCollection;
  svc: IOneDepService;
begin
  services := CreateServices;
  try
    services
      .AddSingleton<IFoo, TFoo>
      .AddTransient<IOneDepService, TOneDepService>;

    svc := services.Resolve<IOneDepService>;

    Assert.IsTrue(svc.HasFoo);
    Assert.AreEqual('foo', svc.FooKind);
  finally
    services.Free;
  end;
end;

procedure TQuickCoreDependencyInjectionTests.T_DI_04_Constructor_Injection_With_Three_Dependencies;
var
  services: TServiceCollection;
  svc: IThreeDepService;
begin
  services := CreateServices;
  try
    services
      .AddSingleton<IFoo, TFoo>
      .AddSingleton<IBar, TBar>
      .AddSingleton<IBaz, TBaz>
      .AddTransient<IThreeDepService, TThreeDepService>;

    svc := services.Resolve<IThreeDepService>;

    Assert.IsTrue(svc.HasAllDependencies);
  finally
    services.Free;
  end;
end;

procedure TQuickCoreDependencyInjectionTests.T_DI_05_Named_Registrations;
var
  services: TServiceCollection;
  foo1: IFoo;
  foo2: IFoo;
begin
  services := CreateServices;
  try
    services.AddSingleton<IFoo, TFoo>('name1');
    services.AddSingleton<IFoo, TNamedFoo>('name2');

    foo1 := services.Resolve<IFoo>('name1');
    foo2 := services.Resolve<IFoo>('name2');

    Assert.AreEqual('foo', foo1.Kind);
    Assert.AreEqual('named-foo', foo2.Kind);
  finally
    services.Free;
  end;
end;

procedure TQuickCoreDependencyInjectionTests.T_DI_06_Factory_Delegate;
var
  services: TServiceCollection;
  factoryCalled: Boolean;
  foo: IFoo;
begin
  services := CreateServices;
  try
    factoryCalled := False;
    services.AddSingleton<IFoo, TFoo>(
      '',
      function: TFoo
      begin
        factoryCalled := True;
        Result := TFoo.Create('factory');
      end);

    foo := services.Resolve<IFoo>;

    Assert.IsTrue(factoryCalled);
    Assert.AreEqual('factory', foo.Kind);
  finally
    services.Free;
  end;
end;

procedure TQuickCoreDependencyInjectionTests.T_DI_07_IsRegistered_Check;
var
  services: TServiceCollection;
begin
  services := CreateServices;
  try
    Assert.IsFalse(services.IsRegistered<IFoo>);

    services.AddSingleton<IFoo, TFoo>;

    Assert.IsTrue(services.IsRegistered<IFoo>);
    Assert.IsTrue(services.IsRegistered<IFoo, TFoo>);
    Assert.IsFalse(services.IsRegistered<IBar>);
  finally
    services.Free;
  end;
end;

procedure TQuickCoreDependencyInjectionTests.T_DI_08_Options_Configure;
var
  services: TServiceCollection;
  options: IOptions<TDiTestOptions>;
  tempFile: string;
begin
  services := CreateServices;
  tempFile := CreateTempJsonFile;
  try
    services.AddOptions(ofJSON, False, tempFile);
    services.Configure<TDiTestOptions>(
      procedure(aOptions: TDiTestOptions)
      begin
        aOptions.AppName := 'QuickCore.Tests';
        aOptions.RetryCount := 3;
      end);

    options := services.Resolve<IOptions<TDiTestOptions>>;

    Assert.IsNotNull(options);
    Assert.AreEqual('QuickCore.Tests', options.Value.AppName);
    Assert.AreEqual(3, options.Value.RetryCount);
  finally
    if TFile.Exists(tempFile) then
      TFile.Delete(tempFile);
    services.Free;
  end;
end;

procedure TQuickCoreDependencyInjectionTests.T_DI_09_AddTypedFactory;
var
  services: TServiceCollection;
  factory: IFactory<TThreeDepConsumer>;
  consumer: TThreeDepConsumer;
begin
  services := CreateServices;
  try
    services
      .AddSingleton<IFoo, TFoo>
      .AddSingleton<IBar, TBar>
      .AddSingleton<IBaz, TBaz>
      .AddTypedFactory<IFactory<TThreeDepConsumer>, TThreeDepConsumer>;

    factory := services.Resolve<IFactory<TThreeDepConsumer>>;
    Assert.IsNotNull(factory);

    consumer := factory.New;
    try
      Assert.IsNotNull(consumer);
      Assert.IsTrue(consumer.HasAllDependencies);
    finally
      consumer.Free;
    end;
  finally
    services.Free;
  end;
end;

procedure TQuickCoreDependencyInjectionTests.T_DI_10_Startup_Pattern;
var
  services: TServiceCollection;
  foo: IFoo;
begin
  TDependencyInjectionTestStartup.ConfigureServicesCalled := False;
  services := TServiceCollection.CreateFromStartup<TDependencyInjectionTestStartup>;
  try
    foo := services.Resolve<IFoo>;

    Assert.IsTrue(TDependencyInjectionTestStartup.ConfigureServicesCalled);
    Assert.IsNotNull(foo);
    Assert.AreEqual('foo', foo.Kind);
  finally
    services.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TQuickCoreDependencyInjectionTests);

end.