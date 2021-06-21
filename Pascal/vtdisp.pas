{ Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved. }

{ TERATERM.EXE, VT terminal display routines }
unit VTDisp;

interface     
{$i teraterm.inc}

{$IFDEF Delphi}
uses WinTypes, WinProcs, Strings, TTTypes, Types, TTCommon,
  TTDialog, TTWinMan, TTIME;
{$ELSE}
uses WinTypes, WinProcs, Win31, Strings, TTTypes, Types, TTCommon,
  TTDialog, TTWinMan, TTIME;
{$ENDIF}

procedure InitDisp;
procedure EndDisp;
procedure DispReset;
procedure DispConvWinToScreen
  (Xw, Yw: integer; Xs, Ys: Pinteger; Right: PBOOL);
procedure SetLogFont;
procedure ChangeFont;
procedure ResetIME;
procedure ChangeCaret;
procedure CaretOn;
procedure CaretOff;
procedure DispDestroyCaret;
function IsCaretOn: bool;
procedure DispEnableCaret(Enable: BOOL);
function IsCaretEnabled: bool;
procedure DispSetCaretWidth(DW: BOOL);
procedure DispChangeWinSize(Nx, Ny: integer);
procedure ResizeWindow(x, y, w, h, cw, ch: integer);
procedure PaintWindow(PaintDC: HDC; PaintRect: TRect; fBkGnd: BOOL;
  var Xs, Ys, Xe, Ye: integer);
procedure DispEndPaint;
procedure DispClearWin;
procedure DispChangeBackground;
procedure DispChangeWin;
procedure DispInitDC;
procedure DispReleaseDC;
procedure DispSetupDC(Attr, Attr2: byte; Reverse: bool);
procedure DispStr(Buff: PChar; Count, Y: integer; var X: integer);
procedure DispEraseCurToEnd(YEnd: integer);
procedure DispEraseHomeToCur(YHome: integer);
procedure DispEraseCharsInLine(XStart, Count: integer);
function DispDeleteLines(Count, YEnd: integer): bool;
function DispInsertLines(Count, YEnd: integer): bool;
function IsLineVisible(var X, Y: integer): bool;
procedure AdjustScrollBar;
procedure DispScrollToCursor(CurX, CurY: integer);
procedure DispScrollNLines(Top, Bottom, Direction: integer);
procedure DispCountScroll(n: integer);
procedure DispUpdateScroll;
procedure DispScrollHomePos;
procedure DispAutoScroll(p: TPOINT);
procedure DispHScroll(Func, Pos: integer);
procedure DispVScroll(Func, Pos: integer);
procedure DispSetupFontDlg;
procedure DispRestoreWinSize;
procedure DispSetWinPos;
procedure DispSetActive(ActiveFlag: BOOL);

var
  WinWidth, WinHeight: integer;
  VTFont: array[0..AttrFontMask] of HFont;
  FontHeight, FontWidth, ScreenWidth, ScreenHeight: integer;
  AdjustSize, DontChangeSize: BOOL;
  CursorX, CursorY: integer;

  {--- scrolling status flags}
  WinOrgX, WinOrgY, NewOrgX, NewOrgY: integer;

  NumOfLines, NumOfColumns: integer;
  PageStart, BuffEnd: integer;

const
  SCROLL_BOTTOM   = 1;
  SCROLL_LINEDOWN = 2;
  SCROLL_LINEUP   = 3;
  SCROLL_PAGEDOWN = 4;
  SCROLL_PAGEUP   = 5;
  SCROLL_POS	  = 6;
  SCROLL_TOP	  = 7;

implementation

const
  CurWidth = 2;

var
  Active: bool;
  CompletelyVisible: bool;
  CRTWidth, CRTHeight: integer;
  CursorOnDBCS: bool;
  VTlf: TLOGFONT;
  SaveWinSize: bool;
  WinWidthOld, WinHeightOld: integer;
  Background: HBRUSH;
  ANSIColor: array[0..15] of TCOLORREF;
  Dx: array[0..255] of integer;

{caret variables}
  CaretStatus: integer;
  CaretEnabled: bool;

{---- device context and status flags}
  VTDC: HDC; {Device context for VT window}
  DCAttr, DCAttr2: byte;
  DCReverse: bool;
  DCPrevFont: HFONT;

{scrolling}
  ScrollCount: integer;
  dScroll: integer;
  SRegionTop: integer;
  SRegionBottom: integer;

procedure InitDisp;
var
  TmpDC: HDC;
  i: integer;
