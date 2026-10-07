{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Mvc.Validation.Builder
  Description : Fluent validation builder (FluentValidation pattern)
  Author      : Kike Perez
  Version     : 1.0
  Created     : 30/04/2026
  Modified    : 08/05/2026

  This file is part of QuickCore: https://github.com/exilon/QuickCore

  Equivalent .NET: FluentValidation — AbstractValidator<T>, IRuleBuilder<T,P>

 ***************************************************************************

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

 *************************************************************************** }

unit Quick.Core.Mvc.Validation.Builder;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.StrUtils,
  System.RegularExpressions,
  System.Math,
  RTTI,
  System.TypInfo,
  System.Generics.Collections;

type

  // ─── Validation result ────────────────────────────────────────────────────

  TValidationError = record
    PropertyName : string;
    ErrorMessage : string;
  end;

  /// <summary>
  /// Result of a fluent validation run.
  ///
  /// .NET equivalent: ValidationResult (FluentValidation)
  ///
  /// Usage:
  ///   result := validator.Validate(model);
  ///   if not result.IsValid then
  ///     for err in result.Errors do
  ///       WriteLn(err.PropertyName + ': ' + err.ErrorMessage);
  ///   result.Free;
  /// </summary>
  TValidationResult = class
  private
    fErrors : TList<TValidationError>;
    function GetIsValid : Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    property IsValid : Boolean read GetIsValid;
    property Errors  : TList<TValidationError> read fErrors;
    procedure AddError(const aPropertyName, aErrorMessage : string);
  end;

  // ─── Internal rule builder (forward) ─────────────────────────────────────

  TPropertyRuleBuilder = class;

  // ─── Predicate types ──────────────────────────────────────────────────────

  TValuePredicate = reference to function(const aValue : TValue) : Boolean;
  TValuePredicate<T> = reference to function(const aValue : T) : Boolean;

  // ─── Property rule builder (chainable) ───────────────────────────────────

  /// <summary>
  /// Fluent chainable rule builder for a single property.
  /// Returned by TAbstractValidator.RuleFor — chain rule methods then move on.
  ///
  /// All rule methods return Self so calls can be chained:
  ///   RuleFor('Email').NotEmpty.EmailAddress.WithMessage('Email is required');
  ///
  /// .NET equivalent: IRuleBuilderInitial&lt;T,TProperty&gt; / IRuleBuilderOptions&lt;T,TProperty&gt;
  /// </summary>
  TPropertyRuleBuilder = class
  public type
    TRuleFunc = reference to function(const aValue : TValue) : string; // '' = pass
  private
    fPropertyName   : string;
    fRules          : TList<TRuleFunc>;
    fPendingMessage : string;  // set by WithMessage before the next rule is added
    procedure AddRule(aRule : TRuleFunc);
    function CurrentMessage(const aDefault : string) : string;
  public
    constructor Create(const aPropertyName : string);
    destructor Destroy; override;

    // ── String rules ────────────────────────────────────────────────────────

    /// <summary>String or numeric must not be empty/zero. Equivalent: NotEmpty().</summary>
    function NotEmpty : TPropertyRuleBuilder;
    /// <summary>String or numeric must be empty/zero. Equivalent: Empty().</summary>
    function Empty : TPropertyRuleBuilder;
    /// <summary>String length must be between aMin and aMax (inclusive). Equivalent: Length(min,max).</summary>
    function Length(aMin, aMax : Integer) : TPropertyRuleBuilder;
    /// <summary>String length must not exceed aMax. Equivalent: MaximumLength(max).</summary>
    function MaxLength(aMax : Integer) : TPropertyRuleBuilder;
    /// <summary>String length must be at least aMin. Equivalent: MinimumLength(min).</summary>
    function MinLength(aMin : Integer) : TPropertyRuleBuilder;
    /// <summary>String must match the regex aPattern. Equivalent: Matches(pattern).</summary>
    function Matches(const aPattern : string) : TPropertyRuleBuilder;
    /// <summary>String must be a valid e-mail address. Equivalent: EmailAddress().</summary>
    function EmailAddress : TPropertyRuleBuilder;

    // ── Numeric rules ────────────────────────────────────────────────────────

    /// <summary>Numeric value must be greater than aValue. Equivalent: GreaterThan(value).</summary>
    function GreaterThan(aValue : Double) : TPropertyRuleBuilder;
    /// <summary>Numeric value must be greater than or equal to aValue. Equivalent: GreaterThanOrEqualTo(value).</summary>
    function GreaterThanOrEqualTo(aValue : Double) : TPropertyRuleBuilder;
    /// <summary>Numeric value must be less than aValue. Equivalent: LessThan(value).</summary>
    function LessThan(aValue : Double) : TPropertyRuleBuilder;
    /// <summary>Numeric value must be less than or equal to aValue. Equivalent: LessThanOrEqualTo(value).</summary>
    function LessThanOrEqualTo(aValue : Double) : TPropertyRuleBuilder;
    /// <summary>Numeric value must be between aMin and aMax (inclusive). Equivalent: InclusiveBetween(min,max).</summary>
    function InclusiveBetween(aMin, aMax : Double) : TPropertyRuleBuilder;

    // ── General rules ────────────────────────────────────────────────────────

    /// <summary>Value must not be nil (object) or empty (string). Equivalent: NotNull().</summary>
    function NotNull : TPropertyRuleBuilder;
    /// <summary>
    /// Custom predicate rule. Return True to pass, False to fail.
    /// Use WithMessage before Must to customize the error.
    /// Equivalent: Must(predicate).
    /// </summary>
    function Must(aPredicate : TValuePredicate) : TPropertyRuleBuilder;
    /// <summary>
    /// Custom predicate for typed values. Return True to pass.
    /// </summary>
    function MustBeString(aPredicate : TValuePredicate<string>) : TPropertyRuleBuilder;

    // ── Message customization ────────────────────────────────────────────────

    /// <summary>
    /// Override the error message for the LAST added rule.
    /// Chain AFTER a rule: RuleFor('Name').NotEmpty.WithMessage('Name is required').
    /// Equivalent: WithMessage('...')
    /// </summary>
    function WithMessage(const aMessage : string) : TPropertyRuleBuilder;

    // ── Internal ─────────────────────────────────────────────────────────────
    function ValidateValue(const aValue : TValue) : TArray<string>;
    property PropertyName : string read fPropertyName;
  end;

  // ─── Abstract validator base ──────────────────────────────────────────────

  /// <summary>
  /// Base class for model validators. Subclass and call RuleFor in the
  /// constructor to define validation rules.
  ///
  /// .NET equivalent: AbstractValidator&lt;T&gt; (FluentValidation)
  ///
  /// Usage:
  ///   type
  ///     TUserValidator = class(TAbstractValidator&lt;TUserModel&gt;)
  ///     public
  ///       constructor Create; override;
  ///     end;
  ///
  ///   constructor TUserValidator.Create;
  ///   begin
  ///     inherited;
  ///     RuleFor('Name').NotEmpty.Length(2, 100).WithMessage('Name must be 2-100 chars');
  ///     RuleFor('Email').NotEmpty.EmailAddress;
  ///     RuleFor('Age').GreaterThanOrEqualTo(18).WithMessage('Must be at least 18');
  ///   end;
  ///
  ///   validator := TUserValidator.Create;
  ///   result    := validator.Validate(userModel);
  /// </summary>
  TAbstractValidator<T : class> = class abstract
  private
    fRuleBuilders : TObjectList<TPropertyRuleBuilder>;
    function GetPropertyValue(const aModel : TObject; const aPropName : string) : TValue;
  protected
    /// <summary>
    /// Define a rule for the named published property.
    /// Call from the constructor to register validation rules.
    /// </summary>
    function RuleFor(const aPropertyName : string) : TPropertyRuleBuilder;
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>
    /// Validate the given model. Returns a TValidationResult (caller owns it).
    /// Runs ALL rules on ALL properties — does not stop on first error.
    /// </summary>
    function Validate(const aModel : T) : TValidationResult;
  end;

  // ─── DI interface ─────────────────────────────────────────────────────────

  IValidator<T : class> = interface
  ['{D1E2F3A4-B5C6-7D8E-9F0A-1B2C3D4E5F60}']
    function Validate(const aModel : T) : TValidationResult;
  end;

  /// <summary>
  /// Adapter that makes a TAbstractValidator&lt;T&gt; injectable as IValidator&lt;T&gt;.
  /// </summary>
  TValidatorAdapter<T : class> = class(TInterfacedObject, IValidator<T>)
  private
    fValidator : TAbstractValidator<T>;
    fOwns      : Boolean;
  public
    constructor Create(aValidator : TAbstractValidator<T>; aOwns : Boolean = True);
    destructor Destroy; override;
    function Validate(const aModel : T) : TValidationResult;
  end;

