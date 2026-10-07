unit Controller.Users;

{ WebApiWithAutoMapper Sample - S-10 }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Mapping.Abstractions,
  Models;

type
  [Route('api/users')]
  [ApiController]
  TUsersController = class(THttpController)
  private
    fMapper : IMapper;
  public
    constructor Create(aMapper : IMapper);
  published
    [HttpGet]
    function GetAll : IActionResult;

    [HttpPost]
    function CreateUser([FromBody] body : TCreateUserDto) : IActionResult;
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils;

{ TUsersController }

constructor TUsersController.Create(aMapper : IMapper);
begin
  inherited Create;
  fMapper := aMapper;
end;

function TUsersController.GetAll: IActionResult;
var
  dtos : TArray<TUserDto>;
  i    : Integer;
  sb   : TStringBuilder;
begin
  SetLength(dtos, Length(gUserStore));
  for i := 0 to High(gUserStore) do
    dtos[i] := fMapper.Map(gUserStore[i]).AsType<TUserDto>;
  try
    sb := TStringBuilder.Create;
    try
      sb.Append('[');
      for i := 0 to High(dtos) do
      begin
        if i > 0 then sb.Append(',');
        sb.AppendFormat('{"id":%d,"username":"%s","email":"%s","member":"%s"}',
          [dtos[i].Id, dtos[i].Username, dtos[i].Email, dtos[i].Member]);
      end;
      sb.Append(']');
      Result := Json(sb.ToString);
    finally
      sb.Free;
    end;
  finally
    for i := 0 to High(dtos) do dtos[i].Free;
  end;
end;

function TUsersController.CreateUser(body: TCreateUserDto): IActionResult;
var
  user : TUser;
  dto  : TUserDto;
begin
  user := fMapper.Map(body).AsType<TUser>;
  user.Id        := gNextId;
  user.CreatedAt := Now;
  Inc(gNextId);

  SetLength(gUserStore, Length(gUserStore) + 1);
  gUserStore[High(gUserStore)] := user;

  dto := fMapper.Map(user).AsType<TUserDto>;
  try
    Result := StatusCode(201, Format('{"id":%d,"username":"%s","email":"%s","member":"%s"}',
      [dto.Id, dto.Username, dto.Email, dto.Member]));
  finally
    dto.Free;
  end;
end;

initialization
  RegisterController(TUsersController);

end.
