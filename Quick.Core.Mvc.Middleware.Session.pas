{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Mvc.Middleware.Session
  Description : Core Mvc Session Middleware
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

unit Quick.Core.Mvc.Middleware.Session;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Core.Mvc.Middleware,
  Quick.Core.Mvc.Context,
  Quick.Core.Mvc.Session;

const
  DEFAULT_SESSION_COOKIE_NAME = '.QuickCore.Session';
  DEFAULT_SESSION_IDLE_TIMEOUT_SECS = 1200; // 20 minutes

type

  TSessionMiddleware = class(TRequestDelegate)
  private
    fStore           : ISessionStore;
    fCookieName      : string;
    fIdleTimeoutSecs : Integer;
    function  GetSessionIdFromCookie(aContext : THttpContextBase) : string;
    procedure SetSessionCookie(aContext : THttpContextBase; const aSessionId : string);
    function  GenerateSessionId : string;
  public
    constructor Create(aNext : TRequestDelegate; aStore : ISessionStore;
                       const aCookieName : string = DEFAULT_SESSION_COOKIE_NAME;
                       aIdleTimeoutSecs : Integer = DEFAULT_SESSION_IDLE_TIMEOUT_SECS);
    procedure Invoke(aContext : THttpContextBase); override;
  end;

implementation

{ TSessionMiddleware }

constructor TSessionMiddleware.Create(aNext : TRequestDelegate; aStore : ISessionStore;
                                      const aCookieName : string;
                                      aIdleTimeoutSecs : Integer);
begin
  inherited Create(aNext);
  fStore           := aStore;
  fCookieName      := aCookieName;
  fIdleTimeoutSecs := aIdleTimeoutSecs;
end;

function TSessionMiddleware.GenerateSessionId : string;
var
  guid : TGUID;
begin
  CreateGUID(guid);
  Result := GUIDToString(guid).Replace('{', '').Replace('}', '').Replace('-', '').ToLower;
end;

function TSessionMiddleware.GetSessionIdFromCookie(aContext : THttpContextBase) : string;
var
  cookieHeader : string;
  parts        : TArray<string>;
  part         : string;
  kv           : TArray<string>;
begin
  Result := '';
  cookieHeader := aContext.Request.Headers.GetValue('Cookie');
  if cookieHeader = '' then Exit;

  parts := cookieHeader.Split(['; ', ';']);
  for part in parts do
  begin
    kv := part.Split(['='], 2);
    if (Length(kv) = 2) and SameText(Trim(kv[0]), fCookieName) then
    begin
      Result := Trim(kv[1]);
      Exit;
    end;
  end;
end;

procedure TSessionMiddleware.SetSessionCookie(aContext : THttpContextBase; const aSessionId : string);
begin
  aContext.Response.Headers.Add('Set-Cookie',
    Format('%s=%s; Path=/; HttpOnly; SameSite=Lax; Secure', [fCookieName, aSessionId]));
end;

procedure TSessionMiddleware.Invoke(aContext : THttpContextBase);
var
  sessionId : string;
  isNew     : Boolean;
  session   : ISession;
begin
  inherited;
  // Resolve session ID from request cookie
  sessionId := GetSessionIdFromCookie(aContext);
  isNew := (sessionId = '');

  if isNew then
    sessionId := GenerateSessionId;

  // Create or load the session
  session := fStore.CreateSession(sessionId, fIdleTimeoutSecs, isNew);
  aContext.Session := session;

  // Continue pipeline
  Next(aContext);

  // Persist session state and refresh TTL
  if session <> nil then
    session.Commit;

  // Set cookie on response for new sessions
  if isNew then
    SetSessionCookie(aContext, sessionId);
end;

end.