begin
  TmpDC := GetDC(0);

  if (ts.ColorFlag and CF_USETEXTCOLOR)=0 then
    ANSIColor[IdBack ]   := RGB(  0,  0,  0)
  else {use background color for "Black"}
    ANSIColor[IdBack ]   := ts.VTColor[1];
  ANSIColor[IdRed  ]     := RGB(255,  0,  0);
  ANSIColor[IdGreen]     := RGB(  0,255,  0);
  ANSIColor[IdYellow]    := RGB(255,255,  0);
  ANSIColor[IdBlue]      := RGB(  0,  0,255);
  ANSIColor[IdMagenta]   := RGB(255,  0,255);
  ANSIColor[IdCyan]      := RGB(  0,255,255);
  if (ts.ColorFlag and CF_USETEXTCOLOR)=0 then
    ANSIColor[IdFore ]   := RGB(255,255,255)
  else {use text color for "white"}
    ANSIColor[IdFore ]   := ts.VTColor[0];

  ANSIColor[IdBack+8]    := RGB(128,128,128);
  ANSIColor[IdRed+8]     := RGB(128,  0,  0);
  ANSIColor[IdGreen+8]   := RGB(  0,128,  0);
  ANSIColor[IdYellow+8]	 := RGB(128,128,  0);
  ANSIColor[IdBlue+8]    := RGB(  0,  0,128);
  ANSIColor[IdMagenta+8] := RGB(128,  0,128);
  ANSIColor[IdCyan+8]    := RGB(  0,128,128);
  ANSIColor[IdFore+8]    := RGB(192,192,192);

  for i := IdBack to IdFore+8 do
    ANSIColor[i] := GetNearestColor(TmpDC, ANSIColor[i]);

  {background paintbrush}
  Background := CreateSolidBrush(ts.VTColor[1]);
  {CRT width & height}
  CRTWidth := GetDeviceCaps(TmpDC,HORZRES);
  CRTHeight := GetDeviceCaps(TmpDC,VERTRES);

  ReleaseDC(0, TmpDC);

  if (ts.VTPos.x > CRTWidth) or (ts.VTPos.y > CRTHeight) then
  begin
    ts.VTPos.x := CW_USEDEFAULT;
    ts.VTPos.y := CW_USEDEFAULT;
  end;

  if (ts.TEKPos.x > CRTWidth) or (ts.TEKPos.y > CRTHeight) then
  begin
    ts.TEKPos.x := CW_USEDEFAULT;
    ts.TEKPos.y := CW_USEDEFAULT;
  end;
end;

procedure EndDisp;
var
  i, j: integer;
begin
  if VTDC<>0 then DispReleaseDC;

  {Delete fonts}
  for i := 0 to AttrFontMask do
  begin
    for j := i+1 to AttrFontMask do
      if VTFont[j]=VTFont[i] then
        VTFont[j] := 0;
    if VTFont[i]<>0 then DeleteObject(VTFont[i]);
  end;

  if Background<>0 then
  begin
    DeleteObject(Background);
    Background := 0;
  end;
end;

procedure DispReset;
begin
  {Cursor}
  CursorX := 0;
  CursorY := 0;

  {Scroll status}
  ScrollCount := 0;
  dScroll := 0;

  if IsCaretOn then CaretOn;
  DispEnableCaret(TRUE); {enable caret}
end;

procedure DispConvWinToScreen
  (Xw, Yw: integer; Xs, Ys: Pinteger; Right: PBOOL);
{ Converts window coordinate to screen cordinate
   Xs: horizontal position in window coordinate (pixels)
   Ys: vertical
  Output
	 Xs, Ys: screen coordinate
   Right: TRUE if the (Xs,Ys) is on the right half of
			 a character cell. }
begin
  if Xs<>nil then
    Xs^ := Xw div FontWidth + WinOrgX;
  Ys^ := Yw div FontHeight + WinOrgY;
  if (Xs<>nil) and (Right<>nil) then
    Right^ := (Xw - (Xs^-WinOrgX)*FontWidth) >= FontWidth div 2;
end;

procedure SetLogFont;
begin
  FillChar(VTlf, sizeof(TLOGFONT), 0);
  with VTlf do begin
    lfWeight := FW_NORMAL;
    lfItalic := 0;
    lfUnderline := 0;
    lfStrikeOut := 0;
    lfWidth := ts.VTFontSize.x;
    lfHeight := ts.VTFontSize.y;
    lfCharSet := ts.VTFontCharSet;
    lfOutPrecision := OUT_CHARACTER_PRECIS;
    lfClipPrecision := CLIP_CHARACTER_PRECIS;
    lfQuality       := DEFAULT_QUALITY;
    lfPitchAndFamily := FIXED_PITCH or FF_DONTCARE;
    strcopy(lfFaceName,ts.VTFont);
  end;
end;

procedure ChangeFont;
var
  i,j: integer;
  Metrics: TTEXTMETRIC;
  TmpDC: HDC;
