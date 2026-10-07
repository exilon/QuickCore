unit UI.Controller.Login;

interface

uses
  System.SysUtils,
  Quick.HttpServer.Types,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Commons,
  Quick.Core.Security.UserManager,
  Infra.Data.Identities;

type
  [Route('Login')]
  TAuthController = class(THttpController)
  private
    fUserManager : IUserManager<TUser,TRole>;
  public
    constructor Create(aUserManager : IUserManager<TUser,TRole>);
  published
    [HttpGet('{username}/{password}')]
    function Login(const UserName, Password : string) : IActionResult;

    [HttpPost('{username}/{password}')]
    function SaveUser(const UserName, Password : string) : IActionResult;
  end;

implementation

{ TAuthController }

constructor TAuthController.Create(aUserManager: IUserManager<TUser,TRole>);
begin
  fUserManager := aUserManager;
end;

function TAuthController.Login(const UserName, Password : string) : IActionResult;
begin
  ViewData['company'] := 'Exilon Soft';
  ViewData['name'] := 'Kike';
  ViewData['core'] := 'Quick Core MVC Framework';
  ViewData['product'] := 'T-Shirt';
  ViewData['colour'] :=  'Blue';
  ViewData['price'] := 28.9;
  if fUserManager.Users.Where('UserName = ?',[UserName]).Count > 0 then Result := Content('User found!')
    else Result := NotFound('User not found!');
  //Result := View;
end;

function TAuthController.SaveUser(const UserName, Password: string): IActionResult;
var
  user : TUser;
begin
  user := TUser.Create;
  user.UserName := UserName;
  user.PasswordHash := Password;
  fUserManager.AddUser(user);
end;

initialization
  RegisterController(TAuthController);

end.
