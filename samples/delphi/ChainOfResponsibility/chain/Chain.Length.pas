unit Chain.Length;

{ ChainOfResponsibility Sample - S-24
  Second link: enforces minimum length rules. }

interface

uses
  Chain;

type
  TLengthValidator = class(TAbstractValidator<TCreateProductCommand>)
  protected
    function DoValidate(aCmd : TCreateProductCommand) : TValidationResult; override;
  end;

implementation

uses
  System.SysUtils;

const
  MIN_NAME_LEN     = 3;
  MAX_NAME_LEN     = 100;
  MIN_CATEGORY_LEN = 2;

function TLengthValidator.DoValidate(aCmd : TCreateProductCommand): TValidationResult;
begin
  if aCmd.Name.Trim.Length < MIN_NAME_LEN then
    Result := TValidationResult.Fail(
      Format('Name must be at least %d characters', [MIN_NAME_LEN]))
  else if aCmd.Name.Trim.Length > MAX_NAME_LEN then
    Result := TValidationResult.Fail(
      Format('Name must be at most %d characters', [MAX_NAME_LEN]))
  else if aCmd.Category.Trim.Length < MIN_CATEGORY_LEN then
    Result := TValidationResult.Fail(
      Format('Category must be at least %d characters', [MIN_CATEGORY_LEN]))
  else
    Result := TValidationResult.Ok;
end;

end.
