unit Quick.Core.AutoMapper.Tests;

interface

uses
  DUnitX.TestFramework,
  System.Generics.Collections,
  System.Rtti,
  System.SysUtils,
  Quick.Core.AutoMapper,
  Quick.Core.Mapping.Abstractions;

type
  {$M+}
  TAmDbUser = class
  private
    FId: Integer;
    FName: string;
  published
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
  end;

  TAmUser = class
  private
    FId: Integer;
    FName: string;
  published
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
  end;

  TAmDelegateSource = class
  private
    FFirstName: string;
    FLastName: string;
  published
    property FirstName: string read FFirstName write FFirstName;
    property LastName: string read FLastName write FLastName;
  end;

  TAmDelegateTarget = class
  private
    FFullName: string;
  published
    property FullName: string read FFullName write FFullName;
  end;

  TAmRenameSource = class
  private
    FFullName: string;
    FAge: Integer;
  published
    property FullName: string read FFullName write FFullName;
    property Age: Integer read FAge write FAge;
  end;

  TAmRenameTarget = class
  private
    FName: string;
    FAge: Integer;
  published
    property Name: string read FName write FName;
    property Age: Integer read FAge write FAge;
  end;

  TAmExplicitSource = class
  private
    FFullName: string;
    FAge: Integer;
  published
    property FullName: string read FFullName write FFullName;
    property Age: Integer read FAge write FAge;
  end;

  TAmExplicitTarget = class
  private
    FName: string;
    FAge: Integer;
  published
    property Name: string read FName write FName;
    property Age: Integer read FAge write FAge;
  end;

  TAmIgnoreMissingSource = class
  private
    FId: Integer;
  published
    property Id: Integer read FId write FId;
  end;

  TAmIgnoreMissingTarget = class
  private
    FId: Integer;
    FName: string;
  published
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
  end;

  TAmAddressEntity = class
  private
    FCity: string;
    FCountry: string;
  published
    property City: string read FCity write FCity;
    property Country: string read FCountry write FCountry;
  end;

  TAmAddressDto = class
  private
    FCity: string;
    FCountry: string;
  published
    property City: string read FCity write FCity;
    property Country: string read FCountry write FCountry;
  end;

  TAmCustomerEntity = class
  private
    FName: string;
    FAddress: TAmAddressEntity;
  public
    constructor Create;
    destructor Destroy; override;
  published
    property Name: string read FName write FName;
    property Address: TAmAddressEntity read FAddress write FAddress;
  end;

  TAmCustomerDto = class
  private
    FName: string;
    FAddress: TAmAddressDto;
  public
    constructor Create;
    destructor Destroy; override;
  published
    property Name: string read FName write FName;
    property Address: TAmAddressDto read FAddress write FAddress;
  end;

  TAmListSource = class
  private
    FUsers: TObjectList<TAmDbUser>;
  public
    constructor Create;
    destructor Destroy; override;
  published
    property Users: TObjectList<TAmDbUser> read FUsers write FUsers;
  end;

  TAmListTarget = class
  private
    FUsers: TObjectList<TAmUser>;
  public
    constructor Create;
    destructor Destroy; override;
  published
    property Users: TObjectList<TAmUser> read FUsers write FUsers;
  end;

  TAmUnmappedSource = class
  private
    FCode: Integer;
    FTitle: string;
  published
    property Code: Integer read FCode write FCode;
    property Title: string read FTitle write FTitle;
  end;

  TAmUnmappedTarget = class
  private
    FCode: Integer;
    FTitle: string;
  published
    property Code: Integer read FCode write FCode;
    property Title: string read FTitle write FTitle;
  end;

  { ---- Advanced-tests types (T-AM-11..17) ---- }

  TAmProdSrc = class
  private
    FId: Integer;
    FName: string;
  published
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
  end;

  TAmProdDst = class
  private
    FId: Integer;
    FName: string;
  published
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
  end;

  TAmCondSrc = class
  private
    FTag: string;
    FScore: Integer;
  published
    property Tag: string read FTag write FTag;
    property Score: Integer read FScore write FScore;
  end;

  TAmCondDst = class
  private
    FTag: string;
    FScore: Integer;
  published
    property Tag: string read FTag write FTag;
    property Score: Integer read FScore write FScore;
  end;

  TAmConvSrc = class
  private
    FPoints: Integer;
  published
    property Points: Integer read FPoints write FPoints;
  end;

  TAmConvDst = class
  private
    FPoints: Integer;
  published
    property Points: Integer read FPoints write FPoints;
  end;

  TAmHookSrc = class
  private
    FName: string;
  published
    property Name: string read FName write FName;
  end;

  TAmHookDst = class
  private
    FName: string;
  published
    property Name: string read FName write FName;
  end;

  TAmCtxSrc = class
  private
    FValue: Integer;
    FTag: string;
  published
    property Value: Integer read FValue write FValue;
    property Tag: string read FTag write FTag;
  end;

  TAmCtxDst = class
  private
    FValue: Integer;
    FTag: string;
  published
    property Value: Integer read FValue write FValue;
    property Tag: string read FTag write FTag;
  end;
  {$M-}

  TAdvancedAutoMapperProfile = class(TProfile)
  public
    constructor Create; override;
  end;

  TQuickCoreAutoMapperProfile = class(TProfile)
  public
    constructor Create; override;
  end;

  [TestFixture]
  TQuickCoreAutoMapperTests = class
  private
    class var FProfileRegistered: Boolean;
    class procedure EnsureProfile;
    function CreateMapper: TAutoMapper;
  public
    [Test]
    procedure T_AM_01_Map_Same_Name_Properties;
    [Test]
    procedure T_AM_02_Map_With_Delegate;
    [Test]
    procedure T_AM_03_ForMember_Renaming;
    [Test]
    procedure T_AM_04_IgnoreOtherMembers;
    [Test]
    procedure T_AM_05_IgnoreAllNonExisting;
    [Test]
    procedure T_AM_06_Map_List_Of_Objects;
    [Test]
    procedure T_AM_07_Map_Nested_Object;
    [Test]
    procedure T_AM_08_Map_Returns_New_Instance;
    [Test]
    procedure T_AM_09_Map_To_Existing_Instance;
    [Test]
    procedure T_AM_10_ResolveUnmapped;
  end;

  [TestFixture]
  TQuickCoreAutoMapperAdvancedTests = class
  private
    class var FAdvancedProfileRegistered: Boolean;
    class procedure EnsureAdvancedProfile;
    function CreateAdvancedMapper: TAutoMapper;
  public
    [Test]
    procedure T_AM_11_ReverseMap;
    [Test]
    procedure T_AM_12_Condition_Skips_When_False;
    [Test]
    procedure T_AM_13_ConvertUsing_Transforms_Value;
    [Test]
    procedure T_AM_14_BeforeMap_Is_Called;
    [Test]
    procedure T_AM_15_AfterMap_Modifies_Destination;
    [Test]
    procedure T_AM_16_AssertConfigurationIsValid_Does_Not_Raise;
    [Test]
    procedure T_AM_17_Map_With_Context;
  end;

