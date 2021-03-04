{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Mvc.ActionInvoker
  Description : Core Http Mvc Routing
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 12/10/2019
  Modified    : 16/04/2020

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
  Quick.Value,
  Quick.Arrays,
  Quick.HttpServer.Types,
  Quick.Core.Mvc.Context,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Mvc.ViewFeatures;

type
  TActionInvoker = class
  public
    class procedure Invoke(aController : TController; aContext: TRequestContext);
  end;

  EControllerMethodNotFound = class(Exception);
  EActionInvokerAlreadyFreeParam = class(Exception);

implementation

{ TActionInvoker }

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
  actionContext : TActionContext;

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
    for attr in rparam.GetAttributes do
    begin
      if attr.ClassName = 'FromBody' then isFromBody := True;
    end;
    //get value from url param or from body
    if isFromBody then
    begin
      {$IFDEF DEBUG_CONTROLLER}
      TDebugger.Trace(nil,'TActionInvoker.Invoke Body content: %s',[aContext.HttpContext.Request.ContentAsString]);
      {$ENDIF}
      flexvalue := aContext.HttpContext.Request.ContentAsString;
    end
    else flexvalue := aContext.RouteData.ParamValues.GetValue(rparam.Name);

    if flexvalue.IsNullOrEmpty then
    begin
      value := nil;
      if rparam.ParamType.TypeKind = tkInterface then value := aContext.HttpContext.RequestServices.GetService(rParam.ParamType.Handle)
        else if rparam.ParamType.TypeKind = tkClass then value := aContext.HttpContext.RequestServices.GetService(rParam.ParamType.Handle);
    end
    else
    begin
      case rparam.ParamType.TypeKind of
        tkInteger : value := flexvalue.AsInteger;
        tkInt64 : value := flexvalue.AsInt64;
        tkFloat : value := flexvalue.AsExtended;
        tkClass : value := aContext.HttpContext.RequestServices.Serializer.Json.ToObject(rParam.ParamType.Handle.TypeData.ClassType,flexvalue.AsString);
        //tkRecord : value := aContext.HttpContext.RequestServices.Serializer.Json.ToValue(flexvalue.AsString);
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
