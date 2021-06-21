{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTMACRO.EXE, TTL parser}
unit TTMParse;

interface
{$I teraterm.inc}

{$ifdef Delphi}
uses WinTypes, WinProcs, SysUtils, TTMDlg;
{$else}
uses WinTypes, WinProcs, Strings, TTMDlg;
{$endif}

const
  IdTTLRun  = 1;
  IdTTLWait = 2;
  IdTTLWaitLn = 3;
  IdTTLWaitNL = 4;
  IdTTLWait2 = 5;
  IdTTLInitDDE = 6;
  IdTTLPause = 7;
  IdTTLWaitCmndEnd = 8;
  IdTTLWaitCmndResult = 9;
  IdTTLSleep = 10;
  IdTTLEnd  = 11;

const
  ErrCloseParent = 1;
  ErrCantCall = 2;
  ErrCantConnect = 3;
  ErrCantOpen = 4;
  ErrDivByZero = 5;
  ErrInvalidCtl = 6;
  ErrLabelAlreadyDef = 7;
  ErrLabelReq = 8;
  ErrLinkFirst = 9;
  ErrStackOver = 10;
  ErrSyntax = 11;
  ErrTooManyLabels = 12;
  ErrTooManyVar = 13;
  ErrTypeMismatch = 14;
  ErrVarNotInit = 15;

  TypUnknown = 0;
  TypInteger = 1;
  TypLogical = 2;
  TypString = 3;
  TypLabel = 4;

  RsvBeep       = 1;
  RsvBPlusRecv  = 2;
  RsvBPlusSend  = 3;
  RsvCall       = 4;
  RsvChangeDir  = 5;
  RsvClearScreen = 6;
  RsvCloseSBox  = 7;
  RsvCloseTT    = 8;
  RsvCode2Str   = 9;
  RsvConnect    = 10;
  RsvDelPassword = 11;
  RsvDisconnect = 12;
  RsvElse       = 13;
  RsvElseIf     = 14;
  RsvEnableKeyb = 15;
  RsvEnd        = 16;
  RsvEndIf      = 17;
  RsvEndWhile   = 18;
  RsvExec       = 19;
  RsvExecCmnd   = 20;
  RsvExit       = 21;
  RsvFileClose  = 22;
  RsvFileConcat = 23;
  RsvFileCopy   = 24;
  RsvFileCreate = 25;
  RsvFileDelete = 26;
  RsvFileMarkPtr = 27;
  RsvFileOpen   = 28;
  RsvFileReadln = 29;
  RsvFileRename = 30;
  RsvFileSearch = 31;
  RsvFileSeek   = 32;
  RsvFileSeekBack = 33;
  RsvFileStrSeek = 34;
  RsvFileStrSeek2 = 35;
  RsvFileWrite  = 36;
  RsvFileWriteLn = 37;
  RsvFindClose  = 38;
  RsvFindFirst  = 39;
  RsvFindNext   = 40;
  RsvFlushRecv  = 41;
  RsvFor        = 42;
  RsvGetDate    = 43;
  RsvGetDir     = 44;
  RsvGetEnv     = 45;
  RsvGetPassword = 46;
  RsvGetTime    = 47;
  RsvGetTitle   = 48;
  RsvGoto       = 49;
  RsvIf         = 50;
  RsvInclude    = 51;
  RsvInputBox   = 52;
  RsvInt2Str    = 53;
  RsvKmtFinish  = 54;
  RsvKmtGet     = 55;
  RsvKmtRecv    = 56;
  RsvKmtSend    = 57;
  RsvLoadKeyMap = 58;
  RsvLogClose   = 59;
  RsvLogOpen    = 60;
  RsvLogPause   = 61;
  RsvLogStart   = 62;
  RsvLogWrite   = 63;
  RsvMakePath   = 64;
  RsvMessageBox = 65;
  RsvNext       = 66;
  RsvPasswordBox = 67;
  RsvPause      = 68;
  RsvQuickVANRecv = 69;
  RsvQuickVANSend = 70;
  RsvRecvLn     = 71;
  RsvRestoreSetup = 72;
  RsvReturn     = 73;
  RsvSend       = 74;
  RsvSendBreak  = 75;
  RsvSendFile   = 76;
  RsvSendKCode  = 77;
  RsvSendLn     = 78;
  RsvSetDate    = 79;
  RsvSetDir     = 80;
  RsvSetDlgPos  = 81;
  RsvSetEcho    = 82;
  RsvSetExitCode = 83;
  RsvSetSync    = 84;
  RsvSetTime    = 85;
  RsvSetTitle   = 86;
  RsvShow       = 87;
  RsvShowTT     = 88;
  RsvStatusBox  = 89;
  RsvStr2Code   = 90;
  RsvStr2Int    = 91;
  RsvStrCompare = 92;
  RsvStrConcat  = 93;
  RsvStrCopy    = 94;
  RsvStrLen     = 95;
  RsvStrScan    = 96;
  RsvThen       = 97;
  RsvTestLink   = 98;
  RsvUnlink     = 99;
  RsvWait       = 100;
  RsvWaitEvent  = 101;
  RsvWaitLn     = 102;
  RsvWaitRecv   = 103;
  RsvWhile      = 104;
  RsvXmodemRecv = 105;
  RsvXmodemSend = 106;
  RsvYesNoBox   = 107;
  RsvZmodemRecv = 108;
  RsvZmodemSend = 109;

  RsvOperator   = 150;
  RsvNot        = 151;
  RsvAnd        = 152;
  RsvOr         = 153;
  RsvXor        = 154;
  RsvMul        = 155;
  RsvPlus       = 156;
  RsvMinus      = 157;
  RsvDiv        = 158;
  RsvMod        = 159;
  RsvLT         = 160;
  RsvEQ         = 161;
  RsvGT         = 162;
  RsvLE         = 163;
  RsvNE         = 164;
  RsvGE         = 165;

