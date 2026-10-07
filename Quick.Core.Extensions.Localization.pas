{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Extensions.Localization
  Description : Core Extensions Localization
  Author      : Kike Perez
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
  System.Classes,
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

  TFileLocalizationStore = class(TInterfacedObject, ILocalizationStore)
  private
    fLocalesPath : string;
    fCache : TObjectDictionary<string, TDictionary<string,string>>;
    function LoadCulture(const aCulture : string) : TDictionary<string,string>;
  public
    constructor Create;
    destructor Destroy; override;
    function GetCultureTranslations(const aCulture : string) : TDictionary<string,string>;
  end;

  TStringLocalization = class(TInterfacedObject,IStringLocalization)
  private
    fLocalizationStore : ILocalizationStore;
    fCurrentCulture : string;
    fOnTranslationNotFound : TTranslationNotFoundEvent;
    function GetItem(const aName: string): string;
    function GetItemFmt(const aName : string; params : array of const) : string;
    procedure SetCulture(const aCulture : string);
    function GetCulture : string;
  public
    constructor Create(aLocalizationStore : ILocalizationStore);
    property Items[const aName : string] : string read GetItem; default;
    property Items[const aName : string; params : array of const] : string read GetItemFmt; default;
    property Culture : string read GetCulture write SetCulture;
  end;

  TLocalizationServiceExtension = class(TServiceCollectionExtension)
    class function AddLocalization(aConfigureOptions : TConfigureOptionsProc<TLocalizationOptions> = nil) : TServiceCollection;
  end;


implementation

{ TLocalizationServiceExtension }

class function TLocalizationServiceExtension.AddLocalization(aConfigureOptions: TConfigureOptionsProc<TLocalizationOptions>): TServiceCollection;
begin
  Result := ServiceCollection;
  if not Result.IsRegistered<ILocalizationStore,TFileLocalizationStore> then
    Result.AddSingleton<ILocalizationStore,TFileLocalizationStore>;
  if not Result.IsRegistered<IStringLocalization,TStringLocalization> then
    Result.AddScoped<IStringLocalization,TStringLocalization>;
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

{ TFileLocalizationStore }

constructor TFileLocalizationStore.Create;
begin
  fLocalesPath := ExtractFilePath(ParamStr(0)) + 'locales\';
  fCache := TObjectDictionary<string, TDictionary<string,string>>.Create([doOwnsValues]);
end;

destructor TFileLocalizationStore.Destroy;
begin
  fCache.Free;
  inherited;
end;

function TFileLocalizationStore.LoadCulture(const aCulture: string): TDictionary<string,string>;
var
  lines : TStringList;
  line, key, value : string;
  eqPos : Integer;
  filePath : string;
begin
  Result := TDictionary<string,string>.Create;
  filePath := fLocalesPath + aCulture + '.lng';
  if not FileExists(filePath) then
    Exit;
  lines := TStringList.Create;
  try
    lines.LoadFromFile(filePath, TEncoding.UTF8);
    for line in lines do
    begin
      eqPos := line.IndexOf('=');
      if eqPos > 0 then
      begin
        key   := line.Substring(0, eqPos).Trim;
        value := line.Substring(eqPos + 1).Trim;
        Result.AddOrSetValue(key, value);
      end;
    end;
  finally
    lines.Free;
  end;
end;

function TFileLocalizationStore.GetCultureTranslations(const aCulture: string): TDictionary<string,string>;
var
  culture : string;
begin
  // normalise: 'es-ES' -> 'es'
  culture := LowerCase(aCulture);
  if culture.Contains('-') then
    culture := culture.Substring(0, culture.IndexOf('-'));
  if not fCache.TryGetValue(culture, Result) then
  begin
    Result := LoadCulture(culture);
    fCache.Add(culture, Result);
  end;
end;

{ TStringLocalization }

constructor TStringLocalization.Create(aLocalizationStore: ILocalizationStore);
begin
  fLocalizationStore := aLocalizationStore;
  fCurrentCulture    := 'en';
end;

procedure TStringLocalization.SetCulture(const aCulture: string);
begin
  fCurrentCulture := aCulture;
end;

function TStringLocalization.GetCulture: string;
begin
  Result := fCurrentCulture;
end;

function TStringLocalization.GetItem(const aName: string): string;
var
  translations : TDictionary<string,string>;
begin
  translations := fLocalizationStore.GetCultureTranslations(fCurrentCulture);
  if not translations.TryGetValue(aName, Result) then
  begin
    if Assigned(fOnTranslationNotFound) then fOnTranslationNotFound(aName);
    Result := aName;
  end;
end;

function TStringLocalization.GetItemFmt(const aName: string; params: array of const): string;
var
  translations : TDictionary<string,string>;
begin
  translations := fLocalizationStore.GetCultureTranslations(fCurrentCulture);
  if not translations.TryGetValue(aName, Result) then
  begin
    if Assigned(fOnTranslationNotFound) then fOnTranslationNotFound(aName);
    Result := aName;
  end;
  Result := Format(Result, params);
end;

end.