begin
  {Delete Old Fonts}
  for i := 0 to AttrFontMask do
  begin
    for j := i+1 to AttrFontMask do
      if VTFont[j]=VTFont[i] then
        VTFont[j] := 0;
    if VTFont[i]<>0 then
      DeleteObject(VTFont[i]);
  end;

  {Normal Font}
  SetLogFont;
  VTFont[0] := CreateFontIndirect(VTlf);

  {set IME font}
  SetConversionLogFont(@VTlf);

  TmpDC := GetDC(HVTWin);

  SelectObject(TmpDC, VTFont[0]);
  GetTextMetrics(TmpDC, Metrics); 
  FontWidth := Metrics.tmAveCharWidth + ts.FontDW;
  FontHeight := Metrics.tmHeight + ts.FontDH;

  ReleaseDC(HVTWin,TmpDC);

  {Underline}
  VTlf.lfUnderline := 1;
  VTFont[AttrUnder] := CreateFontIndirect(VTlf);

  if ts.EnableBold>0 then
  begin
    {Bold}
    VTlf.lfUnderline := 0;
    VTlf.lfWeight := FW_BOLD;
    VTFont[AttrBold] := CreateFontIndirect(VTlf);
    {Bold + Underline}
    VTlf.lfUnderline := 1;
    VTFont[AttrBold or AttrUnder] := CreateFontIndirect(VTlf);
  end
  else begin
    VTFont[AttrBold] := VTFont[AttrDefault];
    VTFont[AttrBold or AttrUnder] := VTFont[AttrUnder];
  end;

  {Special font}
  VTlf.lfWeight := FW_NORMAL;
  VTlf.lfUnderline := 0;
  VTlf.lfWidth := FontWidth + 1; {adjust width}
  VTlf.lfHeight := FontHeight;
  VTlf.lfCharSet := SYMBOL_CHARSET;

  strcopy(VTlf.lfFaceName,'Tera Special');
  VTFont[AttrSpecial] := CreateFontIndirect(VTlf);
  VTFont[AttrSpecial or AttrBold] := VTFont[AttrSpecial];
  VTFont[AttrSpecial or AttrUnder] := VTFont[AttrSpecial];
  VTFont[AttrSpecial or AttrBold or AttrUnder] := VTFont[AttrSpecial];

  SetLogFont;

  for i := 0 to 255 do
    Dx[i] := FontWidth;
end;

procedure ResetIME;
begin
  {reset language for communication}
  cv.Language := ts.Language;

  {reset IME}
  if ts.Language=IdJapanese then
  begin
    if ts.UseIME=0 then
      FreeIME
    else if not LoadIME then
      ts.UseIME := 0;

    if ts.UseIME>0 then
    begin
      if ts.IMEInline>0 then
        SetConversionLogFont(@VTlf)
      else
        SetConversionWindow(HVTWin,-1,0);
    end;
  end
  else
    FreeIME;

  if IsCaretOn then CaretOn;
end;

procedure ChangeCaret;
var
  T: UINT;
begin
  if not Active then exit;
  if CaretEnabled then
  begin
    DestroyCaret;
    case ts.CursorShape of
      IdVCur:
        CreateCaret(HVTWin, 0, CurWidth, FontHeight);
      IdHCur:
        CreateCaret(HVTWin, 0, FontWidth, CurWidth);
    end;
    CaretStatus := 1;
  end;
  CaretOn;
  if CaretEnabled and
     (ts.NonblinkingCursor<>0) then
  begin
    T := GetCaretBlinkTime * 2 div 3;
    SetTimer(HVTWin,IdCaretTimer,T,nil);
  end;
end;

procedure CaretOn;
{Turn on the cursor}
var
  CaretX, CaretY, H: integer;
begin
  if not Active then exit;

  CaretX := (CursorX-WinOrgX)*FontWidth;
  CaretY := (CursorY-WinOrgY)*FontHeight;

  if (ts.Language=IdJapanese) and
     CanUseIME and (ts.IMEInline>0) then
    {set IME conversion window pos. & font}
    SetConversionWindow(HVTWin,CaretX,CaretY);

  if not CaretEnabled then exit;

  if ts.CursorShape<>IdVCur then
  begin
    if ts.CursorShape=IdHCur then
    begin
     CaretY := CaretY+FontHeight-CurWidth;
     H := CurWidth;
    end
    else H := FontHeight;

    DestroyCaret;
    if CursorOnDBCS then
      CreateCaret(HVTWin, 0, FontWidth*2, H) {double width caret}
    else
      CreateCaret(HVTWin, 0, FontWidth, H); {single width caret}
    CaretStatus := 1;
  end;

  SetCaretPos(CaretX,CaretY);

  while CaretStatus > 0 do
  begin
    ShowCaret(HVTWin);
    dec(CaretStatus);
  end;

end;

procedure CaretOff;
begin
  if not Active then exit;
  if CaretStatus = 0 then
  begin
    HideCaret(HVTWin);
    inc(CaretStatus);
  end;
end;

procedure DispDestroyCaret;
begin
  DestroyCaret;
  if ts.NonblinkingCursor<>0 then
    KillTimer(HVTWin,IdCaretTimer);
end;

function IsCaretOn: bool;
{check if caret is on}
begin
  IsCaretOn := Active and (CaretStatus=0);
end;

procedure DispEnableCaret(Enable: BOOL);
begin
  if not Enable then CaretOff;
  CaretEnabled := Enable;
end;

function IsCaretEnabled: bool;
begin
  IsCaretEnabled := CaretEnabled;
