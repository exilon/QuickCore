# Security — Authentication and Authorization

> Modules: `Quick.Core.Security.*`, `Quick.Core.Extensions.Authentication.*`, `Quick.Core.Extensions.Authorization`  
> .NET equivalent: `Microsoft.AspNetCore.Authentication` + `Microsoft.AspNetCore.Authorization`

QuickCore implements the complete ASP.NET Core security model: swappable authentication schemes, claims-based authorization policies, ASP.NET Identity, JWT, API Key, Cookie, and OAuth2.

---

## Table of contents

1. [Key concepts](#key-concepts)
2. [JWT Bearer Authentication](#jwt-bearer-authentication)
3. [API Key Authentication](#api-key-authentication)
4. [Cookie Authentication](#cookie-authentication)
5. [OAuth2 / OpenID Connect](#oauth2--openid-connect)
6. [Policies and roles](#policies-and-roles)
7. [Claims and ClaimsPrincipal](#claims-and-claimsprincipal)
8. [Authorization in controllers](#authorization-in-controllers)
9. [Resource-based Authorization](#resource-based-authorization)
10. [ASP.NET Identity (UserManager)](#aspnet-identity-usermanager)
11. [2FA / TOTP](#2fa--totp)
12. [Security Stamp Validation](#security-stamp-validation)
13. [See also](#see-also)

---

## Key concepts

| Class / Interface | Role | .NET equivalent |
|-----------------|-----|----------------|
| `TAuthenticationScheme` | Describes a scheme (name + handler) | `AuthenticationScheme` |
| `IAuthenticationHandler` | Implements authentication logic | `IAuthenticationHandler` |
| `TAuthenticateResult` | Authentication result (Success/Fail/NoResult) | `AuthenticateResult` |
| `IAuthenticationTicket` | Contains the authenticated `TClaimsPrincipal` | `AuthenticationTicket` |
| `TClaimsPrincipal` | Authenticated user with their claims | `ClaimsPrincipal` |
| `TClaimsIdentity` | Identity with a list of claims | `ClaimsIdentity` |
| `TClaim` | Type/value pair (e.g. `"role"/"admin"`) | `Claim` |
| `IAuthorizationService` | Evaluates policies against the current user | `IAuthorizationService` |
| `TAuthorizationPolicy` | Set of requirements to be met | `AuthorizationPolicy` |

---

## JWT Bearer Authentication

### Configuration

```pascal
uses
  Quick.Core.Extensions.Authentication,
  Quick.Core.Extensions.Authentication.Jwt;

// In ConfigureServices
services
  .Extension<TAuthenticationServiceExtension>
  .AddAuthentication
  .AddJwtBearer(procedure(opt: TJwtOptions)
  begin
    opt.Secret         := 'my-super-secure-secret-256bits';
    opt.Issuer         := 'https://my-api.com';
    opt.Audience       := 'my-client-app';
    opt.ExpiryMinutes  := 60;
    opt.ValidateIssuer    := True;
    opt.ValidateAudience  := True;
    opt.ValidateLifetime  := True;
  end);
```

### Enable in the pipeline

```pascal
app.UseAuthentication
   .UseAuthorization;
```

### Generate and validate tokens

```pascal
uses Quick.Core.Security.Jwt;

// Generate token
var
  jwtService : IJwtTokenService;
  principal  : TClaimsPrincipal;
  token      : string;
begin
  principal := TClaimsPrincipal.Create;
  principal.Identity.AddClaim(TClaim.Create('sub', userId));
  principal.Identity.AddClaim(TClaim.Create('name', userName));
  principal.Identity.AddClaim(TClaim.Create('role', 'admin'));

  token := jwtService.GenerateToken(principal);
end;

// Validate token
var
  outPrincipal : TClaimsPrincipal;
begin
  if jwtService.ValidateToken(token, outPrincipal) then
    // user authenticated
  else
    // invalid or expired token
end;
```

### Expected header

```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### C# equivalent

```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opt => {
        opt.TokenValidationParameters = new TokenValidationParameters {
            ValidateIssuer = true,
            ValidIssuer = "https://my-api.com",
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes("my-super-secure-secret-256bits"))
        };
    });
```

---

## API Key Authentication

```pascal
uses Quick.Core.Extensions.Authentication.ApiKey;

services.Extension<TAuthenticationServiceExtension>
  .AddAuthentication
  .AddApiKey(procedure(opt: TApiKeyOptions)
  begin
    opt.HeaderName := 'X-API-Key';
    opt.ApiKey     := 'my-secret-api-key';
  end);
```

The request must include:
```
X-API-Key: my-secret-api-key
```

---

## Cookie Authentication

```pascal
uses Quick.Core.Extensions.Authentication.Cookie;

services.Extension<TAuthenticationServiceExtension>
  .AddAuthentication
  .AddCookie(procedure(opt: TCookieAuthenticationOptions)
  begin
    opt.LoginPath      := '/account/login';
    opt.CookieName     := 'QuickCore.Auth';
    opt.ExpireMinutes  := 1440; // 24 hours
  end);
```

### Sign in / sign out

```pascal
// Login — in the login controller
procedure TAccountController.Login([FromBody] dto: TLoginDto);
var
  principal : TClaimsPrincipal;
  handler   : IAuthenticationSignInHandler;
begin
  // Verify credentials...
  principal := BuildPrincipal(dto.Username);
  handler   := HttpContext.GetSignInHandler('Cookies');
  handler.SignIn(principal, TAuthenticationProperties.Create);
  Result := Redirect('/dashboard');
end;

// Logout
procedure TAccountController.Logout;
var
  handler : IAuthenticationSignOutHandler;
begin
  handler := HttpContext.GetSignOutHandler('Cookies');
  handler.SignOut(nil);
  Result := Redirect('/');
end;
```

---

## OAuth2 / OpenID Connect

```pascal
uses Quick.Core.Extensions.Authentication.OAuth2;

services.Extension<TAuthenticationServiceExtension>
  .AddAuthentication
  .AddOAuth2(procedure(opt: TOAuth2Options)
  begin
    opt.Authority    := 'https://login.microsoftonline.com/tenant-id/v2.0';
    opt.ClientId     := 'my-client-id';
    opt.ClientSecret := 'my-client-secret';
  end);
```

---

## Policies and roles

```pascal
uses Quick.Core.Extensions.Authorization;

services.Extension<TAuthorizationServiceExtension>
  .AddAuthorization(procedure(opt: TAuthorizationOptions)
  begin
    // Role-based policy
    opt.AddPolicy('AdminOnly',
      TAuthorizationPolicyBuilder.Create
        .RequireRole('admin')
        .Build);

    // Claim-based policy
    opt.AddPolicy('PremiumUser',
      TAuthorizationPolicyBuilder.Create
        .RequireClaim('subscription', 'premium')
        .Build);

    // Composite policy
    opt.AddPolicy('SeniorEditor',
      TAuthorizationPolicyBuilder.Create
        .RequireRole('editor')
        .RequireClaim('seniority', 'senior')
        .RequireAuthenticatedUser
        .Build);
  end);
```

### C# equivalent

```csharp
builder.Services.AddAuthorization(opt => {
    opt.AddPolicy("AdminOnly", p => p.RequireRole("admin"));
    opt.AddPolicy("PremiumUser", p => p.RequireClaim("subscription", "premium"));
});
```

---

## Claims and ClaimsPrincipal

```pascal
uses Quick.Core.Security.Claims;

// Read claims of the current user (in a controller)
var
  userId    : string;
  userName  : string;
  isAdmin   : Boolean;
begin
  userId   := User.FindFirstValue('sub');
  userName := User.Identity.Name;
  isAdmin  := User.IsInRole('admin');

  // Iterate all claims
  for var claim in User.Identity.Claims do
    Logger.Info(claim.ClaimType + ' = ' + claim.Value);
end;
```

---

## Authorization in controllers

```pascal
// Entire controller requires authentication
[Authorize]
TProductsController = class(THttpController)

// Administrators only
[Authorize('admin')]
TAdminController = class(THttpController)

// By policy
[AuthorizePolicy('PremiumUser')]
function GetPremiumContent: TActionResult;

// Allow anonymous access even if the controller has [Authorize]
[AllowAnonymous]
function GetPublicContent: TActionResult;
```

---

## Resource-based Authorization

To authorize based on the state of a specific resource:

```pascal
uses Quick.Core.Extensions.Authorization;

// Define handler
type
  TDocumentEditRequirement = class(TAuthorizationHandler<TDocumentEditRequirement>,
                                    IAuthorizationRequirement)
  public
    function HandleRequirement(
      aContext : TAuthorizationHandlerContext;
      aReq     : TDocumentEditRequirement) : Boolean; override;
  end;

function TDocumentEditRequirement.HandleRequirement(
  aContext : TAuthorizationHandlerContext;
  aReq     : TDocumentEditRequirement) : Boolean;
var
  doc : TDocument;
begin
  doc := aContext.Resource as TDocument;
  if doc.OwnerId = aContext.User.FindFirstValue('sub') then
  begin
    aContext.Succeed(aReq);
    Result := True;
  end
  else
    Result := False;
end;

// Register
services.AddSingleton<IAuthorizationHandler, TDocumentEditRequirement>;

// Use in controller
function TDocumentController.Edit(id: Integer): TActionResult;
var
  doc : TDocument;
begin
  doc := fRepo.GetById(id);
  if not AuthorizeResource(doc, 'EditDocument') then
    Result := Forbid
  else
    Result := View;
end;
```

---

## ASP.NET Identity (UserManager)

Complete user management system with Entity storage:

```pascal
uses
  Quick.Core.Extensions.Authentication,
  Quick.Core.Identity;

// Define user and role entities
type
  TAppUser = class(TIdentityUser);
  TAppRole = class(TIdentityRole);

// Register in ConfigureServices
services.Extension<TAuthenticationServiceExtension>
  .AddIdentity<TAppUser, TAppRole>(procedure(opt: TIdentityOptions)
  begin
    // Password
    opt.Password.RequireDigit          := True;
    opt.Password.RequiredLength        := 8;
    opt.Password.RequireUppercase      := True;
    // Lockout
    opt.Lockout.MaxFailedAttempts      := 5;
    opt.Lockout.LockoutDurationMinutes := 30;
    // User
    opt.User.RequireUniqueEmail        := True;
  end)
  .AddEntityStore<TShopContext>;

// Use UserManager
procedure TAccountController.Register([FromBody] dto: TRegisterDto);
var
  userMgr : TUserManager<TAppUser>;
  user    : TAppUser;
begin
  user          := TAppUser.Create;
  user.UserName := dto.Email;
  user.Email    := dto.Email;

  if userMgr.CreateUser(user, dto.Password) then
    Result := Ok('User created')
  else
    Result := BadRequest(userMgr.LastError);
end;

procedure TAccountController.Login([FromBody] dto: TLoginDto);
var
  userMgr : TUserManager<TAppUser>;
begin
  if userMgr.CheckPassword(dto.Email, dto.Password) then
  begin
    // generate JWT or cookie
    Result := Ok(jwtService.GenerateToken(BuildPrincipal(dto.Email)));
  end
  else
    Result := Unauthorized;
end;
```

### C# equivalent

```csharp
builder.Services.AddIdentity<AppUser, AppRole>()
    .AddEntityFrameworkStores<ShopContext>();
```

---

## 2FA / TOTP

**Unit:** `Quick.Core.Security.Totp` — .NET equivalent: `Rfc6238AuthenticationService`

RFC 6238 service compatible with Google Authenticator and any standard TOTP app.

| Method | Description |
|--------|-------------|
| `GenerateCode(base32Secret)` | Generates the current 6-digit code |
| `ValidateCode(base32Secret, code, [window=1])` | Validates code; `window` = allowed ±30s steps |
| `GetProvisioningUri(secret, account, issuer)` | `otpauth://` URL for QR code generation |

```pascal
uses Quick.Core.Security.Totp;

// DI registration (singleton recommended):
services.AddSingleton<ITotpService, TTotpService>;

// In the identity service — register TOTP for a user:
var totpSvc : ITotpService;

// The Base32 secret is generated externally (or use SecureRandomBytes + Base32Encode):
var secret := '...BASE32SECRET...';  // store encrypted in DB
var qrUri  := totpSvc.GetProvisioningUri(secret, user.Email, 'MyApp');
// Show qrUri as a QR code to the user

// At login — verify entered code:
if totpSvc.ValidateCode(user.TotpSecret, dto.TotpCode) then
  // 2FA correct
else
  Exit(Unauthorized('Invalid TOTP code'));
```

### C# equivalent

```csharp
// ASP.NET Core Identity manages TOTP internally via
// IUserTwoFactorTokenProvider<T> ("Authenticator")
var key  = await userManager.GetAuthenticatorKeyAsync(user);
var uri  = _urlEncoder.Encode($"otpauth://totp/{appName}:{email}?secret={key}&issuer={appName}");
var ok   = await userManager.VerifyTwoFactorTokenAsync(user, "Authenticator", code);
```

---

## Security Stamp Validation

Automatically invalidates active sessions when the password or other sensitive data changes:

```pascal
// On password change
userMgr.UpdateSecurityStamp(user);
// → all previous sessions for the user are invalidated
```

---

## See also

- [Dependency Injection](Dependency-Injection.md) — `AddAuthentication`, `AddAuthorization`
- [MVC](MVC.md) — `UseAuthentication`, `UseAuthorization`, `[Authorize]`
- [Entity / ORM](Entity-ORM.md) — `AddEntityStore`, `TIdentityUser`


---

## Tabla de contenidos

1. [Conceptos clave](#conceptos-clave)
2. [JWT Bearer Authentication](#jwt-bearer-authentication)
3. [API Key Authentication](#api-key-authentication)
4. [Cookie Authentication](#cookie-authentication)
5. [OAuth2 / OpenID Connect](#oauth2--openid-connect)
6. [Policies y roles](#policies-y-roles)
7. [Claims y ClaimsPrincipal](#claims-y-claimsprincipal)
8. [Autorización en controllers](#autorización-en-controllers)
9. [Resource-based Authorization](#resource-based-authorization)
10. [ASP.NET Identity (UserManager)](#aspnet-identity-usermanager)
11. [2FA / TOTP](#2fa--totp)
12. [Security Stamp Validation](#security-stamp-validation)
13. [Ver también](#ver-también)

---

## Conceptos clave

| Clase / Interfaz | Rol | .NET equivalente |
|-----------------|-----|-----------------|
| `TAuthenticationScheme` | Describe un esquema (nombre + handler) | `AuthenticationScheme` |
| `IAuthenticationHandler` | Implementa la lógica de autenticación | `IAuthenticationHandler` |
| `TAuthenticateResult` | Resultado de una autenticación (Success/Fail/NoResult) | `AuthenticateResult` |
| `IAuthenticationTicket` | Contiene el `TClaimsPrincipal` autenticado | `AuthenticationTicket` |
| `TClaimsPrincipal` | Usuario autenticado con sus claims | `ClaimsPrincipal` |
| `TClaimsIdentity` | Identidad con lista de claims | `ClaimsIdentity` |
| `TClaim` | Par tipo/valor (ej. `"role"/"admin"`) | `Claim` |
| `IAuthorizationService` | Evalúa políticas contra el usuario actual | `IAuthorizationService` |
| `TAuthorizationPolicy` | Conjunto de requisitos a cumplir | `AuthorizationPolicy` |

---

## JWT Bearer Authentication

### Configuración

```pascal
uses
  Quick.Core.Extensions.Authentication,
  Quick.Core.Extensions.Authentication.Jwt;

// En ConfigureServices
services
  .Extension<TAuthenticationServiceExtension>
  .AddAuthentication
  .AddJwtBearer(procedure(opt: TJwtOptions)
  begin
    opt.Secret         := 'mi-secreto-super-seguro-256bits';
    opt.Issuer         := 'https://mi-api.com';
    opt.Audience       := 'mi-app-cliente';
    opt.ExpiryMinutes  := 60;
    opt.ValidateIssuer    := True;
    opt.ValidateAudience  := True;
    opt.ValidateLifetime  := True;
  end);
```

### Activar en el pipeline

```pascal
app.UseAuthentication
   .UseAuthorization;
```

### Generar y validar tokens

```pascal
uses Quick.Core.Security.Jwt;

// Generar token
var
  jwtService : IJwtTokenService;
  principal  : TClaimsPrincipal;
  token      : string;
begin
  principal := TClaimsPrincipal.Create;
  principal.Identity.AddClaim(TClaim.Create('sub', userId));
  principal.Identity.AddClaim(TClaim.Create('name', userName));
  principal.Identity.AddClaim(TClaim.Create('role', 'admin'));

  token := jwtService.GenerateToken(principal);
end;

// Validar token
var
  outPrincipal : TClaimsPrincipal;
begin
  if jwtService.ValidateToken(token, outPrincipal) then
    // usuario autenticado
  else
    // token inválido o expirado
end;
```

### Header esperado

```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Equivalente C#

```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opt => {
        opt.TokenValidationParameters = new TokenValidationParameters {
            ValidateIssuer = true,
            ValidIssuer = "https://mi-api.com",
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes("mi-secreto-super-seguro-256bits"))
        };
    });
```

---

## API Key Authentication

```pascal
uses Quick.Core.Extensions.Authentication.ApiKey;

services.Extension<TAuthenticationServiceExtension>
  .AddAuthentication
  .AddApiKey(procedure(opt: TApiKeyOptions)
  begin
    opt.HeaderName := 'X-API-Key';
    opt.ApiKey     := 'my-secret-api-key';
  end);
```

La petición debe incluir:
```
X-API-Key: my-secret-api-key
```

---

## Cookie Authentication

```pascal
uses Quick.Core.Extensions.Authentication.Cookie;

services.Extension<TAuthenticationServiceExtension>
  .AddAuthentication
  .AddCookie(procedure(opt: TCookieAuthenticationOptions)
  begin
    opt.LoginPath      := '/account/login';
    opt.CookieName     := 'QuickCore.Auth';
    opt.ExpireMinutes  := 1440; // 24 horas
  end);
```

### Iniciar/cerrar sesión

```pascal
// Login — en el controller de login
procedure TAccountController.Login([FromBody] dto: TLoginDto);
var
  principal : TClaimsPrincipal;
  handler   : IAuthenticationSignInHandler;
begin
  // Verificar credenciales...
  principal := BuildPrincipal(dto.Username);
  handler   := HttpContext.GetSignInHandler('Cookies');
  handler.SignIn(principal, TAuthenticationProperties.Create);
  Result := Redirect('/dashboard');
end;

// Logout
procedure TAccountController.Logout;
var
  handler : IAuthenticationSignOutHandler;
begin
  handler := HttpContext.GetSignOutHandler('Cookies');
  handler.SignOut(nil);
  Result := Redirect('/');
end;
```

---

## OAuth2 / OpenID Connect

```pascal
uses Quick.Core.Extensions.Authentication.OAuth2;

services.Extension<TAuthenticationServiceExtension>
  .AddAuthentication
  .AddOAuth2(procedure(opt: TOAuth2Options)
  begin
    opt.Authority    := 'https://login.microsoftonline.com/tenant-id/v2.0';
    opt.ClientId     := 'my-client-id';
    opt.ClientSecret := 'my-client-secret';
  end);
```

---

## Policies y roles

```pascal
uses Quick.Core.Extensions.Authorization;

services.Extension<TAuthorizationServiceExtension>
  .AddAuthorization(procedure(opt: TAuthorizationOptions)
  begin
    // Política basada en rol
    opt.AddPolicy('AdminOnly',
      TAuthorizationPolicyBuilder.Create
        .RequireRole('admin')
        .Build);

    // Política basada en claim
    opt.AddPolicy('PremiumUser',
      TAuthorizationPolicyBuilder.Create
        .RequireClaim('subscription', 'premium')
        .Build);

    // Política compuesta
    opt.AddPolicy('SeniorEditor',
      TAuthorizationPolicyBuilder.Create
        .RequireRole('editor')
        .RequireClaim('seniority', 'senior')
        .RequireAuthenticatedUser
        .Build);
  end);
```

### Equivalente C#

```csharp
builder.Services.AddAuthorization(opt => {
    opt.AddPolicy("AdminOnly", p => p.RequireRole("admin"));
    opt.AddPolicy("PremiumUser", p => p.RequireClaim("subscription", "premium"));
});
```

---

## Claims y ClaimsPrincipal

```pascal
uses Quick.Core.Security.Claims;

// Leer claims del usuario actual (en un controller)
var
  userId    : string;
  userName  : string;
  isAdmin   : Boolean;
begin
  userId   := User.FindFirstValue('sub');
  userName := User.Identity.Name;
  isAdmin  := User.IsInRole('admin');

  // Iterar todos los claims
  for var claim in User.Identity.Claims do
    Logger.Info(claim.ClaimType + ' = ' + claim.Value);
end;
```

---

## Autorización en controllers

```pascal
// Controller completo requiere autenticación
[Authorize]
TProductsController = class(THttpController)

// Solo administradores
[Authorize('admin')]
TAdminController = class(THttpController)

// Por política
[AuthorizePolicy('PremiumUser')]
function GetPremiumContent: TActionResult;

// Permite acceso anónimo aunque el controller tenga [Authorize]
[AllowAnonymous]
function GetPublicContent: TActionResult;
```

---

## Resource-based Authorization

Para autorizar según el estado de un recurso específico:

```pascal
uses Quick.Core.Extensions.Authorization;

// Definir handler
type
  TDocumentEditRequirement = class(TAuthorizationHandler<TDocumentEditRequirement>,
                                    IAuthorizationRequirement)
  public
    function HandleRequirement(
      aContext : TAuthorizationHandlerContext;
      aReq     : TDocumentEditRequirement) : Boolean; override;
  end;

function TDocumentEditRequirement.HandleRequirement(
  aContext : TAuthorizationHandlerContext;
  aReq     : TDocumentEditRequirement) : Boolean;
var
  doc : TDocument;
begin
  doc := aContext.Resource as TDocument;
  if doc.OwnerId = aContext.User.FindFirstValue('sub') then
  begin
    aContext.Succeed(aReq);
    Result := True;
  end
  else
    Result := False;
end;

// Registrar
services.AddSingleton<IAuthorizationHandler, TDocumentEditRequirement>;

// Uso en controller
function TDocumentController.Edit(id: Integer): TActionResult;
var
  doc : TDocument;
begin
  doc := fRepo.GetById(id);
  if not AuthorizeResource(doc, 'EditDocument') then
    Result := Forbid
  else
    Result := View;
end;
```

---

## ASP.NET Identity (UserManager)

Sistema completo de gestión de usuarios con almacenamiento en Entity:

```pascal
uses
  Quick.Core.Extensions.Authentication,
  Quick.Core.Identity;

// Definir entidades de usuario y rol
type
  TAppUser = class(TIdentityUser);
  TAppRole = class(TIdentityRole);

// Registrar en ConfigureServices
services.Extension<TAuthenticationServiceExtension>
  .AddIdentity<TAppUser, TAppRole>(procedure(opt: TIdentityOptions)
  begin
    // Contraseña
    opt.Password.RequireDigit          := True;
    opt.Password.RequiredLength        := 8;
    opt.Password.RequireUppercase      := True;
    // Bloqueo
    opt.Lockout.MaxFailedAttempts      := 5;
    opt.Lockout.LockoutDurationMinutes := 30;
    // Usuario
    opt.User.RequireUniqueEmail        := True;
  end)
  .AddEntityStore<TShopContext>;

// Uso del UserManager
procedure TAccountController.Register([FromBody] dto: TRegisterDto);
var
  userMgr : TUserManager<TAppUser>;
  user    : TAppUser;
begin
  user          := TAppUser.Create;
  user.UserName := dto.Email;
  user.Email    := dto.Email;

  if userMgr.CreateUser(user, dto.Password) then
    Result := Ok('Usuario creado')
  else
    Result := BadRequest(userMgr.LastError);
end;

procedure TAccountController.Login([FromBody] dto: TLoginDto);
var
  userMgr : TUserManager<TAppUser>;
begin
  if userMgr.CheckPassword(dto.Email, dto.Password) then
  begin
    // generar JWT o cookie
    Result := Ok(jwtService.GenerateToken(BuildPrincipal(dto.Email)));
  end
  else
    Result := Unauthorized;
end;
```

### Equivalente C#

```csharp
builder.Services.AddIdentity<AppUser, AppRole>()
    .AddEntityFrameworkStores<ShopContext>();
```

---

## 2FA / TOTP

**Unidad:** `Quick.Core.Security.Totp` — Equivalente .NET: `Rfc6238AuthenticationService`

Servicio RFC 6238 compatible con Google Authenticator y cualquier app TOTP estándar.

| Método | Descripción |
|--------|-------------|
| `GenerateCode(base32Secret)` | Genera el código de 6 dígitos actual |
| `ValidateCode(base32Secret, code, [window=1])` | Valida código; `window` = pasos de ±30 s permitidos |
| `GetProvisioningUri(secret, account, issuer)` | URL `otpauth://` para generar QR |

```pascal
uses Quick.Core.Security.Totp;

// Registro DI (singleton recomendado):
services.AddSingleton<ITotpService, TTotpService>;

// En el servicio de identidad — registrar TOTP para un usuario:
var totpSvc : ITotpService;

// El secreto Base32 se genera fuera (o usa SecureRandomBytes + Base32Encode):
var secret := '...BASE32SECRET...';  // almacenar cifrado en BD
var qrUri  := totpSvc.GetProvisioningUri(secret, user.Email, 'MiApp');
// Mostrar qrUri como QR al usuario

// Al hacer login — verificar código introducido:
if totpSvc.ValidateCode(user.TotpSecret, dto.TotpCode) then
  // 2FA correcto
else
  Exit(Unauthorized('Código TOTP inválido'));
```

### Equivalente C#

```csharp
// ASP.NET Core Identity ya gestiona TOTP internamente vía
// IUserTwoFactorTokenProvider<T> ("Authenticator")
var key  = await userManager.GetAuthenticatorKeyAsync(user);
var uri  = _urlEncoder.Encode($"otpauth://totp/{appName}:{email}?secret={key}&issuer={appName}");
var ok   = await userManager.VerifyTwoFactorTokenAsync(user, "Authenticator", code);
```

---

## Security Stamp Validation

Invalida sesiones activas automáticamente cuando cambia la contraseña u otros datos sensibles:

```pascal
// Al cambiar contraseña
userMgr.UpdateSecurityStamp(user);
// → todas las sesiones anteriores del usuario quedan invalidadas
```

---

## Ver también

- [Dependency Injection](Dependency-Injection.md) — `AddAuthentication`, `AddAuthorization`
- [MVC](MVC.md) — `UseAuthentication`, `UseAuthorization`, `[Authorize]`
- [Entity / ORM](Entity-ORM.md) — `AddEntityStore`, `TIdentityUser`
