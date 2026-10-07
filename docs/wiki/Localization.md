# Localization

> Modules: `Quick.Core.Extensions.Localization`, `Quick.Core.Localization.Abstractions`  
> .NET equivalent: `Microsoft.Extensions.Localization`

QuickCore Localization provides string translation using JSON culture files, automatic resolution by `Accept-Language` header, and the injectable `IStringLocalization` interface.

---

## Table of contents

1. [Basics](#basics)
2. [Register Localization (DI)](#register-localization-di)
3. [Culture files](#culture-files)
4. [Use IStringLocalization](#use-istringlocalization)
5. [Change culture at runtime](#change-culture-at-runtime)
6. [Localization in MVC controllers](#localization-in-mvc-controllers)
7. [AddIfNotFound](#addifnotfound)
8. [See also](#see-also)

---

## Basics

| Class / Interface | Role |
|-----------------|-----|
| `IStringLocalization` | Main interface; access translations by key |
| `TStringLocalization` | Concrete implementation; scoped (one per request) |
| `ILocalizationStore` | Translation storage abstraction |
| `TFileLocalizationStore` | Loads translations from JSON files in `locales/` |
| `TLocalizationOptions` | Options: supported cultures, `AddIfNotFound` behavior |

---

## Register Localization (DI)

```pascal
uses Quick.Core.Extensions.Localization;

// In ConfigureServices — minimal configuration
services.Extension<TLocalizationServiceExtension>
  .AddLocalization;

// With options
services.Extension<TLocalizationServiceExtension>
  .AddLocalization(procedure(opt: TLocalizationOptions)
  begin
    opt.AddCulture('es-ES');
    opt.AddCulture('en-US');
    opt.AddCulture('fr-FR');
    opt.AddIfNotFound := True;  // adds key if not found in the file
  end);
```

### C# equivalent

```csharp
builder.Services.AddLocalization(opt => opt.ResourcesPath = "locales");
```

---

## Culture files

Files are stored in the `locales/` folder of the application directory:

```
locales/
  es-ES.json
  en-US.json
  fr-FR.json
```

JSON format (key → translation pairs):

**`locales/es-ES.json`**
```json
{
  "welcome": "Bienvenido",
  "goodbye": "Hasta luego",
  "error.notFound": "Recurso no encontrado",
  "error.unauthorized": "No autorizado",
  "product.created": "Producto '{0}' creado correctamente"
}
```

**`locales/en-US.json`**
```json
{
  "welcome": "Welcome",
  "goodbye": "Goodbye",
  "error.notFound": "Resource not found",
  "error.unauthorized": "Unauthorized",
  "product.created": "Product '{0}' created successfully"
}
```

---

## Use IStringLocalization

```pascal
uses Quick.Core.Localization.Abstractions;

type
  TProductService = class
  private
    fLocalizer : IStringLocalization;
  public
    constructor Create(aLocalizer: IStringLocalization);

    function GetWelcomeMessage: string;
    function GetProductCreatedMsg(const aName: string): string;
  end;

function TProductService.GetWelcomeMessage: string;
begin
  // Simple access by key
  Result := fLocalizer['welcome'];
end;

function TProductService.GetProductCreatedMsg(const aName: string): string;
begin
  // With format parameters (equivalent to Format())
  Result := fLocalizer['product.created', [aName]];
end;
```

### In an MVC controller

```pascal
type
  [Route('api/[controller]')]
  TProductsController = class(THttpController)
  private
    fLocalizer : IStringLocalization;
    fService   : IProductService;
  public
    constructor Create(
      aLocalizer : IStringLocalization;
      aService   : IProductService);

    [HttpPost]
    function Create([FromBody] dto: TProductDto): TActionResult;
  end;

function TProductsController.Create(dto: TProductDto): TActionResult;
var
  product : TProduct;
begin
  product := fService.Create(dto);
  Result  := Ok(fLocalizer['product.created', [product.Name]]);
end;
```

### C# equivalent

```csharp
public class ProductsController : ControllerBase
{
    private readonly IStringLocalizer<ProductsController> _localizer;

    public ProductsController(IStringLocalizer<ProductsController> loc)
        => _localizer = loc;

    [HttpPost]
    public IActionResult Create(ProductDto dto)
    {
        var product = _service.Create(dto);
        return Ok(_localizer["product.created", product.Name]);
    }
}
```

---

## Change culture at runtime

```pascal
// Set culture explicitly
fLocalizer.Culture := 'fr-FR';

// Read current culture
var current := fLocalizer.Culture;  // 'fr-FR'

// Example: change based on user preference
procedure TBaseController.SetCultureFromRequest;
var
  lang : string;
begin
  lang := Request.Headers.GetValue('Accept-Language');
  if lang <> '' then
    fLocalizer.Culture := lang.Split([','])[0].Trim;
end;
```

---

## Localization in MVC controllers

To automatically apply the culture based on the `Accept-Language` header:

```pascal
// In a global Action Filter
type
  TLocalizationFilter = class(TActionFilterAttribute)
  public
    procedure OnActionExecuting(aContext: TActionExecutingContext); override;
  end;

procedure TLocalizationFilter.OnActionExecuting(aContext: TActionExecutingContext);
var
  lang      : string;
  localizer : IStringLocalization;
begin
  lang := aContext.HttpContext.Request.Headers.GetValue('Accept-Language');
  if lang <> '' then
  begin
    localizer := aContext.HttpContext.RequestServices.GetService<IStringLocalization>();
    if Assigned(localizer) then
      localizer.Culture := lang.Split([','])[0].Trim;
  end;
end;
```

---

## AddIfNotFound

When `AddIfNotFound = True`, if a key does not exist in the translations file, it is automatically added with the key itself as the value. Useful during development to identify untranslated keys:

```pascal
opt.AddIfNotFound := True;

// If 'newKey' does not exist in the JSON file:
var text := fLocalizer['newKey'];
// → returns 'newKey' and adds it to the file
```

---

## See also

- [Dependency Injection](Dependency-Injection.md) — `AddLocalization`, scoped lifetimes
- [MVC](MVC.md) — action filters, culture middleware


---

## Tabla de contenidos

1. [Conceptos básicos](#conceptos-básicos)
2. [Registrar Localization (DI)](#registrar-localization-di)
3. [Archivos de cultura](#archivos-de-cultura)
4. [Usar IStringLocalization](#usar-istringlocalization)
5. [Cambiar cultura en runtime](#cambiar-cultura-en-runtime)
6. [Localización en controllers MVC](#localización-en-controllers-mvc)
7. [AddIfNotFound](#addifnotfound)
8. [Ver también](#ver-también)

---

## Conceptos básicos

| Clase / Interfaz | Rol |
|-----------------|-----|
| `IStringLocalization` | Interfaz principal; acceso a traducciones por clave |
| `TStringLocalization` | Implementación concreta; scoped (una por request) |
| `ILocalizationStore` | Abstracción de almacenamiento de traducciones |
| `TFileLocalizationStore` | Carga traducciones desde archivos JSON en `locales/` |
| `TLocalizationOptions` | Opciones: culturas soportadas, comportamiento `AddIfNotFound` |

---

## Registrar Localization (DI)

```pascal
uses Quick.Core.Extensions.Localization;

// En ConfigureServices — configuración mínima
services.Extension<TLocalizationServiceExtension>
  .AddLocalization;

// Con opciones
services.Extension<TLocalizationServiceExtension>
  .AddLocalization(procedure(opt: TLocalizationOptions)
  begin
    opt.AddCulture('es-ES');
    opt.AddCulture('en-US');
    opt.AddCulture('fr-FR');
    opt.AddIfNotFound := True;  // añade clave si no existe en el archivo
  end);
```

### Equivalente C#

```csharp
builder.Services.AddLocalization(opt => opt.ResourcesPath = "locales");
```

---

## Archivos de cultura

Los archivos se almacenan en la carpeta `locales/` del directorio de la aplicación:

```
locales/
  es-ES.json
  en-US.json
  fr-FR.json
```

Formato JSON (pares clave → traducción):

**`locales/es-ES.json`**
```json
{
  "welcome": "Bienvenido",
  "goodbye": "Hasta luego",
  "error.notFound": "Recurso no encontrado",
  "error.unauthorized": "No autorizado",
  "product.created": "Producto '{0}' creado correctamente"
}
```

**`locales/en-US.json`**
```json
{
  "welcome": "Welcome",
  "goodbye": "Goodbye",
  "error.notFound": "Resource not found",
  "error.unauthorized": "Unauthorized",
  "product.created": "Product '{0}' created successfully"
}
```

---

## Usar IStringLocalization

```pascal
uses Quick.Core.Localization.Abstractions;

type
  TProductService = class
  private
    fLocalizer : IStringLocalization;
  public
    constructor Create(aLocalizer: IStringLocalization);

    function GetWelcomeMessage: string;
    function GetProductCreatedMsg(const aName: string): string;
  end;

function TProductService.GetWelcomeMessage: string;
begin
  // Acceso simple por clave
  Result := fLocalizer['welcome'];
end;

function TProductService.GetProductCreatedMsg(const aName: string): string;
begin
  // Con parámetros de formato (equivale a Format())
  Result := fLocalizer['product.created', [aName]];
end;
```

### En un controller MVC

```pascal
type
  [Route('api/[controller]')]
  TProductsController = class(THttpController)
  private
    fLocalizer : IStringLocalization;
    fService   : IProductService;
  public
    constructor Create(
      aLocalizer : IStringLocalization;
      aService   : IProductService);

    [HttpPost]
    function Create([FromBody] dto: TProductDto): TActionResult;
  end;

function TProductsController.Create(dto: TProductDto): TActionResult;
var
  product : TProduct;
begin
  product := fService.Create(dto);
  Result  := Ok(fLocalizer['product.created', [product.Name]]);
end;
```

### Equivalente C#

```csharp
public class ProductsController : ControllerBase
{
    private readonly IStringLocalizer<ProductsController> _localizer;

    public ProductsController(IStringLocalizer<ProductsController> loc)
        => _localizer = loc;

    [HttpPost]
    public IActionResult Create(ProductDto dto)
    {
        var product = _service.Create(dto);
        return Ok(_localizer["product.created", product.Name]);
    }
}
```

---

## Cambiar cultura en runtime

```pascal
// Establecer cultura explícitamente
fLocalizer.Culture := 'fr-FR';

// Leer cultura actual
var current := fLocalizer.Culture;  // 'fr-FR'

// Ejemplo: cambiar según preferencia del usuario
procedure TBaseController.SetCultureFromRequest;
var
  lang : string;
begin
  lang := Request.Headers.GetValue('Accept-Language');
  if lang <> '' then
    fLocalizer.Culture := lang.Split([','])[0].Trim;
end;
```

---

## Localización en controllers MVC

Para aplicar automáticamente la cultura según el header `Accept-Language`:

```pascal
// En un Action Filter global
type
  TLocalizationFilter = class(TActionFilterAttribute)
  public
    procedure OnActionExecuting(aContext: TActionExecutingContext); override;
  end;

procedure TLocalizationFilter.OnActionExecuting(aContext: TActionExecutingContext);
var
  lang      : string;
  localizer : IStringLocalization;
begin
  lang := aContext.HttpContext.Request.Headers.GetValue('Accept-Language');
  if lang <> '' then
  begin
    localizer := aContext.HttpContext.RequestServices.GetService<IStringLocalization>();
    if Assigned(localizer) then
      localizer.Culture := lang.Split([','])[0].Trim;
  end;
end;
```

---

## AddIfNotFound

Cuando `AddIfNotFound = True`, si una clave no existe en el archivo de traducciones, se añade automáticamente con la propia clave como valor. Útil durante el desarrollo para identificar claves sin traducir:

```pascal
opt.AddIfNotFound := True;

// Si 'newKey' no existe en el archivo JSON:
var text := fLocalizer['newKey'];
// → devuelve 'newKey' y lo añade al archivo
```

---

## Ver también

- [Dependency Injection](Dependency-Injection.md) — `AddLocalization`, lifetimes scoped
- [MVC](MVC.md) — action filters, middleware de cultura
