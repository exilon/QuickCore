{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Security.Authorization
  Description : Core Security Authorization
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 07/03/2020
  Modified    : 20/03/2020

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

unit Quick.Core.Security.Authorization;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Quick.Commons,
  Quick.Options,
  Quick.Collections,
  Quick.Core.Logging.Abstractions,
  Quick.Core.Security.Claims;

type

  IAuthorizationRequirement = interface
  ['{1C1DD563-B2F8-4749-8AC6-93DEB992EEA2}']
  end;

  TAuthorizationPolicy = class
  private
    fRequirements : IList<IAuthorizationRequirement>;
    fAuthenticationSchemes : IList<string>;
  public
    constructor Create(aRequirements : IList<IAuthorizationRequirement>; aAuthenticationSchemes : IList<string>);
    property Requirements : IList<IAuthorizationRequirement> read fRequirements write fRequirements;
    property AuthenticationSchemes : IList<string> read fAuthenticationSchemes write fAuthenticationSchemes;
  end;

  IAuthorizationPolicyProvider = interface
  ['{97A6E478-54B8-48B5-8E94-FB3EEC8CF183}']
    function GetPolicy(const aPolicyName : string) : TAuthorizationPolicy;
    function GetDefaultPolicy : TAuthorizationPolicy;
  end;

  IAuthorizationPolicyBuilder = interface
  ['{57F58D70-F4F3-44D8-85E6-9B05A22AF819}']
    function AddRequirements(aRequirements : IList<IAuthorizationRequirement>) : IAuthorizationPolicyBuilder;
    function RequireClaim(const aClaim : string) : IAuthorizationPolicyBuilder; overload;
    function RequireClaim(const aClaim, aAllowedValue : string) : IAuthorizationPolicyBuilder; overload;
    function RequireClaim(const aClaim : string; aAllowedValues : IList<string>) : IAuthorizationPolicyBuilder; overload;
    function RequireRole(const aRole : string) : IAuthorizationPolicyBuilder; overload;
    function RequireRole(aRoles : IList<string>) : IAuthorizationPolicyBuilder; overload;
    function RequireUserName(const aUserName : string) : IAuthorizationPolicyBuilder;
    function RequireAuthenticatedUser : IAuthorizationPolicyBuilder; overload;
    function Build : TAuthorizationPolicy;
  end;

  TAuthorizationOptions = class(TOptions)
  private
    fPolicyMap : TObjectDictionary<string,TAuthorizationPolicy>;
    fDefaultPolicy : TAuthorizationPolicy;
    fInvokeHandlersAfterFailure : Boolean;
    procedure SetDefaultPolicy(aPolicy : TAuthorizationPolicy);
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure AddPolicy(const aName : string; aPolicy : TAuthorizationPolicy);
    function GetPolicy(const aName : string) : TAuthorizationPolicy;
  published
    property DefaultPolicy : TAuthorizationPolicy read fDefaultPolicy write SetDefaultPolicy;
    property InvokeHandlersAfterFailure : Boolean read fInvokeHandlersAfterFailure write fInvokeHandlersAfterFailure;
  end;

  TAuthorizationHandlerContext = class
  private
    fFailCalled : Boolean;
    fSucceededCalled : Boolean;
    fPendingRequirements : IList<IAuthorizationRequirement>;
    fRequirements : IList<IAuthorizationRequirement>;
    fResource : TObject;
    fUser : TClaimsPrincipal;
    function GetPendingRequirements : IList<IAuthorizationRequirement>;
    function GetHasSucceeded: Boolean;
  public
    constructor Create(aRequirements : IList<IAuthorizationRequirement>; aUser : TClaimsPrincipal; aResource : TObject);
    property HasFailed : Boolean read fFailCalled;
    property HasSucceeded  : Boolean read GetHasSucceeded;
    property PendingRequirements : IList<IAuthorizationRequirement> read GetPendingRequirements;
    property Requirements : IList<IAuthorizationRequirement> read fRequirements;
    property Resource : TObject read fResource;
    property User : TClaimsPrincipal read fUser;
    procedure Fail;
    procedure Succeed(aRequirement : IAuthorizationRequirement);
  end;

  IAuthorizationHandler = interface
  ['{042BE351-1027-4425-A27A-C063E7652DFD}']
    procedure Handle(aContext : TAuthorizationHandlerContext);
  end;

  TPassThroughAuthorizationHandler = class(TInterfacedObject,IAuthorizationHandler)
  public
    procedure Handle(aContext : TAuthorizationHandlerContext);
  end;

  TAuthorizationFailure = record
    FailCalled : Boolean;
    FailedRequirements : IList<IAuthorizationRequirement>;
    function ExplicitFail : TAuthorizationFailure;
    function Failed(aFailedRequirements : IList<IAuthorizationRequirement>) : TAuthorizationFailure;
  end;

  TAuthorizationResult = record
    Failure : TAuthorizationFailure;
    Succeeded : Boolean;
    function Success : TAuthorizationResult;
    function Failed(aFailure : TAuthorizationFailure) : TAuthorizationResult; overload;
    function Failed(aPendingRequirements : IList<IAuthorizationRequirement>) : TAuthorizationResult; overload;
  end;

  TAuthorizationHandler<T : class> = class(TInterfacedObject,IAuthorizationHandler)
  public
    procedure Handle(aContext : TAuthorizationHandlerContext);
    function HandleRequirement(aContext : TAuthorizationHandlerContext; aRequirement : T) : Boolean; virtual; abstract;
  end;

  TAssertionRequirement = class(TAuthorizationHandler<TAssertionRequirement>,IAuthorizationRequirement)
  //private
  //  fHandler : TFunc<TAuthorizationHandlerContext,Boolean>;
  public
    constructor Create(aHandler : TFunc<TAuthorizationHandlerContext,Boolean>);
    function HandleRequirement(aContext : TAuthorizationHandlerContext; aRequirement : TAssertionRequirement) : Boolean; override;
  end;

  TClaimsAuthorizationRequirement = class(TAuthorizationHandler<TClaimsAuthorizationRequirement>,IAuthorizationRequirement)
  private
    fClaimType : string;
    fAllowedValues : IList<string>;
  public
    constructor Create(const aClaimType : string; aAllowedValues : IList<string>); overload;
    constructor Create(const aClaimType, aAllowedValue : string); overload;
    function HandleRequirement(aContext : TAuthorizationHandlerContext; aRequirement : TClaimsAuthorizationRequirement) : Boolean; override;
  end;

  TRolesAuthorizationRequirement = class(TAuthorizationHandler<TRolesAuthorizationRequirement>,IAuthorizationRequirement)
  private
    fAllowedValues : IList<string>;
  public
    constructor Create(aAllowedValues : IList<string>);
    function HandleRequirement(aContext : TAuthorizationHandlerContext; aRequirementClass : TRolesAuthorizationRequirement) : Boolean; override;
  end;

  TNameAuthorizationRequirement = class(TAuthorizationHandler<TNameAuthorizationRequirement>,IAuthorizationRequirement)
  private
    fName : string;
  public
    constructor Create(const aRequiredName : string);
    function HandleRequirement(aContext : TAuthorizationHandlerContext; aRequirementClass : TNameAuthorizationRequirement) : Boolean; override;
  end;

  IAuthorizationEvaluator = interface
  ['{EDBC53EF-2FB0-49A1-8DA5-1B17B3CD6AFA}']
    function Evaluate(aContext : TAuthorizationHandlerContext) : TAuthorizationResult;
  end;

  TDefaultAuthorizationEvaluator = class(TInterfacedObject,IAuthorizationEvaluator)
  public
    function Evaluate(aContext : TAuthorizationHandlerContext) : TAuthorizationResult;
  end;


  TAuthorizationPolicyBuilder = class(TInterfacedObject,IAuthorizationPolicyBuilder)
  private
    fPolicy : TAuthorizationPolicy;
  public
    class function GetBuilder : IAuthorizationPolicyBuilder;
    constructor Create;
    function AddRequirements(aRequirements : IList<IAuthorizationRequirement>) : IAuthorizationPolicyBuilder;
    function RequireClaim(const aClaim : string) : IAuthorizationPolicyBuilder; overload;
    function RequireClaim(const aClaim, aAllowedValue : string) : IAuthorizationPolicyBuilder; overload;
    function RequireClaim(const aClaim : string; aAllowedValues : IList<string>) : IAuthorizationPolicyBuilder; overload;
    function RequireRole(const aRole : string) : IAuthorizationPolicyBuilder; overload;
    function RequireRole(aRoles : IList<string>) : IAuthorizationPolicyBuilder; overload;
    function RequireUserName(const aUserName : string) : IAuthorizationPolicyBuilder;
    function RequireAuthenticatedUser : IAuthorizationPolicyBuilder; overload;
    function Build : TAuthorizationPolicy;
  end;

  IAuthorizationService = interface
  ['{543239A6-9B2F-4CAA-A205-E8ECF9B29F6F}']
    function Authorize(aClaimsPrincipal : TClaimsPrincipal; aResource : TObject; aRequirements : IList<IAuthorizationRequirement>) : TAuthorizationResult; overload;
    function Authorize(aClaimsPrincipal : TClaimsPrincipal; aResource : TObject; const aPolicyName : string) : TAuthorizationResult; overload;
  end;

  IAuthorizationHandlerProvider = interface
  ['{5A35160D-B13D-47DE-BF99-23CE88BB2122}']
    function GetHandlers(aContext : TAuthorizationHandlerContext) : IList<IAuthorizationHandler>;
  end;

  TDefaultAuthorizationService = class(TInterfacedObject,IAuthorizationService)
  private
    fPolicyProvider : IAuthorizationPolicyProvider;
    fOptions : TAuthorizationOptions;
    fHandlers : IAuthorizationHandlerProvider;
    fEvaluator : IAuthorizationEvaluator;
    fLogger : ILogger;
  public
    constructor Create(aPolicyProvider : IAuthorizationPolicyProvider; aAuthOptions : IOptions<TAuthorizationOptions>; aHandlers : IAuthorizationHandlerProvider; aEvaluator : IAuthorizationEvaluator; aLogger : ILogger);
    function Authorize(aUser : TClaimsPrincipal; aResource : TObject; aRequirements : IList<IAuthorizationRequirement>) : TAuthorizationResult; overload;
    function Authorize(aUser : TClaimsPrincipal; aResource : TObject; const aPolicyName : string) : TAuthorizationResult; overload;
  end;

  TDefaultAuthorizationPolicyProvider = class(TInterfacedObject,IAuthorizationPolicyProvider)
  private
    fOptions : TAuthorizationOptions;
  public
    constructor Create(aOptions : IOptions<TAuthorizationOptions>);
    function GetPolicy(const aPolicyName : string) : TAuthorizationPolicy;
    function GetDefaultPolicy : TAuthorizationPolicy;
  end;

  TDefaultAuthorizationHandlerProvider = class(TInterfacedObject,IAuthorizationHandlerProvider)
  private
    fHandlers : IList<IAuthorizationHandler>;
  public
    constructor Create(aHandlers : IList<IAuthorizationHandler>); overload;
    destructor Destroy; override;
    function GetHandlers(aContext : TAuthorizationHandlerContext) : IList<IAuthorizationHandler>;
  end;

  EAuthorizationError = class(Exception);
  EAuthorizationArgumentError = class(Exception);

implementation


{ TClaimsAuthorizationRequirement }

constructor TClaimsAuthorizationRequirement.Create(const aClaimType: string; aAllowedValues: IList<string>);
begin
  fClaimType := aClaimType;
  fAllowedValues := aAllowedValues;
end;

constructor TClaimsAuthorizationRequirement.Create(const aClaimType, aAllowedValue: string);
begin
  fClaimType := aClaimType;
  fAllowedValues := TXList<string>.Create;
  fAllowedValues.Add(aAllowedValue);
end;

function TClaimsAuthorizationRequirement.HandleRequirement(aContext : TAuthorizationHandlerContext; aRequirement : TClaimsAuthorizationRequirement) : Boolean;
var
  found : Boolean;
begin
  Result := False;
  if aContext.User <> nil then
  begin
    if (fAllowedValues = nil) or (fAllowedValues.Count = 0) then
    begin
      found := aContext.User.Claims.Any('ClaimType = ?',[fClaimType]);
    end
    else
    begin
      found := aContext.User.Claims.Any('(ClaimType = ?) AND (AllowedValues.Contains = ?',[fClaimType,fAllowedValues]);
    end;
    if found then
    begin
      aContext.Succeed(Self);
      Result := True;
    end;
  end;
end;

{ TDefaultAuthorizationService }

constructor TDefaultAuthorizationService.Create(aPolicyProvider : IAuthorizationPolicyProvider; aAuthOptions : IOptions<TAuthorizationOptions>; aHandlers : IAuthorizationHandlerProvider; aEvaluator : IAuthorizationEvaluator; aLogger : ILogger);
begin
  fOptions := aAuthOptions.Value;
  fPolicyProvider := aPolicyProvider;
  fHandlers := aHandlers;
  fEvaluator := aEvaluator;
  fLogger := aLogger;
end;

function TDefaultAuthorizationService.Authorize(aUser: TClaimsPrincipal; aResource: TObject; aRequirements: IList<IAuthorizationRequirement>): TAuthorizationResult;
var
  authContext : TAuthorizationHandlerContext;
  handlers : IList<IAuthorizationHandler>;
  handler : IAuthorizationHandler;
begin
  authContext := TAuthorizationHandlerContext.Create(aRequirements,aUser,aResource);
  handlers := fHandlers.GetHandlers(authContext);
  if not handlers.Any then
  begin
    fLogger.Warn('No authorization policy handlers provided');
    var failresult : TAuthorizationFailure;
    failresult.ExplicitFail;
    Result.Failed(failresult);
    Exit;
  end;

  for handler in handlers do
  begin
    handler.Handle(authContext);
    if (not fOptions.InvokeHandlersAfterFailure) and (authContext.HasFailed) then Break;
  end;

  Result := fEvaluator.Evaluate(authContext);
  if Result.Succeeded then fLogger.Debug('UserAuthorizationSucceeded')
    else fLogger.Debug('UserAuthorizationFailed');
end;

function TDefaultAuthorizationService.Authorize(aUser: TClaimsPrincipal; aResource: TObject; const aPolicyName: string): TAuthorizationResult;
var
  policy : TAuthorizationPolicy;
begin
  if aPolicyName.IsEmpty then
  begin
    raise EAuthorizationArgumentError.Create('Policy name not found');
  end;

  policy := fPolicyProvider.GetPolicy(aPolicyName);
  if policy = nil then
  begin
    raise EAuthorizationArgumentError.Create('Policy name not found');
  end;
  Result := Authorize(aUser, aResource, policy.Requirements);
end;

{ TAuthorizationHandlerContext }

constructor TAuthorizationHandlerContext.Create(aRequirements: IList<IAuthorizationRequirement>; aUser: TClaimsPrincipal; aResource: TObject);
begin
  fRequirements := aRequirements;
  fPendingRequirements := aRequirements;
  fUser := aUser;
  fResource := aResource;
end;

procedure TAuthorizationHandlerContext.Fail;
begin
  fFailCalled := True;
end;

function TAuthorizationHandlerContext.GetHasSucceeded: Boolean;
begin
  Result := (not fFailCalled) and (fSucceededCalled) and (fPendingRequirements.Count = 0);
end;

function TAuthorizationHandlerContext.GetPendingRequirements: IList<IAuthorizationRequirement>;
begin
  Result := fPendingRequirements;
end;

procedure TAuthorizationHandlerContext.Succeed(aRequirement : IAuthorizationRequirement);
begin
  fSucceededCalled := True;
end;

{ TAuthorizationHandler<IAuthorizationRequirement> }

procedure TAuthorizationHandler<T>.Handle(aContext : TAuthorizationHandlerContext);
var
  requirement : IAuthorizationRequirement;
begin
  for requirement in aContext.Requirements do
  begin
    HandleRequirement(aContext,T(requirement));
  end;
end;

{ TAuthorizationPolicy }

constructor TAuthorizationPolicy.Create(aRequirements: IList<IAuthorizationRequirement>; aAuthenticationSchemes: IList<string>);
begin
  fRequirements := aRequirements;
  fAuthenticationSchemes := aAuthenticationSchemes;
end;

{ TAuthorizationOptions }

constructor TAuthorizationOptions.Create;
begin
  inherited;
  fPolicyMap := TObjectDictionary<string,TAuthorizationPolicy>.Create([doOwnsValues]);
  fDefaultPolicy := TAuthorizationPolicyBuilder.GetBuilder.RequireAuthenticatedUser.Build;
  fInvokeHandlersAfterFailure := True;
end;

destructor TAuthorizationOptions.Destroy;
begin
  fPolicyMap.Free;
  if Assigned(fDefaultPolicy) then fDefaultPolicy.Free;
  inherited;
end;

procedure TAuthorizationOptions.AddPolicy(const aName: string; aPolicy: TAuthorizationPolicy);
begin
  if (aName.IsEmpty) or (aPolicy = nil) then raise EAuthorizationArgumentError.Create('Authorization Policy cannot be unnamed or null');
  fPolicyMap.Add(aName,aPolicy);
end;

function TAuthorizationOptions.GetPolicy(const aName: string): TAuthorizationPolicy;
begin
  if (aName.IsEmpty) or (not fPolicyMap.TryGetValue(aName,Result)) then raise EAuthorizationArgumentError.Create('Authorization Policy not found');
end;

procedure TAuthorizationOptions.SetDefaultPolicy(aPolicy: TAuthorizationPolicy);
begin
  if Assigned(fDefaultPolicy) then fDefaultPolicy.Free;
  fDefaultPolicy := aPolicy;
end;

{ TAuthorizationPolicyBuilder }

function TAuthorizationPolicyBuilder.AddRequirements(aRequirements: IList<IAuthorizationRequirement>): IAuthorizationPolicyBuilder;
begin
  Result := Self;
  fPolicy.Requirements.AddRange(aRequirements.ToArray);
end;

function TAuthorizationPolicyBuilder.Build: TAuthorizationPolicy;
begin
  Result := fPolicy;
end;

constructor TAuthorizationPolicyBuilder.Create;
begin
  fPolicy := TAuthorizationPolicy.Create(TXList<IAuthorizationRequirement>.Create,TXList<string>.Create);
end;

class function TAuthorizationPolicyBuilder.GetBuilder: IAuthorizationPolicyBuilder;
begin
  Result := TAuthorizationPolicyBuilder.Create;
end;

function TAuthorizationPolicyBuilder.RequireAuthenticatedUser: IAuthorizationPolicyBuilder;
begin
  Result := Self;
  //fPolicy.Requirements.Add(
end;

function TAuthorizationPolicyBuilder.RequireClaim(const aClaim: string; aAllowedValues: IList<string>): IAuthorizationPolicyBuilder;
begin
  Result := Self;
  fPolicy.Requirements.Add(TClaimsAuthorizationRequirement.Create(aClaim,aAllowedValues));
end;

function TAuthorizationPolicyBuilder.RequireClaim(const aClaim, aAllowedValue: string): IAuthorizationPolicyBuilder;
begin
  Result := Self;
  fPolicy.Requirements.Add(TClaimsAuthorizationRequirement.Create(aClaim,aAllowedValue));
end;

function TAuthorizationPolicyBuilder.RequireClaim(const aClaim: string): IAuthorizationPolicyBuilder;
begin
  Result := Self;
  fPolicy.Requirements.Add(TClaimsAuthorizationRequirement.Create(aClaim,''));
end;

function TAuthorizationPolicyBuilder.RequireRole(aRoles: IList<string>): IAuthorizationPolicyBuilder;
begin
  Result := Self;
  fPolicy.Requirements.Add(TRolesAuthorizationRequirement.Create(aRoles));
end;

function TAuthorizationPolicyBuilder.RequireRole(const aRole: string): IAuthorizationPolicyBuilder;
var
  list : IList<string>;
begin
  Result := Self;
  list := TXList<string>.Create;
  list.Add(aRole);
  fPolicy.Requirements.Add(TRolesAuthorizationRequirement.Create(list));
end;

function TAuthorizationPolicyBuilder.RequireUserName(const aUserName: string): IAuthorizationPolicyBuilder;
begin
  Result := Self;
  fPolicy.Requirements.Add(TNameAuthorizationRequirement.Create(aUserName));
end;

{ TAssertionRequirement }

constructor TAssertionRequirement.Create(aHandler: TFunc<TAuthorizationHandlerContext, Boolean>);
begin

end;

function TAssertionRequirement.HandleRequirement(aContext : TAuthorizationHandlerContext; aRequirement : TAssertionRequirement) : Boolean;
begin
  raise ENotImplemented.Create('Not implemented yet!');
end;

{ TDefaultAuthorizationPolicyProvider }

constructor TDefaultAuthorizationPolicyProvider.Create(aOptions: IOptions<TAuthorizationOptions>);
begin
  if aOptions = nil then raise EAuthorizationArgumentError.Create('Auth Options cannot be null');
  fOptions := aOptions.Value;
end;

function TDefaultAuthorizationPolicyProvider.GetDefaultPolicy: TAuthorizationPolicy;
begin
  Result := fOptions.DefaultPolicy;
end;

function TDefaultAuthorizationPolicyProvider.GetPolicy(const aPolicyName: string): TAuthorizationPolicy;
begin
  Result := fOptions.GetPolicy(aPolicyName);
end;

{ TDefaultAuthorizationHandlerProvider }

constructor TDefaultAuthorizationHandlerProvider.Create(aHandlers: IList<IAuthorizationHandler>);
begin
  if aHandlers = nil then raise EAuthorizationArgumentError.Create('Handlers cannot be null');
  fHandlers := aHandlers;
end;

destructor TDefaultAuthorizationHandlerProvider.Destroy;
begin
  fHandlers := nil;
  inherited;
end;

function TDefaultAuthorizationHandlerProvider.GetHandlers(aContext: TAuthorizationHandlerContext): IList<IAuthorizationHandler>;
begin
  Result := fHandlers;
end;

{ TRolesAuthorizationRequirement }

constructor TRolesAuthorizationRequirement.Create(aAllowedValues: IList<string>);
begin
  fAllowedValues := aAllowedValues;
end;

function TRolesAuthorizationRequirement.HandleRequirement(aContext : TAuthorizationHandlerContext; aRequirementClass : TRolesAuthorizationRequirement) : Boolean;
begin
  Result := False;

end;

{ TNameAuthorizationRequirement }

constructor TNameAuthorizationRequirement.Create(const aRequiredName: string);
begin
  fName := aRequiredName;
end;

function TNameAuthorizationRequirement.HandleRequirement(aContext : TAuthorizationHandlerContext; aRequirementClass : TNameAuthorizationRequirement) : Boolean;
begin
  Result := False;
  if aContext.User <> nil then
  begin
    //if aContext.User.Identity then

  end;
            {
                if (context.User.Identities.Any(i => string.Equals(i.Name, requirement.RequiredName)))
                {
                    context.Succeed(requirement);
                }


end;

{ TPassThroughAuthorizationHandler }

procedure TPassThroughAuthorizationHandler.Handle(aContext: TAuthorizationHandlerContext);
var
  requeriment : IAuthorizationRequirement;
  handler : IAuthorizationHandler;
begin
  for requeriment in aContext.Requirements do
  begin
    if Supports(requeriment,IAuthorizationHandler,handler) then
    begin
      handler := IAuthorizationHandler(requeriment);
      handler.Handle(aContext);
    end;
  end;
end;

{ TDefaultAuthorizationEvaluator }

function TDefaultAuthorizationEvaluator.Evaluate(aContext: TAuthorizationHandlerContext): TAuthorizationResult;
var
  failure : TAuthorizationFailure;
begin
  if aContext.HasSucceeded then Result.Success
  else
  begin
    if aContext.HasFailed then Result.Failed(failure.ExplicitFail)
    else
    begin
      Result.Failed(failure.Failed(aContext.PendingRequirements));
    end;
  end;
end;

{ TAuthorizationFailure }

function TAuthorizationFailure.ExplicitFail: TAuthorizationFailure;
begin
  FailCalled := True;
  FailedRequirements := TXList<IAuthorizationRequirement>.Create;
end;

function TAuthorizationFailure.Failed(aFailedRequirements: IList<IAuthorizationRequirement>): TAuthorizationFailure;
begin
  FailedRequirements := aFailedRequirements;
end;

{ TAuthorizationResult }

function TAuthorizationResult.Failed(aFailure: TAuthorizationFailure): TAuthorizationResult;
begin
  Failure := aFailure;
end;

function TAuthorizationResult.Failed(aPendingRequirements: IList<IAuthorizationRequirement>): TAuthorizationResult;
begin
  Failure.FailedRequirements := aPendingRequirements;
end;

function TAuthorizationResult.Success: TAuthorizationResult;
begin
  Succeeded := True;
end;

end.
