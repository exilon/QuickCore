program RateLimiting;

(* RateLimiting Sample - S-35
  Demonstrates global and per-action rate limiting with QuickCore MVC.

  UseRateLimiting(10, 60) in the pipeline applies a global token-bucket
  policy: max 10 requests per 60-second sliding window, keyed by client IP.

  The [RateLimit(n, secs)] attribute on a specific action overrides the
  global policy for that endpoint (here: 3 req per 10 s for /api/limited).

  When the limit is exceeded the server returns:
    HTTP 429 Too Many Requests
    Retry-After: <seconds>
    {"error":"Rate limit exceeded","retryAfter":<seconds>}

  Endpoints:
    GET /api/public   — uses global limit (10 req / 60 s)
    GET /api/limited  — tighter per-action limit (3 req / 10 s)
    GET /api/status   — shows current limit configuration

  Example — trigger 429 on /api/limited:
    for i in 1 2 3 4; do curl http://localhost:8080/api/limited; echo; done

  .NET equivalent: Microsoft.AspNetCore.RateLimiting middleware
    (AddRateLimiter / UseRateLimiter / [EnableRateLimiting]).
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Startup             in 'Startup.pas',
  Controller.Demo     in 'controllers\Controller.Demo.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('RateLimiting sample (S-35) on http://localhost:8080 ...', etInfo);
      cout('', ccWhite);
      cout('  GET /api/public   — global limit (10 req/60 s)', ccCyan);
      cout('  GET /api/limited  — tight limit  (3 req/10 s)', ccCyan);
      cout('  GET /api/status   — show limit config', ccCyan);
      cout('', ccWhite);
      cout('  Trigger 429:', ccYellow);
      cout('    for i in 1 2 3 4; do curl http://localhost:8080/api/limited; echo; done', ccWhite);

      ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
      try
        ApiServer.UseStartup<TStartup>;
        ApiServer.Start;
      finally
        ApiServer.Free;
      end;
    end
    else
    begin
      AppService.DisplayName := 'RateLimiting Sample';
      AppService.ServiceName := 'RateLimitingSvc';
      AppService.CanInstallWithOtherName := True;
      AppService.OnStart := procedure
        begin
          ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
          ApiServer.UseStartup<TStartup>;
        end;
      AppService.OnExecute := ApiServer.Start;
      AppService.CheckParams;
    end;
  except
    on E : Exception do
    begin
      cout('Fatal: ' + E.Message, etError);
      ExitCode := 1;
    end;
  end;
end.
