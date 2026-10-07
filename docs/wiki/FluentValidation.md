# FluentValidation Builder

QuickCore includes a fluent validation system equivalent to the `FluentValidation` library for .NET. It lets you define validation rules using a chainable API instead of data attributes, offering greater expressiveness and testability.

**Files:** `Quick.Core.Mvc.Validation.Builder.pas`

---

## Contents

1. [Basics](#basics)
2. [TValidationResult](#tvalidationresult)
3. [TPropertyRuleBuilder — chainable rules](#tpropertyrulebuilder--chainable-rules)
4. [TAbstractValidator — base validator](#tabstractvalidator--base-validator)
5. [IValidator — DI interface](#ivalidator--di-interface)
6. [Define a validator](#define-a-validator)
7. [Use the validator in a controller](#use-the-validator-in-a-controller)
8. [Available rules](#available-rules)
9. [.NET FluentValidation comparison](#net-fluentvalidation-comparison)
10. [See also](#see-also)

---

## Basics

```
TAbstractValidator<TModel>
  └── RuleFor('Email')
        └── TPropertyRuleBuilder
              ├── NotEmpty
              ├── EmailAddress
              └── WithMessage('Email is required')
```

Unlike the attribute system (`[Required]`, `[Range]`), FluentValidation allows:
- Conditional rules with `Must(predicate)`
- Custom error messages with `WithMessage`
- Validator inheritance and composition
- Testability — the validator is a plain class, testable with DUnit

---

## TValidationResult

Result of a validation. The caller is responsible for freeing it (`Free`).

```pascal
TValidationResult = class
  property IsValid : Boolean;                    // True if no errors
  property Errors  : TList<TValidationError>;    // list of errors

  procedure AddError(const aPropertyName, aErrorMessage : string);
end;

TValidationError = record
  PropertyName : string;   // property name
  ErrorMessage : string;   // error message
end;
```

### Usage

```pascal
var
  result : TValidationResult;
begin
  result := validator.Validate(model);
  try
    if not result.IsValid then
    begin
      for var err in result.Errors do
        WriteLn(err.PropertyName + ': ' + err.ErrorMessage);
    end;
  finally
    result.Free;
  end;
end;
```

---

## TPropertyRuleBuilder — chainable rules

Returned by `RuleFor`. All rules return `Self` for chaining.

```pascal
TPropertyRuleBuilder = class
  // ── String rules ────────────────────────────────────────────────────────
  function NotEmpty  : TPropertyRuleBuilder;         // not empty / not zero
  function Empty     : TPropertyRuleBuilder;         // must be empty / zero
  function Length(aMin, aMax : Integer) : TPropertyRuleBuilder;    // length between min and max
  function MaxLength(aMax : Integer)   : TPropertyRuleBuilder;     // maximum length
  function MinLength(aMin : Integer)   : TPropertyRuleBuilder;     // minimum length
  function Matches(const aPattern : string) : TPropertyRuleBuilder; // regex
  function EmailAddress : TPropertyRuleBuilder;      // valid email format

  // ── Numeric rules ───────────────────────────────────────────────────────
  function GreaterThan(aValue : Double)            : TPropertyRuleBuilder;
  function GreaterThanOrEqualTo(aValue : Double)   : TPropertyRuleBuilder;
  function LessThan(aValue : Double)               : TPropertyRuleBuilder;
  function LessThanOrEqualTo(aValue : Double)      : TPropertyRuleBuilder;
  function InclusiveBetween(aMin, aMax : Double)   : TPropertyRuleBuilder;

  // ── General rules ───────────────────────────────────────────────────────
  function NotNull : TPropertyRuleBuilder;           // not nil (object) / not empty (string)
  function Must(aPredicate : TValuePredicate) : TPropertyRuleBuilder;          // custom predicate
  function MustBeString(aPredicate : TValuePredicate<string>) : TPropertyRuleBuilder;

  // ── Custom message ───────────────────────────────────────────────────────
  function WithMessage(const aMessage : string) : TPropertyRuleBuilder;
end;
```

---

## TAbstractValidator — base validator

```pascal
TAbstractValidator<T : class> = class abstract
protected
  // Define a rule for the published property with that name
  function RuleFor(const aPropertyName : string) : TPropertyRuleBuilder;
public
  constructor Create;
  destructor Destroy; override;
  // Validate the model — returns TValidationResult (caller frees)
  function Validate(const aModel : T) : TValidationResult;
end;
```

---

## IValidator — DI interface

To inject validators via DI use `IValidator<T>`. `TValidatorAdapter<T>` adapts any `TAbstractValidator<T>`.

```pascal
IValidator<T : class> = interface
  function Validate(const aModel : T) : TValidationResult;
end;

TValidatorAdapter<T : class> = class(TInterfacedObject, IValidator<T>)
  constructor Create(aValidator : TAbstractValidator<T>; aOwns : Boolean = True);
  function Validate(const aModel : T) : TValidationResult;
end;
```

---

## Define a validator

```pascal
uses Quick.Core.Mvc.Validation.Builder;

type
  TCreateUserRequest = class
  published
    property Name     : string;
    property Email    : string;
    property Age      : Integer;
    property Password : string;
  end;

  TCreateUserValidator = class(TAbstractValidator<TCreateUserRequest>)
  public
    constructor Create; override;
  end;

constructor TCreateUserValidator.Create;
begin
  inherited;

  RuleFor('Name')
    .NotEmpty
    .Length(2, 100)
    .WithMessage('Name must be between 2 and 100 characters');

  RuleFor('Email')
    .NotEmpty
    .EmailAddress
    .WithMessage('Email format is not valid');

  RuleFor('Age')
    .GreaterThanOrEqualTo(18)
    .LessThanOrEqualTo(120)
    .WithMessage('Age must be between 18 and 120');

  RuleFor('Password')
    .NotEmpty
    .MinLength(8)
    .Matches('^(?=.*[A-Z])(?=.*[0-9]).+$')
    .WithMessage('Password must have at least 8 characters, one uppercase letter and one number');
end;
```

---

## Use the validator in a controller

### Manual validation

```pascal
type
  TUsersController = class(THttpController)
  published
    [HttpPost]
    [Route('')]
    function Create : IActionResult;
  end;

function TUsersController.Create : IActionResult;
var
  req       : TCreateUserRequest;
  validator : TCreateUserValidator;
  vResult   : TValidationResult;
begin
  req := GetBody<TCreateUserRequest>;
  try
    validator := TCreateUserValidator.Create;
    try
      vResult := validator.Validate(req);
      try
        if not vResult.IsValid then
        begin
          // Build 400 response with errors
          Result := BadRequest(vResult.Errors);
          Exit;
        end;
        // ... create user
        Result := Created('/api/users/' + newId.ToString, userDto);
      finally
        vResult.Free;
      end;
    finally
      validator.Free;
    end;
  finally
    req.Free;
  end;
end;
```

### With dependency injection

```pascal
// In Startup.ConfigureServices:
services.AddSingleton<IValidator<TCreateUserRequest>>(
  TValidatorAdapter<TCreateUserRequest>.Create(TCreateUserValidator.Create)
);

// In the controller:
type
  TUsersController = class(THttpController)
  private
    fValidator : IValidator<TCreateUserRequest>;
  public
    constructor Create(aValidator : IValidator<TCreateUserRequest>);
  published
    [HttpPost]
    function Create : IActionResult;
  end;

function TUsersController.Create : IActionResult;
var
  req     : TCreateUserRequest;
  vResult : TValidationResult;
begin
  req     := GetBody<TCreateUserRequest>;
  vResult := fValidator.Validate(req);
  try
    if not vResult.IsValid then
      Exit(BadRequest(vResult.Errors));
    // ...
  finally
    vResult.Free;
    req.Free;
  end;
end;
```

---

## Available rules

| Method | .NET equivalent | Description |
|--------|----------------|-------------|
| `NotEmpty` | `NotEmpty()` | String/numeric not empty/zero |
| `Empty` | `Empty()` | String/numeric empty/zero |
| `Length(min, max)` | `Length(min, max)` | String length between min and max |
| `MaxLength(max)` | `MaximumLength(max)` | Maximum length |
| `MinLength(min)` | `MinimumLength(min)` | Minimum length |
| `Matches(pattern)` | `Matches(pattern)` | Regex |
| `EmailAddress` | `EmailAddress()` | Valid email format |
| `GreaterThan(v)` | `GreaterThan(v)` | Greater than |
| `GreaterThanOrEqualTo(v)` | `GreaterThanOrEqualTo(v)` | Greater than or equal to |
| `LessThan(v)` | `LessThan(v)` | Less than |
| `LessThanOrEqualTo(v)` | `LessThanOrEqualTo(v)` | Less than or equal to |
| `InclusiveBetween(min, max)` | `InclusiveBetween(min, max)` | Inclusive range |
| `NotNull` | `NotNull()` | Not nil / not empty |
| `Must(pred)` | `Must(pred)` | Custom predicate |
| `MustBeString(pred)` | `Must(x => ...)` | Typed string predicate |
| `WithMessage(msg)` | `WithMessage(msg)` | Custom message for the LAST rule |

---

## .NET FluentValidation comparison

```csharp
// C# — FluentValidation
public class CreateUserValidator : AbstractValidator<CreateUserRequest>
{
    public CreateUserValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty()
            .Length(2, 100)
            .WithMessage("Name must be between 2 and 100 characters");

        RuleFor(x => x.Email)
            .NotEmpty()
            .EmailAddress();

        RuleFor(x => x.Age)
            .GreaterThanOrEqualTo(18)
            .LessThanOrEqualTo(120);
    }
}

// Usage:
var result = validator.Validate(request);
if (!result.IsValid)
    return BadRequest(result.Errors);
```

```pascal
// Delphi — QuickCore FluentValidation
constructor TCreateUserValidator.Create;
begin
  inherited;
  RuleFor('Name')
    .NotEmpty
    .Length(2, 100)
    .WithMessage('Name must be between 2 and 100 characters');
  RuleFor('Email')
    .NotEmpty
    .EmailAddress;
  RuleFor('Age')
    .GreaterThanOrEqualTo(18)
    .LessThanOrEqualTo(120);
end;

// Usage:
vResult := validator.Validate(request);
if not vResult.IsValid then
  Exit(BadRequest(vResult.Errors));
```

| Feature | FluentValidation (.NET) | QuickCore |
|---------|------------------------|-----------|
| Base class | `AbstractValidator<T>` | `TAbstractValidator<T>` |
| Define rule | `RuleFor(x => x.Prop)` | `RuleFor('PropName')` |
| Result | `ValidationResult.IsValid` | `TValidationResult.IsValid` |
| Errors | `result.Errors` (`ValidationFailure` list) | `result.Errors` (`TValidationError` list) |
| DI | `IValidator<T>` | `IValidator<T>` / `TValidatorAdapter<T>` |
| Custom predicate | `.Must(predicate)` | `.Must(TValuePredicate)` |

> **Key difference:** QuickCore uses the property name as a string (`RuleFor('Email')`) instead of a lambda expression, since Delphi does not have property lambda expressions in the same way as C#. Validation is done via RTTI.

---

## See also

- [MVC.md](MVC.md) — Model Validation with attributes (`[Required]`, `[Range]`)
- [Security.md](Security.md) — Authorization and authentication
- [docs/API-Reference.md](../API-Reference.md#26-fluentvalidation-builder) — full reference


**Archivos:** `Quick.Core.Mvc.Validation.Builder.pas`

---

## Contenido

1. [Conceptos básicos](#conceptos-básicos)
2. [TValidationResult](#tvalidationresult)
3. [TPropertyRuleBuilder — reglas encadenables](#tpropertyrulebuilder--reglas-encadenables)
4. [TAbstractValidator — validador base](#tabstractvalidator--validador-base)
5. [IValidator — interfaz DI](#ivalidator--interfaz-di)
6. [Definir un validador](#definir-un-validador)
7. [Usar el validador en un controller](#usar-el-validador-en-un-controller)
8. [Reglas disponibles](#reglas-disponibles)
9. [Comparativa .NET FluentValidation](#comparativa-net-fluentvalidation)
10. [Ver también](#ver-también)

---

## Conceptos básicos

```
TAbstractValidator<TModel>
  └── RuleFor('Email')
        └── TPropertyRuleBuilder
              ├── NotEmpty
              ├── EmailAddress
              └── WithMessage('Email is required')
```

A diferencia del sistema de atributos (`[Required]`, `[Range]`), FluentValidation permite:
- Reglas condicionales con `Must(predicate)`
- Mensajes de error personalizados con `WithMessage`
- Herencia y composición de validadores
- Testabilidad — el validador es una clase normal, testeable con DUnit

---

## TValidationResult

Resultado de una validación. El caller es responsable de liberarlo (`Free`).

```pascal
TValidationResult = class
  property IsValid : Boolean;                    // True si no hay errores
  property Errors  : TList<TValidationError>;    // lista de errores

  procedure AddError(const aPropertyName, aErrorMessage : string);
end;

TValidationError = record
  PropertyName : string;   // nombre de la propiedad
  ErrorMessage : string;   // mensaje de error
end;
```

### Uso

```pascal
var
  result : TValidationResult;
begin
  result := validator.Validate(model);
  try
    if not result.IsValid then
    begin
      for var err in result.Errors do
        WriteLn(err.PropertyName + ': ' + err.ErrorMessage);
    end;
  finally
    result.Free;
  end;
end;
```

---

## TPropertyRuleBuilder — reglas encadenables

Devuelto por `RuleFor`. Todas las reglas devuelven `Self` para encadenamiento.

```pascal
TPropertyRuleBuilder = class
  // ── Reglas de cadena ──────────────────────────────────────────────────────
  function NotEmpty  : TPropertyRuleBuilder;         // no vacío / no cero
  function Empty     : TPropertyRuleBuilder;         // debe estar vacío / ser cero
  function Length(aMin, aMax : Integer) : TPropertyRuleBuilder;    // longitud entre min y max
  function MaxLength(aMax : Integer)   : TPropertyRuleBuilder;     // longitud máxima
  function MinLength(aMin : Integer)   : TPropertyRuleBuilder;     // longitud mínima
  function Matches(const aPattern : string) : TPropertyRuleBuilder; // regex
  function EmailAddress : TPropertyRuleBuilder;      // formato e-mail válido

  // ── Reglas numéricas ──────────────────────────────────────────────────────
  function GreaterThan(aValue : Double)            : TPropertyRuleBuilder;
  function GreaterThanOrEqualTo(aValue : Double)   : TPropertyRuleBuilder;
  function LessThan(aValue : Double)               : TPropertyRuleBuilder;
  function LessThanOrEqualTo(aValue : Double)      : TPropertyRuleBuilder;
  function InclusiveBetween(aMin, aMax : Double)   : TPropertyRuleBuilder;

  // ── Reglas generales ─────────────────────────────────────────────────────
  function NotNull : TPropertyRuleBuilder;           // no nil (objeto) / no vacío (string)
  function Must(aPredicate : TValuePredicate) : TPropertyRuleBuilder;          // predicado custom
  function MustBeString(aPredicate : TValuePredicate<string>) : TPropertyRuleBuilder;

  // ── Mensaje personalizado ─────────────────────────────────────────────────
  function WithMessage(const aMessage : string) : TPropertyRuleBuilder;
end;
```

---

## TAbstractValidator — validador base

```pascal
TAbstractValidator<T : class> = class abstract
protected
  // Definir una regla para la propiedad publicada con ese nombre
  function RuleFor(const aPropertyName : string) : TPropertyRuleBuilder;
public
  constructor Create;
  destructor Destroy; override;
  // Validar el modelo — devuelve TValidationResult (caller libera)
  function Validate(const aModel : T) : TValidationResult;
end;
```

---

## IValidator — interfaz DI

Para inyectar validadores vía DI use `IValidator<T>`. `TValidatorAdapter<T>` adapta cualquier `TAbstractValidator<T>`.

```pascal
IValidator<T : class> = interface
  function Validate(const aModel : T) : TValidationResult;
end;

TValidatorAdapter<T : class> = class(TInterfacedObject, IValidator<T>)
  constructor Create(aValidator : TAbstractValidator<T>; aOwns : Boolean = True);
  function Validate(const aModel : T) : TValidationResult;
end;
```

---

## Definir un validador

```pascal
uses Quick.Core.Mvc.Validation.Builder;

type
  TCreateUserRequest = class
  published
    property Name     : string;
    property Email    : string;
    property Age      : Integer;
    property Password : string;
  end;

  TCreateUserValidator = class(TAbstractValidator<TCreateUserRequest>)
  public
    constructor Create; override;
  end;

constructor TCreateUserValidator.Create;
begin
  inherited;

  RuleFor('Name')
    .NotEmpty
    .Length(2, 100)
    .WithMessage('El nombre debe tener entre 2 y 100 caracteres');

  RuleFor('Email')
    .NotEmpty
    .EmailAddress
    .WithMessage('El e-mail no tiene un formato válido');

  RuleFor('Age')
    .GreaterThanOrEqualTo(18)
    .LessThanOrEqualTo(120)
    .WithMessage('La edad debe estar entre 18 y 120');

  RuleFor('Password')
    .NotEmpty
    .MinLength(8)
    .Matches('^(?=.*[A-Z])(?=.*[0-9]).+$')
    .WithMessage('La contraseña debe tener al menos 8 caracteres, una mayúscula y un número');
end;
```

---

## Usar el validador en un controller

### Validación manual

```pascal
type
  TUsersController = class(THttpController)
  published
    [HttpPost]
    [Route('')]
    function Create : IActionResult;
  end;

function TUsersController.Create : IActionResult;
var
  req       : TCreateUserRequest;
  validator : TCreateUserValidator;
  vResult   : TValidationResult;
begin
  req := GetBody<TCreateUserRequest>;
  try
    validator := TCreateUserValidator.Create;
    try
      vResult := validator.Validate(req);
      try
        if not vResult.IsValid then
        begin
          // Construir respuesta 400 con los errores
          Result := BadRequest(vResult.Errors);
          Exit;
        end;
        // ... crear usuario
        Result := Created('/api/users/' + newId.ToString, userDto);
      finally
        vResult.Free;
      end;
    finally
      validator.Free;
    end;
  finally
    req.Free;
  end;
end;
```

### Con inyección de dependencias

```pascal
// En Startup.ConfigureServices:
services.AddSingleton<IValidator<TCreateUserRequest>>(
  TValidatorAdapter<TCreateUserRequest>.Create(TCreateUserValidator.Create)
);

// En el controller:
type
  TUsersController = class(THttpController)
  private
    fValidator : IValidator<TCreateUserRequest>;
  public
    constructor Create(aValidator : IValidator<TCreateUserRequest>);
  published
    [HttpPost]
    function Create : IActionResult;
  end;

function TUsersController.Create : IActionResult;
var
  req     : TCreateUserRequest;
  vResult : TValidationResult;
begin
  req     := GetBody<TCreateUserRequest>;
  vResult := fValidator.Validate(req);
  try
    if not vResult.IsValid then
      Exit(BadRequest(vResult.Errors));
    // ...
  finally
    vResult.Free;
    req.Free;
  end;
end;
```

---

## Reglas disponibles

| Método | Equivalente .NET | Descripción |
|--------|-----------------|-------------|
| `NotEmpty` | `NotEmpty()` | String/numérico no vacío/cero |
| `Empty` | `Empty()` | String/numérico vacío/cero |
| `Length(min, max)` | `Length(min, max)` | Longitud de string entre min y max |
| `MaxLength(max)` | `MaximumLength(max)` | Longitud máxima |
| `MinLength(min)` | `MinimumLength(min)` | Longitud mínima |
| `Matches(pattern)` | `Matches(pattern)` | Regex |
| `EmailAddress` | `EmailAddress()` | Formato e-mail válido |
| `GreaterThan(v)` | `GreaterThan(v)` | Mayor que |
| `GreaterThanOrEqualTo(v)` | `GreaterThanOrEqualTo(v)` | Mayor o igual que |
| `LessThan(v)` | `LessThan(v)` | Menor que |
| `LessThanOrEqualTo(v)` | `LessThanOrEqualTo(v)` | Menor o igual que |
| `InclusiveBetween(min, max)` | `InclusiveBetween(min, max)` | Rango inclusivo |
| `NotNull` | `NotNull()` | No nil / no vacío |
| `Must(pred)` | `Must(pred)` | Predicado personalizado |
| `MustBeString(pred)` | `Must(x => ...)` | Predicado sobre string tipado |
| `WithMessage(msg)` | `WithMessage(msg)` | Mensaje personalizado para la ÚLTIMA regla |

---

## Comparativa .NET FluentValidation

```csharp
// C# — FluentValidation
public class CreateUserValidator : AbstractValidator<CreateUserRequest>
{
    public CreateUserValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty()
            .Length(2, 100)
            .WithMessage("El nombre debe tener entre 2 y 100 caracteres");

        RuleFor(x => x.Email)
            .NotEmpty()
            .EmailAddress();

        RuleFor(x => x.Age)
            .GreaterThanOrEqualTo(18)
            .LessThanOrEqualTo(120);
    }
}

// Uso:
var result = validator.Validate(request);
if (!result.IsValid)
    return BadRequest(result.Errors);
```

```pascal
// Delphi — QuickCore FluentValidation
constructor TCreateUserValidator.Create;
begin
  inherited;
  RuleFor('Name')
    .NotEmpty
    .Length(2, 100)
    .WithMessage('El nombre debe tener entre 2 y 100 caracteres');
  RuleFor('Email')
    .NotEmpty
    .EmailAddress;
  RuleFor('Age')
    .GreaterThanOrEqualTo(18)
    .LessThanOrEqualTo(120);
end;

// Uso:
vResult := validator.Validate(request);
if not vResult.IsValid then
  Exit(BadRequest(vResult.Errors));
```

| Característica | FluentValidation (.NET) | QuickCore |
|---------------|------------------------|-----------|
| Clase base | `AbstractValidator<T>` | `TAbstractValidator<T>` |
| Definir regla | `RuleFor(x => x.Prop)` | `RuleFor('PropName')` |
| Resultado | `ValidationResult.IsValid` | `TValidationResult.IsValid` |
| Errores | `result.Errors` (lista `ValidationFailure`) | `result.Errors` (lista `TValidationError`) |
| DI | `IValidator<T>` | `IValidator<T>` / `TValidatorAdapter<T>` |
| Predicado custom | `.Must(predicate)` | `.Must(TValuePredicate)` |

> **Diferencia clave:** QuickCore usa el nombre de la propiedad como string (`RuleFor('Email')`) en lugar de expresión lambda, ya que Delphi no tiene expresiones lambda sobre propiedades de la misma forma que C#. La validación se realiza vía RTTI.

---

## Ver también

- [MVC.md](MVC.md) — Model Validation con atributos (`[Required]`, `[Range]`)
- [Security.md](Security.md) — Autorización y autenticación
- [docs/API-Reference.md](../API-Reference.md#26-fluentvalidation-builder) — referencia completa
