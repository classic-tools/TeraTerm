{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, VT window}
unit VTWin;

interface
{$i teraterm.inc}

{$IFDEF Delphi}
uses
  {$ifndef TERATERM32}
  TTCtl3d,
  {$endif}
  Messages, WinTypes, WinProcs, OWindows, Strings,
  CommDlg, ShellAPI,
  TTTypes, Types, CommLib, TTWinMan, TTCommon, TTSetup,
  TTDDE, Keyboard, VTDisp, Buffer, VTTerm, Clipboard,
  TTFTypes, FileSys, TEKWin, TTLib, Telnet, TTIME, TTDialog,
  WskTypes, TeraPrn, TTPlug;
{$ELSE}
uses
  {$ifndef TERATERM32}
  TTCtl3d,
  {$endif}
  WinTypes, WinProcs, WObjects, Strings, Win31,
  CommDlg, ShellAPI,
  TTTypes, Types, CommLib, TTWinMan, TTCommon, TTSetup,
  TTDDE, Keyboard, VTDisp, Buffer, VTTerm, Clipboard,
  TTFTypes, FileSys, TEKWin, TTLib, Telnet, TTIME, TTDialog,
  WskTypes, TeraPrn, TTPlug;
{$ENDIF}

{$i tt_res.inc}

const
{$ifdef TERATERM32}
  VTClassName = 'VTWin32';
{$else}
  VTClassName = 'VTWin';
{$endif}

  {mouse buttons}
  IdLeftButton = 0;
  IdMiddleButton = 1;
  IdRightButton = 2;

type
  PVTWindow = ^VTWindow;
  VTWindow = object(TWindow)
    FirstPaint, Minimized: bool;

    {mouse status}
    LButton, MButton, RButton: bool;
    DblClk, AfterDblClk, TplClk: bool;
    DblClkX, DblClkY: integer;

    {"Hold" key status}
    Hold: bool;

    MainMenu, FileMenu, TransMenu, EditMenu,
    SetupMenu, ControlMenu, WinMenu, HelpMenu: HMenu;

    constructor Init(Aparent: PWindowsObject);
    procedure SetupWindow; virtual;
    function GetClassName: PChar; virtual;
    procedure GetWindowClass(var AWndClass: TWndClass); virtual;

    function Parse: integer;
    procedure ButtonUp(Paste: bool);
    procedure ButtonDown(p: TPoint; LMR: integer);
    procedure InitMenu(var Menu: HMenu);
    procedure InitMenuPopup(SubMenu: HMenu);
    procedure ResetSetup;
    procedure RestoreSetup;
    procedure SetupTerm;
    procedure Startup;
    procedure OpenTEK;

    procedure DefWndProc(var Msg: TMessage); virtual;

    procedure WMCommand(var Msg: TMessage);
      virtual WM_COMMAND;

    procedure WMActivate(var Msg: TMessage);
      virtual WM_ACTIVATE;
    procedure WMChar(var Msg: TMessage);
      virtual WM_CHAR;
    procedure WMClose(var Msg: TMessage);
      virtual WM_CLOSE;
    procedure WMDestroy(var Msg: TMessage);
      virtual WM_DESTROY;
    procedure WMDropFiles(var Msg: TMessage);
      virtual WM_DROPFILES;
    procedure WMGetMinMaxInfo(var Msg: TMessage);
      virtual WM_GETMINMAXINFO;
    procedure WMHScroll(var Msg: TMessage);
      virtual WM_HSCROLL;
    procedure WMInitMenuPopup(var Msg: TMessage);
      virtual WM_INITMENUPOPUP;
    procedure WMKeyDown(var Msg: TMessage);
      virtual WM_KEYDOWN;
    procedure WMKeyUp(var Msg: TMessage);
      virtual WM_KEYUP;
    procedure WMKillFocus(var Msg: TMessage);
      virtual WM_KILLFOCUS;
    procedure WMLButtonDblClk(var Msg: TMessage);
      virtual WM_LBUTTONDBLCLK;
    procedure WMLButtonDown(var Msg: TMessage);
      virtual WM_LBUTTONDOWN;
    procedure WMLButtonUp(var Msg: TMessage);
      virtual WM_LBUTTONUP;
    procedure WMMButtonDown(var Msg: TMessage);
      virtual WM_MBUTTONDOWN;
    procedure WMMButtonUp(var Msg: TMessage);
      virtual WM_MBUTTONUP;
    procedure WMMouseActivate(var Msg: TMessage);
      virtual WM_MOUSEACTIVATE;
    procedure WMMouseMove(var Msg: TMessage);
      virtual WM_MOUSEMOVE;
    procedure WMMove(var Msg: TMessage);
      virtual WM_MOVE;
    procedure WMNCLBUTTONDBLCLK(var Msg: TMessage);
      virtual WM_NCLBUTTONDBLCLK;
    procedure WMNCRButtonDown(var Msg: TMessage);
      virtual WM_NCRBUTTONDOWN;
    procedure Paint(PaintDC: HDC; var PaintInfo:TPaintStruct); virtual;
    procedure WMRButtonDown(var Msg: TMessage);
      virtual WM_RBUTTONDOWN;
    procedure WMRButtonUp(var Msg: TMessage);
      virtual WM_RBUTTONUP;
    procedure WMSetFocus(var Msg: TMessage);
      virtual WM_SETFOCUS;
    procedure WMSize(var Msg: TMessage);
      virtual WM_SIZE;
    procedure WMSysChar(var Msg: TMessage);
      virtual WM_SYSCHAR;
{$ifndef TERATERM32}
    procedure WMSysColorChange(var Msg: TMessage);
      virtual WM_SYSCOLORCHANGE;
{$endif}
    procedure WMSysCommand(var Msg: TMessage);
      virtual WM_SYSCOMMAND;
    procedure WMSysKeyDown(var Msg: TMessage);
      virtual WM_SYSKEYDOWN;
    procedure WMSysKeyUp(var Msg: TMessage);
      virtual WM_SYSKEYUP;
    procedure WMTimer(var Msg: TMessage);
      virtual WM_TIMER;
    procedure WMVScroll(var Msg: TMessage);
      virtual WM_VSCROLL;
{$ifdef TERATERM32}
    procedure WMIMEComposition(var Msg: TMessage);
      virtual WM_IMECOMPOSITION;
{$endif}

    procedure WMAccelCommand(var Msg: TMessage);
      virtual WM_USER_ACCELCOMMAND;
    procedure WMChangeMenu(var Msg: TMessage);
      virtual WM_USER_CHANGEMENU;
    procedure WMChangeTBar(var Msg: TMessage);
      virtual WM_USER_CHANGETBAR;
    procedure WMCommNotify(var Msg: TMessage);
      virtual WM_USER_COMMNOTIFY;
    procedure WMCommOpen(var Msg: TMessage);
      virtual WM_USER_COMMOPEN;
    procedure WMCommStart(var Msg: TMessage);
      virtual WM_USER_COMMSTART;
    procedure WMDdeEnd(var Msg: TMessage);
      virtual WM_USER_DDEEND;
    procedure WMDlgHelp(var Msg: TMessage);
      virtual WM_USER_DLGHELP2;
    procedure WMFileTransEnd(var Msg: TMessage);
      virtual WM_USER_FTCANCEL;
    procedure WMGetSerialNo(var Msg: TMessage);
      virtual WM_USER_GETSERIALNO;
    procedure WMKeyCode(var Msg: TMessage);
      virtual WM_USER_KEYCODE;
    procedure WMProtoEnd(var Msg: TMessage);
      virtual WM_USER_PROTOCANCEL;

    procedure CMFileNewConnection(var Msg: TMessage);
      virtual ID_FILE_NEWCONNECTION;
    procedure CMFileLog(var Msg: TMessage);
      virtual ID_FILE_LOG;
    procedure CMFileSend(var Msg: TMessage);
      virtual ID_FILE_SENDFILE;
    procedure CMFileKermitRcv(var Msg: TMessage);
      virtual ID_FILE_KERMITRCV;
    procedure CMFileKermitGet(var Msg: TMessage);
      virtual ID_FILE_KERMITGET;
    procedure CMFileKermitSend(var Msg: TMessage);
      virtual ID_FILE_KERMITSEND;
    procedure CMFileKermitFinish(var Msg: TMessage);
      virtual ID_FILE_KERMITFINISH;
    procedure CMFileXRcv(var Msg: TMessage);
      virtual ID_FILE_XRCV;
    procedure CMFileXSend(var Msg: TMessage);
      virtual ID_FILE_XSEND;
    procedure CMFileZRcv(var Msg: TMessage);
      virtual ID_FILE_ZRCV;
    procedure CMFileZSend(var Msg: TMessage);
      virtual ID_FILE_ZSEND;
    procedure CMFileBPRcv(var Msg: TMessage);
      virtual ID_FILE_BPRCV;
    procedure CMFileBPSend(var Msg: TMessage);
      virtual ID_FILE_BPSEND;
    procedure CMFileQVRcv(var Msg: TMessage);
      virtual ID_FILE_QVRCV;
    procedure CMFileQVSend(var Msg: TMessage);
      virtual ID_FILE_QVSEND;
    procedure CMFileChangeDir(var Msg: TMessage);
      virtual ID_FILE_CHANGEDIR;
    procedure CMFilePrint(var Msg: TMessage);
      virtual ID_FILE_PRINT2;
    procedure CMFileDisconnect(var Msg: TMessage);
      virtual ID_FILE_DISCONNECT;
    procedure CMFileExit(var Msg: TMessage);
      virtual ID_FILE_EXIT;

    procedure CMEditCopy(var Msg: TMessage);
      virtual ID_EDIT_COPY2;
    procedure CMEditCopyTable(var Msg: TMessage);
      virtual ID_EDIT_COPYTABLE;
    procedure CMEditPaste(var Msg: TMessage);
      virtual ID_EDIT_PASTE2;
    procedure CMEditPasteCR(var Msg: TMessage);
      virtual ID_EDIT_PASTECR;
    procedure CMEditClearScreen(var Msg: TMessage);
      virtual ID_EDIT_CLEARSCREEN;
    procedure CMEditClearBuffer(var Msg: TMessage);
      virtual ID_EDIT_CLEARBUFFER;

    procedure CMSetupTerminal(var Msg: TMessage);
      virtual ID_SETUP_TERMINAL;
    procedure CMSetupWindow(var Msg: TMessage);
      virtual ID_SETUP_WINDOW;
    procedure CMSetupFont(var Msg: TMessage);
      virtual ID_SETUP_FONT;
    procedure CMSetupKeyboard(var Msg: TMessage);
      virtual ID_SETUP_KEYBOARD;
    procedure CMSetupSerialPort(var Msg: TMessage);
      virtual ID_SETUP_SERIALPORT;
    procedure CMSetupTCPIP(var Msg: TMessage);
      virtual ID_SETUP_TCPIP;
    procedure CMSetupGeneral(var Msg: TMessage);
      virtual ID_SETUP_GENERAL;
    procedure CMSetupSave(var Msg: TMessage);
      virtual ID_SETUP_SAVE;
    procedure CMSetupRestore(var Msg: TMessage);
      virtual ID_SETUP_RESTORE;
    procedure CMSetupLoadKeyMap(var Msg: TMessage);
      virtual ID_SETUP_LOADKEYMAP;

    procedure CMControlResetTerminal(var Msg: TMessage);
      virtual ID_CONTROL_RESETTERMINAL;
    procedure CMControlAreYouThere(var Msg: TMessage);
      virtual ID_CONTROL_AREYOUTHERE;
    procedure CMControlSendBreak(var Msg: TMessage);
      virtual ID_CONTROL_SENDBREAK;
    procedure CMControlResetPort(var Msg: TMessage);
      virtual ID_CONTROL_RESETPORT;
    procedure CMControlOpenTEK(var Msg: TMessage);
      virtual ID_CONTROL_OPENTEK;
    procedure CMControlCloseTEK(var Msg: TMessage);
      virtual ID_CONTROL_CLOSETEK;
    procedure CMControlMacro(var Msg: TMessage);
      virtual ID_CONTROL_MACRO;

    procedure CMWindowWindow(var Msg: TMessage);
      virtual ID_WINDOW_WINDOW;

    procedure CMHelpIndex(var Msg: TMessage);
      virtual ID_HELP_INDEX2;
    procedure CMHelpUsing(var Msg: TMessage);
      virtual ID_HELP_USING2;
    procedure CMHelpAbout(var Msg: TMessage);
      virtual ID_HELP_ABOUT;

  end;

