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
  Infra.Data.DBContext.Shop,
  Infra.Data.Models.Product,
  Infra.Data.Models.Costumer,
  Infra.Data.Identities,
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
   //add entity database
  .Extension<TEntityServiceExtension>
    .AddDBContext<TShopContext>(TDBContextOptionsBuilder.GetBuilder.UseSQLite.ConnectionStringName('ShopContext').Options)
  //add Identity
  .Extension<TAuthenticationServiceExtension>()
    .AddIdentity<TUser,TRole>(procedure(aOptions : TIdentityOptions)
      begin
        aOptions.Password.RequiredLength := 6;
        aOptions.User.RequireUniqueEmail := True;
      end)
    .AddEntityStore<TShopContext>();
  //add Authentication
  services.Extension<TAuthenticationServiceExtension>()
    .AddAuthentication(procedure(aOptions : TAuthenticationOptions)
      begin

      end);
  //add ApiKey Authentication
  services.Extension<TApiKeyAuthenticationServiceExtension>
    .AddApiKey()
      .UseIdentityStore<TUser,TRole>('ApiKey');
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
