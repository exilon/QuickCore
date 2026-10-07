unit Startup;

interface

uses
  System.TimeSpan,
  Quick.Core.Mvc,
  Quick.Core.DependencyInjection,
  Quick.Core.Entity.Config,
  Infra.Data.DBContext.Shop,
  Quick.Core.Extensions.Caching.Memory,
  Quick.Core.Mvc.Extensions.ResponseCaching,
  Quick.Core.Extensions.Caching.Redis,
  Quick.Core.Extensions.Entity,
  Quick.Core.Extensions.AutoMapper,
  Quick.Core.Logging,
  Infra.Config.App,
  Quick.Core.Mvc.Context,
  Quick.Core.Identity,
  Quick.Core.Security.Claims,
  Quick.Core.Security.Authorization,
  Quick.Core.Extensions.Authentication,
  Quick.Core.Extensions.Authorization,
  Quick.Core.Extensions.Authentication.ApiKey,
  Quick.Core.Extensions.HealthChecks,
  Quick.Core.Extensions.HealthChecks.Entity,
  Quick.Core.Extensions.HealthChecks.Redis,
  Quick.Core.Mvc.Extensions.HealthChecks,
  Quick.Core.Mvc.Middleware.HealthChecksUI,
  UI.Controller.Home,
  UI.Controller.Test,
  Infra.Data.Identities,
  Infra.Data.Mappings;

type
  TStartup = class(TStartupMvc)
  public
    class procedure ConfigureServices(services : TServiceCollection); override;
    class procedure Configure(app : TMVCServer); override;
  end;

implementation

uses
  System.SysUtils,
  Quick.HttpServer.Response;

