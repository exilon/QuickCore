unit Chain.NotEmpty;

{ ChainOfResponsibility Sample - S-24
  First link: ensures Name and Category are not blank. }

interface

uses
  Chain;

type
  TNotEmptyValidator = class(TAbstractValidator<TCreateProductCommand>)
  protected
    function DoValidate(aCmd : TCreateProductCommand) : TValidationResult; override;
  end;

implementation

uses
  System.SysUtils;

function TNotEmptyValidator.DoValidate(aCmd : TCreateProductCommand): TValidationResult;
begin
  if aCmd.Name.Trim.IsEmpty then
    Result := TValidationResult.Fail('Name is required')
  else if aCmd.Category.Trim.IsEmpty then
    Result := TValidationResult.Fail('Category is required')
  else
    Result := TValidationResult.Ok;
end;

end.