implementation
{$i helpid.inc}

constructor VTWindow.Init(Aparent: PWindowsObject);
var
{$ifndef TERATERM32}
 i: integer;
{$endif}
 Temp: array[0..MAXPATHLEN-1] of char;
 tempkm: PKeyMap;
begin
  TTXInit(@ts, @cv); {TTPLUG}

  CommInit(@cv);

  MsgDlgHelp := RegisterWindowMessage(HELPMSGSTRING);

  if StartTeraTerm(@ts) then
  begin {first instance}
    if LoadTTSET then
    begin
      { read setup info from "teraterm.ini" }
      ReadIniFile(ts.SetupFName, @ts);
      { read keycode map from "keyboard.cnf" }
      New(tempkm);
      if tempkm<>nil then
      begin
	strcopy(Temp, ts.HomeDir);
	AppendSlash(Temp);
	strcat(Temp,'KEYBOARD.CNF');
	ReadKeyboardCnf(Temp,tempkm,TRUE);
      end;
      FreeTTSET;
      { store default sets in TTCMN }
      ChangeDefaultSet(@ts,tempkm);
      if tempkm<>nil then Dispose(tempkm);
    end;
  end;

  {Get command line}
{$ifdef TERATERM32}
  strcopy(Temp,GetCommandLine);
{$else}
  strcopy(Temp,'teraterm ');
  i := PByte(Ptr(GetCurrentPDB,$80))^;
  Move(PChar(Ptr(GetCurrentPDB,$81))[0],Temp[9],i);
  Temp[9+i] := #0;
{$endif}

  if LoadTTSET then
    ParseParam(Temp, @ts, TopicName);
  FreeTTSET;

  InitKeyboard;
  SetKeyMap;

  {window status}
  AdjustSize := TRUE;
  Minimized := FALSE;
  LButton := FALSE;
  MButton := FALSE;
  RButton := FALSE;
  DblClk := FALSE;
  AfterDblClk := FALSE;
  TplClk := FALSE;
  Hold := FALSE;
  FirstPaint := TRUE;

  {Initialize scroll buffer}
  InitBuffer;

  InitDisp;

  TWindow.Init(Aparent,ts.Title);

  if ts.HideTitle>0 then
    Attr.Style := WS_VSCROLL or WS_HSCROLL or
                  WS_BORDER or WS_THICKFRAME or WS_POPUP
  else
    Attr.Style := WS_VSCROLL or WS_HSCROLL or
                  WS_BORDER or WS_THICKFRAME or
                  WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX;

  Attr.X := ts.VTPos.X;
  Attr.Y := ts.VTPos.Y;

  MainMenu := 0;
  WinMenu := 0;
  if (ts.HideTitle=0) and (ts.PopupMenu=0) then
    InitMenu(MainMenu);
  Attr.Menu := MainMenu;
end;

procedure VTWindow.SetupWindow;
begin
  HVTWin := HWindow;
  {register this window to the window list}
  SerialNo := RegWin(HWindow,0);

{$ifdef TERATERM32}
  {set the small icon}
  PostMessage(HWindow,WM_SETICON,0,
    LPARAM(LoadImage(hInstance,PChar(IDI_VT)),
    IMAGE_ICON,16,16,0));
{$endif}

  {Reset Terminal}
  ResetTerminal;

  if (ts.PopupMenu>0) or (ts.HideTitle>0) then
    PostMessage(HWindow,WM_USER_CHANGEMENU,0,0);

  ChangeFont;

  ResetIME;

  {TWindow.SetupWindow;}

  BuffChangeWinSize(NumOfColumns,NumOfLines);

  ChangeTitle;

  {Enable drag-drop}
  DragAcceptFiles(HWindow,TRUE);

  if ts.HideWindow>0 then
  begin
    if strlen(TopicName)>0 then
    begin
      InitDDE;
      SendDDEReady;
    end;
    FirstPaint := FALSE;
    Startup;
    CmdShow := SW_HIDE;
    TWindow.SetupWindow;
    SetTimer(HWindow,100,1,nil);
    exit;
  end;
  ChangeCaret;
  if ts.Minimize>0 then
    CmdShow := SW_SHOWMINIMIZED;
  TWindow.SetupWindow;
end;

function VTWindow.GetClassName: PChar;
begin
  GetClassName := VTClassName;
end;

procedure VTWindow.GetWindowClass(var AWndClass: TWndClass);
begin
  TWindow.GetWindowClass(AWndClass);
  AWndClass.hbrBackground := 0;
  AWndClass.HIcon := LoadIcon(HInstance, PChar(IDI_VT));
  AWndClass.HCursor := LoadCursor(0, IDC_IBEAM);
  {enable WM_LBUTTONDBLCLK}
  AWndClass.style := AWndClass.style or CS_DBLCLKS;
end;

function VTWindow.Parse: integer;
begin
  if LButton or MButton or RButton then
    Parse := 0
  else
    Parse := VTParse;
end;

procedure VTWindow.ButtonUp(Paste: bool);
begin
  {disable autoscrolling}
  KillTimer(HWindow,IdScrollTimer);
  ReleaseCapture;

  LButton := FALSE;
  MButton := FALSE;
  RButton := FALSE;
  DblClk := FALSE;
  TplClk := FALSE;
  CaretOn;

  BuffEndSelect;
  if Paste then
    CBStartPaste(HWindow,FALSE,0,nil,0);
end;

procedure VTWindow.ButtonDown(p: TPoint; LMR: integer);
var
  PopupMenu, PopupBase: HMenu;
  i, numItems: integer;
  itemText: array[0..255] of char;
  submenu: HMenu;
  state: integer;
