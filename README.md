# Quick Core

Delphi Framework (Windows/Linux/Android/MACOSX/IOS) to build high-performance and scalable desktop, mobile and web applications.

**Areas of functionality:**
----------

* **Mapping**: Map fields from a class to other class, copy objects, etc..
* **Config**: Easy integration of sections into you config settings. Supports Json and Yaml formats.
* **Authorization**: Authorization validation.
* **Serialization**: Object/Array serialization to/from json/Yaml.
* **Scheduling**: Schedule tasks launching as independent threads with retry policies.
* **Database**: Easy entity framework to work with SQLite, MSSQL, etc
* **UserManagement**:
* **Caching:**: Cache string or objects to retrieve fast later.
* **MVC Web:** Create your own Api or MVC server to serve your own site.


**Main units description:**
----------

**Abstractions:**
* **Quick.Core.Logging.Abstractions:** Logging service abstractions.
* **Quick.Core.Caching.Abstractions:** Memory caching service abstractions.
* **Quick.Core.Mapping.Abstractions:** Mapping objects service abstractions.
* **Quick.Core.Identity.Abstractions:** User identity store abstractions.
* **Quick.Core.Linq.Abstractions:** LinQ abstractions.
* **Quick.Core.Serialization.Abstractions:** Serialization service abstractions.

**Services:**
* **Quick.Core.AutoMapper:** Mapping objects service implementation.
* **Quick.Core.Container:** Dependency injection container service.
* **Quick.Core.Entity:** Entity database access service implementation.
* **Quick.Core.Identity:** User Identity service implementation.
* **Quick.Core.Logging:** Logging service implementation.
* **Quick.Core.Serialization:** Json/Yaml Serialization service implementation.
* **Quick.Core.TaskControl:** Task/Job control service implementation (not ready yet).
* **Quick.Core.Security.UserManager:** User manager service implementation.
* **Quick.Core.Security.Authentication:** Authentication service implementation.
* **Quick.Core.Security.Authorization:** Authorization service implementation.
* **Quick.Core.Security.Claims:** Authorization security claims definitions.

**MVC:**
* **Quick.Core.Mvc:** Main Mvc core implementation.
* **Quick.Core.Mvc.Controller:** Controller implementation.
* **Quick.Core.Mvc.ActionResult:** Controller responses implementation.
* **Quick.Core.Mvc.ActionInvoker:** Controller actions implementation.
* **Quick.Core.Mvc.Context:** Http Request Context implementation.
* **Quick.Core.Mvc.Routing:** Mvc routing implementation.
* **Quick.Core.Mvc.Session:** User session implementation (not ready) 
* **Quick.Core.MvcViewFeatures:** Viewdata implementation.
* **Quick.Core.Mvc.ViewEngine.Mustache:** Very basic mustache template implementation.
* **Quick.Core.Mvc.Middleware.Authentication:** Authentication requests middleware.
* **Quick.Core.Mvc.Middleware.Authorization:** Request Authorization validation middleware.
* **Quick.Core.Mvc.Middleware.Cache:** Response caching middleware.
* **Quick.Core.Mvc.Middleware.Hsts:** Http Strict Transport Security middleware.
* **Quick.Core.Mvc.Mvc:** Mvc main middleware.
* **Quick.Core.Mvc.Middleware:** Mvc routing middleware.
* **Quick.Core.Mvc.StaticFiles:** Static files middleware.
* **Quick.Core.Mvc.HttpsRedirection:** Https force redirection middleware.
* **Quick.Core.Mvc.TaskControl:** Task/Job control middleware(not ready yet).

**Extensions:**

* **Quick.Core.Extensions.Authentication:** Authentication service.
* **Quick.Core.Extensions.Authentication.ApiKey:** ApiKey based Authentication.
* **Quick.Core.Extensions.Authorization:** Authorization service.
* **Quick.Core.Extensions.AutoMapper:** Mapping objects service.
* **Quick.Core.Extensions.Caching.Memory:** Memory Cache service.
* **Quick.Core.Extensions.Caching.Redis:** Redis Cache service.
* **Quick.Core.Extensions.Entity:** Entity framework service.
* **Quick.Core.Extensions.Serialization:** Serialization service.

**Mvc Extensions:**

