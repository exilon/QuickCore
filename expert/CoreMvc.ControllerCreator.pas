unit CoreMvc.ControllerCreator;

interface

uses
  CoreMvc.Wizards.Utils,
  ToolsAPI;

resourcestring
  SControllerrResources = 'ControllerTemplate';
  SControllerFileName = 'HomeController';

type
  TCoreMvcControllerCreator = class(TInterfacedObject, IOTACreator, IOTAModuleCreator)
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

function TCoreMvcControllerCreator.GetCreatorType: string;
begin
  Result := sUnit;
end;

function TCoreMvcControllerCreator.GetExisting: Boolean;
begin
  Result := False;
end;

function TCoreMvcControllerCreator.GetFileSystem: string;
begin
  Result := '';
end;

function TCoreMvcControllerCreator.GetOwner: IOTAModule;
begin
  Result := ActiveProject;
end;

function TCoreMvcControllerCreator.GetUnnamed: Boolean;
begin
  Result := True;
end;

function TCoreMvcControllerCreator.GetAncestorName: string;
begin
  Result := '';
end;

function TCoreMvcControllerCreator.GetImplFileName: string;
begin
  Result := GetCurrentDir + '\' + SControllerFileName + '.pas';
end;

function TCoreMvcControllerCreator.GetIntfFileName: string;
begin
  Result := '';
end;

function TCoreMvcControllerCreator.GetFormName: string;
begin
  Result := '';
end;

function TCoreMvcControllerCreator.GetMainForm: Boolean;
begin
  Result := False;
end;

function TCoreMvcControllerCreator.GetShowForm: Boolean;
begin
  Result := False;
end;

function TCoreMvcControllerCreator.GetShowSource: Boolean;
begin
  Result := True;
end;

function TCoreMvcControllerCreator.NewFormFile(const FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := nil;
end;

function TCoreMvcControllerCreator.NewImplSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := TCoreMvcSourceFile.Create(SControllerrResources,fModuleInfo);
end;

function TCoreMvcControllerCreator.NewIntfSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := nil;
end;

constructor TCoreMvcControllerCreator.Create(aModuleInfo : TModuleInfo);
begin
  fModuleInfo := aModuleInfo;
end;

procedure TCoreMvcControllerCreator.FormCreated(const FormEditor: IOTAFormEditor);
begin

end;


end.