implementation

{ TAmCustomerEntity }

constructor TAmCustomerEntity.Create;
begin
  inherited Create;
  FAddress := TAmAddressEntity.Create;
end;

destructor TAmCustomerEntity.Destroy;
begin
  FAddress.Free;
  inherited;
end;

{ TAmCustomerDto }

constructor TAmCustomerDto.Create;
begin
  inherited Create;
  FAddress := TAmAddressDto.Create;
end;

destructor TAmCustomerDto.Destroy;
begin
  FAddress.Free;
  inherited;
end;

{ TAmListSource }

constructor TAmListSource.Create;
begin
  inherited Create;
  FUsers := TObjectList<TAmDbUser>.Create(True);
end;

destructor TAmListSource.Destroy;
begin
  FUsers.Free;
  inherited;
end;

{ TAmListTarget }

constructor TAmListTarget.Create;
begin
  inherited Create;
  FUsers := TObjectList<TAmUser>.Create(True);
end;

destructor TAmListTarget.Destroy;
begin
  FUsers.Free;
  inherited;
end;

{ TQuickCoreAutoMapperProfile }

constructor TQuickCoreAutoMapperProfile.Create;
begin
  inherited Create;

  ResolveUnmapped;

  CreateMap<TAmDbUser, TAmUser>;
  CreateMap<TAmDelegateSource, TAmDelegateTarget>(
    procedure(src: TAmDelegateSource; dest: TAmDelegateTarget)
    begin
      dest.FullName := Trim(src.FirstName + ' ' + src.LastName);
    end);
  CreateMap<TAmRenameSource, TAmRenameTarget>
    .ForMember('FullName', 'Name');
  CreateMap<TAmExplicitSource, TAmExplicitTarget>
    .ForMember('FullName', 'Name')
    .IgnoreOtherMembers;
  CreateMap<TAmIgnoreMissingSource, TAmIgnoreMissingTarget>
    .ForMember('MissingField', 'Name')
    .IgnoreAllNonExisting;
  CreateMap<TAmAddressEntity, TAmAddressDto>;
  CreateMap<TAmCustomerEntity, TAmCustomerDto>;
  CreateMap<TAmListSource, TAmListTarget>;
