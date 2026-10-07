{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Mvc.Middleware.Swagger
  Description : Core Mvc Swagger / OpenAPI 3.0 Middleware
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

unit Quick.Core.Mvc.Middleware.Swagger;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.TypInfo,
  System.Rtti,
  System.JSON,
  Quick.Commons,
  Quick.HttpServer.Types,
  Quick.Core.Mvc.Middleware,
  Quick.Core.Mvc.Context,
  Quick.Core.Mvc.Controller;

type

  TSwaggerInfo = class
  private
    fTitle       : string;
    fVersion     : string;
    fDescription : string;
  public
    constructor Create(const aTitle       : string = 'API';
                       const aVersion     : string = '1.0.0';
                       const aDescription : string = '');
    property Title       : string read fTitle       write fTitle;
    property Version     : string read fVersion     write fVersion;
    property Description : string read fDescription write fDescription;
  end;

  { Apply to a published controller method to enrich the Swagger output. }
  SwaggerOperation = class(TCustomAttribute)
  private
    fSummary     : string;
    fDescription : string;
    fTags        : string;
  public
    constructor Create(const aSummary     : string;
                       const aDescription : string = '';
                       const aTags        : string = '');
    property Summary     : string read fSummary;
    property Description : string read fDescription;
    property Tags        : string read fTags;
  end;

  { Declares a possible response status code for an action. }
  ProducesResponseType = class(TCustomAttribute)
  private
    fStatusCode  : Integer;
    fDescription : string;
  public
    constructor Create(aStatusCode : Integer; const aDescription : string = '');
    property StatusCode  : Integer read fStatusCode;
    property Description : string  read fDescription;
  end;

  { -----------------------------------------------------------------------
    TSwaggerGenerator — builds an OpenAPI 3.0 document from RTTI metadata.
    ----------------------------------------------------------------------- }
  TSwaggerGenerator = class
  private
    fControllers : TList<THttpControllerClass>;
    fInfo        : TSwaggerInfo;
    fSchemas     : TJSONObject;
    procedure EnsureObjectSchema(aType : TRttiType);
    function  NormalizePathTemplate(const aUrl : string) : string;
    function  DelphiTypeToOAS(aType : TRttiType) : TJSONObject;
    function  BuildParameter(aParam : TRttiParameter;
                              const aIn        : string;
                              const aParamName : string) : TJSONObject;
    function  GetControllerTag(aClass : THttpControllerClass) : string;
    function  GetMethodVerb(aMethod : TRttiMethod;
                             out aRoute : string) : TMethodVerbs;
    function  BuildOperation(aMethod          : TRttiMethod;
                              const aFullPath  : string;
                              aControllerClass : THttpControllerClass) : TJSONObject;
  public
    constructor Create(aControllers : TList<THttpControllerClass>;
                       aInfo        : TSwaggerInfo);
    destructor Destroy; override;
    { Returns an OpenAPI 3.0 JSON string. }
    function Generate : string;
  end;

  { -----------------------------------------------------------------------
    TSwaggerMiddleware — serves the Swagger UI and the OpenAPI JSON document.

    Routes served (URL prefix, case-insensitive):
      GET /swagger/v1/swagger.json  → OpenAPI 3.0 JSON
      GET /swagger[/index.html]     → Swagger UI HTML
    ----------------------------------------------------------------------- }
  TSwaggerMiddleware = class(TRequestDelegate)
  private
    fGenerator  : TSwaggerGenerator;
    fCachedJson : string;
    fSwaggerUrl : string;
    fJsonUrl    : string;
    fEnabled    : Boolean;  // SEC-31: disable in production
    function GenerateSwaggerJson : string;
    function GenerateSwaggerUI   : string;
  public
    constructor Create(aNext              : TRequestDelegate;
                       aControllers       : TList<THttpControllerClass>;
                       aInfo              : TSwaggerInfo   = nil;
                       const aSwaggerUrlPrefix : string    = 'swagger';
                       const aJsonPath         : string    = 'swagger/v1/swagger.json';
                       aEnabled                : Boolean   = True);
    destructor Destroy; override;
    procedure Invoke(aContext : THttpContextBase); override;
    property Enabled : Boolean read fEnabled write fEnabled;
  end;

implementation

{ TSwaggerInfo }

constructor TSwaggerInfo.Create(const aTitle, aVersion, aDescription : string);
begin
  fTitle       := aTitle;
  fVersion     := aVersion;
  fDescription := aDescription;
end;

{ SwaggerOperation }

constructor SwaggerOperation.Create(const aSummary, aDescription, aTags : string);
begin
  fSummary     := aSummary;
  fDescription := aDescription;
  fTags        := aTags;
end;

{ ProducesResponseType }

constructor ProducesResponseType.Create(aStatusCode : Integer;
                                         const aDescription : string);
begin
  fStatusCode  := aStatusCode;
  fDescription := aDescription;
end;

{ TSwaggerGenerator }

constructor TSwaggerGenerator.Create(aControllers : TList<THttpControllerClass>;
                                      aInfo        : TSwaggerInfo);
begin
  fControllers := aControllers;
  fInfo        := aInfo;
  fSchemas     := TJSONObject.Create;
end;

destructor TSwaggerGenerator.Destroy;
begin
  fSchemas.Free;
  inherited;
end;

procedure TSwaggerGenerator.EnsureObjectSchema(aType : TRttiType);
var
  rprop      : TRttiProperty;
  props      : TJSONObject;
  required   : TJSONArray;
  propSchema : TJSONObject;
  typeName   : string;
  schemaObj  : TJSONObject;
begin
  if aType = nil then Exit;
  if fSchemas.GetValue(aType.Name) <> nil then Exit;

  // Reserve a placeholder to prevent infinite recursion on circular refs
  fSchemas.AddPair(aType.Name, TJSONNull.Create);

  props    := TJSONObject.Create;
  required := TJSONArray.Create;

  for rprop in aType.GetProperties do
  begin
    if rprop.Visibility <> mvPublished then Continue;
    propSchema := nil;
    case rprop.PropertyType.TypeKind of
      tkInteger, tkInt64 :
        begin
          propSchema := TJSONObject.Create;
          propSchema.AddPair('type', 'integer');
        end;
      tkFloat :
        begin
          propSchema := TJSONObject.Create;
          typeName := rprop.PropertyType.Name.ToLower;
          if (typeName = 'tdatetime') or (typeName = 'tdate') then
          begin
            propSchema.AddPair('type', 'string');
            propSchema.AddPair('format', 'date-time');
          end
          else
            propSchema.AddPair('type', 'number');
        end;
      tkEnumeration :
        begin
          propSchema := TJSONObject.Create;
          if rprop.PropertyType.Name = 'Boolean' then
            propSchema.AddPair('type', 'boolean')
          else
            propSchema.AddPair('type', 'string');
        end;
      tkClass :
        begin
          propSchema := TJSONObject.Create;
          propSchema.AddPair('$ref',
            '#/components/schemas/' + rprop.PropertyType.Name);
          EnsureObjectSchema(rprop.PropertyType);
        end;
      tkDynArray :
        begin
          propSchema := TJSONObject.Create;
          propSchema.AddPair('type', 'array');
          propSchema.AddPair('items', TJSONObject.Create);
        end;
    else
      propSchema := TJSONObject.Create;
      propSchema.AddPair('type', 'string');
    end;

    if propSchema <> nil then
      props.AddPair(rprop.Name, propSchema);
  end;

  schemaObj := TJSONObject.Create;
  schemaObj.AddPair('type', 'object');
  schemaObj.AddPair('properties', props);
  if required.Count > 0 then
    schemaObj.AddPair('required', required)
  else
    required.Free;

  // Replace the null placeholder
  fSchemas.RemovePair(aType.Name).Free;
  fSchemas.AddPair(aType.Name, schemaObj);
end;

function TSwaggerGenerator.NormalizePathTemplate(const aUrl : string) : string;
var
  segments  : TArray<string>;
  i         : Integer;
  seg       : string;
  paramName : string;
  colonPos  : Integer;
begin
  if aUrl = '' then
  begin
    Result := '/';
    Exit;
  end;
  segments := aUrl.Split(['/']);
  for i := 0 to High(segments) do
  begin
    seg := segments[i];
    if seg.StartsWith('{') and seg.EndsWith('}') then
    begin
      colonPos := seg.IndexOf(':');
      if colonPos > 0 then
        paramName := seg.Substring(1, colonPos - 1)
      else
        paramName := seg.Substring(1, seg.Length - 2);
      paramName := paramName.Replace('?', '').Trim;
      if paramName <> '' then
        segments[i] := '{' + paramName + '}'
      else
        segments[i] := seg;
    end;
  end;
  Result := '/' + string.Join('/', segments);
  while Result.Contains('//') do
    Result := Result.Replace('//', '/');
end;

function TSwaggerGenerator.DelphiTypeToOAS(aType : TRttiType) : TJSONObject;
var
  typeName : string;
begin
  Result := TJSONObject.Create;
  if aType = nil then
  begin
    Result.AddPair('type', 'string');
    Exit;
  end;
  case aType.TypeKind of
    tkInteger, tkInt64  : Result.AddPair('type', 'integer');
    tkFloat :
      begin
        typeName := aType.Name.ToLower;
        if (typeName = 'tdatetime') or (typeName = 'tdate') then
        begin
          Result.AddPair('type', 'string');
          Result.AddPair('format', 'date-time');
        end
        else
          Result.AddPair('type', 'number');
      end;
    tkEnumeration :
      if aType.Name = 'Boolean' then
        Result.AddPair('type', 'boolean')
      else
        Result.AddPair('type', 'string');
    tkClass :
      begin
        Result.Free;
        Result := TJSONObject.Create;
        Result.AddPair('$ref', '#/components/schemas/' + aType.Name);
        EnsureObjectSchema(aType);
      end;
    tkDynArray :
      begin
        Result.AddPair('type', 'array');
        Result.AddPair('items', TJSONObject.Create);
      end;
  else
    Result.AddPair('type', 'string');
  end;
end;

function TSwaggerGenerator.BuildParameter(aParam : TRttiParameter;
                                           const aIn        : string;
                                           const aParamName : string) : TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name',     aParamName);
  Result.AddPair('in',       aIn);
  Result.AddPair('required', TJSONBool.Create(aIn = 'path'));
  Result.AddPair('schema',   DelphiTypeToOAS(aParam.ParamType));
end;

function TSwaggerGenerator.GetControllerTag(aClass : THttpControllerClass) : string;
var
  cname : string;
begin
  cname := aClass.ClassName.ToLower;
  if cname.StartsWith('t') then cname := cname.Substring(1);
  if cname.EndsWith('controller') then
    cname := cname.Substring(0, cname.Length - Length('controller'));
  Result := cname;
end;

function TSwaggerGenerator.GetMethodVerb(aMethod : TRttiMethod;
                                          out aRoute : string) : TMethodVerbs;
var
  attr : TCustomAttribute;
begin
  Result := [];
  aRoute := '';
  for attr in aMethod.GetAttributes do
  begin
    if attr is HttpGet then
    begin
      Result := [mGET, mHEAD];
      aRoute := TMethodVerbAttribute(attr).Route;
    end
    else if attr is HttpPost then
    begin
      Result := [mPOST];
      aRoute := TMethodVerbAttribute(attr).Route;
    end
    else if attr is HttpPut then
    begin
      Result := [mPUT];
      aRoute := TMethodVerbAttribute(attr).Route;
    end
    else if attr is HttpDelete then
    begin
      Result := [mDELETE];
      aRoute := TMethodVerbAttribute(attr).Route;
    end
    else if attr is AcceptVerbs then
      Result := AcceptVerbs(attr).Verbs;
  end;
end;

function TSwaggerGenerator.BuildOperation(aMethod          : TRttiMethod;
                                           const aFullPath  : string;
                                           aControllerClass : THttpControllerClass) : TJSONObject;
var
  attr          : TCustomAttribute;
  cAttr         : TCustomAttribute;
  summary       : string;
  description   : string;
  tagsStr       : string;
  params        : TJSONArray;
  requestBody   : TJSONObject;
  responses     : TJSONObject;
  hasCustomResp : Boolean;
  rparam        : TRttiParameter;
  isFromBody    : Boolean;
  isFromQuery   : Boolean;
  isFromHeader  : Boolean;
  fromName      : string;
  routeHasParam : Boolean;
  tagsArr       : TJSONArray;
  bodyContent   : TJSONObject;
  jsonContent   : TJSONObject;
  verbRoute     : string;
  normalizedPath: string;
  dummyVerbs    : TMethodVerbs;
  respObj       : TJSONObject;
  descText      : string;
  r200          : TJSONObject;
  hasAllowAnonymous : Boolean;
  hasAuthorize      : Boolean;
  securityArr       : TJSONArray;
  securityReq       : TJSONObject;
  scopesArr         : TJSONArray;
  ctx               : TRttiContext;
  controllerType    : TRttiType;

  function GetRouteParamName(const aPath, aParamName: string): string;
  var
    segments : TArray<string>;
    seg      : string;
    token    : string;
    colonPos : Integer;
  begin
    Result := aParamName;
    segments := aPath.Split(['/']);
    for seg in segments do
    begin
      if seg.StartsWith('{') and seg.EndsWith('}') then
      begin
        token := seg.Substring(1, seg.Length - 2).Trim;
        colonPos := token.IndexOf(':');
        if colonPos >= 0 then
          token := token.Substring(0, colonPos);
        token := token.Replace('?', '').Trim;
        if SameText(token, aParamName) then
          Exit(token);
      end;
    end;
  end;
begin
  Result        := TJSONObject.Create;
  summary       := aMethod.Name;
  description   := '';
  tagsStr       := GetControllerTag(aControllerClass);
  hasCustomResp := False;
  requestBody   := nil;
  normalizedPath:= NormalizePathTemplate(aFullPath);
  hasAllowAnonymous := False;
  hasAuthorize := False;

  for attr in aMethod.GetAttributes do
  begin
    if attr is SwaggerOperation then
    begin
      summary     := SwaggerOperation(attr).Summary;
      description := SwaggerOperation(attr).Description;
      if SwaggerOperation(attr).Tags <> '' then
        tagsStr := SwaggerOperation(attr).Tags;
    end
    else if attr is AllowAnonymous then
      hasAllowAnonymous := True
    else if (attr is Authorize) or (attr is AuthorizePolicy) then
      hasAuthorize := True;
  end;

  if not hasAllowAnonymous then
  begin
    controllerType := ctx.GetType(aControllerClass);
    if controllerType <> nil then
    begin
      for cAttr in controllerType.GetAttributes do
      begin
        if cAttr is AllowAnonymous then
        begin
          hasAllowAnonymous := True;
          Break;
        end;
        if (cAttr is Authorize) or (cAttr is AuthorizePolicy) then
          hasAuthorize := True;
      end;
    end;
  end;

  Result.AddPair('summary', summary);
  if description <> '' then
    Result.AddPair('description', description);

  tagsArr := TJSONArray.Create;
  tagsArr.Add(tagsStr);
  Result.AddPair('tags', tagsArr);

  // Parameters
  params := TJSONArray.Create;
  dummyVerbs := GetMethodVerb(aMethod, verbRoute);

  for rparam in aMethod.GetParameters do
  begin
    isFromBody   := False;
    isFromQuery  := False;
    isFromHeader := False;
    fromName     := rparam.Name;

    for attr in rparam.GetAttributes do
    begin
      if      attr is FromBody   then isFromBody  := True
      else if attr is FromQuery  then
      begin
        isFromQuery := True;
        if FromQuery(attr).Name <> '' then fromName := FromQuery(attr).Name;
      end
      else if attr is FromHeader then
      begin
        isFromHeader := True;
        if FromHeader(attr).Name <> '' then fromName := FromHeader(attr).Name;
      end;
    end;

    routeHasParam :=
      normalizedPath.Contains('{' + rparam.Name.ToLower + '}') or
      normalizedPath.Contains('{' + rparam.Name + '}');

    if isFromBody then
    begin
      bodyContent := TJSONObject.Create;
      jsonContent := TJSONObject.Create;
      jsonContent.AddPair('schema', DelphiTypeToOAS(rparam.ParamType));
      bodyContent.AddPair('application/json', jsonContent);
      requestBody := TJSONObject.Create;
      requestBody.AddPair('required', TJSONBool.Create(True));
      requestBody.AddPair('content', bodyContent);
    end
    else if isFromHeader then
      params.AddElement(BuildParameter(rparam, 'header', fromName))
    else if isFromQuery then
      params.AddElement(BuildParameter(rparam, 'query', fromName))
    else if routeHasParam then
      params.AddElement(BuildParameter(rparam, 'path', GetRouteParamName(aFullPath, rparam.Name)))
    else
      params.AddElement(BuildParameter(rparam, 'query', rparam.Name));
  end;

  Result.AddPair('parameters', params);
  if requestBody <> nil then
    Result.AddPair('requestBody', requestBody);

  // Responses
  responses := TJSONObject.Create;
  for attr in aMethod.GetAttributes do
    if attr is ProducesResponseType then
    begin
      respObj  := TJSONObject.Create;
      descText := ProducesResponseType(attr).Description;
      if descText = '' then descText := 'Success';
      respObj.AddPair('description', descText);
      responses.AddPair(IntToStr(ProducesResponseType(attr).StatusCode), respObj);
      hasCustomResp := True;
    end;

  if not hasCustomResp then
  begin
    r200 := TJSONObject.Create;
    r200.AddPair('description', 'Success');
    responses.AddPair('200', r200);
  end;

  Result.AddPair('responses', responses);

  if (not hasAllowAnonymous) and hasAuthorize then
  begin
    scopesArr := TJSONArray.Create;
    securityReq := TJSONObject.Create;
    securityReq.AddPair('ApiKeyAuth', scopesArr);
    securityArr := TJSONArray.Create;
    securityArr.AddElement(securityReq);
    Result.AddPair('security', securityArr);
  end;

  Result.AddPair('operationId',
    aControllerClass.ClassName + '_' + aMethod.Name);
end;

function TSwaggerGenerator.Generate : string;
var
  root         : TJSONObject;
  infoObj      : TJSONObject;
  pathsObj     : TJSONObject;
  components   : TJSONObject;
  schemasCopy  : TJSONObject;
  securitySchemes : TJSONObject;
  apiKeyScheme : TJSONObject;
  ctx          : TRttiContext;
  rtype        : TRttiType;
  rmethod      : TRttiMethod;
  attr         : TCustomAttribute;
  cc           : THttpControllerClass;
  globalRoute  : string;
  verbRoute    : string;
  verbs        : TMethodVerbs;
  fullPath     : string;
  pathItem     : TJSONObject;
  existingV    : TJSONValue;
  verbStr      : string;
  verb         : TMethodVerb;
  operation    : TJSONObject;
  hasNonAction : Boolean;
  i            : Integer;
begin
  root := TJSONObject.Create;
  try
    root.AddPair('openapi', '3.0.0');

    infoObj := TJSONObject.Create;
    infoObj.AddPair('title',   fInfo.Title);
    infoObj.AddPair('version', fInfo.Version);
    if fInfo.Description <> '' then
      infoObj.AddPair('description', fInfo.Description);
    root.AddPair('info', infoObj);

    pathsObj := TJSONObject.Create;

    for cc in fControllers do
    begin
      globalRoute := '';
      rtype := ctx.GetType(cc);
      if rtype = nil then Continue;

      for attr in rtype.GetAttributes do
        if attr is Route then
        begin
          globalRoute := Route(attr).URL;
          globalRoute := globalRoute
            .Replace('[controller]', GetControllerTag(cc), [rfIgnoreCase])
            .Replace('[Controller]', GetControllerTag(cc), [rfIgnoreCase]);
        end;

      for rmethod in rtype.GetMethods do
      begin
        if rmethod.Visibility <> mvPublished then Continue;

        hasNonAction := False;
        for attr in rmethod.GetAttributes do
          if attr is NonAction then hasNonAction := True;
        if hasNonAction then Continue;

        verbs := GetMethodVerb(rmethod, verbRoute);
        if verbs = [] then Continue;

        if verbRoute <> '' then
        begin
          if globalRoute <> '' then
            fullPath := globalRoute + '/' + verbRoute
          else
            fullPath := verbRoute;
        end
        else
          fullPath := globalRoute;

        if fullPath = '' then
          fullPath := GetControllerTag(cc) + '/' + rmethod.Name;

        fullPath := NormalizePathTemplate(fullPath);

        existingV := pathsObj.GetValue(fullPath);
        if (existingV <> nil) and (existingV is TJSONObject) then
          pathItem := TJSONObject(existingV)
        else
        begin
          pathItem := TJSONObject.Create;
          pathsObj.AddPair(fullPath, pathItem);
        end;

        for verb in [mGET, mPOST, mPUT, mDELETE, mPATCH] do
        begin
          if not (verb in verbs) then Continue;
          case verb of
            mGET    : verbStr := 'get';
            mPOST   : verbStr := 'post';
            mPUT    : verbStr := 'put';
            mDELETE : verbStr := 'delete';
            mPATCH  : verbStr := 'patch';
          else
            Continue;
          end;
          if pathItem.GetValue(verbStr) <> nil then Continue;
          operation := BuildOperation(rmethod, fullPath, cc);
          pathItem.AddPair(verbStr, operation);
        end;
      end;
    end;

    root.AddPair('paths', pathsObj);

    // Deep-copy component schemas
    schemasCopy := TJSONObject.Create;
    for i := 0 to fSchemas.Count - 1 do
      schemasCopy.AddPair(
        fSchemas.Pairs[i].JsonString.Value,
        fSchemas.Pairs[i].JsonValue.Clone as TJSONValue);

    securitySchemes := TJSONObject.Create;
    apiKeyScheme := TJSONObject.Create;
    apiKeyScheme.AddPair('type', 'apiKey');
    apiKeyScheme.AddPair('name', 'X-Api-Key');
    apiKeyScheme.AddPair('in', 'header');
    securitySchemes.AddPair('ApiKeyAuth', apiKeyScheme);

    components := TJSONObject.Create;
    components.AddPair('schemas', schemasCopy);
    components.AddPair('securitySchemes', securitySchemes);
    root.AddPair('components', components);

    Result := root.Format;
  finally
    root.Free;
  end;
end;

{ TSwaggerMiddleware }

constructor TSwaggerMiddleware.Create(aNext              : TRequestDelegate;
                                       aControllers       : TList<THttpControllerClass>;
                                       aInfo              : TSwaggerInfo;
                                       const aSwaggerUrlPrefix : string;
                                       const aJsonPath         : string;
                                       aEnabled                : Boolean);
var
  info : TSwaggerInfo;
begin
  inherited Create(aNext);
  if aInfo <> nil then
    info := aInfo
  else
    info := TSwaggerInfo.Create;
  fGenerator  := TSwaggerGenerator.Create(aControllers, info);
  fCachedJson := '';
  fSwaggerUrl := aSwaggerUrlPrefix.ToLower;
  fJsonUrl    := aJsonPath.ToLower;
  fEnabled    := aEnabled;
end;

destructor TSwaggerMiddleware.Destroy;
begin
  fGenerator.Free;
  inherited;
end;

function TSwaggerMiddleware.GenerateSwaggerJson : string;
begin
  if fCachedJson = '' then
    fCachedJson := fGenerator.Generate;
  Result := fCachedJson;
end;

function TSwaggerMiddleware.GenerateSwaggerUI : string;
var
  jsonUrl : string;
begin
  jsonUrl := '/' + fJsonUrl;
  Result :=
    '<!DOCTYPE html>' + sLineBreak +
    '<html>' + sLineBreak +
    '<head>' + sLineBreak +
    '  <title>Swagger UI</title>' + sLineBreak +
    '  <meta charset="utf-8"/>' + sLineBreak +
    '  <meta name="viewport" content="width=device-width, initial-scale=1">' + sLineBreak +
    '  <link rel="stylesheet" type="text/css"' + sLineBreak +
    '    href="https://unpkg.com/swagger-ui-dist/swagger-ui.css">' + sLineBreak +
    '</head>' + sLineBreak +
    '<body>' + sLineBreak +
    '<div id="swagger-ui"></div>' + sLineBreak +
    '<script src="https://unpkg.com/swagger-ui-dist/swagger-ui-bundle.js"></script>' + sLineBreak +
    '<script src="https://unpkg.com/swagger-ui-dist/swagger-ui-standalone-preset.js"></script>' + sLineBreak +
    '<script>' + sLineBreak +
    'window.onload = function() {' + sLineBreak +
    '  SwaggerUIBundle({' + sLineBreak +
    '    url: "' + jsonUrl + '",' + sLineBreak +
    '    dom_id: "#swagger-ui",' + sLineBreak +
    '    deepLinking: true,' + sLineBreak +
    '    presets: [SwaggerUIBundle.presets.apis, SwaggerUIStandalonePreset],' + sLineBreak +
    '    layout: "StandaloneLayout"' + sLineBreak +
    '  });' + sLineBreak +
    '};' + sLineBreak +
    '</script>' + sLineBreak +
    '</body>' + sLineBreak +
    '</html>';
end;

procedure TSwaggerMiddleware.Invoke(aContext : THttpContextBase);
var
  requestUrl : string;
begin
  inherited;
  // SEC-31: When Enabled=False, skip Swagger entirely (for production environments)
  if not fEnabled then
  begin
    Next(aContext);
    Exit;
  end;
  requestUrl := aContext.Request.URL.ToLower.Trim;
  if requestUrl.StartsWith('/') then
    requestUrl := requestUrl.Substring(1);

  if requestUrl = fJsonUrl then
  begin
    aContext.Response.StatusCode  := 200;
    aContext.Response.ContentType := 'application/json';
    aContext.Response.ContentText := GenerateSwaggerJson;
    Exit;
  end;

  if (requestUrl = fSwaggerUrl) or
     (requestUrl = fSwaggerUrl + '/') or
     (requestUrl = fSwaggerUrl + '/index.html') then
  begin
    aContext.Response.StatusCode  := 200;
    aContext.Response.ContentType := 'text/html; charset=utf-8';
    aContext.Response.ContentText := GenerateSwaggerUI;
    Exit;
  end;

  Next(aContext);
end;

end.
