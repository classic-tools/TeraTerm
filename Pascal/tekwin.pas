{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, TEK window}
unit TEKWin;

interface
{$i teraterm.inc}

{$IFDEF Delphi}
uses Messages, WinTypes, WinProcs, OWindows, Strings,
     TTTypes, TEKTypes, TEKLib, TTWinMan, TTCommon,
     Keyboard, Clipboard, TeraPrn, TTDialog;
{$ELSE}
uses WinTypes, WinProcs, WObjects, Win31, Strings,
     TTTypes, TEKTypes, TEKLib, TTWinMan, TTCommon,
     Keyboard, Clipboard, TeraPrn, TTDialog;
{$ENDIF}

{$i tt_res.inc}

type
  PTEKWindow = ^TEKWindow;
  TEKWindow = object(TWindow)

    tk: TTEKVar;
    MainMenu, EditMenu, WinMenu: HMenu;
    constructor Init;
    procedure SetupWindow; virtual;
    function GetClassName: PChar; virtual;
    procedure GetWindowClass(var AWndClass: TWndClass); virtual;

    function Parse: integer;
    procedure RestoreSetup;
    procedure InitMenu(var Menu: HMenu);
    procedure InitMenuPopup(SubMenu: HMenu);

    procedure DefWndProc(var Msg: TMessage); virtual;

    procedure WMCommand(var Msg: TMessage);
      virtual WM_COMMAND;

    procedure WMActivate(var Msg: TMessage);
      virtual WM_ACTIVATE;
    procedure WMChar(var Msg: TMessage);
      virtual WM_CHAR;
    procedure WMDestroy(var Msg: TMessage);
      virtual WM_DESTROY;
    procedure WMGetMinMaxInfo(var Msg: TMessage);
      virtual WM_GETMINMAXINFO;
    procedure WMInitMenuPopup(var Msg: TMessage);
      virtual WM_INITMENUPOPUP;
    procedure WMKeyDown(var Msg: TMessage);
      virtual WM_KEYDOWN;
    procedure WMKeyUp(var Msg: TMessage);
      virtual WM_KEYUP;
    procedure WMKillFocus(var Msg: TMessage);
      virtual WM_KILLFOCUS;
    procedure WMLButtonDown(var Msg: TMessage);
      virtual WM_LBUTTONDOWN;
    procedure WMLButtonUp(var Msg: TMessage);
      virtual WM_LBUTTONUP;
    procedure WMMButtonUp(var Msg: TMessage);
      virtual WM_MBUTTONUP;
    procedure WMMouseActivate(var Msg: TMessage);
      virtual WM_MOUSEACTIVATE;
    procedure WMMouseMove(var Msg: TMessage);
      virtual WM_MOUSEMOVE;
    procedure WMMove(var Msg: TMessage);
      virtual WM_MOVE;
    procedure Paint(PaintDC: HDC; var PaintInfo:TPaintStruct); virtual;
    procedure WMRButtonUp(var Msg: TMessage);
      virtual WM_RBUTTONUP;
    procedure WMSetFocus(var Msg: TMessage);
      virtual WM_SETFOCUS;
    procedure WMSize(var Msg: TMessage);
      virtual WM_SIZE;
    procedure WMSysCommand(var Msg: TMessage);
      virtual WM_SYSCOMMAND;
    procedure WMSysKeyDown(var Msg: TMessage);
      virtual WM_SYSKEYDOWN;
    procedure WMSysKeyUp(var Msg: TMessage);
      virtual WM_SYSKEYUP;
    procedure WMTimer(var Msg: TMessage);
      virtual WM_TIMER;

    procedure WMAccelCommand(var Msg: TMessage);
      virtual WM_USER_ACCELCOMMAND;
    procedure WMChangeMenu(var Msg: TMessage);
      virtual WM_USER_CHANGEMENU;
    procedure WMChangeTBar(var Msg: TMessage);
      virtual WM_USER_CHANGETBAR;
    procedure WMDlgHelp(var Msg: TMessage);
      virtual WM_USER_DLGHELP2;
    procedure WMGetSerialNo(var Msg: TMessage);
      virtual WM_USER_GETSERIALNO;

    procedure CMFilePrint(var Msg: TMessage);
      virtual ID_TEKFILE_PRINT;
    procedure CMFileExit(var Msg: TMessage);
      virtual ID_TEKFILE_EXIT;
    procedure CMEditCopy(var Msg: TMessage);
      virtual ID_TEKEDIT_COPY;
    procedure CMEditCopyScreen(var Msg: TMessage);
      virtual ID_TEKEDIT_COPYSCREEN;
    procedure CMEditPaste(var Msg: TMessage);
      virtual ID_TEKEDIT_PASTE;
    procedure CMEditPasteCR(var Msg: TMessage);
      virtual ID_TEKEDIT_PASTECR;
    procedure CMEditClearScreen(var Msg: TMessage);
      virtual ID_TEKEDIT_CLEARSCREEN;
    procedure CMSetupWindow(var Msg: TMessage);
      virtual ID_TEKSETUP_WINDOW;
    procedure CMSetupFont(var Msg: TMessage);
      virtual ID_TEKSETUP_FONT;
    procedure CMVTWin(var Msg: TMessage);
      virtual ID_TEKVTWIN;
    procedure CMWindowWindow(var Msg: TMessage);
      virtual ID_WINDOW_WINDOW;
    procedure CMHelpIndex(var Msg: TMessage);
      virtual ID_TEKHELP_INDEX;
    procedure CMHelpUsing(var Msg: TMessage);
      virtual ID_TEKHELP_USING;
    procedure CMAbout(var Msg: TMessage);
      virtual ID_TEKHELP_ABOUT;
  end;