type
{integer type for buffer pointer}
{$IFDEF TERATERM32}
  BINT = DWORD;
{$ELSE}
  BINT = WORD;
{$ENDIF}

const
  MaxNameLen = 32;
  MaxStrLen = 256;
type
  PName = ^TName;
  TName = array[0..MaxNameLen-1] of char;
  PStrVal = ^TStrVal;
  TStrVal = array[0..MaxStrLen-1] of char;

var
  TTLStatus: word;

  LineBuff: TStrVal;
  LinePtr: word;
  LineLen: word;

function InitVar: BOOL;
procedure EndVar;
procedure DispErr(Err: word);
procedure LockVar;
procedure UnlockVar;
function GetFirstChar: byte;
function GetIdentifier(Name: PChar): BOOL;
function GetReservedWord(var WordId: word): BOOL;
function GetLabelName(Name: PChar): BOOL;
function GetString(Str: PChar; var Err: word): BOOL;
function CheckVar(Name: PChar; var VarType, VarId: word): BOOL;
function NewIntVar(Name: PChar; InitVal: integer): BOOL;
function NewStrVar(Name: PChar; InitVal: PChar): BOOL;
function NewLabVar(Name: PChar; InitVal: BINT; ILevel: word): BOOL;
procedure DelLabVar(ILevel: word);
procedure CopyLabel(ILabel: word; var Ptr: BINT; var Level: word);
function GetExpression(var ValType: word; var Val: integer; var Err: word): BOOL;
procedure GetIntVal(var Val: integer; var Err: word);
procedure SetIntVal(VarId: word; Val: integer);
function CopyIntVal(VarId: word): integer;
procedure GetIntVar(var VarId, Err: word);
procedure GetStrVal(Str: PChar; var Err: word);
procedure GetStrVar(var VarId, Err: word);
procedure SetStrVal(VarId: word; Str: PChar);
function StrVarPtr(VarId: word): PChar;

implementation

const
  MaxNumOfIntVar = 128;
  MaxNumOfStrVar = 128;
  MaxNumOfLabVar = 256;

const
  IntVarIdOff = 0;
  StrVarIdOff = IntVarIdOff + MaxNumOfIntVar;
  LabVarIdOff = StrVarIdOff + MaxNumOfStrVar;
  MaxNumOfName = MaxNumOfIntVar + MaxNumOfStrVar + MaxNumOfLabVar;
  NameBuffLen = MaxNumOfName*MaxNameLen;
  StrBuffLen = MaxNumOfStrVar*MaxStrLen;

type
  PNameBuff = ^TNameBuff;
  TNameBuff = array[0..NameBuffLen-1] of char;
  PStrBuff = ^TStrBuff;
  TStrBuff = array[0..StrBuffLen-1] of char;

var
  IntVal:  array[0..MaxNumOfIntVar-1] of integer;
  LabVal:  array[0..MaxNumOfLabVar-1] of BINT;
  LabLevel: array[0..MaxNumOfLabVar-1] of byte;

var
  HNameBuff: THandle;
  NameBuff: PNameBuff;
  HStrBuff: THandle;
  StrBuff: PStrBuff;
  IntVarCount, StrVarCount, LabVarCount: word;


function InitVar: BOOL;
begin
  InitVar := FALSE;
  HNameBuff := GlobalAlloc(GMEM_MOVEABLE or GMEM_ZEROINIT,NameBuffLen);
  if HNameBuff=0 then exit;
  NameBuff := nil;

  HStrBuff := GlobalAlloc(GMEM_MOVEABLE or GMEM_ZEROINIT,StrBuffLen);
  if HStrBuff=0 then exit;
  StrBuff := nil;

  IntVarCount := 0;
  LabVarCount := 0;
  StrVarCount := 0;

  InitVar := TRUE;
end;

procedure EndVar;
begin
  UnlockVar;
  GlobalFree(HNameBuff);
  GlobalFree(HStrBuff);
end;

procedure DispErr(Err: word);
var
  Msg: array[0..40] of char;
  i: integer;
begin
  case Err of
    ErrCloseParent: StrCopy(Msg,'")" expected.');
    ErrCantCall: StrCopy(Msg,'Can''t call sub.');
    ErrCantConnect: StrCopy(Msg,'Can''t link macro.');
    ErrCantOpen: StrCopy(Msg,'Can''t open file.');
    ErrDivByZero: StrCopy(Msg,'Divide by zero.');
    ErrInvalidCtl: StrCopy(Msg,'Invalid control.');
    ErrLabelAlreadyDef: StrCopy(Msg,'Label already defined.');
    ErrLabelReq: StrCopy(Msg,'Label requiered.');
    ErrLinkFirst: StrCopy(Msg,'Link macro first.');
    ErrStackOver: StrCopy(Msg,'Stack overflow.');
    ErrSyntax: StrCopy(Msg,'Syntax error.');
    ErrTooManyLabels: StrCopy(Msg,'Too many labels.');
    ErrTooManyVar: StrCopy(Msg,'Too many variables.');
    ErrTypeMismatch: StrCopy(Msg,'Type mismatch.');
    ErrVarNotInit: StrCopy(Msg,'Variable not initialized.');
  end;

  i := OpenErrDlg(Msg,LineBuff);
  if i=IDOK then TTLStatus := IdTTLEnd;