end;

procedure DispSetCaretWidth(DW: BOOL);
begin
  {TRUE if cursor is on a DBCS character}
  CursorOnDBCS := DW;
end;

procedure DispChangeWinSize(Nx, Ny: integer);
var
  W, H, dW, dH: longint;
  R: TRECT;
begin
  if SaveWinSize then
  begin
    WinWidthOld := WinWidth;
    WinHeightOld := WinHeight;
    SaveWinSize := FALSE;
  end
  else begin
    WinWidthOld := NumOfColumns;
    WinHeightOld := NumOfLines;
  end;

  WinWidth := Nx;
  WinHeight := Ny;

  ScreenWidth := WinWidth*FontWidth;
  ScreenHeight := WinHeight*FontHeight;

  AdjustScrollBar;

  GetWindowRect(HVTWin,R);
  W := R.right-R.left;
  H := R.bottom-R.top;
  GetClientRect(HVTWin,R);
  dW := ScreenWidth - R.right + R.left;
  dH := ScreenHeight - R.bottom + R.top;
  
  if (dW<>0) or (dH<>0) then
  begin
    AdjustSize := TRUE;
    SetWindowPos(HVTWin,HWND_TOP,0,0,W+dW,H+dH,SWP_NOMOVE);
  end
  else
    InvalidateRect(HVTWin,nil,FALSE);
end;

procedure ResizeWindow(x, y, w, h, cw, ch: integer);
var
  dw,dh, NewX, NewY: integer;
  Point: TPOINT;
begin
  if not AdjustSize then exit;
  dw := ScreenWidth - cw;
  dh := ScreenHeight - ch;
  if (dw<>0) or (dh<>0) then
    SetWindowPos(HVTWin,HWND_TOP,x,y,w+dw,h+dh,SWP_NOMOVE)
  else begin
    AdjustSize := FALSE;

    NewX := x;
    NewY := y;
    if x+w > CRTWidth then
    begin
      NewX := CRTWidth-w;
      if NewX < 0 then NewX := 0;
    end;
    if y+h > CRTHeight then
    begin
      NewY := CRTHeight-h;
      if NewY < 0 then NewY := 0;
    end;
    if (NewX<>x) or (NewY<>y) then
      SetWindowPos(HVTWin,HWND_TOP,NewX,NewY,w,h,SWP_NOSIZE);

    Point.x := 0;
    Point.y := ScreenHeight;
    ClientToScreen(HVTWin,Point);
    CompletelyVisible := (Point.y <= CRTHeight);
    if IsCaretOn then CaretOn;
  end;
end;

procedure PaintWindow(PaintDC: HDC; PaintRect: TRect; fBkGnd: BOOL;
  var Xs, Ys, Xe, Ye: integer);
{  Paint window with background color &
  convert paint region from window coord. to screen coord.
  Called from WM_PAINT handler
    PaintRect: Paint region in window coordinate
    Return:
	*Xs, *Ys: upper left corner of the region
		    in screen coord.
	*Xe, *Ye: lower right }
begin
  if VTDC<>0 then
    DispReleaseDC;
  VTDC := PaintDC;
  DCPrevFont := SelectObject(VTDC, VTFont[0]);
  DispInitDC;
  if fBkGnd then
    FillRect(VTDC,PaintRect,Background);

  Xs := PaintRect.left div FontWidth + WinOrgX;
  Ys := PaintRect.top div FontHeight + WinOrgY;
  Xe := (PaintRect.right-1) div FontWidth + WinOrgX;
  Ye := (PaintRect.bottom-1) div FontHeight + WinOrgY;
end;

procedure DispEndPaint;
begin
  if VTDC=0 then exit;
  SelectObject(VTDC,DCPrevFont);
  VTDC := 0;
end;

procedure DispClearWin;
begin
  InvalidateRect(HVTWin,nil,FALSE);

  ScrollCount := 0;
  dScroll := 0;
  if WinHeight > NumOfLines then
    DispChangeWinSize(NumOfColumns,NumOfLines)
  else begin
    if (NumOfLines=WinHeight) and (ts.EnableScrollBuff>0) then
    begin
      SetScrollRange(HVTWin,SB_VERT,0,1,FALSE);
    end
    else 
      SetScrollRange(HVTWin,SB_VERT,0,NumOfLines-WinHeight,FALSE);

    SetScrollPos(HVTWin,SB_HORZ,0,TRUE);
    SetScrollPos(HVTWin,SB_VERT,0,TRUE);
  end;
  if IsCaretOn then CaretOn;
end;

procedure DispChangeBackground;
begin
  DispReleaseDC;
  if Background <> 0 then DeleteObject(Background);
  Background := CreateSolidBrush(ts.VTColor[1]);

  InvalidateRect(HVTWin,nil,TRUE);
end;

