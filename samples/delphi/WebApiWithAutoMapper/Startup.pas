unit Startup;

{ WebApiWithAutoMapper Sample - S-10 }

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Quick.Core.AutoMapper,
  Quick.Core.Extensions.AutoMapper,
  Controller.Users,
  Models;

type
  TStartup = class(TStartupMvc)
  public
    class procedure ConfigureServices(services : TServiceCollection); override;
    class procedure Configure(app : TMVCServer); override;
  end;

implementation

{ TStartup }

class procedure TStartup.ConfigureServices(services : TServiceCollection);
begin
  TAutoMapper.RegisterProfile<TUserProfile>;
  services
    .AddLogging(TLoggerBuilder.GetBuilder
      .AddConsole(procedure(o : TConsoleLoggerOptions)
        begin
          o.LogLevel        := LOG_DEBUG;
          o.ShowEventColors := True;
          o.ShowTimeStamp   := True;
          o.Enabled         := True;
        end)
      .Build)
    .Extension<TAutoMapperServiceExtension>
      .AddAutoMapper;
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .UseSwagger('WebApiWithAutoMapper API', '1.0.0',
      'QuickCore WebApiWithAutoMapper sample API.')
    .UseRouting
    .UseMVC;
end;

end.
