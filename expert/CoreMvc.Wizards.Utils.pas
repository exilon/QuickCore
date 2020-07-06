unit CoreMvc.Wizards.Utils;

interface

uses
  System.Types,
  System.SysUtils,
	System.Classes,
  ToolsAPI,
  Quick.Commons;

type
  TModuleInfo = record
    ProjectName : string;
    ModuleName : string;
    UsesClause : TArray<string>;
    VarDeclar : TArray<string>;
    CodePart1 : TArray<string>;
    CodePart2 : TArray<string>;
    InitSection : TArray<string>;
    FinalizeSection : TArray<string>;
  end;

  TCoreMvcSourceFile = class(TInterfacedObject, IOTAFile)
  strict private
    fResourceName: string;
    fModuleInfo : TModuleInfo;
  strict protected
    property ResourceName: string read fResourceName;
  public
    constructor Create(const aResourceName: string; aModuleInfo : TModuleInfo);
    function GetAge: TDateTime; virtual;
    function GetSource: string; virtual;
  end;

  TProjectType = (ptMVCServer, ptWebApi);

  TProjectWizardInfo = record
    ProjectName : string;
    ProjectType : TProjectType;
    ControllerInfo : TModuleInfo;
    StartupInfo : TModuleInfo;
  end;

  function ActiveProjectGroup: IOTAProjectGroup;
  function ActiveProject: IOTAProject;
  function ProjectModule(const Project: IOTAProject): IOTAModule;
  function ActiveSourceEditor: IOTASourceEditor;
  function SourceEditor(const Module: IOTAModule): IOTASourceEditor;
  function EditorAsString(const SourceEditor: IOTASourceEditor): string;

implementation

function ActiveProjectGroup: IOTAProjectGroup;
var
  I: Integer;
  AModuleServices: IOTAModuleServices;
  AModule: IOTAModule;
  AProjectGroup: IOTAProjectGroup;
begin
  Result := NIL;
  AModuleServices := BorlandIDEServices as IOTAModuleServices;
  for I := 0 to AModuleServices.ModuleCount - 1 do
  begin
    AModule := AModuleServices.Modules[I];
    if AModule.QueryInterface(IOTAProjectGroup, AProjectGroup) = S_OK then
      Break;
  end;
  Result := AProjectGroup;
end;

function ActiveProject: IOTAProject;
var
  PG: IOTAProjectGroup;
begin
  PG := ActiveProjectGroup;
  if PG <> NIL then
    Result := PG.ActiveProject;
end;

function ProjectModule(const Project: IOTAProject): IOTAModule;
var
  I: Integer;
  AModuleServices: IOTAModuleServices;
  AModule: IOTAModule;
  AProject: IOTAProject;
begin
  Result := NIL;
  AModuleServices := BorlandIDEServices as IOTAModuleServices;
  for I := 0 to AModuleServices.ModuleCount - 1 do
  begin
    AModule := AModuleServices.Modules[I];
    if (AModule.QueryInterface(IOTAProject, AProject) = S_OK) and (Project = AProject) then
      Break;
  end;
  Result := AProject;
end;

function SourceEditor(const Module: IOTAModule): IOTASourceEditor;
var
  I, LFileCount: Integer;
begin
  Result := NIL;
  if Module = NIL then
    Exit;

  LFileCount := Module.GetModuleFileCount;
  for I := 0 to LFileCount - 1 do
  begin
    if Module.GetModuleFileEditor(I).QueryInterface(IOTASourceEditor, Result) = S_OK then
      Break;
  end;
end;

function ActiveSourceEditor: IOTASourceEditor;
var
  CM: IOTAModule;
begin
  Result := NIL;
  if BorlandIDEServices = NIL then
    Exit;

  CM := (BorlandIDEServices as IOTAModuleServices).CurrentModule;
  Result := SourceEditor(CM);
end;

function EditorAsString(const SourceEditor: IOTASourceEditor): string;
Const
  iBufferSize: Integer = 1024;
var
  Reader: IOTAEditReader;
  iPosition, iRead: Integer;
  strBuffer: AnsiString;
begin
  Result := '';
  Reader := SourceEditor.CreateReader;
  try
    iPosition := 0;
    repeat
      SetLength(strBuffer, iBufferSize);
      iRead := Reader.GetText(iPosition, PAnsiChar(strBuffer), iBufferSize);
      SetLength(strBuffer, iRead);
      Result := Result + string(strBuffer);
      Inc(iPosition, iRead);
    until iRead < iBufferSize;
  finally
    Reader := NIL;
  end;
end;

{$REGION 'TWiRLSourceFile'}

constructor TCoreMvcSourceFile.Create(const aResourceName: string; aModuleInfo : TModuleInfo);
begin
  inherited Create;
  fResourceName := aResourceName;
  fModuleInfo := aModuleInfo;
end;

function TCoreMvcSourceFile.GetAge: TDateTime;
begin
  Result := -1;
end;

function TCoreMvcSourceFile.GetSource: string;
var
  Res: TResourceStream;
  S: TStrings;
begin
  Res := TResourceStream.Create(HInstance, ResourceName, RT_RCDATA);
  try
    if Res.Size = 0 then
      raise Exception.CreateFmt('Resource %s is empty', [ResourceName]);

    S := TStringList.Create;
    try
      Res.Position := 0;
      S.LoadFromStream(Res);
      Result := s.Text;
      Result := StringReplace(Result,'{%PROJECTNAME%}',fModuleInfo.ProjectName,[rfIgnoreCase,rfReplaceAll]);
      Result := StringReplace(Result,'{%MODULENAME%}',fModuleInfo.ModuleName,[rfIgnoreCase,rfReplaceAll]);
      Result := StringReplace(Result,'{%USES%}',CommaText(fModuleInfo.UsesClause),[rfIgnoreCase,rfReplaceAll]);
      Result := StringReplace(Result,'{%VAR%}',CommaText(fModuleInfo.VarDeclar),[rfIgnoreCase,rfReplaceAll]);
      Result := StringReplace(Result,'{%CODE1%}',ArrayToString(fModuleInfo.CodePart1),[rfIgnoreCase,rfReplaceAll]);
      Result := StringReplace(Result,'{%CODE2%}',ArrayToString(fModuleInfo.CodePart2),[rfIgnoreCase,rfReplaceAll]);
      Result := StringReplace(Result,'{%INITIALIZATION%}',ArrayToString(fModuleInfo.InitSection),[rfIgnoreCase,rfReplaceAll]);
      Result := StringReplace(Result,'{%FINALIZATION%}',ArrayToString(fModuleInfo.FinalizeSection),[rfIgnoreCase,rfReplaceAll]);
    finally
      S.Free;
    end;
  finally
    Res.Free;
  end;
end;

{$ENDREGION}

end.
