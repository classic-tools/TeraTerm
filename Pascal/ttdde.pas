{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, DDE routines}
unit TTDDE;

interface
{$I teraterm.inc}

{$IFDEF Delphi}
uses Messages, WinTypes, WinProcs, OWindows, Strings, DDEML,
     TTTypes, Types, TTFTypes, TTWinMan,
     TTCommon, TTSetup, Clipboard, Telnet, TTLib;
{$ELSE}
uses WinTypes, WinProcs, WObjects, Strings, DDEML,
     TTTypes, Types, TTFTypes, TTWinMan,
     TTCommon, TTSetup, Clipboard, Telnet, TTLib;
{$ENDIF}

procedure SetTopic;
function InitDDE: bool;
procedure SendDDEReady;
procedure EndDDE;
procedure DDEAdv;
procedure EndDdeCmnd(Result: integer);
procedure SetDdeComReady(Ready: word);
procedure RunMacro(FName: PChar; Startup: BOOL);

var
  TopicName: array[0..20] of char;
  ConvH: HConv;
  AdvFlag: bool;
  CloseTT: bool;

implementation

uses FileSys;

const
  ServiceName = 'TERATERM';
  ItemName = 'DATA';
  ItemName2 = 'PARAM';

var
  DdeCmnd: BOOL;
{$ifndef TERATERM32}
  DdeCallbackPtr: ^TCallBack;
{$endif}

  Inst: Longint;
  Service: HSz;
  Topic: HSz;
  Item: HSz;
  Item2: HSz;
  HWndDdeCli: HWnd;

  StartupFlag: BOOL;

  {for sync mode}
  SyncMode: BOOL;
  SyncRecv: BOOL;
  SyncFreeSpace: longint;

  ParamFileName: array[0..255] of char;
  ParamBinaryFlag: word;
  ParamAppendFlag: word;
  ParamXmodemOpt: word;

const
  CBBufSize = 300;

procedure GetClientHWnd(HWndStr: PCHAR);
var
  i: integer;
  b: BYTE;
  HCli: WORD;
begin
  HCli := 0;
  i := 0;
  b := byte(HWndStr[0]);
  while b > 0 do
  begin
    if b <= $39 then
      HCli := (HCli shl 4) + (b-$30)
    else
      HCli := (HCli shl 4) + (b-$37);
    inc(i);
    b := byte(HWndStr[i]);
  end;
  HWndDdeCli := HCli;
end;

procedure Byte2HexStr(b: BYTE; HexStr: PCHAR);
begin
  if b<$a0 then
    HexStr[0] := char($30 + (b shr 4))
  else
    HexStr[0] := char($37 + (b shr 4));
  if (b and $0f) < $0a then
    HexStr[1] := char($30 + (b and $0f))
  else
    HexStr[1] := char($37 + (b and $0f));
end;

procedure SetTopic;
{$ifdef TERATERM32}
var
  w: WORD;
{$endif}
begin;
{$ifdef TERATERM32}
  w := HIWORD(HVTWin);
  Byte2HexStr(HI(w),@TopicName[0]);
  Byte2HexStr(LO(w),@TopicName[2]);
  w := LOWORD(HVTWin);
  Byte2HexStr(HI(w),@TopicName[4]);
  Byte2HexStr(LO(w),@TopicName[6]);
{$else}
  Byte2HexStr(HI(HVTWin),@TopicName[0]);
  Byte2HexStr(LO(HVTWin),@TopicName[2]);
{$endif}
end;

function WildConnect(ServiceHsz, TopicHsz: HSz; ClipFmt: integer): HDDEData;
var
  Pairs: array [0..1] of THSZPair;
  Ok: bool;
