program WebApiWithAutoMapper;

(* WebApiWithAutoMapper Sample - S-10
  REST API where DTOs are mapped to/from domain entities via IMapper (AutoMapper).
  The controller receives a DTO [FromBody], maps it to an entity, and returns a DTO.

  .NET equivalent: AutoMapper + ASP.NET Core.

  Endpoints:
    GET  http://localhost:8080/api/users
    POST http://localhost:8080/api/users   body: {"Username":"alice","Email":"alice@example.com"}
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
  Controller.Users in 'controllers\Controller.Users.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('Starting WebApiWithAutoMapper on http://localhost:8080 ...', etInfo);
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
      AppService.DisplayName := 'WebApi With AutoMapper';
      AppService.ServiceName := 'WebApiWithAutoMapperSvc';
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
