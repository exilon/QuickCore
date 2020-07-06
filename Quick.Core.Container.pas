{ ***************************************************************************

  Copyright (c) 2016-2019 Kike Pérez

  Unit        : Quick.Core.Dependencies
  Description : Core Mvc Dependency Injection
  Author      : Kike Pérez
  Version     : 1.0
  Created     : 30/08/2019
  Modified    : 08/11/2019

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

unit Quick.Core.DependencyInjection_borrar;

interface

{$i QuickCore.inc}

uses
  RTTI,
  System.TypInfo,
  Quick.IOC,
  Quick.Options;

type
  TDependencyInjector = class
  private
    fContainer : TIocContainer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddSingleton<TInterface: IInterface; TImplementation: class>(const aName : string = ''); overload; inline;
    function AddSingleton<TImplementation : class>(const aName: string = ''): TIocRegistration<TImplementation>; overload; inline;
    procedure AddTransient<TInterface: IInterface; TImplementation: class>(const aName : string = ''); overload; inline;
    function AddTransient<TImplementation : class>(const aName: string = ''): TIocRegistration<TImplementation>; overload; inline;
    procedure AddScoped<TInterface: IInterface; TImplementation: class>(const aName : string = ''); overload; inline;
    procedure AddScoped<TImplementation: class>(const aName : string = ''); overload; inline;
    function Resolve(aTypeInfo: PTypeInfo; const aName: string): TValue; overload; inline;
    function Resolve<TInterface>(const aName : string = ''): TInterface; overload; inline;
    function RegisterOptions<T : TOptions>(aOptions : TOptions) : TIocRegistration<T>; inline;
    function AbstractFactory<T : class, constructor>(aClass : TClass) : T; inline;
  end;

implementation

{ TDependencyInjector }

constructor TDependencyInjector.Create;
begin
  fContainer := TIocContainer.Create;
end;

destructor TDependencyInjector.Destroy;
begin
  fContainer.Free;
  inherited;
end;

procedure TDependencyInjector.AddSingleton<TInterface, TImplementation>(const aName : string = '');
begin
  fContainer.RegisterType<TInterface,TImplementation>(aName).AsSingleton;
end;

function TDependencyInjector.AddSingleton<TImplementation>(const aName: string): TIocRegistration<TImplementation>;
begin
  Result := fContainer.RegisterInstance<TImplementation>(aName).AsSingleton;
end;

procedure TDependencyInjector.AddTransient<TInterface, TImplementation>(const aName: string);
begin
  fContainer.RegisterType<TInterface,TImplementation>(aName).AsTransient;
end;

function TDependencyInjector.AddTransient<TImplementation>(const aName: string): TIocRegistration<TImplementation>;
begin
  Result := fContainer.RegisterInstance<TImplementation>(aName).AsTransient;
end;

procedure TDependencyInjector.AddScoped<TInterface, TImplementation>(const aName: string);
begin
  fContainer.RegisterType<TInterface,TImplementation>(aName).AsScoped;
end;

procedure TDependencyInjector.AddScoped<TImplementation>(const aName: string);
begin
  fContainer.RegisterInstance<TImplementation>(aName).AsScoped;
end;

function TDependencyInjector.RegisterOptions<T>(aOptions: TOptions): TIocRegistration<T>;
begin
  Result := fContainer.RegisterOptions<T>(aOptions);
end;

function TDependencyInjector.Resolve(aTypeInfo: PTypeInfo; const aName: string): TValue;
begin
  Result := fContainer.Resolve(aTypeInfo,aName);
end;

function TDependencyInjector.Resolve<TInterface>(const aName : string = ''): TInterface;
begin
  Result := fContainer.Resolve<TInterface>(aName);
end;

function TDependencyInjector.AbstractFactory<T>(aClass: TClass): T;
begin
  Result := fContainer.AbstractFactory<T>(aClass);
end;

end.
