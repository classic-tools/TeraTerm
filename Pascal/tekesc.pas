{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTTEK.DLL, TEK escape sequences}
unit TEKEsc;

interface
{$i teraterm.inc}

{$IFDEF Delphi}
uses
  WinTypes, WinProcs, TTTypes, TEKTypes, TTCommon, TEKDisp;
{$ELSE}
uses
  WinTypes, WinProcs, Win31, TTTypes, TEKTypes, TTCommon, TEKDisp;
{$ENDIF}

procedure ParseFirst(tk: PTEKVar; ts: PTTSet; cv: PComVar; b: byte);
procedure TEKEscape(tk: PTEKVar; ts: PTTSet; cv: PComVar; b: byte);
procedure SelectCode(tk: PTEKVar; ts: PTTSet; b: byte);
procedure TwoOpCode(tk: PTEKVar; ts: PTTSet; cv: PComVar; b: byte);
procedure ControlSequence(tk: PTEKVar; ts: PTTSet; cv: PComVar; b: byte);
procedure GraphText(tk: PTEKVar; ts: PTTSet; cv: PComVar; b: byte);

implementation

procedure Log1Byte(cv: PComVar; b: byte);
begin
  with cv^ do begin
    PChar(LogBuf)[LogPtr] := char(b);
    inc(LogPtr);
    if LogPtr>=InBuffSize then LogPtr := LogPtr-InBuffSize;
    if LCount>=InBuffSize then
    begin
      LCount := InBuffSize;
      LStart := LogPtr;
    end
    else inc(LCount);
  end;
end;

procedure ChangeTextSize(tk: PTEKVar; ts: PTTSet);
begin
with tk^ do begin
  SelectObject(MemDC,TEKFont[TextSize]);
  FontWidth := FW[TextSize];
  FontHeight := FH[TextSize];

  if Active then TEKChangeCaret(tk, ts);
end;
end;

procedure BackSpace(tk: PTEKVar; cv: PComVar);
begin
with tk^ do begin
  CaretX := CaretX - FontWidth;
  if CaretX < 0 then CaretX := 0;
  if cv^.HLogBuf<>0 then Log1Byte(cv,BS);
end;
end;

procedure LineFeed(tk: PTEKVar; cv: PComVar);
var
  CursorY: integer;
begin
with tk^ do begin
  CaretY := CaretY + FontHeight;
  if CaretY > ScreenHeight then
  begin
    CaretY := FontHeight;
    if (CaretOffset=0) or (CaretX < CaretOffset) then
    begin
      CaretOffset := ScreenWidth div 2;
      CaretX := CaretX + CaretOffset;
      if CaretX >= ScreenWidth then CaretX := CaretOffset;
    end
    else begin
      CaretX := CaretX - CaretOffset;
      CaretOffset := 0;
    end;
  end;
  if cv^.HLogBuf<>0 then Log1Byte(cv,LF);
end;
end;

procedure CarriageReturn(tk: PTEKVar; cv: PComVar);
begin
with tk^ do begin
  CaretX := CaretOffset;
  if (cv^.HLogBuf<>0) then Log1Byte(cv,CR);
end;
end;

procedure Tab(tk: PTEKVar; cv: PComVar);
begin
with tk^ do begin
  if cv^.HLogBuf<>0 then Log1Byte(cv,HT);
  CaretX := CaretX + FontWidth*8;
  if (CaretX>=ScreenWidth) then
  begin
    CarriageReturn(tk,cv);
    LineFeed(tk,cv);
  end;
end;
end;

procedure EnterVectorMode(tk: PTEKVar);
begin
with tk^ do begin
  MoveFlag := TRUE;
  Drawing := FALSE;
  DispMode := IdVectorMode;
end;
end;

procedure EnterMarkerMode(tk: PTEKVar);
begin
with tk^ do begin
  MoveFlag := TRUE;
  Drawing := FALSE;
  DispMode := IdMarkerMode;
end;
end;

procedure EnterPlotMode(tk: PTEKVar);
begin
with tk^ do begin
  if DispMode = IdAlphaMode then
    CaretOffset := 0;

  PlotX := Trunc(CaretX / ScreenWidth * ViewSizeX);
  PlotY := Trunc((ScreenHeight-1-CaretY) / ScreenHeight * ViewSizeY);
  DispMode := IdPlotMode;
  JustAfterRS := TRUE;
