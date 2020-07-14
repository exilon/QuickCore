unit PingTask;

interface

uses
  System.SysUtils;

type
  TPingTask = class
  private
    fId : string;
    fHost : string;
  public
    property Id : string read fId write fId;
    property Host : string read fHost write fHost;
  end;

implementation

end.