begin
  if (LMR=IdLeftButton) and ControlKey and
     (MainMenu=0) and (ts.MenuFlag and MF_POPUP = 0) then
  begin
    {TTPLUG BEGIN}
    InitMenu(PopupMenu);

    PopupBase := CreatePopupMenu;
    numItems := GetMenuItemCount(PopupMenu);

    for i := 0 to numItems-1 do
    begin
      submenu := GetSubMenu(PopupMenu, i);

      if submenu <> 0 then
        InitMenuPopup(submenu);

      if GetMenuString(PopupMenu, i, itemText,
          sizeof(itemText), MF_BYPOSITION) <> 0 then
      begin
        state := GetMenuState(PopupMenu, i, MF_BYPOSITION) and
          (MF_CHECKED or MF_DISABLED or MF_GRAYED or MF_HILITE or
           MF_MENUBARBREAK or MF_MENUBREAK or MF_SEPARATOR);
        if submenu<>0 then
          AppendMenu(PopupBase,Lo(state) or MF_POPUP,submenu,itemText)
        else
          AppendMenu(PopupBase,state,GetMenuItemID(popupMenu,i),itemText);
      end;
    end; {TTPLUG END}

    {InitMenuPopup(FileMenu);
    InitMenuPopup(EditMenu);
    InitMenuPopup(SetupMenu);
    InitMenuPopup(ControlMenu);
    if WinMenu<>0 then
      InitMenuPopup(WinMenu);
    PopupBase := CreatePopupMenu;
    AppendMenu(PopupBase, MF_STRING or MF_ENABLED or MF_POPUP,
               FileMenu, '&File');
    AppendMenu(PopupBase, MF_STRING or MF_ENABLED or MF_POPUP,
               EditMenu, '&Edit');
    AppendMenu(PopupBase, MF_STRING or MF_ENABLED or MF_POPUP,
               SetupMenu, '&Setup');
    AppendMenu(PopupBase, MF_STRING or MF_ENABLED or MF_POPUP,
               ControlMenu, 'C&ontrol');
    if WinMenu<>0 then
      AppendMenu(PopupBase, MF_STRING or MF_ENABLED or MF_POPUP,
                 WinMenu, '&Window');
    AppendMenu(PopupBase, MF_STRING or MF_ENABLED or MF_POPUP,
               GetSubMenu(PopupMenu,4), '&Help');}
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
    PopupMenu := 0;
    exit;
  end;

  if AfterDblClk and (LMR=IdLeftButton) and
    (abs(p.x-DblClkX)<=GetSystemMetrics(SM_CXDOUBLECLK)) and
    (abs(p.y-DblClkY)<=GetSystemMetrics(SM_CYDOUBLECLK)) then
  begin {triple click}
    KillTimer(HWindow, IdDblClkTimer);
    AfterDblClk := FALSE;
    BuffTplClk(p.y);
    LButton := TRUE;
    TplClk := TRUE;
    {for AutoScrolling}
    SetCapture(HWindow);
    SetTimer(HWindow, IdScrollTimer, 100, nil);
  end
  else begin
    if not (LButton or MButton or RButton) then
    begin
      BuffStartSelect(p.x,p.y,(LMR=IdLeftButton) and ShiftKey);
      TplClk := FALSE;
      {for AutoScrolling}
      SetCapture(HWindow);
      SetTimer(HWindow, IdScrollTimer, 100, nil);
    end;
    case LMR of
      IdRightButton: RButton := TRUE;
      IdMiddleButton: MButton := TRUE;
      IdLeftButton: LButton := TRUE;
    end;
  end;
end;

procedure VTWindow.InitMenu(var Menu: HMenu);
begin
  Menu := LoadMenu(HInstance, PChar(IDR_MENU));
  FileMenu := GetSubMenu(Menu,ID_FILE);
  TransMenu := GetSubMenu(FileMenu,ID_TRANSFER);
  EditMenu := GetSubMenu(Menu,ID_EDIT);
  SetupMenu := GetSubMenu(Menu,ID_SETUP);
  ControlMenu := GetSubMenu(Menu,ID_CONTROL);
  HelpMenu := GetSubMenu(Menu,ID_HELPMENU);
  if ts.MenuFlag and MF_SHOWWINMENU <> 0 then
  begin
    WinMenu := CreatePopupMenu;
    InsertMenu(Menu,ID_HELPMENU,
	       MF_STRING or MF_ENABLED or
	       MF_POPUP or MF_BYPOSITION,
	       WinMenu, '&Window');
  end;

  TTXModifyMenu(Menu); {TTPLUG}
end;

procedure VTWindow.InitMenuPopup(SubMenu: HMenu);
begin
  if SubMenu = FileMenu then
  begin
    if Connecting then
      EnableMenuItem(FileMenu,ID_FILE_NEWCONNECTION,MF_BYCOMMAND or MF_GRAYED)
    else
      EnableMenuItem(FileMenu,ID_FILE_NEWCONNECTION,MF_BYCOMMAND or MF_ENABLED);

    if LogVar<>nil then
      EnableMenuItem(FileMenu,ID_FILE_LOG,MF_BYCOMMAND or MF_GRAYED)
    else
      EnableMenuItem(FileMenu,ID_FILE_LOG,MF_BYCOMMAND or MF_ENABLED);

    if (not cv.Ready) or (SendVar<>nil) or (FileVar<>nil) or
       (cv.PortType=IdFile) then
    begin
      EnableMenuItem(FileMenu,ID_FILE_SENDFILE,MF_BYCOMMAND or MF_GRAYED);
      EnableMenuItem(FileMenu,ID_TRANSFER,MF_BYPOSITION or MF_GRAYED); {Transfer}
      EnableMenuItem(FileMenu,ID_FILE_CHANGEDIR,MF_BYCOMMAND or MF_GRAYED);
      EnableMenuItem(FileMenu,ID_FILE_DISCONNECT,MF_BYCOMMAND or MF_GRAYED);
    end
    else begin
      EnableMenuItem(FileMenu,ID_FILE_SENDFILE,MF_BYCOMMAND or MF_ENABLED);
      EnableMenuItem(FileMenu,ID_TRANSFER,MF_BYPOSITION or MF_ENABLED); {Transfer}
      EnableMenuItem(FileMenu,ID_FILE_CHANGEDIR,MF_BYCOMMAND or MF_ENABLED);
      EnableMenuItem(FileMenu,ID_FILE_DISCONNECT,MF_BYCOMMAND or MF_ENABLED);
    end
  end
  else if SubMenu = TransMenu then
  begin
    if (cv.PortType=IdSerial) and
       ((ts.DataBit=IdDataBit7) or (ts.Flow=IdFlowX)) then
    begin
      EnableMenuItem(TransMenu,1,MF_BYPOSITION or MF_GRAYED);  {XMODEM}
      EnableMenuItem(TransMenu,4,MF_BYPOSITION or MF_GRAYED);  {Quick-VAN}
    end
    else begin
      EnableMenuItem(TransMenu,1,MF_BYPOSITION or MF_ENABLED); {XMODEM}
      EnableMenuItem(TransMenu,4,MF_BYPOSITION or MF_ENABLED); {Quick-VAN}
    end;
    if (cv.PortType=IdSerial) and
       (ts.DataBit=IdDataBit7) then
    begin
      EnableMenuItem(TransMenu,2,MF_BYPOSITION or MF_GRAYED); {ZMODEM}
      EnableMenuItem(TransMenu,3,MF_BYPOSITION or MF_GRAYED); {B-Plus}
    end
    else begin
      EnableMenuItem(TransMenu,2,MF_BYPOSITION or MF_ENABLED); {ZMODEM}
      EnableMenuItem(TransMenu,3,MF_BYPOSITION or MF_ENABLED); {B-Plus}
    end;
  end
  else if SubMenu = EditMenu then
  begin
    if Selected then
    begin
      EnableMenuItem(EditMenu,ID_EDIT_COPY2,MF_BYCOMMAND or MF_ENABLED);
      EnableMenuItem(EditMenu,ID_EDIT_COPYTABLE,MF_BYCOMMAND or MF_ENABLED);
    end
    else begin
      EnableMenuItem(EditMenu,ID_EDIT_COPY2,MF_BYCOMMAND or MF_GRAYED);
      EnableMenuItem(EditMenu,ID_EDIT_COPYTABLE,MF_BYCOMMAND or MF_GRAYED);
    end;
    if cv.Ready and
       (SendVar=nil) and (FileVar=nil) and
       (cv.PortType<>IdFile) and
       (IsClipboardFormatAvailable(CF_TEXT) or
        IsClipboardFormatAvailable(CF_OEMTEXT)) then
    begin
      EnableMenuItem(EditMenu,ID_EDIT_PASTE2,MF_BYCOMMAND or MF_ENABLED);
      EnableMenuItem(EditMenu,ID_EDIT_PASTECR,MF_BYCOMMAND or MF_ENABLED);
    end
    else begin
      EnableMenuItem(EditMenu,ID_EDIT_PASTE2,MF_BYCOMMAND or MF_GRAYED);
      EnableMenuItem(EditMenu,ID_EDIT_PASTECR,MF_BYCOMMAND or MF_GRAYED);
    end;
  end
  else if SubMenu = SetupMenu then
    if cv.Ready and
       ((cv.PortType=IdTCPIP) or (cv.PortType=IdFile)) or
       (SendVar<>nil) or (FileVar<>nil) or Connecting then
      EnableMenuItem(SetupMenu,ID_SETUP_SERIALPORT,MF_BYCOMMAND or MF_GRAYED)
    else
      EnableMenuItem(SetupMenu,ID_SETUP_SERIALPORT,MF_BYCOMMAND or MF_ENABLED)

  else if SubMenu = ControlMenu then
  begin
    if cv.Ready and
       (SendVar=nil) and (FileVar=nil) then
    begin
      EnableMenuItem(ControlMenu,ID_CONTROL_SENDBREAK,MF_BYCOMMAND or MF_ENABLED);
      if cv.PortType=IdSerial then
        EnableMenuItem(ControlMenu,ID_CONTROL_RESETPORT,MF_BYCOMMAND or MF_ENABLED)
      else
        EnableMenuItem(ControlMenu,ID_CONTROL_RESETPORT,MF_BYCOMMAND or MF_GRAYED);
    end
    else begin
      EnableMenuItem(ControlMenu,ID_CONTROL_SENDBREAK,MF_BYCOMMAND or MF_GRAYED);
      EnableMenuItem(ControlMenu,ID_CONTROL_RESETPORT,MF_BYCOMMAND or MF_GRAYED);
    end;

    if cv.Ready and cv.TelFlag and (FileVar=nil) then
      EnableMenuItem(ControlMenu,ID_CONTROL_AREYOUTHERE,MF_BYCOMMAND or MF_ENABLED)
    else
      EnableMenuItem(ControlMenu,ID_CONTROL_AREYOUTHERE,MF_BYCOMMAND or MF_GRAYED);

    if HTEKWin=0 then EnableMenuItem(ControlMenu,ID_CONTROL_CLOSETEK,MF_BYCOMMAND or MF_GRAYED)
                 else EnableMenuItem(ControlMenu,ID_CONTROL_CLOSETEK,MF_BYCOMMAND or MF_ENABLED);

    if (ConvH<>0) or (FileVar<>nil) then
      EnableMenuItem(ControlMenu,ID_CONTROL_MACRO,MF_BYCOMMAND or MF_GRAYED)
    else
      EnableMenuItem(ControlMenu,ID_CONTROL_MACRO,MF_BYCOMMAND or MF_ENABLED);

  end
  else if SubMenu = WinMenu then
  begin
    SetWinMenu(WinMenu);
  end;

  TTXModifyPopupMenu(SubMenu); {TTPLUG}
