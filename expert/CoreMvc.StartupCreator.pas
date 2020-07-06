unit CoreMvc.StartupCreator;

interface

uses
  CoreMvc.Wizards.Utils,
  ToolsAPI;

resourcestring
  SStartuprResources = 'StartupTemplate';
  SStartupFileName = 'Startup';

type
  TCoreMvcStartupCreator = class(TInterfacedObject, IOTACreator, IOTAModuleCreator)
  private
    fModuleInfo : TModuleInfo;
  public
    constructor Create(aModuleInfo : TModuleInfo);
    // IOTACreator
    function GetCreatorType: string;
    function GetExisting: Boolean;
    function GetFileSystem: string;
    function GetOwner: IOTAModule;
    function GetUnnamed: Boolean;
    // IOTAModuleCreator
    function GetAncestorName: string;
    function GetImplFileName: string;
    function GetIntfFileName: string;
    function GetFormName: string;
    function GetMainForm: Boolean;
    function GetShowForm: Boolean;
    function GetShowSource: Boolean;
    function NewFormFile(const FormIdent, AncestorIdent: string): IOTAFile;
    function NewImplSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
    function NewIntfSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
    procedure FormCreated(const FormEditor: IOTAFormEditor);
  end;

implementation

uses
  System.SysUtils;

function TCoreMvcStartupCreator.GetCreatorType: string;
begin
  Result := sUnit;
end;

function TCoreMvcStartupCreator.GetExisting: Boolean;
begin
  Result := False;
end;

function TCoreMvcStartupCreator.GetFileSystem: string;
begin
  Result := '';
end;

function TCoreMvcStartupCreator.GetOwner: IOTAModule;
begin
  Result := ActiveProject;
end;

function TCoreMvcStartupCreator.GetUnnamed: Boolean;
begin
  Result := True;
end;

function TCoreMvcStartupCreator.GetAncestorName: string;
begin
  Result := '';
end;

function TCoreMvcStartupCreator.GetImplFileName: string;
begin
  Result := GetCurrentDir + '\' + SStartupFileName + '.pas';
end;

function TCoreMvcStartupCreator.GetIntfFileName: string;
begin
  Result := '';
end;

function TCoreMvcStartupCreator.GetFormName: string;
begin
  Result := '';
end;

function TCoreMvcStartupCreator.GetMainForm: Boolean;
begin
  Result := False;
end;

function TCoreMvcStartupCreator.GetShowForm: Boolean;
begin
  Result := False;
end;

function TCoreMvcStartupCreator.GetShowSource: Boolean;
begin
  Result := True;
end;

function TCoreMvcStartupCreator.NewFormFile(const FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := nil;
end;

function TCoreMvcStartupCreator.NewImplSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := TCoreMvcSourceFile.Create(SStartuprResources,fModuleInfo);
end;

function TCoreMvcStartupCreator.NewIntfSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := nil;
end;

constructor TCoreMvcStartupCreator.Create(aModuleInfo: TModuleInfo);
begin
  fModuleInfo := aModuleInfo;
end;

procedure TCoreMvcStartupCreator.FormCreated(const FormEditor: IOTAFormEditor);
begin

end;


end.
