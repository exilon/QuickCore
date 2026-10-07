unit Quick.Core.Mvc.Tests;

{ Tests: T-MVC-01..09
    T-MVC-01  TStatusResult carries StatusCode and StatusText from constructor
    T-MVC-02  TContentResult carries Content and ContentType (two-arg overload)
    T-MVC-03  TContentResult (one-arg) sets Content; ContentType defaults to empty
    T-MVC-04  TRedirectResult carries StatusCode and URL from constructor
    T-MVC-05  TProblemDetailsResult carries Status, Title, Detail, Type, Instance
    T-MVC-06  TJsonResult serializes a published-property object to non-empty JSON
    T-MVC-07  ActionName attribute carries its value
    T-MVC-08  HTTP verb attributes (HttpGet/HttpPost/HttpPut/HttpDelete) carry Route
    T-MVC-09  THttpRoute URL/ActionName/ControllerName properties are writable
}

interface

uses
  DUnitX.TestFramework,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Mvc.Routing,
  Quick.Core.Mvc.Controller;

type

  { Simple DTO used by T-MVC-06 }
  {$M+}
  TMvcTestDto = class
  private
    fId: Integer;
    fName: string;
  published
    property Id: Integer read fId write fId;
    property Name: string read fName write fName;
  end;
  {$M-}

  [TestFixture]
  TMvcTests = class
  public
    [Test]
    procedure T_MVC_01_StatusResult_Properties;
    [Test]
    procedure T_MVC_02_ContentResult_TwoArg;
    [Test]
    procedure T_MVC_03_ContentResult_OneArg_EmptyContentType;
    [Test]
    procedure T_MVC_04_RedirectResult_Properties;
    [Test]
    procedure T_MVC_05_ProblemDetailsResult_Properties;
    [Test]
    procedure T_MVC_06_JsonResult_SerializesObject;
    [Test]
    procedure T_MVC_07_ActionNameAttribute_CarriesValue;
    [Test]
    procedure T_MVC_08_VerbAttributes_CarryRoute;
    [Test]
    procedure T_MVC_09_HttpRoute_PropertyRoundTrip;
  end;

implementation

uses
  System.SysUtils,
  Quick.HttpServer.Types;

{ T-MVC-01 }

procedure TMvcTests.T_MVC_01_StatusResult_Properties;
var
  r: TStatusResult;
begin
  r := TStatusResult.Create(404, 'Not Found');
  try
    Assert.AreEqual(404, r.StatusCode);
    Assert.AreEqual('Not Found', r.StatusText);
  finally
    r.Free;
  end;
end;

{ T-MVC-02 }

procedure TMvcTests.T_MVC_02_ContentResult_TwoArg;
var
  r: TContentResult;
begin
  r := TContentResult.Create('hello world', 'text/plain');
  try
    Assert.AreEqual('hello world', r.Content);
    Assert.AreEqual('text/plain', r.ContentType);
  finally
    r.Free;
  end;
end;

{ T-MVC-03 }

procedure TMvcTests.T_MVC_03_ContentResult_OneArg_EmptyContentType;
var
  r: TContentResult;
begin
  r := TContentResult.Create('body text');
  try
    Assert.AreEqual('body text', r.Content);
    Assert.AreEqual('', r.ContentType);
  finally
    r.Free;
  end;
end;

{ T-MVC-04 }

procedure TMvcTests.T_MVC_04_RedirectResult_Properties;
var
  r: TRedirectResult;
begin
  r := TRedirectResult.Create(302, 'https://example.com/new');
  try
    Assert.AreEqual(302, r.StatusCode);
    Assert.AreEqual('https://example.com/new', r.URL);
  finally
    r.Free;
  end;
end;

{ T-MVC-05 }

procedure TMvcTests.T_MVC_05_ProblemDetailsResult_Properties;
var
  r: TProblemDetailsResult;
begin
  r := TProblemDetailsResult.Create(422, 'Unprocessable Entity',
    'Validation failed', 'https://tools.ietf.org/html/rfc4918#section-11.2', '/orders/1');
  try
    Assert.AreEqual(422, r.Status);
    Assert.AreEqual('Unprocessable Entity', r.Title);
    Assert.AreEqual('Validation failed', r.Detail);
    Assert.AreEqual('https://tools.ietf.org/html/rfc4918#section-11.2', r.&Type);
    Assert.AreEqual('/orders/1', r.Instance);
  finally
    r.Free;
  end;
end;

{ T-MVC-06 }

procedure TMvcTests.T_MVC_06_JsonResult_SerializesObject;
var
  dto: TMvcTestDto;
  r: TJsonResult;
begin
  dto := TMvcTestDto.Create;
  dto.Id := 42;
  dto.Name := 'widget';
  r := TJsonResult.Create(dto, True);
  try
    Assert.IsTrue(r.JsonText <> '', 'JSON output must not be empty');
    Assert.IsTrue(r.JsonText.Contains('42'), 'JSON must contain Id value');
    Assert.IsTrue(r.JsonText.Contains('widget'), 'JSON must contain Name value');
  finally
    r.Free;
    dto.Free;
  end;
end;

{ T-MVC-07 }

procedure TMvcTests.T_MVC_07_ActionNameAttribute_CarriesValue;
var
  attr: ActionName;
begin
  attr := ActionName.Create('MyAction');
  try
    Assert.AreEqual('MyAction', attr.Name);
  finally
    attr.Free;
  end;
end;

{ T-MVC-08 }

procedure TMvcTests.T_MVC_08_VerbAttributes_CarryRoute;
var
  g: HttpGet;
  p: HttpPost;
  u: HttpPut;
  d: HttpDelete;
begin
  g := HttpGet.Create('/api/items');
  p := HttpPost.Create('/api/items');
  u := HttpPut.Create('/api/items/{id}');
  d := HttpDelete.Create('/api/items/{id}');
  try
    Assert.AreEqual('/api/items', g.Route);
    Assert.AreEqual('/api/items', p.Route);
    Assert.AreEqual('/api/items/{id}', u.Route);
    Assert.AreEqual('/api/items/{id}', d.Route);
  finally
    g.Free;
    p.Free;
    u.Free;
    d.Free;
  end;
end;

{ T-MVC-09 }

procedure TMvcTests.T_MVC_09_HttpRoute_PropertyRoundTrip;
var
  route: THttpRoute;
begin
  route := THttpRoute.Create;
  try
    route.URL            := '/api/products';
    route.ActionName     := 'List';
    route.ControllerName := 'Products';
    route.Authorize      := True;
    Assert.AreEqual('/api/products', route.URL);
    Assert.AreEqual('List',          route.ActionName);
    Assert.AreEqual('Products',      route.ControllerName);
    Assert.IsTrue(route.Authorize);
  finally
    route.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TMvcTests);

end.
