program WebApiService;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.Core.Mvc,
  Quick.Core.Mvc.WebApi,
  Quick.Core.Mvc.Extensions.Service,
  Startup in 'Startup.pas',
  Infra.Data.Identities in 'Infrastructure\DataModel\Identities\Infra.Data.Identities.pas',
  Infra.Config.App in 'Infrastructure\Config\Infra.Config.App.pas',
  Infra.Data.DBContext.Shop in 'Infrastructure\DataModel\Infra.Data.DBContext.Shop.pas',
  Infra.Data.Models.Costumer in 'Infrastructure\DataModel\Infra.Data.Models.Costumer.pas',
  Infra.Data.Models.Product in 'Infrastructure\DataModel\Infra.Data.Models.Product.pas',
  UI.Controller.Home in 'UI\Controllers\UI.Controller.Home.pas',
  UI.Controller.Products in 'UI\Controllers\UI.Controller.Products.pas',
  UI.Controller.Test in 'UI\Controllers\UI.Controller.Test.pas',
  Infra.Data.Mappings in 'Infrastructure\Mappings\Infra.Data.Mappings.pas',
  Domain.Models.Product in 'Domain\Domain.Models.Product.pas',
  UI.Controller.Login in 'UI\Controllers\UI.Controller.Login.pas',
  UI.Controller.Flakey in 'UI\Controllers\UI.Controller.Flakey.pas';

var
  ApiServer : TWebApiServer;

begin
  if IsDebug then ReportMemoryLeaksOnShutdown := True;
  try
    ReportMemoryLeaksOnShutdown := True;

    ApiServer := TWebApiServer.Create('0.0.0.0',8081,False);
    ApiServer.UseStartup<TStartup>;
    ApiServer.UseWindowsService(procedure(aOptions : TWindowsCoreServiceOptions)
                                begin
                                  aOptions.ServiceName := 'ApiServerSvc';
                                  aOptions.DisplayName := 'ApiServer';
                                  aOptions.Description := 'ApiServer';
                                  aOptions.CanInstallWithOtherName := True;
                                end);
    ApiServer.UseSystemd('ApiServer');
    ApiServer.Start;
    ApiServer.Free;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
