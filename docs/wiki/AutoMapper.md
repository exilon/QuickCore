# AutoMapper

> Module: `Quick.Core.AutoMapper`  
> .NET equivalent: `AutoMapper` (NuGet)

QuickCore AutoMapper maps properties between objects using RTTI, eliminating manual copy boilerplate. It supports profiles, custom mappings, type converters, conditions, hooks, and configuration validation.

---

## Table of contents

1. [Basics](#basics)
2. [Register AutoMapper (DI)](#register-automapper-di)
3. [Profiles and mappings](#profiles-and-mappings)
4. [Automatic RTTI mapping](#automatic-rtti-mapping)
5. [ForMember — rename properties](#formember--rename-properties)
6. [ReverseMap — inverse mapping](#reversemap--inverse-mapping)
7. [Condition — conditional mapping](#condition--conditional-mapping)
8. [ConvertUsing — type converter](#convertusing--type-converter)
9. [NullSubstitute — default value](#nullsubstitute--default-value)
10. [BeforeMap / AfterMap — hooks](#beforemap--aftermap--hooks)
11. [AssertConfigurationIsValid](#assertconfigurationisvalid)
12. [List mapping](#list-mapping)
13. [See also](#see-also)

---

## Basics

| Class / Interface | Role |
|-----------------|-----|
| `IMapper` | Main mapping interface |
| `TAutoMapper` | Concrete implementation |
| `TProfile` | Base class for declaring mappings |
| `TProfileMap` | Configuration for a source→destination pair (fluent API) |
| `TMapProc<Src,Dst>` | Custom mapping procedure |
| `TValueConverterFunc` | Function that transforms one `TValue` into another |

---

## Register AutoMapper (DI)

```pascal
uses Quick.Core.Extensions.AutoMapper;

// In ConfigureServices
services.Extension<TAutoMapperServiceExtension>
  .AddAutoMapper;

// Register profiles (after AddAutoMapper)
TAutoMapper.RegisterProfile<TShopProfile>;
```

---

## Profiles and mappings

```pascal
uses Quick.Core.AutoMapper;

type
  // DTOs
  TProductDto = class
  published
    property Id    : Integer read fId    write fId;
    property Name  : string  read fName  write fName;
    property Price : Double  read fPrice write fPrice;
  end;

  // Entity
  TProduct = class
  published
    property Id       : Integer read fId       write fId;
    property Name     : string  read fName     write fName;
    property Price    : Double  read fPrice    write fPrice;
    property Category : string  read fCategory write fCategory;
  end;

  // Profile
  TShopProfile = class(TProfile)
  public
    procedure Configure; override;
  end;

procedure TShopProfile.Configure;
begin
  // Automatic mapping TProduct → TProductDto
  CreateMap<TProduct, TProductDto>;

  // With custom proc
  CreateMap<TProductDto, TProduct>(procedure(src: TProductDto; dst: TProduct)
  begin
    dst.Id    := src.Id;
    dst.Name  := src.Name;
    dst.Price := src.Price;
    // Category is not in the DTO — omitted or filled externally
  end);
end;
```

### C# equivalent

```csharp
public class ShopProfile : Profile
{
    public ShopProfile()
    {
        CreateMap<Product, ProductDto>();
        CreateMap<ProductDto, Product>()
            .ForMember(d => d.Category, opt => opt.Ignore());
    }
}
```

---

## Automatic RTTI mapping

Without a custom proc, AutoMapper copies all properties with matching names and types:

```pascal
// Inject the mapper
type
  TProductService = class
  private
    fMapper : IMapper;
  public
    constructor Create(aMapper: IMapper);

    function ToDto(aProduct: TProduct): TProductDto;
    function ToEntity(aDto: TProductDto): TProduct;
  end;

function TProductService.ToDto(aProduct: TProduct): TProductDto;
begin
  // Creates TProductDto and copies properties automatically
  Result := fMapper.Map<TProductDto>(aProduct);
end;

function TProductService.ToEntity(aDto: TProductDto): TProduct;
begin
  Result := fMapper.Map<TProduct>(aDto);
end;

// In-place mapping (destination already exists)
fMapper.Map(srcProduct, dstProduct);
```

---

## ForMember — rename properties

When the property name differs between source and destination:

```pascal
CreateMap<TUserEntity, TUserDto>
  .ForMember('FullName', 'DisplayName')  // src.FullName → dst.DisplayName
  .ForMember('Email', 'ContactEmail');   // src.Email → dst.ContactEmail
```

---

## ReverseMap — inverse mapping

Automatically registers the `B→A` mapping from `A→B`:

```pascal
CreateMap<TProduct, TProductDto>
  .ReverseMap;
// Equivalent to also registering TProductDto → TProduct
```

### C# equivalent

```csharp
CreateMap<Product, ProductDto>().ReverseMap();
```

---

## Condition — conditional mapping

Skips a destination property when the condition is not met:

```pascal
CreateMap<TProduct, TProductDto>
  .Condition('Price', function(src: TObject): Boolean
  begin
    // Only map Price if the product is active
    Result := (src as TProduct).IsActive;
  end);
```

---

## ConvertUsing — type converter

Transforms the value before assigning it:

```pascal
CreateMap<TOrder, TOrderDto>
  // Convert TDateTime → ISO8601 string
  .ConvertUsing('CreatedAt', function(src: TValue): TValue
  begin
    Result := TValue.From<string>(
      DateTimeToStr(src.AsType<TDateTime>)
    );
  end)
  // Convert cents (Integer) → euros (Double)
  .ConvertUsing('Total', function(src: TValue): TValue
  begin
    Result := TValue.From<Double>(src.AsInteger / 100.0);
  end);
```

---

## NullSubstitute — default value

Replaces `nil` or empty values with a default:

```pascal
CreateMap<TProduct, TProductDto>
  .NullSubstitute('Name',  TValue.From<string>('No name'))
  .NullSubstitute('Price', TValue.From<Double>(0.0));
```

### C# equivalent

```csharp
CreateMap<Product, ProductDto>()
    .ForMember(d => d.Name, opt => opt.NullSubstitute("No name"));
```

---

## BeforeMap / AfterMap — hooks

Runs logic before or after the automatic mapping:

```pascal
CreateMap<TUserEntity, TUserDto>
  .BeforeMap(procedure(src, dst: TObject)
  begin
    // Initialize the destination object before mapping
    (dst as TUserDto).Roles := TList<string>.Create;
  end)
  .AfterMap(procedure(src, dst: TObject)
  begin
    // Post-mapping logic
    var user := src as TUserEntity;
    var dto  := dst as TUserDto;
    dto.DisplayName := user.FirstName + ' ' + user.LastName;
  end);
```

---

## AssertConfigurationIsValid

Validates at startup that all mappings are correct:

```pascal
// On application startup (before Start)
var mapper := services.Resolve<IMapper>() as TAutoMapper;
mapper.AssertConfigurationIsValid;
// → Raises EAutoMapperError if any destination property has no source
```

> Useful for detecting broken mappings after a refactoring.

---

## List mapping

```pascal
var
  products : TObjectList<TProduct>;
  dtos     : TObjectList<TProductDto>;
begin
  products := fRepo.GetAll;

  // Map the entire list
  dtos := TObjectList<TProductDto>.Create;
  for var p in products do
    dtos.Add(fMapper.Map<TProductDto>(p));
end;
```

---

## See also

- [Dependency Injection](Dependency-Injection.md) — `AddAutoMapper`, profile registration
- [MVC](MVC.md) — mapper usage in controllers and services
- [Entity / ORM](Entity-ORM.md) — entity ↔ DTO mapping


---

## Tabla de contenidos

1. [Conceptos básicos](#conceptos-básicos)
2. [Registrar AutoMapper (DI)](#registrar-automapper-di)
3. [Crear perfiles y mapeos](#crear-perfiles-y-mapeos)
4. [Mapeo automático RTTI](#mapeo-automático-rtti)
5. [ForMember — renombrar propiedades](#formember--renombrar-propiedades)
6. [ReverseMap — mapeo inverso](#reversemap--mapeo-inverso)
7. [Condition — mapeo condicional](#condition--mapeo-condicional)
8. [ConvertUsing — conversor de tipo](#convertusing--conversor-de-tipo)
9. [NullSubstitute — valor por defecto](#nullsubstitute--valor-por-defecto)
10. [BeforeMap / AfterMap — hooks](#beforemap--aftermap--hooks)
11. [AssertConfigurationIsValid](#assertconfigurationisvalid)
12. [Mapeo de listas](#mapeo-de-listas)
13. [Ver también](#ver-también)

---

## Conceptos básicos

| Clase / Interfaz | Rol |
|-----------------|-----|
| `IMapper` | Interfaz principal de mapeo |
| `TAutoMapper` | Implementación concreta |
| `TProfile` | Clase base para declarar mapeos |
| `TProfileMap` | Configuración de un par origen→destino (fluent API) |
| `TMapProc<Src,Dst>` | Procedimiento de mapeo personalizado |
| `TValueConverterFunc` | Función que transforma un `TValue` en otro |

---

## Registrar AutoMapper (DI)

```pascal
uses Quick.Core.Extensions.AutoMapper;

// En ConfigureServices
services.Extension<TAutoMapperServiceExtension>
  .AddAutoMapper;

// Registrar perfiles (después de AddAutoMapper)
TAutoMapper.RegisterProfile<TShopProfile>;
```

---

## Crear perfiles y mapeos

```pascal
uses Quick.Core.AutoMapper;

type
  // DTOs
  TProductDto = class
  published
    property Id    : Integer read fId    write fId;
    property Name  : string  read fName  write fName;
    property Price : Double  read fPrice write fPrice;
  end;

  // Entidad
  TProduct = class
  published
    property Id       : Integer read fId       write fId;
    property Name     : string  read fName     write fName;
    property Price    : Double  read fPrice    write fPrice;
    property Category : string  read fCategory write fCategory;
  end;

  // Perfil
  TShopProfile = class(TProfile)
  public
    procedure Configure; override;
  end;

procedure TShopProfile.Configure;
begin
  // Mapeo automático TProduct → TProductDto
  CreateMap<TProduct, TProductDto>;

  // Con proc personalizado
  CreateMap<TProductDto, TProduct>(procedure(src: TProductDto; dst: TProduct)
  begin
    dst.Id    := src.Id;
    dst.Name  := src.Name;
    dst.Price := src.Price;
    // Category no viene del DTO — se omite o rellena externamente
  end);
end;
```

### Equivalente C#

```csharp
public class ShopProfile : Profile
{
    public ShopProfile()
    {
        CreateMap<Product, ProductDto>();
        CreateMap<ProductDto, Product>()
            .ForMember(d => d.Category, opt => opt.Ignore());
    }
}
```

---

## Mapeo automático RTTI

Sin proc personalizado, AutoMapper copia todas las propiedades con el mismo nombre y tipo:

```pascal
// Inyección del mapper
type
  TProductService = class
  private
    fMapper : IMapper;
  public
    constructor Create(aMapper: IMapper);

    function ToDto(aProduct: TProduct): TProductDto;
    function ToEntity(aDto: TProductDto): TProduct;
  end;

function TProductService.ToDto(aProduct: TProduct): TProductDto;
begin
  // Crea TProductDto y copia propiedades automáticamente
  Result := fMapper.Map<TProductDto>(aProduct);
end;

function TProductService.ToEntity(aDto: TProductDto): TProduct;
begin
  Result := fMapper.Map<TProduct>(aDto);
end;

// Mapeo in-place (destino ya existe)
fMapper.Map(srcProduct, dstProduct);
```

---

## ForMember — renombrar propiedades

Cuando el nombre de la propiedad es distinto en origen y destino:

```pascal
CreateMap<TUserEntity, TUserDto>
  .ForMember('FullName', 'DisplayName')  // src.FullName → dst.DisplayName
  .ForMember('Email', 'ContactEmail');   // src.Email → dst.ContactEmail
```

---

## ReverseMap — mapeo inverso

Registra automáticamente el mapeo `B→A` a partir de `A→B`:

```pascal
CreateMap<TProduct, TProductDto>
  .ReverseMap;
// Equivale a registrar también TProductDto → TProduct
```

### Equivalente C#

```csharp
CreateMap<Product, ProductDto>().ReverseMap();
```

---

## Condition — mapeo condicional

Salta una propiedad destino cuando la condición no se cumple:

```pascal
CreateMap<TProduct, TProductDto>
  .Condition('Price', function(src: TObject): Boolean
  begin
    // Solo mapear Price si el producto está activo
    Result := (src as TProduct).IsActive;
  end);
```

---

## ConvertUsing — conversor de tipo

Transforma el valor antes de asignarlo:

```pascal
CreateMap<TOrder, TOrderDto>
  // Convertir TDateTime → string ISO8601
  .ConvertUsing('CreatedAt', function(src: TValue): TValue
  begin
    Result := TValue.From<string>(
      DateTimeToStr(src.AsType<TDateTime>)
    );
  end)
  // Convertir centavos (Integer) → euros (Double)
  .ConvertUsing('Total', function(src: TValue): TValue
  begin
    Result := TValue.From<Double>(src.AsInteger / 100.0);
  end);
```

---

## NullSubstitute — valor por defecto

Sustituye valores `nil` o vacíos por un valor por defecto:

```pascal
CreateMap<TProduct, TProductDto>
  .NullSubstitute('Name',  TValue.From<string>('Sin nombre'))
  .NullSubstitute('Price', TValue.From<Double>(0.0));
```

### Equivalente C#

```csharp
CreateMap<Product, ProductDto>()
    .ForMember(d => d.Name, opt => opt.NullSubstitute("Sin nombre"));
```

---

## BeforeMap / AfterMap — hooks

Ejecuta lógica antes o después del mapeo automático:

```pascal
CreateMap<TUserEntity, TUserDto>
  .BeforeMap(procedure(src, dst: TObject)
  begin
    // Inicializar el objeto destino antes del mapeo
    (dst as TUserDto).Roles := TList<string>.Create;
  end)
  .AfterMap(procedure(src, dst: TObject)
  begin
    // Lógica post-mapeo
    var user := src as TUserEntity;
    var dto  := dst as TUserDto;
    dto.DisplayName := user.FirstName + ' ' + user.LastName;
  end);
```

---

## AssertConfigurationIsValid

Valida en arranque que todos los mapeos son correctos:

```pascal
// En el arranque de la aplicación (antes de Start)
var mapper := services.Resolve<IMapper>() as TAutoMapper;
mapper.AssertConfigurationIsValid;
// → Lanza EAutoMapperError si alguna propiedad destino no tiene origen
```

> Útil para detectar mapeos rotos tras un refactoring.

---

## Mapeo de listas

```pascal
var
  products : TObjectList<TProduct>;
  dtos     : TObjectList<TProductDto>;
begin
  products := fRepo.GetAll;

  // Mapear lista completa
  dtos := TObjectList<TProductDto>.Create;
  for var p in products do
    dtos.Add(fMapper.Map<TProductDto>(p));
end;
```

---

## Ver también

- [Dependency Injection](Dependency-Injection.md) — `AddAutoMapper`, registro de perfiles
- [MVC](MVC.md) — uso del mapper en controllers y servicios
- [Entity / ORM](Entity-ORM.md) — mapeo entidades ↔ DTOs