end;
end;

procedure EnterAlphaMode(tk: PTEKVar);
begin
with tk^ do begin
  if (DispMode = IdVectorMode) or
     (DispMode = IdPlotMode) then
    CaretOffset := 0;

  DispMode := IdAlphaMode;
  Drawing := FALSE;
end;
end;

procedure EnterUnknownMode(tk: PTEKVar);
begin
with tk^ do begin
  if (DispMode = IdVectorMode) or
     (DispMode = IdPlotMode) then
    CaretOffset := 0;

  DispMode := IdUnknownMode;
end;
end;

procedure TEKMoveTo(tk: PTEKVar; ts: PTTSet; X, Y: integer; Draw: boolean);
var
  DC: HDC;
  OldPen: HPen;
begin
with tk^ do begin
  if Draw then
  begin
    DC := GetDC(HWin);
    OldPen := SelectObject(DC,Pen);
    SetBkColor(DC,ts^.TEKColor[1]);
    SetBkMode(DC, 1);
    if (CaretX=X) and (CaretY=Y)
    then begin
      SetPixel(DC,X,Y,PenColor);
      SetPixel(MemDC,X,Y,MemPenColor);
    end
    else begin
      MoveToEx(DC,CaretX,CaretY,nil);
      LineTo(DC,X,Y);
      MoveToEx(MemDC,CaretX,CaretY,nil);
      LineTo(MemDC,X,Y);
    end;
    SelectObject(DC,OldPen);
    ReleaseDC(HWin,DC);
  end;
  CaretX := X;
  CaretY := Y;
end;
end;

procedure DrawMarker(tk: PTEKVar);
var
  b: byte;
  R: TRect;
  OldFont: HFont;
  OldColor: TCOLORREF;
begin
with tk^ do begin
  case MarkerType of
    0: b := $b7;
    1: b := ord('+');
    2: b := $c5;
    3: b := ord('*');
    4: b := ord('o');
    5: b := $b4;
    6: b := ord('O');
    7: b := $e0;
    8: b := $c6;
    9: b := $a8;
    10: b := $a7;
  else
    b := ord('+');
  end;
  OldFont := SelectObject(MemDC,MarkerFont);
  OldColor := SetTextColor(MemDC,PenColor);
  SetTextAlign(MemDC,TA_CENTER or TA_BOTTOM or TA_NOUPDATECP);
  ExtTextOut(MemDC,CaretX,CaretY+MarkerH div 2,
	  0,nil,@b,1,nil);
  SetTextAlign(MemDC,TA_LEFT or TA_BOTTOM or TA_NOUPDATECP);
  SelectObject(MemDC,OldFont);
  SetTextColor(MemDC,OldColor);
  R.left := CaretX - MarkerW;
  R.right := CaretX + MarkerW;
  R.top := CaretY - MarkerH;
  R.bottom := CaretY + MarkerH;
  InvalidateRect(HWin,@R,FALSE);
end;
end;

procedure Draw(tk: PTEKVar; cv: PComVar; ts: PTTSet; b: byte);
var
  X, Y: integer;
begin
with tk^ do begin
  if not Drawing then
  begin
    LoXReceive := FALSE;
    LoCount := 0;
    Drawing := TRUE;
    if DispMode=IdMarkerMode then
    begin
      MoveFlag := TRUE;
      MarkerFlag := TRUE;
    end
    else
      MarkerFlag := FALSE;
  end;

  case b of
    $00..$1f: begin
                CommInsert1Byte(cv,b);
                exit;
              end;
    $20..$3f: if LoCount=0 then HiY := b - $20
                           else HiX := b - $20;
    $40..$5f: begin
                LoX := b - $40;
                LoXReceive := TRUE;
              end;
    $60..$7f: begin
                LoA := LoB;
                LoB := b - $60;
                inc(LoCount);
              end;
  end;

  if not LoXReceive then exit;

  Drawing := FALSE;
  ParseMode := ModeFirst;

  if LoCount>1 then Extra := LoA;
  if LoCount>0 then LoY := LoB;

  X := Trunc((HiX*128+LoX*4+(Extra and 3)) / ViewSizeX * ScreenWidth);
  Y := ScreenHeight-1-Trunc((HiY*128+LoY*4+Extra div 4) / ViewSizeY * ScreenHeight);
  TEKMoveTo(tk,ts,X,Y,not MoveFlag);
  MoveFlag := FALSE;
  if MarkerFlag then
    DrawMarker(tk);
  MarkerFlag := FALSE;
