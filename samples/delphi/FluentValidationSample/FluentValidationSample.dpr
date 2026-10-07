program FluentValidationSample;

(* FluentValidationSample
  Demonstrates the QuickCore fluent validation builder.

  .NET equivalent: FluentValidation
    public class UserValidator : AbstractValidator<User>
    {
        public UserValidator()
        {
            RuleFor(x => x.Name).NotEmpty().Length(2, 100);
            RuleFor(x => x.Email).NotEmpty().EmailAddress();
            RuleFor(x => x.Age).GreaterThanOrEqualTo(18);
        }
    }
    var result = new UserValidator().Validate(user);

  In Delphi, property names are passed as strings (no expression trees).
  RTTI resolves the values at runtime from published properties.
*)

{$APPTYPE CONSOLE}
// {$R *.res}  — .res not generated for dcc32 console builds; omit to avoid linker error

uses
  System.SysUtils,
  System.Rtti,
  Quick.Console,
  Quick.Core.Mvc.Validation.Builder;

// ── Domain models ─────────────────────────────────────────────────────────────

type
  {$M+}
  TUserRegistration = class
  private
    fName      : string;
    fEmail     : string;
    fAge       : Integer;
    fUsername  : string;
    fPassword  : string;
    fScore     : Double;
  published
    property Name      : string  read fName      write fName;
    property Email     : string  read fEmail     write fEmail;
    property Age       : Integer read fAge       write fAge;
    property Username  : string  read fUsername  write fUsername;
    property Password  : string  read fPassword  write fPassword;
    property Score     : Double  read fScore     write fScore;
  end;
  {$M-}

// ── Validators ────────────────────────────────────────────────────────────────

  TUserRegistrationValidator = class(TAbstractValidator<TUserRegistration>)
  public
    constructor Create; reintroduce;
  end;

  TAdminUserValidator = class(TAbstractValidator<TUserRegistration>)
  public
    constructor Create; reintroduce;
  end;

constructor TUserRegistrationValidator.Create;
begin
  inherited;
  RuleFor('Name')
    .NotEmpty.WithMessage('Full name is required')
    .Length(2, 100).WithMessage('Name must be between 2 and 100 characters');

  RuleFor('Email')
    .NotEmpty.WithMessage('Email is required')
    .EmailAddress.WithMessage('Please provide a valid email address');

  RuleFor('Age')
    .GreaterThanOrEqualTo(18).WithMessage('You must be at least 18 years old')
    .LessThanOrEqualTo(120).WithMessage('Age must be realistic');

  RuleFor('Username')
    .NotEmpty
    .MinLength(3).WithMessage('Username must be at least 3 characters')
    .MaxLength(30).WithMessage('Username must not exceed 30 characters')
    .Matches('^[a-zA-Z0-9_]+$').WithMessage('Username may only contain letters, digits and underscores');

  RuleFor('Password')
    .NotEmpty.WithMessage('Password is required')
    .MinLength(8).WithMessage('Password must be at least 8 characters')
    .Must(function(const v: TValue): Boolean
      begin
        Result := v.AsString.Contains('0') or v.AsString.Contains('1') or
                  v.AsString.Contains('2') or v.AsString.Contains('3') or
                  v.AsString.Contains('4') or v.AsString.Contains('5') or
                  v.AsString.Contains('6') or v.AsString.Contains('7') or
                  v.AsString.Contains('8') or v.AsString.Contains('9');
      end)
    .WithMessage('Password must contain at least one digit');

  RuleFor('Score')
    .InclusiveBetween(0, 100).WithMessage('Score must be between 0 and 100');
end;

constructor TAdminUserValidator.Create;
begin
  inherited;
  // Admin: same basic rules + stricter username
  RuleFor('Name').NotEmpty.Length(2, 100);
  RuleFor('Email').NotEmpty.EmailAddress;
  RuleFor('Username')
    .NotEmpty
    .MinLength(5).WithMessage('Admin username must be at least 5 characters')
    .MustBeString(function(const s: string): Boolean
      begin
        Result := s.StartsWith('adm_', True);
      end)
    .WithMessage('Admin username must start with "adm_"');
end;

// ── Helpers ───────────────────────────────────────────────────────────────────

procedure PrintResult(const aTitle: string; const aResult: TValidationResult);
var
  e: TValidationError;
begin
  WriteLn;
  WriteLn('  ' + aTitle);
  if aResult.IsValid then
    WriteLn('  ✅ Valid — no errors')
  else
  begin
    WriteLn(Format('  ❌ Invalid — %d error(s):', [aResult.Errors.Count]));
    for e in aResult.Errors do
      WriteLn(Format('     • [%s] %s', [e.PropertyName, e.ErrorMessage]));
  end;
end;

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────
var
  validator   : TUserRegistrationValidator;
  adminVal    : TAdminUserValidator;
  model       : TUserRegistration;
  result      : TValidationResult;
begin
  try
    WriteLn('QuickCore — Fluent Validation Builder sample (FluentValidation equivalent)');
    WriteLn('══════════════════════════════════════════════════════════════════════════');

    validator := TUserRegistrationValidator.Create;
    adminVal  := TAdminUserValidator.Create;
    model     := TUserRegistration.Create;
    try
      // ── Case 1: fully invalid ─────────────────────────────────────────────
      WriteLn;
      WriteLn('─── Case 1: All fields invalid ────────────────────────────────────');
      model.Name     := '';
      model.Email    := 'not-an-email';
      model.Age      := 15;
      model.Username := 'a b!';
      model.Password := 'short';
      model.Score    := 200;
      result := validator.Validate(model);
      PrintResult('User registration (all invalid):', result);
      result.Free;

      // ── Case 2: fully valid ───────────────────────────────────────────────
      WriteLn;
      WriteLn('─── Case 2: All fields valid ──────────────────────────────────────');
      model.Name     := 'Alice Smith';
      model.Email    := 'alice@example.com';
      model.Age      := 25;
      model.Username := 'alice_smith';
      model.Password := 'Secur3Pass';
      model.Score    := 92.5;
      result := validator.Validate(model);
      PrintResult('User registration (all valid):', result);
      result.Free;

      // ── Case 3: partially invalid ─────────────────────────────────────────
      WriteLn;
      WriteLn('─── Case 3: Some fields invalid ───────────────────────────────────');
      model.Name     := 'Bob';        // ok
      model.Email    := 'bob@';       // invalid
      model.Age      := 17;           // underage
      model.Username := 'bob123';     // ok
      model.Password := 'MyPass99';   // ok
      model.Score    := 75;           // ok
      result := validator.Validate(model);
      PrintResult('User registration (partial errors):', result);
      result.Free;

      // ── Case 4: Admin validator (custom Must predicate) ───────────────────
      WriteLn;
      WriteLn('─── Case 4: Admin validator (username must start with adm_) ───────');
      model.Name     := 'Charlie Admin';
      model.Email    := 'charlie@corp.com';
      model.Username := 'charlie';  // must start with adm_
      result := adminVal.Validate(model);
      PrintResult('Admin validator (charlie fails):', result);
      result.Free;

      model.Username := 'adm_charlie';
      result := adminVal.Validate(model);
      PrintResult('Admin validator (adm_charlie passes):', result);
      result.Free;

    finally
      validator.Free;
      adminVal.Free;
      model.Free;
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
