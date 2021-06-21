{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, TTCMN interface}
unit TTCommon;

interface

uses WinTypes, TTTypes;

function StartTeraTerm(ts: PTTSet): bool;
procedure ChangeDefaultSet(ts: PTTSet; km: PKeyMap);
procedure GetDefaultSet(ts: PTTSet);
{procedure LoadDefaultSet(SetupFName: PChar);}
function GetKeyCode(KeyMap: PKeyMap; Scan: word): word;
procedure GetKeyStr(HWin: HWnd; KeyMap: PKeyMap; KeyCode: word; AppliKeyMode, AppliCursorMode: BOOL;
                    KeyStr: PChar; Len: PInteger; KeyType: PWORD);

procedure SetCOMFlag(Com: word);
function GetCOMFlag: word;

function RegWin(HWinVT, HWinTEK: HWnd): integer;
procedure UnregWin(HWin: HWnd);
procedure SetWinMenu(menu: HMenu);
procedure SetWinList(HWin, HDlg: HWnd; IList: integer);
procedure SelectWin(WinId: integer);
procedure SelectNextWin(HWin: HWnd; Next: integer);
function GetNthWin(n: integer): HWnd;

function CommReadRawByte(cv: PComVar; b: Pbyte): integer;
function CommRead1Byte(cv: PComVar; b: Pbyte): integer;
procedure CommInsert1Byte(cv: PComVar; b:byte);
function CommRawOut(cv: PComVar; B: PChar; C: integer): integer;
function CommBinaryOut(cv: PComVar; B: PChar; C: integer): integer;
function CommTextOut(cv: PComVar; B: PChar; C: integer): integer;
function CommBinaryEcho(cv: PComVar; B: PChar; C: integer): integer;
function CommTextEcho(cv: PComVar; B: PChar; C: integer): integer;

function SJIS2JIS(KCode: word): word;
function SJIS2EUC(KCode: word): word;
function JIS2SJIS(KCode: word): word;
function RussConv(cin, cout: integer; b: byte): byte;
procedure RussConvStr(cin, cout: integer; Str: PCHAR; count: integer);

implementation

function StartTeraTerm;     external 'TTCMN' index 1;
procedure ChangeDefaultSet; external 'TTCMN' index 2;
procedure GetDefaultSet;    external 'TTCMN' index 3;
{procedure LoadDefaultSet;   external 'TTCMN' index 3;}
function  GetKeyCode;       external 'TTCMN' index 4;
procedure GetKeyStr;        external 'TTCMN' index 5;

procedure SetCOMFlag;       external 'TTCMN' index 6;
function GetCOMFlag;        external 'TTCMN' index 7;

function RegWin;            external 'TTCMN' index 10;
procedure UnregWin;         external 'TTCMN' index 11;
procedure SetWinMenu;       external 'TTCMN' index 12;
procedure SetWinList;       external 'TTCMN' index 13;
procedure SelectWin;        external 'TTCMN' index 14;
procedure SelectNextWin;    external 'TTCMN' index 15;
function GetNthWin;         external 'TTCMN' index 16;

function CommReadRawByte;   external 'TTCMN' index 20;
function CommRead1Byte;     external 'TTCMN' index 21;
procedure CommInsert1Byte;  external 'TTCMN' index 22;
function CommRawOut;        external 'TTCMN' index 23;
function CommBinaryOut;     external 'TTCMN' index 24;
function CommTextOut;       external 'TTCMN' index 25;
function CommBinaryEcho;    external 'TTCMN' index 26;
function CommTextEcho;      external 'TTCMN' index 27;

function SJIS2JIS;          external 'TTCMN' index 30;
function SJIS2EUC;          external 'TTCMN' index 31;
function JIS2SJIS;          external 'TTCMN' index 32;
function RussConv;          external 'TTCMN' index 33;
procedure RussConvStr;      external 'TTCMN' index 34;

end.