{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTMACRO.EXE, Macro file buffer}
unit TTMBuff;
{$i teraterm.inc}

interface

{$ifdef Delphi}
uses WinTypes, WinProcs, SysUtils, TTMParse, TTLib;
{$else}
uses WinTypes, WinProcs, Strings, TTMParse, TTLib;
{$endif}

function InitBuff(FileName: PChar): BOOL;
procedure CloseBuff(IBuff: integer);
function GetNewLine: BOOL;
{goto}
procedure JumpToLabel(ILabel: integer);
{call .. return}
function CallToLabel(ILabel: integer): word;
function ReturnFromSub: word;
{include file}
function BuffInclude(FileName: PChar): BOOL;
function ExitBuffer: BOOL;
{for ... next}
function SetForLoop: integer;
procedure LastForLoop;
function CheckNext: BOOL;
function NextLoop: integer;
{while ... endwhile}
function SetWhileLoop: integer;
procedure EndWhileLoop;
function BackToWhile: integer;

var
  EndWhileFlag: integer;

implementation

const
  {$IFDEF TERATERM32}
  MAXBUFFLEN = 2147483647;
  {$ELSE}
  MAXBUFFLEN = 32767;
  {$ENDIF}

const
  MAXNESTLEVEL = 10;
var
  INest: integer;
  BuffHandle: array[0..MAXNESTLEVEL-1] of THandle;
  Buff: array[0..MAXNESTLEVEL-1] of pointer;
  BuffLen: array[0..MAXNESTLEVEL-1] of BINT;
  BuffPtr: array[0..MAXNESTLEVEL-1] of BINT;

const
  MAXSP = 10;
  {Control type}
  CtlCall  = 1; {Call}
  CtlFor   = 2; {For ... Next}
  CtlWhile = 3; {While ... EndWhile}
  {Control stack}
  INVALIDPTR = BINT(-1);
var
  PtrStack: array[0..MAXSP-1] of BINT;
  LevelStack: array[0..MAXSP-1] of integer;
  TypeStack: array[0..MAXSP-1] of integer;
  SP: integer; {Stack pointer}
  LineStart: BINT;
  NextFlag: BOOL;

function LoadMacroFile(FileName: PChar; IBuff: integer): BOOL;
var
  F: integer;
