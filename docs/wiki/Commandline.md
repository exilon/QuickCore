# Commandline

> Module: `Quick.Core.Commandline`  
> .NET equivalent: `System.CommandLine` / `Microsoft.Extensions.Hosting` (args parsing)

QuickCore Commandline parses command-line arguments using RTTI and exposes them as a typed, DI-injectable object. It also supports Windows/Linux service applications via `TServiceParameters`.

---

## Table of contents

1. [Basics](#basics)
2. [Define typed parameters](#define-typed-parameters)
3. [Register (DI)](#register-di)
4. [Resolve and use](#resolve-and-use)
5. [Parameter attributes](#parameter-attributes)
6. [TServiceParameters — service apps](#tserviceparameters--service-apps)
7. [Complete examples](#complete-examples)
8. [See also](#see-also)

---

## Basics

| Class / Interface | Role |
|-----------------|-----|
| `ICommandline<T>` | Interface that exposes the parsed parameters |
| `TCommandline<T>` | Implementation; parses `ParamStr` on construction |
| `TParameters` | Base class for defining parameters (must be inherited) |
| `TServiceParameters` | Predefined parameters for Windows/Linux services |

---

## Define typed parameters

Inherit from `TParameters` and declare `published` properties with mapping attributes:

```pascal
uses Quick.Core.Commandline;

type
  TMyAppParams = class(TParameters)
  private
    fPort       : Integer;
    fHost       : string;
    fVerbose    : Boolean;
    fConfigFile : string;
    fWorkers    : Integer;
  published
    [ParamName('port')]
    [ParamHelp('HTTP port to listen on.', '8080')]
    property Port : Integer read fPort write fPort;

    [ParamName('host')]
    [ParamHelp('Host address to bind.', '0.0.0.0')]
    property Host : string read fHost write fHost;

    [ParamName('verbose')]
    [ParamHelp('Enable verbose logging.')]
    property Verbose : Boolean read fVerbose write fVerbose;

    [ParamName('config')]
    [ParamValueIsNextParam]
    [ParamHelp('Path to config file.', 'appsettings.json')]
    [ParamRequired]
    property ConfigFile : string read fConfigFile write fConfigFile;

    [ParamName('workers')]
    [ParamHelp('Number of concurrent workers.', '4')]
    property Workers : Integer read fWorkers write fWorkers;
  end;
```

### Command-line call

```
myapp.exe --port 9000 --host 127.0.0.1 --verbose --config C:\app\settings.json --workers 8
```

---

## Register (DI)

```pascal
uses Quick.Core.DependencyInjection;

// In ConfigureServices
services.AddCommandline<TMyAppParams>;
```

---

## Resolve and use

```pascal
uses Quick.Core.Commandline;

type
  TMyStartup = class(TStartupBase)
  public
    class procedure ConfigureServices(services: TServiceCollection); override;
  end;

class procedure TMyStartup.ConfigureServices(services: TServiceCollection);
var
  args : ICommandline<TMyAppParams>;
begin
  services.AddCommandline<TMyAppParams>;

  // Read parameters during startup
  args := services.Resolve<ICommandline<TMyAppParams>>();

  // Configure the server based on arguments
  if args.Value.Port > 0 then
    ServerConfig.Port := args.Value.Port;

  if args.Value.Verbose then
    Logger.Level := logDebug;
end;
```

### Inject into a service

```pascal
type
  TWebServer = class
  private
    fArgs : ICommandline<TMyAppParams>;
  public
    constructor Create(aArgs: ICommandline<TMyAppParams>);
    procedure Start;
  end;

procedure TWebServer.Start;
var
  params : TMyAppParams;
begin
  params := fArgs.Value;
  Listen(params.Host, params.Port);
  Logger.Info(Format('Listening on %s:%d', [params.Host, params.Port]));
end;
```

---

## Parameter attributes

| Attribute | Description |
|----------|-------------|
| `[ParamName('name')]` | CLI argument name (`--name value`) |
| `[ParamHelp('text', 'default')]` | Help text and default value |
| `[ParamRequired]` | Parameter is mandatory; error if missing |
| `[ParamValueIsNextParam]` | Value is in the next argument (`--config path`) |
| `[ParamSwitchChar('/')]` | Alternative switch character (default `--`) |
| `[ParamCommand]` | Parameter is a subcommand |
| `[CommandDescription('text')]` | Command description (for help output) |

---

## TServiceParameters — service apps

`TServiceParameters` includes standard parameters for managing a Windows service or Linux daemon:

```pascal
// Available parameters automatically:
// --install   Installs the service/daemon
// --remove    Uninstalls the service/daemon
// --console   Forces console execution
// --instance  Service instance name
// --silent    Silent mode
// (Linux) --detach  Detach from terminal (daemonize)
```

### Use in a service app

```pascal
uses
  Quick.Core.Commandline,
  Quick.Core.Extensions.Service;

// Standard service startup with command-line control
begin
  var args := TCommandline<TServiceParameters>.Create;
  try
    if args.Value.Install then
      InstallService
    else if args.Value.Remove then
      RemoveService
    else if args.Value.Console then
      RunAsConsole
    else
      RunAsService;
  finally
    args.Free;
  end;
end.
```

### With custom parameters + service

```pascal
type
  TMyServiceParams = class(TServiceParameters)
  private
    fPort : Integer;
  published
    [ParamName('port')]
    [ParamHelp('HTTP port.', '8080')]
    property Port : Integer read fPort write fPort;
  end;
```

---

## Complete examples

### CLI app that processes a file

```
process.exe --input data.csv --output result.json --format json --skip-errors
```

```pascal
type
  TProcessParams = class(TParameters)
  published
    [ParamName('input')]
    [ParamRequired]
    [ParamValueIsNextParam]
    property InputFile : string read fInput write fInput;

    [ParamName('output')]
    [ParamValueIsNextParam]
    property OutputFile : string read fOutput write fOutput;

    [ParamName('format')]
    [ParamValueIsNextParam]
    property Format : string read fFormat write fFormat;

    [ParamName('skip-errors')]
    property SkipErrors : Boolean read fSkipErrors write fSkipErrors;
  end;

begin
  var cmd := TCommandline<TProcessParams>.Create;
  var p   := cmd.Value;

  if p.InputFile = '' then
  begin
    WriteLn('Error: --input is required');
    Halt(1);
  end;

  ProcessFile(p.InputFile, p.OutputFile, p.Format, p.SkipErrors);
end.
```

### C# equivalent

```csharp
var root = new RootCommand();
var inputOpt = new Option<FileInfo>("--input") { IsRequired = true };
root.AddOption(inputOpt);
root.SetHandler(file => ProcessFile(file), inputOpt);
root.Invoke(args);
```

---

## See also

- [Dependency Injection](Dependency-Injection.md) — `AddCommandline`, resolution
- [Background Services](Background-Services.md) — service startup


---

## Tabla de contenidos

1. [Conceptos básicos](#conceptos-básicos)
2. [Definir parámetros tipados](#definir-parámetros-tipados)
3. [Registrar (DI)](#registrar-di)
4. [Resolver y usar](#resolver-y-usar)
5. [Atributos de parámetros](#atributos-de-parámetros)
6. [TServiceParameters — apps de servicio](#tserviceparameters--apps-de-servicio)
7. [Ejemplos completos](#ejemplos-completos)
8. [Ver también](#ver-también)

---

## Conceptos básicos

| Clase / Interfaz | Rol |
|-----------------|-----|
| `ICommandline<T>` | Interfaz que expone los parámetros parseados |
| `TCommandline<T>` | Implementación; parsea `ParamStr` al construirse |
| `TParameters` | Clase base para definir parámetros (herencia obligatoria) |
| `TServiceParameters` | Parámetros predefinidos para servicios Windows/Linux |

---

## Definir parámetros tipados

Hereda de `TParameters` y declara propiedades `published` con los atributos de mapeo:

```pascal
uses Quick.Core.Commandline;

type
  TMyAppParams = class(TParameters)
  private
    fPort       : Integer;
    fHost       : string;
    fVerbose    : Boolean;
    fConfigFile : string;
    fWorkers    : Integer;
  published
    [ParamName('port')]
    [ParamHelp('HTTP port to listen on.', '8080')]
    property Port : Integer read fPort write fPort;

    [ParamName('host')]
    [ParamHelp('Host address to bind.', '0.0.0.0')]
    property Host : string read fHost write fHost;

    [ParamName('verbose')]
    [ParamHelp('Enable verbose logging.')]
    property Verbose : Boolean read fVerbose write fVerbose;

    [ParamName('config')]
    [ParamValueIsNextParam]
    [ParamHelp('Path to config file.', 'appsettings.json')]
    [ParamRequired]
    property ConfigFile : string read fConfigFile write fConfigFile;

    [ParamName('workers')]
    [ParamHelp('Number of concurrent workers.', '4')]
    property Workers : Integer read fWorkers write fWorkers;
  end;
```

### Llamada desde línea de comandos

```
myapp.exe --port 9000 --host 127.0.0.1 --verbose --config C:\app\settings.json --workers 8
```

---

## Registrar (DI)

```pascal
uses Quick.Core.DependencyInjection;

// En ConfigureServices
services.AddCommandline<TMyAppParams>;
```

---

## Resolver y usar

```pascal
uses Quick.Core.Commandline;

type
  TMyStartup = class(TStartupBase)
  public
    class procedure ConfigureServices(services: TServiceCollection); override;
  end;

class procedure TMyStartup.ConfigureServices(services: TServiceCollection);
var
  args : ICommandline<TMyAppParams>;
begin
  services.AddCommandline<TMyAppParams>;

  // Leer parámetros durante el arranque
  args := services.Resolve<ICommandline<TMyAppParams>>();

  // Configurar el servidor según argumentos
  if args.Value.Port > 0 then
    ServerConfig.Port := args.Value.Port;

  if args.Value.Verbose then
    Logger.Level := logDebug;
end;
```

### Inyección en un servicio

```pascal
type
  TWebServer = class
  private
    fArgs : ICommandline<TMyAppParams>;
  public
    constructor Create(aArgs: ICommandline<TMyAppParams>);
    procedure Start;
  end;

procedure TWebServer.Start;
var
  params : TMyAppParams;
begin
  params := fArgs.Value;
  Listen(params.Host, params.Port);
  Logger.Info(Format('Listening on %s:%d', [params.Host, params.Port]));
end;
```

---

## Atributos de parámetros

| Atributo | Descripción |
|----------|-------------|
| `[ParamName('nombre')]` | Nombre del argumento en CLI (`--nombre valor`) |
| `[ParamHelp('texto', 'default')]` | Texto de ayuda y valor por defecto |
| `[ParamRequired]` | El parámetro es obligatorio; error si falta |
| `[ParamValueIsNextParam]` | El valor está en el siguiente argumento (`--config path`) |
| `[ParamSwitchChar('/')]` | Carácter de switch alternativo (por defecto `--`) |
| `[ParamCommand]` | El parámetro es un subcomando |
| `[CommandDescription('texto')]` | Descripción del comando (para ayuda) |

---

## TServiceParameters — apps de servicio

`TServiceParameters` incluye los parámetros estándar para gestionar un servicio Windows / daemon Linux:

```pascal
// Parámetros disponibles automáticamente:
// --install   Instala el servicio/daemon
// --remove    Desinstala el servicio/daemon
// --console   Fuerza ejecución en consola
// --instance  Nombre de instancia del servicio
// --silent    Modo silencioso
// (Linux) --detach  Desacoplar del terminal (daemonize)
```

### Uso en una app de servicio

```pascal
uses
  Quick.Core.Commandline,
  Quick.Core.Extensions.Service;

// Arranque estándar de servicio con control por línea de comandos
begin
  var args := TCommandline<TServiceParameters>.Create;
  try
    if args.Value.Install then
      InstallService
    else if args.Value.Remove then
      RemoveService
    else if args.Value.Console then
      RunAsConsole
    else
      RunAsService;
  finally
    args.Free;
  end;
end.
```

### Con parámetros propios + servicio

```pascal
type
  TMyServiceParams = class(TServiceParameters)
  private
    fPort : Integer;
  published
    [ParamName('port')]
    [ParamHelp('HTTP port.', '8080')]
    property Port : Integer read fPort write fPort;
  end;
```

---

## Ejemplos completos

### App CLI que procesa un fichero

```
process.exe --input data.csv --output result.json --format json --skip-errors
```

```pascal
type
  TProcessParams = class(TParameters)
  published
    [ParamName('input')]
    [ParamRequired]
    [ParamValueIsNextParam]
    property InputFile : string read fInput write fInput;

    [ParamName('output')]
    [ParamValueIsNextParam]
    property OutputFile : string read fOutput write fOutput;

    [ParamName('format')]
    [ParamValueIsNextParam]
    property Format : string read fFormat write fFormat;

    [ParamName('skip-errors')]
    property SkipErrors : Boolean read fSkipErrors write fSkipErrors;
  end;

begin
  var cmd := TCommandline<TProcessParams>.Create;
  var p   := cmd.Value;

  if p.InputFile = '' then
  begin
    WriteLn('Error: --input is required');
    Halt(1);
  end;

  ProcessFile(p.InputFile, p.OutputFile, p.Format, p.SkipErrors);
end.
```

### Equivalente C#

```csharp
var root = new RootCommand();
var inputOpt = new Option<FileInfo>("--input") { IsRequired = true };
root.AddOption(inputOpt);
root.SetHandler(file => ProcessFile(file), inputOpt);
root.Invoke(args);
```

---

## Ver también

- [Dependency Injection](Dependency-Injection.md) — `AddCommandline`, resolución
- [Background Services](Background-Services.md) — arranque de servicios
