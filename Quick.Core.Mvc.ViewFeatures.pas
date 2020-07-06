{ ***************************************************************************

  Copyright (c) 2016-2019 Kike Pérez

  Unit        : Quick.Core.Mvc.ViewFeatures
  Description : Core Mvc ViewFeatures
  Author      : Kike Pérez
  Version     : 1.8
  Created     : 29/10/2019
  Modified    : 03/12/2019

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

unit Quick.Core.Mvc.ViewFeatures;

{$i QuickCore.inc}

interface

uses
  System.Classes,
  System.SysUtils,
  System.IoUtils,
  System.Generics.Collections,
  Quick.Value,
  Quick.Core.Mvc.Routing,
  Quick.Core.Mvc.Context;

type

  TViewDataDictionary = class
  private
    fDictionary : TDictionary<string,TFlexValue>;
    function GetItem(const Key: string): TFlexValue;
    procedure SetItem(const Key: string; const Value: TFlexValue);
  public
    constructor Create;
    destructor Destroy; override;
    property Items[const Key: string]: TFlexValue read GetItem write SetItem; default;
  end;

  TActionContext = class
  private
    fHttpContext : THttpContextBase;
    fRouteData : TRouteData;
  public
    constructor Create(aHttpContext : THttpContextBase; aRouteData : TRouteData);
    property HttpContext : THttpContextBase read fHttpContext write fHttpContext;
    property RouteData : TRouteData read fRouteData write fRouteData;
  end;

  TViewContext = class(TActionContext)
  private
    fViewData : TViewDataDictionary;
    fViewModel : TObject;
    fExecutingFilePath : string;
    fWriter : TStreamWriter;
  public
    constructor Create(aContext : TActionContext; aViewData : TViewDataDictionary; aViewModel : TObject; aStream : TStream);
    destructor Destroy; override;
    property ViewData : TViewDataDictionary read fViewData write fViewData;
    property ViewModel : TObject read fViewModel write fViewModel;
    property ExecutingFilePath : string read fExecutingFilePath write fExecutingFilePath;
    property Writer : TStreamWriter read fWriter write fWriter;
  end;

  IView = interface
  ['{3EC6F22F-7AB0-4509-95B3-36EEA1002280}']
    procedure Render(aContext : TViewContext);
  end;

  IViewEngine = interface
  ['{BBA8080C-833A-4475-82DC-6A3A0A692281}']
    function FindView(aContext : TActionContext; const aViewName : string) : IView;
  end;

  ITemplateReader = interface
  ['{C4A020BB-F8AF-4384-8C15-352598D783FF}']
    procedure GetTemplate(const aTemplatePath : string);
    function EoF : Boolean;
    function ReadLine : string;
  end;

  TStreamTemplateReader = class(TInterfacedObject,ITemplateReader)
  private
    fReader : TStreamReader;
  public
    destructor Destroy; override;
    procedure GetTemplate(const aTemplatePath : string);
    function EoF : Boolean;
    function ReadLine : string;
  end;

  TView = class(TInterfacedObject,IView)
  protected
    fPath : string;
    fReader : ITemplateReader;
    fWriter : TStreamWriter;
  public
    constructor Create(const aViewPath : string);
    property Path : string read fPath write fPath;
    procedure Render(aContext : TViewContext); virtual;
  end;

  TViewEngine = class(TInterfacedObject,IViewEngine)
  public
    function FindView(aContext : TActionContext; const aViewName : string) : IView; virtual; abstract;
  end;

implementation

{ TViewDataDictionary }

constructor TViewDataDictionary.Create;
begin
  fDictionary := TDictionary<string,TFlexValue>.Create;
end;

destructor TViewDataDictionary.Destroy;
begin
  fDictionary.Free;
  inherited;
end;

function TViewDataDictionary.GetItem(const Key: string): TFlexValue;
begin
  fDictionary.TryGetValue(Key,Result);
end;

procedure TViewDataDictionary.SetItem(const Key: string; const Value: TFlexValue);
begin
  fDictionary.AddOrSetValue(Key,Value);
end;


{ TViewContext }

constructor TViewContext.Create(aContext : TActionContext; aViewData : TViewDataDictionary; aViewModel : TObject; aStream : TStream);
begin
  fHttpContext := aContext.HttpContext;
  fRouteData := aContext.RouteData;
  fViewData := aViewData;
  fViewModel := aViewModel;
  fWriter := TStreamWriter.Create(aStream);
end;

destructor TViewContext.Destroy;
begin
  fWriter.Free;
  inherited;
end;

{ TActionContext }

constructor TActionContext.Create(aHttpContext: THttpContextBase; aRouteData: TRouteData);
begin
  fHttpContext := aHttpContext;
  fRouteData := aRouteData;
end;

{ TView }

constructor TView.Create(const aViewPath: string);
begin
  fPath := aViewPath;
  fReader := TStreamTemplateReader.Create;
end;

procedure TView.Render(aContext: TViewContext);
begin
  aContext.ExecutingFilePath := fPath;
end;

{ TStreamTemplateReader }

destructor TStreamTemplateReader.Destroy;
begin
  if Assigned(fReader) then fReader.Free;
  inherited;
end;

function TStreamTemplateReader.EoF: Boolean;
begin
  Result := fReader.EndOfStream;
end;

procedure TStreamTemplateReader.GetTemplate(const aTemplatePath: string);
begin
  fReader := TStreamReader.Create(aTemplatePath);
end;

function TStreamTemplateReader.ReadLine: string;
begin
  Result := fReader.ReadLine;
end;

end.
