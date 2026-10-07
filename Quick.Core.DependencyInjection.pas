{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.DependencyInjection
  Description : Core Services Dependency Injection
  Author      : Kike Perez
  Version     : 1.0
  Created     : 19/10/2019
  Modified    : 03/03/2021

  This file is part of QuickCore: https://github.com/exilon/QuickCore

 ***************************************************************************

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

 *************************************************************************** }

unit Quick.Core.DependencyInjection;

{$i QuickCore.inc}

interface

uses
  {$IFDEF DEBUG}
    Quick.Debug.Utils,
  {$ENDIF}
  {$IFDEF ANDROID}
  System.IOUtils,
  {$ENDIF}
  System.SysUtils,
  System.StrUtils,
  RTTI,
  System.TypInfo,
  System.Generics.Collections,
  Quick.Commons,
  Quick.Options,
  Quick.Parameters,
  Quick.Options.Serializer.Json,
  Quick.Options.Serializer.Yaml,
  Quick.Core.Logging.Abstractions,
  Quick.Core.Serialization,
  Quick.Core.Commandline,
  Quick.Core.Extensions.Hosting,
  Quick.IOC;

type
  TServiceCollection = class;

  TRegisterServicesProc = procedure(aServices : TServiceCollection);
  /// <summary>Factory delegate for the Decorate pattern. Receives the inner service and returns the decorator.</summary>
  TDecoratorDelegate<I> = reference to function(inner: I): I;

  TOptionsFileFormat = (ofJSON, ofYAML);

  TDependencyInjector = TIocContainer;

  IServiceCollection = interface
  ['{B62812E4-D28F-4EDD-8D2D-7F17044ABB09}']
    function ConfigureServices(aRegisterProc : TRegisterServicesProc) : TServiceCollection;
    function AddOptions(aOptionsFileFormat : TOptionsFileFormat = ofJSON; aReloadOnChange : Boolean = True; const aOptionsFileName: string = ''): TServiceCollection; overload;
    function AddOptions(aSerializer : IFileOptionsSerializer; aReloadOnChange : Boolean; const aOptionsFileName : string = '') : TServiceCollection; overload;
    function AddLogging(aLoggerService : ILogger) : TServiceCollection;
    function AddDebugger : TServiceCollection;
    procedure Build;
  end;

  TAppServices = record
  private
    fServiceCollection : TServiceCollection;
  public
    constructor Create(aServiceCollection : TServiceCollection);
    function DependencyInjector : TDependencyInjector;
    function Options : TOptionsContainer;
    function Serializer : ISerializers;
    function Logger : ILogger;
  end;

  TStartupBase = class;

  TStartupClass = class of TStartupBase;

  TServiceProvider = class;

  /// <summary>Provides an explicit lifetime scope for scoped service resolution.
  /// All services resolved through the scope's ServiceProvider share the same
  /// instance for the lifetime of the scope. Free the scope to release them.
  /// Usage:
  ///   scope := services.CreateScope;
  ///   try
  ///     svc := scope.ServiceProvider.GetService<IMyService>();
  ///   finally
  ///     scope.Free;
  ///   end;</summary>
  IServiceScope = interface
  ['{A3E7C1D2-F84B-4E9A-B0C6-3D52F17A9E04}']
    function GetServiceProvider : TServiceProvider;
    property ServiceProvider : TServiceProvider read GetServiceProvider;
  end;

  TServiceCollection = class(TInterfacedObject,IServiceCollection)
  private
    fLoggerService : ILogger;
    fSerializer : ISerializers;
    fDependencyInjector : TDependencyInjector;
    fOptionsService : TOptionsContainer;
    fHostEnvironment : IHostEnvironment;
    procedure ResolveEnvVars(aOptions : TOptions);
  protected
    function DependencyInjector : TDependencyInjector; inline;
    function Options : TOptionsContainer; inline;
    function Serializer : ISerializers; inline;
    function Logger : ILogger; inline;
  public
    constructor Create;
    class function CreateFromStartup<T : TStartupBase> : TServiceCollection;
    destructor Destroy; override;
    function AppServices : TAppServices;
    function Environment : IHostEnvironment;
    function IsRegistered<TInterface : IInterface; TImplementation : class>(const aName : string = '') : Boolean; overload;
    function IsRegistered<TInterface : IInterface>(const aName: string = ''): Boolean; overload;
    function Configure<T : TOptions>(const aSectionName : string = '') : TServiceCollection; overload;
    function Configure<T : TOptions>(aConfigureOptionsFunc : TConfigureOptionsProc<T>): TServiceCollection; overload;
    function Configure<T : TOptions>(const aSectionName : string; aConfigureOptionsFunc : TConfigureOptionsProc<T>): TServiceCollection; overload;
    function Configure<T : TOptions>(aOptions : TOptions) : TServiceCollection; overload;
    function GetConfiguration<T : TOptions> : T;
    function Resolve<T>(const aName : string = '') : T; overload;
    function Resolve(aServiceType: PTypeInfo; const aName : string = ''): TValue; overload;
    function ConfigureServices(aRegisterProc : TRegisterServicesProc) : TServiceCollection;
    function AddSingleton<TInterface: IInterface; TImplementation: class>(const aName : string = ''): TServiceCollection; overload;
    function AddSingleton<TInterface: IInterface; TImplementation: class>(const aName : string; aDelegator: TActivatorDelegate<TImplementation>): TServiceCollection; overload;
    function AddSingleton<TImplementation: class>(const aName : string = ''): TServiceCollection; overload;
    function AddSingleton<TImplementation: class>(const aName : string; aDelegator: TActivatorDelegate<TImplementation>): TServiceCollection; overload;
    function AddSingleton<TInterface : IInterface>(aInstance : TInterface; const aName : string = '') : TServiceCollection; overload;
    function AddTransient<TInterface: IInterface; TImplementation: class>(const aName : string = ''): TServiceCollection; overload;
    function AddTransient<TInterface: IInterface; TImplementation: class>(const aName : string; aDelegator: TActivatorDelegate<TImplementation>): TServiceCollection; overload;
    function AddTransient<TImplementation: class>(const aName : string = ''): TServiceCollection; overload;
    function AddTransient<TImplementation: class>(const aName : string; aDelegator: TActivatorDelegate<TImplementation>): TServiceCollection; overload;
    function AddScoped<TInterface: IInterface; TImplementation: class>(const aName : string = ''): TServiceCollection; overload;
    function AddScoped<TInterface: IInterface; TImplementation: class>(const aName : string; aDelegator: TActivatorDelegate<TImplementation>): TServiceCollection; overload;
    function AddScoped<TImplementation: class>(const aName : string = ''): TServiceCollection; overload;
    function AddScoped<TImplementation: class>(const aName : string; aDelegator: TActivatorDelegate<TImplementation>): TServiceCollection; overload;
    function AddOptions(aOptionsFileFormat : TOptionsFileFormat = ofJSON; aReloadOnChange : Boolean = True; const aOptionsFileName: string = ''): TServiceCollection; overload;
    function AddOptions(aSerializer : IFileOptionsSerializer; aReloadOnChange : Boolean; const aOptionsFileName : string = '') : TServiceCollection; overload;
    function AddTypedFactory<TFactoryInterface : IInterface; TFactoryType : class, constructor>(const aName : string = '') : TServiceCollection;
    function AddSimpleFactory<TInterface : IInterface; TImplementation : class, constructor>(const aName : string = '') : TServiceCollection;
    function AddLogging(aLoggerService: ILogger): TServiceCollection;
    function AddDebugger : TServiceCollection;
    function AddCommandline<TArguments : TParameters> : TServiceCollection;
    function AbstractFactory<T : class, constructor> : T;
    /// <summary>Create a new service scope. Caller is responsible for freeing it (interface ref-count).</summary>
    function CreateScope : IServiceScope;
    // ── Keyed (named) service helpers (I-04) ────────────────────────────────
    /// <summary>Register a keyed singleton: shorthand for AddSingleton<I,T>(aKey).</summary>
    function AddKeyedSingleton<TInterface: IInterface; TImplementation: class>(const aKey : string) : TServiceCollection;
    /// <summary>Register a keyed transient: shorthand for AddTransient<I,T>(aKey).</summary>
    function AddKeyedTransient<TInterface: IInterface; TImplementation: class>(const aKey : string) : TServiceCollection;
    /// <summary>Register a keyed scoped: shorthand for AddScoped<I,T>(aKey).</summary>
    function AddKeyedScoped<TInterface: IInterface; TImplementation: class>(const aKey : string) : TServiceCollection;
    /// <summary>Resolve a keyed service: shorthand for Resolve<T>(aKey).</summary>
    function GetKeyedService<T>(const aKey : string) : T;
    // ── DI-01: TryAdd (conditional registration) ────────────────────────────
    /// <summary>Register Singleton only when TInterface is not already registered.</summary>
    function TryAddSingleton<TInterface: IInterface; TImplementation: class>(const aName: string = ''): TServiceCollection;
    /// <summary>Register Transient only when TInterface is not already registered.</summary>
    function TryAddTransient<TInterface: IInterface; TImplementation: class>(const aName: string = ''): TServiceCollection;
    /// <summary>Register Scoped only when TInterface is not already registered.</summary>
    function TryAddScoped<TInterface: IInterface; TImplementation: class>(const aName: string = ''): TServiceCollection;
    // ── DI-02: Replace ───────────────────────────────────────────────────────
    /// <summary>Replace existing registration for TInterface with TImplementation (Singleton).</summary>
    function ReplaceSingleton<TInterface: IInterface; TImplementation: class>(const aName: string = ''): TServiceCollection;
    /// <summary>Replace existing registration for TInterface with TImplementation (Transient).</summary>
    function ReplaceTransient<TInterface: IInterface; TImplementation: class>(const aName: string = ''): TServiceCollection;
    /// <summary>Replace existing registration for TInterface with TImplementation (Scoped).</summary>
    function ReplaceScoped<TInterface: IInterface; TImplementation: class>(const aName: string = ''): TServiceCollection;
    // ── DI-04: Decorate ──────────────────────────────────────────────────────
    /// <summary>Wrap the existing registration for I with a decorator. aFactory receives the inner service and must return the decorator.
    ///  The decorator has the same lifetime as the original registration.</summary>
    function Decorate<I: IInterface>(aFactory: TDecoratorDelegate<I>): TServiceCollection;
    procedure Build;
  end;

  TStartupBase = class
  public
    class procedure ConfigureServices(services : TServiceCollection); virtual; abstract;
  end;

  TActivatorUtilities = record
  private
    fServiceCollection : TServiceCollection;
  public
    constructor Create(aServiceCollection : TServiceCollection);
    function CreateInstance<T : class, constructor>(aClass: TClass): T; overload;
    function CreateInstance<T : class, constructor> : T; overload;
  end;

  TServiceScope = class(TInterfacedObject, IServiceScope)
  private
    fProvider        : TServiceProvider;
    fScopedInstances : TDictionary<string, TValue>;
    function GetServiceProvider : TServiceProvider;
  public
    constructor Create(aParentCollection : TServiceCollection);
    destructor Destroy; override;
    /// <summary>Resolve a service, caching the instance for the lifetime of this scope.</summary>
    function GetService<T : IInterface>(const aName : string = '') : T;
    property ServiceProvider : TServiceProvider read GetServiceProvider;
  end;

  TServiceProvider = class
  private
    fServiceCollection : TServiceCollection;
  public
    constructor Create(aServiceCollection : TServiceCollection);
    function GetService<T : IInterface> : T; overload;
    function GetService<T : IInterface>(const aName : string) : T; overload;
    function GetService(aTypeInfo: PTypeInfo): TValue; overload;
    function GetService(aTypeInfo: PTypeInfo; const aName: string): TValue; overload;
    function Serializer : ISerializers;
    function ActivatorUtilities : TActivatorUtilities;
    /// <summary>Create a new service scope. Caller must free the returned scope.</summary>
    function CreateScope : IServiceScope;
  end;

  TServiceCollectionExtension = class
  private class var
    fServiceCollection : TServiceCollection;
    class function SetService(aServiceCollection : TServiceCollection) : TServiceCollectionExtension;
  public
    class property ServiceCollection : TServiceCollection read fServiceCollection;
  end;

  TServiceCollectionHelper = class helper for TServiceCollection
    function Extension<T : TServiceCollectionExtension> : T;
  end;

  EServiceConfigError = class(Exception);
  EServiceBuildError = class(Exception);

  // ── DI-04: Decorate helper types ────────────────────────────────────────────
  // Delphi cannot reference a generic type parameter I inside an anonymous
  // function body. We work around this by placing the generic logic in a plain
  // generic class method, and calling it through a non-generic interface from
  // inside the anonymous function.

  /// <summary>Non-generic interface for decorator activators.</summary>
  IDecoratorActivator = interface
  ['{A3B7C2D1-4E5F-6A7B-8C9D-E0F1A2B3C4D5}']
    function Activate: TValue;
  end;

  /// <summary>Generic activator that resolves the inner service and applies the factory.
  ///  Declared as a class so that generic type I can be referenced normally.</summary>
  TDecoratorActivator<I: IInterface> = class(TInterfacedObject, IDecoratorActivator)
  private
    FServices : TServiceCollection;
    FInnerKey : string;
    FFactory  : TDecoratorDelegate<I>;
  public
    constructor Create(aServices: TServiceCollection; const aInnerKey: string;
                       aFactory: TDecoratorDelegate<I>);
    function Activate: TValue;
  end;

