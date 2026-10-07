# Data Protection

> Modules: `Quick.Core.DataProtection`, `Quick.Core.DataProtection.KeyStore.File`, `Quick.Core.Extensions.DataProtection`  
> .NET equivalent: `Microsoft.AspNetCore.DataProtection`

QuickCore Data Protection provides authenticated encryption of sensitive data (tokens, cookies, session IDs…) with a purpose-specific API. Each purpose generates an independent derived key, so data encrypted for one purpose cannot be decrypted by another.

---

## Table of contents

1. [Basics](#basics)
2. [DI registration](#di-registration)
3. [Basic usage](#basic-usage)
4. [Chained purposes](#chained-purposes)
5. [File key store](#file-key-store)
6. [Configuration options](#configuration-options)
7. [Security considerations](#security-considerations)
8. [.NET comparison](#net-comparison)
9. [See also](#see-also)

---

## Basics

| Interface / Class | Role |
|-----------------|-----|
| `IDataProtectionProvider` | Protector factory. Resolved via DI. |
| `IDataProtector` | Encrypts (`Protect`) and decrypts (`Unprotect`) for a specific purpose. |
| `TDataProtectionOptions` | `ApplicationName`, `KeyLifetimeDays` (90 days by default). |
| `TDataProtector` | HMAC-SHA256 + keystream derived from HKDF/PBKDF2. |
| `TDataProtectionProvider` | **In-memory** key ring (lost on restart). |
| `TFileKeyStoreDataProtectionProvider` | **File-persisted** key ring (survives restarts). |
| `EDataProtectionError` | Exception raised on tampering or key-miss. |
| `SecureRandomBytes(n)` | Generates `n` cryptographically secure bytes (OS CSPRNG). |

---

## DI registration

### Ephemeral keys (in memory)

Keys are lost when the process restarts. Valid for short-lived tokens or stateless environments.

```pascal
uses Quick.Core.Extensions.DataProtection;

// In ConfigureServices:
services.Extension<TDataProtectionServiceExtension>
  .AddDataProtection('MyApp');
  //  ApplicationName = 'MyApp'  (baked into every key)
  //  KeyLifetimeDays = 90       (default)
```

### File-persisted keys

The master key is written to disk in Base64. If the file does not exist, a new one is generated with `SecureRandomBytes(32)`.

```pascal
uses Quick.Core.Extensions.DataProtection;

services.Extension<TDataProtectionServiceExtension>
  .AddDataProtectionWithFileStore(
    '/var/app/keys/master.key',  // file path
    'MyApp',                     // ApplicationName
    90);                         // KeyLifetimeDays
```

> **Security:** restrict access to the key file with OS permissions (e.g. `chmod 600`).

---

## Basic usage

```pascal
uses Quick.Core.DataProtection;

// Inject the provider:
constructor TMyService.Create(aProvider: IDataProtectionProvider);
begin
  fProtector := aProvider.CreateProtector('MyApp.Auth.Cookie');
end;

// Encrypt:
var token := fProtector.Protect('user-id:42|role:admin');

// Decrypt (raises EDataProtectionError if tampered):
var plain := fProtector.Unprotect(token);
```

---

## Chained purposes

Each call to `CreateProtector` on an existing protector creates a child protector with a different derived key. This guarantees total isolation between uses.

```pascal
var rootProtector   := provider.CreateProtector('MyApp');
var authProtector   := rootProtector.CreateProtector('Auth');
var cookieProtector := authProtector.CreateProtector('Cookie');

// Equivalent to:
var sameProtector := provider.CreateProtector('MyApp')
                              .CreateProtector('Auth')
                              .CreateProtector('Cookie');

// Data encrypted with cookieProtector CANNOT be decrypted
// with rootProtector or authProtector.
```

---

## File key store

`TFileKeyStoreDataProtectionProvider` extends `TDataProtectionProvider` and overrides the master key by reading it from a file on startup.

```pascal
uses Quick.Core.DataProtection.KeyStore.File;

// Direct use (without DI):
var provider := TFileKeyStoreDataProtectionProvider.Create(
  '/var/keys/master.key',
  'MyApp',
  90);
try
  var protector := provider.CreateProtector('MyPurpose');
  var encrypted := protector.Protect('secret-value');
finally
  provider.Free;
end;
```

---

## Configuration options

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `ApplicationName` | `string` | `'QuickCore'` | Logical app name — baked into every key. Keys from different app names are incompatible. |
| `KeyLifetimeDays` | `Integer` | `90` | Days until a key is considered expired. |

---

## Security considerations

> The implementation uses XOR with a SHA-256-derived keystream plus HMAC for authentication. For PCI/HIPAA environments, replace `TDataProtector.EncryptBytes/DecryptBytes` with AES-256-CBC or AES-256-GCM (available in `System.Security.Cryptography` or OpenSSL).

- **Do not share the key** between applications with different names — always use `ApplicationName`.
- **Use `SecureRandomBytes`** to generate secrets; never use `Random()`.
- If you rotate the file key, data encrypted with the previous key can no longer be decrypted — plan for key rotation.

---

## .NET comparison

| Feature | ASP.NET Core DataProtection | QuickCore |
|---------|---------------------------|-----------|
| Interface | `IDataProtectionProvider` / `IDataProtector` | `IDataProtectionProvider` / `IDataProtector` |
| Encryption | AES-256-CBC + HMAC-SHA256 | XOR-keystream + HMAC-SHA256 |
| Purposes | `.CreateProtector("purpose")` | `.CreateProtector('purpose')` |
| Key store | `.PersistKeysToFileSystem(path)` | `AddDataProtectionWithFileStore(path, ...)` |
| In-memory key ring | `.SetApplicationName(name)` without store | `AddDataProtection(appName)` |
| DI | `services.AddDataProtection()` | `services.Extension<TDataProtectionServiceExtension>.AddDataProtection(...)` |
| Key expiry | `SetDefaultKeyLifetime(TimeSpan)` | `KeyLifetimeDays` in `TDataProtectionOptions` |

---

## See also

- [Security](Security.md) — session cookie and token encryption
- [Dependency Injection](Dependency-Injection.md) — `AddDataProtection`, resolving `IDataProtectionProvider`
- [API Reference](../API-Reference.md)


---

## Tabla de contenidos

1. [Conceptos básicos](#conceptos-básicos)
2. [Registro DI](#registro-di)
3. [Uso básico](#uso-básico)
4. [Propósitos encadenados](#propósitos-encadenados)
5. [Key Store de fichero](#key-store-de-fichero)
6. [Opciones de configuración](#opciones-de-configuración)
7. [Consideraciones de seguridad](#consideraciones-de-seguridad)
8. [Comparativa .NET](#comparativa-net)
9. [Ver también](#ver-también)

---

## Conceptos básicos

| Interfaz / Clase | Rol |
|-----------------|-----|
| `IDataProtectionProvider` | Fábrica de protectores. Se resuelve por DI. |
| `IDataProtector` | Cifra (`Protect`) y descifra (`Unprotect`) para un propósito concreto. |
| `TDataProtectionOptions` | `ApplicationName`, `KeyLifetimeDays` (90 días por defecto). |
| `TDataProtector` | Implementación HMAC-SHA256 + keystream derivado de HKDF/PBKDF2. |
| `TDataProtectionProvider` | Key ring **en memoria** (se pierde al reiniciar). |
| `TFileKeyStoreDataProtectionProvider` | Key ring **persistido en fichero** (sobrevive reinicios). |
| `EDataProtectionError` | Excepción lanzada en tampering o key-miss. |
| `SecureRandomBytes(n)` | Genera `n` bytes criptográficamente seguros (OS CSPRNG). |

---

## Registro DI

### Claves efímeras (en memoria)

Las claves se pierden al reiniciar el proceso. Válido para tokens de corta duración o entornos sin estado persistente.

```pascal
uses Quick.Core.Extensions.DataProtection;

// En ConfigureServices:
services.Extension<TDataProtectionServiceExtension>
  .AddDataProtection('MiApp');
  //  ApplicationName = 'MiApp'  (baked into every key)
  //  KeyLifetimeDays = 90       (default)
```

### Claves persistidas en fichero

La clave maestra se escribe en disco en Base64. Si el fichero no existe se genera uno nuevo con `SecureRandomBytes(32)`.

```pascal
uses Quick.Core.Extensions.DataProtection;

services.Extension<TDataProtectionServiceExtension>
  .AddDataProtectionWithFileStore(
    '/var/app/keys/master.key',  // ruta del fichero
    'MiApp',                     // ApplicationName
    90);                         // KeyLifetimeDays
```

> **Seguridad:** restringe el acceso al fichero de clave con permisos de SO (p.ej. `chmod 600`).

---

## Uso básico

```pascal
uses Quick.Core.DataProtection;

// Inyectar el provider:
constructor TMyService.Create(aProvider: IDataProtectionProvider);
begin
  fProtector := aProvider.CreateProtector('MiApp.Auth.Cookie');
end;

// Cifrar:
var token := fProtector.Protect('user-id:42|role:admin');

// Descifrar (lanza EDataProtectionError si está manipulado):
var plain := fProtector.Unprotect(token);
```

---

## Propósitos encadenados

Cada llamada a `CreateProtector` sobre un protector existente crea un protector hijo con una clave derivada diferente. Esto garantiza aislamiento total entre usos.

```pascal
var rootProtector  := provider.CreateProtector('MiApp');
var authProtector  := rootProtector.CreateProtector('Auth');
var cookieProtector := authProtector.CreateProtector('Cookie');

// Equivalente a:
var sameProtector := provider.CreateProtector('MiApp')
                              .CreateProtector('Auth')
                              .CreateProtector('Cookie');

// Los datos cifrados con cookieProtector NO se pueden descifrar
// con rootProtector ni authProtector.
```

---

## Key Store de fichero

`TFileKeyStoreDataProtectionProvider` extiende `TDataProtectionProvider` y sobrescribe la clave maestra leyéndola de un fichero al iniciar.

```pascal
uses Quick.Core.DataProtection.KeyStore.File;

// Uso directo (sin DI):
var provider := TFileKeyStoreDataProtectionProvider.Create(
  '/var/keys/master.key',
  'MiApp',
  90);
try
  var protector := provider.CreateProtector('MyPurpose');
  var encrypted := protector.Protect('secret-value');
finally
  provider.Free;
end;
```

---

## Opciones de configuración

| Propiedad | Tipo | Default | Descripción |
|-----------|------|---------|-------------|
| `ApplicationName` | `string` | `'QuickCore'` | Nombre lógico de la app — baked into every key. Claves de apps diferentes son incompatibles. |
| `KeyLifetimeDays` | `Integer` | `90` | Días hasta que una clave se considera expirada. |

---

## Consideraciones de seguridad

> La implementación usa XOR con keystream derivado de SHA-256 más HMAC para autenticación. Para entornos PCI/HIPAA, reemplaza `TDataProtector.EncryptBytes/DecryptBytes` con AES-256-CBC o AES-256-GCM (disponible en `System.Security.Cryptography` o OpenSSL).

- **No compartas la clave** entre aplicaciones con nombres distintos — usa siempre `ApplicationName`.
- **Usa `SecureRandomBytes`** para generar secretos; nunca `Random()`.
- Si rotas la clave de fichero, los datos cifrados con la clave anterior dejan de ser descifrabless — planifica key rotation.

---

## Comparativa .NET

| Feature | ASP.NET Core DataProtection | QuickCore |
|---------|---------------------------|-----------|
| Interfaz | `IDataProtectionProvider` / `IDataProtector` | `IDataProtectionProvider` / `IDataProtector` |
| Cifrado | AES-256-CBC + HMAC-SHA256 | XOR-keystream + HMAC-SHA256 |
| Propósitos | `.CreateProtector("purpose")` | `.CreateProtector('purpose')` |
| Key store | `.PersistKeysToFileSystem(path)` | `AddDataProtectionWithFileStore(path, ...)` |
| Key ring en memoria | `.SetApplicationName(name)` sin store | `AddDataProtection(appName)` |
| DI | `services.AddDataProtection()` | `services.Extension<TDataProtectionServiceExtension>.AddDataProtection(...)` |
| Expiración key | `SetDefaultKeyLifetime(TimeSpan)` | `KeyLifetimeDays` en `TDataProtectionOptions` |

---

## Ver también

- [Security](Security.md) — cifrado de cookies de sesión y tokens
- [Dependency Injection](Dependency-Injection.md) — `AddDataProtection`, resolución de `IDataProtectionProvider`
- [API Reference](../API-Reference.md)