end;

{ TQuickCoreAutoMapperTests }

class procedure TQuickCoreAutoMapperTests.EnsureProfile;
begin
  if FProfileRegistered then
    Exit;

  TAutoMapper.RegisterProfile<TQuickCoreAutoMapperProfile>;
  FProfileRegistered := True;
end;

function TQuickCoreAutoMapperTests.CreateMapper: TAutoMapper;
begin
  EnsureProfile;
  Result := TAutoMapper.Create;
end;

procedure TQuickCoreAutoMapperTests.T_AM_01_Map_Same_Name_Properties;
var
  mapper: TAutoMapper;
  source: TAmDbUser;
  target: TAmUser;
begin
  mapper := CreateMapper;
  source := TAmDbUser.Create;
  try
    source.Id := 10;
    source.Name := 'Ada';

    target := mapper.Map<TAmUser>(source);
    try
      Assert.AreEqual(10, target.Id);
      Assert.AreEqual('Ada', target.Name);
    finally
      target.Free;
    end;
  finally
    source.Free;
    mapper.Free;
  end;
end;

procedure TQuickCoreAutoMapperTests.T_AM_02_Map_With_Delegate;
var
  mapper: TAutoMapper;
  source: TAmDelegateSource;
  target: TAmDelegateTarget;
begin
  mapper := CreateMapper;
  source := TAmDelegateSource.Create;
  try
    source.FirstName := 'Grace';
    source.LastName := 'Hopper';

    target := mapper.Map<TAmDelegateTarget>(source);
    try
      Assert.AreEqual('Grace Hopper', target.FullName);
    finally
      target.Free;
    end;
  finally
    source.Free;
    mapper.Free;
  end;
end;

procedure TQuickCoreAutoMapperTests.T_AM_03_ForMember_Renaming;
var
  mapper: TAutoMapper;
  source: TAmRenameSource;
  target: TAmRenameTarget;
begin
  mapper := CreateMapper;
  source := TAmRenameSource.Create;
  try
    source.FullName := 'Linus Torvalds';
    source.Age := 55;

    target := mapper.Map<TAmRenameTarget>(source);
    try
      Assert.AreEqual('Linus Torvalds', target.Name);
      Assert.AreEqual(55, target.Age);
    finally
      target.Free;
    end;
  finally
    source.Free;
    mapper.Free;
  end;
end;

procedure TQuickCoreAutoMapperTests.T_AM_04_IgnoreOtherMembers;
var
  mapper: TAutoMapper;
  source: TAmExplicitSource;
  target: TAmExplicitTarget;
begin
  mapper := CreateMapper;
  source := TAmExplicitSource.Create;
  try
    source.FullName := 'Margaret Hamilton';
    source.Age := 37;

    target := mapper.Map<TAmExplicitTarget>(source);
    try
      Assert.AreEqual('Margaret Hamilton', target.Name);
      Assert.AreEqual(0, target.Age);
    finally
      target.Free;
    end;
  finally
    source.Free;
    mapper.Free;
  end;
end;

procedure TQuickCoreAutoMapperTests.T_AM_05_IgnoreAllNonExisting;
var
  mapper: TAutoMapper;
  source: TAmIgnoreMissingSource;
  target: TAmIgnoreMissingTarget;
