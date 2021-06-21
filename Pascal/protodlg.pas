{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, file-transfer-protocol dialog box}
unit ProtoDlg;

interface
{$i teraterm.inc}

{$IFDEF Delphi}
uses
  Messages, WinTypes, WinProcs, OWindows, ODialogs,
  TTTypes, TTFTypes;
{$else}
uses
  WinTypes, WinProcs, WObjects, TTTypes, TTFTypes;
{$endif}

type
  PProtoDlg = ^TProtoDlg;
  TProtoDlg = object(TDialog)
    fv: PFileVar;

    constructor Init(pfv: PFileVar);
    procedure SetupWindow; virtual;
    procedure WMCommand(var Msg: TMessage);
      virtual WM_COMMAND;
    procedure WMSysCommand(var Msg: TMessage);
      virtual WM_SYSCOMMAND;
  end;

implementation
{$i tt_res.inc}

constructor TProtoDlg.Init(pfv: PFileVar);
begin
  TDialog.Init(Application^.MainWindow,PChar(IDD_PROTDLG));
  fv := pfv;
end;

procedure TProtoDlg.SetupWindow;
begin
  fv^.HWin := HWindow;
  TDialog.SetupWindow;
end;

procedure TProtoDlg.WMCommand(var Msg: TMessage);
begin
  case LOWORD(Msg.wParam) of
    IDCANCEL:
      PostMessage(fv^.HMainWin,WM_USER_PROTOCANCEL,0,0);
  else
    TDialog.WMCommand(Msg);
  end;
end;

procedure TProtoDlg.WMSysCommand(var Msg: TMessage);
begin
  if Msg.wParam and $fff0=SC_CLOSE then
    PostMessage(fv^.HMainWin,WM_USER_PROTOCANCEL,0,0)
  else
    TDialog.DefWndProc(Msg);
end;

end.
