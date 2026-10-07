unit Controller.Greet;

{ LocalizationSample Sample - S-20
  Returns a localized greeting based on the Accept-Language request header.
  Translation keys are resolved via IStringLocalization. }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Localization.Abstractions;

type
  [Route('api/greet')]
  [ApiController]
  TGreetController = class(THttpController)
  private
    fL10n : IStringLocalization;
  public
    constructor Create(aL10n : IStringLocalization);
  published
    // GET /api/greet?name=Alice  (Accept-Language: es|fr|en)
    [HttpGet]
    function Greet(name : string) : IActionResult;

    // GET /api/greet/farewell?name=Alice
    [HttpGet('farewell')]
    function Farewell(name : string) : IActionResult;
  end;

implementation

uses
  System.SysUtils;

{ TGreetController }

constructor TGreetController.Create(aL10n : IStringLocalization);
begin
  inherited Create;
  fL10n := aL10n;
end;

function TGreetController.Greet(name : string): IActionResult;
var
  msg : string;
  culture : string;
begin
  culture := Request.Headers.GetValue('Accept-Language');
  if culture = '' then culture := 'en';
  fL10n.SetCulture(culture);
  msg := fL10n.GetItemFmt('greeting', [name]);
  Result := Json(Format('{"message":"%s"}', [msg]));
end;

function TGreetController.Farewell(name : string): IActionResult;
var
  msg : string;
  culture : string;
begin
  culture := Request.Headers.GetValue('Accept-Language');
  if culture = '' then culture := 'en';
  fL10n.SetCulture(culture);
  msg := fL10n.GetItemFmt('farewell', [name]);
  Result := Json(Format('{"message":"%s"}', [msg]));
end;

initialization
  RegisterController(TGreetController);

end.