procedure DispChangeWin;
begin
  {Change window caption}
  ChangeTitle;

  {Menu bar / Popup menu}
  SwitchMenu;

  SwitchTitleBar;

  {Change caret shape}
  ChangeCaret;

  if (ts.ColorFlag and CF_USETEXTCOLOR)=0 then
  begin
    ANSIColor[IdFore ]   := RGB(255,255,255);
    ANSIColor[IdBack ]   := RGB(  0,  0,  0);
  end
  else begin {use text (background) color for "white (black)"}
    ANSIColor[IdFore ]   := ts.VTColor[0];
    ANSIColor[IdBack ]   := ts.VTColor[1];
  end;

  {change background color}
  DispChangeBackground;
end;

procedure DispInitDC;
begin
  if VTDC=0 then
  begin
    VTDC := GetDC(HVTWin);
    DCPrevFont := SelectObject(VTDC, VTFont[0]);
  end
  else
    SelectObject(VTDC, VTFont[0]);
  SetTextColor(VTDC, ts.VTColor[0]);
  SetBkColor(VTDC, ts.VTColor[1]);
  SetBkMode(VTDC,OPAQUE);
  DCAttr := AttrDefault;
  DCAttr2 := AttrDefault2;
  DCReverse := FALSE;
end;

procedure DispReleaseDC;
begin
  if VTDC=0 then exit;
  SelectObject(VTDC, DCPrevFont);
  ReleaseDC(HVTWin,VTDC);
  VTDC := 0;
end;

procedure DispSetupDC(Attr, Attr2: byte; Reverse: bool);
{ Setup device context
   Attr, Attr2: character attribute 1 & 2
   Reverse: true if text is selected (reversed) by mouse}
var
  TextColor, BackColor: TCOLORREF;
  i, j: integer;
begin
  if VTDC=0 then DispInitDC;

  if (DCAttr=Attr) and (DCAttr2=Attr2) and
     (DCReverse=Reverse) then exit;
  DCAttr := Attr;
  DCAttr2 := Attr2;
  DCReverse := Reverse;
     
  SelectObject(VTDC, VTFont[Attr and AttrFontMask]);

  if (ts.ColorFlag and CF_FULLCOLOR) = 0 then
  begin
    if (Attr and AttrBlink) <> 0 then
    begin
      TextColor := ts.VTBlinkColor[0];
      BackColor := ts.VTBlinkColor[1];
    end
    else if (Attr and AttrBold) <> 0 then
    begin
      TextColor := ts.VTBoldColor[0];
      BackColor := ts.VTBoldColor[1];
    end
    else begin
      if (Attr2 and Attr2Fore) <> 0 then
      begin
        j := Attr2 and Attr2ForeMask;
	TextColor := ANSIColor[j];
      end
      else
        TextColor := ts.VTColor[0];

      if (Attr2 and Attr2Back) <> 0 then
      begin
        j := (Attr2 and Attr2BackMask) shr SftAttrBack;
	BackColor := ANSIColor[j];
      end
      else
        BackColor := ts.VTColor[1];
    end;
  end
  else begin {full color}
    if (Attr2 and Attr2Fore) <> 0 then
    begin
      if (Attr and AttrBold) <> 0 then
        i := 0
      else
        i := 8;
      j := Attr2 and Attr2ForeMask;
      if j=0 then
        j := 8 - i + j
      else
        j := i + j;
      TextColor := ANSIColor[j];
    end
    else if (Attr and AttrBlink) <> 0 then
      TextColor := ts.VTBlinkColor[0]
    else if (Attr and AttrBold) <> 0 then
      TextColor := ts.VTBoldColor[0]          
    else
      TextColor := ts.VTColor[0];

    if (Attr2 and Attr2Back) <> 0 then
    begin
      if (Attr and AttrBlink) <> 0 then
        i := 0
      else
        i := 8;
      j := (Attr2 and Attr2BackMask) shr SftAttrBack;
      if j=0 then
        j := 8 - i + j
      else
        j := i + j;
      BackColor := ANSIColor[j];
    end
    else if (Attr and AttrBlink) <> 0 then
      BackColor := ts.VTBlinkColor[1]
    else if (Attr and AttrBold) <> 0 then
      BackColor := ts.VTBoldColor[1]          
    else
      BackColor := ts.VTColor[1];
  end;

  if Reverse <> ((Attr and AttrReverse) <> 0) then
  begin
    SetTextColor(VTDC,BackColor);
    SetBkColor(  VTDC,TextColor);
  end
  else begin
    SetTextColor(VTDC,TextColor);
    SetBkColor(  VTDC,BackColor);
  end;
end;

procedure DispStr(Buff: PChar; Count, Y: integer; var X: integer);
{ Display a string
   Buff: points the string
   Y: vertical position in window cordinate
  *X: horizontal position
 Return:
  *X: horizontal position shifted by the width of the string }
var
  RText: TRECT;
