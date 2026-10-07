unit Models;

interface

uses
  System.SysUtils,
  Quick.Core.Entity,
  Quick.Core.Entity.DAO;

type
  [Table('products')]
  TProduct = class(TEntity)
  private
    FId        : TAutoID;
    FName      : string;
    FPrice     : Double;
    FCreatedAt : TDateTime;
    FIsActive  : Boolean;
  published
    [Key]
    property Id        : TAutoID   read FId        write FId;
    [StringLength(100)]
    property Name      : string    read FName      write FName;
    [DecimalLength(10,2)]
    property Price     : Double    read FPrice     write FPrice;
    property CreatedAt : TDateTime read FCreatedAt write FCreatedAt;
    property IsActive  : Boolean   read FIsActive  write FIsActive;
  end;

implementation

end.
