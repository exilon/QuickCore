{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Mvc.ActionInvoker
  Description : Core Http Mvc Routing
  Author      : Kike Perez
  Version     : 1.0
  Created     : 12/10/2019
  Modified    : 10/11/2019

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

unit Quick.Core.Mvc.ActionInvoker;

{$i QuickCore.inc}

interface

uses
  {$IFDEF DEBUG_CONTROLLER}
  Quick.Debug.Utils,
  {$ENDIF}
  System.SysUtils,
  RTTI,
  System.TypInfo,
  Quick.Value,
  Quick.Arrays,
  Quick.HttpServer.Types,
  Quick.HttpServer.Request,
  Quick.HttpServer,
  Quick.Core.Mvc.Context,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Mvc.ViewFeatures;

type
  TActionInvoker = class
  public
    class procedure Invoke(aController : TController; aContext: TRequestContext);
    class function ParseFormField(aRequest : IHttpRequest; const aFieldName : string) : TFlexValue;
    class function ParseUploadedFile(aRequest : IHttpRequest; const aFieldName : string) : TUploadedFile;
  end;

  EControllerMethodNotFound = class(Exception);
  EActionInvokerAlreadyFreeParam = class(Exception);

implementation

uses
  System.NetEncoding,
  System.Variants,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ModelValidation;

{ TActionInvoker }

class function TActionInvoker.ParseFormField(aRequest : IHttpRequest;
  const aFieldName : string) : TFlexValue;
var
  contentType : string;
  body        : string;
  parts       : TArray<string>;
  pair        : string;
  key         : string;
  value       : string;
  p           : Integer;
  boundary    : string;
  block       : string;
  blocks      : TArray<string>;
  headerEnd   : Integer;
  headersText : string;
  namePos     : Integer;
  contentText : string;
begin
  Result := Null;
  contentType := aRequest.Headers.GetValue('Content-Type');
  body := aRequest.ContentAsString;

  if contentType.Contains('application/x-www-form-urlencoded') then
  begin
    parts := body.Split(['&']);
    for pair in parts do
    begin
      p := pair.IndexOf('=');
      if p > -1 then
      begin
        key := TNetEncoding.URL.Decode(pair.Substring(0, p));
        value := TNetEncoding.URL.Decode(pair.Substring(p + 1));
        if SameText(key, aFieldName) then
          Exit(value);
      end;
    end;
    Exit;
  end;

  if not contentType.Contains('multipart/form-data') then
    Exit;

  p := contentType.IndexOf('boundary=');
  if p < 0 then
    Exit;
  boundary := '--' + contentType.Substring(p + 9).Trim([' ', '"']);
  blocks := body.Split([boundary]);
  for block in blocks do
  begin
    if block.Trim.IsEmpty or (block.Trim = '--') then
      Continue;
    headerEnd := block.IndexOf(#13#10#13#10);
    if headerEnd < 0 then
      Continue;
    headersText := block.Substring(0, headerEnd);
    namePos := LowerCase(headersText).IndexOf(LowerCase('name="' + aFieldName + '"'), 0);
    if namePos < 0 then
      Continue;
    if headersText.Contains('filename="') then
      Continue;
    contentText := block.Substring(headerEnd + 4).Trim;
    if contentText.EndsWith('--') then
      contentText := contentText.Substring(0, contentText.Length - 2).Trim;
    Exit(contentText);
  end;
end;

class function TActionInvoker.ParseUploadedFile(aRequest : IHttpRequest;
  const aFieldName : string) : TUploadedFile;
var
  contentType : string;
  body        : string;
  p           : Integer;
  boundary    : string;
  blocks      : TArray<string>;
  block       : string;
  headerEnd   : Integer;
  headersText : string;
  contentText : string;
  namePos     : Integer;
  filePos     : Integer;
  typePos     : Integer;
  lineEnd     : Integer;
begin
  Result := nil;
  contentType := aRequest.Headers.GetValue('Content-Type');
  if not contentType.Contains('multipart/form-data') then
    Exit;

  p := contentType.IndexOf('boundary=');
  if p < 0 then
    Exit;

  boundary := '--' + contentType.Substring(p + 9).Trim([' ', '"']);
  body := aRequest.ContentAsString;
  blocks := body.Split([boundary]);
  for block in blocks do
  begin
    if block.Trim.IsEmpty or (block.Trim = '--') then
      Continue;
    headerEnd := block.IndexOf(#13#10#13#10);
    if headerEnd < 0 then
      Continue;
    headersText := block.Substring(0, headerEnd);
    namePos := LowerCase(headersText).IndexOf(LowerCase('name="' + aFieldName + '"'), 0);
    if namePos < 0 then
      Continue;

    filePos := LowerCase(headersText).IndexOf('filename="', 0);
    if filePos < 0 then
      Continue;

    Result := TUploadedFile.Create;
    Result.FieldName := aFieldName;

    Inc(filePos, 10);
    p := filePos;
    while (p <= headersText.Length) and (headersText[p] <> '"') do
      Inc(p);
    Result.FileName := headersText.Substring(filePos - 1, p - filePos);

    typePos := LowerCase(headersText).IndexOf('content-type:', 0);
    if typePos >= 0 then
    begin
      lineEnd := headersText.IndexOf(#13#10, typePos);
      if lineEnd < 0 then
        lineEnd := headersText.Length + 1;
      Result.ContentType := Trim(headersText.Substring(typePos + 13, lineEnd - typePos - 13));
    end;

    contentText := block.Substring(headerEnd + 4);
    contentText := contentText.Trim;
    if contentText.EndsWith('--') then
      contentText := contentText.Substring(0, contentText.Length - 2).Trim;
    Result.Data := TEncoding.UTF8.GetBytes(contentText);
    Exit;
  end;
end;

class procedure TActionInvoker.Invoke(aController : TController; aContext: TRequestContext);
var
  ctx : TRttiContext;
  rmethod : TRttiMethod;
  rparam : TRttiParameter;
  flexvalue : TFlexValue;
  value : TValue;
  values : TArray<TValue>;
  attr : TCustomAttribute;
  isFromBody : Boolean;
  isFromQuery : Boolean;
  isFromHeader : Boolean;
  isFromForm : Boolean;
  isFromKeyedServices : Boolean;
  fromQueryName : string;
  fromHeaderName : string;
  fromFormName : string;
  fromKeyedServicesKey : string;
  actionContext : TActionContext;
  modelState : TModelState;

begin
  //execute controller action method
  {$IFDEF DEBUG_CONTROLLER}
  TDebugger.TimeIt(nil,'TActionInvoker.Invoke',Format('URL: %s',[aContext.HttpContext.Request.URL]));
  {$ENDIF}
  rmethod := ctx.GetType(aContext.HttpContext.Route.ControllerClass).GetMethod(aContext.HttpContext.Route.ActionMethodName);
  if rmethod = nil then raise EControllerMethodNotFound.CreateFmt('Controller Method not found [%s] %s',[aContext.HttpContext.Route.ControllerName,aContext.HttpContext.Route.ActionMethodName]);
  //set param values ordered and typecasted to insert into action method
  for rparam in rmethod.GetParameters do
  begin
    //check param attributes
    flexvalue.Clear;
    isFromBody := False;
    isFromQuery := False;
    isFromHeader := False;
    isFromForm := False;
    isFromKeyedServices := False;
    fromQueryName := '';
    fromHeaderName := '';
    fromFormName := '';
    fromKeyedServicesKey := '';
    for attr in rparam.GetAttributes do
    begin
      if attr is FromBody then isFromBody := True
      else if attr is FromForm then
      begin
        isFromForm := True;
        fromFormName := FromForm(attr).Name;
        if fromFormName = '' then fromFormName := rparam.Name;
      end
      else if attr is FromQuery then
      begin
        isFromQuery := True;
        fromQueryName := FromQuery(attr).Name;
        if fromQueryName = '' then fromQueryName := rparam.Name;
      end
      else if attr is FromHeader then
      begin
        isFromHeader := True;
        fromHeaderName := FromHeader(attr).Name;
        if fromHeaderName = '' then fromHeaderName := rparam.Name;
      end
      else if attr is FromKeyedServices then
      begin
        isFromKeyedServices := True;
        fromKeyedServicesKey := FromKeyedServices(attr).Key;
      end;
    end;
    //get value from url param, query string, header, form, or from body
    if isFromBody then
    begin
      {$IFDEF DEBUG_CONTROLLER}
      TDebugger.Trace(nil,'TActionInvoker.Invoke Body content: %s',[aContext.HttpContext.Request.ContentAsString]);
      {$ENDIF}
      flexvalue := aContext.HttpContext.Request.ContentAsString;
    end
    else if isFromForm then
    begin
      // Populated below via specialised TUploadedFile path (tkClass branch)
      flexvalue := fromFormName;
    end
    else if isFromQuery then
      flexvalue := aContext.HttpContext.Request.Query[fromQueryName]
    else if isFromHeader then
      flexvalue := aContext.HttpContext.Request.Headers.GetValue(fromHeaderName)
    else if not isFromKeyedServices then
      flexvalue := aContext.RouteData.ParamValues.GetValue(rparam.Name);

    if flexvalue.IsNullOrEmpty then
    begin
      value := nil;
      if isFromKeyedServices then
      begin
        // Resolve a named service from DI
        value := aContext.HttpContext.RequestServices.GetService(
          rParam.ParamType.Handle, fromKeyedServicesKey);
      end
      else if rparam.ParamType.TypeKind = tkInterface then value := aContext.HttpContext.RequestServices.GetService(rParam.ParamType.Handle)
        else if rparam.ParamType.TypeKind = tkClass then value := aContext.HttpContext.RequestServices.GetService(rParam.ParamType.Handle);
    end
    else
    begin
      case rparam.ParamType.TypeKind of
        tkInteger : value := flexvalue.AsInteger;
        tkInt64 : value := flexvalue.AsInt64;
        tkFloat : value := flexvalue.AsExtended;
        tkClass :
          begin
            // [FromForm] — populate TUploadedFile or extract form field value
            if isFromForm then
            begin
              if rParam.ParamType.Handle.TypeData.ClassType = TUploadedFile then
                value := TActionInvoker.ParseUploadedFile(
                  aContext.HttpContext.Request, fromFormName)
              else
              begin
                // Plain form field → extract text value from body
                flexvalue := TActionInvoker.ParseFormField(
                  aContext.HttpContext.Request, fromFormName);
                value := aContext.HttpContext.RequestServices.Serializer.Json.ToObject(
                  rParam.ParamType.Handle.TypeData.ClassType, flexvalue.AsString);
              end;
            end
            // [FromBody] with empty/null JSON — treat as nil rather than crash
            else if isFromBody and (Trim(flexvalue.AsString) = '') then
              value := nil
            else
            begin
              value := aContext.HttpContext.RequestServices.Serializer.Json.ToObject(
                rParam.ParamType.Handle.TypeData.ClassType, flexvalue.AsString);
              // Auto model-state validation for [FromBody] class params
              if isFromBody and (not value.IsEmpty) and value.IsObjectInstance then
              begin
                modelState := TModelValidator.Validate(value.AsObject);
                if not modelState.IsValid then
                begin
                  aContext.HttpContext.Response.StatusCode := 400;
                  aContext.HttpContext.Response.ContentType := 'application/json';
                  aContext.HttpContext.Response.ContentText := modelState.ToJsonString;
                  modelState.Free;
                  Exit;
                end;
                modelState.Free;
              end;
            end;
          end;
        tkDynArray :
          begin
            // Deserialise JSON array to TValue (handles TArray<T> params)
            if Trim(flexvalue.AsString) = '' then
              value := TValue.Empty
            else
              value := aContext.HttpContext.RequestServices.Serializer.Json.ToValue(flexvalue.AsString);
          end;
        tkEnumeration : TValue.Make(GetEnumValue(rparam.ParamType.Handle,flexvalue.AsString),rparam.ParamType.Handle, value);
        else value := flexvalue.AsString;
      end;
    end;
    {$IFDEF DEBUG_CONTROLLER}
    TDebugger.Trace(nil,'Param: %s',[flexvalue.AsString]);
    {$ENDIF}
    values := values + [value];
  end;
  //param injection
  value := rmethod.Invoke(aController,values);
  try
    //if response is IActionResult execute ExecuteResult
    if value.AsInterface is TActionResult  then
    begin
      actionContext := TActionContext.Create(aContext.HttpContext,aContext.RouteData);
      try
        IActionResult(value.AsInterface).ExecuteResult(actionContext);
      finally
        actionContext.Free;
      end;
    end;
  finally
    //free controller result
    if value.IsObjectInstance then value.AsObject.Free;
    //free params injected into controller
    for value in values do
    begin
      if (not value.IsEmpty) and (value.IsObjectInstance) then
      begin
        try
          value.AsObject.Free;
        except
          {$IFDEF DEBUG_CONTROLLER}
          TDebugger.Trace(nil,'TActionInvoker.Invoke: Controller param objects auto free on exit, don''t free it before!');
          {$ENDIF}
          {$IFDEF DEBUG}
            raise EActionInvokerAlreadyFreeParam.Create('TActionInvoker.Invoke: Controller param objects auto free on exit, don''t free it before!');
          {$ENDIF}
        end;
      end;
    end;
  end;
end;

end.