const
  EMAIL_REGEX = '^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$';

implementation

// ─── TValidationResult ────────────────────────────────────────────────────────

constructor TValidationResult.Create;
begin
  inherited Create;
  fErrors := TList<TValidationError>.Create;
end;

destructor TValidationResult.Destroy;
begin
  fErrors.Free;
  inherited;
end;

function TValidationResult.GetIsValid : Boolean;
begin
  Result := fErrors.Count = 0;
end;

procedure TValidationResult.AddError(const aPropertyName, aErrorMessage : string);
var
  err : TValidationError;
begin
  err.PropertyName := aPropertyName;
  err.ErrorMessage := aErrorMessage;
  fErrors.Add(err);
end;

// ─── TPropertyRuleBuilder ─────────────────────────────────────────────────────

constructor TPropertyRuleBuilder.Create(const aPropertyName : string);
begin
  inherited Create;
  fPropertyName   := aPropertyName;
  fRules          := TList<TRuleFunc>.Create;
  fPendingMessage := '';
end;

destructor TPropertyRuleBuilder.Destroy;
begin
  fRules.Free;
  inherited;
end;

function TPropertyRuleBuilder.CurrentMessage(const aDefault : string) : string;
begin
  if fPendingMessage <> '' then
  begin
    Result          := fPendingMessage;
    fPendingMessage := '';
  end
  else
    Result := aDefault;