begin
  mapper := CreateMapper;
  source := TAmIgnoreMissingSource.Create;
  try
    source.Id := 88;

    Assert.WillNotRaise(
      procedure
      begin
        target := mapper.Map<TAmIgnoreMissingTarget>(source);
      end,
      nil);
    try
      Assert.AreEqual(88, target.Id);
      Assert.AreEqual('', target.Name);
    finally
      target.Free;
    end;
  finally
    source.Free;
    mapper.Free;
  end;
end;

procedure TQuickCoreAutoMapperTests.T_AM_06_Map_List_Of_Objects;
var
  mapper: TAutoMapper;
  source: TAmListSource;
  srcUser: TAmDbUser;
  target: TAmListTarget;
begin
  mapper := CreateMapper;
  source := TAmListSource.Create;
  try
    srcUser := TAmDbUser.Create;
    srcUser.Id := 1;
    srcUser.Name := 'User One';
    source.Users.Add(srcUser);

    srcUser := TAmDbUser.Create;
    srcUser.Id := 2;
    srcUser.Name := 'User Two';
    source.Users.Add(srcUser);

    target := mapper.Map<TAmListTarget>(source);
    try
      Assert.AreEqual(NativeInt(2), target.Users.Count);
      Assert.AreEqual('User One', target.Users[0].Name);
      Assert.AreEqual(2, target.Users[1].Id);
    finally
      target.Free;
    end;
  finally
    source.Free;
    mapper.Free;
  end;
end;

procedure TQuickCoreAutoMapperTests.T_AM_07_Map_Nested_Object;
var
  mapper: TAutoMapper;
  source: TAmCustomerEntity;
  target: TAmCustomerDto;
begin
  mapper := CreateMapper;
  source := TAmCustomerEntity.Create;
  try
    source.Name := 'Nested User';
    source.Address.City := 'Madrid';
    source.Address.Country := 'Spain';

    target := mapper.Map<TAmCustomerDto>(source);
    try
      Assert.AreEqual('Nested User', target.Name);
      Assert.IsNotNull(target.Address);
      Assert.AreEqual('Madrid', target.Address.City);
      Assert.AreEqual('Spain', target.Address.Country);
    finally
      target.Free;
    end;
  finally
    source.Free;
    mapper.Free;
  end;
end;

procedure TQuickCoreAutoMapperTests.T_AM_08_Map_Returns_New_Instance;
var
  mapper: TAutoMapper;
  source: TAmDbUser;
  target: TAmUser;
begin
  mapper := CreateMapper;
  source := TAmDbUser.Create;
  try
    source.Id := 5;
    source.Name := 'New Instance';

    target := mapper.Map<TAmUser>(source);
    try
      Assert.AreNotSame(source, target);
      Assert.AreEqual(5, target.Id);
    finally
      target.Free;
    end;
  finally
    source.Free;
    mapper.Free;
  end;
end;

procedure TQuickCoreAutoMapperTests.T_AM_09_Map_To_Existing_Instance;
var
  mapper: TAutoMapper;
  source: TAmDbUser;
  target: TAmUser;
begin
  mapper := CreateMapper;
  source := TAmDbUser.Create;
  target := TAmUser.Create;
  try
    source.Id := 15;
    source.Name := 'Overwrite';
    target.Id := -1;
    target.Name := 'Old';

    mapper.Map(source, target);

    Assert.AreEqual(15, target.Id);
    Assert.AreEqual('Overwrite', target.Name);
  finally
    target.Free;
    source.Free;
    mapper.Free;
  end;
end;

procedure TQuickCoreAutoMapperTests.T_AM_10_ResolveUnmapped;
var
  mapper: TAutoMapper;
  source: TAmUnmappedSource;
  target: TAmUnmappedTarget;
begin
  mapper := CreateMapper;
  source := TAmUnmappedSource.Create;
  try
    source.Code := 404;
    source.Title := 'Unmapped but compatible';

    target := mapper.Map<TAmUnmappedTarget>(source);
    try
      Assert.AreEqual(404, target.Code);
      Assert.AreEqual('Unmapped but compatible', target.Title);
    finally
      target.Free;
    end;
  finally
    source.Free;
    mapper.Free;
  end;
end;

{ --- Advanced AutoMapper tests (T-AM-11..17) --- }

var
  GAmBeforeMapCalled: Boolean = False;
  GAmAfterMapTag: string = '';

{ TAdvancedAutoMapperProfile }

