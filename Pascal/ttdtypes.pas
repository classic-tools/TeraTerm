{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, TTDLG interface}
unit TTDTypes;

interface

uses WinTypes, TTTypes;

type
  TSetupTerminal = function(WndParent: HWnd; ts: PTTSet): BOOL;
  TSetupWin = function(WndParent: HWnd; ts: PTTSet): BOOL;
  TSetupKeyboard = function(WndParent: HWnd; ts: PTTSet): BOOL;
  TSetupSerialPort= function(WndParent: HWnd; ts: PTTSet): BOOL;
  TSetupTCPIP = function(WndParent: HWnd; ts: PTTSet): BOOL;
  TGetHostName = function(WndParent: HWnd; GetHNRec: PGetHNRec): BOOL;
  TChangeDirectory = function(WndParent: HWnd; CurDir: PChar): BOOL;
  TAboutDialog = function(WndParent: HWnd): BOOL;
  TChooseFontDlg = function(WndParent: HWnd; LogFont: PLogFont; ts: PTTSet): BOOL;
  TSetupGeneral = function(WndParent: HWnd; ts: PTTSet): BOOL;
  TWindowWindow = function(WndParent: HWnd; Close: PBOOL): BOOL;

implementation

end.
