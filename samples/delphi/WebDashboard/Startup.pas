unit Startup;

{ WebDashboard — S-26 }

interface

uses
  System.SysUtils,
  System.IOUtils,
  Quick.Core.Mvc,
  Quick.Core.Mvc.Context,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging,
  Service.Tasks,
  Controller.Home,
  Controller.Tasks;

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
    // Single shared instance — all requests see the same task list and counters.
    .AddSingleton<ITaskService, TTaskService>;
end;

class procedure TStartup.Configure(app : TMVCServer);
begin
  app
    .AddControllers
    // Fast-path: intercept GET / before any middleware (SetURL('/') strips leading '/'
    // leaving fURL = '', so classic routing would short-circuit to nil -> 404).
    .MapGet('/', function(ctx: THttpContextBase): string
      begin
        ctx.Response.ContentType := 'text/html; charset=utf-8';
        // ctx.WebRoot = '.\wwwroot\' (CWD-relative, set by UseWebRoot below)
        ctx.Response.ContentText := TFile.ReadAllText(
          ctx.WebRoot + 'index.html', TEncoding.UTF8);
        Result := '';
      end)
    // Fallback via TRoutingMiddleware: fDefaultRoute is returned for empty URL.
    // Dispatches to THomeController.Index even if MapGet above is bypassed.
    .DefaultRoute(THomeController, '/Index')
    // Swagger middleware BEFORE UseRouting so /swagger* is intercepted early.
    .UseSwagger('WebDashboard Tasks API', '1.0.0',
      'QuickCore WebDashboard — in-memory task list with Add / Complete / Delete operations.')
    .UseWebRoot(TPath.Combine(ExtractFilePath(ParamStr(0)), 'wwwroot'))
    .UseStaticFiles
    .UseRouting
    .UseMVC;
end;

end.
