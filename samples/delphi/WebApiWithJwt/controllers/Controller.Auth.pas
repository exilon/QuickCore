unit Controller.Auth;

{ WebApiWithJwt Sample - S-27
  Auth controller: POST /api/auth/login returns a JWT token.
                   GET  /api/auth/me    returns claims from the current token. }

interface

uses
  System.SysUtils,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Security.Jwt,
  Quick.Core.Security.Claims,
  Quick.Core.Extensions.Authentication.Jwt,
  Models;

type
  [Route('api/auth')]
  [ApiController]
  TAuthController = class(THttpController)
  private
    fJwtService : IJwtTokenService;
    // In-memory user store (no DB needed for this sample)
    function TryGetUser(const aUserName, aPassword : string;
                        out aRole : string) : Boolean;
  public
    constructor Create(aJwtService : IJwtTokenService);
  published
    /// POST /api/auth/login
    /// Body: {"userName":"admin","password":"admin123"}
    [HttpPost('login')]
    function Login([FromBody] body : TLoginRequest) : IActionResult;

    /// GET /api/auth/me  (requires valid JWT)
    [HttpGet('me')]
    [Authorize]
    function Me : IActionResult;
  end;

implementation

uses
  Quick.JsonSerializer;

{ TAuthController }

constructor TAuthController.Create(aJwtService : IJwtTokenService);
begin
  inherited Create;
  fJwtService := aJwtService;
end;

function TAuthController.TryGetUser(const aUserName, aPassword : string;
                                    out aRole : string) : Boolean;
begin
  // Hardcoded credentials — replace with a real user store in production
  Result := True;
  if SameText(aUserName, 'admin') and (aPassword = 'admin123') then
    aRole := 'Admin'
  else if SameText(aUserName, 'user') and (aPassword = 'user123') then
    aRole := 'User'
  else
    Result := False;
end;

function TAuthController.Login(body : TLoginRequest) : IActionResult;
var
  role      : string;
  identity  : TClaimsIdentity;
  principal : TClaimsPrincipal;
  token     : string;
begin
  if body = nil then
  begin
    Result := BadRequest('{"error":"Request body is required"}');
    Exit;
  end;

  if not TryGetUser(body.UserName, body.Password, role) then
  begin
    Result := StatusCode(401, '{"error":"Invalid username or password"}');
    Exit;
  end;

  // Build claims principal
  identity := TClaimsIdentity.Create;
  identity.AuthenticationType := JwtBearerDefaults_AuthenticationScheme;
  identity.AddClaim(TClaim.Create(TClaimTypes.Name,  body.UserName));
  identity.AddClaim(TClaim.Create(TClaimTypes.Role,  role));
  identity.AddClaim(TClaim.Create('userName',        body.UserName));

  principal := TClaimsPrincipal.Create(identity);
  try
    token := fJwtService.GenerateToken(principal);
  finally
    principal.Free;
  end;

  Result := Json(Format(
    '{"token":"%s","userName":"%s","role":"%s","expiresIn":3600}',
    [token, body.UserName, role]));
end;

function TAuthController.Me : IActionResult;
var
  user, role : string;
begin
  user := HttpContext.User.Identity.Name;
  role := HttpContext.User.FindFirst(
    function(c : TClaim) : Boolean
    begin
      Result := c.&Type = TClaimTypes.Role;
    end).Value;

  Result := Json(Format(
    '{"userName":"%s","role":"%s","isAuthenticated":%s}',
    [user, role, BoolToStr(HttpContext.User.Identity.IsAuthenticated, True).ToLower]));
end;

initialization
  RegisterController(TAuthController);

end.
