unit Startup;

{ WebApiWithApiKeyAuth Sample - S-13 }

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Quick.Core.Extensions.Authentication,
  Quick.Core.Extensions.Authentication.ApiKey,
  Quick.Core.Extensions.Authorization,
  Quick.Core.Security.Authorization,
  Controller.Products;

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
  services
    .AddLogging(TLoggerBuilder.GetBuilder
      .AddConsole(procedure(o : TConsoleLoggerOptions)
        begin
          o.LogLevel        := LOG_DEBUG;
          o.ShowEventColors := True;
          o.ShowTimeStamp   := True;
          o.ShowEventType   := False;
          o.Enabled         := True;
        end)
      .Build)
    // 1. Add core Authentication infrastructure
    .Extension<TAuthenticationServiceExtension>
      .AddAuthentication(procedure(o : TAuthenticationOptions)
        begin
          // default scheme will be set by AddApiKey
        end);

  // 2. Register API Keys: Name, Role, Key
  services.Extension<TApiKeyAuthenticationServiceExtension>
    .AddApiKey
      .UseMemoryStore(procedure(o : TApiKeyMemoryStoreOptions)
        begin
          o.AddApiKey('Alice', 'Admin', 'admin-key-abc123');
          o.AddApiKey('Bob',   'User',  'user-key-xyz789');
        end);

  // 3. Authorization policies
  services.Extension<TAuthorizationServiceExtension>
    .AddAuthorization(procedure(o : TAuthorizationOptions)
      begin
        // Any authenticated caller
        o.AddPolicy('Authenticated',
          TAuthorizationPolicyBuilder.GetBuilder
            .RequireAuthenticatedUser
            .Build);
        // Admin-only
        o.AddPolicy('AdminOnly',
          TAuthorizationPolicyBuilder.GetBuilder
            .RequireAuthenticatedUser
            .RequireClaim('role', 'Admin')
            .Build);
      end);
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .UseSwagger('WebApiWithApiKeyAuth API', '1.0.0',
      'QuickCore WebApiWithApiKeyAuth sample API.')
    .UseRouting
    .UseAuthentication
    .UseAuthorization
    .UseMVC;
end;

end.
