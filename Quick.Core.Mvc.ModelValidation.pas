{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Mvc.ModelValidation
  Description : Core Mvc Model Validation
  Author      : Kike Perez
  Version     : 1.0
  Created     : 13/04/2026
  Modified    : 08/05/2026

  This file is part of QuickCore: https://github.com/exilon/QuickCore

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

unit Quick.Core.Mvc.ModelValidation;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.RegularExpressions,
  RTTI,
  System.TypInfo,
  System.Generics.Collections,
  Quick.Collections;

type

  { ----------- Validation attributes ----------- }

  /// <summary>Property must not be empty/nil/zero.</summary>
  Required = class(TCustomAttribute)
  private
    fErrorMessage : string;
  public
    constructor Create(const aErrorMessage : string = '');
    property ErrorMessage : string read fErrorMessage;
  end;

  /// <summary>Numeric value must be between Min and Max (inclusive).</summary>
  Range = class(TCustomAttribute)
  private
    fMin, fMax : Double;
    fErrorMessage : string;
  public
    constructor Create(aMin, aMax : Double; const aErrorMessage : string = ''); overload;
    constructor Create(aMin, aMax : Integer; const aErrorMessage : string = ''); overload;
    property Min : Double read fMin;
    property Max : Double read fMax;
    property ErrorMessage : string read fErrorMessage;
  end;

  /// <summary>String length must be between MinLength and MaxLength.</summary>
  StringLength = class(TCustomAttribute)
  private
    fMinLength, fMaxLength : Integer;
    fErrorMessage : string;
  public
    constructor Create(aMaxLength : Integer; const aErrorMessage : string = ''); overload;
    constructor Create(aMinLength, aMaxLength : Integer; const aErrorMessage : string = ''); overload;
    property MinLength : Integer read fMinLength;
    property MaxLength : Integer read fMaxLength;
    property ErrorMessage : string read fErrorMessage;
  end;

  /// <summary>String must match the given regex pattern.</summary>
  RegularExpression = class(TCustomAttribute)
  private
    fPattern : string;
    fErrorMessage : string;
  public
    constructor Create(const aPattern : string; const aErrorMessage : string = '');
    property Pattern : string read fPattern;
    property ErrorMessage : string read fErrorMessage;
  end;

  /// <summary>String must be a valid e-mail address.</summary>
  EmailAddress = class(TCustomAttribute)
  private
    fErrorMessage : string;
  public
    constructor Create(const aErrorMessage : string = '');
    property ErrorMessage : string read fErrorMessage;
  end;

  { ----------- Validation result ----------- }

  TModelError = record
    PropertyName : string;
    ErrorMessage : string;
  end;

  TModelState = class
  private
    fErrors : TList<TModelError>;
    function GetIsValid : Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    property IsValid : Boolean read GetIsValid;
    property Errors : TList<TModelError> read fErrors;
    procedure AddError(const aProperty, aMessage : string);
    function ToJsonString : string;
  end;

  { ----------- Validator ----------- }

  TModelValidator = class
  public
    /// <summary>Validate all published properties of aModel using attributes.
    ///  Returns a populated TModelState (caller owns it).</summary>
    class function Validate(aModel : TObject) : TModelState;
  end;

implementation

const
  EMAIL_PATTERN = '^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$';

{ Required }

constructor Required.Create(const aErrorMessage : string);
begin
  fErrorMessage := aErrorMessage;
  if fErrorMessage = '' then fErrorMessage := 'Field is required';
end;

{ Range }

constructor Range.Create(aMin, aMax : Double; const aErrorMessage : string);
begin
  fMin := aMin;
  fMax := aMax;
  fErrorMessage := aErrorMessage;
  if fErrorMessage = '' then
    fErrorMessage := Format('Value must be between %g and %g', [aMin, aMax]);
end;

constructor Range.Create(aMin, aMax : Integer; const aErrorMessage : string);
begin
  Create(Double(aMin), Double(aMax), aErrorMessage);
end;

{ StringLength }

constructor StringLength.Create(aMaxLength : Integer; const aErrorMessage : string);
begin
  Create(0, aMaxLength, aErrorMessage);
end;

constructor StringLength.Create(aMinLength, aMaxLength : Integer; const aErrorMessage : string);
begin
  fMinLength := aMinLength;
  fMaxLength := aMaxLength;
  fErrorMessage := aErrorMessage;
  if fErrorMessage = '' then
  begin
    if aMinLength > 0 then
      fErrorMessage := Format('Length must be between %d and %d characters', [aMinLength, aMaxLength])
    else
      fErrorMessage := Format('Maximum length is %d characters', [aMaxLength]);
  end;
end;

{ RegularExpression }

constructor RegularExpression.Create(const aPattern, aErrorMessage : string);
begin
  fPattern := aPattern;
  fErrorMessage := aErrorMessage;
  if fErrorMessage = '' then fErrorMessage := 'Field format is invalid';
end;

{ EmailAddress }

constructor EmailAddress.Create(const aErrorMessage : string);
begin
  fErrorMessage := aErrorMessage;
  if fErrorMessage = '' then fErrorMessage := 'Invalid e-mail address';
end;

{ TModelState }

constructor TModelState.Create;
begin
  fErrors := TList<TModelError>.Create;
end;

destructor TModelState.Destroy;
begin
  fErrors.Free;
  inherited;
end;

function TModelState.GetIsValid : Boolean;
begin
  Result := fErrors.Count = 0;
end;

procedure TModelState.AddError(const aProperty, aMessage : string);
var
  err : TModelError;
begin
  err.PropertyName := aProperty;
  err.ErrorMessage := aMessage;
  fErrors.Add(err);
end;

function TModelState.ToJsonString : string;
var
  sb : TStringBuilder;
  i : Integer;
  err : TModelError;
begin
  sb := TStringBuilder.Create;
  try
    sb.Append('{"errors":{');
    for i := 0 to fErrors.Count - 1 do
    begin
      err := fErrors[i];
      if i > 0 then sb.Append(',');
      sb.AppendFormat('"%s":["%s"]', [err.PropertyName, err.ErrorMessage]);
    end;
    sb.Append('}}');
    Result := sb.ToString;
  finally
    sb.Free;
  end;
end;

{ TModelValidator }

class function TModelValidator.Validate(aModel : TObject) : TModelState;
var
  ctx : TRttiContext;
  rType : TRttiType;
  rProp : TRttiProperty;
  attr : TCustomAttribute;
  state : TModelState;
  propValue : TValue;
  strValue : string;
  dblValue : Double;
  isNull : Boolean;
begin
  state := TModelState.Create;
  rType := ctx.GetType(aModel.ClassInfo);
  for rProp in rType.GetProperties do
  begin
    if not (rProp.Visibility in [mvPublished]) then Continue;
    propValue := rProp.GetValue(aModel);

    // Determine if the value is "null/empty"
    case propValue.Kind of
      tkString, tkUString, tkWString, tkLString :
        isNull := propValue.AsString = '';
      tkInteger, tkInt64, tkFloat :
        isNull := False; // numerics are never "absent"
      tkClass :
        isNull := propValue.IsEmpty or (propValue.AsObject = nil);
      else isNull := propValue.IsEmpty;
    end;

    for attr in rProp.GetAttributes do
    begin
      // Required
      if attr is Required then
      begin
        if isNull then
          state.AddError(rProp.Name, Required(attr).ErrorMessage);
      end
      // Range
      else if attr is Range then
      begin
        case propValue.Kind of
          tkInteger : dblValue := propValue.AsInteger;
          tkInt64   : dblValue := propValue.AsInt64;
          tkFloat   : dblValue := propValue.AsExtended;
          else dblValue := 0;
        end;
        if (dblValue < Range(attr).Min) or (dblValue > Range(attr).Max) then
          state.AddError(rProp.Name, Range(attr).ErrorMessage);
      end
      // StringLength
      else if attr is StringLength then
      begin
        strValue := propValue.AsString;
        if (Length(strValue) < StringLength(attr).MinLength) or
           (Length(strValue) > StringLength(attr).MaxLength) then
          state.AddError(rProp.Name, StringLength(attr).ErrorMessage);
      end
      // RegularExpression
      else if attr is RegularExpression then
      begin
        strValue := propValue.AsString;
        if not TRegEx.IsMatch(strValue, RegularExpression(attr).Pattern) then
          state.AddError(rProp.Name, RegularExpression(attr).ErrorMessage);
      end
      // EmailAddress
      else if attr is EmailAddress then
      begin
        strValue := propValue.AsString;
        if not TRegEx.IsMatch(strValue, EMAIL_PATTERN) then
          state.AddError(rProp.Name, EmailAddress(attr).ErrorMessage);
      end;
    end;
  end;
  Result := state;
end;

end.