implementation

{ TServiceCollection }

constructor TServiceCollection.Create;
begin
  fLoggerService := TNullLogger.Create;
  fDependencyInjector := TDependencyInjector.Create;
  fSerializer := TSerializers.Create;
  fHostEnvironment := THostEnvironment.Create;
end;

class function TServiceCollection.CreateFromStartup<T> : TServiceCollection;
begin
  try
    Result := TServiceCollection.Create;
    T.ConfigureServices(Result);
    Result.Build;
  except
    on E : Exception do
    begin
      raise EServiceBuildError.CreateFmt('DependencyInjection: Failed to build services (%s)',[e.Message]);
    end;
  end;
end;

destructor TServiceCollection.Destroy;
begin
  {$IFDEF DEBUG_DI}
  TDebugger.Enter(Self,'Destroy');
  {$ENDIF}
  fDependencyInjector.Free;
  if Assigned(fOptionsService) then fOptionsService.Free;
  inherited;
end;

function TServiceCollection.Environment: IHostEnvironment;
begin
  Result := fHostEnvironment;
end;

function TServiceCollection.GetConfiguration<T>: T;
begin
  Result := fOptionsService.GetSection<T>;
end;

function TServiceCollection.IsRegistered<TInterface, TImplementation>(const aName: string = ''): Boolean;
begin
  Result := fDependencyInjector.IsRegistered<TInterface,TImplementation>(aName);