implementation
{$i helpid.inc}

const
{$ifdef TERATERM32}
  TEKClassName = 'TEKWin32';
{$else}
  TEKClassName = 'TEKWin';
{$endif}

constructor TEKWindow.Init;
begin
  TWindow.Init(nil, nil);

  if not LoadTTTEK then
  begin
    CloseWindow;
  end;

  TEKInit(@tk,@ts);
  Attr.Menu := 0;

  if ts.HideTitle>0 then
    Attr.Style := WS_VISIBLE or WS_POPUP or WS_THICKFRAME or WS_BORDER
  else
    Attr.Style := WS_VISIBLE or WS_CAPTION or WS_SYSMENU or
                  WS_MINIMIZEBOX or WS_BORDER or WS_THICKFRAME;

  Attr.W := 640; {temporary width}
  Attr.H := 400; {temporary height}
  Attr.X := ts.TEKPos.X;
  Attr.Y := ts.TEKPos.Y;

  MainMenu := 0;
  WinMenu := 0;
  if (ts.HideTitle=0) and (ts.PopupMenu=0) then
    InitMenu(MainMenu);
  Attr.Menu := MainMenu;
end;

procedure TEKWindow.SetupWindow;
var
  rect: TRect;
begin
  HTEKWin := HWindow;
  tk.HWin := HWindow;
  {register this window to the window list}
  RegWin(HVTWin,HWindow);

  TEKResizeWindow(@tk,@ts,Attr.W,Attr.H);

{$ifdef TERATERM32}
  {set the small icon}
  PostMessage(HWindow,WM_SETICON,0,
    LPARAM(LoadImage(hInstance,PChar(IDI_TEK)),
    IMAGE_ICON,16,16,0));
{$endif}
  ChangeTitle;

  GetWindowRect(tk.HWin,rect);
  TEKResizeWindow(@tk,@ts,
    rect.right-rect.left, rect.bottom-rect.top);

  if (ts.PopupMenu>0) or (ts.HideTitle>0) then
    PostMessage(HWindow,WM_USER_CHANGEMENU,0,0);

  TWindow.SetupWindow;
end;

function TEKWindow.GetClassName: PChar;
begin
  GetClassName := TEKClassName;
end;

procedure TEKWindow.GetWindowClass(var AWndClass: TWndClass);
begin
  TWindow.GetWindowClass(AWndClass);
  AWndClass.hbrBackground := 0; {BackGround}
  AWndClass.HIcon := LoadIcon(HInstance, PChar(IDI_TEK));
end;

function TEKWindow.Parse: integer;
begin
  Parse := TEKParse(@tk,@ts,@cv);
end;

procedure TEKWindow.RestoreSetup;
begin
  TEKRestoreSetup(@tk,@ts);
  ChangeTitle;
end;

procedure TEKWindow.InitMenu(var Menu: HMenu);
begin
  Menu := LoadMenu(hInstance,PChar(IDR_TEKMENU));
  EditMenu := GetSubMenu(MainMenu,1);
  if ts.MenuFlag and MF_SHOWWINMENU <> 0 then
  begin
    WinMenu := CreatePopupMenu;
    InsertMenu(Menu,4,
      MF_STRING or MF_ENABLED or MF_POPUP or MF_BYPOSITION,
      WinMenu, '&Window');
  end;
