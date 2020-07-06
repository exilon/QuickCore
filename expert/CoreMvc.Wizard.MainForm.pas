unit CoreMvc.Wizard.MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  CoreMvc.Wizards.Utils, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.ComCtrls,
  Vcl.Imaging.pngimage, Vcl.CheckLst, Vcl.Buttons;

type
  TfrmProjectWizard = class(TForm)
    btnOk: TButton;
    btnCancel: TButton;
    paBottom: TPanel;
    pageMain: TPageControl;
    tabExtensions: TTabSheet;
    imgLogo: TImage;
    tabServer: TTabSheet;
    Label1: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    edProjectPath: TEdit;
    edProjectName: TEdit;
    btnBrowseProjectPath: TButton;
    cxCreateProjectDirectory: TCheckBox;
    paTitlebar: TPanel;
    paMain: TPanel;
    meProjecTypetInfo: TMemo;
    lvProjectType: TListView;
    lvMiddlewares: TListView;
    lvServices: TListView;
    btnBack: TButton;
    paLogo: TPanel;
    udServices: TUpDown;
    udMiddlewares: TUpDown;
    Label2: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure OnParametersChange(Sender: TObject);
    procedure btnOkClick(Sender: TObject);
    procedure btnBackClick(Sender: TObject);
    procedure udServicesClick(Sender: TObject; Button: TUDBtnType);
    procedure udMiddlewaresClick(Sender: TObject; Button: TUDBtnType);
  private
    { Private declarations }
    fProjectWizardInfo : TProjectWizardInfo;
    procedure ValidateParameters;
    procedure ExchangeItems(lv: TListView; const i, j: Integer);
  public
    { Public declarations }
    class function Execute(var ProjectWizardInfo : TProjectWizardInfo) : Boolean;
  end;

var
  frmProjectWizard: TfrmProjectWizard;

implementation

{$R *.dfm}

procedure TfrmProjectWizard.ExchangeItems(lv: TListView; const i, j: Integer);
var
  tempLI: TListItem;
begin
  lv.Items.BeginUpdate;
  try
    tempLI := TListItem.Create(lv.Items);
    tempLI.Assign(lv.Items.Item[i]);
    lv.Items.Item[i].Assign(lv.Items.Item[j]);
    lv.Items.Item[j].Assign(tempLI);
    tempLI.Free;
  finally
    lv.Items.EndUpdate
  end;
end;

procedure TfrmProjectWizard.OnParametersChange(Sender: TObject);
begin
  ValidateParameters;
end;

procedure TfrmProjectWizard.udMiddlewaresClick(Sender: TObject; Button: TUDBtnType);
var
  idx : Integer;
begin
  idx := lvMiddlewares.ItemIndex;
  if idx = -1 then Exit;
  if (Button = TUDBtnType.btPrev) and (idx >= 0) and (idx < lvMiddlewares.Items.Count - 1) then
  begin
    ExchangeItems(lvMiddlewares,idx, idx + 1);
    lvMiddlewares.Items[idx + 1].Selected := True;
  end
  else
  if (Button = TUDBtnType.btNext) and (idx > 0) and (idx < lvMiddlewares.Items.Count) then
  begin
    ExchangeItems(lvMiddlewares,idx, idx - 1);
    lvMiddlewares.Items[idx - 1].Selected := True;
  end;
end;
procedure TfrmProjectWizard.udServicesClick(Sender: TObject; Button: TUDBtnType);
var
  idx : Integer;
begin
  idx := lvServices.ItemIndex;
  if idx = -1 then Exit;
  if (Button = TUDBtnType.btPrev) and (idx >= 0) and (idx < lvServices.Items.Count - 1) then
  begin
    ExchangeItems(lvServices,idx, idx + 1);
    lvServices.Items[idx + 1].Selected := True;
  end
  else
  if (Button = TUDBtnType.btNext) and (idx > 0) and (idx < lvServices.Items.Count) then
  begin
    ExchangeItems(lvServices,idx, idx - 1);
    lvServices.Items[idx - 1].Selected := True;
  end;
end;

procedure TfrmProjectWizard.btnBackClick(Sender: TObject);
begin
  btnOk.Caption := 'Next';
  pageMain.ActivePage := tabServer;
  btnBack.Visible := False;
end;

procedure TfrmProjectWizard.btnOkClick(Sender: TObject);
begin
  if btnOk.Caption = 'Next' then
  begin
    btnOk.Caption := 'Create';
    pageMain.ActivePage := tabExtensions;
    btnBack.Visible := True;
  end
  else ModalResult := mrOk;
end;

class function TfrmProjectWizard.Execute(var ProjectWizardInfo: TProjectWizardInfo): Boolean;
begin
  Result := False;
  with TfrmProjectWizard.Create(nil) do
  begin
    fProjectWizardInfo := ProjectWizardInfo;
    if ShowModal = mrOk then
    begin
      //set project info
      if cxCreateProjectDirectory.Checked then edProjectPath.Text := edProjectPath.Text + '\' + edProjectName.Text;
      fProjectWizardInfo.ProjectName := edProjectName.Text;
      fProjectWizardInfo.ProjectType := TProjectType(lvProjectType.ItemIndex);
      ForceDirectories(edProjectPath.Text);
      SetCurrentDir(edProjectPath.Text);
      //set startup info
      fProjectWizardInfo.StartupInfo.ModuleName := 'Startup';
      //set controllerinfo
      fProjectWizardInfo.ControllerInfo.ModuleName := 'HomeController2';
      Result := True;
    end;
  end;
end;


procedure TfrmProjectWizard.FormCreate(Sender: TObject);
begin
  pageMain.Pages[0].TabVisible := False;
  pageMain.Pages[1].TabVisible := False;
  pageMain.ActivePage := tabServer;
  lvProjectType.ItemIndex := 0;
  lvServices.Column[2].Width := 0;
  lvMiddlewares.Column[2].Width := 0;
  edProjectPath.Text := GetEnvironmentVariable('BDSPROJECTSDIR');
end;

procedure TfrmProjectWizard.ValidateParameters;
begin
  btnOk.Enabled := (edProjectName.Text <> '') and (edProjectPath.Text <> '');
end;

end.