end;

function TServiceCollection.IsRegistered<TInterface>(const aName: string = ''): Boolean;
begin
  Result := fDependencyInjector.IsRegistered<TInterface>(aName);
end;

function TServiceCollection.DependencyInjector: TDependencyInjector;
begin
  Result := fDependencyInjector;
end;

function TServiceCollection.Logger: ILogger;
begin
  Result := fLoggerService;
end;

function TServiceCollection.Options: TOptionsContainer;
begin
  Result := fOptionsService;
end;

function TServiceCollection.Serializer: ISerializers;
begin
  Result := fSerializer;
end;

function TServiceCollection.AbstractFactory<T>: T;
begin
  Result := fDependencyInjector.AbstractFactory<T>;
end;

function TServiceCollection.AddKeyedSingleton<TInterface, TImplementation>(const aKey : string) : TServiceCollection;
begin
  Result := AddSingleton<TInterface, TImplementation>(aKey);
end;

function TServiceCollection.AddKeyedTransient<TInterface, TImplementation>(const aKey : string) : TServiceCollection;
begin
  Result := AddTransient<TInterface, TImplementation>(aKey);
end;

function TServiceCollection.AddKeyedScoped<TInterface, TImplementation>(const aKey : string) : TServiceCollection;
begin
  Result := AddScoped<TInterface, TImplementation>(aKey);
