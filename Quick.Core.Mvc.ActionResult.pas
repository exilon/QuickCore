{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Mvc.ActionResult
  Description : Core Mvc ActionResult
  Author      : Kike Perez
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

  /// <summary>Bind a controller parameter from multipart/form-data or
  ///  application/x-www-form-urlencoded. Use with TUploadedFile for file parts.</summary>
  FromForm = class(TCustomAttribute)
  private
    fName : string;
  public
    constructor Create(const aName : string = '');
    property Name : string read fName;
  end;

  /// <summary>A file part received via multipart/form-data. Populated automatically
  ///  when a parameter is annotated with [FromForm] and its type is TUploadedFile.</summary>
  TUploadedFile = class
  private
    fFieldName   : string;
    fFileName    : string;
    fContentType : string;
    fData        : TBytes;
  public
    property FieldName   : string read fFieldName   write fFieldName;
    property FileName    : string read fFileName    write fFileName;
    property ContentType : string read fContentType write fContentType;
    property Data        : TBytes read fData        write fData;
    function Size : Int64;
    function AsString(aEncoding : TEncoding = nil) : string;
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
    constructor Create(aObject: TObject; aOnlyPublishedProperties : Boolean = False); overload;
    constructor Create(const aJsonText : string); overload;
    destructor Destroy; override;
    property JsonText : string read fJsonText write fJsonText;
    /// <summary>Respects the Accept header: returns JSON or minimal XML.</summary>
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

  /// <summary>RFC 7807 Problem Details response.
  ///  Content-Type: application/problem+json
  ///  Body: { "type": "...", "title": "...", "status": NNN,
  ///           "detail": "...", "instance": "..." }
  /// </summary>
  TProblemDetailsResult = class(TActionResult)
  private
    fStatus   : Integer;
    fTitle    : string;
    fDetail   : string;
    fType     : string;
    fInstance : string;
    fExtra    : string;  // optional extra JSON fields (raw, no outer braces)
  public
    constructor Create(aStatus : Integer; const aTitle : string;
      const aDetail : string = ''; const aType : string = '';
      const aInstance : string = ''); overload;
    property Status   : Integer read fStatus   write fStatus;
    property Title    : string  read fTitle    write fTitle;
    property Detail   : string  read fDetail   write fDetail;
    property &Type    : string  read fType     write fType;
    property Instance : string  read fInstance write fInstance;
    /// <summary>Append extra raw JSON properties (no braces) to the response body.</summary>
    property Extra    : string  read fExtra    write fExtra;
    procedure ExecuteResult(aContext : TActionContext); override;
  end;

implementation


{ FromForm }

constructor FromForm.Create(const aName : string);
begin
  fName := aName;
end;

{ TUploadedFile }

function TUploadedFile.Size : Int64;
begin
  Result := Length(fData);
end;

function TUploadedFile.AsString(aEncoding : TEncoding) : string;
var
  enc : TEncoding;
begin
  if aEncoding = nil then enc := TEncoding.UTF8
  else enc := aEncoding;
  Result := enc.GetString(fData);
end;

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
  if fViewEngine = nil then raise Exception.Create('Not MVC Engine defined');

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

constructor TJsonResult.Create(const aJsonText: string);
begin
  fJsonText := aJsonText;
end;

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
var
  acceptHeader : string;
  xmlBody      : string;
  sb           : TStringBuilder;
  i            : Integer;
  ch           : Char;
  inStr        : Boolean;
  key          : string;
  value        : string;
  depth        : Integer;
  // Minimal JSON→XML helper (flat/scalar properties only)
  procedure AppendXmlEscaped(b : TStringBuilder; const s : string);
  var j : Integer;
  begin
    for j := 1 to Length(s) do
      case s[j] of
        '<' : b.Append('&lt;');
        '>' : b.Append('&gt;');
        '&' : b.Append('&amp;');
        '"' : b.Append('&quot;');
        else  b.Append(s[j]);
      end;
  end;
begin
  acceptHeader := aContext.HttpContext.Request.Headers.GetValue('Accept');
  if acceptHeader.Contains('application/xml') or
     acceptHeader.Contains('text/xml') then
  begin
    // Produce a minimal XML representation from the JSON text
    sb := TStringBuilder.Create;
    try
      sb.Append('<?xml version="1.0" encoding="utf-8"?><response>');
      // Simple single-pass flat JSON→XML (top-level scalars only)
      i := 1; inStr := False; depth := 0; key := ''; value := '';
      while i <= Length(fJsonText) do
      begin
        ch := fJsonText[i];
        case ch of
          '"' :
            begin
              inStr := not inStr;
              if inStr and (depth = 1) and (key = '') then
              begin
                Inc(i);
                while (i <= Length(fJsonText)) and not
                  ((fJsonText[i] = '"') and (fJsonText[i-1] <> '\')) do
                begin
                  key := key + fJsonText[i];
                  Inc(i);
                end;
              end
              else if inStr and (depth = 1) and (key <> '') then
              begin
                Inc(i);
                while (i <= Length(fJsonText)) and not
                  ((fJsonText[i] = '"') and (fJsonText[i-1] <> '\')) do
                begin
                  value := value + fJsonText[i];
                  Inc(i);
                end;
                sb.Append('<'); sb.Append(key); sb.Append('>');
                AppendXmlEscaped(sb, value);
                sb.Append('</'); sb.Append(key); sb.Append('>');
                key := ''; value := '';
              end;
            end;
          '{', '[' : if not inStr then Inc(depth);
          '}', ']' : if not inStr then Dec(depth);
          ':' :
            if (not inStr) and (depth = 1) and (key <> '') then
            begin
              Inc(i);
              while (i <= Length(fJsonText)) and (fJsonText[i] = ' ') do Inc(i);
              if (i <= Length(fJsonText)) and (fJsonText[i] <> '"') and
                 (fJsonText[i] <> '{') and (fJsonText[i] <> '[') then
              begin
                value := '';
                while (i <= Length(fJsonText)) and
                  not CharInSet(fJsonText[i], [',','}',']',#10,#13]) do
                begin
                  value := value + fJsonText[i];
                  Inc(i);
                end;
                value := Trim(value);
                if (value <> '') and (value <> 'null') then
                begin
                  sb.Append('<'); sb.Append(key); sb.Append('>');
                  AppendXmlEscaped(sb, value);
                  sb.Append('</'); sb.Append(key); sb.Append('>');
                end;
                key := ''; value := '';
                Continue;
              end;
            end;
        end;
        Inc(i);
      end;
      sb.Append('</response>');
      xmlBody := sb.ToString;
    finally
      sb.Free;
    end;
    aContext.HttpContext.Response.ContentText := xmlBody;
    aContext.HttpContext.Response.ContentType := 'application/xml';
  end
  else
  begin
    aContext.HttpContext.Response.ContentText := fJsonText;
    aContext.HttpContext.Response.ContentType := 'application/json';
  end;
end;

{ TProblemDetailsResult }

constructor TProblemDetailsResult.Create(aStatus : Integer; const aTitle : string;
  const aDetail, aType, aInstance : string);
begin
  fStatus   := aStatus;
  fTitle    := aTitle;
  fDetail   := aDetail;
  fType     := aType;
  fInstance := aInstance;
end;

procedure TProblemDetailsResult.ExecuteResult(aContext : TActionContext);
var
  sb : TStringBuilder;
  typeUri : string;
begin
  typeUri := fType;
  if typeUri.IsEmpty then
    typeUri := 'https://tools.ietf.org/html/rfc7807';

  sb := TStringBuilder.Create;
  try
    sb.Append('{');
    sb.AppendFormat('"type":"%s"', [typeUri]);
    sb.AppendFormat(',"title":"%s"', [StringReplace(fTitle,'"','\"',[rfReplaceAll])]);
    sb.AppendFormat(',"status":%d', [fStatus]);
    if not fDetail.IsEmpty then
      sb.AppendFormat(',"detail":"%s"', [StringReplace(fDetail,'"','\"',[rfReplaceAll])]);
    if not fInstance.IsEmpty then
      sb.AppendFormat(',"instance":"%s"', [fInstance]);
    if not fExtra.IsEmpty then
    begin
      sb.Append(',');
      sb.Append(fExtra);
    end;
    sb.Append('}');

    aContext.HttpContext.Response.StatusCode  := fStatus;
    aContext.HttpContext.Response.ContentType := 'application/problem+json';
    aContext.HttpContext.Response.ContentText := sb.ToString;
  finally
    sb.Free;
  end;
end;

end.
