unit Infra.Data.Identities;

interface

uses
  Quick.Core.Entity;

type
  TUser = class(TIdentityUser<TAutoID>)
  private
    fFullName : string;
    fEmail : string;
    fApiKey : string;
  published
    [StringLength(100)]
    property FulName : string read fFullName write fFullName;

    [StringLength(100)]
    property Email : string read fEmail write fEmail;

    [StringLength(50)]
    property ApiKey : string read fApiKey write fApiKey;
  end;

  TRole = class(TIdentityRole<TAutoID>)
  private
    fDescription : string;
  published
    [StringLength(255)]
    property Description : string read fDescription write fDescription;
  end;

implementation

end.