end;

function TServiceCollection.GetKeyedService<T>(const aKey : string) : T;
begin
  Result := fDependencyInjector.Resolve<T>(aKey);
end;

// ── DI-01: TryAdd ────────────────────────────────────────────────────────────

function TServiceCollection.TryAddSingleton<TInterface, TImplementation>(const aName: string): TServiceCollection;
begin
  Result := Self;
  if not IsRegistered<TInterface>(aName) then
    AddSingleton<TInterface, TImplementation>(aName);
end;

function TServiceCollection.TryAddTransient<TInterface, TImplementation>(const aName: string): TServiceCollection;
begin
  Result := Self;
  if not IsRegistered<TInterface>(aName) then
    AddTransient<TInterface, TImplementation>(aName);
end;

function TServiceCollection.TryAddScoped<TInterface, TImplementation>(const aName: string): TServiceCollection;
begin
  Result := Self;
  if not IsRegistered<TInterface>(aName) then
    AddScoped<TInterface, TImplementation>(aName);
end;

// ── DI-02: Replace ───────────────────────────────────────────────────────────

function TServiceCollection.ReplaceSingleton<TInterface, TImplementation>(const aName: string): TServiceCollection;
begin
  Result := Self;
  fDependencyInjector.Registrator.RemoveRegistrations(
    fDependencyInjector.Registrator.GetKey(TypeInfo(TInterface), aName));
  AddSingleton<TInterface, TImplementation>(aName);
end;

function TServiceCollection.ReplaceTransient<TInterface, TImplementation>(const aName: string): TServiceCollection;
begin
  Result := Self;
  fDependencyInjector.Registrator.RemoveRegistrations(
    fDependencyInjector.Registrator.GetKey(TypeInfo(TInterface), aName));
  AddTransient<TInterface, TImplementation>(aName);
end;

function TServiceCollection.ReplaceScoped<TInterface, TImplementation>(const aName: string): TServiceCollection;
begin
  Result := Self;
  fDependencyInjector.Registrator.RemoveRegistrations(
    fDependencyInjector.Registrator.GetKey(TypeInfo(TInterface), aName));
  AddScoped<TInterface, TImplementation>(aName);
end;

// ── DI-04: Decorate ──────────────────────────────────────────────────────────

function TServiceCollection.Decorate<I>(aFactory: TDecoratorDelegate<I>): TServiceCollection;
const
  INNER_SUFFIX = '.__inner__';
var
  key        : string;
  innerKey   : string;
  regList    : TObjectList<TIocRegistration>;
  existing   : TIocRegistration;
  implClass  : TClass;
  isSingle   : Boolean;
  isTransient: Boolean;
  savedDlg   : TActivatorDelegate<TValue>;
  innerReg   : TIocRegistration;
  decReg     : TIocRegistrationInterface;
  decList    : TObjectList<TIocRegistration>;
  act        : IDecoratorActivator;
