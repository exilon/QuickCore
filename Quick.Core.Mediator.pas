{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Mediator
  Description : TMediator — request/notification dispatcher with pipeline support
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

unit Quick.Core.Mediator;

{$i QuickCore.inc}

interface

uses
  System.Classes,
  System.Rtti,
  System.SysUtils,
  System.Generics.Collections,
  Quick.Core.Mediator.Abstractions;

type
  // ── Factory delegates ───────────────────────────────────────────────────────

  /// <summary>Factory that produces a request handler on demand.</summary>
  THandlerFactory     = reference to function: IRequestHandlerBase;

  /// <summary>Factory that produces a notification handler on demand.</summary>
  TNotifHandlerFactory = reference to function: INotificationHandlerBase;

  /// <summary>Factory that produces a pipeline behavior on demand.</summary>
  TPipelineFactory    = reference to function: IPipelineBehaviorBase;

  // ── Registry ────────────────────────────────────────────────────────────────

  /// <summary>
  /// Central registry that maps request/notification class names to their
  /// handler factories. Populated at startup via TMediatorBuilder and shared
  /// with TMediator as a singleton.
  /// </summary>
  TMediatorRegistry = class
  private
    fRequestHandlers   : TDictionary<string, THandlerFactory>;
    fNotifHandlers     : TObjectDictionary<string, TList<TNotifHandlerFactory>>;
    fPipelineBehaviors : TList<TPipelineFactory>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddRequestHandler(const aRequestClassName: string; aFactory: THandlerFactory);
    procedure AddNotifHandler(const aNotifClassName: string; aFactory: TNotifHandlerFactory);
    procedure AddPipelineBehavior(aFactory: TPipelineFactory);

    function HasRequestHandler(const aRequestClassName: string): Boolean;
    function GetRequestHandler(const aRequestClassName: string): THandlerFactory;
    function GetNotifHandlers(const aNotifClassName: string): TArray<TNotifHandlerFactory>;
    function GetPipelineBehaviors: TArray<TPipelineFactory>;
  end;

  // ── Mediator ─────────────────────────────────────────────────────────────────

  /// <summary>
  /// Dispatches requests to their registered handler and publishes notifications
  /// to all registered handlers. Pipeline behaviors wrap the handler chain.
  ///
  /// Register via Quick.Core.Extensions.Mediator:
  ///   services.Extension&lt;TMediatorServiceExtension&gt;
  ///     .AddMediatR
  ///     .AddRequestHandler&lt;TMyQuery, TMyResponse, TMyQueryHandler&gt;
  ///     .AddNotificationHandler&lt;TMyEvent, TMyEventHandler&gt;;
  ///
  /// Then inject:
  ///   constructor TMyController.Create(aMediator: IMediator);
  ///   result := aMediator.Send(TMyQuery.Create(id)).AsType&lt;TMyResponse&gt;;
  ///
  /// Or for type-safe dispatch, inject TMediator directly:
  ///   result := aMediator.SendRequest&lt;TMyResponse&gt;(TMyQuery.Create(id));
  /// </summary>
  TMediator = class(TInterfacedObject, IMediator)
  private
    fRegistry: TMediatorRegistry;
    function BuildChain(aHandler: IRequestHandlerBase;
                        const aBehaviors: TArray<TPipelineFactory>): TPipelineDelegate;
  public
    constructor Create(aRegistry: TMediatorRegistry);

    // ── IMediator ──────────────────────────────────────────────────────────
    /// <summary>Send a request to its single registered handler.
    /// The pipeline behaviors (if any) are applied in registration order.
    /// Raises EMediatorError if no handler is registered for the request type.</summary>
    function Send(const aRequest: TObject): TValue;

    /// <summary>Publish a notification to all registered handlers.
    /// Handlers are called in registration order. Errors in one handler
    /// do NOT prevent subsequent handlers from running.</summary>
    procedure Publish(const aNotification: TObject);

    // ── Generic convenience (type-safe) ────────────────────────────────────
    /// <summary>Type-safe Send. Returns TResponse directly without TValue unwrapping.
    /// Requires injecting TMediator (not IMediator) — use when you control the
    /// injection point and prefer compile-time type safety.</summary>
    function SendRequest<TResponse>(const aRequest: TObject): TResponse;
  end;

// ── Internal pipeline chain builder (module-scope, not in interface) ────────

function BuildChainLink(aBehavior: IPipelineBehaviorBase;
                        aNext: TPipelineDelegate): TPipelineDelegate;

implementation

// ── TMediatorRegistry ────────────────────────────────────────────────────────

constructor TMediatorRegistry.Create;
begin
  inherited Create;
  fRequestHandlers   := TDictionary<string, THandlerFactory>.Create;
  fNotifHandlers     := TObjectDictionary<string, TList<TNotifHandlerFactory>>.Create([doOwnsValues]);
  fPipelineBehaviors := TList<TPipelineFactory>.Create;
end;

destructor TMediatorRegistry.Destroy;
begin
  fRequestHandlers.Free;
  fNotifHandlers.Free;
  fPipelineBehaviors.Free;
  inherited;
end;

procedure TMediatorRegistry.AddRequestHandler(const aRequestClassName: string;
  aFactory: THandlerFactory);
begin
  fRequestHandlers.AddOrSetValue(aRequestClassName, aFactory);
end;

procedure TMediatorRegistry.AddNotifHandler(const aNotifClassName: string;
  aFactory: TNotifHandlerFactory);
var
  list: TList<TNotifHandlerFactory>;
begin
  if not fNotifHandlers.TryGetValue(aNotifClassName, list) then
  begin
    list := TList<TNotifHandlerFactory>.Create;
    fNotifHandlers.Add(aNotifClassName, list);
  end;
  list.Add(aFactory);
end;

procedure TMediatorRegistry.AddPipelineBehavior(aFactory: TPipelineFactory);
begin
  fPipelineBehaviors.Add(aFactory);
end;

function TMediatorRegistry.HasRequestHandler(const aRequestClassName: string): Boolean;
begin
  Result := fRequestHandlers.ContainsKey(aRequestClassName);
end;

function TMediatorRegistry.GetRequestHandler(const aRequestClassName: string): THandlerFactory;
begin
  if not fRequestHandlers.TryGetValue(aRequestClassName, Result) then
    raise EMediatorError.CreateFmt(
      'Mediator: no handler registered for request type "%s". ' +
      'Did you call AddRequestHandler<%s,...>() in AddMediatR?',
      [aRequestClassName, aRequestClassName]);
end;

function TMediatorRegistry.GetNotifHandlers(
  const aNotifClassName: string): TArray<TNotifHandlerFactory>;
var
  list: TList<TNotifHandlerFactory>;
begin
  if fNotifHandlers.TryGetValue(aNotifClassName, list) then
    Result := list.ToArray
  else
    SetLength(Result, 0);
end;

function TMediatorRegistry.GetPipelineBehaviors: TArray<TPipelineFactory>;
begin
  Result := fPipelineBehaviors.ToArray;
end;

// ── Pipeline chain builder ────────────────────────────────────────────────────

function BuildChainLink(aBehavior: IPipelineBehaviorBase;
                        aNext: TPipelineDelegate): TPipelineDelegate;
begin
  // Each captured aBehavior + aNext pair is independent — no loop-variable aliasing.
  Result := function(const req: TObject): TValue
            begin
              Result := aBehavior.HandleObj(req, aNext);
            end;
end;

// ── TMediator ─────────────────────────────────────────────────────────────────

constructor TMediator.Create(aRegistry: TMediatorRegistry);
begin
  inherited Create;
  fRegistry := aRegistry;
end;

function TMediator.BuildChain(aHandler: IRequestHandlerBase;
  const aBehaviors: TArray<TPipelineFactory>): TPipelineDelegate;
var
  i         : Integer;
  innerChain: TPipelineDelegate;
begin
  // Innermost link: the actual handler
  innerChain := function(const req: TObject): TValue
                begin
                  Result := aHandler.HandleObj(req);
                end;

  // Wrap behaviors from innermost to outermost (reverse order ensures
  // first-registered behavior is the outermost / first to execute)
  for i := High(aBehaviors) downto 0 do
    innerChain := BuildChainLink(aBehaviors[i](), innerChain);

  Result := innerChain;
end;

function TMediator.Send(const aRequest: TObject): TValue;
var
  handlerFactory : THandlerFactory;
  handler        : IRequestHandlerBase;
  behaviors      : TArray<TPipelineFactory>;
  chain          : TPipelineDelegate;
begin
  if aRequest = nil then
    raise EMediatorError.Create('Mediator.Send: request cannot be nil');

  handlerFactory := fRegistry.GetRequestHandler(aRequest.ClassName);
  handler        := handlerFactory();
  behaviors      := fRegistry.GetPipelineBehaviors;
  chain          := BuildChain(handler, behaviors);
  Result         := chain(aRequest);
end;

procedure TMediator.Publish(const aNotification: TObject);
var
  factories : TArray<TNotifHandlerFactory>;
  factory   : TNotifHandlerFactory;
  handler   : INotificationHandlerBase;
  errors    : TStringList;
begin
  if aNotification = nil then
    raise EMediatorError.Create('Mediator.Publish: notification cannot be nil');

  factories := fRegistry.GetNotifHandlers(aNotification.ClassName);
  if Length(factories) = 0 then Exit; // no handlers registered is valid (no-op)

  errors := TStringList.Create;
  try
    for factory in factories do
    begin
      try
        handler := factory();
        handler.HandleObj(aNotification);
      except
        on E: Exception do
          errors.Add(Format('[%s] %s', [aNotification.ClassName, E.Message]));
      end;
    end;

    // Surface any errors after all handlers have run
    if errors.Count > 0 then
      raise EMediatorError.CreateFmt(
        'Mediator.Publish: %d handler(s) failed for "%s":%s%s',
        [errors.Count, aNotification.ClassName, sLineBreak, errors.Text.TrimRight]);
  finally
    errors.Free;
  end;
end;

function TMediator.SendRequest<TResponse>(const aRequest: TObject): TResponse;
var
  v: TValue;
begin
  v := Send(aRequest);
  if v.IsEmpty then
    Result := Default(TResponse)
  else
    Result := v.AsType<TResponse>;
end;

end.
