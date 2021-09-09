{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Commandline
  Description : Core Commandline
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 29/07/2020
  Modified    : 01/08/2020

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

unit Quick.Core.Commandline;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Parameters;

type
  ICommandline<T : TParameters> = interface
  ['{3773C294-CF56-451C-AE04-7BD3878BD633}']
    function Value : T;
  end;

  TCommandline<T : TParameters> = class(TInterfacedObject,ICommandline<T>)
  private
    fValue : T;
  public
    constructor Create;
    destructor Destroy; override;
    function Value : T;
  end;

  CommandDescription = Quick.Parameters.CommandDescription;
  ParamCommand = Quick.Parameters.ParamCommand;
  ParamName = Quick.Parameters.ParamName;
  ParamRequired = Quick.Parameters.ParamRequired;
  ParamValueSeparator = Quick.Parameters.ParamValueSeparator;
  ParamSwitchChar = Quick.Parameters.ParamSwitchChar;
  ParamHelp = Quick.Parameters.ParamHelp;
  ParamValueIsNextParam = Quick.Parameters.ParamValueIsNextParam;

  TParameters = Quick.Parameters.TParameters;

  {$IFDEF MSWINDOWS}
  TServiceParameters = class(TParameters)
  private
    fSilent: Boolean;
    fInstall: Boolean;
    fRemove: Boolean;
    fInstance: string;
    fConsole: Boolean;
  published
    [ParamName('console')]
    [ParamHelp('Force run as console.')]
    property Console : Boolean read fConsole write fConsole;

    [ParamName('install')]
    [ParamHelp('Install service.')]
    property Install : Boolean read fInstall write fInstall;

    [ParamName('remove')]
    [ParamHelp('Remove service.')]
    property Remove : Boolean read fRemove write fRemove;

    [ParamName('instance')]
    [ParamValueIsNextParam]
    [ParamHelp('Define instance name of service.','intance')]
    property Instance : string read fInstance write fInstance;

    [ParamHelp('Silent mode.')]
    property Silent : Boolean read fSilent write fSilent;
  end;
  {$ELSE}
  TServiceParameters = class(TParameters)
  private
    fSilent: Boolean;
    fInstall: Boolean;
    fRemove: Boolean;
    fInstance: string;
    fConsole: Boolean;
    fDetach : Boolean;
  published
    [ParamName('console')]
    [ParamHelp('Force run as console.')]
    property Console : Boolean read fConsole write fConsole;

    [ParamName('install')]
    [ParamHelp('Install daemon.')]
    property Install : Boolean read fInstall write fInstall;

    [ParamName('remove')]
    [ParamHelp('Remove daemon.')]
    property Remove : Boolean read fRemove write fRemove;

    [ParamName('instance')]
    [ParamValueIsNextParam]
    [ParamHelp('Define instance name of daemon.','intance')]
    property Instance : string read fInstance write fInstance;

    [ParamHelp('Silent mode.')]
    [ParamName('silent')]
    property Silent : Boolean read fSilent write fSilent;

    [ParamHelp('Run in background.')]
    [ParamName('detach','d')]
    property Detach : Boolean read fDetach write fDetach;
  end;
  {$ENDIF}

implementation

{ TCommandline<T> }

constructor TCommandline<T>.Create;
begin
  fValue := T.Create(True);
  //if fValue.Help then fValue.ShowHelp;
end;

destructor TCommandline<T>.Destroy;
begin
  fValue.Free;
  inherited;
end;

function TCommandline<T>.Value: T;
begin
  Result := fValue;
end;

end.
