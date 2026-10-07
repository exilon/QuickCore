{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Extensions.HealthChecks.RabbitMQ
  Description : Core Extensions RabbitMQ Health Check (AMQP 0-9-1)
  Author      : Kike Perez
  Version     : 1.0
  Created     : 29/04/2026
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

unit Quick.Core.Extensions.HealthChecks.RabbitMQ;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.TimeSpan,
  IdTCPClient,
  IdGlobal,
  Quick.Options,
  Quick.Core.DependencyInjection,
  Quick.Core.Extensions.HealthChecks;

type
  TRabbitMQHealthCheckOptions = class(TOptions)
  private
    fHost : string;
    fPort : Integer;
    fConnectionTimeout : Integer;
    fReadTimeout : Integer;
  public
    constructor Create; override;
  published
    property Host : string read fHost write fHost;
    property Port : Integer read fPort write fPort;
    property ConnectionTimeout : Integer read fConnectionTimeout write fConnectionTimeout;
    property ReadTimeout : Integer read fReadTimeout write fReadTimeout;
  end;

  TRabbitMQHealthCheck = class(THealthCheck)
  private
    fHost : string;
    fPort : Integer;
    fConnectionTimeout : Integer;
    fReadTimeout : Integer;
  public
    constructor Create(aOptions : TRabbitMQHealthCheckOptions; aTimeSpan : TTimeSpan);
    function GetCheckKind : string; override;
    function GetTags : string; override;
    procedure Check; override;
  end;

  TRabbitMQHealthChecksExtension = class(THealthChecksExtension)
    class function AddRabbitMQCheck(const aName : string; aOptionsProc : TConfigureOptionsProc<TRabbitMQHealthCheckOptions>; aTimeSpan : TTimeSpan) : THealthChecksService;
  end;

implementation

{ TRabbitMQHealthCheckOptions }

constructor TRabbitMQHealthCheckOptions.Create;
begin
  inherited;
  fHost := 'localhost';
  fPort := 5672;
  fConnectionTimeout := 3000;
  fReadTimeout := 3000;
end;

{ TRabbitMQHealthCheck }

constructor TRabbitMQHealthCheck.Create(aOptions : TRabbitMQHealthCheckOptions; aTimeSpan : TTimeSpan);
begin
  inherited Create(aTimeSpan);
  fName := 'RabbitMQ';
  fHost := aOptions.Host;
  fPort := aOptions.Port;
  fConnectionTimeout := aOptions.ConnectionTimeout;
  fReadTimeout := aOptions.ReadTimeout;
end;

function TRabbitMQHealthCheck.GetCheckKind: string;
begin
  Result := 'rabbitmq';
end;

function TRabbitMQHealthCheck.GetTags: string;
begin
  Result := Format('{"host":"%s","port":%d}',[fHost, fPort]);
end;

procedure TRabbitMQHealthCheck.Check;
var
  client : TIdTCPClient;
  header : TIdBytes;
  response : TIdBytes;
begin
  inherited;
  client := TIdTCPClient.Create(nil);
  try
    client.Host := fHost;
    client.Port := fPort;
    client.ConnectTimeout := fConnectionTimeout;
    client.Connect;
    try
      client.IOHandler.ReadTimeout := fReadTimeout;
      // Send AMQP 0-9-1 protocol header: 'AMQP' + 0x00 0x00 0x09 0x01
      SetLength(header, 8);
      header[0] := $41; // 'A'
      header[1] := $4D; // 'M'
      header[2] := $51; // 'Q'
      header[3] := $50; // 'P'
      header[4] := $00;
      header[5] := $00;
      header[6] := $09; // major
      header[7] := $01; // minor
      client.IOHandler.Write(header);
      // Read first 7 bytes: frame-type (1) + channel (2) + payload-size (4)
      // Frame type 1 = method frame (Connection.Start expected)
      SetLength(response, 0);
      client.IOHandler.ReadBytes(response, 7, False);
      if Length(response) < 7 then
        raise Exception.Create('No response received from RabbitMQ server');
      if response[0] <> 1 then
        raise Exception.CreateFmt('Unexpected AMQP frame type %d from "%s:%d"; expected 1 (method frame)',
          [response[0], fHost, fPort]);
    finally
      if client.Connected then client.Disconnect;
    end;
  finally
    client.Free;
  end;
end;

{ TRabbitMQHealthChecksExtension }

class function TRabbitMQHealthChecksExtension.AddRabbitMQCheck(const aName : string;
  aOptionsProc : TConfigureOptionsProc<TRabbitMQHealthCheckOptions>;
  aTimeSpan : TTimeSpan) : THealthChecksService;
var
  check : IHealthCheck;
  options : TRabbitMQHealthCheckOptions;
begin
  if not Assigned(aOptionsProc) then raise Exception.Create('RabbitMQOptions param cannot be nil!');
  options := TRabbitMQHealthCheckOptions.Create;
  try
    aOptionsProc(options);
    check := TRabbitMQHealthCheck.Create(options, aTimeSpan);
  finally
    options.Free;
  end;
  check.Name := aName;
  Result := HealthChecksService.AddCheck(check);
end;

end.
