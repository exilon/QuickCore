unit Models;

{ WebApiWithJwt Sample - S-27
  Request / response DTOs for the Auth + Products controllers. }

interface

type
  TLoginRequest = class
  private
    FUserName : string;
    FPassword : string;
  published
    property UserName : string read FUserName write FUserName;
    property Password : string read FPassword write FPassword;
  end;

  TLoginResponse = class
  private
    FToken     : string;
    FUserName  : string;
    FRole      : string;
    FExpiresIn : Integer;
  published
    property Token     : string  read FToken     write FToken;
    property UserName  : string  read FUserName  write FUserName;
    property Role      : string  read FRole      write FRole;
    property ExpiresIn : Integer read FExpiresIn write FExpiresIn;
  end;

implementation

end.
