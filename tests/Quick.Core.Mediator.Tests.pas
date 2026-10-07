unit Quick.Core.Mediator.Tests;

{ Tests: T-MED-01..09
    T-MED-01  Send a query with a registered handler returns the correct response
    T-MED-02  Send a command (handler with side effect) executes correctly
    T-MED-03  Publish a notification calls all registered handlers
    T-MED-04  Pipeline behavior fires before and after the handler
    T-MED-05  Send with unregistered request type raises EMediatorError
    T-MED-06  Multiple notification handlers for same event are all called
    T-MED-07  SendRequest<T> generic helper returns typed result without cast
    T-MED-08  Pipeline behaviors apply in registration order
    T-MED-09  Publish with no handlers registered is a no-op (no exception)
}

interface

uses
  DUnitX.TestFramework,
  System.Rtti,
  System.SysUtils,
  Quick.Core.Mediator.Abstractions,
  Quick.Core.Mediator;

// ── Test domain model ────────────────────────────────────────────────────────

type
  // Queries / Commands

  TGetGreetingQuery = class
  private
    fName: string;
  public
    constructor Create(const aName: string);
    property Name: string read fName;
  end;

  TAddCommand = class
  private
    fA, fB: Integer;
  public
    constructor Create(aA, aB: Integer);
    property A: Integer read fA;
    property B: Integer read fB;
  end;

  TUnregisteredRequest = class
  end;

  // Notifications

  TOrderPlacedEvent = class
  private
    fOrderId: Integer;
  public
    constructor Create(aOrderId: Integer);
    property OrderId: Integer read fOrderId;
  end;

  TNoHandlerEvent = class
  end;

  // Handlers

  TGetGreetingHandler = class(TRequestHandler<TGetGreetingQuery, string>)
  public
    function Handle(const aRequest: TGetGreetingQuery): string; override;
  end;

  TAddCommandHandler = class(TRequestHandler<TAddCommand, Integer>)
  public
    function Handle(const aRequest: TAddCommand): Integer; override;
  end;

  TOrderEmailHandler = class(TNotificationHandler<TOrderPlacedEvent>)
  public
    class var CallCount: Integer;
    procedure Handle(const aNotification: TOrderPlacedEvent); override;
  end;

  TOrderAuditHandler = class(TNotificationHandler<TOrderPlacedEvent>)
  public
    class var CallCount: Integer;
    procedure Handle(const aNotification: TOrderPlacedEvent); override;
  end;

  // Pipeline behaviors

  TTestLogBehavior = class(TPipelineBehavior<TGetGreetingQuery, string>)
  public
    class var BeforeCalled: Boolean;
    class var AfterCalled: Boolean;
    class var Order: TArray<string>;
    function Handle(const aRequest: TGetGreetingQuery;
                    aNext: TRequestHandlerDelegate<string>): string; override;
  end;

  TTestSecondBehavior = class(TPipelineBehavior<TGetGreetingQuery, string>)
  public
    class var Called: Boolean;
    function Handle(const aRequest: TGetGreetingQuery;
                    aNext: TRequestHandlerDelegate<string>): string; override;
  end;

  // Test fixture

  [TestFixture]
  TMediatorTests = class
  private
    fRegistry: TMediatorRegistry;
    fMediator: TMediator;
    procedure SetupBasicRegistry;
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure T_MED_01_SendQuery_ReturnsCorrectResponse;
    [Test]
    procedure T_MED_02_SendCommand_ExecutesSideEffect;
    [Test]
    procedure T_MED_03_Publish_CallsSingleHandler;
    [Test]
    procedure T_MED_04_Pipeline_BehaviorFiresAroundHandler;
    [Test]
    procedure T_MED_05_Send_UnregisteredRequest_RaisesError;
    [Test]
    procedure T_MED_06_Publish_MultipleHandlers_AllCalled;
    [Test]
    procedure T_MED_07_SendRequest_Generic_ReturnsTypedResult;
    [Test]
    procedure T_MED_08_Pipeline_MultipleOrdered_CorrectOrder;
    [Test]
    procedure T_MED_09_Publish_NoHandlers_NoException;
  end;

implementation

// ── Domain model impl ────────────────────────────────────────────────────────

constructor TGetGreetingQuery.Create(const aName: string);
begin
  fName := aName;
end;

constructor TAddCommand.Create(aA, aB: Integer);
begin
  fA := aA;
  fB := aB;
end;