class procedure TStartup.ConfigureServices(services : TServiceCollection);
begin
  //add Logging
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
              aOptions.FileName := './WebApiServer.log';
              aOptions.MaxFileSizeInMB := 200;
              aOptions.Enabled := True;
            end)
        .AddRedis(procedure(aOptions : TRedisLoggerOptions)
            begin
              aOptions.LogLevel := LOG_DEBUG;
              aOptions.Host := 'klingon';
              aOptions.DataBase := 1;
              aOptions.LogKey := 'WebApi';
              aOptions.Environment := 'PRO';
              aOptions.Password := 'pass123';
              aOptions.OutputAsJson := True;
              aOptions.JsonOutputOptions.UseUTCTime := True;
              aOptions.Enabled := True;
            end)
        .AddSlack(procedure(aOptions : TSlackLoggerOptions)
            begin

            end)
        .AddRest(procedure(aOptions : TRestLoggerOptions)
            begin

            end)
        {$IFDEF MSWINDOWS}
        .AddEventLog(procedure(aOptions : TEventLogLoggerOptions)
            begin

            end)
        .AddADODB(procedure(aOptions : TADODBLoggerOptions)
            begin

            end)
        {$ENDIF}
        .AddTelegram(procedure(aOptions : TTelegramLoggerOptions)
            begin

            end)
        .AddEmail(procedure(aOptions : TEmailLoggerOptions)
            begin
              aOptions.LogLevel := [TEventType.etCritical];
              aOptions.SMTP.Host := 'smtp.mydomain.com';
              aOptions.SMTP.Port := 25;
              aOptions.SMTP.UserName := 'myname@mydomain.com';
              aOptions.SMTP.Password := '';
              aOptions.SMTP.ServerAuth := False;
              aOptions.SMTP.UseSSL := True;
              aOptions.Mail.SenderName := 'MyName';
              aOptions.Mail.From := 'myname@mydomain.com';
              aOptions.Mail.Recipient := 'test@mydomain.com';
              aOptions.Mail.Subject := 'Email from apiserver';
              aOptions.SendLimits.TimeRange := TSendLimitTimeRange.slByDay;
              aOptions.SendLimits.MaxSent := 10;
              aOptions.Enabled := False;
            end)
        .Build
    )
  .AddDebugger
  .AddOptions(TOptionsFileFormat.ofYAML,True)
  //add Entity database
  .Extension<TEntityServiceExtension>
    .AddDBContext<TShopContext>(TDBContextOptionsBuilder.GetBuilder.UseSQLite.ConnectionStringName('ShopContext').Options);
  //add Response caching
  services.Extension<TResponseCachingServiceExtension>
      .AddResponseCaching;
  //add Healtchecks
  services.Extension<THealthChecksServiceExtension>
    .AddHealthChecks(procedure(aOptions : THealthCheckOptions)
    begin
      aOptions.LogFails := True;
      aOptions.RetryTimes := 3;
      aOptions.MaxSize := 50;
    end)
    .AddUrlCheck('Google','https://www.google.com',TTimeSpan.FromSeconds(10))
    .AddUrlCheck('Flakey Endpoint','http://localhost:8081/flakey/ping',TTimeSpan.FromSeconds(5))
    .AddDBContextCheck<TShopContext>('Shop DB',TTimeSpan.FromSeconds(60))
    .AddDiskStorageCheck('App Drive',ExtractFileDrive(ParamStr(0)) + PathDelim,1.0,TTimeSpan.FromSeconds(30))
    .AddMemoryCheck('Process Memory',512,TTimeSpan.FromSeconds(30))
    .AddInMemoryStorage;
  //add Redis cache
  services.Extension<TRedisCacheServiceExtension>
    .AddDistributedRedisCache(procedure(aOptions : TRedisCacheOptions)
        begin
          aOptions.PoolSize := 100;
          aOptions.Host := 'klingon';
          aOptions.Port := 6379;
          aOptions.Password := 'pass123';
          aOptions.DatabaseNumber := 3;
        end)
  //add Memory cache
  .Extension<TMemoryCacheServiceExtension>
    .AddMemoryCache(procedure(aOptions : TMemoryCacheOptions)
                    begin
                      aOptions.PurgeInterval := 30;
                      aOptions.MaxSize := 0;
                    end)
  //configure settings
  .Configure<TAppSettings>(procedure(aOptions : TAppSettings)
                           begin
                             aOptions.Smtp := 'mail.domain.com';
                             aOptions.Email := 'info@domain.com';
                           end)
  //add Automapper
  .Extension<TAutoMapperServiceExtension>
    .AddAutoMapper
  //add Authentication
  .Extension<TAuthenticationServiceExtension>()
    .AddAuthentication(procedure(aOptions : TAuthenticationOptions)
      begin

      end)
  //add Identity
  .Extension<TAuthenticationServiceExtension>()
    .AddIdentity<TUser,TRole>(procedure(aOptions : TIdentityOptions)
      begin
        aOptions.Password.RequiredLength := 6;
        aOptions.User.RequireUniqueEmail := True;
      end)
    .AddEntityStore<TShopContext>();
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
        aOptions.AddPolicy('AdminOnly',TAuthorizationPolicyBuilder.GetBuilder
          .RequireClaim(TClaimTypes.Role,'Admin').Build
        );
      end);
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
  .AddControllers
  //configure routing
  //.MapRoute('default',TTestController,'{controller=Test}/{action=Index}/{id?}')
  //.MapRoute('HelloWorld',TTestController,'Test/Hello')
  //.DefaultRoute(TTestController,'Test/Sum/{number1}/{number2}')
  .DefaultRoute(TTestController,'Home/Index')
  .UseLogRequest(TLoggerBuilder.GetBuilder(False)//(TLoggerOptionsFormat.ofYAML,True,'W3C')
        .AddFile(procedure(aOptions : TFileLoggerOptions)
            begin
              aOptions.FileName := '.\W3C.log';
              aOptions.ShowHeaderInfo := False;
              aOptions.ShowEventType := False;
              aOptions.LogLevel := [TEventType.etInfo];
              aOptions.DailyRotate := True;
              aOptions.Enabled := True;
            end)
        .Build
            )
  .UseWebRoot('.\wwwroot')
  //.UserHsts
  //.UseHttpsRedirection
  .Extension<THealthChecksUIMVCServerExtension>
    .UseHealthChecksUI(procedure(o: THealthChecksUIOptions)
                        begin
                          //o.FullWidthHeader := True;
                          //o.CenterHeaderContent := True;
                        end)
//  .Extension<TResponseCachingMVCServerExtension>
//    .UseResponseCaching
  .UseSwagger('ApiServer API', '1.0.0',
    'QuickCore ApiServer sample API.')
  .UseStaticFiles
  .UseRouting
  .UseAuthentication
  .Use(function(aContext : THttpContextBase) : Boolean
       begin
         aContext.Response.Headers.Add('MyHeader','Hello');
         //aContext.User.Identity.AuthenticationType := TAuthenticationTypes.Basic;
         //aContext.User.Claims.Add(TClaim.Create(TClaimTypes.Role,'Admin'));
         Result := True;
       end)
  .UseAuthorization
  .UseMustachePages
  .UseMVC;
end;

end.
