program FileUpload;

(* FileUpload Sample - S-31
  Demonstrates multipart/form-data file upload with QuickCore MVC.

  POST /api/upload
    Upload a file (multipart/form-data, field name "file").
    Returns JSON with fileName, size, contentType, savedTo.

  GET  /api/upload/list
    Returns JSON array of previously uploaded files.

  Example curl:
    curl -X POST http://localhost:8080/api/upload \
         -F "file=@/path/to/photo.jpg"

    curl http://localhost:8080/api/upload/list

  .NET equivalent: IFormFile / [FromForm] binding in ASP.NET Core.
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Startup              in 'Startup.pas',
  Controller.Upload    in 'controllers\Controller.Upload.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('FileUpload sample (S-31) on http://localhost:8080 ...', etInfo);
      cout('', ccWhite);
      cout('  POST /api/upload         — upload a file', ccCyan);
      cout('    curl -X POST http://localhost:8080/api/upload -F "file=@./photo.jpg"', ccWhite);
      cout('', ccWhite);
      cout('  GET  /api/upload/list    — list uploaded files', ccCyan);
      cout('    curl http://localhost:8080/api/upload/list', ccWhite);

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
      AppService.DisplayName := 'FileUpload Sample';
      AppService.ServiceName := 'FileUploadSvc';
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
