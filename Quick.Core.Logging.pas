{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Logging
  Description : Core Logging
  Author      : Kike Pérez
  Version     : 1.8
  Created     : 02/11/2019
  Modified    : 16/06/2020

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

unit Quick.Core.Logging;

{$i QuickCore.inc}

interface

uses
  {$IFDEF DEBUG_LOGGING}
  Quick.Debug.Utils,
  {$ENDIF}
  System.SysUtils,
  Quick.Commons,
  Quick.Options,
  Quick.Options.Serializer.Json,
  Quick.Options.Serializer.Yaml,
  Quick.AutoMapper,
  Quick.Core.Logging.Abstractions,
  Quick.Logger,
  Quick.Console,
  Quick.Logger.Provider.Console,
  Quick.Logger.Provider.Files,
  Quick.Logger.Provider.Redis,
  Quick.Logger.Provider.Rest,
  {$IFDEF MSWINDOWS}
  Quick.Logger.Provider.EventLog,
  Quick.Logger.Provider.ADODB,
  {$ENDIF}
  Quick.Logger.Provider.Telegram,
  Quick.Logger.Provider.Slack,
  {$IFDEF DEBUG}
  Quick.Logger.ExceptionHook,
  {$ENDIF}
  Quick.Logger.UnhandledExceptionHook;

type

  TQuickLogger = class(TInterfacedObject,ILogger)
  private
    fLogger : TLogger;
  public
    constructor Create;
    destructor Destroy; override;
    function Providers : TLogProviderList;
    procedure Init;
    procedure Info(const aMsg : string); overload;
    procedure Info(const aMsg : string; aValues : array of const); overload;
    procedure Succ(const aMsg : string); overload;
    procedure Succ(const aMsg : string; aParams : array of const); overload;
    procedure Done(const aMsg : string); overload;
    procedure Done(const aMsg : string; aValues : array of const); overload;
    procedure Warn(const aMsg : string); overload;
    procedure Warn(const aMsg : string; aValues : array of const); overload;
    procedure Error(const aMsg : string); overload;
    procedure Error(const aMsg : string; aValues : array of const); overload;
    procedure Critical(const aMsg : string); overload;
    procedure Critical(const aMsg : string; aValues : array of const); overload;
    procedure Trace(const aMsg : string); overload;
    procedure Trace(const aMsg : string; aValues : array of const); overload;
    procedure Debug(const aMsg : string); overload;
    procedure Debug(const aMsg : string; aValues : array of const); overload;
    procedure &Except(const aMsg : string; aValues : array of const); overload;
    procedure &Except(const aMsg, aException, aStackTrace : string); overload;
    procedure &Except(const aMsg : string; aValues: array of const; const aException, aStackTrace: string); overload;
  end;

  TLogSendLimit = class
  private
    fTimeRange : TSendLimitTimeRange;
    fLimitEventTypes : TLogLevel;
    fMaxSent: Integer;
  published
    property TimeRange : TSendLimitTimeRange read fTimeRange write fTimeRange;
    property LimitEventTypes : TLogLevel read fLimitEventTypes write fLimitEventTypes;
    property MaxSent : Integer read fMaxSent write fMaxSent;
  end;

  TJsonOutputOptions = class
  private
    fUseUTCTime : Boolean;
    fTimeStampName : string;
  published
    property UseUTCTime : Boolean read fUseUTCTime write fUseUTCTime;
    property TimeStampName : string read fTimeStampName write fTimeStampName;
  end;

  TEventType = Quick.Logger.TEventType;

  TLogLevel = Quick.Logger.TLogLevel;

  TLoggerOptions = class(TOptions)
  private
    fFormatSettings : TFormatSettings;
    fTimePrecission : Boolean;
    fMaxFailsToRestart : Integer;
    fMaxFailsToStop : Integer;
    fUsesQueue : Boolean;
    fEnvironment : string;
    fPlatformInfo : string;
    fSendLimits : TLogSendLimit;
    fLogLevel : TLogLevel;
    fIncludedInfo : TIncludedLogInfo;
    fEventTypeNames : TEventTypeNames;
    fCustomMsgOutput : Boolean;
    fEnabled : Boolean;
    fAppName: string;
  protected
    fOutputAsJson : Boolean;
    fJsonOutputOptions : TJsonOutputOptions;
  public
    constructor Create; override;
    destructor Destroy; override;
  published
    property MaxFailsToRestart : Integer read fMaxFailsToRestart write fMaxFailsToRestart;
    property MaxFailsToStop : Integer read fMaxFailsToStop write fMaxFailsToStop;
    property AppName : string read fAppName write fAppName;
    property Environment : string read fEnvironment write fEnvironment;
    property IncludedInfo : TIncludedLogInfo read fIncludedInfo write fIncludedInfo;
    property SendLimits : TLogSendLimit read fSendLimits write fSendLimits;
    property LogLevel : TLogLevel read fLogLevel write fLogLevel;
    property CustomMsgOutput : Boolean read fCustomMsgOutput write fCustomMsgOutput;
    property Enabled : Boolean read fEnabled write fEnabled;
  end;

  TLoggerOptionsProc<T : TLoggerOptions> = reference to procedure(aOptions : T);

  TConsoleLoggerOptions = class(TLoggerOptions)
  private
    fShowEventColors : Boolean;
    fShowTimeStamp : Boolean;
    fEventTypeColors : TEventTypeColors;
    fShowEventTypes : Boolean;
    fUnderlineHeaderEventType : Boolean;
  published
    property ShowEventColors : Boolean read fShowEventColors write fShowEventColors;
    property ShowTimeStamp : Boolean read fShowTimeStamp write fShowTimeStamp;
    property ShowEventType : Boolean read fShowEventTypes write fShowEventTypes;
    property UnderlineHeaderEventType : Boolean read fUnderlineHeaderEventType write fUnderlineHeaderEventType;
    //property EventTypeColor[cEventType : TEventType] : TConsoleColor read GetEventTypeColor write SetEventTypeColor;
  end;

  TFileLoggerOptions = class(TLoggerOptions)
  private
    fFileName : string;
    fMaxRotateFiles : Integer;
    fMaxFileSizeInMB : Integer;
    fDailyRotate : Boolean;
    fCompressRotatedFiles : Boolean;
    fRotatedFilesPath : string;
    fShowEventTypes : Boolean;
    fShowHeaderInfo : Boolean;
    fUnderlineHeaderEventType: Boolean;
    fAutoFlush : Boolean;
    fAutoFileName : Boolean;
  published
    property FileName : string read fFileName write fFileName;
    {$IFDEF MSWINDOWS}
    property AutoFileNameByProcess : Boolean read fAutoFileName write fAutoFileName;
    {$ENDIF}
    property MaxRotateFiles : Integer read fMaxRotateFiles write fMaxRotateFiles;
    property MaxFileSizeInMB : Integer read fMaxFileSizeInMB write fMaxFileSizeInMB;
    property DailyRotate : Boolean read fDailyRotate write fDailyRotate;
    property RotatedFilesPath : string read fRotatedFilesPath write fRotatedFilesPath;
    property CompressRotatedFiles : Boolean read fCompressRotatedFiles write fCompressRotatedFiles;
    property ShowEventType : Boolean read fShowEventTypes write fShowEventTypes;
    property ShowHeaderInfo : Boolean read fShowHeaderInfo write fShowHeaderInfo;
    property UnderlineHeaderEventType : Boolean read fUnderlineHeaderEventType write fUnderlineHeaderEventType;
    property AutoFlush : Boolean read fAutoFlush write fAutoFlush;
  end;

  TRedisLoggerOptions = class(TLoggerOptions)
  private
    fHost : string;
    fPort : Integer;
    fDataBase : Integer;
    fLogKey : string;
    fMaxSize : Int64;
    fPassword : string;
  published
    property Host : string read fHost write fHost;
    property Port : Integer read fPort write fPort;
    property DataBase : Integer read fDataBase write fDataBase;
    property LogKey : string read fLogKey write fLogKey;
    property MaxSize : Int64 read fMaxSize write fMaxSize;
    property Password : string read fPassword write fPassword;
    property OutputAsJson : Boolean read fOutputAsJson write fOutputAsJson;
    property JsonOutputOptions : TJsonOutputOptions read fJsonOutputOptions write fJsonOutputOptions;
  end;

  TRestLoggerOptions = class(TLoggerOptions)
  private
    fURL : string;
    fUserAgent : string;
  published
    property URL : string read fURL write fURL;
    property UserAgent : string read fUserAgent write fUserAgent;
    property JsonOutputOptions : TJsonOutputOptions read fJsonOutputOptions write fJsonOutputOptions;
  end;

  TEventLogLoggerOptions = class(TLoggerOptions)
  private
    fSource : string;
  published
    property Source : string read fSource write fSource;
  end;

  TTelegramLoggerOptions = class(TLoggerOptions)
  private
    fChannelName : string;
    fChannelType : TTelegramChannelType;
    fBotToken : string;
  published
    property ChannelName : string read fChannelName write fChannelName;
    property ChannelType : TTelegramChannelType read fChannelType write fChannelType;
    property BotToken : string read fBotToken write fBotToken;
  end;

  TSlackLoggerOptions = class(TLoggerOptions)
  private
    fChannelName : string;
    fUserName : string;
    fWebHookURL : string;
  published
    property ChannelName : string read fChannelName write fChannelName;
    property UserName : string read fUserName write fUserName;
    property WebHookURL : string read fWebHookURL write fWebHookURL;
  end;

  {$IFDEF MSWINDOWS}
  TADODBLoggerOptions = class(TLoggerOptions)
  private
    fConnectionString : string;
    fDBConfig : TDBConfig;
    //fFieldsMapping : TFieldsMapping;
  public
    constructor Create; override;
    destructor Destroy; override;
  published
    property ConnectionString : string read fConnectionString write fConnectionString;
    property DBConfig : TDBConfig read fDBConfig write fDBConfig;
    //property FieldsMapping : TFieldsMapping read fFieldsMapping write fFieldsMapping;
  end;
  {$ENDIF}

  ILoggerBuilder<T> = interface
  ['{0A3594B0-7CE7-405F-9DA6-6ECC4A557B81}']
    function MaxFailsToRestart(aNumFails : Integer) : T;
    function MaxFailsToStop(aNumFails : Integer) : T;
    function Environment(const aEnvironment : string) : T;
    function IncludedInfo(aInfo : TIncludedLogInfo) : T;
    function SendLimits(aLimits : TLogSendLimit) : T;
    function LogLevel(aLevel : TLogLevel) : T;
    function Enable : T;
  end;

  ILoggerConsoleBuilder = interface
  ['{705773EA-FFE2-4A93-AB54-AACC9AB96BE1}']
    function ShowEventColors(aValue : Boolean) : ILoggerConsoleBuilder;
    function ShowTimeStamp(aValue : Boolean) : ILoggerConsoleBuilder;
    function ShowEventType(aValue : Boolean) : ILoggerConsoleBuilder;
    function UnderlineHeaderEventType(aValue : Boolean) : ILoggerConsoleBuilder;
    function EventTypeColor(aEventType : TEventType; aColor : TConsoleColor) : ILoggerConsoleBuilder;
    function Build : TConsoleLoggerOptions;
  end;

  TLoggerConsoleBuilder = class(TOptionsBuilder<TConsoleLoggerOptions>,ILoggerConsoleBuilder)
  private
    function ShowEventColors(aValue : Boolean) : ILoggerConsoleBuilder;
    function ShowTimeStamp(aValue : Boolean) : ILoggerConsoleBuilder;
    function ShowEventType(aValue : Boolean) : ILoggerConsoleBuilder;
    function UnderlineHeaderEventType(aValue : Boolean) : ILoggerConsoleBuilder;
    function EventTypeColor(aEventType : TEventType; aColor : TConsoleColor) : ILoggerConsoleBuilder;
    function Build : TConsoleLoggerOptions;
  public
    class function GetBuilder : ILoggerConsoleBuilder;
  end;

  ILoggerBuilder = interface
  ['{4EF49E04-9C4E-47AD-88C6-6D65D5427741}']
    function AddConsole(aOptions : TConsoleLoggerOptions) : ILoggerBuilder; overload;
    function AddConsole(aConfigureProc : TLoggerOptionsProc<TConsoleLoggerOptions>) : ILoggerBuilder; overload;
    function AddFile(aConfigureProc: TLoggerOptionsProc<TFileLoggerOptions>) : ILoggerBuilder;
    function AddRedis(aConfigureProc : TLoggerOptionsProc<TRedisLoggerOptions>) : ILoggerBuilder;
    function AddRest(aOptions : TLoggerOptionsProc<TRestLoggerOptions>) : ILoggerBuilder;
    function AddTelegram(aConfigureProc: TLoggerOptionsProc<TTelegramLoggerOptions>): ILoggerBuilder;
    function AddSlack(aConfigureProc: TLoggerOptionsProc<TSlackLoggerOptions>): ILoggerBuilder;
    {$IFDEF MSWINDOWS}
    function AddEventLog(aConfigureProc: TLoggerOptionsProc<TEventLogLoggerOptions>): ILoggerBuilder;
    function AddADODB(aConfigureProc: TLoggerOptionsProc<TADODBLoggerOptions>): ILoggerBuilder;
    {$ENDIF}
    function Build : ILogger;
  end;

  TLoggerOptionsFormat = (ofJSON, ofYAML);

  TLoggerBuilder = class(TInterfacedObject,ILoggerBuilder)
  type
    TLoggerProviderFactory = class
      class function NewInstance(const aName : string) : TLogProviderBase;
    end;
  private
    fUseOptionsFile : Boolean;
    fOptionsFilename : string;
    fOptionContainer : TOptionsContainer;
    fCreateIfNotExists : Boolean;
    constructor Create; overload;
    constructor Create(aOptionsFormat : TLoggerOptionsFormat; aCreateConfigFileIfNotExists : Boolean = True; aOptionsFilename : string = ''); overload;
    procedure AddOptions(aOptionsFormat : TLoggerOptionsFormat);
    procedure AddOptionClass(const aName : string);
    procedure LoadConfig;
    procedure AddProvider(aProvider : TLogProviderBase);
    function GetEnvironment : string;
  protected
    fLogger : TQuickLogger;
    function AddConsole(aOptions : TConsoleLoggerOptions) : ILoggerBuilder; overload;
    function AddConsole(aConfigureProc : TLoggerOptionsProc<TConsoleLoggerOptions>) : ILoggerBuilder; overload;
    function AddFile(aConfigureProc: TLoggerOptionsProc<TFileLoggerOptions>): ILoggerBuilder;
    function AddRedis(aConfigureProc : TLoggerOptionsProc<TRedisLoggerOptions>) : ILoggerBuilder;
    function AddRest(aConfigureProc : TLoggerOptionsProc<TRestLoggerOptions>) : ILoggerBuilder;
    function AddTelegram(aConfigureProc: TLoggerOptionsProc<TTelegramLoggerOptions>): ILoggerBuilder;
    function AddSlack(aConfigureProc: TLoggerOptionsProc<TSlackLoggerOptions>): ILoggerBuilder;
    {$IFDEF MSWINDOWS}
    function AddEventLog(aConfigureProc: TLoggerOptionsProc<TEventLogLoggerOptions>): ILoggerBuilder;
    function AddADODB(aConfigureProc: TLoggerOptionsProc<TADODBLoggerOptions>): ILoggerBuilder;
    {$ENDIF}
    function Build : ILogger;
  public
    destructor Destroy; override;
    class function GetBuilder(aUseConfigFile : Boolean) : ILoggerBuilder; overload;
    class function GetBuilder(aOptionsFormat : TLoggerOptionsFormat = ofYAML; aCreateConfigFileIfNotExists : Boolean = True) : ILoggerBuilder; overload;
    class function GetBuilder(aOptionsFormat : TLoggerOptionsFormat; aCreateConfigFileIfNotExists : Boolean; aOptionsFilename : string) : ILoggerBuilder; overload;
  end;

  ELoggerConfigError = class(Exception);

const
  LOG_ONLYERRORS = [etHeader,etInfo,etError,etCritical,etException];
  LOG_ERRORSANDWARNINGS = [etHeader,etInfo,etWarning,etError,etCritical,etException];
  LOG_BASIC = [etInfo,etSuccess,etWarning,etError,etCritical,etException];
  LOG_ALL = [etHeader,etInfo,etSuccess,etDone,etWarning,etError,etCritical,etException,etCustom1,etCustom2];
  LOG_TRACE = [etHeader,etInfo,etSuccess,etDone,etWarning,etError,etCritical,etException,etTrace];
  LOG_DEBUG = [etHeader,etInfo,etSuccess,etDone,etWarning,etError,etCritical,etException,etTrace,etDebug];
  LOG_VERBOSE : TLogLevel = [Low(TEventType)..high(TEventType)];

implementation

{ TQuickLogger }

constructor TQuickLogger.Create;
begin
  fLogger := TLogger.Create;
  Init;
end;

destructor TQuickLogger.Destroy;
begin
  fLogger.Free;
  inherited;
end;

procedure TQuickLogger.Init;
begin
  //if IsDebug then GlobalLogConsoleProvider.LogLevel := LOG_DEBUG;
  //add default logger before load settings from file
  //Logger.Providers.Add(GlobalLogConsoleProvider);
  //GlobalLogConsoleProvider.Name := 'default';
  //GlobalLogConsoleProvider.Enabled := True;
end;

function TQuickLogger.Providers: TLogProviderList;
begin
  Result := fLogger.Providers;
end;

procedure TQuickLogger.Info(const aMsg: string);
begin
  fLogger.Info(aMsg);
end;

procedure TQuickLogger.Info(const aMsg: string; aValues: array of const);
begin
  fLogger.Info(aMsg,aValues);
end;

procedure TQuickLogger.Succ(const aMsg: string);
begin
  fLogger.Succ(aMsg);
end;

procedure TQuickLogger.Succ(const aMsg: string; aParams: array of const);
begin
  fLogger.Succ(aMsg,aParams);
end;

procedure TQuickLogger.Done(const aMsg: string);
begin
  fLogger.Done(aMsg);
end;

procedure TQuickLogger.Done(const aMsg: string; aValues: array of const);
begin
  fLogger.Done(aMsg,aValues);
end;

procedure TQuickLogger.Warn(const aMsg: string);
begin
  fLogger.Warn(aMsg);
end;

procedure TQuickLogger.Warn(const aMsg: string; aValues: array of const);
begin
  fLogger.Warn(aMsg,aValues);
end;

procedure TQuickLogger.Error(const aMsg: string);
begin
  fLogger.Error(aMsg);
end;

procedure TQuickLogger.Error(const aMsg: string; aValues: array of const);
begin
  fLogger.Error(aMsg,aValues);
end;

procedure TQuickLogger.Critical(const aMsg: string);
begin
  fLogger.Critical(aMsg);
end;

procedure TQuickLogger.Critical(const aMsg: string; aValues: array of const);
begin
  fLogger.Critical(aMsg,aValues);
end;

procedure TQuickLogger.Trace(const aMsg: string);
begin
  fLogger.Trace(aMsg);
end;

procedure TQuickLogger.Trace(const aMsg: string; aValues: array of const);
begin
  fLogger.Trace(aMsg,aValues);
end;

procedure TQuickLogger.Debug(const aMsg: string);
begin
  fLogger.Debug(aMsg);
end;

procedure TQuickLogger.Debug(const aMsg: string; aValues: array of const);
begin
  fLogger.Debug(aMsg,aValues);
end;

procedure TQuickLogger.&Except(const aMsg: string; aValues: array of const);
begin
  fLogger.&Except(aMsg,aValues);
end;

procedure TQuickLogger.&Except(const aMsg: string; aValues: array of const; const aException, aStackTrace: string);
begin
  fLogger.&Except(aMsg,aValues,aException,aStacktrace);
end;

procedure TQuickLogger.&Except(const aMsg, aException, aStackTrace: string);
begin
  fLogger.&Except(aMsg,aException,aStackTrace);
end;

{ TLoggerConsoleProviderBuilder }

class function TLoggerConsoleBuilder.GetBuilder: ILoggerConsoleBuilder;
begin
  Result := TLoggerConsoleBuilder.Create;
end;

function TLoggerConsoleBuilder.Build: TConsoleLoggerOptions;
begin
  Result := Self.Options;
end;

function TLoggerConsoleBuilder.EventTypeColor(aEventType: TEventType; aColor: TConsoleColor): ILoggerConsoleBuilder;
begin

end;

function TLoggerConsoleBuilder.ShowEventColors(aValue: Boolean): ILoggerConsoleBuilder;
begin

end;

function TLoggerConsoleBuilder.ShowEventType(aValue: Boolean): ILoggerConsoleBuilder;
begin

end;

function TLoggerConsoleBuilder.ShowTimeStamp(aValue: Boolean): ILoggerConsoleBuilder;
begin

end;

function TLoggerConsoleBuilder.UnderlineHeaderEventType(aValue: Boolean): ILoggerConsoleBuilder;
begin

end;

{ TLoggerBuilder }

constructor TLoggerBuilder.Create;
begin
  fOptionsFilename := '';
  fCreateIfNotExists := False;
  fUseOptionsFile := False;
  fLogger := TQuickLogger.Create;
end;

constructor TLoggerBuilder.Create(aOptionsFormat : TLoggerOptionsFormat; aCreateConfigFileIfNotExists : Boolean = True; aOptionsFilename : string = '');
begin
  fUseOptionsFile := True;
  fOptionsFilename := aOptionsFilename;
  fCreateIfNotExists := aCreateConfigFileIfNotExists;
  fLogger := TQuickLogger.Create;
  //load settings
  AddOptions(aOptionsFormat);
end;

destructor TLoggerBuilder.Destroy;
begin
  if Assigned(fOptionContainer) then fOptionContainer.Free;
  inherited;
end;

//builder without save to file
class function TLoggerBuilder.GetBuilder(aUseConfigFile : Boolean) : ILoggerBuilder;
begin
  if aUseConfigFile then Result := GetBuilder
    else Result := TLoggerBuilder.Create;
end;

class function TLoggerBuilder.GetBuilder(aOptionsFormat : TLoggerOptionsFormat = ofYAML; aCreateConfigFileIfNotExists : Boolean = True) : ILoggerBuilder;
begin
  Result := GetBuilder(aOptionsFormat,aCreateConfigFileIfNotExists,'');
end;

class function TLoggerBuilder.GetBuilder(aOptionsFormat: TLoggerOptionsFormat; aCreateConfigFileIfNotExists: Boolean; aOptionsFilename: string): ILoggerBuilder;
begin
  Result := TLoggerBuilder.Create(aOptionsFormat,aCreateConfigFileIfNotExists,aOptionsFilename);
end;

function TLoggerBuilder.GetEnvironment: string;
begin
  Result := GetEnvironmentVariable('CORE_ENVIRONMENT');
end;

procedure TLoggerBuilder.LoadConfig;
var
  oplogger : TLoggerOptions;
  i : Integer;
  logprovider : TLogProviderBase;
  iprovider : ILogProvider;
  sections : TArray<string>;
  sectionName : string;
begin
  if not fUseOptionsFile then Exit;

  for iprovider in fLogger.Providers do iprovider.Stop;
  fLogger.Providers.Clear;
  //get options in file
  if fOptionContainer.GetFileSectionNames(sections) then
  begin
    for sectionName in sections do
    begin
      AddOptionClass(sectionName);
    end;
  end;
  //load options
  fOptionContainer.Load;
  for i := 0 to fOptionContainer.Count - 1 do
  begin
    oplogger := fOptionContainer.Items[i] as TLoggerOptions;
    logprovider := TLoggerProviderFactory.NewInstance(oplogger.Name);
    TObjMapper.Map(oplogger,logprovider);
    fLogger.Providers.Add(logprovider);
    {$IFDEF DEBUG_LOGGING}
    TDebugger.Trace(Self,Format('Loaded Logger provider %s',[logprovider.Name]));
    {$ENDIF}
  end;
  {$IFDEF DEBUG_LOGGING}
    TDebugger.Trace(Self,Format('Loaded %d logger providers',[fLogger.Providers.Count]));
  {$ENDIF}
end;

procedure TLoggerBuilder.AddProvider(aProvider : TLogProviderBase);
begin
  fLogger.Providers.Add(aProvider);
  {$IFDEF DEBUG_LOGGING}
    TDebugger.Trace(Self,Format('Added Logger provider %s',[aProvider.Name]));
  {$ENDIF}
  //loggerConsole.Enabled := True;
end;

function TLoggerBuilder.AddConsole(aConfigureProc: TLoggerOptionsProc<TConsoleLoggerOptions>): ILoggerBuilder;
var
  options : TConsoleLoggerOptions;
  loggerConsole : TLogConsoleProvider;
begin
  Result := Self;
  if fUseOptionsFile then
  begin
    if (fOptionContainer.IsLoaded) and (fOptionContainer.ExistsSection(TConsoleLoggerOptions,'Console')) then Exit;

    options := fOptionContainer.AddSection(TConsoleLoggerOptions,'Console') as TConsoleLoggerOptions;
  end
  else options := TConsoleLoggerOptions.Create;

  loggerConsole := TLogConsoleProvider.Create;
  loggerConsole.Name := options.Name;
  TObjMapper.Map(loggerConsole,options);
  aConfigureProc(options);
  TObjMapper.Map(options,loggerConsole);
  AddProvider(loggerConsole);
  if not fUseOptionsFile then options.Free;
end;

function TLoggerBuilder.AddConsole(aOptions: TConsoleLoggerOptions): ILoggerBuilder;
begin
  fOptionContainer.AddOption(aOptions);
end;

function TLoggerBuilder.AddFile(aConfigureProc: TLoggerOptionsProc<TFileLoggerOptions>): ILoggerBuilder;
var
  options : TFileLoggerOptions;
  loggerFile : TLogFileProvider;
begin
  Result := Self;
  if fUseOptionsFile then
  begin
    if (fOptionContainer.IsLoaded) and (fOptionContainer.ExistsSection(TFileLoggerOptions,'File')) then Exit;

    options := fOptionContainer.AddSection(TFileLoggerOptions,'File') as TFileLoggerOptions;
  end
  else options := TFileLoggerOptions.Create;
  loggerFile := TLogFileProvider.Create;
  loggerFile.Name := options.Name;
  TObjMapper.Map(loggerFile,options);
  aConfigureProc(options);
  TObjMapper.Map(options,loggerFile);
  AddProvider(loggerFile);
  if not fUseOptionsFile then options.Free;
end;

function TLoggerBuilder.AddRedis(aConfigureProc: TLoggerOptionsProc<TRedisLoggerOptions>): ILoggerBuilder;
var
  options : TRedisLoggerOptions;
  loggerRedis : TLogRedisProvider;
begin
  Result := Self;
  if (fOptionContainer.IsLoaded) and (fOptionContainer.ExistsSection(TRedisLoggerOptions,'Redis')) then Exit;

  options := fOptionContainer.AddSection(TRedisLoggerOptions,'Redis') as TRedisLoggerOptions;
  loggerRedis := TLogRedisProvider.Create;
  loggerRedis.Name := options.Name;
  TObjMapper.Map(loggerRedis,options);
  aConfigureProc(options);
  TObjMapper.Map(options,loggerRedis);
  AddProvider(loggerRedis);
  if not fUseOptionsFile then options.Free;
end;

function TLoggerBuilder.AddRest(aConfigureProc: TLoggerOptionsProc<TRestLoggerOptions>): ILoggerBuilder;
var
  options : TRestLoggerOptions;
  loggerRest : TLogRestProvider;
begin
  Result := Self;
  if (fOptionContainer.IsLoaded) and (fOptionContainer.ExistsSection(TRestLoggerOptions,'Rest')) then Exit;

  options := fOptionContainer.AddSection(TRestLoggerOptions,'Rest') as TRestLoggerOptions;
  loggerRest := TLogRestProvider.Create;
  loggerRest.Name := options.Name;
  TObjMapper.Map(loggerRest,options);
  aConfigureProc(options);
  TObjMapper.Map(options,loggerRest);
  AddProvider(loggerRest);
  if not fUseOptionsFile then options.Free;
end;

{$IFDEF MSWINDOWS}
function TLoggerBuilder.AddEventLog(aConfigureProc: TLoggerOptionsProc<TEventLogLoggerOptions>): ILoggerBuilder;
var
  options : TEventLogLoggerOptions;
  loggerEventLog : TLogEventLogProvider;
begin
  Result := Self;
  if (fOptionContainer.IsLoaded) and (fOptionContainer.ExistsSection(TEventLogLoggerOptions,'EventLog')) then Exit;

  options := fOptionContainer.AddSection(TEventLogLoggerOptions,'EventLog') as TEventLogLoggerOptions;
  loggerEventLog := TLogEventLogProvider.Create;
  loggerEventLog.Name := options.Name;
  TObjMapper.Map(loggerEventLog,options);
  aConfigureProc(options);
  TObjMapper.Map(options,loggerEventLog);
  AddProvider(loggerEventLog);
  if not fUseOptionsFile then options.Free;
end;
{$ENDIF}

function TLoggerBuilder.AddTelegram(aConfigureProc: TLoggerOptionsProc<TTelegramLoggerOptions>): ILoggerBuilder;
var
  options : TTelegramLoggerOptions;
  loggerTelegram : TLogTelegramProvider;
begin
  Result := Self;
  if (fOptionContainer.IsLoaded) and (fOptionContainer.ExistsSection(TTelegramLoggerOptions,'Telegram')) then Exit;

  options := fOptionContainer.AddSection(TTelegramLoggerOptions,'Telegram') as TTelegramLoggerOptions;
  loggerTelegram := TLogTelegramProvider.Create;
  loggerTelegram.Name := options.Name;
  TObjMapper.Map(loggerTelegram,options);
  aConfigureProc(options);
  TObjMapper.Map(options,loggerTelegram);
  AddProvider(loggerTelegram);
  if not fUseOptionsFile then options.Free;
end;

function TLoggerBuilder.AddSlack(aConfigureProc: TLoggerOptionsProc<TSlackLoggerOptions>): ILoggerBuilder;
var
  options : TSlackLoggerOptions;
  loggerSlack : TLogSlackProvider;
begin
  Result := Self;
  if (fOptionContainer.IsLoaded) and (fOptionContainer.ExistsSection(TSlackLoggerOptions,'Slack')) then Exit;

  options := fOptionContainer.AddSection(TSlackLoggerOptions,'Slack') as TSlackLoggerOptions;
  loggerSlack := TLogSlackProvider.Create;
  loggerSlack.Name := options.Name;
  TObjMapper.Map(loggerSlack,options);
  aConfigureProc(options);
  TObjMapper.Map(options,loggerSlack);
  AddProvider(loggerSlack);
  if not fUseOptionsFile then options.Free;
end;

{$IFDEF MSWINDOWS}
function TLoggerBuilder.AddADODB(aConfigureProc: TLoggerOptionsProc<TADODBLoggerOptions>): ILoggerBuilder;
var
  options : TADODBLoggerOptions;
  loggerADODB : TLogADODBProvider;
begin
  Result := Self;
  if (fOptionContainer.IsLoaded) and (fOptionContainer.ExistsSection(TADODBLoggerOptions,'ADODB')) then Exit;

  options := fOptionContainer.AddSection(TADODBLoggerOptions,'ADODB') as TADODBLoggerOptions;
  loggerADODB := TLogADODBProvider.Create;
  loggerADODB.Name := options.Name;
  TObjMapper.Map(loggerADODB,options);
  aConfigureProc(options);
  TObjMapper.Map(options,loggerADODB);
  AddProvider(loggerADODB);
  if not fUseOptionsFile then options.Free;
end;
{$ENDIF}

procedure TLoggerBuilder.AddOptionClass(const aName: string);
var
  provname : string;
begin
  provname := aName.ToLower;
  if provname = 'console' then fOptionContainer.AddSection<TConsoleLoggerOptions>('Console')
  else if provname = 'file' then fOptionContainer.AddSection<TFileLoggerOptions>('File')
  else if provname = 'redis' then fOptionContainer.AddSection<TRedisLoggerOptions>('Redis')
  else if provname = 'rest' then fOptionContainer.AddSection<TRestLoggerOptions>('Rest')
  else if provname = 'telegram' then fOptionContainer.AddSection<TTelegramLoggerOptions>('Telegram')
  else if provname = 'slack' then fOptionContainer.AddSection<TSlackLoggerOptions>('Slack')
  {$IFDEF MSWINDOWS}
  else if provname = 'eventlog' then fOptionContainer.AddSection<TEventLogLoggerOptions>('EventLog')
  else if provname = 'adodb' then fOptionContainer.AddSection<TADODBLoggerOptions>('ADODB')
  {$ENDIF}
  else raise Exception.CreateFmt('Logger provider "%S" is not a valid provider!',[aName]);
end;

procedure TLoggerBuilder.AddOptions(aOptionsFormat : TLoggerOptionsFormat);
var
  filename : string;
  iserializer : IOptionsSerializer;
  environment : string;
  opfilename : string;
begin
  environment := GetEnvironment;
  if not environment.IsEmpty then environment := '.' + environment;

  if fOptionsFilename.IsEmpty then opfilename := 'QuickLogger'
    else opfilename := fOptionsFilename;

  if aOptionsFormat = TLoggerOptionsFormat.ofJSON then
  begin
      filename := path.EXEPATH + PathDelim + opfilename + environment + '.json';
    iserializer := TJsonOptionsSerializer.Create;
  end
  else if aOptionsFormat = TLoggerOptionsFormat.ofYAML then
  begin
    filename := path.EXEPATH + PathDelim + opfilename + environment + '.yml';
    iserializer := TYamlOptionsSerializer.Create;
  end
  else raise ELoggerConfigError.Create('Logger Options Serializer not recognized!');

  fOptionContainer := TOptionsContainer.Create(filename,iserializer,False);
  if FileExists(filename) then
  begin
    {$IFDEF DEBUG_LOGGING}
    TDebugger.Trace(Self,Format('Loading Logger settings from "%s"',[filename]));
    {$ENDIF}
    //load config
    LoadConfig;
  end
  else
  begin
    {$IFDEF DEBUG_LOGGING}
    TDebugger.Trace(Self,Format('Autocreate Logger settings "%s"',[filename]));
    {$ENDIF}
  end;
end;

function TLoggerBuilder.Build: ILogger;
begin
  Result := fLogger;
  if fCreateIfNotExists then fOptionContainer.Save;
end;

{ TLoggerProviderOptions }

constructor TLoggerOptions.Create;
begin
  inherited Create;
  fFormatSettings.DateSeparator := '/';
  fFormatSettings.TimeSeparator := ':';
  fFormatSettings.ShortDateFormat := 'DD-MM-YYY HH:NN:SS';
  fFormatSettings.ShortTimeFormat := 'HH:NN:SS';
  fTimePrecission := False;
  fSendLimits := TLogSendLimit.Create;
  fAppName := GetAppName;
  fMaxFailsToRestart := 2;
  fMaxFailsToStop := 0;
  fEnabled := False;
  fUsesQueue := True;
  fEventTypeNames := DEF_EVENTTYPENAMES;
  fEnvironment := '';
  fPlatformInfo := '';
  fIncludedInfo := [iiAppName,iiHost];
  fJsonOutputOptions := TJsonOutputOptions.Create;
  fJsonOutputOptions.UseUTCTime := False;
  fJsonOutputOptions.TimeStampName := 'timestamp';
end;

destructor TLoggerOptions.Destroy;
begin
  fSendLimits.Free;
  fJsonOutputOptions.Free;
  inherited;
end;

{ TLoggerBuilder.TLoggerProviderFactory }

class function TLoggerBuilder.TLoggerProviderFactory.NewInstance(const aName: string): TLogProviderBase;
var
  provname : string;
begin
  provname := aName.ToLower;
  if provname = 'console' then Result := TLogConsoleProvider.Create
  else if provname = 'file' then Result := TLogFileProvider.Create
  else if provname = 'redis' then Result := TLogRedisProvider.Create
  else if provname = 'rest' then Result := TLogRestProvider.Create
  else if provname = 'telegram' then Result := TLogTelegramProvider.Create
  else if provname = 'slack' then Result := TLogSlackProvider.Create
  {$IFDEF MSWINDOWS}
  else if provname = 'eventlog' then Result := TLogEventLogProvider.Create
  else if provname = 'adodb' then Result := TLogADODBProvider.Create
  {$ENDIF}
  else raise Exception.CreateFmt('Logger provider "%S" is not a valid provider!',[aName]);
end;

{ TADODBLoggerOptions }

{$IFDEF MSWINDOWS}
constructor TADODBLoggerOptions.Create;
begin
  inherited;
  fDBConfig := TDBConfig.Create;
end;

destructor TADODBLoggerOptions.Destroy;
begin
  fDBConfig.Free;
  inherited;
end;
{$ENDIF}

end.

