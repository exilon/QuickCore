unit Quick.Core.Mvc.ModelValidation.Tests;

{ Tests: T-MV-01..15
    T-MV-01  [Required] - valid non-empty string passes
    T-MV-02  [Required] - empty string fails with default message
    T-MV-03  [Required] - custom error message is propagated
    T-MV-04  [Range] - value inside range passes
    T-MV-05  [Range] - value below minimum fails
    T-MV-06  [Range] - value above maximum fails
    T-MV-07  [StringLength(max)] - string within limit passes
    T-MV-08  [StringLength(max)] - string over limit fails
    T-MV-09  [StringLength(min,max)] - string below minimum fails
    T-MV-10  [RegularExpression] - matching string passes
    T-MV-11  [RegularExpression] - non-matching string fails
    T-MV-12  [EmailAddress] - valid e-mail passes
    T-MV-13  [EmailAddress] - invalid e-mail fails
    T-MV-14  TModelState.IsValid - True when no errors
    T-MV-15  TModelState.ToJsonString - contains field name and message
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Quick.Core.Mvc.ModelValidation;

type

  // ---- Model fixtures ----

  {$M+}
  TRequiredModel = class
  private
    fName : string;
  published
    [Required]
    property Name : string read fName write fName;
  end;

  TRequiredCustomMsgModel = class
  private
    fEmail : string;
  published
    [Required('E-mail is required')]
    property Email : string read fEmail write fEmail;
  end;

  TRangeModel = class
  private
    fAge : Integer;
  published
    [Range(18, 99)]
    property Age : Integer read fAge write fAge;
  end;

  TStringLengthMaxModel = class
  private
    fCode : string;
  published
    [StringLength(5)]
    property Code : string read fCode write fCode;
  end;

  TStringLengthMinMaxModel = class
  private
    fUsername : string;
  published
    [StringLength(3, 20)]
    property Username : string read fUsername write fUsername;
  end;

  TRegexModel = class
  private
    fZip : string;
  published
    [RegularExpression('^\d{5}$', 'Must be a 5-digit zip code')]
    property Zip : string read fZip write fZip;
  end;

  TEmailModel = class
  private
    fEmail : string;
  published
    [EmailAddress]
    property Email : string read fEmail write fEmail;
  end;

  TMultiValidModel = class
  private
    fName  : string;
    fAge   : Integer;
    fEmail : string;
  published
    [Required]
    property Name  : string  read fName  write fName;
    [Range(1, 120)]
    property Age   : Integer read fAge   write fAge;
    [EmailAddress]
    property Email : string  read fEmail write fEmail;
  end;
  {$M-}

  [TestFixture]
  TModelValidationTests = class
  public
    [Test]
    procedure T_MV_01_Required_Valid_Passes;
    [Test]
    procedure T_MV_02_Required_Empty_Fails;
    [Test]
    procedure T_MV_03_Required_Custom_Error_Message;
    [Test]
    procedure T_MV_04_Range_Inside_Passes;
    [Test]
    procedure T_MV_05_Range_Below_Min_Fails;
    [Test]
    procedure T_MV_06_Range_Above_Max_Fails;
    [Test]
    procedure T_MV_07_StringLength_Max_Within_Limit_Passes;
    [Test]
    procedure T_MV_08_StringLength_Max_Over_Limit_Fails;
    [Test]
    procedure T_MV_09_StringLength_Min_Below_Minimum_Fails;
    [Test]
    procedure T_MV_10_Regex_Matching_Passes;
    [Test]
    procedure T_MV_11_Regex_NonMatching_Fails;
    [Test]
    procedure T_MV_12_Email_Valid_Passes;
    [Test]
    procedure T_MV_13_Email_Invalid_Fails;
    [Test]
    procedure T_MV_14_ModelState_IsValid_True_When_No_Errors;
    [Test]
    procedure T_MV_15_ModelState_ToJsonString_Contains_Field_And_Message;
  end;

implementation

// ─── helpers ─────────────────────────────────────────────────────────────────

procedure TModelValidationTests.T_MV_01_Required_Valid_Passes;
var
  m  : TRequiredModel;
  ms : TModelState;
begin
  m := TRequiredModel.Create;
  try
    m.Name := 'Alice';
    ms := TModelValidator.Validate(m);
    try
      Assert.IsTrue(ms.IsValid, 'Non-empty name should pass [Required]');
    finally
      ms.Free;
    end;
  finally
    m.Free;
  end;
end;

procedure TModelValidationTests.T_MV_02_Required_Empty_Fails;
var
  m  : TRequiredModel;
  ms : TModelState;
begin
  m := TRequiredModel.Create;
  try
    m.Name := '';
    ms := TModelValidator.Validate(m);
    try
      Assert.IsFalse(ms.IsValid, 'Empty name should fail [Required]');
      Assert.AreEqual<Integer>(1, ms.Errors.Count);
      Assert.AreEqual('Name', ms.Errors[0].PropertyName);
    finally
      ms.Free;
    end;
  finally
    m.Free;
  end;
end;

procedure TModelValidationTests.T_MV_03_Required_Custom_Error_Message;
var
  m  : TRequiredCustomMsgModel;
  ms : TModelState;
begin
  m := TRequiredCustomMsgModel.Create;
  try
    m.Email := '';
    ms := TModelValidator.Validate(m);
    try
      Assert.IsFalse(ms.IsValid);
      Assert.AreEqual('E-mail is required', ms.Errors[0].ErrorMessage);
    finally
      ms.Free;
    end;
  finally
    m.Free;
  end;
end;

procedure TModelValidationTests.T_MV_04_Range_Inside_Passes;
var
  m  : TRangeModel;
  ms : TModelState;
begin
  m := TRangeModel.Create;
  try
    m.Age := 25;
    ms := TModelValidator.Validate(m);
    try
      Assert.IsTrue(ms.IsValid, 'Age=25 inside [18..99] should pass');
    finally
      ms.Free;
    end;
  finally
    m.Free;
  end;
end;

procedure TModelValidationTests.T_MV_05_Range_Below_Min_Fails;
var
  m  : TRangeModel;
  ms : TModelState;
begin
  m := TRangeModel.Create;
  try
    m.Age := 10;
    ms := TModelValidator.Validate(m);
    try
      Assert.IsFalse(ms.IsValid, 'Age=10 below minimum 18 should fail');
      Assert.AreEqual('Age', ms.Errors[0].PropertyName);
    finally
      ms.Free;
    end;
  finally
    m.Free;
  end;
end;

procedure TModelValidationTests.T_MV_06_Range_Above_Max_Fails;
var
  m  : TRangeModel;
  ms : TModelState;
begin
  m := TRangeModel.Create;
  try
    m.Age := 150;
    ms := TModelValidator.Validate(m);
    try
      Assert.IsFalse(ms.IsValid, 'Age=150 above maximum 99 should fail');
    finally
      ms.Free;
    end;
  finally
    m.Free;
  end;
end;

procedure TModelValidationTests.T_MV_07_StringLength_Max_Within_Limit_Passes;
var
  m  : TStringLengthMaxModel;
  ms : TModelState;
begin
  m := TStringLengthMaxModel.Create;
  try
    m.Code := 'ABC';   // 3 ≤ max 5
    ms := TModelValidator.Validate(m);
    try
      Assert.IsTrue(ms.IsValid, '"ABC" is within max length 5');
    finally
      ms.Free;
    end;
  finally
    m.Free;
  end;
end;

procedure TModelValidationTests.T_MV_08_StringLength_Max_Over_Limit_Fails;
var
  m  : TStringLengthMaxModel;
  ms : TModelState;
begin
  m := TStringLengthMaxModel.Create;
  try
    m.Code := 'ABCDEF';   // 6 > max 5
    ms := TModelValidator.Validate(m);
    try
      Assert.IsFalse(ms.IsValid, '"ABCDEF" exceeds max length 5');
      Assert.AreEqual('Code', ms.Errors[0].PropertyName);
    finally
      ms.Free;
    end;
  finally
    m.Free;
  end;
end;

procedure TModelValidationTests.T_MV_09_StringLength_Min_Below_Minimum_Fails;
var
  m  : TStringLengthMinMaxModel;
  ms : TModelState;
begin
  m := TStringLengthMinMaxModel.Create;
  try
    m.Username := 'ab';   // 2 < min 3
    ms := TModelValidator.Validate(m);
    try
      Assert.IsFalse(ms.IsValid, '"ab" is below minimum length 3');
    finally
      ms.Free;
    end;
  finally
    m.Free;
  end;
end;

procedure TModelValidationTests.T_MV_10_Regex_Matching_Passes;
var
  m  : TRegexModel;
  ms : TModelState;
begin
  m := TRegexModel.Create;
  try
    m.Zip := '12345';
    ms := TModelValidator.Validate(m);
    try
      Assert.IsTrue(ms.IsValid, '"12345" should match 5-digit zip pattern');
    finally
      ms.Free;
    end;
  finally
    m.Free;
  end;
end;

procedure TModelValidationTests.T_MV_11_Regex_NonMatching_Fails;
var
  m  : TRegexModel;
  ms : TModelState;
begin
  m := TRegexModel.Create;
  try
    m.Zip := 'ABCDE';
    ms := TModelValidator.Validate(m);
    try
      Assert.IsFalse(ms.IsValid, '"ABCDE" should not match zip pattern');
      Assert.AreEqual('Must be a 5-digit zip code', ms.Errors[0].ErrorMessage);
    finally
      ms.Free;
    end;
  finally
    m.Free;
  end;
end;

procedure TModelValidationTests.T_MV_12_Email_Valid_Passes;
var
  m  : TEmailModel;
  ms : TModelState;
begin
  m := TEmailModel.Create;
  try
    m.Email := 'user@example.com';
    ms := TModelValidator.Validate(m);
    try
      Assert.IsTrue(ms.IsValid, 'Valid e-mail should pass [EmailAddress]');
    finally
      ms.Free;
    end;
  finally
    m.Free;
  end;
end;

procedure TModelValidationTests.T_MV_13_Email_Invalid_Fails;
var
  m  : TEmailModel;
  ms : TModelState;
begin
  m := TEmailModel.Create;
  try
    m.Email := 'not-an-email';
    ms := TModelValidator.Validate(m);
    try
      Assert.IsFalse(ms.IsValid, '"not-an-email" should fail [EmailAddress]');
    finally
      ms.Free;
    end;
  finally
    m.Free;
  end;
end;

procedure TModelValidationTests.T_MV_14_ModelState_IsValid_True_When_No_Errors;
var
  ms : TModelState;
begin
  ms := TModelState.Create;
  try
    Assert.IsTrue(ms.IsValid, 'Fresh TModelState with no errors should be valid');
    Assert.AreEqual<Integer>(0, ms.Errors.Count);
  finally
    ms.Free;
  end;
end;

procedure TModelValidationTests.T_MV_15_ModelState_ToJsonString_Contains_Field_And_Message;
var
  ms  : TModelState;
  json : string;
begin
  ms := TModelState.Create;
  try
    ms.AddError('Email', 'Invalid e-mail address');
    json := ms.ToJsonString;
    Assert.IsTrue(json.Contains('Email'),   'JSON should contain field name');
    Assert.IsTrue(json.Contains('Invalid'), 'JSON should contain error message');
  finally
    ms.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TModelValidationTests);

end.
