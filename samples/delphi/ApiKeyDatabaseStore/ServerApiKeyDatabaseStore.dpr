program ServerApiKeyDatabaseStore;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Controller.Home in 'controllers\Controller.Home.pas',
  Startup in 'Startup.pas',
  Infra.Data.DBContext.Shop in 'infrastructure\Infra.Data.DBContext.Shop.pas',
  Infra.Data.Models.Costumer in 'infrastructure\Infra.Data.Models.Costumer.pas',
  Infra.Data.Models.Product in 'infrastructure\Infra.Data.Models.Product.pas',
  Controller.Products in 'controllers\Controller.Products.pas',
  Infra.Data.Identities in 'infrastructure\Identities\Infra.Data.Identities.pas';

var
  ApiServer : TMvcServer;

begin
  try
    ReportMemoryLeaksOnShutdown := True;
    //run as console
    if not AppService.IsRunningAsService then
    begin
      //create server
      cout('Init server...',etInfo);
      ApiServer := TMvcServer.Create('127.0.0.1',8080,False);
      try
        ApiServer.UseStartup<TStartup>;
        ApiServer.Start;
        //Wait for Exit
        cout(' ',ccWhite);
        cout('Press [Enter] to quit',ccYellow);
        ConsoleWaitForEnterKey;
      finally
        ApiServer.Free;
      end;
    end
    else //run as a service
    begin
      AppService.DisplayName := 'Quick Server';
      AppService.ServiceName := 'QuickServerSvc';
      AppService.CanInstallWithOtherName := True;
      AppService.OnStart := procedure
                               begin
                                 ApiServer := TMvcServer.Create('127.0.0.1',8080,False);
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
