{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Mvc.Middleware.TaskControlUI
  Description : Core MVC TaskControl Dashboard UI Middleware
  Author      : Kike Perez
  Version     : 1.0
  Created     : 04/05/2026

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

unit Quick.Core.Mvc.Middleware.TaskControlUI;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.IOUtils,
  Quick.Core.Mvc,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Mvc.Extensions.TaskControl;

type
  TTaskControlUIOptions = class
  private
    fTitle              : string;
    fDefaultTheme       : string;
    fAutoRefreshMs      : Integer;
    fFullWidth          : Boolean;
    fFullWidthHeader    : Boolean;
    fCenterHeaderContent: Boolean;
    fMaxContentWidth    : Integer;
    fShowThemeToggle    : Boolean;
    fShowRefreshControls: Boolean;
    fShowFooter         : Boolean;
  public
    constructor Create;
    property Title               : string  read fTitle               write fTitle;
    property DefaultTheme        : string  read fDefaultTheme        write fDefaultTheme;
    property AutoRefreshMs       : Integer read fAutoRefreshMs       write fAutoRefreshMs;
    property FullWidth           : Boolean read fFullWidth           write fFullWidth;
    property FullWidthHeader     : Boolean read fFullWidthHeader     write fFullWidthHeader;
    property CenterHeaderContent : Boolean read fCenterHeaderContent write fCenterHeaderContent;
    property MaxContentWidth     : Integer read fMaxContentWidth     write fMaxContentWidth;
    property ShowThemeToggle     : Boolean read fShowThemeToggle     write fShowThemeToggle;
    property ShowRefreshControls : Boolean read fShowRefreshControls write fShowRefreshControls;
    property ShowFooter          : Boolean read fShowFooter          write fShowFooter;
  end;

  TTaskControlUIMVCServerExtension = class(TMVCServerExtension)
    class function UseTaskControlUI : TMVCServer; overload;
    class function UseTaskControlUI(aConfigureOptions : TProc<TTaskControlUIOptions>) : TMVCServer; overload;
  end;

  [Route('taskcontrolui')]
  TTaskControlUIController = class(THttpController)
  published
    [HttpGet]
    function Index : IActionResult;
  end;

var
  GTaskControlUITitle             : string  = '';
  GTaskControlUIDefaultTheme      : string  = 'dark';
  GTaskControlUIAutoRefreshMs     : Integer = 5000;
  GTaskControlUIFullWidth         : Boolean = False;
  GTaskControlUIFullWidthHeader   : Boolean = True;
  GTaskControlUICenterHeader      : Boolean = False;
  GTaskControlUIMaxContentWidth   : Integer = 1280;
  GTaskControlUIShowThemeToggle   : Boolean = True;
  GTaskControlUIShowRefreshCtrl   : Boolean = True;
  GTaskControlUIShowFooter        : Boolean = True;

implementation

{ TTaskControlUIOptions }

constructor TTaskControlUIOptions.Create;
begin
  inherited;
  fTitle               := '';
  fDefaultTheme        := 'dark';
  fAutoRefreshMs       := 5000;
  fFullWidth           := False;
  fFullWidthHeader     := True;
  fCenterHeaderContent := False;
  fMaxContentWidth     := 1280;
  fShowThemeToggle     := True;
  fShowRefreshControls := True;
  fShowFooter          := True;
end;

{ TTaskControlUIMVCServerExtension }

class function TTaskControlUIMVCServerExtension.UseTaskControlUI : TMVCServer;
begin
  Result := UseTaskControlUI(nil);
end;

class function TTaskControlUIMVCServerExtension.UseTaskControlUI(aConfigureOptions : TProc<TTaskControlUIOptions>) : TMVCServer;
var
  opts : TTaskControlUIOptions;
begin
  Result := MVCServer;
  opts := TTaskControlUIOptions.Create;
  try
    if Assigned(aConfigureOptions) then aConfigureOptions(opts);
    if opts.Title.Trim.IsEmpty then
      GTaskControlUITitle := TPath.GetFileNameWithoutExtension(ParamStr(0)) + ' TaskControl'
    else
      GTaskControlUITitle := opts.Title;
    GTaskControlUIDefaultTheme    := opts.DefaultTheme;
    GTaskControlUIAutoRefreshMs   := opts.AutoRefreshMs;
    GTaskControlUIFullWidth       := opts.FullWidth;
    GTaskControlUIFullWidthHeader := opts.FullWidthHeader;
    GTaskControlUICenterHeader    := opts.CenterHeaderContent;
    GTaskControlUIMaxContentWidth := opts.MaxContentWidth;
    GTaskControlUIShowThemeToggle := opts.ShowThemeToggle;
    GTaskControlUIShowRefreshCtrl := opts.ShowRefreshControls;
    GTaskControlUIShowFooter      := opts.ShowFooter;
  finally
    opts.Free;
  end;
  MVCServer.AddController(TTaskControlUIController);
end;

{ TTaskControlUIController }

function TTaskControlUIController.Index : IActionResult;
var
  html : TStringBuilder;
  hw   : Integer;
begin
  html := TStringBuilder.Create;
  try
    html.AppendLine('<!DOCTYPE html>');
    html.AppendLine('<html lang="en">');
    html.AppendLine('<head>');
    html.AppendLine('  <meta charset="utf-8">');
    html.AppendLine('  <meta name="viewport" content="width=device-width, initial-scale=1">');
    html.AppendLine('  <title>' + GTaskControlUITitle + '</title>');
    html.AppendLine('  <style>');
    html.AppendLine('    :root { --bg:#1a1f2e; --panel:#252b3b; --panel2:#2d3447; --line:rgba(255,255,255,0.08); --ink:#e2e8f0; --muted:#94a3b8; --running:#6366f1; --done:#10b981; --error:#ef4444; --pending:#f59e0b; --disabled:#64748b; --shadow:0 4px 24px rgba(0,0,0,0.4); --body-bg:#1a1f2e; --accent:#6366f1; }');
    html.AppendLine('    [data-theme="light"] { --bg:#f1f5f9; --panel:#ffffff; --panel2:#f8fafc; --line:rgba(0,0,0,0.08); --ink:#1e293b; --muted:#64748b; --running:#4f46e5; --done:#059669; --error:#dc2626; --pending:#d97706; --disabled:#94a3b8; --shadow:0 4px 24px rgba(0,0,0,0.1); --body-bg:#f1f5f9; --accent:#4f46e5; }');
    html.AppendLine('    * { box-sizing: border-box; margin: 0; }');
    html.AppendLine('    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; color: var(--ink); background: var(--body-bg); min-height: 100vh; transition: background 0.3s, color 0.3s; }');
    html.AppendLine('    .app-header { background: var(--panel); border: 1px solid var(--line); padding: 0 24px; display: flex; align-items: center; height: 60px; gap: 16px; position: sticky; top: 0; z-index: 100; box-shadow: var(--shadow); }');
    html.AppendLine('    .header-brand { display: flex; align-items: center; gap: 10px; font-size: 17px; font-weight: 700; color: var(--ink); white-space: nowrap; }');
    html.AppendLine('    .brand-icon { width: 30px; height: 30px; background: var(--accent); border-radius: 7px; display: flex; align-items: center; justify-content: center; color: #fff; font-size: 15px; font-weight: 900; flex-shrink: 0; }');
    html.AppendLine('    .header-spacer { flex: 1; }');
    html.AppendLine('    .header-right { display: flex; align-items: center; gap: 10px; flex-shrink: 0; }');
    html.AppendLine('    .updated-label { font-size: 12px; color: var(--muted); white-space: nowrap; }');
    html.AppendLine('    .theme-btn { background: var(--panel2); border: 1px solid var(--line); border-radius: 8px; padding: 6px 14px; font-size: 12px; cursor: pointer; color: var(--muted); transition: color 0.2s, background 0.2s; white-space: nowrap; }');
    html.AppendLine('    .theme-btn:hover { color: var(--ink); }');
    html.AppendLine('    .refresh-bar { display: flex; align-items: center; gap: 6px; font-size: 12px; color: var(--muted); }');
    html.AppendLine('    .interval-btn { padding: 4px 10px; border-radius: 6px; border: 1px solid var(--line); background: transparent; color: var(--muted); font-size: 12px; cursor: pointer; transition: background 0.15s, color 0.15s; }');
    html.AppendLine('    .interval-btn.active { background: rgba(99,102,241,0.15); color: #818cf8; font-weight: 700; border-color: rgba(99,102,241,0.3); }');
    if GTaskControlUIFullWidth then
      html.AppendLine('    .page { width: 100%; padding: 24px 32px 48px; box-sizing: border-box; }')
    else
      html.AppendLine('    .page { max-width: ' + IntToStr(GTaskControlUIMaxContentWidth) + 'px; margin: 0 auto; padding: 24px 24px 48px; }');
    html.AppendLine('    .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(190px, 1fr)); gap: 14px; margin-bottom: 24px; }');
    html.AppendLine('    .stat-card { background: var(--panel); border: 1px solid var(--line); border-radius: 12px; padding: 18px 20px; display: flex; align-items: center; gap: 14px; box-shadow: var(--shadow); }');
    html.AppendLine('    .stat-icon { width: 44px; height: 44px; border-radius: 10px; display: flex; align-items: center; justify-content: center; font-size: 18px; flex-shrink: 0; }');
    html.AppendLine('    .si-total    { background: rgba(99,102,241,0.15); color: #818cf8; }');
    html.AppendLine('    .si-running  { background: rgba(99,102,241,0.15); color: #818cf8; }');
    html.AppendLine('    .si-done     { background: rgba(16,185,129,0.15); color: #34d399; }');
    html.AppendLine('    .si-error    { background: rgba(239,68,68,0.15);  color: #f87171; }');
    html.AppendLine('    .si-queue    { background: rgba(245,158,11,0.15); color: #fbbf24; }');
    html.AppendLine('    .si-disabled { background: rgba(100,116,139,0.15); color: #94a3b8; }');
    html.AppendLine('    .stat-info { flex: 1; min-width: 0; }');
    html.AppendLine('    .stat-label { font-size: 11px; color: var(--muted); text-transform: uppercase; letter-spacing: 0.08em; margin-bottom: 6px; }');
    html.AppendLine('    .stat-value { font-size: 30px; font-weight: 700; color: var(--ink); line-height: 1; }');
    html.AppendLine('    .section-head { display: flex; align-items: center; gap: 12px; margin-bottom: 16px; margin-top: 8px; flex-wrap:wrap; }');
    html.AppendLine('    .section-title { font-size: 18px; font-weight: 700; color: var(--ink); }');
    html.AppendLine('    .filter-bar { display:flex; align-items:center; gap:6px; flex-wrap:wrap; margin-left:auto; }');
    html.AppendLine('    .filter-btn { padding:4px 13px; border-radius:6px; border:1px solid var(--line); background:transparent; color:var(--muted); font-size:12px; cursor:pointer; transition:all 0.15s; display:inline-flex; align-items:center; gap:5px; white-space:nowrap; }');
    html.AppendLine('    .filter-btn.active { background:var(--accent); color:#fff; border-color:var(--accent); }');
    html.AppendLine('    .filter-btn:hover:not(.active) { background:var(--panel2); color:var(--ink); }');
    html.AppendLine('    .fb-count { font-size:10px; padding:1px 5px; border-radius:9px; background:rgba(255,255,255,0.18); }');
    html.AppendLine('    .filter-btn:not(.active) .fb-count { background:rgba(0,0,0,0.09); color:var(--muted); }');
    html.AppendLine('    .search-input { padding:5px 11px; border-radius:6px; border:1px solid var(--line); background:var(--panel2); color:var(--ink); font-size:12px; outline:none; width:150px; transition:border-color 0.15s; }');
    html.AppendLine('    .search-input:focus { border-color:var(--accent); }');
    html.AppendLine('    .search-input::placeholder { color:var(--muted); }');
    html.AppendLine('    .tbl-wrap { background: var(--panel); border: 1px solid var(--line); border-radius: 12px; box-shadow: var(--shadow); overflow: hidden; margin-bottom: 28px; }');
    html.AppendLine('    .tc-table { width: 100%; border-collapse: collapse; font-size: 14px; }');
    html.AppendLine('    .tc-table thead th { padding: 11px 16px; text-align: left; font-size: 11px; text-transform: uppercase; letter-spacing: 0.08em; color: var(--muted); border-bottom: 1px solid var(--line); background: rgba(0,0,0,0.15); font-weight: 600; }');
    html.AppendLine('    .tc-table tbody tr { border-bottom: 1px solid var(--line); transition: background 0.15s; }');
    html.AppendLine('    .tc-table tbody tr:last-child { border-bottom: none; }');
    html.AppendLine('    .tc-table tbody tr:hover { background: rgba(255,255,255,0.03); }');
    html.AppendLine('    .tc-table td { padding: 12px 16px; vertical-align: middle; color: var(--ink); }');
    html.AppendLine('    .td-name { font-weight: 700; font-size: 15px; }');
    html.AppendLine('    .td-mono { font-family: monospace; font-size: 13px; color: var(--muted); white-space: nowrap; }');
    html.AppendLine('    .td-actions { white-space: nowrap; text-align: right; }');
    html.AppendLine('    .dot { width: 8px; height: 8px; border-radius: 50%; display: inline-block; flex-shrink: 0; }');
    html.AppendLine('    .st-badge { display: inline-flex; align-items: center; gap: 6px; padding: 4px 10px; border-radius: 999px; font-size: 12px; font-weight: 600; }');
    html.AppendLine('    .st-running  { background: rgba(99,102,241,0.12);  color: var(--running);  border: 1px solid rgba(99,102,241,0.25); }');
    html.AppendLine('    .st-done     { background: rgba(16,185,129,0.12);  color: var(--done);     border: 1px solid rgba(16,185,129,0.25); }');
    html.AppendLine('    .st-error    { background: rgba(239,68,68,0.12);   color: var(--error);    border: 1px solid rgba(239,68,68,0.25); }');
    html.AppendLine('    .st-pending  { background: rgba(245,158,11,0.12);  color: var(--pending);  border: 1px solid rgba(245,158,11,0.25); }');
    html.AppendLine('    .st-disabled { background: rgba(100,116,139,0.10); color: var(--disabled); border: 1px solid rgba(100,116,139,0.2); }');
    html.AppendLine('    .st-skipped  { background: rgba(245,158,11,0.10);  color: #a16207;         border: 1px solid rgba(245,158,11,0.2); }');
    html.AppendLine('    .st-deleted  { background: rgba(239,68,68,0.08);   color: var(--disabled); border: 1px solid rgba(239,68,68,0.15); text-decoration:line-through; }');
    html.AppendLine('    .no-overlap-tag { display:inline-block; margin-left:5px; font-size:10px; color:var(--muted); vertical-align:middle; }');
    html.AppendLine('    .act-btn { padding: 4px 12px; border-radius: 6px; border: 1px solid var(--line); background: transparent; color: var(--muted); font-size: 12px; cursor: pointer; transition: all 0.15s; }');
    html.AppendLine('    .act-btn:hover { color: var(--ink); background: var(--panel2); }');
    html.AppendLine('    .act-btn.danger:hover { color: var(--error); border-color: var(--error); }');
    html.AppendLine('    .act-btn.success:hover { color: var(--done); border-color: var(--done); }');
    html.AppendLine('    .act-btn.run:hover { color: var(--pending); border-color: var(--pending); }');
    html.AppendLine('    .modal-overlay { display:none; position:fixed; inset:0; background:rgba(0,0,0,0.6); z-index:200; align-items:center; justify-content:center; }');
    html.AppendLine('    .modal-overlay.open { display:flex; }');
    html.AppendLine('    .modal-box { background:var(--panel); border:1px solid var(--line); border-radius:14px; width:min(700px,95vw); max-height:80vh; display:flex; flex-direction:column; box-shadow:0 8px 48px rgba(0,0,0,0.5); }');
    html.AppendLine('    .modal-head { display:flex; align-items:center; gap:12px; padding:16px 20px; border-bottom:1px solid var(--line); }');
    html.AppendLine('    .modal-title { flex:1; font-size:16px; font-weight:700; color:var(--ink); }');
    html.AppendLine('    .modal-close { background:none; border:none; color:var(--muted); font-size:20px; cursor:pointer; line-height:1; padding:0 4px; }');
    html.AppendLine('    .modal-close:hover { color:var(--ink); }');
    html.AppendLine('    .modal-body { padding:16px 20px; overflow-y:auto; }');
    html.AppendLine('    .hist-tbl { width:100%; border-collapse:collapse; font-size:13px; }');
    html.AppendLine('    .hist-tbl th { padding:8px 12px; text-align:left; font-size:11px; text-transform:uppercase; letter-spacing:0.07em; color:var(--muted); border-bottom:1px solid var(--line); font-weight:600; }');
    html.AppendLine('    .hist-tbl td { padding:9px 12px; border-bottom:1px solid var(--line); color:var(--ink); }');
    html.AppendLine('    .hist-tbl tr:last-child td { border-bottom:none; }');
    html.AppendLine('    .dur-badge { font-size:11px; color:var(--muted); font-family:monospace; }');
    html.AppendLine('    .bg-panel { background: var(--panel); border: 1px solid var(--line); border-radius: 12px; padding: 20px 24px; box-shadow: var(--shadow); display: flex; gap: 32px; flex-wrap: wrap; }');
    html.AppendLine('    .bg-stat { text-align: center; }');
    html.AppendLine('    .bg-stat-val { font-size: 28px; font-weight: 700; color: var(--ink); }');
    html.AppendLine('    .bg-stat-lbl { font-size: 11px; color: var(--muted); text-transform: uppercase; letter-spacing: 0.08em; margin-top: 4px; }');
    html.AppendLine('    .footer { margin-top: 24px; font-size: 12px; color: var(--muted); }');
    html.AppendLine('    @keyframes tc-spin { to { transform: rotate(360deg); } }');
    // Tab nav
    html.AppendLine('    .tab-nav { display:flex; gap:4px; margin-bottom:20px; border-bottom:2px solid var(--line); }');
    html.AppendLine('    .tab-btn { background:none; border:none; padding:10px 20px; font-size:14px; font-weight:600; color:var(--muted); cursor:pointer; border-bottom:3px solid transparent; margin-bottom:-2px; transition:color 0.15s,border-color 0.15s; }');
    html.AppendLine('    .tab-btn:hover { color:var(--ink); }');
    html.AppendLine('    .tab-btn.active { color:var(--accent); border-bottom-color:var(--accent); }');
    // Jobs pager
    html.AppendLine('    .jobs-pager { display:flex; align-items:center; gap:12px; margin-top:14px; justify-content:center; }');
    html.AppendLine('    @media (max-width: 700px) { .page { padding: 16px 14px 32px; } .stats-grid { grid-template-columns: 1fr 1fr; } .app-header { padding: 0 14px !important; margin: 0 !important; max-width: 100% !important; border-radius: 0 !important; } .header-right { gap: 6px; } .updated-label { display: none; } }');
    if not GTaskControlUIFullWidthHeader then
    begin
      hw := GTaskControlUIMaxContentWidth - 48;
      html.AppendLine('    .app-header { width: calc(100% - 48px); max-width: ' + IntToStr(hw) + 'px; margin: 8px auto 0; border-radius: 12px; }');
    end;
    if GTaskControlUIFullWidthHeader and GTaskControlUICenterHeader then
      html.AppendLine('    .header-inner { display: flex; align-items: center; gap: 16px; width: 100%; max-width: ' + IntToStr(GTaskControlUIMaxContentWidth) + 'px; margin: 0 auto; }');
    html.AppendLine('  </style>');
    html.AppendLine('</head>');
    if SameText(GTaskControlUIDefaultTheme, 'light') then
      html.AppendLine('<body data-theme="light">')
    else
      html.AppendLine('<body>');
    html.AppendLine('  <header class="app-header">');
    if GTaskControlUIFullWidthHeader and GTaskControlUICenterHeader then
      html.AppendLine('    <div class="header-inner">');
    html.AppendLine('    <div class="header-brand"><div class="brand-icon">&#9654;</div>' + GTaskControlUITitle + '</div>');
    html.AppendLine('    <div class="header-spacer"></div>');
    html.AppendLine('    <div class="header-right">');
    html.AppendLine('      <span class="updated-label">Updated: <strong id="last-update">--</strong></span>');
    if GTaskControlUIShowRefreshCtrl then
    begin
      html.AppendLine('      <div class="refresh-bar">');
      html.AppendLine('        <span>Auto:</span>');
      html.AppendLine('        <button class="interval-btn" data-ms="1000"  onclick="setRefreshInterval(1000)">1s</button>');
      html.AppendLine('        <button class="interval-btn" data-ms="5000"  onclick="setRefreshInterval(5000)">5s</button>');
      html.AppendLine('        <button class="interval-btn" data-ms="10000" onclick="setRefreshInterval(10000)">10s</button>');
      html.AppendLine('        <button class="interval-btn" data-ms="30000" onclick="setRefreshInterval(30000)">30s</button>');
      html.AppendLine('        <button class="interval-btn" data-ms="60000" onclick="setRefreshInterval(60000)">60s</button>');
      html.AppendLine('      </div>');
    end;
    if GTaskControlUIShowThemeToggle then
      html.AppendLine('      <button class="theme-btn" id="theme-toggle" onclick="toggleTheme()">&#9728; Light</button>');
    html.AppendLine('      <button class="theme-btn" id="pause-all-btn" onclick="pauseAll()" title="Pause all scheduled tasks">&#9646;&#9646; Pause All</button>');
    html.AppendLine('      <button class="theme-btn" id="resume-all-btn" onclick="resumeAll()" title="Resume scheduling" style="display:none">&#9654; Resume All</button>');
    html.AppendLine('    </div>');
    if GTaskControlUIFullWidthHeader and GTaskControlUICenterHeader then
      html.AppendLine('    </div>');
    html.AppendLine('  </header>');
    html.AppendLine('  <div class="page">');
    html.AppendLine('    <div id="pause-banner" style="display:none;background:rgba(234,179,8,0.15);border:1px solid rgba(234,179,8,0.4);color:#b45309;border-radius:8px;padding:10px 16px;margin-bottom:16px;font-weight:600;text-align:center;">');
    html.AppendLine('      &#9646;&#9646; Scheduler paused &mdash; no new tasks will be triggered. <button class="act-btn success" onclick="resumeAll()" style="margin-left:12px">&#9654; Resume All</button>');
    html.AppendLine('    </div>');
    // Stats cards
    html.AppendLine('    <div class="stats-grid">');
    html.AppendLine('      <div class="stat-card"><div class="stat-icon si-total">&#9776;</div><div class="stat-info"><div class="stat-label">Scheduled Tasks</div><div class="stat-value" id="st-total">0</div></div></div>');
    html.AppendLine('      <div class="stat-card"><div class="stat-icon si-running">&#9654;</div><div class="stat-info"><div class="stat-label">Running</div><div class="stat-value" id="st-running">0</div></div></div>');
    html.AppendLine('      <div class="stat-card"><div class="stat-icon si-done">&#10003;</div><div class="stat-info"><div class="stat-label">Done</div><div class="stat-value" id="st-done">0</div></div></div>');
    html.AppendLine('      <div class="stat-card"><div class="stat-icon si-error">&#9888;</div><div class="stat-info"><div class="stat-label">Failed</div><div class="stat-value" id="st-error">0</div></div></div>');
    html.AppendLine('      <div class="stat-card"><div class="stat-icon si-disabled">&#9646;</div><div class="stat-info"><div class="stat-label">Disabled</div><div class="stat-value" id="st-disabled">0</div></div></div>');
    html.AppendLine('      <div class="stat-card"><div class="stat-icon si-queue">&#8801;</div><div class="stat-info"><div class="stat-label">BG Queue</div><div class="stat-value" id="st-queue">0</div></div></div>');
    html.AppendLine('    </div>');
    // Tab navigation
    html.AppendLine('    <div class="tab-nav">');
    html.AppendLine('      <button class="tab-btn active" id="tab-btn-recurring" onclick="showTab(''recurring'')">Recurring Jobs</button>');
    html.AppendLine('      <button class="tab-btn"        id="tab-btn-jobs"      onclick="showTab(''jobs'')">Jobs</button>');
    html.AppendLine('    </div>');
    // ── TAB: Recurring Jobs ──────────────────────────────────────────
    html.AppendLine('    <div id="tab-recurring">');
    // Scheduled tasks table
    html.AppendLine('    <div class="section-head">');
    html.AppendLine('      <span class="section-title">Scheduled Tasks</span>');
    html.AppendLine('      <div class="filter-bar">');
    html.AppendLine('        <input type="text" id="task-search" class="search-input" placeholder="Search tasks…" oninput="applyFilter()">');
    html.AppendLine('        <button class="filter-btn active" data-filter="all"      onclick="setFilter(''all'')">All <span class="fb-count" id="fb-all">0</span></button>');
    html.AppendLine('        <button class="filter-btn" data-filter="running"   onclick="setFilter(''running'')">&#9654; Running <span class="fb-count" id="fb-running">0</span></button>');
    html.AppendLine('        <button class="filter-btn" data-filter="done"      onclick="setFilter(''done'')">&#10003; Done <span class="fb-count" id="fb-done">0</span></button>');
    html.AppendLine('        <button class="filter-btn" data-filter="failed"    onclick="setFilter(''failed'')">&#9888; Failed <span class="fb-count" id="fb-failed">0</span></button>');
    html.AppendLine('        <button class="filter-btn" data-filter="skipped"   onclick="setFilter(''skipped'')">&#8634; Skipped <span class="fb-count" id="fb-skipped">0</span></button>');
    html.AppendLine('        <button class="filter-btn" data-filter="disabled"  onclick="setFilter(''disabled'')">&#9646; Disabled <span class="fb-count" id="fb-disabled">0</span></button>');
    html.AppendLine('      </div>');
    html.AppendLine('    </div>');
    html.AppendLine('    <div class="tbl-wrap">');
    html.AppendLine('      <table class="tc-table">');
    html.AppendLine('        <thead><tr>');
    html.AppendLine('          <th>Name</th>');
    html.AppendLine('          <th>Status</th>');
    html.AppendLine('          <th>Schedule</th>');
    html.AppendLine('          <th>Last Run</th>');
    html.AppendLine('          <th>Next Run</th>');
    html.AppendLine('          <th>Runs</th>');
    html.AppendLine('          <th>Retries</th>');
    html.AppendLine('          <th style="text-align:right">Actions</th>');
    html.AppendLine('        </tr></thead>');
    html.AppendLine('        <tbody id="tasks-body"><tr><td colspan="8" style="text-align:center;color:var(--muted);padding:32px">Loading...</td></tr></tbody>');
    html.AppendLine('      </table>');
    html.AppendLine('    </div>');
    // Background tasks
    html.AppendLine('    <div class="section-head"><span class="section-title">Background Workers</span></div>');
    html.AppendLine('    <div class="bg-panel">');
    html.AppendLine('      <div class="bg-stat"><div class="bg-stat-val" id="bg-queued">0</div><div class="bg-stat-lbl">In Queue</div></div>');
    html.AppendLine('      <div class="bg-stat"><div class="bg-stat-val" id="bg-active">0</div><div class="bg-stat-lbl">Active Now</div></div>');
    html.AppendLine('      <div class="bg-stat"><div class="bg-stat-val" id="bg-workers">0</div><div class="bg-stat-lbl">Pool Size</div></div>');
    html.AppendLine('      <div class="bg-stat"><div class="bg-stat-val" id="bg-total">0</div><div class="bg-stat-lbl">Total Processed</div></div>');
    html.AppendLine('    </div>');
    html.AppendLine('    </div>'); // end #tab-recurring
    // ── TAB: Jobs (execution history across all tasks) ───────────────
    html.AppendLine('    <div id="tab-jobs" style="display:none">');
    html.AppendLine('    <div class="section-head">');
    html.AppendLine('      <span class="section-title">Jobs</span>');
    html.AppendLine('      <div class="filter-bar">');
    html.AppendLine('        <button class="filter-btn active" id="jf-all"       onclick="setJobFilter('''')">All <span class="fb-count" id="jf-total">0</span></button>');
    html.AppendLine('        <button class="filter-btn"        id="jf-running"   onclick="setJobFilter(''Running'')">&#9654; Running</button>');
    html.AppendLine('        <button class="filter-btn"        id="jf-succeeded" onclick="setJobFilter(''Done'')">&#10003; Succeeded</button>');
    html.AppendLine('        <button class="filter-btn"        id="jf-failed"    onclick="setJobFilter(''Exception'')">&#9888; Failed</button>');
    html.AppendLine('        <button class="filter-btn"        id="jf-skipped"   onclick="setJobFilter(''Skipped'')">&#8634; Skipped</button>');
    html.AppendLine('      </div>');
    html.AppendLine('    </div>');
    html.AppendLine('    <div class="tbl-wrap">');
    html.AppendLine('      <table class="tc-table">');
    html.AppendLine('        <thead><tr>');
    html.AppendLine('          <th>Task</th>');
    html.AppendLine('          <th>Time</th>');
    html.AppendLine('          <th>Duration</th>');
    html.AppendLine('          <th>Status</th>');
    html.AppendLine('          <th>Error</th>');
    html.AppendLine('        </tr></thead>');
    html.AppendLine('        <tbody id="jobs-body"><tr><td colspan="5" style="text-align:center;color:var(--muted);padding:32px">Select this tab to load job history</td></tr></tbody>');
    html.AppendLine('      </table>');
    html.AppendLine('    </div>');
    html.AppendLine('    <div class="jobs-pager" id="jobs-pager" style="display:none">');
    html.AppendLine('      <button class="act-btn" id="jobs-prev" onclick="jobPrev()">&#8592; Prev</button>');
    html.AppendLine('      <span id="jobs-page-info" style="font-size:13px;color:var(--muted)"></span>');
    html.AppendLine('      <button class="act-btn" id="jobs-next" onclick="jobNext()">Next &#8594;</button>');
    html.AppendLine('    </div>');
    html.AppendLine('    </div>'); // end #tab-jobs
    // Footer
    if GTaskControlUIShowFooter then
    begin
      html.AppendLine('    <div class="footer">');
      html.AppendLine('      <div style="margin-top:10px;padding-top:10px;border-top:1px solid var(--line);display:flex;align-items:center;gap:6px;font-size:11px;">');
      html.AppendLine('        Powered by <strong style="color:var(--ink);">QuickCore</strong> &mdash; <a href="https://github.com/exilon/QuickCore" target="_blank" style="color:var(--accent);text-decoration:none;">github.com/exilon/QuickCore</a>');
      html.AppendLine('      </div>');
      html.AppendLine('    </div>');
    end;
    html.AppendLine('  </div>');
    // JavaScript
    html.AppendLine('<script>');
    html.AppendLine('  function fmtDate(s) {');
    html.AppendLine('    if (!s) return "--";');
    html.AppendLine('    try { return new Date(s).toLocaleTimeString(); } catch(e) { return s; }');
    html.AppendLine('  }');
    html.AppendLine('  function humanizeCron(expr) {');
    html.AppendLine('    if (!expr) return expr;');
    html.AppendLine('    var p = expr.trim().split(/\s+/);');
    html.AppendLine('    if (p.length < 5) return expr;');
    html.AppendLine('    var min=p[0],hr=p[1],dom=p[2],mon=p[3],dow=p[4];');
    html.AppendLine('    if (min===''*''&&hr===''*''&&dom===''*''&&mon===''*''&&dow===''*'') return ''Every minute'';');
    html.AppendLine('    if (min!==''*''&&hr===''*''&&dom===''*''&&mon===''*''&&dow===''*'') return ''Every hour at :''+min.padStart(2,''0'');');
    html.AppendLine('    var days=[''Sun'',''Mon'',''Tue'',''Wed'',''Thu'',''Fri'',''Sat''];');
    html.AppendLine('    if (min!==''*''&&hr!==''*''&&dom===''*''&&mon===''*''&&dow===''*'') return ''Daily at ''+hr.padStart(2,''0'')+'':''+min.padStart(2,''0'');');
    html.AppendLine('    if (min!==''*''&&hr!==''*''&&dom===''*''&&mon===''*''&&dow!==''*'') return (days[+dow]||dow)+'' at ''+hr.padStart(2,''0'')+'':''+min.padStart(2,''0'');');
    html.AppendLine('    return expr;');
    html.AppendLine('  }');
    html.AppendLine('  function scheduleLabel(t) {');
    html.AppendLine('    if (t.scheduleMode === "RunOnce") return "Run once";');
    html.AppendLine('    if (t.scheduleMode === "Cron" && t.cronExpr) return humanizeCron(t.cronExpr);');
    html.AppendLine('    if (!t.interval || !t.timeMeasure) return "--";');
    html.AppendLine('    var n = +t.interval, m = t.timeMeasure;');
    html.AppendLine('    if (n === 1 && m === "Days")    return "Daily";');
    html.AppendLine('    if (n === 7 && m === "Days")    return "Weekly";');
    html.AppendLine('    if (n === 1 && m === "Hours")   return "Hourly";');
    html.AppendLine('    if (n === 1 && m === "Minutes") return "Every minute";');
    html.AppendLine('    var u = {"Days":"d","Hours":"h","Minutes":"min","Seconds":"s","Milliseconds":"ms"}[m] || m;');
    html.AppendLine('    return "Every " + n + u;');
    html.AppendLine('  }');
    html.AppendLine('  function retryBackoffLabel(t) {');
    html.AppendLine('    if (!t.maxRetries || !t.retryDelay) return "";');
    html.AppendLine('    var s = t.retryDelay + "ms";');
    html.AppendLine('    if (t.retryMultiplier > 1) s += " x" + t.retryMultiplier.toFixed(1);');
    html.AppendLine('    return " <span class=\"no-overlap-tag\" title=\"Backoff: " + s + "\">&#9203;</span>";');
    html.AppendLine('  }');
    html.AppendLine('  function statusBadge(t) {');
    html.AppendLine('    if (!t.enabled) return "<span class=\"st-badge st-disabled\">&#9646; Disabled</span>";');
    html.AppendLine('    var map = {');
    html.AppendLine('      "Running":   "<span class=\"st-badge st-running\">&#9654; Running</span>",');
    html.AppendLine('      "Done":      "<span class=\"st-badge st-done\">&#10003; Done</span>",');
    html.AppendLine('      "Exception": "<span class=\"st-badge st-error\">&#9888; Failed</span>",');
    html.AppendLine('      "Pending":   "<span class=\"st-badge st-pending\">&#9711; Pending</span>",');
    html.AppendLine('      "Assigned":  "<span class=\"st-badge st-pending\">&#9711; Assigned</span>",');
    html.AppendLine('      "Skipped":   "<span class=\"st-badge st-skipped\">&#8634; Skipped</span>",');
    html.AppendLine('      "Deleted":   "<span class=\"st-badge st-deleted\">&#10006; Deleted</span>"');
    html.AppendLine('    };');
    html.AppendLine('    return map[t.status] || ("<span class=\"st-badge st-pending\">" + t.status + "</span>");');
    html.AppendLine('  }');
    html.AppendLine('  function toggleTask(name, enable) {');
    html.AppendLine('    var action = enable ? "enable" : "disable";');
    html.AppendLine('    fetch("/TaskControl/Tasks/" + encodeURIComponent(name) + "/" + action, { method: "POST" })');
    html.AppendLine('      .then(function() { loadTasks(); });');
    html.AppendLine('  }');
    html.AppendLine('  function triggerTask(name) {');
    html.AppendLine('    fetch("/TaskControl/Tasks/" + encodeURIComponent(name) + "/trigger", { method: "POST" })');
    html.AppendLine('      .then(function() { loadTasks(); });');
    html.AppendLine('  }');
    html.AppendLine('  function cancelTask(name) {');
    html.AppendLine('    fetch("/TaskControl/Tasks/" + encodeURIComponent(name) + "/cancel", { method: "POST" })');
    html.AppendLine('      .then(function() { loadTasks(); });');
    html.AppendLine('  }');
    html.AppendLine('  function deleteTask(name) {');
    html.AppendLine('    if (!confirm("Delete task \"" + name + "\"? This will remove it from the scheduler.")) return;');
    html.AppendLine('    fetch("/TaskControl/Tasks/" + encodeURIComponent(name), { method: "DELETE" })');
    html.AppendLine('      .then(function() { loadTasks(); });');
    html.AppendLine('  }');
    html.AppendLine('  function pauseAll() {');
    html.AppendLine('    fetch("/TaskControl/Tasks/pauseAll", { method: "POST" })');
    html.AppendLine('      .then(function() { setPausedUI(true); loadTasks(); });');
    html.AppendLine('  }');
    html.AppendLine('  function resumeAll() {');
    html.AppendLine('    fetch("/TaskControl/Tasks/resumeAll", { method: "POST" })');
    html.AppendLine('      .then(function() { setPausedUI(false); loadTasks(); });');
    html.AppendLine('  }');
    html.AppendLine('  function setPausedUI(paused) {');
    html.AppendLine('    var pb = document.getElementById("pause-all-btn");');
    html.AppendLine('    var rb = document.getElementById("resume-all-btn");');
    html.AppendLine('    var banner = document.getElementById("pause-banner");');
    html.AppendLine('    if (pb) pb.style.display = paused ? "none" : "";');
    html.AppendLine('    if (rb) rb.style.display = paused ? "" : "none";');
    html.AppendLine('    if (banner) banner.style.display = paused ? "" : "none";');
    html.AppendLine('  }');
    html.AppendLine('  function showHistory(name) {');
    html.AppendLine('    document.getElementById("hist-modal-title").textContent = name + " - Execution History";');
    html.AppendLine('    document.getElementById("hist-modal-body").innerHTML = ''<p style="color:var(--muted);text-align:center;padding:20px">Loading...</p>'';');
    html.AppendLine('    document.getElementById("hist-modal").classList.add("open");');
    html.AppendLine('    fetch("/TaskControl/Tasks/" + encodeURIComponent(name) + "/history", { cache: "no-store" })');
    html.AppendLine('      .then(function(r) { return r.json(); })');
    html.AppendLine('      .then(function(hist) {');
    html.AppendLine('        if (!hist || hist.length === 0) {');
    html.AppendLine('          document.getElementById("hist-modal-body").innerHTML = ''<p style="color:var(--muted);text-align:center;padding:20px">No execution history yet</p>'';');
    html.AppendLine('          return;');
    html.AppendLine('        }');
    html.AppendLine('        var rows = hist.map(function(h) {');
    html.AppendLine('          var stMap = {');
    html.AppendLine('            "Done":      ''<span class="st-badge st-done">&#10003; Done</span>'',');
    html.AppendLine('            "Exception": ''<span class="st-badge st-error">&#9888; Failed</span>'',');
    html.AppendLine('            "Skipped":   ''<span class="st-badge st-skipped">&#8634; Skipped</span>''');
    html.AppendLine('          };');
    html.AppendLine('          var st = stMap[h.status] || (''<span class="st-badge st-pending">'' + h.status + ''</span>'');');
    html.AppendLine('          var dt = h.execTime ? new Date(h.execTime).toLocaleString() : "--";');
    html.AppendLine('          var dur = h.durationMs >= 1000');
    html.AppendLine('            ? (h.durationMs / 1000).toFixed(2) + " s"');
    html.AppendLine('            : h.durationMs + " ms";');
    html.AppendLine('          var errCell = (h.errorMessage && h.errorMessage.length > 0)');
    html.AppendLine('            ? (''<span style="color:var(--error);font-size:11px;" title="'' + h.exceptionType + ''">'' + h.errorMessage + ''</span>'')');
    html.AppendLine('            : "";');
    html.AppendLine('          return "<tr><td>" + dt + "</td><td>" + st + ''</td><td class="dur-badge">'' + dur + ''</td><td style="font-size:11px;max-width:220px;overflow:hidden;text-overflow:ellipsis;">'' + errCell + "</td></tr>";');
    html.AppendLine('        }).join("");');
    html.AppendLine('        document.getElementById("hist-modal-body").innerHTML =');
    html.AppendLine('          ''<table class="hist-tbl"><thead><tr><th>Time</th><th>Status</th><th>Duration</th><th>Error</th></tr></thead><tbody>'' + rows + "</tbody></table>";');
    html.AppendLine('      })');
    html.AppendLine('      .catch(function(e) {');
    html.AppendLine('        document.getElementById("hist-modal-body").innerHTML = ''<p style="color:var(--error);padding:16px">Error: '' + e + "</p>";');
    html.AppendLine('      });');
    html.AppendLine('  }');
    html.AppendLine('  function closeHistModal() {');
    html.AppendLine('    document.getElementById("hist-modal").classList.remove("open");');
    html.AppendLine('  }');
    html.AppendLine('  function renderRows(tasks) {');
    html.AppendLine('    if (!tasks || tasks.length === 0)');
    html.AppendLine('      return "<tr><td colspan=\"8\" style=\"text-align:center;color:var(--muted);padding:32px\">No scheduled tasks registered</td></tr>";');
    html.AppendLine('    var nR=0,nD=0,nE=0,nDis=0;');
    html.AppendLine('    var rows = tasks.map(function(t) {');
    html.AppendLine('      var runBtn  = t.status !== "Running" ? "<button class=\"act-btn run\" onclick=\"triggerTask(''" + t.name + "'')\">&#9654; Run</button>" : "";');
    html.AppendLine('      var stopBtn = t.status === "Running" ? "<button class=\"act-btn danger\" onclick=\"cancelTask(''" + t.name + "'')\">&#9724; Stop</button>" : "";');
    html.AppendLine('      var toggleBtn = t.enabled');
    html.AppendLine('        ? " <button class=\"act-btn danger\" onclick=\"toggleTask(''" + t.name + "'',false)\">Pause</button>"');
    html.AppendLine('        : " <button class=\"act-btn success\" onclick=\"toggleTask(''" + t.name + "'',true)\">Resume</button>";');
    html.AppendLine('      var histBtn  = " <button class=\"act-btn\" onclick=\"showHistory(''" + t.name + "'')\">&#128203; Log</button>";');
    html.AppendLine('      var delBtn   = " <button class=\"act-btn danger\" onclick=\"deleteTask(''" + t.name + "'')\">&#128465; Del</button>";');
    html.AppendLine('      return "<tr>"');
    html.AppendLine('        + "<td class=\"td-name\">" + t.name + (t.noOverlap ? " <span class=\"no-overlap-tag\" title=\"No concurrent execution\">&#128274;</span>" : "") + "</td>"');
    html.AppendLine('        + "<td>" + statusBadge(t) + "</td>"');
    html.AppendLine('        + "<td class=\"td-mono\">" + scheduleLabel(t) + (t.finished?" <span style=\"color:var(--muted);font-size:11px;\">(expired)</span>":"") + "</td>"');
    html.AppendLine('        + "<td class=\"td-mono\">" + fmtDate(t.lastExecution) + "</td>"');
    html.AppendLine('        + "<td class=\"td-mono\">" + fmtDate(t.nextExecution) + "</td>"');
    html.AppendLine('        + "<td class=\"td-mono\" style=\"text-align:center\">" + t.executionTimes + "</td>"');
    html.AppendLine('        + "<td class=\"td-mono\" style=\"text-align:center\">" + t.numRetries + (t.maxRetries>0?" / "+t.maxRetries:"") + retryBackoffLabel(t) + "</td>"');
    html.AppendLine('        + "<td class=\"td-actions\">" + runBtn + stopBtn + toggleBtn + histBtn + delBtn + "</td>"');
    html.AppendLine('        + "</tr>";');
    html.AppendLine('    }).join("");');
    html.AppendLine('    return rows;');
    html.AppendLine('  }');
    html.AppendLine('  // Global state');
    html.AppendLine('  var allTasks = []; var currentFilter = ''all'';');
    html.AppendLine('  function updateStatCards(tasks) {');
    html.AppendLine('    var nR=0,nD=0,nE=0,nDis=0;');
    html.AppendLine('    (tasks||[]).forEach(function(t) {');
    html.AppendLine('      if (!t.enabled) nDis++;');
    html.AppendLine('      else if (t.status==="Running")   nR++;');
    html.AppendLine('      else if (t.status==="Done")      nD++;');
    html.AppendLine('      else if (t.status==="Exception") nE++;');
    html.AppendLine('    });');
    html.AppendLine('    setText("st-total",   tasks.length);');
    html.AppendLine('    setText("st-running", nR);');
    html.AppendLine('    setText("st-done",    nD);');
    html.AppendLine('    setText("st-error",   nE);');
    html.AppendLine('    setText("st-disabled",nDis);');
    html.AppendLine('  }');
    html.AppendLine('  function setFilter(f) {');
    html.AppendLine('    currentFilter = f;');
    html.AppendLine('    document.querySelectorAll(''.filter-btn'').forEach(function(b) {');
    html.AppendLine('      b.classList.toggle(''active'', b.dataset.filter === f);');
    html.AppendLine('    });');
    html.AppendLine('    applyFilter();');
    html.AppendLine('  }');
    html.AppendLine('  function applyFilter() {');
    html.AppendLine('    var search = ((document.getElementById(''task-search'')||{}).value||'''').toLowerCase();');
    html.AppendLine('    var filtered = (allTasks||[]).filter(function(t) {');
    html.AppendLine('      var nm = !search || t.name.toLowerCase().indexOf(search) >= 0;');
    html.AppendLine('      var sm = currentFilter===''all''');
    html.AppendLine('        || (currentFilter===''running''  && t.enabled && t.status===''Running'')'); 
    html.AppendLine('        || (currentFilter===''done''     && t.status===''Done'')'); 
    html.AppendLine('        || (currentFilter===''failed''   && t.status===''Exception'')'); 
    html.AppendLine('        || (currentFilter===''skipped''  && t.status===''Skipped'')'); 
    html.AppendLine('        || (currentFilter===''disabled'' && !t.enabled);');
    html.AppendLine('      return nm && sm;');
    html.AppendLine('    });');
    html.AppendLine('    document.getElementById(''tasks-body'').innerHTML = renderRows(filtered);');
    html.AppendLine('    setText(''fb-all'',      allTasks.length);');
    html.AppendLine('    setText(''fb-running'',  allTasks.filter(function(t){return t.enabled&&t.status===''Running'';}).length);');
    html.AppendLine('    setText(''fb-done'',     allTasks.filter(function(t){return t.status===''Done'';}).length);');
    html.AppendLine('    setText(''fb-failed'',   allTasks.filter(function(t){return t.status===''Exception'';}).length);');
    html.AppendLine('    setText(''fb-skipped'',  allTasks.filter(function(t){return t.status===''Skipped'';}).length);');
    html.AppendLine('    setText(''fb-disabled'', allTasks.filter(function(t){return !t.enabled;}).length);');
    html.AppendLine('  }');
    html.AppendLine('  function setText(id, val) { var e=document.getElementById(id); if(e) e.textContent=val; }');
    html.AppendLine('  async function loadTasks() {');
    html.AppendLine('    try {');
    html.AppendLine('      var r = await fetch("/TaskControl/Tasks", { cache: "no-store" });');
    html.AppendLine('      var d = await r.json();');
    html.AppendLine('      allTasks = d.scheduled || [];');
    html.AppendLine('      updateStatCards(allTasks);');
    html.AppendLine('      applyFilter();');
    html.AppendLine('      var bg = d.background || {};');
    html.AppendLine('      setText("bg-queued",  bg.queued  || 0);');
    html.AppendLine('      setText("bg-active",  bg.active  || 0);');
    html.AppendLine('      setText("bg-workers", bg.workers || 0);');
    html.AppendLine('      setText("bg-total",   bg.totalPushed || 0);');
    html.AppendLine('      setText("st-queue",   bg.queued  || 0);');
    html.AppendLine('      setPausedUI(d.paused === true);');
    html.AppendLine('      document.getElementById("last-update").textContent = new Date().toLocaleTimeString();');
    html.AppendLine('    } catch(e) {');
    html.AppendLine('      document.getElementById("tasks-body").innerHTML = "<tr><td colspan=\"8\" style=\"text-align:center;color:var(--error);padding:32px\">Error loading tasks: " + e + "</td></tr>";');
    html.AppendLine('    }');
    html.AppendLine('  }');
    // Theme
    html.AppendLine('  function applyTheme(theme) {');
    html.AppendLine('    if (theme === "light") document.documentElement.setAttribute("data-theme", "light");');
    html.AppendLine('    else document.documentElement.removeAttribute("data-theme");');
    html.AppendLine('    var btn = document.getElementById("theme-toggle");');
    html.AppendLine('    if (btn) btn.innerHTML = theme === "light" ? "&#9790; Dark" : "&#9728; Light";');
    html.AppendLine('  }');
    html.AppendLine('  function toggleTheme() {');
    html.AppendLine('    var isLight = document.documentElement.getAttribute("data-theme") === "light";');
    html.AppendLine('    var next = isLight ? "dark" : "light";');
    html.AppendLine('    localStorage.setItem("tc-theme", next);');
    html.AppendLine('    applyTheme(next);');
    html.AppendLine('  }');
    // Refresh interval
    html.AppendLine('  var pollTimer = null;');
    html.AppendLine('  function setRefreshInterval(ms) {');
    html.AppendLine('    if (pollTimer) clearInterval(pollTimer);');
    html.AppendLine('    pollTimer = setInterval(function() {');
    html.AppendLine('      loadTasks();');
    html.AppendLine('      var jobsVisible = document.getElementById("tab-jobs").style.display !== "none";');
    html.AppendLine('      if (jobsVisible) loadJobs();');
    html.AppendLine('    }, ms);');
    html.AppendLine('    localStorage.setItem("tc-refresh", String(ms));');
    html.AppendLine('    document.querySelectorAll(".interval-btn").forEach(function(b) {');
    html.AppendLine('      b.classList.toggle("active", Number(b.dataset.ms) === ms);');
    html.AppendLine('    });');
    html.AppendLine('  }');
    // Init
    html.AppendLine('  (function() {');
    html.AppendLine('    var saved = localStorage.getItem("tc-theme");');
    html.AppendLine('    var serverDefault = "' + LowerCase(GTaskControlUIDefaultTheme) + '";');
    html.AppendLine('    var prefersLight = window.matchMedia && window.matchMedia("(prefers-color-scheme: light)").matches;');
    html.AppendLine('    applyTheme(saved || (prefersLight ? "light" : serverDefault));');
    html.AppendLine('  })();');
    html.AppendLine('  loadTasks();');
    // Jobs tab JS
    html.AppendLine('  // ── Jobs tab ──────────────────────────────────────────');
    html.AppendLine('  var jobStatus = ''''; var jobPage = 1; var jobPageSize = 50; var jobTotal = 0; var jobRunningItems = null;');
    html.AppendLine('  var jobTabLoaded = false;');
    html.AppendLine('  function showTab(tab) {');
    html.AppendLine('    var rec  = document.getElementById("tab-recurring");');
    html.AppendLine('    var jobs = document.getElementById("tab-jobs");');
    html.AppendLine('    var bRec  = document.getElementById("tab-btn-recurring");');
    html.AppendLine('    var bJobs = document.getElementById("tab-btn-jobs");');
    html.AppendLine('    if (tab === "jobs") {');
    html.AppendLine('      rec.style.display  = "none";  jobs.style.display = "";');
    html.AppendLine('      bRec.classList.remove("active"); bJobs.classList.add("active");');
    html.AppendLine('      if (!jobTabLoaded) { jobTabLoaded = true; loadJobs(); }');
    html.AppendLine('    } else {');
    html.AppendLine('      jobs.style.display = "none"; rec.style.display  = "";');
    html.AppendLine('      bJobs.classList.remove("active"); bRec.classList.add("active");');
    html.AppendLine('    }');
    html.AppendLine('  }');
    html.AppendLine('  function setJobFilter(st) {');
    html.AppendLine('    jobStatus = st; jobPage = 1;');
    html.AppendLine('    ["jf-all","jf-running","jf-succeeded","jf-failed","jf-skipped"].forEach(function(id) {');
    html.AppendLine('      document.getElementById(id).classList.remove("active");');
    html.AppendLine('    });');
    html.AppendLine('    var map = {"":"jf-all","Running":"jf-running","Done":"jf-succeeded","Exception":"jf-failed","Skipped":"jf-skipped"};');
    html.AppendLine('    var btn = document.getElementById(map[st] || "jf-all");');
    html.AppendLine('    if (btn) btn.classList.add("active");');
    html.AppendLine('    loadJobs();');
    html.AppendLine('  }');
    html.AppendLine('  function jobPrev() { if (jobPage > 1) { jobPage--; loadJobs(); } }');
    html.AppendLine('  function jobNext() { if (jobPage * jobPageSize < jobTotal) { jobPage++; loadJobs(); } }');
    html.AppendLine('  async function loadJobs() {');
    html.AppendLine('    document.getElementById("jobs-body").innerHTML = ''<tr><td colspan="5" style="text-align:center;color:var(--muted);padding:32px">Loading...</td></tr>'';');
    html.AppendLine('    try {');
    html.AppendLine('      if (jobStatus === "Running") {');
    // ── Running only: live data from /Tasks ──
    html.AppendLine('        var r = await fetch("/TaskControl/Tasks", { cache: "no-store" });');
    html.AppendLine('        var d = await r.json();');
    html.AppendLine('        var scheduledRunning = (d.scheduled || []).filter(function(t) { return t.status === "Running"; });');
    html.AppendLine('        var bgRunning = (d.background_running || []).map(function(r) {');
    html.AppendLine('          return { name: r.name, status: "Running", lastExecution: r.startTime, isBg: true };');
    html.AppendLine('        });');
    html.AppendLine('        var running = scheduledRunning.concat(bgRunning);');
    html.AppendLine('        jobTotal = running.length;');
    html.AppendLine('        setText("jf-total", jobTotal);');
    html.AppendLine('        document.getElementById("jobs-body").innerHTML = running.length > 0 ? renderRunningRows(running) : ''<tr><td colspan="5" style="text-align:center;color:var(--muted);padding:32px">No running jobs at this moment</td></tr>'';');
    html.AppendLine('        document.getElementById("jobs-pager").style.display = "none";');
    html.AppendLine('      } else if (jobStatus === "") {');
    // ── All: running (live) + history, in parallel ──
    html.AppendLine('        var histUrl = "/TaskControl/Jobs?status=&page=" + jobPage + "&pageSize=" + jobPageSize;');
    html.AppendLine('        var results = await Promise.all([');
    html.AppendLine('          fetch("/TaskControl/Tasks", { cache: "no-store" }).then(function(r){ return r.json(); }),');
    html.AppendLine('          fetch(histUrl,              { cache: "no-store" }).then(function(r){ return r.json(); })');
    html.AppendLine('        ]);');
    html.AppendLine('        var running  = (results[0].scheduled || []).filter(function(t){ return t.status === "Running"; });');
    html.AppendLine('        // merge BG tasks currently executing as running rows');
    html.AppendLine('        var bgRunning = (results[0].background_running || []).map(function(r) {');
    html.AppendLine('          return { name: r.name, status: "Running", lastExecution: r.startTime, isBg: true };');
    html.AppendLine('        });');
    html.AppendLine('        var allRunning = running.concat(bgRunning);');
    html.AppendLine('        var histData = results[1];');
    html.AppendLine('        var histTotal = histData.total || 0;');
    html.AppendLine('        jobTotal = allRunning.length + histTotal;');
    html.AppendLine('        setText("jf-total", jobTotal);');
    html.AppendLine('        var rowsHtml = renderRunningRows(allRunning) + renderJobRows(histData.items || [], allRunning.length === 0 && histTotal === 0);');
    html.AppendLine('        if (allRunning.length === 0 && histTotal === 0)');
    html.AppendLine('          rowsHtml = ''<tr><td colspan="5" style="text-align:center;color:var(--muted);padding:32px">No job executions found</td></tr>'';');
    html.AppendLine('        document.getElementById("jobs-body").innerHTML = rowsHtml;');
    html.AppendLine('        var pager = document.getElementById("jobs-pager");');
    html.AppendLine('        pager.style.display = histTotal > jobPageSize ? "" : "none";');
    html.AppendLine('        var totalPages = Math.ceil(histTotal / jobPageSize);');
    html.AppendLine('        setText("jobs-page-info", "Page " + jobPage + " of " + (totalPages||1) + " (" + histTotal + " history entries)");');
    html.AppendLine('        document.getElementById("jobs-prev").disabled = jobPage <= 1;');
    html.AppendLine('        document.getElementById("jobs-next").disabled = jobPage >= totalPages;');
    html.AppendLine('      } else {');
    // ── Specific status filter: history only ──
    html.AppendLine('        var url = "/TaskControl/Jobs?status=" + encodeURIComponent(jobStatus)');
    html.AppendLine('                + "&page=" + jobPage + "&pageSize=" + jobPageSize;');
    html.AppendLine('        var r = await fetch(url, { cache: "no-store" });');
    html.AppendLine('        var d = await r.json();');
    html.AppendLine('        jobTotal = d.total || 0;');
    html.AppendLine('        setText("jf-total", jobTotal);');
    html.AppendLine('        document.getElementById("jobs-body").innerHTML = renderJobRows(d.items || [], true);');
    html.AppendLine('        var pager = document.getElementById("jobs-pager");');
    html.AppendLine('        pager.style.display = jobTotal > jobPageSize ? "" : "none";');
    html.AppendLine('        var totalPages = Math.ceil(jobTotal / jobPageSize);');
    html.AppendLine('        setText("jobs-page-info", "Page " + jobPage + " of " + (totalPages||1) + " (" + jobTotal + " entries)");');
    html.AppendLine('        document.getElementById("jobs-prev").disabled = jobPage <= 1;');
    html.AppendLine('        document.getElementById("jobs-next").disabled = jobPage >= totalPages;');
    html.AppendLine('      }');
    html.AppendLine('    } catch(e) {');
    html.AppendLine('      document.getElementById("jobs-body").innerHTML = ''<tr><td colspan="5" style="text-align:center;color:var(--error);padding:32px">Error: '' + e + "</td></tr>";');
    html.AppendLine('    }');
    html.AppendLine('  }');
    html.AppendLine('  function renderRunningRows(tasks) {');
    html.AppendLine('    if (!tasks || tasks.length === 0) return "";');
    html.AppendLine('    return tasks.map(function(t) {');
    html.AppendLine('      var dt = t.lastExecution ? new Date(t.lastExecution).toLocaleString() : "--";');
    html.AppendLine('      var badge = t.isBg');
    html.AppendLine('        ? ''<span class="st-badge st-running">&#9654; Running <small style="opacity:.7">(bg)</small></span>''');
    html.AppendLine('        : ''<span class="st-badge st-running">&#9654; Running</span>'';');
    html.AppendLine('      return "<tr>"');
    html.AppendLine('        + ''<td class="td-name">'' + t.name + "</td>"');
    html.AppendLine('        + ''<td class="td-mono">'' + dt + "</td>"');
    html.AppendLine('        + ''<td class="dur-badge">--</td>''');
    html.AppendLine('        + "<td>" + badge + "</td>"');
    html.AppendLine('        + "<td></td>"');
    html.AppendLine('        + "</tr>";');
    html.AppendLine('    }).join("");');
    html.AppendLine('  }');
    html.AppendLine('  function renderJobRows(items, showEmpty) {');
    html.AppendLine('    if (!items || items.length === 0) {');
    html.AppendLine('      if (!showEmpty) return "";');
    html.AppendLine('      return ''<tr><td colspan="5" style="text-align:center;color:var(--muted);padding:32px">No job executions found</td></tr>'';');
    html.AppendLine('    }');
    html.AppendLine('    var stMap = {');
    html.AppendLine('      "Done":      ''<span class="st-badge st-done">&#10003; Succeeded</span>'',');
    html.AppendLine('      "Exception": ''<span class="st-badge st-error">&#9888; Failed</span>'',');
    html.AppendLine('      "Skipped":   ''<span class="st-badge st-skipped">&#8634; Skipped</span>''');
    html.AppendLine('    };');
    html.AppendLine('    return items.map(function(j) {');
    html.AppendLine('      var st  = stMap[j.status] || (''<span class="st-badge st-pending">'' + j.status + ''</span>'');');
    html.AppendLine('      var dt  = j.execTime ? new Date(j.execTime).toLocaleString() : "--";');
    html.AppendLine('      var dur = j.durationMs >= 1000');
    html.AppendLine('        ? (j.durationMs / 1000).toFixed(2) + " s"');
    html.AppendLine('        : j.durationMs + " ms";');
    html.AppendLine('      var err = (j.errorMessage && j.errorMessage.length > 0)');
    html.AppendLine('        ? (''<span style="color:var(--error);font-size:11px;" title="'' + j.exceptionType + ''">'' + j.errorMessage + ''</span>'')');
    html.AppendLine('        : "";');
    html.AppendLine('      return "<tr>"');
    html.AppendLine('        + ''<td class="td-name">'' + j.taskName + "</td>"');
    html.AppendLine('        + ''<td class="td-mono">'' + dt + "</td>"');
    html.AppendLine('        + ''<td class="dur-badge">'' + dur + "</td>"');
    html.AppendLine('        + "<td>" + st + "</td>"');
    html.AppendLine('        + ''<td style="font-size:11px;max-width:220px;overflow:hidden;text-overflow:ellipsis;">'' + err + "</td>"');
    html.AppendLine('        + "</tr>";');
    html.AppendLine('    }).join("");');
    html.AppendLine('  }');
    html.AppendLine('  (function() {');
    html.AppendLine('    var saved = parseInt(localStorage.getItem("tc-refresh") || "' + IntToStr(GTaskControlUIAutoRefreshMs) + '", 10);');
    html.AppendLine('    setRefreshInterval(saved);');
    html.AppendLine('    document.querySelectorAll(".interval-btn").forEach(function(b) {');
    html.AppendLine('      if (Number(b.dataset.ms) === saved) b.classList.add("active");');
    html.AppendLine('    });');
    html.AppendLine('  })();');
    html.AppendLine('</script>');
    html.AppendLine('<div class="modal-overlay" id="hist-modal" onclick="if(event.target===this)closeHistModal()">');
    html.AppendLine('  <div class="modal-box">');
    html.AppendLine('    <div class="modal-head">');
    html.AppendLine('      <span class="modal-title" id="hist-modal-title">History</span>');
    html.AppendLine('      <button class="modal-close" onclick="closeHistModal()">&#10005;</button>');
    html.AppendLine('    </div>');
    html.AppendLine('    <div class="modal-body" id="hist-modal-body"></div>');
    html.AppendLine('  </div>');
    html.AppendLine('</div>');
    html.AppendLine('</body>');
    html.AppendLine('</html>');
    Result := TContentResult.Create(html.ToString, 'text/html');
  finally
    html.Free;
  end;
end;

end.
