{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Localization.Abstractions
  Description : Core Localization Abstractions
  Author      : Kike Pérez
  Version     : 1.8
  Created     : 26/06/2020
  Modified    : 30/06/2020

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

unit Quick.Core.Localization.Abstractions;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  IStringLocalization = interface
  ['{C14539B0-2CF3-453C-BA50-ECFA5D1A7E80}']
    function GetItem(const aName : string) : string;
    function GetItemFmt(const aName : string; params : array of const) : string;
    property Items[const aName : string] : string read GetItem; default;
    property Items[const aName : string; params : array of const] : string read GetItemFmt; default;
  end;

  ILocalizationStore = interface
  ['{E543DFAD-1BDE-4A99-B1DA-E5C2CF5E8AF9}']
    function GetCultureTranslations(const aCulture : string) : TDictionary<string,string>;
  end;

implementation

end.
