{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Extensions.DataProtection
  Description : DI extensions for Data Protection
  Author      : Kike Perez
  Version     : 1.0
  Created     : 29/04/2026
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

unit Quick.Core.Extensions.DataProtection;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Core.DependencyInjection,
  Quick.Core.DataProtection;

type
  /// <summary>
  /// DI extension methods for Data Protection.
  ///
  /// Usage — in-memory ephemeral keys (default, keys lost on restart):
  ///   services.AddDataProtection('MyApp');
  ///
  /// Usage — file-persisted keys (survives restarts):
  ///   services.Extension<TDataProtectionServiceExtension>
  ///     .AddDataProtectionWithFileStore('/var/keys/master.key', 'MyApp');
  ///
  /// Then inject anywhere:
  ///   constructor Create(aProvider: IDataProtectionProvider);
  ///   var protector := aProvider.CreateProtector('Auth.Cookie');
  ///   encrypted := protector.Protect('user-id:42');
  /// </summary>
  TDataProtectionServiceExtension = class(TServiceCollectionExtension)
  public
    /// <summary>Register IDataProtectionProvider with ephemeral (in-memory) key.
    /// Key is regenerated on every application restart.</summary>
    class function AddDataProtection(const aApplicationName: string = 'QuickCore';
      aKeyLifetimeDays: Integer = 90): TServiceCollection;

    /// <summary>Register IDataProtectionProvider backed by a file key store.
    /// The master key is persisted at aKeyFilePath and reloaded on startup.</summary>
    class function AddDataProtectionWithFileStore(
      const aKeyFilePath: string;
      const aApplicationName: string = 'QuickCore';
      aKeyLifetimeDays: Integer = 90): TServiceCollection;
  end;

implementation

uses
  Quick.Core.DataProtection.KeyStore.File;

{ TDataProtectionServiceExtension }

class function TDataProtectionServiceExtension.AddDataProtection(
  const aApplicationName: string; aKeyLifetimeDays: Integer): TServiceCollection;
var
  opts : TDataProtectionOptions;
begin
  opts := TDataProtectionOptions.Create;
  opts.ApplicationName := aApplicationName;
  opts.KeyLifetimeDays := aKeyLifetimeDays;
  ServiceCollection.AddSingleton<IDataProtectionProvider>(
    TDataProtectionProvider.Create(opts) as IDataProtectionProvider);
  opts.Free;
  Result := ServiceCollection;
end;

class function TDataProtectionServiceExtension.AddDataProtectionWithFileStore(
  const aKeyFilePath: string; const aApplicationName: string;
  aKeyLifetimeDays: Integer): TServiceCollection;
begin
  ServiceCollection.AddSingleton<IDataProtectionProvider>(
    TFileKeyStoreDataProtectionProvider.Create(
      aKeyFilePath, aApplicationName, aKeyLifetimeDays) as IDataProtectionProvider);
  Result := ServiceCollection;
end;

end.
