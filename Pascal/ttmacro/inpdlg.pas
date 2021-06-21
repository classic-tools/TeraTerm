{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTMACRO.EXE, input dialog box}
unit InpDlg;

interface
{$i teraterm.inc}

{$IFDEF Delphi}
uses
  Messages, WinTypes, WinProcs, OWindows, ODialogs, Types;
{$ELSE}
uses
  WinTypes, WinProcs, WObjects, Win31, Types;
{$ENDIF}

type
  PInpDlg = ^TInpDlg;
  TInpDlg = object(TDialog)
    InputStr, TextStr, TitleStr: PChar;
    PaswdFlag: bool;
    PosX, PosY: integer;
    constructor Init
      (Input, Text, Title: PChar; Paswd: bool; x, y: integer);
    procedure SetupWindow; virtual;
    procedure WMCommand(var Msg: TMessage);
      virtual WM_COMMAND;
  end;

implementation

const
  IDD_INPDLG = 300;
  IDC_INPTEXT = 301;
  IDC_INPEDIT = 302;

  MaxStrLen = 256;

constructor TInpDlg.Init
  (Input, Text, Title: PChar; Paswd: bool; x, y: integer);
begin
  TDialog.Init(Application^.MainWindow,PChar(IDD_INPDLG));
  InputStr := Input;
  TextStr := Text;
  TitleStr := Title;
  PaswdFlag := Paswd;
  PosX := x;
  PosY := y;
end;

procedure TInpDlg.SetupWindow;
var
  R: TRect;
  TmpDC: HDC;
begin
  TDialog.SetupWindow;
  SetWindowText(HWindow, TitleStr);
  SetDlgItemText(HWindow, IDC_INPTEXT, TextStr);
  if PaswdFlag then
    SendDlgItemMessage(HWindow,IDC_INPEDIT,EM_SETPASSWORDCHAR,UINT('*'),0);

  SendDlgItemMessage(HWindow, IDC_INPEDIT, EM_LIMITTEXT, MaxStrLen, 0);

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

procedure TInpDlg.WMCommand(var Msg: TMessage);
begin
  case LOWORD(Msg.wParam) of
    IDOK:
      GetDlgItemText(HWindow, IDC_INPEDIT, InputStr, MaxStrLen);
    IDCANCEL: begin
        EndDlg(0);
        exit;
      end;
  end;
  TDialog.WMCommand(Msg);
end;

end.