end;

procedure TEKWindow.InitMenuPopup(SubMenu: HMenu);
begin
  if SubMenu=EditMenu then
  begin
    if tk.Select then
      EnableMenuItem(EditMenu,ID_TEKEDIT_COPY,MF_BYCOMMAND or MF_ENABLED)
    else
      EnableMenuItem(EditMenu,ID_TEKEDIT_COPY,MF_BYCOMMAND or MF_GRAYED);

    if cv.Ready and
       (IsClipboardFormatAvailable(CF_TEXT) or
        IsClipboardFormatAvailable(CF_OEMTEXT)) then
    begin
      EnableMenuItem(EditMenu,ID_TEKEDIT_PASTE,MF_BYCOMMAND or MF_ENABLED);
      EnableMenuItem(EditMenu,ID_TEKEDIT_PASTECR,MF_BYCOMMAND or MF_ENABLED);
    end
    else begin
      EnableMenuItem(EditMenu,ID_TEKEDIT_PASTE,MF_BYCOMMAND or MF_GRAYED);
      EnableMenuItem(EditMenu,ID_TEKEDIT_PASTECR,MF_BYCOMMAND or MF_GRAYED);
    end;
  end
  else if SubMenu=WinMenu then
  begin
    SetWinMenu(WinMenu);
  end;
end;

procedure TEKWindow.DefWndProc(var Msg: TMessage);
begin
  if Msg.Message=MsgDlgHelp then
    WMDlgHelp(Msg)
  else if (ts.HideTitle>0) and
          (Msg.Message=WM_NCHITTEST) then
  begin
    TWindow.DefWndProc(Msg);
    if (Msg.Result=HTCLIENT) and AltKey then
      Msg.Result := HTCAPTION;
  end         
  else
    TWindow.DefWndProc(Msg);
end;

procedure TEKWindow.WMCommand(var Msg: TMessage);
begin
  if (LOWORD(Msg.wParam)>=ID_WINDOW_1) and
     (LOWORD(Msg.wParam)<ID_WINDOW_1+9) then
    SelectWin(LOWORD(Msg.wParam)-ID_WINDOW_1)
  else begin
    Msg.wParam := LOWORD(Msg.wParam)-CM_FIRST;
    TWindow.WMCommand(Msg);
  end;
end;

procedure TEKWindow.WMActivate(var Msg: TMessage);
begin
with tk do begin
  if LOWORD(Msg.wParam)<>WA_INACTIVE then
  begin
    Active := TRUE;
    ActiveWin := IdTEK;
  end
  else begin
    Active := FALSE;
  end;
end;
end;

procedure TEKWindow.WMChar(var Msg: TMessage);
var
  i, Count: integer;
  Code: byte;
begin
  if not KeybEnabled or (TalkStatus<>IdTalkKeyb) then exit;

  Code  := Msg.wParam and $ff;
  Count := Msg.lParam and $007f;

  if tk.GIN then TEKReportGIN(@tk,@ts,@cv,Code)
  else
    for i := 1 to Count do
    begin
      CommTextOut(@cv,@Code,1);
      if ts.LocalEcho>0 then
      CommTextEcho(@cv,@Code,1);
    end;
end;

procedure TEKWindow.WMDestroy(var Msg: TMessage);
begin
  {remove this window from the window list}
  UnregWin(HWindow);

  TWindow.WMDestroy(Msg);

  TEKEnd(@tk);
  FreeTTTEK;
  HTEKWin := 0;
  pTEKWin := nil;
  ActiveWin := IdVT;
end;

procedure TEKWindow.WMGetMinMaxInfo(var Msg: TMessage);
begin
with tk do begin
  PMinMaxInfo(Msg.lParam)^.ptMaxSize.X := 10000;
  PMinMaxInfo(Msg.lParam)^.ptMaxSize.Y := 10000;
  PMinMaxInfo(Msg.lParam)^.ptMaxTrackSize.X := 10000;
  PMinMaxInfo(Msg.lParam)^.ptMaxTrackSize.Y := 10000;
end;
end;

procedure TEKWindow.WMInitMenuPopup(var Msg: TMessage);
begin
  InitMenuPopup(Msg.wParam);
end;

procedure TEKWindow.WMKeyDown(var Msg: TMessage);
begin
  KeyDown(HWindow,Msg.wParam,Msg.lParam and $007f,HiWord(Msg.lParam) and $1ff);
end;

