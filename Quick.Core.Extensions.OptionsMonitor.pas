{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Extensions.OptionsMonitor
  Description : DI extensions — AddOptionsMonitor / AddOptionsSnapshot
  Author      : Kike Perez
  Version     : 1.0
  Created     : 30/04/2026
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

unit Quick.Core.Extensions.OptionsMonitor;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Options,
  Quick.Core.DependencyInjection,
  Quick.Core.Options.Monitor;

type

  /// <summary>
  /// DI extensions for reactive options monitoring.
  ///
  /// PREREQUISITE: Call services.Configure&lt;T&gt; before calling these methods
  /// so that the options section is already registered in the container.
  ///
  /// ─── AddOptionsMonitor&lt;T&gt; ────────────────────────────────────────────
  /// Registers IOptionsMonitor&lt;T&gt; as a singleton. The monitor hooks into the
  /// options container's OnConfigReloaded event (fired by the file watcher when
  /// appsettings.json changes) and fans out to all registered callbacks.
  ///
  ///   services.Configure&lt;TDatabaseOptions&gt;('Database');
  ///   services.Extension&lt;TOptionsMonitorServiceExtension&gt;
  ///     .AddOptionsMonitor&lt;TDatabaseOptions&gt;;
  ///
  ///   // Later, in a service constructor:
  ///   constructor TMyService.Create(aMonitor: IOptionsMonitor&lt;TDatabaseOptions&gt;);
  ///   begin
  ///     fToken := aMonitor.OnChange(procedure(o: TDatabaseOptions)
  ///       begin
  ///         ReconnectWithNewSettings(o.ConnectionString);
  ///       end);
  ///   end;
  ///
  /// ─── AddOptionsSnapshot&lt;T&gt; ──────────────────────────────────────────────
  /// Registers IOptionsSnapshot&lt;T&gt; as a singleton whose Value property always
  /// returns the current options value. Suitable for per-request consumers
  /// (e.g. MVC controllers) that need a fresh read without subscribing to
  /// change events.
  ///
  ///   services.Extension&lt;TOptionsMonitorServiceExtension&gt;
  ///     .AddOptionsSnapshot&lt;TFeatureOptions&gt;;
  ///
  /// .NET equivalent:
  ///   services.AddOptions&lt;T&gt;()
  ///           .BindConfiguration("Section")
  ///           .AddOptionsMonitor / AddOptionsSnapshot
  /// </summary>
  TOptionsMonitorServiceExtension = class(TServiceCollectionExtension)
  public
    /// <summary>
    /// Registers IOptionsMonitor&lt;T&gt; as a singleton. Requires T to be already
    /// configured via services.Configure&lt;T&gt;.
    /// </summary>
    class function AddOptionsMonitor<T: TOptions>: TServiceCollection;

    /// <summary>
    /// Registers IOptionsSnapshot&lt;T&gt; as a singleton. Value always reflects the
    /// latest loaded configuration. Requires T to be already configured.
    /// </summary>
    class function AddOptionsSnapshot<T: TOptions>: TServiceCollection;
  end;

implementation

{ TOptionsMonitorServiceExtension }

class function TOptionsMonitorServiceExtension.AddOptionsMonitor<T>: TServiceCollection;
var
  container : TOptionsContainer;
  monitor   : IOptionsMonitor<T>;
begin
  container := ServiceCollection.AppServices.Options;
  monitor   := TOptionsMonitor<T>.Create(container);
  ServiceCollection.AddSingleton<IOptionsMonitor<T>>(monitor);
  Result := ServiceCollection;
end;

class function TOptionsMonitorServiceExtension.AddOptionsSnapshot<T>: TServiceCollection;
var
  container : TOptionsContainer;
begin
  container := ServiceCollection.AppServices.Options;
  ServiceCollection.AddSingleton<IOptionsSnapshot<T>>(
    TOptionsSnapshot<T>.Create(container) as IOptionsSnapshot<T>
  );
  Result := ServiceCollection;
end;

end.
