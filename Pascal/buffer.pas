{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, scroll buffer routines}
unit Buffer;

interface
{$I teraterm.inc}

{$IFDEF Delphi}
uses WinTypes, WinProcs, OWindows, SysUtils,
  TTTypes, TTWinMan, VTDisp,
  Clipboard, TeraPrn, Telnet, TTPlug;
{$ELSE}
uses WinTypes, WinProcs, WObjects, Strings, TTTypes, TTWinMan, VTDisp,
  Clipboard, TeraPrn, Telnet, TTPlug;
{$ENDIF}

var
  StatusLine: integer;
  CursorTop, CursorBottom: integer;
  Selected: bool;
  Wrap: bool;

procedure InitBuffer;
procedure LockBuffer;
procedure UnlockBuffer;
procedure FreeBuffer;
procedure BuffReset;
procedure BuffScroll(Count, Bottom: integer);
procedure BuffInsertSpace(Count: integer);
procedure BuffEraseCurToEnd;
procedure BuffEraseHomeToCur;
procedure BuffInsertLines(Count, YEnd: integer);
procedure BuffEraseCharsInLine(XStart, Count: integer);
procedure BuffDeleteLines(Count, YEnd: integer);
procedure BuffDeleteChars(Count: integer);
procedure BuffEraseChars(Count: integer);
procedure BuffFillWithE;
procedure BuffDrawLine(Attr, Attr2 : byte; Direction, C: integer);
procedure BuffEraseBox(XStart, YStart, XEnd, YEnd: integer);
procedure BuffCBCopy(Table: BOOL);
procedure BuffPrint(ScrollRegion: BOOL);
procedure BuffDumpCurrentLine(TERM: byte);
procedure BuffPutChar(b, Attr, Attr2: byte; Insert: bool);
procedure BuffPutKanji(w: WORD; Attr, Attr2: byte; Insert: bool);
procedure BuffUpdateRect(XStart, YStart, XEnd, YEnd: integer);
procedure UpdateStr;
procedure MoveCursor(Xnew, Ynew: integer);
procedure MoveRight;
procedure BuffSetCaretWidth;
procedure BuffScrollNLines(n: integer);
procedure BuffClearScreen;
procedure BuffUpdateScroll;
procedure CursorUpWithScroll;
procedure BuffDblClk(Xw, Yw: integer);
procedure BuffTplClk(Yw: integer);
procedure BuffStartSelect(Xw, Yw: integer; Box: bool);
procedure BuffChangeSelect(Xw, Yw, NClick: integer);
procedure BuffEndSelect;
procedure BuffChangeWinSize(Nx, Ny: integer);
procedure BuffChangeTerminalSize(Nx, Ny: integer);
procedure ChangeWin;
procedure ClearBuffer;
procedure SetTabStop;
procedure MoveToNextTab;
procedure ClearTabStop(Ps: integer);
procedure ShowStatusLine(Show: integer);

implementation
const
  BuffXMax = 300;
{$ifdef TERATERM32}
  BuffYMax = 100000;
  BuffSizeMax = 8000000;
{$else}
  BuffYMax = 800;
  BuffSizeMax: longint = 65535;
{$endif}

var
  TabStops: array[0..255] of word;
  NTabStops: integer;

  BuffLock: word;
  HCodeBuff, HAttrBuff, HAttrBuff2: THandle;

  CodeBuff: PChar; {Character code buffer}
  AttrBuff: PChar; {Attribute buffer}
  AttrBuff2: PChar; {Color attr buffer}
  CodeLine: PChar;
  AttrLine: PChar;
  AttrLine2: PChar;
  LinePtr: longint;
  BufferSize: longint;
  NumOfLinesInBuff: integer;
  BuffStartAbs, BuffEndAbs: integer;
  SelectStart, SelectEnd, SelectEndOld: TPoint;
  BoxSelect: bool;
  DblClkStart, DblClkEnd: TPoint;

  StrChangeStart, StrChangeCount: integer;


function GetLinePtr(Line: integer): longint;
var
  Ptr: longint;
begin
{$ifdef TERATERM32}
  Ptr := longint(BuffStartAbs + Line) *
         longint(NumOfColumns);
{$else}
  Ptr := longmul(BuffStartAbs + Line, NumOfColumns);
{$endif}
  while Ptr>= BufferSize do
    Ptr := Ptr - BufferSize;
  GetLinePtr := Ptr;
end;

function NextLinePtr(Ptr: longint): longint;
begin
  Ptr := Ptr + longint(NumOfColumns);
  if Ptr >= BufferSize then Ptr := Ptr - BufferSize; 
  NextLinePtr := Ptr;
end;

function PrevLinePtr(Ptr: longint): longint;
begin
  Ptr := Ptr - longint(NumOfColumns);
  if Ptr < 0 then Ptr := Ptr + BufferSize;
  PrevLinePtr := Ptr;
end;

function ChangeBuffer(Nx, Ny: integer): bool;
var
  HCodeNew, HAttrNew, HAttr2New: THandle;
  NewSize: longint;
  NxCopy, NyCopy, i: integer;
  CodeDest, AttrDest, AttrDest2: PChar;
  Ptr: PChar;
  SrcPtr, DestPtr: longint;
  LockOld: word;
begin
  ChangeBuffer := FALSE;

  if Nx > BuffXMax then Nx := BuffXMax;
  if ts.ScrollBuffMax > BuffYMax then
    ts.ScrollBuffMax := BuffYMax;
  if Ny > ts.ScrollBuffMax then Ny := ts.ScrollBuffMax;
 
{$ifdef TERATERM32}
  if Nx*Ny > BuffSizeMax then
{$else}
  if longmul(Nx,Ny) > BuffSizeMax then
{$endif}
    Ny := BuffSizeMax div Nx;

{$ifdef TERATERM32}
  NewWize := Nx * Ny;
{$else}
  NewSize := longmul(Nx,Ny);
{$endif}

  HCodeNew := GlobalAlloc(GMEM_MOVEABLE, NewSize);
  if HCodeNew=0 then exit;
  Ptr := GlobalLock(HCodeNew);
  if Ptr=nil then
  begin
    GlobalFree(HCodeNew);
    exit;
  end;
  CodeDest := Ptr;

  HAttrNew := GlobalAlloc(GMEM_MOVEABLE, NewSize);
  if HAttrNew=0 then
  begin
    GlobalFree(HCodeNew);
    exit;
  end;
  Ptr := GlobalLock(HAttrNew);
  if Ptr=nil then
  begin
    GlobalFree(HCodeNew);
    GlobalFree(HAttrNew);
    exit;
  end;
  AttrDest := PChar(Ptr);

  HAttr2New := GlobalAlloc(GMEM_MOVEABLE, NewSize);
  if HAttr2New=0 then
  begin
    GlobalFree(HCodeNew);
    GlobalFree(HAttrNew);
    exit;
  end;
  Ptr := GlobalLock(HAttr2New);
  if Ptr=nil then
  begin
    GlobalFree(HCodeNew);
    GlobalFree(HAttrNew);
    GlobalFree(HAttr2New);
    exit;
  end;
  AttrDest2 := Ptr;

  FillChar(CodeDest[0], word(NewSize), $20);
  FillChar(AttrDest[0], word(NewSize), AttrDefault);
  FillChar(AttrDest2[0], word(NewSize), AttrDefault2);

  if HCodeBuff<>0 then
  begin
    if NumOfColumns > Nx then NxCopy := Nx
                         else NxCopy := NumOfColumns;
    if BuffEnd > Ny then NyCopy := Ny
                    else NyCopy := BuffEnd;
    LockOld := BuffLock;
    LockBuffer;
    SrcPtr := GetLinePtr(BuffEnd-NyCopy);
    DestPtr := 0;
    for i := 1 to NyCopy do
    begin
      Move(CodeBuff[SrcPtr], CodeDest[DestPtr], NxCopy);
      Move(AttrBuff[SrcPtr], AttrDest[DestPtr], NxCopy);
      Move(AttrBuff2[SrcPtr], AttrDest2[DestPtr], NxCopy);
      SrcPtr := NextLinePtr(SrcPtr);
      DestPtr := DestPtr + longint(Nx);
    end;
    FreeBuffer;
  end
  else begin
    LockOld := 0;
    NyCopy := NumOfLines;
    Selected := FALSE;
  end;

  if Selected then
  begin
    SelectStart.y := SelectStart.y - BuffEnd + NyCopy;
    SelectEnd.y := SelectEnd.y - BuffEnd + NyCopy;
    if SelectStart.y < 0 then
    begin
      SelectStart.y := 0;
      SelectStart.x := 0;
    end;
    if SelectEnd.y < 0 then
    begin
      SelectEnd.x := 0;
      SelectEnd.y := 0;
    end;

    Selected := (SelectEnd.y > SelectStart.y) or
              ((SelectEnd.y=SelectStart.y) and
               (SelectEnd.x > SelectStart.x));
  end;

  HCodeBuff := HCodeNew;
  HAttrBuff := HAttrNew;
  HAttrBuff2 := HAttr2New;
  BufferSize := NewSize;
  NumOfLinesInBuff := Ny;
  BuffStartAbs := 0;
  BuffEnd := NyCopy;

  if BuffEnd=NumOfLinesInBuff then
    BuffEndAbs := 0
  else
    BuffEndAbs := BuffEnd;

  PageStart := BuffEnd - NumOfLines;

  LinePtr := 0;
  if LockOld>0 then
  begin
    CodeBuff := PChar(GlobalLock(HCodeBuff));
    AttrBuff := PChar(GlobalLock(HAttrBuff));
    AttrBuff2 := PChar(GlobalLock(HAttrBuff2));
    CodeLine := CodeBuff;
    AttrLine := AttrBuff;
    AttrLine2 := AttrBuff2;
  end
  else begin
    GlobalUnlock(HCodeNew);
    GlobalUnlock(HAttrNew);
  end;
  BuffLock := LockOld;

  ChangeBuffer := TRUE;
