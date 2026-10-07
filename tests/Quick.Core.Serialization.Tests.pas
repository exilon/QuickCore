unit Quick.Core.Serialization.Tests;

{ Tests: T-SER-01..14
    T-SER-01  TJsonSerializer.FromObject serializes published properties to JSON
    T-SER-02  TJsonSerializer.FromObject indented - JSON is non-empty
    T-SER-03  TJsonSerializer.ToObject(Class, JSON) deserializes back
    T-SER-04  TJsonSerializer.ToObject(Instance, JSON) fills existing instance
    T-SER-05  TJsonSerializer.FromValue serializes an Integer TValue
    T-SER-06  TJsonSerializer.Options returns non-nil
    T-SER-07  TYamlSerializer.FromObject serializes to YAML (non-empty)
    T-SER-08  TYamlSerializer.ToObject(Class, YAML) deserializes back
    T-SER-09  TYamlSerializer.ToObject(Instance, YAML) fills existing instance
    T-SER-10  TSerializers.Json returns non-nil TJsonSerializer
    T-SER-11  TSerializers.Yaml returns non-nil TYamlSerializer
    T-SER-12  TSerializers.Json and .Yaml are stable across multiple calls
    T-SER-13  TJsonSerializer serialized output contains field value
    T-SER-14  TYamlSerializer serialized output contains field value
}

interface

uses
  DUnitX.TestFramework,
  System.Rtti,
  System.SysUtils,
  Quick.Core.Serialization.Json,
  Quick.Core.Serialization.Yaml,
  Quick.Core.Serialization;

type

  {$M+}
  TSerPerson = class
  private
    fName : string;
    fAge  : Integer;
  published
    property Name : string  read fName write fName;
    property Age  : Integer read fAge  write fAge;
  end;
  {$M-}

  [TestFixture]
  TSerializationTests = class
  private
    fJson : TJsonSerializer;
    fYaml : TYamlSerializer;
    fHub  : TSerializers;
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure T_SER_01_Json_FromObject_NonEmpty;
    [Test]
    procedure T_SER_02_Json_FromObject_Indented_NonEmpty;
    [Test]
    procedure T_SER_03_Json_ToObject_Class_Deserializes;
    [Test]
    procedure T_SER_04_Json_ToObject_Instance_Fills;
    [Test]
    procedure T_SER_05_Json_FromValue_Integer;
    [Test]
    procedure T_SER_06_Json_Options_NotNil;
    [Test]
    procedure T_SER_07_Yaml_FromObject_NonEmpty;
    [Test]
    procedure T_SER_08_Yaml_ToObject_Class_Deserializes;
    [Test]
    procedure T_SER_09_Yaml_ToObject_Instance_Fills;
    [Test]
    procedure T_SER_10_Serializers_Json_NotNil;
    [Test]
    procedure T_SER_11_Serializers_Yaml_NotNil;
    [Test]
    procedure T_SER_12_Serializers_Json_StableAcrossCalls;
    [Test]
    procedure T_SER_13_Json_Output_ContainsFieldValue;
    [Test]
    procedure T_SER_14_Yaml_Output_ContainsFieldValue;
  end;

implementation

{ TSerializationTests }

procedure TSerializationTests.SetUp;
begin
  fJson := TJsonSerializer.Create;
  fYaml := TYamlSerializer.Create;
  fHub  := TSerializers.Create;
end;

procedure TSerializationTests.TearDown;
begin
  fHub.Free;
  fYaml.Free;
  fJson.Free;
end;

// ─── JSON ─────────────────────────────────────────────────────────────────────

procedure TSerializationTests.T_SER_01_Json_FromObject_NonEmpty;
var
  p    : TSerPerson;
  json : string;
begin
  p := TSerPerson.Create;
  try
    p.Name := 'Alice';
    p.Age  := 30;
    json   := fJson.FromObject(p);
    Assert.IsNotEmpty(json, 'JSON output should not be empty');
  finally
    p.Free;
  end;
end;

procedure TSerializationTests.T_SER_02_Json_FromObject_Indented_NonEmpty;
var
  p    : TSerPerson;
  json : string;
begin
  p := TSerPerson.Create;
  try
    p.Name := 'Bob';
    p.Age  := 25;
    json   := fJson.FromObject(p, True {aIndent});
    Assert.IsNotEmpty(json, 'Indented JSON output should not be empty');
  finally
    p.Free;
  end;
end;

procedure TSerializationTests.T_SER_03_Json_ToObject_Class_Deserializes;
var
  p    : TSerPerson;
  p2   : TSerPerson;
  json : string;
