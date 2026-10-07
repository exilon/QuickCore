{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Entity.Repository
  Description : Core Entity Generic Repository Pattern
  Author      : Kike Perez
  Version     : 1.0
  Created     : 13/04/2026
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

unit Quick.Core.Entity.Repository;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Rtti,
  System.Generics.Collections,
  Quick.Core.Entity,
  Quick.Core.Entity.DAO,
  Quick.Core.Entity.Query;

type
  /// <summary>Generic repository interface for a single entity type T.
  ///  Provides CRUD + LINQ query access without exposing the DB context.</summary>
  IRepository<T : TEntity, constructor> = interface
  ['{4D8C1F6B-A3E7-4D97-BD38-EC74A2881C40}']
    function GetById(const aId : TAutoID) : T;
    function GetAll : TList<T>;
    function Add(aEntity : T) : Boolean;
    function AddOrUpdate(aEntity : T) : Boolean;
    function Update(aEntity : T) : Boolean;
    function Delete(aEntity : T) : Boolean; overload;
    function DeleteById(const aId : TAutoID) : Boolean;
    function Count : Int64;
    function Exists(const aId : TAutoID) : Boolean;
    {$IFDEF VALUE_FORMATPARAMS}
    function Find(const aWhere : string; const aParams : array of TValue) : TList<T>;
    {$ELSE}
    function Find(const aWhere : string; const aParams : array of const) : TList<T>;
    {$ENDIF}
    function FindFirst(const aWhere : string) : T;
    function Query : IEntityLinqQuery<T>;
  end;

  /// <summary>Concrete generic repository backed by a TDBSet<T>.</summary>
  TEntityRepository<T : TEntity, constructor> = class(TInterfacedObject, IRepository<T>)
  private
    fDBSet : TDBSet<T>;
    fPrimaryKeyName : string;
    function BuildIdWhere(const aId : TAutoID) : string;
  public
    constructor Create(aDBSet : TDBSet<T>; const aPrimaryKeyName : string = 'Id');
    function GetById(const aId : TAutoID) : T;
    function GetAll : TList<T>;
    function Add(aEntity : T) : Boolean;
    function AddOrUpdate(aEntity : T) : Boolean;
    function Update(aEntity : T) : Boolean;
    function Delete(aEntity : T) : Boolean; overload;
    function DeleteById(const aId : TAutoID) : Boolean;
    function Count : Int64;
    function Exists(const aId : TAutoID) : Boolean;
    {$IFDEF VALUE_FORMATPARAMS}
    function Find(const aWhere : string; const aParams : array of TValue) : TList<T>;
    {$ELSE}
    function Find(const aWhere : string; const aParams : array of const) : TList<T>;
    {$ENDIF}
    function FindFirst(const aWhere : string) : T;
    function Query : IEntityLinqQuery<T>;
  end;

implementation

{ TEntityRepository<T> }

constructor TEntityRepository<T>.Create(aDBSet : TDBSet<T>; const aPrimaryKeyName : string);
begin
  fDBSet := aDBSet;
  fPrimaryKeyName := aPrimaryKeyName;
  if fPrimaryKeyName = '' then fPrimaryKeyName := 'Id';
end;

function TEntityRepository<T>.BuildIdWhere(const aId : TAutoID) : string;
begin
  Result := fPrimaryKeyName + ' = ' + IntToStr(aId);
end;

function TEntityRepository<T>.GetById(const aId : TAutoID) : T;
begin
  Result := fDBSet.Where(BuildIdWhere(aId)).SelectFirst;
end;

function TEntityRepository<T>.GetAll : TList<T>;
var
  resultSet : IEntityResult<T>;
  item : T;
begin
  Result := TList<T>.Create;
  resultSet := fDBSet.Where('').Select;
  for item in resultSet do
    Result.Add(item);
end;

function TEntityRepository<T>.Add(aEntity : T) : Boolean;
begin
  Result := fDBSet.Add(aEntity);
end;

function TEntityRepository<T>.AddOrUpdate(aEntity : T) : Boolean;
begin
  Result := fDBSet.AddOrUpdate(aEntity);
end;

function TEntityRepository<T>.Update(aEntity : T) : Boolean;
begin
  Result := fDBSet.Update(aEntity);
end;

function TEntityRepository<T>.Delete(aEntity : T) : Boolean;
begin
  Result := fDBSet.Delete(aEntity);
end;

function TEntityRepository<T>.DeleteById(const aId : TAutoID) : Boolean;
begin
  Result := fDBSet.Delete(BuildIdWhere(aId));
end;

function TEntityRepository<T>.Count : Int64;
begin
  Result := fDBSet.Where('').Count;
end;

function TEntityRepository<T>.Exists(const aId : TAutoID) : Boolean;
begin
  Result := fDBSet.Where(BuildIdWhere(aId)).Count > 0;
end;

{$IFDEF VALUE_FORMATPARAMS}
function TEntityRepository<T>.Find(const aWhere : string; const aParams : array of TValue) : TList<T>;
var
  resultSet : IEntityResult<T>;
  item : T;
begin
  Result := TList<T>.Create;
  resultSet := fDBSet.Where(aWhere, aParams).Select;
  for item in resultSet do
    Result.Add(item);
end;
{$ELSE}
function TEntityRepository<T>.Find(const aWhere : string; const aParams : array of const) : TList<T>;
var
  resultSet : IEntityResult<T>;
  item : T;
begin
  Result := TList<T>.Create;
  resultSet := fDBSet.Where(aWhere, aParams).Select;
  for item in resultSet do
    Result.Add(item);
end;
{$ENDIF}

function TEntityRepository<T>.FindFirst(const aWhere : string) : T;
begin
  Result := fDBSet.Where(aWhere).SelectFirst;
end;

function TEntityRepository<T>.Query : IEntityLinqQuery<T>;
begin
  Result := fDBSet.Where('');
end;

end.
