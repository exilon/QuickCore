unit Chain.Price;

{ ChainOfResponsibility Sample - S-24
  Third (last) link: enforces price business rules. }

interface

uses
  Chain;

type
  TPriceValidator = class(TAbstractValidator<TCreateProductCommand>)
  protected
    function DoValidate(aCmd : TCreateProductCommand) : TValidationResult; override;
  end;

implementation

uses
  System.SysUtils;

const
  MIN_PRICE = 0.01;
  MAX_PRICE = 1000000.0;

function TPriceValidator.DoValidate(aCmd : TCreateProductCommand): TValidationResult;
begin
  if aCmd.Price < MIN_PRICE then
    Result := TValidationResult.Fail(
      Format('Price must be greater than %.2f', [MIN_PRICE]))
  else if aCmd.Price > MAX_PRICE then
    Result := TValidationResult.Fail(
      Format('Price must not exceed %.2f', [MAX_PRICE]))
  else
    Result := TValidationResult.Ok;
end;

end.
