{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Mvc.Middleware.Compression
  Description : Core Mvc Response Compression Middleware
  Author      : Kike Perez
  Version     : 1.0
  Created     : 14/04/2026
  Modified    : 08/05/2026

  This file is part of QuickCore: https://github.com/exilon/QuickCore

 ***************************************************************************

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

 *************************************************************************** }

unit Quick.Core.Mvc.Middleware.Compression;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.ZLib,
  Quick.Options,
  Quick.Core.Mvc.Middleware,
  Quick.Core.Mvc.Context;

type
  TCompressionEncoding = (ceGzip, ceDeflate);

  TCompressionOptions = class(TOptions)
  private
    fMinimumBytes    : Integer;
    fCompressedMIMEs : TArray<string>;
  public
    constructor Create; override;
    function AddMimeType(const aMimeType : string) : TCompressionOptions;
    /// <summary>Minimum response size in bytes to apply compression (default: 860).</summary>
    property MinimumBytes : Integer read fMinimumBytes write fMinimumBytes;
    /// <summary>MIME types that will be compressed.</summary>
    property CompressedMIMEs : TArray<string> read fCompressedMIMEs write fCompressedMIMEs;
  end;

  TCompressionMiddleware = class(TRequestDelegate)
  private
    fOptions : TCompressionOptions;
    function AcceptedEncoding(const aAcceptEncoding : string; out aEncoding : TCompressionEncoding) : Boolean;
    function ShouldCompress(const aContentType : string; aContentLen : Integer) : Boolean;
    function CompressGzip(const aInput : TBytes) : TBytes;
    function CompressDeflate(const aInput : TBytes) : TBytes;
  public
    constructor Create(aNext : TRequestDelegate; aOptions : IOptions<TCompressionOptions>);
    destructor Destroy; override;
    procedure Invoke(aContext : THttpContextBase); override;
  end;

implementation

{ TCompressionOptions }

constructor TCompressionOptions.Create;
begin
  inherited;
  fMinimumBytes := 860;
  fCompressedMIMEs := [
    'text/plain',
    'text/html',
    'text/css',
    'text/javascript',
    'application/json',
    'application/javascript',
    'application/xml',
    'text/xml',
    'image/svg+xml'
  ];
end;

function TCompressionOptions.AddMimeType(const aMimeType : string) : TCompressionOptions;
begin
  fCompressedMIMEs := fCompressedMIMEs + [aMimeType.ToLower];
  Result := Self;
end;

{ TCompressionMiddleware }

constructor TCompressionMiddleware.Create(aNext : TRequestDelegate; aOptions : IOptions<TCompressionOptions>);
begin
  inherited Create(aNext);
  if aOptions <> nil then
    fOptions := aOptions.Value
  else
    fOptions := TCompressionOptions.Create;
end;

destructor TCompressionMiddleware.Destroy;
begin
  inherited;
end;

function TCompressionMiddleware.AcceptedEncoding(const aAcceptEncoding : string; out aEncoding : TCompressionEncoding) : Boolean;
var
  lower : string;
begin
  lower := aAcceptEncoding.ToLower;
  if lower.Contains('gzip') then
  begin
    aEncoding := ceGzip;
    Exit(True);
  end;
  if lower.Contains('deflate') then
  begin
    aEncoding := ceDeflate;
    Exit(True);
  end;
  Result := False;
end;

function TCompressionMiddleware.ShouldCompress(const aContentType : string; aContentLen : Integer) : Boolean;
var
  mime    : string;
  allowed : string;
  lct     : string;
begin
  Result := False;
  if aContentLen < fOptions.MinimumBytes then Exit;
  // Extract base MIME type (strip charset suffix)
  lct := aContentType.ToLower;
  if lct.Contains(';') then
    mime := Trim(lct.Substring(0, lct.IndexOf(';')))
  else
    mime := Trim(lct);
  for allowed in fOptions.CompressedMIMEs do
    if SameText(allowed, mime) then Exit(True);
end;

function TCompressionMiddleware.CompressGzip(const aInput : TBytes) : TBytes;
var
  inStream  : TBytesStream;
  outStream : TBytesStream;
  gzipStr   : TZCompressionStream;
begin
  inStream  := TBytesStream.Create(aInput);
  outStream := TBytesStream.Create;
  try
    gzipStr := TZCompressionStream.Create(outStream, zcDefault, 31);
    try
      gzipStr.CopyFrom(inStream, 0);
    finally
      gzipStr.Free;
    end;
    Result := outStream.Bytes;
    SetLength(Result, outStream.Size);
  finally
    inStream.Free;
    outStream.Free;
  end;
end;

function TCompressionMiddleware.CompressDeflate(const aInput : TBytes) : TBytes;
var
  inStream  : TBytesStream;
  outStream : TBytesStream;
  deflStr   : TZCompressionStream;
begin
  inStream  := TBytesStream.Create(aInput);
  outStream := TBytesStream.Create;
  try
    deflStr := TZCompressionStream.Create(outStream, zcDefault, 15);
    try
      deflStr.CopyFrom(inStream, 0);
    finally
      deflStr.Free;
    end;
    Result := outStream.Bytes;
    SetLength(Result, outStream.Size);
  finally
    inStream.Free;
    outStream.Free;
  end;
end;

procedure TCompressionMiddleware.Invoke(aContext : THttpContextBase);
var
  acceptEncoding : string;
  encoding       : TCompressionEncoding;
  contentType    : string;
  contentText    : string;
  inputBytes     : TBytes;
  compressed     : TBytes;
  contentStream  : TBytesStream;
begin
  inherited; // calls Next(aContext)

  // Only compress if client advertises Accept-Encoding
  acceptEncoding := aContext.Request.Headers.GetValue('Accept-Encoding');
  if acceptEncoding = '' then Exit;
  if not AcceptedEncoding(acceptEncoding, encoding) then Exit;

  contentType  := aContext.Response.Headers.GetValue('Content-Type');
  contentText  := aContext.Response.ContentText;
  if contentText = '' then Exit;

  // Convert text to UTF-8 bytes to measure / compress
  inputBytes := TEncoding.UTF8.GetBytes(contentText);
  if not ShouldCompress(contentType, Length(inputBytes)) then Exit;

  // Compress
  case encoding of
    ceGzip    : compressed := CompressGzip(inputBytes);
    ceDeflate : compressed := CompressDeflate(inputBytes);
  else
    Exit;
  end;

  // Write compressed bytes into response Content stream (server takes ownership)
  contentStream := TBytesStream.Create(compressed);
  aContext.Response.Content := contentStream;
  aContext.Response.ContentText := ''; // clear text so server uses stream

  // Set compression headers
  case encoding of
    ceGzip    : aContext.Response.Headers.Add('Content-Encoding', 'gzip');
    ceDeflate : aContext.Response.Headers.Add('Content-Encoding', 'deflate');
  end;
  aContext.Response.Headers.Add('Vary', 'Accept-Encoding');
end;

end.