end;
end;

procedure Plot(tk: PTEKVar; ts: PTTSet; b: byte);
var
  X, Y: integer;
begin
with tk^ do begin
  X := 0;
  Y := 0;
  case b of
    ord('A'): X := 4;
    ord('B'): X := -4;
    ord('D'): Y := 4;
    ord('E'): begin
                X := 4;
                Y := 4;
              end;
    ord('F'): begin
                X := -4;
                Y := 4;
              end;
    ord('H'): Y := -4;
    ord('I'): begin
                X := 4;
                Y := -4;
              end;  
    ord('J'): begin
                X := -4;
                Y := -4;
              end;
  else
    exit;
  end;
  PlotX := PlotX + X;
  if PlotX < 0 then PlotX := 0;
  if PlotX >= ViewSizeX then PlotX := ViewSizeX - 1;
  PlotY := PlotY + Y;
  if PlotY < 0 then PlotY := 0;
  if PlotY >= ViewSizeY then PlotY := ViewSizeY - 1;
  X := Trunc(PlotX / ViewSizeX * ScreenWidth);
  Y := ScreenHeight-1-Trunc(PlotY / ViewSizeY * ScreenHeight);
  TekMoveTo(tk,ts,X,Y,PenDown);
end;
end;

procedure DispChar(tk: PTEKVar; cv: PComVar; b: byte);
var
  Dx: array[0..1] of integer;
  R: TRect;
begin
with tk^ do begin
  Dx[0] := FontWidth;
  Dx[1] := FontWidth;
  ExtTextOut(MemDc,CaretX,CaretY,0,nil,@b,1,@Dx);
  R.left := CaretX;
  R.Right := CaretX + FontWidth;
  R.top := CaretY - FontHeight;
  R.bottom := CaretY;
  InvalidateRect(HWin,@R,FALSE);
  CaretX := R.Right;

  if cv^.HLogBuf<>0 then Log1Byte(cv,b);

  if (CaretX>ScreenWidth-FontWidth) then
  begin
    CarriageReturn(tk,cv);
    LineFeed(tk,cv);
  end;
end;
end;

procedure TEKBeep(ts: PTTSet);
begin
  if ts^.Beep <> 0 then
    MessageBeep(0);
end;

