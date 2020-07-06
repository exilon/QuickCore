{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Mapping.Abstractions
  Description : Core Mapping Abstractions
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 22/02/2020
  Modified    : 06/03/2020

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

unit Quick.Core.Mapping.Abstractions;

{$i QuickCore.inc}

interface

uses
  {$IFDEF DEBUG_MAPPER}
    Quick.Debug.Utils,
    System.TypInfo,
  {$ENDIF}
  System.SysUtils;

type

  TMapTarget = record
  type
    TMapDelegate = procedure(aSrcObj, aTgtObj : TObject) of object;
  private
    fSrcObj : TObject;
    fMapDelegate : TMapDelegate;
  public
    constructor Create(aSrcObj : TObject; aMapDelegate : TMapDelegate);
    function AsType<T : class, constructor> : T;
  end;

  IMapper = interface
  ['{B64F8600-53F1-4A54-8581-1255D31E91A6}']
    procedure Map(aSrcObj, aTgtObj : TObject); overload;
    function Map(aSrcObj : TObject) : TMapTarget; overload;
  end;

implementation

{ TMapTarget }

constructor TMapTarget.Create(aSrcObj : TObject; aMapDelegate : TMapDelegate);
begin
  fSrcObj := aSrcObj;
  fMapDelegate := aMapDelegate;
end;

function TMapTarget.AsType<T>: T;
begin
  {$IFDEF DEBUG_MAPPER}
    TDebugger.TimeIt(nil,'IMapper.Map',fSrcObj.ClassName + ' to ' + TClass(T).ClassName);
  {$ENDIF}
  Result := T.Create;
  fMapDelegate(fSrcObj,Result);
end;

end.