end;

procedure InitBuffer;
var
  Ny: integer;
begin
  {setup terminal}
  NumOfColumns := ts.TerminalWidth;
  NumOfLines := ts.TerminalHeight;

  {setup window}
  if ts.EnableScrollBuff>0 then
  begin
    if ts.ScrollBuffSize < NumOfLines then
      ts.ScrollBuffSize := NumOfLines;
    Ny := ts.ScrollBuffSize;
  end
  else
    Ny := NumOfLines;

  if not ChangeBuffer(NumOfColumns,Ny) then
    PostQuitMessage(0);

  if ts.EnableScrollBuff>0 then
    ts.ScrollBuffSize := NumOfLinesInBuff;

  StatusLine := 0;
end;

procedure NewLine(Line: integer);
begin
  LinePtr := GetLinePtr(Line);
  CodeLine := @CodeBuff[LinePtr];
  AttrLine := @AttrBuff[LinePtr];
  AttrLine2 := @AttrBuff2[LinePtr];
end;

procedure LockBuffer;
begin
  inc(BuffLock);
  if BuffLock>1 then exit;
  CodeBuff := PChar(GlobalLock(HCodeBuff));
  AttrBuff := PChar(GlobalLock(HAttrBuff));
  AttrBuff2 := PChar(GlobalLock(HAttrBuff2));
  NewLine(PageStart+CursorY);
end;

procedure UnlockBuffer;
begin
  if BuffLock=0 then exit;
  dec(BuffLock);
  if BuffLock>0 then exit;
  if HCodeBuff<>0 then
    GlobalUnlock(HCodeBuff);
  if HAttrBuff<>0 then
    GlobalUnlock(HAttrBuff);
  if HAttrBuff2<>0 then
    GlobalUnlock(HAttrBuff2);
end;

procedure FreeBuffer;
begin
  BuffLock := 1;
  UnlockBuffer;
  if HCodeBuff<>0 then
  begin
    GlobalFree(HCodeBuff);
    HCodeBuff := 0;
  end;
  if HAttrBuff<>0 then
  begin
    GlobalFree(HAttrBuff);
    HAttrBuff := 0;
  end;
  if HAttrBuff2<>0 then
  begin
    GlobalFree(HAttrBuff2);
    HAttrBuff2 := 0;
  end;
end;

procedure BuffReset;
{ Reset buffer status. don't update real display
   called by ResetTerminal }
var
  i: integer;
begin
  {Cursor}
  NewLine(PageStart);
  WinOrgX := 0;
  WinOrgY := 0;
  NewOrgX := 0;
  NewOrgY := 0;

  {Top/bottom margin}
  CursorTop := 0;
  CursorBottom := NumOfLines-1;

  {Tab stops}
  NTabStops := (NumOfColumns-1) shr 3;
  for i := 1 to NTabStops do
    TabStops[i-1] := i*8;

  {Initialize text selection region}
  SelectStart.x := 0;
  SelectStart.y := 0;
  SelectEnd := SelectStart;
  SelectEndOld := SelectStart;
  Selected := FALSE;

  StrChangeCount := 0;
  Wrap := FALSE;
  StatusLine := 0;
end;

procedure BuffScroll(Count, Bottom: integer);
var
  i, n: integer;
  SrcPtr, DestPtr: longint;
  BuffEndOld: integer;
begin
  if Count>NumOfLinesInBuff then
    Count := NumOfLinesInBuff;

  DestPtr := GetLinePtr(PageStart+NumOfLines-1+Count);
  n := Count;
  if Bottom<NumOfLines-1 then
  begin
    SrcPtr := GetLinePtr(PageStart+NumOfLines-1);
    for i := NumOfLines-1 downto Bottom+1 do
    begin
      Move(CodeBuff[SrcPtr],CodeBuff[DestPtr],NumOfColumns);
      Move(AttrBuff[SrcPtr],AttrBuff[DestPtr],NumOfColumns);
      Move(AttrBuff2[SrcPtr],AttrBuff2[DestPtr],NumOfColumns);
      FillChar(CodeBuff[SrcPtr],NumOfColumns,$20);
      FillChar(AttrBuff[SrcPtr],NumOfColumns,AttrDefault);
      FillChar(AttrBuff2[SrcPtr],NumOfColumns,AttrDefault2);
      SrcPtr := PrevLinePtr(SrcPtr);
      DestPtr := PrevLinePtr(DestPtr);
      dec(n);
    end;
  end;
  for i := 1 to n do
  begin
    FillChar(CodeBuff[DestPtr],NumOfColumns,$20);
    FillChar(AttrBuff[DestPtr],NumOfColumns,AttrDefault);
    FillChar(AttrBuff2[DestPtr],NumOfColumns,AttrDefault2);
    DestPtr := PrevLinePtr(DestPtr);
  end;

  BuffEndAbs := BuffEndAbs + Count;
  if BuffEndAbs >= NumOfLinesInBuff then
    BuffEndAbs := BuffEndAbs - NumOfLinesInBuff;
  BuffEndOld := BuffEnd;
  BuffEnd := BuffEnd + Count;
  if BuffEnd >= NumOfLinesInBuff then
  begin
    BuffEnd := NumOfLinesInBuff;
    BuffStartAbs := BuffEndAbs;
  end;
  PageStart := BuffEnd-NumOfLines;

  if Selected then
  begin
    SelectStart.y := SelectStart.y - Count + BuffEnd - BuffEndOld;
    SelectEnd.y := SelectEnd.y - Count + BuffEnd - BuffEndOld;
    if SelectStart.y<0 then
    begin
      SelectStart.x := 0;
      SelectStart.y := 0;
    end;
    if SelectEnd.y<0 then
    begin
      SelectEnd.x := 0;
      SelectEnd.y := 0;
    end;
    Selected :=
      (SelectEnd.y > SelectStart.y) or
      ((SelectEnd.y = SelectStart.y) and
       (SelectEnd.x > SelectStart.x));
  end;

  NewLine(PageStart+CursorY);
end;

procedure NextLine;
begin
  LinePtr := NextLinePtr(LinePtr);
  CodeLine := @CodeBuff[LinePtr];
  AttrLine := @AttrBuff[LinePtr];
  AttrLine2 := @AttrBuff2[LinePtr];
end;

procedure PrevLine;
begin
  LinePtr := PrevLinePtr(LinePtr);
  CodeLine := @CodeBuff[LinePtr];
  AttrLine := @AttrBuff[LinePtr];
  AttrLine2 := @AttrBuff2[LinePtr];
end;

procedure EraseKanji(LR: integer);
begin
{If cursor is on left/right half of a Kanji, erase it.
   LR: left(0)/right(1) flag }

  if (CursorX-LR >= 0) and
     (byte(AttrLine[CursorX-LR]) and AttrKanji <> 0) then
  begin
    CodeLine[CursorX-LR] := #$20;
    AttrLine[CursorX-LR] := char(AttrDefault);
    AttrLine2[CursorX-LR] := char(AttrDefault2);
    if CursorX-LR+1 < NumOfColumns then
    begin
      CodeLine[CursorX-LR+1] := #$20;
      AttrLine[CursorX-LR+1] := char(AttrDefault);
      AttrLine2[CursorX-LR+1] := char(AttrDefault2);
    end;
  end;
end;

procedure BuffInsertSpace(Count: integer);
{ Insert space characters at the current position
   Count: Number of characters to be inserted }
begin
  NewLine(PageStart+CursorY);

  if ts.Language=IdJapanese then
    EraseKanji(1); {if cursor is on right half of a kanji, erase the kanji}

  if Count > NumOfColumns - CursorX then
    Count := NumOfColumns - CursorX;

  Move(CodeLine[CursorX],CodeLine[CursorX+Count],
       NumOfColumns-Count-CursorX);
  Move(AttrLine[CursorX],AttrLine[CursorX+Count],
       NumOfColumns-Count-CursorX);
  Move(AttrLine2[CursorX],AttrLine2[CursorX+Count],
       NumOfColumns-Count-CursorX);
  FillChar(CodeLine[CursorX],Count,$20);
  FillChar(AttrLine[CursorX],Count,AttrDefault);
  FillChar(AttrLine2[CursorX],Count,AttrDefault2);
  {last char in current line is kanji first?}
  if byte(AttrLine[NumOfColumns-1]) and AttrKanji <> 0 then
  begin
    {then delete it}
    CodeLine[NumOfColumns-1] := #$20;
    AttrLine[NumOfColumns-1] := char(AttrDefault);
    AttrLine2[NumOfColumns-1] := char(AttrDefault2);
  end;
  BuffUpdateRect(CursorX,CursorY,NumOfColumns-1,CursorY);
end;

procedure BuffEraseCurToEnd;
{Erase characters from cursor to the end of screen}
var
  TmpPtr: longint;
  offset: integer;
  i, YEnd: integer;
