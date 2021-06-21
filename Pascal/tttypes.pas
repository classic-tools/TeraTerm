{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{Constants and types for Tera Term}
unit TTTypes;

interface
{$i teraterm.inc}

{$IFDEF Delphi}
uses Messages, WinTypes, Types;
{$ELSE}
uses WinTypes, Win31, Types;
{$ENDIF}

{$i teraterm.inc}

const
  IdBreakTimer = 1;
  IdDelayTimer = 2;
  IdProtoTimer = 3;
  IdDblClkTimer = 4;
  IdScrollTimer = 5;
  IdComEndTimer = 6;
  IdCaretTimer = 7;
  IdPrnStartTimer = 8;
  IdPrnProcTimer = 9;

const
  {Window Id}
  IdVT = 1;
  IdTEK = 2;

const
  {Talker mode}
  IdTalkKeyb = 0;
  IdTalkCB = 1;
  IdTalkFile = 2;
  IdTalkQuiet = 3;

const
  {Character sets}
  IdASCII = 0;
  IdKatakana = 1;
  IdKanji = 2;
  IdSpecial = 3;

const
  {Character attribute bit masks}
  AttrDefault = $00;
  AttrDefault2 = $00;
  AttrBold = $01;
  AttrUnder = $02;
  AttrSpecial = $04;
  AttrFontMask = $07;
  AttrBlink = $08;
  AttrReverse = $10;
  AttrKanji = $80;
  {Color attribute bit masks}
  Attr2Fore = $08;
  Attr2ForeMask = $07;
  Attr2Back = $80;
  Attr2BackMask  = $70;
  SftAttrBack = 4;

const
  {Color codes}
  IdBack    = 0;
  IdRed     = 1;
  IdGreen   = 2;
  IdYellow  = 3;
  IdBlue    = 4;
  IdMagenta = 5;
  IdCyan    = 6;
  IdFore    = 7;

const
  {Kermit function id}
  IdKmtReceive = 1;
  IdKmtGet = 2;
  IdKmtSend = 3;
  IdKmtFinish = 4;

  {XMODEM function id}
  IdXReceive = 1;
  IdXSend = 2;

  {ZMODEM function id}
  IdZReceive = 1;
  IdZSend = 2;
  IdZAuto = 3;

  {B-Plus function id}
  IdBPReceive = 1;
  IdBPSend = 2;
  IdBPAuto = 3;

  {Quick-VAN function id}
  IdQVReceive = 1;
  IdQVSend = 2;

const
  HostNameMaxLength=80;

const
  {internal WM_USER messages}
  WM_USER_ACCELCOMMAND = WM_USER + 1;
  WM_USER_CHANGEMENU = WM_USER + 2;
  WM_USER_CLOSEIME = WM_USER + 3;
{$ifdef TERATERM32}
  WM_USER_COMMNOTIFY = WM_USER + 4;
{$else}
  WM_USER_COMMNOTIFY = WM_COMMNOTIFY;
{$endif}
  WM_USER_COMMOPEN = WM_USER + 5;
  WM_USER_COMMSTART = WM_USER + 6;
  WM_USER_DLGHELP2 = WM_USER + 7;
  WM_USER_GETHOST = WM_USER + 8;
  WM_USER_FTCANCEL = WM_USER + 9;
  WM_USER_PROTOCANCEL = WM_USER + 10;
  WM_USER_CHANGETBAR = WM_USER + 11;
  WM_USER_KEYCODE = WM_USER + 12;
  WM_USER_GETSERIALNO = WM_USER + 13;

  WM_USER_DDEREADY = WM_USER + 21;
  WM_USER_DDECMNDEND = WM_USER + 22;
  WM_USER_DDECOMREADY = WM_USER + 23;
  WM_USER_DDEEND = WM_USER + 24;

const
  {port type ID}
  IdTCPIP  = 1;
  IdSerial = 2;
  IdFile   = 3;
const
  {XMODEM option}
  XoptCheck = 1;
  XoptCRC   = 2;
  Xopt1K    = 3;
const
  {Language}
  IdEnglish = 1;
  IdJapanese = 2;
  IdRussian = 3;

const
{ log flags (used in ts.LogFlag) }
  LOG_TEL = 1;
  LOG_KMT = 2;
  LOG_X   = 4;
  LOG_Z   = 8;
  LOG_BP  = 16;
  LOG_QV  = 32;

const
{ file transfer flags {used in ts.FTFlag}
  FT_ZESCCTL  = 1;
  FT_ZAUTO    = 2;
  FT_BPESCCTL = 4;
  FT_BPAUTO   = 8;
  FT_RENAME   = 16;

const
{ menu flags (used in ts.MenuFlag) }
  MF_NOSHOWMENU = 1;
  MF_NOPOPUP = 2;
  MF_NOLANGUAGE = 4;
  MF_SHOWWINMENU = 8;

{ Terminal flags (used in ts.TermFlag) }
  TF_FIXEDJIS	= 1;
  TF_AUTOINVOKE	= 2;
  TF_CTRLINKANJI = 8;
  TF_ALLOWWRONGSEQUENCE = 16;
  TF_ACCEPT8BITCTRL = 32;
  TF_ENABLESLINE= 64;
  TF_BACKWRAP = 128;

const
{ ANSI color flags (used in ts.ColorFlag) }
  CF_FULLCOLOR = 1;
  CF_USETEXTCOLOR = 2;

const
{ port flags (used in ts.PortFlag) }
  PF_CONFIRMDISCONN = 1;
  PF_BEEPONCONNECT = 2;

type
{Setup record for VT window}
  PTTSet = ^TTTSet;
  TTTSet = record
{-------- VTSet --------}
    {Tera Term home directory}
    HomeDir: array [0..MAXPATHLEN-1] of char;

    {Setup file name}
    SetupFName: array [0..MAXPATHLEN-1] of char;
    KeyCnfFN: array [0..MAXPATHLEN-1] of char;
    LogFN: array [0..MAXPATHLEN-1] of char;
    MacroFN: array [0..MAXPATHLEN-1] of char;
    HostName: array [0..79] of char;

    VTPos: TPoint;
    VTFont: array[0..LF_FACESIZE-1] of char;
    VTFontSize: TPoint;
    VTFontCharSet: integer;
    FontDW, FontDH, FontDX, FontDY: integer;
    PrnFont: array[0..LF_FACESIZE-1] of char;
    PrnFontSize: TPoint;
    PrnFontCharSet: integer;
    VTPPI, TEKPPI: TPoint;
    PrnMargin: array[0..3] of integer;
    PrnDev: array[0..79] of char;
    PassThruDelay: word;
    PrnConvFF: word;
    EnableBold: word;
    RussFont: word;
    ScrollThreshold: integer;
    Debug: word;
    LogFlag: word;
    FTFlag: word;
    TransBin, Append: word;
    XmodemOpt, XmodemBin: word;
    ZmodemDataLen, ZmodemWinSize: integer;
    QVWinSize: integer;
    FileDir: array[0..MAXPATHLEN-1] of char;
    Language: word;
    DelimList: array[0..51] of char;
    DelimDBCS: word;
    Minimize: word;
    HideWindow: word;
    MenuFlag: word;
    SelOnActive: word;
    AutoTextCopy: word;
{-------- TEKSet --------}
    TEKPos: TPoint;
    TEKFont: array[0..lf_FaceSize-1] of char;
    TEKFontSize: TPoint;
    TEKFontCharSet: integer;
    GINMouseCode: integer;
{-------- TermSet --------}
    TerminalWidth: integer;
    TerminalHeight: integer;
    TermIsWin: word;
    AutoWinResize: word;
    CRSend: word;
    CRReceive: word;
    LocalEcho: word;
    Answerback: array[0..31] of char;
    AnswerbackLen: integer;
    KanjiCode: word;
    KanjiCodeSend: word;
    JIS7Katakana: word;
    JIS7KatakanaSend: word;
    KanjiIn: word;
    KanjiOut: word;
    RussHost: word;
    RussClient: word;
    RussPrint: word;
    AutoWinSwitch: word;
    TerminalID: word;
    TermFlag: word;
{-------- WinSet --------}
    VTFlag: word;
    SampleFont: HFont;
    TmpColor: array[0..2, 0..5] of word;
    {Tera Term window setup variables}
    Title: array[0..49] of char;
    TitleFormat: word;
    CursorShape: word;
    NonblinkingCursor: word;
    EnableScrollBuff: word;
    ScrollBuffSize: longint;
    ScrollBuffMax: longint;
    HideTitle: word;
    PopupMenu: word;
    ColorFlag: word;
    TEKColorEmu: word;
    VTColor: array[0..1] of TColorRef;
    TEKColor: array[0..1] of TColorRef;
    VTBoldColor: array[0..1] of TColorRef;
    VTBlinkColor: array[0..1] of TColorRef;
    Beep: word;
{-------- KeybSet --------}
    BSKey: word;
    DelKey: word;
    UseIME: word;
    IMEInline: word;
    MetaKey: word;
    RussKeyb: word;
{-------- PortSet --------}
    PortType: word;
    {TCP/IP}
    TCPPort: word;
    Telnet: word;
    TelPort: word;
    TelBin: word;
    TelEcho: word;
    TermType: array[0..39] of char;
    AutoWinClose: word;
    PortFlag: word;
    TCPCRSend: word;
    TCPLocalEcho: word;
    HistoryList: word;
    {Serial}
    ComPort: word;
    Baud: word;
    Parity: word;
    DataBit: word;
    StopBit: word;
    Flow: word;
    DelayPerChar: word;
    DelayPerLine: word;
    MaxComPort: word;
  end;

const
  {New Line modes}
  IdCR = 1;
  IdCRLF = 2;
  {Terminal ID}
  IdVT100 = 1;
  IdVT100J = 2;
  IdVT101 = 3;
  IdVT102 = 4;
  IdVT102J = 5;
  IdVT220J = 6;
  IdVT282 = 7;
  IdVT320 = 8;
  IdVT382 = 9;
  {Kanji Code ID}
  IdSJIS = 1;
  IdEUC = 2;
  IdJIS = 3;

  {Russian code sets}
  IdWindows = 1;
  IdKOI8 = 2;
  Id866 = 3;
  IdISO = 4;

  {KanjiIn modes}
  IdKanjiInA = 1;
  IdKanjiInB = 2;
  {KanjiOut modes}
  IdKanjiOutB = 1;
  IdKanjiOutJ = 2;
  IdKanjiOutH = 3;

const
  TermWidthMax = 300;
  TermHeightMax = 200;

const
  {Cursor shapes}
  IdBlkCur = 1;
  IdVCur = 2;
  IdHCur = 3;

const
  IdBS = 1;
  IdDEL = 2;

const
  {Serial port ID}
  IdCOM1 = 1;
  IdCOM2 = 2;
  IdCOM3 = 3;
  IdCOM4 = 4;
  {Baud rate ID}
  IdBaud110 = 1;
  IdBaud300 = 2;
  IdBaud600 = 3;
  IdBaud1200 = 4;
  IdBaud2400 = 5;
  IdBaud4800 = 6;
  IdBaud9600 = 7;
  IdBaud14400 = 8;
  IdBaud19200 = 9;
  IdBaud38400 = 10;
  IdBaud57600 = 11;
  IdBaud115200 = 12;

  {Parity ID}
  IdParityEven = 1;
  IdParityOdd = 2;
  IdParityNone = 3;
  {Data bit ID}
  IdDataBit7 = 1;
  IdDataBit8 = 2;
  {Stop bit ID}
  IdStopBit1 = 1;
  IdStopBit2 = 2;
  {Flow control ID}
  IdFlowX = 1;
  IdFlowHard = 2;
  IdFlowNone = 3;


type
{GetHostName dialog record}
  PGetHNRec = ^TGetHNRec;
  TGetHNRec = record
    SetupFN: PChar; {setup file name}
    PortType: word; {TCPIP/Serial}
    HostName: PChar; {host name}
    Telnet: word; {non-zero: enable telnet}
    TelPort: word; {default TCP port # for telnet}
    TCPPort: word; {TCP port #}
    COMPort: word; {serial port #}
    MaxComPort: word; {max serial port #}
  end;

{Tera Term internal key codes}
const
  IdUp     =  1;
  IdDown   =  2;
  IdRight  =  3;
  IdLeft   =  4;
  Id0      =  5;
  Id1      =  6;
  Id2      =  7;
  Id3      =  8;
  Id4      =  9;
  Id5      = 10;
  Id6      = 11;
  Id7      = 12;
  Id8      = 13;
  Id9      = 14;
  IdMinus  = 15;
  IdComma  = 16;
  IdPeriod = 17;
  IdEnter  = 18;
  IdPF1    = 19;
  IdPF2    = 20;
  IdPF3    = 21;
  IdPF4    = 22;
  IdFind   = 23;
  IdInsert = 24;
  IdRemove = 25;
  IdSelect = 26;
  IdPrev   = 27;
  IdNext   = 28;
  IdHold   = 29;
  IdPrint  = 30;
  IdBreak  = 31;
  IdF6     = 32;
  IdF7     = 33;
  IdF8     = 34;
  IdF9     = 35;
  IdF10    = 36;
  IdF11    = 37;
  IdF12    = 38;
  IdF13    = 39;
  IdF14    = 40;
  IdHelp   = 41;
  IdDo     = 42;
  IdF17    = 43;
  IdF18    = 44;
  IdF19    = 45;
  IdF20    = 46;
  IdUDK6   = 47;
  IdUDK7   = 48;
  IdUDK8   = 49;
  IdUDK9   = 50;
  IdUDK10  = 51;
  IdUDK11  = 52;
  IdUDK12  = 53;
  IdUDK13  = 54;
  IdUDK14  = 55;
  IdUDK15  = 56;
  IdUDK16  = 57;
  IdUDK17  = 58;
  IdUDK18  = 59;
  IdUDK19  = 60;
  IdUDK20  = 61;
  IdXF1    = 62;
  IdXF2    = 63;
  IdXF3    = 64;
  IdXF4    = 65;
  IdXF5    = 66;
  IdCmdEditCopy = 67;
  IdCmdEditPaste = 68;
  IdCmdEditPasteCR = 69;
  IdCmdEditCLS = 70;
  IdCmdEditCLB = 71;
  IdCmdCtrlOpenTEK = 72;
  IdCmdCtrlCloseTEK = 73;
  IdCmdLineUp = 74;
  IdCmdLineDown = 75;
  IdCmdPageUp = 76;
  IdCmdPageDown = 77;
  IdCmdBuffTop = 78;
  IdCmdBuffBottom = 79;
  IdCmdNextWin = 80;
  IdCmdPrevWin = 81;
  IdCmdLocalEcho = 82;
  IdUser1 = 83;
  NumOfUserKey = 99;
  IdKeyMax = IdUser1+NumOfUserKey-1;

  {key code for macro commands}
  IdCmdDisconnect = 1000;
  IdCmdLoadKeyMap = 1001;
  IdCmdRestoreSetup = 1002;

  KeyStrMax = 1023;

{ (user) key type IDs}
  IdBinary = 0; {transmit text without any modification}
  IdText = 1; {transmit text with new-line & DBCS conversions}
  IdMacro = 2; {activate macro}
  IdCommand = 3; {post a WM_COMMAND message}
type
  PKeyMap = ^TKeyMap;
  TKeyMap = record
    Map: array[0..IdKeyMax-1] of word;
    {user key str position/length in buffer}
    UserKeyPtr, UserKeyLen: array[0..NumOfUserKey-1] of integer;
    UserKeyStr: array[0..KeyStrMax] of byte;
    {user key type}
    UserKeyType: array[0..NumOfUserKey-1] of byte;
  end;

{Control Characters}

const
  NUL = $00;
  SOH = $01;
  STX = $02;
  ETX = $03;
  EOT = $04;
  ENQ = $05;
  ACK = $06;
  BEL = $07;
  BS  = $08;
  HT  = $09;
  LF  = $0A;
  VT  = $0B;
  FF  = $0C;
  CR  = $0D;
  SO  = $0E;
  SI  = $0F;
  DLE = $10;
  DC1 = $11;
    XON = $11;
  DC2 = $12;
  DC3 = $13;
    XOFF = $13;
  DC4 = $14;
  NAK = $15;
  SYN = $16;
  ETB = $17;
  CAN = $18;
  EM  = $19;
  SUB = $1A;
  ESC = $1B;
  FS  = $1C;
  GS  = $1D;
  RS  = $1E;
  US  = $1F;

  SP  = $20;

  DEL = $7F;

  IND = $84;
  NEL = $85;
  SSA = $86;
  ESA = $87;
  HTS = $88;
  HTJ = $89;
  VTS = $8A;
  PLD = $8B;
  PLU = $8C;
  RI  = $8D;
  SS2 = $8E;
  SS3 = $8F;
  DCS = $90;
  PU1 = $91;
  PU2 = $92;
  STS = $93;
  CCH = $94;
  MW  = $95;
  SPA = $96;
  EPA = $97;
  SOS = $98;


  CSI = $9B;
  ST  = $9C;
  OSC = $9D;
  PM  = $9E;
  APC = $9F;


const
  InBuffSize = 1024;
  OutBuffSize = 1024;
type
  PComVar = ^TComVar;
  TComVar = record
    InBuff: array[0..InBuffSize-1] of byte;
    InBuffCount,InPtr: integer;
    OutBuff: array[0..OutBuffSize-1] of byte;
    OutBuffCount,OutPtr: integer;

    HWin: HWnd;
    Ready, Open: BOOL;
    PortType: word;
    ComPort: word;
    s: integer; {SOCKET;}
    RetryCount: word;
{$ifdef TERATERM32}
    ComID: THandle;
{$else}
    ComID: integer;
{$endif}
    CanSend, RRQ: BOOL;

    SendKanjiFlag: BOOL;
    EchoKanjiFlag: BOOL;
    SendCode: integer;
    EchoCode: integer;
    SendKanjiFirst: byte;
    EchoKanjiFirst: byte;

    {from VTSet}
    Language: word;
    {from TermSet}
    CRSend: word;
    KanjiCodeEcho: word;
    JIS7KatakanaEcho: word;
    KanjiCodeSend: word;
    JIS7KatakanaSend: word;
    KanjiIN: word;
    KanjiOut: word;
    RussHost: word;
    RussClient: word;
    {from PortSet}
    DelayPerChar: word;
    DelayPerLine: word;
    TelBinRecv, TelBinSend: BOOL;

    DelayFlag: BOOL;
    TelFlag, TelMode: BOOL;
    IACFlag, TelCRFlag: BOOL;
    TelCRSend, TelCRSendEcho: BOOL;
    TelAutoDetect: BOOL; {TTPLUG}

    {Text log}
    HLogBuf: THandle;
    LogBuf: PCHAR;
    LogPtr, LStart, LCount: integer;
    {Binary log & DDE}
    HBinBuf: THandle;
    BinBuf: PCHAR;
    BinPtr, BStart, BCount, DStart, DCount: integer;
    BinSkip: integer;
    FilePause: WORD;
    ProtoFlag: BOOL;
    {message flag}
    NoMsg: WORD;
  end;

{ VT window menu ID's }
const
  ID_FILE = 0;
  ID_EDIT = 1;
  ID_SETUP = 2;
  ID_CONTROL = 3;
  ID_HELPMENU = 4;
  ID_WINDOW_1 = 50801;
  ID_WINDOW_WINDOW = 50810;

  ID_TRANSFER = 4;
  ID_SHOWMENUBAR = 995;


implementation

end.