begin
  Pairs[0].hszSvc  := Service;
  Pairs[0].hszTopic:= Topic;
  Pairs[1].hszSvc  := 0;
  Pairs[1].hszTopic:= 0;

  Ok := FALSE;

  if (ServiceHsz= 0) and (TopicHsz = 0) then
    Ok := TRUE
  else
    if (TopicHsz = 0) and
       (DdeCmpStringHandles(Service, ServiceHSz) = 0) then
      Ok := TRUE
    else
      if (DdeCmpStringHandles(Topic, TopicHSz) = 0) and
         (ServiceHsz = 0) then
        Ok := TRUE;

  if Ok then
    WildConnect := DdeCreateDataHandle(Inst, @Pairs, SizeOf(Pairs),
      0, 0, ClipFmt, 0)
  else
    WildConnect := 0;
end;


function AcceptRequest(ItemHSz: HSz): HDDEData;

  function Get1(var b: byte): boolean;
  begin
  with cv do begin
    if DCount>0 then
      Get1 := TRUE
    else begin
      Get1 := FALSE;
      exit;
    end;
    b := byte( PChar(LogBuf)[DStart] );
    inc(DStart);
    if DStart>=InBuffSize then DStart := DStart-InBuffSize;
    dec(DCount);
  end;
  end;

  function GetDataLen: longint;
  var
    b: byte;
    Len: longint;
    Start, Count: integer;
  begin
  with cv do begin
    Len := DCount;
    Start := DStart;
    Count := DCount;
    while Count>0 do
    begin
      b := byte( PChar(LogBuf)[Start] );
      if (b=0) or (b=$01) then inc(Len);
      inc(Start);
      if Start>=InBuffSize then Start := Start-InBuffSize;
      dec(Count);
    end;
    GetDataLen := Len;
  end;
  end;

var
  b: byte;
  Unlock: bool;
  DH: HDDEData;
  DP: PChar;
  i: integer;
  Len: longint;
begin
with cv do begin
  AcceptRequest := 0;
  if not DDELog or (ConvH=0) then exit;

  if DdeCmpStringHandles(ItemHSz, Item2)=0 then {item 'PARAM'}
    DH := DdeCreateDataHandle(Inst,@ParamFileName[0],
      sizeof(ParamFileName),0,Item2,CF_OEMTEXT,0)
  else if DdeCmpStringHandles(ItemHSz, Item)=0 then {item 'DATA'}
  begin
    if HLogBuf=0 then exit;

    if LogBuf=nil then
    begin
      Unlock := TRUE;
      LogBuf := GlobalLock(HLogBuf);
      if LogBuf = nil then exit;
    end
    else Unlock := FALSE;

    Len := GetDataLen;
    if SyncMode and
       (SyncFreeSpace<Len) then
      Len := SyncFreeSpace;

    DH := DdeCreateDataHandle(Inst,nil,Len+2,0,
                            Item,CF_OEMTEXT,0);
    DP := DdeAccessData(DH,nil);
    if DP<>nil then
    begin
      i := 0;
      while i < Len do
      begin
        if Get1(b) then
        begin
          if (b=0) or (b=$01) then
          begin
            DP[i] := #$01;
            DP[i+1] := char(b + 1);
            i := i + 2;
          end
          else begin
            DP[i] := char(b);
            inc(i);
          end;
        end
        else
          Len := 0;
      end;
      DP[i] := #0;
      DdeUnAccessData(DH);
    end;

    if Unlock then
    begin
      GlobalUnlock(HLogBuf);
      LogBuf := nil;
    end;
  end
  else
    DH := 0;

  AcceptRequest := DH;
end;
end;

function AcceptPoke(ItemHSz: HSz; ClipFmt: integer;
  Data: HDDEData): HDDEDATA;
var
  DataPtr: PCHAR;
  DataSize: longint;
