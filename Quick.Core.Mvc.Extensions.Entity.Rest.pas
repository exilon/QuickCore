{ ***************************************************************************

  Copyright (c) 2016-2021 Kike Pérez

  Unit        : Quick.Core.Mvc.Extensions.Entity.Rest
  Description : Core MVC Extensions TaskControl
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 12/03/2020
  Modified    : 21/05/2021

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

unit Quick.Core.Mvc.Extensions.Entity.Rest;

{$i QuickCore.inc}

interface

uses
  {$IFDEF DEBUG_ENTITY}
  Quick.Debug.Utils,
  {$ENDIF}
  System.SysUtils,
  System.Variants,
  System.Rtti,
  System.Generics.Collections,
  Quick.Options,
  Quick.Core.MVC,
  Quick.Core.Entity,
  Quick.HttpServer.Types,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Entity.Request,
  Quick.Core.Entity.DAO;

type
  TEntityRestOptions = class(TOptions)
  private
    fUser : string;
    fPassword : string;
    fNeedCredentials : Boolean;
  published
    property User : string read fUser write fUser;
    property Password : string read fPassword write fPassword;
    property NeedCredentials : Boolean read fNeedCredentials write fNeedCredentials;
  end;

  TEntityRestMVCServerExtension = class(TMVCServerExtension)
    class function UseRestApi<T : TDBContext>(aOptionsProc : TConfigureOptionsProc<TEntityRestOptions> = nil) : TMVCServer;
  end;

  [Route('api')]
  //[Authorize]
  TEntityRestController<T : TDBContext> = class(THttpController)
  private
    fDBContext : TDBContext;
    fOptions : TEntityRestOptions;
    function GetWhereId(aModel: TEntityModel; const aId : string): string;
    procedure RaiseEntityNotFound(const aMsg : string);
    procedure RaiseEntityError(const aMsg : string);
  public
    constructor Create(aDBContext : T; aOptions : IOptions<TEntityRestOptions>);
  published
    [HttpPost('connect')]
    function Connect(const [FromBody]request: TEntityConnectRequest) : IActionResult;

    [HttpPost('query/select')]
    function SelectQuery(const [FromBody]request: TEntitySelectRequest) : IActionResult;

    [HttpPost('query/update')]
    function UpdateQuery(const [FromBody]request: TEntityUpdateRequest) : IActionResult;

    [HttpPost('query/delete')]
    function DeleteQuery(const [FromBody]request: TEntityDeleteRequest) : IActionResult;

    [HttpPost('query/count')]
    function CountQuery(const [FromBody]request: TEntityCountRequest) : IActionResult;

    [HttpGet('{table}/{id}')]
    function Get(const table : string; id : string) : IActionResult;

    [HttpPost('{table}')]
    function Add(const table : string; const [FromBody]value : string) : IActionResult;

    [HttpPut('{table}/AOU/{id}')]
    function AddOrUpdate(const table: string; const id : string; const [FromBody]value: string): IActionResult;

    [HttpPut('{table}/{id}')]
    function Update(const table: string; const id : string; const [FromBody]value: string): IActionResult;

    [HttpDelete('{table}/{id}')]
    function Delete(const table : string; id : string) : IActionResult;
  end;

  EEntityRestError = class(EControlledException);

implementation

{ TEntityRestMVCServerExtension }

class function TEntityRestMVCServerExtension.UseRestApi<T>(aOptionsProc : TConfigureOptionsProc<TEntityRestOptions> = nil) : TMVCServer;
var
  restOptions : TEntityRestOptions;
begin
  Result := MVCServer;
  if MVCServer.Services.IsRegistered<T>('') then
  begin
   // restOptions := MVCServer.Services.Resolve<IOptions<TEntityRestOptions>>.Value;
    restOptions := TEntityRestOptions.Create;
    if Assigned(aOptionsProc) then aOptionsProc(restOptions)
    else
    begin
      restOptions.NeedCredentials := True;
      restOptions.User := 'admin';
      restOptions.Password := 'admin';
    end;
    MVCServer.Services.Configure<TEntityRestOptions>(restOptions);

    MVCServer.AddController(TEntityRestController<T>);
  end
  else raise EEntityRestError.Create(nil,'DBContext dependency not found. Need to be added before!');
end;

{ TEntityRestController }

constructor TEntityRestController<T>.Create(aDBContext : T; aOptions : IOptions<TEntityRestOptions>);
begin
  fDBContext := aDBContext as TDBContext;
  fOptions := aOptions.Value;
end;

function TEntityRestController<T>.GetWhereId(aModel: TEntityModel; const aId : string): string;
begin
  if (aModel.PrimaryKey.DataType >= TFieldDataType.dtInteger) and
     (aModel.PrimaryKey.DataType <= TFieldDataType.dtFloat) then Result := Format('%s = %s',[aModel.PrimaryKey.Name,aId])
  else Result := Format('%s = "%s"',[aModel.PrimaryKey.Name,aId]);
end;

procedure TEntityRestController<T>.RaiseEntityError(const aMsg: string);
begin
  Response.StatusCode := 500;
  Response.StatusText := aMsg;
  raise EControlledException.Create(nil,aMsg);
end;

procedure TEntityRestController<T>.RaiseEntityNotFound(const aMsg: string);
begin
  Response.StatusCode := 404;
  Response.StatusText := aMsg;
  raise EControlledException.Create(nil,aMsg);
end;

function TEntityRestController<T>.Connect(const [FromBody]request: TEntityConnectRequest) : IActionResult;
begin
  //check credentials
  if fOptions.NeedCredentials then
  begin
    if (CompareText(fOptions.User,request.User) <> 0) or (fOptions.Password <> request.Password) then RaiseEntityError('User/Pass not valid!');
  end;

  //if HttpContext.User.Identity.IsAuthenticated then Writeln('ok');

  Result := Content(Integer(fDBContext.Connection.Provider).ToString);
end;

function TEntityRestController<T>.SelectQuery(const request: TEntitySelectRequest): IActionResult;
var
  dbset : TDBSet<TEntity>;
  linq : IEntityLinqQuery<TEntity>;
  reslinq : IEntityResult<TEntity>;
  list : TObjectList<TEntity>;
begin
  {$IFDEF DEBUG_ENTITY}
    TDebugger.Enter(Self,'SelectQuery').TimeIt;
  {$ENDIF}
  list := nil;
  try
    dbset := fDBContext.GetDBSet(request.Table);

    //set where clause
    linq := dbset.Where(request.WhereClause);

    //set order clause
    if not request.Order.IsEmpty then
    begin
      if request.OrderAsc then linq.OrderBy(request.Order)
        else linq.OrderByDescending(request.Order);
    end;

    //select
    list := TObjectList<TEntity>.Create(True);
    try
      if request.Limit = 1 then list.Add(linq.SelectFirst)
      else if request.Limit = -1 then list.Add(linq.SelectLast)
      else
      begin
        linq.SelectTop(request.Limit).ToObjectList(list);
      end;
      Result := Json(list,True);
    finally
      list.Free;
    end;
  except
    on E : Exception do RaiseEntityError(Format('Entity: %s',[e.Message]));
  end;
end;

function TEntityRestController<T>.UpdateQuery(const request: TEntityUpdateRequest): IActionResult;
begin
  {$IFDEF DEBUG_ENTITY}
    TDebugger.Enter(Self,'UpdateQuery');
  {$ENDIF}

end;

function TEntityRestController<T>.CountQuery(const request: TEntityCountRequest): IActionResult;
var
  dbset : TDBSet<TEntity>;
begin
  {$IFDEF DEBUG_ENTITY}
    TDebugger.Enter(Self,'CountQuery').TimeIt;
  {$ENDIF}
  try
    dbset := fDBContext.GetDBSet(request.Table);
    Result := Content(dbset.Where(request.WhereClause).Count.ToString);
  except
    on E : Exception do RaiseEntityError(Format('Entity: %s',[e.Message]));
  end;
end;

function TEntityRestController<T>.DeleteQuery(const request: TEntityDeleteRequest): IActionResult;
var
  dbset : TDBSet<TEntity>;
  linq : IEntityLinqQuery<TEntity>;
  reslinq : IEntityResult<TEntity>;
begin
  {$IFDEF DEBUG_ENTITY}
    TDebugger.Enter(Self,'DeleteQuery');
  {$ENDIF}
  try
    dbset := fDBContext.GetDBSet(request.Table);

    //set where clause
    linq := dbset.Where(request.WhereClause);

    //delete
    linq.Delete;
    Result := Ok;
  except
    on E : Exception do RaiseEntityError(Format('Entity: %s',[e.Message]));
  end;
end;

function TEntityRestController<T>.Get(const table: string; id: string): IActionResult;
var
  dbset : TDBSet<TEntity>;
  entity : TEntity;
begin
  {$IFDEF DEBUG_ENTITY}
    TDebugger.Enter(Self,'Get').TimeIt;
  {$ENDIF}
  dbset := fDBContext.GetDBSet(table);

  entity := dbset.Where(GetWhereId(dbset.Model,id),[]).SelectFirst;

  if entity = nil then RaiseEntityNotFound('register not found in database');
  try
    Result := Json(entity,True);
  finally
    entity.Free;
  end;
end;

function TEntityRestController<T>.Add(const table: string; const value: string): IActionResult;
var
  dbset : TDBSet<TEntity>;
  entity : TEntity;
begin
  {$IFDEF DEBUG_ENTITY}
    TDebugger.Enter(Self,'Add').TimeIt;
  {$ENDIF}
  dbset := fDBContext.GetDBSet(table);
  entity := dbset.Model.Table.Create;
  try
    Self.HttpContext.RequestServices.Serializer.Json.ToObject(entity,value);
    if dbset.Add(entity) then Result := Self.StatusCode(THttpStatusCode.Created,'')
      else RaiseEntityNotFound('Cannot add register to database!');
  finally
    entity.Free;
  end;
end;

function TEntityRestController<T>.AddOrUpdate(const table: string; const id : string; const value: string): IActionResult;
var
  dbset : TDBSet<TEntity>;
  entity : TEntity;
begin
  {$IFDEF DEBUG_ENTITY}
    TDebugger.Enter(Self,'AddOrUpdate').TimeIt;
  {$ENDIF}
  dbset := fDBContext.GetDBSet(table);
  entity := dbset.Model.Table.Create;
  try
    Self.HttpContext.RequestServices.Serializer.Json.ToObject(entity,value);
    if entity.FieldValueIsEmpty(dbset.Model.PrimaryKey.Name) then HttpContext.RaiseHttpErrorBadRequest(nil,'not defined Primary Key!');

    if dbset.AddOrUpdate(entity) then Result := Ok
      else RaiseEntityNotFound('Cannot add or update register to database!');
  finally
    entity.Free;
  end;
end;

function TEntityRestController<T>.Update(const table: string; const id : string; const value: string): IActionResult;
var
  dbset : TDBSet<TEntity>;
  entity : TEntity;
begin
  {$IFDEF DEBUG_ENTITY}
    TDebugger.Enter(Self,'Update').TimeIt;
  {$ENDIF}
  dbset := fDBContext.GetDBSet(table);
  entity := dbset.Model.Table.Create;
  try
    Self.HttpContext.RequestServices.Serializer.Json.ToObject(entity,value);
    if entity.FieldValueIsEmpty(dbset.Model.PrimaryKey.Name) then HttpContext.RaiseHttpErrorBadRequest(nil,'not defined Primary Key!');

    if dbset.Update(entity) then Result := Ok
      else RaiseEntityNotFound('Cannot update register to database!');
  finally
    entity.Free;
  end;
end;

function TEntityRestController<T>.Delete(const table: string; id: string): IActionResult;
var
  dbset : TDBSet<TEntity>;
begin
  {$IFDEF DEBUG_ENTITY}
    TDebugger.Enter(Self,'Delete').TimeIt;
  {$ENDIF}
  dbset := fDBContext.GetDBSet(table);

  if dbset.Where(GetWhereId(dbset.Model,id),[]).Delete then Result := Ok
    else RaiseEntityNotFound('register not found in database');
end;

end.