constructor TAdvancedAutoMapperProfile.Create;
begin
  inherited Create;

  // T-AM-11: ReverseMap — registers both TAmProdSrc→TAmProdDst and the inverse
  CreateMap<TAmProdSrc, TAmProdDst>.ReverseMap;

  // T-AM-12: Condition — skip copying Score when it is negative
  CreateMap<TAmCondSrc, TAmCondDst>
    .Condition('Score',
      function(src: TObject): Boolean
      begin
        Result := TAmCondSrc(src).Score >= 0;
      end);

  // T-AM-13: ConvertUsing — double the Points value
  CreateMap<TAmConvSrc, TAmConvDst>
    .ConvertUsing('Points',
      function(const v: TValue): TValue
      begin
        Result := TValue.From<Integer>(v.AsInteger * 2);
      end);

  // T-AM-14 / T-AM-15: BeforeMap + AfterMap hooks
  CreateMap<TAmHookSrc, TAmHookDst>
    .BeforeMap(
      procedure(s, d: TObject)
      begin
        GAmBeforeMapCalled := True;
      end)
    .AfterMap(
      procedure(s, d: TObject)
      begin
        GAmAfterMapTag := TAmHookDst(d).Name + '_done';
      end);

  // T-AM-17: Map with context — delegate reads TAutoMapper.CurrentContext
  CreateMap<TAmCtxSrc, TAmCtxDst>(
    procedure(src: TAmCtxSrc; dst: TAmCtxDst)
    var
      ctx: TMapContext;
    begin
      dst.Value := src.Value;
      ctx := TAutoMapper.CurrentContext;
      if Assigned(ctx) and ctx.Items.ContainsKey('prefix') then
        dst.Tag := ctx.Items['prefix'].AsString + IntToStr(src.Value)
      else
        dst.Tag := IntToStr(src.Value);
    end)
    .IgnoreOtherMembers;
end;

{ TQuickCoreAutoMapperAdvancedTests }

class procedure TQuickCoreAutoMapperAdvancedTests.EnsureAdvancedProfile;
begin
  if FAdvancedProfileRegistered then
    Exit;
  TAutoMapper.RegisterProfile<TAdvancedAutoMapperProfile>;
  FAdvancedProfileRegistered := True;
end;

function TQuickCoreAutoMapperAdvancedTests.CreateAdvancedMapper: TAutoMapper;
begin
  EnsureAdvancedProfile;
  Result := TAutoMapper.Create;
end;

procedure TQuickCoreAutoMapperAdvancedTests.T_AM_11_ReverseMap;
var
  mapper: TAutoMapper;
  src: TAmProdSrc;
  dst: TAmProdDst;
  rev: TAmProdSrc;
begin
  mapper := CreateAdvancedMapper;
  // Forward: TAmProdSrc → TAmProdDst
  src := TAmProdSrc.Create;
  try
    src.Id := 7;
    src.Name := 'Widget';
    dst := mapper.Map<TAmProdDst>(src);
    try
      Assert.AreEqual(7, dst.Id);
      Assert.AreEqual('Widget', dst.Name);
    finally
      dst.Free;
    end;
  finally
    src.Free;
  end;
  // Reverse: TAmProdDst → TAmProdSrc (registered by ReverseMap)
  dst := TAmProdDst.Create;
  try
    dst.Id := 99;
    dst.Name := 'Gadget';
    rev := mapper.Map<TAmProdSrc>(dst);
    try
      Assert.AreEqual(99, rev.Id);
      Assert.AreEqual('Gadget', rev.Name);
    finally
      rev.Free;
    end;
  finally
    dst.Free;
    mapper.Free;
  end;
end;

procedure TQuickCoreAutoMapperAdvancedTests.T_AM_12_Condition_Skips_When_False;
var
  mapper: TAutoMapper;
  src: TAmCondSrc;
  dst: TAmCondDst;
begin
  mapper := CreateAdvancedMapper;
  src := TAmCondSrc.Create;
  try
    src.Tag := 'test';
    src.Score := -5; // negative → Condition returns False → Score not copied
    dst := mapper.Map<TAmCondDst>(src);
    try
      Assert.AreEqual('test', dst.Tag);
      Assert.AreEqual(0, dst.Score, 'Score must not be copied when Condition returns False');
    finally
      dst.Free;
    end;
    // Positive score: Condition returns True → Score IS copied
    src.Score := 42;
    dst := mapper.Map<TAmCondDst>(src);
    try
      Assert.AreEqual(42, dst.Score, 'Score must be copied when Condition returns True');
    finally
      dst.Free;
    end;
  finally
    src.Free;
    mapper.Free;
  end;
