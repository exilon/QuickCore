{ ***************************************************************************

  QuickCore compatibility shim: Quick.JsonSerializer
  Maps the TJsonSerializer.Serialize class method to the current
  Quick.Json.Serializer instance API.

 *************************************************************************** }

unit Quick.JsonSerializer;

{$i QuickCore.inc}

interface

type
  TJsonSerializer = class
  public
    { Serialize any TObject to a JSON string. }
    class function Serialize(aObject: TObject): string; overload; static;
    { Generic overload — delegates to the non-generic version. }
    class function Serialize<T: class>(aObject: T): string; overload; static;
  end;

implementation

uses
  Quick.Json.Serializer;

class function TJsonSerializer.Serialize(aObject: TObject): string;
var
  ser: Quick.Json.Serializer.TJsonSerializer;
begin
  ser := Quick.Json.Serializer.TJsonSerializer.Create(slPublicProperty, True);
  try
    Result := ser.ObjectToJson(aObject, False);
  finally
    ser.Free;
  end;
end;

class function TJsonSerializer.Serialize<T>(aObject: T): string;
begin
  Result := Serialize(TObject(aObject));
end;

end.
