{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Mvc.ViewEngine.Mustache
  Description : Core Mvc ViewEngine Mustache
  Author      : Kike Pérez
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
  System.DateUtils,
  System.IOUtils,
  Quick.Commons,
  Quick.Core.Mvc.Context,
  Quick.Core.Mvc.ViewFeatures;

type

  TMustacheViewEngine = class(TViewEngine)
  public
    function FindView(aActionContext : TActionContext; const aViewName : string) : IView; override;
  end;

  TMustacheView = class(TView)
  private
    function ProcessViewData(const aToken : string; aViewData : TViewDataDictionary; out vTokenRep : string) : Boolean;
    function ProcessVariable(const aToken : string; out vTokenRep : string) : Boolean;
    function ProcessViewModel(const aToken : string; aViewModel : TObject; out vTokenRep : string) : Boolean;
  public
    procedure Render(aContext : TViewContext); override;
  end;

implementation

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

function TMustacheView.ProcessViewModel(const aToken: string; aViewModel: TObject; out vTokenRep : string): Boolean;
begin
  Result := False;
  if aViewModel <> nil then
  begin

  end
end;

procedure TMustacheView.Render(aContext : TViewContext);
var
  line : string;
  token : string;
  tokrep : string;
  found : Boolean;
begin
  inherited;
  fReader.GetTemplate(fPath);
  fWriter := aContext.Writer;
  while not fReader.EoF do
  begin
    line := fReader.ReadLine;
    found := line.Contains('{{');
    while found do
    begin
      token := GetSubString(line,'{{','}}').ToLower;
      //try process token as viewdata
      if not ProcessViewData(token,aContext.ViewData,tokrep) then
      //try process token as variable
      if not ProcessVariable(token,tokrep) then
      //try process token as viewmodel
      if not ProcessViewModel(token,aContext.ViewModel,tokrep) then tokrep := '%error%';
      //replace token
      line := StringReplace(line,'{{'+token+'}}',tokrep,[rfIgnoreCase,rfReplaceAll]);
      found := line.Contains('{{');
    end;
    fWriter.WriteLine(line);
  end;
  fWriter.Close;
end;


end.
