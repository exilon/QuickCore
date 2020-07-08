program TaskControlServer;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Quick.Commons,
  Quick.Console,
  Quick.AppService,
  Quick.Core.Mvc,
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.Context,
  Quick.Core.DependencyInjection,
  Quick.Core.TaskControl in '..\..\..\Quick.Core.TaskControl.pas',
  Quick.Core.Extensions.MVC.TaskControl,
  TaskControlServer.Controller.Home in 'TaskControlServer.Controller.Home.pas',
  TaskControlServer.Config.App in 'TaskControlServer.Config.App.pas',
  Startup in 'Startup.pas';

var
  Server : TMVCServer;

begin
  try
    //run as console
    if not AppService.IsRunningAsService then
    begin
      //create server
      cout('Init server...',etInfo);
      Server := TMVCServer.Create('127.0.0.1',8080,False);
      try
        Server.UseStartup<TStartup>;
        Server.Start;
        //Wait for Exit
        cout(' ',ccWhite);
        cout('Press [Enter] to quit',ccYellow);
        ConsoleWaitForEnterKey;
      finally
        Server.Free;
      end;
    end
    else //run as a service
    begin
      AppService.DisplayName := 'Remote Server';
      AppService.ServiceName := 'RemoteServerSvc';
      AppService.CanInstallWithOtherName := True;
      AppService.OnStart := procedure
                               begin
                                 Server := TMVCServer.Create('127.0.0.1',8080,False);
                                 Server.UseStartup<TStartup>;
                               end;
      AppService.OnStop := Server.Free;
      AppService.OnExecute := Server.Start;
      AppService.CheckParams;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
