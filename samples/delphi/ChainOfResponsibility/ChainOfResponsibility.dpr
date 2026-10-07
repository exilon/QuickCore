program ChainOfResponsibility;

(* ChainOfResponsibility Sample - S-24
  Demonstrates the Chain-of-Responsibility pattern for building a validation
  pipeline. Each handler in the chain either:
    (a) processes the request and passes it on to the next handler, or
    (b) short-circuits the chain and returns a failure result.

  Pipeline for a "Create Product" command:
    TNotEmptyValidator  ->  TLengthValidator  ->  TPriceValidator
                                                      |
                                                  (end of chain)

  .NET equivalent: MediatR pipeline behaviours / ASP.NET Core middleware.

  Run the executable; no server is started.
*)

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Chain in 'chain\Chain.pas',
  Chain.NotEmpty in 'chain\Chain.NotEmpty.pas',
  Chain.Length in 'chain\Chain.Length.pas',
  Chain.Price in 'chain\Chain.Price.pas';

procedure RunTest(const aName, aCategory : string; const aPrice : Double);
var
  cmd      : TCreateProductCommand;
  handler  : IValidator<TCreateProductCommand>;
  result   : TValidationResult;
begin
  cmd           := TCreateProductCommand.Create;
  cmd.Name      := aName;
  cmd.Category  := aCategory;
  cmd.Price     := aPrice;
  try
    // Build the chain: NotEmpty -> Length -> Price
    handler := TNotEmptyValidator.Create(
                 TLengthValidator.Create(
                   TPriceValidator.Create(nil)));
    result := handler.Validate(cmd);
    if result.IsValid then
      cout(Format('  PASS  Name="%s" Category="%s" Price=%.2f', [aName, aCategory, aPrice]), ccGreen)
    else
      cout(Format('  FAIL  Name="%s" Category="%s" Price=%.2f => %s', [aName, aCategory, aPrice, result.ErrorMessage]), ccRed);
  finally
    cmd.Free;
  end;
end;

begin
  cout('--- Chain of Responsibility: Product Validation Pipeline ---', ccCyan);
  Writeln;
  RunTest('Laptop',   'Electronics', 999.00);  // PASS
  RunTest('',         'Electronics', 100.00);  // FAIL: name empty
  RunTest('AB',       'Electronics', 100.00);  // FAIL: name too short (< 3)
  RunTest('Laptop',   '',            100.00);  // FAIL: category empty
  RunTest('Laptop',   'Electronics',   0.00);  // FAIL: price <= 0
  RunTest('Laptop',   'Electronics', -5.00);   // FAIL: price negative
  RunTest('Keyboard', 'Electronics',  49.99);  // PASS
  Writeln;
  cout('Done. Press [Enter] to exit.', ccYellow);
  ConsoleWaitForEnterKey;
end.
