unit Quick.Core.Security.Authorization.Tests;

{ Tests: T-AZ-01..10
    T-AZ-01  TAuthorizationOptions default InvokeHandlersAfterFailure = True
    T-AZ-02  TAuthorizationOptions default policy is non-nil
    T-AZ-03  TAuthorizationOptions AddPolicy / GetPolicy round-trip
    T-AZ-04  TAuthorizationOptions AddPolicy with empty name raises exception
    T-AZ-05  TAuthorizationOptions GetPolicy for unknown name raises exception
    T-AZ-06  TAuthorizationHandlerContext Fail sets HasFailed = True
    T-AZ-07  TAuthorizationHandlerContext HasFailed is False initially
    T-AZ-08  TAuthorizationPolicyBuilder.GetBuilder returns non-nil
    T-AZ-09  TAuthorizationPolicyBuilder RequireClaim returns Self (fluent)
    T-AZ-10  TAuthorizationPolicyBuilder Build returns non-nil policy
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Quick.Collections,
  Quick.Core.Security.Claims,
  Quick.Core.Security.Authorization;

type

  [TestFixture]
  TAuthorizationTests = class
  public
    [Test]
    procedure T_AZ_01_Options_DefaultInvokeHandlers_True;
    [Test]
    procedure T_AZ_02_Options_DefaultPolicy_NotNil;
    [Test]
    procedure T_AZ_03_Options_AddGetPolicy_RoundTrip;
    [Test]
    procedure T_AZ_04_Options_AddPolicy_EmptyName_Raises;
    [Test]
    procedure T_AZ_05_Options_GetPolicy_Unknown_Raises;
    [Test]
    procedure T_AZ_06_HandlerContext_Fail_SetsHasFailed;
    [Test]
    procedure T_AZ_07_HandlerContext_HasFailed_DefaultFalse;
    [Test]
    procedure T_AZ_08_PolicyBuilder_GetBuilder_NonNil;
    [Test]
    procedure T_AZ_09_PolicyBuilder_RequireClaim_ReturnsSelf;
    [Test]
    procedure T_AZ_10_PolicyBuilder_Build_ReturnsPolicy;
  end;

implementation

{ TAuthorizationTests }

procedure TAuthorizationTests.T_AZ_01_Options_DefaultInvokeHandlers_True;
var
  opts : TAuthorizationOptions;
begin
  opts := TAuthorizationOptions.Create;
  try
    Assert.IsTrue(opts.InvokeHandlersAfterFailure,
      'InvokeHandlersAfterFailure should default to True');
  finally
    opts.Free;
  end;
end;

procedure TAuthorizationTests.T_AZ_02_Options_DefaultPolicy_NotNil;
var
  opts : TAuthorizationOptions;
begin
  opts := TAuthorizationOptions.Create;
  try
    Assert.IsNotNull(opts.DefaultPolicy, 'DefaultPolicy should not be nil after creation');
  finally
    opts.Free;
  end;
end;

procedure TAuthorizationTests.T_AZ_03_Options_AddGetPolicy_RoundTrip;
var
  opts   : TAuthorizationOptions;
  policy : TAuthorizationPolicy;
  found  : TAuthorizationPolicy;
begin
  opts   := TAuthorizationOptions.Create;
  policy := TAuthorizationPolicyBuilder.GetBuilder.RequireAuthenticatedUser.Build;
  try
    opts.AddPolicy('Admin', policy);
    found := opts.GetPolicy('Admin');
    Assert.IsNotNull(found, 'GetPolicy should return the policy just added');
  finally
    opts.Free;  // owns policy via ObjectDictionary
  end;
end;

procedure TAuthorizationTests.T_AZ_04_Options_AddPolicy_EmptyName_Raises;
var
  opts   : TAuthorizationOptions;
  policy : TAuthorizationPolicy;
begin
  opts   := TAuthorizationOptions.Create;
  policy := TAuthorizationPolicyBuilder.GetBuilder.RequireAuthenticatedUser.Build;
  try
    Assert.WillRaise(
      procedure
      begin
        opts.AddPolicy('', policy);
      end,
      EAuthorizationArgumentError,
      'AddPolicy with empty name should raise EAuthorizationArgumentError');
    policy.Free; // not added, so we own it
  finally
    opts.Free;
  end;
end;

procedure TAuthorizationTests.T_AZ_05_Options_GetPolicy_Unknown_Raises;
var
  opts : TAuthorizationOptions;
begin
  opts := TAuthorizationOptions.Create;
  try
    Assert.WillRaise(
      procedure
      begin
        opts.GetPolicy('NonExistentPolicy');
      end,
      EAuthorizationArgumentError,
      'GetPolicy for unknown policy should raise EAuthorizationArgumentError');
  finally
    opts.Free;
  end;
end;

procedure TAuthorizationTests.T_AZ_06_HandlerContext_Fail_SetsHasFailed;
var
  ctx : TAuthorizationHandlerContext;
begin
  // Pass nil requirements — we only test Fail which does not access the list
  ctx := TAuthorizationHandlerContext.Create(nil, nil, nil);
  try
    ctx.Fail;
    Assert.IsTrue(ctx.HasFailed, 'HasFailed should be True after calling Fail');
  finally
    ctx.Free;
  end;
end;

procedure TAuthorizationTests.T_AZ_07_HandlerContext_HasFailed_DefaultFalse;
var
  ctx : TAuthorizationHandlerContext;
begin
  ctx := TAuthorizationHandlerContext.Create(nil, nil, nil);
  try
    Assert.IsFalse(ctx.HasFailed, 'HasFailed should be False on a new context');
  finally
    ctx.Free;
  end;
end;

procedure TAuthorizationTests.T_AZ_08_PolicyBuilder_GetBuilder_NonNil;
var
  builder : IAuthorizationPolicyBuilder;
begin
  builder := TAuthorizationPolicyBuilder.GetBuilder;
  Assert.IsNotNull(builder, 'GetBuilder should return a non-nil IAuthorizationPolicyBuilder');
end;

procedure TAuthorizationTests.T_AZ_09_PolicyBuilder_RequireClaim_ReturnsSelf;
var
  builder : IAuthorizationPolicyBuilder;
  result  : IAuthorizationPolicyBuilder;
begin
  builder := TAuthorizationPolicyBuilder.GetBuilder;
  result  := builder.RequireClaim('sub');
  Assert.AreSame(builder as TObject, result as TObject,
    'RequireClaim should return the same builder for fluent chaining');
end;

procedure TAuthorizationTests.T_AZ_10_PolicyBuilder_Build_ReturnsPolicy;
var
  policy : TAuthorizationPolicy;
begin
  policy := TAuthorizationPolicyBuilder.GetBuilder.RequireAuthenticatedUser.Build;
  try
    Assert.IsNotNull(policy, 'Build should return a non-nil TAuthorizationPolicy');
  finally
    policy.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TAuthorizationTests);

end.
