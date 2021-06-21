{ Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved. }

{ TTMACRO.EXE, main window}
unit ttmmain;

interface
{$I teraterm.inc}

{$IFDEF Delphi}
uses
  {$ifndef TERATERM32}
  TTCtl3d,
  {$endif}
  Messages, WinTypes, WinProcs, OWindows, ODialogs, Strings,
  Types, TTMMsg, TTMParse, TTMDDE, TTL, TTMDlg;
{$ELSE}
uses
  {$ifndef TERATERM32}
  TTCtl3d,
  {$endif}
  WinTypes, WinProcs, WObjects, Win31, Strings,
  Types, TTMMsg, TTMParse, TTMDDE, TTL, TTMDlg;
{$ENDIF}

type
  PCtrlWindow = ^TCtrlWindow;
  TCtrlWindow = object(TDlgWindow)
    Pause: bool;
    function OnIdle: bool;
    destructor  Done; virtual;
    procedure SetupWindow; virtual;
    function GetClassName: PChar; virtual;
    procedure GetWindowClass(var AWndClass: TWndClass); virtual;
    procedure WMCommand(var Msg: TMessage);
      virtual WM_COMMAND;
    procedure WMSysCommand(var Msg: TMessage);
      virtual WM_SYSCOMMAND;
{$ifndef TERATERM32}
    procedure WMSysColorChange(var Msg: TMessage);
      virtual WM_SYSCOLORCHANGE;
{$endif}
    procedure WMTimer(var Msg: TMessage);
      virtual WM_TIMER;
    procedure WMDdeCmndEnd(var Msg: TMessage);
      virtual WM_USER_DDECMNDEND;
    procedure WMDdeComReady(var Msg: TMessage);
      virtual WM_USER_DDECOMREADY;
    procedure WMDdeReady(var Msg: TMessage);
      virtual WM_USER_DDEREADY;
    procedure WMDdeEnd(var Msg: TMessage);
      virtual WM_USER_DDEEND;
  end;

implementation

const                
  IDC_CTRLPAUSESTART = 101;
  IDC_CTRLEND        = 102;
  IDI_TTMACRO        = 100;

const
{$ifdef TERATERM32}
  ClassName = 'TTPMACRO';
{$else}
  ClassName = 'TTMACRO';
{$endif}

var
  Busy: bool;

{TTMACRO main engine}
function TCtrlWindow.OnIdle: bool;
var
  ResultCode: integer;
  Temp: array[0..1] of char;
begin
  OnIdle := FALSE;
  if Busy then exit;
  Busy := TRUE;

  if TTLStatus=IdTTLEnd then
  begin
    CloseWindow;
    exit;
  end;

  SendSync; {for sync mode}

  if OutLen>0 then
  begin
    DDESend;
    OnIdle := TRUE;
  end
  else if not Pause and
    (TTLStatus=IdTTLRun) then
  begin
    Exec;
    OnIdle := TRUE;
  end
  else if TTLStatus=IdTTLWait then
  begin
    ResultCode := Wait;
    if ResultCode>0 then
    begin
      KillTimer(HWindow,IdTimeOutTimer);
      TTLStatus := IdTTLRun;
      LockVar;
      SetResult(ResultCode);
      UnlockVar;
      OnIdle := TRUE;
    end
    else if ComReady=0 then
      SetTimer(HWindow,IdTimeOutTimer,0,nil);
  end
  else if TTLStatus=IdTTLWaitLn then
  begin
    ResultCode := Wait;
    if ResultCode>0 then
    begin
      LockVar;
      SetResult(ResultCode);
      UnlockVar;
      Temp[0] := #$0a;
      Temp[1] := #0;
      if CmpWait(ResultCode,Temp)=0 then
      begin {new-line is received}
        KillTimer(HWindow,IdTimeOutTimer);
	ClearWait;
	TTLStatus := IdTTLRun;
	LockVar;
	SetInputStr(GetRecvLnBuff);
	UnlockVar;
      end
      else begin {wait new-line}
        ClearWait;
	SetWait(1,Temp);
	TTLStatus := IdTTLWaitNL;
      end;
      OnIdle := TRUE;
    end
    else if ComReady=0 then
      SetTimer(HWIndow,IdTimeOutTimer,0,nil);
  end
  else if TTLStatus=IdTTLWaitNL then
  begin
    ResultCode := Wait;
    if ResultCode>0 then
    begin
      KillTimer(HWindow,IdTimeOutTimer);
      TTLStatus := IdTTLRun;
      LockVar;
      SetInputStr(GetRecvLnBuff);
      UnlockVar;
      OnIdle := TRUE;
    end
    else if ComReady=0 then
      SetTimer(HWindow,IdTimeOutTimer,0,nil);
  end
  else if TTLStatus=IdTTLWait2 then
  begin
    if Wait2 then
    begin
      KillTimer(HWindow,IdTimeOutTimer);
      TTLStatus := IdTTLRun;
      LockVar;
      SetInputStr(Wait2Str);
      SetResult(1);
      UnlockVar;
      OnIdle := TRUE;
    end
    else if ComReady=0 then
      SetTimer(HWindow,IdTimeOutTimer,0,nil);
  end;

  Busy := FALSE;