procedure ParseFirst(tk: PTEKVar; ts: PTTSet; cv: PComVar; b: byte);
begin
with tk^ do begin
  if DispMode = IdAlphaMode then
    case b of
      $00..$06:;
      $07: TEKBeep(ts);
      $08: BackSpace(tk,cv);
      $09: Tab(tk,cv);
      $0a: LineFeed(tk,cv);
      $0b..$0c:;
      $0d: begin
             CarriageReturn(tk,cv);
             if ts^.CRReceive=IdCRLF then
               CommInsert1Byte(cv,$0A);
           end;
      $0e..$17:;
      $18: if ts^.AutoWinSwitch>0 then ChangeEmu := IdVT; {Enter VT Mode}
      $19..$1a:;
      $1b: begin
             ParseMode := ModeEscape;
             exit;
           end;
      $1c: EnterMarkerMode(tk);
      $1d: EnterVectorMode(tk);
      $1e: EnterPlotMode(tk);
      $1f: ;
      $7f: if Drawing then Draw(tk,cv,ts,b);
    else
      if Drawing then Draw(tk,cv,ts,b)
                 else DispChar(tk,cv,b);
    end
  else if (DispMode=IdVectorMode) or
          (DispMode=IdMarkerMode) then
    case b of
      $00..$06:;
      $07: if MoveFlag then MoveFlag := FALSE
                       else TEKBeep(ts);
      $08..$0c: ;
      $0d: begin
             CommInsert1Byte(cv,$0d);
             EnterAlphaMode(tk);  {EnterAlphaMode}
           end;
      $0e..$17:;
      $18: if ts^.AutoWinSwitch>0 then ChangeEmu := IdVT; {Enter VT Mode}
      $19..$1a:;
      $1b: begin
             ParseMode := ModeEscape;
             exit;
           end;
      $1c: EnterMarkerMode(tk);
      $1d: EnterVectorMode(tk);
      $1e: EnterPlotMode(tk);
      $1f: EnterAlphaMode(tk);  {EnterAlphaMode}
    else
        Draw(tk,cv,ts,b);
    end
  else if DispMode=IdPlotMode then
    case b of
      $00..$06:;
      $07: TEKBeep(ts);
      $08..$0c: ;
      $0d: begin
             CommInsert1Byte(cv,$0d);
             EnterAlphaMode(tk);  {EnterAlphaMode}
           end;
      $0e..$17:;
      $18: if ts^.AutoWinSwitch>0 then ChangeEmu := IdVT; {Enter VT Mode}
      $19..$1a:;
      $1b: begin
             ParseMode := ModeEscape;
             exit;
           end;
      $1c: EnterMarkerMode(tk);
      $1d: EnterVectorMode(tk);
      $1e: EnterPlotMode(tk);
      $1f: EnterAlphaMode(tk);  {EnterAlphaMode}
      $7f: ;
    else
      if JustAfterRS then
      begin
        if b=$20 then
          PenDown := FALSE
        else if b=ord('P') then
          PenDown := TRUE
        else
          EnterUnknownMode(tk);
        JustAfterRS := FALSE;
      end
      else             
        Plot(tk,ts,b);
    end
  else
    case b of
      $1f: EnterAlphaMode(tk);
    end;  

  ParseMode := ModeFirst;
end;
end;

procedure SelectCode(tk: PTEKVar; ts: PTTSet; b: byte);
begin
with tk^ do begin
  case b of
    NUL..US: exit;
    ord(' '): begin
        if SelectCodeFlag = ord('#') then SelectCodeFlag := b;
        exit;
      end;
    ord('!'): begin
        if SelectCodeFlag = ord('%') then SelectCodeFlag := b;
        exit;
      end;
    ord('0'): ;
    ord('1')..Ord('2'): if (SelectCodeFlag=ord(' ')) or
                           (SelectCodeFlag=ord('!')) then ChangeEmu := IdVT; {enter VT mode}
    ord('3'): if SelectCodeFlag=ord('!') then ChangeEmu := IdVT; {enter VT mode}
    ord('5'): if SelectCodeFlag=ord(' ') then ChangeEmu := IdVT; {enter VT mode}
  end;
  if ($20<=b) and (b<$7f) then ParseMode := ModeFirst;
  SelectCodeFlag := 0;
  if ts^.AutoWinSwitch=0 then ChangeEmu := 0;
end;
end;

function ColorIndex(Fore, Back: TColorRef; w: word): TColorRef;
begin
  case w of
    1: ColorIndex := Fore;
    2: ColorIndex := RGB(255,  0,  0); {Red}
    3: ColorIndex := RGB(  0,255,  0); {Green}
    4: ColorIndex := RGB(  0,  0,255); {Blue}
    5: ColorIndex := RGB(  0,255,255); {Cyan}
    6: ColorIndex := RGB(255,  0,255); {Magenta}
    7: ColorIndex := RGB(255,255,  0); {Yellow}
    8: ColorIndex := RGB(255,128,  0); {Orange}
    9: ColorIndex := RGB(128,255,  0); {Green-Yellow}
   10: ColorIndex := RGB(  0,255,128); {Green-Cyan}
   11: ColorIndex := RGB(  0,128,255); {Blue-Cyan}
   12: ColorIndex := RGB(128,  0,255); {Blue-Magenta}
   13: ColorIndex := RGB(255,  0,128); {Red-Magenta}
   14: ColorIndex := RGB( 85, 85, 85); {Dark gray}
   15: ColorIndex := RGB(170,170,170); {Light gray}
  else
    ColorIndex := Back;
  end;
end;

procedure SetLineIndex(tk: PTEKVar; ts: PTTSet; w: word);
{chage graphic color}
var
  TempDC: HWnd;
