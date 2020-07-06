{ ***************************************************************************

  Copyright (c) 2016-2019 Kike Pérez

  Unit        : Quick.Core.Mvc.WebApi
  Description : Http WebApi Server
  Author      : Kike Pérez
  Version     : 1.8
  Created     : 30/09/2019
  Modified    : 31/10/2019

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

unit Quick.Core.Mvc.WebApi;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Quick.Commons,
  Quick.Logger.Intf,
  Quick.Core.Mvc;

type
  TApiKey = class
  private
    fName : string;
    fKey : string;
    fEnabled : Boolean;
  public
    property Name : string read fName write fName;
    property Key : string read fKey write fKey;
    property Enabled : Boolean read fEnabled write fEnabled;
  end;

  TApiKeys = class
  private
    fItems : TDictionary<string,TApiKey>;
  public
    function Exists(const aApiKey : string) : Boolean;
  end;

  TWebApiServer = class(TMVCServer)
  private
    fApiKeys : TApiKeys;
  public
    property ApiKeys : TApiKeys read fApiKeys write fApiKeys;
  end;


implementation


{ TApiKeys }

function TApiKeys.Exists(const aApiKey: string): Boolean;
begin
  Result := fItems.ContainsKey(aApiKey);
end;

end.
