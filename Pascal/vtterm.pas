{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, VT terminal emulation}
unit VTTerm;

interface
{$i teraterm.inc}

{$IFDEF Delphi}
uses
  WinTypes, WinProcs, Strings,
  TTTypes, Keyboard, VTDisp, Buffer, TTWinMan, TTCommon, TeraPrn,
  FileSys, CommLib, TTLib, Telnet;
{$ELSE}
uses
  WinTypes, WinProcs, Strings,
  TTTypes, Keyboard, VTDisp, Buffer, TTWinMan, TTCommon, TeraPrn,
  FileSys, CommLib, TTLib, Telnet;
{$ENDIF}

procedure ResetTerminal;
procedure ResetCharSet;
procedure HideStatusLine;
procedure ChangeTerminalSize(Nx, Ny: integer);
function VTParse: integer;

implementation

const
  {Parsing modes}
  ModeFirst = 0;
  ModeESC   = 1;
  ModeDCS   = 2;
  ModeDCUserKey = 3;
  ModeSOS   = 4;
  ModeCSI   = 5;
  ModeXS    = 6;
  ModeDLE   = 7;
  ModeCAN   = 8;

  NParamMax = 16;
  IntCharMax = 5;

var
  {character attribute}
  CharAttr, CharAttr2: byte;

  {various modes of VT emulation}
  RelativeOrgMode: bool;
  ReverseColor: bool;
  InsertMode: bool;
  LFMode: bool;
  AutoWrapMode: bool;

{save/restore cursor}
type
  PStatusBuff = ^TStatusBuff;
  TStatusBuff = record
    CursorX, CursorY: integer;
    Attr, Attr2: byte;
    Glr: array[0..1] of integer; {GL & GR}
    Gn: array[0..3] of integer; {G0-G3}
    AutoWrapMode: bool;
    RelativeOrgMode: bool;
  end;

var
  {status buffer for main screen & status line}
  SBuff1, SBuff2: TStatusBuff;

  ESCFlag, JustAfterESC: bool;
  KanjiIn: bool;
  EUCkanaIn, EUCsupIn: bool;
  EUCcount: integer;
  Special: bool;

  Param: array[0..NParamMax] of integer;
  NParam: integer;
  FirstPrm: bool;
  IntChar: array[0..IntCharMax] of byte;
  ICount: integer;
  Prv: byte;
  ParseMode, SavedMode: integer;
  ChangeEmu: integer;

  {user defined keys}
  WaitKeyId, WaitHi: bool;

  {GL, GR code group}
  Glr: array[0..1] of integer;
  {G0, G1, G2, G3 code group}
  Gn: array[0..3] of integer;
  {GL for single shift 2/3}
  GLtmp: integer;
  {single shift 2/3 flag}
  SSflag: bool;
  {JIS -> SJIS conversion flag}
  ConvJIS: bool;
  Kanji: word;

  {variables for status line mode}
  StatusX: integer;
  StatusWrap: bool;
  StatusCursor: bool;
  MainX, MainY: integer; {cursor registers}
  MainTop, MainBottom: integer; {scroll region registers}
  MainWrap: bool;
  MainCursor: bool;

  {status for printer escape sequences}
  PrintEX: bool; {printing extent}
		 {(TRUE: screen, FALSE: scroll region)}
  AutoPrintMode: bool;
  PrinterMode: bool;
  DirectPrn: bool;

var
  {User key}
  NewKeyStr: array[0..FuncKeyStrMax-1] of byte;
  NewKeyId, NewKeyLen: integer;

procedure ResetSBuffers;
begin
  SBuff1.CursorX := 0;
  SBuff1.CursorY := 0;
  SBuff1.Attr := AttrDefault;
  SBuff1.Attr2 := AttrDefault2;
  if ts.Language=IdJapanese then
  begin
    SBuff1.Gn[0] := IdASCII;
    SBuff1.Gn[1] := IdKatakana;
    SBuff1.Gn[2] := IdKatakana;
    SBuff1.Gn[3] := IdKanji;
    SBuff1.Glr[0] := 0;
    if (ts.KanjiCode=IdJIS) and
       (ts.JIS7Katakana=0) then
      SBuff1.Glr[1] := 2 {8-bit katakana}
    else
      SBuff1.Glr[1] := 3;
  end
  else begin
    SBuff1.Gn[0] := IdASCII;
    SBuff1.Gn[1] := IdSpecial;
    SBuff1.Gn[2] := IdASCII;
    SBuff1.Gn[3] := IdASCII;
    SBuff1.Glr[0] := 0;
    SBuff1.Glr[1] := 0;
  end;
  SBuff1.AutoWrapMode := TRUE;
  SBuff1.RelativeOrgMode := FALSE;
  {copy SBuff1 to SBuff2}
  SBuff2 := SBuff1;
end;

