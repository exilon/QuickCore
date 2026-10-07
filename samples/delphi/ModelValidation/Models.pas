unit Models;

{ ModelValidation Sample - S-34
  DTOs with validation attributes. }

interface

uses
  Quick.Core.Mvc.ModelValidation;

type
  /// DTO for creating a product — validates input before business logic.
  TCreateProductRequest = class
  private
    FName     : string;
    FPrice    : Double;
    FStock    : Integer;
    FEmail    : string;
  published
    [Required]
    [StringLength(3, 100)]
    property Name  : string  read FName  write FName;

    [Required]
    [Range(0.01, 999999.99)]
    property Price : Double  read FPrice write FPrice;

    [Range(0, 10000)]
    property Stock : Integer read FStock write FStock;

    [EmailAddress]
    property ContactEmail : string read FEmail write FEmail;
  end;

implementation

end.
