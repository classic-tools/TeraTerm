{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, print-abort dialog box}
unit PrnAbort;

interface
{$i teraterm.inc}

{$IFDEF Delphi}
uses Messages, WinTypes, OWindows, ODialogs, WinProcs;
{$ELSE}
uses WinTypes, WObjects, WinProcs;
{$ENDIF}

type
  PPrnAbortDlg = ^TPrnAbortDlg;
  TPrnAbortDlg = object(TDlgWindow)
    Abort: PBOOL;
    constructor Init(Aparent: PWindowsObject; AbortFlag: PBOOL);
    procedure WMInitDialog(var Msg: TMessage);
      virtual WM_INITDIALOG;
    procedure WMCommand(var Msg: TMessage);
      virtual WM_COMMAND;
    procedure CloseWindow; virtual;
  end;

implementation
{$i tt_res.inc}

constructor TPrnAbortDlg.Init(Aparent: PWindowsObject; AbortFlag: PBOOL);
begin
  Abort := AbortFlag;
  TDlgWindow.Init(Aparent, PChar(IDD_PRNABORTDLG));
end;

procedure TPrnAbortDlg.WMInitDialog(var Msg: TMessage);
begin
  EnableWindow(Parent^.HWindow,FALSE);
  SetFocus(HWindow);
end;

procedure TPrnAbortDlg.WMCommand(var Msg: TMessage);
begin
  Abort^ := TRUE;
  CloseWindow;
end;

procedure TPrnAbortDlg.CloseWindow;
begin
  EnableWindow(Parent^.HWindow,TRUE);
  SetFocus(Parent^.HWindow);
  TDlgWindow.CloseWindow;
end;

end.
