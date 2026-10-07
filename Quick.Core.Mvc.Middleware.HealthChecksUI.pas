{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Mvc.Middleware.HealthChecksUI
  Description : HealthChecks HTML dashboard UI
  Author      : Kike Perez
  Version     : 1.0
  Created     : 30/04/2026
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

unit Quick.Core.Mvc.Middleware.HealthChecksUI;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.IOUtils,
  Quick.Core.Extensions.HealthChecks,
  Quick.Core.Mvc,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Mvc.Extensions.HealthChecks;

type
  THealthChecksUIOptions = class
  private
    fTitle : string;
    fFullWidth : Boolean;
    fFullWidthHeader : Boolean;
    fShowEndpoints : Boolean;
    fDefaultTheme : string;
    fAutoRefreshMs : Integer;
    fShowThemeToggle : Boolean;
    fShowRefreshControls : Boolean;
    fShowFooter : Boolean;
    fMaxContentWidth : Integer;
    fCenterHeaderContent : Boolean;
  public
    constructor Create;
    property Title : string read fTitle write fTitle;
    // When True, page content stretches to full browser width. Default: False (centered)
    property FullWidth : Boolean read fFullWidth write fFullWidth;
    // When True, header stretches to full browser width. Default: True
    property FullWidthHeader : Boolean read fFullWidthHeader write fFullWidthHeader;
    // When True and FullWidthHeader=True, the header bar is full-width but its inner content is centered up to MaxContentWidth. Default: False
    property CenterHeaderContent : Boolean read fCenterHeaderContent write fCenterHeaderContent;
    // When True, shows the health endpoint URLs in the footer. Default: False
    property ShowEndpoints : Boolean read fShowEndpoints write fShowEndpoints;
    // Initial color theme: 'dark' or 'light'. User can still toggle unless ShowThemeToggle=False. Default: 'dark'
    property DefaultTheme : string read fDefaultTheme write fDefaultTheme;
    // Default auto-refresh interval in milliseconds. Default: 10000
    property AutoRefreshMs : Integer read fAutoRefreshMs write fAutoRefreshMs;
    // When False, hides the Light/Dark toggle button. Default: True
    property ShowThemeToggle : Boolean read fShowThemeToggle write fShowThemeToggle;
    // When False, hides the auto-refresh interval buttons. Default: True
    property ShowRefreshControls : Boolean read fShowRefreshControls write fShowRefreshControls;
    // When False, hides the entire footer. Default: True
    property ShowFooter : Boolean read fShowFooter write fShowFooter;
    // Max content width in pixels when FullWidth=False. Default: 1280
    property MaxContentWidth : Integer read fMaxContentWidth write fMaxContentWidth;
  end;

  THealthChecksUIMVCServerExtension = class(TMVCServerExtension)
    class function UseHealthChecksUI : TMVCServer; overload;
    class function UseHealthChecksUI(aConfigureOptions : TProc<THealthChecksUIOptions>) : TMVCServer; overload;
  end;

  [Route('healthui')]
  THealthChecksUIController = class(THttpController)
  published
    [HttpGet]
    function Index : IActionResult;
  end;

var
  GHealthChecksUITitle            : string  = '';
  GHealthChecksUIFullWidth        : Boolean = False;
  GHealthChecksUIFullWidthHeader  : Boolean = True;
  GHealthChecksUIShowEndpoints    : Boolean = False;
  GHealthChecksUIDefaultTheme     : string  = 'dark';
  GHealthChecksUIAutoRefreshMs    : Integer = 10000;
  GHealthChecksUIShowThemeToggle  : Boolean = True;
  GHealthChecksUIShowRefreshCtrl  : Boolean = True;
  GHealthChecksUIShowFooter       : Boolean = True;
  GHealthChecksUIMaxContentWidth      : Integer = 1280;
  GHealthChecksUICenterHeaderContent  : Boolean = False;

implementation

{ THealthChecksUIOptions }

constructor THealthChecksUIOptions.Create;
begin
  inherited;
  fFullWidthHeader     := True;
  fFullWidth           := False;
  fShowEndpoints       := False;
  fDefaultTheme        := 'dark';
  fAutoRefreshMs       := 10000;
  fShowThemeToggle     := True;
  fShowRefreshControls  := True;
  fShowFooter           := True;
  fMaxContentWidth      := 1280;
  fCenterHeaderContent  := False;
end;

class function THealthChecksUIMVCServerExtension.UseHealthChecksUI : TMVCServer;
begin
  Result := UseHealthChecksUI(nil);
end;

class function THealthChecksUIMVCServerExtension.UseHealthChecksUI(aConfigureOptions : TProc<THealthChecksUIOptions>) : TMVCServer;
var
  opts : THealthChecksUIOptions;
begin
  Result := MVCServer;
  opts := THealthChecksUIOptions.Create;
  try
    if Assigned(aConfigureOptions) then aConfigureOptions(opts);
    if opts.Title.Trim.IsEmpty then
      GHealthChecksUITitle := TPath.GetFileNameWithoutExtension(ParamStr(0)) + ' HealthChecks'
    else
      GHealthChecksUITitle := opts.Title;
    GHealthChecksUIFullWidth       := opts.FullWidth;
    GHealthChecksUIFullWidthHeader := opts.FullWidthHeader;
    GHealthChecksUIShowEndpoints   := opts.ShowEndpoints;
    GHealthChecksUIDefaultTheme    := opts.DefaultTheme;
    GHealthChecksUIAutoRefreshMs   := opts.AutoRefreshMs;
    GHealthChecksUIShowThemeToggle := opts.ShowThemeToggle;
    GHealthChecksUIShowRefreshCtrl := opts.ShowRefreshControls;
    GHealthChecksUIShowFooter      := opts.ShowFooter;
    GHealthChecksUIMaxContentWidth     := opts.MaxContentWidth;
    GHealthChecksUICenterHeaderContent := opts.CenterHeaderContent;
  finally
    opts.Free;
  end;
  if MVCServer.Services.IsRegistered<IHealthChecksService>('') then
  begin
    MVCServer.Extension<THealthChecksMVCServerExtension>.UseHealthChecks;
    MVCServer.AddController(THealthChecksUIController);
  end
  else raise Exception.Create('HealthChecks dependency not found. Need to be added before!');
end;

function THealthChecksUIController.Index : IActionResult;
var
  html : TStringBuilder;
begin
  html := TStringBuilder.Create;
  try
    html.AppendLine('<!DOCTYPE html>');
    html.AppendLine('<html lang="en">');
    html.AppendLine('<head>');
    html.AppendLine('  <meta charset="utf-8">');
    html.AppendLine('  <meta name="viewport" content="width=device-width, initial-scale=1">');
    html.AppendLine('  <title>' + GHealthChecksUITitle + '</title>');
    html.AppendLine('  <style>');
    html.AppendLine('    :root { --bg:#1a1f2e; --panel:#252b3b; --panel2:#2d3447; --line:rgba(255,255,255,0.08); --ink:#e2e8f0; --muted:#94a3b8; --healthy:#10b981; --degraded:#f59e0b; --unhealthy:#ef4444; --shadow:0 4px 24px rgba(0,0,0,0.4); --body-bg:#1a1f2e; --badge-bg:rgba(255,255,255,0.07); --accent:#6366f1; }');
    html.AppendLine('    [data-theme="light"] { --bg:#f1f5f9; --panel:#ffffff; --panel2:#f8fafc; --line:rgba(0,0,0,0.08); --ink:#1e293b; --muted:#64748b; --healthy:#059669; --degraded:#d97706; --unhealthy:#dc2626; --shadow:0 4px 24px rgba(0,0,0,0.1); --body-bg:#f1f5f9; --badge-bg:rgba(0,0,0,0.04); --accent:#4f46e5; }');
    html.AppendLine('    * { box-sizing: border-box; margin: 0; }');
    html.AppendLine('    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; color: var(--ink); background: var(--body-bg); min-height: 100vh; transition: background 0.3s, color 0.3s; }');
    html.AppendLine('    .app-header { background: var(--panel); border: 1px solid var(--line); padding: 0 24px; display: flex; align-items: center; height: 60px; gap: 16px; position: sticky; top: 0; z-index: 100; box-shadow: var(--shadow); }');
    html.AppendLine('    .header-brand { display: flex; align-items: center; gap: 10px; font-size: 17px; font-weight: 700; color: var(--ink); white-space: nowrap; }');
    html.AppendLine('    .brand-icon { width: 30px; height: 30px; background: var(--accent); border-radius: 7px; display: flex; align-items: center; justify-content: center; color: #fff; font-size: 15px; font-weight: 900; flex-shrink: 0; }');
    html.AppendLine('    .header-spacer { flex: 1; }');
    html.AppendLine('    .header-right { display: flex; align-items: center; gap: 10px; flex-shrink: 0; }');
    html.AppendLine('    .updated-label { font-size: 12px; color: var(--muted); white-space: nowrap; }');
    if GHealthChecksUIFullWidth then
      html.AppendLine('    .page { width: 100%; padding: 24px 32px 48px; box-sizing: border-box; }')
    else
      html.AppendLine('    .page { max-width: ' + IntToStr(GHealthChecksUIMaxContentWidth) + 'px; margin: 0 auto; padding: 24px 24px 48px; }');
    html.AppendLine('    .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(190px, 1fr)); gap: 14px; margin-bottom: 24px; }');
    html.AppendLine('    .stat-card { background: var(--panel); border: 1px solid var(--line); border-radius: 12px; padding: 18px 20px; display: flex; align-items: center; gap: 14px; box-shadow: var(--shadow); }');
    html.AppendLine('    .stat-icon { width: 44px; height: 44px; border-radius: 10px; display: flex; align-items: center; justify-content: center; font-size: 18px; flex-shrink: 0; }');
    html.AppendLine('    .si-total { background: rgba(99,102,241,0.15); color: #818cf8; }');
    html.AppendLine('    .si-healthy { background: rgba(16,185,129,0.15); color: #34d399; }');
    html.AppendLine('    .si-unhealthy { background: rgba(239,68,68,0.15); color: #f87171; }');
    html.AppendLine('    .si-degraded { background: rgba(245,158,11,0.15); color: #f59e0b; }');
    html.AppendLine('    .stat-info { flex: 1; min-width: 0; }');
    html.AppendLine('    .stat-label { font-size: 11px; color: var(--muted); text-transform: uppercase; letter-spacing: 0.08em; margin-bottom: 6px; }');
    html.AppendLine('    .stat-value { font-size: 30px; font-weight: 700; color: var(--ink); line-height: 1; }');
    html.AppendLine('    .section-head { display: flex; align-items: center; gap: 12px; margin-bottom: 16px; margin-top: 8px; }');
    html.AppendLine('    .section-title { font-size: 18px; font-weight: 700; color: var(--ink); }');
    html.AppendLine('    .badge { display: inline-flex; align-items: center; gap: 6px; padding: 5px 12px; border-radius: 999px; font-size: 13px; font-weight: 600; border: 1px solid transparent; }');
    html.AppendLine('    .badge.healthy { background: rgba(16,185,129,0.12); color: var(--healthy); border-color: rgba(16,185,129,0.25); }');
    html.AppendLine('    .badge.unhealthy { background: rgba(239,68,68,0.12); color: var(--unhealthy); border-color: rgba(239,68,68,0.25); }');
    html.AppendLine('    .badge.pending { background: rgba(148,163,184,0.12); color: var(--muted); border-color: rgba(148,163,184,0.2); }');
    html.AppendLine('    .badge.degraded { background: rgba(245,158,11,0.12); color: var(--degraded); border-color: rgba(245,158,11,0.25); }');
    html.AppendLine('    .theme-btn { background: var(--panel2); border: 1px solid var(--line); border-radius: 8px; padding: 6px 14px; font-size: 12px; cursor: pointer; color: var(--muted); transition: color 0.2s, background 0.2s; white-space: nowrap; }');
    html.AppendLine('    .theme-btn:hover { color: var(--ink); }');
    html.AppendLine('    .dot { width: 8px; height: 8px; border-radius: 50%; background: currentColor; flex-shrink: 0; }');
    html.AppendLine('    .healthy { color: var(--healthy); }');
    html.AppendLine('    .degraded { color: var(--degraded); }');
    html.AppendLine('    .unhealthy { color: var(--unhealthy); }');
    html.AppendLine('    .pending { color: var(--muted); }');
    html.AppendLine('    .tbl-wrap { background: var(--panel); border: 1px solid var(--line); border-radius: 12px; box-shadow: var(--shadow); overflow: hidden; }');
    html.AppendLine('    .hc-table { width: 100%; border-collapse: collapse; font-size: 14px; }');
    html.AppendLine('    .hc-table thead th { padding: 11px 16px; text-align: left; font-size: 11px; text-transform: uppercase; letter-spacing: 0.08em; color: var(--muted); border-bottom: 1px solid var(--line); background: rgba(0,0,0,0.15); font-weight: 600; }');
    html.AppendLine('    .hc-table tbody tr { border-bottom: 1px solid var(--line); transition: background 0.15s; }');
    html.AppendLine('    .hc-table tbody tr:last-child { border-bottom: none; }');
    html.AppendLine('    .hc-table tbody tr:hover { background: rgba(255,255,255,0.03); }');
    html.AppendLine('    .hc-table td { padding: 13px 16px; vertical-align: middle; color: var(--ink); }');
    html.AppendLine('    .hc-table td.td-name { font-weight: 700; font-size: 15px; }');
    html.AppendLine('    .hc-table td.td-detail { color: var(--muted); font-size: 13px; }');
    html.AppendLine('    .hc-table td.td-dur { white-space: nowrap; font-family: monospace; font-size: 13px; color: var(--muted); }');
    html.AppendLine('    .hc-table td.td-next { white-space: nowrap; font-family: monospace; font-size: 13px; color: var(--muted); }');
    html.AppendLine('    .hc-table td.td-trend { white-space: nowrap; }');
    html.AppendLine('    .hc-table td.td-status { text-align: right; white-space: nowrap; }');
    html.AppendLine('    .hc-table td.td-expand { width: 28px; padding: 0 8px 0 14px; cursor: pointer; color: var(--muted); font-size: 12px; user-select: none; }');
    html.AppendLine('    .expand-btn { background: none; border: none; cursor: pointer; color: var(--muted); font-size: 13px; padding: 2px 4px; border-radius: 4px; transition: transform 0.2s; }');
    html.AppendLine('    .expand-btn.open { transform: rotate(90deg); }');
    html.AppendLine('    .hc-history-row td { padding: 0 !important; background: rgba(0,0,0,0.18); }');
    html.AppendLine('    .hc-history-wrap { overflow: hidden; max-height: 0; transition: max-height 0.35s ease; }');
    html.AppendLine('    .hc-history-wrap.open { max-height: 800px; }');
    html.AppendLine('    .hc-history-inner { padding: 10px 16px 14px 16px; }');
    html.AppendLine('    .mini-dots { display: inline-flex; align-items: center; gap: 3px; vertical-align: middle; }');
    html.AppendLine('    .mini-dot { width: 8px; height: 8px; border-radius: 50%; display: inline-block; flex-shrink: 0; }');
    html.AppendLine('    .hc-history-table { width: 100%; border-collapse: collapse; font-size: 12px; }');
    html.AppendLine('    .hc-history-table th { text-align: left; padding: 4px 10px; color: var(--muted); font-weight: 600; border-bottom: 1px solid var(--line); font-size: 11px; text-transform: uppercase; letter-spacing: 0.06em; }');
    html.AppendLine('    .hc-history-table td { padding: 5px 10px; color: var(--ink); border-bottom: 1px solid rgba(128,128,128,0.07); font-family: monospace; }');
    html.AppendLine('    .hc-history-table tr:last-child td { border-bottom: none; }');
    html.AppendLine('    .hc-hist-scroll { max-height:200px; overflow-y:auto; scrollbar-width:thin; scrollbar-color:var(--line) transparent; }');
    html.AppendLine('    .hc-hist-scroll::-webkit-scrollbar { width:5px; }');
    html.AppendLine('    .hc-hist-scroll::-webkit-scrollbar-track { background:transparent; }');
    html.AppendLine('    .hc-hist-scroll::-webkit-scrollbar-thumb { background:var(--line); border-radius:999px; }');
    html.AppendLine('    .hc-hist-scroll::-webkit-scrollbar-thumb:hover { background:var(--muted); }');
    html.AppendLine('    .hc-history-table td.h-err { font-family: sans-serif; color: var(--unhealthy); font-size: 11px; max-width: 400px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }');
    html.AppendLine('    .entry-desc { margin-top: 10px; padding-top: 10px; border-top: 1px solid var(--line); color: var(--muted); }');
    html.AppendLine('    .kind-badge { display: inline-flex; align-items: center; gap: 6px; padding: 3px 10px; border-radius: 999px; font-size: 11px; font-weight: 700; letter-spacing: 0.06em; text-transform: uppercase; background: rgba(128,128,128,0.12); color: var(--muted); border: 1px solid var(--line); flex-shrink: 0; }');
    html.AppendLine('    .tag-chips { display: flex; flex-wrap: wrap; gap: 6px; }');
    html.AppendLine('    .tag-chip { display: inline-flex; gap: 4px; padding: 2px 8px; border-radius: 6px; background: rgba(128,128,128,0.08); border: 1px solid var(--line); color: var(--muted); font-size: 12px; }');
    html.AppendLine('    .tag-chip strong { color: var(--ink); }');
    html.AppendLine('    .footer { margin-top: 24px; font-size: 12px; color: var(--muted); }');
    html.AppendLine('    .refresh-bar { display: flex; align-items: center; gap: 6px; font-size: 12px; color: var(--muted); }');
    html.AppendLine('    .interval-btn { padding: 4px 10px; border-radius: 6px; border: 1px solid var(--line); background: transparent; color: var(--muted); font-size: 12px; cursor: pointer; transition: background 0.15s, color 0.15s; }');
    html.AppendLine('    .interval-btn.active { background: rgba(99,102,241,0.15); color: #818cf8; font-weight: 700; border-color: rgba(99,102,241,0.3); }');
    html.AppendLine('    @keyframes hc-spin { to { transform: rotate(360deg); } }');
    html.AppendLine('    @media (max-width: 700px) { .page { padding: 16px 14px 32px; } .stats-grid { grid-template-columns: 1fr 1fr; } .app-header { padding: 0 14px !important; margin: 0 !important; max-width: 100% !important; border-radius: 0 !important; } .header-right { gap: 6px; } .updated-label { display: none; } }');
    if not GHealthChecksUIFullWidthHeader then
    begin
      var hw := GHealthChecksUIMaxContentWidth - 48;
      html.AppendLine('    .app-header { width: calc(100% - 48px); max-width: ' + IntToStr(hw) + 'px; margin: 8px auto 0; border-radius: 12px; }');
    end;
    if GHealthChecksUIFullWidthHeader and GHealthChecksUICenterHeaderContent then
      html.AppendLine('    .header-inner { display: flex; align-items: center; gap: 16px; width: 100%; max-width: ' + IntToStr(GHealthChecksUIMaxContentWidth) + 'px; margin: 0 auto; }');
    html.AppendLine('  </style>');
    html.AppendLine('</head>');
    if SameText(GHealthChecksUIDefaultTheme, 'light') then
      html.AppendLine('<body data-theme="light">')
    else
      html.AppendLine('<body>');
    html.AppendLine('  <header class="app-header">');
    if GHealthChecksUIFullWidthHeader and GHealthChecksUICenterHeaderContent then
      html.AppendLine('    <div class="header-inner">');
    html.AppendLine('    <div class="header-brand"><div class="brand-icon">&#10003;</div>' + GHealthChecksUITitle + '</div>');
    html.AppendLine('    <div class="header-spacer"></div>');
    html.AppendLine('    <div class="header-right">');
    html.AppendLine('      <span class="updated-label">Updated: <strong id="last-update">--</strong></span>');
    if GHealthChecksUIShowRefreshCtrl then
    begin
      html.AppendLine('      <div class="refresh-bar">');
      html.AppendLine('        <span>Auto:</span>');
      html.AppendLine('        <button class="interval-btn" data-ms="1000" onclick="setRefreshInterval(1000)">1s</button>');
      html.AppendLine('        <button class="interval-btn" data-ms="5000" onclick="setRefreshInterval(5000)">5s</button>');
      html.AppendLine('        <button class="interval-btn" data-ms="10000" onclick="setRefreshInterval(10000)">10s</button>');
      html.AppendLine('        <button class="interval-btn" data-ms="30000" onclick="setRefreshInterval(30000)">30s</button>');
      html.AppendLine('        <button class="interval-btn" data-ms="60000" onclick="setRefreshInterval(60000)">60s</button>');
      html.AppendLine('      </div>');
    end;
    if GHealthChecksUIShowThemeToggle then
      html.AppendLine('      <button class="theme-btn" id="theme-toggle" onclick="toggleTheme()">&#9728; Light</button>');
    html.AppendLine('    </div>');
    if GHealthChecksUIFullWidthHeader and GHealthChecksUICenterHeaderContent then
      html.AppendLine('    </div>');
    html.AppendLine('  </header>');
    html.AppendLine('  <div class="page">');
    html.AppendLine('    <div class="stats-grid">');
    html.AppendLine('      <div class="stat-card"><div class="stat-icon si-total">&#9776;</div><div class="stat-info"><div class="stat-label">Total Checks</div><div class="stat-value" id="stat-total">0</div></div></div>');
    html.AppendLine('      <div class="stat-card"><div class="stat-icon si-healthy">&#10003;</div><div class="stat-info"><div class="stat-label">Healthy</div><div class="stat-value" id="stat-healthy">0</div></div></div>');
    html.AppendLine('      <div class="stat-card"><div class="stat-icon si-unhealthy">&#9888;</div><div class="stat-info"><div class="stat-label">Unhealthy</div><div class="stat-value" id="stat-unhealthy">0</div></div></div>');
    html.AppendLine('      <div class="stat-card"><div class="stat-icon si-degraded">&#9650;</div><div class="stat-info"><div class="stat-label">Degraded</div><div class="stat-value" id="stat-degraded">0</div></div></div>');
    html.AppendLine('    </div>');
    html.AppendLine('    <div class="section-head">');
    html.AppendLine('      <span class="section-title">Health Checks</span>');
    html.AppendLine('      <div id="overall-status" class="badge pending"><span class="dot"></span><span>Loading</span></div>');
    html.AppendLine('    </div>');
    html.AppendLine('    <section id="entries"></section>');
    html.AppendLine('    <div class="footer">');
    if GHealthChecksUIShowEndpoints then
      html.AppendLine('      <div>Endpoints: <strong>/health</strong> &bull; <strong>/health/detail</strong> &bull; <strong>/health/history/{name}</strong> &bull; <strong>/health/ready</strong> &bull; <strong>/health/live</strong></div>');
    html.AppendLine('      <div style="margin-top:10px;padding-top:10px;border-top:1px solid var(--line);display:flex;align-items:center;gap:6px;font-size:11px;">');
    html.AppendLine('        Powered by <strong style="color:var(--ink);">QuickCore</strong> &mdash; <a href="https://github.com/exilon/QuickCore" target="_blank" style="color:var(--accent);text-decoration:none;">github.com/exilon/QuickCore</a>');
    html.AppendLine('      </div>');
    html.AppendLine('    </div>');
    html.AppendLine('  </div>');
    html.AppendLine('  <script>');
    html.AppendLine('    const overall = document.getElementById("overall-status");');
    html.AppendLine('    const lastUpdate = document.getElementById("last-update");');
    html.AppendLine('    const entriesHost = document.getElementById("entries");');
    html.AppendLine('');
    html.AppendLine('    function cssClassFor(status) {');
    html.AppendLine('      const value = (status || "").toLowerCase();');
    html.AppendLine('      if (value === "healthy") return "healthy";');
    html.AppendLine('      if (value === "degraded") return "degraded";');
    html.AppendLine('      if (value === "pending") return "pending";');
    html.AppendLine('      return "unhealthy";');
    html.AppendLine('    }');
    html.AppendLine('');
    html.AppendLine('    function setOverall(status) {');
    html.AppendLine('      const css = cssClassFor(status);');
    html.AppendLine('      overall.className = "badge " + css;');
    html.AppendLine('      overall.innerHTML = "<span class=\"dot\"></span><span>" + status + "</span>";');
    html.AppendLine('    }');
    html.AppendLine('');
    html.AppendLine('    function kindIcon(kind) {');
    html.AppendLine('      const icons = { http:"&#127760;", mysql:"&#128024;", sqlserver:"&#128024;", dbcontext:"&#128024;", redis:"&#9889;", rabbitmq:"&#128007;", disk:"&#128190;", memory:"&#129302;", custom:"&#9881;" };');
    html.AppendLine('      return icons[(kind||"").toLowerCase()] || icons.custom;');
    html.AppendLine('    }');
    html.AppendLine('');
    html.AppendLine('    function renderTags(tags) {');
    html.AppendLine('      if (!tags || typeof tags !== "object") return "";');
    html.AppendLine('      const labelMap = { url:"URL", host:"Host", port:"Port", database:"Database", server:"Server", path:"Path", minFreeGB:"Min Free", maxAllowedMB:"Max Allowed (MB)", password:"***" };');
    html.AppendLine('      const chips = Object.entries(tags).filter(([k]) => k !== "password").map(function([k,v]) {');
    html.AppendLine('        const label = labelMap[k] || k;');
    html.AppendLine('        const display = typeof v === "number" ? v : String(v);');
    html.AppendLine('        return "<span class=\"tag-chip\">" + label + ": <strong>" + display + "</strong></span>";');
    html.AppendLine('      });');
    html.AppendLine('      if (chips.length === 0) return "";');
    html.AppendLine('      return "<div class=\"tag-chips\">" + chips.join("") + "</div>";');
    html.AppendLine('    }');
    html.AppendLine('');
    html.AppendLine('    function nextCheckLabel(entry) {');
    html.AppendLine('      if (!entry.lastCheckUtc || !entry.checkEveryMs) return "--";');
    html.AppendLine('      const last = new Date(entry.lastCheckUtc).getTime();');
    html.AppendLine('      const nextMs = last + entry.checkEveryMs - Date.now();');
    html.AppendLine('      if (nextMs <= 0) return "now";');
    html.AppendLine('      const s = Math.floor(nextMs / 1000);');
    html.AppendLine('      if (s < 60) return s + "s";');
    html.AppendLine('      return Math.floor(s / 60) + "m " + (s % 60) + "s";');
    html.AppendLine('    }');
    html.AppendLine('');
    html.AppendLine('    function renderSparkline(hist) {');
    html.AppendLine('      var dms = hist.map(function(h) { return typeof h.durationMs === "number" ? h.durationMs : 0; });');
    html.AppendLine('      if (dms.length < 2) return "";');
    html.AppendLine('      var TPAD = 8, BPAD = 20;');
    html.AppendLine('      var VW = 300, H = 64;');
    html.AppendLine('      var plotH = H - TPAD - BPAD;');
    html.AppendLine('      var max = Math.max.apply(null, dms); if (max === 0) max = 1;');
    html.AppendLine('      var n = dms.length;');
    html.AppendLine('      function cx(i) { return (i / (n - 1) * VW).toFixed(1); }');
    html.AppendLine('      function cy(v)  { return (TPAD + (1 - v / max) * plotH).toFixed(1); }');
    html.AppendLine('      var axisColor = "rgba(128,128,128,0.25)";');
    html.AppendLine('      var maxLabel = max >= 1000 ? (max / 1000).toFixed(1) + "s" : max.toFixed(0) + "ms";');
    html.AppendLine('      // Y-axis labels SVG (fixed 40px, no stretch)');
    html.AppendLine('      var yAxisSvg =');
    html.AppendLine('        "<svg width=\"40\" height=\"" + H + "\" style=\"flex-shrink:0;overflow:visible\">" +');
    html.AppendLine('          "<text x=\"36\" y=\"" + (TPAD + 4) + "\" text-anchor=\"end\" fill=\"var(--muted)\" style=\"font-size:9px;font-family:monospace\">" + maxLabel + "</text>" +');
    html.AppendLine('          "<text x=\"36\" y=\"" + (TPAD + plotH) + "\" text-anchor=\"end\" fill=\"var(--muted)\" style=\"font-size:9px;font-family:monospace\">0</text>" +');
    html.AppendLine('          "<line x1=\"38\" y1=\"" + TPAD + "\" x2=\"40\" y2=\"" + TPAD + "\" stroke=\"" + axisColor + "\" stroke-width=\"1\"/>" +');
    html.AppendLine('          "<line x1=\"38\" y1=\"" + (TPAD + plotH) + "\" x2=\"40\" y2=\"" + (TPAD + plotH) + "\" stroke=\"" + axisColor + "\" stroke-width=\"1\"/>" +');
    html.AppendLine('          "<line x1=\"40\" y1=\"" + TPAD + "\" x2=\"40\" y2=\"" + (TPAD + plotH) + "\" stroke=\"" + axisColor + "\" stroke-width=\"1\"/>" +');
    html.AppendLine('        "</svg>";');
    html.AppendLine('      // Chart SVG: full-width, no circles (preserveAspectRatio=none distorts circles)');
    html.AppendLine('      var poly = "";');
    html.AppendLine('      for (var i = 0; i < n - 1; i++) {');
    html.AppendLine('        var st0 = hist[i] ? (hist[i].status || "") : "";');
    html.AppendLine('        var sc = st0 === "Unhealthy" ? "var(--unhealthy)" : st0 === "Degraded" ? "var(--degraded)" : "var(--healthy)";');
    html.AppendLine('        poly += "<line x1=\"" + cx(i) + "\" y1=\"" + cy(dms[i]) + "\" x2=\"" + cx(i+1) + "\" y2=\"" + cy(dms[i+1]) + "\" stroke=\"" + sc + "\" stroke-width=\"1.5\" stroke-linecap=\"round\"/>";');
    html.AppendLine('      }');
    html.AppendLine('      var xAxis = "<line x1=\"0\" y1=\"" + (TPAD + plotH) + "\" x2=\"" + VW + "\" y2=\"" + (TPAD + plotH) + "\" stroke=\"" + axisColor + "\" stroke-width=\"1\"/>";');
    html.AppendLine('      var chartSvg =');
    html.AppendLine('        "<svg viewBox=\"0 0 " + VW + " " + H + "\" preserveAspectRatio=\"none\" style=\"position:absolute;top:0;left:0;width:100%;height:" + H + "px;overflow:visible\">" +');
    html.AppendLine('          xAxis + poly +');
    html.AppendLine('        "</svg>";');
    html.AppendLine('      // HTML dots overlay: left=% (tracks SVG x), top=px (height is fixed so no distortion)');
    html.AppendLine('      var overlayDots = dms.map(function(v, i) {');
    html.AppendLine('        var lp = (n === 1 ? 50 : i / (n - 1) * 100).toFixed(2);');
    html.AppendLine('        var tp = parseFloat(cy(v));');
    html.AppendLine('        var st = hist[i] ? (hist[i].status || "") : "";');
    html.AppendLine('        var col = st === "Unhealthy" ? "var(--unhealthy)" : st === "Degraded" ? "var(--degraded)" : "var(--healthy)";');
    html.AppendLine('        var tip = v.toFixed(0) + " ms" + (hist[i].ts ? " \u00b7 " + new Date(hist[i].ts).toLocaleTimeString() : "");');
    html.AppendLine('        return "<span style=\"position:absolute;left:" + lp + "%;top:" + tp + "px;transform:translate(-50%,-50%);width:6px;height:6px;border-radius:50%;background:" + col + ";box-shadow:0 0 0 2px var(--panel);\" title=\"" + tip + "\"></span>";');
    html.AppendLine('      }).join("");');
    html.AppendLine('      var chartWrap = "<div style=\"flex:1;position:relative;height:" + H + "px;\">" + chartSvg + overlayDots + "</div>";');
    html.AppendLine('      // X labels as HTML (no SVG, no stretch)');
    html.AppendLine('      var tsFirst = hist[0].ts ? new Date(hist[0].ts).toLocaleTimeString([], {hour:"2-digit",minute:"2-digit"}) : "";');
    html.AppendLine('      var tsLast  = hist[hist.length-1].ts ? new Date(hist[hist.length-1].ts).toLocaleTimeString([], {hour:"2-digit",minute:"2-digit"}) : "";');
    html.AppendLine('      var xLabels = "<div style=\"display:flex;justify-content:space-between;font-size:9px;font-family:monospace;color:var(--muted);padding-left:40px;margin-top:2px\"><span>" + tsFirst + "</span><span>" + tsLast + "</span></div>";');
    html.AppendLine('      return "<div style=\"display:flex;align-items:stretch;margin:8px 0 0\">" + yAxisSvg + chartWrap + "</div>" + xLabels;');
    html.AppendLine('    }');
    html.AppendLine('');
    html.AppendLine('    var lastEntries = {};');
    html.AppendLine('    var idToName = {};');
    html.AppendLine('    var historyCache = {};');
    html.AppendLine('    function renderMiniDots(hist) {');
    html.AppendLine('      var last10 = hist.slice(-10);');
    html.AppendLine('      if (last10.length === 0) return "<span class=\"mini-dots\"><span style=\"color:var(--muted);font-size:11px;\">--</span></span>";');
    html.AppendLine('      var dots = last10.map(function(h) {');
    html.AppendLine('        var s = (h.status || "").toLowerCase();');
    html.AppendLine('        var col = s === "healthy" ? "var(--healthy)" : s === "degraded" ? "var(--degraded)" : s === "pending" ? "var(--muted)" : "var(--unhealthy)";');
    html.AppendLine('        var tip = (h.status || "?") + (h.ts ? " \u00b7 " + new Date(h.ts).toLocaleTimeString() : "") + (h.duration ? " \u00b7 " + h.duration : "");');
    html.AppendLine('        return "<span class=\"mini-dot\" style=\"background:" + col + "\" title=\"" + tip + "\"></span>";');
    html.AppendLine('      }).join("");');
    html.AppendLine('      return "<span class=\"mini-dots\">" + dots + "</span>";');
    html.AppendLine('    }');
    html.AppendLine('    function renderHistoryTable(data) {');
    html.AppendLine('      if (!data || !data.history || data.history.length === 0) return "<em style=\"color:var(--muted);font-size:12px;\">No history yet</em>";');
    html.AppendLine('      var rows = data.history.slice().reverse().map(function(h) {');
    html.AppendLine('        var hcss = cssClassFor(h.status || "");');
    html.AppendLine('        var ts = h.ts ? new Date(h.ts).toLocaleTimeString() : "--";');
    html.AppendLine('        var errCell = h.error ? "<td class=\"h-err\" title=\"" + h.error + "\">" + h.error + "</td>" : "<td></td>";');
    html.AppendLine('        return "<tr><td><span class=\"dot " + hcss + "\"></span></td><td>" + (h.status||"?") + "</td><td>" + (h.duration||"--") + "</td><td>" + ts + "</td>" + errCell + "</tr>";');
    html.AppendLine('      }).join("");');
    html.AppendLine('      return "<div class=\"hc-hist-scroll\"><table class=\"hc-history-table\"><thead><tr><th></th><th>Status</th><th>Duration</th><th>Time</th><th>Error</th></tr></thead><tbody>" + rows + "</tbody></table></div>";');
    html.AppendLine('    }');
    html.AppendLine('    async function fetchHistory(id) {');
    html.AppendLine('      var name = idToName[id];');
    html.AppendLine('      if (!name) return;');
    html.AppendLine('      function liveInner() { return document.getElementById("hist-inner-" + id); }');
    html.AppendLine('      var el = liveInner();');
    html.AppendLine('      if (!el) return;');
    html.AppendLine('      if (historyCache[id] && historyCache[id].history && historyCache[id].history.length > 0) {');
    html.AppendLine('        el.innerHTML = renderHistoryTable(historyCache[id]);');
    html.AppendLine('      } else {');
    html.AppendLine('        el.innerHTML = "<div style=\"display:flex;align-items:center;gap:8px;padding:10px 0;color:var(--muted);font-size:12px;\"><svg width=\"14\" height=\"14\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2.5\" style=\"animation:hc-spin 0.8s linear infinite;flex-shrink:0\"><circle cx=\"12\" cy=\"12\" r=\"10\" stroke-opacity=\"0.2\"/><path d=\"M12 2a10 10 0 0 1 10 10\"/></svg>Loading history&#x2026;</div>";');
    html.AppendLine('      }');
    html.AppendLine('      try {');
    html.AppendLine('        var r = await fetch("/health/history/" + encodeURIComponent(name), { cache: "no-store" });');
    html.AppendLine('        var text = await r.text();');
    html.AppendLine('        var data = JSON.parse(text);');
    html.AppendLine('        historyCache[id] = data;');
    html.AppendLine('        var cur = liveInner(); if (cur) cur.innerHTML = renderHistoryTable(data);');
    html.AppendLine('      } catch(e) {');
    html.AppendLine('        var cur = liveInner(); if (cur) cur.innerHTML = "<em style=\"color:var(--unhealthy)\">Error loading history</em>";');
    html.AppendLine('      }');
    html.AppendLine('    }');
    html.AppendLine('    function renderEntries(entries) {');
    html.AppendLine('      lastEntries = entries || {};');
    html.AppendLine('      const names = Object.keys(lastEntries);');
    html.AppendLine('      var nH = 0, nU = 0, nD = 0, nP = 0;');
    html.AppendLine('      names.forEach(function(n) { var s = (entries[n]||{}).status||""; if(s==="Healthy")nH++; else if(s==="Unhealthy")nU++; else if(s==="Degraded")nD++; else nP++; });');
    html.AppendLine('      document.getElementById("stat-total").textContent = String(names.length);');
    html.AppendLine('      document.getElementById("stat-healthy").textContent = String(nH);');
    html.AppendLine('      document.getElementById("stat-unhealthy").textContent = String(nU);');
    html.AppendLine('      document.getElementById("stat-degraded").textContent = String(nD);');
    html.AppendLine('      if (names.length === 0) { entriesHost.innerHTML = ""; return; }');
    html.AppendLine('      const rows = names.map(function(name) {');
    html.AppendLine('        const entry = entries[name] || {};');
    html.AppendLine('        const css = cssClassFor(entry.status);');
    html.AppendLine('        const kind = (entry.kind || "custom").toLowerCase();');
    html.AppendLine('        const description = entry.description || "";');
    html.AppendLine('        const tagsHtml = renderTags(entry.tags);');
    html.AppendLine('        const detail = [tagsHtml, (description && entry.status !== "Healthy") ? "<span style=\"color:var(--unhealthy);font-size:12px;\">" + description + "</span>" : ""].filter(Boolean).join("<br>");');
    html.AppendLine('        const safeId = "hx-" + name.replace(/[^a-z0-9]/gi, "_");');
    html.AppendLine('        const hist = Array.isArray(entry.history) ? entry.history : [];');
    html.AppendLine('        const miniDots = renderMiniDots(hist);');
    html.AppendLine('        const histHtml = (hist.length >= 2 ? renderSparkline(hist) : "") + "<div id=\"hist-inner-" + safeId + "\"></div>";');
    html.AppendLine('        idToName[safeId] = name;');
    html.AppendLine('        const mainRow = "<tr data-hcid=\"" + safeId + "\" class=\"hc-main-row\" style=\"cursor:pointer;\">" +');
    html.AppendLine('          "<td class=\"td-expand\"><button class=\"expand-btn\" id=\"btn-" + safeId + "\">&#9654;</button></td>" +');
    html.AppendLine('          "<td class=\"td-name\">" + name + "</td>" +');
    html.AppendLine('          "<td><span class=\"kind-badge\">" + kind + "</span></td>" +');
    html.AppendLine('          "<td class=\"td-dur\">" + (entry.duration || "--") + "</td>" +');
    html.AppendLine('          "<td class=\"td-next\">" + nextCheckLabel(entry) + "</td>" +');
    html.AppendLine('          "<td class=\"td-detail\">" + detail + "</td>" +');
    html.AppendLine('          "<td class=\"td-trend\">" + miniDots + "</td>" +');
    html.AppendLine('          "<td class=\"td-status\"><div class=\"badge " + css + "\"><span class=\"dot\"></span><span>" + (entry.status || "Unknown") + "</span></div></td>" +');
    html.AppendLine('        "</tr>";');
    html.AppendLine('        const histRow = "<tr class=\"hc-history-row\" id=\"row-" + safeId + "\"><td colspan=\"8\"><div class=\"hc-history-wrap\" id=\"wrap-" + safeId + "\"><div class=\"hc-history-inner\">" + histHtml + "</div></div></td></tr>";');
    html.AppendLine('        return mainRow + histRow;');
    html.AppendLine('      }).join("");');
    html.AppendLine('      entriesHost.innerHTML = "<div class=\"tbl-wrap\"><table class=\"hc-table\"><thead><tr>" +');
    html.AppendLine('        "<th></th><th>Name</th><th>Type</th><th>Duration</th><th>Next check</th><th>Details</th><th>Trend</th><th style=\"text-align:right;\">Status</th>" +');
    html.AppendLine('        "</tr></thead><tbody>" + rows + "</tbody></table></div>";');
    html.AppendLine('      // restore expanded state, then attach click handlers');
    html.AppendLine('      entriesHost.querySelectorAll(".hc-main-row").forEach(function(tr) {');
    html.AppendLine('        var id = tr.dataset.hcid;');
    html.AppendLine('        if (expandedSet.has(id)) {');
    html.AppendLine('          var wrap = document.getElementById("wrap-" + id);');
    html.AppendLine('          var btn  = document.getElementById("btn-"  + id);');
    html.AppendLine('          if (wrap) wrap.classList.add("open");');
    html.AppendLine('          if (btn)  btn.classList.add("open");');
    html.AppendLine('          fetchHistory(id);');
    html.AppendLine('        }');
    html.AppendLine('        tr.addEventListener("click", function() { toggleHistory(id); });');
    html.AppendLine('      });');
    html.AppendLine('    }');
    html.AppendLine('');
    html.AppendLine('    var expandedSet = new Set();');
    html.AppendLine('    function toggleHistory(id) {');
    html.AppendLine('      const wrap = document.getElementById("wrap-" + id);');
    html.AppendLine('      const btn  = document.getElementById("btn-"  + id);');
    html.AppendLine('      if (!wrap) return;');
    html.AppendLine('      const open = wrap.classList.toggle("open");');
    html.AppendLine('      if (btn) btn.classList.toggle("open", open);');
    html.AppendLine('      if (open) {');
    html.AppendLine('        expandedSet.add(id);');
    html.AppendLine('        fetchHistory(id);');
    html.AppendLine('      } else {');
    html.AppendLine('        expandedSet.delete(id);');
    html.AppendLine('      }');
    html.AppendLine('    }');
    html.AppendLine('');
    html.AppendLine('    async function loadHealth() {');
    html.AppendLine('      try {');
    html.AppendLine('        const response = await fetch("/health/detail", { headers: { "Accept": "application/json" }, cache: "no-store" });');
    html.AppendLine('        const text = await response.text();');
    html.AppendLine('        const data = JSON.parse(text);');
    html.AppendLine('        setOverall(data.status || (response.ok ? "Healthy" : "Unhealthy"));');
    html.AppendLine('        lastUpdate.textContent = new Date().toLocaleTimeString();');
    html.AppendLine('        renderEntries(data.entries || {});');
    html.AppendLine('      } catch (error) {');
    html.AppendLine('        setOverall("Unhealthy");');
    html.AppendLine('        ["stat-total","stat-healthy","stat-unhealthy","stat-degraded"].forEach(function(id){var el=document.getElementById(id);if(el)el.textContent="0";});');
    html.AppendLine('        lastUpdate.textContent = new Date().toLocaleTimeString();');
    html.AppendLine('        entriesHost.innerHTML = "<div class=\"tbl-wrap\"><table class=\"hc-table\"><thead><tr><th></th><th>Name</th><th>Type</th><th>Duration</th><th>Next check</th><th>Details</th><th>Trend</th><th style=\"text-align:right;\">Status</th></tr></thead><tbody><tr><td></td><td class=\"td-name\">Dashboard error</td><td></td><td></td><td></td><td class=\"td-detail\" style=\"color:var(--unhealthy);\">Unable to reach /health: " + error + "</td><td></td><td></td></tr></tbody></table></div>";');
    html.AppendLine('      }');
    html.AppendLine('    }');
    html.AppendLine('');
    html.AppendLine('    (function() {');
    html.AppendLine('      const saved = localStorage.getItem("hc-theme");');
    html.AppendLine('      const serverDefault = "' + LowerCase(GHealthChecksUIDefaultTheme) + '";');
    html.AppendLine('      const prefersLight = window.matchMedia && window.matchMedia("(prefers-color-scheme: light)").matches;');
    html.AppendLine('      const theme = saved || (prefersLight ? "light" : serverDefault);');
    html.AppendLine('      applyTheme(theme);');
    html.AppendLine('    })();');
    html.AppendLine('    function applyTheme(theme) {');
    html.AppendLine('      if (theme === "light") document.documentElement.setAttribute("data-theme", "light");');
    html.AppendLine('      else document.documentElement.removeAttribute("data-theme");');
    html.AppendLine('      const btn = document.getElementById("theme-toggle");');
    html.AppendLine('      if (btn) btn.innerHTML = theme === "light" ? "&#9790; Dark" : "&#9728; Light";');
    html.AppendLine('    }');
    html.AppendLine('    function toggleTheme() {');
    html.AppendLine('      const isLight = document.documentElement.getAttribute("data-theme") === "light";');
    html.AppendLine('      const next = isLight ? "dark" : "light";');
    html.AppendLine('      localStorage.setItem("hc-theme", next);');
    html.AppendLine('      applyTheme(next);');
    html.AppendLine('    }');
    html.AppendLine('    var pollTimer = null;');
    html.AppendLine('    function setRefreshInterval(ms) {');
    html.AppendLine('      if (pollTimer) clearInterval(pollTimer);');
    html.AppendLine('      pollTimer = setInterval(loadHealth, ms);');
    html.AppendLine('      localStorage.setItem("hc-refresh", String(ms));');
    html.AppendLine('      document.querySelectorAll(".interval-btn").forEach(function(b) {');
    html.AppendLine('        b.classList.toggle("active", Number(b.dataset.ms) === ms);');
    html.AppendLine('      });');
    html.AppendLine('    }');
    html.AppendLine('    loadHealth();');
    html.AppendLine('    (function() {');
    html.AppendLine('      var saved = parseInt(localStorage.getItem("hc-refresh") || "' + IntToStr(GHealthChecksUIAutoRefreshMs) + '", 10);');
    html.AppendLine('      setRefreshInterval(saved);');
    html.AppendLine('      document.querySelectorAll(".interval-btn").forEach(function(b) {');
    html.AppendLine('        b.classList.toggle("active", Number(b.dataset.ms) === saved);');
    html.AppendLine('      });');
    html.AppendLine('    })();');
    html.AppendLine('    setInterval(function() {');
    html.AppendLine('      const names = Object.keys(lastEntries);');
    html.AppendLine('      document.querySelectorAll(".td-next").forEach(function(cell, i) {');
    html.AppendLine('        if (i < names.length) cell.textContent = nextCheckLabel(lastEntries[names[i]] || {});');
    html.AppendLine('      });');
    html.AppendLine('    }, 1000);');
    html.AppendLine('  </script>');
    html.AppendLine('</body>');
    html.AppendLine('</html>');
    Result := TContentResult.Create(html.ToString, 'text/html');
  finally
    html.Free;
  end;
end;

end.