begin
  LoadMacroFile := FALSE;
  if (FileName[0]=#0) or (IBuff>MAXNESTLEVEL-1) then exit;
  if (BuffHandle[IBuff]<>0) then exit;
  BuffPtr[IBuff] := 0;

  {get file length}
  BuffLen[IBuff] := GetFSize(FileName);
  if BuffLen[IBuff]=0 then exit;
  if BuffLen[IBuff]>MAXBUFFLEN then exit;

  F :=_lopen(FileName,0);
  if F<=0 then exit;
  BuffHandle[IBuff] := GlobalAlloc(GMEM_MOVEABLE, BuffLen[IBuff]);
  if BuffHandle[IBuff]<>0 then
  begin
    Buff[IBuff] := GlobalLock(BuffHandle[IBuff]);
    if Buff[IBuff]<>nil then
    begin
      _lread(F, Buff[IBuff], BuffLen[IBuff]);
      GlobalUnlock(BuffHandle[IBuff]);
      LoadMacroFile := TRUE;
    end
    else begin
      GlobalFree(BuffHandle[IBuff]);
      BuffHandle[IBuff] := 0;
    end;
  end;
  _lclose(F);
end;

function GetRawLine: BOOL;
var
  i: integer;
  b: byte;
begin
  LineStart := BuffPtr[INest];
  GetRawLine := FALSE;
  Buff[INest] := GlobalLock(BuffHandle[INest]);
  if Buff[INest]=nil then exit;

  if BuffPtr[INest]<BuffLen[INest] then
    b := byte(PChar(Buff[INest])[BuffPtr[INest]]);

  i := 0;
  while (BuffPtr[INest]<BuffLen[INest]) and
        ((b>=$20) or (b=$09)) do
  begin
    LineBuff[i] := char(b);
    inc(i);
    inc(BuffPtr[INest]);
    if BuffPtr[INest]<BuffLen[INest] then
      b := byte(PChar(Buff[INest])[BuffPtr[INest]]);
  end;
  LineBuff[i] := #0;
  LinePtr := 0;
  LineLen := strlen(LineBuff);

  while (BuffPtr[INest]<BuffLen[INest]) and
        (b<$20) and (b<>$09) do
  begin
    inc(BuffPtr[INest]);
    if BuffPtr[INest]<BuffLen[INest] then
      b := byte(PChar(Buff[INest])[BuffPtr[INest]]);
  end;
  GlobalUnlock(BuffHandle[INest]);
  GetRawLine := (LineLen>0) or (BuffPtr[INest]<BuffLen[INest]);
end;

function GetNewLine: BOOL;
var
  Ok: BOOL;
  b: byte;
begin
  GetNewLine := FALSE;

  repeat
    Ok := GetRawLine;
    if not Ok and (INest>0) then
      repeat
        CloseBuff(INest);
        dec(INest);
        Ok := GetRawLine;
      until Ok or (INest<=0);
    if not Ok then exit;

    b := GetFirstChar;
    dec(LinePtr);
  until (b<>0) and (b<>ord(':'));

  GetNewLine := TRUE;
end;

function RegisterLabels(IBuff: integer): BOOL;
var
  b: byte;
  LabName: TName;
  Err: word;
  VarType, VarId: word;
begin
  RegisterLabels := FALSE;
  Buff[IBuff] := GlobalLock(BuffHandle[IBuff]);
  if Buff[IBuff]=nil then exit;
  RegisterLabels := TRUE;
  BuffPtr[IBuff] := 0;

  while GetRawLine do
  begin
    Err := 0;

    b := GetFirstChar;
    if b=ord(':') then
    begin
      if GetLabelName(LabName) and (GetFirstChar=0) then
      begin
        if CheckVar(LabName,VarType,VarId) then
          Err := ErrLabelAlreadyDef
        else
          if not NewLabVar(LabName,BuffPtr[IBuff],IBuff) then
            Err := ErrTooManyLabels;
      end
      else
        Err := ErrSyntax;
    end;

    if Err>0 then DispErr(Err);
  end;
  BuffPtr[IBuff] := 0;
  GlobalUnlock(BuffHandle[IBuff]);
end;

function InitBuff(FileName: PChar): BOOL;
var
  i: integer;
begin
  SP := 0;
  NextFlag := FALSE;
  EndWhileFlag := 0;
  InitBuff := FALSE;
  for i:=0 to MAXNESTLEVEL-1 do
    BuffHandle[i] := 0;
  INest := 0;
  if not LoadMacroFile(FileName, INest) then exit;
  if not RegisterLabels(INest) then exit;
  InitBuff := TRUE;
end;

procedure CloseBuff(IBuff: integer);
var
  i: integer;
begin
  DelLabVar(IBuff);
  for i:=IBuff to MAXNESTLEVEL-1 do
  begin
    if BuffHandle[i]<>0 then
    begin
      GlobalUnlock(BuffHandle[i]);
      GlobalFree(BuffHandle[i]);
    end;
    BuffHandle[i] := 0;
  end;

  while (SP>0) and (LevelStack[SP-1]>=IBuff) do
    dec(SP);
end;

procedure JumpToLabel(ILabel: integer);
var
  Ptr: BINT;
  Level: word;
begin
  CopyLabel(ILabel, Ptr,Level);
  if Level < INest then
  begin
    INest := Level;
    CloseBuff(INest+1);
  end;
  BuffPtr[INest] := Ptr;
end;

function CallToLabel(ILabel: integer): word;
var
  Ptr: BINT;
  Level: word;
begin
  CopyLabel(ILabel, Ptr,Level);
  if Level <> INest then
  begin
    CallToLabel := ErrCantCall;
    exit;
  end;
  if SP>=MAXSP then
  begin
    CallToLabel := ErrStackOver;
    exit;
  end;
  PtrStack[SP] := BuffPtr[INest];
  LevelStack[SP] := INest;
  TypeStack[SP] := CtlCall;
  inc(SP);

  BuffPtr[INest] := Ptr;
  CallToLabel := 0;
end;

function ReturnFromSub: word;
begin
  if (SP<1) or
     (TypeStack[SP-1]<>CtlCall) then
  begin
    ReturnFromSub := ErrInvalidCtl;
    exit;
  end;

  dec(SP);
  if LevelStack[SP] < INest then
  begin
    INest := LevelStack[SP];
    CloseBuff(INest+1);
  end;
  BuffPtr[INest] := PtrStack[SP];
  ReturnFromSub := 0;
end;

function BuffInclude(FileName: PChar): BOOL;
begin
  BuffInclude := FALSE;
  if INest>=MAXNESTLEVEL-1 then exit;
  inc(INest);
  if LoadMacroFile(FileName, INest) then
  begin
    if RegisterLabels(INest) then
      BuffInclude := TRUE
    else begin
      CloseBuff(INest);
      dec(INest);
    end;
  end
  else
    dec(INest);
end;

function ExitBuffer: BOOL;
begin
  ExitBuffer := FALSE;
  if INest<1 then exit;
  CloseBuff(INest);
  dec(INest);
  ExitBuffer := TRUE;
end;

function SetForLoop: integer;
begin
  if SP>=MAXSP then
  begin
    SetForLoop := ErrStackOver;
    exit;
  end;

  PtrStack[SP] := LineStart;
  LevelStack[SP] := INest;
  TypeStack[SP] := CtlFor;
  inc(SP);
  SetForLoop := 0;
end;

procedure LastForLoop;
begin
  if (SP<1) or (TypeStack[SP-1]<>CtlFor) then exit;
  PtrStack[SP-1] := INVALIDPTR;
end;

function CheckNext: BOOL;
begin
  CheckNext := NextFlag;
  NextFlag := FALSE;
end;

function NextLoop: integer;
begin
  if (SP<1) or (TypeStack[SP-1]<>CtlFor) then
  begin
    NextLoop := ErrInvalidCtl;
    exit;
  end;
  NextFlag := PtrStack[SP-1]<>INVALIDPTR;
  NextLoop := 0;
  if not NextFlag then {exit from loop}
  begin
    dec(SP);
    exit;
  end;  
  if LevelStack[SP-1] < INest then
  begin
    INest := LevelStack[SP-1];
    CloseBuff(INest+1);
  end;
  BuffPtr[INest] := PtrStack[SP-1];
end;

function SetWhileLoop: integer;
begin
  if SP>=MAXSP then
  begin
    SetWhileLoop := ErrStackOver;
    exit;
  end;

  PtrStack[SP] := LineStart;
  LevelStack[SP] := INest;
  TypeStack[SP] := CtlWhile;
  inc(SP);
  SetWhileLoop := 0;
end;

procedure EndWhileLoop;
begin
  EndWhileFlag := 1;
end;

function BackToWhile: integer;
begin
  if (SP<1) or (TypeStack[SP-1]<>CtlWhile) then
  begin
    BackToWhile := ErrInvalidCtl;
    exit;
  end;
  dec(SP);
  if LevelStack[SP] < INest then
  begin
    INest := LevelStack[SP];
    CloseBuff(INest+1);
  end;
  BuffPtr[INest] := PtrStack[SP];
  BackToWhile := 0;
end;

end.
