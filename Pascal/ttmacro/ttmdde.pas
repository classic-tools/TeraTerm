{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTMACRO.EXE, DDE routines}
unit TTMDDE;

interface
{$I teraterm.inc}

{$ifdef Delphi}
uses
  Messages, WinTypes, WinProcs, DDEML, SysUtils,
  Types, TTMDlg, TTMParse, TTMMsg;
{$else}
uses
  WinTypes, WinProcs, DDEML, Strings,
  Types, TTMDlg, TTMParse, TTMMsg;
{$endif}

const
  CmdSetHWnd      = ' ';
  CmdSetFile      = '!';
  CmdSetBinary    = '"';
  CmdSetAppend    = '#';
  CmdSetXmodemOpt = '$';
  CmdSetSync      = '%';

  CmdBPlusRecv    = '&';
  CmdBPlusSend    = '''';
  CmdChangeDir    = '(';
  CmdClearScreen  = ')';
  CmdCloseWin     = '*';
  CmdConnect      = '+';
  CmdDisconnect   = ',';
  CmdEnableKeyb   = '-';
  CmdGetTitle     = '.';
  CmdInit         = '/';
  CmdKmtFinish    = '0';
  CmdKmtGet       = '1';
  CmdKmtRecv      = '2';
  CmdKmtSend      = '3';
  CmdLoadKeyMap   = '4';
  CmdLogClose     = '5';
  CmdLogOpen      = '6';
  CmdLogPause     = '7';
  CmdLogStart     = '8';
  CmdLogWrite     = '9';
  CmdQVRecv       = ':';
  CmdQVSend       = ';';
  CmdRestoreSetup = '<';
  CmdSendBreak    = '=';
  CmdSendFile     = '>';
  CmdSendKCode    = '?';
  CmdSetEcho      = '@';
  CmdSetTitle     = 'A';
  CmdShowTT       = 'B';
  CmdXmodemSend   = 'C';
  CmdXmodemRecv   = 'D';
  CmdZmodemSend   = 'E';
  CmdZmodemRecv   = 'F';

var
  Linked: BOOL;
  ComReady: word;
  OutLen: integer;

  {for "WaitRecv" command}
  Wait2Str: TStrVal;
  Wait2Found: BOOL;

procedure Word2HexStr(w: WORD; HexStr: PChar);
function InitDDE(HWin: HWnd): bool;
procedure EndDDE;
procedure DDEOut1Byte(B: byte);
procedure DDEOut(B: PChar);
procedure DDESend;
function GetRecvLnBuff: PCHAR;
procedure FlushRecv;
procedure ClearWait;
procedure SetWait(Index: integer; Str: PChar);
function CmpWait(Index: integer; Str: PCHAR): integer;
procedure SetWait2(Str: PChar; Len, Pos: integer);
function Wait: integer;
function Wait2: BOOL;
procedure SetFile(FN: PChar);
procedure SetBinary(BinFlag: word);
procedure SetAppend(AppendFlag: word);
procedure SetXOption(XOption: word);
procedure SendSync;
procedure SetSync(OnFlag: bool);
function SendCmnd(OpId: char; WaitFlag: integer): word;
function GetTTParam(OpId: char; Param: PCHAR): word;

implementation

const
  ServiceName = 'TERATERM';
  ItemName = 'DATA';
  ItemName2 = 'PARAM';

const
  OutBufSize = 512;
  RingBufSize = 4096;
  RCountLimit = 3072;

var
  HMainWin: HWnd;
{$ifndef TERATERM32}
  DdeCallBackPtr: ^TCallback;
{$endif}
  Inst: Longint;
  ConvH: HConv;

  Service: HSz;
  Topic: HSz;
  Item: HSz;
  Item2: HSz;

  {sync mode}
  SyncMode: BOOL;
  SyncSent: BOOL;

  QuoteFlag: boolean;
  OutBuf: array[0..OutBufSize-1] of char;

  RingBuf: array[0..RingBufSize-1] of char;
  RBufStart, RBufPtr, RBufCount: integer;

  {for 'Wait' command}
  PWaitStr: array[1..10] of PChar;
  WaitStrLen: array[1..10] of integer;
  WaitCount: array[1..10] of integer;
  {for "WaitRecv" command}
  Wait2SubStr: TStrVal;
  Wait2Count, Wait2Len,
  Wait2SubLen, Wait2SubPos: integer;
  {waitln & recvln}
  RecvLnBuff: TStrVal;
  RecvLnPtr: integer;
  RecvLnLast: char;

{ring buffer}
procedure Put1Byte(b: byte);
begin
  RingBuf[RBufPtr] := char(b);
  inc(RBufPtr);
  if RBufPtr>=RingBufSize then RBufPtr := RBufPtr-RingBufSize;
  if RBufCount>=RingBufSize then
  begin
    RBufCount := RingBufSize;
    RBufStart := RBufPtr;
  end
  else
    inc(RBufCount);
end;

function Read1Byte(var b: byte): boolean;
begin
  if RBufCount<=0 then
  begin
    Read1Byte := FALSE;
    exit;
  end;

  b := byte(RingBuf[RBufStart]);
  inc(RBufStart);
  if RBufStart>=RingBufSize then RBufStart := RBufStart-RingBufSize;
  dec(RBufCount);
  if QuoteFlag then
  begin
    b := b - 1;
    QuoteFlag := FALSE;
  end
  else
    QuoteFlag := b=$01;

  Read1Byte := not QuoteFlag;
end;

function AcceptData(ItemHSz: HSz; Data: HDDEData): HDDEData;
var
  DH: HDDEData;
  DPtr: PChar;
  DSize: longint;
  i: integer;
begin
  AcceptData := 0;
  if DdeCmpStringHandles(ItemHSz, Item) <> 0 then exit;
  AcceptData := DDE_FACK;

  DH := Data;
  if DH=0 then
    DH := DdeClientTransaction(nil,0,ConvH,Item,CF_OEMTEXT,XTYP_REQUEST,1000,nil);

  if DH=0 then exit;
  DPtr := DdeAccessData(DH,@DSize);
  if DPtr=nil then exit;
  DSize := strlen(DPtr);
  for i:=0 to DSize-1 do
    Put1Byte(byte(DPtr[i]));
  DdeUnaccessData(DH);
  DdeFreeDataHandle(DH);
  SyncSent := FALSE;
end;

{ CallBack Procedure for DDEML }
function DDECallbackProc
  (CallType, Fmt: UINT; Conv: HConv; hsz1, hsz2: HSZ;
   Data: HDDEData; Data1, Data2: DWORD)
  : HDDEData; {$IFDEF TERATERM32} stdcall;
              {$ELSE} export; {$ENDIF}
begin
  DDECallbackProc := 0;
  if Inst=0 then exit;
  case CallType of
    XTYP_REGISTER: ;
    XTYP_UNREGISTER: ;
    XTYP_XACT_COMPLETE: ;
    XTYP_ADVDATA:
      DDECallbackProc := AcceptData(HSz2,Data);
    XTYP_DISCONNECT:
      begin
        ConvH := 0;
        Linked := FALSE;
        PostMessage(HMainWin,WM_USER_DDEEND,0,0);
      end;
  end;
end;

procedure Byte2HexStr(b: BYTE; HexStr: PChar);
begin
  if b < $a0 then
    HexStr[0] := char($30 + (b shr 4))
  else
    HexStr[0] := char($37 + (b shr 4));
  if (b and $0f) < $0a then
    HexStr[1] := char($30 + (b and $0f))
  else
    HexStr[1] := char($37 + (b and $0f));
  HexStr[2] := #0;
end;

procedure Word2HexStr(w: WORD; HexStr: PChar);
begin
  Byte2HexStr(Hi(w),HexStr);
  Byte2HexStr(Lo(w),@HexStr[2]);
end;

function InitDDE(HWin: HWnd): bool;
var
  i: integer;
  w: WORD;
  Cmd: array[0..9] of char;
begin
  InitDDE := FALSE;

  HMainWin := HWin;
  Linked := FALSE;
  SyncMode := FALSE;
  OutLen := 0;
  RBufStart := 0;
  RBufPtr := 0;
  RBufCount := 0;
  QuoteFlag := FALSE;
  for i := 1 to 10 do
  begin
    PWaitStr[i] := nil;
    WaitStrLen[i] := 0;
    WaitCount[i] := 0;
  end;

{$ifdef TERATERM32}
  if DdeInitialize(Inst, @DdeCallbackProc,
       APPCMD_CLIENTONLY or
       CBF_SKIP_REGISTRATIONS or
       CBF_SKIP_UNREGISTRATIONS,0)
     <> DMLERR_NO_ERROR then exit;
{$else}
  DdeCallbackPtr:= MakeProcInstance(@DdeCallbackProc, HInstance);
  if DdeCallbackPtr=nil then exit;
  if DdeInitialize(Inst,TCallback(DdeCallbackPtr),
       APPCMD_CLIENTONLY or
       CBF_SKIP_REGISTRATIONS or
       CBF_SKIP_UNREGISTRATIONS,0)
     <> DMLERR_NO_ERROR then
  begin
    FreeProcInstance(DdeCallbackPtr);
    DdeCallbackPtr := nil;
    exit;
  end;
{$endif}

  Service:= DdeCreateStringHandle(Inst, ServiceName, CP_WINANSI);
  Topic  := DdeCreateStringHandle(Inst, TopicName, CP_WINANSI);
  Item   := DdeCreateStringHandle(Inst, ItemName, CP_WINANSI);
  Item2  := DdeCreateStringHandle(Inst, ItemName2, CP_WINANSI);
  if (Service=0) or (Topic=0) or
     (Item=0) or (Item2=0) then exit;

  ConvH := DdeConnect(Inst, Service, Topic, nil);
  if ConvH = 0 then exit;
  Linked := TRUE;

  Cmd[0] := CmdSetHWnd;
{$IFDEF TERATERM32}
  w := HIWORD(HWin);
  Word2HexStr(w,@Cmd[1]);
  w := LOWORD(HWin);
  Word2HexStr(w,@Cmd[5]);
{$ELSE}
  w := HWin;
  Word2HexStr(w,@Cmd[1]);
{$ENDIF}

  DdeClientTransaction(@Cmd[0],StrLen(Cmd)+1,ConvH,0,
    CF_OEMTEXT,XTYP_EXECUTE,1000,nil);

  DdeClientTransaction(nil,0,ConvH,Item,
    CF_OEMTEXT,XTYP_ADVSTART,1000,nil);

  InitDDE := TRUE;
end;

procedure EndDDE;
var
  Temp: DWORD;
begin
  Linked := FALSE;
  SyncMode := FALSE;

  ConvH := 0;
  TopicName[0] := #0;

  Temp := Inst;
  if Inst <> 0 then
  begin
    Inst := 0;
    if Service <> 0 then
      DdeFreeStringHandle(Temp, Service);
    Service := 0;
    if Topic <> 0 then
      DdeFreeStringHandle(Temp, Topic);
    Topic := 0;
    if Item <> 0 then
      DdeFreeStringHandle(Temp, Item);
    Item := 0;
    if Item2 <> 0 then
      DdeFreeStringHandle(Temp, Item2);
    Item2 := 0;

    DdeUninitialize(Temp);   { Ignore the return value }
  end;
{$ifndef TERATERM32}
  if DdeCallbackPtr <> nil then
    FreeProcInstance(DdeCallbackPtr);
  DdeCallbackPtr := nil;
{$endif}
end;

procedure DDEOut1Byte(B: byte);
begin
  if ((B=$00) or (B=$01)) and
     (OutLen < OutBufSize-2) then
  begin
{ Character encoding
   to support NUL character sending

  [char to be sent] --> [encoded character]
         00         -->     01 01
         01         -->     01 02  }
    OutBuf[OutLen] := #$01;
    OutBuf[OutLen+1] := char(B+1);
    OutLen := OutLen + 2;
  end
  else if OutLen < OutBufSize-1 then
  begin
    OutBuf[OutLen] := char(B);
    inc(OutLen);
  end;
end;

procedure DDEOut(B: PChar);
var
  i: integer;
begin
  i := strlen(B);
  if OutLen+i > OutBufSize-1 then
    i := OutBufSize-1 - OutLen;
  Move(B[0],OutBuf[OutLen],i);
  OutLen := OutLen + i;
end;

procedure DDESend;
begin
  if (not Linked) or (OutLen=0) then exit;
  OutBuf[OutLen] := #0;
  if DdeClientTransaction(@OutBuf[0],OutLen+1,ConvH,Item,CF_OEMTEXT,XTYP_POKE,1000,nil)
     <>0 then
    OutLen := 0;
end;

procedure ClearRecvLnBuff;
begin
  RecvLnPtr := 0;
  RecvLnLast := #0;
end;

procedure PutRecvLnBuff(b: BYTE);
begin
  if RecvLnLast=#$0a then
    ClearRecvLnBuff;
  if RecvLnPtr < sizeof(RecvLnBuff)-1 then
  begin
    RecvLnBuff[RecvLnPtr] := char(b);
    inc(RecvLnPtr);
  end;
  RecvLnLast := char(b);
end;

function GetRecvLnBuff: PCHAR;
begin
  if (RecvLnPtr>0) and
     (RecvLnBuff[RecvLnPtr-1]=#$0a) then
  begin
    dec(RecvLnPtr);
    if (RecvLnPtr>0) and
       (RecvLnBuff[RecvLnPtr-1]=#$0d) then
      dec(RecvLnPtr);
  end;
  RecvLnBuff[RecvLnPtr] := #0;
  ClearRecvLnBuff;
  GetRecvLnBuff := RecvLnBuff;
end;

procedure FlushRecv;
begin
  ClearRecvLnBuff;
  RBufStart := 0;
  RBufPtr := 0;
  RBufCount := 0;
end;

procedure ClearWait;
var
  i: integer;
begin
  for i := 1 to 10 do
  begin
    if PWaitStr[i]<>nil then
      StrDispose(PWaitStr[i]);
    PWaitStr[i] := nil;
    WaitStrLen[i] := 0;
    WaitCount[i] := 0;
  end;
end;

procedure SetWait(Index: integer; Str: PChar);
begin
  if PWaitStr[Index]<>nil then
    StrDispose(PWaitStr[Index]);
  PWaitStr[Index] := StrNew(Str);
  WaitStrLen[Index] := StrLen(Str);
  WaitCount[Index] := 0;
end;

function CmpWait(Index: integer; Str: PCHAR): integer;
begin
  if PWaitStr[Index-1]<>nil then
    CmpWait := strcomp(PWaitStr[Index-1],Str)
  else
    CmpWait := 1;
end;

procedure SetWait2(Str: PChar; Len, Pos: integer);
begin
  strcopy(Wait2SubStr,Str);
  Wait2SubLen := strlen(Wait2SubStr);

  if Len<1 then
    Wait2Len := 0
  else if Len>MaxStrLen-1 then
    Wait2Len := MaxStrLen-1
  else
    Wait2Len := Len;

  if Wait2Len<Wait2SubLen then
    Wait2Len := Wait2SubLen;

  if Pos<1 then
    Wait2SubPos := 1
  else if Pos>Wait2Len-Wait2SubLen+1 then
    Wait2SubPos := Wait2Len-Wait2SubLen+1
  else
    Wait2SubPos := Pos;

  Wait2Count := 0;
  Wait2Str[0] := #0;
  Wait2Found := Wait2SubStr[0]=#0;
end;

function Wait: integer;
var
  b: byte;
  i, Found: integer;
  Str: PChar;
begin
  Found := 0;
  while (Found=0) and Read1Byte(b) do
  begin
    PutRecvLnBuff(b);
    for i := 10 downto 1 do
    begin
      Str := PWaitStr[i];
      if Str<>nil then
      begin
        if byte(Str[WaitCount[i]])=b then
          inc(WaitCount[i])
        else if WaitCount[i]>0 then
        begin
          WaitCount[i] := 0;
          if byte(Str[0])=b then
            WaitCount[i] := 1;
        end;
        if WaitCount[i]=WaitStrLen[i] then
          Found := i;
      end;
    end;
  end;
  Wait := Found;
  if Found>0 then ClearWait;
  SendSync;
end;

function Wait2: BOOL;
var
  b: byte;
begin
  while not (Wait2Found and (Wait2Count=Wait2Len))
        and Read1Byte(b) do
  begin
    if Wait2Count>=Wait2Len then
    begin
      Move(Wait2Str[1],Wait2Str[0],Wait2Len-1);
      Wait2Str[Wait2Len-1] := char(b);
      Wait2Count := Wait2Len;
    end
    else begin
      Wait2Str[Wait2Count] := char(b);
      inc(Wait2Count);
    end;
    Wait2Str[Wait2Count] := #0;
    if not Wait2Found and
      (Wait2Count>=Wait2SubPos+Wait2SubLen-1) then
      Wait2Found :=
        strlcomp(@Wait2Str[Wait2SubPos-1],Wait2SubStr,Wait2SubLen)=0;
  end;
  SendSync;

  Wait2 :=  Wait2Found and (Wait2Count=Wait2Len);
end;

procedure SetFile(FN: PChar);
var
  Cmd: array[0..259] of char;
begin
  Cmd[0] := CmdSetFile;
  StrCopy(@Cmd[1],FN);
  DdeClientTransaction(@Cmd[0],StrLen(Cmd)+1,ConvH,0,CF_OEMTEXT,XTYP_EXECUTE,1000,nil);
end;

procedure SetBinary(BinFlag: word);
var
  Cmd: array[0..2] of char;
begin
  Cmd[0] := CmdSetBinary;
  Cmd[1] := char($30 + BinFlag and 1);
  Cmd[2] := #0;
  DdeClientTransaction(@Cmd[0],StrLen(Cmd)+1,ConvH,0,CF_OEMTEXT,XTYP_EXECUTE,1000,nil);
end;

procedure SetAppend(AppendFlag: word);
var
  Cmd: array[0..2] of char;
begin
  Cmd[0] := CmdSetAppend;
  Cmd[1] := char($30 + AppendFlag and 1);
  Cmd[2] := #0;
  DdeClientTransaction(@Cmd[0],StrLen(Cmd)+1,ConvH,0,CF_OEMTEXT,XTYP_EXECUTE,1000,nil);
end;

procedure SetXOption(XOption: word);
var
  Cmd: array[0..2] of char;
begin
  if (XOption<1) or (XOption>3) then XOption := 1;
  Cmd[0] := CmdSetXmodemOpt;
  Cmd[1] := char($30 + XOption);
  Cmd[2] := #0;
  DdeClientTransaction(@Cmd[0],StrLen(Cmd)+1,ConvH,0,CF_OEMTEXT,XTYP_EXECUTE,1000,nil);
end;

procedure SendSync;
var
  NumStr: string[9];
  Cmd: array[0..9] of char;
  i: integer;
begin
  if not Linked then exit;
  if not SyncMode then exit;
  if SyncSent then exit;
  if RBufCount>=RCountLimit then exit;

  {notify free buffer space to Tera Term}
  i := RingBufSize - RBufCount;
  if i<1 then i := 1;
  if i>RingBufSize then i := RingBufSize;
  SyncSent := TRUE;

  Cmd[0] := CmdSetSync;
  Str(i,NumStr);
  strpcopy(@Cmd[1],NumStr);
  DdeClientTransaction(@Cmd[0],StrLen(Cmd)+1,ConvH,0,CF_OEMTEXT,XTYP_EXECUTE,1000,nil);
end;

procedure SetSync(OnFlag: Bool);
var
  NumStr: string[9];
  Cmd: array[0..9] of char;
  i: integer;
begin
  if not Linked then exit;
  if SyncMode=OnFlag then exit;
  SyncMode := OnFlag;

  if OnFlag then {sync mode on}
  begin
    {notify free buffer space to Tera Term}
    i := RingBufSize - RBufCount;
    if i<1 then i := 1;
    if i>RingBufSize then i := RingBufSize;
    SyncSent := TRUE;
  end
  else {sync mode off}
    i := 0;

  Cmd[0] := CmdSetSync;
  Str(i,NumStr);
  strpcopy(@Cmd[1],NumStr);
  DdeClientTransaction(@Cmd[0],StrLen(Cmd)+1,ConvH,0,CF_OEMTEXT,XTYP_EXECUTE,1000,nil);
end;

function SendCmnd(OpId: char; WaitFlag: integer): word;
{ WaitFlag should be 0 or IdTTLWaitCmndEnd or IdTTLWaitCmndResult.}
var
  Cmd: array[0..1] of char;
begin
  if not Linked then
  begin
    SendCmnd := ErrLinkFirst;
    exit;
  end
  else
    SendCmnd := 0;

  if WaitFlag<>0 then TTLStatus := WaitFlag;
  Cmd[0] := OpId;
  Cmd[1] := #0;
  if DdeClientTransaction(@Cmd[0],StrLen(Cmd)+1,ConvH,0,CF_OEMTEXT,XTYP_EXECUTE,5000,nil)=0
  then
    TTLStatus := IdTTLRun;
end;

function GetTTParam(OpId: char; Param: PCHAR): word;
var
  Data: HDDEDATA;
  DataPtr: PCHAR;
begin
  if not Linked then
  begin
    GetTTParam := ErrLinkFirst;
    exit;
  end;
  GetTTParam := 0;

  SendCmnd(OpId,0);
  Data :=
    DdeClientTransaction(nil,0,ConvH,Item2,CF_OEMTEXT,XTYP_REQUEST,5000,nil);
  if Data=0 then exit;
  DataPtr := PCHAR(DdeAccessData(Data,nil));
  if DataPtr<>nil then
  begin
    strcopy(Param,DataPtr);
    DdeUnaccessData(Data);
  end;
  DdeFreeDataHandle(Data);
end;

begin
  Linked := FALSE;
  ComReady := 0;

  HMainWin := 0;
{$ifndef TERATERM32}
  DdeCallBackPtr := nil;
{$endif}
  Inst := 0;
  ConvH := 0;

  Service := 0;
  Topic := 0;
  Item := 0;
  Item2 := 0;

  SyncMode := FALSE;

  RBufStart := 0;
  RBufPtr := 0;
  RBufCount := 0;

  RecvLnPtr := 0;
  RecvLnLast := #0;
end.
