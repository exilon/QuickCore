{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Linq.Abstractions
  Description : Core Linq Abstractions
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 12/03/2020
  Modified    : 24/03/2020

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

unit Quick.Core.Linq.Abstractions;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  Quick.Value,
  Quick.Collections;

type

  TLinqOrderDirection = (odAscending, odDescending);

  ILinq<T> = interface
  ['{18131A32-C79F-4D6D-9FF0-C0A019E28B02}']
    function Where(const aWhereClause : string; aWhereValues : array of const) : ILinq<T>; overload;
    function Where(const aWhereClause: string): ILinq<T>; overload;
    function Where(aPredicate : TPredicate<T>) : ILinq<T>; overload;
    function OrderBy(const aFieldNames : string) : ILinq<T>;
    function OrderByDescending(const aFieldNames : string) : ILinq<T>;
    function SelectFirst : T;
    function SelectLast : T;
    function SelectTop(aLimit : Integer) : IList<T>;
    function Select : IList<T>; overload;
    function Select(const aPropertyName : string) : IList<TFlexValue>; overload;
    function Count : Integer;
    function Update(const aFields : TArray<string>; aValues : array of const) : Boolean;
    function Delete : Boolean;
  end;

implementation

end.