end;

procedure VTWindow.ResetSetup;
begin
  ChangeFont;
  BuffChangeWinSize(WinWidth,WinHeight);
  ChangeCaret;

  if cv.Ready then
  begin
    ts.PortType := cv.PortType;
    if cv.PortType=IdSerial then
    begin
      {if serial port, change port parameters}
      ts.ComPort := cv.ComPort;
      CommResetSerial(@ts,@cv);
    end;
  end;

  {setup terminal}
  SetupTerm;

  {setup window}
  ChangeWin;

  {Language & IME}
  ResetIME;

  {change TEK window}
  if pTEKWin<>nil then
    PTEKWindow(pTEKWin)^.RestoreSetup;
end;

procedure VTWindow.RestoreSetup;
var
  TempDir: array[0..MAXPATHLEN-1] of char;
  TempName: array[0..MAXPATHLEN-1] of char;
begin
  if strlen(ts.SetupFName)=0 then exit;
  ExtractFileName(ts.SetupFName,TempName);
  ExtractDirName(ts.SetupFName,TempDir);
  if TempDir[0]=#0 then
    strcopy(TempDir,ts.HomeDir);
  FitFileName(TempName,'.INI');

  strcopy(ts.SetupFName,TempDir);
  AppendSlash(ts.SetupFName);
  strcat(ts.SetupFName,TempName);

  if LoadTTSET then
    ReadIniFile(ts.SetupFName,@ts);
  FreeTTSET;

  ChangeDefaultSet(@ts,nil);

  ResetSetup;
end;

{called by the [Setup] Terminal command}
procedure VTWindow.SetupTerm;
begin
  if ts.Language=IdJapanese then
    ResetCharSet;
  cv.CRSend := ts.CRSend;

  {for russian mode}
  cv.RussHost := ts.RussHost;
  cv.RussClient := ts.RussClient;

  if cv.Ready and cv.TelFlag and (ts.TelEcho>0) then
    TelChangeEcho;

  if (ts.TerminalWidth<>NumOfColumns) or
     (ts.TerminalHeight<>NumOfLines-StatusLine) then
  begin
    LockBuffer;
    HideStatusLine;
    ChangeTerminalSize(ts.TerminalWidth,
                       ts.TerminalHeight);
    UnlockBuffer;
  end
  else if (ts.TermIsWin>0) and
          ((ts.TerminalWidth<>WinWidth) or
           (ts.TerminalHeight<>WinHeight-StatusLine)) then
    BuffChangeWinSize(ts.TerminalWidth,ts.TerminalHeight+StatusLine);
end;

