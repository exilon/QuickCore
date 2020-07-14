{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Security.Authentication
  Description : Core Security Authentication
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 10/03/2020
  Modified    : 14/04/2020

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

unit Quick.Core.Security.Authentication;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.TypInfo,
  System.Generics.Collections,
  Quick.Options,
  Quick.Collections,
  Quick.Core.Logging.Abstractions,
  Quick.HttpServer.Request,
  Quick.HttpServer.Response,
  Quick.Core.Mvc.Context,
  Quick.Core.Security.Claims,
  Quick.Core.Identity;

type
  TAuthenticationProperties = class
  private const
    IssuedUtcKey = '.issued';
    ExpiresUtcKey = '.expires';
    IsPersistentKey = '.persistent';
    RedirectUriKey = '.redirect';
    RefreshKey = '.refresh';
    UtcDateTimeFormat = 'r';
  private
    fItems : TDictionary<string,string>;
    fParameters : TDictionary<string,TObject>;
    function GetAllowRefresh: Boolean;
    function GetExpiresUtc: Boolean;
    function GetIsPersistent: Boolean;
    function GetIssuedUtc: Boolean;
    function GetRedirectUri: Boolean;
    procedure SetAllowRefresh(const aValue: Boolean);
    procedure SetExpiresUtc(const aValue: Boolean);
    procedure SetIssuedUtc(const aValue: Boolean);
    procedure SetRedirectUri(const aValue: Boolean);
    procedure SetIsPersistent(const aValue: Boolean);
  public
    constructor Create;
    destructor Destroy; override;
    property AllowRefresh : Boolean read GetAllowRefresh write SetAllowRefresh;
    property ExpiresUtc : Boolean read GetExpiresUtc write SetExpiresUtc;
    property IsPersistent : Boolean read GetIsPersistent write SetIsPersistent;
    property IssuedUtc : Boolean read GetIssuedUtc write SetIssuedUtc;
    property Items : TDictionary<string,string> read fItems;
    property Parameters : TDictionary<string,TObject> read fParameters;
    property RedirectUri : Boolean read GetRedirectUri write SetRedirectUri;
    function GetString(const aKey : string) : string;
    function GetBool(const aKey : string) : Boolean;
    procedure SetString(const aKey, aValue : string);
    procedure SetBool(const aKey : string; aValue : Boolean);
    function GetParameter<T : class>(const aKey : string) : T;
    procedure SetParamter<T : class>(const aKey : string; aValue : T);
  end;

  IAuthenticationTicket = interface
  ['{767D0C6F-5A4B-4DC9-B19C-FC35D2BE2C1E}']
    function GetAuthenticationScheme: string;
    function GetPrincipal: TClaimsPrincipal;
    function GetProperties: TAuthenticationProperties;
    property Principal : TClaimsPrincipal read GetPrincipal;
    property Properties : TAuthenticationProperties read GetProperties;
    property AuthenticationScheme : string read GetAuthenticationScheme;
  end;

  TAuthenticationTicket = class(TInterfacedObject,IAuthenticationTicket)
  private
    fPrincipal : TClaimsPrincipal;
    fAuthenticationScheme : string;
    fProperties : TAuthenticationProperties;
    function GetAuthenticationScheme: string;
    function GetPrincipal: TClaimsPrincipal;
    function GetProperties: TAuthenticationProperties;
  public
    constructor Create(aPrincipal : TClaimsPrincipal; const aScheme : string); overload;
    constructor Create(aPrincipal : TClaimsPrincipal; aProperties : TAuthenticationProperties; const aScheme : string); overload;
    property Principal : TClaimsPrincipal read GetPrincipal;
    property Properties : TAuthenticationProperties read GetProperties;
    property AuthenticationScheme : string read GetAuthenticationScheme;
  end;

  TAuthenticateResult = record
  private
    fFailure : Exception;
    fTicket : IAuthenticationTicket;
    fAuthenticationProperties : TAuthenticationProperties;
    function GetPrincipal : TClaimsPrincipal;
    function GetSucceeded: Boolean;
  public
    property Principal : TClaimsPrincipal read GetPrincipal;
    property Properties : TAuthenticationProperties read fAuthenticationProperties write fAuthenticationProperties;
    property Ticket : IAuthenticationTicket read fTicket write fTicket;
    property Succeeded : Boolean read GetSucceeded;
    function Fail(aException : Exception) : TAuthenticateResult;
    function Success(aTicket : IAuthenticationTicket) : TAuthenticateResult;
    function NoResult : TAuthenticateResult;
  end;

  TAuthenticationScheme = class;

  IAuthenticationHandler = interface
  ['{EABCA94E-9A35-4F6C-A501-6FF0B5DE6E7E}']
    procedure Initialize(aScheme : TAuthenticationScheme; aContext : THttpContextBase);
    function Authenticate : TAuthenticateResult;
    procedure Challenge(aProperties : TAuthenticationProperties);
    procedure Forbid(aProperties : TAuthenticationProperties);
  end;

  IAuthenticationSignInHandler = interface
  ['{0E8F21AD-197C-46FA-A153-30936BE106FC}']
    procedure SignIn(aPrincipal : TClaimsPrincipal; aProperties : TAuthenticationProperties);
  end;

  IAuthenticationSignOutHandler = interface
  ['{2660316C-5071-4DD2-83CE-AEEE81A64934}']
    procedure SignOut(aProperties : TAuthenticationProperties);
  end;

  TAuthenticationScheme = class
  private
    fName : string;
    fHandlerType : PTypeInfo;
  public
    constructor Create(const aName : string; aHandlerType : PTypeInfo);
    property Name : string read fName write fName;
    property HandlerType : PTypeInfo read fHandlerType write fHandlerType;
    function Clone : TAuthenticationScheme;
  end;

  TAuthenticationHandler<T : TOptions> = class(TInterfacedObject,IAuthenticationHandler)
  protected
    fOptions : T;
    fScheme : TAuthenticationScheme;
    fContext : THttpContextBase;
    fRequest : IHttpRequest;
    fResponse : IHttpResponse;
    fLogger : ILogger;
    procedure DoInitialize; virtual; abstract;
  public
    constructor Create(aOptions : IOptions<T>; aLogger : ILogger);
    property Scheme : TAuthenticationScheme read fScheme;
    property Context : THttpContextBase read fContext write fContext;
    property Request : IHttpRequest read fRequest write fRequest;
    property Response : IHttpResponse read fResponse write fResponse;
    procedure Initialize(aScheme : TAuthenticationScheme; aContext : THttpContextBase); virtual;
    function Authenticate : TAuthenticateResult; virtual; abstract;
    procedure Challenge(aProperties : TAuthenticationProperties); virtual;
    procedure Forbid(aProperties : TAuthenticationProperties); virtual;
  end;

  TAuthenticationOptions = class(TOptions)
  private
    fSchemes : TObjectList<TAuthenticationScheme>;
    fSchemeMap : TDictionary<string,TAuthenticationScheme>;
    fDefaultAuthenticateScheme : string;
    fDefaultChallengeScheme : string;
    fDefaultForbidScheme : string;
    fDefaultSignInScheme : string;
    fDefaultSignOutScheme : string;
    fRequireAuthenticatedSignIn : Boolean;
  public
    constructor Create; override;
    destructor Destroy; override;
    property SchemeMap : TDictionary<string,TAuthenticationScheme> read fSchemeMap;
    property Schemes : TObjectList<TAuthenticationScheme> read fSchemes;
    procedure AddScheme(const aName : string; aScheme : TAuthenticationScheme); overload;
    procedure AddScheme(const aName : string; aHandlerType : PTypeInfo); overload;
  published
    property DefaultAuthenticateScheme : string read fDefaultAuthenticateScheme write fDefaultAuthenticateScheme;
    property DefaultChallengeScheme : string read fDefaultChallengeScheme write fDefaultChallengeScheme;
    property DefaultForbidScheme : string read fDefaultForbidScheme write fDefaultForbidScheme;
    property DefaultSignInScheme : string read fDefaultSignInScheme write fDefaultSignInScheme;
    property DefaultSignOutScheme : string read fDefaultSignOutScheme write fDefaultSignOutScheme;
    property RequireAuthenticatedSignIn : Boolean read fRequireAuthenticatedSignIn write fRequireAuthenticatedSignIn;
  end;

  IAuthenticationSchemeProvider = interface
  ['{13427B0A-354C-4BA1-80A3-76348C3A2DB6}']
    function GetAllSchemes : IList<TAuthenticationScheme>;
    function GetScheme(const aName : string) : TAuthenticationScheme;
    procedure RemoveScheme(const aName : string);
    function GetDefaultAuthenticateScheme : TAuthenticationScheme;
    function GetDefaultChallengeScheme : TAuthenticationScheme;
    function GetDefaultForbidScheme : TAuthenticationScheme;
    function GetDefaultSignInScheme : TAuthenticationScheme;
    function GetDefaultSignOutScheme : TAuthenticationScheme;
  end;

  TAuthenticationSchemeProvider = class(TInterfacedObject,IAuthenticationSchemeProvider)
  private
    fSchemes : TDictionary<string,TAuthenticationScheme>;
    fOptions : TAuthenticationOptions;
  public
    constructor Create(aOptions : IOptions<TAuthenticationOptions>);
    destructor Destroy; override;
    procedure AddScheme(aScheme : TAuthenticationScheme);
    function GetAllSchemes : IList<TAuthenticationScheme>;
    function GetScheme(const aName : string) : TAuthenticationScheme;
    procedure RemoveScheme(const aName : string);
    function GetDefaultAuthenticateScheme : TAuthenticationScheme;
    function GetDefaultChallengeScheme : TAuthenticationScheme;
    function GetDefaultForbidScheme : TAuthenticationScheme;
    function GetDefaultSignInScheme : TAuthenticationScheme;
    function GetDefaultSignOutScheme : TAuthenticationScheme;
  end;

  IAuthenticationHandlerProvider = interface
  ['{EE81A33B-9738-4A3E-B8B1-29AAA27B3F51}']
    function GetHandler(aContext : THttpContextBase; const aAuthenticationScheme : string) : IAuthenticationHandler;
  end;

  TAuthenticationHandlerProvider = class(TInterfacedObject,IAuthenticationHandlerProvider)
  private
    fSchemes : IAuthenticationSchemeProvider;
    //fHandlerMap : TObjectDictionary<string,IAuthenticationHandler>;   s
  public
    constructor Create(aSchemes : IAuthenticationSchemeProvider);
    destructor Destroy; override;
    property Schemes : IAuthenticationSchemeProvider read fSchemes;
    function GetHandler(aContext : THttpContextBase; const aAuthenticationScheme : string) : IAuthenticationHandler;
  end;

  IAuthenticationService = interface
  ['{A47B8468-D83A-45D5-9E32-D377877296CF}']
    function Authenticate(aContext : THttpContextBase; const aScheme : string) : TAuthenticateResult;
    function Challenge(aContext : THttpContextBase; const aScheme : string;  aProperties : TAuthenticationProperties) : TAuthenticateResult;
    function Forbid(aContext : THttpContextBase; const aScheme : string;  aProperties : TAuthenticationProperties) : TAuthenticateResult;
    function SignIn(aContext : THttpContextBase; const aScheme : string; aPrincipal : TClaimsPrincipal; aProperties : TAuthenticationProperties) : TAuthenticateResult;
    function SignOut(aContext : THttpContextBase; const aScheme : string; aProperties : TAuthenticationProperties) : TAuthenticateResult;
  end;

  TAuthenticationService = class(TInterfacedObject,IAuthenticationService)
  private
    fSchemes : IAuthenticationSchemeProvider;
    fHandlers : IAuthenticationHandlerProvider;
    fOptions : TAuthenticationOptions;
    fProperties : TAuthenticationProperties;
  public
    constructor Create(aSchemes : IAuthenticationSchemeProvider; aHandlers : IAuthenticationHandlerProvider; aOptions : IOptions<TAuthenticationOptions>);
    function Authenticate(aContext : THttpContextBase; const aScheme : string) : TAuthenticateResult;
    function Challenge(aContext : THttpContextBase; const aScheme : string;  aProperties : TAuthenticationProperties) : TAuthenticateResult;
    function Forbid(aContext : THttpContextBase; const aScheme : string;  aProperties : TAuthenticationProperties) : TAuthenticateResult;
    function SignIn(aContext : THttpContextBase; const aScheme : string; aPrincipal : TClaimsPrincipal; aProperties : TAuthenticationProperties) : TAuthenticateResult;
    function SignOut(aContext : THttpContextBase; const aScheme : string; aProperties : TAuthenticationProperties) : TAuthenticateResult;
  end;

  EAuthenticacionScheme = class(Exception);
  EAuthenticationProperty = class(Exception);
  EAuthenticationHandler = class(Exception);

implementation


{ TAuthenticateResult }

function TAuthenticateResult.Fail(aException: Exception): TAuthenticateResult;
begin
  fTicket := nil;
  fFailure := aException;
  Result := Self;
end;

function TAuthenticateResult.GetPrincipal: TClaimsPrincipal;
begin
  Result := nil;
  if fTicket <> nil then Result := fTicket.Principal;
end;

function TAuthenticateResult.GetSucceeded: Boolean;
begin
  Result := fTicket <> nil;
end;

function TAuthenticateResult.NoResult: TAuthenticateResult;
begin
  fTicket := nil;
  Result := Self;
end;

function TAuthenticateResult.Success(aTicket : IAuthenticationTicket) : TAuthenticateResult;
begin
  fTicket := aTicket;
  Result := Self;
end;

{ TAuthenticationTicket }

constructor TAuthenticationTicket.Create(aPrincipal: TClaimsPrincipal; const aScheme: string);
begin
  if aPrincipal = nil then raise EArgumentNilException.Create('ClaimsPrinpical cannot be null');
  fPrincipal := aPrincipal;
  fAuthenticationScheme := aScheme;
end;

constructor TAuthenticationTicket.Create(aPrincipal: TClaimsPrincipal; aProperties: TAuthenticationProperties; const aScheme: string);
begin
  Create(aPrincipal,aScheme);
  if aProperties <> nil then fProperties := aProperties
    else fProperties := TAuthenticationProperties.Create;
end;

function TAuthenticationTicket.GetAuthenticationScheme: string;
begin
  Result := fAuthenticationScheme;
end;

function TAuthenticationTicket.GetPrincipal: TClaimsPrincipal;
begin
  Result := fPrincipal;
end;

function TAuthenticationTicket.GetProperties: TAuthenticationProperties;
begin
  Result := fProperties;
end;

{ TAuthenticationScheme }

function TAuthenticationScheme.Clone: TAuthenticationScheme;
begin
  Result := TAuthenticationScheme.Create(Self.Name,Self.HandlerType);
end;

constructor TAuthenticationScheme.Create(const aName: string; aHandlerType: PTypeInfo);
begin
  fName := aName;
  fHandlerType := aHandlerType;
end;

{ TAuthenticationSchemeProvider }

constructor TAuthenticationSchemeProvider.Create(aOptions: IOptions<TAuthenticationOptions>);
var
  scheme : TAuthenticationScheme;
begin
  fOptions := aOptions.Value;
  fSchemes := TObjectDictionary<string,TAuthenticationScheme>.Create([doOwnsValues]);
  for scheme in fOptions.Schemes do
  begin
    fSchemes.Add(scheme.Name,scheme.Clone);
  end;
end;

destructor TAuthenticationSchemeProvider.Destroy;
begin
  fSchemes.Free;
  inherited;
end;

procedure TAuthenticationSchemeProvider.AddScheme(aScheme: TAuthenticationScheme);
begin
  fSchemes.Add(aScheme.Name,aScheme);
end;

function TAuthenticationSchemeProvider.GetAllSchemes: IList<TAuthenticationScheme>;
var
  pair : TPair<string,TAuthenticationScheme>;
begin
  Result := TXList<TAuthenticationScheme>.Create;
  for pair in fSchemes do Result.Add(pair.Value);
end;

function TAuthenticationSchemeProvider.GetDefaultAuthenticateScheme: TAuthenticationScheme;
begin
  if not fSchemes.TryGetValue(fOptions.DefaultAuthenticateScheme,Result) then EAuthenticacionScheme.Create('Not Default Authenticate Scheme defined!');
end;

function TAuthenticationSchemeProvider.GetDefaultChallengeScheme: TAuthenticationScheme;
begin
  if not fSchemes.TryGetValue(fOptions.DefaultChallengeScheme,Result) then EAuthenticacionScheme.Create('Not Default Challenge Scheme defined!');
end;

function TAuthenticationSchemeProvider.GetDefaultForbidScheme: TAuthenticationScheme;
begin
  if not fSchemes.TryGetValue(fOptions.DefaultForbidScheme,Result) then EAuthenticacionScheme.Create('Not Default Forbid Scheme defined!');
end;

function TAuthenticationSchemeProvider.GetDefaultSignInScheme: TAuthenticationScheme;
begin
  if not fSchemes.TryGetValue(fOptions.DefaultSignInScheme,Result) then EAuthenticacionScheme.Create('Not Default SignIn Scheme defined!');
end;

function TAuthenticationSchemeProvider.GetDefaultSignOutScheme: TAuthenticationScheme;
begin
  if not fSchemes.TryGetValue(fOptions.DefaultSignOutScheme,Result) then EAuthenticacionScheme.Create('Not Default SignOut Scheme defined!');
end;

function TAuthenticationSchemeProvider.GetScheme(const aName: string): TAuthenticationScheme;
begin
  if not fSchemes.TryGetValue(aName,Result) then EAuthenticacionScheme.CreateFmt('Authentication Scheme "%s" not supported!',[aName]);
end;

procedure TAuthenticationSchemeProvider.RemoveScheme(const aName: string);
begin
  fSchemes.Remove(aName);
end;

{ TAuthenticationService }

constructor TAuthenticationService.Create(aSchemes: IAuthenticationSchemeProvider; aHandlers: IAuthenticationHandlerProvider; aOptions: IOptions<TAuthenticationOptions>);
begin
  fSchemes := aSchemes;
  fHandlers := aHandlers;
  fOptions := aOptions.Value;
end;

function TAuthenticationService.Authenticate(aContext: THttpContextBase; const aScheme: string): TAuthenticateResult;
var
  scheme : string;
  handler : IAuthenticationHandler;
begin
  //get default scheme if passed as empty
  if aScheme.IsEmpty then scheme := fSchemes.GetDefaultAuthenticateScheme.Name
    else scheme := aScheme;

  handler := fHandlers.GetHandler(aContext,scheme);
  if handler = nil then raise EAuthenticationHandler.CreateFmt('Authentication handler for "%s" Authenticate scheme not found!',[scheme]);

  Result := handler.Authenticate;
  if Result.Succeeded then
  begin
    Result.Success(TAuthenticationTicket.Create(Result.Principal,Result.Properties,Result.Ticket.AuthenticationScheme));
  end;
end;

function TAuthenticationService.Challenge(aContext: THttpContextBase; const aScheme: string; aProperties: TAuthenticationProperties): TAuthenticateResult;
var
  scheme : string;
  handler : IAuthenticationHandler;
begin
  //get default scheme if passed as empty
  if aScheme.IsEmpty then scheme := fSchemes.GetDefaultChallengeScheme.Name
    else scheme := aScheme;

  handler := fHandlers.GetHandler(aContext,scheme);
  if handler = nil then raise EAuthenticationHandler.CreateFmt('Authentication handler for "%s" Challenge scheme not found!',[scheme]);

  handler.Challenge(fProperties);
end;

function TAuthenticationService.Forbid(aContext: THttpContextBase; const aScheme: string; aProperties: TAuthenticationProperties): TAuthenticateResult;
var
  scheme : string;
  handler : IAuthenticationHandler;
begin
  //get default scheme if passed as empty
  if aScheme.IsEmpty then scheme := fSchemes.GetDefaultForbidScheme.Name
    else scheme := aScheme;

  handler := fHandlers.GetHandler(aContext,scheme);
  if handler = nil then raise EAuthenticationHandler.CreateFmt('Authentication handler for "%s" Forbid scheme not found!',[scheme]);

  handler.Forbid(fProperties);
end;

function TAuthenticationService.SignIn(aContext: THttpContextBase; const aScheme: string; aPrincipal: TClaimsPrincipal; aProperties: TAuthenticationProperties): TAuthenticateResult;
var
  scheme : string;
  handler : IAuthenticationHandler;
  signInHandler : IAuthenticationSignInHandler;
begin
  if aPrincipal = nil then raise EArgumentNilException.Create('Principal');

  if fOptions.RequireAuthenticatedSignIn then
  begin
    if aPrincipal.Identity = nil then raise EInvalidOpException.Create('SignIn not allowed if AuthenticationOptions.RequiredSignIn and Principal.Identity is null');
    if not aPrincipal.Identity.IsAuthenticated then raise EInvalidOpException.Create('SignIn not allowed if AuthenticationOptions.RequiredSignIn and Pricipal.Identity.IsAuthenticated is False');
  end;

  //get default scheme if passed as empty
  if aScheme.IsEmpty then scheme := fSchemes.GetDefaultSignInScheme.Name
    else scheme := aScheme;

  handler := fHandlers.GetHandler(aContext,scheme);
  if handler = nil then raise EAuthenticationHandler.CreateFmt('Authentication handler for "%s" SignIn scheme not found!',[scheme]);

  handler.Forbid(fProperties);


  signInHandler := handler as IAuthenticationSignInHandler;
  if signInHandler = nil then raise EAuthenticationHandler.CreateFmt('Authentication SignInhandler for "%s" SignIn scheme not found!',[scheme]);

  signInHandler.SignIn(aPrincipal,aProperties);
end;

function TAuthenticationService.SignOut(aContext: THttpContextBase; const aScheme: string; aProperties: TAuthenticationProperties): TAuthenticateResult;
var
  scheme : string;
  handler : IAuthenticationHandler;
  signOutHandler : IAuthenticationSignOutHandler;
begin
  //get default scheme if passed as empty
  if aScheme.IsEmpty then scheme := fSchemes.GetDefaultSignOutScheme.Name
    else scheme := aScheme;

  handler := fHandlers.GetHandler(aContext,scheme);
  if handler = nil then raise EAuthenticationHandler.CreateFmt('Authentication handler for "%s" SignOut scheme not found!',[scheme]);

  handler.Forbid(fProperties);


  signOutHandler := handler as IAuthenticationSignOutHandler;
  if signOutHandler = nil then raise EAuthenticationHandler.CreateFmt('Authentication SignOuthandler for "%s" SignOut scheme not found!',[scheme]);

  signOutHandler.SignOut(aProperties);
end;

{ TAuthenticationProperties }

constructor TAuthenticationProperties.Create;
begin
  fItems := TDictionary<string,string>.Create;
  fParameters := TDictionary<string,TObject>.Create;
end;

destructor TAuthenticationProperties.Destroy;
begin
  fItems.Free;
  fParameters.Free;
  inherited;
end;

function TAuthenticationProperties.GetAllowRefresh: Boolean;
var
  value : string;
begin
  if fItems.TryGetValue(RefreshKey,value) then Result := value.ToBoolean
    else Result := False;
end;

function TAuthenticationProperties.GetBool(const aKey: string): Boolean;
var
  value : string;
begin
  if fItems.TryGetValue(aKey,value) then Result := value.ToBoolean
    else Result := False;
end;

function TAuthenticationProperties.GetExpiresUtc: Boolean;
var
  value : string;
begin
  if fItems.TryGetValue(ExpiresUtcKey,value) then Result := value.ToBoolean
    else Result := False;
end;

function TAuthenticationProperties.GetIsPersistent: Boolean;
var
  value : string;
begin
  if fItems.TryGetValue(IsPersistentKey,value) then Result := value.ToBoolean
    else Result := False;
end;

function TAuthenticationProperties.GetIssuedUtc: Boolean;
var
  value : string;
begin
  if fItems.TryGetValue(IssuedUtcKey,value) then Result := value.ToBoolean
    else Result := False;
end;

function TAuthenticationProperties.GetParameter<T>(const aKey: string): T;
var
  value : TObject;
begin
  if fParameters.TryGetValue(IssuedUtcKey,value) then Result := value as T
    else Result := nil;
end;

function TAuthenticationProperties.GetRedirectUri: Boolean;
var
  value : string;
begin
  if fItems.TryGetValue(RedirectUriKey,value) then Result := value.ToBoolean
    else Result := False;
end;

function TAuthenticationProperties.GetString(const aKey: string): string;
begin
  if not fItems.TryGetValue(RedirectUriKey,Result) then raise EAuthenticationProperty.CreateFmt('Authentication property "%s" not defined!',[aKey]);
end;

procedure TAuthenticationProperties.SetAllowRefresh(const aValue: Boolean);
begin
  fItems.AddOrSetValue(RefreshKey,aValue.ToString);
end;

procedure TAuthenticationProperties.SetBool(const aKey: string; aValue: Boolean);
begin
  fItems.AddOrSetValue(aKey,aValue.ToString);
end;

procedure TAuthenticationProperties.SetExpiresUtc(const aValue: Boolean);
begin
  fItems.AddOrSetValue(ExpiresUtcKey,aValue.ToString);
end;

procedure TAuthenticationProperties.SetIsPersistent(const aValue: Boolean);
begin
  fItems.AddOrSetValue(IsPersistentKey,aValue.ToString);
end;

procedure TAuthenticationProperties.SetIssuedUtc(const aValue: Boolean);
begin
  fItems.AddOrSetValue(IssuedUtcKey,aValue.ToString);
end;

procedure TAuthenticationProperties.SetParamter<T>(const aKey: string; aValue: T);
begin
  fParameters.AddOrSetValue(aKey,TObject(aValue));
end;

procedure TAuthenticationProperties.SetRedirectUri(const aValue: Boolean);
begin
  fItems.AddOrSetValue(RedirectUriKey,aValue.ToString);
end;

procedure TAuthenticationProperties.SetString(const aKey, aValue: string);
begin
  fItems.AddOrSetValue(aKey,aValue);
end;

{ TAuthenticationOptions }

constructor TAuthenticationOptions.Create;
begin
  fSchemes := TObjectList<TAuthenticationScheme>.Create(True);
  fSchemeMap := TDictionary<string,TAuthenticationScheme>.Create;
end;

destructor TAuthenticationOptions.Destroy;
begin
  fSchemeMap.Free;
  fSchemes.Free;
  inherited;
end;

procedure TAuthenticationOptions.AddScheme(const aName: string; aHandlerType : PTypeInfo);
var
  scheme : TAuthenticationScheme;
begin
  scheme := TAuthenticationScheme.Create(aName,aHandlerType);
  fSchemes.Add(scheme);
  fSchemeMap.Add(aName,scheme);
end;

procedure TAuthenticationOptions.AddScheme(const aName: string; aScheme: TAuthenticationScheme);
begin
  fSchemes.Add(aScheme);
  fSchemeMap.Add(aName,aScheme);
end;

{ TAuthenticationHandlerProvider }

constructor TAuthenticationHandlerProvider.Create(aSchemes: IAuthenticationSchemeProvider);
begin
  fSchemes := aSchemes;
  //fHandlerMap := TObjectDictionary<string,IAuthenticationHandler>.Create([]);
end;

destructor TAuthenticationHandlerProvider.Destroy;
begin
  //fHandlerMap.Free;
  inherited;
end;

function TAuthenticationHandlerProvider.GetHandler(aContext: THttpContextBase; const aAuthenticationScheme: string): IAuthenticationHandler;
var
  handler : IAuthenticationHandler;
begin
  //if fHandlerMap.ContainsKey(aAuthenticationScheme) then Exit(fHandlerMap[aAuthenticationScheme]);

  var scheme := fSchemes.GetScheme(aAuthenticationScheme);
  if scheme = nil then Exit(nil);

  handler := aContext.RequestServices.GetService(scheme.HandlerType).AsType<IAuthenticationHandler>;

  if handler <> nil then
  begin
    handler.Initialize(scheme,aContext);
    //fHandlerMap.AddOrSetValue(aAuthenticationScheme,handler);
  end;
  Result := handler;
end;



{ TAuthenticationHandler<T> }

constructor TAuthenticationHandler<T>.Create(aOptions: IOptions<T>; aLogger: ILogger);
begin
  fOptions := aOptions.Value;
  fLogger := aLogger;
end;

procedure TAuthenticationHandler<T>.Challenge(aProperties: TAuthenticationProperties);
begin
  fContext.Response.StatusCode := 401;
end;

procedure TAuthenticationHandler<T>.Forbid(aProperties: TAuthenticationProperties);
begin
  fContext.Response.StatusCode := 403;
end;

procedure TAuthenticationHandler<T>.Initialize(aScheme: TAuthenticationScheme; aContext: THttpContextBase);
begin
  fScheme := aScheme;
  fContext := aContext;
  fRequest := aContext.Request;
  fResponse := aContext.Response;
  //initialize class options based
  DoInitialize;
end;

end.
