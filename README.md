![alt text](docs/QuickCore.png "QuickCore") 

Delphi Framework (Windows/Linux/Android/MACOSX/IOS) to build high-performance and scalable desktop, mobile and web applications easily.

**Areas of functionality:**
----------

* **Mapping**: Map fields from a class to other class, copy objects, etc..
* **Config**: Easy integration of sections into config settings. Supports Json and Yaml formats.
* **Authorization**: Authorization validation.
* **Serialization**: Object/Array serialization to/from json/Yaml.
* **Scheduling**: Schedule tasks launching as independent threads with retry policies.
* **Database**: Easy entity framework to work with SQLite, MSSQL, etc
* **UserManagement**:
* **Caching:**: Cache string or objects to retrieve fast later.
* **MVC Web:** Create own Api or MVC server to serve own site.

## Give it a star
Please "star" this project in GitHub! It costs nothing but helps to reference the code.
![alt text](docs/githubstartme.jpg "Give it a star")

## Support
If you find this project useful, please consider making a donation.

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate/?hosted_button_id=BKLKPNEYKSBKL)


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
* 11/08/2020: Added commandline extension.
* 12/07/2020: Updated documentation.
* 06/07/2020: First beta implementation.

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
QuickCore is a framework to easy build desktop/mobile/web apps.

## DependencyInjection

Entire Framework is based on dependency injection priciples. A container holds all services needed by the application, allowing easy infrastructure changes with a minor enfort.

Services are automatically injected into server and configured from a single unit "startup".
Every Core project needs a startup.pas with a class inheriting from TStartupBase (see examples on samples folder).

*ServiceCollection:*
--
It's a collection of services where we can register predefined or custom services and control its lifecycle (singleton, transient,..). ServiceCollection is the build-in container included in QuickCore and supports constructor injection by default.
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
QuickCore works with ILogger interface. We can use build-in Logging extension or define own implementation and inject it.

To use QuickLogger implementation (Needs QuickLogger library. See installation requirements).
QuickLogger uses an ILogger builder to easy configuration. Default options can be passed as Options delegate function. When QuickLogger config file exists, no default options will be applied more:
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
...or add own logger implementation
```delphi
services.AddLogging(MyLogger);
```
QuickCore logging config file is saved as QuickLogger.yml o json file. Using CORE_ENVIRONMENT environment variable we can define what file use for each implementation. If environment variable is defined, QuickCore will try to load/save "QuickCore.[CORE_ENVIRONMENT].yaml/json" file.

*Options:*
--
QuickCore works with Options pattern. Every TOptions object will be saved as a section in config file and can be injected into services or controllers constructors.
Options service needs to added to ServiceCollection before we can add sections. We can define config filename and Json or Yaml format.
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
and we can inject it later as simple as...
```delphi
constructor TMyController.Create(aLogger : ILogger; aAppSettings : IOptions<TAppSettings>);
begin
    fOptions := aAppSettings.Value;
    fSMTPServer.Host := fOptions.Smtp;
end;
```
Into startup config you can use read options to do some optional actions:
```delphi
  if services.GetConfiguration<TAppSettings>.UseCache then
  begin
    //do some stuff or define service implementation
  end
  else
  begin
    //do some stuff or define alternative service implementation
  end;
```
Using CORE_ENVIRONMENT environment variable we can define what file use for every implementation. If environment variable is defined, QuickCore will try to load/save "QuickCore.[CORE_ENVIRONMENT].yaml" file.

If not Options.Name is defined, class name will be used as section name in config file.
Every Configured Option will be save and load to config file, but if we want, we can hide some options from been saved. Use Options.HideOptions := True (for internal options not configurable externally).

*Debugger:*
--
Debugger is a simple tracer-debugger (See QuickLib documentation). To connect debugger with a logging service only needs to add Debugger service in ServiceCollection (by default uses a console output):
```delphi
services.AddDebugger;
```

