unit Quick.Core.Extensions.FormFactory;

interface

uses
  System.SysUtils,
  {$IFDEF VCL}
  Vcl.Forms,
  {$ELSE}
  Fmx.Forms,
  {$ENDIF}
  Quick.Core.DependencyInjection;

type
  TFormFactoryServiceExtension = class(TServiceCollectionExtension)
    class function AddFormFactory : TServiceCollection;
  end;

  TFormFactory = class
  var
    fServiceCollection : TServiceCollection;
  public
    constructor Create(aServiceCollection : TServiceCollection);
    function New<T : TForm, constructor> : T;
  end;

implementation

{ TFormFactoryServiceExtension }

class function TFormFactoryServiceExtension.AddFormFactory : TServiceCollection;
begin
  Result := ServiceCollection;
  Result.AddSingleton<TFormFactory>('',function : TFormFactory
    begin
      Result := TFormFactory.Create(ServiceCollection);
    end);
end;

{ TFormFactory }

constructor TFormFactory.Create(aServiceCollection: TServiceCollection);
begin
  fServiceCollection := aServiceCollection;
end;

function TFormFactory.New<T>: T;
begin
  Result := fServiceCollection.AbstractFactory<T>;
end;

end.
