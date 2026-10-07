program MinimalApiSample;

(* MinimalApiSample - S-33
  Demonstrates the Minimal API pattern with QuickCore MVC.
  No controller classes are needed — HTTP verbs are mapped to inline
  anonymous functions via MapGet / MapPost / MapPut / MapDelete.

  In-memory task list CRUD:
    GET    /tasks        — list all tasks
    GET    /tasks/{id}   — get task by id
    POST   /tasks        — create task  (body: {"title":"...","done":false})
    PUT    /tasks/{id}   — update task  (body: {"title":"...","done":true})
    DELETE /tasks/{id}   — delete task

  .NET equivalent: app.MapGet / MapPost / MapPut / MapDelete in
  Program.cs Minimal API style (introduced in .NET 6).
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Generics.Collections,
  StrUtils,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Quick.Core.Mvc.Context,
  Quick.Core.DependencyInjection,
  Quick.Core.Logging;

// ── In-memory task store ───────────────────────────────────────────────────────
type
  TTask = record
    Id    : Integer;
    Title : string;
    Done  : Boolean;
  end;

var
  Tasks   : TList<TTask>;
  NextId  : Integer;
  ApiServer: TMvcServer;

// ── TTask constructor ───────────────────────────────────────────────────────────
function TTask_Create(aId: Integer; const aTitle: string; aDone: Boolean): TTask;
begin
  Result.Id    := aId;
  Result.Title := aTitle;
  Result.Done  := aDone;
end;

// ── Helper to format a task as JSON ──────────────────────────────────────────
function TaskToJson(const t : TTask) : string;
begin
  Result := Format('{"id":%d,"title":"%s","done":%s}',
    [t.Id, t.Title, IfThen(t.Done, 'true', 'false')]);
end;

// ── Main ──────────────────────────────────────────────────────────────────────
begin
  ReportMemoryLeaksOnShutdown := True;
  Tasks  := TList<TTask>.Create;
  NextId := 1;

  // Seed some data
  Tasks.Add(TTask_Create(1, 'Buy groceries', False));
  Tasks.Add(TTask_Create(2, 'Write sample', True));
  NextId := 3;

  try
    if not AppService.IsRunningAsService then
    begin
      cout('MinimalApiSample (S-33) on http://localhost:8080 ...', etInfo);
      cout('', ccWhite);
      cout('  GET    /tasks          — list tasks', ccCyan);
      cout('  GET    /tasks/1        — get task by id', ccCyan);
      cout('  POST   /tasks          — create task', ccCyan);
      cout('  PUT    /tasks/1        — update task', ccCyan);
      cout('  DELETE /tasks/1        — delete task', ccCyan);

      ApiServer := TMvcServer.Create('127.0.0.1', 8080, False);
      try
        // ── Configure DI ─────────────────────────────────────────────────────
        ApiServer
          .Services
          .AddLogging(TLoggerBuilder.GetBuilder
            .AddConsole(procedure(o : TConsoleLoggerOptions)
              begin
                o.LogLevel        := LOG_DEBUG;
                o.ShowEventColors := True;
                o.ShowTimeStamp   := True;
                o.ShowEventType   := False;
                o.Enabled         := True;
              end)
            .Build);

        // ── Map routes — no controllers needed ───────────────────────────────
        ApiServer
          .UseRouting

          // GET /tasks
          .MapGet('/tasks',
            function(ctx : THttpContextBase) : string
            var
              sb    : TStringBuilder;
              first : Boolean;
              t     : TTask;
            begin
              sb    := TStringBuilder.Create;
              first := True;
              try
                sb.Append('[');
                for t in Tasks do
                begin
                  if not first then sb.Append(',');
                  sb.Append(TaskToJson(t));
                  first := False;
                end;
                sb.Append(']');
                ctx.Response.ContentType := 'application/json';
                Result := sb.ToString;
              finally
                sb.Free;
              end;
            end)

          // GET /tasks/{id}
          .MapGet('/tasks/{id}',
            function(ctx : THttpContextBase) : string
            var
              id : Integer;
              t  : TTask;
            begin
              id := StrToIntDef(ctx.Request.URL.Split(['/'])[2], 0);
              for t in Tasks do
                if t.Id = id then
                begin
                  ctx.Response.ContentType := 'application/json';
                  Exit(TaskToJson(t));
                end;
              ctx.Response.StatusCode := 404;
              Result := '{"error":"Task not found"}';
            end)

          // POST /tasks
          .MapPost('/tasks',
            function(ctx : THttpContextBase) : string
            var
              body  : string;
              t     : TTask;
              title : string;
            begin
              body  := ctx.Request.ContentAsString;
              // Simple parse: extract "title" value
              title := '';
              if body.Contains('"title"') then
              begin
                title := body;
                title := Copy(title, title.IndexOf('"title"') + 9, MaxInt);
                title := Copy(title, title.IndexOf('"') + 2, MaxInt);
                title := Copy(title, 1, title.IndexOf('"'));
              end;
              if title = '' then
              begin
                ctx.Response.StatusCode := 400;
                Exit('{"error":"title is required"}');
              end;
              t.Id    := NextId;
              t.Title := title;
              t.Done  := False;
              Inc(NextId);
              Tasks.Add(t);
              ctx.Response.StatusCode  := 201;
              ctx.Response.ContentType := 'application/json';
              Result := TaskToJson(t);
            end)

          // PUT /tasks/{id}
          .MapPut('/tasks/{id}',
            function(ctx : THttpContextBase) : string
            var
              id    : Integer;
              body  : string;
              i     : Integer;
              t     : TTask;
              title : string;
              done  : Boolean;
            begin
              id   := StrToIntDef(ctx.Request.URL.Split(['/'])[2], 0);
              body := ctx.Request.ContentAsString;
              title := '';
              done  := False;
              if body.Contains('"title"') then
              begin
                title := body;
                title := Copy(title, title.IndexOf('"title"') + 9, MaxInt);
                title := Copy(title, title.IndexOf('"') + 2, MaxInt);
                title := Copy(title, 1, title.IndexOf('"'));
              end;
              if body.Contains('"done":true') then done := True;
              for i := 0 to Tasks.Count - 1 do
                if Tasks[i].Id = id then
                begin
                  t       := Tasks[i];
                  if title <> '' then t.Title := title;
                  t.Done  := done;
                  Tasks[i] := t;
                  ctx.Response.ContentType := 'application/json';
                  Exit(TaskToJson(t));
                end;
              ctx.Response.StatusCode := 404;
              Result := '{"error":"Task not found"}';
            end)

          // DELETE /tasks/{id}
          .MapDelete('/tasks/{id}',
            function(ctx : THttpContextBase) : string
            var
              id : Integer;
              i  : Integer;
            begin
              id := StrToIntDef(ctx.Request.URL.Split(['/'])[2], 0);
              for i := 0 to Tasks.Count - 1 do
                if Tasks[i].Id = id then
                begin
                  Tasks.Delete(i);
                  ctx.Response.StatusCode := 204;
                  Exit('');
                end;
              ctx.Response.StatusCode := 404;
              Result := '{"error":"Task not found"}';
            end);

        ApiServer.Start;
      finally
        ApiServer.Free;
      end;
    end
    else
    begin
      AppService.DisplayName := 'MinimalApiSample';
      AppService.ServiceName := 'MinimalApiSampleSvc';
      AppService.CanInstallWithOtherName := True;
      AppService.CheckParams;
    end;
  except
    on E : Exception do
    begin
      cout('Fatal: ' + E.Message, etError);
      ExitCode := 1;
    end;
  end;
  Tasks.Free;
end.
