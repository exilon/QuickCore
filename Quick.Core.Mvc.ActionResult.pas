{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Mvc.ActionResult
  Description : Core Mvc ActionResult
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 11/10/2019
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

unit Quick.Core.Mvc.ActionResult;

{$i QuickCore.inc}

interface

uses
  System.Classes,
  System.SysUtils,
  Quick.Arrays,
  Quick.Json.Serializer,
  Quick.Core.Mvc.Context,
  Quick.HttpServer.Types,
  Quick.HttpServer.Response,
  Quick.Core.Mvc.ViewFeatures;

type
  IActionResult = interface
  ['{CF13DC00-D3F0-4B27-9D76-EC1AE863A440}']
    procedure ExecuteResult(aContext : TActionContext);
  end;

  TActionResult = class(TInterfacedObject,IActionResult)
  public
    procedure ExecuteResult(aContext : TActionContext); virtual; abstract;
  end;

  TStatusResult = class(TActionResult)
  private
    fStatusCode : Integer;
    fStatusText : string;
  public
    constructor Create(aStatusCode : Integer; const aStatusText : string = '');
    property StatusCode : Integer read fStatusCode write fStatusCode;
    property StatusText : string read fStatusText write fStatusText;
    procedure ExecuteResult(aContext : TActionContext); override;
  end;

  TRedirectResult = class(TActionResult)
  private
    fStatusCode : Integer;
    fURL : string;
  public
    constructor Create(aStatusCode : Integer; const aURL : string);
    property StatusCode : Integer read fStatusCode write fStatusCode;
    property URL : string read fURL write fURL;
    procedure ExecuteResult(aContext : TActionContext); override;
  end;

  TContentResult = class(TActionResult)
  private
    fContent : string;
    fContentType : string;
  public
    constructor Create(const aContentText : string); overload;
    constructor Create(const aContentText, aContentType : string); overload;
    property Content : string read fContent write fContent;
    property ContentType : string read fContentType write fContentType;
    procedure ExecuteResult(aContext : TActionContext); override;
  end;

  TJsonResult = class(TActionResult)
  private
    fJsonText : string;
    fJsonSerializer : TJsonSerializer;
  public
    constructor Create(aObject: TObject; aOnlyPublishedProperties : Boolean = False);
    destructor Destroy; override;
    property JsonText : string read fJsonText write fJsonText;
    procedure ExecuteResult(aContext : TActionContext); override;
  end;

  TViewResult = class(TActionResult)
  private
    fViewName : string;
    fViewData : TViewDataDictionary;
    fViewEngine : IViewEngine;
    fContentType : string;
  public
    constructor Create(const aViewName : string);
    property ViewName : string read fViewName write fViewName;
    property ViewData : TViewDataDictionary read fViewData write fViewData;
    property ViewEngine : IViewEngine read fViewEngine write fViewEngine;
    property ContentType : string read fContentType write fContentType;
    procedure ExecuteResult(aContext : TActionContext); override;
  end;

implementation


{ TStatusResult }

constructor TStatusResult.Create(aStatusCode: Integer; const aStatusText: string);
begin
  fStatusCode := aStatusCode;
  fStatusText := aStatusText;
end;

procedure TStatusResult.ExecuteResult(aContext: TActionContext);
begin
  aContext.HttpContext.Response.StatusCode := fStatusCode;
  aContext.HttpContext.Response.StatusText := fStatusText;
  if fStatusCode > 399 then raise EControlledException.Create(Self,fStatusText);
end;

{ TRedirectResult }

constructor TRedirectResult.Create(aStatusCode : Integer; const aURL : string);
begin
  fStatusCode := aStatusCode;
  fURL := aURL;
end;

procedure TRedirectResult.ExecuteResult(aContext: TActionContext);
begin
  aContext.HttpContext.Response.Headers.AddOrUpdate('Location',fURL);
end;

{ TContentResult }

constructor TContentResult.Create(const aContentText: string);
begin
  fContent := aContentText;
end;

constructor TContentResult.Create(const aContentText, aContentType: string);
begin
  fContent := aContentText;
  fContentType := aContentType;
end;

procedure TContentResult.ExecuteResult(aContext: TActionContext);
begin
  aContext.HttpContext.Response.ContentText := fContent;
  aContext.HttpContext.Response.ContentType := fContentType;
end;

{ TViewResult }

constructor TViewResult.Create(const aViewName: string);
begin
  if aViewName = '' then fViewName := 'Home'
    else fViewName := aViewName;
end;

procedure TViewResult.ExecuteResult(aContext: TActionContext);
var
  viewContext : TViewContext;
  view : IView;
  streamPage : TMemoryStream;
begin
  view := fViewEngine.FindView(aContext,fViewName);
  streamPage := TStringStream.Create;
  viewContext := TViewContext.Create(aContext,fViewData,nil,streampage);
  try
    view.Render(viewContext);
  finally
    viewContext.Free;
  end;
  aContext.HttpContext.Response.Content := streampage;
  aContext.HttpContext.Response.ContentType := 'text/html';
  aContext.HttpContext.Response.StatusCode := 200;
end;

{ TJsonResult }

constructor TJsonResult.Create(aObject: TObject; aOnlyPublishedProperties : Boolean = False);
var
  serializerlevel : TSerializeLevel;
begin
  if aOnlyPublishedProperties then serializerlevel := TSerializeLevel.slPublishedProperty
    else serializerlevel := TSerializeLevel.slPublicProperty;
  fJsonSerializer := TJsonSerializer.Create(serializerlevel,True);
  fJsonText := fJsonSerializer.ObjectToJson(aObject,False);
end;

destructor TJsonResult.Destroy;
begin
  fJsonSerializer.Free;
  inherited;
end;

procedure TJsonResult.ExecuteResult(aContext: TActionContext);
begin
  aContext.HttpContext.Response.ContentText := fJsonText;
  aContext.HttpContext.Response.ContentType := 'application/json';
end;

end.