begin
with tk^ do begin
  PenColor := ColorIndex(ts^.TEKColor[0],ts^.TEKColor[1],w);
  TempDC := GetDC(HWin);
  PenColor := GetNearestColor(TempDC,PenColor);
  ReleaseDC(HWin,TempDC);
  if ts^.TEKColorEmu>0 then
    MemPenColor := PenColor
  else
    if PenColor=ts^.TEKColor[1] then
      MemPenColor := MemBackColor
    else
      MemPenColor := MemForeColor;

  DeleteObject(Pen);
  Pen := CreatePen(ps,1,PenColor);
  
  SelectObject(MemDC, OldMemPen);
  DeleteObject(MemPen);
  MemPen := CreatePen(ps,1,MemPenColor);
  OldMemPen := SelectObject(MemDC,MemPen);
end;
end;

procedure SetTextIndex(tk: PTEKVar; ts: PTTSet; w: word);
{change text color}
var
  TempDC: HWnd;
begin
with tk^ do begin
  TextColor := ColorIndex(ts^.TEKColor[0],ts^.TEKColor[1],w);
  TempDC := GetDC(HWin);
  TextColor := GetNearestColor(TempDC,TextColor);
  ReleaseDC(HWin,TempDC);
  if ts^.TEKColorEmu>0 then
    MemTextColor := TextColor
  else
    if TextColor=ts^.TEKColor[1] then
      MemTextColor := MemBackColor
    else
      MemTextColor := MemForeColor;

  SetTextColor(MemDC, MemTextColor)
end;
end;

procedure SetColorIndex(tk: PTEKVar; ts: PTTSet; w: word);
{change color for text & graphics}
begin
  SetLineIndex(tk,ts,w);
  SetTextIndex(tk,ts,w);
end;

procedure SetLineStyle(tk: PTEKVar; b: byte);
begin
with tk^ do begin
  case b of
    0: ps := PS_SOLID;
    1: ps := PS_DOT;
    2: ps := PS_DASHDOT;
    3: ps := PS_DASH;
    4: ps := PS_DASH;
    5: ps := PS_DASHDOTDOT;
    6: ps := PS_DASHDOT;
    7: ps := PS_DASH;
    8: ps := PS_DASHDOTDOT;
  else
    ps := PS_SOLID;
  end;
  if Pen<>0 then DeleteObject(Pen);
  Pen := CreatePen(ps,1,PenColor);

  SelectObject(MemDC, OldMemPen);
  if MemPen<>0 then DeleteObject(MemPen);
  MemPen := CreatePen(ps,1,MemPenColor);
  OldMemPen := SelectObject(MemDC,MemPen);
end;
end;

procedure TwoOpCode(tk: PTEKVar; ts: PTTSet; cv: PComVar; b: byte);
var
  R0, R1, Re: real;
