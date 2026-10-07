{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Mvc.ViewEngine.Liquid
  Description : Core Mvc ViewEngine — Liquid/Handlebars-style template engine
  Author      : Kike Perez
  Version     : 1.0
  Created     : 26/04/2026
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

unit Quick.Core.Mvc.ViewEngine.Liquid;

{$i QuickCore.inc}

interface

uses
  System.Classes,
  System.SysUtils,
  System.StrUtils,
  System.IOUtils,
  System.Generics.Collections,
  System.RTTI,
  Quick.Commons,
  Quick.Core.Mvc.Context,
  Quick.Core.Mvc.ViewFeatures;

type

  /// <summary>Custom filter function: receives the current string value
  /// and an optional argument; returns the transformed string.</summary>
  TLiquidFilterFunc = reference to function(const aValue, aArg : string) : string;

  // ────────────────────────────────────────────────────────────────────────────
  // Engine
  // ────────────────────────────────────────────────────────────────────────────

  TLiquidViewEngine = class(TViewEngine)
  public
    function FindView(aActionContext : TActionContext; const aViewName : string) : IView; override;
  end;

  // ────────────────────────────────────────────────────────────────────────────
  // View
  // ────────────────────────────────────────────────────────────────────────────

  TLiquidView = class(TView)
  private class var
    fFilters : TDictionary<string, TLiquidFilterFunc>;
  private
    fViewContext : TViewContext;
    fVars : TDictionary<string, string>;   // {% assign %} variables

    // ── rendering pipeline ──────────────────────────────────────────────
    function RenderTemplate(const aContent, aViewsDir : string) : string;

    // ── tag processors ──────────────────────────────────────────────────
    function ProcessIncludes(const aContent, aViewsDir : string) : string;
    function ProcessAssign(const aContent : string) : string;
    function ProcessIf(const aContent : string) : string;
    function ProcessFor(const aContent : string) : string;

    // ── variable / filter resolution ─────────────────────────────────────
    function ResolveVariable(const aVarExpr : string) : string;
    function ApplyFilters(const aValue, aFilters : string) : string;
    function ApplyFilter(const aValue, aFilterExpr : string) : string;

    // ── value lookup ─────────────────────────────────────────────────────
    function LookupValue(const aKey : string) : string;
    function LookupViewData(const aKey : string) : string;
    function LookupViewModel(const aKey : string) : string;

    // ── helpers ──────────────────────────────────────────────────────────
    function LoadFile(const aPath : string) : string;
    function EvalCondition(const aExpr : string) : Boolean;
  public
    class constructor Create;
    class destructor Destroy;
    /// <summary>Register a named filter, e.g. RegisterFilter('money',
    ///  func(v,a) → '$'+v).</summary>
    class procedure RegisterFilter(const aName : string; aFilter : TLiquidFilterFunc);
    procedure Render(aContext : TViewContext); override;
  end;

implementation

uses
  System.RegularExpressions,
  Quick.Value;

// ─────────────────────────────────────────────────────────────────────────────
//  Built-in filters
// ─────────────────────────────────────────────────────────────────────────────

function BuiltinUpcase(const v, _ : string) : string;    begin Result := v.ToUpper;    end;
function BuiltinDowncase(const v, _ : string) : string;  begin Result := v.ToLower;    end;
function BuiltinCapitalize(const v, _ : string) : string;
var s : string;
begin
  s := v.ToLower;
  if s <> '' then s[1] := UpCase(s[1]);
  Result := s;
end;
function BuiltinSize(const v, _ : string) : string;      begin Result := IntToStr(Length(v)); end;
function BuiltinStrip(const v, _ : string) : string;     begin Result := Trim(v);             end;
function BuiltinDefault(const v, a : string) : string;   begin if v = '' then Result := a else Result := v; end;
function BuiltinAppend(const v, a : string) : string;    begin Result := v + a;               end;
function BuiltinPrepend(const v, a : string) : string;   begin Result := a + v;               end;
function BuiltinReplace(const v, a : string) : string;
var
  parts : TArray<string>;
begin
  parts := a.Split([',']);
  if Length(parts) = 2 then
    Result := StringReplace(v, Trim(parts[0]), Trim(parts[1]), [rfReplaceAll])
  else
    Result := v;
end;
function BuiltinTruncate(const v, a : string) : string;
var
  n : Integer;
begin
  n := StrToIntDef(Trim(a), 50);
  if Length(v) > n then Result := Copy(v, 1, n) + '...'
  else Result := v;
end;
function BuiltinEscape(const v, _ : string) : string;
begin
  Result := v;
  Result := StringReplace(Result, '&',  '&amp;',  [rfReplaceAll]);
  Result := StringReplace(Result, '<',  '&lt;',   [rfReplaceAll]);
  Result := StringReplace(Result, '>',  '&gt;',   [rfReplaceAll]);
  Result := StringReplace(Result, '"',  '&quot;', [rfReplaceAll]);
end;

// ─────────────────────────────────────────────────────────────────────────────
//  TLiquidViewEngine
// ─────────────────────────────────────────────────────────────────────────────

function TLiquidViewEngine.FindView(aActionContext : TActionContext;
  const aViewName : string) : IView;
var
  viewPath : string;
begin
  viewPath := TPath.Combine(aActionContext.HttpContext.WebRoot, 'Views');
  viewPath := TPath.Combine(viewPath, aViewName + '.liquid');
  if not FileExists(viewPath) then
    aActionContext.HttpContext.RaiseHttpErrorNotFound(Self, 'Liquid view not found: ' + aViewName + '.liquid')
  else
    Result := TLiquidView.Create(viewPath);
end;

// ─────────────────────────────────────────────────────────────────────────────
//  TLiquidView
// ─────────────────────────────────────────────────────────────────────────────

class constructor TLiquidView.Create;
begin
  fFilters := TDictionary<string, TLiquidFilterFunc>.Create;
  // register built-ins
  fFilters.Add('upcase',     BuiltinUpcase);
  fFilters.Add('downcase',   BuiltinDowncase);
  fFilters.Add('capitalize', BuiltinCapitalize);
  fFilters.Add('size',       BuiltinSize);
  fFilters.Add('strip',      BuiltinStrip);
  fFilters.Add('default',    BuiltinDefault);
  fFilters.Add('append',     BuiltinAppend);
  fFilters.Add('prepend',    BuiltinPrepend);
  fFilters.Add('replace',    BuiltinReplace);
  fFilters.Add('truncate',   BuiltinTruncate);
  fFilters.Add('escape',     BuiltinEscape);
  // SEC-30: 'raw' filter bypasses auto HTML-escaping — for trusted HTML values
  fFilters.Add('raw',        function(const v, _ : string) : string begin Result := v; end);
end;

class destructor TLiquidView.Destroy;
begin
  fFilters.Free;
end;

class procedure TLiquidView.RegisterFilter(const aName : string;
  aFilter : TLiquidFilterFunc);
begin
  fFilters.AddOrSetValue(aName.ToLower, aFilter);
end;

// ─── value lookup ─────────────────────────────────────────────────────────────

function TLiquidView.LookupViewData(const aKey : string) : string;
var
  v : TFlexValue;
begin
  if fViewContext = nil then Exit('');
  // Caller already stripped 'viewdata.' prefix
  v := fViewContext.ViewData[aKey];
  Result := v.AsString;
end;

function TLiquidView.LookupViewModel(const aKey : string) : string;
var
  ctx   : TRttiContext;
  rtyp  : TRttiType;
  prop  : TRttiProperty;
  prop2 : TRttiProperty;
  val   : TValue;
begin
  Result := '';
  if (fViewContext = nil) or (fViewContext.ViewModel = nil) then Exit;
  ctx  := TRttiContext.Create;
  try
    rtyp := ctx.GetType(fViewContext.ViewModel.ClassType);
    prop := rtyp.GetProperty(aKey);
    if prop = nil then
    begin
      // case-insensitive fallback — use separate variable so prop stays nil
      // when nothing matches (the for-in loop leaves the loop var as the last
      // iterated element, not nil, when no Break is reached).
      for prop2 in rtyp.GetProperties do
        if SameText(prop2.Name, aKey) then
        begin
          prop := prop2;
          Break;
        end;
    end;
    if prop <> nil then
    begin
      val    := prop.GetValue(fViewContext.ViewModel);
      Result := val.ToString;
    end;
  finally
    ctx.Free;
  end;
end;

function TLiquidView.LookupValue(const aKey : string) : string;
var
  lower : string;
begin
  lower := aKey.ToLower;
  // 1. {% assign %} variables (highest priority)
  if fVars.TryGetValue(lower, Result) then Exit;
  // 2. Built-in variables
  if lower = 'now' then Exit(DateTimeToStr(Now));
  if lower = 'today' then Exit(DateToStr(Date));
  // 3. viewdata.xxx
  if lower.StartsWith('viewdata.') then
    Exit(LookupViewData(Copy(aKey, 10, MaxInt)));
  // 4. model properties (prefix optional)
  if lower.StartsWith('model.') then
    Exit(LookupViewModel(Copy(aKey, 7, MaxInt)));
  // 5. Try direct ViewModel property match (unprefixed)
  Result := LookupViewModel(aKey);
end;

// ─── variable / filter resolution ─────────────────────────────────────────────

function TLiquidView.ApplyFilter(const aValue, aFilterExpr : string) : string;
var
  colonPos : Integer;
  name     : string;
  arg      : string;
  fn       : TLiquidFilterFunc;
begin
  Result := aValue;
  colonPos := Pos(':', aFilterExpr);
  if colonPos > 0 then
  begin
    name := Trim(Copy(aFilterExpr, 1, colonPos - 1)).ToLower;
    arg  := Trim(Copy(aFilterExpr, colonPos + 1, MaxInt));
    // strip surrounding quotes from argument
    if (Length(arg) >= 2) and (arg[1] = '''') and (arg[Length(arg)] = '''') then
      arg := Copy(arg, 2, Length(arg) - 2)
    else if (Length(arg) >= 2) and (arg[1] = '"') and (arg[Length(arg)] = '"') then
      arg := Copy(arg, 2, Length(arg) - 2);
  end
  else
  begin
    name := Trim(aFilterExpr).ToLower;
    arg  := '';
  end;
  if fFilters.TryGetValue(name, fn) then
    Result := fn(aValue, arg);
end;

function TLiquidView.ApplyFilters(const aValue, aFilters : string) : string;
var
  parts  : TArray<string>;
  filter : string;
begin
  Result := aValue;
  if aFilters = '' then Exit;
  parts := aFilters.Split(['|']);
  for filter in parts do
    if Trim(filter) <> '' then
      Result := ApplyFilter(Result, Trim(filter));
end;

function TLiquidView.ResolveVariable(const aVarExpr : string) : string;
var
  pipePos : Integer;
  varPart : string;
  filterPart : string;
begin
  // Split on first pipe
  pipePos := Pos('|', aVarExpr);
  if pipePos > 0 then
  begin
    varPart    := Trim(Copy(aVarExpr, 1, pipePos - 1));
    filterPart := Trim(Copy(aVarExpr, pipePos + 1, MaxInt));
  end
  else
  begin
    varPart    := Trim(aVarExpr);
    filterPart := '';
  end;
  Result := LookupValue(varPart);
  if filterPart <> '' then
    Result := ApplyFilters(Result, filterPart)
  else
    // SEC-30: Auto-escape HTML in variable output to prevent XSS.
    // Developers can opt out by appending the 'raw' filter: {{ var | raw }}
    Result := BuiltinEscape(Result, '');
end;

// ─── {% assign %} ─────────────────────────────────────────────────────────────

function TLiquidView.ProcessAssign(const aContent : string) : string;
var
  regex    : TRegEx;
  matches  : TMatchCollection;
  m        : TMatch;
  varName  : string;
  varValue : string;
begin
  Result := aContent;
  regex := TRegEx.Create('\{%[-\s]*assign\s+(\w+)\s*=\s*[''"]?([^''"%}]*)[''"]?\s*[-]?%\}',
    [roIgnoreCase, roMultiLine]);
  matches := regex.Matches(Result);
  for m in matches do
  begin
    varName  := Trim(m.Groups[1].Value);
    varValue := Trim(m.Groups[2].Value);
    fVars.AddOrSetValue(varName.ToLower, varValue);
    Result := StringReplace(Result, m.Value, '', []);
  end;
end;

// ─── {% if %} ... {% endif %} ─────────────────────────────────────────────────

function TLiquidView.EvalCondition(const aExpr : string) : Boolean;
var
  expr  : string;
  parts : TArray<string>;
  lhs   : string;
  op    : string;
  rhs   : string;
  lval  : string;
  rval  : string;
begin
  expr := Trim(aExpr);

  // {% unless x %} style → negation handled before calling
  // Handle "blank" / "empty"
  if expr.StartsWith('blank ') or expr.StartsWith('empty ') then
  begin
    lval := LookupValue(Trim(Copy(expr, 7, MaxInt)));
    Exit(lval = '');
  end;

  // == != > < >= <=
  for op in ['==', '!=', '>=', '<=', '>', '<'] do
  begin
    if expr.Contains(op) then
    begin
      parts := expr.Split([op]);
      if Length(parts) >= 2 then
      begin
        lhs  := Trim(parts[0]);
        rhs  := Trim(parts[1]);
        lval := LookupValue(lhs);
        // strip quotes from rhs literal
        if (Length(rhs) >= 2) and (rhs[1] = '"') and (rhs[Length(rhs)] = '"') then
          rval := Copy(rhs, 2, Length(rhs) - 2)
        else if (Length(rhs) >= 2) and (rhs[1] = '''') and (rhs[Length(rhs)] = '''') then
          rval := Copy(rhs, 2, Length(rhs) - 2)
        else
          rval := LookupValue(rhs);
        case op[1] of
          '=': Exit(lval = rval);
          '!': Exit(lval <> rval);
          '>': if op = '>=' then Exit(StrToFloatDef(lval,0) >= StrToFloatDef(rval,0))
               else Exit(StrToFloatDef(lval,0) > StrToFloatDef(rval,0));
          '<': if op = '<=' then Exit(StrToFloatDef(lval,0) <= StrToFloatDef(rval,0))
               else Exit(StrToFloatDef(lval,0) < StrToFloatDef(rval,0));
        end;
      end;
    end;
  end;

  // Simple truthy check
  lval := LookupValue(expr);
  Result := (lval <> '') and (lval <> '0') and
            not SameText(lval, 'false') and not SameText(lval, 'nil');
end;

function TLiquidView.ProcessIf(const aContent : string) : string;
var
  regex   : TRegEx;
  m       : TMatch;
  cond    : string;
  body    : string;
  elseBody: string;
  isUnless: Boolean;
  ifResult: Boolean;
begin
  Result := aContent;
  // Iterate from innermost: find last {% if/unless %}
  regex := TRegEx.Create(
    '\{%-?\s*(if|unless)\s+(.+?)\s*-?%\}(.*?)(?:\{%-?\s*else\s*-?%\}(.*?))?\{%-?\s*end(?:if|unless)\s*-?%\}',
    [roIgnoreCase, roSingleLine]);
  m := regex.Match(Result);
  while m.Success do
  begin
    isUnless := SameText(m.Groups[1].Value, 'unless');
    cond     := Trim(m.Groups[2].Value);
    body     := m.Groups[3].Value;
    // Group 4 (else body) is inside an optional non-capturing group; when the
    // else branch is absent Delphi/PCRE may not include it in Groups — guard.
    if m.Groups.Count > 4 then
      elseBody := m.Groups[4].Value
    else
      elseBody := '';
    ifResult := EvalCondition(cond);
    if isUnless then ifResult := not ifResult;
    if ifResult then
      Result := StringReplace(Result, m.Value, body, [])
    else
      Result := StringReplace(Result, m.Value, elseBody, []);
    m := regex.Match(Result);
  end;
end;

// ─── {% for %} ... {% endfor %} ───────────────────────────────────────────────

function TLiquidView.ProcessFor(const aContent : string) : string;
var
  regex      : TRegEx;
  m          : TMatch;
  itemAlias  : string;
  collVar    : string;
  loopBody   : string;
  collVal    : string;
  items      : TArray<string>;
  item       : string;
  sb         : TStringBuilder;
  idx        : Integer;
  forzen : string;
begin
  Result := aContent;
  regex := TRegEx.Create(
    '\{%-?\s*for\s+(\w+)\s+in\s+(\S+)\s*-?%\}(.*?)\{%-?\s*endfor\s*-?%\}',
    [roIgnoreCase, roSingleLine]);
  m := regex.Match(Result);
  while m.Success do
  begin
    itemAlias := m.Groups[1].Value;
    collVar   := m.Groups[2].Value;
    loopBody  := m.Groups[3].Value;
    collVal   := LookupValue(collVar);
    // Comma-separated collection stored as "a,b,c".
    // An empty string would produce one spurious empty item — skip the whole
    // block instead.
    if collVal = '' then
    begin
      Result := StringReplace(Result, m.Value, '', []);
      m := regex.Match(Result);
      Continue;
    end;
    items := collVal.Split([',']);
    sb    := TStringBuilder.Create;
    try
      idx := 0;
      for item in items do
      begin
        forzen := loopBody;
        // resolve {{ itemAlias }} and {{ itemAlias.xxx }}
        forzen := TRegEx.Replace(forzen,
          '\{\{\s*' + TRegEx.Escape(itemAlias) + '\s*\}\}',
          Trim(item));
        forzen := TRegEx.Replace(forzen,
          '\{\{\s*forloop\.index0\s*\}\}',
          IntToStr(idx));
        forzen := TRegEx.Replace(forzen,
          '\{\{\s*forloop\.index\s*\}\}',
          IntToStr(idx + 1));
        forzen := TRegEx.Replace(forzen,
          '\{\{\s*forloop\.first\s*\}\}',
          IfThen(idx = 0, 'true', 'false'));
        forzen := TRegEx.Replace(forzen,
          '\{\{\s*forloop\.last\s*\}\}',
          IfThen(idx = Length(items) - 1, 'true', 'false'));
        sb.Append(forzen);
        Inc(idx);
      end;
      Result := StringReplace(Result, m.Value, sb.ToString, []);
    finally
      sb.Free;
    end;
    m := regex.Match(Result);
  end;
end;

// ─── {% include %} ────────────────────────────────────────────────────────────

function TLiquidView.ProcessIncludes(const aContent, aViewsDir : string) : string;
var
  regex    : TRegEx;
  m        : TMatch;
  partName : string;
  partPath : string;
  partContent : string;
begin
  Result := aContent;
  regex := TRegEx.Create(
    '\{%-?\s*include\s+[''"]([^''"]+)[''"]\s*-?%\}',
    [roIgnoreCase]);
  m := regex.Match(Result);
  while m.Success do
  begin
    partName := m.Groups[1].Value;
    // SEC-32: Prevent path traversal in include names
    if partName.Contains('..') or partName.Contains('/') or partName.Contains('\') then
    begin
      partContent := '<!-- include rejected: unsafe path -->';
      Result := StringReplace(Result, m.Value, partContent, []);
      m := regex.Match(Result);
      Continue;
    end;
    if TPath.GetExtension(partName).IsEmpty then
      partName := partName + '.liquid';
    partPath := TPath.Combine(aViewsDir, partName);
    // Verify canonical path stays within views directory
    if not TPath.GetFullPath(partPath).StartsWith(TPath.GetFullPath(aViewsDir), True) then
      partContent := '<!-- include rejected: unsafe path -->'
    else if FileExists(partPath) then
      partContent := LoadFile(partPath)
    else
      partContent := '<!-- include not found: ' + partName + ' -->';
    Result := StringReplace(Result, m.Value, partContent, []);
    m := regex.Match(Result);
  end;
end;

// ─── variable interpolation ───────────────────────────────────────────────────

function TLiquidView.RenderTemplate(const aContent, aViewsDir : string) : string;
var
  regex   : TRegEx;
  m       : TMatch;
  varExpr : string;
  value   : string;
begin
  Result := aContent;

  // 1. assign (update fVars)
  Result := ProcessAssign(Result);
  // 2. includes
  Result := ProcessIncludes(Result, aViewsDir);
  // 3. if/unless blocks
  Result := ProcessIf(Result);
  // 4. for loops
  Result := ProcessFor(Result);

  // 5. {{ variable | filters }}
  regex := TRegEx.Create('\{\{-?\s*(.+?)\s*-?\}\}', [roIgnoreCase]);
  m := regex.Match(Result);
  while m.Success do
  begin
    varExpr := Trim(m.Groups[1].Value);
    value   := ResolveVariable(varExpr);
    Result  := StringReplace(Result, m.Value, value, []);
    m       := regex.Match(Result);
  end;
end;

// ─── file loading ─────────────────────────────────────────────────────────────

function TLiquidView.LoadFile(const aPath : string) : string;
var
  sr : TStreamReader;
begin
  sr := TStreamReader.Create(aPath, TEncoding.UTF8);
  try
    Result := sr.ReadToEnd;
  finally
    sr.Free;
  end;
end;

// ─── Render entry point ───────────────────────────────────────────────────────

procedure TLiquidView.Render(aContext : TViewContext);
var
  content  : string;
  rendered : string;
  viewsDir : string;
begin
  inherited;
  fViewContext := aContext;
  fWriter      := aContext.Writer;
  fVars        := TDictionary<string, string>.Create;
  try
    viewsDir := TPath.GetDirectoryName(fPath);
    content  := LoadFile(fPath);
    rendered := RenderTemplate(content, viewsDir);
    fWriter.Write(rendered);
    fWriter.Close;
  finally
    FreeAndNil(fVars);
  end;
end;

end.
