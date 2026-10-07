{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Mediator.Abstractions
  Description : Mediator pattern abstractions — interfaces and base classes
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

unit Quick.Core.Mediator.Abstractions;

{$i QuickCore.inc}

interface

uses
  System.Rtti,
  System.SysUtils,
  System.TypInfo;

type
  EMediatorError = class(Exception);

  // ── Non-generic dispatch interfaces (used internally by TMediator) ─────────

  /// <summary>Non-generic base for all request handlers. TMediator calls HandleObj
  /// at dispatch time — implement via TRequestHandler&lt;TReq,TResp&gt; instead.</summary>
  IRequestHandlerBase = interface
  ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function HandleObj(const aRequest: TObject): TValue;
  end;

  /// <summary>Non-generic base for all notification handlers.</summary>
  INotificationHandlerBase = interface
  ['{B2C3D4E5-F6A7-8901-BCDE-F01234567890}']
    procedure HandleObj(const aNotification: TObject);
  end;

  /// <summary>Delegate type for the next step in a pipeline chain.</summary>
  TPipelineDelegate = reference to function(const aRequest: TObject): TValue;

  /// <summary>Non-generic base for pipeline behaviors (middleware).
  /// Implement via TPipelineBehavior&lt;TReq,TResp&gt; instead.</summary>
  IPipelineBehaviorBase = interface
  ['{C3D4E5F6-A7B8-9012-CDEF-012345678901}']
    function HandleObj(const aRequest: TObject; aNext: TPipelineDelegate): TValue;
  end;

  // ── Optional marker interfaces ──────────────────────────────────────────────

  /// <summary>Optional marker for request objects that return TResponse.
  /// Implement to get compile-time documentation of the response type.</summary>
  IRequest<TResponse> = interface
  ['{D4E5F6A7-B8C9-0123-DEFA-123456789012}']
  end;

  /// <summary>Optional marker for command requests (no response value).</summary>
  IRequest = interface
  ['{E5A6B7C8-D9E0-1234-5678-90ABCDEF1234}']
  end;

  /// <summary>Marker interface for notification objects published to multiple handlers.</summary>
  INotification = interface
  ['{E5F6A7B8-C9D0-1234-EFAB-234567890123}']
  end;

  // ── Typed generic handler interfaces ───────────────────────────────────────

  /// <summary>Handles a request of TRequest type, returning TResponse.
  /// Equivalent to IRequestHandler&lt;TRequest, TResponse&gt; in MediatR.
  ///
  /// Usage: implement via TRequestHandler&lt;TRequest, TResponse&gt; base class.</summary>
  IRequestHandler<TRequest: class; TResponse> = interface(IRequestHandlerBase)
  ['{F6A7B8C9-D0E1-2345-FABC-345678901234}']
    function Handle(const aRequest: TRequest): TResponse;
  end;

  /// <summary>Handles a notification of TNotification type (fan-out: many handlers per notification).
  /// Equivalent to INotificationHandler&lt;TNotification&gt; in MediatR.
  ///
  /// Usage: implement via TNotificationHandler&lt;TNotification&gt; base class.</summary>
  INotificationHandler<TNotification: class> = interface(INotificationHandlerBase)
  ['{A7B8C9D0-E1F2-3456-ABCD-456789012345}']
    procedure Handle(const aNotification: TNotification);
  end;

  /// <summary>Delegate type for pipeline behaviors (typed version).</summary>
  TRequestHandlerDelegate<TResponse> = reference to function: TResponse;

  /// <summary>Pipeline behavior (middleware) that wraps request handling.
  /// Equivalent to IPipelineBehavior&lt;TRequest, TResponse&gt; in MediatR.
  ///
  /// Usage: implement via TPipelineBehavior&lt;TRequest, TResponse&gt; base class.
  ///
  /// Example:
  ///   TLoggingBehavior = class(TPipelineBehavior&lt;TMyRequest, TMyResponse&gt;)
  ///     function Handle(const req: TMyRequest;
  ///                     aNext: TRequestHandlerDelegate&lt;TMyResponse&gt;): TMyResponse; override;
  ///   end;</summary>
  IPipelineBehavior<TRequest: class; TResponse> = interface(IPipelineBehaviorBase)
  ['{B8C9D0E1-F2A3-4567-BCDE-567890123456}']
    function Handle(const aRequest: TRequest;
                    aNext: TRequestHandlerDelegate<TResponse>): TResponse;
  end;

  // ── Core mediator interface ─────────────────────────────────────────────────

  /// <summary>
  /// Central mediator — dispatches requests to handlers and publishes notifications.
  /// Equivalent to IMediator in MediatR.
  ///
  /// Inject IMediator or resolve TMediator for the generic Send&lt;TResponse&gt; helper.
  ///
  /// Usage:
  ///   // Send a query (with response)
  ///   result := mediator.Send(TGetProductQuery.Create(id)).AsType&lt;TProductDto&gt;;
  ///
  ///   // Or with typed helper (requires TMediator, not IMediator):
  ///   result := (mediator as TMediator).SendRequest&lt;TProductDto&gt;(TGetProductQuery.Create(id));
  ///
  ///   // Publish a notification (fan-out)
  ///   mediator.Publish(TProductCreatedEvent.Create(id, name));
  /// </summary>
  IMediator = interface
  ['{C9D0E1F2-A3B4-5678-CDEF-678901234567}']
    /// <summary>Send a request to its single handler. Returns TValue wrapping the response.
    /// Raises EMediatorError if no handler is registered for the request type.</summary>
    function Send(const aRequest: TObject): TValue;
    /// <summary>Publish a notification to all registered handlers (zero or more).</summary>
    procedure Publish(const aNotification: TObject);
  end;

  // ── Abstract base classes (users extend these) ─────────────────────────────

  /// <summary>
  /// Abstract base class for request handlers.
  /// Extend this and override Handle to implement your handler.
  ///
  /// Usage:
  ///   TGetProductHandler = class(TRequestHandler&lt;TGetProductQuery, TProductDto&gt;)
  ///     function Handle(const req: TGetProductQuery): TProductDto; override;
  ///   end;
  ///
  ///   // Register:
  ///   mediatorBuilder.AddRequestHandler&lt;TGetProductQuery, TProductDto, TGetProductHandler&gt;
  /// </summary>
  TRequestHandler<TRequest: class; TResponse> = class abstract(TInterfacedObject,
    IRequestHandlerBase, IRequestHandler<TRequest, TResponse>)
  public
    function Handle(const aRequest: TRequest): TResponse; virtual; abstract;
    /// <summary>Called by TMediator at dispatch time. Do not override.</summary>
    function HandleObj(const aRequest: TObject): TValue;
  end;

  /// <summary>
  /// Abstract base class for notification handlers.
  ///
  /// Usage:
  ///   TEmailOnProductCreated = class(TNotificationHandler&lt;TProductCreatedEvent&gt;)
  ///     procedure Handle(const notif: TProductCreatedEvent); override;
  ///   end;
  /// </summary>
  TNotificationHandler<TNotification: class> = class abstract(TInterfacedObject,
    INotificationHandlerBase, INotificationHandler<TNotification>)
  public
    procedure Handle(const aNotification: TNotification); virtual; abstract;
    /// <summary>Called by TMediator at dispatch time. Do not override.</summary>
    procedure HandleObj(const aNotification: TObject);
  end;

  /// <summary>
  /// Abstract base class for pipeline behaviors.
  ///
  /// Usage:
  ///   TLoggingBehavior = class(TPipelineBehavior&lt;TMyReq, TMyResp&gt;)
  ///     function Handle(const req: TMyReq;
  ///                     aNext: TRequestHandlerDelegate&lt;TMyResp&gt;): TMyResp; override;
  ///   end;
  ///
  ///   // Register:
  ///   mediatorBuilder.AddPipelineBehavior&lt;TMyReq, TMyResp, TLoggingBehavior&gt;
  /// </summary>
  TPipelineBehavior<TRequest: class; TResponse> = class abstract(TInterfacedObject,
    IPipelineBehaviorBase, IPipelineBehavior<TRequest, TResponse>)
  public
    function Handle(const aRequest: TRequest;
                    aNext: TRequestHandlerDelegate<TResponse>): TResponse; virtual; abstract;
    /// <summary>Called by TMediator at dispatch time. Do not override.</summary>
    function HandleObj(const aRequest: TObject; aNext: TPipelineDelegate): TValue;
  end;

implementation

{ TRequestHandler<TRequest, TResponse> }

function TRequestHandler<TRequest, TResponse>.HandleObj(const aRequest: TObject): TValue;
begin
  Result := TValue.From<TResponse>(Handle(TRequest(aRequest)));
end;

{ TNotificationHandler<TNotification> }

procedure TNotificationHandler<TNotification>.HandleObj(const aNotification: TObject);
begin
  Handle(TNotification(aNotification));
end;

{ TPipelineBehavior<TRequest, TResponse> }

function TPipelineBehavior<TRequest, TResponse>.HandleObj(
  const aRequest: TObject; aNext: TPipelineDelegate): TValue;
var
  typedNext: TRequestHandlerDelegate<TResponse>;
  requestClass: TClass;
begin
  requestClass := nil;
  if (TypeInfo(TRequest) <> nil) and (GetTypeData(TypeInfo(TRequest)) <> nil) then
    requestClass := GetTypeData(TypeInfo(TRequest))^.ClassType;

  // Apply this behavior only to matching request types.
  // Without this guard, globally-registered behaviors may cast unrelated
  // requests and cause access violations.
  if (aRequest = nil) or (requestClass = nil) or not aRequest.InheritsFrom(requestClass) then
    Exit(aNext(aRequest));

  // Wrap the non-generic aNext delegate into the typed delegate
  typedNext := function: TResponse
               begin
                 Result := aNext(aRequest).AsType<TResponse>;
               end;
  Result := TValue.From<TResponse>(Handle(TRequest(aRequest), typedNext));
end;

end.
