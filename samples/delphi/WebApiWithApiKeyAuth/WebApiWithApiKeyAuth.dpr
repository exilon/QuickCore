program WebApiWithApiKeyAuth;

(* WebApiWithApiKeyAuth Sample - S-13
  REST API secured with API Key authentication.
  - Two keys pre-registered: one with "Admin" role, one with "User" role.
  - All endpoints require authentication ([Authorize]).
  - Admin-only endpoint uses [Authorize(Policy='AdminOnly')].
  - Public endpoint uses [AllowAnonymous].

  .NET equivalent: Custom API Key middleware + policy-based authorization.

  Usage:
    Authorized:  curl -H "X-API-Key: admin-key-abc123" http://localhost:8080/api/products
    Forbidden:   curl -H "X-API-Key: user-key-xyz789" http://localhost:8080/api/products/admin
    Anonymous:   curl http://localhost:8080/api/products/public
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Controller.Products in 'controllers\Controller.Products.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('Starting WebApiWithApiKeyAuth on http://localhost:8080 ...', etInfo);
      cout('Admin key : admin-key-abc123', ccWhite);
      cout('User key  : user-key-xyz789', ccWhite);
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
      AppService.DisplayName := 'WebApi With ApiKey Auth';
      AppService.ServiceName := 'WebApiWithApiKeyAuthSvc';
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
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
