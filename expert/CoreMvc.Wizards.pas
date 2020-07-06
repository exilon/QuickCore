unit CoreMvc.Wizards;

interface

uses
  ToolsAPI,
  CoreMvc.Wizards.Utils,
  CoreMvc.Wizard.MainForm;

resourcestring
  SGalleryCategory = 'Quick Core';
  SIDString = 'Quick.Core.Mvc.Wizard.Server';

type
  TCoreMvcProjectWizard = class(TNotifierObject, IOTAWizard, IOTARepositoryWizard, IOTARepositoryWizard60,
    IOTARepositoryWizard80, IOTAProjectWizard, IOTAProjectWizard100)
  private
    fProjectWizardInfo : TProjectWizardInfo;
  public
    constructor Create;
    // IOTAWizard
    procedure Execute;
    procedure AfterSave;
    procedure BeforeSave;
    procedure Destroyed;
    procedure Modified;
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    // IOTARepositoryWizard
    function GetAuthor: string;
    function GetComment: string;
    function GetGlyph: Cardinal;
    function GetPage: string;
    // IOTARepositoryWizard60
    function GetDesigner: string;
    // IOTARepositoryWizard80
    function GetGalleryCategory: IOTAGalleryCategory;
    function GetPersonality: string;
    // IOTAProjectWizard100
    function IsVisible(Project: IOTAProject): Boolean;
  end;

procedure Register;

implementation

uses
  CoreMvc.ProjectCreator;

{ TCoreMvcProjectWizard }

constructor TCoreMvcProjectWizard.Create;
var
  LCategoryServices: IOTAGalleryCategoryManager;
begin
  inherited Create;
  LCategoryServices := BorlandIDEServices as IOTAGalleryCategoryManager;
  LCategoryServices.AddCategory(LCategoryServices.FindCategory(sCategoryRoot), SIDString, SGalleryCategory);
end;

procedure TCoreMvcProjectWizard.Execute;
begin
  if TfrmProjectWizard.Execute(fProjectWizardInfo) then (BorlandIDEServices as IOTAModuleServices).CreateModule(TCoreMvcProjectCreator.Create(fProjectWizardInfo));
end;

function TCoreMvcProjectWizard.GetIDString: string;
begin
  Result := SIDString;
end;

function TCoreMvcProjectWizard.GetName: string;
begin
  Result := 'Quick Core Mvc Wizard';
end;

function TCoreMvcProjectWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

procedure TCoreMvcProjectWizard.AfterSave;
begin
end;

procedure TCoreMvcProjectWizard.BeforeSave;
begin
end;

procedure TCoreMvcProjectWizard.Destroyed;
begin
end;

procedure TCoreMvcProjectWizard.Modified;
begin
end;

function TCoreMvcProjectWizard.GetAuthor: string;
begin
  Result := 'Exilon Soft';
end;

function TCoreMvcProjectWizard.GetComment: string;
begin
  Result := 'Creates a MVC Project';
end;

function TCoreMvcProjectWizard.GetGlyph: Cardinal;
begin
  Result := 0;
end;

function TCoreMvcProjectWizard.GetPage: string;
begin
  Result := SGalleryCategory;
end;

function TCoreMvcProjectWizard.GetDesigner: string;
begin
  Result := dAny;
end;

function TCoreMvcProjectWizard.GetGalleryCategory: IOTAGalleryCategory;
begin
  Result := (BorlandIDEServices as IOTAGalleryCategoryManager).FindCategory(SIDString);
end;

function TCoreMvcProjectWizard.GetPersonality: string;
begin
  Result := sDelphiPersonality;
end;

function TCoreMvcProjectWizard.IsVisible(Project: IOTAProject): Boolean;
begin
  Result := True;
end;

procedure Register;
begin
  RegisterPackageWizard(TCoreMvcProjectWizard.Create);
end;


end.