constructor TOrderPlacedEvent.Create(aOrderId: Integer);
begin
  fOrderId := aOrderId;
end;

// ── Handlers impl ────────────────────────────────────────────────────────────

function TGetGreetingHandler.Handle(const aRequest: TGetGreetingQuery): string;
begin
  Result := 'Hello, ' + aRequest.Name + '!';
end;

function TAddCommandHandler.Handle(const aRequest: TAddCommand): Integer;
begin
  Result := aRequest.A + aRequest.B;
end;

procedure TOrderEmailHandler.Handle(const aNotification: TOrderPlacedEvent);
begin
  Inc(CallCount);
end;

procedure TOrderAuditHandler.Handle(const aNotification: TOrderPlacedEvent);
begin
  Inc(CallCount);
end;

// ── Pipeline behavior impl ────────────────────────────────────────────────────

function TTestLogBehavior.Handle(const aRequest: TGetGreetingQuery;
  aNext: TRequestHandlerDelegate<string>): string;
begin
  BeforeCalled := True;
  SetLength(Order, Length(Order) + 1);
  Order[High(Order)] := 'LogBehavior.Before';

  Result := aNext();  // call next in chain

  AfterCalled := True;
  SetLength(Order, Length(Order) + 1);
  Order[High(Order)] := 'LogBehavior.After';
end;

function TTestSecondBehavior.Handle(const aRequest: TGetGreetingQuery;
  aNext: TRequestHandlerDelegate<string>): string;
begin
  Called := True;
  SetLength(TTestLogBehavior.Order, Length(TTestLogBehavior.Order) + 1);
  TTestLogBehavior.Order[High(TTestLogBehavior.Order)] := 'SecondBehavior';
  Result := aNext();
end;

// ── TMediatorTests ────────────────────────────────────────────────────────────

procedure TMediatorTests.SetUp;
begin
  fRegistry := TMediatorRegistry.Create;
  fMediator := TMediator.Create(fRegistry);
  // Reset class-level counters
  TOrderEmailHandler.CallCount  := 0;
  TOrderAuditHandler.CallCount  := 0;
  TTestLogBehavior.BeforeCalled := False;
  TTestLogBehavior.AfterCalled  := False;
  TTestLogBehavior.Order        := nil;
  TTestSecondBehavior.Called    := False;
end;

procedure TMediatorTests.TearDown;
begin
  fMediator.Free;
  fRegistry.Free;
end;

procedure TMediatorTests.SetupBasicRegistry;
begin
  fRegistry.AddRequestHandler(TGetGreetingQuery.ClassName,
    function: IRequestHandlerBase
    begin
      Result := TGetGreetingHandler.Create;
    end);

  fRegistry.AddRequestHandler(TAddCommand.ClassName,
    function: IRequestHandlerBase
    begin
      Result := TAddCommandHandler.Create;
    end);

  fRegistry.AddNotifHandler(TOrderPlacedEvent.ClassName,
    function: INotificationHandlerBase
    begin
      Result := TOrderEmailHandler.Create;
    end);
end;

procedure TMediatorTests.T_MED_01_SendQuery_ReturnsCorrectResponse;
var
  query  : TGetGreetingQuery;
  result : string;
begin
  SetupBasicRegistry;
  query := TGetGreetingQuery.Create('World');
  try
    result := fMediator.Send(query).AsType<string>;
    Assert.AreEqual('Hello, World!', result);
  finally
    query.Free;
  end;
end;

procedure TMediatorTests.T_MED_02_SendCommand_ExecutesSideEffect;
var
  cmd    : TAddCommand;
  result : Integer;
begin
  SetupBasicRegistry;
  cmd := TAddCommand.Create(3, 7);
  try
    result := fMediator.Send(cmd).AsType<Integer>;
    Assert.AreEqual(10, result);
  finally
    cmd.Free;
  end;
end;

procedure TMediatorTests.T_MED_03_Publish_CallsSingleHandler;
var
  event: TOrderPlacedEvent;
begin
  SetupBasicRegistry;
  event := TOrderPlacedEvent.Create(42);
  try
    fMediator.Publish(event);
    Assert.AreEqual(1, TOrderEmailHandler.CallCount);
  finally
    event.Free;
  end;
end;

procedure TMediatorTests.T_MED_04_Pipeline_BehaviorFiresAroundHandler;
var
  query  : TGetGreetingQuery;
  result : string;
