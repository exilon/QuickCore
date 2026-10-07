unit Controller.Hello;

// HelloWorldApi Sample - S-01
// Minimal controller that responds to GET /hello and GET /hello/greet/{name}

interface

uses
  System.SysUtils,
  Quick.HttpServer.Types,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult;

type
  [Route('hello')]
  [ApiController]
  THelloController = class(THttpController)
  published
    /// GET /hello  ->  "Hello, World!"
    [HttpGet]
    function Index : IActionResult;

    /// GET /hello/greet/{name}  ->  "Hello, {name}!"
    [HttpGet('greet/{name}')]
    function Greet(name : string) : IActionResult;
  end;

implementation

{ THelloController }

function THelloController.Index: IActionResult;
begin
  Result := Json(Format('{"Message":"Hello, World!","Timestamp":"%s"}', [DateTimeToStr(Now)]));
end;

function THelloController.Greet(name: string): IActionResult;
begin
  Result := Ok(Format('Hello, %s!', [name]));
end;

initialization
  RegisterController(THelloController);

end.
