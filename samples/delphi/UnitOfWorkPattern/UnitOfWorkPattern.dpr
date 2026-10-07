program UnitOfWorkPattern;

(* UnitOfWorkPattern Sample - S-22
  Shows how to use TDBContext.Database.BeginTransaction / CommitTransaction /
  RollbackTransaction to save multiple entities atomically.

  Scenario: placing an order saves one TOrder row and one-or-many TOrderItem rows
  inside a single database transaction. If any step fails, the whole operation is
  rolled back and a 500 response is returned.

  .NET equivalent: DbContext.Database.BeginTransaction() + SaveChanges + Commit/Rollback.

  Endpoints:
    GET  http://localhost:8080/api/orders           -> list all orders
    POST http://localhost:8080/api/orders           -> place a new order (atomic)
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  FireDAC.Phys.SQLite,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Startup in 'Startup.pas',
  Models in 'Models.pas',
  Service.Order in 'services\Service.Order.pas',
  Controller.Orders in 'controllers\Controller.Orders.pas';

var
  ApiServer : TMvcServer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    if not AppService.IsRunningAsService then
    begin
      cout('Starting UnitOfWorkPattern on http://localhost:8080 ...', etInfo);
      ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
      try
        ApiServer.UseStartup<TStartup>;
        cout('POST {"customerId":1,"items":[{"productId":1,"qty":2}]} to /api/orders', ccWhite);
        ApiServer.Start;
      finally
        ApiServer.Free;
      end;
    end
    else
    begin
      AppService.DisplayName := 'Unit of Work Pattern Demo';
      AppService.ServiceName := 'UnitOfWorkPatternSvc';
      AppService.CanInstallWithOtherName := True;
      AppService.OnStart := procedure
        begin
          ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
          ApiServer.UseStartup<TStartup>;
        end;
      AppService.OnExecute := ApiServer.Start;
      AppService.CheckParams;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
