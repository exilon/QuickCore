unit Infra.Data.Mappings;

interface

uses
  System.SysUtils,
  Quick.Core.AutoMapper,
  Domain.Models.Product,
  Infra.Data.Models.Product;

type

  TMyProfile = class(TProfile)
  public
    constructor Create;
  end;

implementation




{ TMyProfile }

constructor TMyProfile.Create;
begin
  CreateMap<TDBProduct,TProduct>(procedure(src : TDBProduct; tgt : TProduct)
    begin
      tgt.Id := src.Id;
      //tgt.Name := src.Name;
    end)
    .ForMember('Id','Price')
    .ForMember('Name','Name')
    .IgnoreOtherMembers;
end;

initialization
  TAutoMapper.RegisterProfile<TMyProfile>;

end.