begin
  if (ts.Language=IdRussian) and
     (ts.RussClient<>ts.RussFont) then
    RussConvStr(ts.RussClient,ts.RussFont,Buff,Count);

  RText.top := Y;
  RText.bottom := Y+FontHeight;
  RText.left := X;
  RText.right := X + Count*FontWidth;
  ExtTextOut(VTDC,X+ts.FontDX,Y+ts.FontDY,
             ETO_CLIPPED or ETO_OPAQUE,
             @RText,Buff,Count,@Dx[0]);
  X := RText.right;

  if (ts.Language=IdRussian) and
     (ts.RussClient<>ts.RussFont) then
    RussConvStr(ts.RussFont,ts.RussClient,Buff,Count);
end;

procedure DispEraseCurToEnd(YEnd: integer);
var
  R: TRECT;
begin
  if VTDC=0 then DispInitDC;
  R.left := 0;
  R.right := ScreenWidth;
  R.top := (CursorY+1-WinOrgY)*FontHeight;
  R.bottom := (YEnd+1-WinOrgY)*FontHeight;
  FillRect(VTDC,R,Background);
  R.left := (CursorX-WinOrgX)*FontWidth;
  R.bottom := R.top;
  R.top := R.bottom-FontHeight;
  FillRect(VTDC,R,Background);
end;

procedure DispEraseHomeToCur(YHome: integer);
var
  R: TRECT;
begin
  if VTDC=0 then DispInitDC;
  R.left := 0;
  R.right := ScreenWidth;
  R.top := (YHome-WinOrgY)*FontHeight;
  R.bottom := (CursorY-WinOrgY)*FontHeight;
  FillRect(VTDC,R,Background);
  R.top := R.bottom;
  R.bottom := R.top + FontHeight;
  R.right := (CursorX+1-WinOrgX)*FontWidth;
  FillRect(VTDC,R,Background);
end;

procedure DispEraseCharsInLine(XStart, Count: integer);
var
  R: TRECT;
begin
  if VTDC=0 then DispInitDC;
  R.top := (CursorY-WinOrgY)*FontHeight;
  R.bottom := R.top+FontHeight;
  R.left := (XStart-WinOrgX)*FontWidth;
  R.right := R.left + Count * FontWidth;
  FillRect(VTDC,R,Background);
end;

function DispDeleteLines(Count, YEnd: integer): bool;
{ return value:
   TRUE  - screen is successfully updated
   FALSE - screen is not updated }
var
  R: TRECT;
begin
  if Active and CompletelyVisible and
    (YEnd+1-WinOrgY <= WinHeight) then
  begin  
    R.left := 0;
    R.right := ScreenWidth;
    R.top := (CursorY-WinOrgY)*FontHeight;
    R.bottom := (YEnd+1-WinOrgY)*FontHeight;
    ScrollWindow(HVTWin,0,-FontHeight*Count,@R,@R);
    UpdateWindow(HVTWin);
    DispDeleteLines := TRUE;
  end
  else
    DispDeleteLines := FALSE;
end;

function DispInsertLines(Count, YEnd: integer): bool;
{ return value:
   TRUE  - screen is successfully updated
   FALSE - screen is not updated }
var
  R: TRECT;
begin
  if Active and CompletelyVisible and
     (CursorY >= WinOrgY) then
  begin
    R.left := 0;
    R.right := ScreenWidth;
    R.top := (CursorY-WinOrgY)*FontHeight;
    R.bottom := (YEnd+1-WinOrgY)*FontHeight;
    ScrollWindow(HVTWin,0,FontHeight*Count,@R,@R);
    UpdateWindow(HVTWin);
    DispInsertLines := TRUE;
  end
  else
    DispInsertLines := FALSE;
end;

function IsLineVisible(var X, Y: integer): bool;
{  Check the visibility of a line
	called from UpdateStr
    X, Y: position of a character in the line. screen coord.
    Return: TRUE if the line is visible.
	X, Y:
	  If the line is visible
	    position of the character in window coord.
	  Otherwise
	    no change. same as input value. }
begin
  IsLineVisible := FALSE;
  if (dScroll <> 0) and
     (Y>=SRegionTop) and
     (Y<=SRegionBottom) then
  begin
    Y := Y + dScroll;
    if (Y<SRegionTop) or (Y>SRegionBottom) then
      exit;
  end;

  if (Y<WinOrgY) or
     (Y>=WinOrgY+WinHeight) then
    exit;

  {screen coordinate -> window coordinate}
  X := (X-WinOrgX)*FontWidth;
  Y := (Y-WinOrgY)*FontHeight;
  IsLineVisible := TRUE;
end;

{-------------- scrolling functions --------------------}

procedure AdjustScrollBar; {called by ChangeWindowSize}
var
  XRange, YRange: longint;
  ScrollPosX, ScrollPosY: integer;
