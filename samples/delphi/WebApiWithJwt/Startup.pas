unit Startup;

{ WebApiWithJwt Sample - S-27 }

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Quick.Core.Extensions.Authentication,
  Quick.Core.Extensions.Authentication.Jwt,
  Quick.Core.Extensions.Authorization,
  Quick.Core.Security.Authorization,
  Quick.Core.Security.Claims,
  Quick.Core.Security.Jwt,
  Controller.Auth,
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
    .AddOptions()
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
    // 1. Add authentication infrastructure + JWT Bearer scheme
    .Extension<TAuthenticationServiceExtension>
      .AddAuthentication(procedure(o : TAuthenticationOptions)
        begin
          // default scheme set automatically by AddJwtBearer
        end);

  services.Extension<TJwtBearerServiceExtension>
    .AddJwtBearer(procedure(o : TJwtOptions)
      begin
        o.Secret           := 'super-secret-key-change-in-production-32chars!';
        o.Issuer           := 'QuickCore';
        o.Audience         := 'QuickCoreClients';
        o.ExpiryMinutes    := 60;
        o.ValidateIssuer   := True;
        o.ValidateAudience := False;
        o.ValidateLifetime := True;
      end);

  // 2. Authorization policies
  services.Extension<TAuthorizationServiceExtension>
    .AddAuthorization(procedure(o : TAuthorizationOptions)
      begin
        o.AddPolicy('AdminOnly',
          TAuthorizationPolicyBuilder.GetBuilder
            .RequireAuthenticatedUser
            .RequireClaim(TClaimTypes.Role, 'Admin')
            .Build);
      end);
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .UseSwagger('WebApiWithJwt API', '1.0.0',
      'QuickCore WebApiWithJwt sample API.')
    .UseRouting
    .UseAuthentication
    .UseAuthorization
    .UseMVC;
end;

end.
