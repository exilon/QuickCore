program MediatorCQRS;

(* MediatorCQRS Sample — S-xx
  Demonstrates the MediatR-pattern mediator in QuickCore:
    - Queries     : request + response (TGetProductQuery → TProductDto)
    - Commands    : request with side effect (TCreateProductCommand → Integer)
    - Notifications: fan-out events (TProductCreatedEvent → email + audit handlers)
    - Pipeline    : cross-cutting concern (TLoggingBehavior wraps every request)

  .NET equivalent: Console app using MediatR 12.x
    services.AddMediatR(cfg => cfg.RegisterServicesFromAssembly(...));
*)

{$APPTYPE CONSOLE}
// {$R *.res}  — resource file not needed for console apps; omit to avoid build errors

uses
  System.SysUtils,
  System.Rtti,
  Quick.Console,
  Quick.Core.Mediator.Abstractions,
  Quick.Core.Mediator,
  Quick.Core.Extensions.Mediator,
  Quick.Core.DependencyInjection;

// ─────────────────────────────────────────────────────────────────────────────
// Domain model
// ─────────────────────────────────────────────────────────────────────────────

type
  // ── DTOs ──────────────────────────────────────────────────────────────────

  TProductDto = class
  public
    Id   : Integer;
    Name : string;
    Price: Double;
    constructor Create(aId: Integer; const aName: string; aPrice: Double);
  end;

  // ── Queries ───────────────────────────────────────────────────────────────

  TGetProductQuery = class
  public
    Id: Integer;
    constructor Create(aId: Integer);
  end;

  TGetAllProductsQuery = class
  end;

  // ── Commands ──────────────────────────────────────────────────────────────

  TCreateProductCommand = class
  public
    Name : string;
    Price: Double;
    constructor Create(const aName: string; aPrice: Double);
  end;

  // ── Notifications / Events ─────────────────────────────────────────────────

  TProductCreatedEvent = class
  public
    ProductId: Integer;
    Name     : string;
    constructor Create(aId: Integer; const aName: string);
  end;

  // ── In-memory "database" ───────────────────────────────────────────────────

  TProductStore = class
  public
    class var NextId  : Integer;
    class var Products: TArray<TProductDto>;
    class function Add(const aName: string; aPrice: Double): Integer;
    class function FindById(aId: Integer): TProductDto;
  end;

  // ── Query Handlers ─────────────────────────────────────────────────────────

  TGetProductHandler = class(TRequestHandler<TGetProductQuery, TProductDto>)
    function Handle(const aRequest: TGetProductQuery): TProductDto; override;
  end;

  // ── Command Handlers ───────────────────────────────────────────────────────

  TCreateProductHandler = class(TRequestHandler<TCreateProductCommand, Integer>)
  private
    fMediator: IMediator;
  public
    constructor Create(aMediator: IMediator);
    function Handle(const aRequest: TCreateProductCommand): Integer; override;
  end;

  // ── Notification Handlers ─────────────────────────────────────────────────

  TEmailNotificationHandler = class(TNotificationHandler<TProductCreatedEvent>)
    procedure Handle(const aNotification: TProductCreatedEvent); override;
  end;

  TAuditNotificationHandler = class(TNotificationHandler<TProductCreatedEvent>)
    procedure Handle(const aNotification: TProductCreatedEvent); override;
  end;

  // ── Pipeline Behavior ─────────────────────────────────────────────────────

  TLoggingBehavior<TResponse> = class(TPipelineBehavior<TCreateProductCommand, TResponse>)
    function Handle(const aRequest: TCreateProductCommand;
                    aNext: TRequestHandlerDelegate<TResponse>): TResponse; override;
  end;

// ─────────────────────────────────────────────────────────────────────────────
// Domain model implementations
// ─────────────────────────────────────────────────────────────────────────────

constructor TProductDto.Create(aId: Integer; const aName: string; aPrice: Double);
begin
  Id    := aId;
  Name  := aName;
  Price := aPrice;
end;

constructor TGetProductQuery.Create(aId: Integer);
begin
  Id := aId;
end;

constructor TCreateProductCommand.Create(const aName: string; aPrice: Double);
begin
  Name  := aName;
  Price := aPrice;
end;

constructor TProductCreatedEvent.Create(aId: Integer; const aName: string);
begin
  ProductId := aId;
  Name      := aName;
end;

class function TProductStore.Add(const aName: string; aPrice: Double): Integer;
var
  dto: TProductDto;
begin
  Inc(NextId);
  dto := TProductDto.Create(NextId, aName, aPrice);
  SetLength(Products, Length(Products) + 1);
  Products[High(Products)] := dto;
  Result := NextId;
end;

class function TProductStore.FindById(aId: Integer): TProductDto;
var
  p: TProductDto;
begin
  Result := nil;
  for p in Products do
    if p.Id = aId then Exit(p);
end;

// Handlers

function TGetProductHandler.Handle(const aRequest: TGetProductQuery): TProductDto;
begin
  Result := TProductStore.FindById(aRequest.Id);
  if Result = nil then
    raise Exception.CreateFmt('Product with Id=%d not found', [aRequest.Id]);
end;