begin
  if NumOfColumns-WinWidth>0 then
    XRange := NumOfColumns-WinWidth
  else
    XRange := 0;

  if BuffEnd-WinHeight>0 then
    YRange := BuffEnd-WinHeight
  else
    YRange := 0;

  ScrollPosX := GetScrollPos(HVTWin,SB_HORZ);
  ScrollPosY := GetScrollPos(HVTWin,SB_VERT);
  if ScrollPosX > XRange then
    ScrollPosX := XRange;
  if ScrollPosY > YRange then
    ScrollPosY := YRange;

  WinOrgX := ScrollPosX;
  WinOrgY := ScrollPosY-PageStart;
  NewOrgX := WinOrgX;
  NewOrgY := WinOrgY;

  DontChangeSize := TRUE;

  SetScrollRange(HVTWin,SB_HORZ,0,XRange,FALSE);

  if (YRange = 0) and (ts.EnableScrollBuff>0) then
  begin
    SetScrollRange(HVTWin,SB_VERT,0,1,FALSE);
  end
  else begin
    SetScrollRange(HVTWin,SB_VERT,0,YRange,FALSE);
  end;

  SetScrollPos(HVTWin,SB_HORZ,ScrollPosX,TRUE);
  SetScrollPos(HVTWin,SB_VERT,ScrollPosY,TRUE);

  DontChangeSize := FALSE;  
end;

procedure DispScrollToCursor(CurX, CurY: integer);
begin
  if CurX < NewOrgX then 
    NewOrgX := CurX
  else if CurX >= NewOrgX+WinWidth then
    NewOrgX := CurX + 1 - WinWidth;

  if CurY < NewOrgY then
    NewOrgY := CurY
  else if CurY >= NewOrgY+WinHeight then
    NewOrgY := CurY + 1 - WinHeight;
end;

procedure DispScrollNLines(Top, Bottom, Direction: integer);
{  Scroll a region of the window by Direction lines
    updates window if necessary
  Top: top line of scroll region
  Bottom: bottom line
  Direction: +: forward, -: backward }
begin
  if (dScroll*Direction <0) or
      (dScroll*Direction >0) and
      ((SRegionTop<>Top) or
       (SRegionBottom<>Bottom)) then
    DispUpdateScroll;
  SRegionTop := Top;
  SRegionBottom := Bottom;
  dScroll := dScroll + Direction;
  if Direction>0 then
    DispCountScroll(Direction)
  else
    DispCountScroll(-Direction);
end;

procedure DispCountScroll(n: integer);
begin
  ScrollCount := ScrollCount + n;
  if ScrollCount>=ts.ScrollThreshold then DispUpdateScroll;
end;

procedure DispUpdateScroll;
var
  d: integer;
  R: TRECT;
begin
  ScrollCount := 0;

  {Update partial scroll}
  if dScroll <> 0 then
  begin
    d := dScroll * FontHeight;
    R.left := 0;
    R.right := ScreenWidth;
    R.top := (SRegionTop-WinOrgY)*FontHeight;
    R.bottom := (SRegionBottom+1-WinOrgY)*FontHeight;
    ScrollWindow(HVTWin,0,-d,@R,@R);
    if (SRegionTop=0) and (dScroll>0) then
    begin {update scroll bar if BuffEnd is changed}
      if (BuffEnd=WinHeight) and
         (ts.EnableScrollBuff>0) then
        SetScrollRange(HVTWin,SB_VERT,0,1,TRUE)
      else
        SetScrollRange(HVTWin,SB_VERT,0,BuffEnd-WinHeight,FALSE);
      SetScrollPos(HVTWin,SB_VERT,WinOrgY+PageStart,TRUE);
    end;
    dScroll := 0;
  end;

  {Update normal scroll}
  if NewOrgX < 0 then NewOrgX := 0;
  if NewOrgX>NumOfColumns-WinWidth then
    NewOrgX := NumOfColumns-WinWidth;
  if NewOrgY < -PageStart then NewOrgY := -PageStart;
  if NewOrgY>BuffEnd-WinHeight-PageStart then
    NewOrgY := BuffEnd-WinHeight-PageStart;

  if (NewOrgX=WinOrgX) and
     (NewOrgY=WinOrgY) then exit;

  if NewOrgX=WinOrgX then
  begin
    d := (NewOrgY-WinOrgY) * FontHeight;
    ScrollWindow(HVTWin,0,-d,nil,nil);
  end
  else if (NewOrgY=WinOrgY) then
  begin
    d := (NewOrgX-WinOrgX) * FontWidth;
    ScrollWindow(HVTWin,-d,0,nil,nil);
  end
  else
    InvalidateRect(HVTWin,nil,TRUE);

  {Update scroll bars}
  if NewOrgX<>WinOrgX then
    SetScrollPos(HVTWin,SB_HORZ,NewOrgX,TRUE);

  if NewOrgY<>WinOrgY then
  begin
    if (BuffEnd=WinHeight) and
       (ts.EnableScrollBuff>0) then
      SetScrollRange(HVTWin,SB_VERT,0,1,TRUE)
    else
      SetScrollRange(HVTWin,SB_VERT,0,BuffEnd-WinHeight,FALSE);
    SetScrollPos(HVTWin,SB_VERT,NewOrgY+PageStart,TRUE);
  end;

  WinOrgX := NewOrgX;
  WinOrgY := NewOrgY;

  if IsCaretOn then CaretOn;
