{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Extensions.Localization
  Description : Core Extensions Localization
  Author      : Kike Pérez
  Version     : 1.8
  Created     : 26/06/2020
  Modified    : 26/06/2020

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

unit Quick.Core.Extensions.Localization;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Quick.Options,
  Quick.Core.DependencyInjection,
  Quick.Core.Localization.Abstractions;

type
  TLocalizationOptions = class(TOptions)
  private
    fSupportedCultures : TList<string>;
    fAddIfNotFound : Boolean;
  public
    constructor Create; override;
    destructor Destroy; override;
  published
    procedure AddCulture(const aCulture : string);
    property AddIfNotfound : Boolean read fAddIfNotFound write fAddIfNotFound;
  end;

  TTranslationNotFoundEvent = procedure(const aName : string) of object;

  TStringLocalization = class(TInterfacedObject,IStringLocalization)
  private
    fTranslations : TDictionary<string,string>;
    fLocalizationStore : ILocalizationStore;
    fOnTranslationNotFound : TTranslationNotFoundEvent;
    function GetItem(const aName: string): string;
    function GetItemFmt(const aName : string; params : array of const) : string;
  public
    constructor Create(aLocalizationStore : ILocalizationStore);
    property Items[const aName : string] : string read GetItem; default;
    property Items[const aName : string; params : array of const] : string read GetItemFmt; default;
  end;

  TLocalizationServiceExtension = class(TServiceCollectionExtension)
    class function AddLocalization(aConfigureOptions : TConfigureOptionsProc<TLocalizationOptions> = nil) : TServiceCollection;
  end;


implementation

{ TLocalizationServiceExtension }

class function TLocalizationServiceExtension.AddLocalization(aConfigureOptions: TConfigureOptionsProc<TLocalizationOptions>): TServiceCollection;
begin
  Result := ServiceCollection;
  if not Result.IsRegistered<IStringLocalization,TStringLocalization> then
  begin
    Result.AddSingleton<IStringLocalization,TStringLocalization>;
  end;
end;

{ TLocalizationOptions }

procedure TLocalizationOptions.AddCulture(const aCulture: string);
begin
  fSupportedCultures.Add(aCulture);
end;

constructor TLocalizationOptions.Create;
begin
  fSupportedCultures := TList<string>.Create;
end;

destructor TLocalizationOptions.Destroy;
begin
  fSupportedCultures.Free;
  inherited;
end;

{ TStringLocalization }

constructor TStringLocalization.Create(aLocalizationStore: ILocalizationStore);
begin
  fLocalizationStore := aLocalizationStore;
  fTranslations := aLocalizationStore.GetCultureTranslations('es-es');
end;

function TStringLocalization.GetItem(const aName: string): string;
begin
  if not fTranslations.TryGetValue(aName,Result) then
  begin
    if Assigned(fOnTranslationNotFound) then fOnTranslationNotFound(aName);
    Result := aName;
  end;
end;

function TStringLocalization.GetItemFmt(const aName: string; params: array of const): string;
begin
  if not fTranslations.TryGetValue(aName,Result) then
  begin
    if Assigned(fOnTranslationNotFound) then fOnTranslationNotFound(aName);
    Result := aName;
  end;
  Result := Format(Result,params);
end;

end.
