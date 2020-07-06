{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Caching.Abstractions
  Description : Core Caching Interfaces
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 23/02/2020
  Modified    : 26/02/2020

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

unit Quick.Core.Caching.Abstractions;

{$i QuickCore.inc}

interface

uses
  Quick.Cache.Intf;

type

  IMemoryCache = ICache;

  ICache = Quick.Cache.Intf.ICache;

  IDistributedCache = interface
  ['{22603DEF-E3FB-4607-9731-54C974B527B3}']
    procedure SetValue(const aKey : string; aValue : TObject; aExpirationMilliseconds : Integer = 0); overload;
    procedure SetValue(const aKey : string; aValue : TObject; aExpirationDate : TDateTime); overload;
    procedure SetValue(const aKey, aValue : string; aExpirationMilliseconds : Integer = 0); overload;
    procedure SetValue(const aKey, aValue : string; aExpirationDate : TDateTime); overload;
    procedure SetValue(const aKey : string; aValue : TArray<string>; aExpirationMilliseconds : Integer = 0); overload;
    procedure SetValue(const aKey : string; aValue : TArray<string>; aExpirationDate : TDateTime); overload;
    procedure SetValue(const aKey : string; aValue : TArray<TObject>; aExpirationMilliseconds : Integer = 0); overload;
    procedure SetValue(const aKey : string; aValue : TArray<TObject>; aExpirationDate : TDateTime); overload;
    function GetValue(const aKey : string) : string; overload;
    function TryGetValue(const aKey : string; aValue : TObject) : Boolean; overload;
    function TryGetValue(const aKey : string; out aValue : string) : Boolean; overload;
    function TryGetValue(const aKey : string; out aValue : TArray<string>) : Boolean; overload;
    function TryGetValue(const aKey : string; out aValue : TArray<TObject>) : Boolean; overload;
    procedure Refresh(const aKey: string; aExpirationMilliseconds : Integer);
    procedure RemoveValue(const aKey : string);
    procedure Flush;
  end;

implementation

end.
