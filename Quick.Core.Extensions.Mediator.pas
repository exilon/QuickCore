{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Extensions.Mediator
  Description : DI extension — AddMediatR fluent builder
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

unit Quick.Core.Extensions.Mediator;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Rtti,
  Quick.Core.DependencyInjection,
  Quick.Core.Mediator,
  Quick.Core.Mediator.Abstractions;

type
  /// <summary>
  /// Fluent builder returned by AddMediatR. Chain .AddRequestHandler,
  /// .AddNotificationHandler and .AddPipelineBehavior calls to register handlers.
  ///
  /// Usage (in ConfigureServices):
  ///   services.Extension&lt;TMediatorServiceExtension&gt;
  ///     .AddMediatR
  ///     .AddRequestHandler&lt;TGetProductQuery, TProductDto, TGetProductHandler&gt;
  ///     .AddNotificationHandler&lt;TProductCreatedEvent, TEmailHandler&gt;
  ///     .AddPipelineBehavior&lt;TGetProductQuery, TProductDto, TLoggingBehavior&gt;;
  ///
  /// Equivalent to .NET:
  ///   services.AddMediatR(cfg => cfg.RegisterServicesFromAssembly(Assembly.GetExecutingAssembly()));
  /// </summary>
  TMediatorBuilder = class
  private
    fServices : TServiceCollection;
    fRegistry : TMediatorRegistry;
  public
    constructor Create(aServices: TServiceCollection; aRegistry: TMediatorRegistry);

    /// <summary>Register a request handler for TRequest that returns TResponse.
    /// THandler must extend TRequestHandler&lt;TRequest, TResponse&gt;.</summary>
    function AddRequestHandler<TRequest: class; TResponse;
      THandler: class, constructor>: TMediatorBuilder;

    /// <summary>Register a notification handler for TNotification.
    /// Multiple handlers can be registered for the same notification type.
    /// THandler must extend TNotificationHandler&lt;TNotification&gt;.</summary>
    function AddNotificationHandler<TNotification: class;
      THandler: class, constructor>: TMediatorBuilder;

    /// <summary>Register a pipeline behavior (cross-cutting concern).
    /// Behaviors are applied in registration order (first registered = outermost).
    /// TBehavior must extend TPipelineBehavior&lt;TRequest, TResponse&gt;.</summary>
    function AddPipelineBehavior<TRequest: class; TResponse;
      TBehavior: class, constructor>: TMediatorBuilder;

    /// <summary>Returns the parent TServiceCollection for further chaining.</summary>
    function Build: TServiceCollection;
  end;

  /// <summary>
  /// Service collection extension that adds the IMediator/TMediator to DI.
  ///
  /// Usage:
  ///   services.Extension&lt;TMediatorServiceExtension&gt;.AddMediatR
  ///     .AddRequestHandler&lt;...&gt;
  ///     ...;
  /// </summary>
  TMediatorServiceExtension = class(TServiceCollectionExtension)
  public
    /// <summary>Registers IMediator (and TMediator as a singleton) in the DI container
    /// and returns a TMediatorBuilder for registering handlers.
    ///
    /// Call this ONCE in ConfigureServices. Returns TMediatorBuilder for chaining.
    /// The caller owns the TMediatorBuilder — it is freed automatically after the
    /// fluent chain ends when the caller goes out of scope, OR call .Build to
    /// get back TServiceCollection.</summary>
    class function AddMediatR: TMediatorBuilder;
  end;

implementation

{ TMediatorBuilder }

constructor TMediatorBuilder.Create(aServices: TServiceCollection;
  aRegistry: TMediatorRegistry);
begin
  inherited Create;
  fServices := aServices;
  fRegistry := aRegistry;
end;

function TMediatorBuilder.AddRequestHandler<TRequest, TResponse, THandler>: TMediatorBuilder;
var
  requestClassName: string;
  services: TServiceCollection;
begin
  requestClassName := TRequest.ClassName;
  services := fServices;

  // Register handler in DI as transient (for direct injection if needed)
  fServices.AddTransient<THandler>;

  // Add factory to mediator registry
  fRegistry.AddRequestHandler(requestClassName,
    function: IRequestHandlerBase
    var
      h: TObject;
      v: TValue;
    begin
      v := services.Resolve(TypeInfo(THandler));
      if v.IsEmpty then
        raise EMediatorError.CreateFmt('Mediator: handler class "%s" could not be resolved from DI.', [THandler.ClassName]);
      h := v.AsObject;
      if not Supports(h, IRequestHandlerBase, Result) then
      begin
        h.Free;
        raise EMediatorError.CreateFmt(
          'Mediator: handler class "%s" does not implement IRequestHandlerBase. ' +
          'Did you extend TRequestHandler<TRequest, TResponse>?',
          [THandler.ClassName]);
      end;
    end);

  Result := Self;
end;

function TMediatorBuilder.AddNotificationHandler<TNotification, THandler>: TMediatorBuilder;
var
  notifClassName: string;
  services: TServiceCollection;
begin
  notifClassName := TNotification.ClassName;
  services := fServices;

  // Register in DI for direct injection
  fServices.AddTransient<THandler>;

  // Add factory to mediator registry
  fRegistry.AddNotifHandler(notifClassName,
    function: INotificationHandlerBase
    var
      h: TObject;
      v: TValue;
    begin
      v := services.Resolve(TypeInfo(THandler));
      if v.IsEmpty then
        raise EMediatorError.CreateFmt('Mediator: handler class "%s" could not be resolved from DI.', [THandler.ClassName]);
      h := v.AsObject;
      if not Supports(h, INotificationHandlerBase, Result) then
      begin
        h.Free;
        raise EMediatorError.CreateFmt(
          'Mediator: handler class "%s" does not implement INotificationHandlerBase. ' +
          'Did you extend TNotificationHandler<TNotification>?',
          [THandler.ClassName]);
      end;
    end);

  Result := Self;
end;

function TMediatorBuilder.AddPipelineBehavior<TRequest, TResponse, TBehavior>: TMediatorBuilder;
var
  services: TServiceCollection;
begin
  services := fServices;
  fServices.AddTransient<TBehavior>;

  fRegistry.AddPipelineBehavior(
    function: IPipelineBehaviorBase
    var
      b: TObject;
      v: TValue;
    begin
      v := services.Resolve(TypeInfo(TBehavior));
      if v.IsEmpty then
        raise EMediatorError.CreateFmt('Mediator: behavior class "%s" could not be resolved from DI.', [TBehavior.ClassName]);
      b := v.AsObject;
      if not Supports(b, IPipelineBehaviorBase, Result) then
      begin
        b.Free;
        raise EMediatorError.CreateFmt(
          'Mediator: behavior class "%s" does not implement IPipelineBehaviorBase. ' +
          'Did you extend TPipelineBehavior<TRequest, TResponse>?',
          [TBehavior.ClassName]);
      end;
    end);

  Result := Self;
end;

function TMediatorBuilder.Build: TServiceCollection;
begin
  Result := fServices;
end;

{ TMediatorServiceExtension }

class function TMediatorServiceExtension.AddMediatR: TMediatorBuilder;
var
  registry : TMediatorRegistry;
  mediator : TMediator;
begin
  registry := TMediatorRegistry.Create;
  mediator := TMediator.Create(registry);

  // Register the SAME mediator instance under both IMediator (interface injection)
  // and as a named concrete class entry (for generic SendRequest<T> usage).
  ServiceCollection.AddSingleton<IMediator>(mediator as IMediator);
  // TMediator is also accessible via Resolve<IMediator> + 'as TMediator' cast.

  Result := TMediatorBuilder.Create(ServiceCollection, registry);
end;

end.
