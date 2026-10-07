unit Controller.Catalog;

(* LiquidViewEngine Sample - S-36
  A product catalog rendered with the Liquid template engine.

  Routes:
    GET /             -> redirect to /catalog
    GET /catalog      -> list all products (Liquid template: catalog/index.liquid)
    GET /catalog/:id  -> product detail (Liquid template: catalog/detail.liquid)
    GET /about        -> about page (Liquid template: about.liquid)
*)

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult;

type

  [Route('')]
  [ApiController]
  TCatalogController = class(THttpController)
  public
    constructor Create;
  published
    [HttpGet]
    function Index : IActionResult;

    [HttpGet('catalog')]
    function Catalog : IActionResult;

    [HttpGet('catalog/{id:int}')]
    function Detail(id : Integer) : IActionResult;

    [HttpGet('about')]
    function About : IActionResult;
  end;

implementation

uses
  System.SysUtils;

{ TCatalogController }

constructor TCatalogController.Create;
begin
  inherited Create;
end;

function TCatalogController.Index : IActionResult;
begin
  Result := Redirect('/catalog');
end;

function TCatalogController.Catalog : IActionResult;
begin
  // Pass comma-separated product names for the {% for %} loop
  ViewData['page_title']    := 'Product Catalog';
  ViewData['product_names'] := 'Laptop,Keyboard,Monitor,Mouse,Headset';
  ViewData['product_ids']   := '1,2,3,4,5';
  ViewData['item_count']    := '5';
  Result := View('catalog/index');
end;

function TCatalogController.Detail(id : Integer) : IActionResult;
begin
  case id of
    1 : begin
          ViewData['id']          := '1';
          ViewData['name']        := 'Laptop';
          ViewData['price']       := '999.99';
          ViewData['description'] := 'A powerful 15" laptop with 32GB RAM.';
          ViewData['in_stock']    := 'true';
        end;
    2 : begin
          ViewData['id']          := '2';
          ViewData['name']        := 'Keyboard';
          ViewData['price']       := '49.99';
          ViewData['description'] := 'Mechanical keyboard with RGB lighting.';
          ViewData['in_stock']    := 'true';
        end;
    3 : begin
          ViewData['id']          := '3';
          ViewData['name']        := 'Monitor';
          ViewData['price']       := '349.99';
          ViewData['description'] := '27" 4K IPS display with HDR support.';
          ViewData['in_stock']    := '';
        end;
    4 : begin
          ViewData['id']          := '4';
          ViewData['name']        := 'Mouse';
          ViewData['price']       := '29.99';
          ViewData['description'] := 'Wireless ergonomic mouse.';
          ViewData['in_stock']    := 'true';
        end;
    5 : begin
          ViewData['id']          := '5';
          ViewData['name']        := 'Headset';
          ViewData['price']       := '79.99';
          ViewData['description'] := 'Noise-cancelling stereo headset.';
          ViewData['in_stock']    := 'true';
        end;
  else
    Exit(NotFound);
  end;
  ViewData['page_title'] := ViewData['name'] + ' - Catalog';
  Result := View('catalog/detail');
end;

function TCatalogController.About : IActionResult;
begin
  ViewData['page_title']  := 'About';
  ViewData['engine_name'] := 'QuickCore Liquid View Engine';
  ViewData['version']     := '1.0';
  Result := View('about');
end;

initialization
  RegisterController(TCatalogController);

end.
