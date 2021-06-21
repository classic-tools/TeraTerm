{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTMACRO.EXE, Tera Term Language interpreter}
unit TTL;

interface
{$I teraterm.inc}

{$ifdef Delphi}
uses Messages, WinTypes, WinProcs, SysUtils, WinDos,
     Types, TTMDlg, TTMBuff, TTMParse, TTMDDE, TTMEnc, TTMLib, TTLib;
{$else}
uses WinTypes, WinProcs, Strings, WinDos,
     Types, TTMDlg, TTMBuff, TTMParse, TTMDDE, TTMEnc, TTMLib, TTLib;
{$endif}

const
  IdTimeOutTimer = 1;
  {wakeup condition for sleep state}
  IdWakeupTimeout = 1;
  IdWakeupUnlink  = 2;
  IdWakeupDisconn = 4;
  IdWakeupConnect = 8;
  {connection trial state}
  IdWakeupInit = 16;

function InitTTL(HWin: HWnd): boolean;
procedure EndTTL;
procedure Exec;
procedure SetInputStr(Str: PChar);
procedure SetResult(ResultCode: integer);
function CheckTimeout: BOOL;
function TestWakeup(Wakeup: integer): BOOL;
procedure SetWakeup(Wakeup: integer);

implementation

const
{$IFDEF TERATERM32}
  TTERMCOMMAND = 'TTERMPRO /D=';
{$ELSE}
  TTERMCOMMAND = 'TERATERM /D=';
{$ENDIF}

var
{for 'ExecCmnd' command}
  ParseAgain: BOOL;
  IfNest: integer;
  ElseFlag: integer;
  EndIfFlag: integer;
{Window handle of the main window}
  HMainWin: HWnd;
{Timeout}
  TimeLimit: longint; {should be signed 32-bit}
{ for "WaitEvent" command}
  WakeupCondition: integer;

{ for "FindXXXX" commands}
const
  NumDirHandle = 8;
var
  DirHandle: array[0..NumDirHandle-1] of pointer;
{ for "FileMarkPtr" and "FileSeekBack" commands}
const
  NumFHandle = 16;
var
  FHandle: array[0..NumFHandle-1] of integer;
  FPointer: array[0..NumFHandle-1] of longint;

{forward declaration}
function ExecCmnd: integer; forward;


function InitTTL(HWin: HWnd): boolean;
var
  i: integer;
  Dir: TStrVal;
