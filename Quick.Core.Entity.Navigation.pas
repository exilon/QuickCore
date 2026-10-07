{ ***************************************************************************

  Copyright (c) 2016-2026 Kike Perez

  Unit        : Quick.Core.Entity.Navigation
  Description : Core Entity Navigation Properties
  Author      : Kike Perez
  Version     : 1.0
  Created     : 01/06/2022
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

unit Quick.Core.Entity.Navigation;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  System.Variants,
  System.Generics.Collections,
  Quick.RTTI.Utils,
  Quick.Core.Entity.DAO,
  Quick.Core.Entity.Database;

type
  { ForeignKey — Many-to-One / One-to-One (FK on this entity).
    Decorate an entity property of type TRelatedEntity with the name of the
    FK field that lives on the CURRENT entity.

    Example:
      [ForeignKey('UserId')]
      property User : TUser read fUser write fUser;

    Meaning: load User by querying TUser WHERE PrimaryKey = Self.UserId }
  ForeignKey = class(TCustomAttribute)
  private
    fForeignKeyField : string;
  public
    constructor Create(const aForeignKeyField : string);
    property ForeignKeyField : string read fForeignKeyField;
  end;

  { HasMany — One-to-Many (FK on the related entity).
    Decorate a TObjectList<TEntity> property with the related entity class
    and the FK field name on the RELATED entity.

    NOTE: declare the property as TObjectList<TEntity>; items can be cast to
    the concrete related type at run time.

    Example:
      [HasMany(TOrderItem, 'OrderId')]
      property Items : TObjectList<TEntity> read fItems write fItems; }
  HasMany = class(TCustomAttribute)
  private
    fRelatedClass    : TEntityClass;
    fForeignKeyField : string;
  public
    constructor Create(aRelatedClass : TEntityClass; const aForeignKeyField : string);
    property RelatedClass    : TEntityClass read fRelatedClass;
    property ForeignKeyField : string       read fForeignKeyField;
  end;

  { HasOne — One-to-One (FK on the related entity side).
    Decorate an entity property with the related entity class and the FK
    field name on the RELATED entity.

    Example:
      [HasOne(TUserProfile, 'UserId')]
      property Profile : TUserProfile read fProfile write fProfile; }
  HasOne = class(TCustomAttribute)
  private
    fRelatedClass    : TEntityClass;
    fForeignKeyField : string;
  public
    constructor Create(aRelatedClass : TEntityClass; const aForeignKeyField : string);
    property RelatedClass    : TEntityClass read fRelatedClass;
    property ForeignKeyField : string       read fForeignKeyField;
  end;

  { TNavigationLoader
    Loads a single named navigation property for a given entity instance
    by executing an additional query against aEntityDatabase.

    Requirements:
      - The related entity class must already be registered in
        aEntityDatabase.Models.
      - For HasMany, the entity property must be an initialized
        TObjectList<TEntity> instance (created in the entity's constructor). }
  TNavigationLoader = class
  public
    class function LoadProperty(
      aEntityDatabase : TEntityDatabase;
      aEntity         : TEntity;
      const aPropertyName : string) : Boolean;

    { Returns True if the given RTTI property has any navigation attribute. }
    class function IsNavigationProperty(aRttiProp : TRttiProperty) : Boolean;
  end;

implementation

{ ForeignKey }

constructor ForeignKey.Create(const aForeignKeyField : string);
begin
  fForeignKeyField := aForeignKeyField;
end;

{ HasMany }

constructor HasMany.Create(aRelatedClass : TEntityClass; const aForeignKeyField : string);
begin
  fRelatedClass    := aRelatedClass;
  fForeignKeyField := aForeignKeyField;
end;

{ HasOne }

constructor HasOne.Create(aRelatedClass : TEntityClass; const aForeignKeyField : string);
begin
  fRelatedClass    := aRelatedClass;
  fForeignKeyField := aForeignKeyField;
end;

{ TNavigationLoader }

class function TNavigationLoader.IsNavigationProperty(aRttiProp : TRttiProperty) : Boolean;
var
  attr : TCustomAttribute;
begin
  for attr in aRttiProp.GetAttributes do
  begin
    if (attr is ForeignKey) or (attr is HasMany) or (attr is HasOne) then
      Exit(True);
  end;
  Result := False;
end;

class function TNavigationLoader.LoadProperty(
  aEntityDatabase : TEntityDatabase;
  aEntity         : TEntity;
  const aPropertyName : string) : Boolean;
var
  ctx         : TRttiContext;
  rType       : TRttiType;
  rProp       : TRttiProperty;
  attr        : TCustomAttribute;
  relModel    : TEntityModel;
  parentModel : TEntityModel;
  query       : IEntityQuery<TEntity>;
  linq        : IEntityLinqQuery<TEntity>;
  related     : TEntity;
  whereClause : string;
  {$IFDEF VALUE_FORMATPARAMS}
  fkValue     : TValue;
  pkValue     : TValue;
  {$ELSE}
  fkVariant   : Variant;
  pkVariant   : Variant;
  {$ENDIF}
begin
  Result := False;
  rType  := ctx.GetType(aEntity.ClassInfo);
  try
    rProp := rType.GetProperty(aPropertyName);
    if rProp = nil then Exit;

    for attr in rProp.GetAttributes do
    begin
      { ---- ForeignKey: Many-to-One ownership is on the current entity side ---- }
      if attr is ForeignKey then
      begin
        {$IFDEF VALUE_FORMATPARAMS}
        fkValue := aEntity.FieldByName(ForeignKey(attr).ForeignKeyField);
        if fkValue.IsEmpty then Exit(True);
        {$ELSE}
        fkVariant := aEntity.FieldByName(ForeignKey(attr).ForeignKeyField);
        if VarIsEmpty(fkVariant) or VarIsNull(fkVariant) then Exit(True);
        {$ENDIF}

        if not (rProp.PropertyType is TRttiInstanceType) then Exit(True);
        var instType := TRttiInstanceType(rProp.PropertyType);
        if not instType.MetaclassType.InheritsFrom(TEntity) then Exit(True);

        try
          relModel := aEntityDatabase.Models.Get(TEntityClass(instType.MetaclassType));
        except
          Exit(True);
        end;

        {$IFDEF VALUE_FORMATPARAMS}
        whereClause := Format('%s = %s', [relModel.PrimaryKey.Name, fkValue.ToString]);
        {$ELSE}
        whereClause := Format('%s = %s', [relModel.PrimaryKey.Name, VarToStr(fkVariant)]);
        {$ENDIF}

        query := aEntityDatabase.CreateQuery(relModel);
        if Supports(query, IEntityLinqQuery<TEntity>, linq) then
        begin
          related := linq.Where(whereClause).SelectFirst;
          if (related <> nil) and rProp.IsWritable then
            rProp.SetValue(TObject(aEntity), related);
        end;
        Exit(True);
      end;

      { ---- HasMany: FK is on the related entity side ---- }
      if attr is HasMany then
      begin
        try
          parentModel := aEntityDatabase.Models.Get(aEntity);
        except
          Exit(True);
        end;

        {$IFDEF VALUE_FORMATPARAMS}
        pkValue := aEntity.FieldByName(parentModel.PrimaryKey.Name);
        if pkValue.IsEmpty then Exit(True);
        {$ELSE}
        pkVariant := aEntity.FieldByName(parentModel.PrimaryKey.Name);
        if VarIsEmpty(pkVariant) or VarIsNull(pkVariant) then Exit(True);
        {$ENDIF}

        try
          relModel := aEntityDatabase.Models.Get(HasMany(attr).RelatedClass);
        except
          Exit(True);
        end;

        {$IFDEF VALUE_FORMATPARAMS}
        whereClause := Format('%s = %s', [HasMany(attr).ForeignKeyField, pkValue.ToString]);
        {$ELSE}
        whereClause := Format('%s = %s', [HasMany(attr).ForeignKeyField, VarToStr(pkVariant)]);
        {$ENDIF}

        query := aEntityDatabase.CreateQuery(relModel);
        if Supports(query, IEntityLinqQuery<TEntity>, linq) then
        begin
          var entityResult := linq.Where(whereClause).Select;
          // Populate the entity's list property (must be TObjectList<TEntity>)
          var listValue := rProp.GetValue(TObject(aEntity));
          if (not listValue.IsEmpty) and listValue.IsObject then
          begin
            var listObj := listValue.AsObject;
            if listObj is TObjectList<TEntity> then
              entityResult.ToObjectList(TObjectList<TEntity>(listObj));
          end;
        end;
        Exit(True);
      end;

      { ---- HasOne: FK is on the related entity side (one-to-one) ---- }
      if attr is HasOne then
      begin
        try
          parentModel := aEntityDatabase.Models.Get(aEntity);
        except
          Exit(True);
        end;

        {$IFDEF VALUE_FORMATPARAMS}
        pkValue := aEntity.FieldByName(parentModel.PrimaryKey.Name);
        if pkValue.IsEmpty then Exit(True);
        {$ELSE}
        pkVariant := aEntity.FieldByName(parentModel.PrimaryKey.Name);
        if VarIsEmpty(pkVariant) or VarIsNull(pkVariant) then Exit(True);
        {$ENDIF}

        try
          relModel := aEntityDatabase.Models.Get(HasOne(attr).RelatedClass);
        except
          Exit(True);
        end;

        {$IFDEF VALUE_FORMATPARAMS}
        whereClause := Format('%s = %s', [HasOne(attr).ForeignKeyField, pkValue.ToString]);
        {$ELSE}
        whereClause := Format('%s = %s', [HasOne(attr).ForeignKeyField, VarToStr(pkVariant)]);
        {$ENDIF}

        query := aEntityDatabase.CreateQuery(relModel);
        if Supports(query, IEntityLinqQuery<TEntity>, linq) then
        begin
          related := linq.Where(whereClause).SelectFirst;
          if (related <> nil) and rProp.IsWritable then
            rProp.SetValue(TObject(aEntity), related);
        end;
        Exit(True);
      end;
    end;
  finally
    ctx.Free;
  end;
end;

end.
