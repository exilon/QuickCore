unit Models;

{ WebApiWithAutoMapper Sample - S-10
  Domain entity, DTO, and AutoMapper profile. }

interface

uses
  System.SysUtils,
  Quick.Core.AutoMapper,
  Quick.Core.Mapping.Abstractions;

type
  { Domain entity }
  TUser = class
  private
    FId        : Integer;
    FUsername  : string;
    FEmail     : string;
    FCreatedAt : TDateTime;
  public
    property Id        : Integer   read FId        write FId;
    property Username  : string    read FUsername  write FUsername;
    property Email     : string    read FEmail     write FEmail;
    property CreatedAt : TDateTime read FCreatedAt write FCreatedAt;
  end;

  { Data Transfer Object — exposed to API consumers }
  TUserDto = class
  private
    FId       : Integer;
    FUsername : string;
    FEmail    : string;
    FMember   : string;   // e.g. "since 2024"
  public
    property Id       : Integer read FId       write FId;
    property Username : string  read FUsername write FUsername;
    property Email    : string  read FEmail    write FEmail;
    property Member   : string  read FMember   write FMember;
  end;

  { Create-user DTO (no Id, no CreatedAt) }
  TCreateUserDto = class
  private
    FUsername : string;
    FEmail    : string;
  published
    property Username : string read FUsername write FUsername;
    property Email    : string read FEmail    write FEmail;
  end;

  { AutoMapper profile }
  TUserProfile = class(TProfile)
  public
    procedure Configure; override;
  end;

var
  gUserStore : TArray<TUser>;  // in-memory store for demo
  gNextId    : Integer = 1;

implementation

uses
  System.DateUtils;

{ TUserProfile }

procedure TUserProfile.Configure;
begin
  // TUser -> TUserDto: map same-named props + compute Member field
  CreateMap<TUser, TUserDto>
    .AfterMap(procedure(src, dst : TObject)
      begin
        (dst as TUserDto).Member := 'since ' + FormatDateTime('yyyy', (src as TUser).CreatedAt);
      end);

  // TCreateUserDto -> TUser: same-named props only
  CreateMap<TCreateUserDto, TUser>;
end;

initialization
  SetLength(gUserStore, 0);

end.
