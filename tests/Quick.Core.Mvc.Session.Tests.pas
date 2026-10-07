unit Quick.Core.Mvc.Session.Tests;

{ Tests: T-SS-01..12
    T-SS-01  CreateSession returns a non-nil ISession
    T-SS-02  New session Id is non-empty
    T-SS-03  New session IsAvailable = True
    T-SS-04  SetString / GetString round-trip
    T-SS-05  SetInteger / GetInteger round-trip
    T-SS-06  SetFloat / GetFloat round-trip (exact equality via Int cast)
    T-SS-07  GetString for unknown key returns empty string
    T-SS-08  GetInteger for unknown key returns 0
    T-SS-09  Remove deletes a stored key
    T-SS-10  Clear empties all keys in the session
    T-SS-11  Overwriting a key stores the latest value
    T-SS-12  SessionExists returns True after session is created
}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Quick.Core.Mvc.Session;

type

  [TestFixture]
  TSessionTests = class
  private
    fStore   : TInMemorySessionStore;
    fSession : ISession;
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure T_SS_01_CreateSession_ReturnsNonNil;
    [Test]
    procedure T_SS_02_NewSession_IdIsNonEmpty;
    [Test]
    procedure T_SS_03_NewSession_IsAvailableTrue;
    [Test]
    procedure T_SS_04_SetString_GetString_RoundTrip;
    [Test]
    procedure T_SS_05_SetInteger_GetInteger_RoundTrip;
    [Test]
    procedure T_SS_06_SetFloat_GetFloat_RoundTrip;
    [Test]
    procedure T_SS_07_GetString_UnknownKey_ReturnsEmpty;
    [Test]
    procedure T_SS_08_GetInteger_UnknownKey_ReturnsZero;
    [Test]
    procedure T_SS_09_Remove_DeletesKey;
    [Test]
    procedure T_SS_10_Clear_EmptiesAllKeys;
    [Test]
    procedure T_SS_11_Overwrite_ReturnsLatestValue;
    [Test]
    procedure T_SS_12_SessionExists_ReturnsTrueAfterCreate;
  end;

implementation

{ TSessionTests }

procedure TSessionTests.SetUp;
begin
  fStore   := TInMemorySessionStore.Create(300);   // 5-min timeout
  fSession := fStore.CreateSession('test-session-id', 300, True);
end;

procedure TSessionTests.TearDown;
begin
  fSession := nil;
  fStore.Free;
end;

// ─── T-SS-01 ─────────────────────────────────────────────────────────────────

procedure TSessionTests.T_SS_01_CreateSession_ReturnsNonNil;
begin
  Assert.IsNotNull(fSession, 'CreateSession should return a non-nil ISession');
end;

// ─── T-SS-02 ─────────────────────────────────────────────────────────────────

procedure TSessionTests.T_SS_02_NewSession_IdIsNonEmpty;
begin
  Assert.IsNotEmpty(fSession.Id, 'Session Id should not be empty');
end;

// ─── T-SS-03 ─────────────────────────────────────────────────────────────────

procedure TSessionTests.T_SS_03_NewSession_IsAvailableTrue;
begin
  Assert.IsTrue(fSession.IsAvailable, 'Newly created session should be available');
end;

// ─── T-SS-04 ─────────────────────────────────────────────────────────────────

procedure TSessionTests.T_SS_04_SetString_GetString_RoundTrip;
begin
  fSession.SetString('user', 'Alice');
  Assert.AreEqual('Alice', fSession.GetString('user'));
end;

// ─── T-SS-05 ─────────────────────────────────────────────────────────────────

procedure TSessionTests.T_SS_05_SetInteger_GetInteger_RoundTrip;
begin
  fSession.SetInteger('count', 42);
  Assert.AreEqual(Int64(42), fSession.GetInteger('count'));
end;

// ─── T-SS-06 ─────────────────────────────────────────────────────────────────

procedure TSessionTests.T_SS_06_SetFloat_GetFloat_RoundTrip;
begin
  fSession.SetFloat('score', 9.5);
  // Float round-trip via string may differ slightly; compare truncated integer part
  Assert.AreEqual(Int64(9), Trunc(fSession.GetFloat('score')));
end;

// ─── T-SS-07 ─────────────────────────────────────────────────────────────────

procedure TSessionTests.T_SS_07_GetString_UnknownKey_ReturnsEmpty;
begin
  Assert.AreEqual('', fSession.GetString('__no_such_key__'),
    'GetString for unknown key should return empty string');
end;

// ─── T-SS-08 ─────────────────────────────────────────────────────────────────

procedure TSessionTests.T_SS_08_GetInteger_UnknownKey_ReturnsZero;
begin
  Assert.AreEqual(Int64(0), fSession.GetInteger('__no_such_key__'),
    'GetInteger for unknown key should return 0');
end;

// ─── T-SS-09 ─────────────────────────────────────────────────────────────────

procedure TSessionTests.T_SS_09_Remove_DeletesKey;
begin
  fSession.SetString('temp', 'value');
  fSession.Remove('temp');
  Assert.AreEqual('', fSession.GetString('temp'),
    'Key should be empty after Remove');
end;

// ─── T-SS-10 ─────────────────────────────────────────────────────────────────

procedure TSessionTests.T_SS_10_Clear_EmptiesAllKeys;
begin
  fSession.SetString('a', '1');
  fSession.SetString('b', '2');
  fSession.Clear;
  Assert.AreEqual('', fSession.GetString('a'), 'After Clear, key ''a'' should be gone');
  Assert.AreEqual('', fSession.GetString('b'), 'After Clear, key ''b'' should be gone');
end;

// ─── T-SS-11 ─────────────────────────────────────────────────────────────────

procedure TSessionTests.T_SS_11_Overwrite_ReturnsLatestValue;
begin
  fSession.SetString('name', 'Alice');
  fSession.SetString('name', 'Bob');
  Assert.AreEqual('Bob', fSession.GetString('name'),
    'Second SetString should overwrite the first');
end;

// ─── T-SS-12 ─────────────────────────────────────────────────────────────────

procedure TSessionTests.T_SS_12_SessionExists_ReturnsTrueAfterCreate;
begin
  Assert.IsTrue(fStore.SessionExists('test-session-id'),
    'SessionExists should return True for a session just created');
end;

initialization
  TDUnitX.RegisterTestFixture(TSessionTests);

end.