constructor TCreateProductHandler.Create(aMediator: IMediator);
begin
  inherited Create;
  fMediator := aMediator;
end;

function TCreateProductHandler.Handle(const aRequest: TCreateProductCommand): Integer;
var
  newId : Integer;
  event : TProductCreatedEvent;
begin
  newId := TProductStore.Add(aRequest.Name, aRequest.Price);
  // After creating, publish a domain event
  event := TProductCreatedEvent.Create(newId, aRequest.Name);
  try
    fMediator.Publish(event);
  finally
    event.Free;
  end;
  Result := newId;
end;

procedure TEmailNotificationHandler.Handle(const aNotification: TProductCreatedEvent);
begin
  WriteLn(Format('  [EMAIL] Sending confirmation email for product #%d "%s"',
    [aNotification.ProductId, aNotification.Name]));
end;

procedure TAuditNotificationHandler.Handle(const aNotification: TProductCreatedEvent);
begin
  WriteLn(Format('  [AUDIT] Logged creation of product #%d at %s',
    [aNotification.ProductId, FormatDateTime('hh:nn:ss', Now)]));
end;

function TLoggingBehavior<TResponse>.Handle(const aRequest: TCreateProductCommand;
  aNext: TRequestHandlerDelegate<TResponse>): TResponse;
begin
  WriteLn(Format('  [PIPELINE] Before CreateProductCommand(Name="%s", Price=%.2f)',
    [aRequest.Name, aRequest.Price]));
  Result := aNext();
  WriteLn('  [PIPELINE] After CreateProductCommand — completed');
end;

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

var
  services  : TServiceCollection;
  mediator  : IMediator;
  // Queries
  queryById : TGetProductQuery;
  product   : TProductDto;
  // Commands
  createCmd : TCreateProductCommand;
  newId     : Integer;
  // Pipeline & notification mediator builder (local, freed after setup)
  builder   : TMediatorBuilder;

begin
  try
    WriteLn('QuickCore — Mediator / CQRS sample');
    WriteLn('═══════════════════════════════════════');
    WriteLn;

    // ── Wire up DI ──────────────────────────────────────────────────────────
    services := TServiceCollection.Create;
    try
      builder := services.Extension<TMediatorServiceExtension>.AddMediatR;
      try
        builder
          // Query handlers
          .AddRequestHandler<TGetProductQuery, TProductDto, TGetProductHandler>
          // Command handlers
          .AddRequestHandler<TCreateProductCommand, Integer, TCreateProductHandler>
          // Notification handlers (fan-out — multiple for same event)
          .AddNotificationHandler<TProductCreatedEvent, TEmailNotificationHandler>
          .AddNotificationHandler<TProductCreatedEvent, TAuditNotificationHandler>
          // Pipeline behavior (cross-cutting logging)
          .AddPipelineBehavior<TCreateProductCommand, Integer, TLoggingBehavior<Integer>>;
      finally
        builder.Free;
      end;
      services.Build;

      mediator := services.Resolve<IMediator>;

      // ── Commands ────────────────────────────────────────────────────────
      WriteLn('1. COMMAND — Creating products:');
      WriteLn('─────────────────────────────────');

      createCmd := TCreateProductCommand.Create('Laptop Pro 16"', 1499.99);
      try
        newId := mediator.Send(createCmd).AsType<Integer>;
        WriteLn(Format('   Created product with Id=%d', [newId]));
      finally
        createCmd.Free;
      end;

      WriteLn;
      createCmd := TCreateProductCommand.Create('Wireless Mouse', 49.95);
      try
        newId := mediator.Send(createCmd).AsType<Integer>;
        WriteLn(Format('   Created product with Id=%d', [newId]));
      finally
        createCmd.Free;
      end;

      // ── Queries ─────────────────────────────────────────────────────────
      WriteLn;
      WriteLn('2. QUERY — Fetching product by Id:');
      WriteLn('────────────────────────────────────');

      queryById := TGetProductQuery.Create(1);
      try
        product := mediator.Send(queryById).AsType<TProductDto>;
        if Assigned(product) then
          WriteLn(Format('   Found: [%d] %s — $%.2f', [product.Id, product.Name, product.Price]))
        else
          WriteLn('   Product not found');
      finally
        queryById.Free;
      end;

      // ── Unregistered request (error handling demo) ───────────────────────
      WriteLn;
      WriteLn('3. ERROR HANDLING — Unregistered request:');
      WriteLn('──────────────────────────────────────────');
      var unknown := TGetAllProductsQuery.Create;
      try
        try
          mediator.Send(unknown);
        except
          on E: EMediatorError do
            WriteLn('   Caught expected EMediatorError: ' + E.Message.Substring(0, 80) + '...');
        end;
      finally
        unknown.Free;
      end;

    finally
      services.Free;
    end;

    WriteLn;
    WriteLn('Sample completed successfully.');

  except
    on E: Exception do
    begin
      WriteLn('FATAL: ' + E.Message);
      ExitCode := 1;
    end;
  end;

  {$IFDEF DEBUG}
  WriteLn;
  Write('Press Enter to exit...');
  ReadLn;
  {$ENDIF}
end.