* **Quick.Core.Mvc.Extensions.Entity.Rest:** Api Rest service.
* **Quick.Core.Mvc.Extensions.ResponseCaching:** Response caching service.
* **Quick.core.Mvc.Extensions.TaskControl:** Task/Job control service.

**Updates:**
* NEW: First beta implementation.

**Installation:**
----------
* **From package managers:**
1. Search "QuickCore" on Delphinus package managers and click *Install*
* **From Github:**
1. Clone this Github repository or download zip file and extract it.
2. Add QuickCore folder to your path libraries on Delphi IDE.
3. Clone QuickLib Github repository https://github.com/exilon/QuickLib or download zip file and extract it.
4. Add QuickLib folder to your path libraries on Delphi IDE.
3. Clone QuickLogger Github repository https://github.com/exilon/QuickLogger or download zip file and extract it.
4. Add QuickLogger folder to your path libraries on Delphi IDE.

# Documentation:
---
---

QuickCore is a framework to easy build desktop/mobile/web apps.

## DependencyInjection

Framework is based on dependency injection priciples. A container holds all services your application needs and allows an easy infrastructure changes with no enfort.
Services are automatically injected into server and configured from a single unit "startup".

*ServiceCollection:*
--
Is a dependency injection container to hold all services your application needs and control their lifetime.
```delphi
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
```

## Basic Services

*Logging:*
--
QuickCore works with ILogger interface. You can use our Logging extension or define your own implementation and inject it.

To use QuickLogger implementation (Needs QuickLogger library. See installation requirements):
```delphi
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
    );
```
...or add your own logger implementation
```delphi
services.AddLogging(MyLogger);
```
QuickCore logging config file is saved as QuickLogger.yml o json file. Using CORE_ENVIRONMENT environment variable you can define what file use for every implementation. If environment variable is defined, QuickCore will try to load/save "QuickCore.[CORE_ENVIRONMENT].yaml" file.

*Options:*
--
QuickCore works with Options pattern. Every TOptions class is a section in your config file and can be injected into services or controllers.
Options service needs to added to ServiceCollection before you can add your sections. You can define config filename and Json or Yaml format.
```delphi
.AddOptions(TOptionsFileFormat.ofYAML,True)
```
Every config section needs to be added, and can be configured with default values.

```delphi
services.Configure<TAppSettings>(procedure(aOptions : TAppSettings)
                           begin
                             aOptions.Smtp := 'mail.domain.com';
                             aOptions.Email := 'info@domain.com';
                           end)

```
and you can inject it later as simple as...
```delphi
constructor TMyController.Create(aLogger : ILogger; aAppSettings : IOptions<TAppSettings>);
begin
    fOptions := aAppSettings.Value;
    fSMTPServer.Host := fOptions.Smtp;
end;
```
Using CORE_ENVIRONMENT environment variable you can define what file use for every implementation. If environment variable is defined, QuickCore will try to load/save "QuickCore.[CORE_ENVIRONMENT].yaml" file.

If not Options.Name is defined, class name will be used as section name in your config file.
Every Configured Option will be save and load to your config file, but if you want, you can hide some options from been saved. Use Options.HideOptions := True;

*Debugger:*
--
Debugger is a simple tracer-debugger. You can see QuickLib documentation. To connect debugger with your logging service only needs add Debugger service in ServiceCollection:
```delphi
services.AddDebugger;
```

*Add custom services:*
--
Interfaces and Implementations can be added to ServiceCollection. AddSingleton and AddTransient allow define live cycle.
```delphi
services.AddSingleton<IMyService,TMyService>;
```
or with delegated creation
```delphi
services.AddTransient<IMyService,TMyService>(function : TMyService)
    begin
        Result := TMyService.Create(myparam);
        Result.Host := 'localhost';
    end);
```
or add an implementation
```delphi
services.AddSingleton<TMyService>;
```

## Extensions

Extensions are injectable services you can add to your app/server. Extensions are injected into ServiceCollection startup unit.
ServiceCollection method Extensions works similar to .net extension methods, extendending ServiceCollection.
To add an extension, you need to add its unit to Startup unit uses clause (See QuickCore predefined extensions above).
```delphi
uses
    Quick.Core.Extensions.AutoMapper;
...
begin
    services.Extension<TAutoMapperServiceExtension>
    .AddAutoMapper;
end;
```

..more documentation soon