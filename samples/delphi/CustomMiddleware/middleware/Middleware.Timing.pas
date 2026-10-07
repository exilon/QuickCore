unit Middleware.Timing;

// CustomMiddleware Sample - S-11
// Middleware that measures request duration and adds X-Response-Time header.

interface

uses
  Quick.Core.Mvc.Middleware,
  Quick.Core.Mvc.Context;

type
  TTimingMiddleware = class(TRequestDelegate)
  public
    procedure Invoke(aContext : THttpContextBase); override;
  end;

implementation

uses
  System.SysUtils,
  System.Diagnostics;

{ TTimingMiddleware }

procedure TTimingMiddleware.Invoke(aContext : THttpContextBase);
var
  sw : TStopwatch;
begin
  sw := TStopwatch.StartNew;
  Next(aContext);
  sw.Stop;
  aContext.Response.Headers.Add('X-Response-Time',
    Format('%d ms', [sw.ElapsedMilliseconds]));
end;

end.
