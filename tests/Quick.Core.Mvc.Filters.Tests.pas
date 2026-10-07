unit Quick.Core.Mvc.Filters.Tests;

{ Tests: T-FLT-01..08
    T-FLT-01  TActionExecutingContext.Canceled defaults to False
    T-FLT-02  TActionExecutingContext.Canceled := True persists
    T-FLT-03  TActionExecutingContext.Result defaults to nil
    T-FLT-04  TActionExecutedContext.Exception defaults to nil
    T-FLT-05  TActionExecutedContext.Exception can be set
    T-FLT-06  TActionFilterAttribute.OnActionExecuting is a no-op (no exception raised)
    T-FLT-07  TActionFilterAttribute.OnActionExecuted is a no-op (no exception raised)
    T-FLT-08  Custom filter subclass can override OnActionExecuting
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Quick.Core.Mvc.Filters;

type

  // A filter that records whether it was invoked
  TCapturingFilter = class(TActionFilterAttribute)
  public
    ExecutingCalled : Boolean;
    ExecutedCalled  : Boolean;
    procedure OnActionExecuting(aContext : TActionExecutingContext); override;
    procedure OnActionExecuted(aContext  : TActionExecutedContext);  override;
  end;

  [TestFixture]
  TFiltersTests = class
  public
    [Test]
    procedure T_FLT_01_ExecutingContext_Canceled_DefaultFalse;
    [Test]
    procedure T_FLT_02_ExecutingContext_Canceled_SetTrue;
    [Test]
    procedure T_FLT_03_ExecutingContext_Result_DefaultNil;
    [Test]
    procedure T_FLT_04_ExecutedContext_Exception_DefaultNil;
    [Test]
    procedure T_FLT_05_ExecutedContext_Exception_CanBeSet;
    [Test]
    procedure T_FLT_06_BaseFilter_OnActionExecuting_NoOp;
    [Test]
    procedure T_FLT_07_BaseFilter_OnActionExecuted_NoOp;
    [Test]
    procedure T_FLT_08_CustomFilter_Override_IsInvoked;
  end;

implementation

{ TCapturingFilter }

procedure TCapturingFilter.OnActionExecuting(aContext : TActionExecutingContext);
begin
  ExecutingCalled := True;
end;

procedure TCapturingFilter.OnActionExecuted(aContext : TActionExecutedContext);
begin
  ExecutedCalled := True;
end;

{ TFiltersTests }

procedure TFiltersTests.T_FLT_01_ExecutingContext_Canceled_DefaultFalse;
var
  ctx : TActionExecutingContext;
begin
  // Pass nil for TRequestContext — no access to it in these tests
  ctx := TActionExecutingContext.Create(nil);
  try
    Assert.IsFalse(ctx.Canceled, 'Canceled should default to False');
  finally
    ctx.Free;
  end;
end;

procedure TFiltersTests.T_FLT_02_ExecutingContext_Canceled_SetTrue;
var
  ctx : TActionExecutingContext;
begin
  ctx := TActionExecutingContext.Create(nil);
  try
    ctx.Canceled := True;
    Assert.IsTrue(ctx.Canceled, 'Canceled should be True after setting it');
  finally
    ctx.Free;
  end;
end;

procedure TFiltersTests.T_FLT_03_ExecutingContext_Result_DefaultNil;
var
  ctx : TActionExecutingContext;
begin
  ctx := TActionExecutingContext.Create(nil);
  try
    Assert.IsNull(ctx.Result, 'Result should default to nil');
  finally
    ctx.Free;
  end;
end;

procedure TFiltersTests.T_FLT_04_ExecutedContext_Exception_DefaultNil;
var
  ctx : TActionExecutedContext;
begin
  ctx := TActionExecutedContext.Create(nil);
  try
    Assert.IsNull(ctx.Exception, 'Exception should default to nil');
  finally
    ctx.Free;
  end;
end;

procedure TFiltersTests.T_FLT_05_ExecutedContext_Exception_CanBeSet;
var
  ctx : TActionExecutedContext;
  ex  : Exception;
begin
  ctx := TActionExecutedContext.Create(nil);
  ex  := Exception.Create('test error');
  try
    ctx.Exception := ex;
    Assert.IsNotNull(ctx.Exception,
      'Exception should be non-nil after assignment');
    Assert.AreEqual('test error', ctx.Exception.Message);
  finally
    ex.Free;
    ctx.Free;
  end;
end;

procedure TFiltersTests.T_FLT_06_BaseFilter_OnActionExecuting_NoOp;
var
  filter : TActionFilterAttribute;
  ctx    : TActionExecutingContext;
begin
  filter := TActionFilterAttribute.Create;
  ctx    := TActionExecutingContext.Create(nil);
  try
    // Should not raise
    Assert.WillNotRaiseAny(procedure begin filter.OnActionExecuting(ctx) end,
      'Base OnActionExecuting should be a no-op and not raise');
  finally
    ctx.Free;
    filter.Free;
  end;
end;

procedure TFiltersTests.T_FLT_07_BaseFilter_OnActionExecuted_NoOp;
var
  filter : TActionFilterAttribute;
  ctx    : TActionExecutedContext;
begin
  filter := TActionFilterAttribute.Create;
  ctx    := TActionExecutedContext.Create(nil);
  try
    Assert.WillNotRaiseAny(procedure begin filter.OnActionExecuted(ctx) end,
      'Base OnActionExecuted should be a no-op and not raise');
  finally
    ctx.Free;
    filter.Free;
  end;
end;

procedure TFiltersTests.T_FLT_08_CustomFilter_Override_IsInvoked;
var
  filter : TCapturingFilter;
  ectx   : TActionExecutingContext;
  dctx   : TActionExecutedContext;
begin
  filter := TCapturingFilter.Create;
  ectx   := TActionExecutingContext.Create(nil);
  dctx   := TActionExecutedContext.Create(nil);
  try
    filter.OnActionExecuting(ectx);
    filter.OnActionExecuted(dctx);
    Assert.IsTrue(filter.ExecutingCalled,
      'Overridden OnActionExecuting should be called');
    Assert.IsTrue(filter.ExecutedCalled,
      'Overridden OnActionExecuted should be called');
  finally
    dctx.Free;
    ectx.Free;
    filter.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TFiltersTests);

end.