end;

procedure LockVar;
begin
  if NameBuff=nil then
    NameBuff := GlobalLock(HNameBuff);
  if NameBuff=nil then
    PostQuitMessage(0);

  if StrBuff=nil then
    StrBuff := GlobalLock(HStrBuff);
  if StrBuff=nil then
    PostQuitMessage(0);
end;

procedure UnlockVar;
begin
  if NameBuff<>nil then
    GlobalUnlock(HNameBuff);
  NameBuff := nil;

  if StrBuff<>nil then
    GlobalUnlock(HStrBuff);
  StrBuff := nil;
end;

function CheckReservedWord(Str: PChar; var WordId: word): BOOL;
begin
  WordId := 0;

  if StrIComp(Str,'beep')=0 then WordId := RsvBeep
  else if StrIComp(Str,'bplusrecv')=0 then WordId := RsvBPlusRecv
  else if StrIComp(Str,'bplussend')=0 then WordId := RsvBPlusSend
  else if StrIComp(Str,'call')=0 then WordId := RsvCall
  else if StrIComp(Str,'changedir')=0 then WordId := RsvChangeDir
  else if StrIComp(Str,'clearscreen')=0 then WordId := RsvClearScreen
  else if StrIComp(Str,'closesbox')=0 then WordId := RsvCloseSBox
  else if StrIComp(Str,'closett')=0 then WordId := RsvCloseTT
  else if StrIComp(Str,'code2str')=0 then WordId := RsvCode2Str
  else if StrIComp(Str,'connect')=0 then WordId := RsvConnect
  else if StrIComp(Str,'delpassword')=0 then WordId := RsvDelpassword
  else if StrIComp(Str,'disconnect')=0 then WordId := RsvDisconnect
  else if StrIComp(Str,'else')=0 then WordId := RsvElse
  else if StrIComp(Str,'elseif')=0 then WordId := RsvElseIf
  else if StrIComp(Str,'enablekeyb')=0 then WordId := RsvEnableKeyb
  else if StrIComp(Str,'end')=0 then WordId := RsvEnd
  else if StrIComp(Str,'endif')=0 then WordId := RsvEndIf
  else if StrIComp(Str,'endwhile')=0 then WordId := RsvEndWhile
  else if StrIComp(Str,'exec')=0 then WordId := RsvExec
  else if StrIComp(Str,'execcmnd')=0 then WordId := RsvExecCmnd
  else if StrIComp(Str,'exit')=0 then WordId := RsvExit
  else if StrIComp(Str,'fileclose')=0 then WordId := RsvFileClose
  else if StrIComp(Str,'fileconcat')=0 then WordId := RsvFileConcat
  else if StrIComp(Str,'filecopy')=0 then WordId := RsvFileCopy
  else if StrIComp(Str,'filecreate')=0 then WordId := RsvFileCreate
  else if StrIComp(Str,'filedelete')=0 then WordId := RsvFileDelete
  else if StrIComp(Str,'filemarkptr')=0 then WordId := RsvFileMarkPtr
  else if StrIComp(Str,'fileopen')=0 then WordId := RsvFileOpen
  else if StrIComp(Str,'filereadln')=0 then WordId := RsvFileReadln
  else if StrIComp(Str,'filerename')=0 then WordId := RsvFileRename
  else if StrIComp(Str,'filesearch')=0 then WordId := RsvFileSearch
  else if StrIComp(Str,'fileseek')=0 then WordId := RsvFileSeek
  else if StrIComp(Str,'fileseekback')=0 then WordId := RsvFileSeekBack
  else if StrIComp(Str,'filestrseek')=0 then WordId := RsvFileStrSeek
  else if StrIComp(Str,'filestrseek2')=0 then WordId := RsvFileStrSeek2
  else if StrIComp(Str,'filewrite')=0 then WordId := RsvFileWrite
  else if StrIComp(Str,'filewriteln')=0 then WordId := RsvFileWriteLn
  else if StrIComp(Str,'findclose')=0 then WordId := RsvFindClose
  else if StrIComp(Str,'findfirst')=0 then WordId := RsvFindFirst
  else if StrIComp(Str,'findnext')=0 then WordId := RsvFindNext
  else if StrIComp(Str,'flushrecv')=0 then WordId := RsvFlushRecv
  else if StrIComp(Str,'for')=0 then WordId := RsvFor
  else if StrIComp(Str,'getdate')=0 then WordId := RsvGetDate
  else if StrIComp(Str,'getdir')=0 then WordId := RsvGetDir
  else if StrIComp(Str,'getenv')=0 then WordId := RsvGetEnv
  else if StrIComp(Str,'getpassword')=0 then WordId := RsvGetPassword
  else if StrIComp(Str,'gettime')=0 then WordId := RsvGetTime
  else if StrIComp(Str,'gettitle')=0 then WordId := RsvGetTitle
  else if StrIComp(Str,'goto')=0 then WordId := RsvGoto
  else if StrIComp(Str,'if')=0 then WordId := RsvIf
  else if StrIComp(Str,'include')=0 then WordId := RsvInclude
  else if StrIComp(Str,'inputbox')=0 then WordId := RsvInputBox
  else if StrIComp(Str,'int2str')=0 then WordId := RsvInt2Str
  else if StrIComp(Str,'kmtfinish')=0 then WordId := RsvKmtFinish
  else if StrIComp(Str,'kmtget')=0 then WordId := RsvKmtGet
  else if StrIComp(Str,'kmtrecv')=0 then WordId := RsvKmtRecv
  else if StrIComp(Str,'kmtsend')=0 then WordId := RsvKmtSend
  else if StrIComp(Str,'loadkeymap')=0 then WordId := RsvLoadKeyMap
  else if StrIComp(Str,'logclose')=0 then WordId := RsvLogClose
  else if StrIComp(Str,'logopen')=0 then WordId := RsvLogOpen
  else if StrIComp(Str,'logpause')=0 then WordId := RsvLogPause
  else if StrIComp(Str,'logstart')=0 then WordId := RsvLogStart
  else if StrIComp(Str,'logwrite')=0 then WordId := RsvLogWrite
  else if StrIComp(Str,'makepath')=0 then WordId := RsvMakePath
  else if StrIComp(Str,'messagebox')=0 then WordId := RsvMessageBox
  else if StrIComp(Str,'next')=0 then WordId := RsvNext
  else if StrIComp(Str,'passwordbox')=0 then WordId := RsvPasswordBox
  else if StrIComp(Str,'pause')=0 then WordId := RsvPause
  else if StrIComp(Str,'quickvanrecv')=0 then WordId := RsvQuickVANRecv
  else if StrIComp(Str,'quickvansend')=0 then WordId := RsvQuickVANSend
  else if StrIComp(Str,'recvln')=0 then WordId := RsvRecvLn
  else if StrIComp(Str,'restoresetup')=0 then WordId := RsvRestoreSetup
  else if StrIComp(Str,'return')=0 then WordId := RsvReturn
  else if StrIComp(Str,'send')=0 then WordId := RsvSend
  else if StrIComp(Str,'sendbreak')=0 then WordId := RsvSendBreak
  else if StrIComp(Str,'sendfile')=0 then WordId := RsvSendFile
  else if StrIComp(Str,'sendkcode')=0 then WordId := RsvSendKCode
  else if StrIComp(Str,'sendln')=0 then WordId := RsvSendLn
  else if StrIComp(Str,'setdate')=0 then WordId := RsvSetDate
  else if StrIComp(Str,'setdir')=0 then WordId := RsvSetDir
  else if StrIComp(Str,'setdlgpos')=0 then WordId := RsvSetDlgPos
  else if StrIComp(Str,'setecho')=0 then WordId := RsvSetEcho
  else if StrIComp(Str,'setexitcode')=0 then WordId := RsvSetExitCode
  else if StrIComp(Str,'setsync')=0 then WordId := RsvSetSync
  else if StrIComp(Str,'settime')=0 then WordId := RsvSetTime
  else if StrIComp(Str,'settitle')=0 then WordId := RsvSetTitle
  else if StrIComp(Str,'show')=0 then WordId := RsvShow
  else if StrIComp(Str,'showtt')=0 then WordId := RsvShowTT
  else if StrIComp(Str,'statusbox')=0 then WordId := RsvStatusBox
  else if StrIComp(Str,'str2code')=0 then WordId := RsvStr2Code
  else if StrIComp(Str,'str2int')=0 then WordId := RsvStr2Int
  else if StrIComp(Str,'strcompare')=0 then WordId := RsvStrCompare
  else if StrIComp(Str,'strconcat')=0 then WordId := RsvStrConcat
  else if StrIComp(Str,'strcopy')=0 then WordId := RsvStrCopy
  else if StrIComp(Str,'strlen')=0 then WordId := RsvStrLen
  else if StrIComp(Str,'strscan')=0 then WordId := RsvStrScan
  else if StrIComp(Str,'then')=0 then WordId := RsvThen
  else if StrIComp(Str,'testlink')=0 then WordId := RsvTestLink
  else if StrIComp(Str,'unlink')=0 then WordId := RsvUnlink
  else if StrIComp(Str,'wait')=0 then WordId := RsvWait
  else if StrIComp(Str,'waitevent')=0 then WordId := RsvWaitEvent
  else if StrIComp(Str,'waitln')=0 then WordId := RsvWaitLn
  else if StrIComp(Str,'waitrecv')=0 then WordId := RsvWaitRecv
  else if StrIComp(Str,'while')=0 then WordId := RsvWhile
  else if StrIComp(Str,'xmodemrecv')=0 then WordId := RsvXmodemRecv
  else if StrIComp(Str,'xmodemsend')=0 then WordId := RsvXmodemSend
  else if StrIComp(Str,'yesnobox')=0 then WordId := RsvYesNoBox
  else if StrIComp(Str,'zmodemrecv')=0 then WordId := RsvZmodemRecv
  else if StrIComp(Str,'zmodemsend')=0 then WordId := RsvZmodemSend

  else if StrIComp(Str,'not')=0 then WordId := RsvNot
  else if StrIComp(Str,'and')=0 then WordId := RsvAnd
  else if StrIComp(Str,'or')=0 then WordId := RsvOr
  else if StrIComp(Str,'xor')=0 then WordId := RsvXor;

  CheckReservedWord := WordId<>0;
