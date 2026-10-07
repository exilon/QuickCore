program QuickCore.Tests;

{$APPTYPE CONSOLE}

uses
  DUnitX.Loggers.Console,
  DUnitX.TestFramework,
  System.SysUtils,
  Quick.Core.DependencyInjection.Tests in 'Quick.Core.DependencyInjection.Tests.pas',
  Quick.Core.AutoMapper.Tests in 'Quick.Core.AutoMapper.Tests.pas',
  Quick.Core.Entity.Tests in 'Quick.Core.Entity.Tests.pas',
  Quick.Core.Security.Tests in 'Quick.Core.Security.Tests.pas',
  Quick.Core.Caching.Tests in 'Quick.Core.Caching.Tests.pas',
  Quick.Core.HealthChecks.Tests in 'Quick.Core.HealthChecks.Tests.pas',
  Quick.Core.Mvc.Tests in 'Quick.Core.Mvc.Tests.pas',
  Quick.Core.Entity.Advanced.Tests in 'Quick.Core.Entity.Advanced.Tests.pas',
  Quick.Core.Mvc.ViewEngine.Liquid.Tests in 'Quick.Core.Mvc.ViewEngine.Liquid.Tests.pas',
  Quick.Core.Mvc.ModelValidation.Tests in 'Quick.Core.Mvc.ModelValidation.Tests.pas',
  Quick.Core.Mvc.Session.Tests in 'Quick.Core.Mvc.Session.Tests.pas',
  Quick.Core.Mvc.Middleware.Tests in 'Quick.Core.Mvc.Middleware.Tests.pas',
  Quick.Core.Security.Authentication.Tests in 'Quick.Core.Security.Authentication.Tests.pas',
  Quick.Core.Security.Authorization.Tests in 'Quick.Core.Security.Authorization.Tests.pas',
  Quick.Core.Security.Totp.Tests in 'Quick.Core.Security.Totp.Tests.pas',
  Quick.Core.Serialization.Tests in 'Quick.Core.Serialization.Tests.pas',
  Quick.Core.Identity.Tests in 'Quick.Core.Identity.Tests.pas',
  Quick.Core.Mvc.Filters.Tests in 'Quick.Core.Mvc.Filters.Tests.pas',
  Quick.Core.Entity.QueryGenerators.Tests in 'Quick.Core.Entity.QueryGenerators.Tests.pas',
  Quick.Core.Commandline.Tests in 'Quick.Core.Commandline.Tests.pas',
  Quick.Core.Extensions.Localization.Tests in 'Quick.Core.Extensions.Localization.Tests.pas',
  Quick.Core.Mediator.Tests in 'Quick.Core.Mediator.Tests.pas',
  Quick.Core.Resilience.Tests in 'Quick.Core.Resilience.Tests.pas',
  Quick.Core.Caching.Hybrid.Tests in 'Quick.Core.Caching.Hybrid.Tests.pas',
  Quick.Core.Options.Monitor.Tests in 'Quick.Core.Options.Monitor.Tests.pas',
  Quick.Core.Mvc.Validation.Builder.Tests in 'Quick.Core.Mvc.Validation.Builder.Tests.pas',
  Quick.Core.Telemetry.Tests in 'Quick.Core.Telemetry.Tests.pas';

{$R *.res}

var
  runner: ITestRunner;
  results: IRunResults;
  logger: ITestLogger;

begin
  runner := TDUnitX.CreateRunner;
  runner.UseRTTI := True;
  runner.FailsOnNoAsserts := False;

  logger := TDUnitXConsoleLogger.Create;
  runner.AddLogger(logger);

  results := runner.Execute;

  if not results.AllPassed then
    ExitCode := 1;

  {$IFDEF DEBUG}
  System.Write('Test finished. Press <Enter> to exit...');
  System.Readln;
  {$ENDIF}
end.