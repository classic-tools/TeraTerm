{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, Clipboard routines}
unit Clipboard;

interface
{$i teraterm.inc}

uses WinTypes, WinProcs, TTTypes, TTWinMan, TTCommon;

function CBOpen(MemSize: longint): PChar;
procedure CBClose;
procedure CBStartPaste
  (HWin: HWnd; AddCR: BOOL; BuffSize: integer; DataPtr: PChar; DataSize: integer);
procedure CBSend;
procedure CBEndPaste;

implementation

var
{for clipboard copy}
  CBCopyHandle: THandle;
  CBCopyPtr: PChar;

{for clipboard paste}
  CBMemHandle: THandle;
  CBMemPtr: PChar;
  CBMemPtr2: longint;
  CBAddCR: BOOL;
  CBByte: byte;
  CBRetrySend: BOOL;
  CBRetryEcho: BOOL;
  CBSendCR: BOOL;
  CBDDE: BOOL;

function CBOpen(MemSize: longint): PChar;
begin
  CBOpen := nil;
  if MemSize=0 then exit;
  if CBCopyHandle<>0 then exit;
  CBCopyPtr := nil;
  CBCopyHandle := GlobalAlloc(GMEM_MOVEABLE, MemSize);
  if CBCopyHandle=0 then
    MessageBeep(0)
  else begin
    CBCopyPtr := GlobalLock(CBCopyHandle);
    if CBCopyPtr = nil then
    begin
      GlobalFree(CBCopyHandle);
      CBCopyHandle := 0;
      MessageBeep(0);
    end;
  end;
  CBOpen := CBCopyPtr;
end;

procedure CBClose;
var
  Empty: BOOL;
begin
  if CBCopyHandle=0 then exit;

  Empty := FALSE;
  if CBCopyPtr<>nil then
    Empty := (CBCopyPtr[0]=#0);

  GlobalUnlock(CBCopyHandle);
  CBCopyPtr := nil;

  if OpenClipboard(HVTWin) then
  begin
    EmptyClipboard;
    if not Empty then
      SetClipboardData(CF_TEXT, CBCopyHandle);
    CloseClipboard;
  end;
  CBCopyHandle := 0;
end;

procedure CBStartPaste
  (HWin: HWnd; AddCR: BOOL; BuffSize: integer; DataPtr: PChar; DataSize: integer);
{
  DataPtr and DataSize are used only for DDE
	  For clipboard, BuffSize should be 0
	  DataSize should be <= BuffSize      }
var
  Cf: integer;
begin
  if not cv.Ready then exit;
  if TalkStatus<>IdTalkKeyb then exit;

  CBAddCR := AddCR;

  if BuffSize=0 then {for clipboard}
  begin
    if IsClipboardFormatAvailable(CF_TEXT) then
      Cf := CF_TEXT
    else if IsClipboardFormatAvailable(CF_OEMTEXT) then
      Cf := cf_OEMText
    else exit;
  end;

  CBMemHandle := 0;
  CBMemPtr := nil;
  CBDDE := FALSE;
  if BuffSize=0 then {for clipboard}
  begin
    if OpenClipboard(HWin) then
      CBMemHandle := GetClipboardData(Cf);
    if CBMemHandle <> 0 then TalkStatus := IdTalkCB;
  end
  else begin {dde}
    CBMemHandle := GlobalAlloc(GHND,BuffSize);
    if CBMemHandle <> 0 then
    begin
      CBDDE := TRUE;
      CBMemPtr := GlobalLock(CBMemHandle);
      if CBMemPtr<>nil then
      begin
        move(DataPtr[0],CBMemPtr[0],DataSize);
        GlobalUnlock(CBMemHandle);
        CBMemPtr := nil;
        TalkStatus := IdTalkCB;
      end;
    end;
  end;
  CBRetrySend := FALSE;
  CBRetryEcho := FALSE;
  CBSendCR := FALSE;
  if TalkStatus <> IdTalkCB then CBEndPaste;
end;

procedure CBSend;
var
  c: integer;
  EndFlag: BOOL;
begin
  if CBMemHandle=0 then exit;

  if CBRetrySend then
  begin
    CBRetryEcho := ts.LocalEcho>0;
    c := CommTextOut(@cv,@CBByte,1);
    CBRetrySend := c=0;
    if CBRetrySend then exit;
  end;

  if CBRetryEcho then
  begin
    c := CommTextEcho(@cv,@CBByte,1);
    CBRetryEcho := c=0;
    if CBRetryEcho then exit;
  end;

  CBMemPtr := GlobalLock(CBMemHandle);
  if CBMemPtr=nil then exit;

  repeat
    if CBSendCR and (CBMemPtr[CBMemPtr2]=#$0A) then
      inc(CBMemPtr2);

    EndFlag := CBMemPtr[CBMemPtr2]=#0;

    if not EndFlag then
    begin
      CBByte := byte(CBMemPtr[CBMemPtr2]);
      inc(CBMemPtr2);
{ Decoding characters which are encoded by TTMACRO
   to support NUL character sending

  [encoded character] --> [decoded character]
         01 01        -->     00
         01 02        -->     01               }
      if CBByte=$01 then {01 from TTMACRO}
      begin
        CBByte := byte(CBMemPtr[CBMemPtr2]);
        inc(CBMemPtr2);
        CBByte := CBByte - 1; {character just after $01}
      end;
    end
    else if CBAddCR then
    begin
      EndFlag := FALSE;
      CBAddCR := FALSE;
      CBByte := $0d;
    end
    else begin
      CBEndPaste;
      exit;
    end;

    if not EndFlag then
    begin
      c := CommTextOut(@cv,@CBByte,1);
      CBSendCR := CBByte=$0D;
      CBRetrySend := c=0;
      if not CBRetrySend and
         (ts.LocalEcho>0) then
      begin
        c := CommTextEcho(@cv,@CBByte,1);
        CBRetryEcho := c=0;
      end;
    end
    else
      c := 0;
  until c<=0;

  if CBMemPtr<>nil then
  begin
    GlobalUnlock(CBMemHandle);
    CBMemPtr := nil;
  end;
end;

procedure CBEndPaste;
begin
  TalkStatus := IdTalkKeyb;

  if CBMemHandle<>0 then
  begin
    if CBMemPtr<>nil then
      GlobalUnlock(CBMemHandle);
    if CBDDE then
      GlobalFree(CBMemHandle);
  end;
  if not CBDDE then CloseClipboard;

  CBDDE := FALSE;
  CBMemHandle := 0;
  CBMemPtr := nil;
  CBMemPtr2 := 0;
  CBAddCR := FALSE;
end;

{initialization}
begin
  CBCopyHandle := 0;
  CBCopyPtr := nil;
  CBMemHandle := 0;
  CBMemPtr := nil;
  CBMemPtr2 := 0;
  CBAddCR := FALSE;
end.
