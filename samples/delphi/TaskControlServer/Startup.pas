unit Startup;

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Quick.Core.Mvc.Context,
  Quick.Core.TaskControl,
  Quick.Core.Extensions.MVC.TaskControl,
  TaskControlServer.Config.App,
  TaskControlServer.Controller.Home;

type
  TStartup = class(TStartupBase)
  public
    class procedure ConfigureServices(services : TServiceCollection); override;
    class procedure Configure(app : TMVCServer); override;
  end;

implementation

class procedure TStartup.ConfigureServices(services : TServiceCollection);
begin
  services
    .AddLogging(TLoggerBuilder.GetBuilder//(TLoggerOptionsFormat.ofYAML,False)
        .AddConsole(procedure(aOptions : TLoggerConsoleOptions)
            begin
              aOptions.LogLevel := LOG_DEBUG;
              aOptions.ShowEventColors := True;
              aOptions.ShowTimeStamp := True;
              aOptions.ShowEventType := False;
              aOptions.Enabled := True;
            end)
        .AddFile(procedure(aOptions : TLoggerFileOptions)
            begin
              aOptions.FileName := '.\TaskControlService.log';
              aOptions.MaxFileSizeInMB := 200;
              aOptions.Enabled := True;
            end)
        .Build
    )
    .AddOptions(TOptionsFileFormat.ofJSON,True)
    .Configure<TAppSettings>(procedure(aOptions : TAppSettings)
                                                 begin
                                                   aOptions.Smtp := 'mail.domain.com';
                                                   aOptions.Email := 'info@domain.com';
                                                 end)
    .Extension<TTaskControlServiceExtension>.AddTaskControl;
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .AddController(THomeController)
    //configure routing
    .DefaultRoute(THomeController,'Home/Index')
    .UseWebRoot('.\wwwroot')
    .UseRouting
    .UseMVC
    .Extension<TTaskControlMVCServerExtension>.UseTaskControl;
end;

end.

