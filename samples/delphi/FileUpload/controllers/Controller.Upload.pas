unit Controller.Upload;

{ FileUpload Sample - S-31
  Demonstrates multipart/form-data file upload.

  Client sends: POST /api/upload  with multipart body, field "file"
  Server parses TUploadedFile, saves to ./uploads/, returns JSON with metadata. }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Mvc.Context,
  Quick.Core.Mvc.Middleware.Swagger;

type
  [Route('api')]
  [ApiController]
  TUploadController = class(THttpController)
  public
    constructor Create;
  published
    /// POST /api/upload — upload one file
    [HttpPost('upload')]
    [SwaggerOperation('Upload a file', 'Accepts multipart/form-data with field name "file".', 'Uploads')]
    [ProducesResponseType(200, 'Upload metadata JSON')]
    [ProducesResponseType(400, 'No file received or file is empty')]
    function Upload([FromForm('file')] aFile : TUploadedFile) : IActionResult;

    /// GET /api/upload/list — list previously uploaded files
    [HttpGet('upload/list')]
    [SwaggerOperation('List uploaded files', 'Returns uploaded file names and sizes from ./uploads.', 'Uploads')]
    [ProducesResponseType(200, 'Array of uploaded files')]
    function List : IActionResult;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils;

const
  UPLOAD_DIR = '.\uploads';

{ TUploadController }

constructor TUploadController.Create;
begin
  inherited Create;
  if not TDirectory.Exists(UPLOAD_DIR) then
    TDirectory.CreateDirectory(UPLOAD_DIR);
end;

function TUploadController.Upload(aFile : TUploadedFile) : IActionResult;
var
  destPath : string;
  safeName : string;
begin
  if aFile = nil then
    Exit(BadRequest('No file received'));
  if aFile.Size = 0 then
    Exit(BadRequest('File is empty'));

  // Sanitize filename — strip path separators
  safeName := TPath.GetFileName(aFile.FileName);
  if safeName = '' then
    safeName := 'upload_' + FormatDateTime('yyyymmdd_hhnnss', Now);

  destPath := TPath.Combine(UPLOAD_DIR, safeName);
  TFile.WriteAllBytes(destPath, aFile.Data);

  Result := Json(Format(
    '{"success":true,"fileName":"%s","originalName":"%s","size":%d,"contentType":"%s","savedTo":"%s"}',
    [safeName, aFile.FileName, aFile.Size, aFile.ContentType,
     destPath.Replace('\', '\\')]));
end;

function TUploadController.List : IActionResult;
var
  files   : TArray<string>;
  sb      : TStringBuilder;
  first   : Boolean;
  f       : string;
  fs      : TFileStream;
  size    : Int64;
begin
  sb    := TStringBuilder.Create;
  first := True;
  try
    sb.Append('{"files":[');
    if TDirectory.Exists(UPLOAD_DIR) then
    begin
      files := TDirectory.GetFiles(UPLOAD_DIR);
      for f in files do
      begin
        if not first then sb.Append(',');
        size := 0;
        fs   := TFileStream.Create(f, fmOpenRead or fmShareDenyNone);
        try
          size := fs.Size;
        finally
          fs.Free;
        end;
        sb.Append(Format('{"name":"%s","size":%d}',
          [TPath.GetFileName(f), size]));
        first := False;
      end;
    end;
    sb.Append(']}');
    Result := Json(sb.ToString);
  finally
    sb.Free;
  end;
end;

initialization
  RegisterController(TUploadController);

end.