begin
  p := TSerPerson.Create;
  try
    p.Name := 'Carol';
    p.Age  := 40;
    json   := fJson.FromObject(p);
  finally
    p.Free;
  end;
  p2 := fJson.ToObject(TSerPerson, json) as TSerPerson;
  try
    Assert.AreEqual('Carol', p2.Name);
    Assert.AreEqual(40, p2.Age);
  finally
    p2.Free;
  end;
end;

procedure TSerializationTests.T_SER_04_Json_ToObject_Instance_Fills;
var
  p    : TSerPerson;
  p2   : TSerPerson;
  json : string;
begin
  p := TSerPerson.Create;
  try
    p.Name := 'Dan';
    p.Age  := 50;
    json   := fJson.FromObject(p);
  finally
    p.Free;
  end;
  p2 := TSerPerson.Create;
  try
    fJson.ToObject(p2, json);
    Assert.AreEqual('Dan', p2.Name);
    Assert.AreEqual(50, p2.Age);
  finally
    p2.Free;
  end;
end;

procedure TSerializationTests.T_SER_05_Json_FromValue_Integer;
var
  v    : TValue;
  json : string;
begin
  v    := TValue.From<Integer>(99);
  json := fJson.FromValue(v);
  Assert.IsTrue(json.Contains('99'), 'JSON of integer 99 should contain "99"');
end;

procedure TSerializationTests.T_SER_06_Json_Options_NotNil;
begin
  Assert.IsNotNull(fJson.Options, 'JsonSerializer.Options should not be nil');
end;

// ─── YAML ────────────────────────────────────────────────────────────────────

procedure TSerializationTests.T_SER_07_Yaml_FromObject_NonEmpty;
var
  p    : TSerPerson;
  yaml : string;
begin
  p := TSerPerson.Create;
  try
    p.Name := 'Eve';
    p.Age  := 22;
    yaml   := fYaml.FromObject(p);
    Assert.IsNotEmpty(yaml, 'YAML output should not be empty');
  finally
    p.Free;
  end;
end;

procedure TSerializationTests.T_SER_08_Yaml_ToObject_Class_Deserializes;
var
  p    : TSerPerson;
  p2   : TSerPerson;
  yaml : string;
begin
  p := TSerPerson.Create;
  try
    p.Name := 'Frank';
    p.Age  := 35;
    yaml   := fYaml.FromObject(p);
  finally
    p.Free;
  end;
  p2 := fYaml.ToObject(TSerPerson, yaml) as TSerPerson;
  try
    Assert.AreEqual('Frank', p2.Name);
    Assert.AreEqual(35, p2.Age);
  finally
    p2.Free;
  end;
end;

procedure TSerializationTests.T_SER_09_Yaml_ToObject_Instance_Fills;
var
  p    : TSerPerson;
  p2   : TSerPerson;
  yaml : string;
begin
  p := TSerPerson.Create;
  try
    p.Name := 'Grace';
    p.Age  := 28;
    yaml   := fYaml.FromObject(p);
  finally
    p.Free;
  end;
  p2 := TSerPerson.Create;
  try
    fYaml.ToObject(p2, yaml);
    Assert.AreEqual('Grace', p2.Name);
    Assert.AreEqual(28, p2.Age);
  finally
    p2.Free;
  end;
end;

// ─── TSerializers hub ────────────────────────────────────────────────────────

procedure TSerializationTests.T_SER_10_Serializers_Json_NotNil;
begin
  Assert.IsNotNull(fHub.Json, 'TSerializers.Json should return a non-nil serializer');
end;

procedure TSerializationTests.T_SER_11_Serializers_Yaml_NotNil;
begin
  Assert.IsNotNull(fHub.Yaml, 'TSerializers.Yaml should return a non-nil serializer');
end;

procedure TSerializationTests.T_SER_12_Serializers_Json_StableAcrossCalls;
begin
  Assert.AreSame(fHub.Json, fHub.Json,
    'TSerializers.Json should return the same instance across calls');
end;

procedure TSerializationTests.T_SER_13_Json_Output_ContainsFieldValue;
var
  p    : TSerPerson;
  json : string;
begin
  p := TSerPerson.Create;
  try
    p.Name := 'Zara';
    p.Age  := 77;
    json   := fJson.FromObject(p);
    Assert.IsTrue(json.Contains('Zara'), 'JSON must contain name value "Zara"');
  finally
    p.Free;
  end;
end;

procedure TSerializationTests.T_SER_14_Yaml_Output_ContainsFieldValue;
var
  p    : TSerPerson;
  yaml : string;
begin
  p := TSerPerson.Create;
  try
    p.Name := 'Zara';
    p.Age  := 77;
    yaml   := fYaml.FromObject(p);
    Assert.IsTrue(yaml.Contains('Zara'), 'YAML must contain name value "Zara"');
  finally
    p.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSerializationTests);

end.
