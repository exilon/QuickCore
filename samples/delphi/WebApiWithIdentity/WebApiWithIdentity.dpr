program WebApiWithIdentity;

(* WebApiWithIdentity Sample - S-14
  Full Identity system: user registration, password hashing, login validation.
  IUserManager<TAppUser,TAppRole> is injected into TAuthController via DI.
  Users are persisted in SQLite via TIdentityContext.

  .NET equivalent: ASP.NET Core Identity + Entity Framework Core.

  Endpoints:
    POST  http://localhost:8080/auth/register   body: {"UserName":"alice","Email":"a@b.com","Password":"pass123"}
    POST  http://localhost:8080/auth/login      body: {"UserName":"alice","Password":"pass123"}
    GET   http://localhost:8080/auth/users
*)

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  FireDAC.Phys.SQLite,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Quick.Core.Entity.Engine.FireDAC,
  Startup in 'Startup.pas',
  Models in 'Models.pas',
  Controller.Auth in 'controllers\Controller.Auth.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('Starting WebApiWithIdentity on http://localhost:8080 ...', etInfo);
      ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
      try
        ApiServer.UseStartup<TStartup>;
        cout('Identity DB: .\identity.db (SQLite)', ccWhite);
        ApiServer.Start;
      finally
        ApiServer.Free;
      end;
    end
    else
    begin
      AppService.DisplayName := 'WebApi With Identity';
      AppService.ServiceName := 'WebApiWithIdentitySvc';
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
