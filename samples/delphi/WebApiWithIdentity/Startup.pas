unit Startup;

{ WebApiWithIdentity Sample - S-14 }

interface

uses
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Quick.Core.Extensions.Entity,
  Quick.Core.Entity.Config,
  Quick.Core.Extensions.Authentication,
  Quick.Core.Identity,
  Models,
  Controller.Auth;

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
          o.Enabled         := True;
        end)
      .Build)
    .AddOptions(TOptionsFileFormat.ofJSON, True)
    // 1. Add SQLite DBContext for identity tables
    .Extension<TEntityServiceExtension>
      .AddDBContext<TIdentityContext>(procedure(o : IDBConnectionOptions)
        begin
          o.UseSQLite;
          o.Database := '.\identity.db';
        end)
    // 2. Add Identity with entity store backed by TIdentityContext
    .Extension<TAuthenticationServiceExtension>
      .AddIdentity<TAppUser, TAppRole>(procedure(o : TIdentityOptions)
        begin
          o.Password.RequiredLength      := 6;
          o.Password.RequireDigit        := True;
          o.Password.RequireUppercase    := False;
          o.Password.RequireNonAlphanumeric := False;
        end)
      .AddEntityStore<TIdentityContext>;
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    .UseSwagger('WebApiWithIdentity API', '1.0.0',
      'QuickCore WebApiWithIdentity sample API.')
    .UseRouting
    .UseMVC;
end;

end.