begin
  Result := Self;
  key := fDependencyInjector.Registrator.GetKey(TypeInfo(I), '');

  if not fDependencyInjector.Registrator.Dependencies.TryGetValue(key, regList)
     or (regList.Count = 0) then
    raise EServiceConfigError.CreateFmt(
      'Decorate: service %s is not registered', [GetTypeName(TypeInfo(I))]);

  existing    := regList[regList.Count - 1]; // last = active registration
  implClass   := existing.&Implementation;
  isSingle    := existing.IsSingleton;
  isTransient := existing.IsTransient;
  savedDlg    := existing.ActivatorDelegate;

  if implClass = nil then
    raise EServiceConfigError.CreateFmt(
      'Decorate: cannot decorate instance-based registration of %s. ' +
      'Use type-based AddSingleton/Transient/Scoped instead.',
      [GetTypeName(TypeInfo(I))]);

  // Re-register the original implementation under a keyed "inner" name
  innerKey := key + INNER_SUFFIX;
  innerReg := fDependencyInjector.RegisterType(TypeInfo(I), implClass, innerKey);
  if isSingle then innerReg.AsSingleton
  else if isTransient then innerReg.AsTransient
  else innerReg.AsScoped;
  if Assigned(savedDlg) then
    innerReg.ActivatorDelegate := savedDlg;

  // Remove the original (unnamed) registration so the decorator takes its place
  fDependencyInjector.Registrator.RemoveRegistrations(key);

  // Build the decorator registration using a factory delegate.
  // TDecoratorActivator<I> is used to avoid referencing generic type I
  // inside the anonymous function body (Delphi compiler limitation).
  act := TDecoratorActivator<I>.Create(Self, innerKey, aFactory);
  decReg := TIocRegistrationInterface.Create('');
  decReg.IntfInfo := TypeInfo(I);
  decReg.ActivatorDelegate := function: TValue
  begin
    Result := act.Activate;  // No generic type I referenced inside this closure
  end;
  if isSingle then decReg.AsSingleton
  else if isTransient then decReg.AsTransient
  else decReg.AsScoped;

  // Inject decorator registration into the IOC registrator
  if not fDependencyInjector.Registrator.Dependencies.TryGetValue(key, decList) then
  begin
    decList := TObjectList<TIocRegistration>.Create(True); // owns objects
    fDependencyInjector.Registrator.Dependencies.Add(key, decList);
  end;
  decList.Add(decReg);
  fDependencyInjector.Registrator.DependencyOrder.Add(decReg);
end;

// ── TDecoratorActivator<I> ──────────────────────────────────────────────────

constructor TDecoratorActivator<I>.Create(aServices: TServiceCollection;
  const aInnerKey: string; aFactory: TDecoratorDelegate<I>);
begin
  inherited Create;
  FServices := aServices;
  FInnerKey := aInnerKey;
  FFactory  := aFactory;
end;

function TDecoratorActivator<I>.Activate: TValue;
begin
  // I is the class's own generic parameter here – Delphi handles this normally.
  Result := TValue.From<I>(FFactory(FServices.Resolve<I>(FInnerKey)));
end;

function TServiceCollection.AddDebugger: TServiceCollection;
begin
  Result := Self;
  {$IFDEF DEBUG}
    TDebugger.SetLogger(fLoggerService);
    TDebugger.Log.Warn('Debug logging enabled');
  {$ENDIF}
end;

function TServiceCollection.AddLogging(aLoggerService: ILogger): TServiceCollection;
begin
  Result := Self;
  if aLoggerService = nil then aLoggerService := TNullLogger.Create;
  fLoggerService := aLoggerService;
  fDependencyInjector.RegisterInstance<ILogger>(aLoggerService).AsSingleton;
end;

function TServiceCollection.AddCommandline<TArguments> : TServiceCollection;
begin
  Result := Self;
  fDependencyInjector.RegisterInstance<ICommandline<TArguments>>(TCommandline<TArguments>.Create).AsSingleton;
end;

function TServiceCollection.AddOptions(aOptionsFileFormat : TOptionsFileFormat = ofJSON; aReloadOnChange : Boolean = True; const aOptionsFileName: string = ''): TServiceCollection;
var
  serializer : IFileOptionsSerializer;
begin
  case aOptionsFileFormat of
    TOptionsFileFormat.ofJSON : serializer := TJsonOptionsSerializer.Create(aOptionsFileName);
    TOptionsFileFormat.ofYAML : serializer := TYamlOptionsSerializer.Create(aOptionsFileName);
    else raise EServiceConfigError.Create('Options Serializer not recognized!');
  end;
  Result := AddOptions(serializer,aReloadOnChange,aOptionsFileName);
