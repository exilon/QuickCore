unit Controller.Demo;

{ RateLimiting Sample - S-35
  Demonstrates per-action and global rate limiting.

  GET /api/public   — not rate-limited (always succeeds)
  GET /api/limited  — overrides global limit: max 3 req per 10 s
  GET /api/status   — not rate-limited, shows help }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Mvc.Middleware.RateLimit;

type
  [Route('api')]
  [ApiController]
  TDemoController = class(THttpController)
  public
    constructor Create;
  published
    /// No rate limit attribute — uses global policy (10 req / 60 s)
    [HttpGet('public')]
    function PublicEndpoint : IActionResult;

    /// Per-action tighter limit: 3 requests per 10 seconds
    [HttpGet('limited')]
    [RateLimit(3, 10)]
    function LimitedEndpoint : IActionResult;

    [HttpGet('status')]
    function Status : IActionResult;
  end;

implementation

uses
  System.SysUtils;

{ TDemoController }

constructor TDemoController.Create;
begin
  inherited Create;
end;

function TDemoController.PublicEndpoint : IActionResult;
begin
  Result := Json('{"endpoint":"public","message":"No per-action limit. Global: 10 req/60 s"}');
end;

function TDemoController.LimitedEndpoint : IActionResult;
begin
  Result := Json('{"endpoint":"limited","message":"Tight limit: 3 req per 10 s. Try rapid requests!"}');
end;

function TDemoController.Status : IActionResult;
begin
  Result := Json(
    '{"limits":{'  +
    '"global":"10 requests per 60 seconds",' +
    '"limited":"3 requests per 10 seconds"' +
    '},"tip":"429 Too Many Requests is returned when limit is exceeded"}');
end;

initialization
  RegisterController(TDemoController);

end.
