{ **************************** }
{      Quick.Core Library      }
{        Action Filters         }
{ **************************** }
{ Author: QuickCore Team       }
{ **************************** }
unit Quick.Core.Mvc.Filters;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.HttpServer,
  Quick.Core.Mvc.Context,
  Quick.Core.Mvc.ActionResult;

type
  TActionExecutingContext = class
  private
    fRequestContext : TRequestContext;
    fCanceled       : Boolean;
    fResult         : IActionResult;
  public
    constructor Create(aRequestContext : TRequestContext);
    property RequestContext : TRequestContext read fRequestContext;
    { Set Canceled := True to short-circuit the action pipeline. }
    property Canceled : Boolean read fCanceled write fCanceled;
    { When Canceled = True, assign a Result to be rendered instead of the action. }
    property Result : IActionResult read fResult write fResult;
  end;

  TActionExecutedContext = class
  private
    fRequestContext : TRequestContext;
    fException      : Exception;
  public
    constructor Create(aRequestContext : TRequestContext; aException : Exception = nil);
    property RequestContext : TRequestContext read fRequestContext;
    { Non-nil when the action raised an exception (only set if the filter
      runs in an exception-aware host that catches and re-raises). }
    property Exception : Exception read fException write fException;
  end;

  { Base class for action filter attributes. Override OnActionExecuting and/or
    OnActionExecuted in your derived attribute.

    Usage:
      type
        TMyFilter = class(TActionFilterAttribute)
          procedure OnActionExecuting(aContext : TActionExecutingContext); override;
        end;

      [TMyFilter]
      function TMyController.MyAction : IActionResult;
  }
  TActionFilterAttribute = class(TCustomAttribute)
  public
    procedure OnActionExecuting(aContext : TActionExecutingContext); virtual;
    procedure OnActionExecuted(aContext : TActionExecutedContext); virtual;
  end;

implementation

{ TActionExecutingContext }

constructor TActionExecutingContext.Create(aRequestContext : TRequestContext);
begin
  fRequestContext := aRequestContext;
  fCanceled := False;
  fResult := nil;
end;

{ TActionExecutedContext }

constructor TActionExecutedContext.Create(aRequestContext : TRequestContext; aException : Exception = nil);
begin
  fRequestContext := aRequestContext;
  fException := aException;
end;

{ TActionFilterAttribute }

procedure TActionFilterAttribute.OnActionExecuting(aContext : TActionExecutingContext);
begin
  // default: no-op
end;

procedure TActionFilterAttribute.OnActionExecuted(aContext : TActionExecutedContext);
begin
  // default: no-op
end;

end.