end;

function GetFirstChar: byte;
var
  b: byte;
begin
  GetFirstChar := 0;
  if LinePtr<LineLen then
    b := byte(LineBuff[LinePtr])
  else exit;

  while (LinePtr<LineLen) and ((b=$20) or (b=$09)) do
  begin
    inc(LinePtr);
    if LinePtr<LineLen then b := byte(LineBuff[LinePtr]);
  end;

  if (b>$20) and (b<>ord(';')) then
  begin
    GetFirstChar := b;
    inc(LinePtr);
  end;
end;

function GetIdentifier(Name: PChar): BOOL;
var
  i: integer;
  b: byte;
begin
  GetIdentifier := FALSE;

  FillChar(Name[0],MaxNameLen,0);

  b := GetFirstChar;
  if b=0 then exit;

  {Check first character of identifier}
  if ((b<ord('A')) or (b>ord('Z'))) and
     (b<>ord('_')) and
     ((b<ord('a')) or (b>ord('z'))) then
  begin
    dec(LinePtr);
    exit;
  end;

  GetIdentifier := TRUE;
  Name[0] := char(b);
  i := 1;

  if LinePtr<LineLen then b := byte(LineBuff[LinePtr]);
  while (LinePtr<LineLen) and
        ( (b>=ord('0')) and (b<=ord('9')) or
          (b>=ord('A')) and (b<=ord('Z')) or
          (b>=ord('_')) or
          (b>=ord('a')) and (b<=ord('z')) ) do
  begin
    if i<MaxNameLen-1 then
    begin
      Name[i] := char(b);
      inc(i);
    end;
    inc(LinePtr);
    if LinePtr<LineLen then b := byte(LineBuff[LinePtr]);
  end;

