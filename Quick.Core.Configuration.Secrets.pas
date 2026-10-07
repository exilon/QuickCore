{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Configuration.Secrets
  Description : Secrets management service
  Author      : Kike Perez
  Version     : 1.0
  Created     : 13/04/2026
  Modified    : 08/05/2026

 *************************************************************************** }

unit Quick.Core.Configuration.Secrets;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.JSON,
  System.Generics.Collections,
  Quick.Options,
  Quick.Core.DependencyInjection;

type
  TSecretsOptions = class(TOptions)
  private
    fSecretFile : string;
  public
    constructor Create; override;
  published
    property SecretFile : string read fSecretFile write fSecretFile;
  end;

  ISecretsManager = interface
  ['{A2A0B2E7-0A9B-46A2-9B39-8D1ACFD14A33}']
    function GetSecret(const aKey : string; const aDefault : string = '') : string;
  end;

  TSecretsManager = class(TInterfacedObject, ISecretsManager)
  private
    fOptions : TSecretsOptions;
    fSecrets : TDictionary<string, string>;
    procedure LoadSecrets;
  public
    constructor Create(aOptions : IOptions<TSecretsOptions>);
    destructor Destroy; override;
    function GetSecret(const aKey : string; const aDefault : string = '') : string;
  end;

  TSecretsServiceExtension = class(TServiceCollectionExtension)
  public
    class function AddSecrets(const aSecretFile : string = 'appsecrets.json') : TServiceCollection;
  end;

implementation

{ TSecretsOptions }

constructor TSecretsOptions.Create;
begin
  inherited;
  Name := 'Secrets';
  HideOptions := True;
  fSecretFile := 'appsecrets.json';
end;

{ TSecretsManager }

constructor TSecretsManager.Create(aOptions : IOptions<TSecretsOptions>);
begin
  inherited Create;
  fOptions := aOptions.Value;
  fSecrets := TDictionary<string, string>.Create;
  LoadSecrets;
end;

destructor TSecretsManager.Destroy;
begin
  fSecrets.Free;
  inherited;
end;

function TSecretsManager.GetSecret(const aKey, aDefault : string) : string;
begin
  if not fSecrets.TryGetValue(aKey, Result) then
    Result := aDefault;
end;

procedure TSecretsManager.LoadSecrets;
var
  fileName : string;
  json     : TJSONObject;
  pair     : TJSONPair;
begin
  fileName := fOptions.SecretFile;
  if fileName.IsEmpty then
    Exit;
  if TPath.IsRelativePath(fileName) then
    fileName := TPath.Combine(GetCurrentDir, fileName);
  if not FileExists(fileName) then
    Exit;

  json := TJSONObject.ParseJSONValue(TFile.ReadAllText(fileName, TEncoding.UTF8)) as TJSONObject;
  try
    if json = nil then
      Exit;
    for pair in json do
      fSecrets.AddOrSetValue(pair.JsonString.Value, pair.JsonValue.Value);
  finally
    json.Free;
  end;
end;

{ TSecretsServiceExtension }

class function TSecretsServiceExtension.AddSecrets(const aSecretFile : string) : TServiceCollection;
var
  opts : TSecretsOptions;
begin
  Result := ServiceCollection;
  opts := TSecretsOptions.Create;
  opts.SecretFile := aSecretFile;
  Result.Configure<TSecretsOptions>(opts);
  if not Result.IsRegistered<ISecretsManager, TSecretsManager> then
    Result.AddSingleton<ISecretsManager, TSecretsManager>;
end;

end.