end;

function TServiceCollection.AddOptions(aSerializer : IFileOptionsSerializer; aReloadOnChange : Boolean; const aOptionsFileName : string = '') : TServiceCollection;
var
  filename : string;
  fullfilename : string;
  iserializer : IFileOptionsSerializer;
  env : string;
begin
  Result := Self;
  env := Environment.EnvironmentName;
  if not env.IsEmpty then
  begin
    Logger.Info('Core Environment: "%s"',[env]);
    env := '.' + env;
  end;

  if not aOptionsFileName.IsEmpty then fullfilename := aOptionsFileName
  else
  begin
    {$IFDEF ANDROID}
    filename := TPath.GetDocumentsPath + PathDelim + 'appSettings';
    {$ELSE}
    filename := path.EXEPATH + PathDelim + 'appSettings';
    {$ENDIF}

    if aSerializer is TJsonOptionsSerializer then
    begin
      fullfilename := filename + env + '.json';
      if not FileExists(fullfilename) then
      begin
        Logger.Warn('Config file not found: "%s"',[fullfilename]);
        fullfilename := filename + '.json';
      end;
    end
    else if aSerializer is TYamlOptionsSerializer then
    begin
      fullfilename := filename + env + '.yml';
      if not FileExists(fullfilename) then
      begin
        Logger.Warn('Config file not found: "%s"',[fullfilename]);
        fullfilename := filename + '.yml';
      end;
    end
    else raise EServiceConfigError.Create('Options Serializer not recognized!');
  end;
  if aSerializer <> nil then
  begin
    iserializer := aSerializer;
    iserializer.Filename := fullfilename;
  end
  else iserializer := TJsonOptionsSerializer.Create(fullfilename);
  if IsDebug then Logger.Debug('Loading settings from "%s"',[fullfilename]);
  fOptionsService := TFileOptionsContainer.Create(iserializer,aReloadOnChange);
end;

function TServiceCollection.AddSingleton<TInterface, TImplementation>(const aName : string = ''): TServiceCollection;
begin
  Result := Self;
  fDependencyInjector.RegisterType<TInterface,TImplementation>(aName).AsSingleton;
end;

function TServiceCollection.AddSingleton<TInterface, TImplementation>(const aName: string; aDelegator: TActivatorDelegate<TImplementation>): TServiceCollection;
begin
  Result := Self;
  fDependencyInjector.RegisterType<TInterface,TImplementation>(aName).AsSingleton.DelegateTo(aDelegator);
end;

function TServiceCollection.AddSingleton<TImplementation>(const aName: string): TServiceCollection;
begin
  Result := Self;
  fDependencyInjector.RegisterInstance<TImplementation>(aName).AsSingleton;
end;

function TServiceCollection.AddSimpleFactory<TInterface, TImplementation>(const aName: string): TServiceCollection;
begin
  Result := Self;
  fDependencyInjector.RegisterSimpleFactory<TInterface,TImplementation>;
  //fDependencyInjector.RegisterType<IFactory<TInterface>,TSimpleFactory<TInterface,TImplementation>>(aName).AsSingleton;
end;

function TServiceCollection.AddSingleton<TImplementation>(const aName: string; aDelegator: TActivatorDelegate<TImplementation>): TServiceCollection;
begin
  Result := Self;
  fDependencyInjector.RegisterInstance<TImplementation>(aName).AsSingleton.DelegateTo(aDelegator);
end;

function TServiceCollection.AddSingleton<TInterface>(aInstance: TInterface;const aName: string): TServiceCollection;
begin
  Result := Self;
  fDependencyInjector.RegisterInstance<TInterface>(aInstance,aName).AsSingleton;
end;

function TServiceCollection.AddTransient<TInterface, TImplementation>(const aName : string = ''): TServiceCollection;
begin
  Result := Self;
  fDependencyInjector.RegisterType<TInterface,TImplementation>(aName).AsTransient;
end;

function TServiceCollection.AddTransient<TInterface, TImplementation>(const aName: string; aDelegator: TActivatorDelegate<TImplementation>): TServiceCollection;
begin
  Result := Self;
  fDependencyInjector.RegisterType<TInterface, TImplementation>(aName).AsTransient.DelegateTo(aDelegator);
end;

function TServiceCollection.AddTypedFactory<TFactoryInterface, TFactoryType>(const aName: string): TServiceCollection;
begin
  Result := Self;
  fDependencyInjector.RegisterTypedFactory<TFactoryInterface,TFactoryType>(aName);
end;

function TServiceCollection.AppServices: TAppServices;
begin
  Result.Create(Self);
end;

procedure TServiceCollection.Build;
var
  i : Integer;
  canSave : Boolean;
