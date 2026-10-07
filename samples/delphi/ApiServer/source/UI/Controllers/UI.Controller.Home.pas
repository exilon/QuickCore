unit UI.Controller.Home;

interface

uses
  System.SysUtils,
  Quick.HttpServer.Types,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Commons;

type
  THomeController = class(THttpController)
  published
    [HttpGet('Home'),ActionName('Index')]
    function Index : IActionResult;
  end;

implementation

{ THomeController }

function THomeController.Index: IActionResult;
begin
  ViewData['company'] := 'Exilon Soft';
  ViewData['name'] := 'Kike';
  ViewData['core'] := 'Quick Core MVC Framework';
  ViewData['product'] := 'T-Shirt';
  ViewData['colour'] :=  'Blue';
  ViewData['price'] := 28.9;
  //Result := Content('Welcome to Home page!');
  Result := View;
end;

initialization
  RegisterController(THomeController);

end.