end;

procedure TPropertyRuleBuilder.AddRule(aRule : TRuleFunc);
begin
  fRules.Add(aRule);
end;

// ── String rules ──────────────────────────────────────────────────────────────

function TPropertyRuleBuilder.NotEmpty : TPropertyRuleBuilder;
var
  msg : string;
begin
  msg := CurrentMessage(Format('''%s'' must not be empty', [fPropertyName]));
  AddRule(function(const v : TValue) : string
    begin
      case v.Kind of
        tkUString, tkString, tkLString, tkWString:
          if v.AsString.Trim = '' then Exit(msg);
        tkInteger, tkInt64:
          if v.AsInt64 = 0 then Exit(msg);
        tkFloat:
          if v.AsExtended = 0 then Exit(msg);
      end;
      Result := '';
    end);
  Result := Self;
end;

function TPropertyRuleBuilder.Empty : TPropertyRuleBuilder;
var
  msg : string;
begin
  msg := CurrentMessage(Format('''%s'' must be empty', [fPropertyName]));
  AddRule(function(const v : TValue) : string
    begin
      case v.Kind of
        tkUString, tkString, tkLString, tkWString:
          if v.AsString.Trim <> '' then Exit(msg);
        tkInteger, tkInt64:
          if v.AsInt64 <> 0 then Exit(msg);
        tkFloat:
          if v.AsExtended <> 0 then Exit(msg);
      end;
      Result := '';
    end);
  Result := Self;
end;

function TPropertyRuleBuilder.Length(aMin, aMax : Integer) : TPropertyRuleBuilder;
var
  msg : string;
  mn  : Integer;
  mx  : Integer;
begin
  mn  := aMin;
  mx  := aMax;
  msg := CurrentMessage(Format('''%s'' must be between %d and %d characters', [fPropertyName, mn, mx]));
  AddRule(function(const v : TValue) : string
    var
      s  : string;
      ln : Integer;
    begin
      s  := v.AsString;
      ln := s.Length;
      if (ln < mn) or (ln > mx) then Exit(msg);
      Result := '';
    end);
  Result := Self;
end;

function TPropertyRuleBuilder.MaxLength(aMax : Integer) : TPropertyRuleBuilder;
var
  msg : string;
  mx  : Integer;
begin
  mx  := aMax;
  msg := CurrentMessage(Format('''%s'' must not exceed %d characters', [fPropertyName, mx]));
  AddRule(function(const v : TValue) : string
    begin
      if v.AsString.Length > mx then Exit(msg);
      Result := '';
    end);
  Result := Self;
end;

function TPropertyRuleBuilder.MinLength(aMin : Integer) : TPropertyRuleBuilder;
var
  msg : string;
  mn  : Integer;
begin
  mn  := aMin;
  msg := CurrentMessage(Format('''%s'' must be at least %d characters', [fPropertyName, mn]));
  AddRule(function(const v : TValue) : string
    begin
      if v.AsString.Length < mn then Exit(msg);
      Result := '';
    end);
  Result := Self;
end;

function TPropertyRuleBuilder.Matches(const aPattern : string) : TPropertyRuleBuilder;
var
  msg     : string;
  pattern : string;
begin
  pattern := aPattern;
  msg     := CurrentMessage(Format('''%s'' does not match required pattern', [fPropertyName]));
  AddRule(function(const v : TValue) : string
    begin
      if not TRegEx.IsMatch(v.AsString, pattern) then Exit(msg);
      Result := '';
    end);
  Result := Self;
end;

function TPropertyRuleBuilder.EmailAddress : TPropertyRuleBuilder;
var
  msg : string;
begin
  msg := CurrentMessage(Format('''%s'' is not a valid email address', [fPropertyName]));
  AddRule(function(const v : TValue) : string
    begin
      if not TRegEx.IsMatch(v.AsString, EMAIL_REGEX, [roIgnoreCase]) then Exit(msg);
      Result := '';
    end);
  Result := Self;
end;

// ── Numeric rules ──────────────────────────────────────────────────────────────

function TPropertyRuleBuilder.GreaterThan(aValue : Double) : TPropertyRuleBuilder;
var
  msg : string;
  av  : Double;
begin
  av  := aValue;
  msg := CurrentMessage(Format('''%s'' must be greater than %g', [fPropertyName, av]));
  AddRule(function(const v : TValue) : string
    begin
      if v.AsExtended <= av then Exit(msg);
      Result := '';
    end);
  Result := Self;
end;

function TPropertyRuleBuilder.GreaterThanOrEqualTo(aValue : Double) : TPropertyRuleBuilder;
var
  msg : string;
  av  : Double;
begin
  av  := aValue;
  msg := CurrentMessage(Format('''%s'' must be greater than or equal to %g', [fPropertyName, av]));
  AddRule(function(const v : TValue) : string
    begin
      if v.AsExtended < av then Exit(msg);
      Result := '';
    end);
  Result := Self;
end;

function TPropertyRuleBuilder.LessThan(aValue : Double) : TPropertyRuleBuilder;
var
  msg : string;
  av  : Double;
begin
  av  := aValue;
  msg := CurrentMessage(Format('''%s'' must be less than %g', [fPropertyName, av]));
  AddRule(function(const v : TValue) : string
    begin
      if v.AsExtended >= av then Exit(msg);
      Result := '';
    end);
  Result := Self;
end;

function TPropertyRuleBuilder.LessThanOrEqualTo(aValue : Double) : TPropertyRuleBuilder;
var
  msg : string;
  av  : Double;
begin
  av  := aValue;
  msg := CurrentMessage(Format('''%s'' must be less than or equal to %g', [fPropertyName, av]));
  AddRule(function(const v : TValue) : string
    begin
      if v.AsExtended > av then Exit(msg);
      Result := '';
    end);
  Result := Self;
end;

function TPropertyRuleBuilder.InclusiveBetween(aMin, aMax : Double) : TPropertyRuleBuilder;
var
  msg : string;
  mn, mx : Double;
begin
  mn  := aMin;
  mx  := aMax;
  msg := CurrentMessage(Format('''%s'' must be between %g and %g', [fPropertyName, mn, mx]));
  AddRule(function(const v : TValue) : string
    var
      d : Double;
    begin
      d := v.AsExtended;
      if (d < mn) or (d > mx) then Exit(msg);
      Result := '';
    end);
  Result := Self;
end;

// ── General rules ──────────────────────────────────────────────────────────────

function TPropertyRuleBuilder.NotNull : TPropertyRuleBuilder;
var
  msg : string;
begin
  msg := CurrentMessage(Format('''%s'' must not be null', [fPropertyName]));
  AddRule(function(const v : TValue) : string
    begin
      if v.IsEmpty or (v.IsObject and (v.AsObject = nil)) then Exit(msg);
      Result := '';
    end);
  Result := Self;
end;

function TPropertyRuleBuilder.Must(aPredicate : TValuePredicate) : TPropertyRuleBuilder;
var
  msg  : string;
  pred : TValuePredicate;
begin
  pred := aPredicate;
  msg  := CurrentMessage(Format('''%s'' failed custom validation', [fPropertyName]));
  AddRule(function(const v : TValue) : string
    begin
      if not pred(v) then Exit(msg);
      Result := '';
    end);
  Result := Self;
end;

function TPropertyRuleBuilder.MustBeString(aPredicate : TValuePredicate<string>) : TPropertyRuleBuilder;
var
  msg  : string;
  pred : TValuePredicate<string>;
begin
  pred := aPredicate;
  msg  := CurrentMessage(Format('''%s'' failed custom validation', [fPropertyName]));
  AddRule(function(const v : TValue) : string
    begin
      if not pred(v.AsString) then Exit(msg);
      Result := '';
    end);
  Result := Self;
end;

// ── Message override ──────────────────────────────────────────────────────────

function TPropertyRuleBuilder.WithMessage(const aMessage : string) : TPropertyRuleBuilder;
var
  lastIdx : Integer;
  lastMsg : string;
begin
  // Replace the last rule with a version that uses the new message
  if fRules.Count = 0 then
  begin
    // No rule yet — store as pending message for the next rule
    fPendingMessage := aMessage;
    Exit(Self);
  end;

  // We cannot modify a closure directly.
  // Strategy: Remove last rule and re-add a wrapper that replaces non-empty results.
  lastIdx := fRules.Count - 1;
  var originalRule := fRules[lastIdx];
  lastMsg := aMessage;
  fRules.Delete(lastIdx);
  // Re-register with overridden message: run original, replace any error with aMessage
  AddRule(function(const v : TValue) : string
    begin
      Result := originalRule(v);
      if Result <> '' then Result := lastMsg;
    end);
  Result := Self;
end;

// ── Validate ──────────────────────────────────────────────────────────────────

function TPropertyRuleBuilder.ValidateValue(const aValue : TValue) : TArray<string>;
var
  rule : TRuleFunc;
  err  : string;
  list : TList<string>;
begin
  list := TList<string>.Create;
  try
    for rule in fRules do
    begin
      err := rule(aValue);
      if err <> '' then
        list.Add(err);
    end;
    Result := list.ToArray;
  finally
    list.Free;
  end;
end;

// ─── TAbstractValidator<T> ───────────────────────────────────────────────────

constructor TAbstractValidator<T>.Create;
begin
  inherited Create;
  fRuleBuilders := TObjectList<TPropertyRuleBuilder>.Create(True); // owns builders
end;

destructor TAbstractValidator<T>.Destroy;
begin
  fRuleBuilders.Free;
  inherited;
end;

function TAbstractValidator<T>.RuleFor(const aPropertyName : string) : TPropertyRuleBuilder;
var
  builder : TPropertyRuleBuilder;
begin
  builder := TPropertyRuleBuilder.Create(aPropertyName);
  fRuleBuilders.Add(builder);
  Result := builder;
end;

function TAbstractValidator<T>.GetPropertyValue(const aModel : TObject;
  const aPropName : string) : TValue;
var
  ctx   : TRttiContext;
  rType : TRttiType;
  rProp : TRttiProperty;
begin
  Result := TValue.Empty;
  rType  := ctx.GetType(aModel.ClassInfo);
  for rProp in rType.GetProperties do
  begin
    if SameText(rProp.Name, aPropName) then
      Exit(rProp.GetValue(aModel));
  end;
  raise EArgumentException.CreateFmt(
    'TAbstractValidator: Property "%s" not found on %s',
    [aPropName, aModel.ClassName]);
end;

function TAbstractValidator<T>.Validate(const aModel : T) : TValidationResult;
var
  builder : TPropertyRuleBuilder;
  value   : TValue;
  errors  : TArray<string>;
  err     : string;
begin
  Result := TValidationResult.Create;
  for builder in fRuleBuilders do
  begin
    value  := GetPropertyValue(aModel, builder.PropertyName);
    errors := builder.ValidateValue(value);
    for err in errors do
      Result.AddError(builder.PropertyName, err);
  end;
end;

// ─── TValidatorAdapter<T> ─────────────────────────────────────────────────────

constructor TValidatorAdapter<T>.Create(aValidator : TAbstractValidator<T>; aOwns : Boolean);
begin
  inherited Create;
  fValidator := aValidator;
  fOwns      := aOwns;
end;

destructor TValidatorAdapter<T>.Destroy;
begin
  if fOwns then fValidator.Free;
  inherited;
end;

function TValidatorAdapter<T>.Validate(const aModel : T) : TValidationResult;
begin
  Result := fValidator.Validate(aModel);
end;

end.