procedure VTWindow.Startup;
begin
  {auto log}
  if (ts.LogFN[0]<>#0) and NewFileVar(LogVar) then
  begin
    LogVar^.DirLen := 0;
    strcopy(LogVar^.FullName,ts.LogFN);
    LogStart;
  end;
  
  if (TopicName[0]=#0) and (ts.MacroFN[0]<>#0) then
  begin {start the macro specified in the command line or setup file}
	RunMacro(ts.MacroFN,TRUE);
	ts.MacroFN[0] := #0;
  end
  else begin {start connection}
    if TopicName[0]<>#0 then
      cv.NoMsg:=1; {suppress error messages}
    PostMessage(HWindow,WM_USER_COMMSTART,0,0);
  end;
end;

procedure VTWindow.OpenTEK;
begin
  ActiveWin := IdTEK;
  if HTEKWin=0 then
  begin
    pTEKWin := PTEKWindow(Application^.MakeWindow
      (New(PTEKWindow,Init)));
  end
  else begin
    ShowWindow(HTEKWin,SW_SHOWNORMAL);
    SetFocus(HTEKWin);
  end;
end;

procedure VTWindow.DefWndProc(var Msg: TMessage);
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

procedure VTWindow.WMCommand(var Msg: TMessage);
var
  wID: word;
  wNotifyCode: word;
begin
{$ifdef TEARTERM32}
  wID := LOWORD(Msg.wParam);
  wNotifyCode := HIWORD(Msg.wParam);
{$else}
  wID := Msg.wParam;
  wNotifyCode := HIWORD(Msg.lParam); 
{$endif}
  if wNotifyCode=1 then
  begin
    case wID of
      ID_ACC_SENDBREAK: begin
        CMControlSendBreak(Msg);
        exit;
      end;
      ID_ACC_PASTECR: begin
        CMEditPasteCR(Msg);
        exit;
      end;
      ID_ACC_AREYOUTHERE: begin
        CMControlAreYouThere(Msg);
        exit;
      end;
      ID_ACC_PASTE: begin
        CMEditPaste(Msg);
        exit;
      end;
    end;
    if ActiveWin=IdVT then
    begin
      case wID of
        ID_ACC_NEWCONNECTION: begin
	  CMFileNewConnection(Msg);
          exit;
        end;
	ID_ACC_COPY: begin
	  CMEditCopy(Msg);
	  exit;
        end;
	ID_ACC_PRINT: begin
	  CMFilePrint(Msg);
          exit;
        end;
	ID_ACC_EXIT: begin
	  CMFileExit(Msg);
	  exit;
        end;
      end;
    end
    else begin {transfer accelerator message to TEK win}
      case wID of
        ID_ACC_COPY: begin
	  PostMessage(HTEKWin,WM_COMMAND,ID_TEKEDIT_COPY,0);
	  exit;
        end;
	ID_ACC_PRINT: begin
	  PostMessage(HTEKWin,WM_COMMAND,ID_TEKFILE_PRINT,0);
	  exit;
        end;
	ID_ACC_EXIT: begin
	  PostMessage(HTEKWin,WM_COMMAND,ID_TEKFILE_EXIT,0);
          exit;
	end;
      end;
    end;
  end;

  if (wID>=ID_WINDOW_1) and
     (wID<ID_WINDOW_1+9) then
    SelectWin(wID-ID_WINDOW_1)
  else if not TTXProcessCommand(HVTWin,wID) then {TTPLUG}
  begin
    Msg.wParam := wID-CM_FIRST;
    TWindow.WMCommand(Msg);
  end;
end;

procedure VTWindow.WMActivate(var Msg: TMessage);
begin
  DispSetActive(LOWORD(Msg.wParam)<>WA_INACTIVE);
end;

procedure VTWindow.WMChar(var Msg: TMessage);
var
  i, Count: integer;
  Code: byte;
begin
  if not KeybEnabled or (TalkStatus<>IdTalkKeyb) then exit;

  if (ts.MetaKey>0) and AltKey then
  begin
    PostMessage(HVTWin,WM_SYSCHAR,Msg.wParam,Msg.lParam);
    exit;
  end;

  Code  := Msg.wParam and $ff;
  Count := Msg.lParam and $007f;

  if (ts.Language=IdRussian) and
     (Code>=128) then
    Code :=
      RussConv(ts.RussKeyb,ts.RussClient,Code);

  for i:=1 to Count do
  begin
    CommTextOut(@cv,@Code,1);
    if ts.LocalEcho>0 then
    CommTextEcho(@cv,@Code,1);
  end;
end;

procedure VTWindow.WMClose(var Msg: TMessage);
begin
  if (HTEKWin<>0) and not IsWindowEnabled(HTEKWin) then
  begin
    MessageBeep(0);
    exit;
  end;
  if cv.Ready and (cv.PortType=IdTCPIP) and
     (ts.PortFlag and PF_CONFIRMDISCONN <> 0) and
     not CloseTT and
     (MessageBox(HWindow,'Disconnect?','Tera Term',
      MB_OKCANCEL or MB_ICONEXCLAMATION or MB_DEFBUTTON2)=IDCANCEL) then
    exit;

  FileTransEnd(0);
  ProtoEnd;

  DestroyWindow(HWindow);
end;

procedure VTWindow.WMDestroy(var Msg: TMessage);
begin
  {remove this window from the window list}
  UnregWin(HWindow);

  EndKeyboard;

  {Disable drag-drop}
  DragAcceptFiles(HWindow,FALSE);

  EndDDE;

  if cv.TelFlag then EndTelnet;
  CommClose(@cv);

  OpenHelp(HWindow,HELP_QUIT,0);

  FreeIME;
  FreeTTSET;

  while FreeTTDLG do;

  while FreeTTFILE do;

  if HTEKWin<>0 then
    DestroyWindow(HTEKWin);

  EndDisp;

  FreeBuffer;

  TWindow.WMDestroy(Msg);
  TTXEnd; {TTPLUG}
end;

procedure VTWindow.WMDropFiles(var Msg: TMessage);
begin
{$ifdef TERATERM32}
  SetForegroundWindow(HWindow);
{$else}
  SetActiveWindow(HWindow);
{$endif}
  if cv.Ready and (SendVar=nil) and NewFileVar(SendVar) then
  begin
    if DragQueryFile(Msg.wParam,0,SendVar^.FullName,
         SizeOf(SendVar^.FullName))>0 then
    begin
      SendVar^.DirLen := 0;
      ts.TransBin := 0;
      FileSendStart
    end
    else
      FreeFileVar(SendVar);
  end;
  DragFinish(Msg.wParam);
end;

procedure VTWindow.WMGetMinMaxInfo(var Msg: TMessage);
begin
  PMinMaxInfo(Msg.lParam)^.ptMaxSize.X := 10000;
  PMinMaxInfo(Msg.lParam)^.ptMaxSize.Y := 10000;
  PMinMaxInfo(Msg.lParam)^.ptMaxTrackSize.X := 10000;
  PMinMaxInfo(Msg.lParam)^.ptMaxTrackSize.Y := 10000;
end;

procedure VTWindow.WMHScroll(var Msg: TMessage);
var
  nSBCode, nPos: word;
  Func: integer;
begin
{$ifdef TERATERM32}
  nSBCode := LOWORD(Msg.wParam);
  nPos := HIWORD(Msg.wParam);
{$else}
  nSBCode := Msg.wParam;
  nPos := LOWORD(Msg.lParam);
{$endif}   
  case nSBCode of
    SB_BOTTOM: Func := SCROLL_BOTTOM;
    SB_ENDSCROLL: exit;
    SB_LINEDOWN: Func := SCROLL_LINEDOWN;
    SB_LINEUP: Func := SCROLL_LINEUP;
    SB_PAGEDOWN: Func := SCROLL_PAGEDOWN;
    SB_PAGEUP: Func := SCROLL_PAGEUP;
    SB_THUMBPOSITION,
    SB_THUMBTRACK: Func := SCROLL_POS;
    SB_TOP: Func := SCROLL_TOP;
  else
    exit;
  end;
  DispHScroll(Func,nPos);
end;

procedure VTWindow.WMInitMenuPopup(var Msg: TMessage);
begin
  InitMenuPopup(Msg.wParam);
end;

procedure VTWindow.WMKeyDown(var Msg: TMessage);
var
  KeyState: array[0..255] of byte;
  M: TMSG;
begin
  if KeyDown(HWindow,Msg.wParam,Msg.lParam and $007f,
             HiWord(Msg.lParam) and $1ff) then exit;

  if (ts.MetaKey>0) and (Msg.lParam and $20000000 <> 0) then
  begin {for Ctrl+Alt+Key combination}
    GetKeyboardState(TKeyboardState(KeyState));
    KeyState[VK_MENU] := 0;
    SetKeyboardState(TKeyboardState(KeyState));
    M.hwnd := HVTWin;
    M.message := WM_KEYDOWN;
    M.wParam := Msg.wParam;
    M.lParam := Msg.lParam and $dfffffff;
    TranslateMessage(M);
  end;
end;

procedure VTWindow.WMKeyUp(var Msg: TMessage);
begin
  KeyUp(Msg.wParam);
end;

procedure VTWindow.WMKillFocus(var Msg: TMessage);
begin
  DispDestroyCaret;
  TWindow.DefWndProc(Msg);
end;

procedure VTWindow.WMLButtonDblClk(Var Msg: TMessage);
begin
  if LButton or MButton or RButton then exit;

  DblClkX := LOWORD(Msg.lParam);
  DblClkY := HIWORD(Msg.lParam);
  BuffDblClk(DblClkX, DblClkY);
  LButton := TRUE;
  DblClk := TRUE;
  AfterDblClk := TRUE;
  SetTimer(HWindow, IdDblClkTimer, GetDoubleClickTime, nil);

  {for AutoScrolling}
  SetCapture(HWindow);
  SetTimer(HWindow, IdScrollTimer, 100, nil);
end;

procedure VTWindow.WMLButtonDown(Var Msg: TMessage);
var
  p: TPoint;
begin
  p.x := LOWORD(Msg.lParam);
  p.y := HIWORD(Msg.lParam);
  ButtonDown(p,IdLeftButton);
end;

procedure VTWindow.WMLButtonUp(Var Msg: TMessage);
begin
  if not LButton then exit;
  ButtonUp(FALSE);
end;

procedure VTWindow.WMMButtonDown(Var Msg: TMessage);
var
  p: TPoint;
begin
  p.x := LOWORD(Msg.lParam);
  p.y := HIWORD(Msg.lParam);
  ButtonDown(p,IdMiddleButton);
end;

procedure VTWindow.WMMButtonUp(Var Msg: TMessage);
begin
  if not MButton then exit;
  ButtonUp(TRUE);
end;

procedure VTWindow.WMMouseActivate(var Msg: TMessage);
begin
  if (ts.SelOnActive=0) and
     (LOWORD(Msg.lParam)=HTCLIENT) then
     {disable mouse event for text selection}
     {when window is activated}
    Msg.Result := MA_ACTIVATEANDEAT
  else
    Msg.Result := MA_ACTIVATE;
end;

procedure VTWindow.WMMouseMove(Var Msg: TMessage);
var
  i: integer;
begin
  if not (LButton or MButton or RButton) then exit;
  if DblClk then
    i := 2
  else if TplClk then
    i := 3
  else
    i := 1;
  BuffChangeSelect(LOWORD(Msg.lParam),HIWORD(Msg.lParam),i);
end;

procedure VTWindow.WMMove(var Msg: TMessage);
begin
  DispSetWinPos;
end;

procedure VTWindow.WMNCLButtonDblClk(var Msg: TMessage);
begin
  if not MiniMized and (Msg.wParam = HTCAPTION) then
    DispRestoreWinSize
  else
    TWindow.DefWndProc(Msg);
end;

procedure VTWindow.WMNCRButtonDown(Var Msg: TMessage);
begin
  if (Msg.wParam=HTCAPTION) and
     (ts.HideTitle>0) and
     AltKey then
    WINPROCS.CloseWindow(HWindow); {iconize}
end;

procedure VTWindow.Paint(PaintDC: HDC; var PaintInfo:TPaintStruct);
var
  Xs, Ys, Xe, Ye: integer;
begin
  PaintWindow(PaintDC,PaintInfo.rcPaint,PaintInfo.fErase,
              Xs,Ys,Xe,Ye);
  LockBuffer;
  BuffUpdateRect(Xs,Ys,Xe,Ye);
  UnlockBuffer;
  DispEndPaint;

  if FirstPaint then
  begin
    if strlen(TopicName)>0 then
    begin
      InitDDE;
      SendDDEReady;
    end;
    FirstPaint := FALSE;
    Startup;
  end;
end;

procedure VTWindow.WMRButtonDown(Var Msg: TMessage);
var
  p: TPoint;
begin
  p.x := LOWORD(Msg.lParam);
  p.y := HIWORD(Msg.lParam);
  ButtonDown(p,IdRightButton);
end;

procedure VTWindow.WMRButtonUp(Var Msg: TMessage);
begin
  if not RButton then exit;
  ButtonUp(TRUE);
end;

procedure VTWindow.WMSetFocus(var Msg: TMessage);
begin
  ChangeCaret;
  TWindow.DefWndProc(Msg);
end;

procedure VTWindow.WMSize(Var Msg: TMessage);
var
  cx, cy, w, h: integer;
  R: TRect;
begin
  TWindow.WMSize(Msg);
  MiniMized := Msg.wParam = SIZE_MINIMIZED;

  if FirstPaint and MiniMized then
  begin
    if strlen(TopicName)>0 then
    begin
      InitDDE;
      SendDDEReady;
    end;
    FirstPaint := FALSE;
    Startup;
    exit;
  end;
  if (MiniMized) or DontChangeSize then exit; 

  cx := LOWORD(Msg.lParam);
  cy := HIWORD(Msg.lParam);
  GetWindowRect(HWindow,R);
  w := R.right-R.left;
  h := R.bottom-R.top;
  if AdjustSize then
    ResizeWindow(R.left,R.top,w,h,cx,cy)
  else begin
    w := cx div FontWidth;
    h := cy div FontHeight;
    HideStatusLine;
    BuffChangeWinSize(w,h);
  end; 
end;

procedure VTWindow.WMSysChar(var Msg: TMessage);
var
  Code: byte;
  Count, i: integer;
begin
  if ts.MetaKey>0 then
  begin
    if not KeybEnabled or (TalkStatus<>IdTalkKeyb) then exit;

    Code  := Msg.wParam and $ff;
    Count := Msg.lParam and $007f;

    for i:=1 to Count do
    begin
      CommTextOut(@cv,#$1B,1);
      CommTextOut(@cv,@Code,1);
      if ts.LocalEcho>0 then
      begin
        CommTextEcho(@cv,#$1B,1);
        CommTextEcho(@cv,@Code,1);
      end;
    end;
    exit;
  end;

  DefWndProc(Msg);
end;

{$ifndef TERATERM32}
procedure VTWindow.WMSysColorChange(var Msg: TMessage);
begin
  SysColorChange;
end;
{$endif}

procedure VTWindow.WMSysCommand(var Msg: TMessage);
begin
  if Msg.wParam=ID_SHOWMENUBAR then
  begin
    ts.PopupMenu := 0;
    SwitchMenu;
  end
  else if (Msg.wParam and $fff0=SC_CLOSE) and (cv.PortType=IdTCPIP) and
          cv.Open and not cv.Ready and (cv.ComPort>0) then
    {now getting host address (see CommOpen in commlib.pas}
    PostMessage(HWindow,WM_SYSCOMMAND,Msg.wParam,Msg.lParam)
  else
    DefWndProc(Msg);
end;

procedure VTWindow.WMSysKeyDown(var Msg: TMessage);
begin
  if (Msg.wParam=VK_F10) or
     (ts.MetaKey>0) and
     ((MainMenu=0) or (Msg.wParam<>VK_MENU)) and
     (Msg.lParam and $20000000 <> 0) then
    KeyDown(HWindow,Msg.wParam,Msg.lParam and $007f,
             HiWord(Msg.lParam) and $1ff)
    {WMKeyDown(Msg)}
  else
    TWindow.DefWndProc(Msg);
end;

procedure VTWindow.WMSysKeyUp(var Msg: TMessage);
begin
  if Msg.wParam=VK_F10 then
    WMKeyUp(Msg)
  else
    TWindow.DefWndProc(Msg);
end;

procedure VTWindow.WMTimer(var Msg: TMessage);
var
  Point: TPoint;
  PortType: word;
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
    exit;
  end
  else if Msg.wParam=IdScrollTimer then
  begin
    GetCursorPos(Point);
    ScreenToClient(HWindow,Point);
    DispAutoScroll(Point);
    if (Point.x < 0) or (Point.x >= ScreenWidth) or
       (Point.y < 0) or (Point.y >= ScreenHeight) then
      PostMessage(HWindow,WM_MOUSEMOVE,MK_LBUTTON,MAKELONG(Point.x,Point.y));
    exit;
  end;

  KillTimer(HWindow, Msg.wParam);

  case Msg.wParam of
    IdDelayTimer: cv.CanSend := TRUE;
    IdProtoTimer: ProtoDlgTimeOut;
    IdDblClkTimer: AfterDblClk := FALSE;
    IdComEndTimer: begin
        if not CommCanClose(@cv) then
        begin {wait if received data remains}
          SetTimer(HWindow,IdComEndTimer,1,nil);
          exit;
        end;
        cv.Ready := FALSE;
        if cv.TelFlag then EndTelnet;
        PortType := cv.PortType;
        CommClose(@cv);
        SetDdeComReady(0);
        if (PortType=IdTCPIP) and
           (ts.PortFlag and PF_BEEPONCONNECT<>0) then
          MessageBeep(0);
        if (PortType=IdTCPIP) and
           (ts.AutoWinClose>0) and
           IsWindowEnabled(HWindow) and
           ((HTEKWin=0) or IsWindowEnabled(HTEKWin)) then
          CloseWindow
        else
          ChangeTitle;
      end;
    IdPrnStartTimer: PrnFileStart;
    IdPrnProcTimer: PrnFileDirectProc;
  end;
end;

procedure VTWindow.WMVScroll(var Msg: TMessage);
var
  nSBCode, nPos: word;
  Func: integer;
begin
{$ifdef TERATERM32}
  nSBCode := LOWORD(Msg.wParam);
  nPos := HIWORD(Msg.wParam);
{$else}
  nSBCode := Msg.wParam;
  nPos := LOWORD(Msg.lParam);
{$endif}   
  case nSBCode of
    SB_BOTTOM: Func := SCROLL_BOTTOM;
    SB_ENDSCROLL: exit;
    SB_LINEDOWN: Func := SCROLL_LINEDOWN;
    SB_LINEUP: Func := SCROLL_LINEUP;
    SB_PAGEDOWN: Func := SCROLL_PAGEDOWN;
    SB_PAGEUP: Func := SCROLL_PAGEUP;
    SB_THUMBPOSITION,
    SB_THUMBTRACK: Func := SCROLL_POS;
    SB_TOP: Func := SCROLL_TOP;
  else
    exit;
  end;
  DispVScroll(Func,nPos);
end;

{$ifdef TERATERM32}
procedure VTWindow.WMIMEComposition(var Msg: TMessage);
var
  hstr: HGlobal;
  pstr: PChar;
  Len: integer;
begin
  if CanUseIME then
    hstr := GetConvString(Msg.lParam)
  else
    hstr := 0;

  if hstr<>0 then
  begin
    pstr := GlobalLock(hstr);
    if pstr<>nil then
    begin
      {add this string into text buffer of application}
      Len := strlen(pstr);
      if Len=1 then
      begin
        case pstr[0] of
          #$20: if ControlKey then pstr[0] := #0; {Ctrl-Space}
          #$5C: {Ctrl=\ support for NEC-PC98}
            if ControlKey then pstr[0] := #$1C;
        end;
      end;
      if ts.LocalEcho>0 then
        CommTextEcho(@cv,pstr,Len);
      CommTextOut(cv,pstr,Len);
      GlobalUnlock(hstr);
    end;
    GlobalFree(hstr);
    Msg.Result := 0;
    exit;
  end;
  TWindow.DefWndProc(Msg);
end;
{$endif}

procedure VTWindow.WMAccelCommand(var Msg: TMessage);
begin
  case Msg.wParam of
    IdHold:
      if TalkStatus=IdTalkKeyb then
      begin
        Hold := not Hold;
        CommLock(@ts,@cv,Hold);
      end;
    IdPrint: CMFilePrint(Msg);
    IdBreak: CMControlSendBreak(Msg);
    IdCmdEditCopy:
      CMEditCopy(Msg);
    IdCmdEditPaste:
      CMEditPaste(Msg);
    IdCmdEditPasteCR:
      CMEditPasteCR(Msg);
    IdCmdEditCLS:
      CMEditClearScreen(Msg);
    IdCmdEditCLB:
      CMEditClearBuffer(Msg);
    IdCmdCtrlOpenTEK:
      CMControlOpenTEK(Msg);
    IdCmdCtrlCloseTEK:
      CMControlCloseTEK(Msg);
    IdCmdLineUp: begin
{$ifdef TERATERM32}
      Msg.wParam := MAKELONG(SB_LINEUP,0);
{$else}
      Msg.wParam := SB_LINEUP;
      Msg.lParam := 0;
{$endif} 
      WMVScroll(Msg);
    end;
    IdCmdLineDown: begin
{$ifdef TERATERM32}
      Msg.wParam := MAKELONG(SB_LINEDOWN,0);
{$else}
      Msg.wParam := SB_LINEDOWN;
      Msg.lParam := 0;
{$endif} 
      WMVScroll(Msg);
    end;
    IdCmdPageUp: begin
{$ifdef TERATERM32}
      Msg.wParam := MAKELONG(SB_PAGEUP,0);
{$else}
      Msg.wParam := SB_PAGEUP;
      Msg.lParam := 0;
{$endif} 
      WMVScroll(Msg);
    end;
    IdCmdPageDown: begin
{$ifdef TERATERM32}
      Msg.wParam := MAKELONG(SB_PAGEDOWN,0);
{$else}
      Msg.wParam := SB_PAGEDOWN;
      Msg.lParam := 0;
{$endif} 
      WMVScroll(Msg);
    end;
    IdCmdBuffTop: begin
{$ifdef TERATERM32}
      Msg.wParam := MAKELONG(SB_TOP,0);
{$else}
      Msg.wParam := SB_TOP;
      Msg.lParam := 0;
{$endif}
    end; 
    IdCmdBuffBottom: begin
{$ifdef TERATERM32}
      Msg.wParam := MAKELONG(SB_BOTTOM,0);
{$else}
      Msg.wParam := SB_BOTTOM;
      Msg.lParam := 0;
{$endif} 
    end;
    IdCmdNextWin:
      SelectNextWin(HWindow,1);
    IdCmdPrevWin:
      SelectNextWin(HWindow,-1);
    IdCmdLocalEcho: begin
      if ts.LocalEcho=0 then
        ts.LocalEcho := 1
      else
        ts.LocalEcho := 0;
      if cv.Ready and cv.TelFlag and
         (ts.TelEcho>0) then
        TelChangeEcho;
    end;
    IdCmdDisconnect: {called by TTMACRO}
      CMFileDisconnect(Msg);
    IdCmdLoadKeyMap: {called by TTMACRO}
      SetKeyMap;
    IdCmdRestoreSetup: {called by TTMACRO}
      RestoreSetup;
  end;
end;

procedure VTWindow.WMChangeMenu(var Msg: TMessage);
var
  SysMenu: HMenu;
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

    AdjustSize := TRUE;
    SetMenu(HWindow, MainMenu);
    DrawMenuBar(HWindow);
  end;

  B1 := ts.MenuFlag and MF_SHOWWINMENU <> 0;
  B2 := WinMenu<>0;
  if (MainMenu<>0) and (B1<>B2) then
  begin
    if WinMenu=0 then
    begin
      WinMenu := CreatePopupMenu;
      InsertMenu(MainMenu,ID_HELPMENU,
        MF_STRING or MF_ENABLED or
        MF_POPUP or MF_BYPOSITION,
        WinMenu, '&Window');
    end
    else begin
      RemoveMenu(MainMenu,ID_HELPMENU,MF_BYPOSITION);
      DestroyMenu(WinMenu);
      WinMenu := 0;
    end;
    DrawMenuBar(HWindow);
  end;

  GetSystemMenu(HWindow,TRUE);
  if not S and (ts.MenuFlag and MF_NOSHOWMENU = 0) then
  begin
    SysMenu := GetSystemMenu(HWindow,FALSE);
    AppendMenu(SysMenu, MF_SEPARATOR, 0, nil);
    AppendMenu(SysMenu, MF_STRING, ID_SHOWMENUBAR, 'Show menu &bar');
  end;
end;

procedure VTWindow.WMChangeTBar(var Msg: TMessage);
var
  TBar: bool;
  Style: longint;
  SysMenu: HMenu;
begin
  Style := GetWindowLong(HWindow, GWL_STYLE);
  TBar := (Style and WS_SYSMENU<>0);
  if TBar = (ts.HideTitle=0) then exit;
  if ts.HideTitle>0 then
    Style := Style and
      not (WS_SYSMENU or WS_CAPTION or WS_MINIMIZEBOX)
      or WS_BORDER or WS_POPUP
  else
    Style := Style and not WS_POPUP or
      WS_SYSMENU or WS_CAPTION or WS_MINIMIZEBOX;
  AdjustSize := TRUE;
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

procedure VTWindow.WMCommNotify(var Msg: TMessage);
begin
  case LOWORD(Msg.lParam) of
    FD_READ: {TCP/IP}
      CommProcRRQ(@cv);
{$ifndef TERATERM32}
    CN_EVENT: {Win 3.1 serial}
      CommProcRRQ(@cv);
{$endif}
    FD_CLOSE: begin
      Connecting := FALSE;
      TCPIPClosed := TRUE;
      {disable transmition}
      cv.OutBuffCount := 0;
      SetTimer(HWindow,IdComEndTimer,1,nil);
    end;
  end;
end;

procedure VTWindow.WMCommOpen(var Msg: TMessage);
begin
  CommStart(@cv,Msg.lParam);
  Connecting := FALSE;
  ChangeTitle;
  if not cv.Ready then exit;

  if (ts.PortType=IdTCPIP) and
     (ts.PortFlag and PF_BEEPONCONNECT <> 0) then
    MessageBeep(0);

  if cv.PortType=IdTCPIP then
  begin
    InitTelnet;

    if cv.TelFlag and
      (ts.TCPPort=ts.TelPort) then
    begin
      {Start telnet option negotiation from this side
       if telnet flag is set and port# = default telnet port# (23) }
      TelEnableMyOpt(TermType);

      TelEnableHisOpt(SGA);

      TelEnableMyOpt(SGA);

      if ts.TelEcho>0 then
        TelChangeEcho
      else
        TelEnableHisOpt(ECHO);

      TelEnableMyOpt(NAWS);
      if ts.TelBin>0 then
      begin
        TelEnableMyOpt(BINARY);
        TelEnableHisOpt(BINARY);
      end;
    end
    else begin
      if ts.TCPCRSend>0 then
      begin
        ts.CRSend := ts.TCPCRSend;
        cv.CRSend := ts.TCPCRSend;
      end;
      if ts.TCPLocalEcho>0 then
        ts.LocalEcho := ts.TCPLocalEcho;
    end;
  end;

  if DDELog or FileLog then
  begin
    if not CreateLogBuf then
    begin
      if DDELog then EndDDE;
      if FileLog then FileTransEnd(OpLog);
    end;
  end;

  if BinLog then
  begin
    if not CreateBinBuf then
      FileTransEnd(OpLog);
  end;

  SetDdeComReady(1);
end;

procedure VTWindow.WMCommStart(var Msg: TMessage);
begin
  if (ts.PortType<>IdSerial) and (ts.HostName[0]=#0) then
    CMFileNewConnection(Msg)
  else begin
    Connecting := TRUE;
    ChangeTitle;
    CommOpen(HWindow,@ts,@cv);
  end;
end;

procedure VTWindow.WMDdeEnd(var Msg: TMessage);
begin
  EndDde;
  if CloseTT then
    CloseWindow;
end;

procedure VTWindow.WMDlgHelp(var Msg: TMessage);
begin
  OpenHelp(HWindow,HELP_CONTEXT,HelpId);
end;

procedure VTWindow.WMFileTransEnd(var Msg: TMessage);
begin
  FileTransEnd(Msg.wParam);
end;

procedure VTWindow.WMGetSerialNo(var Msg: TMessage);
begin
  Msg.Result := longint(SerialNo);
end;

procedure VTWindow.WMKeyCode(var Msg: TMessage);
begin
  KeyCodeSend(Msg.wParam,word(Msg.lParam));
end;

procedure VTWindow.WMProtoEnd(var Msg: TMessage);
begin
  ProtoDlgCancel;
end;

procedure VTWindow.CMFileNewConnection(var Msg: TMessage);
var
  Command, Command2: array[0..MAXPATHLEN-1] of char;
  GetHNRec: TGetHNRec; {record for dialog box}
  i: integer;
begin
  if Connecting then exit;

  HelpId := HlpFileNewConnection;
  GetHNRec.SetupFN := ts.SetupFName;
  GetHNRec.PortType := ts.PortType;
  GetHNRec.Telnet := ts.Telnet;
  GetHNRec.TelPort := ts.TelPort;
  GetHNRec.TCPPort := ts.TCPPort;
  GetHNRec.ComPort := ts.ComPort;
  GetHNRec.MaxComPort := ts.MaxComPort;

{$ifdef TERATERM32}
  strcopy(Command,'ttermpro ');
{$else}
  strcopy(Command,'teraterm ');
{$endif}
  GetHNRec.HostName := @Command[9];

  if not LoadTTDLG then exit;
  if GetHostName(HWindow,@GetHNRec) then
  begin
    if (GetHNRec.PortType=IdTCPIP) and
       (ts.HistoryList>0) and
       LoadTTSET then
    begin
      AddHostToList(ts.SetupFName,GetHNRec.HostName);
      FreeTTSET;
    end;

    if (not cv.Ready) then
    begin
      ts.PortType := GetHNRec.PortType;
      ts.Telnet := GetHNRec.Telnet;
      ts.TCPPort := GetHNRec.TCPPort;
      ts.ComPort := GetHNRec.ComPort;

      if (GetHNRec.PortType=IdTCPIP) and
         LoadTTSET then
      begin
        ParseParam(Command, @ts, nil);
        FreeTTSET;
      end;
      SetKeyMap;
      if ts.MacroFN[0]<>#0 then
      begin
        RunMacro(ts.MacroFN,TRUE);
        ts.MacroFN[0] := #0;
      end
      else begin
        Connecting := TRUE;
        ChangeTitle;
        CommOpen(HWindow,@ts,@cv);
      end;
      ResetSetup;
    end
    else begin
      if GetHNRec.PortType=IdSerial then
      begin
        Command[8] := #0;
        StrCat(Command,' /C=');
        uint2str(GetHNRec.ComPort,@Command[strlen(Command)],2);
      end
      else begin
        StrCopy(Command2, @Command[9]);
        Command[9] := #0;
        if GetHNRec.Telnet=0 then
          StrCat(Command,' /T=0')
        else
          StrCat(Command,' /T=1');
        if GetHNRec.TCPPort<65535 then
        begin
          strcat(Command,' /P=');
          uint2str(GetHNRec.TCPPort,@Command[strlen(Command)],5);
        end;
        StrCat(Command,' ');
        StrLCat(Command, Command2, sizeof(Command)-1);
      end;
      TTXSetCommandLine(Command, sizeof(Command), @GetHNRec); {TTPLUG}
      WinExec(Command,SW_SHOW);
    end;
  end
  else begin {canceled}
    if not cv.Ready then
      SetDdeComReady(0);
  end;
  FreeTTDLG;
end;

procedure VTWindow.CMFileLog(var Msg: TMessage);
begin
  HelpId := HlpFileLog;
  LogStart;
end;

procedure VTWindow.CMFileSend(var Msg: TMessage);
begin
  HelpId := HlpFileSend;
  FileSendStart;
end;

procedure VTWindow.CMFileKermitRcv(var Msg: TMessage);
begin
  KermitStart(IdKmtReceive);
end;

procedure VTWindow.CMFileKermitGet(var Msg: TMessage);
begin
  HelpId := HlpFileKmtGet;
  KermitStart(IdKmtGet);
end;

procedure VTWindow.CMFileKermitSend(var Msg: TMessage);
begin
  HelpId := HlpFileKmtSend;
  KermitStart(IdKmtSend);
end;

procedure VTWindow.CMFileKermitFinish(var Msg: TMessage);
begin
  KermitStart(IdKmtFinish);
end;

procedure VTWindow.CMFileXRcv(var Msg: TMessage);
begin
  HelpId := HlpFileXmodemRecv;
  XMODEMStart(IdXReceive);
end;

procedure VTWindow.CMFileXSend(var Msg: TMessage);
begin
  HelpId := HlpFileXmodemSend;
  XMODEMStart(IdXSend);
end;

procedure VTWindow.CMFileZRcv(var Msg: TMessage);
begin
  ZMODEMStart(IdZReceive);
end;

procedure VTWindow.CMFileZSend(var Msg: TMessage);
begin
  HelpId := HlpFileZmodemSend;
  ZMODEMStart(IdZSend);
end;

procedure VTWindow.CMFileBPRcv(var Msg: TMessage);
begin
  BPStart(IdBPReceive);
end;

procedure VTWindow.CMFileBPSend(var Msg: TMessage);
begin
  HelpId := HlpFileBPlusSend;
  BPStart(IdBPSend);
end;

procedure VTWindow.CMFileQVRcv(var Msg: TMessage);
begin
  QVStart(IdQVReceive);
end;

procedure VTWindow.CMFileQVSend(var Msg: TMessage);
begin
  HelpId := HlpFileQVSend;
  QVStart(IdQVSend);
end;

procedure VTWindow.CMFileChangeDir(var Msg: TMessage);
begin
  HelpId := HlpFileChangeDir;
  if not LoadTTDLG then exit;
  ChangeDirectory(HWindow,ts.FileDir);
  FreeTTDLG;
end;

procedure VTWindow.CMFilePrint(var Msg: TMessage);
begin
  HelpId := HlpFilePrint;
  BuffPrint(FALSE);
end;

procedure VTWindow.CMFileDisconnect(var Msg: TMessage);
begin
  if not cv.Ready then exit;
  if (cv.PortType=IdTCPIP) and
     (ts.PortFlag and PF_CONFIRMDISCONN <> 0) and
     (MessageBox(HWindow,'Disconnect?','Tera Term',
      MB_OKCANCEL or MB_ICONEXCLAMATION or MB_DEFBUTTON2)=IDCANCEL) then
    exit;
  PostMessage(HWindow, WM_USER_COMMNOTIFY, 0, FD_CLOSE);
end;

procedure VTWindow.CMFileExit(var Msg: TMessage);
begin
  CloseWindow;
end;

procedure VTWindow.CMEditCopy(var Msg: TMessage);
begin
  {copy selected text to clipboard}
  BuffCBCopy(FALSE);
end;

procedure VTWindow.CMEditCopyTable(var Msg: TMessage);
begin
  {copy selected text to clipboard in Excel format}
  BuffCBCopy(TRUE);
end;

procedure VTWindow.CMEditPaste(var Msg: TMessage);
begin
  CBStartPaste(HWindow,FALSE,0,nil,0);
end;

procedure VTWindow.CMEditPasteCR(var Msg: TMessage);
begin
  CBStartPaste(HWindow,TRUE,0,nil,0);
end;

procedure VTWindow.CMEditClearScreen(var Msg: TMessage);
begin
  LockBuffer;
  BuffClearScreen;
  if (StatusLine>0) and (CursorY=NumOfLines-1) then
    MoveCursor(0,CursorY)
  else
    MoveCursor(0,0);
  BuffUpdateScroll;
  BuffSetCaretWidth;
  UnlockBuffer;
end;

procedure VTWindow.CMEditClearBuffer(var Msg: TMessage);
begin
  LockBuffer;
  ClearBuffer;
  UnlockBuffer;
end;

procedure VTWindow.CMSetupTerminal(var Msg: TMessage);
var
  Ok: bool;
begin
  if ts.Language=IdRussian then
    HelpId := HlpSetupTerminalRuss
  else
    HelpId := HlpSetupTerminal;
  if not LoadTTDLG then exit;
  Ok := SetupTerminal(HWindow,@ts);
  FreeTTDLG;
  if Ok then SetupTerm;
end;

procedure VTWindow.CMSetupWindow(var Msg: TMessage);
var
  Ok: bool;
begin
  HelpId := HlpSetupWindow;
  ts.VTFlag := 1;
  ts.SampleFont := VTFont[0];

  if not LoadTTDLG then exit;
  Ok := SetupWin(HWindow, @ts);
  FreeTTDLG;

  if Ok then ChangeWin;
end;

procedure VTWindow.CMSetupFont(var Msg: TMessage);
var
  Ok: bool;
begin
  if ts.Language=IdRussian then
    HelpId := HlpSetupFontRuss
  else
    HelpId := HlpSetupFont;

  DispSetupFontDlg;
end;

procedure VTWindow.CMSetupKeyboard(var Msg: TMessage);
var
  Ok: bool;
begin
  if ts.Language=IdRussian then
    HelpId := HlpSetupKeyboardRuss
  else
    HelpId := HlpSetupKeyboard;
  if not LoadTTDLG then exit;
  Ok := SetupKeyboard(HWindow,@ts);
  FreeTTDLG;

  if Ok and 
     (ts.Language=IdJapanese) then
    ResetIME;
end;

procedure VTWindow.CMSetupSerialPort(var Msg: TMessage);
var
  Ok: bool;
begin
  HelpId := HlpSetupSerialPort;
  if not LoadTTDLG then exit;
  Ok := SetupSerialPort(HWindow, @ts);
  FreeTTDLG;

  if Ok then
  begin
    if cv.Open then
    begin
      if ts.ComPort <> cv.ComPort then
      begin
        CommClose(@cv);
        CommOpen(HWindow,@ts,@cv);
      end
      else
        CommResetSerial(@ts,@cv);
    end
    else
      CommOpen(HWindow,@ts,@cv);
  end;
end;

procedure VTWindow.CMSetupTCPIP(var Msg: TMessage);
begin
  HelpId := HlpSetupTCPIP;
  if not LoadTTDLG then exit;
  SetupTCPIP(HWindow, @ts);
  FreeTTDLG;
end;

procedure VTWindow.CMSetupGeneral(var Msg: TMessage);
begin
  HelpId := HlpSetupGeneral;
  if not LoadTTDLG then exit;
  if SetupGeneral(HWindow,@ts) then
  begin
    ResetCharSet;
    ResetIME;
  end;
  FreeTTDLG;
end;

procedure VTWindow.CMSetupSave(var Msg: TMessage);
var
  Ok: bool;
  TmpSetupFN: array[0..MAXPATHLEN-1] of char;
begin
  StrCopy(TmpSetupFN, ts.SetupFName);
  if not LoadTTFILE then exit;
  HelpId := HlpSetupSave;
  Ok := GetSetupFname(HWindow,GSF_SAVE,@ts);
  FreeTTFILE;
  if not Ok then exit;

  if LoadTTSET then
  begin
    {write current setup values to file}
    WriteIniFile(ts.SetupFName,@ts);
    {copy host list}
    CopyHostList(TmpSetupFN,ts.SetupFName);
    FreeTTSET;
  end;

  ChangeDefaultSet(@ts,nil);
end;

procedure VTWindow.CMSetupRestore(var Msg: TMessage);
var
  Ok: bool;
begin
  HelpId := HlpSetupRestore;
  if not LoadTTFILE then exit;
  Ok := GetSetupFname(HWindow,GSF_RESTORE,@ts);
  FreeTTFILE;
  if Ok then RestoreSetup;
end;

procedure VTWindow.CMSetupLoadKeyMap(var Msg: TMessage);
var
  Ok: bool;
begin
  HelpId := HlpSetupLoadKeyMap;
  if not LoadTTFILE then exit;
  Ok := GetSetupFname(HWindow,GSF_LOADKEY,@ts);
  FreeTTFILE;
  if not Ok then exit;

  {load key map}
  SetKeyMap;
end;

procedure VTWindow.CMControlResetTerminal(var Msg: TMessage);
begin
  LockBuffer;
  HideStatusLine;
  DispScrollHomePos;
  ResetTerminal;
  UnlockBuffer;

  LButton := FALSE;
  MButton := FALSE;
  RButton := FALSE;

  Hold := FALSE;
  CommLock(@ts,@cv,FALSE);

  KeybEnabled := TRUE;
end;

procedure VTWindow.CMControlAreYouThere(var Msg: TMessage);
begin
  if cv.Ready and (cv.PortType=IdTCPIP) then
    TelSendAYT;
end;

procedure VTWindow.CMControlSendBreak(var Msg: TMessage);
begin
  if cv.Ready then
    case cv.PortType of
      IdTCPIP: TelSendBreak;
      IdSerial: CommSendBreak(@cv);
    end;
end;

procedure VTWindow.CMControlResetPort(var Msg: TMessage);
begin
  CommResetSerial(@ts,@cv);
end;

procedure VTWindow.CMControlOpenTEK(var Msg: TMessage);
begin
  OpenTEK;
end;

procedure VTWindow.CMControlCloseTEK(var Msg: TMessage);
begin
  if (HTEKWin=0) or
     not IsWindowEnabled(HTEKWin) then
    MessageBeep(0)
  else
    PTEKWindow(pTEKWin)^.CloseWindow;
end;

procedure VTWindow.CMControlMacro(var Msg: TMessage);
begin
  RunMacro(nil,FALSE);
end;

procedure VTWindow.CMWindowWindow(var Msg: TMessage);
var
  Close: bool;
begin
  HelpId := HlpWindowWindow;
  if not LoadTTDLG then exit;
  WindowWindow(HWindow,@Close);
  FreeTTDLG;
  if Close then CloseWindow;
end;

procedure VTWindow.CMHelpIndex(var Msg: TMessage);
begin
  OpenHelp(HWindow,HELP_INDEX,0);
end;

procedure VTWindow.CMHelpUsing(var Msg: TMessage);
begin
  WinHelp(HWindow, '', HELP_HELPONHELP, 0);
end;

procedure VTWindow.CMHelpAbout(var Msg: TMessage);
begin
  if not LoadTTDLG then exit;
  AboutDialog(HWindow);
  FreeTTDLG;
end;

end.
