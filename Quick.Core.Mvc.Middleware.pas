{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Mvc.Middleware
  Description : Core Mvc Middleware
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 01/10/2019
  Modified    : 05/06/2020

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

unit Quick.Core.Mvc.Middleware;

{$i QuickCore.inc}

interface

uses
  {$IFDEF DEBUG_ROUTING}
  Quick.Debug.Utils,
  {$ENDIF}
  System.SysUtils,
  Quick.Core.Mvc.Context;

type
  TRequestDelegate = class abstract
  protected
    fNext : TRequestDelegate;
  public
    constructor Create(aNext : TRequestDelegate); virtual;
    procedure SetNextInvoker(aNext : TRequestDelegate);
    procedure Next(aContext : THttpContextBase);
    procedure Invoke(aContext : THttpContextBase); virtual;
  end;

  TRequestDelegateFunc = reference to function(aContext : THttpContextBase) : Boolean;

  TCustomRequestDelegate = class(TRequestDelegate)
  private
    fRequestDelegateFunc : TRequestDelegateFunc;
  public
    constructor Create(aNext : TRequestDelegate; aRequestDelegateFunc : TRequestDelegateFunc);
    procedure Invoke(aContext : THttpContextBase); override;
  end;

  TRequestDelegateClass = class of TRequestDelegate;

implementation

{ TRequestDelegate }

constructor TRequestDelegate.Create(aNext : TRequestDelegate);
begin
  fNext := aNext;
end;

procedure TRequestDelegate.Invoke(aContext: THttpContextBase);
begin
  {$IFDEF DEBUG_ROUTING}
    TDebugger.Enter(Self,'Invoke');
  {$ENDIF}
end;

procedure TRequestDelegate.Next(aContext : THttpContextBase);
begin
  if Assigned(fNext) then fNext.Invoke(aContext);
end;

procedure TRequestDelegate.SetNextInvoker(aNext: TRequestDelegate);
begin
  fNext := aNext;
end;

{ TCustomRequestDelegate }

constructor TCustomRequestDelegate.Create(aNext : TRequestDelegate; aRequestDelegateFunc : TRequestDelegateFunc);
begin
  inherited Create(aNext);
  fRequestDelegateFunc := aRequestDelegateFunc;
end;

procedure TCustomRequestDelegate.Invoke(aContext: THttpContextBase);
begin
  inherited;
  if fRequestDelegateFunc(aContext) then Next(aContext);
end;

end.
