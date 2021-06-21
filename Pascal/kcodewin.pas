{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{KEYCODE.EXE, main window}
unit KCodeWin;

interface
{$I teraterm.inc}

{$IFDEF Delphi}
uses Messages, WinTypes, WinProcs, OWindows, Strings;
{$ELSE}
uses WinTypes, WinProcs, WObjects, Strings;
{$ENDIF}

type
  PKCodeWindow = ^KCodeWindow;

  KCodeWindow = object(TWindow)
    KeyDown, Short: boolean;
    Scan: integer;
    constructor Init(Aparent: PWindowsObject; ATitle: PChar);
    procedure SetupWindow; virtual;
    function GetClassName: PChar; virtual;
    procedure GetWindowClass(var AWndClass: TWndClass); virtual;

    procedure WMSysKeyDown(var Msg: TMessage);
      virtual wm_First + wm_SysKeyDown;
    procedure WMSysKeyUp(var Msg: TMessage);
      virtual wm_First + wm_SysKeyUp;
    procedure WMKeyDown(var Msg: TMessage);
      virtual wm_First + wm_KeyDown;
    procedure WMKeyUp(var Msg: TMessage);
      virtual wm_First + wm_KeyUp;
    procedure WMTimer(var Msg: TMessage);
      virtual wm_First + wm_Timer;
    procedure Paint(PaintDC: HDC; var PaintInfo:TPaintStruct); virtual;
  end;

implementation

constructor KCodeWindow.Init(Aparent: PWindowsObject; Atitle: PChar);
begin
  TWindow.Init(Aparent, Atitle);
  KeyDown := false;
  Attr.W := 200;
  Attr.H := 100;
end;

procedure KCodeWindow.SetupWindow;
begin
  TWindow.SetupWindow;
end;

function KCodeWindow.GetClassName: PChar;
begin
  GetClassName := 'KCodeWin';
end;

procedure KCodeWindow.GetWindowClass(var AWndClass: TWndClass);
begin
  TWindow.GetWindowClass(AWndClass);
  AWndClass.HIcon := LoadIcon(HInstance, PChar(100));
end;

procedure KCodeWindow.WMSysKeyDown(var Msg: TMessage);
begin
  case Msg.wParam of
    VK_F10: WMKeyDown(Msg);
  else
    DefWndProc(Msg);
  end;
end;

procedure KCodeWindow.WMSysKeyUp(var Msg: TMessage);
begin
  case Msg.wParam of
    VK_F10: WMKeyUp(Msg);
  else
    DefWndProc(Msg);
  end;
end;

procedure KCodeWindow.WMKeyDown(var Msg: TMessage);
begin
  if (Msg.wParam=VK_Shift) or
     (Msg.wParam=VK_Control) or
     (Msg.wParam=VK_Menu) then exit;

  Scan := HiWord(Msg.lParam) and $1ff;
  if GetKeyState(VK_Shift) and $80 <> 0 then
    Scan := Scan or $200;
  if GetKeyState(VK_Control) and $80 <> 0 then
    Scan := Scan or $400;
  if GetKeyState(VK_Menu) and $80 <> 0 then
    Scan := Scan or $800;

  if not KeyDown then
  begin
    KeyDown := TRUE;
    Short := TRUE;
    SetTimer(HWindow,1,10,nil);
    InvalidateRect(HWindow,nil,TRUE);
  end;
end;

procedure KCodeWindow.WMKeyUp(var Msg: TMessage);
begin
  if not KeyDown then exit; 
  if Short then
    SetTimer(HWindow,2,500,nil)
  else begin
    KeyDown := FALSE;
    InvalidateRect(HWindow,nil,TRUE);
  end;
end;

procedure KCodeWindow.WMTimer(var Msg: TMessage);
begin
  KillTimer(HWindow,Msg.wParam);
  if Msg.wParam=1 then
    Short := FALSE
  else if Msg.wParam=2 then
  begin
    KeyDown := FALSE;
    InvalidateRect(HWindow,nil,TRUE);
  end;
end;

procedure KCodeWindow.Paint(PaintDC: HDC; var PaintInfo:TPaintStruct);
var
  OutStr: array[0..20] of char;
  NumStr: string[10];
begin
  TWindow.Paint(PaintDC,PaintInfo);
  if KeyDown then
  begin
    StrCopy(OutStr,'Key code is ');
    Str(Scan,NumStr);
    StrPCopy(@OutStr[12],NumStr);
    StrCat(OutStr,'.');
    TextOut(PaintDC,10,10,OutStr,StrLen(OutStr));
  end
  else
    TextOut(PaintDC,10,10,'Push any key.',13);
end;

end.