begin
  AcceptPoke := DDE_FNOTPROCESSED;

  if (TalkStatus<>IdTalkKeyb) or
     (ConvH=0) then exit;

  if (ClipFmt<>CF_TEXT) and (ClipFmt<>CF_OEMTEXT) then exit;

  if DdeCmpStringHandles(ItemHSz, Item) <> 0 then exit;

  DataPtr := DdeAccessData(Data,@DataSize);
  if DataPtr=nil then exit;
  CBStartPaste(0,FALSE,CBBufSize,DataPtr,DataSize);
  DdeUnaccessData(Data);
  if TalkStatus=IdTalkCB then
    AcceptPoke := DDE_FACK;
end;

function HexStr2Word(Str: PChar): word;
var
  i: integer;
  b: byte;
  w: word;
begin
  for i := 0 to 3 do
  begin
    b := byte(Str[i]);
    if b <= $39 then
      w := (w shl 4) + (b-$30)
    else
      w := (w shl 4) + (b-$37);
  end;
  HexStr2Word := w;
end;

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

function AcceptExecute(TopicHSz: HSz; Data: HDDEData): HDDEData;
var
  Command: array[0..259] of char;
  Temp: array[0..MAXPATHLEN-1] of char;
  i: integer;
  w, c: word;
begin
  AcceptExecute := DDE_FNOTPROCESSED;
  if ConvH=0 then exit;
  if DdeCmpStringHandles(TopicHSz, Topic) <> 0 then exit;
  if DdeGetData(Data,@Command[0],SizeOf(Command),0) = 0 then exit;
  AcceptExecute := DDE_FACK;

  case Command[0] of
    CmdSetHWnd: begin
        GetClientHWnd(@Command[1]);
        if cv.Ready then
          SetDdeComReady(1);
      end;
    CmdSetFile: StrCopy(ParamFileName,@Command[1]);
    CmdSetBinary: ParamBinaryFlag := byte(Command[1]) and 1;
    CmdSetAppend: ParamAppendFlag := byte(Command[1]) and 1;
    CmdSetXmodemOpt: begin
        ParamXmodemOpt := byte(Command[1]) and 3;
        if ParamXmodemOpt=0 then ParamXmodemOpt := 1;
      end;
    CmdSetSync: begin
        Val(StrPas(@Command[1]),SyncFreeSpace,i);
        if i<>0 then
          SyncFreeSpace := 0;
        SyncMode := SyncFreeSpace>0;
        SyncRecv := TRUE;
      end;
    CmdBPlusRecv:
        if (FileVar=nil) and NewFileVar(FileVar) then
        begin
          FileVar^.NoMsg := TRUE;
          DdeCmnd := TRUE;
          BPStart(IdBPReceive);
        end
        else begin
          AcceptExecute := DDE_FNOTPROCESSED;
        end;
    CmdBPlusSend:
        if (FileVar=nil) and NewFileVar(FileVar) then
        begin
          FileVar^.DirLen := 0;
          StrCopy(FileVar^.FullName,ParamFileName);
          FileVar^.NumFname := 1;
          FileVar^.NoMsg := TRUE;
          DdeCmnd := TRUE;
          BPStart(IdBPSend);
        end
        else begin
          AcceptExecute := DDE_FNOTPROCESSED;
        end;
    CmdChangeDir:
        StrCopy(ts.FileDir,ParamFileName);
    CmdClearScreen:
      case ParamFileName[0] of
        '0':
          PostMessage(HVTWin,WM_USER_ACCELCOMMAND,IdCmdEditCLS,0);
        '1':
          PostMessage(HVTWin,WM_USER_ACCELCOMMAND,IdCmdEditCLB,0);
        '2':
          PostMessage(HTEKWin,WM_USER_ACCELCOMMAND,IdCmdEditCLS,0);
      end;
    CmdCloseWin:
      CloseTT := TRUE;
    CmdConnect: begin
        if cv.Open then
        begin
          if cv.Ready then
            SetDdeComReady(1);
          exit;
        end;
        strcopy(Temp,'a '); {dummy exe name}
        strcat(Temp,ParamFileName);
        if LoadTTSet then
          ParseParam(Temp,@ts,nil);
        FreeTTSet;
        cv.NoMsg := 1;
        PostMessage(HVTWin,WM_USER_COMMSTART,0,0);
      end;
    CmdDisconnect:
      PostMessage(HVTWin,WM_USER_ACCELCOMMAND,IdCmdDisconnect,0);
    CmdEnableKeyb:
      KeybEnabled := (ParamBinaryFlag<>0);
    CmdGetTitle:
      {title is transfered later by XTYP_REQUEST}
      strcopy(ParamFileName,ts.Title);
    CmdInit: {initialization signal from TTMACRO}
      if StartupFlag then {in case of startup macro}
      begin {TTMACRO is waiting for connecting to the host}
        if (ts.PortType=IdSerial) or
           (ts.HostName[0]<>#0) then
        begin
          cv.NoMsg := 1;
          {start connecting}
          PostMessage(HVTWin,WM_USER_COMMSTART,0,0)
        end
        else {notify TTMACRO that I can not connect}
          SetDdeComReady(0);
        StartupFlag := FALSE;
      end;
    CmdKmtFinish,
    CmdKmtRecv:
        if (FileVar=nil) and NewFileVar(FileVar) then
        begin
          FileVar^.NoMsg := TRUE;
          DdeCmnd := TRUE;
          if Command[0]=CmdKmtFinish then
            i := IdKmtFinish
          else
            i := IdKmtReceive;
          KermitStart(i);
        end
        else begin
          AcceptExecute := DDE_FNOTPROCESSED;
        end;
    CmdKmtGet,
    CmdKmtSend:
        if (FileVar=nil) and NewFileVar(FileVar) then
        begin
          FileVar^.DirLen := 0;
          StrCopy(FileVar^.FullName,ParamFileName);
          FileVar^.NumFname := 1;
          FileVar^.NoMsg := TRUE;
          DdeCmnd := TRUE;
          if Command[0]=CmdKmtGet then
            i := IdKmtGet
          else
            i := IdKmtSend;
          KermitStart(i);
        end
        else begin
          AcceptExecute := DDE_FNOTPROCESSED;
        end;
    CmdLoadKeyMap: begin
        strcopy(ts.KeyCnfFN,ParamFileName);
        PostMessage(HVTWin,WM_USER_ACCELCOMMAND,IdCmdLoadKeyMap,0);
      end;
    CmdLogClose: if LogVar<>nil then FileTransEnd(OpLog);
    CmdLogOpen:
        if (LogVar=nil) and NewFileVar(LogVar) then
        begin
          LogVar^.DirLen := 0;
          LogVar^.NoMsg := TRUE;
          StrCopy(LogVar^.FullName,ParamFileName);
          ts.TransBin := ParamBinaryFlag;
          ts.Append := ParamAppendFlag;
          LogStart;
        end
        else begin
          AcceptExecute := DDE_FNOTPROCESSED;
        end;
    CmdLogPause:
      FLogChangeButton(TRUE);
    CmdLogStart:
      FLogChangeButton(FALSE);
    CmdLogWrite:
      if LogVar<>nil then
      begin
        _lwrite(LogVar^.FileHandle,
                ParamFileName,StrLen(ParamFileName));
        LogVar^.ByteCount :=
          LogVar^.ByteCount + StrLen(ParamFileName);
        FLogRefreshNum;
      end;
    CmdQVRecv:
      if (FileVar=nil) and NewFileVar(FileVar) then
      begin
        FileVar^.NoMsg := TRUE;
        DdeCmnd := TRUE;
        QVStart(IdQVReceive);
      end
      else begin
        AcceptExecute := DDE_FNOTPROCESSED;
      end;
    CmdQVSend:
        if (FileVar=nil) and NewFileVar(FileVar) then
        begin
          FileVar^.DirLen := 0;
          StrCopy(FileVar^.FullName,ParamFileName);
          FileVar^.NumFname := 1;
          FileVar^.NoMsg := TRUE;
          DdeCmnd := TRUE;
          QVStart(IdQVSend);
        end
        else begin
          AcceptExecute := DDE_FNOTPROCESSED;
        end;
    CmdRestoreSetup: begin
        strcopy(ts.SetupFName,ParamFileName);
        PostMessage(HVTWin,WM_USER_ACCELCOMMAND,IdCmdRestoreSetup,0);
      end;
    CmdSendBreak:
      PostMessage(HVTWin,WM_USER_ACCELCOMMAND,IdBreak,0);     
    CmdSendFile:
        if (SendVar=nil) and NewFileVar(SendVar) then
        begin
          SendVar^.DirLen := 0;
          StrCopy(SendVar^.FullName,ParamFileName);
          ts.TransBin := ParamBinaryFlag;
          SendVar^.NoMsg := TRUE;
          DdeCmnd := TRUE;
          FileSendStart;
        end
        else begin
          AcceptExecute := DDE_FNOTPROCESSED;
        end;
    CmdSendKCode: begin
        w := HexStr2Word(ParamFileName);
        c := HexStr2Word(@ParamFileName[4]);
        PostMessage(HVTWin,WM_USER_KEYCODE,w,c);
      end;
    CmdSetEcho: begin
        ts.LocalEcho := ParamBinaryFlag;
        if cv.Ready and cv.TelFlag and (ts.TelEcho>0) then
          TelChangeEcho;
      end;
    CmdSetTitle: begin
        strcopy(ts.Title,ParamFileName);
        ChangeTitle;
      end;
    CmdShowTT:
      case ParamFileName[0] of
        '-': ShowWindow(HVTWin,SW_HIDE);
        '0': ShowWindow(HVTWin,SW_MINIMIZE);
        '1': ShowWindow(HVTWin,SW_RESTORE);
        '2': ShowWindow(HTEKWin,SW_HIDE);
        '3': ShowWindow(HTEKWin,SW_MINIMIZE);
        '4': PostMessage(HVTWin,WM_USER_ACCELCOMMAND,IdCmdCtrlOpenTEK,0);
        '5': PostMessage(HVTWin,WM_USER_ACCELCOMMAND,IdCmdCtrlCloseTEK,0);
      end;
    CmdXmodemRecv:
        if (FileVar=nil) and NewFileVar(FileVar) then
        begin
          FileVar^.DirLen := 0;
          StrCopy(FileVar^.FullName,ParamFileName);
          ts.XmodemOpt := ParamXmodemOpt;
          ts.XmodemBin := ParamBinaryFlag;
          FileVar^.NoMsg := TRUE;
          DdeCmnd := TRUE;
          XmodemStart(IdXReceive);
        end
        else begin
          AcceptExecute := DDE_FNOTPROCESSED;
        end;
    CmdXmodemSend:
        if (FileVar=nil) and NewFileVar(FileVar) then
        begin
          FileVar^.DirLen := 0;
          StrCopy(FileVar^.FullName,ParamFileName);
          ts.XmodemOpt := ParamXmodemOpt;
          FileVar^.NoMsg := TRUE;
          DdeCmnd := TRUE;
          XmodemStart(IdXSend);
        end
        else begin
          AcceptExecute := DDE_FNOTPROCESSED;
        end;
    CmdZmodemRecv:
        if (FileVar=nil) and NewFileVar(FileVar) then
        begin
          FileVar^.NoMsg := TRUE;
          DdeCmnd := TRUE;
          ZmodemStart(IdZReceive);
        end
        else begin
          AcceptExecute := DDE_FNOTPROCESSED;
        end;
    CmdZmodemSend:
        if (FileVar=nil) and NewFileVar(FileVar) then
        begin
          FileVar^.DirLen := 0;
          StrCopy(FileVar^.FullName,ParamFileName);
          FileVar^.NumFname := 1;
          ts.XmodemBin := ParamBinaryFlag;
          FileVar^.NoMsg := TRUE;
          DdeCmnd := TRUE;
          ZmodemStart(IdZSend);
        end
        else begin
          AcceptExecute := DDE_FNOTPROCESSED;
        end;
  else
    AcceptExecute := DDE_FNOTPROCESSED;
  end;
end;

function DdeCallbackProc(CallType, Fmt: UINT; Conv: HConv; HSz1, HSz2: HSZ;
  Data: HDDEData; Data1, Data2: Longint): HDDEData; export;
var
  Res: HDDEDATA;
begin
  DdeCallbackProc := 0;
  if Inst=0 then exit;
  Res := 0;

  case CallType of
    XTYP_WILDCONNECT:
      Res := WildConnect(HSz2, HSz1, Fmt);
    XTYP_CONNECT:
      if Conv = 0 then
      begin
        if (DdeCmpStringHandles(Topic, HSz1) = 0) and
           (DdeCmpStringHandles(Service, HSz2) = 0) then
        begin
          if cv.Ready then
            SetDdeComReady(1);
          Res := 1;
        end;
      end;
    XTYP_CONNECT_CONFIRM:
      ConvH := Conv;
    XTYP_ADVREQ, XTYP_REQUEST:
      Res := AcceptRequest(HSz2);
    XTYP_POKE:
      Res := AcceptPoke(HSz2, Fmt, Data);
    XTYP_ADVSTART:
      if (ConvH<>0) and
         (DdeCmpStringHandles(Topic, HSz1) = 0) and
         (DdeCmpStringHandles(Item, HSz2) = 0) and
         (not AdvFlag) then
      begin
        AdvFlag := TRUE;
        Res := 1;
      end;
    XTYP_ADVSTOP:
      if (ConvH<>0) and
         (DdeCmpStringHandles(Topic, HSz1) = 0) and
         (DdeCmpStringHandles(Item, HSz2) = 0) and
         AdvFlag then
      begin
        AdvFlag := FALSE;
        Res := 1;
      end;
    XTYP_DISCONNECT:
      begin
        ConvH := 0;
        PostMessage(HVTWin,WM_USER_DDEEND,0,0);
      end;
    XTYP_EXECUTE:
      Res := AcceptExecute(HSz1, Data);
  end;  { Case CallType }

  DdeCallbackProc := Res;
end;

function InitDDE: bool;
var
  Ok: boolean;
begin
  InitDDE := FALSE;
  if ConvH<>0 then exit;

  Ok := TRUE;

{$ifdef TERATERM32}
  if DdeInitialize(Inst,DdeCallbackProc,0,0) = DMLERR_NO_ERROR then
{$else}
  DdeCallbackPtr:= MakeProcInstance(@DdeCallbackProc, HInstance);
  if (DdeCallbackPtr<>nil) and
     (DdeInitialize(Inst,TCallBack(DdeCallbackPtr),0,0) = DMLERR_NO_ERROR) then
{$endif}
  begin
    Service:= DdeCreateStringHandle(Inst, ServiceName, CP_WINANSI);
    Topic  := DdeCreateStringHandle(Inst, TopicName, CP_WINANSI);
    Item   := DdeCreateStringHandle(Inst, ItemName, CP_WINANSI);
    Item2  := DdeCreateStringHandle(Inst, ItemName2, CP_WINANSI);

    Ok := DdeNameService(Inst, Service, 0, DNS_REGISTER) <> 0;
  end
  else
    Ok := FALSE;

  SyncMode := FALSE;
  CloseTT := FALSE;
  StartupFlag := FALSE;
  DDELog := FALSE;

  if Ok then
  begin
    Ok := CreateLogBuf;
    if Ok then DDELog := TRUE;
  end;

  if not Ok then EndDDE;
  InitDDE := Ok;
end;

procedure SendDDEReady;
begin
  GetClientHWnd(TopicName);
  PostMessage(HWndDdeCli,WM_USER_DDEREADY,0,0);
end;

procedure EndDDE;
var
  Temp: longint;
begin
  if ConvH<>0 then
    DdeDisconnect(ConvH);
  ConvH := 0;
  SyncMode := FALSE;
  StartupFlag := FALSE;

  Temp := Inst;
  if (Inst <> 0) then
  begin
    Inst := 0;
    DdeNameService(Temp, Service, 0, DNS_UNREGISTER);
    if Service <> 0 then
      DdeFreeStringHandle(Inst, Service);
    Service := 0;
    if Topic <> 0 then
      DdeFreeStringHandle(Inst, Topic);
    Topic := 0;
    if Item <> 0 then
      DdeFreeStringHandle(Inst, Item);
    Item := 0;
    if Item2 <> 0 then
      DdeFreeStringHandle(Inst, Item2);
    Item2 := 0;

    DdeUninitialize(Temp);
{$ifndef TERATERM32}
    if DdeCallBackPtr <> nil then
      FreeProcInstance(DdeCallBackPtr);
    DdeCallBackPtr := nil;
{$endif}
  end;
  TopicName[0] := #0;

  if HWndDdeCli<>0 then
    PostMessage(HWndDdeCli,WM_USER_DDECMNDEND,0,0);
  HWndDdeCli := 0;
  AdvFlag := FALSE;

  DDELog := FALSE;
  FreeLogBuf;
  cv.NoMsg := 0;
end;

procedure DDEAdv;
begin
  if (ConvH=0) or
     (not AdvFlag) or
     (cv.DCount=0) then exit;

  if not SyncMode or
     SyncMode and SyncRecv then
  begin
    if SyncFreeSpace<10 then
      SyncFreeSpace := 0
    else
      SyncFreeSpace := SyncFreeSpace - 10;
    DdePostAdvise(Inst,Topic,Item);
    SyncRecv := FALSE;
  end;
end;

procedure EndDdeCmnd(Result: integer);
begin
  if (ConvH=0) or (HWndDdeCli=0) or (not DdeCmnd) then exit;
  PostMessage(HWndDdeCli,WM_USER_DDECMNDEND,Result,0);
  DdeCmnd := FALSE;
end;

procedure SetDdeComReady(Ready: word);
begin
  if HWndDdeCli=0 then exit;
  PostMessage(HWndDdeCli,WM_USER_DDECOMREADY,Ready,0);
end;

procedure RunMacro(FName: PChar; Startup: BOOL);
{  FName: macro filename
   Startup: TRUE in case of startup macro execution.
    	    In this case, the connection to the host will
	    made after the link to TT(P)MACRO is established. }
var
  i: integer;
  Cmnd: array[0..MAXPATHLEN+39] of char;
begin
  SetTopic;
  if not InitDDE then exit;
{$ifdef TERATERM32}
  strcopy(Cmnd,'TTPMACRO /D=');
{$else}
  strcopy(Cmnd,'TTMACRO /D=');
{$endif}
  strcat(Cmnd,TopicName);
  if FName<>nil then
  begin
    strcat(Cmnd,' ');
    i := strlen(Cmnd);
    strcat(Cmnd,FName);
{$ifdef TERATERM32}
    QuoteFName(@Cmnd[i]);
{$endif}
  end;

  StartupFlag := Startup;
  if Startup then
    strcat(Cmnd,' /S'); {"startup" flag}

  if WinExec(Cmnd,SW_MINIMIZE) < 32 then
    EndDDE;
end;

begin
  TopicName[0] := #0;
  ConvH := 0;
  AdvFlag := FALSE;
  CloseTT := FALSE;

  DdeCmnd := FALSE;
{$ifndef TERATERM32}
  DdeCallBackPtr := nil;
{$endif}
  Inst := 0;
  Service := 0;
  Topic := 0;
  Item := 0;
  Item2 := 0;
  HWndDdeCli := 0;

  StartupFlag := FALSE;

  SyncMode := FALSE;
end.