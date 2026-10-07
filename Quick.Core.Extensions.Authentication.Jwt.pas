{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Extensions.Authentication.Jwt
  Description : Core Extensions Authentication JWT Bearer
  Author      : Kike Perez
  Version     : 1.0
  Created     : 13/04/2026
  Modified    : 08/05/2026

  This file is part of QuickCore: https://github.com/exilon/QuickCore

 ***************************************************************************

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

 *************************************************************************** }

unit Quick.Core.Extensions.Authentication.Jwt;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Options,
  Quick.Core.Logging.Abstractions,
  Quick.Core.DependencyInjection,
  Quick.Core.Security.Authentication,
  Quick.Core.Security.Claims,
  Quick.Core.Security.Jwt;

const
  JwtBearerDefaults_AuthenticationScheme = 'Bearer';

type
  /// <summary>Authentication handler that validates Bearer JWT tokens from
  ///  the Authorization header: "Authorization: Bearer <token>"</summary>
  {$M+}
  TJwtBearerHandler = class(TAuthenticationHandler<TJwtOptions>, IAuthenticationHandler)
  private
    fJwtService : IJwtTokenService;
  protected
    procedure DoInitialize; override;
  public
    constructor Create(aOptions : IOptions<TJwtOptions>; aLogger : ILogger);
    function Authenticate : TAuthenticateResult; override;
  end;
  {$M-}

  TJwtBearerServiceExtension = class(TServiceCollectionExtension)
  public
    class function AddJwtBearer(aConfigureOptions : TConfigureOptionsProc<TJwtOptions>) : TServiceCollection;
  end;

implementation

{ TJwtBearerHandler }

constructor TJwtBearerHandler.Create(aOptions : IOptions<TJwtOptions>; aLogger : ILogger);
begin
  inherited Create(aOptions, aLogger);
  fJwtService := TJwtTokenService.Create(aOptions);
end;

procedure TJwtBearerHandler.DoInitialize;
begin
  // Nothing extra needed – fRequest/fContext are set by the base Initialize()
end;

function TJwtBearerHandler.Authenticate : TAuthenticateResult;
var
  authHeader, token : string;
  principal : TClaimsPrincipal;
  ticket : IAuthenticationTicket;
begin
  // Read the Authorization header
  authHeader := fRequest.Headers.GetValue('Authorization');
  if authHeader.IsEmpty then
  begin
    Result.NoResult;
    Exit;
  end;

  // Expect "Bearer <token>"
  if not authHeader.StartsWith('Bearer ', True) then
  begin
    Result.NoResult;
    Exit;
  end;

  token := authHeader.Substring(7).Trim;

  if token.IsEmpty then
  begin
    Result.Fail(EJwtException.Create('Empty Bearer token'));
    Exit;
  end;

  if fJwtService.ValidateToken(token, principal) then
  begin
    ticket := TAuthenticationTicket.Create(principal, JwtBearerDefaults_AuthenticationScheme);
    Result.Success(ticket);
  end
  else
  begin
    Result.Fail(EJwtException.Create('Invalid or expired JWT token'));
  end;
end;

{ TJwtBearerServiceExtension }

class function TJwtBearerServiceExtension.AddJwtBearer(aConfigureOptions : TConfigureOptionsProc<TJwtOptions>) : TServiceCollection;
var
  jwtOptions : TJwtOptions;
begin
  Result := ServiceCollection;
  jwtOptions := TJwtOptions.Create;
  aConfigureOptions(jwtOptions);
  jwtOptions.HideOptions := True;
  Result.Configure<TJwtOptions>(jwtOptions);
  Result.AddSingleton<IJwtTokenService, TJwtTokenService>();
  // Register the JWT handler in IOC so authentication can resolve it
  Result.AddTransient<TJwtBearerHandler>();
  // Register the JWT handler scheme with AuthenticationOptions
  Result.Configure<TAuthenticationOptions>(
    procedure(aOptions : TAuthenticationOptions)
    begin
      aOptions.AddScheme(JwtBearerDefaults_AuthenticationScheme,
        TypeInfo(TJwtBearerHandler));
      if aOptions.DefaultAuthenticateScheme = '' then
        aOptions.DefaultAuthenticateScheme := JwtBearerDefaults_AuthenticationScheme;
    end);
end;

end.
