{ ***************************************************************************

  Copyright (c) 2016-2019 Kike Pérez

  Unit        : Quick.Core.Mvc.Middleware.StaticFile
  Description : Core Mvc StaticFiles Middleware
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 17/10/2019
  Modified    : 17/10/2019

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

unit Quick.Core.Mvc.Middleware.StaticFiles;

{$i QuickCore.inc}

interface

uses
  Classes,
  System.SysUtils,
  System.Generics.Collections,
  Quick.HttpServer.Types,
  Quick.HttpServer.Request,
  Quick.Core.Mvc.Middleware,
  Quick.Core.Mvc.Context,
  Quick.Core.Mvc.Routing,
  Quick.HttpServer.Response;

type
  TStaticFilesMiddleware = class(TRequestDelegate)
  private
    function CanHandleExtension(const aFilename : string) : Boolean;
  public
    destructor Destroy; override;
    procedure Invoke(aContext : THttpContextBase); override;
  end;

implementation

{ TStaticFilesMiddleware }

function TStaticFilesMiddleware.CanHandleExtension(const aFilename: string): Boolean;
begin
  //check extensionless
  Result := not ExtractFileExt(aFilename).IsEmpty;
end;

destructor TStaticFilesMiddleware.Destroy;
begin

  inherited;
end;

procedure TStaticFilesMiddleware.Invoke(aContext: THttpContextBase);
var
  filename : string;
begin
  inherited;
  //check file exists
  filename := aContext.WebRoot + aContext.Request.URL;
  if CanHandleExtension(filename) then
  begin
    if FileExists(filename) then
    begin
      aContext.Response.Content := TFileStream.Create(filename,fmShareDenyWrite);
      aContext.Response.ContentType := MIMETypes.GetFileMIMEType(filename);
      aContext.Response.StatusCode := 200;
      Exit;
    end
    else
    begin
      aContext.RaiseHttpErrorNotFound(Self,Format('The resource "%s" you requested was not found',[filename]));
      //aContext.Response.StatusCode := 404;
      //aContext.Response.StatusText := 'Not found';
      //aContext.Response.ContentText := 'The resource you requested was not found';
    end;
  end
  else Next(aContext);
end;

end.
