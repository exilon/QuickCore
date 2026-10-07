{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Extensions.Cors
  Description : Core Extensions CORS
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

unit Quick.Core.Extensions.Cors;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Options,
  Quick.Core.DependencyInjection,
  Quick.Core.Mvc.Middleware.Cors;

type
  TCorsServiceExtension = class(TServiceCollectionExtension)
  public
    /// <summary>Register CORS with a configure callback.
    /// Usage: services.Extension<TCorsServiceExtension>.AddCors(
    ///   procedure(p: TCorsPolicyOptions) begin p.AllowAnyOrigin.AllowAnyMethod.AllowAnyHeader end)</summary>
    class function AddCors(aConfigureOptions : TConfigureOptionsProc<TCorsPolicyOptions>) : TServiceCollection; overload;
    /// <summary>Register CORS with default permissive policy (allow-any).</summary>
    class function AddCors : TServiceCollection; overload;
  end;

implementation

{ TCorsServiceExtension }

class function TCorsServiceExtension.AddCors(aConfigureOptions : TConfigureOptionsProc<TCorsPolicyOptions>) : TServiceCollection;
var
  opts : TCorsPolicyOptions;
begin
  Result := ServiceCollection;
  opts := TCorsPolicyOptions.Create;
  aConfigureOptions(opts);
  opts.HideOptions := True;
  Result.Configure<TCorsPolicyOptions>(opts);
end;

class function TCorsServiceExtension.AddCors : TServiceCollection;
begin
  Result := AddCors(
    procedure(aOpts : TCorsPolicyOptions)
    begin
      aOpts.AllowAnyOrigin.AllowAnyMethod.AllowAnyHeader;
    end);
end;

end.
