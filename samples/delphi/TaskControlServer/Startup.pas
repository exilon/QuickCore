unit Startup;

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Quick.Core.Mvc.Context,
  Quick.Core.TaskControl,
  Quick.Core.Mvc.Extensions.TaskControl,
  TaskControlServer.Config.App,
  TaskControlServer.Controller.Home;

type
  TStartup = class(TStartupMvc)
  public
    class procedure ConfigureServices(services : TServiceCollection); override;
    class procedure Configure(app : TMVCServer); override;
  end;

implementation

class procedure TStartup.ConfigureServices(services : TServiceCollection);
begin
  services
    .AddLogging(TLoggerBuilder.GetBuilder//(TLoggerOptionsFormat.ofYAML,False)
        .AddConsole(procedure(aOptions : TConsoleLoggerOptions)
            begin
              aOptions.LogLevel := LOG_DEBUG;
              aOptions.ShowEventColors := True;
              aOptions.ShowTimeStamp := True;
              aOptions.ShowEventType := False;
              aOptions.Enabled := True;
            end)
        .AddFile(procedure(aOptions : TFileLoggerOptions)
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
    //configure routing
    .DefaultRoute(THomeController,'Home/Index')
    .UseWebRoot('.\wwwroot')
    .UseSwagger('TaskControlServer API', '1.0.0',
      'QuickCore TaskControlServer sample API.')
    .UseRouting
    .UseMVC
    .Extension<TTaskControlMVCServerExtension>.UseTaskControl;
end;

end.

