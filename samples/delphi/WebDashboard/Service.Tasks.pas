unit Service.Tasks;

{ WebDashboard — S-26
  In-memory task list service shared across requests.
  Thread-safe via TCriticalSection. }

interface

uses
  System.SysUtils,
  System.SyncObjs,
  System.Generics.Collections;

type
  TTaskStatus = (tsPending, tsDone);

  TTask = class
  private
    fId       : Integer;
    fTitle    : string;
    fStatus   : TTaskStatus;
    fCreatedAt : TDateTime;
  public
    property Id        : Integer     read fId        write fId;
    property Title     : string      read fTitle     write fTitle;
    property Status    : TTaskStatus read fStatus    write fStatus;
    property CreatedAt : TDateTime   read fCreatedAt write fCreatedAt;
    function StatusText : string;
    function ToJson : string;
  end;

  ITaskService = interface
  ['{A0B1C2D3-E4F5-4A6B-7C8D-9E0F1A2B3C4D}']
    function  GetAll              : TArray<TTask>;
    function  GetById    (aId : Integer) : TTask;
    function  Add        (const aTitle : string) : TTask;
    procedure Complete   (aId : Integer);
    procedure Delete     (aId : Integer);
    function  GetStats   : string;  // JSON server stats blob
  end;

  TTaskService = class(TInterfacedObject, ITaskService)
  private
    fItems      : TObjectList<TTask>;
    fNextId     : Integer;
    fLock       : TCriticalSection;
    fStartTime  : TDateTime;
    fReqCount   : Integer;
  public
    constructor Create;
    destructor  Destroy; override;
    function  GetAll              : TArray<TTask>;
    function  GetById    (aId : Integer) : TTask;
    function  Add        (const aTitle : string) : TTask;
    procedure Complete   (aId : Integer);
    procedure Delete     (aId : Integer);
    function  GetStats   : string;
    procedure IncrementRequests;
  end;

implementation

uses
  System.DateUtils;

{ TTask }

function TTask.StatusText: string;
begin
  if fStatus = tsPending then Result := 'pending' else Result := 'done';
end;

function TTask.ToJson: string;
begin
  Result := Format('{"id":%d,"title":"%s","status":"%s","createdAt":"%s"}',
    [fId,
     StringReplace(fTitle, '"', '\"', [rfReplaceAll]),
     StatusText,
     FormatDateTime('yyyy-mm-dd hh:nn:ss', fCreatedAt)]);
end;

{ TTaskService }

constructor TTaskService.Create;
var
  t : TTask;
begin
  fItems     := TObjectList<TTask>.Create(True);
  fNextId    := 1;
  fLock      := TCriticalSection.Create;
  fStartTime := Now;
  fReqCount  := 0;

  // Seed initial tasks
  t := TTask.Create;
  t.Id := fNextId; Inc(fNextId);
  t.Title     := 'Review QuickCore README';
  t.Status    := tsDone;
  t.CreatedAt := Now - 1;
  fItems.Add(t);

  t := TTask.Create;
  t.Id := fNextId; Inc(fNextId);
  t.Title     := 'Write unit tests for localization';
  t.Status    := tsPending;
  t.CreatedAt := Now;
  fItems.Add(t);

  t := TTask.Create;
  t.Id := fNextId; Inc(fNextId);
  t.Title     := 'Deploy to production server';
  t.Status    := tsPending;
  t.CreatedAt := Now;
  fItems.Add(t);
end;

destructor TTaskService.Destroy;
begin
  fLock.Free;
  fItems.Free;
  inherited;
end;

procedure TTaskService.IncrementRequests;
begin
  TInterlocked.Increment(fReqCount);
end;

function TTaskService.GetAll: TArray<TTask>;
var
  i : Integer;
begin
  fLock.Enter;
  try
    SetLength(Result, fItems.Count);
    for i := 0 to fItems.Count - 1 do
      Result[i] := fItems[i];
  finally
    fLock.Leave;
  end;
end;

function TTaskService.GetById(aId: Integer): TTask;
var
  t : TTask;
begin
  Result := nil;
  fLock.Enter;
  try
    for t in fItems do
      if t.Id = aId then
      begin
        Result := t;
        Break;
      end;
  finally
    fLock.Leave;
  end;
end;

function TTaskService.Add(const aTitle: string): TTask;
begin
  Result := TTask.Create;
  Result.Id        := fNextId;
  Result.Title     := aTitle;
  Result.Status    := tsPending;
  Result.CreatedAt := Now;
  fLock.Enter;
  try
    Inc(fNextId);
    fItems.Add(Result);
  finally
    fLock.Leave;
  end;
end;

procedure TTaskService.Complete(aId: Integer);
var
  t : TTask;
begin
  fLock.Enter;
  try
    for t in fItems do
      if t.Id = aId then
      begin
        t.Status := tsDone;
        Break;
      end;
  finally
    fLock.Leave;
  end;
end;

procedure TTaskService.Delete(aId: Integer);
var
  i : Integer;
begin
  fLock.Enter;
  try
    for i := 0 to fItems.Count - 1 do
      if fItems[i].Id = aId then
      begin
        fItems.Delete(i);
        Break;
      end;
  finally
    fLock.Leave;
  end;
end;

function TTaskService.GetStats: string;
var
  uptimeSecs : Int64;
  pending, done : Integer;
  t : TTask;
begin
  fLock.Enter;
  try
    pending := 0; done := 0;
    for t in fItems do
      if t.Status = tsPending then Inc(pending) else Inc(done);
  finally
    fLock.Leave;
  end;
  uptimeSecs := SecondsBetween(Now, fStartTime);
  Result := Format(
    '{"uptimeSeconds":%d,"totalRequests":%d,"tasksPending":%d,"tasksDone":%d,"totalTasks":%d}',
    [uptimeSecs, fReqCount, pending, done, pending + done]);
end;

end.
