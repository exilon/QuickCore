{ ***************************************************************************

  Copyright (c) 2016-2021 Kike Pérez

  Unit        : Quick.Core.AutoMapper
  Description : Core AutoMapper
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 07/02/2020
  Modified    : 07/04/2021

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

unit Quick.Core.AutoMapper;

{$i QuickCore.inc}

interface

uses
  System.SysUtils,
  typinfo,
  System.Rtti,
  Quick.RTTI.Utils,
  System.Generics.Collections,
  Quick.Value,
  Quick.Core.Mapping.Abstractions;

type

  TMapProc<TSource,TDestination> = reference to procedure(src : TSource; dest : TDestination);

  TCustomMapping = class
  private
    fMapDictionary : TDictionary<string,string>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddMap(const aName, aMapName : string);
    function GetMap(const aName : string; out vMapName : string) : Boolean;
    function Count : Integer;
  end;

  TProfileMap = class
  private
    fMap : TMapProc<TObject,TObject>;
    fCustomMapping : TCustomMapping;
    fIgnoreOtherMembers : Boolean;
    fIgnoreAllNonExisting : Boolean;
  public
    constructor Create(aMap : TMapProc<TObject,TObject>);
    destructor Destroy; override;
    property Map : TMapProc<TObject,TObject> read fMap;
    function IgnoreOtherMembers : TProfileMap;
    function IgnoreAllNonExisting : TProfileMap;
    function ForMember(const aSrcProperty, aTgtProperty : string) : TProfileMap;
  end;

  TProfileMapList = TObjectDictionary<string,TProfileMap>;

  TProfile = class
  class var
    fMappings : TProfileMapList;
    fResolveUnmapped : Boolean;
    fDefaultProfileMap : TProfileMap;
    class function GetKey(aSrcObj, aTgtObj : TObject) : string; overload;
    class function GetKey(aSrcObj, aTgtObj: TClass): string; overload;
  public
    class constructor Create;
    class destructor Destroy;
    function ResolveUnmapped : TProfileMap;
    function CreateMap<TSource,TDestination : class, constructor>(aMapProc : TMapProc<TSource,TDestination> = nil) : TProfileMap;
  end;

  TAutoMapper = class(TInterfacedObject,IMapper)
  private
    fDefaultProfileMap : TProfileMap;
    fResolveUnmapped : Boolean;
    fMappingList : TObjectDictionary<string,TProfileMap>;
    procedure ObjMapper(aSrcObj : TObject; aTgtObj : TObject; aProfileMap : TProfileMap; IsRootClass : Boolean); overload;
    procedure ListMapper(aSrcList, aTgtList : TObject; aProfileMap : TProfileMap);
    procedure ObjListMapper(aSrcObjList, aTgtObjList: TObject; aProfileMap: TProfileMap);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Map(aSrcObj, aTgtObj : TObject); overload;
    function Map<T : class, constructor>(aSrcObj : TObject) : T; overload;
    function Map(aSrcObj : TObject) : TMapTarget; overload;
    class procedure RegisterProfile<T : TProfile, constructor>;
  end;

  EAutoMapperError = class(Exception);

implementation

{ TAutoMapper }

constructor TAutoMapper.Create;
begin
  fMappingList := TProfile.fMappings;
  fResolveUnmapped := TProfile.fResolveUnmapped;
  fDefaultProfileMap := TProfile.fDefaultProfileMap;
end;

destructor TAutoMapper.Destroy;
begin
  fDefaultProfileMap.Free;
  inherited;
end;

procedure TAutoMapper.ListMapper(aSrcList, aTgtList: TObject; aProfileMap: TProfileMap);
var
  rtype: TRttiType;
  rtype2 : TRttiType;
  typinfo : PTypeInfo;
  methToArray: TRttiMethod;
  value: TValue;
  valuecop : TValue;
  obj : TObject;
  i : Integer;
  rprop : TRttiProperty;
  ctx : TRttiContext;
begin
  rtype := ctx.GetType(aSrcList.ClassInfo);
  methToArray := rtype.GetMethod('ToArray');
  if Assigned(methToArray) then
  begin
    value := methToArray.Invoke(aSrcList,[]);
    Assert(value.IsArray);

    rtype2 := ctx.GetType(aTgtList.ClassInfo);
    rProp := rtype2.GetProperty('List');
    typinfo := GetTypeData(rProp.PropertyType.Handle).DynArrElType^;

    case typinfo.Kind of
      tkChar, tkString, tkWChar, tkWString : TList<string>(aTgtList).Capacity := value.GetArrayLength;
      tkInteger, tkInt64 : TList<Integer>(aTgtList).Capacity := value.GetArrayLength;
      tkFloat : TList<Extended>(aTgtList).Capacity := value.GetArrayLength;
      tkRecord :
        begin
          ObjMapper(aSrcList,aTgtList,aProfileMap,False);
          exit;
        end;
      else TList<TObject>(aTgtList).Capacity := value.GetArrayLength;
    end;

    for i := 0 to value.GetArrayLength - 1 do
    begin
      if typinfo.Kind = tkClass then
      begin
        obj := typinfo.TypeData.ClassType.Create;
        ObjMapper(value.GetArrayElement(i).AsObject,obj,aProfileMap,False);
        TList<TObject>(aTgtList).Add(obj);
      end
      else
      begin
        valuecop := value.GetArrayElement(i);
        case typinfo.Kind of
          tkChar, tkString, tkWChar, tkWString : TList<string>(aTgtList).Add(valuecop.AsString);
          tkInteger, tkInt64 : TList<Integer>(aTgtList).Add(valuecop.AsInt64);
          tkFloat : TList<Extended>(aTgtList).Add(valuecop.AsExtended);
        end;
      end;
    end;
  end;
end;

class procedure TAutoMapper.RegisterProfile<T>;
var
  profile : T;
begin
  profile := T.Create;
  try
    //only need to call constructor add profilesmap to global TProfile class
  finally
    profile.Free;
  end;
end;

procedure TAutoMapper.Map(aSrcObj, aTgtObj: TObject);
var
  profile : TProfileMap;
begin
  if TProfile.fMappings.TryGetValue(TProfile.GetKey(aSrcObj,aTgtObj),profile) then
  begin
    ObjMapper(aSrcObj,aTgtObj,profile,True);
  end
  else
  begin
    if fResolveUnmapped then ObjMapper(aSrcObj,aTgtObj,fDefaultProfileMap,True)
      else raise EAutoMapperError.CreateFmt('AutoMapper: Not defined profile for %s > %s',[aSrcObj.ClassName,aTgtObj.ClassName]);
  end;
end;

function TAutoMapper.Map(aSrcObj : TObject): TMapTarget;
begin
  if aSrcObj = nil then raise EAutoMapperError.Create('AutoMapper: Source object cannot be null!');
  Result.Create(aSrcObj,Self.Map);
end;

function TAutoMapper.Map<T>(aSrcObj: TObject): T;
begin
  Result := T.Create;
  ObjMapper(aSrcObj,Result,nil,True);
end;

procedure TAutoMapper.ObjMapper(aSrcObj : TObject; aTgtObj : TObject; aProfileMap : TProfileMap; IsRootClass : Boolean);
var
  ctx : TRttiContext;
  rType : TRttiType;
  tgtprop : TRttiProperty;
  mapname : string;
  obj : TObject;
  clname : string;
  objvalue : TValue;
begin
  //if aTgtObj = nil then aTgtObj := GetTypeData(aTgtObj.ClassInfo).classType.Create;
  if aTgtObj = nil then raise EAutoMapperError.Create('TObjMapper: Target Object passed must be created before');
  if not Assigned(aProfileMap) then EAutoMapperError.CreateFmt('AutoMapper: Not defined Profile for %s > %s mapping',[aSrcObj.ClassName,aTgtObj]);

  //if exists a map delegate
  if (IsRootClass) and (Assigned(aProfileMap.Map)) then aProfileMap.Map(aSrcObj,aTgtObj);
  //check if need to mapping other members
  if (aProfileMap.fIgnoreOtherMembers) and (not Assigned(aProfileMap.fCustomMapping)) then Exit;
  objvalue := TValue.From(aSrcObj);
  rType := ctx.GetType(aSrcObj.ClassInfo);
  for tgtprop in ctx.GetType(aTgtObj.ClassInfo).GetProperties do
  begin
    if tgtprop.IsWritable then
    begin
      if not tgtprop.PropertyType.IsInstance then
      begin
        if (Assigned(aProfileMap)) and (Assigned(aProfileMap.fCustomMapping)) then
        begin
          if aProfileMap.fCustomMapping.GetMap(tgtprop.Name,mapname) then
          begin
            {$IFNDEF PROPERTYPATH_MODE}
              if rType.GetProperty(mapname) = nil then
              begin
                if not aProfileMap.fIgnoreAllNonExisting then raise EAutoMapperError.CreateFmt('No valid custom mapping (Source: %s - Target: %s)',[mapname,tgtprop.Name]);
              end;
              try
                tgtprop.SetValue(aTgtObj,rType.GetProperty(mapname).GetValue(aSrcObj));
              except
                on E : Exception do raise EAutoMapperError.CreateFmt('Error mapping property "%s" : %s',[tgtprop.Name,e.message]);
              end;
            {$ELSE}
              if not TRTTI.PathExists(aSrcObj,mapname) then
              begin
                if not aProfileMap.fIgnoreAllNonExisting then raise EAutoMapperError.CreateFmt('No valid custom mapping (Source: %s - Target: %s)',[mapname,tgtprop.Name]);
              end;
              TRTTI.SetPathValue(aTgtObj,tgtprop.Name,TRTTI.GetPathValue(aSrcObj,mapname));
            {$ENDIF}
          end
          else
          begin
            //if not ignore others, map equal names
            if (not aProfileMap.fIgnoreOtherMembers) and (rType.GetProperty(tgtprop.Name) <> nil) then
            begin
              try
                tgtprop.SetValue(aTgtObj,rType.GetProperty(tgtprop.Name).GetValue(aSrcObj));
              except
                on E : Exception do raise EAutoMapperError.CreateFmt('Error mapping property "%s" : %s',[tgtprop.Name,e.message]);
              end;
            end;
          end;
        end;
      end
      else
      begin
        obj := tgtprop.GetValue(aTgtObj).AsObject;
        if obj = nil then
        begin
          if TRTTI.PropertyExists(aSrcObj.ClassInfo,tgtprop.Name) then obj := GetObjectProp(aSrcObj,tgtprop.Name).ClassType.Create// TObject.Create;
          else
          begin
            if (Assigned(aProfileMap)) and (aProfileMap.fIgnoreAllNonExisting) then Continue;
          end;
        end;

        if obj <> nil then
        begin
          try
            if (rType.GetProperty(tgtprop.Name) <> nil)
              and (not rType.GetProperty(tgtprop.Name).GetValue(aSrcObj).IsEmpty) then clname := rType.GetProperty(tgtprop.Name).GetValue(aSrcObj).AsObject.ClassName
            else Continue;
          except
            on E : Exception do raise EAutoMapperError.CreateFmt('Error mapping property "%s" : %s',[tgtprop.Name,e.message]);
          end;
          if clname.StartsWith('TList') then ListMapper(rType.GetProperty(tgtprop.Name).GetValue(aSrcObj).AsObject,obj,aProfileMap)
          else if clname.StartsWith('TObjectList') then ObjListMapper(rType.GetProperty(tgtprop.Name).GetValue(aSrcObj).AsObject,obj,aProfileMap)
            else ObjMapper(rType.GetProperty(tgtprop.Name).GetValue(aSrcObj).AsObject,obj,aProfileMap,False)
        end
        else raise EAutoMapperError.CreateFmt('Target object "%s" not autocreated by class',[tgtprop.Name]);
      end;
    end;
  end;
end;

procedure TAutoMapper.ObjListMapper(aSrcObjList, aTgtObjList: TObject; aProfileMap: TProfileMap);
var
  rtype: TRttiType;
  rtype2 : TRttiType;
  typinfo : PTypeInfo;
  methToArray: TRttiMethod;
  value: TValue;
  obj : TObject;
  i : Integer;
  rprop : TRttiProperty;
  ctx : TRttiContext;
begin
  rtype := ctx.GetType(aSrcObjList.ClassInfo);
  methToArray := rtype.GetMethod('ToArray');
  if Assigned(methToArray) then
  begin
    value := methToArray.Invoke(aSrcObjList,[]);
    Assert(value.IsArray);

    rtype2 := ctx.GetType(aTgtObjList.ClassInfo);
    rProp := rtype2.GetProperty('List');
    typinfo := GetTypeData(rProp.PropertyType.Handle).DynArrElType^;

    for i := 0 to value.GetArrayLength - 1 do
    begin
      obj := typinfo.TypeData.ClassType.Create;
      ObjMapper(value.GetArrayElement(i).AsObject,obj,aProfileMap,False);
      TObjectList<TObject>(aTgtObjList).Add(obj);
    end;
  end;
end;

{ TProfile }

class constructor TProfile.Create;
begin
  fMappings := TObjectDictionary<string,TProfileMap>.Create([doOwnsValues]);
  fResolveUnmapped := False;
  fDefaultProfileMap := TProfileMap.Create(nil);
end;

class destructor TProfile.Destroy;
begin
  fMappings.Free;
  inherited;
end;

class function TProfile.GetKey(aSrcObj, aTgtObj: TObject): string;
begin
  Result := aSrcObj.ClassName + ':' + aTgtObj.ClassName;
end;

class function TProfile.GetKey(aSrcObj, aTgtObj: TClass): string;
begin
  Result := aSrcObj.ClassName + ':' + aTgtObj.ClassName;
end;

function TProfile.ResolveUnmapped: TProfileMap;
begin
  fResolveUnmapped := True;
  Result := fDefaultProfileMap;
end;

function TProfile.CreateMap<TSource,TDestination>(aMapProc : TMapProc<TSource,TDestination> = nil) : TProfileMap;
var
  profilemap : TProfileMap;
begin
  profilemap := TProfileMap.Create(TMapProc<TObject,TObject>(aMapProc));
  fMappings.Add(GetKey(TClass(TSource),TClass(TDestination)),profilemap);
  Result := profilemap;
end;

{ TProfileMap }

constructor TProfileMap.Create(aMap: TMapProc<TObject, TObject>);
begin
  fIgnoreAllNonExisting := False;
  fIgnoreOtherMembers := False;
  fMap := aMap;
  fCustomMapping := TCustomMapping.Create;
end;

destructor TProfileMap.Destroy;
begin
  fCustomMapping.Free;
  inherited;
end;

function TProfileMap.ForMember(const aSrcProperty, aTgtProperty : string): TProfileMap;
begin
  Result := Self;
  fCustomMapping.AddMap(aSrcProperty,aTgtProperty);
end;

function TProfileMap.IgnoreAllNonExisting: TProfileMap;
begin
  Result := Self;
  fIgnoreAllNonExisting := True;
end;

function TProfileMap.IgnoreOtherMembers: TProfileMap;
begin
  Result := Self;
  fIgnoreOtherMembers := True;
end;

{ TCustomMapping }

procedure TCustomMapping.AddMap(const aName, aMapName: string);
begin
  //add map fields
  fMapDictionary.Add(aName,aMapName);
  //add reverse lookup if not same name
  if aName <> aMapName then fMapDictionary.Add(aMapName,aName);
end;

function TCustomMapping.Count: Integer;
begin
  Result := fMapDictionary.Count;
end;

constructor TCustomMapping.Create;
begin
  fMapDictionary := TDictionary<string,string>.Create;
end;

destructor TCustomMapping.Destroy;
begin
  fMapDictionary.Free;
  inherited;
end;

function TCustomMapping.GetMap(const aName: string; out vMapName: string): Boolean;
begin
  Result := fMapDictionary.TryGetValue(aName,vMapName);
end;

end.