begin
  fRegistry.AddRequestHandler(TGetGreetingQuery.ClassName,
    function: IRequestHandlerBase
    begin
      Result := TGetGreetingHandler.Create;
    end);

  fRegistry.AddPipelineBehavior(
    function: IPipelineBehaviorBase
    begin
      Result := TTestLogBehavior.Create;
    end);

  query := TGetGreetingQuery.Create('Pipeline');
  try
    result := fMediator.Send(query).AsType<string>;
    Assert.IsTrue(TTestLogBehavior.BeforeCalled,
      'Pipeline behavior should have fired before handler');
    Assert.IsTrue(TTestLogBehavior.AfterCalled,
      'Pipeline behavior should have fired after handler');
    Assert.AreEqual('Hello, Pipeline!', result);
  finally
    query.Free;
  end;
end;

procedure TMediatorTests.T_MED_05_Send_UnregisteredRequest_RaisesError;
var
  req: TUnregisteredRequest;
begin
  req := TUnregisteredRequest.Create;
  try
    Assert.WillRaise(
      procedure
      begin
        fMediator.Send(req);
      end,
      EMediatorError);
  finally
    req.Free;
  end;
end;

procedure TMediatorTests.T_MED_06_Publish_MultipleHandlers_AllCalled;
var
  event: TOrderPlacedEvent;
begin
  // Register both handlers for the same event
  fRegistry.AddNotifHandler(TOrderPlacedEvent.ClassName,
    function: INotificationHandlerBase
    begin
      Result := TOrderEmailHandler.Create;
    end);

  fRegistry.AddNotifHandler(TOrderPlacedEvent.ClassName,
    function: INotificationHandlerBase
    begin
      Result := TOrderAuditHandler.Create;
    end);

  event := TOrderPlacedEvent.Create(99);
  try
    fMediator.Publish(event);
    Assert.AreEqual(1, TOrderEmailHandler.CallCount,  'Email handler should be called once');
    Assert.AreEqual(1, TOrderAuditHandler.CallCount, 'Audit handler should be called once');
  finally
    event.Free;
  end;
end;

procedure TMediatorTests.T_MED_07_SendRequest_Generic_ReturnsTypedResult;
var
  query  : TGetGreetingQuery;
  result : string;
begin
  fRegistry.AddRequestHandler(TGetGreetingQuery.ClassName,
    function: IRequestHandlerBase
    begin
      Result := TGetGreetingHandler.Create;
    end);

  query := TGetGreetingQuery.Create('Generic');
  try
    result := fMediator.SendRequest<string>(query);
    Assert.AreEqual('Hello, Generic!', result);
  finally
    query.Free;
  end;
end;

procedure TMediatorTests.T_MED_08_Pipeline_MultipleOrdered_CorrectOrder;
var
  query  : TGetGreetingQuery;
begin
  fRegistry.AddRequestHandler(TGetGreetingQuery.ClassName,
    function: IRequestHandlerBase
    begin
      Result := TGetGreetingHandler.Create;
    end);

  // LogBehavior registered first → outermost (runs first before, last after)
  fRegistry.AddPipelineBehavior(
    function: IPipelineBehaviorBase
    begin
      Result := TTestLogBehavior.Create;
    end);

  fRegistry.AddPipelineBehavior(
    function: IPipelineBehaviorBase
    begin
      Result := TTestSecondBehavior.Create;
    end);

  query := TGetGreetingQuery.Create('Order');
  try
    fMediator.Send(query);
    // Expected call order: LogBehavior.Before → SecondBehavior → Handler → LogBehavior.After
    Assert.IsTrue(Length(TTestLogBehavior.Order) >= 3,
      'Should have at least 3 pipeline execution steps');
    Assert.AreEqual('LogBehavior.Before', TTestLogBehavior.Order[0],
      'LogBehavior should be outermost (first before)');
    Assert.AreEqual('SecondBehavior', TTestLogBehavior.Order[1],
      'SecondBehavior should fire second');
    Assert.AreEqual('LogBehavior.After', TTestLogBehavior.Order[High(TTestLogBehavior.Order)],
      'LogBehavior.After should be last (outermost returns last)');
  finally
    query.Free;
  end;
end;

procedure TMediatorTests.T_MED_09_Publish_NoHandlers_NoException;
var
  event: TNoHandlerEvent;
begin
  // No handlers registered for TNoHandlerEvent — Publish should be a silent no-op
  event := TNoHandlerEvent.Create;
  try
    Assert.WillNotRaise(
      procedure
      begin
        fMediator.Publish(event);
      end);
  finally
    event.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TMediatorTests);

end.
