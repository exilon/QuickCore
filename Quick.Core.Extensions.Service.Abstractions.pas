unit Quick.Core.Extensions.Service.Abstractions;

interface

uses
  System.SysUtils,
  Quick.Core.Logging.Abstractions,
  Quick.Core.Extensions.Hosting;

type
  TSvcInitializeEvent = procedure of object;
  TSvcAnonMethod = reference to procedure;
  TSvcRemoveEvent = procedure of object;

  IHostService = interface(IHost)
  ['{79251D22-01C3-44EF-8E8A-4C2CAC7DA510}']
    procedure Start;
    procedure Stop;
    procedure Install;
    procedure Remove;
    function CheckParams : Boolean;
    function IsRunningAsService : Boolean;
  end;

  THostService = class(TInterfacedObject,IHostService)
  private
    fLogger : ILogger;
    fOnExecute: TSvcAnonMethod;
    fWaitForKeyOnExit: Boolean;
    fOnStop: TSvcAnonMethod;
    fOnStart: TSvcAnonMethod;
    fOnInitialize: TSvcInitializeEvent;
    fServiceName: string;
    fPassword: string;
    fUser: string;
    fDescription: string;
  public
    property ServiceName : string read fServiceName write fServiceName;
    property User : string read fUser write fUser;
    property Password : string read fPassword write fPassword;
    property Description : string read fDescription write fDescription;
    property OnInitialize : TSvcInitializeEvent read fOnInitialize write fOnInitialize;
    property OnStart : TSvcAnonMethod read fOnStart write fOnStart;
    property OnStop : TSvcAnonMethod read fOnStop write fOnStop;
    property OnExecute : TSvcAnonMethod read fOnExecute write fOnExecute;
    property WaitForKeyOnExit : Boolean read fWaitForKeyOnExit write fWaitForKeyOnExit;
    property Logger : ILogger read fLogger write fLogger;
    procedure Start; virtual; abstract;
    procedure Stop; virtual; abstract;
    procedure Install; virtual; abstract;
    procedure Remove; virtual; abstract;
    function CheckParams : Boolean; virtual; abstract;
    function IsRunningAsService : Boolean; virtual; abstract;
  end;

implementation

end.
