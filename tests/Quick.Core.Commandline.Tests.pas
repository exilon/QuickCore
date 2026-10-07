unit Quick.Core.Commandline.Tests;

{ Tests: T-CMD-01..08
    T-CMD-01  TCommandline<TServiceParameters> Value returns non-nil
    T-CMD-02  TCommandline<TServiceParameters> Install defaults to False
    T-CMD-03  TCommandline<TServiceParameters> Remove defaults to False
    T-CMD-04  TCommandline<TServiceParameters> Console defaults to False
    T-CMD-05  TCommandline<TServiceParameters> Silent defaults to False
    T-CMD-06  TServiceParameters is a TParameters subclass
    T-CMD-07  A second TCommandline instance is independent of the first
    T-CMD-08  TCommandline<TServiceParameters> Value is stable across calls
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Quick.Core.Commandline;

type

  [TestFixture]
  TCommandlineTests = class
  public
    [Test]
    procedure T_CMD_01_Value_NonNil;
    [Test]
    procedure T_CMD_02_Install_DefaultFalse;
    [Test]
    procedure T_CMD_03_Remove_DefaultFalse;
    [Test]
    procedure T_CMD_04_Console_DefaultFalse;
    [Test]
    procedure T_CMD_05_Silent_DefaultFalse;
    [Test]
    procedure T_CMD_06_Value_IsServiceParameters;
    [Test]
    procedure T_CMD_07_TwoInstances_AreIndependent;
    [Test]
    procedure T_CMD_08_Value_StableAcrossCalls;
  end;

implementation

{ TCommandlineTests }

procedure TCommandlineTests.T_CMD_01_Value_NonNil;
var
  cmd : TCommandline<TServiceParameters>;
begin
  cmd := TCommandline<TServiceParameters>.Create;
  try
    Assert.IsNotNull(cmd.Value, 'TCommandline.Value should not be nil');
  finally
    cmd.Free;
  end;
end;

procedure TCommandlineTests.T_CMD_02_Install_DefaultFalse;
var
  cmd : TCommandline<TServiceParameters>;
begin
  cmd := TCommandline<TServiceParameters>.Create;
  try
    Assert.IsFalse(cmd.Value.Install,
      'Install should default to False when not passed on command line');
  finally
    cmd.Free;
  end;
end;

procedure TCommandlineTests.T_CMD_03_Remove_DefaultFalse;
var
  cmd : TCommandline<TServiceParameters>;
begin
  cmd := TCommandline<TServiceParameters>.Create;
  try
    Assert.IsFalse(cmd.Value.Remove,
      'Remove should default to False');
  finally
    cmd.Free;
  end;
end;

procedure TCommandlineTests.T_CMD_04_Console_DefaultFalse;
var
  cmd : TCommandline<TServiceParameters>;
begin
  cmd := TCommandline<TServiceParameters>.Create;
  try
    Assert.IsFalse(cmd.Value.Console,
      'Console should default to False');
  finally
    cmd.Free;
  end;
end;

procedure TCommandlineTests.T_CMD_05_Silent_DefaultFalse;
var
  cmd : TCommandline<TServiceParameters>;
begin
  cmd := TCommandline<TServiceParameters>.Create;
  try
    Assert.IsFalse(cmd.Value.Silent,
      'Silent should default to False');
  finally
    cmd.Free;
  end;
end;

procedure TCommandlineTests.T_CMD_06_Value_IsServiceParameters;
var
  cmd : TCommandline<TServiceParameters>;
begin
  cmd := TCommandline<TServiceParameters>.Create;
  try
    Assert.IsTrue(cmd.Value is TServiceParameters,
      'Value should be an instance of TServiceParameters');
  finally
    cmd.Free;
  end;
end;

procedure TCommandlineTests.T_CMD_07_TwoInstances_AreIndependent;
var
  cmd1 : TCommandline<TServiceParameters>;
  cmd2 : TCommandline<TServiceParameters>;
begin
  cmd1 := TCommandline<TServiceParameters>.Create;
  cmd2 := TCommandline<TServiceParameters>.Create;
  try
    Assert.AreNotSame(cmd1.Value, cmd2.Value,
      'Two separate TCommandline instances should have independent Value objects');
  finally
    cmd2.Free;
    cmd1.Free;
  end;
end;

procedure TCommandlineTests.T_CMD_08_Value_StableAcrossCalls;
var
  cmd : TCommandline<TServiceParameters>;
begin
  cmd := TCommandline<TServiceParameters>.Create;
  try
    Assert.AreSame(cmd.Value, cmd.Value,
      'Value should return the same instance on repeated calls');
  finally
    cmd.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCommandlineTests);

end.
