{ ***************************************************************************

  Copyright (c) 2016-2023 Kike Pérez

  Unit        : Quick.Core.MessageQueue
  Description : Core MessageQueue
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 07/07/2020
  Modified    : 12/06/2023

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

unit Quick.Core.MessageQueue;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Threads,
  Quick.Core.MessageQueue.Abstractions,
  Quick.Core.Serialization.Json;

type
  TMessageQueue<T : class, constructor> = class(TInterfacedObject,IMessageQueue<T>)
  private
    fSerializer : TJsonSerializer;
  protected
    fQueueSize : Integer;
    fQueueOffset: Integer;
    fShutDown: Boolean;
    fTotalItemsPushed : Cardinal;
    fTotalItemsPopped: Cardinal;
    function Serialize(aValue : T) : string;
    function Deserialize(const aValue : string) : T;
  public
    constructor Create;
    destructor Destroy; override;
    function Push(const aMessage : T; aMaxPriority : Boolean) : TMSQWaitResult; virtual; abstract;
    function Pop(out oMessage : T) : TMSQWaitResult; virtual; abstract;
    function Remove(const aMessage : T) : Boolean; overload; virtual; abstract;
    function Remove(const aCurrentMessage, aProcessedMessage : T) : Boolean; overload; virtual; abstract;
    function Remove(const aCurrentMessage : T; aBeforeSaveToDones : TProc<T>) : Boolean; overload; virtual; abstract;
    function Failed(const aMessage : T) : Boolean; overload; virtual; abstract;
    function Failed(const aCurrentMessage, aProcessedMessage : T) : Boolean; overload; virtual; abstract;
    function Failed(const aCurrentMessage : T; aBeforeSaveToFaileds : TProc<T>) : Boolean; overload; virtual; abstract;
    procedure Clear; virtual; abstract;
    function QueueSize : Integer; virtual; abstract;
    function TotalItemsPushed: Cardinal; virtual; abstract;
    function TotalItemsPopped: Cardinal; virtual; abstract;
  end;

  EMessageQueueSerializationError = class(Exception);

implementation

{ TMessageQueue<T> }

constructor TMessageQueue<T>.Create;
begin
  fSerializer := TJsonSerializer.Create;
end;

destructor TMessageQueue<T>.Destroy;
begin
  fSerializer.Free;
  inherited;
end;

function TMessageQueue<T>.Serialize(aValue: T): string;
begin
  try
    Result := fSerializer.FromObject(aValue);
  except
    on E : Exception do raise EMessageQueueSerializationError.CreateFmt('MessaegQueue Deserialization Error: %s',[e.Message]);
  end;
end;

function TMessageQueue<T>.Deserialize(const aValue: string): T;
begin
  Result := T.Create;
  try
    Result := fSerializer.ToObject(Result,aValue) as T;
  except
    on E : Exception do raise EMessageQueueSerializationError.CreateFmt('MessaegQueue Serialization Error: %s',[e.Message]);
  end;
end;

end.
