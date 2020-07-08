unit TaskControlServer.Config.App;

interface

uses
  Quick.Options;

type
  TAppSettings = class(TOptions)
  private
    fSmtp : string;
    fEmail : string;
  published
    property Smtp : string read fSmtp write fSmtp;
    property Email : string read fEmail write fEmail;
  end;

implementation

end.