begin
  NewLine(PageStart+CursorY);
  if ts.Language=IdJapanese then
    EraseKanji(1); {if cursor is on right half of a kanji, erase the kanji}
  offset := CursorX;
  TmpPtr := GetLinePtr(PageStart+CursorY);
  YEnd := NumOfLines-1;
  if (StatusLine>0) and
     (CursorY<NumOfLines-1) then
    dec(YEnd);
  for i := CursorY to YEnd do
  begin
    FillChar(CodeBuff[TmpPtr+offset],NumOfColumns-offset,$20);
    FillChar(AttrBuff[TmpPtr+offset],NumOfColumns-offset,AttrDefault);
    FillChar(AttrBuff2[TmpPtr+offset],NumOfColumns-offset,AttrDefault2);
    offset := 0;
    TmpPtr := NextLinePtr(TmpPtr);
  end;
  {update window}
  DispEraseCurToEnd(YEnd);
end;

procedure BuffEraseHomeToCur;
{Erase characters from home to cursor}
var
  TmpPtr: longint;
  offset: integer;
  i, YHome: integer;
begin
  NewLine(PageStart+CursorY);
  if ts.Language=IdJapanese then
    EraseKanji(0); {if cursor is on left half of a kanji, erase the kanji}
  offset := NumOfColumns;
  if (StatusLine>0) and (CursorY=NumOfLines-1) then
    YHome := CursorY
  else
    YHome := 0;
  TmpPtr := GetLinePtr(PageStart+YHome);
  for i := YHome to CursorY do
  begin
    if i=CursorY then offset := CursorX+1;
    FillChar(CodeBuff[TmpPtr],offset,$20);
    FillChar(AttrBuff[TmpPtr],offset,AttrDefault);
    FillChar(AttrBuff2[TmpPtr],offset,AttrDefault2);
    TmpPtr := NextLinePtr(TmpPtr);
  end;

  {update window}
  DispEraseHomeToCur(YHome);
end;

procedure BuffInsertLines(Count, YEnd: integer);
{ Insert lines at current position
   Count: number of lines to be inserted
   YEnd: bottom line number of scroll region (screen coordinate)}
var
  i: integer;
  SrcPtr, DestPtr: longint;
begin
  BuffUpdateScroll;

  SrcPtr := GetLinePtr(PageStart+YEnd-Count);
  DestPtr := GetLinePtr(PageStart+YEnd);
  for i := YEnd-Count downto CursorY do
  begin
    Move(CodeBuff[SrcPtr],CodeBuff[DestPtr],NumOfColumns);
    Move(AttrBuff[SrcPtr],AttrBuff[DestPtr],NumOfColumns);
    Move(AttrBuff2[SrcPtr],AttrBuff2[DestPtr],NumOfColumns);
    SrcPtr := PrevLinePtr(SrcPtr);
    DestPtr := PrevLinePtr(DestPtr);
  end;
  for i := 1 to Count do
  begin
    FillChar(CodeBuff[DestPtr],NumOfColumns,$20);
    FillChar(AttrBuff[DestPtr],NumOfColumns,AttrDefault);
    FillChar(AttrBuff2[DestPtr],NumOfColumns,AttrDefault2);
    DestPtr := PrevLinePtr(DestPtr);
  end;

  if not DispInsertLines(Count,YEnd) then
    BuffUpdateRect(WinOrgX,CursorY,WinOrgX+WinWidth-1,YEnd);
end;

procedure BuffEraseCharsInLine(XStart, Count: integer);
{ erase characters in the current line
  XStart: start position of erasing
  Count: number of characters to be erased}
begin
  if ts.Language=IdJapanese then
    EraseKanji(1); {if cursor is on right half of a kanji, erase the kanji}

  NewLine(PageStart+CursorY);
  FillChar(CodeLine[XStart],Count,$20);
  FillChar(AttrLine[XStart],Count,AttrDefault);
  FillChar(AttrLine2[XStart],Count,AttrDefault2);

  DispEraseCharsInLine(XStart, Count);
end;

procedure BuffDeleteLines(Count, YEnd: integer);
{ Delete lines from current line
   Count: number of lines to be deleted
   YEnd: bottom line number of scroll region (screen coordinate)}
var
  i: integer;
  SrcPtr, DestPtr: longint;
begin
  BuffUpdateScroll;

  SrcPtr := GetLinePtr(PageStart+CursorY+Count);
  DestPtr := GetLinePtr(PageStart+CursorY);
  for i := CursorY to YEnd-Count do
  begin
    Move(CodeBuff[SrcPtr],CodeBuff[DestPtr],NumOfColumns);
    Move(AttrBuff[SrcPtr],AttrBuff[DestPtr],NumOfColumns);
    Move(AttrBuff2[SrcPtr],AttrBuff2[DestPtr],NumOfColumns);
    SrcPtr := NextLinePtr(SrcPtr);
    DestPtr := NextLinePtr(DestPtr);
  end;
  for i := YEnd+1-Count to YEnd do
  begin
    FillChar(CodeBuff[DestPtr],NumOfColumns,$20);
    FillChar(AttrBuff[DestPtr],NumOfColumns,AttrDefault);
    FillChar(AttrBuff2[DestPtr],NumOfColumns,AttrDefault2);
    DestPtr := NextLinePtr(DestPtr);
  end;

  if not DispDeleteLines(Count,YEnd) then
    BuffUpdateRect(WinOrgX,CursorY,WinOrgX+WinWidth-1,YEnd);
end;

procedure BuffDeleteChars(Count: integer);
{ Delete characters in current line from cursor
   Count: number of characters to be deleted}
begin
  NewLine(PageStart+CursorY);

  if ts.Language=IdJapanese then
  begin
    EraseKanji(0); {if cursor is on left harf of a kanji, erase the kanji}
    EraseKanji(1); {if cursor on right half...}
  end;

  if Count > NumOfColumns-CursorX then
    Count := NumOfColumns-CursorX;

  Move(CodeLine[CursorX+Count],CodeLine[CursorX],
       NumOfColumns-Count-CursorX);
  Move(AttrLine[CursorX+Count],AttrLine[CursorX],
       NumOfColumns-Count-CursorX);
  Move(AttrLine2[CursorX+Count],AttrLine2[CursorX],
       NumOfColumns-Count-CursorX);
  FillChar(CodeLine[NumOfColumns-Count],Count,$20);
  FillChar(AttrLine[NumOfColumns-Count],Count,AttrDefault);
  FillChar(AttrLine2[NumOfColumns-Count],Count,AttrDefault2);

  BuffUpdateRect(CursorX,CursorY,WinOrgX+WinWidth-1,CursorY);
end;

procedure BuffEraseChars(Count: integer);
{ Erase characters in current line from cursor
   Count: number of characters to be deleted }
begin
  NewLine(PageStart+CursorY);

  if ts.Language=IdJapanese then
  begin
    EraseKanji(0); {if cursor is on left harf of a kanji, erase the kanji}
    EraseKanji(1); {if cursor on right half...}
  end;

  if Count > NumOfColumns-CursorX then
    Count := NumOfColumns-CursorX;
  FillChar(CodeLine[CursorX],Count,$20);
  FillChar(AttrLine[CursorX],Count,AttrDefault);
  FillChar(AttrLine2[CursorX],Count,AttrDefault2);

  {update window}
  DispEraseCharsInLine(CursorX,Count);
end;

procedure BuffFillWithE;
{Fill screen with 'E' characters}
var
  TmpPtr: longint;
  i: integer;
begin
  TmpPtr := GetLinePtr(PageStart);
  for i := 0 to NumOfLines-1-StatusLine do
  begin
    FillChar(CodeBuff[TmpPtr],NumOfColumns,'E');
    FillChar(AttrBuff[TmpPtr],NumOfColumns,AttrDefault);
    FillChar(AttrBuff2[TmpPtr],NumOfColumns,AttrDefault2);
    TmpPtr := NextLinePtr(TmpPtr);
  end;
  BuffUpdateRect(WinOrgX,WinOrgY,WinOrgX+WinWidth-1,WinOrgY+WinHeight-1);
end;

procedure BuffDrawLine(Attr, Attr2 : byte; Direction, C: integer);
{IO-8256 terminal}
var
  Ptr: longint;
  i, X, Y: integer;
begin
  if C=0 then exit;
  Attr := Attr or AttrSpecial;

  case Direction of
    3..4: begin
      if Direction=3 then
      begin
        if CursorY=0 then exit;
	Y := CursorY-1;
      end
      else begin
        if CursorY=NumOfLines-1-StatusLine then exit;
	Y := CursorY+1;
      end;
      if CursorX+C > NumOfColumns then
        C := NumOfColumns-CursorX;
      Ptr := GetLinePtr(PageStart+Y);
      FillChar(CodeBuff[Ptr+CursorX],C,'q');
      FillChar(AttrBuff[Ptr+CursorX],C,Attr);
      FillChar(AttrBuff2[Ptr+CursorX],C,Attr2);
      BuffUpdateRect(CursorX,Y,CursorX+C-1,Y);
    end;
    5..6: begin
      if Direction=5 then
      begin
        if CursorX=0 then exit;
	X := CursorX - 1;
      end
      else begin
        if CursorX=NumOfColumns-1 then
	  X := CursorX-1
	else
	  X := CursorX+1;
      end;
      Ptr := GetLinePtr(PageStart+CursorY);
      if CursorY+C > NumOfLines-StatusLine then
        C := NumOfLines-StatusLine-CursorY;
      for i := 1 to C do
      begin
        CodeBuff[Ptr+X] := 'x';
	AttrBuff[Ptr+X] := char(Attr);
	AttrBuff2[Ptr+X] := char(Attr2);
	Ptr := NextLinePtr(Ptr);
      end;
      BuffUpdateRect(X,CursorY,X,CursorY+C-1);
    end;
  end;	  