procedure ResetTerminal;
{reset variables but don't update screen}
begin
  DispReset;
  BuffReset;

  {Attribute}
  CharAttr := AttrDefault;
  CharAttr2 := AttrDefault2;
  Special := FALSE;

  {Various modes}
  InsertMode := FALSE;
  LFMode := (ts.CRSend = IdCRLF);
  AutoWrapMode := TRUE;
  AppliKeyMode := FALSE;
  AppliCursorMode := FALSE;
  RelativeOrgMode := FALSE;
  ReverseColor := FALSE;
  AutoRepeatMode := TRUE;

  {Character sets}
  ResetCharSet;

  {ESC flag for device control sequence}
  ESCFlag := FALSE;
  {for TEK sequence}
  JustAfterESC := FALSE;

  {Parse mode}
  ParseMode := ModeFirst;

  {Clear printer mode}
  PrinterMode := FALSE;

  {status buffers}
  ResetSBuffers;
end;

procedure ResetCharSet;
begin
  if ts.Language=IdJapanese then
  begin
    Gn[0] := IdASCII;
    Gn[1] := IdKatakana;
    Gn[2] := IdKatakana;
    Gn[3] := IdKanji;
    Glr[0] := 0;
    if (ts.KanjiCode=IdJIS) and
       (ts.JIS7Katakana=0) then
      Glr[1] := 2 {8-bit katakana}
    else
      Glr[1] := 3;
  end
  else begin
    Gn[0] := IdASCII;
    Gn[1] := IdSpecial;
    Gn[2] := IdASCII;
    Gn[3] := IdASCII;
    Glr[0] := 0;
    Glr[1] := 0;
    cv.SendCode := IdASCII;
    cv.SendKanjiFlag := FALSE;
    cv.EchoCode := IdASCII;
    cv.EchoKanjiFlag := FALSE;
  end;
  {Kanji flag}
  KanjiIn := FALSE;
  EUCkanaIn := FALSE;
  EUCsupIn := FALSE;
  SSflag := FALSE;

  cv.Language := ts.Language;
  cv.CRSend := ts.CRSend;
  cv.KanjiCodeEcho := ts.KanjiCode;
  cv.JIS7KatakanaEcho := ts.JIS7Katakana;
  cv.KanjiCodeSend := ts.KanjiCodeSend;
  cv.JIS7KatakanaSend := ts.JIS7KatakanaSend;
  cv.KanjiIn := ts.KanjiIn;
  cv.KanjiOut := ts.KanjiOut;
end;

procedure MoveToMainScreen;
begin
  StatusX := CursorX;
  StatusWrap := Wrap;
  StatusCursor := IsCaretEnabled;

  CursorTop := MainTop;
  CursorBottom := MainBottom;
  Wrap := MainWrap;
  DispEnableCaret(MainCursor);
  MoveCursor(MainX,MainY); {move to main screen}
end;

procedure MoveToStatusLine;
begin
  MainX := CursorX;
  MainY := CursorY;
  MainTop := CursorTop;
  MainBottom := CursorBottom;
  MainWrap := Wrap;
  MainCursor := IsCaretEnabled;

  DispEnableCaret(StatusCursor);
  MoveCursor(StatusX,NumOfLines-1); {move to status line}
  CursorTop := NumOfLines-1;
  CursorBottom := CursorTop;
  Wrap := StatusWrap;
end;

procedure HideStatusLine;
begin
  if (StatusLine>0) and
     (CursorY=NumOfLines-1) then
    MoveToMainScreen;
  StatusX := 0;
  StatusWrap := FALSE;
  StatusCursor := TRUE;
  ShowStatusLine(0); {hide}
end;

procedure ChangeTerminalSize(Nx, Ny: integer);
begin
  BuffChangeTerminalSize(Nx,Ny);
  StatusX := 0;
  MainX := 0;
  MainY := 0;
  MainTop := 0;
  MainBottom := NumOfColumns-1;
end;

procedure BackSpace;
begin
  if CursorX=0 then
  begin
    if (CursorY>0) and
       (ts.TermFlag and TF_BACKWRAP <> 0) then
    begin
      MoveCursor(NumOfColumns-1,CursorY-1);
      if cv.HLogBuf<>0 then Log1Byte(BS);
    end;
  end
  else if CursorX > 0 then
  begin
    MoveCursor(CursorX-1,CursorY);
    if cv.HLogBuf<>0 then Log1Byte(BS);
  end;
end;

procedure CarriageReturn;
begin
 if cv.HLogBuf<>0 then Log1Byte(CR);
 if CursorX>0 then
   MoveCursor(0,CursorY);
end;

procedure LineFeed(b: byte);
begin
 {for auto print mode}
 if AutoPrintMode and
    (b>=LF) and (b<=FF) then
   BuffDumpCurrentLine(b);

 if cv.HLogBuf<>0 then Log1Byte(LF);

 if CursorY < CursorBottom then
   MoveCursor(CursorX,CursorY+1)
 else if CursorY = CursorBottom then BuffScrollNLines(1)
 else if CursorY < NumOfLines-StatusLine-1 then
   MoveCursor(CursorX,CursorY+1);

 if LFMode then CarriageReturn;
end;

procedure Tab;
begin
  MoveToNextTab;
  if cv.HLogBuf<>0 then Log1Byte(HT);
end;

procedure PutChar(b: byte);
var
  SpecialNew: bool;
  CharAttrTmp: byte;
begin
  if PrinterMode then {printer mode}
  begin
    WriteToPrnFile(b,TRUE);
    exit;
  end;

  if Wrap then
  begin
    CarriageReturn;
    LineFeed(LF);
  end;
  if cv.HLogBuf<>0 then Log1Byte(b);
  Wrap := FALSE;

  SpecialNew := FALSE;
  if (b>$5F) and (b<$80) then
  begin
    if SSflag then
      SpecialNew := (Gn[GLtmp]=IdSpecial)
    else
      SpecialNew := (Gn[Glr[0]]=IdSpecial);
  end
  else if b>$DF then
  begin
    if SSflag then
      SpecialNew := (Gn[GLtmp]=IdSpecial)
    else
      SpecialNew := (Gn[Glr[1]]=IdSpecial);
  end;

  if SpecialNew <> Special then
  begin
    UpdateStr;
    Special := SpecialNew;
  end;

  if Special then
  begin
    b := b and $7F;
    CharAttrTmp := CharAttr or AttrSpecial;
  end
  else
    CharAttrTmp := CharAttr;

  BuffPutChar(b,CharAttrTmp,CharAttr2,InsertMode);

  if CursorX < NumOfColumns-1 then
    MoveRight
  else begin
    UpdateStr;
    Wrap := AutoWrapMode;
  end;
end;

procedure PutKanji(b: byte);
begin
  Kanji := Kanji + b;

  if PrinterMode and DirectPrn then
  begin
    WriteToPrnFile(HI(Kanji),FALSE);
    WriteToPrnFile(LO(Kanji),TRUE);
    exit;
  end;

  if ConvJIS then
    Kanji := JIS2SJIS(Kanji and $7f7f);

  if PrinterMode then {printer mode}
  begin
    WriteToPrnFile(HI(Kanji),FALSE);
    WriteToPrnFile(LO(Kanji),TRUE);
    exit;
  end;

  if Wrap then
  begin
    CarriageReturn;
    LineFeed(LF);
  end
  else if CursorX > NumOfColumns-2 then
    if AutoWrapMode then
    begin
      CarriageReturn;
      LineFeed(LF);
    end
    else exit;

  Wrap := FALSE;

  if cv.HLogBuf<>0 then
  begin
    Log1Byte(HI(Kanji));
    Log1Byte(LO(Kanji));
  end;

  if Special then
  begin
    UpdateStr;
    Special := FALSE;
  end;
  
  BuffPutKanji(Kanji,CharAttr,CharAttr2,InsertMode);

  if CursorX < NumOfColumns-2 then
  begin
    MoveRight;
    MoveRight;
  end
  else begin
    UpdateStr;
    Wrap := AutoWrapMode;
  end;
end;

procedure PutDebugChar(b: byte);
begin
  InsertMode := FALSE;
  AutoWrapMode := TRUE;

  if (b and $80) = $80 then
  begin
    UpdateStr;
    CharAttr := AttrReverse;
    b := b and $7f;
  end;

  if b<=US then
  begin
    PutChar(ord('^'));
    PutChar(b+$40);
  end
  else if b=DEL then
  begin
    PutChar(ord('<'));
    PutChar(ord('D'));
    PutChar(ord('E'));
    PutChar(ord('L'));
    PutChar(ord('>'));
  end
  else
    PutChar(b);

  if CharAttr <> AttrDefault then
  begin
    UpdateStr;
    CharAttr := AttrDefault;
  end;
end;

procedure PrnParseControl(b: byte); {printer mode}
begin
  case b of
    NUL: exit;
    SO: if not DirectPrn then
      begin      
        if (ts.Language=IdJapanese) and
           (ts.KanjiCode=IdJIS) and
	   (ts.JIS7Katakana=1) and
	   (ts.TermFlag and TF_FIXEDJIS <>0) then
          Gn[1] := IdKatakana;

        Glr[0] := 1; {LS1}
        exit;
      end;
    SI: if not DirectPrn then
      begin
        Glr[0] := 0; {LS0}
        exit;
      end;
    DC1,DC3: exit;
    ESC: begin
      ICount := 0;
      JustAfterESC := TRUE;
      ParseMode := ModeESC;
      WriteToPrnFile(0,TRUE); {flush prn buff}
      exit;
    end;
    CSI: begin
      if (ts.TerminalID<IdVT220J) or
         (ts.TermFlag and TF_ACCEPT8BITCTRL = 0) then
      begin
        PutChar(b); { Disp C1 char in VT100 mode }
        exit;
      end;
      ICount := 0;
      FirstPrm := TRUE;
      NParam := 1;
      Param[1] := -1;
      Prv := 0;
      ParseMode := ModeCSI;
      WriteToPrnFile(0,TRUE); {flush prn buff}
      WriteToPrnFile(b,FALSE);
      exit;
    end;
  end;
  {send the uninterpreted character to printer}
  WriteToPrnFile(b,TRUE);
end;

procedure ParseControl(b: byte); {b is control char}
begin
  if PrinterMode then
  begin {printer mode}
    PrnParseControl(b);
    exit;
  end;

  if (b>=$80) then {C1 char}
  begin
    {English mode}    
    if (ts.Language=IdEnglish) then
    begin
      if (ts.TerminalID<IdVT220J) or
         (ts.TermFlag and TF_ACCEPT8BITCTRL = 0) then
      begin
        PutChar(b); {Disp C1 char in VT100 mode}
        exit;
      end;
    end
    else begin {Japanese mode}
      if ts.TermFlag and TF_ACCEPT8BITCTRL = 0 then
        exit; {ignore C1 char}
      {C1 chars are interpreted as C0 chars in VT100 mode}
      if ts.TerminalID<IdVT220J then
        b := b and $7F;
    end;
  end;

  case b of
    {C0 group}
    ENQ: CommBinaryOut(@cv,ts.AnswerBack,ts.AnswerBackLen);
    BEL: begin
        if ts.Beep <> 0 then
          MessageBeep(0);
      end;
    BS: BackSpace;
    HT: Tab;
    LF..VT: LineFeed(b);
    FF: if (ts.AutoWinSwitch>0) and JustAfterESC then
        begin
          CommInsert1Byte(@cv,b);
          CommInsert1Byte(@cv,ESC);
          ChangeEmu := IdTEK;  {Enter TEK Mode}
        end
        else
          LineFeed(b);
    CR: begin
          CarriageReturn;
          if ts.CRReceive=IdCRLF then
             CommInsert1Byte(@cv,LF);
        end;
    SO: begin
          if (ts.Language=IdJapanese) and
             (ts.KanjiCode=IdJIS) and
             (ts.JIS7Katakana=1) and
             (ts.TermFlag and TF_FIXEDJIS <>0) then
            Gn[1] := IdKatakana;
          Glr[0] := 1; {LS1}
        end;
    SI: Glr[0] := 0; {LS0}
    DLE: if ts.FTFlag and FT_BPAUTO <> 0 then
      ParseMode := ModeDLE; {Auto B-Plus activation}
    CAN: if ts.FTFlag and FT_ZAUTO <> 0 then
        ParseMode := ModeCAN {Auto ZMODEM activation}
      else
        ParseMode := ModeFirst;
    SUB: ParseMode := ModeFirst;
    ESC: begin
           ICount := 0;
           JustAfterESC := TRUE;
           ParseMode := ModeESC;
         end;
    FS..US: if ts.AutoWinSwitch>0 then
        begin
          CommInsert1Byte(@cv,b);
          ChangeEmu := IdTEK;  {Enter TEK Mode}
        end;

    {C1 group}
    IND: LineFeed(0);
    NEL: begin
           LineFeed(0);
           CarriageReturn;
         end;
    HTS: SetTabStop;
    RI: CursorUpWithScroll;
    SS2: begin
           GLtmp := 2;
           SSflag := TRUE;
         end;
    SS3: begin
           GLtmp := 3;
           SSflag := TRUE;
         end;
    DCS: begin
           SavedMode := ParseMode;
           ESCFlag := FALSE;
           NParam := 1;
           Param[1] := -1;
           ParseMode := ModeDCS;
         end;
    SOS: begin
           SavedMode := ParseMode;
           ESCFlag := FALSE;
           ParseMode := ModeSOS;
         end;
    CSI: begin
           ICount := 0;
           FirstPrm := TRUE;
           NParam := 1;
           Param[1] := -1;
           Prv := 0;
           ParseMode := ModeCSI;
         end;
    OSC..APC: begin
           SavedMode := ParseMode;
           ESCFlag := FALSE;
           ParseMode := ModeSOS;
         end;

  end;
end;

procedure SaveCursor;
var
  i: integer;
  Buff: PStatusBuff;
begin
  if (StatusLine>0) and
     (CursorY=NumOfLines-1) then
    Buff := @SBuff2 {for status line}
  else
    Buff := @SBuff1; {for main screen}

  Buff^.CursorX := CursorX;
  Buff^.CursorY := CursorY;
  Buff^.Attr := CharAttr;
  Buff^.Attr2 := CharAttr2;
  Buff^.Glr[0] := Glr[0];
  Buff^.Glr[1] := Glr[1];
  for i := 0 to 3 do
    Buff^.Gn[i] := Gn[i];
  Buff^.AutoWrapMode := AutoWrapMode;
  Buff^.RelativeOrgMode := RelativeOrgMode;
end;

procedure RestoreCursor;
var
  i: integer;
  Buff: PStatusBuff;
begin
  UpdateStr;

  if (StatusLine>0) and
     (CursorY=NumOfLines-1) then
    Buff := @SBuff2 {for status line}
  else
    Buff := @SBuff1; {for main screen}

  if Buff^.CursorX > NumOfColumns-1 then
    Buff^.CursorX := NumOfColumns-1;
  if Buff^.CursorY > NumOfLines-1-StatusLine then
    Buff^.CursorY := NumOfLines-1-StatusLine;
  MoveCursor(Buff^.CursorX,Buff^.CursorY);
  CharAttr := Buff^.Attr;
  CharAttr2 := Buff^.Attr2;
  Glr[0] := Buff^.Glr[0];
  Glr[1] := Buff^.Glr[1];
  for i := 0 to 3 do
    Gn[i] := Buff^.Gn[i];
  AutoWrapMode := Buff^.AutoWrapMode;
  RelativeOrgMode := Buff^.RelativeOrgMode;
end;

procedure AnswerTerminalType;
var
  Tmp: array[0..30] of char;
begin
  if ts.TerminalID<IdVT320 then
    StrCopy(Tmp,#$1b'[?')
  else
    StrCopy(Tmp,#$9B'?');

  case ts.TerminalID of
    IdVT100:  StrCat(Tmp,'1;2');
    IdVT100J: StrCat(Tmp,'5;2');
    IdVT101:  StrCat(Tmp,'1;0');
    IdVT102:  StrCat(Tmp,'6');
    IdVT102J: StrCat(Tmp,'15');
    IdVT220J: StrCat(Tmp,'62;1;2;5;6;7;8');
    IdVT282:  StrCat(Tmp,'62;1;2;4;5;6;7;8;10;11');
    IdVT320:  StrCat(Tmp,'63;1;2;6;7;8');
    IdVT382:  StrCat(Tmp,'63;1;2;4;5;6;7;8;10;15');
  end;
  StrCat(Tmp,'c');

  CommBinaryOut(@cv,Tmp,StrLen(Tmp)); {Report terminal ID}
end;

procedure ParseEscape(b: byte); {b is final char}

  procedure ESCSharp(b: byte);
  begin
    case b of
      Ord('8'):  {Fill screen with "E"}
        begin
          BuffUpdateScroll;
          BuffFillWithE;
          MoveCursor(0,0);
          ParseMode := ModeFirst;
        end;
    end;
  end;

  {select double byte code set}
  procedure DBCSSelect(b: byte);
  var
    Dist: integer;
  begin
    if ts.Language<>IdJapanese then exit;

    case ICount of

      1: if (b=Ord('@')) or (b=Ord('B')) then
      begin
        Gn[0] := IdKanji; {Kanji -> G0}
        if ts.TermFlag and TF_AUTOINVOKE <> 0 then
          Glr[0] := 0;  {G0->GL}
      end;

      2: begin
        {Second intermediate char must be
         '(' or ')' or '*' or '+'. }
        Dist := (IntChar[2]-Ord('(')) and 3; {G0 - G3}
        if (b=Ord('1')) or (b=Ord('3')) or
           (b=Ord('@')) or (b=Ord('B')) then
        begin  
          Gn[Dist] := IdKanji; {Kanji -> G0-3}
          if (ts.TermFlag and TF_AUTOINVOKE <> 0) and (Dist=0) then
            Glr[0] := 0;  {G0->GL}
        end;
      end;

    end;
  end;


  procedure SelectCode(b: byte);
  begin
    case b of
      Ord('0'): if ts.AutoWinSwitch>0 then
        ChangeEmu := IdTEK; {enter TEK mode}
    end;
  end;

  {select single byte code set}
  procedure SBCSSelect(b: integer);
  var
    Dist: integer;
  begin
    {Intermediate char must be
     '(' or ')' or '*' or '+'. }
    Dist := (IntChar[1]-Ord('(')) and 3; {G0 - G3}

    case b of
      ord('0'): Gn[Dist] := IdSpecial;
      ord('<'): Gn[Dist] := IdASCII;
      ord('>'): Gn[Dist] := IdASCII;
      ord('B'): Gn[Dist] := IdASCII;
      ord('H'): Gn[Dist] := IdASCII;
      ord('I'): if ts.Language=IdJapanese then
                  Gn[Dist] := IdKatakana;
      ord('J'): Gn[Dist] := IdASCII;
    end;

    if (ts.TermFlag and TF_AUTOINVOKE <> 0) and (Dist=0) then
      Glr[0] := 0;  {G0->GL}
  end;

  procedure PrnParseEscape(b: byte); {printer mode}
  var
    i: integer;
  begin
    ParseMode := ModeFirst;
    case ICount of
      {no intermediate char}
      0:
        case b of
          ord('['): begin {CSI}
            ICount := 0;
            FirstPrm := TRUE;
            NParam := 1;
            Param[1] := -1;
            Prv := 0;
	    WriteToPrnFile(ESC,FALSE);
	    WriteToPrnFile(ord('['),FALSE);
            ParseMode := ModeCSI;
            exit;
          end;
        end; {end of case Icount=0}

      {one intermediate char}
      1:
        case IntChar[1] of
          ord('$'): if not DirectPrn then
            begin           
              DBCSSelect(b);
              exit;
            end;
          ord('(')..ord('+'): if not DirectPrn then
            begin
              SBCSSelect(b);
              exit;
            end;
        end;

      {two intermediate char}
      2:
        if not DirectPrn and
           (IntChar[1]=ord('$')) and
           (ord('(')<=IntChar[2]) and
           (IntChar[2]<=ord('+')) then
        begin
          DBCSSelect(b);
          exit;
        end;
  end;
  {send the uninterpreted sequence to printer}
  WriteToPrnFile(ESC,FALSE);
  for i:=1 to ICount do
    WriteToPrnFile(IntChar[i],FALSE);
  WriteToPrnFile(b,TRUE);
end;

begin
  if PrinterMode then {printer mode}
  begin
    PrnParseEscape(b);
    exit;
  end;

  case Icount of
    {no intermediate char}
    0: case b of
      Ord('7'): SaveCursor;
      Ord('8'): RestoreCursor;
      Ord('='): AppliKeyMode := TRUE;
      Ord('>'): AppliKeyMode := FALSE;
      Ord('D'): LineFeed(0);  {IND}
      Ord('E'): begin                  {NEL}
                  MoveCursor(0,CursorY);
                  LineFeed(0);
                end;
      Ord('H'): SetTabStop;            {HTS}
      Ord('M'): CursorUpWithScroll;    {RI}
      Ord('N'): begin                  {SS2}
                  GLtmp := 2;
                  SSflag := TRUE;
                end;
      Ord('O'): begin                  {SS3}
                  GLtmp := 3;
                  SSflag := TRUE;
                end;
      Ord('P'): begin                  {DCS}
                  SavedMode := ParseMode;
                  ESCFlag := FALSE;
                  NParam := 1;
                  Param[1] := -1;
                  ParseMode := ModeDCS;
                  exit;
                end;
      Ord('X'): begin                  {SOS}
                  SavedMode := ParseMode;
                  ESCFlag := FALSE;
                  ParseMode := ModeSOS;
                  exit;
                end;
      Ord('Z'): AnswerTerminalType;
      Ord('['): begin                  {CSI}
                  ICount := 0;
                  FirstPrm := TRUE;
                  NParam := 1;
                  Param[1] := -1;
                  Prv := 0;
                  ParseMode := ModeCSI;
                  exit;
                end;
      Ord('\'): ;                      {ST}
      Ord(']'): begin  {XTERM sequence (OSC)}
                  NParam := 1;
                  Param[1] := 0;
                  ParseMode := ModeXS;
                  exit;  
                end;
      Ord('^')..Ord('_'): begin  {PM, APC}
                  SavedMode := ParseMode;
                  ESCFlag := FALSE;
                  ParseMode := ModeSOS;
                  exit;
                end;
      Ord('c'): begin; {Hardware reset}
                  HideStatusLine;
                  ResetTerminal;
                  ClearUserKey;
                  ClearBuffer;
                  if ts.PortType=IdSerial then
                  begin
                    { reset serial port }
                    CommResetSerial(@ts,@cv);
                  end;
                end;
      Ord('n'): Glr[0] := 2; {LS2}
      Ord('o'): Glr[0] := 3; {LS3}               
      Ord('|'): Glr[1] := 3; {LS3R}
      Ord('}'): Glr[1] := 2; {LS2R}
      Ord('~'): Glr[1] := 1; {LS1R}
    end; {of case Icount=0}

    {one intermediate char}
    1: case IntChar[1] of
      Ord('#'): ESCSharp(b);
      Ord('$'): DBCSSelect(b);
      Ord('%'): ;
      Ord('(')..Ord('+'): SBCSSelect(b);
    end;

    {two intermediate char}
    2: if (IntChar[1]=Ord('$')) and
          (Ord('(')<=IntChar[2]) and
          (IntChar[2]<=Ord('+')) then DBCSSelect(b)
       else if (IntChar[1]=Ord('%')) and
               (IntChar[2]=Ord('!')) then SelectCode(b);

  end;
  ParseMode := ModeFirst;

end;

procedure EscapeSequence(b: byte);
begin
  case b of
    NUL..US: ParseControl(b);
    $20..$2F: begin
                if Icount<IntCharMax then inc(Icount);
                IntChar[Icount] := b;
              end;
    $30..$7E: ParseEscape(b);
    $80..$9F: ParseControl(b);
  end;
  JustAfterESC := FALSE;
end;

procedure ParseCS(b: byte); {b is final char}

  procedure InsertCharacter;
  {Insert space characters at cursor}
  var
    Count: integer;
  begin
    BuffUpdateScroll;
    if Param[1]<1 then Param[1] := 1;
    Count := Param[1];
    BuffInsertSpace(Count);
  end;

  procedure CursorUp;
  begin
    if Param[1]<1 then Param[1] := 1;

    if CursorY >= CursorTop then
    begin
      if CursorY-Param[1] > CursorTop then
        MoveCursor(CursorX,CursorY-Param[1])
      else
        MoveCursor(CursorX,CursorTop);
    end
    else begin
      if CursorY > 0 then
        MoveCursor(CursorX,CursorY-Param[1])
      else
        MoveCursor(CursorX,0);
    end;
  end;

  procedure CursorUp1;
  begin
    MoveCursor(0,CursorY);
    CursorUp;
  end;

  procedure CursorDown;
  begin
    if Param[1]<1 then Param[1] := 1;

    if CursorY <= CursorBottom then
    begin
      if CursorY+Param[1] < CursorBottom then
        MoveCursor(CursorX,CursorY+Param[1])
      else
        MoveCursor(CursorX,CursorBottom);
    end
    else begin
      if CursorY < NumOfLines-StatusLine-1 then
        MoveCursor(CursorX,CursorY+Param[1])
      else
        MoveCursor(CursorX,NumOfLines-StatusLine);
    end;
  end;

  procedure CursorDown1;
  begin
    MoveCursor(0,CursorY);
    CursorDown;
  end;

  procedure ScreenErase;
  begin
    if Param[1] = -1 then Param[1] := 0;
    BuffUpdateScroll;
    case Param[1] of
      0: {Erase characters from cursor to the end of screen}
        BuffEraseCurToEnd;
      1: {Erase characters from home to cursor}
        BuffEraseHomeToCur;
      2: {Erase screen (scroll out)}
        begin
          BuffClearScreen;
          UpdateWindow(HVTWin);
        end;
    end;
  end;

  procedure InsertLine;
  {Insert lines at current position}
  var
    Count, YEnd: integer;
  begin
    if CursorY < CursorTop then exit;
    if CursorY > CursorBottom then exit;
    if Param[1]<1 then Param[1] := 1;
    Count := Param[1];

    YEnd := CursorBottom;
    if CursorY > YEnd then YEnd := NumOfLines-1-StatusLine;
    if Count > YEnd+1 - CursorY then count := YEnd+1 - CursorY;

    BuffInsertLines(Count,YEnd);
  end;

  procedure LineErase;
  begin
    if Param[1] = -1 then Param[1] := 0;
    BuffUpdateScroll;
    case Param[1] of
      {erase char from cursor to end of line}
      0: BuffEraseCharsInLine(CursorX,NumOfColumns-CursorX);
      {erase char from start of line to cursor}
      1: BuffEraseCharsInLine(0,CursorX+1);
      {erase entire line}
      2: BuffEraseCharsInLine(0,NumOfColumns);
    end;
  end;

  procedure DeleteNLines;
  {Delete lines from current line}
  var
    Count, YEnd: integer;
  begin
    if CursorY < CursorTop then exit;
    if CursorY > CursorBottom then exit;
    Count := Param[1];
    if Count<1 then Count := 1;

    YEnd := CursorBottom;
    if CursorY > YEnd then YEnd := NumOfLines-1-StatusLine;
    if Count > YEnd+1-CursorY then Count := YEnd+1-CursorY;
    BuffDeleteLines(Count,YEnd);
  end;

  procedure DeleteCharacter;
  {Delete characters in current line from cursor}
  begin
    if Param[1]<1 then Param[1] := 1;
    BuffUpdateScroll;
    BuffDeleteChars(Param[1]);
  end;

  procedure EraseCharacter;
  begin
    if Param[1]<1 then Param[1] := 1;
    BuffUpdateScroll;
    BuffEraseChars(Param[1]);
  end;

  procedure MoveToColumnN;
  begin
    if Param[1]<1 then Param[1] := 1;
    dec(Param[1]);
    if Param[1] < 0 then Param[1] := 0;
    if Param[1] > NumOfColumns-1 then Param[1] := NumOfColumns-1;
    MoveCursor(Param[1],CursorY);
  end;

  procedure CursorRight;
  begin
    if Param[1]<1 then Param[1] := 1;
    if CursorX + Param[1] > NumOfColumns-1 then
      MoveCursor(NumOfColumns-1,CursorY)
    else
      MoveCursor(CursorX+Param[1],CursorY);
  end;

  procedure CursorLeft;
  begin
    if Param[1]<1 then Param[1] := 1;
    if CursorX-Param[1] < 0 then
      MoveCursor(0,CursorY)
    else
      MoveCursor(CursorX-Param[1],CursorY);
  end;

  procedure MoveToLineN;
  begin
    if Param[1]<1 then Param[1] := 1;
    if RelativeOrgMode
    then begin
      if CursorTop+Param[1]-1 > CursorBottom then
        MoveCursor(CursorX,CursorBottom)
      else
        MoveCursor(CursorX,CursorTop+Param[1]-1);
    end
    else begin
      if Param[1] > NumOfLines-StatusLine then
        MoveCursor(CursorX,NumOfLines-1-StatusLine)
      else
        MoveCursor(CursorX,Param[1]-1);
    end;
  end;

  procedure MoveToXY;
  var
    NewX, NewY: integer;
  begin
    if Param[1]<1 then Param[1] := 1;
    if (NParam < 2) or (Param[2]<1) then Param[2] := 1;
    NewX := Param[2] - 1;
    if NewX > NumOfColumns-1 then NewX := NumOfColumns-1;

    if (StatusLine>0) and (CursorY=NumOfLines-1) then
      NewY := CursorY
    else if RelativeOrgMode
    then begin
      NewY := CursorTop + Param[1] - 1;
      if NewY > CursorBottom then NewY := CursorBottom;
    end
    else begin
      NewY := Param[1] - 1;
      if NewY > NumOfLines-1-StatusLine then
        NewY := NumOfLines-1-StatusLine;
    end;
    MoveCursor(NewX,NewY);
  end;

  procedure DeleteTabStop;
  var
    i,j: integer;
  begin
    if Param[1]=-1 then Param[1] := 0;
    ClearTabStop(Param[1]);
  end;

  procedure h_Mode;
  begin
    case Param[1] of
      4: InsertMode := TRUE;
      12: begin
        ts.LocalEcho := 0;
        if cv.Ready and cv.TelFlag and
           (ts.TelEcho>0) then
          TelChangeEcho;
      end;
      20: begin
            LFMode := TRUE;
            ts.CRSend := IdCRLF;
            cv.CRSend := IdCRLF;
          end;
    end;
  end;

  procedure i_Mode;
  begin
    if Param[1]=-1 then Param[1] := 0;
    case Param[1] of
      {print screen}
        { PrintEX -- TRUE: print screen}
        {         -- FALSE: scroll region}
      0: BuffPrint(not PrintEx);
      {printer controller mode off}
      4: ; {See PrnParseCS}
      {printer controller mode on}
      5: begin
          if not AutoPrintMode then
            OpenPrnFile;
          DirectPrn := (ts.PrnDev[0]<>#0);
          PrinterMode := TRUE;
        end;
    end;
  end;

  procedure l_Mode;
  begin
    case Param[1] of
      4: InsertMode := FALSE;
      12: begin
        ts.LocalEcho := 1;
        if cv.Ready and cv.TelFlag and
           (ts.TelEcho>0) then
          TelChangeEcho;
      end;
      20: begin
            LFMode := FALSE;
            ts.CRSend := IdCR;
            cv.CRSend := IdCR;
          end;
    end;
  end;

  procedure n_Mode;
  var
    Report: array[0..15] of char;
    Y: integer;
    NumStr: string[4];
  begin
    case Param[1] of
      5: CommBinaryOut(@cv,#$1B'[0n',4); {Device Status Report -> Ready}
      6: begin
           {Cursor Position Report}
           Y := CursorY + 1;
           if (StatusLine>0) and
              (Y=NumOfLines) then
             Y := 1;
           StrCopy(Report,#$1B'[');
           Str(Y,NumStr);
           StrPCopy(StrEnd(Report),NumStr);
           StrCat(Report,';');
           Str(CursorX+1,NumStr);
           StrPCopy(StrEnd(Report),NumStr);
           StrCat(Report,'R');
           CommBinaryOut(@cv,Report,StrLen(Report));
         end;
    end;
  end;

  procedure SetAttr;
  var
    i, P: integer;
  begin
    UpdateStr;
    for i:=1 to NParam do
    begin
      P := Param[i];
      if P<0 then P := 0;
      case P of
        {Clear}
        0: begin
            CharAttr := AttrDefault;
            CharAttr2 := AttrDefault2;
          end;
        {Bold}
        1: CharAttr := CharAttr or AttrBold;
        {Under line}
        4: CharAttr := CharAttr or AttrUnder;
        {Blink}
        5: CharAttr := CharAttr or AttrBlink;
        {Reverse}
        7: CharAttr := CharAttr or AttrReverse;
        {Bold off}
        22: CharAttr := CharAttr and not AttrBold;
        {Under line off}
        24: CharAttr := CharAttr and not AttrUnder;
        {Blink off}
        25: CharAttr := CharAttr and not AttrBlink;
        {Reverse off}
        27: CharAttr := CharAttr and not AttrReverse;
        {Text color}
        30..37: CharAttr2 := CharAttr2 and (Attr2Back or Attr2BackMask)
                             or (P-30) or Attr2Fore;
        {Back color}
        40..47: CharAttr2 := CharAttr2 and (Attr2Fore or Attr2ForeMask)
                             or ((P-40) shl SftAttrBack) or Attr2Back;
        {Reset color attributes}
        100: CharAttr2 := AttrDefault2;
      end;
    end;
  end;

  procedure SetScrollRegion;
  begin
    if (StatusLine>0) and
       (CursorY=NumOfLines-1) then
    begin
      MoveCursor(0,CursorY);
      exit;
    end;
    if Param[1]<1 then Param[1] :=1;    
    if (NParam < 2) or (Param[2]<1) then
      Param[2] := NumOfLines-StatusLine;
    Dec(Param[1]);
    Dec(Param[2]);
    if Param[1] > NumOfLines-1-StatusLine then
      Param[1] := NumOfLines-1-StatusLine;
    if Param[2] > NumOfLines-1-StatusLine then
      Param[2] := NumOfLines-1-StatusLine;
    if Param[1] >= Param[2] then exit;
    CursorTop := Param[1];
    CursorBottom := Param[2];
    if RelativeOrgMode then MoveCursor(0,CursorTop)
                       else MoveCursor(0,0);
  end;

  procedure SunSequence; {Sun terminal private sequences}
  var
    Report: array[0..15] of char;
    NumStr: string[4];
  begin
    case Param[1] of
      8: begin {set terminal size}
        if (Param[2]<=1) or (NParam<2) then Param[2] := 24;
        if (Param[3]<=1) or (NParam<3) then Param[3] := 80;
        ChangeTerminalSize(Param[3],Param[2]);
      end;
      14: begin {get window size???}
          {this is not actual window size} 
          CommBinaryOut(@cv,#$1B'[4;640;480t',12);
        end;
      18: begin {get terminal size}
        {Cursor Position Report}
        StrCopy(Report,#$1B'[8;');
        Str(NumOfLines-StatusLine,NumStr);
        StrPCopy(StrEnd(Report),NumStr);
        StrCat(Report,';');
        Str(NumOfColumns,NumStr);
        StrPCopy(StrEnd(Report),NumStr);
        StrCat(Report,'t');
        CommBinaryOut(@cv,Report,StrLen(Report));
      end;
    end;
  end;

  procedure CSGT(b: byte);
  begin
    case b of
      Ord('c'): {second terminal report}
        CommBinaryOut(@cv,#$1B'[>32;10;2c',11); {VT382}
      Ord('J'): {IO-8256 terminal}
        if Param[1]=3 then
        begin
	  if Param[2]<1 then Param[2]:=1;
	  if Param[3]<1 then Param[3]:=1;
	  if Param[4]<1 then Param[4]:=1;
	  if Param[5]<1 then Param[5]:=1;
	  BuffEraseBox(Param[3]-1,Param[2]-1,
	               Param[5]-1,Param[4]-1);
	end;
      Ord('K'): {IO-8256 terminal}
        if (NParam>=2) and (Param[1]=5) then
        begin
	  case Param[2] of
	    3..6:
	      BuffDrawLine(CharAttr,CharAttr2,
	                   Param[2],Param[3]);
	    12: {text color}
	      if (Param[3]>=0) and (Param[3]<=7) then
	      begin
	        if Param[3]=3 then Param[3]:=IdBlue
		else if Param[3]=4 then Param[3]:=IdCyan
		else if Param[3]=5 then Param[3]:=IdYellow
		else if Param[3]=6 then Param[3]:=IdMagenta;
		CharAttr2 := CharAttr2 and (Attr2Back or Attr2BackMask)
                  or Param[3] or Attr2Fore;
	      end;
          end;
        end
        else if Param[1]=3 then
        begin {IO-8256 terminal}
	  if Param[2]<1 then Param[2] := 1;
	  if Param[3]<1 then Param[2] := 1;
	  BuffEraseCharsInLine(Param[2]-1,Param[3]-Param[2]+1);
        end;
    end;
  end;

  procedure CSQuest(b: byte);

    procedure ExchangeColor;
    var
      ColorRef: TColorRef;
    begin
      BuffUpdateScroll;

      ColorRef := ts.VTColor[0];
      ts.VTColor[0] := ts.VTColor[1];
      ts.VTColor[1] := ColorRef;
      DispChangeBackground;
    end;

    procedure qh_Mode;
    var
      i: integer;
    begin
      for i := 1 to NParam do
        case Param[i] of
          1: AppliCursorMode := TRUE;
          3: ChangeTerminalSize(132,NumOfLines-StatusLine);
          5: begin
            if ReverseColor then exit;
              ReverseColor := TRUE;
              {Exchange text/back color}
              ExchangeColor;
            end;
          6: begin
            if (StatusLine>0) and
               (CursorY=NumOfLines-1) then
              MoveCursor(0,CursorY)
            else begin
              RelativeOrgMode := TRUE;
              MoveCursor(0,CursorTop);
            end;
          end;
          7: AutoWrapMode := TRUE;
          8: AutoRepeatMode := TRUE;
          19: PrintEX := TRUE;
          25: DispEnableCaret(TRUE); {cursor on}
          38: if ts.AutoWinSwitch>0 then
                ChangeEmu := IdTEK; {Enter TEK Mode}
          59: if ts.Language=IdJapanese then
              begin {kanji terminal}
                Gn[0] := IdASCII;
                Gn[1] := IdKatakana;
                Gn[2] := IdKatakana;
                Gn[3] := IdKanji;
                Glr[0] := 0;
                if (ts.KanjiCode=IdJIS) and
                   (ts.JIS7Katakana=0) then
                  Glr[1] := 2 {8-bit katakana}
                else
                  Glr[1] := 3;
              end;
          67: ts.BSKey := IdBS;
        end;
    end;

    procedure qi_Mode;
    begin
      if Param[1]=-1 then Param[1] := 0;
      case Param[1] of
        1: begin
          OpenPrnFile;
          BuffDumpCurrentLine(LF);
          if not AutoPrintMode then
            ClosePrnFile;
        end;
        {auto print mode off}
        4: if AutoPrintMode then
          begin
            ClosePrnFile;
            AutoPrintMode := FALSE;
          end;
        {auto print mode on}
        5: if not AutoPrintMode then
          begin
            OpenPrnFile;
            AutoPrintMode := TRUE;
          end;
      end;
    end;

    procedure ql_Mode;
    var
      i: integer;
    begin
      for i := 1 to NParam do
        case Param[i] of
          1: AppliCursorMode := FALSE;
          3: ChangeTerminalSize(80,NumOfLines-StatusLine);
          5: begin
            if not ReverseColor then exit;
            ReverseColor := FALSE;
            {Exchange text/back color}
            ExchangeColor;
          end;
          6: begin
            if (StatusLine>0) and
               (CursorY=NumOfLines-1) then
              MoveCursor(0,CursorY)
            else begin
              RelativeOrgMode := FALSE;
              MoveCursor(0,0);
            end;
          end;
          7: AutoWrapMode := FALSE;
          8: AutoRepeatMode := FALSE;
          19: PrintEX := FALSE;
          25: DispEnableCaret(FALSE); {cursor off}
          59: if ts.Language=IdJapanese then
              begin {katakana terminal}
                Gn[0] := IdASCII;
                Gn[1] := IdKatakana;
                Gn[2] := IdKatakana;
                Gn[3] := IdKanji;
                Glr[0] := 0;
                if (ts.KanjiCode=IdJIS) and
                   (ts.JIS7Katakana=0) then
                  Glr[1] := 2 {8-bit katakana}
                else
                  Glr[1] := 3;
              end;
          67: ts.BSKey := IdDEL;
        end;
    end;

    procedure qn_Mode;
    begin
    end;

  begin
    case b of
      Ord('h'): qh_Mode;
      Ord('i'): qi_Mode;
      Ord('l'): ql_Mode;
      Ord('n'): qn_Mode;
    end;
  end;

  procedure SoftReset;
  {called by software-reset escape sequence handler}
  begin
    UpdateStr;
    AutoRepeatMode := TRUE;
    DispEnableCaret(TRUE); {cursor on}
    InsertMode := FALSE;
    RelativeOrgMode := FALSE;
    AppliKeyMode := FALSE;
    AppliCursorMode := FALSE;
    if (StatusLine>0) and
       (CursorY = NumOfLines-1) then
      MoveToMainScreen;
    CursorTop := 0;
    CursorBottom := NumOfLines-1-StatusLine;
    ResetCharSet;

    {Attribute}
    CharAttr := AttrDefault;
    CharAttr2 := AttrDefault2;
    Special := FALSE;

    {status buffers}
    ResetSBuffers;
  end;

  procedure CSExc(b: byte);
  begin
    case b of
      Ord('p'): begin
        {Software reset}
        SoftReset;
      end;
    end;
  end;

  procedure CSDouble(b: byte);
  begin
    case b of
      Ord('p'): begin
        {select terminal mode (software reset)}
        SoftReset;
      end;
    end;
  end;

  procedure CSDol(b: byte);
  begin
    case b of
      Ord('}'): begin
        if ts.TermFlag and TF_ENABLESLINE = 0 then exit;
        if StatusLine=0 then exit;
	if (Param[1]<1) and (CursorY=NumOfLines-1) then
	  MoveToMainScreen
	else if (Param[1]=1) and (CursorY<NumOfLines-1) then
          MoveToStatusLine;
      end;
      Ord('~'): begin
        if ts.TermFlag and TF_ENABLESLINE = 0 then exit;
        if Param[1]<=1 then
	  HideStatusLine
	else if (StatusLine=0) and (Param[1]=2) then
	  ShowStatusLine(1); {show}
      end;
    end;
  end;

  procedure PrnParseCS(b: byte); {printer mode}
  begin
    ParseMode := ModeFirst;
    case ICount of
      {no intermediate char}
      0:
        case Prv of
          {no private parameter}
          0:
	    case b of
              ord('i'):
	        if Param[1]=4 then
		begin
		  PrinterMode := FALSE;
		  {clear prn buff}
		  WriteToPrnFile(0,FALSE);
		  if not AutoPrintMode then
		    ClosePrnFile;
                  exit;
		end;
	    end; {of Prv=0}
	end;
      {one intermediate char}
      1: ;
    end; {of case Icount}

    WriteToPrnFile(b,TRUE);
  end;

begin
  if PrinterMode then
  begin {printer mode}
    PrnParseCS(b);
    exit;
  end;

  case Icount of

    {no intermediate char}
    0: case Prv of

      {no private parameter}
      0: case b of
        Ord('@'): InsertCharacter;
        Ord('A'): CursorUp;
        Ord('B'): CursorDown;
        Ord('C'): CursorRight;
        Ord('D'): CursorLeft;
        Ord('E'): CursorDown1;
        Ord('F'): CursorUp1;
        Ord('G'): MoveToColumnN;
        Ord('H'): MoveToXY;
        Ord('J'): ScreenErase;
        Ord('K'): LineErase;
        Ord('L'): InsertLine;
        Ord('M'): DeleteNLines;
        Ord('P'): DeleteCharacter;
        Ord('X'): EraseCharacter;
        Ord('`'): MoveToColumnN;
        Ord('a'): CursorRight;
        Ord('c'): AnswerTerminalType;
        Ord('d'): MoveToLineN;
        Ord('e'): CursorUp;
        Ord('f'): MoveToXY;
        Ord('g'): DeleteTabStop;
        Ord('h'): h_Mode;
        Ord('i'): i_Mode;
        Ord('l'): l_Mode;
        Ord('m'): SetAttr;
        Ord('n'): n_Mode;
        Ord('r'): SetScrollRegion;
        Ord('s'): SaveCursor;
        Ord('t'): SunSequence;
        Ord('u'): RestoreCursor;
      end; {of case Prv=0}

      {private parameter = '>'}
      Ord('>'): CSGT(b);
      {private parameter = '?'}
      Ord('?'): CSQuest(b);

    end;

    {one intermediate char}
    1: case IntChar[1] of
      {intermediate char = '!'}
      Ord('!'): CSExc(b);
      {intermediate char = '"'}
      Ord('"'): CSDouble(b);
      {intermediate char = '$'}
      Ord('$'): CSDol(b);
    end;

  end; {of case Icount}

  ParseMode := ModeFirst;
end;

procedure ControlSequence(b: byte);
begin
  if (b<=US) or (b>=$80) and (b<=$9F) then
    ParseControl(b) {ctrl char}
  else if (b>=$40) and (b<=$7E) then
    ParseCS(b) {terminate char}
  else begin
    if PrinterMode then
      WriteToPrnFile(b,FALSE);

    case b of
      $20..$2F: begin
          if Icount<IntCharMax then inc(Icount);
            IntChar[Icount] := b;
        end;
      $30..$39: begin
          if Param[NParam] < 0 then Param[NParam] := 0; 
          if Param[NParam]<1000 then
            Param[NParam] := Param[NParam]*10 + b - $30;
        end;
      $3B: if NParam < NParamMax then
         begin
           Inc(NParam);
           Param[NParam] := -1;
         end;
      $3C..$3F: if FirstPrm then Prv := b;
    end;
  end;
  FirstPrm := FALSE;
end;

procedure DeviceControl(b: byte);
begin
  if (ESCFlag and (b=Ord('\'))) or (b=ST) then
  begin
    ESCFlag := FALSE;
    ParseMode := SavedMode;
    exit;
  end;

  if b=ESC then
  begin
    ESCFlag := TRUE;
    exit;
  end
  else ESCFlag := FALSE;

  case b of
    NUL..US: ParseControl(b);
    $30..$39: begin
                if Param[NParam] < 0 then Param[NParam] := 0; 
                if Param[NParam]<1000 then
                  Param[NParam] := Param[NParam]*10 + b - $30;
              end;
    $3B: if NParam < NParamMax then
         begin
           Inc(NParam);
           Param[NParam] := -1;
         end;
    $40..$7E: begin
                if b=ord('|') then
                begin
                  ParseMode := ModeDCUserKey;
                  if Param[1] < 1 then ClearUserKey;
                  WaitKeyId := TRUE;
                  NewKeyId := 0;
                end
                else ParseMode := ModeSOS;
              end;
  end;

end;

procedure DCUserKey(b: byte);
begin
  if (ESCFlag and (b=Ord('\'))) or (b=ST) then
  begin
    if not WaitKeyId then
      DefineUserKey(NewKeyId,@NewKeyStr[0],NewKeyLen);
    ESCFlag := FALSE;
    ParseMode := SavedMode;
    exit;
  end;

  if b=ESC then
  begin
    ESCFlag := TRUE;
    exit;
  end
  else ESCFlag := FALSE;

  if WaitKeyId then
    case b of
      $30..$39: if NewKeyId<1000 then
                    NewKeyId := NewKeyId*10 + b - $30;
      $2F: begin
             WaitKeyId := FALSE;
             WaitHi := TRUE;
             NewKeyLen := 0;
           end;
    end
  else
    if b=$3B then
    begin
      DefineUserKey(NewKeyId,@NewKeyStr[0],NewKeyLen);
      WaitKeyId := TRUE;
      NewKeyId := 0;
    end
    else
      if NewKeyLen < FuncKeyStrMax then
        if WaitHi then
        begin
          NewKeyStr[NewKeyLen] := ConvHexChar(b) shl 4;
          WaitHi := FALSE;
        end
        else begin
          NewKeyStr[NewKeyLen] := NewKeyStr[NewKeyLen] +
                                    ConvHexChar(b);
          WaitHi := TRUE;
          inc(NewKeyLen);
        end;

end;

procedure IgnoreString(b: byte);
begin
  if (ESCFlag and (b=Ord('\'))) or (b=ST) then
    ParseMode := SavedMode;

  if b=ESC then ESCFlag := TRUE
           else ESCFlag := FALSE;
end;

procedure XSequence(b: byte);
begin
  if NParam=1 then
    case b of
      $30..$39: if Param[1]<1000 then
                  Param[1] := Param[1]*10 + b - $30;
    else
      NParam := 2;
    end
  else
    case b of
      NUL..US: begin
          if Param[1]<=2 then
          begin
            ts.Title[NParam-2] := #0;
            ChangeTitle;
          end;
          ParseMode := ModeFirst;
        end;
    else
      if (Param[1]<=2) and (NParam-2<SizeOf(ts.Title)-1) then
      begin
        ts.Title[NParam-2] := char(b);
        inc(NParam);
      end;
    end;
end;

procedure DLESeen(b: byte);
begin
  ParseMode := ModeFirst;
  if (ts.FTFlag and FT_BPAUTO <> 0) and (b=ord('B')) then
    BPStart(IdBPAuto); {Auto B-Plus activation}
  ChangeEmu := -1;
end;

procedure CANSeen(b: byte);
begin
  ParseMode := ModeFirst;
  if (ts.FTFlag and FT_ZAUTO <> 0) and (b=ord('B')) then
    ZMODEMStart(IdZAuto); {Auto ZMODEM activation}
  ChangeEmu := -1;
end;

function CheckKanji(b: byte): bool;
var
  Check: bool;
begin
  CheckKanji := FALSE;
  if ts.Language<>IdJapanese then exit;

  Check := FALSE;

  ConvJIS := FALSE;

  if ts.KanjiCode=IdSJIS then
  begin
    if ($80<b) and (b<$a0) or ($df<b) and (b<$fd) then
    begin
      CheckKanji := TRUE; {SJIS kanji}
      exit;
    end;
    if ($a1<=b) and (b<=$df) then
      exit; {SJIS katakana}
  end;

  if (b>=$21) and (b<=$7e) then
  begin
    Check := (Gn[Glr[0]]=IdKanji);
    ConvJIS := Check;
  end
  else if (b>=$A1) and (b<=$FE) then
  begin
    Check := (Gn[Glr[1]]=IdKanji);
    if ts.KanjiCode=IdEUC then
      Check := TRUE
    else if ts.KanjiCode=IdJIS then
    begin
      if (ts.TermFlag and TF_FIXEDJIS <>0) and
         (ts.JIS7Katakana=0) then
        Check := FALSE; {8-bit katakana}
    end;
    ConvJIS := Check;
  end
  else
    Check := FALSE;

  CheckKanji := Check;
end;

function ParseFirstJP(b: byte): bool;
{ returns TRUE if b is processed
 (actually allways returns TRUE)}
begin
  ParseFirstJP := TRUE;

  if KanjiIn then
  begin
    if ((not ConvJIS) and ($3F<b) and (b<$FD) or
        ConvJIS and ( ($20<b) and (b<$7F) or
		      ($A0<b) and (b<$FF) )) then
    begin
      PutKanji(b);
      KanjiIn := FALSE;
      exit;
    end
    else if ts.TermFlag and TF_CTRLINKANJI = 0 then
      KanjiIn := FALSE;
  end;
        
  if SSflag then
  begin
    if Gn[GLtmp] = IdKanji then
    begin
      Kanji := b shl 8;
      KanjiIn := TRUE;
      SSflag := FALSE;
      exit;
    end
    else if Gn[GLtmp] = IdKatakana then
      b := b or $80;

    PutChar(b);
    SSflag := FALSE;
    exit;
  end;

  if (not EUCsupIn) and (not EUCkanaIn) and
     (not KanjiIn) and CheckKanji(b) then
  begin
    Kanji := b shl 8;
    KanjiIn := TRUE;
    exit;
  end;

  if b<=US then
    ParseControl(b)
  else if b=$20 then
    PutChar(b)
  else if (b>=$21) and (b<=$7E) then
  begin
    if EUCsupIn then
    begin
      dec(EUCcount);
      EUCsupIn := (EUCcount=0);
      exit;
    end;

    if (Gn[Glr[0]] = IdKatakana) or EUCkanaIn then
    begin
      b := b or $80;
      EUCkanaIn := FALSE;
    end;
    PutChar(b);
  end
  else if b=$7f then
    exit
  else if (b>=$80) and (b<=$8D) then
    ParseControl(b)
  else if b=$8E then
  begin
    if ts.KanjiCode=IdEUC then
      EUCkanaIn := TRUE
    else
      ParseControl(b);
  end
  else if b=$8F then
  begin
    if ts.KanjiCode=IdEUC then
    begin
      EUCcount := 2;
      EUCsupIn := TRUE;
    end else
      ParseControl(b);
  end
  else if (b>=$90) and (b<=$9F) then
    ParseControl(b)
  else if b=$A0 then
    PutChar($20)
  else if (b>=$A1) and (b<=$FE) then
  begin
    if EUCsupIn then
    begin
      dec(EUCcount);
      EUCsupIn := (EUCcount=0);
      exit;
    end;

    if (Gn[Glr[1]] <> IdASCII) or
       (ts.KanjiCode=IdEUC) and EUCkanaIn or
       (ts.KanjiCode=IdSJIS) or
       (ts.KanjiCode=IdJIS) and
       (ts.JIS7Katakana=0) and
       (ts.TermFlag and TF_FIXEDJIS <>0) then
      PutChar(b) {katakana}
    else begin
      if Gn[Glr[1]] = IdASCII then	  
        b := b and $7f;
      PutChar(b);
    end;
    EUCkanaIn := FALSE;
  end
  else
    PutChar(b);
end;

function ParseFirstRus(b: byte): bool;
{returns if b is processed}
begin
  if b>=128 then
  begin
    b := RussConv(ts.RussHost,ts.RussClient,b);
    PutChar(b);
    ParseFirstRus := TRUE;
    exit;
  end;
  ParseFirstRus := FALSE;
end;

procedure ParseFirst(b: byte);
begin
  if (ts.Language=IdJapanese) and
     ParseFirstJP(b) then exit
  else if (ts.Language=IdRussian) and
       ParseFirstRus(b) then exit;
        
  if SSflag then
  begin
    PutChar(b);
    SSflag := FALSE;
    exit;
  end;

  if b<=US then
    ParseControl(b)
  else if (b>=$20) and (b<=$7E) then
    PutChar(b)
  else if (b>=$80) and (b<=$9F) then
    ParseControl(b)
  else if b>=$A0 then
    PutChar(b);
end;

function VTParse: integer;
var
  b: byte;
  c: integer;
begin
  VTParse := 0;
  c := CommRead1Byte(@cv,@b);

  if c=0 then exit;

  CaretOff;

  ChangeEmu := 0;

  {Get Device Context}
  DispInitDC;

  LockBuffer;

  while (c>0) and (ChangeEmu=0) do
  begin
    if DebugFlag then
      PutDebugChar(b)
    else begin
     { LockBuffer;} {for safety}
      case ParseMode of
        ModeFirst: ParseFirst(b);
        ModeESC: EscapeSequence(b);
        ModeDCS: DeviceControl(b);
        ModeDCUserKey: DCUserKey(b);
        ModeSOS: IgnoreString(b);
        ModeCSI: ControlSequence(b);
        ModeXS:  XSequence(b);
        ModeDLE: DLESeen(b);
        ModeCAN: CANSeen(b);
      else
        begin
          ParseMode := ModeFirst;
          ParseFirst(b);
        end;
      end;
    end;

    if ChangeEmu=0 then
      c := CommRead1Byte(@cv,@b);
  end;

  BuffUpdateScroll;

  BuffSetCaretWidth;
  UnlockBuffer;

  {release device context}
  DispReleaseDC;

  CaretOn;

  if ChangeEmu > 0 then ParseMode := ModeFirst;
  VTParse := ChangeEmu;
end;

begin
  StatusX := 0;
  StatusWrap := FALSE;
  StatusCursor := TRUE;
  MainCursor := TRUE;
  PrintEX := TRUE;
  AutoPrintMode := FALSE;
  PrinterMode := FALSE;
  DirectPrn := FALSE;
end.
