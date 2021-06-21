{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTMACRO.EXE, status dialog box}
unit StatDlg;

interface
{$i teraterm.inc}

{$IFDEF Delphi}
uses
  WinTypes, WinProcs, OWindows, ODialogs, Strings,
  Types, TTMLib;
{$ELSE}
uses
  WinTypes, WinProcs, WObjects, Win31, Strings,
  Types, TTMLib;
{$ENDIF}

type
  PStatDlg = ^TStatDlg;
  TStatDlg = object(TDlgWindow)
    TextStr, TitleStr: PChar;
    PosX, PosY: integer;
    constructor Init(Text, Title: PChar; x, y: integer);
    procedure Update(Text, Title: PChar; x, y: integer);
    procedure SetupWindow; virtual;
  end;

implementation

const
  IDD_STATDLG  = 500;
  IDC_STATTEXT = 501;

constructor TStatDlg.Init(Text, Title: PChar; x, y: integer);
begin
  TDlgWindow.Init(Application^.MainWindow, PChar(IDD_STATDLG));
  TextStr := Text;
  TitleStr := Title;
  PosX := x;
  PosY := y;
end;

procedure TStatDlg.Update(Text, Title: PChar; x, y: integer);
var
  R: TRECT;
  TmpDC: HDC;
  s: TSIZE;
  HText: HWND;
  WW, WH, CW, CH, TW, TH: integer;
begin
  if Title<>nil then
    SetWindowText(HWindow,Title);

  GetWindowRect(HWindow,R);
  PosX := R.left;
  PosY := R.top;
  WW := R.right-R.left;
  WH := R.bottom-R.top;

  if Text<>nil then
  begin
    SetDlgItemText(HWindow,IDC_STATTEXT,Text);

    HText := GetDlgItem(HWindow, IDC_STATTEXT);

    TmpDC := GetDC(HWindow);
    CalcTextExtent(TmpDC,Text,s);
    ReleaseDC(HWindow,TmpDC);
    TW := s.cx + s.cx div 10;
    TH := s.cy;

    GetClientRect(HWindow,R);
    CW := R.right-R.left;
    CH := R.bottom-R.top;
    if TW < CW then
      TW := CW;
    WW := WW + TW - CW;
    WH := WH + 2*TH - CH;

    MoveWindow(HText,(TW-s.cx) div 2,TH div 2,TW,TH,TRUE);
  end;

  if x<>32767 then
  begin
    PosX := x;
    PosY := y;
  end;
  if PosX<=-100 then
  begin
    TmpDC := GetDC(HWindow);
    PosX := (GetDeviceCaps(TmpDC,HORZRES)-WW) div 2;
    PosY := (GetDeviceCaps(TmpDC,VERTRES)-WH) div 2;
    ReleaseDC(HWindow,TmpDC);
  end;
  SetWindowPos(HWindow,HWND_TOP,PosX,PosY,WW,WH,SWP_NOZORDER);
end;

procedure TStatDlg.SetupWindow;
begin
  TDlgWindow.SetupWindow;
  Update(TextStr,TitleStr,PosX,PosY);
{$ifdef TERATERM32}
  SetForegroundWindow(HWindow);
{$else}
  SetActiveWindow(HWindow);
{$endif}
end;

end.
