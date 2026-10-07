unit Infra.Data.Models.Costumer;

interface

uses
  Quick.Core.Entity;

type
  [Table('Costumers')]
  TDBCostumer = class(TEntity)
  private
    fId : TAutoID;
    fFirstName : string;
    fLastName : string;
    fPhone : string;
    fEmail : string;
    fStreet : string;
    fCity : string;
    fState : string;
  published
    [Key]
    property Id : TAutoID read fId write fId;
    [StringLength(50)]
    property FirstName : string read fFirstName write fFirstName;
    [StringLength(100)]
    property LastName : string read fLastName write fLastName;
    [StringLength(25)]
    property Phone : string read fPhone write fPhone;
    [StringLength(50)]
    property Email : string read fEmail write fEmail;
    [StringLength(100)]
    property Street : string read fStreet write fStreet;
    [StringLength(50)]
    property City : string read fCity write fCity;
    [StringLength(50)]
    property State : string read fState write fState;
  end;

implementation

end.
