{ **************************** }
{      Quick.Core Library      }
{      Unit of Work Pattern    }
{ **************************** }
{ Author: QuickCore Team       }
{ **************************** }
unit Quick.Core.Entity.UnitOfWork;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Core.Entity;

type
  IUnitOfWork = interface
  ['{D7F2A3B1-9C4E-4F2D-8B6A-1E5C7D0F3A8B}']
    procedure BeginTransaction;
    procedure Commit;
    procedure Rollback;
    { Execute aProc inside a transaction. Returns True on success (commits),
      False if an exception occurs (rolls back and swallows the exception). }
    function Execute(aProc : TProc) : Boolean;
  end;

  TUnitOfWork = class(TInterfacedObject, IUnitOfWork)
  private
    fContext : IDBContext;
  public
    constructor Create(aContext : IDBContext);
    procedure BeginTransaction;
    procedure Commit;
    procedure Rollback;
    function Execute(aProc : TProc) : Boolean;
  end;

implementation

{ TUnitOfWork }

constructor TUnitOfWork.Create(aContext : IDBContext);
begin
  fContext := aContext;
end;

procedure TUnitOfWork.BeginTransaction;
begin
  fContext.BeginTransaction;
end;

procedure TUnitOfWork.Commit;
begin
  fContext.CommitTransaction;
end;

procedure TUnitOfWork.Rollback;
begin
  fContext.RollbackTransaction;
end;

function TUnitOfWork.Execute(aProc : TProc) : Boolean;
begin
  Result := False;
  fContext.BeginTransaction;
  try
    aProc();
    fContext.CommitTransaction;
    Result := True;
  except
    fContext.RollbackTransaction;
  end;
end;

end.
