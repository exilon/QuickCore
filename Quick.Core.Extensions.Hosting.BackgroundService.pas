{ **************************** }
{      Quick.Core Library      }
{   IHostedService / Background }
{ **************************** }
{ Author: QuickCore Team       }
{ **************************** }
unit Quick.Core.Extensions.Hosting.BackgroundService;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.TypInfo,
  System.Generics.Collections,
  Quick.Core.DependencyInjection;

type
  { Implement StartAsync/StopAsync to provide a hosted service that runs
    alongside the application. Use AddHostedService<T> to register. }
  IHostedService = interface
  ['{B3F1A6D2-7C8E-4A3F-9D1B-2E5C0F4A7B3D}']
    procedure StartAsync;
    procedure StopAsync;
  end;

  { Manages the lifecycle of all registered IHostedService instances.
    Call Initialize(ServiceCollection) once after Build, then StartAll/StopAll. }
  IHostedServiceManager = interface
  ['{A4C2E8F1-3D7B-4E9A-8C6F-1B5A0D3E7C2F}']
    procedure Initialize(aServiceCollection : TServiceCollection);
    procedure StartAll;
    procedure StopAll;
  end;

  THostedServiceManager = class(TInterfacedObject, IHostedServiceManager)
  private
    { Pending type-infos registered before Build.
      Class var so they are accumulated by AddHostedService calls. }
    class var fPendingTypes : TList<PTypeInfo>;
    class var fPendingNames : TList<string>;
    fRunning : TList<IHostedService>;
  public
    constructor Create;
    destructor Destroy; override;
    class constructor ClassCreate;
    class destructor ClassDestroy;
    class procedure AddPendingType(aTypeInfo : PTypeInfo; const aName : string);
    procedure Initialize(aServiceCollection : TServiceCollection);
    procedure StartAll;
    procedure StopAll;
  end;

  { Abstract base. Override ExecuteAsync with your background logic.
    ExecuteAsync runs on a background thread. Check CancelRequested in loops. }
  TBackgroundService = class abstract(TInterfacedObject, IHostedService)
  private type
    TWorkerThread = class(TThread)
    private
      fOwner : TBackgroundService;
    public
      constructor Create(aOwner : TBackgroundService);
      procedure Execute; override;
    end;
  private
    fThread          : TWorkerThread;
    fCancelRequested : Boolean;
  protected
    procedure ExecuteAsync; virtual; abstract;
    property CancelRequested : Boolean read fCancelRequested;
  public
    constructor Create;
    destructor Destroy; override;
    procedure StartAsync; virtual;
    procedure StopAsync; virtual;
  end;

  THostedServiceExtension = class(TServiceCollectionExtension)
  public
    { Register TImplementation as a singleton IHostedService that will be
      started when the host starts and stopped when it stops. }
    class function AddHostedService<TImplementation : class, constructor> : TServiceCollection;
  end;

implementation

uses
  System.Rtti;

{ THostedServiceManager }

class constructor THostedServiceManager.ClassCreate;
begin
  fPendingTypes := TList<PTypeInfo>.Create;
  fPendingNames := TList<string>.Create;
end;

class destructor THostedServiceManager.ClassDestroy;
begin
  fPendingTypes.Free;
  fPendingNames.Free;
end;

constructor THostedServiceManager.Create;
begin
  fRunning := TList<IHostedService>.Create;
end;

destructor THostedServiceManager.Destroy;
begin
  fRunning.Free;
  inherited;
end;

class procedure THostedServiceManager.AddPendingType(aTypeInfo : PTypeInfo; const aName : string);
begin
  fPendingTypes.Add(aTypeInfo);
  fPendingNames.Add(aName);
end;

procedure THostedServiceManager.Initialize(aServiceCollection : TServiceCollection);
var
  i       : Integer;
  svc     : IHostedService;
  value   : TValue;
begin
  fRunning.Clear;
  for i := 0 to fPendingTypes.Count - 1 do
  begin
    value := aServiceCollection.Resolve(fPendingTypes[i], fPendingNames[i]);
    if value.IsObjectInstance then
    begin
      if Supports(value.AsObject, IHostedService, svc) then
        fRunning.Add(svc);
    end
    else if value.Kind = tkInterface then
    begin
      if value.AsInterface.QueryInterface(IHostedService, svc) = S_OK then
        fRunning.Add(svc);
    end;
  end;
end;

procedure THostedServiceManager.StartAll;
var
  svc : IHostedService;
begin
  for svc in fRunning do
    svc.StartAsync;
end;

procedure THostedServiceManager.StopAll;
var
  svc : IHostedService;
begin
  for svc in fRunning do
    svc.StopAsync;
end;

{ TBackgroundService.TWorkerThread }

constructor TBackgroundService.TWorkerThread.Create(aOwner : TBackgroundService);
begin
  inherited Create(True);
  fOwner := aOwner;
  FreeOnTerminate := False;
end;

procedure TBackgroundService.TWorkerThread.Execute;
begin
  fOwner.ExecuteAsync;
end;

{ TBackgroundService }

constructor TBackgroundService.Create;
begin
  fThread := nil;
  fCancelRequested := False;
end;

destructor TBackgroundService.Destroy;
begin
  if fThread <> nil then
  begin
    fCancelRequested := True;
    fThread.WaitFor;
    fThread.Free;
  end;
  inherited;
end;

procedure TBackgroundService.StartAsync;
begin
  fCancelRequested := False;
  fThread := TWorkerThread.Create(Self);
  fThread.Start;
end;

procedure TBackgroundService.StopAsync;
begin
  fCancelRequested := True;
  if fThread <> nil then
  begin
    fThread.WaitFor;
    FreeAndNil(fThread);
  end;
end;

{ THostedServiceExtension }

class function THostedServiceExtension.AddHostedService<TImplementation> : TServiceCollection;
var
  typeName : string;
begin
  Result := ServiceCollection;
  // Ensure the manager is registered
  if not ServiceCollection.IsRegistered<IHostedServiceManager> then
    ServiceCollection.AddSingleton<IHostedServiceManager, THostedServiceManager>;
  // Register the concrete implementation as a singleton with a unique name
  typeName := TImplementation.ClassName;
  ServiceCollection.AddSingleton<TImplementation>(typeName);
  // Record the type info so the manager can resolve it after Build
  THostedServiceManager.AddPendingType(TypeInfo(TImplementation), typeName);
end;

end.
