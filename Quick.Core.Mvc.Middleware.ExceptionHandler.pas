{ **************************** }
{      Quick.Core Library      }
{   Global Exception Handler   }
{ **************************** }
{ Author: QuickCore Team       }
{ **************************** }
unit Quick.Core.Mvc.Middleware.ExceptionHandler;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Core.Mvc.Context,
  Quick.Core.Mvc.Middleware;

type
  { Optional callback for custom error logging or alternate response formatting. }
  TExceptionHandlerProc = reference to procedure(aContext : THttpContextBase; aException : Exception);

  TExceptionHandlerMiddleware = class(TRequestDelegate)
  private
    fOnException : TExceptionHandlerProc;
    function BuildErrorJson(const aMessage : string) : string;
  public
    { aOnException: optional logging/override callback. If nil, default 500 JSON is sent. }
    constructor Create(aNext : TRequestDelegate; aOnException : TExceptionHandlerProc = nil);
    procedure Invoke(aContext : THttpContextBase); override;
  end;

implementation

{ TExceptionHandlerMiddleware }

constructor TExceptionHandlerMiddleware.Create(aNext : TRequestDelegate; aOnException : TExceptionHandlerProc = nil);
begin
  inherited Create(aNext);
  fOnException := aOnException;
end;

function TExceptionHandlerMiddleware.BuildErrorJson(const aMessage : string) : string;
var
  safeMsg : string;
begin
  // Basic JSON-safe escaping: replace \ and " to avoid injection in the message
  safeMsg := StringReplace(aMessage, '\', '\\', [rfReplaceAll]);
  safeMsg := StringReplace(safeMsg, '"', '\"', [rfReplaceAll]);
  Result := Format('{"error":{"status":500,"message":"%s"}}', [safeMsg]);
end;

procedure TExceptionHandlerMiddleware.Invoke(aContext : THttpContextBase);
begin
  inherited;
  try
    Next(aContext);
  except
    on E : Exception do
    begin
      if Assigned(fOnException) then
      begin
        fOnException(aContext, E);
      end
      else
      begin
        aContext.Response.StatusCode := 500;
        aContext.Response.ContentType := 'application/json';
        // SEC-26: Do not expose internal exception details (SQL, paths, etc.) in the response.
        // Return a generic message; the actual error is available via the OnException callback.
        aContext.Response.ContentText := BuildErrorJson('Internal Server Error');
      end;
    end;
  end;
end;

end.
