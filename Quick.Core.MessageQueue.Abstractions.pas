{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.MessageQueue.Abstractions
  Description : Core MessageQueue Abstractions
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 07/07/2020
  Modified    : 10/07/2020

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

unit Quick.Core.MessageQueue.Abstractions;

{$i QuickCore.inc}

interface

uses
  System.SysUtils;

type
  TMSQWaitResult = (wrOk, wrTimeout, wrError);

  IMessageQueue<T> = interface
  ['{0E859677-5431-4D2E-9E3F-F288AECDA75E}']
    function Push(const aMessage : T; aMaxPriority : Boolean) : TMSQWaitResult; overload;
    function Pop(out oMessage : T) : TMSQWaitResult;
    function Remove(const aMessage : T) : Boolean; overload;
    function Remove(const aCurrentMessage, aProcessedMessage : T) : Boolean; overload;
    function Remove(const aCurrentMessage : T; aBeforeSaveToDones : TProc<T>) : Boolean; overload;
    function Failed(const aMessage : T) : Boolean; overload;
    function Failed(const aCurrentMessage, aProcessedMessage : T) : Boolean; overload;
    function Failed(const aCurrentMessage : T; aBeforeSaveToFaileds : TProc<T>) : Boolean; overload;
  end;

implementation

end.
