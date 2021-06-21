{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTMACRO.EXE, main}
program TTMACRO;
{$R ttmacro.res}
{$I teraterm.inc}

{$IFDEF Delphi}
uses
{$ifndef TERATERM32}
  TTCtl3d,
{$endif}
  Messages, WinTypes, WinProcs, OWindows,
  TTMMain;
{$ELSE}
uses
{$ifndef TERATERM32}
  TTCtl3d,
{$endif}
  WinTypes, WinProcs, WObjects,
  TTMMain;
{$ENDIF}

type
  TCtrlApp = object(TApplication)
{$ifndef TERATERM32}
    destructor Done; virtual;
{$endif}
    procedure InitMainWindow; virtual;
    procedure MessageLoop; virtual;
  end;

var
  App: TCtrlApp;

const
  IDD_CTRLWIN = 100;

{$ifndef TERATERM32}
destructor TCtrlApp.Done;
begin
  FreeCtl3d;
  TApplication.Done;
end;
{$endif}

procedure TCtrlApp.InitMainWindow;
begin
{$ifndef TERATERM32}
  LoadCtl3d;
{$endif}
  MainWindow := New(PCtrlWindow, Init(nil,PChar(IDD_CTRLWIN)));
end;

procedure TCtrlApp.MessageLoop;
var
  Msg: TMsg;
  More: bool;
begin
  while TRUE do
  begin
    if GetMessage(Msg,0,0,0) then
    begin
      if not ProcessAppMsg(Msg) then
      begin
        TranslateMessage(Msg);
        DispatchMessage(Msg);
      end;
    end
    else begin
      Status := Msg.WParam;
      exit;
    end;

    repeat
      if MainWindow<>nil then
        More := PCtrlWindow(MainWindow)^.OnIdle
      else
        More := FALSE;

      if PeekMessage(Msg, 0, 0, 0, PM_REMOVE) then
      begin
        if Msg.Message = WM_QUIT then
        begin
          Status := Msg.wParam;
          exit;
        end;
        if not ProcessAppMsg(Msg) then
        begin
          TranslateMessage(Msg);
          DispatchMessage(Msg);
        end;
        More := TRUE;
      end;
    until not More;
  end;
end;

begin
  App.Init('');
  App.Run;
  App.Done;
  Halt(ExitCode);
end.
