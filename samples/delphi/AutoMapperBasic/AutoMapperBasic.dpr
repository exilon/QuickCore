program AutoMapperBasic;

(* AutoMapperBasic Sample - S-04
  Demonstrates AutoMapper in QuickCore:
    - Simple property mapping (same-name props)
    - ForMember renaming
    - Delegate mapping (computed properties)
    - List mapping
    - Nested object mapping
    - ReverseMap

  .NET equivalent: AutoMapper basic usage with profiles.
*)

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Generics.Collections,
  Quick.Console,
  Quick.Core.AutoMapper,
  Quick.Core.Mapping.Abstractions;

// ── Model classes ────────────────────────────────────────────────────────────

type
  // Database entity (source)
  TDBUser = class
  private
    FId        : Integer;
    FFirstName : string;
    FLastName  : string;
    FEmail     : string;
    FAge       : Integer;
  published
    property Id        : Integer read FId        write FId;
    property FirstName : string  read FFirstName write FFirstName;
    property LastName  : string  read FLastName  write FLastName;
    property Email     : string  read FEmail     write FEmail;
    property Age       : Integer read FAge       write FAge;
  end;

  // DTO (destination) - FullName is a computed field
  TUserDto = class
  private
    FId       : Integer;
    FFullName : string;
    FEmail    : string;
    FAge      : Integer;
  published
    property Id       : Integer read FId       write FId;
    property FullName : string  read FFullName write FFullName;
    property Email    : string  read FEmail    write FEmail;
    property Age      : Integer read FAge      write FAge;
  end;

  // Product entity
  TProduct = class
  private
    FCode  : string;
    FName  : string;
    FPrice : Double;
  published
    property Code  : string  read FCode  write FCode;
    property Name  : string  read FName  write FName;
    property Price : Double  read FPrice write FPrice;
  end;

  // Product summary DTO
  TProductSummary = class
  private
    FCode  : string;
    FName  : string;
    FPrice : Double;
  published
    property Code  : string  read FCode  write FCode;
    property Name  : string  read FName  write FName;
    property Price : Double  read FPrice write FPrice;
  end;

// ── AutoMapper Profile ───────────────────────────────────────────────────────

  TAppProfile = class(TProfile)
  public
    constructor Create;
  end;

constructor TAppProfile.Create;
begin
  inherited Create;

  // 1. Delegate map: TDBUser → TUserDto (FullName = FirstName + LastName)
  CreateMap<TDBUser, TUserDto>(
    procedure(src : TDBUser; dst : TUserDto)
    begin
      dst.Id       := src.Id;
      dst.FullName := Trim(src.FirstName + ' ' + src.LastName);
      dst.Email    := src.Email;
      dst.Age      := src.Age;
    end);

  // 2. Simple same-name map + ReverseMap: TProduct ↔ TProductSummary
  CreateMap<TProduct, TProductSummary>
    .ReverseMap;
end;

// ── Helpers ──────────────────────────────────────────────────────────────────

procedure PrintUser(const caption : string; dto : TUserDto);
begin
  cout(caption, ccLightCyan);
  cout(Format('  Id       : %d', [dto.Id]), ccWhite);
  cout(Format('  FullName : %s', [dto.FullName]), ccWhite);
  cout(Format('  Email    : %s', [dto.Email]), ccWhite);
  cout(Format('  Age      : %d', [dto.Age]), ccWhite);
end;

// ── Main program ─────────────────────────────────────────────────────────────

var
  mapper  : TAutoMapper;
  dbUser  : TDBUser;
  userDto : TUserDto;
  product : TProduct;
  summary : TProductSummary;
  dbUsers : TObjectList<TDBUser>;
  dtos    : TObjectList<TUserDto>;
  i       : Integer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    // Register the profile (once per app lifetime)
    TAutoMapper.RegisterProfile<TAppProfile>;
    mapper := TAutoMapper.Create;
    try

      // ── 1. Delegate mapping: TDBUser → TUserDto ──────────────────────
      cout('=== DELEGATE MAP: TDBUser → TUserDto ===', ccLightCyan);
      dbUser := TDBUser.Create;
      try
        dbUser.Id        := 1;
        dbUser.FirstName := 'Ana';
        dbUser.LastName  := 'García';
        dbUser.Email     := 'ana@example.com';
        dbUser.Age       := 30;

        userDto := mapper.Map<TUserDto>(dbUser);
        try
          PrintUser('  Result:', userDto);
        finally
          userDto.Free;
        end;
      finally
        dbUser.Free;
      end;

      cout('', ccWhite);

      // ── 2. Same-name map: TProduct → TProductSummary ─────────────────
      cout('=== SAME-NAME MAP: TProduct → TProductSummary ===', ccLightCyan);
      product := TProduct.Create;
      try
        product.Code  := 'PROD-001';
        product.Name  := 'Widget';
        product.Price := 9.99;

        summary := mapper.Map<TProductSummary>(product);
        try
          cout(Format('  Code  : %s', [summary.Code]), ccWhite);
          cout(Format('  Name  : %s', [summary.Name]), ccWhite);
          cout(Format('  Price : %.2f', [summary.Price]), ccWhite);

          // ── 3. ReverseMap: TProductSummary → TProduct ──────────────
          cout('', ccWhite);
          cout('=== REVERSE MAP: TProductSummary → TProduct ===', ccLightCyan);
          summary.Price := 12.99;  // modify
          var productBack := mapper.Map<TProduct>(summary);
          try
            cout(Format('  Code  : %s', [productBack.Code]), ccWhite);
            cout(Format('  Price : %.2f', [productBack.Price]), ccGreen);
          finally
            productBack.Free;
          end;
        finally
          summary.Free;
        end;
      finally
        product.Free;
      end;

      cout('', ccWhite);

      // ── 4. List mapping ──────────────────────────────────────────────
      cout('=== LIST MAP: TObjectList<TDBUser> → TObjectList<TUserDto> ===', ccLightCyan);
      dbUsers := TObjectList<TDBUser>.Create(True);
      try
        for i := 1 to 3 do
        begin
          dbUser := TDBUser.Create;
          dbUser.Id        := i;
          dbUser.FirstName := 'User';
          dbUser.LastName  := IntToStr(i);
          dbUser.Email     := Format('user%d@example.com', [i]);
          dbUser.Age       := 20 + i;
          dbUsers.Add(dbUser);
        end;

        dtos := TObjectList<TUserDto>.Create(True);
        try
          for dbUser in dbUsers do
          begin
            var dto := mapper.Map<TUserDto>(dbUser);
            dtos.Add(dto);
          end;
          for var dto in dtos do
            cout(Format('  %d: %s (%s)', [dto.Id, dto.FullName, dto.Email]), ccWhite);
        finally
          dtos.Free;
        end;
      finally
        dbUsers.Free;
      end;

    finally
      mapper.Free;
    end;

    cout('', ccWhite);
    cout('Press [Enter] to exit.', ccYellow);
    ConsoleWaitForEnterKey;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
