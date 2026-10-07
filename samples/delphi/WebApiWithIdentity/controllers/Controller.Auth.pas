unit Controller.Auth;

{ WebApiWithIdentity Sample - S-14
  Register + Login + list users. }

interface

uses
  System.SysUtils,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Security.UserManager,
  Models;

type
  {$M+}
  TRegisterRequest = class
  private
    FUserName : string;
    FEmail    : string;
    FPassword : string;
  published
    property UserName : string read FUserName write FUserName;
    property Email    : string read FEmail    write FEmail;
    property Password : string read FPassword write FPassword;
  end;

  TLoginRequest = class
  private
    FUserName : string;
    FPassword : string;
  published
    property UserName : string read FUserName write FUserName;
    property Password : string read FPassword write FPassword;
  end;
  {$M-}

  [Route('auth')]
  [ApiController]
  TAuthController = class(THttpController)
  private
    fUserManager : IUserManager<TAppUser, TAppRole>;
  public
    constructor Create(aUserManager : IUserManager<TAppUser, TAppRole>);
  published
    [HttpPost('register')]
    function Register([FromBody] body : TRegisterRequest) : IActionResult;

    [HttpPost('login')]
    function Login([FromBody] body : TLoginRequest) : IActionResult;

    [HttpGet('users')]
    function ListUsers : IActionResult;
  end;

implementation

uses
  Quick.JsonSerializer;

{ TAuthController }

constructor TAuthController.Create(aUserManager : IUserManager<TAppUser, TAppRole>);
begin
  inherited Create;
  fUserManager := aUserManager;
end;

function TAuthController.Register(body : TRegisterRequest): IActionResult;
var
  user     : TAppUser;
  existing : TAppUser;
begin
  existing := fUserManager.FindByName(body.UserName);
  if Assigned(existing) then
  begin
    existing.Free;
    Result := StatusCode(409, '{"error":"Username already taken"}');
    Exit;
  end;

  user          := TAppUser.Create;
  user.UserName := body.UserName;
  user.Email    := body.Email;
  user.PasswordHash := body.Password;
  fUserManager.AddUser(user);
  try
    Result := StatusCode(201, Format('{"id":%d,"userName":"%s","email":"%s"}', [Int64(user.Id), user.UserName, user.Email]));
  finally
    user.Free;
  end;
end;

function TAuthController.Login(body : TLoginRequest): IActionResult;
begin
  if fUserManager.ValidateCredentials(body.UserName, body.Password) then
    Result := Json(Format('{"success":true,"user":"%s"}', [body.UserName]))
  else
    Result := StatusCode(401, '{"error":"Invalid credentials"}');
end;

function TAuthController.ListUsers: IActionResult;
var
  arr : TArray<TAppUser>;
  sb  : TStringBuilder;
  i   : Integer;
  u   : TAppUser;
begin
  arr := fUserManager.Users.SelectTop(MaxInt).ToArray;
  sb  := TStringBuilder.Create;
  try
    sb.Append('[');
    for i := 0 to High(arr) do
    begin
      if i > 0 then sb.Append(',');
      u := arr[i];
      sb.AppendFormat('{"id":%d,"userName":"%s","email":"%s"}',
        [u.Id, u.UserName, u.Email]);
    end;
    sb.Append(']');
    Result := Json(sb.ToString);
  finally
    sb.Free;
  end;
end;

initialization
  RegisterController(TAuthController);

end.
