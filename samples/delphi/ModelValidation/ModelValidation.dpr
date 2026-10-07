program ModelValidation;

(* ModelValidation Sample - S-34
  Demonstrates attribute-based model validation with QuickCore MVC.

  The TCreateProductRequest DTO is decorated with:
    [Required]        — field must be non-empty
    [StringLength]    — min/max character length
    [Range]           — numeric range check
    [EmailAddress]    — e-mail format check

  TModelValidator.Validate(aModel) runs all checks and returns a TModelState.
  If TModelState.IsValid = False the controller returns HTTP 400 + error JSON.

  Endpoints:
    POST /api/products             — create (validates body first)
    GET  /api/products/validation-rules — describes validation rules

  Example curl — valid request:
    curl -X POST http://localhost:8080/api/products \
         -H "Content-Type: application/json" \
         -d "{\"Name\":\"Laptop\",\"Price\":999.99,\"Stock\":5,\"ContactEmail\":\"shop@example.com\"}"

  Example curl — invalid request (returns 400 with error details):
    curl -X POST http://localhost:8080/api/products \
         -H "Content-Type: application/json" \
         -d "{\"Price\":-5,\"Stock\":99999}"

  .NET equivalent: [Required]/[Range]/[StringLength]/[EmailAddress] data
  annotations + ModelState.IsValid in ASP.NET Core controllers.
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Startup                 in 'Startup.pas',
  Models                  in 'Models.pas',
  Controller.Products     in 'controllers\Controller.Products.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('ModelValidation sample (S-34) on http://localhost:8080 ...', etInfo);
      cout('', ccWhite);
      cout('  POST /api/products            — validated create', ccCyan);
      cout('  GET  /api/products/validation-rules — show rules', ccCyan);
      cout('', ccWhite);
      cout('  Valid:   {"Name":"Laptop","Price":999.99,"Stock":5,"ContactEmail":"x@x.com"}', ccWhite);
      cout('  Invalid: {"Price":-5,"Stock":99999}  → returns HTTP 400', ccYellow);

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
      AppService.DisplayName := 'ModelValidation Sample';
      AppService.ServiceName := 'ModelValidationSvc';
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