begin
  {$IFDEF DEBUG_DI}
  TDebugger.Trace(Self,'Build');
  {$ENDIF}
  fDependencyInjector.Build;
  if Assigned(fOptionsService) then
  begin
    canSave := False;
    for i := 0 to fOptionsService.Count-1 do
    begin
      if not fOptionsService.Items[i].HideOptions then
      begin
        canSave := True;
        Break;
      end;
    end;
    if canSave then fOptionsService.Save;
  end;
end;

function TServiceCollection.AddTransient<TImplementation>(const aName: string): TServiceCollection;
begin
  Result := Self;
  fDependencyInjector.RegisterInstance<TImplementation>(aName).AsTransient;
end;

function TServiceCollection.AddTransient<TImplementation>(const aName: string; aDelegator: TActivatorDelegate<TImplementation>): TServiceCollection;
begin
  Result := Self;
  fDependencyInjector.RegisterInstance<TImplementation>(aName).AsTransient.DelegateTo(aDelegator);
end;

function TServiceCollection.AddScoped<TInterface, TImplementation>(const aName : string = ''): TServiceCollection;
begin
  Result := Self;
  fDependencyInjector.RegisterType<TInterface,TImplementation>(aName).AsScoped;
end;

function TServiceCollection.AddScoped<TInterface, TImplementation>(const aName: string; aDelegator: TActivatorDelegate<TImplementation>): TServiceCollection;
begin
  Result := Self;
  fDependencyInjector.RegisterType<TInterface,TImplementation>(aName).AsScoped.DelegateTo(aDelegator);
end;

function TServiceCollection.AddScoped<TImplementation>(const aName: string): TServiceCollection;
begin
  Result := Self;
  fDependencyInjector.RegisterInstance<TImplementation>(aName).AsScoped;
end;

function TServiceCollection.AddScoped<TImplementation>(const aName: string; aDelegator: TActivatorDelegate<TImplementation>): TServiceCollection;
begin
  Result := Self;
  fDependencyInjector.RegisterInstance<TImplementation>(aName).AsScoped.DelegateTo(aDelegator);
end;

function TServiceCollection.Configure<T>(const aSectionName : string = '') : TServiceCollection;
begin
  Result := Self;
  Configure<T>(aSectionName,nil);
end;

function TServiceCollection.Configure<T>(aConfigureOptionsFunc : TConfigureOptionsProc<T>): TServiceCollection;
begin
  Result := Self;
  Configure<T>('',aConfigureOptionsFunc);
end;

function TServiceCollection.Configure<T>(const aSectionName : string; aConfigureOptionsFunc : TConfigureOptionsProc<T>): TServiceCollection;
var
  options : T;
begin
  Result := Self;
  if not Assigned(fOptionsService) then raise EServiceConfigError.CreateFmt('Cannot Configure "%s" Options before AddOptions',[aSectionName]);
  fOptionsService.AddSection<T>(aSectionName).ConfigureOptions(aConfigureOptionsFunc);
  options := fOptionsService.GetSection<T>(aSectionName);
  fDependencyInjector.RegisterOptions<T>(options);
  //load section from file
  if not TOptions(options).HideOptions then
  begin
    Logger.Debug('Loading "%s" settings...',[TOptions(options).Name]);
    fOptionsService.LoadSection(options);
    ResolveEnvVars(options);
  end;
end;

function TServiceCollection.Configure<T>(aOptions : TOptions) : TServiceCollection;
begin
  Result := Self;
  if not Assigned(fOptionsService) then raise EServiceConfigError.CreateFmt('Cannot Configure "%s" Options before AddOptions',[Ifx(aOptions.Name.IsEmpty,aOptions.ClassName,aOptions.Name)]);
  fOptionsService.AddOption(aOptions);
  fDependencyInjector.RegisterOptions<T>(aOptions);
  //load section from file
  if not TOptions(aOptions).HideOptions then
  begin
    Logger.Debug('Loading "%s" settings...',[TOptions(aOptions).Name]);
    fOptionsService.LoadSection(aOptions);
    ResolveEnvVars(aOptions);
  end;
end;

procedure TServiceCollection.ResolveEnvVars(aOptions : TOptions);
var
  ctx      : TRttiContext;
  rType    : TRttiType;
  rProp    : TRttiProperty;
  value    : string;
  startPos : Integer;
  endPos   : Integer;
  varName  : string;
  varValue : string;
begin
  if aOptions = nil then
    Exit;

  rType := ctx.GetType(aOptions.ClassInfo);
  for rProp in rType.GetProperties do
  begin
    if not rProp.IsWritable then
      Continue;
    if not (rProp.PropertyType.TypeKind in [tkString, tkLString, tkWString, tkUString]) then
      Continue;

    value := rProp.GetValue(aOptions).AsString;
    startPos := Pos('${', value);
    while startPos > 0 do
    begin
      endPos := PosEx('}', value, startPos + 2);
      if endPos = 0 then
        Break;
      varName := Copy(value, startPos + 2, endPos - startPos - 2);
      varValue := GetEnvironmentVariable(varName);
      value := Copy(value, 1, startPos - 1) + varValue + Copy(value, endPos + 1, MaxInt);
      startPos := Pos('${', value);
    end;

    rProp.SetValue(aOptions, value);
  end;