*Commandline parameters:*
--
Working with commandline parameters will be easy using commandline extension.
Define a class inherited from TParameters or TServiceParameters (if working with QuickAppServices) with your possible arguments:
```delphi
uses
  Quick.Parameters;
type
  TArguments = class(TParameters)
  private
    fPort : Integer;
    fSilent : Boolean;
  published
    [ParamCommand(1)]
    [ParamHelp('Define listen port','port')]
    property Port : Integer read fPort write fPort;
    property Silent : Boolean read fSilent write fSilent;
  end;
```
And pass to de commandline extension:
```delphi
services.AddCommandline<TArguments>;
```
When you call your exe with --help you get documentation. If you need to check for a switch or value, you can do like this:
```delphi
if services.Commandline<TArguments>.Port = 0 then ...
if services.Commandline<TArguments>.Silent then ...
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

Extensions are injectable services we can add to our app/server. Extensions are injected into ServiceCollection startup unit.
ServiceCollection method Extensions works similar to .net extension methods, extendending ServiceCollection.

To add an extension, we need to add its unit to Startup unit uses clause (See QuickCore predefined extensions above).
```delphi
uses
    Quick.Core.Extensions.AutoMapper;
...
begin
    services.Extension<TAutoMapperServiceExtension>
    .AddAutoMapper;
end;
```

# MVC Server 
With QuickCore we can create web applications with controllers and actions.

## Create AppServer
Create an application server and define binding and security.
```delphi
ApiServer := TMvcServer.Create('127.0.0.1',8080,False);
ApiServer.UseStartup<TStartup>;
ApiServer.Start;
```delphi
To configure services and middlewares startup must configured
```delphi
class procedure TStartup.Configure(app : TMVCServer);
begin
  app
  .AddControllers
  .AddController(THomeController)
  .DefaultRoute(THomeController,'Home/Index')
  .UseWebRoot('.\wwwroot')
  .UseRouting
  .UseMVC;
end;
```
**AddController(ControllerClass):** Allow add a controller to an web app server.

**AddControllers:** Add all controllers registered during its initialization unit with RegisterController(ControllerClass);

**UseWebRoot(path):** Define static files/data folder.

**UseCustomErrorPages:** Enable use of custom error pages. On a 403 error, server will search for a 403.html, 40x.html or 4xx.html files. If dinamic page specified, simple mustache patterns will be replaced with error info (StatusCode, StatusMsg, etc).

**UseMustachePages:** Simple mustache template engine to replace simple views.

## Middlewares:
Middlewares are like layers of functionality and runs into a request pipeline. Every request pass for each middlwares (in creation order) or not, depending of middelware requeriments.

**UseStaticFiles:** To allow serve static content.

**UseHsts:** Http Strict Transport Security middleware to allow only https connections.

**UseHttpsRedirection:** Enables redirection middleware to redirect on header location found.

**UseRouting:** Enables Routing middleware to get matching route from request.

**UseMVC:** Enable MVC middleware to manage and redirect every request to its correspondent 
controller action or view.

**UseMiddleware:** To add custom middleware class to request pipeline.

**Use(RequestDelegate):** Execute an anonymous method as a middleware.

**UseAuthentication:** Tries to get authentication info from a request.

**UseAuthorization:** Allow/Disallow acces to resources based on authorization policies.

## Controllers
Every controller inherites from THttpController and published methods becomes actions. With custom attributes we can define routing, authorization, etc of these methods.
As all controllers are injected from dependency injection, we can define constructor with autoinjectable parameters and IOC will try to resolve on constructor creation.
```delphi
constructor THomeController.Create(aLogger: ILogger);
```

## Routing
Http routing is custom attributes based. We need to define routing for each controller and method/action.
```delphi
[HttpGet('home/index')]
function THomeController.Index : IActionResult;

[HttpPost('home/GetAll')]
function THomeController.GetAll : IActionResult;
```
If routing defined on class, then it's global and doesn't need to be replicated on each method/action:
```delphi
[Route('home/other')]
THomeController = class(THttpController)
published
    [HttpPost('GetAll')] // global + local = home/other/GetAll
    function THomeController.GetAll : IActionResult;
