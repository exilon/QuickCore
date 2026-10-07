program WebApiWithJwt;

(* WebApiWithJwt Sample - S-27
  REST API secured with JWT Bearer authentication.

  Credentials (hardcoded for demo):
    admin / admin123  → role: Admin
    user  / user123   → role: User

  Flow:
    1. POST /api/auth/login   {"userName":"admin","password":"admin123"}
       → {"token":"<jwt>","userName":"admin","role":"Admin","expiresIn":3600}
    2. GET  /api/products        Authorization: Bearer <token>
       → product list (any authenticated user)
    3. GET  /api/products/admin  Authorization: Bearer <admin-token>
       → admin panel (Admin role required; User gets 403)
    4. GET  /api/auth/me         Authorization: Bearer <token>
       → {"userName":"admin","role":"Admin","isAuthenticated":true}

  .NET equivalent: AddJwtBearer + [Authorize] + policy-based authorization.
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Models in 'Models.pas',
  Controller.Auth     in 'controllers\Controller.Auth.pas',
  Controller.Products in 'controllers\Controller.Products.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('WebApiWithJwt sample (S-27) starting on http://localhost:8080 ...', etInfo);
      cout('', ccWhite);
      cout('  Step 1 — Get a token:', ccCyan);
      cout('    curl -s -X POST http://localhost:8080/api/auth/login ^', ccWhite);
      cout('         -H "Content-Type: application/json" ^', ccWhite);
      cout('         -d "{\"userName\":\"admin\",\"password\":\"admin123\"}"', ccWhite);
      cout('', ccWhite);
      cout('  Step 2 — Use the token:', ccCyan);
      cout('    curl -H "Authorization: Bearer <token>" http://localhost:8080/api/products', ccWhite);
      cout('    curl -H "Authorization: Bearer <token>" http://localhost:8080/api/products/admin', ccWhite);
      cout('    curl -H "Authorization: Bearer <token>" http://localhost:8080/api/auth/me', ccWhite);
      cout('', ccWhite);
      cout('  Users: admin/admin123 (Admin)  |  user/user123 (User)', ccYellow);

      ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
      try
        ApiServer.UseStartup<TStartup>;
        ApiServer.Start;
      finally
        ApiServer.Free;
      end;
    end
    else
    begin
      AppService.DisplayName := 'WebApi With JWT Auth';
      AppService.ServiceName := 'WebApiWithJwtSvc';
      AppService.CanInstallWithOtherName := True;
      AppService.OnStart := procedure
        begin
          ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
          ApiServer.UseStartup<TStartup>;
        end;
      AppService.OnExecute := ApiServer.Start;
      AppService.CheckParams;
    end;
  except
    on E : Exception do
    begin
      cout('Fatal: ' + E.Message, etError);
      ExitCode := 1;
    end;
  end;
end.