end;

function GetReservedWord(var WordId: word): BOOL;
var
  Name: TName;
  P: word;
begin
  GetReservedWord := FALSE;
  P := LinePtr;
  if not GetIdentifier(Name) then exit;
  if not CheckReservedWord(Name,WordId) then
  begin
    LinePtr := P;
    exit;
  end;
  if 0<WordId then
    GetReservedWord := TRUE
  else
    LinePtr := P;
end;

function GetOperator(var WordId: word): BOOL;
var
  P: word;
  b: byte;
begin
  GetOperator := FALSE;
  P := LinePtr;
  b := GetFirstChar;
  case b of
    0: exit;
    ord('*'): WordId := RsvMul;
    ord('+'): WordId := RsvPlus;
    ord('-'): WordId := RsvMinus;
    ord('/'): WordId := RsvDiv;
    ord('%'): WordId := RsvMod;
    ord('<'): WordId := RsvLT;
    ord('='): WordId := RsvEQ;
    ord('>'): WordId := RsvGT;
  else
    begin
      dec(LinePtr);
      if not GetReservedWord(WordId) or (WordId<RsvOperator) then
      begin
        LinePtr := P;
        exit;
      end;
    end;
  end;

  if ((WordId=RsvLT) or (WordId=RsvGT)) and
     (LinePtr<LineLen) then
  begin
    b := byte(LineBuff[LinePtr]);
    if b=ord('=') then
    begin
      if WordId=RsvLT then
        WordId:=RsvLE
      else
        WordId:=RsvGE;
      inc(LinePtr);
    end
    else if (b=ord('>')) and (WordId=RsvLT) then
    begin
      WordId := RsvNE;
      inc(LinePtr);
    end;
  end;
  GetOperator := TRUE;
end;

function GetLabelName(Name: PChar): BOOL;
var
  i: integer;
  b: byte;
begin
  GetLabelName := FALSE;

  FillChar(Name[0],MaxNameLen,0);

  b := GetFirstChar;
  if b=0 then exit;
  Name[0] := char(b);

  i := 1;
  if LinePtr<LineLen then b := byte(LineBuff[LinePtr]);
  while (LinePtr<LineLen) and
        ( (b>=ord('0')) and (b<=ord('9')) or
          (b>=ord('A')) and (b<=ord('Z')) or
          (b>=ord('_')) or
          (b>=ord('a')) and (b<=ord('z')) ) do
  begin
    if i<MaxNameLen-1 then
    begin
      Name[i] := char(b);
      inc(i);
    end;
    inc(LinePtr);
    if LinePtr<LineLen then b := byte(LineBuff[LinePtr]);
  end;

  GetLabelName := StrLen(Name)>0;
end;

