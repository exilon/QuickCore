unit Models;

{ WebApiWithIdentity Sample - S-14
  Identity domain models: TAppUser + TAppRole + TIdentityContext (DBContext). }

interface

uses
  Quick.Core.Entity,
  Quick.Core.Entity.DAO;

type
  [Table('users')]
  TAppUser = class(TEntity)
  private
    FId           : TAutoID;
    FUserName     : string;
    FEmail        : string;
    FPasswordHash : string;
    FSecurityStamp : string;
    FLockoutEnd   : TDateTime;
    FIsLockedOut  : Boolean;
  published
    [Key]
    property Id            : TAutoID   read FId            write FId;
    [StringLength(64)]
    property UserName      : string    read FUserName      write FUserName;
    [StringLength(128)]
    property Email         : string    read FEmail         write FEmail;
    [StringLength(256)]
    property PasswordHash  : string    read FPasswordHash  write FPasswordHash;
    [StringLength(128)]
    property SecurityStamp : string    read FSecurityStamp write FSecurityStamp;
    property LockoutEnd    : TDateTime read FLockoutEnd    write FLockoutEnd;
    property IsLockedOut   : Boolean   read FIsLockedOut   write FIsLockedOut;
  end;

  [Table('roles')]
  TAppRole = class(TEntity)
  private
    FId   : TAutoID;
    FName : string;
  published
    [Key]
    property Id   : TAutoID read FId   write FId;
    [StringLength(64)]
    property Name : string  read FName write FName;
  end;

  TIdentityContext = class(TIdentityDbContext<TAppUser, TAppRole>)
    // No extra sets needed — Users + Roles come from TIdentityDbContext
  end;

implementation

end.
