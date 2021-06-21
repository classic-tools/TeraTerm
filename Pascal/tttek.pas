{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTTEK.DLL, for TEK window}
library TTTEK;
{$I teraterm.inc}

{$IFDEF Delphi}
uses WinTypes, WinProcs, OWindows, Strings, TTTypes, TEKTypes,
     TTCommon, CommDlg, TEKEsc, TEKDisp;
{$ELSE}
uses WinTypes, WinProcs, WObjects, Win31, Strings, TTTypes, TEKTypes,
     TTCommon, CommDlg, TEKEsc, TEKDisp;
{$ENDIF}

procedure TEKInit(tk: PTEKVar; ts: PTTSet); export;
var
  i: integer;
begin
with tk^ do begin

  MemDC := 0;
  HBits := 0;
  Pen := 0;
  MemPen := 0;
  ps := PS_SOLID;
  BackGround := 0;
  MemBackGround := 0;
  for i := 0 to 3 do
    TEKFont[i] := 0;
  ScreenHeight := 0;
  ScreenWidth := 0;
  AdjustSize := FALSE;
  ScaleFont := FALSE;
  TextSize := 0;

  FillChar(TEKlf, SizeOf(TLogFont), #0);
  with TEKlf do
  begin
    lfHeight        := ts^.TEKFontSize.y;  {Font Height}
    lfWidth         := ts^.TEKFontSize.x;  {Font Width}
    lfCharSet       := ts^.TEKFontCharSet;  {Character Set}
    StrCopy(lfFaceName, @ts^.TEKFont);
  end;

  MoveFlag := TRUE;

  ParseMode := ModeFirst;
  DispMode := IdAlphaMode;
  Drawing := FALSE;

  RubberBand := FALSE;
  Select := FALSE;
  ButtonDown := FALSE;

  GIN := FALSE;
  CrossHair := FALSE;
  IgnoreCount := 0;
  GINX := 0;
  GINY := 0;

  GTWidth := 39;
  GTHeight := 59;
  GTSpacing := 12;

  MarkerType := 1;
  MarkerFont := 0;
  MarkerFlag := FALSE;
end;
end;

procedure ToggleCrossHair(tk: PTEKVar; ts: PTTSet; OnFlag: bool);
var
  DC: HDC;
  TempPen, OldPen: HPen;
begin
with tk^ do begin
  if CrossHair=OnFlag then exit;
  DC := GetDC(HWin);
  TempPen := CreatePen(PS_SOLID, 1, ts^.TEKColor[0]);
  OldPen := SelectObject(DC,TempPen);
  SetROP2(DC, R2_NOT);
  MoveToEx(DC,GINX,0,nil);
  LineTo(DC,GINX,ScreenHeight-1);
  MoveToEx(DC,0,GINY,nil);
  LineTo(DC,ScreenWidth-1,GINY);
  SelectObject(DC,OldPen);
  DeleteObject(TempPen);
  ReleaseDC(HWin,DC);
  CrossHair := OnFlag;
end;
end;

procedure SwitchRubberBand(tk: PTEKVar; ts: PTTSet; OnFlag: bool);
var
  DC: HDC;
  TempPen, OldPen: HPen;
  OldMemRop: integer;
  OldMemBrush: HBrush;
begin
with tk^ do begin
  if RubberBand=OnFlag then exit;

  TempPen := CreatePen(PS_DOT, 1, ts^.TEKColor[0]);
  DC := GetDC(HWin);
  SetBkMode(DC,1);
  SelectObject(DC,GetStockObject(HOLLOW_BRUSH));
  OldPen := SelectObject(DC,TempPen);
  SetROP2(DC, R2_NOT);
  Rectangle(DC,SelectStart.x,SelectStart.y,SelectEnd.x,SelectEnd.y);
  SelectObject(DC,OldPen);
  ReleaseDC(HWin,DC);
  DeleteObject(TempPen);

  TempPen := CreatePen(PS_DOT, 1, MemForeColor);
  OldMemBrush := SelectObject(MemDC,GetStockObject(HOLLOW_BRUSH));
  SelectObject(MemDC,TempPen);
  OldMemRop := SetROP2(MemDC, R2_XORPEN);
  Rectangle(MemDC,SelectStart.x,SelectStart.y,SelectEnd.x,SelectEnd.y);
  SelectObject(MemDC,OldMemBrush);
  SetRop2(MemDC,OldMemRop);
  SelectObject(MemDC,MemPen);
  DeleteObject(TempPen);     

  RubberBand := OnFlag;
end;
end;

procedure TEKResizeWindow(tk: PTEKVar; ts: PTTSet; W, H: Integer); export;
var
  i, Height, Width: integer;
  Metrics: TTextMetric;
  TempDC: HDC;
  TempOldFont: HFont;
  R: TRect;
begin
with tk^ do begin
  if tk^.Select then SwitchRubberband(tk,ts,FALSE);
  Select := FALSE;

  {Delete old MemDC}
  if MemDC<>0 then
  begin
    SelectObject(MemDC, OldMemFont);
    SelectObject(MemDC, OldMemBmp);
    SelectObject(MemDC, OldMemPen);
    DeleteDC(MemDC);
  end;

  {Delete old fonts}
  for i :=0 to 3 do
    if TEKFont[i]<>0 then
      DeleteObject(TEKFont[i]);
  if MarkerFont<>0 then
    DeleteObject(MarkerFont);

  {Delete old bitmap}
  if HBits <> 0 then DeleteObject(HBits);

  {Delete old pen}
  if Pen <> 0 then DeleteObject(Pen);
  if MemPen <> 0 then DeleteObject(MemPen);

  {Delete old brush}
  if BackGround <> 0 then DeleteObject(BackGround);
  if MemBackGround <> 0 then DeleteObject(MemBackGround);

  {get DC}
  TempDC := GetDC(HWin);
  MemDC := CreateCompatibleDC(TempDC);

  {Create standard size font}
  if ScaleFont then
  begin
    TEKlf.lfHeight := round(ScreenHeight / 35);
    TEKlf.lfWidth := round(ScreenWidth / 74);
  end;

  with TEKlf do
  begin
    lfWeight := FW_NORMAL;
    lfItalic := 0;
    lfUnderLine := 0;
    lfStrikeOut := 0;
    lfOutPrecision  := OUT_CHARACTER_PRECIS;
    lfClipPrecision := CLIP_CHARACTER_PRECIS;
    lfQuality       := DEFAULT_QUALITY;
    lfPitchAndFamily:= FIXED_PITCH or FF_DONTCARE;
  end;

  TEKFont[0] := CreateFontIndirect(TEKlf);
  {Check standard font size}
  TempOldFont := SelectObject(TempDC,TEKFont[0]);
  GetTextMetrics(TempDC, Metrics);
  FW[0] := Metrics.tmAveCharWidth;
  FH[0] := Metrics.tmHeight;
 
  if not ScaleFont then
  begin
    ScreenHeight := FH[0]*35;
    ScreenWidth := FW[0]*74;
    Width := round(ScreenHeight/ViewSizeY*ViewSizeX);
    if ScreenWidth < Width then
      ScreenWidth := Width;
  end;

  Height := TEKlf.lfHeight;
  Width := TEKlf.lfWidth;

  {marker font}
  TEKlf.lfCharSet := SYMBOL_CHARSET;
  strcopy(TEKlf.lfFaceName,'Symbol');
  MarkerFont := CreateFontIndirect(TEKlf);
  TEKlf.lfCharSet := ts^.TEKFontCharSet;
  strcopy(TEKlf.lfFaceName, ts^.TEKFont);
  SelectObject(TempDC,MarkerFont);
  GetTextMetrics(TempDC, Metrics);
  MarkerW := Metrics.tmAveCharWidth;
  MarkerH := Metrics.tmHeight;

  {second font}
  TEKlf.lfHeight := round(ScreenHeight/38);
  TEKlf.lfWidth := round(ScreenWidth/80);
  TEKFont[1] := CreateFontIndirect(TEKlf);
  SelectObject(TempDC,TEKFont[1]);
  GetTextMetrics(TempDC, Metrics);
  FW[1] := Metrics.tmAveCharWidth;
  FH[1] := Metrics.tmHeight;

  {third font}
  TEKlf.lfHeight := round(ScreenHeight/58);
  TEKlf.lfWidth := round(ScreenWidth/121);
  TEKFont[2] := CreateFontIndirect(TEKlf);
  SelectObject(TempDC,TEKFont[2]);
  GetTextMetrics(TempDC, Metrics);
  FW[2] := Metrics.tmAveCharWidth;
  FH[2] := Metrics.tmHeight;

  {forth font}
  TEKlf.lfHeight := round(ScreenHeight/64);
  TEKlf.lfWidth := round(ScreenWidth/133);
  TEKFont[3] := CreateFontIndirect(TEKlf);
  SelectObject(TempDC,TEKFont[3]);
  GetTextMetrics(TempDC, Metrics);
  FW[3] := Metrics.tmAveCharWidth;
  FH[3] := Metrics.tmHeight;

  OldMemFont := SelectObject(MemDC,TEKFont[TextSize]);
  FontWidth := FW[TextSize];
  FontHeight := FH[TextSize];

  TEKlf.lfHeight := Height;
  TEKlf.lfWidth := Width;

  if ts^.TEKColorEmu>0 then
    HBits := CreateCompatibleBitmap(TempDC,ScreenWidth,ScreenHeight)
  else
    HBits := CreateBitmap(ScreenWidth, ScreenHeight, 1, 1, nil);

  OldMemBmp := SelectObject(MemDC, HBits);

  TextColor := ts^.TEKColor[0];
  if ts^.TEKColorEmu>0 then
  begin
    MemForeColor := ts^.TEKColor[0];
    MemBackColor := ts^.TEKColor[1];
  end
  else begin
    MemForeColor := RGB(0,0,0);
    MemBackColor := RGB(255,255,255);
  end;
  MemTextColor := MemForeColor;

  SetTextColor(MemDC, MemTextColor);
  SetBkColor(MemDC,MemBackColor);
  SetBkMode(MemDC, 1);
  SetTextAlign(MemDC,TA_LEFT or TA_BOTTOM or TA_NOUPDATECP);

  BackGround := CreateSolidBrush(ts^.TEKColor[1]);
  MemBackGround := CreateSolidBrush(MemBackColor);

  PenColor := ts^.TEKColor[0];
  Pen := CreatePen(ps,1,PenColor);

  MemPenColor := MemForeColor;
  MemPen := CreatePen(ps,1,MemPenColor);
  OldMemPen := SelectObject(MemDC, MemPen);

  SelectObject(TempDC,TempOldFont);
  ReleaseDC(HWin,TempDC);

  R.left := 0;
  R.right := ScreenWidth;
  R.top := 0;
  R.bottom := ScreenHeight;
  FillRect(MemDC,R,MemBackGround);
  InvalidateRect(HWin, @R, TRUE);

  DispMode := IdAlphaMode;
  HiY := 0;
  Extra := 0;
  LoY := 0;
  HiX := 0;
  LoX := 0;
  CaretX := 0;
  CaretOffset := 0;
  CaretY := FontHeight;
  if Active then TEKChangeCaret(tk,ts);

  GetClientRect(HWin,R);
  Width := W + ScreenWidth - R.Right + R.Left;
  Height := H + ScreenHeight - R.Bottom + R.Top;
  if (Width<>W) or (Height<>H) then
  begin
    AdjustSize := TRUE;
    SetWindowPos(HWin,HWND_TOP,0,0,Width,Height,SWP_NOMOVE);
  end;

  ScaleFont := FALSE;
end;
end;

function TEKParse(tk: PTEKVar; ts: PTTSet; cv: PComVar): integer; export;
var
  f: boolean;
  c: integer;
  b: byte;
{$ifndef TERATERM32}
  DummyMsg: TMsg;
{$endif}
begin
with tk^ do begin
  if ButtonDown then
  begin
    TEKParse := 0;
    exit
  end;

  ChangeEmu := 0;
  f := TRUE;

  repeat
    c := CommRead1Byte(cv,@b);

    if c > 0 then
    begin
      if IgnoreCount <= 0 then
      begin
        if f then
        begin
          TEKCaretOff(tk);
          f := FALSE;
          if GIN then ToggleCrossHair(tk,ts,FALSE);
          if RubberBand then SwitchRubberBand(tk,ts,FALSE);
        end;

        case ParseMode of
          ModeFirst: ParseFirst(tk,ts,cv,b);
          ModeEscape: TEKEscape(tk,ts,cv,b);
          ModeCS: ControlSequence(tk,ts,cv,b);
          ModeSelectCode: SelectCode(tk,ts,b);
          Mode2OC: TwoOpCode(tk,ts,cv,b);
          ModeGT: GraphText(tk,ts,cv,b);
        else
          begin
            ParseMode := ModeFirst;
            ParseFirst(tk,ts,cv,b);
          end;
        end;
{$ifndef TERATERM32}
        PeekMessage(DummyMsg, 0, 0, 0, PM_NOREMOVE);
{$endif}
      end
      else Dec(IgnoreCount);
    end;
  until (c=0) or (ChangeEmu>0);

  ToggleCrossHair(tk,ts,GIN);
  if not f then
  begin
    TEKCaretOn(tk,ts);
    SwitchRubberBand(tk,ts,Select);
  end;

  if ChangeEmu > 0 then ParseMode := ModeFirst;
  TEKParse := ChangeEmu;
end;
end;


procedure TEKReportGIN(tk: PTEKVar; ts: PTTSet; cv: PComVar; KeyCode: byte); export;
var
  Code: array[0..10] of byte;
  X, Y: integer;
begin
with tk^ do begin
  ToggleCrossHair(tk,ts,FALSE);
  X := Trunc(GINX/ScreenWidth*ViewSizeX);
  Y := Trunc((1-(GINY+1)/ScreenHeight)*ViewSizeY);
  Code[0] := KeyCode;
  Code[1] := (X shr 7) + 32;
  Code[2] := ((X shr 2) and $1f) + 32;
  Code[3] := (Y shr 7) + 32;
  Code[4] := ((Y shr 2) and $1f) + 32;
  Code[5] := $0d;
  GIN := FALSE;
  ReleaseCapture;
  CommBinaryOut(cv, @Code[0],6);
  IgnoreCount := 6;
end;
end;

procedure TEKPaint(tk: PTEKVar; ts: PTTSet; PaintDC: HDC; PaintInfo: PPaintStruct); export;
var
  X,Y,W,H: integer;
begin
with tk^ do begin
  if PaintInfo^.fErase then
    FillRect(PaintDC, PaintInfo^.rcPaint,Background);

  if GIN then ToggleCrossHair(tk,ts,FALSE);
  if Select then SwitchRubberBand(tk,ts,FALSE);
  X := PaintInfo^.rcPaint.left;
  Y := PaintInfo^.rcPaint.top;
  W := PaintInfo^.rcPaint.right - X;
  H := PaintInfo^.rcPaint.bottom - Y;
  SetTextColor(PaintDC, ts^.TEKColor[0]);
  SetBkColor(PaintDC,  ts^.TEKColor[1]);
  BitBlt(PaintDC,X,Y,W,H,MemDC,X,Y,SRCCOPY);
  SwitchRubberBand(tk,ts,Select);
  if GIN then ToggleCrossHair(tk,ts,TRUE);
end;
end;

procedure TEKWMLButtonDown
  (tk: PTEKVar; ts: PTTSet; cv: PComVar; pos: TPoint); export;
var
  b: byte;
begin
with tk^ do begin
  if GIN then
  begin
    b := ts^.GINMouseCode and $ff;
    TEKReportGIN(tk,ts,cv,b);
    exit;
  end;

  if ButtonDown then exit;

  {Capture mouse}
  SetCapture(HWin);

  {Is the position in client area?}
  if (pos.x>=0) and (pos.x<ScreenWidth) and
     (pos.y>=0) and (pos.y<ScreenHeight) then
  begin
    SwitchRubberBand(tk,ts,FALSE);
    Select := FALSE;

    SelectStart.x := pos.x;
    SelectStart.y := pos.y;
    SelectEnd := SelectStart;
    ButtonDown := TRUE;
  end;

end;
end;

procedure TEKWMLButtonUp(tk: PTEKVar; ts: PTTSet); export;
var
  X: integer;
begin
with tk^ do begin
  ReleaseCapture;
  ButtonDown := FALSE;
  if (Abs(SelectEnd.y-SelectStart.y)>2) and
     (Abs(SelectEnd.x-SelectStart.x)>2) then
  begin
    if SelectStart.x>SelectEnd.x then
    begin
      X := SelectEnd.x;
      SelectEnd.x := SelectStart.x; 
      SelectStart.x := X;
    end;
    if SelectStart.y>SelectEnd.y then
    begin
      X := SelectEnd.y;
      SelectEnd.y := SelectStart.y; 
      SelectStart.y := X;
    end;
    Select := TRUE;
  end
  else begin
    SwitchRubberBand(tk,ts,FALSE);
    Select := FALSE;
  end;
end;
end;

procedure TEKWMMouseMove(tk: PTEKVar; ts: PTTSet; p: TPoint); export;
var
  X, Y: integer;
begin
with tk^ do begin
  if (not ButtonDown) and (not GIN) then exit;
  {get position}
  X := p.x + 1;
  Y := p.y + 1;

  { if out of client area, force into client area}
  if X<0 then X := 0
  else if X>ScreenWidth then X := ScreenWidth - 1;
  if Y<0 then Y := 0
  else if Y>ScreenHeight then Y := ScreenHeight - 1;

  if GIN then
  begin
    ToggleCrossHair(tk,ts,FALSE);
    GINX := X;
    GINY := Y;
    ToggleCrossHair(tk,ts,TRUE);
  end
  else begin
    SwitchRubberBand(tk,ts,FALSE);
    SelectEnd.x := X + 1;
    SelectEnd.y := Y + 1;
    SwitchRubberBand(tk,ts,TRUE);
  end;  

  if GIN then SetCapture(HWin);
end;
end;

procedure TEKWMSize(tk: PTEKVar; ts: PTTSet; W, H, cx, cy: Integer); export;
var
  Width, Height: integer;
begin
with tk^ do begin
  Width := cx;
  Height := cy;

  if (ScreenWidth=Width) and
     (ScreenHeight=Height) then
  begin
    AdjustSize := FALSE;
    exit;
  end;

  if AdjustSize then
  begin {resized by myself}
    Width := W + ScreenWidth - Width;
    Height := H + ScreenHeight - Height;
    SetWindowPos(HWin,HWND_TOP,0,0,Width,Height,SWP_NOMOVE);
  end
  else begin
    if (ScreenWidth=0) or (ScreenHeight=0) then
      exit; {resized during initialization}
    {resized by user}
    ScreenWidth := Width;
    ScreenHeight := Height;
    ScaleFont := TRUE;
    TEKResizeWindow(tk,ts,W,H);
  end;
end;
end;

procedure CopyToClipboard
  (tk: PTEKVar; ts: PTTSet; x, y, Width, Height: integer);
var
  CopyDC: HDC;
  CopyBitmap: HBitmap;
begin
with tk^ do begin
  if Select then SwitchRubberBand(tk,ts,FALSE);
  TEKCaretOff(tk);
  if OpenClipBoard(HWin) and EmptyClipBoard then
  begin
    { Create the new bitmap }
    CopyDC := CreateCompatibleDC(MemDC);
    CopyBitmap := CreateCompatibleBitmap(MemDC, Width, Height);
    CopyBitmap := SelectObject(CopyDC, CopyBitmap);
    BitBlt(CopyDC, 0, 0, Width, Height, MemDC, x, y, SRCCOPY);
    CopyBitmap := SelectObject(CopyDC, CopyBitmap);
    { Transfer the new bitmap to the clipboard }
    SetClipBoardData(CF_BITMAP, CopyBitmap);
  end;

  CloseClipBoard;
  DeleteDC(CopyDC);

  TEKCaretOn(tk,ts);
  SwitchRubberBand(tk,ts,Select);
end;
end;

procedure TEKCMCopy(tk: PTEKVar; ts: PTTSet); export;
var
  x, y: integer;
begin
with tk^ do begin
  if not Select then exit;

  if SelectStart.x < SelectEnd.x then x := SelectStart.x
                                 else x := SelectEnd.x;
  if SelectStart.y < SelectEnd.y then y := SelectStart.y
                                 else y := SelectEnd.y;
  {copy selected area to clipboard}
  CopyToClipboard(tk, ts, x, y,
    abs(SelectEnd.x-SelectStart.x),
    abs(SelectEnd.y-SelectStart.y));                          
end;
end;

procedure TEKCMCopyScreen(tk: PTEKVar; ts: PTTSet); export;
begin
with tk^ do begin
  {copy fullscreen to clipboard}
  CopyToClipboard(tk, ts, 0, 0, ScreenWidth, ScreenHeight);
end;
end;

procedure TEKPrint(tk: PTEKVar; ts: PTTSet; PrintDC: HDC; SelFlag: BOOL); export;
var
  PPI: TPoint;
  Margin: TRect;
  Caps: integer;
  PrnWidth, PrnHeight: integer;
  MemWidth, MemHeight: integer;
  PrintStart, PrintEnd: TPoint;
begin
with tk^ do begin

  if PrintDC = 0 then exit;

  if SelFlag then
  begin
    {print selection}
    PrintStart := SelectStart;
    PrintEnd := SelectEnd;
  end
  else begin
    {print current page} 
    PrintStart.x := 0;
    PrintStart.y := 0;
    PrintEnd.x := ScreenWidth;
    PrintEnd.y := ScreenHeight;
  end;

  Caps := GetDeviceCaps(PrintDC,RASTERCAPS);
  if (Caps and RC_BITBLT)<>RC_BITBLT then
  begin
    MessageBox(HWin,'Printer dose not support graphics',
      'Tera Term: Error',MB_ICONEXCLAMATION);
    exit;
  end;
  if Active then TEKCaretOff(tk);
  if RubberBand then SwitchRubberBand(tk,ts,FALSE);

  MemWidth := PrintEnd.x - PrintStart.x;
  MemHeight := PrintEnd.y - PrintStart.y;
  if (MemWidth=0) or (MemHeight=0) then exit;

  StartPage(PrintDC);

  if (ts^.TEKPPI.x>0) and (ts^.TEKPPI.y>0) then
    PPI := ts^.TEKPPI
  else begin
    PPI.X := GetDeviceCaps(PrintDC,LOGPIXELSX);
    PPI.Y := GetDeviceCaps(PrintDC,LOGPIXELSY);
  end;

  Margin.left := {left margin}
    round(ts^.PrnMargin[0]/100*PPI.x);
  Margin.right := {right margin}
    GetDeviceCaps(PrintDC,HORZRES) -
    round(ts^.PrnMargin[1]/100*PPI.x);
  Margin.top := {top margin}
    round(ts^.PrnMargin[2]/100*PPI.y);
  Margin.bottom := {bottom margin}
    GetDeviceCaps(PrintDC,VERTRES) -
    round(ts^.PrnMargin[3]/100*PPI.y);

  if (Caps and RC_STRETCHBLT) = RC_STRETCHBLT then
  begin
    PrnWidth := round(MemWidth/GetDeviceCaps(MemDC,LOGPIXELSX)*PPI.x);
    PrnHeight := round(MemHeight/GetDeviceCaps(MemDC,LOGPIXELSY)*PPI.y);
    StretchBlt(PrintDC, Margin.left, Margin.top, PrnWidth, PrnHeight,
               MemDC, PrintStart.x, PrintStart.y, MemWidth, MemHeight, SRCCOPY);
  end
  else
    BitBlt(PrintDC, Margin.left, Margin.top, MemWidth, MemHeight,
               MemDC, PrintStart.x, PrintStart.y, SRCCOPY);

  EndPage(PrintDC);

  SwitchRubberBand(tk,ts,Select);
end;
end;

procedure TEKClearScreen(tk: PTEKVar; ts: PTTSet); export;
var
  R: TRect;
begin
with tk^ do begin
  GetClientRect(HWin,R);
  FillRect(MemDC,R,MemBackground);
  InvalidateRect(HWin,@R,FALSE);
  DispMode := IdAlphaMode;
  CaretX := 0;
  CaretOffset := 0;
  CaretY := FontHeight;
  TEKCaretOn(tk,ts);
end;
end;

procedure TEKSetupFont(tk: PTEKVar; ts: PTTSet); export;
var
  W, H: integer;
{  Ok: bool;}
  R: TRect;
begin
with tk^ do begin
{  if not LoadTTDLG then exit;
  Ok := ChooseFontDlg(HWin,@TEKlf,nil);
  FreeTTDLG;
  if not OK then exit;}

  StrCopy(ts^.TEKFont,TEKlf.lfFaceName);
  ts^.TEKFontSize.x := TEKlf.lfWidth;
  ts^.TEKFontSize.y := TEKlf.lfHeight;
  ts^.TEKFontCharSet := TEKlf.lfCharSet;

  GetWindowRect(HWin, R);
  W := R.right - R.left;
  H := R.bottom - R.top;
  TextSize := 0;
  TEKResizeWindow(tk,ts,W,H);
end;
end;

procedure TEKResetWin(tk: PTEKVar; ts: PTTSet; EmuOld: word); export;
var
  TmpDC: HDC;
  R: TRect;
begin
with tk^ do begin
  {Change caret shape}
  TEKChangeCaret(tk,ts);

  {Change display color}
  TmpDC := GetDC(HWin);

  if ts^.TEKColorEmu<>EmuOld then
  begin
    SelectObject(MemDC,OldMemBmp);
    if HBits<>0 then DeleteObject(HBits);
    if ts^.TEKColorEmu>0 then
      HBits := CreateCompatibleBitmap(TmpDC,ScreenWidth,ScreenHeight)
    else
      HBits := CreateBitmap(ScreenWidth, ScreenHeight, 1, 1, nil);
    OldMemBmp := SelectObject(MemDC, HBits);
    GetClientRect(HWin,R);
    FillRect(MemDC,R,MemBackground);
  end;

  ReleaseDC(HWin,TmpDC);

  TextColor := ts^.TEKColor[0];

  ps := PS_SOLID;
  PenColor := ts^.TEKColor[0];
  if Pen<>0 then DeleteObject(Pen);
  Pen := CreatePen(ps,1,PenColor);

  if BackGround<>0 then DeleteObject(BackGround);
  BackGround := CreateSolidBrush(ts^.TEKColor[1]);

  if ts^.TEKColorEmu>0 then
  begin
    MemForeColor := ts^.TEKColor[0];
    MemBackColor := ts^.TEKColor[1];
  end
  else begin
    MemForeColor := RGB(0,0,0);
    MemBackColor := RGB(255,255,255);
  end;
  MemTextColor := MemForeColor;
  MemPenColor := MemForeColor;

  SelectObject(MemDC, OldMemPen);
  if MemPen<>0 then DeleteObject(MemPen);
  MemPen := CreatePen(ps,1,MemPenColor);
  OldMemPen := SelectObject(MemDC,MemPen);

  if MemBackGround<>0 then DeleteObject(MemBackGround);
  MemBackGround := CreateSolidBrush(MemBackColor);

  SetTextColor(MemDC, MemTextColor);
  SetBkColor(MemDC, MemBackColor);

  if (ts^.TEKColorEmu>0) or
     (ts^.TEKColorEmu<>EmuOld) then
    TEKClearScreen(tk,ts);

  InvalidateRect(HWin,nil,TRUE);
end;
end;

{function TEKSetupWinDlg(tk: PTEKVar; ts: PTTSet): BOOL; export;
var
  Ok: BOOL;
  OldEmu: word;
begin
with tk^ do begin

  ts^.VTFlag := 0;
  ts^.SampleFont := TEKFont[0];

  if not LoadTTDLG then exit;
  OldEmu := ts^.TEKColorEmu;
  Ok := SetupWin(HWin, ts);
  FreeTTDLG;

  if Ok then TEKResetWin(tk,ts,OldEmu);
  TEKSetupWinDlg := Ok;
end;
end; }

procedure TEKRestoreSetup(tk: PTEKVar; ts: PTTSet); export;
var
  W, H: integer;
  R: TRect;
begin
with tk^ do begin
  {change window}
  StrCopy(TEKlf.lfFaceName,ts^.TEKFont);
  TEKlf.lfWidth := ts^.TEKFontSize.x;
  TEKlf.lfHeight := ts^.TEKFontSize.y;
  TEKlf.lfCharSet := ts^.TEKFontCharSet;
  TextSize := 0;

  GetWindowRect(HWin, R);
  W := R.right - R.left;
  H := R.bottom - R.top;
  TEKResizeWindow(tk,ts,W,H);
end;
end;

procedure TEKEnd(tk: PTEKVar); export;
var
  i: integer;
begin
with tk^ do begin
  if MemDC <> 0 then DeleteDC(MemDC);
  for i := 0 to 3 do
    if TEKFont[i]<>0 then DeleteObject(TEKFont[i]);
  if MarkerFont<>0 then DeleteObject(MarkerFont);
  if HBits <> 0 then DeleteObject(HBits);
  if Pen <> 0 then DeleteObject(Pen);
  if MemPen <> 0 then DeleteObject(MemPen);
  if BackGround <> 0 then DeleteObject(BackGround);
  if MemBackGround <> 0 then DeleteObject(MemBackGround);
end;
end;

exports

  TEKInit          index 1,
  TEKResizeWindow  index 2,
  TEKChangeCaret   index 3,
  TEKDestroyCaret  index 4,
  TEKParse         index 5,
  TEKReportGIN     index 6,
  TEKPaint         index 7,
  TEKWMLButtonDown index 8,
  TEKWMLButtonUp   index 9,
  TEKWMMouseMove   index 10,
  TEKWMSize        index 11,
  TEKCMCopy        index 12,
  TEKCMCopyScreen  index 13,
  TEKPrint         index 14,
  TEKClearScreen   index 15,
  TEKSetupFont     index 16,
  TEKResetWin      index 17,
  TEKRestoreSetup  index 18,
  TEKEnd           index 19;

begin
end.
