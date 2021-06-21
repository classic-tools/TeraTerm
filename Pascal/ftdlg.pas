{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, file transfer dialog box}
unit FTDlg;

interface
{$i teraterm.inc}

{$IFDEF Delphi}
uses
  {$ifndef TERATERM32}
  TTCtl3d,
  {$endif}
  Messages, WinTypes, WinProcs, OWindows, ODialogs, Strings,
  TTTypes, TTFTypes;
{$ELSE}
uses
  {$ifndef TERATERM32}
  TTCtl3d,
  {$endif}
  WinTypes, WinProcs, WObjects, Strings, TTTypes, TTFTypes;
{$ENDIF}

type
{text file transfer dialog box}
  PFileTransDlg = ^TFileTransDlg;
  TFileTransDlg = object(TDlgWindow)
    fv: PFileVar;
    cv: PComVar;
    Pause: BOOL;
    constructor Init(pfv: PFileVar; pcv: PComVar);
    function GetClassName: PChar; virtual;
    procedure GetWindowClass(var AWndClass: TWndClass); virtual;
    procedure SetupWindow; virtual;
    procedure ChangeButton(PauseFlag: BOOL);
    procedure RefreshNum;
    procedure WMCommand(var Msg: TMessage);
      virtual WM_COMMAND;
    procedure WMSysCommand(var Msg: TMessage);
      virtual WM_SYSCOMMAND;
  end;

implementation
{$i tt_res.inc}

{File transfer dialog box}
constructor TFileTransDlg.Init(pfv: PFileVar; pcv: PComVar);
begin
  if pfv^.OpId=OpLog then {parent window is desktop}
    TDlgWindow.Init(nil,PChar(IDD_FILETRANSDLG))
  else {parent window is VT window}
    TDlgWindow.Init(Application^.MainWindow,PChar(IDD_FILETRANSDLG));
  fv := pfv;
  cv := pcv;
  cv^.FilePause := cv^.FilePause and not fv^.OpId;
  Pause := FALSE;
end;

function TFileTransDlg.GetClassName: PChar;
begin
{$ifdef TERATERM32}
  GetClassName := 'FTDlg32';
{$else}
  GetClassName := 'FTDlg';
{$endif}
end;

procedure TFileTransDlg.GetWindowClass(var AWndClass: TWndClass);
begin
  TDlgWindow.GetWindowClass(AWndClass);
  AWndClass.HIcon := LoadIcon(HInstance, PChar(IDI_TTERM));
end;

procedure TFileTransDlg.SetupWindow;
begin
{$ifndef TERATERM32}
  SubclassDlg(HWindow); {CTL3D}
{$endif}

  fv^.HWin := HWindow;
  SetWindowText(HWindow, fv^.DlgCaption);
  SetDlgItemText(HWindow, IDC_TRANSFNAME, @fv^.FullName[fv^.DirLen]);
{$ifdef TERATERM32}
  {set small icon}
  PostMessage(HWindow,WM_SETICON,0,
    LoadImage(hInstance,PChar(IDI_TTERM),IMAGE_ICON,16,16,0));
{$endif}
  TDlgWindow.SetupWindow;
end;

procedure TFileTransDlg.ChangeButton(PauseFlag: BOOL);
begin
  Pause := PauseFlag;
  if Pause then
  begin
    SetDlgItemText(HWindow, IDC_TRANSPAUSESTART, '&Start');
    cv^.FilePause := cv^.FilePause or fv^.OpId;
  end
  else begin
    SetDlgItemText(HWindow, IDC_TRANSPAUSESTART, 'Pau&se');
    cv^.FilePause := cv^.FilePause and not fv^.OpId;
  end;
end;

procedure TFileTransDlg.RefreshNum;
var
  NumPStr: string[10];
  NumStr: array[0..12] of char;
begin
  Str(FV^.ByteCount,NumPStr);
  StrPCopy(NumStr,NumPStr);
  SetDlgItemText(HWindow, IDC_TRANSBYTES, NumStr);
end;

procedure TFileTransDlg.WMCommand(var Msg: TMessage);
begin
  case LOWORD(Msg.wParam) of
    IDCANCEL:
      PostMessage(fv^.HMainWin,WM_USER_FTCANCEL,fv^.OpId,0);
    IDC_TRANSPAUSESTART:
      ChangeButton(not Pause);
    IDC_TRANSHELP:
      PostMessage(fv^.HMainWin,WM_USER_DLGHELP2,0,0);
  else 
    TDlgWindow.WMCommand(Msg);
  end;
end;

procedure TFileTransDlg.WMSysCommand(var Msg: TMessage);
begin
  if Msg.wParam and $fff0=SC_CLOSE then
    PostMessage(fv^.HMainWin,WM_USER_FTCANCEL,fv^.OpId,0)
  else
    TDlgWindow.DefWndProc(Msg);
end;

end.