end;

procedure BuffEraseBox(XStart, YStart, XEnd, YEnd: integer);
{IO-8256 terminal}
var
  C, i: integer;
  Ptr: longint;
begin
  if XEnd>NumOfColumns-1 then
    XEnd := NumOfColumns-1;
  if YEnd>NumOfLines-1-StatusLine then
    YEnd := NumOfLines-1-StatusLine;
  if XStart>XEnd then exit;
  if YStart>YEnd then exit;
  C := XEnd-XStart+1;
  Ptr := GetLinePtr(PageStart+YStart);
  for i :=YStart to YEnd do
  begin
    if (XStart>0) and
       (byte(AttrBuff[Ptr+XStart-1]) and AttrKanji <> 0) then
    begin
      CodeBuff[Ptr+XStart-1] := char($20);
      AttrBuff[Ptr+XStart-1] := char(AttrDefault);
      AttrBuff2[Ptr+XStart-1] := char(AttrDefault2);
    end;
    if (XStart+C<NumOfColumns) and
       (byte(AttrBuff[Ptr+XStart+C-1]) and AttrKanji <> 0) then
    begin
      CodeBuff[Ptr+XStart+C] := char($20);
      AttrBuff[Ptr+XStart+C] := char(AttrDefault);
      AttrBuff2[Ptr+XStart+C] := char(AttrDefault2);
    end;
    FillChar(CodeBuff[Ptr+XStart],C,$20);
    FillChar(AttrBuff[Ptr+XStart],C,AttrDefault);
    FillChar(AttrBuff2[Ptr+XStart],C,AttrDefault2);
    Ptr := NextLinePtr(Ptr);
  end;
  BuffUpdateRect(XStart,YStart,XEnd,YEnd);
end;

function LeftHalfOfDBCS(Line: longint; CharPtr: integer): integer;
{ If CharPtr is on the right half of a DBCS character,
 return pointer to the left half
   Line: points to a line in CodeBuff
   CharPtr: points to a char
   return: points to the left half of the DBCS }
begin
  if (CharPtr>0) and
     (byte(AttrBuff[Line+CharPtr-1]) and AttrKanji <> 0) then
    dec(CharPtr);
  LeftHalfOfDBCS := CharPtr;
end;

function MoveCharPtr(Line: longint; var x: integer; dx: integer): integer;
{ move character pointer x by dx character unit
   in the line specified by Line
   Line: points to a line in CodeBuff
   x: points to a character in the line
   dx: moving distance in character unit (-: left, +: right)
		One DBCS character is counted as one character.
      The pointer stops at the beginning or the end of line.
 Output
   x: new pointer. x points to a SBCS character or
      the left half of a DBCS character.
   return: actual moving distance in character unit }
var
  i: integer;
begin
  x := LeftHalfOfDBCS(Line,x);
  i := 0;
  while dx<>0 do
  begin
    if dx>0 then {move right}
    begin
      if byte(AttrBuff[Line+x]) and AttrKanji <> 0 then
      begin
        if x<NumOfColumns-2 then
	begin
	  inc(i);
	  x := x + 2;
	end;
      end
      else if x<NumOfColumns-1 then
      begin
        inc(i);
	inc(x);
      end;
      dec(dx);
    end
    else begin {move left}
      if x>0 then
      begin
        dec(i);
	dec(x);
      end;
      x := LeftHalfOfDBCS(Line,x);
      inc(dx);
    end;
  end;
  MoveCharPtr := i;
end;

procedure BuffCBCopy(Table: BOOL);
{ copy selected text to clipboard}
var
  MemSize: longint;
  CBPtr: PChar;
  TmpPtr: longint;
  i, j, k, IStart, IEnd: integer;
  Sp, FirstChar: bool;
  b: byte;
begin
  if TalkStatus=IdTalkCB then exit;
  if not Selected then exit;

{--- open clipboard and get CB memory}
  if BoxSelect then
    MemSize := (SelectEnd.x-SelectStart.x+3)*
               (SelectEnd.y-SelectStart.y+1) + 1
  else
    MemSize := (SelectEnd.y-SelectStart.y)*
               (NumOfColumns+2) +
               SelectEnd.x - SelectStart.x + 1;
  CBPtr := CBOpen(MemSize);
  if CBPtr=nil then exit;