procedure TEKWindow.WMKeyUp(var Msg: TMessage);
begin
  KeyUp(Msg.wParam);
end;

procedure TEKWindow.WMKillFocus(var Msg: TMessage);
begin
  TEKDestroyCaret(@tk,@ts);
  TWindow.DefWndProc(Msg);
end;

procedure TEKWindow.WMLButtonDown(Var Msg: TMessage);
var
  p: TPoint;
  PopupMenu, PopupBase: HMenu;
begin
  p.x := LOWord(Msg.lParam);
  p.y := HIWord(Msg.lParam);

  {popup menu}
  if ControlKey and (MainMenu=0) then
  begin
    InitMenu(PopupMenu);
    InitMenuPopup(EditMenu);
    if WinMenu<>0 then
      InitMenuPopup(WinMenu);
    PopupBase := CreatePopupMenu;
    AppendMenu(PopupBase, MF_STRING or MF_ENABLED or MF_POPUP,
      GetSubMenu(PopupMenu,0), '&File');
    AppendMenu(PopupBase, MF_STRING or MF_ENABLED or MF_POPUP,
      EditMenu, '&Edit');
    AppendMenu(PopupBase, MF_STRING or MF_ENABLED or MF_POPUP,
      GetSubMenu(PopupMenu,2), '&Setup');
    AppendMenu(PopupBase, MF_STRING or MF_ENABLED,
      ID_TEKVTWIN, 'VT&Win');
    if WinMenu<>0 then
      AppendMenu(PopupBase, MF_STRING or MF_ENABLED or MF_POPUP,
        WinMenu, '&Window');
    AppendMenu(PopupBase, MF_STRING or MF_ENABLED or MF_POPUP,
      GetSubMenu(PopupMenu,4),'&Help');

    ClientToScreen(HWindow, p);
    TrackPopupMenu(PopupBase,TPM_LEFTALIGN or TPM_LEFTBUTTON,
                   p.x,p.y,0,HWindow,nil);
    if WinMenu<>0 then
    begin
      DestroyMenu(WinMenu);
      WinMenu := 0;
    end;
    DestroyMenu(PopupBase);
    DestroyMenu(PopupMenu);
  end
  else
    TEKWMLButtonDown(@tk,@ts,@cv,p);
end;

procedure TEKWindow.WMLButtonUp(Var Msg: TMessage);
begin
  TEKWMLButtonUp(@tk,@ts);
end;

procedure TEKWindow.WMMButtonUp(Var Msg: TMessage);
begin
  WMRButtonUp(Msg);
end;

procedure TEKWindow.WMMouseActivate(var Msg: TMessage);
begin
  if (ts.SelOnActive=0) and
     (LOWORD(Msg.lParam)=HTCLIENT) then
     {disable mouse event for text selection}
     {when window is activated}
    Msg.Result := MA_ACTIVATEANDEAT
  else
    Msg.Result := MA_ACTIVATE;
end;

procedure TEKWindow.WMMouseMove(var Msg: TMessage);
var
  p: TPoint;
begin
  p.x := LOWORD(Msg.lParam);
  p.y := HIWORD(Msg.lParam);
  TEKWMMouseMove(@tk,@ts,p);
end;

procedure TEKWindow.WMMove(var Msg: TMessage);
begin
  TWindow.WMMove(Msg);
  ts.TEKPos.x := Attr.x;
  ts.TEKPos.y := Attr.y;
end;

procedure TEKWindow.Paint(PaintDC: HDC; var PaintInfo:TPaintStruct);
begin
  TEKPaint(@tk,@ts,PaintDC,@PaintInfo);
end;

procedure TEKWindow.WMRButtonUp(Var Msg: TMessage);
begin
  CBStartPaste(HWindow,FALSE,0,nil,0);
end;

procedure TEKWindow.WMSetFocus(var Msg: TMessage);
begin
  TEKChangeCaret(@tk,@ts);
  TWindow.DefWndProc(Msg);
end;

procedure TEKWindow.WMSize(Var Msg: TMessage);
begin
  TWindow.WMSize(Msg);

  if tk.Minimized and (Msg.wParam=SIZE_RESTORED) then
  begin
    tk.Minimized := FALSE;
    exit;
  end;
  tk.Minimized := (Msg.wParam=SIZE_MINIMIZED);
  if tk.Minimized then exit;

  TEKWMSize(@tk,@ts,Attr.W,Attr.H,
            LOWORD(Msg.lParam),HIWORD(Msg.lParam));
