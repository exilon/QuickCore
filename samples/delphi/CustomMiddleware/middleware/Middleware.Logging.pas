unit Middleware.Logging;

// CustomMiddleware Sample - S-11
// Middleware that logs METHOD path -> status for every request.

interface

uses
  Quick.Core.Mvc.Middleware,
  Quick.Core.Mvc.Context,
  Quick.HttpServer.Types;

type
  TLoggingMiddleware = class(TRequestDelegate)
  public
    procedure Invoke(aContext : THttpContextBase); override;
  end;

implementation

uses
  System.SysUtils;

{ TLoggingMiddleware }

procedure TLoggingMiddleware.Invoke(aContext : THttpContextBase);
begin
  Next(aContext);
  WriteLn(Format('[%s] %s -> %d',
    [MethodVerbStr[Ord(aContext.Request.Method)],
     aContext.Request.URL,
     aContext.Response.StatusCode]));
end;

end.