end;

function TServiceCollection.ConfigureServices(aRegisterProc: TRegisterServicesProc): TServiceCollection;
begin
  Result := Self;
  aRegisterProc(Self);
end;

function TServiceCollection.Resolve(aServiceType: PTypeInfo; const aName : string = ''): TValue;
begin
  Result := fDependencyInjector.Resolve(aServiceType,aName);
end;

function TServiceCollection.Resolve<T>(const aName : string = '') : T;
begin
  Result := fDependencyInjector.Resolve<T>(aName);
end;

function TServiceCollection.CreateScope : IServiceScope;
begin
  Result := TServiceScope.Create(Self);
end;

{ TServiceProvider }

function TServiceProvider.ActivatorUtilities: TActivatorUtilities;
begin
  Result.Create(fServiceCollection);
end;

constructor TServiceProvider.Create(aServiceCollection: TServiceCollection);
begin
  fServiceCollection := aServiceCollection;
end;

function TServiceProvider.GetService<T>: T;
begin
  Result := fServiceCollection.Resolve<T>;
end;

function TServiceProvider.GetService<T>(const aName : string): T;
begin
  Result := fServiceCollection.Resolve<T>(aName);
end;

function TServiceProvider.Serializer: ISerializers;
begin
  Result := fServiceCollection.Serializer;
end;

function TServiceProvider.GetService(aTypeInfo : PTypeInfo) : TValue;
begin
  Result := fServiceCollection.Resolve(aTypeInfo,'');
end;

function TServiceProvider.GetService(aTypeInfo : PTypeInfo; const aName: string) : TValue;
begin
  Result := fServiceCollection.Resolve(aTypeInfo, aName);
end;

function TServiceProvider.CreateScope : IServiceScope;
begin
  Result := TServiceScope.Create(fServiceCollection);
end;

{ TServiceScope }

constructor TServiceScope.Create(aParentCollection : TServiceCollection);
begin
  fProvider        := TServiceProvider.Create(aParentCollection);
  fScopedInstances := TDictionary<string, TValue>.Create;
end;

destructor TServiceScope.Destroy;
begin
  fScopedInstances.Free; // releases all TValue entries (and their interface ref-counts)
  fProvider.Free;
  inherited;
end;

function TServiceScope.GetServiceProvider : TServiceProvider;
begin
  Result := fProvider;
end;

function TServiceScope.GetService<T>(const aName : string = '') : T;
var
  key : string;
  val : TValue;
begin
  key := string(GetTypeName(TypeInfo(T)));
  if aName <> '' then key := key + '::' + aName;
  if fScopedInstances.TryGetValue(key, val) then
  begin
    Result := val.AsType<T>;
    Exit;
  end;
  Result := fProvider.fServiceCollection.Resolve<T>(aName);
  fScopedInstances.Add(key, TValue.From<T>(Result));
end;

{ TAppServices }

constructor TAppServices.Create(aServiceCollection: TServiceCollection);
begin
  fServiceCollection := aServiceCollection;
end;

function TAppServices.DependencyInjector: TDependencyInjector;
begin
  Result := fServiceCollection.DependencyInjector;
end;

function TAppServices.Logger: ILogger;
begin
  Result := fServiceCollection.Logger;
end;

function TAppServices.Options: TOptionsContainer;
begin
  Result := fServiceCollection.Options;
end;

function TAppServices.Serializer: ISerializers;
begin
  Result := fServiceCollection.Serializer;
end;


{ TServiceCollectionExtension }

class function TServiceCollectionExtension.SetService(aServiceCollection: TServiceCollection): TServiceCollectionExtension;
begin
  Result := TServiceCollectionExtension(Self);
  fServiceCollection := aServiceCollection;
end;

{ TServiceCollectionHelper }

function TServiceCollectionHelper.Extension<T>: T;
begin
  //TServiceCollectionExtension(Result).SetService(Self);
  Result := T(TServiceCollectionExtension.SetService(Self));
end;

{ TActivatorUtilities }

constructor TActivatorUtilities.Create(aServiceCollection: TServiceCollection);
begin
  fServiceCollection := aServiceCollection;
end;

function TActivatorUtilities.CreateInstance<T>(aClass: TClass): T;
begin
  Result := fServiceCollection.DependencyInjector.AbstractFactory<T>(aClass);
end;

function TActivatorUtilities.CreateInstance<T>: T;
begin
  Result := fServiceCollection.DependencyInjector.AbstractFactory<T>;
end;

end.
