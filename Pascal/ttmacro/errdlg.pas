{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTMACRO.EXE, error dialog box}
unit ErrDlg;

interface
{$i teraterm.inc}

{$IFDEF Delphi}
uses
  WinTypes, WinProcs, OWindows, ODialogs;
{$ELSE}
uses
  WinTypes, WinProcs, WObjects, Win31;
{$ENDIF}

type
  PErrDlg = ^TErrDlg;
  TErrDlg = object(TDialog)
    MsgStr, LineStr: PChar;
    PosX, PosY: integer;
    constructor Init(Msg, Line: PChar; x, y: integer);
    procedure SetupWindow; virtual;
  end;

implementation

const
 IDD_ERRDLG  = 200;
 IDC_ERRMSG  = 201;
 IDC_ERRLINE = 202;

constructor TErrDlg.Init(Msg, Line: PChar; x, y: integer);
begin
  TDialog.Init(Application^.MainWindow,PChar(IDD_ERRDLG));
  MsgStr := Msg;
  LineStr := Line;
  PosX := x;
  PosY := y;
end;

procedure TErrDlg.SetupWindow;
var
  R: TRect;
  TmpDC: HDC;
begin
  TDialog.SetupWindow;
  SetDlgItemText(HWindow, IDC_ERRMSG, MsgStr);
  SetDlgItemText(HWindow, IDC_ERRLINE, LineStr);

  if PosX<=-100 then
  begin
    GetWindowRect(HWindow,R);
    TmpDC := GetDC(HWindow);
    PosX := (GetDeviceCaps(TmpDC,HORZRES)-R.right+R.left) div 2;
    PosY := (GetDeviceCaps(TmpDC,VERTRES)-R.bottom+R.top) div 2;
    ReleaseDC(HWindow,TmpDC);
  end;
  SetWindowPos(HWindow,HWND_TOP,PosX,PosY,0,0,SWP_NOSIZE);
{$ifdef TERATERM32}
  SetForegroundWindow(HWindow);
{$else}
  SetActiveWindow(HWindow);
{$endif}
end;

end.
