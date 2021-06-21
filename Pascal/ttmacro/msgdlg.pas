{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTMACRO.EXE, message dialog box}
unit MsgDlg;

interface
{$i teraterm.inc}

{$IFDEF Delphi}
uses
  WinTypes, WinProcs, OWindows, ODialogs, Strings,
  Types, TTMLib;
{$ELSE}
uses
  WinTypes, WinProcs, WObjects, Win31, Strings, Types, TTMLib;
{$ENDIF}

type
  PMsgDlg = ^TMsgDlg;
  TMsgDlg = object(TDialog)
    TextStr, TitleStr: PChar;
    YesNoFlag: bool;
    PosX, PosY: integer;
    constructor Init
      (Text, Title: PChar; YesNo: bool; x, y: integer);
    procedure SetupWindow; virtual;
  end;

implementation

const
  IDD_MSGDLG  = 400;
  IDC_MSGTEXT = 401;

constructor TMsgDlg.Init
  (Text, Title: PChar; YesNo: bool; x, y: integer);
begin
  TDialog.Init(Application^.MainWindow, PChar(IDD_MSGDLG));
  TextStr := Text;
  TitleStr := Title;
  YesNoFlag := YesNo;
  PosX := x;
  PosY := y;
end;

procedure TMsgDlg.SetupWindow;
var
  R: TRECT;
  TmpDC: HDC;
  s: TSIZE;
  HText, HOk, HNo: HWnd;
  WW, WH, CW, CH, TW, TH, BW, BH: integer;
begin
  TDialog.SetupWindow;
  SetWindowText(HWindow,TitleStr);
  SetDlgItemText(HWindow,IDC_MSGTEXT,TextStr);

  HText := GetDlgItem(HWindow, IDC_MSGTEXT);

  TmpDC := GetDC(HWindow);
  CalcTextExtent(TmpDC,TextStr,s);
  ReleaseDC(HWindow,TmpDC);
  TW := s.cx + s.cx div 10;
  TH := s.cy;

  HOk := GetDlgItem(HWindow, IDOK);
  HNo := GetDlgItem(HWindow, IDCANCEL);
  GetWindowRect(HOk,R);
  BW := R.right-R.left;
  BH := R.bottom-R.top;

  GetWindowRect(HWindow, R);
  WW := R.right-R.left;
  WH := R.bottom-R.top;
  GetClientRect(HWindow, R);
  CW := R.right-R.left;
  CH := R.bottom-R.top;
  if TW < CW then
    TW := CW;
  if YesNoFlag and (TW < 7 * BW div 2) then
    TW := 7*BW div 2;
  WW := WW + TW - CW;
  WH := WH + 2*TH+3*BH div 2 - CH;

  MoveWindow(HText,(TW-s.cx) div 2,TH div 2,TW,TH,TRUE);
  if YesNoFlag then
  begin
    SetWindowText(HOk,'&Yes');
    MoveWindow(HOk,(2*TW-5*BW) div 4,2*TH,BW,BH,TRUE);
    SetWindowText(HNo,'&No');
    MoveWindow(HNo,(2*TW+BW) div 4,2*TH,BW,BH,TRUE);
    ShowWindow(HNo,SW_SHOW);
  end
  else
    MoveWindow(HOk,(TW-BW) div 2,2*TH,BW,BH,TRUE);

  if PosX<=-100 then
  begin
    TmpDC := GetDC(HWindow);
    PosX := (GetDeviceCaps(TmpDC,HORZRES)-WW) div 2;
    PosY := (GetDeviceCaps(TmpDC,VERTRES)-WH) div 2;
    ReleaseDC(HWindow,TmpDC);
  end;
  SetWindowPos(HWindow,HWND_TOP,PosX,PosY,WW,WH,0);
{$ifdef TERATERM32}
  SetForegroundWindow(HWindow);
{$else}
  SetActiveWindow(HWindow);
{$endif}
end;

end.