{ --- copy selected text to CB memory}
  LockBuffer;

  CBPtr[0] := #0;
  TmpPtr := GetLinePtr(SelectStart.y);
  k := 0;
  for j := SelectStart.y to SelectEnd.y do
  begin
    if BoxSelect then
    begin
      IStart := SelectStart.x;
      IEnd := SelectEnd.x-1;
    end
    else begin
      IStart := 0;
      IEnd := NumOfColumns-1;
      if j=SelectStart.y then IStart := SelectStart.x;
      if j=SelectEnd.y then IEnd := SelectEnd.x-1;
    end;
    i := LeftHalfOfDBCS(TmpPtr,IStart);
    if i<>IStart then
    begin
      if j=SelectStart.y then
        IStart := i
      else
        IStart := i + 2;
    end;

    {exclude right-side space characters}
    IEnd := LeftHalfOfDBCS(TmpPtr,IEnd);
    while (IEnd>0) and (CodeBuff[TmpPtr+IEnd]=#$20) do
      MoveCharPtr(TmpPtr,IEnd,-1);
    if (IEnd=0) and (CodeBuff[TmpPtr]=#$20) then
      IEnd := -1
    else if byte(AttrBuff[TmpPtr+IEnd]) and AttrKanji <> 0 then {DBCS first byte?}
      inc(IEnd);

    Sp := FALSE;
    FirstChar := TRUE;
    i := IStart;
    while i <= IEnd do
    begin
      b := byte(CodeBuff[TmpPtr+i]);
      inc(i);
      if not Sp then
      begin
        if Table and (b<=$20) then
	begin
	  Sp := TRUE;
	  b := $09;
	end;
	if (b<>$09) or (not FirstChar) then
	begin
	  FirstChar := FALSE;
	  CBPtr[k] := char(b);
	  inc(k);
	end;
      end
      else begin
        if b>$20 then
	begin
	  Sp := FALSE;
	  FirstChar := FALSE;
	  CBPtr[k] := char(b);
	  inc(k);
	end;
      end;
    end;

    if j < SelectEnd.y then
    begin
      CBPtr[k] := #$0d;
      inc(k);
      CBPtr[k] := #$0a;
      inc(k);
    end;

    TmpPtr := NextLinePtr(TmpPtr);
  end;
  CBPtr[k] := #0;

  UnlockBuffer;

  { --- send CB memory to clipboard}
  CBClose;
end;

procedure BuffPrint(ScrollRegion: BOOL);
{Print screen or selected text}
var
  Id: integer;
  PrintStart, PrintEnd: TPoint;
  TempAttr, TempAttr2, CurAttr, CurAttr2: byte;
  i, j, count: integer;
  IStart, IEnd: integer;
  TmpPtr: longint;
begin
  if ScrollRegion then
    Id := VTPrintInit(IdPrnScrollRegion)
  else if Selected then
    Id := VTPrintInit(IdPrnScreen or IdPrnSelectedText)
  else
    Id := VTPrintInit(IdPrnScreen);
  if Id=IdPrnCancel then exit;

  {set print region}
  if Id=IdPrnSelectedText then
  begin
    {print selected region}
    PrintStart := SelectStart;
    PrintEnd := SelectEnd;
  end
  else if Id=IdPrnScrollRegion then
  begin
    {print scroll region}
    PrintStart.x := 0;
    PrintStart.y := PageStart + CursorTop;
    PrintEnd.x := NumOfColumns;
    PrintEnd.y := PageStart + CursorBottom;
  end
  else begin
    {print current screen}
    PrintStart.x := 0;
    PrintStart.y := PageStart;
    PrintEnd.x := NumOfColumns;
    PrintEnd.y := PageStart + NumOfLines - 1;
  end;
  if PrintEnd.y > BuffEnd-1 then
    PrintEnd.y := BuffEnd-1;

  TempAttr := AttrDefault;
  TempAttr2 := AttrDefault2;

  LockBuffer;

  TmpPtr := GetLinePtr(PrintStart.y);
  for j := PrintStart.y to PrintEnd.y do
  begin
    if j=PrintStart.y then
      IStart := PrintStart.x
    else IStart := 0;
    if j = PrintEnd.y then
      IEnd := PrintEnd.x - 1
    else
      IEnd := NumOfColumns - 1;

    while (IEnd>=IStart) and
          (CodeBuff[TmpPtr+IEnd]=#$20) and
	  (AttrBuff[TmpPtr+IEnd]=char(AttrDefault)) and
	  (AttrBuff2[TmpPtr+IEnd]=char(AttrDefault2)) do
      dec(IEnd);

    i := IStart;
    while i <= IEnd do
    begin
      CurAttr := byte(AttrBuff[TmpPtr+i]) and not AttrKanji;
      CurAttr2 := byte(AttrBuff2[TmpPtr+i]);

      count := 1;
      while (i+count <= IEnd) and
            (CurAttr = byte(AttrBuff[TmpPtr+i+count]) and not AttrKanji) and
            (CurAttr2 = byte(AttrBuff2[TmpPtr+i+count])) or
            (i+count<NumOfColumns) and
            (byte(AttrBuff[TmpPtr+i+count-1]) and AttrKanji <> 0) do
        inc(count);

      if (CurAttr <> TempAttr) or
         (CurAttr2 <> TempAttr2) then
      begin
        PrnSetAttr(CurAttr,CurAttr2);
        TempAttr := CurAttr;
        TempAttr2 := CurAttr2;
      end;
      PrnOutText(@CodeBuff[TmpPtr+i],count);	
      i := i+count;
    end;
    PrnNewLine;
    TmpPtr := NextLinePtr(TmpPtr);
  end;

  UnlockBuffer;
  VTPrintEnd;
end;

procedure BuffDumpCurrentLine(TERM: byte);
{ Dumps current line to the file (for path through printing)
   HFile: file handle
   TERM: terminator character
	= LF or VT or FF }
var
  i, j: integer;
begin
  i := NumOfColumns;
  while (i>0) and (CodeLine[i-1]=#$20) do
    dec(i);
  for j := 0 to i do
    WriteToPrnFile(byte(CodeLine[j]),FALSE);
  WriteToPrnFile(0,TRUE);
  if (TERM>=LF) and (TERM<=FF) then
  begin
    WriteToPrnFile($0d,FALSE);
    WriteToPrnFile(TERM,TRUE);
  end;
end;

procedure BuffPutChar(b, Attr, Attr2: byte; Insert: bool);
{ Put a character in the buffer at the current position
   b: character
   Attr: attribute #1
   Attr2: attribute #2
   Insert: Insert flag }
var
  XStart: integer;
begin 
  if ts.Language=IdJapanese then
  begin
    EraseKanji(1); {if cursor is on right half of a kanji, erase the kanji}
    if not Insert then EraseKanji(0); {if cursor on left half...}
  end;

  if Insert then
  begin
    Move(CodeLine[CursorX],CodeLine[CursorX+1],NumOfColumns-1-CursorX);
    Move(AttrLine[CursorX],AttrLine[CursorX+1],NumOfColumns-1-CursorX);
    Move(AttrLine2[CursorX],AttrLine2[CursorX+1],NumOfColumns-1-CursorX);
    CodeLine[CursorX] := char(b);
    AttrLine[CursorX] := char(Attr);
    AttrLine2[CursorX] := char(Attr2);
    {last char in current line is kanji first?}
    if byte(AttrLine[NumOfColumns-1]) and AttrKanji <> 0 then
    begin
      {then delete it}
      CodeLine[NumOfColumns-1] := #$20;
      AttrLine[NumOfColumns-1] := char(AttrDefault);
      AttrLine2[NumOfColumns-1] := char(AttrDefault2);
    end;

    if StrChangeCount=0 then
      XStart := CursorX
    else
      XStart := StrChangeStart;
    StrChangeCount := 0;
    BuffUpdateRect(XStart,CursorY,NumOfColumns-1,CursorY);
  end
  else begin
    CodeLine[CursorX] := char(b);
    AttrLine[CursorX] := char(Attr);
    AttrLine2[CursorX] := char(Attr2);

    if StrChangeCount = 0 then
      StrChangeStart := CursorX;
    inc(StrChangeCount);
  end;
end;

procedure BuffPutKanji(w: WORD; Attr, Attr2: byte; Insert: bool);
{ Put a kanji character in the buffer at the current position
   b: character
   Attr: attribute #1
   Attr2: attribute #2
   Insert: Insert flag }
var
  XStart: integer;
begin
  EraseKanji(1); {if cursor is on right half of a kanji, erase the kanji}

  if Insert then
  begin
    Move(CodeLine[CursorX],CodeLine[CursorX+2],NumOfColumns-2-CursorX);
    Move(AttrLine[CursorX],AttrLine[CursorX+2],NumOfColumns-2-CursorX);
    Move(AttrLine2[CursorX],AttrLine2[CursorX+2],NumOfColumns-2-CursorX);
    CodeLine[CursorX] := char(HI(w));
    AttrLine[CursorX] := char(Attr or AttrKanji); {DBCS first byte}
    AttrLine2[CursorX] := char(Attr2);
    if CursorX < NumOfColumns-1 then
    begin
      CodeLine[CursorX+1] := char(LO(w));
      AttrLine[CursorX+1] := char(Attr);
      AttrLine2[CursorX+1] := char(Attr2);
    end;

    {last char in current line is kanji first?}
    if byte(AttrLine[NumOfColumns-1]) and AttrKanji <> 0 then
    begin
      {then delete it}
      CodeLine[NumOfColumns-1] := #$20;
      AttrLine[NumOfColumns-1] := char(AttrDefault);
      AttrLine2[NumOfColumns-1] := char(AttrDefault2);
    end;

    if StrChangeCount=0 then
      XStart := CursorX
    else
      XStart := StrChangeStart;
    StrChangeCount := 0;
    BuffUpdateRect(XStart,CursorY,NumOfColumns-1,CursorY);
  end
  else begin
    CodeLine[CursorX] := char(HI(w));
    AttrLine[CursorX] := char(Attr or AttrKanji); {DBCS first byte}
    AttrLine2[CursorX] := char(Attr2);
    if CursorX < NumOfColumns-1 then
    begin
      CodeLine[CursorX+1] := char(LO(w));
      AttrLine[CursorX+1] := char(Attr);
      AttrLine2[CursorX+1] := char(Attr2);
    end;

    if StrChangeCount=0 then
      StrChangeStart := CursorX;
    StrChangeCount := StrChangeCount + 2;
  end;
end;

function CheckSelect(x, y: integer): bool;
{subroutine called by BuffUpdateRect}
var
  L, L1, L2: longint;
begin
  if BoxSelect then
  begin
    CheckSelect := Selected and
     ((SelectStart.x<=x) and (x<SelectEnd.x) or
      (SelectEnd.x<=x) and (x<SelectStart.x)) and
     ((SelectStart.y<=y) and (y<=SelectEnd.y) or
      (SelectEnd.y<=y) and (y<=SelectStart.y));
  end
  else begin
    L := MAKELONG(x,y);
    L1 := MAKELONG(SelectStart.x,SelectStart.y);
    L2 := MAKELONG(SelectEnd.x,SelectEnd.y);

    CheckSelect := Selected and
      ((L1<=L) and (L<L2) or (L2<=L) and (L<L1));
  end;
end;

procedure BuffUpdateRect(XStart, YStart, XEnd, YEnd: integer);
{ Display text in a rectangular region in the screen
   XStart: x position of the upper-left corner (screen cordinate)
   YStart: y position
   XEnd: x position of the lower-right corner (last character)
   YEnd: y position }
var
  i, j, count: integer;
  IStart, IEnd: integer;
  X, Y: integer;
  TmpPtr: longint;
  CurAttr, TempAttr: byte;
  CurAttr2, TempAttr2: byte;
  CurSel, TempSel, Caret: bool;
begin
  if XStart >= WinOrgX+WinWidth then exit;
  if YStart >= WinOrgY+WinHeight then exit;
  if XEnd < WinOrgX then exit;
  if YEnd < WinOrgY then exit;

  if XStart < WinOrgX then XStart := WinOrgX;
  if YStart < WinOrgY then YStart := WinOrgY;
  if XEnd >= WinOrgX+WinWidth then XEnd := WinOrgX+WinWidth-1;
  if YEnd >= WinOrgY+WinHeight then YEnd := WinOrgY+WinHeight-1;

  TempAttr := AttrDefault;
  TempAttr2 := AttrDefault2;
  TempSel := FALSE;

  Caret := IsCaretOn;
  if Caret then CaretOff;

  DispSetupDC(TempAttr,TempAttr2,TempSel);

  Y := (YStart-WinOrgY)*FontHeight;
  TmpPtr := GetLinePtr(PageStart+YStart);
  for j := YStart+PageStart to YEnd+PageStart do
  begin
    IStart := XStart;
    IEnd := XEnd;

    IStart := LeftHalfOfDBCS(TmpPtr,IStart);

    X := (IStart-WinOrgX)*FontWidth;

    i := IStart;
    repeat
      CurAttr := byte(AttrBuff[TmpPtr+i]) and not AttrKanji;
      CurAttr2 := byte(AttrBuff2[TmpPtr+i]);
      CurSel := CheckSelect(i,j);
      count := 1;
      while
        (i+count <= IEnd) and
        (CurAttr=
         byte(AttrBuff[TmpPtr+i+count]) and not AttrKanji) and
        (CurAttr2=byte(AttrBuff2[TmpPtr+i+count])) and
        (CurSel=CheckSelect(i+count,j)) or
        (i+count<NumOfColumns) and
        (byte(AttrBuff[TmpPtr+i+count-1]) and AttrKanji <> 0) do
        inc(count);
        
      if (CurAttr <> TempAttr) or
         (CurAttr2 <> TempAttr2) or
         (CurSel <> TempSel) then
      begin
        DispSetupDC(CurAttr,CurAttr2,CurSel);
        TempAttr := CurAttr;
        TempAttr2 := CurAttr2;
        TempSel := CurSel;
      end;
      DispStr(@CodeBuff[TmpPtr+i],count,Y, X);
      i := i+count;
    until i>IEnd;
    Y := Y + FontHeight;
    TmpPtr := NextLinePtr(TmpPtr);
  end;
  if Caret then CaretOn;
end;

procedure UpdateStr;
{ Display not-yet-displayed string}
var
  X, Y: integer;
begin
  if StrChangeCount=0 then exit;
  X := StrChangeStart;
  Y := CursorY;
  if not IsLineVisible(X, Y) then
  begin
    StrChangeCount := 0;
    exit;
  end;

  DispSetupDC(byte(AttrLine[StrChangeStart]),
              byte(AttrLine2[StrChangeStart]),FALSE);
  DispStr(@CodeLine[StrChangeStart],StrChangeCount,Y, X);
  StrChangeCount := 0;
end;

procedure MoveCursor(Xnew, Ynew: integer);
begin
  UpdateStr;

  if CursorY<>Ynew then NewLine(PageStart+Ynew);

  CursorX := Xnew;
  CursorY := Ynew;
  Wrap := FALSE;

  DispScrollToCursor(CursorX, CursorY);
end;

procedure MoveRight;
{ move cursor right, but dont update screen.
  this procedure must be called from DispChar&DispKanji only}
begin
  inc(CursorX);
  DispScrollToCursor(CursorX, CursorY);
end;

procedure BuffSetCaretWidth;
var
  DW: BOOL;
begin
  {check whether cursor on a DBCS character}
  DW := byte(AttrLine[CursorX]) and AttrKanji <> 0;
  DispSetCaretWidth(DW);
end;

procedure ScrollUp1Line;
var
  i: integer;
  SrcPtr, DestPtr: longint;
begin
  if (CursorTop<=CursorY) and (CursorY<=CursorBottom) then
  begin
    UpdateStr;

    DestPtr := GetLinePtr(PageStart+CursorBottom);
    for i := CursorBottom-1 downto CursorTop do
    begin
      SrcPtr := PrevLinePtr(DestPtr);
      Move(CodeBuff[SrcPtr],CodeBuff[DestPtr],NumOfColumns);
      Move(AttrBuff[SrcPtr],AttrBuff[DestPtr],NumOfColumns);
      Move(AttrBuff2[SrcPtr],AttrBuff2[DestPtr],NumOfColumns);
      DestPtr := SrcPtr;
    end;
    FillChar(CodeBuff[SrcPtr],NumOfColumns,$20);
    FillChar(AttrBuff[SrcPtr],NumOfColumns,AttrDefault);
    FillChar(AttrBuff2[SrcPtr],NumOfColumns,AttrDefault2);

    DispScrollNLines(CursorTop,CursorBottom,-1);
  end;
end;

procedure BuffScrollNLines(n: integer);
var
  i: integer;
  SrcPtr, DestPtr: longint;
begin
  if n<1 then exit;
  UpdateStr;

  if (CursorTop = 0) and (CursorBottom = NumOfLines-1) then
  begin
    WinOrgY := WinOrgY-n;
    BuffScroll(n,CursorBottom);
    DispCountScroll(n);
  end
  else if (CursorTop=0) and (CursorY<=CursorBottom) then
  begin
    BuffScroll(n,CursorBottom);
    DispScrollNLines(WinOrgY,CursorBottom,n);
  end
  else if (CursorTop<=CursorY) and (CursorY<=CursorBottom) then
  begin
    DestPtr := GetLinePtr(PageStart+CursorTop);
    if n<CursorBottom-CursorTop+1 then
    begin
      SrcPtr := GetLinePtr(PageStart+CursorTop+n);
      for i := CursorTop+n to CursorBottom do
      begin
        Move(CodeBuff[SrcPtr],CodeBuff[DestPtr],NumOfColumns);
        Move(AttrBuff[SrcPtr],AttrBuff[DestPtr],NumOfColumns);
        Move(AttrBuff2[SrcPtr],AttrBuff2[DestPtr],NumOfColumns);
	SrcPtr := NextLinePtr(SrcPtr);
	DestPtr := NextLinePtr(DestPtr);
      end;
    end
    else
      n := CursorBottom-CursorTop+1;
    for i := CursorBottom+1-n to CursorBottom do
    begin
      FillChar(CodeBuff[DestPtr],NumOfColumns,$20);
      FillChar(AttrBuff[DestPtr],NumOfColumns,AttrDefault);
      FillChar(AttrBuff2[DestPtr],NumOfColumns,AttrDefault2);
      DestPtr := NextLinePtr(DestPtr);
    end;
    DispScrollNLines(CursorTop,CursorBottom,n);
  end;
end;

procedure BuffClearScreen;
begin
 { clear screen }
 if (StatusLine>0) and (CursorY=NumOfLines-1) then
   BuffScrollNLines(1) { clear status line }
 else begin { clear main screen }
   UpdateStr;
   BuffScroll(NumOfLines-StatusLine,NumOfLines-1-StatusLine);
   DispScrollNLines(WinOrgY,NumOfLines-1-StatusLine,NumOfLines-StatusLine);
 end;
end;

procedure BuffUpdateScroll;
{Updates scrolling}
begin
  UpdateStr;
  DispUpdateScroll;
end;

procedure CursorUpWithScroll;
begin
  if (0<CursorY) and (CursorY<CursorTop) or
      (CursorTop<CursorY) then
    MoveCursor(CursorX,CursorY-1)
  else if CursorY=CursorTop then
    ScrollUp1Line;
end;

{ called by BuffDblClk
   check if a character is the word delimiter }
function IsDelimiter(Line: longint; CharPtr: integer): bool;
begin
  if byte(AttrBuff[Line+CharPtr]) and AttrKanji <> 0 then
    IsDelimiter := ts.DelimDBCS<>0;
  IsDelimiter :=
    strscan(ts.DelimList,CodeBuff[Line+CharPtr])<>nil;
end;

procedure GetMinMax(i1,i2,i3: integer; var min,max: integer);
begin
  if i1<i2 then
  begin
    min := i1;
    max := i2;
  end
  else begin
    min := i2;
    max := i1;
  end;
  if i3<min then
    min := i3;
  if i3>max then
    max := i3;
end;

procedure ChangeSelectRegion;
var
  TempStart, TempEnd: TPoint;
  j, IStart, IEnd: integer;
  Caret: bool;
begin
  if (SelectEndOld.x=SelectEnd.x) and
     (SelectEndOld.y=SelectEnd.y) then exit;

  if BoxSelect then
  begin
    GetMinMax(SelectStart.x,SelectEndOld.x,SelectEnd.x,
              TempStart.x,TempEnd.x);
    GetMinMax(SelectStart.y,SelectEndOld.y,SelectEnd.y,
              TempStart.y,TempEnd.y);
    dec(TempEnd.x);
    Caret := IsCaretOn;
    if Caret then CaretOff;
    DispInitDC;
    BuffUpdateRect(TempStart.x,TempStart.y-PageStart,
                   TempEnd.x,TempEnd.y-PageStart);
    DispReleaseDC;
    if Caret then CaretOn;
    SelectEndOld := SelectEnd;
    exit
  end;

  if (SelectEndOld.y < SelectEnd.y) or
     (SelectEndOld.y=SelectEnd.y) and
     (SelectEndOld.x<=SelectEnd.x) then
  begin
    TempStart := SelectEndOld;
    TempEnd.x := SelectEnd.x-1;
    TempEnd.y := SelectEnd.y;
  end
  else begin
    TempStart := SelectEnd;
    TempEnd.x := SelectEndOld.x-1;
    TempEnd.y := SelectEndOld.y;
  end;
  if TempEnd.x < 0 then
  begin
    TempEnd.x := NumOfColumns - 1;
    dec(TempEnd.y);
  end;

  Caret := IsCaretOn;
  if Caret then CaretOff;
  for j := TempStart.y to TempEnd.y do
  begin
    IStart := 0;
    IEnd := NumOfColumns-1;
    if j=TempStart.y then IStart := TempStart.x;
    if j=TempEnd.y then IEnd := TempEnd.x;

    if (IEnd>=IStart) and (j >= PageStart+WinOrgY) and
       (j < PageStart+WinOrgY+WinHeight) then
    begin
      DispInitDC;
      BuffUpdateRect(IStart,j-PageStart,IEnd,j-PageStart);
      DispReleaseDC;
    end;
  end;
  if Caret then CaretOn;

  SelectEndOld := SelectEnd;
end;

procedure BuffDblClk(Xw, Yw: integer);
{  Select a word at (Xw, Yw) by mouse double click
    Xw: horizontal position in window coordinate (pixels)
    Yw: vertical }
var
  X, Y: integer;
  IStart, IEnd, i: integer;
  TmpPtr: longint;
  b: byte;
  DBCS: bool;
begin
  CaretOff;

  DispConvWinToScreen(Xw,Yw,@X,@Y,nil);
  Y := Y + PageStart;
  if (Y<0) or (Y>=BuffEnd) then exit;
  if X<0 then X := 0;
  if X>=NumOfColumns then X := NumOfColumns-1;

  BoxSelect := FALSE;
  LockBuffer;
  SelectEnd := SelectStart;
  ChangeSelectRegion;

  if (Y>=0) and (Y<BuffEnd) then
  begin
    TmpPtr := GetLinePtr(Y);

    IStart := X;
    IStart := LeftHalfOfDBCS(TmpPtr,IStart);
    IEnd := IStart;

    if IsDelimiter(TmpPtr,IStart) then
    begin
      b := byte(CodeBuff[TmpPtr+IStart]);
      DBCS := byte(AttrBuff[TmpPtr+IStart]) and AttrKanji <> 0;
      while (IStart>0) and
            ((char(b)=CodeBuff[TmpPtr+IStart]) or
	     DBCS and
	     (byte(AttrBuff[TmpPtr+IStart]) and AttrKanji<>0)) do
        MoveCharPtr(TmpPtr,IStart,-1); {move left}
      if (char(b)<>CodeBuff[TmpPtr+IStart]) and
         not (DBCS and
	      (byte(AttrBuff[TmpPtr+IStart]) and AttrKanji<>0)) then
        MoveCharPtr(TmpPtr,IStart,1);

      i := 1;
      while (i<>0) and
            ((char(b)=CodeBuff[TmpPtr+IEnd]) or
	     DBCS and
	     (byte(AttrBuff[TmpPtr+IEnd]) and AttrKanji<>0)) do
        i := MoveCharPtr(TmpPtr,IEnd,1); {move right}
    end
    else begin
      while (IStart>0) and
            not IsDelimiter(TmpPtr,IStart) do
        MoveCharPtr(TmpPtr,IStart,-1); {move left}
      if IsDelimiter(TmpPtr,IStart) then
        MoveCharPtr(TmpPtr,IStart,1);

      i := 1;
      while (i<>0) and
            not IsDelimiter(TmpPtr,IEnd) do
        i := MoveCharPtr(TmpPtr,IEnd,1); {move right}
    end;
    if i=0 then
      IEnd := NumOfColumns;

    if IStart<=X then
    begin
      SelectStart.x := IStart;
      SelectStart.y := Y;
      SelectEnd.x := IEnd;
      SelectEnd.y := Y;
      SelectEndOld := SelectStart;
      DblClkStart := SelectStart;
      DblClkEnd := SelectEnd;
      Selected := TRUE;
      ChangeSelectRegion;
    end;
  end;
  UnlockBuffer;
end;

procedure BuffTplClk(Yw: integer);
{  Select a line at Yw by mouse tripple click
    Yw: vertical clicked position
			in window coordinate (pixels)}
var
  Y: integer;
begin
  CaretOff;

  DispConvWinToScreen(0,Yw,nil,@Y,nil);
  Y := Y + PageStart;
  if (Y<0) or (Y>=BuffEnd) then exit;

  LockBuffer;
  SelectEnd := SelectStart;
  ChangeSelectRegion;
  SelectStart.x := 0;
  SelectStart.y := Y;
  SelectEnd.x := NumOfColumns;
  SelectEnd.y := Y;
  SelectEndOld := SelectStart;
  DblClkStart := SelectStart;
  DblClkEnd := SelectEnd;
  Selected := TRUE;
  ChangeSelectRegion;
  UnlockBuffer;
end;

procedure BuffStartSelect(Xw, Yw: integer; Box: bool);
{  Start text selection by mouse button down
    Xw: horizontal position in window coordinate (pixels)
    Yw: vertical
    Box: Box selection if TRUE }
var
  X, Y: integer;
  Right: bool;
  TmpPtr: longint;
begin
  DispConvWinToScreen(Xw,Yw, @X,@Y,@Right);
  Y := Y + PageStart;
  if (Y<0) or (Y>=BuffEnd) then exit;
  if X<0 then X := 0;
  if X>=NumOfColumns then X := NumOfColumns-1;

  SelectEndOld := SelectEnd;
  SelectEnd := SelectStart;

  LockBuffer;
  ChangeSelectRegion;
  UnlockBuffer;

  SelectStart.x := X;
  SelectStart.y := Y;
  if SelectStart.x<0 then SelectStart.x := 0;
  if SelectStart.x > NumOfColumns then
    SelectStart.x := NumOfColumns;
  if SelectStart.y < 0 then SelectStart.y := 0;
  if SelectStart.y >= BuffEnd then
    SelectStart.y := BuffEnd - 1;

  TmpPtr := GetLinePtr(SelectStart.y);
  {check if the cursor is on the right half of a character}
  if (SelectStart.x>0) and
     (byte(AttrBuff[TmpPtr+SelectStart.x-1]) and AttrKanji <> 0) or
     (byte(AttrBuff[TmpPtr+SelectStart.x]) and AttrKanji = 0) and
     Right then inc(SelectStart.x);
  
  SelectEnd := SelectStart;
  SelectEndOld := SelectEnd;
  CaretOff;
  Selected := TRUE;
  BoxSelect := Box;
end;

procedure BuffChangeSelect(Xw, Yw, NClick: integer);
{  Change selection region by mouse move
    Xw: horizontal position of the mouse cursor
			in window coordinate
    Yw: vertical }
var
  X, Y: integer;
  Right: bool;
  TmpPtr: longint;
  i: integer;
  b: byte;
  DBCS: bool;
begin
  DispConvWinToScreen(Xw,Yw,@X,@Y,@Right);
  Y := Y + PageStart;

  if X<0 then X := 0;
  if X > NumOfColumns then
    X := NumOfColumns;
  if Y < 0 then Y := 0;
  if Y >= BuffEnd then
    Y := BuffEnd - 1;

  TmpPtr := GetLinePtr(Y);
  LockBuffer;
  {check if the cursor is on the right half of a character}
  if (X>0) and
     (byte(AttrBuff[TmpPtr+X-1]) and AttrKanji <> 0) or
     (X<NumOfColumns) and
     (byte(AttrBuff[TmpPtr+X]) and AttrKanji = 0) and
     Right then inc(X);

  if X > NumOfColumns then
    X := NumOfColumns;

  SelectEnd.x := X;
  SelectEnd.y := Y;

  if NClick=2 then {drag after double click}
  begin
    if (SelectEnd.y>SelectStart.y) or
       (SelectEnd.y=SelectStart.y) and
       (SelectEnd.x>=SelectStart.x) then
    begin
      if SelectStart.x=DblClkEnd.x then
      begin
        SelectEnd := DblClkStart;
	ChangeSelectRegion;
	SelectStart := DblClkStart;
	SelectEnd.x := X;
	SelectEnd.y := Y;
      end;
      MoveCharPtr(TmpPtr,X,-1);
      if X<SelectStart.x then X := SelectStart.x;

      i := 1;
      if IsDelimiter(TmpPtr,X) then
      begin
        b := byte(CodeBuff[TmpPtr+X]);
	DBCS := byte(AttrBuff[TmpPtr+X]) and AttrKanji <> 0;
	while (i<>0) and
	      ((char(b)=CodeBuff[TmpPtr+SelectEnd.x]) or
	       DBCS and
	       (byte(AttrBuff[TmpPtr+SelectEnd.x]) and AttrKanji<>0)) do
	  i := MoveCharPtr(TmpPtr,SelectEnd.x,1); {move right}
      end
      else begin
        while (i<>0) and
	       not IsDelimiter(TmpPtr,SelectEnd.x) do
	  i := MoveCharPtr(TmpPtr,SelectEnd.x,1); {move right}
      end;
      if i=0 then
        SelectEnd.x := NumOfColumns;
    end
    else begin
      if SelectStart.x=DblClkStart.x then
      begin
        SelectEnd := DblClkEnd;
	ChangeSelectRegion;
	SelectStart := DblClkEnd;
	SelectEnd.x := X;
	SelectEnd.y := Y;
      end;
      if IsDelimiter(TmpPtr,SelectEnd.x) then
      begin
        b := byte(CodeBuff[TmpPtr+SelectEnd.x]);
	DBCS := byte(AttrBuff[TmpPtr+SelectEnd.x]) and AttrKanji <> 0;
	while (SelectEnd.x>0) and
	      ((char(b)=CodeBuff[TmpPtr+SelectEnd.x]) or
	       DBCS and
	       (byte(AttrBuff[TmpPtr+SelectEnd.x]) and AttrKanji<>0)) do
	  MoveCharPtr(TmpPtr,SelectEnd.x,-1); {move left}
	if (char(b)<>CodeBuff[TmpPtr+SelectEnd.x]) and
	   not (DBCS and
	        (byte(AttrBuff[TmpPtr+SelectEnd.x]) and AttrKanji<>0)) then
	  MoveCharPtr(TmpPtr,SelectEnd.x,1);
      end
      else begin
        while (SelectEnd.x>0) and
	      not IsDelimiter(TmpPtr,SelectEnd.x) do
	  MoveCharPtr(TmpPtr,SelectEnd.x,-1); {move left}
	if IsDelimiter(TmpPtr,SelectEnd.x) then
	  MoveCharPtr(TmpPtr,SelectEnd.x,1);
      end;
    end;
  end
  else if NClick=3 then {drag after tripple click}
  begin
    if (SelectEnd.y>SelectStart.y) or
       (SelectEnd.y=SelectStart.y) and
       (SelectEnd.x>=SelectStart.x) then
    begin
      if SelectStart.x=DblClkEnd.x then
      begin
        SelectEnd := DblClkStart;
	ChangeSelectRegion;
	SelectStart := DblClkStart;
	SelectEnd.x := X;
	SelectEnd.y := Y;
      end;
      SelectEnd.x := NumOfColumns;
    end
    else begin
      if SelectStart.x=DblClkStart.x then
      begin
        SelectEnd := DblClkEnd;
	ChangeSelectRegion;
	SelectStart := DblClkEnd;
	SelectEnd.x := X;
	SelectEnd.y := Y;
      end;
      SelectEnd.x := 0;
    end;
  end;

  ChangeSelectRegion;
  UnlockBuffer;
end;

procedure BuffEndSelect;
{End text selection by mouse button up}
begin
  Selected := (SelectStart.x<>SelectEnd.x) or
	    (SelectStart.y<>SelectEnd.y);
  if Selected then
  begin
    if BoxSelect then
    begin
      if SelectStart.x>SelectEnd.x then
      begin
        SelectEndOld.x := SelectStart.x;
        SelectStart.x := SelectEnd.x;
        SelectEnd.x := SelectEndOld.x;
      end;
      if SelectStart.y>SelectEnd.y then
      begin
        SelectEndOld.y := SelectStart.y;
        SelectStart.y := SelectEnd.y;
        SelectEnd.y := SelectEndOld.y;
      end;
    end
    else if (SelectEnd.y < SelectStart.y) or
      (SelectEnd.y = SelectStart.y) and
      (SelectEnd.x < SelectStart.x) then
    begin
      SelectEndOld := SelectStart;
      SelectStart := SelectEnd;
      SelectEnd := SelectEndOld;
    end;

    {copy to the clipboard}
    if ts.AutoTextCopy>0 then
    begin
      LockBuffer;
      BuffCBCopy(FALSE);
      UnlockBuffer;
    end;
  end;
end;

procedure BuffChangeWinSize(Nx, Ny: integer);
{ Change window size
   Nx: new window width (number of characters)
   Ny: new window hight}
begin
  if Nx=0 then Nx := 1;
  if Ny=0 then Ny := 1;

  if (ts.TermIsWin>0) and
     ((Nx<>NumOfColumns) or (Ny<>NumOfLines)) then
  begin
    LockBuffer;
    BuffChangeTerminalSize(Nx,Ny-StatusLine);
    UnlockBuffer;
    Nx := NumOfColumns;
    Ny := NumOfLines;
  end;
  if Nx>NumOfColumns then Nx := NumOfColumns;
  if Ny>BuffEnd then Ny := BuffEnd;
  DispChangeWinSize(Nx,Ny);
end;

procedure BuffChangeTerminalSize(Nx, Ny: integer);
var
  i, Nb, W, H: integer;
  St: BOOL;
begin
  Ny := Ny + StatusLine;
  if Nx < 1 then Nx := 1;
  if Ny < 1 then Ny := 1;
  if Nx > BuffXMax then Nx := BuffXMax;
  if ts.ScrollBuffMax > BuffYMax then
    ts.ScrollBuffMax := BuffYMax;
  if Ny > ts.ScrollBuffMax then Ny := ts.ScrollBuffMax;

  St := (StatusLine>0) and (CursorY=NumOfLines-1);
  if (Nx<>NumOfColumns) or (Ny<>NumOfLines) then
  begin
    if (ts.ScrollBuffSize < Ny) or
       (ts.EnableScrollBuff=0) then
      Nb := Ny
    else Nb := ts.ScrollBuffSize;

    if not ChangeBuffer(Nx,Nb) then exit;
    if ts.EnableScrollBuff>0 then
      ts.ScrollBuffSize := NumOfLinesInBuff;
    if Ny > NumOfLinesInBuff then Ny := NumOfLinesInBuff;

    NumOfColumns := Nx;
    NumOfLines := Ny;
    ts.TerminalWidth := Nx;
    ts.TerminalHeight := Ny-StatusLine;

    PageStart := BuffEnd - NumOfLines;
  end;
  BuffScroll(NumOfLines,NumOfLines-1);
  {Set Cursor}
  CursorX := 0;
  if St then
  begin
    CursorY := NumOfLines-1;
    CursorTop := CursorY;
    CursorBottom := CursorY;
  end
  else begin
    CursorY := 0;
    CursorTop := 0;
    CursorBottom := NumOfLines-1-StatusLine;
  end;

  SelectStart.x := 0;
  SelectStart.y := 0;
  SelectEnd := SelectStart;
  Selected := FALSE;

  {Tab stops}
  NTabStops := (NumOfColumns-1) shr 3;
  for i := 1 to NTabStops do
    TabStops[i-1] := i*8;

  if ts.TermIsWin>0 then
  begin
    W := NumOfColumns;
    H := NumOfLines;
  end
  else begin
    W := WinWidth;
    H := WinHeight;
    if (ts.AutoWinResize>0) or
       (NumOfColumns < W) then W := NumOfColumns;
    if ts.AutoWinResize>0 then H := NumOfLines
    else if BuffEnd < H then H := BuffEnd;
  end;
                              
  NewLine(PageStart+CursorY);

  {Change Window Size}
  BuffChangeWinSize(W,H);
  WinOrgY := -NumOfLines;
  DispScrollHomePos;

  if cv.Ready and cv.TelFlag then
    TelInformWinSize(NumOfColumns,NumOfLines-StatusLine);

  TTXSetWinSize(NumOfLines-StatusLine, NumOfColumns); {TTPLUG}
end;

procedure ChangeWin;
var
  Ny: integer;
begin
  {Change buffer}
  if ts.EnableScrollBuff>0 then
  begin
    if ts.ScrollBuffSize < NumOfLines then
      ts.ScrollBuffSize := NumOfLines;
    Ny := ts.ScrollBuffSize;
  end
  else
    Ny := NumOfLines;

  if NumOfLinesInBuff<>Ny then
  begin
    ChangeBuffer(NumOfColumns,Ny);
    if ts.EnableScrollBuff>0 then
      ts.ScrollBuffSize := NumOfLinesInBuff;

    if BuffEnd < WinHeight then
      BuffChangeWinSize(WinWidth,BuffEnd)
    else
      BuffChangeWinSize(WinWidth,WinHeight);
  end;

  DispChangeWin;
end;

procedure ClearBuffer;
begin
  {Reset buffer}
  PageStart := 0;
  BuffStartAbs := 0;
  BuffEnd := NumOfLines;
  if NumOfLines=NumOfLinesInBuff then
    BuffEndAbs := 0
  else
    BuffEndAbs := NumOfLines;

  SelectStart.x := 0;
  SelectStart.y := 0;
  SelectEnd := SelectStart;
  SelectEndOld := SelectStart;
  Selected := FALSE;

  NewLine(0);
  FillChar(CodeBuff[0],BufferSize,$20);
  FillChar(AttrBuff[0],BufferSize,AttrDefault);
  FillChar(AttrBuff2[0],BufferSize,AttrDefault2);

  {Home position}
  CursorX := 0;
  CursorY := 0;
  WinOrgX := 0;
  WinOrgY := 0;
  NewOrgX := 0;
  NewOrgY := 0;

  {Top/bottom margin}
  CursorTop := 0;
  CursorBottom := NumOfLines-1;

  StrChangeCount := 0;

  DispClearWin;
end;

procedure SetTabStop;
var
  i, j: integer;
begin
  if NTabStops<NumOfColumns then
  begin
    i := 0;
    while (TabStops[i]<CursorX) and (i<NTabStops) do
      inc(i);
    
    if (i<NTabStops) and (TabStops[i]=CursorX) then exit;

    for j := NTabStops downto i+1 do
      TabStops[j] := TabStops[j-1];
    TabStops[i] := CursorX;
    inc(NTabStops);
  end;
end;

procedure MoveToNextTab;
var
  i: integer;
begin
  if NTabStops>0 then
  begin
    i := -1;
    repeat
      inc(i);
    until (TabStops[i]>CursorX) or (i>=NTabStops-1);
    if TabStops[i]>CursorX then
      MoveCursor(TabStops[i],CursorY)
    else
      MoveCursor(NumOfColumns-1,CursorY);
  end
  else
    MoveCursor(NumOfColumns-1,CursorY);
end;

procedure ClearTabStop(Ps: integer);
{ Clear tab stops
   Ps = 0: clear the tab stop at cursor
      = 3: clear all tab stops }
var
  i, j: integer;
begin
  if NTabStops>0 then
    case Ps of
      0: begin
        i := 0;
        while (TabStops[i]<>CursorX) and (i<NTabStops-1) do
          inc(i);
        if TabStops[i] = CursorX then
        begin
          dec(NTabStops);
          for j:=i to NTabStops do
            TabStops[j] := TabStops[j+1];
        end;
      end;
      3: NTabStops := 0;
    end;
end;

procedure ShowStatusLine(Show: integer);
{show/hide status line}
var
  Ny, Nb, W, H: integer;
begin
  BuffUpdateScroll;
  if Show=StatusLine then exit;
  StatusLine := Show;

  if StatusLine=0 then
  begin
    dec(NumOfLines);
    dec(BuffEnd);
    BuffEndAbs:=PageStart+NumOfLines;
    if BuffEndAbs >= NumOfLinesInBuff then
      BuffEndAbs := BuffEndAbs-NumOfLinesInBuff;
    Ny := NumOfLines;
  end
  else
    Ny := ts.TerminalHeight+1;

  if (ts.ScrollBuffSize < Ny) or
     (ts.EnableScrollBuff=0) then
    Nb := Ny
  else Nb := ts.ScrollBuffSize;

  if not ChangeBuffer(NumOfColumns,Nb) then exit;
  if ts.EnableScrollBuff>0 then
    ts.ScrollBuffSize := NumOfLinesInBuff;
  if Ny > NumOfLinesInBuff then Ny := NumOfLinesInBuff;

  NumOfLines := Ny;
  ts.TerminalHeight := Ny-StatusLine;

  if StatusLine=1 then
    BuffScroll(1,NumOfLines-1);

  if ts.TermIsWin>0 then
  begin
    W := NumOfColumns;
    H := NumOfLines;
  end
  else begin
    W := WinWidth;
    H := WinHeight;
    if (ts.AutoWinResize>0) or
       (NumOfColumns < W) then W := NumOfColumns;
    if ts.AutoWinResize>0 then H := NumOfLines
    else if BuffEnd < H then H := BuffEnd;
  end;
                              
  PageStart := BuffEnd-NumOfLines;
  NewLine(PageStart+CursorY);

  {Change Window Size}
  BuffChangeWinSize(W,H);
  WinOrgY := -NumOfLines;
  DispScrollHomePos;

  MoveCursor(CursorX,CursorY);
end;

begin
  BuffLock := 0;
  HCodeBuff := 0;
  HAttrBuff := 0;
  HAttrBuff2 := 0;
end.
