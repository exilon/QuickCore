{ ***************************************************************************

  Copyright (c) 2016-2021 Kike Pérez

  Unit        : Quick.Core.DependencyInjection
  Description : Core Services Dependency Injection
  Author      : Kike Pérez
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
  System.SysUtils,
  RTTI,
  System.TypInfo,
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

  TOptionsFileFormat = (ofJSON, ofYAML);

  TDependencyInjector = TIocContainer;

  IServiceCollection = interface
  ['{B62812E4-D28F-4EDD-8D2D-7F17044ABB09}']
    function ConfigureServices(aRegisterProc : TRegisterServicesProc) : TServiceCollection;
    function AddOptions(aOptionsFileFormat : TOptionsFileFormat = ofJSON; aReloadOnChange : Boolean = True; const aOptionsFileName: string = ''): TServiceCollection; overload;
    function AddOptions(aSerializer : IOptionsSerializer; aReloadOnChange : Boolean; const aOptionsFileName : string = '') : TServiceCollection; overload;
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

  TServiceCollection = class(TInterfacedObject,IServiceCollection)
  private
    fLoggerService : ILogger;
    fSerializer : ISerializers;
    fDependencyInjector : TDependencyInjector;
    fOptionsService : TOptionsContainer;
    fHostEnvironment : IHostEnvironment;
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
    function AddOptions(aSerializer : IOptionsSerializer; aReloadOnChange : Boolean; const aOptionsFileName : string = '') : TServiceCollection; overload;
    function AddTypedFactory<TFactoryInterface : IInterface; TFactoryType : class, constructor>(const aName : string = '') : TServiceCollection;
    function AddLogging(aLoggerService: ILogger): TServiceCollection;
    function AddDebugger : TServiceCollection;
    function AddCommandline<TArguments : TParameters> : TServiceCollection;
    function AbstractFactory<T : class, constructor> : T;
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

  TServiceProvider = class
  private
    fServiceCollection : TServiceCollection;
  public
    constructor Create(aServiceCollection : TServiceCollection);
    function GetService<T : IInterface> : T; overload;
    function GetService(aTypeInfo: PTypeInfo): TValue; overload;
    function Serializer : ISerializers;
    function ActivatorUtilities : TActivatorUtilities;
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
  serializer : TOptionsSerializer;
begin
  case aOptionsFileFormat of
    TOptionsFileFormat.ofJSON : serializer := TJsonOptionsSerializer.Create;
    TOptionsFileFormat.ofYAML : serializer := TYamlOptionsSerializer.Create;
    else raise EServiceConfigError.Create('Options Serializer not recognized!');
  end;
  Result := AddOptions(serializer,aReloadOnChange,aOptionsFileName);
end;

function TServiceCollection.AddOptions(aSerializer : IOptionsSerializer; aReloadOnChange : Boolean; const aOptionsFileName : string = '') : TServiceCollection;
var
  filename : string;
  fnalternative : string;
  iserializer : IOptionsSerializer;
  env : string;
begin
  Result := Self;
  env := Environment.EnvironmentName;
  if not env.IsEmpty then
  begin
    Logger.Info('Core Environment: "%s"',[env]);
    env := '.' + env;
  end;

  if not aOptionsFileName.IsEmpty then filename := aOptionsFileName
  else
  begin
    if aSerializer is TJsonOptionsSerializer then
    begin
      filename := path.EXEPATH + PathDelim + 'appSettings' + env + '.json';
      if not FileExists(filename) then
      begin
        Logger.Warn('Config file not found: "%s"',[filename]);
        filename := path.EXEPATH + PathDelim + 'appSettings.json';
      end;
    end
    else if aSerializer is TYamlOptionsSerializer then
    begin
      filename := path.EXEPATH + PathDelim + 'appSettings' + env + '.yml';
      if not FileExists(filename) then
      begin
        Logger.Warn('Config file not found: "%s"',[filename]);
        filename := path.EXEPATH + PathDelim + 'appSettings.yml';
      end;
    end
    else raise EServiceConfigError.Create('Options Serializer not recognized!');
  end;
  if aSerializer <> nil then iserializer := aSerializer
    else iserializer := TJsonOptionsSerializer.Create;
  if IsDebug then Logger.Debug('Loading settings from "%s"',[filename]);
  fOptionsService := TOptionsContainer.Create(filename,iserializer,aReloadOnChange);
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
  fDependencyInjector.Build;
  if Assigned(fOptionsService) then
  begin
    canSave := False;
    for i := 0 to fOptionsService.Count do
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

function TServiceProvider.Serializer: ISerializers;
begin
  Result := fServiceCollection.Serializer;
end;

function TServiceProvider.GetService(aTypeInfo : PTypeInfo) : TValue;
begin
  Result := fServiceCollection.Resolve(aTypeInfo,'');
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
