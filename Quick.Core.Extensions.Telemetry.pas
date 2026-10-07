{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Extensions.Telemetry
  Description : DI extension — AddTelemetry / AddTracerProvider
  Author      : Kike Perez
  Version     : 1.0
  Created     : 30/04/2026
  Modified    : 08/05/2026

  This file is part of QuickCore: https://github.com/exilon/QuickCore

  Equivalent .NET: TracerProviderBuilder extension methods
    services.AddOpenTelemetry().WithTracing(builder => ...)

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

unit Quick.Core.Extensions.Telemetry;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Core.DependencyInjection,
  Quick.Core.Telemetry.Abstractions,
  Quick.Core.Telemetry;

type

  // ─── Builder ─────────────────────────────────────────────────────────────────

  /// <summary>
  /// Fluent builder for configuring the tracer provider.
  ///
  /// .NET equivalent: TracerProviderBuilder
  ///
  /// Usage:
  ///   services.AddTelemetry('MyService')
  ///     .AddExporter(TJaegerExporter.Create(jaegerOpts))
  ///     .AddExporter(TInMemorySpanExporter.Create);
  /// </summary>
  TTracerProviderBuilder = class
  private
    fProvider    : TTracerProvider;
    fCollection  : TServiceCollection;
    fSetGlobal   : Boolean;
  public
    constructor Create(const aServiceName : string; aCollection : TServiceCollection);
    destructor Destroy; override;

    /// <summary>Add a span exporter. Can be called multiple times.</summary>
    function AddExporter(const aExporter : ISpanExporter) : TTracerProviderBuilder;
    /// <summary>Also set this provider as the global TTracerProvider.Global instance.</summary>
    function SetAsGlobal : TTracerProviderBuilder;
    /// <summary>Finalize — register ITracerProvider in the DI container and return the collection.</summary>
    function Build : TServiceCollection;
  end;

  // ─── Extension ───────────────────────────────────────────────────────────────

  /// <summary>
  /// DI extension: services.AddTelemetry('service-name')
  ///
  /// Example:
  ///   services
  ///     .AddTelemetry('my-service')
  ///       .AddExporter(TJaegerExporter.Create(jaegerOpts))
  ///       .SetAsGlobal
  ///       .Build;
  ///
  /// Then inject ITracerProvider or ITracer as needed.
  /// </summary>
  TTelemetryServiceExtension = class(TServiceCollectionExtension)
  public
    /// <summary>
    /// Start building a TracerProvider for the given service name.
    /// Returns a fluent builder; call .Build to finalize DI registration.
    /// </summary>
    function AddTelemetry(const aServiceName : string) : TTracerProviderBuilder;

    /// <summary>
    /// Register the given exporter as ISpanExporter singleton.
    /// Useful when you create the provider manually and just need the exporter in DI.
    /// </summary>
    function AddSpanExporter(const aExporter : ISpanExporter) : TTelemetryServiceExtension;
  end;

implementation

// ─── TTracerProviderBuilder ──────────────────────────────────────────────────

constructor TTracerProviderBuilder.Create(const aServiceName : string;
  aCollection : TServiceCollection);
begin
  inherited Create;
  fProvider   := TTracerProvider.Create(aServiceName);
  fCollection := aCollection;
  fSetGlobal  := False;
end;

destructor TTracerProviderBuilder.Destroy;
begin
  // fProvider ownership is transferred to DI on Build; do NOT free here
  inherited;
end;

function TTracerProviderBuilder.AddExporter(const aExporter : ISpanExporter) : TTracerProviderBuilder;
begin
  fProvider.AddExporter(aExporter);
  Result := Self;
end;

function TTracerProviderBuilder.SetAsGlobal : TTracerProviderBuilder;
begin
  fSetGlobal := True;
  Result     := Self;
end;

function TTracerProviderBuilder.Build : TServiceCollection;
var
  provider : ITracerProvider;
begin
  provider := fProvider;  // keep alive via interface
  if fSetGlobal then
    TTracerProvider.SetGlobal(provider);
  fCollection.AddSingleton<ITracerProvider>(provider);
  // Also register ITracer so simple consumers can inject it directly
  fCollection.AddSingleton<ITracer>(provider.GetTracer('default'));
  Result := fCollection;
end;

// ─── TTelemetryServiceExtension ──────────────────────────────────────────────

function TTelemetryServiceExtension.AddTelemetry(const aServiceName : string) : TTracerProviderBuilder;
begin
  Result := TTracerProviderBuilder.Create(aServiceName, ServiceCollection);
end;

function TTelemetryServiceExtension.AddSpanExporter(const aExporter : ISpanExporter) : TTelemetryServiceExtension;
begin
  ServiceCollection.AddSingleton<ISpanExporter>(aExporter);
  Result := Self;
end;

end.
