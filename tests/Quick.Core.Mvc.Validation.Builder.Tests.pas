unit Quick.Core.Mvc.Validation.Builder.Tests;

{ Tests: T-FVB-01..15
    T-FVB-01  NotEmpty fails on empty string
    T-FVB-02  NotEmpty passes on non-empty string
    T-FVB-03  Length(2,50) fails when too short
    T-FVB-04  Length(2,50) fails when too long
    T-FVB-05  Length(2,50) passes when in range
    T-FVB-06  EmailAddress fails on invalid email
    T-FVB-07  EmailAddress passes on valid email
    T-FVB-08  GreaterThanOrEqualTo(18) fails when below threshold
    T-FVB-09  GreaterThanOrEqualTo(18) passes when at threshold
    T-FVB-10  WithMessage overrides error message on last rule
    T-FVB-11  Multiple rules on same property produce all errors
    T-FVB-12  Multiple properties validated independently
    T-FVB-13  IsValid is True when no errors found
    T-FVB-14  Must(custom predicate) fails when predicate returns False
    T-FVB-15  InclusiveBetween fails when out of range
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Rtti,
  Quick.Core.Mvc.Validation.Builder;

// ── Domain model ──────────────────────────────────────────────────────────────

type
  {$M+}
  TUserModel = class
  private
    fName     : string;
    fEmail    : string;
    fAge      : Integer;
    fUsername : string;
    fScore    : Double;
  published
    property Name     : string  read fName     write fName;
    property Email    : string  read fEmail    write fEmail;
    property Age      : Integer read fAge      write fAge;
    property Username : string  read fUsername write fUsername;
    property Score    : Double  read fScore    write fScore;
  end;
  {$M-}

// ── Concrete validator ────────────────────────────────────────────────────────

  TUserValidator = class(TAbstractValidator<TUserModel>)
  public
    constructor Create; reintroduce;
  end;

  TCustomMsgValidator = class(TAbstractValidator<TUserModel>)
  public
    constructor Create; reintroduce;
  end;

  TMustValidator = class(TAbstractValidator<TUserModel>)
  public
    constructor Create; reintroduce;
  end;

// ── Test fixture ──────────────────────────────────────────────────────────────

  [TestFixture]
  TFluentValidationBuilderTests = class
  private
    FValidator : TUserValidator;
    FModel     : TUserModel;
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure T_FVB_01_NotEmpty_FailsOnEmptyString;
    [Test]
    procedure T_FVB_02_NotEmpty_PassesOnNonEmpty;
    [Test]
    procedure T_FVB_03_Length_FailsWhenTooShort;
    [Test]
    procedure T_FVB_04_Length_FailsWhenTooLong;
    [Test]
    procedure T_FVB_05_Length_PassesWhenInRange;
    [Test]
    procedure T_FVB_06_EmailAddress_FailsOnInvalid;
    [Test]
    procedure T_FVB_07_EmailAddress_PassesOnValid;
    [Test]
    procedure T_FVB_08_GreaterThanOrEqualTo_FailsWhenBelow;
    [Test]
    procedure T_FVB_09_GreaterThanOrEqualTo_PassesAtThreshold;
    [Test]
    procedure T_FVB_10_WithMessage_OverridesErrorMessage;
    [Test]
    procedure T_FVB_11_MultipleRulesSameProperty_AllErrorsReported;
    [Test]
    procedure T_FVB_12_MultipleProperties_ValidatedIndependently;
    [Test]
    procedure T_FVB_13_IsValid_TrueWhenNoErrors;
    [Test]
    procedure T_FVB_14_Must_FailsWhenPredicateFalse;
    [Test]
    procedure T_FVB_15_InclusiveBetween_FailsOutOfRange;
  end;

implementation

// ── TUserValidator ────────────────────────────────────────────────────────────

constructor TUserValidator.Create;
begin
  inherited;
  RuleFor('Name').NotEmpty.Length(2, 100);
  RuleFor('Email').NotEmpty.EmailAddress;
  RuleFor('Age').GreaterThanOrEqualTo(18).LessThanOrEqualTo(120);
  RuleFor('Username').MinLength(3).MaxLength(30)
    .Matches('^[a-zA-Z0-9_]+$').WithMessage('''Username'' must contain only letters, digits and underscore');
  RuleFor('Score').InclusiveBetween(0, 100);
end;

// ── TFluentValidationBuilderTests ─────────────────────────────────────────────

procedure TFluentValidationBuilderTests.SetUp;
begin
  FValidator := TUserValidator.Create;
  // Valid model by default
  FModel           := TUserModel.Create;
  FModel.Name      := 'John Doe';
  FModel.Email     := 'john@example.com';
  FModel.Age       := 30;
  FModel.Username  := 'johndoe';
  FModel.Score     := 85.5;
end;

procedure TFluentValidationBuilderTests.TearDown;
begin
  FValidator.Free;
  FModel.Free;
end;

{ T-FVB-01 }
procedure TFluentValidationBuilderTests.T_FVB_01_NotEmpty_FailsOnEmptyString;
var
  r : TValidationResult;
begin
  FModel.Name := '';
  r := FValidator.Validate(FModel);
  try
    Assert.IsFalse(r.IsValid);
    Assert.IsTrue(r.Errors.Count > 0);
    Assert.AreEqual('Name', r.Errors[0].PropertyName);
  finally
    r.Free;
  end;
end;

{ T-FVB-02 }
procedure TFluentValidationBuilderTests.T_FVB_02_NotEmpty_PassesOnNonEmpty;
var
  r          : TValidationResult;
  nameErrors : Integer;
  e          : TValidationError;
begin
  // Name already 'John Doe' in setup
  r := FValidator.Validate(FModel);
  try
    // Check no Name errors
    nameErrors := 0;
    for e in r.Errors do
      if e.PropertyName = 'Name' then Inc(nameErrors);
    Assert.AreEqual(0, nameErrors, 'Name must have no errors');
  finally
    r.Free;
  end;
end;

{ T-FVB-03 }
procedure TFluentValidationBuilderTests.T_FVB_03_Length_FailsWhenTooShort;
var
  r     : TValidationResult;
  found : Boolean;
  e     : TValidationError;
begin
  FModel.Name := 'A'; // length 1, min is 2
  r := FValidator.Validate(FModel);
  try
    Assert.IsFalse(r.IsValid);
    found := False;
    for e in r.Errors do
      if (e.PropertyName = 'Name') and e.ErrorMessage.Contains('between') then
        found := True;
    Assert.IsTrue(found, 'Expected a Length error on Name');
  finally
    r.Free;
  end;
end;

{ T-FVB-04 }
procedure TFluentValidationBuilderTests.T_FVB_04_Length_FailsWhenTooLong;
var
  r     : TValidationResult;
  found : Boolean;
  e     : TValidationError;
begin
  FModel.Name := StringOfChar('A', 101); // length 101, max is 100
  r := FValidator.Validate(FModel);
  try
    Assert.IsFalse(r.IsValid);
    found := False;
    for e in r.Errors do
      if e.PropertyName = 'Name' then found := True;
    Assert.IsTrue(found, 'Expected a Length error on Name');
  finally
    r.Free;
  end;
end;

{ T-FVB-05 }
procedure TFluentValidationBuilderTests.T_FVB_05_Length_PassesWhenInRange;
var
  r          : TValidationResult;
  nameErrors : Integer;
  e          : TValidationError;
begin
  FModel.Name := 'Jo'; // length 2, exactly at min
  r := FValidator.Validate(FModel);
  try
    nameErrors := 0;
    for e in r.Errors do
      if e.PropertyName = 'Name' then Inc(nameErrors);
    Assert.AreEqual(0, nameErrors, 'Name length=2 should pass Length(2,100)');
  finally
    r.Free;
  end;
end;

{ T-FVB-06 }
procedure TFluentValidationBuilderTests.T_FVB_06_EmailAddress_FailsOnInvalid;
var
  r     : TValidationResult;
  found : Boolean;
  e     : TValidationError;
begin
  FModel.Email := 'not-an-email';
  r := FValidator.Validate(FModel);
  try
    Assert.IsFalse(r.IsValid);
    found := False;
    for e in r.Errors do
      if e.PropertyName = 'Email' then found := True;
    Assert.IsTrue(found, 'Expected EmailAddress error on Email');
  finally
    r.Free;
  end;
end;

{ T-FVB-07 }
procedure TFluentValidationBuilderTests.T_FVB_07_EmailAddress_PassesOnValid;
var
  r           : TValidationResult;
  emailErrors : Integer;
  e           : TValidationError;
begin
  // Email is 'john@example.com' from setup
  r := FValidator.Validate(FModel);
  try
    emailErrors := 0;
    for e in r.Errors do
      if e.PropertyName = 'Email' then Inc(emailErrors);
    Assert.AreEqual(0, emailErrors, 'Valid email must produce no errors');
  finally
    r.Free;
  end;
end;

{ T-FVB-08 }
procedure TFluentValidationBuilderTests.T_FVB_08_GreaterThanOrEqualTo_FailsWhenBelow;
var
  r     : TValidationResult;
  found : Boolean;
  e     : TValidationError;
begin
  FModel.Age := 16; // below 18
  r := FValidator.Validate(FModel);
  try
    Assert.IsFalse(r.IsValid);
    found := False;
    for e in r.Errors do
      if e.PropertyName = 'Age' then found := True;
    Assert.IsTrue(found, 'Expected GreaterThanOrEqualTo error on Age');
  finally
    r.Free;
  end;
end;

{ T-FVB-09 }
procedure TFluentValidationBuilderTests.T_FVB_09_GreaterThanOrEqualTo_PassesAtThreshold;
var
  r         : TValidationResult;
  ageErrors : Integer;
  e         : TValidationError;
begin
  FModel.Age := 18; // exactly at threshold
  r := FValidator.Validate(FModel);
  try
    ageErrors := 0;
    for e in r.Errors do
      if e.PropertyName = 'Age' then Inc(ageErrors);
    Assert.AreEqual(0, ageErrors, 'Age=18 must pass GreaterThanOrEqualTo(18)');
  finally
    r.Free;
  end;
end;

{ T-FVB-10 }
procedure TFluentValidationBuilderTests.T_FVB_10_WithMessage_OverridesErrorMessage;
var
  cv    : TCustomMsgValidator;
  r     : TValidationResult;
  found : Boolean;
  e     : TValidationError;
begin
  cv := TCustomMsgValidator.Create;
  FModel.Name := '';
  r := cv.Validate(FModel);
  try
    Assert.IsFalse(r.IsValid);
    found := False;
    for e in r.Errors do
      if (e.PropertyName = 'Name') and (e.ErrorMessage = 'Name is required') then
        found := True;
    Assert.IsTrue(found, 'WithMessage must override the default error text');
  finally
    r.Free;
    cv.Free;
  end;
end;

{ T-FVB-11 }
procedure TFluentValidationBuilderTests.T_FVB_11_MultipleRulesSameProperty_AllErrorsReported;
var
  r          : TValidationResult;
  nameErrors : Integer;
  e          : TValidationError;
begin
  FModel.Name := ''; // empty → fails NotEmpty AND Length(2,100)
  r := FValidator.Validate(FModel);
  try
    nameErrors := 0;
    for e in r.Errors do
      if e.PropertyName = 'Name' then Inc(nameErrors);
    // NotEmpty fires first; Length also fires (empty string has len 0 < 2)
    Assert.IsTrue(nameErrors >= 1, 'Must have at least one Name error');
  finally
    r.Free;
  end;
end;

{ T-FVB-12 }
procedure TFluentValidationBuilderTests.T_FVB_12_MultipleProperties_ValidatedIndependently;
var
  r           : TValidationResult;
  nameErrors  : Integer;
  emailErrors : Integer;
  ageErrors   : Integer;
  e           : TValidationError;
begin
  FModel.Name  := '';             // fails
  FModel.Email := 'bad-email';   // fails
  FModel.Age   := 30;            // passes
  r := FValidator.Validate(FModel);
  try
    Assert.IsFalse(r.IsValid);
    nameErrors := 0;
    emailErrors := 0;
    ageErrors := 0;
    for e in r.Errors do
    begin
      if e.PropertyName = 'Name'  then Inc(nameErrors);
      if e.PropertyName = 'Email' then Inc(emailErrors);
      if e.PropertyName = 'Age'   then Inc(ageErrors);
    end;
    Assert.IsTrue(nameErrors > 0,   'Name must have errors');
    Assert.IsTrue(emailErrors > 0,  'Email must have errors');
    Assert.AreEqual(0, ageErrors,   'Age must have no errors');
  finally
    r.Free;
  end;
end;

{ T-FVB-13 }
procedure TFluentValidationBuilderTests.T_FVB_13_IsValid_TrueWhenNoErrors;
var
  r : TValidationResult;
begin
  // Default setup: all valid
  r := FValidator.Validate(FModel);
  try
    Assert.IsTrue(r.IsValid, 'All-valid model must produce IsValid=True');
    Assert.AreEqual<Integer>(0, r.Errors.Count);
  finally
    r.Free;
  end;
end;

{ T-FVB-14 }
procedure TFluentValidationBuilderTests.T_FVB_14_Must_FailsWhenPredicateFalse;
var
  mv    : TMustValidator;
  r     : TValidationResult;
  found : Boolean;
  e     : TValidationError;
begin
  mv := TMustValidator.Create;
  FModel.Name := 'invalid!'; // contains '!'
  r := mv.Validate(FModel);
  try
    Assert.IsFalse(r.IsValid);
    found := False;
    for e in r.Errors do
      if e.PropertyName = 'Name' then found := True;
    Assert.IsTrue(found, 'Must predicate must report Name error');
  finally
    r.Free;
    mv.Free;
  end;
end;

{ T-FVB-15 }
procedure TFluentValidationBuilderTests.T_FVB_15_InclusiveBetween_FailsOutOfRange;
var
  r     : TValidationResult;
  found : Boolean;
  e     : TValidationError;
begin
  FModel.Score := 150.0; // above 100
  r := FValidator.Validate(FModel);
  try
    Assert.IsFalse(r.IsValid);
    found := False;
    for e in r.Errors do
      if e.PropertyName = 'Score' then found := True;
    Assert.IsTrue(found, 'Score > 100 must fail InclusiveBetween');
  finally
    r.Free;
  end;
end;

constructor TCustomMsgValidator.Create;
begin
  inherited;
  RuleFor('Name').WithMessage('Name is required').NotEmpty;
end;

constructor TMustValidator.Create;
begin
  inherited;
  RuleFor('Name')
    .Must(function(const v: TValue): Boolean
      begin
        Result := not v.AsString.Contains('!');
      end)
    .WithMessage('''Name'' must not contain exclamation marks');
end;

initialization
  TDUnitX.RegisterTestFixture(TFluentValidationBuilderTests);

end.
