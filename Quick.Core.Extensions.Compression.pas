{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Extensions.Compression
  Description : Core Extensions Response Compression
  Author      : Kike Perez
  Version     : 1.0
  Created     : 14/04/2026
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

unit Quick.Core.Extensions.Compression;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Options,
  Quick.Core.DependencyInjection,
  Quick.Core.Mvc.Middleware.Compression;

type
  TCompressionServiceExtension = class(TServiceCollectionExtension)
  public
    /// <summary>Register Response Compression with a configure callback.
    /// Usage: services.Extension<TCompressionServiceExtension>.AddResponseCompression(
    ///   procedure(p: TCompressionOptions) begin p.MinimumBytes := 512 end)</summary>
    class function AddResponseCompression(aConfigureOptions : TConfigureOptionsProc<TCompressionOptions>) : TServiceCollection; overload;
    /// <summary>Register Response Compression with default options.</summary>
    class function AddResponseCompression : TServiceCollection; overload;
  end;

implementation

{ TCompressionServiceExtension }

class function TCompressionServiceExtension.AddResponseCompression(aConfigureOptions : TConfigureOptionsProc<TCompressionOptions>) : TServiceCollection;
var
  opts : TCompressionOptions;
begin
  Result := ServiceCollection;
  opts := TCompressionOptions.Create;
  aConfigureOptions(opts);
  opts.HideOptions := True;
  Result.Configure<TCompressionOptions>(opts);
end;

class function TCompressionServiceExtension.AddResponseCompression : TServiceCollection;
begin
  Result := AddResponseCompression(
    procedure(aOpts : TCompressionOptions)
    begin
      // use defaults
    end);
end;

end.