end;

procedure TEKWindow.WMSysCommand(var Msg: TMessage);
begin
  case Msg.wParam of
    ID_SHOWMENUBAR:
      begin
        ts.PopupMenu := 0;
        SwitchMenu;
      end;
  else
    DefWndProc(Msg);
  end;
end;

procedure TEKWindow.WMSysKeyDown(var Msg: TMessage);
begin
  case Msg.wParam of
    VK_F10: WMKeyDown(Msg);
  else
    DefWndProc(Msg);
  end;
end;

procedure TEKWindow.WMSysKeyUp(var Msg: TMessage);
begin
  case Msg.wParam of
    VK_F10: WMKeyUp(Msg);
  else
    DefWndProc(Msg);
  end;
end;

procedure TEKWindow.WMTimer(var Msg: TMessage);
var
  T: integer;
begin
  if Msg.wParam=IdCaretTimer then
  begin
    if ts.NonblinkingCursor<>0 then
    begin
      T := GetCaretBlinkTime;
      SetCaretBlinkTime(T);
    end
    else
      KillTimer(HWindow,IdCaretTimer);
  end
  else
    KillTimer(HWindow,Msg.wParam);
end;

procedure TEKWindow.WMAccelCommand(var Msg: TMessage);
begin
  case Msg.wParam of
    IdPrint: CMFilePrint(Msg);
    IdCmdEditCopy: CMEditCopy(Msg);
    IdCmdEditPaste: CMEditPaste(Msg);
    IdCmdEditPasteCR: CMEditPasteCR(Msg);
    IdCmdEditCLS: CMEditClearScreen(Msg);
    IdCmdCtrlCloseTEK: CMFileExit(Msg);
    IdCmdNextWin:
      SelectNextWin(HWindow,1);
    IdCmdPrevWin:
      SelectNextWin(HWindow,-1);
    IdBreak,
    IdCmdRestoreSetup,
    IdCmdLoadKeyMap:
      PostMessage(HVTWin,WM_USER_ACCELCOMMAND,Msg.wParam,0);
  end;
end;

procedure TEKWindow.WMChangeMenu(var Msg: TMessage);
var
  SysMenu: HMENU;
  S, B1, B2: bool;
begin
  S := (ts.PopupMenu=0) and (ts.HideTitle=0);
  if S <> (MainMenu<>0) then
  begin
    if not S then
    begin
      if WinMenu<>0 then
        DestroyMenu(WinMenu);
      WinMenu := 0;
      DestroyMenu(MainMenu);
      MainMenu := 0;
    end
    else
      InitMenu(MainMenu);
    Attr.Menu := MainMenu;
    tk.AdjustSize := TRUE;
    SetMenu(tk.HWin, MainMenu);
    DrawMenuBar(HWindow);
  end;

  B1 := (ts.MenuFlag and MF_SHOWWINMENU)<>0;
  B2 := (WinMenu<>0);
  if (MainMenu<>0) and
     (B1 <> B2) then
  begin
    if WinMenu=0 then
    begin
      WinMenu := CreatePopupMenu;
      InsertMenu(MainMenu,4,
        MF_STRING or MF_ENABLED or
	MF_POPUP or MF_BYPOSITION,
	WinMenu, '&Window');
    end
    else begin
      RemoveMenu(MainMenu,4,MF_BYPOSITION);
      DestroyMenu(WinMenu);
      WinMenu := 0;
    end;
    DrawMenuBar(HWindow);
  end;

  GetSystemMenu(tk.HWin,TRUE);
  if not S and (ts.MenuFlag and MF_NOSHOWMENU = 0) then
  begin
    SysMenu := GetSystemMenu(tk.HWin,FALSE);
    AppendMenu(SysMenu, MF_SEPARATOR, 0, nil);
    AppendMenu(SysMenu, MF_STRING, ID_SHOWMENUBAR, 'Show menu &bar');
  end;
end;

procedure TEKWindow.WMChangeTBar(var Msg: TMessage);
var
  TBar: bool;
  Style: longint;
  SysMenu: HMenu;