end;

destructor TCtrlWindow.Done;
begin
  EndTTL;
  EndDDE;
  TDlgWindow.Done;
end;

procedure TCtrlWindow.SetupWindow;
var
  TmpDC: HDC;
  CRTWidth,CRTHeight: integer;
  Rect: TRect;
  Temp: array[0..MAXPATHLEN-1] of char;
  IOption, VOption: bool;
  Cmd: integer;
begin
{$ifndef TERATERM32}
  SubclassDlg(HWindow); {CTL3D}
{$endif}

  Pause := FALSE;

  TmpDC := GetDC(HWindow);
  CRTWidth := GetDeviceCaps(TmpDC,HORZRES);
  CRTHeight := GetDeviceCaps(TmpDC,VERTRES);
  GetWindowRect(HWindow,Rect);
  ReleaseDC(HWindow, TmpDC);
  SetWindowPos(HWindow,HWND_TOP,
    (CRTWidth-Rect.right+Rect.left) div 2,
    (CRTHeight-Rect.bottom+Rect.top) div 2,
    0,0,SWP_NOSIZE or SWP_NOZORDER);

  ParseParam(IOption,VOption);

  if TopicName[0]<>#0 then InitDDE(HWindow);

  if (FileName[0]=#0) and
     not GetFileName(HWindow) then
  begin
    EndDDE;
    PostQuitMessage(0);
    exit;
  end;

  if not InitTTL(HWindow) then
  begin
    EndDDE;
    PostQuitMessage(0);
    exit;
  end;

  StrCopy(Temp,'MACRO - ');
  StrCat(Temp,ShortName);
  SetWindowText(HWindow,Temp);

  {send the initialization signal to TT}
  SendCmnd(CmdInit,0);

  if VOption then
    Cmd := SW_HIDE
  else if IOption then
    Cmd := SW_SHOWMINIMIZED
  else
{$ifdef TERATERM32}
    Cmd := SW_SHOWDEFAULT;
{$else}
    Cmd := CmdShow;
{$endif}

{$ifdef TERATERM32}
  ShowWindow(HWindow,Cmd);
{$else}
  CmdShow := Cmd;
{$endif}
 TDlgWindow.SetupWindow;
  SetTimer(HWindow,100,1,nil); {activate message loop}

{$ifdef TERATERM32}
  {set the small icon}
  PostMessage(HWindow,WM_SETICON,0,
    LoadImage(hInstance,PChar(IDI_TTMACRO),
    IMAGE_ICON,16,16,0));
{$endif}
end;

function TCtrlWindow.GetClassName: PChar;
begin
  GetClassName := ClassName;
end;

procedure TCtrlWindow.GetWindowClass(var AWndClass: TWndClass);
begin
  TDlgWindow.GetWindowClass(AWndClass);
  AWndClass.HIcon := LoadIcon(HInstance, PChar(IDI_TTMACRO));
end;

procedure TCtrlWindow.WMCommand(var Msg: TMessage);
begin
  case LOWORD(Msg.wParam) of
    IDC_CTRLPAUSESTART:
      begin
        if Pause then
          SetDlgItemText(HWindow, IDC_CTRLPAUSESTART, 'Pau&se')
        else
          SetDlgItemText(HWindow, IDC_CTRLPAUSESTART, '&Start');
        Pause := not Pause;
      end;
    IDC_CTRLEND: TTLStatus := IdTTLEnd;
  else
    TDlgWindow.WMCommand(Msg);
  end;
end;

procedure TCtrlWindow.WMSysCommand(var Msg: TMessage);
begin
  if Msg.wParam=SC_CLOSE then
    TTLStatus := IdTTLEnd
  else
    TCtrlWindow.DefWndProc(Msg);
end;

{$ifndef TERATERM32}
procedure TCtrlWindow.WMSysColorChange(var Msg: TMessage);
begin
  SysColorChange;
end;
{$endif}

procedure TCtrlWindow.WMTimer(var Msg: TMessage);
var
  TimeOut: bool;
begin
  KillTimer(HWindow, Msg.wParam);
  if Msg.wParam<>IdTimeOutTimer then exit;
  if TTLStatus=IdTTLRun then exit;

  TimeOut := CheckTimeOut;
  LockVar;

  if (TTLStatus=IdTTLWait) or
     (TTLStatus=IdTTLWaitLn) or
     (TTLStatus=IdTTLWaitNL) then
  begin
    if not Linked or (ComReady=0) or TimeOut then
    begin
      SetResult(0);
      if TTLStatus=IdTTLWaitNL then
        SetInputStr(GetRecvLnBuff);
      TTLStatus := IdTTLRun;
    end;
  end
  else if TTLStatus=IdTTLWait2 then
  begin
    if not Linked or (ComReady=0) or TimeOut then
    begin
      if Wait2Found then
      begin
        SetInputStr(Wait2Str);
        SetResult(-1);
      end
      else begin
        SetInputStr('');
        SetResult(0);
      end;
      TTLStatus := IdTTLRun;
    end;
  end
  else if TTLStatus=IdTTLPause then
  begin
    if TimeOut then
      TTLStatus := IdTTLRun;
  end
  else if TTLStatus=IdTTLSleep then
  begin
    if TimeOut and
       TestWakeup(IdWakeupTimeout) then
    begin
      SetResult(IdWakeupTimeout);
      TTLStatus := IdTTLRun;
    end;
  end
  else
    TTLStatus := IdTTLRun;

  UnlockVar;

  if TimeOut or (TTLStatus=IdTTLRun) then
    exit;

  SetTimer(HWindow,IdTimeOutTimer,1000, nil);
end;

procedure TCtrlWindow.WMDdeCmndEnd(var Msg: TMessage);
begin
  if (TTLStatus=IdTTLWaitCmndResult) then
  begin
    LockVar;
    SetResult(Msg.wParam);
    UnlockVar;
  end;

  if (TTLStatus=IdTTLWaitCmndEnd) or
     (TTLStatus=IdTTLWaitCmndResult) then
    TTLStatus := IdTTLRun;
end;

procedure TCtrlWindow.WMDdeComReady(var Msg: TMessage);
begin
  ComReady := Msg.wParam;
  if (TTLStatus = IdTTLWait) or
     (TTLStatus = IdTTLWaitLn) or
     (TTLStatus = IdTTLWaitNL) or
     (TTLStatus = IdTTLWait2) then
  begin
    if ComReady=0 then
      SetTimer(HWindow,IdTimeOutTimer,0,nil);
  end
  else if TTLStatus=IdTTLSleep then
  begin
    LockVar;
    if TestWakeup(IdWakeupInit) then
    begin
      if ComReady<>0 then
        SetResult(2)
      else
        SetResult(1);
      TTLStatus := IdTTLRun;
    end
    else if (ComReady<>0) and TestWakeup(IdWakeupConnect) then
    begin
      SetResult(IdWakeupConnect);
      TTLStatus := IdTTLRun;
    end
    else if (ComReady=0) and TestWakeup(IdWakeupDisconn) then
    begin
      SetResult(IdWakeupDisconn);
      TTLStatus := IdTTLRun;
    end;
    UnlockVar;
  end;
end;

procedure TCtrlWindow.WMDdeReady(var Msg: TMessage);
begin
  if TTLStatus <> IdTTLInitDDE then exit;
  SetWakeup(IdWakeupInit);
  TTLStatus := IdTTLSleep;

  if not InitDDE(HWindow) then
  begin
    LockVar;
    SetResult(0);
    UnlockVar;
    TTLStatus := IdTTLRun;
  end;
end;

procedure TCtrlWindow.WMDdeEnd(var Msg: TMessage);
begin
  EndDDE;
  if (TTLStatus = IdTTLWaitCmndEnd) or
     (TTLStatus = IdTTLWaitCmndResult) then
    TTLStatus := IdTTLRun
  else if (TTLStatus = IdTTLWait) or
          (TTLStatus = IdTTLWaitLn) or
	  (TTLStatus = IdTTLWaitNL) or
	  (TTLStatus = IdTTLWait2) then
    SetTimer(HWindow,IdTimeOutTimer,0,nil)
  else if TTLStatus=IdTTLSleep then
  begin
    LockVar;
    if TestWakeup(IdWakeupInit) then
    begin
      SetResult(0);
      TTLStatus := IdTTLRun;
    end
    else if TestWakeup(IdWakeupUnlink) then
    begin
      SetResult(IdWakeupUnlink);
      TTLStatus := IdTTLRun;
    end;
    UnlockVar;
  end;
end;

begin
  Busy := FALSE;
end.
