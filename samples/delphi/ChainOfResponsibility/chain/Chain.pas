unit Chain;

{ ChainOfResponsibility Sample - S-24
  Core abstractions: command, result, and handler interface. }

interface

uses
  System.SysUtils;

type
  { Command: the data object that travels through the chain }
  TCreateProductCommand = class
  private
    FName     : string;
    FCategory : string;
    FPrice    : Double;
  public
    property Name     : string read FName     write FName;
    property Category : string read FCategory write FCategory;
    property Price    : Double read FPrice    write FPrice;
  end;

  { Result returned by every handler }
  TValidationResult = record
    IsValid      : Boolean;
    ErrorMessage : string;
    class function Ok : TValidationResult; static;
    class function Fail(const aMsg : string) : TValidationResult; static;
  end;

  { Handler interface — each concrete validator implements this }
  IValidator<T> = interface
  ['{F2C3D8A1-7B4E-4A2C-B97F-6E0D5F1C3A88}']
    function Validate(aCmd : T) : TValidationResult;
  end;

  { Base class for chained validators.
    Concrete validators override DoValidate; if valid they call PassToNext. }
  TAbstractValidator<T> = class(TInterfacedObject, IValidator<T>)
  private
    fNext : IValidator<T>;
  protected
    function DoValidate(aCmd : T) : TValidationResult; virtual; abstract;
    function PassToNext(aCmd : T) : TValidationResult;
  public
    constructor Create(aNext : IValidator<T>);
    function Validate(aCmd : T) : TValidationResult;
  end;

implementation

{ TValidationResult }

class function TValidationResult.Ok: TValidationResult;
begin
  Result.IsValid      := True;
  Result.ErrorMessage := '';
end;

class function TValidationResult.Fail(const aMsg : string): TValidationResult;
begin
  Result.IsValid      := False;
  Result.ErrorMessage := aMsg;
end;

{ TAbstractValidator<T> }

constructor TAbstractValidator<T>.Create(aNext : IValidator<T>);
begin
  inherited Create;
  fNext := aNext;
end;

function TAbstractValidator<T>.Validate(aCmd : T): TValidationResult;
begin
  Result := DoValidate(aCmd);
  if Result.IsValid then
    Result := PassToNext(aCmd);
end;

function TAbstractValidator<T>.PassToNext(aCmd : T): TValidationResult;
begin
  if fNext <> nil then
    Result := fNext.Validate(aCmd)
  else
    Result := TValidationResult.Ok;   // end of chain — success
end;

end.