begin
with tk^ do begin

  if OpCount=2 then
  begin
    dec(OpCount);
    Op2OC := b*256;
    exit;
  end
  else if OpCount=1 then
  begin
    case b of
      $00..$1A: exit;
      $1B..$1F: begin
          CommInsert1Byte(cv,b);
          ParseMode := ModeFirst;
          exit;
        end;
    else
      begin 
        dec(OpCount);
        Op2OC := Op2OC + b;
        case Op2OC of
          IdMove: PrmCountMax := 0;
          IdDraw: PrmCountMax := 0;
          IdDrawMarker: PrmCountMax := 0;
          IdGraphText: PrmCountMax := 1;
          IdSetDialogVisibility: PrmCountMax := 1;
          IdSetGraphTextSize: PrmCountMax := 3;
          IdSetWriteMode: PrmCountMax := 1;
          IdSetLineIndex: PrmCountMax := 1;
          IdSetMarkerType: PrmCountMax := 1;
          IdSetCharPath: PrmCountMax := 1;
          IdSetPrecision: PrmCountMax := 1;
          IdSetRotation: PrmCountMax := 2;
          IdSetTextIndex: PrmCountMax := 1;
          IdSetLineStyle: PrmCountMax := 1;
        else
          PrmCountMax := 0;
        end;
        FillChar(Prm2OC,sizeof(Prm2OC),#0);
        PrmCount := 0;
        if PrmCountMax>0 then exit;
      end;
    end;
  end;

  if PrmCount<PrmCountMax then
    case b of
      $00..$1A: exit;
      $1B..$1F: begin
          CommInsert1Byte(cv,b);
          PrmCount := PrmCountMax;
          ParseMode := ModeFirst;
        end;
      $20..$2F: begin  {LoI (minus)}
          Prm2OC[PrmCount] :=
           - (Prm2OC[PrmCount]*16 + b - $20);
          inc(PrmCount);
        end;
      $30..$3F: begin  {LoI (plus)}
          Prm2OC[PrmCount] :=
            Prm2OC[PrmCount]*16 + b - $30;
          inc(PrmCount);
        end;
      $40..$7F: Prm2OC[PrmCount] :=
        Prm2OC[PrmCount]*64 + b - $40;
    end;

  if PrmCount<PrmCountMax then exit;

  case Op2OC of
    IdMove: begin
        LoXReceive := FALSE;
        LoCount := 0;
        Drawing := TRUE;
        MoveFlag := TRUE;
        MarkerFlag := FALSE;
      end;
    IdDraw: begin
        LoXReceive := FALSE;
        LoCount := 0;
        Drawing := TRUE;
        MoveFlag := FALSE;
        MarkerFlag := FALSE;
      end;
    IdDrawMarker: begin
        LoXReceive := FALSE;
        LoCount := 0;
        Drawing := TRUE;
        MoveFlag := TRUE;
        MarkerFlag := TRUE;
      end;
    IdGraphText: begin
        GTCount := 0;
        GTLen := Prm2OC[0];
        if GTLen>0 then
          ParseMode := ModeGT
        else
          ParseMode := ModeFirst;
        exit;
      end;
    IdSetDialogVisibility: ;
    IdSetGraphTextSize: begin
        GTWidth := Prm2OC[0];
	GTHeight := Prm2OC[1];
	GTSpacing := Prm2OC[2];
	if (GTWidth=0) and
	   (GTHeight=0) and
	   (GTSpacing=0) then
	begin
	  GTWidth := 39;
	  GTHeight := 59;
	  GTSpacing := 12;
	end;
	if GTWidth<=0 then GTWidth:=39;
	if GTHeight<=0 then GTWidth:=59;
	if GTSpacing<=0 then GTSpacing:=0;
      end;
    IdSetWriteMode: ;
    IdSetLineIndex: SetLineIndex(tk,ts,Prm2OC[0]);
    IdSetMarkerType: MarkerType := Prm2OC[0];
    IdSetCharPath: ;
    IdSetPrecision: ;
    IdSetRotation: begin
        R0 := Prm2OC[0];
        R1 := Prm2OC[1];
        Re := R0 * exp(ln(2.0) * R1);
        R0 := trunc(Re/360.0);
	Re := Re-R0*360.0;
	if Re<0 then Re := Re + 360.0;
	if Re<45.0 then
	  GTAngle:= 0
	else if Re<135.0 then
	  GTAngle := 1
	else if Re<315.0 then
	  GTAngle := 2
	else
	  GTAngle := 3;
      end;
    IdSetTextIndex: SetTextIndex(tk,ts,Prm2OC[0]);
    IdSetLineStyle: SetLineStyle(tk,byte(Prm2OC[0]));
  end;

  ParseMode := ModeFirst;

end;
end;

procedure TEKEscape(tk: PTEKVar; ts: PTTSet; cv: PComVar; b: byte);
  
  procedure Page(tk: PTEKVar); {Clear Screen and enter ALPHAMODE}
  var
    R: TRect;
  begin
  with tk^ do begin
    SetLineStyle(tk,0);
    GetClientRect(HWin,R);
    FillRect(MemDC,R,MemBackGround);
    InvalidateRect(HWin,@R,FALSE);
    UpdateWindow(HWin);
    EnterAlphaMode(tk);
    CaretX := 0;
    CaretOffset := 0;
    CaretY := 0;
  end;
  end;

begin
with tk^ do begin
  case b of
    $00: exit;
    $0A: exit;
    $0C: Page(tk);
    $0D: exit;
    $1A: begin
           GIN := TRUE;
           {Capture mouse}
           SetCapture(HWin);
           EnterAlphaMode(tk);
         end;
    $1B: exit;
    $1C..$1F: CommInsert1Byte(cv,b);
    Ord('#'): begin
                ParseMode := ModeSelectCode;
                SelectCodeFlag := b;
                exit;
              end;
    Ord('%'): begin
                ParseMode := ModeSelectCode;
                SelectCodeFlag := b;
                exit;
              end;
    Ord('2'): if ts^.AutoWinSwitch>0 then
                ChangeEmu := IdVT; {Enter VT Mode}
    Ord('8')..Ord(';'): begin
                          if TextSize<>b-$38 then
                          begin
                            TextSize := b-$38;
                            ChangeTextSize(tk,ts);
                          end;
                        end;
    Ord('I')..Ord('Z'): begin
                          ParseMode := Mode2OC;
                          OpCount := 2;
                          TwoOpCode(tk,ts,cv,b);
                          exit;
                        end;
    Ord('['): begin
                CSCount := 0;
                ParseMode := ModeCS;
                exit;
              end;
    $60..$6f: SetLineStyle(tk,(b-$60) and 7);
    $7f: exit;
  end;
  ParseMode := ModeFirst;
end;
end;

  procedure CSSetAttr(tk: PTEKVar; ts: PTTSet);
  var
    i, P: integer;
  begin
  with tk^ do begin
    for i := 1 to NParam do
    begin
      P := Param[i];
      if P<0 then P := 0;
      case P of
        {Clear}
        0: SetColorIndex(tk,ts,1);
        {Bold}
        1: ;
        {Under line}
        4: ;
        {Blink}
        5: ;
        {Reverse}
        7: ;
        {Bold off}
        22: ;
        {Under line off}
        24: ;
        {Blink off}
        25: ;
        {Reverse off}
        27: ;
	{colors for text & graphics}
	30: SetColorIndex(tk,ts,0);
	31: SetColorIndex(tk,ts,2);
	32: SetColorIndex(tk,ts,3);
	33: SetColorIndex(tk,ts,7);
	34: SetColorIndex(tk,ts,4);
	35: SetColorIndex(tk,ts,6);
	36: SetColorIndex(tk,ts,5);
	37: SetColorIndex(tk,ts,1);
	39: SetColorIndex(tk,ts,1);
      end;
    end;
  end;
  end;

const
  IntCharMax = 5;
procedure ParseCS(tk: PTEKVar; ts: PTTSet; cv: PComVar);
var
  i: integer;
  IntChar: array[0..IntCharMax] of byte;
  ICount: integer;
  FirstPrm: bool;
  Prv: byte;
  MoveToVT: bool;
  b: byte;
begin
with tk^ do begin
  i := 0;
  ICount := 0;
  FirstPrm := TRUE;
  Prv := 0;

  NParam := 1;
  Param[1] := -1;
  repeat
    b := CSBuff[i];
    inc(i);
    if (b>=$20) and (b<=$2F) then
    begin
      if ICount<IntCharMax then inc(ICount);
      IntChar[ICount] := b;
    end
    else if (b>=$30) and (b<=$39) then
    begin
      if Param[NParam] < 0 then
        Param[NParam] := 0; 
      if Param[NParam]<1000 then
        Param[NParam] := Param[NParam]*10 + b - $30;
    end
    else if b=$3B then
    begin
      if NParam < NParamMax then
      begin
        inc(NParam);
        Param[NParam] := -1;
      end;
    end
    else if (b>=$3C) and (b<=$3F) then
    begin
      if FirstPrm then Prv := b;
    end;
    FirstPrm := FALSE;
  until (i>=CSCount) or
        (b>=$40) and (b<=$7e);

  MoveToVT := FALSE;
  if (b>=$40) and (b<=$7E) then
    case ICount of
      {no intermediate char}
      0:
	case Prv of
	  {no private parameters}
	  0:
	    case b of
	      ord('m'): CSSetAttr(tk,ts);
            else
	      MoveToVT := TRUE;
	    end;
	  ord('?'):
	    {ignore ^[?38h (select TEK mode)}
	    if (b<>ord('h')) or (Param[1]<>38) then
	      MoveToVT := TRUE;

	else
	  MoveToVT := TRUE;
	end;
    else
      MoveToVT := TRUE;
    end {end of 'case Icount of'}
  else
    MoveToVT := TRUE;

  if (ts^.AutoWinSwitch>0) and MoveToVT then
  begin
    for i := CSCount-1 downto 0 do
      CommInsert1Byte(cv,CSBuff[i]);
    CommInsert1Byte(cv,$5B);
    CommInsert1Byte(cv,$1B);
    ChangeEmu := IdVT;
  end;
  ParseMode := ModeFirst;
end;
end;

procedure ControlSequence(tk: PTEKVar; ts: PTTSet; cv: PComVar; b: byte);
begin
with tk^ do begin
  case b of
    $1B..$1F:
      CommInsert1Byte(cv,b);
  else
    if CSCount < sizeof(CSBuff) then
    begin
      CSBuff[CSCount] := b;
      inc(CSCount);
      if (b>=$40) and (b<=$7E) then
        ParseCS(tk,ts,cv);
	exit;
    end;
  end;
  ParseMode := ModeFirst;
end;
end;

procedure GraphText(tk: PTEKVar; ts: PTTSet; cv: PComVar; b: byte);
var
  i: integer;
  Dx: array[0..79] of integer;
  TempFont, TempOld: HFont;
  lf: TLOGFONT;
  R: TRECT;
  W, H: integer;
  Metrics: TTEXTMETRIC;
begin
with tk^ do begin
  case b of
    $1B..$1F:
      CommInsert1Byte(cv,b);
  else
    begin
      GTBuff[GTCount] := char(b);
      inc(GTCount);
      if (GTCount>=sizeof(GTBuff)) or
         (GTCount>=GTLen) then
      begin
        Move(TEKlf,lf,sizeof(lf));
	case GTAngle of
	  0: lf.lfEscapement := 0;
	  1: lf.lfEscapement := 900;
	  2: lf.lfEscapement := 1800;
	  3: lf.lfEscapement := 2700;
	end;

        PlotX := Trunc(CaretX / ScreenWidth * ViewSizeX);
	W := Trunc(GTWidth / ViewSizeX * ScreenWidth);
        H := Trunc(GTHeight / ViewSizeY * ScreenHeight);
	lf.lfWidth := W;
	lf.lfHeight := H;
	TempFont := CreateFontIndirect(lf);		
	TempOld := SelectObject(MemDC,TempFont);
        W := Trunc((GTWidth+GTSpacing)/ViewSizeX*ScreenWidth);
	GetTextMetrics(MemDC, Metrics);
	if W < Metrics.tmAveCharWidth then
	  W := Metrics.tmAveCharWidth;
	H := Metrics.tmHeight;
	for i:=0 to GTLen do
	  Dx[i] := W;
	SetTextAlign(MemDC,TA_LEFT or TA_BASELINE or TA_NOUPDATECP);
	ExtTextOut(MemDC,CaretX,CaretY,0,nil,GTBuff,GTLen,@Dx[0]);
	SetTextAlign(MemDC,TA_LEFT or TA_BOTTOM or TA_NOUPDATECP);
	SelectObject(MemDC,TempOld);
	DeleteObject(TempFont);
	case GTAngle of
	  0: begin
	    R.left := CaretX;
	    R.top := CaretY - H;
	    R.right := CaretX + GTLen*W;
	    R.bottom := CaretY + H;
	    CaretX := R.right;
	  end;
	  1: begin
	    R.left := CaretX - H;
	    R.top := CaretY - GTLen*W;
	    R.right := CaretX + H;
	    R.bottom := CaretY;
	    CaretY := R.top;
	  end;
	  2: begin
	    R.left := CaretX - GTLen*W;
	    R.top := CaretY - H;
	    R.right := CaretX;
	    R.bottom := CaretY + H;
	    CaretX := R.left;
	  end;
	  3: begin
	    R.left := CaretX - H;
	    R.top := CaretY;
	    R.right := CaretX + H;
	    R.bottom := CaretY + GTLen*W;
	    CaretY := R.bottom;
	  end;
	end;
	InvalidateRect(HWin,@R,FALSE);
      end
      else
        exit;
    end;
  end;
  ParseMode := ModeFirst;
end;
end;

end.