end;

procedure TQuickCoreAutoMapperAdvancedTests.T_AM_13_ConvertUsing_Transforms_Value;
var
  mapper: TAutoMapper;
  src: TAmConvSrc;
  dst: TAmConvDst;
begin
  mapper := CreateAdvancedMapper;
  src := TAmConvSrc.Create;
  try
    src.Points := 7;
    dst := mapper.Map<TAmConvDst>(src);
    try
      Assert.AreEqual(14, dst.Points, 'ConvertUsing must double the Points value');
    finally
      dst.Free;
    end;
  finally
    src.Free;
    mapper.Free;
  end;
end;

procedure TQuickCoreAutoMapperAdvancedTests.T_AM_14_BeforeMap_Is_Called;
var
  mapper: TAutoMapper;
  src: TAmHookSrc;
  dst: TAmHookDst;
begin
  GAmBeforeMapCalled := False;
  mapper := CreateAdvancedMapper;
  src := TAmHookSrc.Create;
  try
    src.Name := 'alpha';
    dst := mapper.Map<TAmHookDst>(src);
    try
      Assert.IsTrue(GAmBeforeMapCalled, 'BeforeMap hook must have been invoked');
    finally
      dst.Free;
    end;
  finally
    src.Free;
    mapper.Free;
  end;
end;

procedure TQuickCoreAutoMapperAdvancedTests.T_AM_15_AfterMap_Modifies_Destination;
var
  mapper: TAutoMapper;
  src: TAmHookSrc;
  dst: TAmHookDst;
begin
  GAmAfterMapTag := '';
  mapper := CreateAdvancedMapper;
  src := TAmHookSrc.Create;
  try
    src.Name := 'beta';
    dst := mapper.Map<TAmHookDst>(src);
    try
      Assert.AreEqual('beta_done', GAmAfterMapTag,
        'AfterMap hook must set GAmAfterMapTag = Name + "_done"');
    finally
      dst.Free;
    end;
  finally
    src.Free;
    mapper.Free;
  end;
end;

procedure TQuickCoreAutoMapperAdvancedTests.T_AM_16_AssertConfigurationIsValid_Does_Not_Raise;
var
  mapper: TAutoMapper;
begin
  mapper := CreateAdvancedMapper;
  try
    Assert.WillNotRaise(
      procedure
      begin
        mapper.AssertConfigurationIsValid;
      end,
      nil,
      'All registered mappings have matching properties; AssertConfigurationIsValid must not raise');
  finally
    mapper.Free;
  end;
end;

procedure TQuickCoreAutoMapperAdvancedTests.T_AM_17_Map_With_Context;
var
  mapper: TAutoMapper;
  src: TAmCtxSrc;
  dst: TAmCtxDst;
  configProc: TMapOptionsProc;
begin
  mapper := CreateAdvancedMapper;
  src := TAmCtxSrc.Create;
  try
    src.Value := 42;
    src.Tag := 'ignored';
    // Map without context: Tag = '42'
    dst := mapper.Map<TAmCtxDst>(src);
    try
      Assert.AreEqual(42, dst.Value);
      Assert.AreEqual('42', dst.Tag, 'Without context, Tag must equal Value.ToString');
    finally
      dst.Free;
    end;
    // Map with context: Tag = prefix + '42'
    configProc := procedure(ctx: TMapContext)
      begin
        ctx.Items.AddOrSetValue('prefix', TValue.From<string>('X_'));
      end;
    dst := mapper.Map(src, configProc).AsType<TAmCtxDst>;
    try
      Assert.AreEqual(42, dst.Value);
      Assert.AreEqual('X_42', dst.Tag,
        'With context prefix "X_", Tag must be "X_42"');
    finally
      dst.Free;
    end;
  finally
    src.Free;
    mapper.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TQuickCoreAutoMapperTests);
  TDUnitX.RegisterTestFixture(TQuickCoreAutoMapperAdvancedTests);

end.