end;

procedure DispScrollHomePos;
begin
  NewOrgX := 0;
  NewOrgY := 0;
  DispUpdateScroll;
end;

procedure DispAutoScroll(p: TPOINT);
var
  X, Y: integer;
begin
  X := (p.x + FontWidth div 2) div FontWidth;
  Y := p.y div FontHeight;
  if X<0 then
    NewOrgX := WinOrgX + X
  else if X>=WinWidth then
    NewOrgX := NewOrgX + X - WinWidth + 1;
  if Y<0 then
    NewOrgY := WinOrgY + Y
  else if Y>=WinHeight then
    NewOrgY := NewOrgY + Y - WinHeight + 1;

  DispUpdateScroll;
end;

procedure DispHScroll(Func, Pos: integer);
begin
  case Func of
    SCROLL_BOTTOM:
      NewOrgX := NumOfColumns-WinWidth;
    SCROLL_LINEDOWN:
      NewOrgX := WinOrgX + 1;
    SCROLL_LINEUP:
      NewOrgX := WinOrgX - 1;
    SCROLL_PAGEDOWN:
      NewOrgX := WinOrgX + WinWidth - 1;
    SCROLL_PAGEUP:
      NewOrgX := WinOrgX - WinWidth + 1;
    SCROLL_POS:
      NewOrgX := Pos;
    SCROLL_TOP:
      NewOrgX := 0;
  end;
  DispUpdateScroll;
end;

procedure DispVScroll(Func, Pos: integer);
begin
  case Func of
    SCROLL_BOTTOM:
      NewOrgY := BuffEnd-WinHeight-PageStart;
    SCROLL_LINEDOWN:
      NewOrgY := WinOrgY + 1;
    SCROLL_LINEUP:
      NewOrgY := WinOrgY - 1;
    SCROLL_PAGEDOWN:
      NewOrgY := WinOrgY + WinHeight - 1;
    SCROLL_PAGEUP:
      NewOrgY := WinOrgY - WinHeight + 1;
    SCROLL_POS:
      NewOrgY := Pos-PageStart;
    SCROLL_TOP:
      NewOrgY := -PageStart;
  end;
  DispUpdateScroll;
end;

{-------------- end of scrolling functions --------}

procedure DispSetupFontDlg;
{  Popup the Setup Font dialogbox and
  reset window }
var
  Ok: BOOL;
begin
  if not LoadTTDLG then exit;
  SetLogFont;
  Ok := ChooseFontDlg(HVTWin,@VTlf,@ts);
  FreeTTDLG;
  if not Ok then exit;

  strcopy(ts.VTFont,VTlf.lfFaceName);
  ts.VTFontSize.x := VTlf.lfWidth;
  ts.VTFontSize.y := VTlf.lfHeight;
  ts.VTFontCharSet := VTlf.lfCharSet;

  ChangeFont;

  DispChangeWinSize(WinWidth,WinHeight);

  ChangeCaret;
end;

procedure DispRestoreWinSize;
{ Restore window size by double clik on caption bar}
begin
  if ts.TermIsWin>0 then exit;

  if (WinWidth=NumOfColumns) and (WinHeight=NumOfLines) then
  begin
    if WinWidthOld > NumOfColumns then
      WinWidthOld := NumOfColumns;
    if WinHeightOld > BuffEnd then
      WinHeightOld := BuffEnd;
    DispChangeWinSize(WinWidthOld,WinHeightOld);
  end
  else begin
    SaveWinSize := TRUE;
    DispChangeWinSize(NumOfColumns,NumOfLines);
  end;
end;

procedure DispSetWinPos;
var
  CaretX, CaretY: integer;
  Point: TPOINT;
  R: TRECT;
begin
  GetWindowRect(HVTWin,R);
  ts.VTPos.x := R.left;
  ts.VTPos.y := R.top;

  if CanUseIME and (ts.IMEInline > 0) then
  begin
    CaretX := (CursorX-WinOrgX)*FontWidth;
    CaretY := (CursorY-WinOrgY)*FontHeight;
    {set IME conversion window pos.}
    SetConversionWindow(HVTWin,CaretX,CaretY);
  end;

  Point.x := 0;
  Point.y := ScreenHeight;
  ClientToScreen(HVTWin,Point);
  CompletelyVisible := (Point.y <= CRTHeight);
end;

procedure DispSetActive(ActiveFlag: BOOL);
begin
  Active := ActiveFlag;
  if Active then
  begin
    SetFocus(HVTWin);
    ActiveWin := IdVT;
  end
  else begin
    if (ts.Language=IdJapanese) and
       CanUseIME then
    {position & font of conv. window -> default}
      SetConversionWindow(HVTWin,-1,0);
  end;
end;

begin
  Active := FALSE;
  DontChangeSize := FALSE;
  CursorOnDBCS := FALSE;
  SaveWinSize := FALSE;
  CaretEnabled := TRUE;
  VTDC := 0;
  ScrollCount := 0;
  dScroll := 0;
end.
