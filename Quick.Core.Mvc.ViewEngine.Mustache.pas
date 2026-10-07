{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Mvc.ViewEngine.Mustache
  Description : Core Mvc ViewEngine Mustache
  Author      : Kike Perez
  Version     : 1.8
  Created     : 22/02/2020
  Modified    : 22/02/2020

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

unit Quick.Core.Mvc.ViewEngine.Mustache;

{$i QuickCore.inc}

interface

uses
  System.Classes,
  System.SysUtils,
  System.StrUtils,
  System.DateUtils,
  System.IOUtils,
  System.Generics.Collections,
  Quick.Commons,
  Quick.Core.Mvc.Context,
  Quick.Core.Mvc.ViewFeatures;

type

  TMustacheHelperFunc = reference to function(const aParam : string) : string;

  TMustacheViewEngine = class(TViewEngine)
  public
    function FindView(aActionContext : TActionContext; const aViewName : string) : IView; override;
  end;

  TMustacheView = class(TView)
  private class var
    fHelpers : TDictionary<string, TMustacheHelperFunc>;
  private
    function ProcessViewData(const aToken : string; aViewData : TViewDataDictionary; out vTokenRep : string) : Boolean;
    function ProcessVariable(const aToken : string; out vTokenRep : string) : Boolean;
    function ProcessHelper(const aToken : string; out vTokenRep : string) : Boolean;
    function ProcessViewModel(const aToken : string; aViewModel : TObject; out vTokenRep : string) : Boolean;
    function LoadFileContent(const aFilePath : string) : string;
    function ProcessPartials(const aContent : string; const aViewsDir : string) : string;
    function ProcessTokens(const aContent : string; aContext : TViewContext) : string;
  public
    class constructor Create;
    class destructor Destroy;
    class procedure RegisterHelper(const aName : string; aHelper : TMustacheHelperFunc);
    procedure Render(aContext : TViewContext); override;
  end;

implementation

{ TMustacheView }

class constructor TMustacheView.Create;
begin
  fHelpers := TDictionary<string, TMustacheHelperFunc>.Create;
end;

class destructor TMustacheView.Destroy;
begin
  fHelpers.Free;
end;

class procedure TMustacheView.RegisterHelper(const aName : string;
  aHelper : TMustacheHelperFunc);
begin
  fHelpers.AddOrSetValue(aName.ToLower, aHelper);
end;

{ TMustacheViewEngine }

function TMustacheViewEngine.FindView(aActionContext : TActionContext; const aViewName : string) : IView;
var
  viewPath : string;
begin
  viewPath := TPath.Combine(aActionContext.HttpContext.WebRoot, 'Views');
  viewPath := TPath.Combine(viewPath, aViewName + '.qhtml');
  if not FileExists(viewpath) then aActionContext.HttpContext.RaiseHttpErrorNotFound(Self,'View not found!')
  else
  begin
    Result := TMustacheView.Create(viewpath);
  end;
end;

{ TMustacheView }

function TMustacheView.ProcessViewData(const aToken: string; aViewData: TViewDataDictionary; out vTokenRep : string): Boolean;
begin
  if aToken.StartsWith('viewdata.') then
  begin
    vTokenRep := Copy(aToken,10,aToken.Length);
    vTokenRep := aViewData[vTokenRep];
    Result := True;
  end
  else Result := False;
end;

function TMustacheView.ProcessVariable(const aToken: string; out vTokenRep : string): Boolean;
begin
  if aToken = 'date' then vTokenRep := DateToStr(Now())
  else if aToken = 'year' then vTokenRep := YearOf(Now()).ToString
  else if aToken = 'month' then vTokenRep := MonthOf(Now()).ToString
  else if aToken = 'day' then vTokenRep := DayOf(Now()).ToString;
  Result := not vTokenRep.IsEmpty;
end;

function TMustacheView.ProcessHelper(const aToken : string; out vTokenRep : string) : Boolean;
var
  helperName : string;
  helperArg  : string;
  sepPos     : Integer;
  helper     : TMustacheHelperFunc;
begin
  Result := False;
  sepPos := Pos(' ', Trim(aToken));
  if sepPos <= 0 then
    Exit;

  helperName := Trim(Copy(aToken, 1, sepPos - 1)).ToLower;
  helperArg := Trim(Copy(aToken, sepPos + 1, MaxInt));
  if (Length(helperArg) >= 2) and (helperArg[1] = '"') and (helperArg[Length(helperArg)] = '"') then
    helperArg := Copy(helperArg, 2, Length(helperArg) - 2);

  if fHelpers.TryGetValue(helperName, helper) then
  begin
    vTokenRep := helper(helperArg);
    Result := True;
  end;
end;

function TMustacheView.ProcessViewModel(const aToken: string; aViewModel: TObject; out vTokenRep : string): Boolean;
begin
  Result := False;
  if aViewModel <> nil then
  begin

  end
end;

function TMustacheView.LoadFileContent(const aFilePath : string) : string;
var
  sr : TStreamReader;
begin
  sr := TStreamReader.Create(aFilePath, TEncoding.UTF8);
  try
    Result := sr.ReadToEnd;
  finally
    sr.Free;
  end;
end;

function TMustacheView.ProcessPartials(const aContent : string; const aViewsDir : string) : string;
var
  startPos : Integer;
  endPos   : Integer;
  tag      : string;
  partName : string;
  partPath : string;
  partContent : string;
begin
  Result := aContent;
  // Process {{> partialname}} or {{> "filename.qhtml"}}
  // Layout tags ({{> layout "..."}}) are handled separately in Render, skip them here
  startPos := Pos('{{>', Result);
  while startPos > 0 do
  begin
    endPos := PosEx('}}', Result, startPos);
    if endPos = 0 then Break;
    // extract inner content: e.g. " partialname" or "> layout "file""
    tag := Trim(Copy(Result, startPos + 3, endPos - startPos - 3));
    // skip layout directives
    if tag.ToLower.StartsWith('layout') then
    begin
      startPos := PosEx('{{>', Result, endPos + 2);
      Continue;
    end;
    // strip surrounding quotes if present
    partName := tag;
    if (Length(partName) >= 2) and (partName[1] = '"') and (partName[Length(partName)] = '"') then
      partName := Copy(partName, 2, Length(partName) - 2);
    // resolve path: if no extension, append .qhtml; relative to views dir
    if TPath.GetExtension(partName).IsEmpty then
      partName := partName + '.qhtml';
    if TPath.IsRelativePath(partName) then
      partPath := TPath.Combine(aViewsDir, partName)
    else
      partPath := partName;
    if FileExists(partPath) then
    begin
      partContent := LoadFileContent(partPath);
      // recursively process nested partials
      partContent := ProcessPartials(partContent, aViewsDir);
    end
    else
      partContent := '<!-- partial not found: ' + partName + ' -->';
    // replace the tag
    Result := Copy(Result, 1, startPos - 1) + partContent + Copy(Result, endPos + 2, MaxInt);
    startPos := Pos('{{>', Result);
  end;
end;

function TMustacheView.ProcessTokens(const aContent : string; aContext : TViewContext) : string;
var
  lines    : TStringList;
  i        : Integer;
  line     : string;
  token    : string;
  rawToken : string;
  tokrep   : string;
  found    : Boolean;
begin
  lines := TStringList.Create;
  try
    lines.Text := aContent;
    for i := 0 to lines.Count - 1 do
    begin
      line := lines[i];
      found := line.Contains('{{');
      while found do
      begin
        rawToken := GetSubString(line, '{{', '}}');
        token := rawToken.ToLower;
        tokrep := '';
        if not ProcessHelper(rawToken, tokrep) then
        if not ProcessViewData(token, aContext.ViewData, tokrep) then
        if not ProcessVariable(token, tokrep) then
        if not ProcessViewModel(token, aContext.ViewModel, tokrep) then tokrep := '%error%';
        line := StringReplace(line, '{{' + rawToken + '}}', tokrep, [rfIgnoreCase, rfReplaceAll]);
        // also handle triple-mustache {{{body}}} — already processed as {{body}} above,
        // but explicitly handle {{{...}}} for unescaped output (no-op here, same replacement)
        found := line.Contains('{{');
      end;
      lines[i] := line;
    end;
    Result := lines.Text;
    // trim trailing newline added by TStringList
    if Result.EndsWith(sLineBreak) then
      Result := Copy(Result, 1, Length(Result) - Length(sLineBreak));
  finally
    lines.Free;
  end;
end;

procedure TMustacheView.Render(aContext : TViewContext);
var
  content      : string;
  layoutName   : string;
  layoutPath   : string;
  layoutContent: string;
  viewsDir     : string;
  tagStart     : Integer;
  tagEnd       : Integer;
  tagFull      : string;
  tagInner     : string;
  rendered     : string;
begin
  inherited;
  fWriter := aContext.Writer;
  viewsDir := TPath.GetDirectoryName(fPath);

  // load view content
  content := LoadFileContent(fPath);

  // --- V-01: detect layout directive {{> layout "filename"}} ---
  layoutName := '';
  tagStart := Pos('{{>', content);
  while tagStart > 0 do
  begin
    tagEnd := PosEx('}}', content, tagStart);
    if tagEnd = 0 then Break;
    tagInner := Trim(Copy(content, tagStart + 3, tagEnd - tagStart - 3));
    if tagInner.ToLower.StartsWith('layout') then
    begin
      tagFull := Copy(content, tagStart, tagEnd - tagStart + 2);
      // extract layout name from: layout "name" or layout name
      layoutName := Trim(Copy(tagInner, 7, Length(tagInner) - 6));
      if (Length(layoutName) >= 2) and (layoutName[1] = '"') and (layoutName[Length(layoutName)] = '"') then
        layoutName := Copy(layoutName, 2, Length(layoutName) - 2);
      // remove layout directive from view content
      content := StringReplace(content, tagFull, '', []);
      Break;
    end;
    tagStart := PosEx('{{>', content, tagEnd + 2);
  end;

  // --- V-02: process partials in view ---
  content := ProcessPartials(content, viewsDir);

  // process tokens in view
  rendered := ProcessTokens(content, aContext);

  // --- V-01: apply layout if specified ---
  if not layoutName.IsEmpty then
  begin
    if TPath.GetExtension(layoutName).IsEmpty then
      layoutName := layoutName + '.qhtml';
    if TPath.IsRelativePath(layoutName) then
      layoutPath := TPath.Combine(viewsDir, layoutName)
    else
      layoutPath := layoutName;
    if FileExists(layoutPath) then
    begin
      layoutContent := LoadFileContent(layoutPath);
      // process partials in layout
      layoutContent := ProcessPartials(layoutContent, viewsDir);
      // inject rendered view into {{{body}}} placeholder
      layoutContent := StringReplace(layoutContent, '{{{body}}}', rendered, [rfIgnoreCase]);
      // also accept {{body}} (escaped variant)
      layoutContent := StringReplace(layoutContent, '{{body}}', rendered, [rfIgnoreCase]);
      // process remaining tokens in layout
      rendered := ProcessTokens(layoutContent, aContext);
    end;
  end;

  fWriter.Write(rendered);
  fWriter.Close;
end;


end.
