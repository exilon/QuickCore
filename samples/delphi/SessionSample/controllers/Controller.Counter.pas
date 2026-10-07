unit Controller.Counter;

{ SessionSample - S-32
  Demonstrates HTTP session usage with QuickCore MVC.

  Each visit to GET /api/counter increments a per-session counter stored
  in ISession (in-memory session store). The session ID is managed by the
  framework via a session cookie.

  GET /api/counter         — returns current visit count for this session
  POST /api/counter/reset  — resets the counter to zero
  GET /api/counter/id      — returns the current session ID }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult;

type
  [Route('api/counter')]
  [ApiController]
  TCounterController = class(THttpController)
  public
    constructor Create;
  published
    [HttpGet]
    function GetCount : IActionResult;

    [HttpPost('reset')]
    function Reset : IActionResult;

    [HttpGet('id')]
    function GetSessionId : IActionResult;
  end;

implementation

uses
  System.SysUtils;

const
  COUNTER_KEY = 'visit_count';

{ TCounterController }

constructor TCounterController.Create;
begin
  inherited Create;
end;

function TCounterController.GetCount : IActionResult;
var
  count : Int64;
begin
  count := HttpContext.Session.GetInteger(COUNTER_KEY) + 1;
  HttpContext.Session.SetInteger(COUNTER_KEY, count);
  Result := Json(Format('{"sessionId":"%s","visitCount":%d}',
    [HttpContext.Session.Id, count]));
end;

function TCounterController.Reset : IActionResult;
begin
  HttpContext.Session.SetInteger(COUNTER_KEY, 0);
  Result := Json('{"message":"Counter reset to 0"}');
end;

function TCounterController.GetSessionId : IActionResult;
begin
  Result := Json(Format('{"sessionId":"%s"}',
    [HttpContext.Session.Id]));
end;

initialization
  RegisterController(TCounterController);

end.
