program LiquidViewEngine;

(* LiquidViewEngine Sample - S-36
  Demonstrates the Liquid template engine (V-04) for server-side HTML rendering.

  Pages served:
    GET /           → redirect to /catalog
    GET /catalog    → product list (Liquid for-loop, filters)
    GET /catalog/1  → product detail (Liquid if/unless, variables)
    GET /about      → about page (assign, built-ins)

  Template features exercised:
    {{ variable }}               — variable output
    {{ var | filter }}           — built-in filters (upcase, default, escape…)
    {% if condition %}…{% endif %} — conditionals
    {% unless … %}…{% endunless %} — inverse conditionals
    {% for item in list %}…{% endfor %} — loops over comma-separated values
    {% assign x = "value" %}    — variable assignment
    {% include 'partial.liquid' %} — partials (nav, footer)
    {{ now }}  {{ today }}       — built-in date variables

  Templates live in:   wwwroot/Views/
  Partials live in:    wwwroot/Views/ (included via {% include 'nav.liquid' %})

  .NET equivalent: Razor Pages (.cshtml) or Liquid for .NET (Fluid library).
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Startup              in 'Startup.pas',
  Controller.Catalog   in 'controllers\Controller.Catalog.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('LiquidViewEngine sample (S-36) on http://localhost:8080 ...', etInfo);
      cout('', ccWhite);
      cout('  Pages:', ccCyan);
      cout('    http://localhost:8080/         → product catalog', ccWhite);
      cout('    http://localhost:8080/catalog  → product list', ccWhite);
      cout('    http://localhost:8080/catalog/1 → product detail', ccWhite);
      cout('    http://localhost:8080/about    → about page', ccWhite);
      cout('', ccWhite);
      cout('  Templates: wwwroot\Views\  (*.liquid)', ccYellow);

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
      AppService.DisplayName := 'LiquidViewEngine Sample';
      AppService.ServiceName := 'LiquidViewEngineSvc';
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
