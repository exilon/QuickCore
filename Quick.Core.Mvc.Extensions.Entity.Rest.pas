{ ***************************************************************************

  Copyright (c) 2016-2020 Kike Pérez

  Unit        : Quick.Core.Mvc.Extensions.Entity.Rest
  Description : Core MVC Extensions TaskControl
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 12/03/2020
  Modified    : 09/06/2020

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
  Quick.Core.MVC,
  Quick.Core.Entity,
  Quick.HttpServer.Types,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Entity.Request,
  Quick.Core.Entity.DAO;

type
  TEntityRestMVCServerExtension = class(TMVCServerExtension)
    class function UseRestApi<T : TDBContext> : TMVCServer;
  end;

  [Route('api')]
  [Authorize]
  TEntityRestController<T : TDBContext> = class(THttpController)
  private
    fDBContext : TDBContext;
    function GetWhereId(aModel: TEntityModel; const aId : string): string;
  public
    constructor Create(aDBContext : T);
  published
    [HttpPost('query/select')]
    function SelectQuery(const [FromBody]request: TEntitySelectRequest) : IActionResult;

    [HttpPost('query/update')]
    function UpdateQuery(const [FromBody]request: TEntityUpdateRequest) : IActionResult;

    [HttpPost('query/delete')]
    function DeleteQuery(const [FromBody]request: TEntityDeleteRequest) : IActionResult;

    [HttpGet('{table}/{id}')]
    function Get(const table : string; id : string) : IActionResult;

    [HttpPost('{table}')]
    function Add(const table : string; const [FromBody]value : string) : IActionResult;

    [HttpPut('{table}/{id}')]
    function Update(const table: string; const id : string; const [FromBody]value: string): IActionResult;

    [HttpDelete('{table}/{id}')]
    function Delete(const table : string; id : string) : IActionResult;
  end;

implementation

{ TEntityRestMVCServerExtension }

class function TEntityRestMVCServerExtension.UseRestApi<T>: TMVCServer;
begin
  Result := MVCServer;
  if MVCServer.Services.IsRegistered<T>('') then
  begin
    MVCServer.AddController(TEntityRestController<T>);
  end
  else raise Exception.Create('DBContext dependency not found. Need to be added before!');
end;

{ TEntityRestController }

constructor TEntityRestController<T>.Create(aDBContext : T);
begin
  fDBContext := aDBContext as TDBContext;
end;

function TEntityRestController<T>.GetWhereId(aModel: TEntityModel; const aId : string): string;
begin
  if (aModel.PrimaryKey.DataType >= TFieldDataType.dtInteger) and
     (aModel.PrimaryKey.DataType <= TFieldDataType.dtFloat) then Result := Format('%s = %s',[aModel.PrimaryKey.Name,aId])
  else Result := Format('%s = "%s"',[aModel.PrimaryKey.Name,aId]);
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
  if request.Limit = 1 then list.Add(linq.SelectFirst)
  else if request.Limit = -1 then list.Add(linq.SelectLast)
  else
  begin
    linq.SelectTop(request.Limit).ToObjectList(list);
  end;

  try
    Result := Json(list,True);
  finally
    list.Free;
  end;
end;

function TEntityRestController<T>.UpdateQuery(const request: TEntityUpdateRequest): IActionResult;
begin
  {$IFDEF DEBUG_ENTITY}
    TDebugger.Enter(Self,'UpdateQuery');
  {$ENDIF}

end;

function TEntityRestController<T>.DeleteQuery(const request: TEntityDeleteRequest): IActionResult;
begin
  {$IFDEF DEBUG_ENTITY}
    TDebugger.Enter(Self,'DeleteQuery');
  {$ENDIF}

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

  if entity = nil then HttpContext.RaiseHttpErrorNotFound(nil,'register not found in database');
  Result := Json(entity,True);
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
  Self.HttpContext.RequestServices.Serializer.Json.ToObject(entity,value);
  if dbset.Add(entity) then Result := Self.StatusCode(THttpStatusCode.Created,'')
    else HttpContext.RaiseHttpErrorNotFound(nil,'Cannot add register to database!');
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
  Self.HttpContext.RequestServices.Serializer.Json.ToObject(entity,value);
  if VarIsEmpty(entity.FieldByName(dbset.Model.PrimaryKey.Name)) then HttpContext.RaiseHttpErrorBadRequest(nil,'not defined Primary Key!');

  if dbset.Update(entity) then Result := Ok
    else HttpContext.RaiseHttpErrorNotFound(nil,'Cannot update register to database!');
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
    else HttpContext.RaiseHttpErrorNotFound(nil,'register not found in database');
end;

end.
