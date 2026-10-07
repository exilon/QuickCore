unit Middleware.RequestId;

// CustomMiddleware Sample - S-11
// Middleware that adds a unique X-Request-ID header to each request.

interface

uses
  Quick.Core.Mvc.Middleware,
  Quick.Core.Mvc.Context;

type
  TRequestIdMiddleware = class(TRequestDelegate)
  public
    procedure Invoke(aContext : THttpContextBase); override;
  end;

implementation

uses
  System.SysUtils;

{ TRequestIdMiddleware }

procedure TRequestIdMiddleware.Invoke(aContext : THttpContextBase);
var
  reqId : string;
begin
  reqId := GUIDToString(TGuid.NewGuid);
  aContext.Request.Headers.Add('X-Request-ID', reqId);
  aContext.Response.Headers.Add('X-Request-ID', reqId);
  Next(aContext);
end;

end.
