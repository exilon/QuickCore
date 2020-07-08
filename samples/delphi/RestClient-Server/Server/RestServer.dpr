program RestServer;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.DependencyInjection in '..\..\..\..\Quick.Core.DependencyInjection.pas',
  Quick.Core.Extensions.Caching.Memory in '..\..\..\..\Quick.Core.Extensions.Caching.Memory.pas',
  Quick.Core.Mvc in '..\..\..\..\Quick.Core.Mvc.pas',
  Quick.Core.Entity in '..\..\..\..\Quick.Core.Entity.pas',
  Quick.Core.Serializer in '..\..\..\..\Quick.Core.Serializer.pas',
  Quick.Core.Mvc.Routing in '..\..\..\..\Quick.Core.Mvc.Routing.pas',
  Quick.Core.Mvc.WebApi in '..\..\..\..\Quick.Core.Mvc.WebApi.pas',
  Quick.Core.Mvc.ActionInvoker in '..\..\..\..\Quick.Core.Mvc.ActionInvoker.pas',
  Quick.Core.Mvc.ActionResult in '..\..\..\..\Quick.Core.Mvc.ActionResult.pas',
  Quick.Core.Mvc.Context in '..\..\..\..\Quick.Core.Mvc.Context.pas',
  Quick.Core.Mvc.Controller in '..\..\..\..\Quick.Core.Mvc.Controller.pas',
  Quick.Core.Mvc.Factory.Controller in '..\..\..\..\Quick.Core.Mvc.Factory.Controller.pas',
  Quick.Core.Mvc.Middleware.Cache in '..\..\..\..\Quick.Core.Mvc.Middleware.Cache.pas',
  Quick.Core.Mvc.Middleware.Hsts in '..\..\..\..\Quick.Core.Mvc.Middleware.Hsts.pas',
  Quick.Core.Mvc.Middleware.MVC in '..\..\..\..\Quick.Core.Mvc.Middleware.MVC.pas',
  Quick.Core.Mvc.Middleware in '..\..\..\..\Quick.Core.Mvc.Middleware.pas',
  Quick.Core.Mvc.Middleware.Routing in '..\..\..\..\Quick.Core.Mvc.Middleware.Routing.pas',
  Quick.Core.Mvc.Middleware.StaticFiles in '..\..\..\..\Quick.Core.Mvc.Middleware.StaticFiles.pas',
  Quick.Core.Mvc.ViewFeatures in '..\..\..\..\Quick.Core.Mvc.ViewFeatures.pas',
  Quick.Core.Logging in '..\..\..\..\Quick.Core.Logging.pas',
  Quick.Core.Extensions.Entity in '..\..\..\..\Quick.Core.Extensions.Entity.pas',
  Quick.Core.Extensions.AutoMapper in '..\..\..\..\Quick.Core.Extensions.AutoMapper.pas',
  Startup in '..\..\ApiServer\source\Startup.pas',
  Infra.Config.App in '..\..\ApiServer\source\Infrastructure\Config\Infra.Config.App.pas',
  Infra.Data.DBContext.Shop in '..\..\ApiServer\source\Infrastructure\DataModel\Infra.Data.DBContext.Shop.pas',
  Infra.Data.Models.Costumer in '..\..\ApiServer\source\Infrastructure\DataModel\Infra.Data.Models.Costumer.pas',
  Infra.Data.Models.Product in '..\..\ApiServer\source\Infrastructure\DataModel\Infra.Data.Models.Product.pas',
  UI.Controller.Home in '..\..\ApiServer\source\UI\Controllers\UI.Controller.Home.pas',
  UI.Controller.Products in '..\..\ApiServer\source\UI\Controllers\UI.Controller.Products.pas',
  UI.Controller.Test in '..\..\ApiServer\source\UI\Controllers\UI.Controller.Test.pas',
  Quick.Core.Mvc.ViewEngine.Mustache in '..\..\..\..\Quick.Core.Mvc.ViewEngine.Mustache.pas',
  Quick.Core.Mvc.Session in '..\..\..\..\Quick.Core.Mvc.Session.pas',
  Quick.Core.Mvc.Middleware.HttpsRedirection in '..\..\..\..\Quick.Core.Mvc.Middleware.HttpsRedirection.pas',
  Quick.Core.Caching.Abstractions in '..\..\..\..\Quick.Core.Caching.Abstractions.pas',
  Quick.Core.Logging.Abstractions in '..\..\..\..\Quick.Core.Logging.Abstractions.pas',
  Quick.Core.Extensions.Caching.Redis in '..\..\..\..\Quick.Core.Extensions.Caching.Redis.pas',
  Infra.Data.Mappings in '..\..\ApiServer\source\Infrastructure\Mappings\Infra.Data.Mappings.pas',
  Domain.Models.Product in '..\..\ApiServer\source\Domain\Domain.Models.Product.pas',
  Quick.Core.Identity in '..\..\..\..\Quick.Core.Identity.pas',
  Quick.Core.Security.Claims in '..\..\..\..\Quick.Core.Security.Claims.pas',
  Quick.Core.Extensions.Authorization in '..\..\..\..\Quick.Core.Extensions.Authorization.pas',
  Quick.Core.Mvc.Middleware.Authorization in '..\..\..\..\Quick.Core.Mvc.Middleware.Authorization.pas',
  Quick.Core.Security.Authorization in '..\..\..\..\Quick.Core.Security.Authorization.pas',
  Quick.Core.Security.Authentication in '..\..\..\..\Quick.Core.Security.Authentication.pas',
  Quick.Core.Mvc.Middleware.Authentication in '..\..\..\..\Quick.Core.Mvc.Middleware.Authentication.pas',
  Quick.Core.Extensions.Authentication in '..\..\..\..\Quick.Core.Extensions.Authentication.pas',
  Quick.Core.Security.UserManager in '..\..\..\..\Quick.Core.Security.UserManager.pas',
  Quick.Core.Identity.Store.Abstractions in '..\..\..\..\Quick.Core.Identity.Store.Abstractions.pas',
  Quick.Core.Identity.Store.Entity in '..\..\..\..\Quick.Core.Identity.Store.Entity.pas',
  Quick.Core.Linq.Abstractions in '..\..\..\..\Quick.Core.Linq.Abstractions.pas',
  Infra.Data.Identities in '..\..\ApiServer\source\Infrastructure\DataModel\Identities\Infra.Data.Identities.pas',
  UI.Controller.Login in '..\..\ApiServer\source\UI\Controllers\UI.Controller.Login.pas',
  Quick.Core.Extensions.Authentication.ApiKey in '..\..\..\..\Quick.Core.Extensions.Authentication.ApiKey.pas',
  Quick.Core.Entity.Config in '..\..\..\..\Quick.Core.Entity.Config.pas',
  Quick.Core.Entity.DAO in '..\..\..\..\Quick.Core.Entity.DAO.pas',
  Quick.Core.Entity.Database in '..\..\..\..\Quick.Core.Entity.Database.pas',
  Quick.Core.Entity.Engine.ADO in '..\..\..\..\Quick.Core.Entity.Engine.ADO.pas',
  Quick.Core.Entity.Engine.FireDAC in '..\..\..\..\Quick.Core.Entity.Engine.FireDAC.pas',
  Quick.Core.Entity.Engine.RestServer in '..\..\..\..\Quick.Core.Entity.Engine.RestServer.pas',
  Quick.Core.Entity.Factory.Database in '..\..\..\..\Quick.Core.Entity.Factory.Database.pas',
  Quick.Core.Entity.Factory.QueryGenerator in '..\..\..\..\Quick.Core.Entity.Factory.QueryGenerator.pas',
  Quick.Core.Mvc.Extensions.ResponseCaching in '..\..\..\..\Quick.Core.Mvc.Extensions.ResponseCaching.pas';

var
  ApiServer : TWebApiServer;

begin
  try
    ReportMemoryLeaksOnShutdown := True;
    //run as console
    if not AppService.IsRunningAsService then
    begin
      //create server
      cout('Init server...',etInfo);
      ApiServer := TWebApiServer.Create('127.0.0.1',8080,False);
      //add dependency services
      //ApiServer.Services.ConfigureServices(RegisterServices);
      //register application
      //ApiServer.ConfigureApp(RegisterServer);
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
      AppService.DisplayName := 'Remote Server';
      AppService.ServiceName := 'RemoteServerSvc';
      AppService.CanInstallWithOtherName := True;
      AppService.OnStart := procedure
                               begin
                                 ApiServer := TWebApiServer.Create('127.0.0.1',8080,False);
                                 //register service dependencies
                                 //ApiServer.Services.ConfigureServices(RegisterServices);
                                 //register application
                                 //ApiServer.ConfigureApp(RegisterServer);
                                 ApiServer.UseStartup<TStartup>;
                               end;
      //AppService.OnStop := ApiServer.Free;
      AppService.OnExecute := ApiServer.Start;
      AppService.CheckParams;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