```

## Attributes
* [NonAction] Method not configured as an action method.
* [ActionName] Defines name of action if different from method name.
* [Route] Defines controller routing or action routing.
* [HttpGet(route)] Defines a route with a GET method.
* [HttpPost(route)] Defines a route with a POST method.
* [HttpPut(route)] Defines a route with a PUT method.
* [HttpDelete(route)] Defines a route with a DELETE method.
* [HttpMethod(method)] Defines a custom method.
* [AccepVerbs([verbs])] Defines all accepted verbs.
* [Authorize] Limits acces to a controller or single method to only authenticated users.
* [Authorize(role)] Limits access to a controller or single method to users with x role/s.
* [AllowAnonymous] If global attribute defines a more restricted authorization, using this on a method allow access it without.
* [OutputCache(TTL)] If ResponseCaching middleware defined, then response from this action will be saved and retrieved from cache while TTL interval not reached.

## Handling parameters
Parameters are defined with attributes and automatically parsed and injected as method parameters. 
```delphi
[HttpGet('Add/{productname}/{price}')]
function Add(const ProductName : string; Price : Integer): IActionResult;
```
Parameters can be typed defined.
Int: numeric only
alpha: only letters.
Float: only floating numbers.
```delphi
[HttpGet('Add/{productname:alpha}/{price:float}')]
function Add(const ProductName : string; Price : Extended): IActionResult;
```
An ? define a parameter as optional
```delphi
[HttpGet('Add/{productname:alpha}/{price:float?}')]
function Add(const ProductName : string; Price : Extended): IActionResult;
```
To get a parameter from the request body (with automatic deserialization)
```delphi
[HttpPost('Add/User')]
function Add([FromBody] User : TUser): IActionResult;
```
## Action Results
Action results are results of a controller.
**StatusCode(statuscode, statustext):** Returns a status code and optional status text to client.
```delphi
    Result := StatusCode(200,'ok');
```
**Ok(statustext):** Returns a 200 status code and optional statustext.

**Accepted(statustext):** Returns a 202 status code and optional status text.

**BadRequest(statustext):** Returns a 400 status code and optional status text.

**NotFound(statustext):** Returns a 404 status code and optional status text.

**Forbid(statustext):** Returns a 403 status code and optional status text.

**Unauthorized(statustext):** Returns a 401 status code and optional status text.

**Redirect(url):** Returns a temporal redirection to url.

**RedirectPermament(url):** Returns a permanent redirection to url.

**Content(text):** Returns a response text.

**Json(object,onlypublishedproperties):** Returns a serialized json object or list. If OnlyPublishedProperties enabled, only object published properties will be serialized.
```delphi
    Result := Json(User);
```
**View(viewname):** Returns a view.
```delphi
    Result := View('home');
```

# Core Extensions

## AutoMapper:
Automapper extension allows map a class type to another class type.
To use Automapper we must add service to ServiceCollection in Statup unit:
```delphi
services.Extension<TAutoMapperServiceExtension>
    .AddAutoMapper;
```
Then define profile maps with mapping relationship.
If property names are identical, we should not have to manually provide a mapping:
```delphi
constructor TMyProfile.Create;
begin
  //maps properties with same name in both classes
  CreateMap<TDBUser,TUser>();
end;

initialization
  TAutoMapper.RegisterProfile<TMyProfile>;
```
If some properties have diferent name or type, we must use custom mappings:
```delphi
constructor TMyProfile.Create;
begin
  //maps properties with delegate function and rest maps formember
  CreateMap<TDBProduct,TProduct>(procedure(src : TDBProduct; tgt : TProduct)
    begin
      tgt.Id := src.uid;
      tgt.Age := src.Age;
    end)
    .ForMember('Money','Cash')
    .ForMember('Name','FullName')
    .IgnoreOtherMembers;
end;

initialization
  TAutoMapper.RegisterProfile<TMyProfile>;
```
**ForMember(SourceProperty,TargetProperty):** Maps a source property name to a target property name.
**IgnoreAllNonExisting:** Ignore all non existing properties on target.

**IgnoreOtherMembers:** Only properties defined in custom mapping will be resolved.

**ResolveUnmapped:** Tries to resolve automatically any map without a profilemap defined.

AutoMapper service can be injected into a object/controller defining the abstraction in uses clauses.
```delphi
uses
    Quick.Core.Mapping.Abstractions;
...
    TMyController.Create(aMapper : IMapper);
```
..and use it:
```delphi
product := fMapper.Map(dbproduct).AsType<TProduct>;
```


## ..more documentation soon

>Do you want to learn delphi or improve your skills? [learndelphi.org](https://learndelphi.org)

