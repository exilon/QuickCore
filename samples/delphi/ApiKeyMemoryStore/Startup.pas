unit Startup;

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Entity.Config,
  Quick.Core.Extensions.Caching.Memory,
  Quick.Core.Mvc.Extensions.ResponseCaching,
  Quick.Core.Extensions.Caching.Redis,
  Quick.Core.Extensions.Entity,
  Quick.Core.Extensions.AutoMapper,
  Quick.Core.Logging,
  Quick.Core.Mvc.Context,
  Quick.Core.Identity,
  Quick.Core.Security.Claims,
  Quick.Core.Security.Authorization,
  Quick.Core.Extensions.Authentication,
  Quick.Core.Extensions.Authorization,
  Quick.Core.Extensions.Authentication.ApiKey,
  Controller.Home;

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
   .AddLogging(TLoggerBuilder.GetBuilder(TLoggerOptionsFormat.ofYAML,False)
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
              aOptions.FileName := '.\WebApiServer.log';
              aOptions.MaxFileSizeInMB := 200;
              aOptions.Enabled := True;
            end)
        .Build
    )
  .AddDebugger
  .AddOptions(TOptionsFileFormat.ofYAML,True)
  //add Authentication
  .Extension<TAuthenticationServiceExtension>()
    .AddAuthentication(procedure(aOptions : TAuthenticationOptions)
      begin

      end);
  //add ApiKey Authentication
  services.Extension<TApiKeyAuthenticationServiceExtension>
    .AddApiKey()
      .UseMemoryStore(procedure(aOptions : TApiKeyMemoryStoreOptions)
        begin
          aOptions.AddApiKey('John','Admin','fkjsfVMfskdfkaiienvz23k12nfaadfavbkx');
          aOptions.AddApiKey('Peter','User','mmvkasffoasd034jadsfkvnaaj3bfajxcfh');
        end);
  //add Authorization
  services.Extension<TAuthorizationServiceExtension>
    .AddAuthorization(procedure(aOptions : TAuthorizationOptions)
      begin
        aOptions.AddPolicy('ApiKeyValidation',TAuthorizationPolicyBuilder.GetBuilder
          .RequireAuthenticatedUser.Build
          //.RequireClaim(TClaimTypes.Role,'Admin').Build
        );
      end);
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
  .AddControllers
  .AddController(THomeController)
  .DefaultRoute(THomeController,'Home/Index')
  .UseWebRoot('.\wwwroot')
  .UseStaticFiles
  .UseRouting
  .UseAuthentication
  .UseAuthorization
  .UseMustachePages
  .UseMVC;
end;

end.