begin
  InitTTL := FALSE;

  HMainWin := HWin;

  if not InitVar then exit;
  LockVar;

  {System variables}
  NewIntVar('result',0);
  NewIntVar('timeout',0);
  NewStrVar('inputstr',#0);

  NewStrVar('param2',Param2);
  NewStrVar('param3',Param3);

  ParseAgain := FALSE;
  IfNest := 0;
  ElseFlag := 0;
  EndIfFlag := 0;

  for i := 0 to NumDirHandle-1 do
    DirHandle[i] := nil;
  for i := 0 to NumFHandle-1 do
    FHandle[i] := -1; 

  if not InitBuff(FileName) then
  begin
    TTLStatus := IdTTLEnd;
    exit;
  end;

  UnlockVar;

  ExtractDirName(FileName,Dir);
  TTMSetDir(Dir);

  if SleepFlag then
  begin
  {synchronization for startup macro
   sleep until Tera Term is ready}
    WakeupCondition := IdWakeupInit;
{      IdWakeupConnect or
      IdWakeupDisconn or
      IdWakeupUnlink;}
    TTLStatus := IdTTLSleep;
  end
  else
    TTLStatus := IdTTLRun;
  InitTTL := TRUE;
end;

procedure EndTTL;
var
  i: integer;
begin
  CloseStatDlg;

  for i := 0 to NumDirHandle-1 do
  begin
    if DirHandle[i]<>nil then
      FreeMem(DirHandle[i],sizeof(TSearchRec));
    DirHandle[i] := nil;
  end;

  UnlockVar;
  if TTLStatus=IdTTLWait then
    KillTimer(HMainWin,IdTimeOutTimer);
  CloseBuff(0);
  EndVar;
end;

function CalcTime: longint;
{$ifdef TERATERM32}
var
  Time: TSystemTime;
begin
  GetLocalTime(Time);
  CalcTime :=
    longint(Time.wHour)*3600 +
    longint(Time.wMinute)*60 +
    longint(Time.wSecond);
end;
{$else}
var
  h, m, s, s100: word;
begin
  GetTime(h,m,s,s100);
  CalcTime :=
    longint(h)*3600 +
    longint(m)*60 +
    longint(s);
end;
{$endif}

{//////////////// Beginning of TTL commands //////////////}
function TTLCommCmd(Cmd: char; Wait: integer): word;
begin
  if GetFirstChar<>0 then
    TTLCommCmd := ErrSyntax
  else if not Linked then
    TTLCommCmd := ErrLinkFirst
  else
    TTLCommCmd := SendCmnd(Cmd,Wait);
end;

function TTLCommCmdFile(Cmd: char; Wait: integer): WORD;
var
  Str: TStrVal;
  Err: word;
begin
  Err := 0;
  GetStrVal(Str,Err);

  if (Err=0) and
     ((StrLen(Str)=0) or (GetFirstChar<>0)) then
    Err := ErrSyntax;
  if (Err=0) and not Linked then
    Err := ErrLinkFirst;
  if Err=0 then
  begin
    SetFile(Str);
    Err := SendCmnd(Cmd,Wait);
  end;
  TTLCommCmdFile := Err;
end;

function TTLCommCmdBin(Cmd: char; Wait: integer): WORD;
var
  Val: integer;
  Err: WORD;
begin
  Err := 0;
  GetIntVal(Val,Err);

  if (Err=0) and
     (GetFirstChar<>0) then
    Err := ErrSyntax;
  if (Err=0) and not Linked then
    Err := ErrLinkFirst;
  if Err=0 then
  begin
    SetBinary(Val);
    Err := SendCmnd(Cmd,Wait);
  end;
  TTLCommCmdBin := Err;
end;

function TTLCommCmdInt(Cmd: char; Wait: integer): WORD;
var
  Val: integer;
  NumStr: string;
  Str2: array[0..20] of char; 
  Err: WORD;
begin
  Err := 0;
  GetIntVal(Val,Err);

  if (Err=0) and
     (GetFirstChar<>0) then
    Err := ErrSyntax;
  if (Err=0) and not Linked then
    Err := ErrLinkFirst;
  if Err=0 then
  begin
    Str(Val,NumStr);
    StrPCopy(Str2,NumStr);
    SetFile(Str2);
    Err := SendCmnd(Cmd,Wait);
  end;
  TTLCommCmdInt := Err;
end;

function TTLBeep: word;
begin
  if GetFirstChar=0 then
  begin
    TTLBeep := 0;
    messagebeep(0);
  end
  else
    TTLBeep := ErrSyntax;
end;

function TTLCall: word;
var
  LabName: TName;
  Err, VarType, VarId: word;
begin
  if GetLabelName(LabName) and (GetFirstChar=0) then
  begin
    if CheckVar(LabName,VarType,VarId) and (VarType=TypLabel) then
      Err := CallToLabel(VarId)
    else
      Err := ErrLabelReq;
  end
  else
    Err := ErrSyntax;

  TTLCall := Err;
end;

function TTLCloseSBox: word;
begin
  if GetFirstChar<>0 then
  begin
    TTLCloseSBox := ErrSyntax;
    exit;
  end;
  CloseStatDlg;
  TTLCloseSBox := 0;
end;

function TTLCloseTT: word;
begin
  if GetFirstChar<>0 then
  begin
    TTLCloseTT := ErrSyntax;
    exit;
  end;
  if not Linked then
    TTLCloseTT := ErrLinkFirst
  else begin
  {Close Tera Term}
    SendCmnd(CmdCloseWin,IdTTLWaitCmndEnd);
    EndDDE;
    TTLCloseTT := 0;
  end;
end;

function TTLCode2Str: word;
var
  VarId, Err: word;
  Num, Len, c, i: integer;
  d: byte;
  Str: TStrVal;
begin
  Err := 0;
  GetStrVar(VarId,Err);

  GetIntVal(Num,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLCode2Str := Err;
  if Err<>0 then exit;

  Len := sizeof(Num);
  i := 0;
  for c := 0 to Len-1 do
  begin
    d := (Num shr ((Len-1-c)*8)) and $ff;
    if (i>0) or (d<>0) then
    begin
      Str[i] := char(d);
      inc(i);
    end;
  end;
  Str[i] := #0;
  SetStrVal(VarId,Str);
end;

function TTLConnect: word;
var
  Cmnd, Str: TStrVal;
  Err: word;
  w: word;
begin
  Str[0] := #0;

  Err := 0;
  GetStrVal(Str,Err);

  TTLConnect := Err;
  if Err<>0 then exit;

  if GetFirstChar<>0 then
  begin
    TTLConnect := ErrSyntax;
    exit;
  end;

  if Linked then
  begin
    if ComReady<>0 then
    begin
      SetResult(2);
      exit;
    end;
    SetFile(Str);
    SendCmnd(CmdConnect,0);
    WakeupCondition := IdWakeupInit;
    TTLStatus := IdTTLSleep;
    exit;
  end;

  SetResult(0);
  {link to Tera Term}
  if strlen(TopicName)=0 then
  begin
    strcopy(Cmnd,TTERMCOMMAND);
{$IFDEF TERATERM32}
    w := HIWORD(HMainWin);
    Word2HexStr(w,TopicName);
    w := LOWORD(HMainWin);
    Word2HexStr(w,@TopicName[4]);
{$ELSE}
    w := HMainWin;
    Word2HexStr(w,TopicName);
{$ENDIF}
    strcat(Cmnd,TopicName);
    strcat(Cmnd,' ');
    StrLCat(Cmnd,Str,SizeOf(Cmnd)-1);
    if WinExec(Cmnd,SW_SHOW)<32 then
      TTLConnect := ErrCantConnect
    else
      TTLStatus := IdTTLInitDDE;
  end;

end;

function TTLDelPassword: word;
var
  Str, Str2: TStrVal;
  Err: WORD;
begin
  Err := 0;
  GetStrVal(Str,Err);
  GetStrVal(Str2,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLDelPassword := Err;
  if Err<>0 then exit;
  if Str[0]=#0 then exit;

  GetAbsPath(Str);
  if not DoesFileExist(Str) then exit;
  if Str2[0]=#0 then {delete all password}
    WritePrivateProfileString('Password',nil,nil,Str)
  else	{delete password specified by Str2}
    WritePrivateProfileString('Password',Str2,nil,Str);
end;

function TTLElse: word;
begin
  if GetFirstChar<>0 then
  begin
    TTLElse := ErrSyntax;
    exit;
  end;
  if IfNest<1 then
  begin
    TTLElse := ErrInvalidCtl;
    exit;
  end;
  {Skip until 'EndIf'}
  dec(IfNest);
  EndIfFlag := 1;
  TTLElse := 0;
end;

function CheckElseIf(var Err: word): integer;
var
  Val: integer;
  WId: word;
begin
  CheckElseIf := 0;
  Err := 0;
  GetIntVal(Val,Err);
  if Err<>0 then exit;
  CheckElseIf := Val;
  if not GetReservedWord(WId) or
     (WId<>RsvThen) or
     (GetFirstChar<>0) then
    Err := ErrSyntax;
end;

function TTLElseIf: word;
var
  Err: word;
  Val: integer;
begin
  Val := CheckElseIf(Err);
  TTLElseIf := Err;
  if Err<>0 then exit;

  if IfNest<1 then
  begin
    TTLElseIf := ErrInvalidCtl;
    exit;
  end;
  {Skip until 'EndIf'}
  dec(IfNest);
  EndIfFlag := 1;
end;

function TTLEnd: word;
begin
  if GetFirstChar=0 then
  begin
    TTLEnd := 0;
    TTLStatus := IdTTLEnd;
  end
  else
    TTLEnd := ErrSyntax;
end;

function TTLEndIf: word;
begin
  if GetFirstChar<>0 then
  begin
    TTLEndIf := ErrSyntax;
    exit;
  end;
  if IfNest<1 then
  begin
    TTLEndIf := ErrInvalidCtl;
    exit;
  end;  
  dec(IfNest);
  TTLEndIf := 0;
end;

function TTLEndWhile: word;
begin
  if GetFirstChar<>0 then
  begin
    TTLEndWhile := ErrSyntax;
    exit;
  end;
  TTLEndWhile := BackToWhile;
end;

function TTLExec: word;
var
  Str: TStrVal;
  Err: word;
begin
  Err := 0;
  GetStrVal(Str,Err);

  if (Err=0) and
     ((StrLen(Str)=0) or (GetFirstChar<>0)) then
    Err := ErrSyntax;

  TTLExec := Err;
  if Err<>0 then exit;

  WinExec(Str,SW_SHOW);
end;

function TTLExecCmnd: word;
var
  Err: word;
  NextLine: TStrVal;
  b: byte;
begin
  Err := 0;
  GetStrVal(NextLine,Err);
  TTLExecCmnd := Err;
  if Err<>0 then exit;
  if GetFirstChar<>0 then
  begin
    TTLExecCmnd := ErrSyntax;
    exit;
  end;

  strcopy(LineBuff,NextLine);
  LineLen := strlen(LineBuff);
  LinePtr := 0;
  b := GetFirstChar;
  dec(LinePtr);
  ParseAgain := (b<>0) and (b<>ord(':')) and (b<>ord(';'))
end;

function TTLExit: word;
begin
  if GetFirstChar=0 then
  begin
    TTLExit := 0;
    if not ExitBuffer then
      TTLStatus := IdTTLEnd;
  end
  else
    TTLExit := ErrSyntax;
end;

function TTLFileClose: word;
var
  Err: word;
  FH, i: integer;
begin
  Err := 0;
  GetIntVal(FH,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLFileClose := Err;
  if Err<>0 then exit;
  _lclose(FH);
  i := 0;
  while (i<NumFHandle) and (FH<>FHandle[i]) do inc(i);
  if i<NumFHandle then FHandle[i] := -1;
end;

function TTLFileConcat: word;
var
  Err: word;
  FH1, FH2, c: integer;
  FName1, FName2, Temp: TStrVal;
  buf: array[0..1023] of byte;
begin
  Err := 0;
  GetStrVal(FName1,Err);
  GetStrVal(FName2,Err);
  if (Err=0) and
    ((StrLen(FName1)=0) or
     (StrLen(FName2)=0) or
     (GetFirstChar<>0)) then
    Err := ErrSyntax;
  TTLFileConcat := Err;
  if Err<>0 then exit;

  GetAbsPath(FName1);
  GetAbsPath(FName2);
  if StrIComp(FName1,FName2)=0 then exit;

  FH1 := _lopen(FName1,OF_WRITE);
  if FH1<0 then
    FH1 := _lcreat(FName1,0);
  if FH1<0 then exit;
  _llseek(FH1,0,2);

  FH2 := _lopen(FName2,OF_READ);
  if FH2<>-1 then
  begin
    repeat
      c := _lread(FH2,@buf[0],SizeOf(buf));
      if c>0 then
        _lwrite(FH1,@buf[0],c);
    until c < SizeOf(buf);
    _lclose(FH2);
  end;
  _lclose(FH1);
end;

function TTLFileCopy: word;
var
  Err: word;
  FH1, FH2, c: integer;
  FName1, FName2: TStrVal;
  buf: array[0..1023] of byte;
{$ifndef TEARTERM32}
  f: text;
  ftime: longint;
{$endif}
begin
  Err := 0;
  GetStrVal(FName1,Err);
  GetStrVal(FName2,Err);
  if (Err=0) and
    ((StrLen(FName1)=0) or
     (StrLen(FName2)=0) or
     (GetFirstChar<>0)) then
    Err := ErrSyntax;
  TTLFileCopy := Err;
  if Err<>0 then exit;

  GetAbsPath(FName1);
  GetAbsPath(FName2);
  if StrIComp(FName1,FName2)=0 then exit;

{$ifdef TERATERM32}
  CopyFile(FName1,FName2);
{$else}
  FH1 := _lopen(FName1,OF_READ);
  if FH1<0 then exit;
  FH2 := _lcreat(FName2,0);
  if FH2<>-1 then
  begin
    repeat
      c := _lread(FH1,@buf[0],SizeOf(buf));
      if c>0 then
        _lwrite(FH2,@buf[0],c);
    until c < SizeOf(buf);
    _lclose(FH2);
  end;
  _lclose(FH1);

  Assign(f, Fname1);
  Reset(f);
  GetFTime(f,ftime);
  Close(f);
  Assign(f, Fname2);
  Reset(f);
  SetFTime(f,ftime);
  Close(f);

{$endif}
end;

function TTLFileCreate: word;
var
  Err, VarId: word;
  FH: integer;
  FName: TStrVal;
begin
  Err := 0;
  GetIntVar(VarId,Err);
  GetStrVal(FName,Err);
  if (Err=0) and
    ((StrLen(FName)=0) or (GetFirstChar<>0)) then
    Err := ErrSyntax;
  TTLFileCreate := Err;
  if Err<>0 then exit;

  GetAbsPath(FName);
  FH := _lcreat(FName,0);
  if FH<0 then FH := -1;
  SetIntVal(VarId,FH);
end;

function TTLFileDelete: word;
var
  Err: word;
  FName: TStrVal;
begin
  Err := 0;
  GetStrVal(FName,Err);
  if (Err=0) and
    ((StrLen(FName)=0) or (GetFirstChar<>0)) then
    Err := ErrSyntax;
  TTLFileDelete := Err;
  if Err<>0 then exit;

  GetAbsPath(FName);
  remove(FName);
end;

function TTLFileMarkPtr: word;
var
  Err: word;
  FH, i: integer;
begin
  Err := 0;
  GetIntVal(FH,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLFileMarkPtr := Err;
  if Err<>0 then exit;
  i := 0;
  while (i<NumFHandle) and (FH<>FHandle[i]) do inc(i);
  if i>=NumFHandle then
  begin
    i := 0;
    while (i<NumFHandle) and (FHandle[i]<>-1) do inc(i);
    if i<NumFHandle then FHandle[i] := FH;
  end;
  if i<NumFHandle then
  begin
    FPointer[i] := _llseek(FH,0,1); {mark current pos}
    if FPointer[i]<0 then FPointer[i] := 0;
  end;
end;

function TTLFileOpen: word;
var
  Err, VarId: word;
  Append, FH: integer;
  FName: TStrVal;
begin
  Err := 0;
  GetIntVar(VarId,Err);
  GetStrVal(FName,Err);
  GetIntVal(Append,Err);
  if (Err=0) and
    ((StrLen(FName)=0) or (GetFirstChar<>0)) then
    Err := ErrSyntax;
  TTLFileOpen := Err;
  if Err<>0 then exit;

  GetAbsPath(FName);
  FH := _lopen(FName,OF_READWRITE);
  if FH<0 then
    FH := _lcreat(FName,0);
  if FH<0 then FH := -1;
  SetIntVal(VarId,FH);
  if FH<0 then exit;
  if Append<>0 then _llseek(FH,0,2);  
end;

function TTLFileReadln: word;
var
  Err, VarId: word;
  FH, i, c: integer;
  Str: TStrVal;
  EndFile, EndLine: boolean;
  b: byte;
begin
  Err := 0;
  GetIntVal(FH,Err);
  GetStrVar(VarId,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLFileReadln := Err;
  if Err<>0 then exit;

  i := 0;
  EndLine := FALSE;
  EndFile := TRUE;
  repeat
    c := _lread(FH,@b,1);
    if c>0 then EndFile := FALSE;
    if c=1 then
      case b of
        $0d: begin
            c := _lread(FH,@b,1);
            if (c=1) and (b<>$0a) then
              _llseek(FH,-1,1);
            EndLine := TRUE;
          end;
        $0a: EndLine := TRUE;
      else
        if i<MaxStrLen-1 then
        begin
          Str[i] := char(b);
          inc(i);
        end;
      end;
  until (c<1) or EndLine;

  if EndFile then
    SetResult(1)
  else
    SetResult(0);

  Str[i] := #0;
  SetStrVal(VarId,Str);
end;

function TTLFileRename: word;
var
  Err: word;
  FName1, FName2: TStrVal;
  f: file;
begin
  Err := 0;
  GetStrVal(FName1,Err);
  GetStrVal(FName2,Err);
  if (Err=0) and
    ((StrLen(FName1)=0) or
     (StrLen(FName2)=0) or
     (GetFirstChar<>0)) then
    Err := ErrSyntax;
  TTLFileRename := Err;
  if Err<>0 then exit;
  if StrIComp(FName1,FName2)=0 then exit;
  GetAbsPath(FName1);
  {$I-}
  Assign(f,StrPas(FName1));
  Rename(f,StrPas(FName2));
  {$I+}
end;

function TTLFileSearch: word;
var
  Err: word;
  FName: TStrVal;
begin
  Err := 0;
  GetStrVal(FName,Err);
  if (Err=0) and
    ((StrLen(FName)=0) or (GetFirstChar<>0)) then
    Err := ErrSyntax;
  TTLFileSearch := Err;
  if Err<>0 then exit;

  GetAbsPath(FName);
  if DoesFileExist(FName) then
    SetResult(1)
  else
    SetResult(0);
end;

function TTLFileSeek: word;
var
  Err: word;
  FH, i, j: integer;
begin
  Err := 0;
  GetIntVal(FH,Err);
  GetIntVal(i,Err);
  GetIntVal(j,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLFileSeek := Err;
  if Err<>0 then exit;
  _llseek(FH,i,j);
end;

function TTLFileSeekBack: word;
var
  Err: word;
  FH, i: integer;
begin
  Err := 0;
  GetIntVal(FH,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLFileSeekBack := Err;
  if Err<>0 then exit;
  i := 0;
  while (i<NumFHandle) and (FH<>FHandle[i]) do inc(i);
  {move back to the marked pos}
  if i<NumFHandle then
    _llseek(FH,FPointer[i],0);
end;

function TTLFileStrSeek: word;
var
  Err: word;
  FH, Len, i, c: integer;
  Str: TStrVal;
  b: byte;
  pos: longint;
begin
  Err := 0;
  GetIntVal(FH,Err);
  GetStrVal(Str,Err);
  if (Err=0) and
    ((StrLen(Str)=0) or (GetFirstChar<>0)) then
    Err := ErrSyntax;
  TTLFileStrSeek := Err;
  if Err<>0 then exit;
  pos := _llseek(FH,0,1);
  if pos=-1 then exit;

  Len := StrLen(Str);
  i := 0;
  repeat
    c := _lread(FH,@b,1);
    if c=1 then
    begin
      if b=byte(Str[i]) then
        inc(i)
      else if i>0 then
      begin
        i := 0;
        if b=byte(Str[0]) then
          i := 1;
      end;
    end;
  until (c<1) or (i=Len);
  if i=Len then
    SetResult(1)
  else begin
    SetResult(0);
    _llseek(FH,pos,0);
  end;
end;

function TTLFileStrSeek2: word;
var
  Err: word;
  FH, Len, i, c: integer;
  Str: TStrVal;
  b: byte;
  pos, pos2: longint;
  Last: bool;
begin
  Err := 0;
  GetIntVal(FH,Err);
  GetStrVal(Str,Err);
  if (Err=0) and
    ((StrLen(Str)=0) or (GetFirstChar<>0)) then
    Err := ErrSyntax;
  TTLFileStrSeek2 := Err;
  if Err<>0 then exit;
  pos := _llseek(FH,0,1);
  if pos<=0 then exit;

  Len := StrLen(Str);
  i := 0;
  pos2 := pos;
  repeat
    Last := pos2<=0; 
    c := _lread(FH,@b,1);
    pos2 := _llseek(FH,-2,1);
    if c=1 then
    begin
      if b=byte(Str[Len-1-i]) then
        inc(i)
      else if i>0 then
      begin
        i := 0;
        if b=byte(Str[Len-1]) then
          i := 1;
      end;
    end;
  until Last or (i=Len);
  if i=Len then
    SetResult(1)
  else begin
    SetResult(0);
    _llseek(FH,pos,0);
  end;
end;

function TTLFileWrite: word;
var
  Err: word;
  FH: integer;
  Str: TStrVal;
begin
  Err := 0;
  GetIntVal(FH,Err);
  GetStrVal(Str,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLFileWrite := Err;
  if Err<>0 then exit;

  _lwrite(FH,Str,StrLen(Str));
end;

function TTLFileWriteLn: word;
var
  Err: word;
  FH: integer;
  Str: TStrVal;
begin
  Err := 0;
  GetIntVal(FH,Err);
  GetStrVal(Str,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLFileWriteLn := Err;
  if Err<>0 then exit;

  _lwrite(FH,Str,StrLen(Str));
  _lwrite(FH,#$0d#$0a,2);
end;

function TTLFindClose: word;
var
  Err: word;
  DH: integer;
begin
  Err := 0;
  GetIntVal(DH,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLFindClose := Err;
  if Err<>0 then exit;
  if (DH>=0) and (DH<NumDirHandle) and
     (DirHandle[DH]<>nil) then
  begin
    FreeMem(DirHandle[DH],sizeof(TSearchRec));
    DirHandle[DH] := nil;
  end;
end;

function TTLFindFirst: word;
var
  DH, Name, Err: word;
  Dir: TStrVal;
  i: integer;
begin
  Err := 0;
  GetIntVar(DH,Err);
  GetStrVal(Dir,Err);
  GetStrVar(Name,Err);
  if (Err=0) and
     (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLFindFirst := Err;
  if Err<>0 then exit;

  if Dir[0]=#0 then strcopy(Dir,'*.*');
  GetAbsPath(Dir);
  i := 0;
  while (i<NumDirHandle) and
        (DirHandle[i]<>nil) do
    inc(i);
  if (i<NumDirHandle) and
     (MaxAvail >= sizeof(TSearchRec)) then
  begin
    GetMem(DirHandle[i],sizeof(TSearchRec));
    FindFirst(Dir,faReadOnly or faHidden or faSysFile or
      faDirectory or faArchive, TSearchRec(DirHandle[i]^));
    if DosError=0 then
    begin
      SetStrVal(Name,TSearchRec(DirHandle[i]^).Name);
    end
    else begin
      FreeMem(DirHandle[i],sizeof(TSearchRec));
      DirHandle[i] := nil;
      i := -1;
    end;
  end
  else
    i := -1;  

  SetIntVal(DH,i);
  if i<0 then
  begin
    SetResult(0);
    SetStrVal(Name,'');
  end
  else
    SetResult(1);
end;

function TTLFindNext: word;
var
  Name, Err: word;
  DH: integer;
begin
  Err := 0;
  GetIntVal(DH,Err);
  GetStrVar(Name,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLFindNext := Err;
  if Err<>0 then exit;

  SetStrVal(Name,'');
  SetResult(0);
  if (DH>=0) and (DH<NumDirHandle) and
     (DirHandle[DH]<>nil) then
  begin
    FindNext(TSearchRec(DirHandle[DH]^));
    if DosError=0 then
    begin
      SetStrVal(Name,TSearchRec(DirHandle[DH]^).Name);
      SetResult(1);
    end
  end;
end;

function TTLFlushRecv: word;
begin
  if GetFirstChar<>0 then
    TTLFlushRecv := ErrSyntax
  else begin
    FlushRecv;
    TTLFlushRecv := 0;
  end;
end;

function TTLFor: word;
var
  Err, VarId: word;
  ValStart, ValEnd, i: integer;
begin
  Err := 0;
  GetIntVar(VarId,Err);
  GetIntVal(ValStart,Err);
  GetIntVal(ValEnd,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLFor := Err;
  if Err<>0 then exit;

  if not CheckNext then
  begin {first time}
    Err := SetForLoop;
    if Err=0 then
    begin
      SetIntVal(VarId,ValStart);
      i := CopyIntVal(VarId);
      if i=ValEnd then
        LastForLoop;
    end;
    TTLFor := Err;
  end
  else begin {return from 'next'}
    i := CopyIntVal(VarId);
    if i<ValEnd then
      inc(i)
    else if i>ValEnd then
      dec(i);
    SetIntVal(VarId,i);
    if i=ValEnd then
      LastForLoop;
  end;
end;

procedure AddDate(DateStr: PChar; DateNum: word);
var
  NumStr: string[10];
  PasStr: array[0..10] of char;
begin
  Str(DateNum,NumStr);
  StrPCopy(PasStr,NumStr);
  if StrLen(PasStr)=1 then
    StrCat(DateStr,'0');
  StrCat(DateStr,PasStr);
end;

function TTLGetDate: word;
var
  VarId, Err: word;
  Str2: TStrVal;
{$ifdef TERATERM32}
  Time: TSystemTime;
{$else}
  y, m, d, dw: word;
{$endif}
begin
  Err := 0;
  GetStrVar(VarId,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLGetDate := Err;
  if Err<>0 then exit;

  {get current date & time}
{$ifdef TERATERM32}
  GetLocalTime(Time);
  Str2[0] := #0;
  AddDate(Str2,Time.wYear);
  StrCat(Str2,'-');
  AddDate(Str2,Time.wMonth);
  StrCat(Str2,'-');
  AddDate(Str2,Time.wDay);
{$else}
  GetDate(y,m,d,dw);
  Str2[0] := #0;
  AddDate(Str2,y);
  StrCat(Str2,'-');
  AddDate(Str2,m);
  StrCat(Str2,'-');
  AddDate(Str2,d);
{$endif}
  SetStrVal(VarId,Str2);
end;

function TTLGetDir: word;
var
  VarId, Err: word;
  Str: TStrVal;
begin
  Err := 0;
  GetStrVar(VarId,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLGetDir := Err;
  if Err<>0 then exit;

  TTMGetDir(Str);
  SetStrVal(VarId,Str);
end;

function TTLGetEnv: word;
var
  VarId, Err: word;
  Str, Str2: TStrVal;
{$ifndef TERATERM32}
  PStr2: PChar;
{$endif}
begin
  Err := 0;
  GetStrVal(Str,Err);
  GetStrVar(VarId,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLGetEnv := Err;
  if Err<>0 then exit;

{$ifdef TERATERM32}
  if GetEnvironmentVariable(Str,Str2,sizeof(Str2))
       =0 then Str2[0] := #0;
{$else}
  PStr2 := GetEnvVar(Str);
  if PStr2<>nil then
    strcopy(Str2,PStr2)
  else
    Str2[0] := #0;
{$endif}  
  SetStrVal(VarId,Str2);
end;

function TTLGetPassword: word;
var
  Str, Str2, Temp2: TStrVal;
  Temp: array[0..511] of char;
  VarId, Err: word;
begin
  Err := 0;
  GetStrVal(Str,Err);
  GetStrVal(Str2,Err);
  GetStrVar(VarId,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLGetPassword := Err;
  if Err<>0 then exit;
  SetStrVal(VarId,'');
  if Str[0]=#0 then exit;
  if Str2[0]=#0 then exit;
  GetAbsPath(Str);
  GetPrivateProfileString('Password',Str2,'',
                          Temp,sizeof(Temp),Str);
  if Temp[0]=#0 then {password not exist}
  begin
    OpenInpDlg(Temp2,Str2,'Enter password',TRUE);
    if Temp2[0]<>#0 then
    begin
      Encrypt(Temp2,Temp);
      WritePrivateProfileString('Password',Str2,Temp,Str);
    end;
  end
  else {password exist}
    Decrypt(Temp,Temp2);

  SetStrVal(VarId,Temp2);
end;

function TTLGetTime: word;
var
  VarId, Err: word;
  Str2: TStrVal;
{$ifdef TERATERM32}
  Time: TSystemTime;
{$else}
  h, m, s, s100: word;
{$endif}
begin
  Err := 0;
  GetStrVar(VarId,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLGetTime := Err;
  if Err<>0 then exit;

  Str2[0] := #0;
{$ifdef TERATERM32}
  {get current date & time}
  GetLocalTime(Time);
  AddDate(Str2,Time.wHour);
  StrCat(Str2,':');
  AddDate(Str2,Time.wMinute);
  StrCat(Str2,':');
  AddDate(Str2,Time.wSecond);
{$else}
  {get current date & time}
  GetTime(h,m,s,s100);
  AddDate(Str2,h);
  StrCat(Str2,':');
  AddDate(Str2,m);
  StrCat(Str2,':');
  AddDate(Str2,s);
{$endif}
  SetStrVal(VarId,Str2);
end;

function TTLGetTitle: word;
var
  VarId, Err: word;
  Str: TName;
begin
  Err := 0;
  GetStrVar(VarId,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  if (Err=0) and not Linked then
    Err := ErrLinkFirst;
  TTLGetTitle := Err;
  if Err<>0 then exit;

  Err := GetTTParam(CmdGetTitle,Str);
  if Err=0 then
    SetStrVal(VarId,Str);
  TTLGetTitle := Err;
end;

function TTLGoto: word;
var
  LabName: TName;
  Err, VarType, VarId: word;
begin
  if GetLabelName(LabName) and (GetFirstChar=0) then
  begin
    if CheckVar(LabName,VarType,VarId) and (VarType=TypLabel) then
    begin
      JumpToLabel(VarId);
      Err := 0;
    end
    else
      Err := ErrLabelReq;
  end
  else
    Err := ErrSyntax;

  TTLGoto := Err;
end;

function CheckThen(var Err: word): BOOL;
var
  b: byte;
  Temp: TName;
begin
  CheckThen := FALSE;

  repeat

    repeat
      b := GetFirstChar;
      if b=0 then exit;
    until ((b>=ord('A')) and (b<=ord('Z'))) or
          (b=ord('_')) or
          ((b>=ord('a')) and (b<=ord('z')));
    dec(LinePtr);
    if not GetIdentifier(Temp) then exit;

  until stricomp(Temp,'then')=0;

  CheckThen := TRUE;
  if GetFirstChar<>0 then
    Err := ErrSyntax;
end;

function TTLIf: word;
var
  Err, ValType, Tmp, WId: word;
  Val: integer;
begin
  if not GetExpression(ValType,Val,Err) then
  begin
    TTLIf := ErrSyntax;
    exit;
  end;

  TTLIf := Err;
  if Err<>0 then exit;

  if ValType<>TypInteger then
  begin
    TTLIf := ErrTypeMismatch;
    exit;
  end;

  Tmp := LinePtr;
  if GetReservedWord(WId) and
     (WId=RsvThen) then
  begin  {If then ... EndIf structure}
    if GetFirstChar<>0 then
    begin
      TTLIf := ErrSyntax;
      exit;
    end;
    inc(IfNest);
    if Val=0 then
      ElseFlag := 1; {Skip until 'Else' or 'EndIf'}
  end
  else begin {single line lf command}
    if Val=0 then
    begin
      TTLIf := 0;
      exit;
    end;
    LinePtr := Tmp;
    TTLIf := ExecCmnd;
    exit;
  end;
end;

function TTLInclude: word;
var
  Err: word;
  Str: TStrVal;
begin
  Err := 0;
  GetStrVal(Str,Err);
  GetAbsPath(Str);
  if not BuffInclude(Str) then
    Err := ErrCantOpen;
  TTLInclude := Err;
end;

function TTLInputBox(Paswd: BOOL): word;
var
  Str1, Str2: TStrVal;
  Err, ValType, VarId: word;
begin
  Err := 0;
  GetStrVal(Str1,Err);
  GetStrVal(Str2,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;

  TTLInputBox := Err;
  if Err<>0 then exit;
  SetInputStr('');
  if CheckVar('inputstr',ValType,VarId) and
    (ValType=TypString) then
    OpenInpDlg(StrVarPtr(VarId),Str1,Str2,Paswd);
end;

function TTLInt2Str: word;
var
  VarId, Err: word;
  Num: integer;
  Str2: TStrVal;
  NumStr: String[15];
begin
  Err := 0;
  GetStrVar(VarId,Err);

  GetIntVal(Num,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLInt2Str := Err;
  if Err<>0 then exit;

  Str(Num,NumStr);
  StrPCopy(Str2,NumStr);

  SetStrVal(VarId,Str2);
end;

function TTLLogOpen: word;
var
  Str: TStrVal;
  Err: word;
  BinFlag, AppendFlag: integer;
begin
  Err := 0;
  GetStrVal(Str,Err);
  GetIntVal(BinFlag,Err);
  GetIntVal(AppendFlag,Err);
  if (Err=0) and
    ((StrLen(Str)=0) or (GetFirstChar<>0)) then
    Err := ErrSyntax;

  TTLLogOpen := Err;
  if Err<>0 then exit;

  SetFile(Str);
  SetBinary(BinFlag);
  SetAppend(AppendFlag);
  TTLLogOpen := SendCmnd(CmdLogOpen,0);
end;

function TTLMakePath: word;
var
  VarId, Err: word;
  Dir, Name: TStrVal;
begin
  Err := 0;
  GetStrVar(VarId,Err);
  GetStrVal(Dir,Err);
  GetStrVal(Name,Err);
  if (Err=0) and
     (GetFirstChar<>0) then
    Err := ErrSyntax;

  TTLMakePath := Err;
  if Err<>0 then exit;

  AppendSlash(Dir);
  strcat(Dir,Name);
  SetStrVal(VarId,Dir);
end;

const
  IdMsgBox=1;
  IdYesNoBox=2;
  IdStatusBox=3;

function MessageCommand(BoxId: integer; var Err: word): integer;
var
  Str1, Str2: TStrVal;
begin
  Err := 0;
  GetStrVal(Str1,Err);
  GetStrVal(Str2,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  if Err<>0 then exit;

  MessageCommand := 0;
  if BoxId=IdMsgBox then
    OpenMsgDlg(Str1,Str2,FALSE)
  else if BoxId=IdYesNoBox then
    MessageCommand :=
      OpenMsgDlg(Str1,Str2,TRUE)
  else if BoxId=IdStatusBox then
    OpenStatDlg(Str1,Str2);
end;

function TTLMessageBox: word;
var
  Err: word;
begin
  MessageCommand(IdMsgBox, Err);
  TTLMessageBox := Err;
end;

function TTLNext: word;
begin
  if GetFirstChar<>0 then
  begin
    TTLNext := ErrSyntax;
    exit;
  end;
  TTLNext := NextLoop;
end;

function TTLPause: word;
var
  TimeOut: integer;
  Err: word;
begin
  Err := 0;
  GetIntVal(TimeOut,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLPause := Err;
  if Err<>0 then exit;

  if TimeOut>0 then
  begin
    TTLStatus := IdTTLPause;
    TimeLimit := CalcTime + longint(TimeOut);
    if TimeLimit>=86400 then TimeLimit := TimeLimit-86400;
    SetTimer(HMainWin, IdTimeOutTimer,1000, nil)
  end

end;

function TTLRecvLn: word;
var
  Str: TStrVal;
  ValType, VarId: word;
  TimeOut: integer;
begin
  if GetFirstChar<>0 then
  begin
    TTLRecvLn := ErrSyntax;
    exit;
  end;
  if not Linked then
  begin
    TTLRecvLn := ErrLinkFirst;
    exit;
  end;

  ClearWait;

  Str[0] := #$0a;
  Str[1] := #0;
  SetWait(1,Str);
  SetInputStr('');
  SetResult(1);
  TTLStatus := IdTTLWaitNL;

  TimeOut := 0;
  if CheckVar('timeout',ValType,VarId) and
     (ValType=TypInteger) then
    TimeOut := CopyIntVal(VarId);

  if TimeOut>0 then
  begin
    TimeLimit := CalcTime + longint(TimeOut);
    if TimeLimit>=86400 then TimeLimit := TimeLimit-86400;
    SetTimer(HMainWin, IdTimeOutTimer,1000, nil)
  end;

  TTLRecvLn := 0;
end;

function TTLReturn: word;
begin
  if GetFirstChar=0 then
    TTLReturn := ReturnFromSub
  else
    TTLReturn := ErrSyntax;
end;

function TTLSend: word;
var
  Str: TStrVal;
  Err, ValType: word;
  Val: integer;
  EndOfLine: bool;
begin
  if not Linked then
  begin
    TTLSend := ErrLinkFirst;
    exit;
  end;

  EndOfLine := FALSE;
  repeat
    if GetString(Str,Err) then
    begin
      TTLSend := Err;
      if Err<>0 then exit;
      DDEOut(Str);
    end
    else if GetExpression(ValType,Val,Err) then
    begin
      TTLSend := Err;
      if Err<>0 then exit;
      case ValType of
        TypInteger: DDEOut1Byte(byte(Val));
        TypString: DDEOut(StrVarPtr(Val));
      else
        begin
          TTLSend := ErrTypeMismatch;
          exit;
        end;
      end;
    end
    else
      EndOfLine := TRUE;
    TTLSend := 0;
  until EndOfLine;
end;

function TTLSendFile: word;
var
  Str: TStrVal;
  Err: word;
  BinFlag: integer;
begin
  Err := 0;
  GetStrVal(Str,Err);
  GetIntVal(BinFlag,Err);
  if (Err=0) and
    ((StrLen(Str)=0) or (GetFirstChar<>0)) then
    Err := ErrSyntax;

  TTLSendFile := Err;
  if Err<>0 then exit;

  SetFile(Str);
  SetBinary(BinFlag);
  TTLSendFile := SendCmnd(CmdSendFile,IdTTLWaitCmndEnd);
end;

function TTLSendKCode: word;
var
  Str: TStrVal;
  Err: word;
  KCode, Count: integer;
begin
  Err := 0;
  GetIntVal(KCode,Err);
  GetIntVal(Count,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLSendKCode := Err;
  if Err<>0 then exit;

  Word2HexStr(KCode,Str);
  Word2HexStr(Count,@Str[4]);
  SetFile(Str);
  TTLSendKCode := SendCmnd(CmdSendKCode,0);
end;

function TTLSendLn: word;
var
  Err: word;
  Str: array[0..2] of char;
begin
  Err := TTLSend;
  if Err=0 then
  begin
    Str[0] := #$0D;
    Str[1] := #$0A;
    Str[2] := #0;
    if Linked then
      DDEOut(Str)
    else
      Err := ErrLinkFirst;
  end;
  TTLSendLn := Err;
end;

function TTLSetDate: word;
var
  Err: word;
  Str: TStrVal;
  v, c: integer;
{$ifdef TERATERM32}
  Time: TSystemTime;
{$else}
  y, m, d, dw: word;
{$endif}
begin
  Err := 0;
  GetStrVal(Str,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLSetDate := Err;
  if Err<>0 then exit;

{$ifdef TERATERM32}
  GetLocalTime(Time);
  Str[4] := #0;
  Val(StrPas(Str),v,c);
  if c=0 then
    Time.wYear := v;
  Str[7] := #0;
  Val(StrPas(@Str[5]),v,c);
  if c=0 then
    Time.wMonth := v;
  Str[10] := #0;
  Val(StrPas(@Str[8]),v,c);
  if c=0 then
    Time.wDay := v;
  SetLocalTime(Time);
{$else}
  GetDate(y,m,d,dw);
  Str[4] := #0;
  Val(StrPas(Str),v,c);
  if c=0 then
    y := v;
  Str[7] := #0;
  Val(StrPas(@Str[5]),v,c);
  if c=0 then
    m := v;
  Str[10] := #0;
  Val(StrPas(@Str[8]),v,c);
  if c=0 then
    d := v;
  SetDate(y,m,d);
{$endif}
end;

function TTLSetDir: word;
var
  Err: word;
  Str: TStrVal;
begin
  Err := 0;
  GetStrVal(Str,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLSetDir := Err;
  if Err<>0 then exit;

  TTMSetDir(Str);
end;

function TTLSetDlgPos: word;
var
  Err: word;
  x, y: integer;
begin
  Err := 0;
  GetIntVal(x,Err);
  GetIntVal(y,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLSetDlgPos := Err;
  if Err<>0 then exit;
  SetDlgPos(x,y);
end;

{function TTLSetEnv: word;
var
  Err: word;
  Str, Str2: TStrVal;
begin
  Err := 0;
  GetStrVal(Str,Err);
  GetStrVal(Str2,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLSetEnv := Err;
  if Err<>0 then exit;}

{$ifdef TERATERM32}
{  SetEnvironmentVariable(Str,Str2);}
{$else}
{  MessageBox(0,'Setenv is not supported','TTMACRO: Error',
    MB_ICONEXCLAMATION);}
{$endif}
{end;}

function TTLSetExitCode: word;
var
  Err: word;
  Val: integer;
begin
  Err := 0;
  GetIntVal(Val,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLSetExitCode := Err;
  if Err<>0 then exit;
  ExitCode := Val;
end;

function TTLSetSync: word;
var
  Err: WORD;
  Val: integer;
begin
  Err := 0;
  GetIntVal(Val,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  if (Err=0) and not Linked then
    Err := ErrLinkFirst;
  TTLSetSync := Err;
  if Err<>0 then exit;

  if Val=0 then
    SetSync(FALSE)
  else
    SetSync(TRUE);
end;

function TTLSetTime: word;
var
  Err: word;
  Str: TStrVal;
  v, c: integer;
{$ifdef TERATERM32}
  Time: TSystemTime;
{$else}
  h, m, s, s100: word;
{$endif}
begin
  Err := 0;
  GetStrVal(Str,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLSetTime := Err;
  if Err<>0 then exit;

{$ifdef TERATERM32}
  GetLocalTime(Time);
  Str[2] := #0;
  Val(StrPas(Str),v,c);
  if c=0 then
    Time.wHour := v;
  Str[5] := #0;
  Val(StrPas(@Str[3]),v,c);
  if c=0 then
    Time.wMinute := v;
  Str[8] := #0;
  Val(StrPas(@Str[6]),v,c);
  if c=0 then
    Time.wSecond := v;
  SetLocalTime(Time);
{$else}
  GetTime(h,m,s,s100);
  Str[2] := #0;
  Val(StrPas(Str),v,c);
  if c=0 then
    h := v;
  Str[5] := #0;
  Val(StrPas(@Str[3]),v,c);
  if c=0 then
    m := v;
  Str[8] := #0;
  Val(StrPas(@Str[6]),v,c);
  if c=0 then
    s := v;
  SetTime(h,m,s,0);
{$endif}
end;

function TTLShow: word;
var
  Err: word;
  Val: integer;
begin
  Err := 0;
  GetIntVal(Val,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLShow := Err;
  if Err<>0 then exit;
  if Val=0 then
    ShowWindow(HMainWin,SW_MINIMIZE)
  else if Val>0 then
    ShowWindow(HMainWin,SW_RESTORE)
  else
    ShowWindow(HMainWin,SW_HIDE);
end;

function TTLStatusBox: word;
var
  Err: word;
begin
  MessageCommand(IdStatusBox, Err);
  TTLStatusBox := Err;
end;

function TTLStr2Code: word;
var
  VarId, Err: word;
  Str: TStrVal;
  Len, c, i: integer;
  Num: UINT;
begin
  Err := 0;
  GetIntVar(VarId,Err);
  GetStrVal(Str,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;

  TTLStr2Code := Err;
  if Err<>0 then exit;

  Len := strlen(Str);
  if Len > sizeof(Num) then
    c := sizeof(Num)
  else
    c := Len; 
  Num := 0;
  for i := c downto 1 do
    Num := Num*256 + byte(Str[Len-i]);
  SetIntVal(VarId,Num);
end;

function TTLStr2Int: word;
var
  VarId, Err: word;
  Str: TStrVal;
  Num, c: integer;
begin
  Err := 0;
  GetIntVar(VarId,Err);
  GetStrVal(Str,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;

  TTLStr2Int := Err;
  if Err<>0 then exit;

  Val(StrPas(Str),Num,c);
  if c<>0 then
  begin
    Num := 0;
    SetResult(0);
  end
  else
    SetResult(1);
  SetIntVal(VarId,Num);
end;

function TTLStrCompare: word;
var
  Str1, Str2: TStrVal;
  Err: word;
  i: integer;
begin
  Err := 0;
  GetStrVal(Str1,Err);
  GetStrVal(Str2,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLStrCompare := Err;
  if Err<>0 then exit;

  i := StrComp(Str1,Str2);
  if i<0 then
    i := -1
  else if i>0 then
    i := 1;
  SetResult(i);
end;

function TTLStrConcat: word;
var
  VarId, Err: word;
  Str: TStrVal;
begin
  Err := 0;
  GetStrVar(VarId,Err);
  GetStrVal(Str,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLStrConcat := Err;
  if Err<>0 then exit;

  StrLCat(StrVarPtr(VarId),Str,
          MaxStrLen-1);
end;

function TTLStrCopy: word;
var
  Err, VarId: word;
  From, Len, SrcLen: integer;
  Str: TStrVal;
begin
  Err := 0;
  GetStrVal(Str,Err);
  GetIntVal(From,Err);
  GetIntVal(Len,Err);
  GetStrVar(VarId,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLStrCopy := Err;
  if Err<>0 then exit;

  if From<1 then From := 1;
  SrcLen := StrLen(Str)-From+1;
  if Len > SrcLen then Len := SrcLen;
  if Len < 0 then Len := 0;
  Move(Str[From-1],StrVarPtr(VarId)[0],Len);
  StrVarPtr(VarId)[Len] := #0;
end;

function TTLStrLen: word;
var
  Err: word;
  Str: TStrVal;
begin
  Err := 0;
  GetStrVal(Str,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLStrLen := Err;
  if Err<>0 then exit;
  SetResult(StrLen(Str));
end;

function TTLStrScan: word;
var
  Err: word;
  Len1, Len2, i, j: integer;
  Str1, Str2: TStrVal;
begin
  Err := 0;
  GetStrVal(Str1,Err);
  GetStrVal(Str2,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLStrScan := Err;
  if Err<>0 then exit;

  Len1 := StrLen(Str1);
  Len2 := StrLen(Str2);
  if (Len1=0) or (Len2=0) then
  begin
    SetResult(0);
    exit;
  end;

  i := 0;
  j := 0;
  repeat
    if Str1[i]=Str2[j] then
    begin
      inc(j);
      inc(i);
    end
    else if j=0 then
      inc(i)
    else
      j := 0;
  until (i=Len1) or (j=Len2);
  if j=Len2 then
    SetResult(i-Len2+1)
  else
    SetResult(0);
end;

function TTLTestLink: word;
begin
  if GetFirstChar<>0 then
  begin
    TTLTestLink := ErrSyntax;
    exit;
  end;
  TTLTestLink := 0;
  if not Linked then
    SetResult(0)
  else if ComReady=0 then
    SetResult(1)
  else
    SetResult(2);
end;

function TTLUnlink: word;
begin
  if GetFirstChar<>0 then
  begin
    TTLUnlink := ErrSyntax;
    exit;
  end;
  TTLUnlink := 0;
  if Linked then EndDDE;
end;

function TTLWait(Ln: BOOL): word;
var
  Str: TStrVal;
  Err, ValType, VarId: word;
  i, Val: integer;
  NoMore: bool;
  TimeOut: integer;
begin
  ClearWait;

  i := 0;
  repeat
    Err := 0;
    Str[0] := #0;
    NoMore := FALSE;
    if not GetString(Str,Err) then
    begin
      if GetExpression(ValType,Val,Err) then
      begin
        if Err=0 then
        begin
          if ValType=TypString then
            StrCopy(Str,StrVarPtr(Val))
          else
            Err:=ErrTypeMismatch;
        end;
      end
      else
        NoMore := TRUE;
    end;

    if (Err=0) and (StrLen(Str)>0) and (i<10) then
    begin
      inc(i);
      SetWait(i,Str);
    end;
  until (Err<>0) or (i>=10) or NoMore;

  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;

  if not Linked then
    Err := ErrLinkFirst;

  if (Err=0) and (i>0) then
  begin
    if Ln then
      TTLStatus := IdTTLWaitLn
    else
      TTLStatus := IdTTLWait;
    TimeOut := 0;
    if CheckVar('timeout',ValType,VarId) and
     (ValType=TypInteger) then
      TimeOut := CopyIntVal(VarId);

    if TimeOut>0 then
    begin
      TimeLimit := CalcTime + longint(TimeOut);
      if TimeLimit>=86400 then TimeLimit := TimeLimit-86400;
      SetTimer(HMainWin, IdTimeOutTimer,1000, nil)
    end;
  end
  else
    ClearWait;

  TTLWait := Err;
end;

function TTLWaitEvent: word;
var
  Err, ValType, VarId: word;
  TimeOut: integer;
begin
  Err := 0;
  GetIntVal(WakeupCondition,Err);
  if (Err<>0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  if Err<>0 then exit;

  WakeupCondition := WakeupCondition and 15; 
  TimeOut := 0;
  if CheckVar('timeout',ValType,VarId) and
     (ValType=TypInteger) then
    TimeOut := CopyIntVal(VarId);

  if TimeOut>0 then
  begin
    TimeLimit := CalcTime + longint(TimeOut);
    if TimeLimit>=86400 then TimeLimit := TimeLimit-86400;
    SetTimer(HMainWin, IdTimeOutTimer,1000, nil)
  end;
  TTLStatus := IdTTLSleep;

  TTLWaitEvent := Err;
end;

function TTLWaitRecv: word;
var
  Str: TStrVal;
  Err: word;
  Pos, Len, TimeOut: integer;
  VarType, VarId: word;
begin
  Err := 0;
  GetStrVal(Str,Err);
  GetIntVal(Len,Err);
  GetIntVal(Pos,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  if (Err=0) and (not Linked) then
    Err := ErrLinkFirst;
  TTLWaitRecv := Err;
  if Err<>0 then exit;
  SetInputStr('');
  SetWait2(Str,Len,Pos);

  TTLStatus := IdTTLWait2;
  TimeOut := 0;
  if CheckVar('timeout',VarType,VarId) and
     (VarType=TypInteger) then
    TimeOut := CopyIntVal(VarId);
  if TimeOut>0 then
  begin
    TimeLimit := CalcTime + longint(TimeOut);
    if TimeLimit>=86400 then TimeLimit := TimeLimit-86400;
    SetTimer(HMainWin, IdTimeOutTimer,1000, nil)
  end;

end;

function TTLWhile: word;
var
  Err: word;
  Val: integer;
begin
  Err := 0;
  GetIntVal(Val,Err);
  if (Err=0) and (GetFirstChar<>0) then
    Err := ErrSyntax;
  TTLWhile := Err;
  if (Err<>0) then exit;

  if Val<>0 then
    TTLWhile := SetWhileLoop
  else
    EndWhileLoop;
end;

function TTLXmodemRecv: word;
var
  Str: TStrVal;
  Err: word;
  BinFlag, XOption: integer;
begin
  Err := 0;
  GetStrVal(Str,Err);
  GetIntVal(BinFlag,Err);
  GetIntVal(XOption,Err);
  if (Err=0) and
    ((StrLen(Str)=0) or (GetFirstChar<>0)) then
    Err := ErrSyntax;

  TTLXmodemRecv := Err;
  if Err<>0 then exit;

  SetFile(Str);
  SetBinary(BinFlag);
  SetXOption(XOption);
  TTLXmodemRecv := SendCmnd(CmdXmodemRecv,IdTTLWaitCmndResult);
end;

function TTLXmodemSend: word;
var
  Str: TStrVal;
  Err: word;
  XOption: integer;
begin
  Err := 0;
  GetStrVal(Str,Err);
  GetIntVal(XOption,Err);
  if (Err=0) and
    ((StrLen(Str)=0) or (GetFirstChar<>0)) then
    Err := ErrSyntax;
  TTLXmodemSend := Err;
  if Err<>0 then exit;

  SetFile(Str);
  SetXOption(XOption);
  TTLXmodemSend := SendCmnd(CmdXmodemSend,IdTTLWaitCmndResult);
end;

function TTLYesNoBox: word;
var
  Err: word;
  YesNo: integer;
begin
  YesNo := MessageCommand(IdYesNoBox, Err);
  TTLYesNoBox := Err;
  if Err<>0 then exit;
  if YesNo=IDOK then
    YesNo := 1   {Yes}
  else
    YesNo := 0;  {No}
  SetResult(YesNo);
end;

function TTLZmodemSend: word;
var
  Str: TStrVal;
  Err: word;
  BinFlag: integer;
begin
  Err := 0;
  GetStrVal(Str,Err);
  GetIntVal(BinFlag,Err);
  if (Err=0) and
    ((StrLen(Str)=0) or (GetFirstChar<>0)) then
    Err := ErrSyntax;
  TTLZmodemSend := Err;
  if Err<>0 then exit;

  SetFile(Str);
  SetBinary(BinFlag);
  TTLZmodemSend := SendCmnd(CmdZmodemSend,IdTTLWaitCmndResult);
end;

function ExecCmnd: integer;
var
  WId, Err: word;
  StrConst, E: bool;
  Str: TStrVal;
  Cmnd: TName;
  ValType, VarType, VarId: word;
  Val: integer;
begin
  if (EndWhileFlag>0) then
  begin
    if not GetReservedWord(WId) then
      WId := 0;
    if WId=RsvWhile then
      inc(EndWhileFlag)
    else if WId=RsvEndWhile then
      dec(EndWhileFlag);
    ExecCmnd := 0;
    exit;
  end;

  if (EndIfFlag>0) then
  begin
    Err := 0;
    if not GetReservedWord(WId) then
      WId := 0;
    if (WId=RsvIf) and CheckThen(Err) then
      inc(EndIfFlag)
    else if (WId=RsvEndIf) then
      dec(EndIfFlag);
    ExecCmnd := Err;
    exit;
  end;

  if (ElseFlag>0) then
  begin
    Err := 0;
    if not GetReservedWord(WId) then
      WId := 0;
    if (WId=RsvIf) and CheckThen(Err) then
      inc(EndIfFlag)
    else if (WId=RsvElse) then
      dec(ElseFlag)
    else if (WId=RsvElseIf) then
    begin
      if CheckElseIf(Err)<>0 then
        dec(ElseFlag);
    end
    else if (WId=RsvEndIf) then
    begin
      dec(ElseFlag);
      if ElseFlag=0 then
        dec(IfNest);
    end;
    ExecCmnd := Err;
    exit;
  end;

  Err := 0;
  if GetReservedWord(WId) then
    case WId of
      RsvBeep:       Err := TTLBeep;
      RsvBPlusRecv:
        Err := TTLCommCmd(CmdBPlusRecv,IdTTLWaitCmndResult);
      RsvBPlusSend:
        Err := TTLCommCmdFile(CmdBPlusSend,IdTTLWaitCmndResult);
      RsvCall:       Err := TTLCall;
      RsvChangeDir:
        Err := TTLCommCmdFile(CmdChangeDir,0);
      RsvClearScreen:
        Err := TTLCommCmdInt(CmdClearScreen,0);
      RsvCloseSBox:  Err := TTLCloseSBox;
      RsvCloseTT:    Err := TTLCloseTT;
      RsvCode2Str:   Err := TTLCode2Str;
      RsvConnect:    Err := TTLConnect;
      RsvDelpassword: Err := TTLDelpassword;
      RsvDisconnect:
        Err := TTLCommCmd(CmdDisconnect,0);
      RsvElse:       Err := TTLElse;
      RsvElseIf:     Err := TTLElseIf;
      RsvEnableKeyb:
        Err := TTLCommCmdBin(CmdEnableKeyb,0);
      RsvEnd:        Err := TTLEnd;
      RsvEndIf:      Err := TTLEndIf;
      RsvEndWhile:   Err := TTLEndWhile;
      RsvExec:       Err := TTLExec;
      RsvExecCmnd:   Err := TTLExecCmnd;
      RsvExit:       Err := TTLExit;
      RsvFileClose:  Err := TTLFileClose;
      RsvFileConcat: Err := TTLFileConcat;
      RsvFileCopy:   Err := TTLFileCopy;
      RsvFileCreate: Err := TTLFileCreate;
      RsvFileDelete: Err := TTLFileDelete;
      RsvFileMarkPtr: Err := TTLFileMarkPtr;
      RsvFileOpen:   Err := TTLFileOpen;
      RsvFileReadln: Err := TTLFileReadln;
      RsvFileRename: Err := TTLFileRename;
      RsvFileSearch: Err := TTLFileSearch;
      RsvFileSeek:   Err := TTLFileSeek;
      RsvFileSeekBack: Err := TTLFileSeekBack;
      RsvFileStrSeek: Err := TTLFileStrSeek;
      RsvFileStrSeek2: Err := TTLFileStrSeek2;
      RsvFileWrite:  Err := TTLFileWrite;
      RsvFileWriteLn: Err := TTLFileWriteLn;
      RsvFindClose:  Err := TTLFindClose;
      RsvFindFirst:  Err := TTLFindFirst;
      RsvFindNext:   Err := TTLFindNext;
      RsvFlushRecv:  Err := TTLFlushRecv;
      RsvFor:        Err := TTLFor;
      RsvGetDate:    Err := TTLGetDate;
      RsvGetDir:     Err := TTLGetDir;
      RsvGetEnv:     Err := TTLGetEnv;
      RsvGetPassword: Err := TTLGetPassword;
      RsvGetTime:    Err := TTLGetTime;
      RsvGetTitle:   Err := TTLGetTitle;
      RsvGoto:       Err := TTLGoto;
      RsvIf:         Err := TTLIf;
      RsvInclude:    Err := TTLInclude;
      RsvInputBox:   Err := TTLInputBox(FALSE);
      RsvInt2Str:    Err := TTLInt2Str;
      RsvKmtFinish:
        Err := TTLCommCmd(CmdKmtFinish,IdTTLWaitCmndResult);
      RsvKmtGet:
        Err := TTLCommCmdFile(CmdKmtGet,IdTTLWaitCmndResult);
      RsvKmtRecv:
        Err := TTLCommCmd(CmdKmtRecv,IdTTLWaitCmndResult);
      RsvKmtSend:
        Err := TTLCommCmdFile(CmdKmtSend,IdTTLWaitCmndResult);
      RsvLoadKeyMap:
        Err := TTLCommCmdFile(CmdLoadKeyMap,0);
      RsvLogClose:
        Err := TTLCommCmd(CmdLogClose,0);
      RsvLogOpen:    Err := TTLLogOpen;
      RsvLogPause:
        Err := TTLCommCmd(CmdLogPause,0);
      RsvLogStart:
        Err := TTLCommCmd(CmdLogStart,0);
      RsvLogWrite:
        Err := TTLCommCmdFile(CmdLogWrite,0);
      RsvMakePath:   Err := TTLMakePath;
      RsvMessageBox: Err := TTLMessageBox;
      RsvNext:       Err := TTLNext;
      RsvPasswordBox: Err := TTLInputBox(TRUE);
      RsvPause:      Err := TTLPause;
      RsvQuickVANRecv:
        Err := TTLCommCmd(CmdQVRecv,IdTTLWaitCmndResult);
      RsvQuickVANSend:
        Err := TTLCommCmdFile(CmdQVSend,IdTTLWaitCmndResult);
      RsvRecvLn:     Err := TTLRecvLn;
      RsvRestoreSetup:
        Err := TTLCommCmdFile(CmdRestoreSetup,0);
      RsvReturn:     Err := TTLReturn;
      RsvSend:       Err := TTLSend;
      RsvSendBreak:
        Err := TTLCommCmd(CmdSendBreak,0);
      RsvSendFile:   Err := TTLSendFile;
      RsvSendKCode:  Err := TTLSendKCode;
      RsvSendLn:     Err := TTLSendLn;
      RsvSetDate:    Err := TTLSetDate;
      RsvSetDir:     Err := TTLSetDir;
      RsvSetDlgPos:  Err := TTLSetDlgPos;
      RsvSetEcho:
        Err := TTLCommCmdBin(CmdSetEcho,0);
      RsvSetExitCode: Err := TTLSetExitCode;
      RsvSetSync:    Err := TTLSetSync;
      RsvSetTime:    Err := TTLSetTime;
      RsvSetTitle:
        Err := TTLCommCmdFile(CmdSetTitle,0);
      RsvShow:       Err := TTLShow;
      RsvShowTT:
        Err := TTLCommCmdInt(CmdShowTT,0);
      RsvStatusBox:  Err := TTLStatusBox;
      RsvStr2Code:   Err := TTLStr2Code;
      RsvStr2Int:    Err := TTLStr2Int;
      RsvStrCompare: Err := TTLStrCompare;
      RsvStrConcat:  Err := TTLStrConcat;
      RsvStrCopy:    Err := TTLStrCopy;
      RsvStrLen:     Err := TTLStrLen;
      RsvStrScan:    Err := TTLStrScan;
      RsvTestLink:   Err := TTLTestLink;
      RsvUnlink:     Err := TTLUnlink;
      RsvWait:       Err := TTLWait(FALSE);
      RsvWaitEvent:  Err := TTLWaitEvent;
      RsvWaitLn:     Err := TTLWait(TRUE);
      RsvWaitRecv:   Err := TTLWaitRecv;
      RsvWhile:      Err := TTLWhile;
      RsvXmodemRecv: Err := TTLXmodemRecv;
      RsvXmodemSend: Err := TTLXmodemSend;
      RsvYesNoBox:   Err := TTLYesNoBox;
      RsvZmodemRecv:
        Err := TTLCommCmd(CmdZmodemRecv,IdTTLWaitCmndResult);
      RsvZmodemSend: Err := TTLZmodemSend;
    else
      Err := ErrSyntax;
    end
  else if GetIdentifier(Cmnd) then
  begin
    if (GetFirstChar=ord('=')) then
    begin
      StrConst := GetString(Str,Err);
      if StrConst then
        ValType := TypString
      else
        if not GetExpression(ValType,Val,Err) then
          Err := ErrSyntax;

      if Err=0 then
      begin
        if CheckVar(Cmnd,VarType,VarId) then
        begin
          if VarType=ValType then
            case ValType of
              TypInteger: SetIntVal(VarId,Val);
              TypString:
                if StrConst then
                  SetStrVal(VarId,Str)
                else
                  StrCopy(StrVarPtr(VarId),StrVarPtr(Val));
            end
          else
            Err := ErrTypeMismatch;
        end
        else begin
          case ValType of
            TypInteger: E := NewIntVar(Cmnd,Val);
            TypString:
              if StrConst then
                E := NewStrVar(Cmnd,Str)
              else
                E := NewStrVar(Cmnd,StrVarPtr(Val));
          else
            E := FALSE;
          end;
          if not E then Err := ErrTooManyVar;
        end;
        if (Err=0) and (GetFirstChar<>0) then
          Err := ErrSyntax;
      end;
    end
    else Err := ErrSyntax;
  end
  else
    Err := ErrSyntax;

  ExecCmnd := Err;
end;

procedure Exec;
var
  Err: word;
begin
  {ParseAgain is set by 'ExecCmnd'}
  if not ParseAgain and
     not GetNewLine then
  begin
    TTLStatus := IdTTLEnd;
    exit;
  end;
  ParseAgain := FALSE;

  LockVar;
  Err := ExecCmnd;
  if Err>0 then DispErr(Err);
  UnlockVar;

end;

procedure SetInputStr(Str: PChar);
var
  VarType, VarId: word;
begin
  if CheckVar('inputstr',VarType,VarId) and
     (VarType=TypString) then
    SetStrVal(VarId,Str);
end;

procedure SetResult(ResultCode: integer);
var
  VarType, VarId: word;
begin
  if CheckVar('result',VarType,VarId) and
     (VarType=TypInteger) then
    SetIntVal(VarId,ResultCode);
end;

function CheckTimeout: BOOL;
var
  dT: longint;
begin
  dT := TimeLimit-CalcTime;
  if dT>43199 then dT := dT - 86400
  else if dT<-43200 then dT := dT + 86400;
  CheckTimeout := (dT < 0);
end;

function TestWakeup(Wakeup: integer): BOOL;
begin
  TestWakeup :=
    (Wakeup and WakeupCondition)<>0;
end;

procedure SetWakeup(Wakeup: integer);
begin
  WakeupCondition := Wakeup;
end;

end.