function GetString(Str: PChar; var Err: word): BOOL;

  function GetQuotedStr(q: byte; var i: word): integer;
  var
    b: byte;
  begin
    GetQuotedStr := 0;
    b:=0;
    if LinePtr<LineLen then b := byte(LineBuff[LinePtr]);
    while (LinePtr<LineLen) and (b>=ord(' ')) and (b<>q) do
    begin
      if i<MaxStrLen-1 then
      begin
        Str[i] := char(b);
        inc(i);
      end;

      inc(LinePtr);
      if LinePtr<LineLen then b := byte(LineBuff[LinePtr]);
    end;
    if b=q then
    begin
      if LinePtr<LineLen then inc(LinePtr)
    end
    else GetQuotedStr := ErrSyntax;
  end;

  function GetCharByCode(var i: word): word;
  var
    b: byte;
    n: word;
    temp: string[20];
    temp2: array[0..21] of char;
  begin
    GetCharByCode := ErrSyntax;
    b:=0;
    n := 0;
    if LinePtr<LineLen then b := byte(LineBuff[LinePtr]);
    if ((b<ord('0')) or (b>ord('9'))) and
       (b<>ord('$')) then exit;

    if b<>ord('$') then {decimal}
      while (LinePtr<LineLen) and (b>=ord('0')) and (b<=ord('9')) do
      begin
        n := n * 10 + b - $30;
        inc(LinePtr);
        if LinePtr<LineLen then b := byte(LineBuff[LinePtr]);
      end
    else begin {hexadecimal}
      inc(LinePtr);
      if LinePtr<LineLen then b := byte(LineBuff[LinePtr]);
      while (LinePtr<LineLen) and
        ((b>=ord('0')) and (b<=ord('9')) or
         (b>=ord('A')) and (b<=ord('F')) or
         (b>=ord('a')) and (b<=ord('f'))) do
      begin
        if b>=ord('a') then
          b := b - $57
        else if b>=ord('A') then
          b := b - $37
        else
          b := b - $30;
        n := n*16 + b;
        inc(LinePtr);
        if LinePtr<LineLen then b := byte(LineBuff[LinePtr]);
      end;
    end;

    if (n=0) or (n>255) then exit;
    GetCharByCode := 0;

    if i<MaxStrLen-1 then
    begin
      Str[i] := char(n);
      inc(i);
    end;
  end;

var
  q: byte;
  i: word;
begin
  GetString := FALSE;
  Err := 0;
  FillChar(Str[0],MaxStrLen,0);

  q := GetFirstChar;
  if q=0 then exit;
  dec(LinePtr);
  if (q=$22) or (q=$27) or (q=ord('#')) then
    GetString := TRUE
  else
    exit;

  i := 0;
  while ((q=$22) or (q=$27) or (q=ord('#'))) and (Err=0) do
  begin
    inc(LinePtr);
    case q of
      $22,$27: Err := GetQuotedStr(q,i);
      ord('#'): Err := GetCharByCode(i);
    end;
    q := byte(LineBuff[LinePtr]);
  end;

end;

function GetNumber(var Num: integer): BOOL;
var
  b: byte;
begin
  GetNumber := FALSE;
  Num := 0;

  b := GetFirstChar;
  if b=0 then exit;
  if (b>=ord('0')) and (b<=ord('9')) then
  begin {decimal constant}
    GetNumber := TRUE;
    Num := b-$30;
    if LinePtr<LineLen then b := byte(LineBuff[LinePtr]);
    while (LinePtr<LineLen) and (b>=ord('0')) and (b<=ord('9')) do
    begin
      Num := Num*10 - $30 + b;
      inc(LinePtr);
      if LinePtr<LineLen then b := byte(LineBuff[LinePtr]);
    end;
  end
  else if b=ord('$') then
  begin {hexadecimal constant}
    GetNumber := TRUE;
    if LinePtr<LineLen then b := byte(LineBuff[LinePtr]);
    while (LinePtr<LineLen) and
      ((b>=ord('0')) and (b<=ord('9')) or
       (b>=ord('A')) and (b<=ord('F')) or
       (b>=ord('a')) and (b<=ord('f'))) do
    begin
      if b>=ord('a') then
        b := b - $57
      else if b>=ord('A') then
        b := b - $37
      else
        b := b - $30;
      Num := Num*16 + b;
      inc(LinePtr);
      if LinePtr<LineLen then b := byte(LineBuff[LinePtr]);
    end;
  end
  else {integer constant is not found}
    dec(LinePtr);
end;

function CheckVar(Name: PChar; var VarType, VarId: word): BOOL;
var
  i, P: word;
begin
  CheckVar := TRUE;
  VarType := TypUnknown;

  i := 0;
  while i<IntVarCount do
  begin
    P := (i+IntVarIdOff)*MaxNameLen;
    if StrIComp(@NameBuff^[P],Name)=0 then
    begin
      VarType := TypInteger;
      VarId := i;
      exit;
    end;
    inc(i);
  end;

  i := 0;
  while i<StrVarCount do
  begin
    P := (i+StrVarIdOff)*MaxNameLen;
    if StrIComp(@NameBuff^[P],Name)=0 then
    begin
      VarType := TypString;
      VarId := i;
      exit;
    end;
    inc(i);
  end;

  i := 0;
  while i<LabVarCount do
  begin
    P := (i+LabVarIdOff)*MaxNameLen;
    if StrIComp(@NameBuff^[P],Name)=0 then
    begin
      VarType := TypLabel;
      VarId := i;
      exit;
    end;
    inc(i);
  end;

  CheckVar := FALSE;
end;

function NewIntVar(Name: PChar; InitVal: integer): BOOL;
var
  P: word;
begin
  NewIntVar := FALSE;
  if IntVarCount>=MaxNumOfIntVar then exit;
  P := (IntVarIdOff+IntVarCount)*MaxNameLen;
  StrCopy(@NameBuff^[P],Name);
  IntVal[IntVarCount] := InitVal;
  inc(IntVarCount);
  NewIntVar := TRUE;
end;