begin
  Style := GetWindowLong(HWindow, GWL_STYLE);
  TBar := ((Style and WS_SYSMENU)<>0);
  if TBar = (ts.HideTitle=0) then exit;
  if ts.HideTitle>0 then
    Style := Style and
      not (WS_SYSMENU or WS_CAPTION or WS_MINIMIZEBOX)
      or WS_BORDER or WS_POPUP
  else
    Style := Style and not WS_POPUP or
      WS_SYSMENU or WS_CAPTION or WS_MINIMIZEBOX;
  tk.AdjustSize := TRUE;
  SetWindowLong(HWindow, GWL_STYLE, Style);
  SetWindowPos(HWindow, 0, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or
                SWP_NOZORDER or SWP_FRAMECHANGED);
  ShowWindow(HWindow, SW_SHOW);

  if (ts.HideTitle=0) and (MainMenu=0) and
     (ts.MenuFlag and MF_NOSHOWMENU = 0) then
  begin
    SysMenu := GetSystemMenu(HWindow,FALSE);
    AppendMenu(SysMenu, MF_SEPARATOR, 0, nil);
    AppendMenu(SysMenu, MF_STRING, ID_SHOWMENUBAR, 'Show menu &bar');
  end;
end;

procedure TEKWindow.WMDlgHelp(var Msg: TMessage);
begin
  OpenHelp(tk.HWin,HELP_CONTEXT,HelpId);
end;

procedure TEKWindow.WMGetSerialNo(var Msg: TMessage);
begin
  Msg.Result := longint(SerialNo);
end;

procedure TEKWindow.CMFilePrint(var Msg: TMessage);
var
  Sel: bool;
  PrintDC: HDC;
begin
with tk do begin
  HelpId := HlpTEKFilePrint;

  Sel := Select;
  PrintDC := PrnBox(HWindow,@Sel);
  if PrintDC=0 then exit;
  if not PrnStart(ts.Title) then exit;

  TEKPrint(@tk,@ts,PrintDC,Sel);

  PrnStop;
end;
end;

procedure TEKWindow.CMFileExit(var Msg: TMessage);
begin
  CloseWindow;
end;

procedure TEKWindow.CMEditCopy(var Msg: TMessage);
begin
  TEKCMCopy(@tk,@ts);
end;

procedure TEKWindow.CMEditCopyScreen(var Msg: TMessage);
begin
  TEKCMCopyScreen(@tk,@ts);
end;


procedure TEKWindow.CMEditPaste(var Msg: TMessage);
begin
with tk do begin
  CBStartPaste(HWindow,FALSE,0,nil,0);
end;
end;

procedure TEKWindow.CMEditPasteCR(var Msg: TMessage);
begin
with tk do begin
  CBStartPaste(HWindow,TRUE,0,nil,0);
end;
end;

procedure TEKWindow.CMEditClearScreen(var Msg: TMessage);
begin
  TEKClearScreen(@tk,@ts);
end;

procedure TEKWindow.CMSetupWindow(var Msg: TMessage);
var
  Ok: bool;
  OldEmu: word;
begin
  HelpId := HlpTEKSetupWindow;
  ts.VTFlag := 0;
  ts.SampleFont := tk.TEKFont[0];

  if not LoadTTDLG then exit;
  OldEmu := ts.TEKColorEmu;
  Ok := SetupWin(HTEKWin, @ts);
  FreeTTDLG;
  if Ok then
  begin
    TEKResetWin(@tk,@ts,OldEmu);
    ChangeTitle;
    SwitchMenu;
    SwitchTitleBar;
  end;
end;

procedure TEKWindow.CMSetupFont(var Msg: TMessage);
var
  Ok: bool;
begin
  HelpId := HlpTEKSetupFont;
  if not LoadTTDLG then exit;
  Ok := ChooseFontDlg(HTEKWin,@tk.TEKlf,nil);
  FreeTTDLG;
  if not OK then exit;

  TEKSetupFont(@tk,@ts);
end;

procedure TEKWindow.CMVTWin(var Msg: TMessage);
begin
  VTActivate;
end;

procedure TEKWindow.CMWindowWindow(var Msg: TMessage);
var
  Close: bool;
begin
  HelpId := HlpWindowWindow;
  if not LoadTTDLG then exit;
  WindowWindow(HWindow,@Close);
  FreeTTDLG;
  if Close then CMFileExit(Msg);
end;

procedure TEKWindow.CMHelpIndex(var Msg: TMessage);
begin
  OpenHelp(HWindow,HELP_INDEX,0);
end;

procedure TEKWindow.CMHelpUsing(var Msg: TMessage);
begin
  WinHelp(HWindow, '', HELP_HELPONHELP, 0);
end;

procedure TEKWindow.CMAbout(var Msg: TMessage);
begin
  if not LoadTTDLG then exit;
  AboutDialog(HWindow);
  FreeTTDLG;
end;

end.
