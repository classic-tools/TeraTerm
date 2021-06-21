{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTTEK.DLL, TEK display routines}
unit TEKDisp;

interface
{$i teraterm.inc}

{$IFDEF Delphi}
uses
  WinTypes, WinProcs, TTTypes, TEKTypes;
{$ELSE}
uses
  WinTypes, WinProcs, Win31, TTTypes, TEKTypes;
{$ENDIF}

procedure TEKCaretOn(tk: PTEKVar; ts: PTTSet);
procedure TEKCaretOff(tk: PTEKVar);
procedure TEKDestroyCaret(tk: PTEKVar; ts: PTTSet); export;
procedure TEKChangeCaret(tk: PTEKVar; ts: PTTSet); export;

implementation

procedure TEKCaretOn(tk: PTEKVar; ts: PTTSet);
begin
with tk^ do begin
  if not Active then exit;
  if DispMode = IdAlphaMode then
  begin
    if ts^.CursorShape=IdHCur then
      SetCaretPos(CaretX,CaretY-CurWidth)
    else
      SetCaretPos(CaretX,CaretY-FontHeight);

    while CaretStatus > 0 do
    begin
      ShowCaret(HWin);
      Dec(CaretStatus);
    end;
  end;
end;
end;

procedure TEKCaretOff(tk: PTEKVar);
begin
with tk^ do begin
  if not Active then exit;

  if CaretStatus = 0 then
  begin
    HideCaret(HWin);
    inc(CaretStatus);
  end;
end;
end;

procedure TEKDestroyCaret(tk: PTEKVar; ts: PTTSet);
begin
with tk^ do begin
  DestroyCaret;
  if ts^.NonblinkingCursor<>0 then
    KillTimer(HWin,IdCaretTimer);
end;
end;

procedure TEKChangeCaret(tk: PTEKVar; ts: PTTSet);
var
  T: integer;
begin
with tk^ do begin
  if not Active then exit;

  case ts^.CursorShape of
    IdHCur: CreateCaret(HWin, 0, FontWidth, CurWidth);
    IdVCur: CreateCaret(HWin, 0, CurWidth, FontHeight);
  else
    CreateCaret(HWin, 0, FontWidth, FontHeight);
  end;
  CaretStatus := 1;
  TEKCaretOn(tk,ts);
  if ts^.NonblinkingCursor<>0 then
  begin
    T := GetCaretBlinkTime * 2 div 3;
    SetTimer(HWin,IdCaretTimer,T,nil);
  end;
end;
end;

end.