function NewStrVar(Name: PChar; InitVal: PChar): BOOL;
var
  P: word;
begin
  NewStrVar := FALSE;
  if StrVarCount>=MaxNumOfStrVar then exit;
  P := (StrVarIdOff+StrVarCount)*MaxNameLen;
  StrCopy(@NameBuff^[P],Name);
  P := StrVarCount*MaxStrLen;
  StrCopy(@StrBuff^[P],InitVal);
  inc(StrVarCount);
  NewStrVar := TRUE;
end;

function NewLabVar(Name: PChar; InitVal: BINT; ILevel: word): BOOL;
var
  P: word;
begin
  NewLabVar := FALSE;
  if LabVarCount>=MaxNumOfLabVar then exit;

  P := (LabVarIdOff+LabVarCount)*MaxNameLen;
  StrCopy(@NameBuff^[P],Name);
  LabVal[LabVarCount] := InitVal;
  LabLevel[LabVarCount] := byte(ILevel);
  inc(LabVarCount);
  NewLabVar := TRUE;
end;

procedure DelLabVar(ILevel: word);
begin
  while (LabVarCount>0) and (LabLevel[LabVarCount-1]>=ILevel) do
    dec(LabVarCount);
end;

procedure CopyLabel(ILabel: word; var Ptr: BINT; var Level: word);
begin
  Ptr := LabVal[ILabel];
  Level := word(LabLevel[ILabel]);
end;

function GetFactor(var ValType: word; var Val: integer; var Err: word): BOOL;
var
  Name: TName;
  P, Id: word;
begin
  GetFactor := TRUE;
  P := LinePtr;
  Err := 0;
  if GetIdentifier(Name) then
  begin
    if CheckReservedWord(Name,Id) then
    begin
      if Id=RsvNot then
      begin
        if GetFactor(ValType,Val,Err) then
        begin
          if (Err=0) and (ValType<>TypInteger) then
            Err := ErrTypeMismatch;
          Val := not Val;
        end
        else
          Err := ErrSyntax;
      end
      else
        Err := ErrSyntax;
    end
    else if CheckVar(Name, ValType, Id) then
    begin
      case ValType of
        TypInteger: Val := IntVal[Id];
        TypString: Val := Id;
      end;
    end
    else
      Err := ErrVarNotInit;
  end
  else if GetNumber(Val) then
    ValType := TypInteger
  else if GetOperator(Id) then
  begin
    if (Id=RsvPlus) or (Id=RsvMinus) then
    begin
      if GetFactor(ValType,Val,Err) then
      begin
        if (Err=0) and (ValType<>TypInteger) then
          Err := ErrTypeMismatch;
        if Id=RsvMinus then Val := -Val;
      end
      else
        Err := ErrSyntax;
    end
    else
      Err := ErrSyntax;
  end
  else if GetFirstChar=ord('(') then
  begin
    if GetExpression(ValType,Val,Err) then
    begin
      if (Err=0) and (GetFirstChar<>ord(')')) then
        Err := ErrCloseParent;
    end
    else
      Err := ErrSyntax;
  end
  else begin
    GetFactor := FALSE;
    Err := 0
  end;

  if Err<>0 then LinePtr := P;
end;

function GetTerm(var ValType: word; var Val: integer; var Err: word): BOOL;
var
  P1, P2, Type1, Type2, Er: word;
  Val1, Val2: integer;
  WId: word;
begin
  GetTerm := FALSE;
  P1 := LinePtr;
  if not GetFactor(Type1,Val1,Er) then exit;
  GetTerm := TRUE;
  ValType := Type1;
  Val := Val1;
  Err := Er;
  if Er<>0 then
  begin
    LinePtr := P1;
    exit;
  end;
  if Type1<>TypInteger then exit;

  repeat
    P2 := LinePtr;
    if not GetOperator(WId) then exit;

    case WId of 
      RsvAnd:;
      RsvMul:;
      RsvDiv:;
      RsvMod:;
    else
      begin
        LinePtr := P2;
        exit;
      end;
    end;

    if not GetFactor(Type2,Val2,Er) then
    begin
      Err := ErrSyntax;
      LinePtr := P1;
      exit;
    end;

    if Er<>0 then
    begin
      Err := Er;
      LinePtr := P1;
      exit;
    end;

    if Type2<>TypInteger then
    begin
      Err := ErrTypeMismatch;
      LinePtr := P1;
      exit;
    end;

    case WId of
      RsvAnd: Val1 := Val1 and Val2;
      RsvMul: Val1 := Val1  *  Val2;
      RsvDiv: if Val2<>0 then
                Val1 := Val1 div Val2
              else begin
                Err := ErrDivByZero;
                LinePtr := P1;
                exit;
              end;
      RsvMod: if Val2<>0 then
                Val1 := Val1 mod Val2
              else begin
                Err := ErrDivByZero;
                LinePtr := P1;
                exit;
              end;
    end;

    Val := Val1;
  until FALSE;
end;

function GetSimpleExpression(var ValType: word; var Val: integer; var Err: word): BOOL;
var
  P1, P2, Type1,Type2, Er: word;
  Val1,Val2: integer;
  WId: word;
