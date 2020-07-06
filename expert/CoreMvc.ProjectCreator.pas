unit CoreMvc.ProjectCreator;

interface

uses
  ToolsAPI,
  PlatformAPI,
  System.SysUtils,
  System.Types,
  System.Classes,
  CoreMvc.Wizards.Utils;

resourcestring
  SCoreMvcProject = 'ProjectTemplate';

type
  TCoreMvcProjectCreator = class(TInterfacedObject, IOTACreator, IOTAProjectCreator50, IOTAProjectCreator80,IOTAProjectCreator160, IOTAProjectCreator)
  private
    fProjectWizardInfo : TProjectWizardInfo;
  public
    constructor Create(aProjectWizardInfo : TProjectWizardInfo);
    // IOTACreator
    function GetCreatorType: string;
    function GetExisting: Boolean;
    function GetFileSystem: string;
    function GetOwner: IOTAModule;
    function GetUnnamed: Boolean;
    // IOTAProjectCreator
    function GetFileName: string;
    function GetOptionFileName: string; deprecated;
    function GetShowSource: Boolean;
    procedure NewDefaultModule; deprecated;
    function NewOptionSource(const ProjectName: string): IOTAFile; deprecated;
    procedure NewProjectResource(const Project: IOTAProject);
    function NewProjectSource(const ProjectName: string): IOTAFile;
    // IOTAProjectCreator50
    procedure NewDefaultProjectModule(const Project: IOTAProject);
    // IOTAProjectCreator80
    function GetProjectPersonality: string;
    // IOTAProjectCreator160
    function GetFrameworkType: string;
    function GetPlatforms: TArray<string>;
    function GetPreferredPlatform: string;
    procedure SetInitialOptions(const NewProject: IOTAProject);
  end;

implementation

uses
  CoreMvc.ControllerCreator,
  CoreMvc.StartupCreator;

constructor TCoreMvcProjectCreator.Create(aProjectWizardInfo: TProjectWizardInfo);
begin
  fProjectWizardInfo := aProjectWizardInfo;
end;

function TCoreMvcProjectCreator.GetCreatorType: string;
begin
  Result := '';
end;

function TCoreMvcProjectCreator.GetExisting: Boolean;
begin
  Result := False;
end;

function TCoreMvcProjectCreator.GetFileSystem: string;
begin
  Result := '';
end;

function TCoreMvcProjectCreator.GetOwner: IOTAModule;
begin
  Result := ActiveProjectGroup;
end;

function TCoreMvcProjectCreator.GetUnnamed: Boolean;
begin
  Result := True;
end;

function TCoreMvcProjectCreator.GetFileName: string;
begin
  Result := GetCurrentDir + '\CoreMVCProject.dpr';
end;

function TCoreMvcProjectCreator.GetOptionFileName: string; deprecated;
begin
  Result := '';
end;

function TCoreMvcProjectCreator.GetShowSource: Boolean;
begin
  Result := True;
end;

function TCoreMvcProjectCreator.NewProjectSource(const ProjectName: string): IOTAFile;
var
  moduleInfo : TModuleInfo;
begin
  moduleInfo.ProjectName := ProjectName;
  Result := TCoreMvcSourceFile.Create(SCoreMvcProject,moduleInfo);
end;

function TCoreMvcProjectCreator.NewOptionSource(const ProjectName: string): IOTAFile; deprecated;
begin
  Result := nil;
end;

procedure TCoreMvcProjectCreator.NewDefaultModule; deprecated;
begin
end;

procedure TCoreMvcProjectCreator.NewProjectResource(const Project: IOTAProject);
begin
end;

procedure TCoreMvcProjectCreator.NewDefaultProjectModule(const Project: IOTAProject);
var
  ms: IOTAModuleServices;
begin
  ms := BorlandIDEServices as IOTAModuleServices;
  ms.CreateModule(TCoreMvcControllerCreator.Create(fProjectWizardInfo.ControllerInfo));
  ms.CreateModule(TCoreMvcStartupCreator.Create(fProjectWizardInfo.StartupInfo));
end;

function TCoreMvcProjectCreator.GetProjectPersonality: string;
begin
  Result := sDelphiPersonality;
end;

function TCoreMvcProjectCreator.GetFrameworkType: string;
begin
  Result := sFrameworkTypeVCL;
end;

function TCoreMvcProjectCreator.GetPlatforms: TArray<string>;
begin
  SetLength(Result, 2);
  Result[0] := cWin32Platform;
  Result[1] := cWin64Platform;
  //Result[2] := cLinux64Platform;
end;

function TCoreMvcProjectCreator.GetPreferredPlatform: string;
begin
  Result := cWin64Platform;
end;

procedure TCoreMvcProjectCreator.SetInitialOptions(const NewProject: IOTAProject);
begin
end;

end.