begin
  GetSimpleExpression := FALSE;
  P1 := LinePtr;
  if not GetTerm(Type1,Val1,Er) then exit;
  GetSimpleExpression := TRUE;
  ValType := Type1;
  Val := Val1;
  Err := Er;
  if Er<>0 then
  begin
    LinePtr := P1;
    exit;
  end;
  if Type1<>TypInteger then exit;

  repeat
    P2 := LinePtr;
    if not GetOperator(WId) then exit;

    case WId of 
      RsvOr:;
      RsvXor:;
      RsvPlus:;
      RsvMinus:;
    else
      begin
        LinePtr := P2;
        exit;
      end;
    end;

    if not GetTerm(Type2,Val2,Er) then
    begin
      Err := ErrSyntax;
      LinePtr := P1;
      exit;
    end;

    if Er<>0 then
    begin
      Err := Er;
      LinePtr := P1;
      exit;
    end;

    if Type2<>TypInteger then
    begin
      Err := ErrTypeMismatch;
      LinePtr := P1;
      exit;
    end;

    case WId of
      RsvOr:    Val1 := Val1 or  Val2;
      RsvXor:   Val1 := Val1 xor Val2;
      RsvPlus:  Val1 := Val1  +  Val2;
      RsvMinus: Val1 := Val1  -  Val2;
    end;
    Val := Val1;
  until FALSE;
end;

function GetExpression(var ValType: word; var Val: integer; var Err: word): BOOL;
var
  P1,P2, Type1,Type2, Er: word;
  Val1, Val2: integer;
  WId: word;
begin
  P1 := LinePtr;
  if not GetSimpleExpression(Type1,Val1,Er) then
  begin
    GetExpression := FALSE;
    LinePtr := P1;
    exit;
  end;
  GetExpression := TRUE;
  ValType := Type1;
  Val := Val1;
  Err := Er;
  if Er<>0 then
  begin
    LinePtr := P1;
    exit;
  end;
  if Type1<>TypInteger then exit;

  P2 := LinePtr;
  if not GetOperator(WId) then exit;

  case WId of
    RsvLT:;
    RsvEQ:;
    RsvGT:;
    RsvLE:;
    RsvNE:;
    RsvGE:;
  else
    begin
      LinePtr := P2;
      exit;
    end;
  end;

  if not GetSimpleExpression(Type2,Val2,Er) then
  begin
    Err := ErrSyntax;
    LinePtr := P1;
    exit;
  end;

  if Er<>0 then
  begin
    Err := Er;
    LinePtr := P1;
    exit;
  end;

  if Type2<>TypInteger then
  begin
    Err := ErrTypeMismatch;
    exit;
  end;

  Val := 0;
  case WId of
    RsvLT: if Val1<Val2 then Val := 1;
    RsvEQ: if Val1=Val2 then Val := 1;
    RsvGT: if Val1>Val2 then Val := 1;
    RsvLE: if Val1<=Val2 then Val := 1;
    RsvNE: if Val1<>Val2 then Val := 1;
    RsvGE: if Val1>=Val2 then Val := 1;
  end;
end;

procedure GetIntVal(var Val: integer; var Err: word);
var
  ValType: word;
begin
  if Err<>0 then exit;
  if not GetExpression(ValType,Val,Err) then
  begin
    Err := ErrSyntax;
    exit;
  end;
  if Err<>0 then exit;
  if ValType<>TypInteger then
    Err := ErrTypeMismatch;
end;

procedure SetIntVal(VarId: word; Val: integer);
begin
  IntVal[VarId] := Val;
end;

function CopyIntVal(VarId: word): integer;
begin
  CopyIntVal := IntVal[VarId];
end;

procedure GetIntVar(var VarId, Err: word);
var
  Name: TName;
  VarType: word;
begin
  if Err<>0 then exit;

  if GetIdentifier(Name) then
  begin
    if CheckVar(Name,VarType,VarId) then
    begin
      if VarType<>TypInteger then
        Err := ErrTypeMismatch;
    end
    else begin
      if NewIntVar(Name,0) then
        CheckVar(Name,VarType,VarId)
      else
        Err := ErrTooManyVar;
    end;
  end
  else
    Err := ErrSyntax;
end;

procedure GetStrVal(Str: PChar; var Err: word);
var
  VarType: word;
  VarId: integer;
begin
  Str[0] := #0;
  if Err<>0 then exit;

  if GetString(Str,Err) then
    exit
  else if GetExpression(VarType,VarId,Err) then
  begin
    if Err<>0 then exit;
    if VarType<>TypString then
      Err := ErrTypeMismatch
    else
      StrCopy(Str,@StrBuff^[VarId*MaxStrLen]);
  end
  else
    Err := ErrSyntax;
end;

procedure GetStrVar(var VarId, Err: word);
var
  Name: TName;
  VarType: word;
begin
  if Err<>0 then exit;

  if GetIdentifier(Name) then
  begin
    if CheckVar(Name,VarType,VarId) then
    begin
      if VarType<>TypString then
        Err := ErrTypeMismatch;
    end
    else begin
      if NewStrVar(Name,#0) then
        CheckVar(Name,VarType,VarId)
      else
        Err := ErrTooManyVar;
    end;
  end
  else
    Err := ErrSyntax;
end;

procedure SetStrVal(VarId: word; Str: PChar);
begin
  StrCopy(@StrBuff^[VarId*MaxStrLen],Str);
end;

function StrVarPtr(VarId: word): PChar;
begin
  StrVarPtr := @StrBuff^[VarId*MaxStrLen];
end;

begin
  TTLStatus := 0;
end.
