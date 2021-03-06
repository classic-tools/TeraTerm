/* Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved. */

/* TERATERM.EXE, VT terminal emulation */
#include "teraterm.h"
#include "tttypes.h"
#include <stdio.h>
#include <string.h>

#include "buffer.h"
#include "ttwinman.h"
#include "ttcommon.h"
#include "commlib.h"
#include "vtdisp.h"
#include "keyboard.h"
#include "ttlib.h"
#include "ttftypes.h"
#include "filesys.h"
#include "teraprn.h"
#include "telnet.h"

#include "vtterm.h"

  /* Parsing modes */
#define ModeFirst 0
#define ModeESC   1
#define ModeDCS   2
#define ModeDCUserKey 3
#define ModeSOS   4
#define ModeCSI   5
#define ModeXS	  6
#define ModeDLE   7
#define ModeCAN   8

#define NParamMax 16
#define IntCharMax 5

/* character attribute */
static BYTE CharAttr, CharAttr2;

/* various modes of VT emulation */
static BOOL RelativeOrgMode;
static BOOL ReverseColor;
static BOOL InsertMode;
static BOOL LFMode;
static BOOL AutoWrapMode;

// save/restore cursor
typedef struct {
  int CursorX, CursorY;
  BYTE Attr, Attr2;
  int Glr[2], Gn[4]; // G0-G3, GL & GR
  BOOL AutoWrapMode;
  BOOL RelativeOrgMode;
} TStatusBuff;
typedef TStatusBuff *PStatusBuff;

// status buffer for main screen & status line
static TStatusBuff SBuff1, SBuff2;

static BOOL ESCFlag, JustAfterESC;
static BOOL KanjiIn;
static BOOL EUCkanaIn, EUCsupIn;
static int  EUCcount;
static BOOL Special;

static int Param[NParamMax+1];
static int NParam;
static BOOL FirstPrm;
static BYTE IntChar[IntCharMax+1];
static int ICount;
static BYTE Prv;
static int ParseMode, SavedMode;
static int ChangeEmu;

/* user defined keys */
static BOOL WaitKeyId, WaitHi;

/* GL, GR code group */
static int Glr[2];
/* G0, G1, G2, G3 code group */
static int Gn[4];
/* GL for single shift 2/3 */
static int GLtmp;
/* single shift 2/3 flag */
static BOOL SSflag;
/* JIS -> SJIS conversion flag */
static BOOL ConvJIS;
static WORD Kanji;

// variables for status line mode
static int StatusX=0;
static BOOL StatusWrap=FALSE;
static BOOL StatusCursor=TRUE;
static int MainX, MainY; //cursor registers
static int MainTop, MainBottom; // scroll region registers
static BOOL MainWrap;
static BOOL MainCursor=TRUE;

/* status for printer escape sequences */
static BOOL PrintEX = TRUE;  // printing extent
			    // (TRUE: screen, FALSE: scroll region)
static BOOL AutoPrintMode = FALSE;
static BOOL PrinterMode = FALSE;
static BOOL DirectPrn = FALSE;

/* User key */
static BYTE NewKeyStr[FuncKeyStrMax];
static int NewKeyId, NewKeyLen;

void ResetSBuffers()
{
  SBuff1.CursorX = 0;
  SBuff1.CursorY = 0;
  SBuff1.Attr = AttrDefault;
  SBuff1.Attr2 = AttrDefault2;
  if (ts.Language==IdJapanese)
  {
    SBuff1.Gn[0] = IdASCII;
    SBuff1.Gn[1] = IdKatakana;
    SBuff1.Gn[2] = IdKatakana;
    SBuff1.Gn[3] = IdKanji;
    SBuff1.Glr[0] = 0;
    if ((ts.KanjiCode==IdJIS) &&
	(ts.JIS7Katakana==0))
      SBuff1.Glr[1] = 2;  // 8-bit katakana
    else
      SBuff1.Glr[1] = 3;
  }
  else {
    SBuff1.Gn[0] = IdASCII;
    SBuff1.Gn[1] = IdSpecial;
    SBuff1.Gn[2] = IdASCII;
    SBuff1.Gn[3] = IdASCII;
    SBuff1.Glr[0] = 0;
    SBuff1.Glr[1] = 0;
  }
  SBuff1.AutoWrapMode = TRUE;
  SBuff1.RelativeOrgMode = FALSE;
  // copy SBuff1 to SBuff2
  SBuff2 = SBuff1;
}

void ResetTerminal() /*reset variables but don't update screen */
{
  DispReset();
  BuffReset();

  /* Attribute */
  CharAttr = AttrDefault;
  CharAttr2 = AttrDefault2;
  Special = FALSE;

  /* Various modes */
  InsertMode = FALSE;
  LFMode = (ts.CRSend == IdCRLF);
  AutoWrapMode = TRUE;
  AppliKeyMode = FALSE;
  AppliCursorMode = FALSE;
  RelativeOrgMode = FALSE;
  ReverseColor = FALSE;
  AutoRepeatMode = TRUE;

  /* Character sets */
  ResetCharSet();

  /* ESC flag for device control sequence */
  ESCFlag = FALSE;
  /* for TEK sequence */
  JustAfterESC = FALSE;

  /* Parse mode */
  ParseMode = ModeFirst;

  /* Clear printer mode */
  PrinterMode = FALSE;

  // status buffers
  ResetSBuffers();
}

void ResetCharSet()
{
  if (ts.Language==IdJapanese)
  {
    Gn[0] = IdASCII;
    Gn[1] = IdKatakana;
    Gn[2] = IdKatakana;
    Gn[3] = IdKanji;
    Glr[0] = 0;
    if ((ts.KanjiCode==IdJIS) &&
	(ts.JIS7Katakana==0))
      Glr[1] = 2;  // 8-bit katakana
    else
      Glr[1] = 3;
  }
  else {
    Gn[0] = IdASCII;
    Gn[1] = IdSpecial;
    Gn[2] = IdASCII;
    Gn[3] = IdASCII;
    Glr[0] = 0;
    Glr[1] = 0;
    cv.SendCode = IdASCII;
    cv.SendKanjiFlag = FALSE;
    cv.EchoCode = IdASCII;
    cv.EchoKanjiFlag = FALSE;
  }
  /* Kanji flag */
  KanjiIn = FALSE;
  EUCkanaIn = FALSE;
  EUCsupIn = FALSE;
  SSflag = FALSE;

  cv.Language = ts.Language;
  cv.CRSend = ts.CRSend;
  cv.KanjiCodeEcho = ts.KanjiCode;
  cv.JIS7KatakanaEcho = ts.JIS7Katakana;
  cv.KanjiCodeSend = ts.KanjiCodeSend;
  cv.JIS7KatakanaSend = ts.JIS7KatakanaSend;
  cv.KanjiIn = ts.KanjiIn;
  cv.KanjiOut = ts.KanjiOut;
}

void MoveToMainScreen()
{
  StatusX = CursorX;
  StatusWrap = Wrap;
  StatusCursor = IsCaretEnabled();

  CursorTop = MainTop;
  CursorBottom = MainBottom;
  Wrap = MainWrap;
  DispEnableCaret(MainCursor);
  MoveCursor(MainX,MainY); // move to main screen
}

void MoveToStatusLine()
{
  MainX = CursorX;
  MainY = CursorY;
  MainTop = CursorTop;
  MainBottom = CursorBottom;
  MainWrap = Wrap;
  MainCursor = IsCaretEnabled();

  DispEnableCaret(StatusCursor);
  MoveCursor(StatusX,NumOfLines-1); // move to status line
  CursorTop = NumOfLines-1;
  CursorBottom = CursorTop;
  Wrap = StatusWrap;
}

void HideStatusLine()
{
  if ((StatusLine>0) &&
      (CursorY==NumOfLines-1))
    MoveToMainScreen();
  StatusX = 0;
  StatusWrap = FALSE;
  StatusCursor = TRUE;
  ShowStatusLine(0); //hide
}

void ChangeTerminalSize(int Nx, int Ny)
{
  BuffChangeTerminalSize(Nx,Ny);
  StatusX = 0;
  MainX = 0;
  MainY = 0;
  MainTop = 0;
  MainBottom = NumOfColumns-1;
}

void BackSpace()
{
  if (CursorX == 0)
  {
    if ((CursorY>0) &&
	((ts.TermFlag & TF_BACKWRAP)!=0))
    {
      MoveCursor(NumOfColumns-1,CursorY-1);
      if (cv.HLogBuf!=0) Log1Byte(BS);
    }
  }
  else if (CursorX > 0)
  {
    MoveCursor(CursorX-1,CursorY);
    if (cv.HLogBuf!=0) Log1Byte(BS);
  }
}

void CarriageReturn()
{
 if (cv.HLogBuf!=0) Log1Byte(CR);
 if (CursorX>0)
   MoveCursor(0,CursorY);
}

void LineFeed(BYTE b)
{
 /* for auto print mode */
 if ((AutoPrintMode) &&
     (b>=LF) && (b<=FF))
   BuffDumpCurrentLine(b);

 if (cv.HLogBuf!=0) Log1Byte(LF);

 if (CursorY < CursorBottom)
   MoveCursor(CursorX,CursorY+1);
 else if (CursorY == CursorBottom) BuffScrollNLines(1);
 else if (CursorY < NumOfLines-StatusLine-1)
   MoveCursor(CursorX,CursorY+1);

 if (LFMode) CarriageReturn();
}

void Tab()
{
  MoveToNextTab();
  if (cv.HLogBuf!=0) Log1Byte(HT);
}

void PutChar(BYTE b)
{
  BOOL SpecialNew;
  BYTE CharAttrTmp;

  if (PrinterMode) { // printer mode
    WriteToPrnFile(b,TRUE);
    return;
  }

  if (Wrap)
  {
    CarriageReturn();
    LineFeed(LF);
  }
  if (cv.HLogBuf!=0) Log1Byte(b);
  Wrap = FALSE;

  SpecialNew = FALSE;
  if ((b>0x5F) && (b<0x80))
  {
    if (SSflag)
      SpecialNew = (Gn[GLtmp]==IdSpecial);
    else
      SpecialNew = (Gn[Glr[0]]==IdSpecial);
  }
  else if (b>0xDF)
  {
    if (SSflag)
      SpecialNew = (Gn[GLtmp]==IdSpecial);
    else
      SpecialNew = (Gn[Glr[1]]==IdSpecial);
  }

  if (SpecialNew != Special)
  {
    UpdateStr();
    Special = SpecialNew;
  }

  if (Special)
  {
    b = b & 0x7F;
    CharAttrTmp = CharAttr | AttrSpecial;
  }
  else
    CharAttrTmp = CharAttr;

  BuffPutChar(b,CharAttrTmp,CharAttr2,InsertMode);

  if (CursorX < NumOfColumns-1)
    MoveRight();
  else {
    UpdateStr();
    Wrap = AutoWrapMode;
  }
}

void PutKanji(BYTE b)
{
  Kanji = Kanji + b;

  if (PrinterMode && DirectPrn)
  {
    WriteToPrnFile(HIBYTE(Kanji),FALSE);
    WriteToPrnFile(LOBYTE(Kanji),TRUE);
    return;
  }

  if (ConvJIS)
    Kanji = JIS2SJIS((WORD)(Kanji & 0x7f7f));

  if (PrinterMode) { // printer mode
    WriteToPrnFile(HIBYTE(Kanji),FALSE);
    WriteToPrnFile(LOBYTE(Kanji),TRUE);
    return;
  }

  if (Wrap)
  {
    CarriageReturn();
    LineFeed(LF);
  }
  else if (CursorX > NumOfColumns-2)
    if (AutoWrapMode)
    {
      CarriageReturn();
      LineFeed(LF);
    }
    else return;

  Wrap = FALSE;

  if (cv.HLogBuf!=0)
  {
    Log1Byte(HIBYTE(Kanji));
    Log1Byte(LOBYTE(Kanji));
  }

  if (Special)
  {
    UpdateStr();
    Special = FALSE;
  }
  
  BuffPutKanji(Kanji,CharAttr,CharAttr2,InsertMode);

  if (CursorX < NumOfColumns-2)
  {
    MoveRight();
    MoveRight();
  }
  else {
    UpdateStr();
    Wrap = AutoWrapMode;
  }
}

void PutDebugChar(BYTE b)
{
  InsertMode = FALSE;
  AutoWrapMode = TRUE;

  if ((b & 0x80) == 0x80)
  {
    UpdateStr();
    CharAttr = AttrReverse;
    b = b & 0x7f;
  }

  if (b<=US)
  {
    PutChar('^');
    PutChar((char)(b+0x40));
  }
  else if (b==DEL)
  {
    PutChar('<');
    PutChar('D');
    PutChar('E');
    PutChar('L');
    PutChar('>');
  }
  else
    PutChar(b);

  if (CharAttr != AttrDefault)
  {
    UpdateStr();
    CharAttr = AttrDefault;
  }
}

void PrnParseControl(BYTE b) // printer mode
{
  switch (b) {
    case NUL: return;
    case SO:
      if (! DirectPrn)
      {
	if ((ts.Language==IdJapanese) &&
	    (ts.KanjiCode==IdJIS) &&
	    (ts.JIS7Katakana==1) &&
	    ((ts.TermFlag & TF_FIXEDJIS)!=0))
	  Gn[1] = IdKatakana;
	Glr[0] = 1; /* LS1 */
	return;
      }
      break;
    case SI:
      if (! DirectPrn)
      {
	Glr[0] = 0; /* LS0 */
	return;
      }
      break;
    case DC1:
    case DC3: return;
    case ESC:
      ICount = 0;
      JustAfterESC = TRUE;
      ParseMode = ModeESC;
      WriteToPrnFile(0,TRUE); // flush prn buff
      return;
    case CSI:
      if ((ts.TerminalID<IdVT220J) ||
	  ((ts.TermFlag & TF_ACCEPT8BITCTRL)==0))
      {
	PutChar(b); /* Disp C1 char in VT100 mode */
	return;
      }
      ICount = 0;
      FirstPrm = TRUE;
      NParam = 1;
      Param[1] = -1;
      Prv = 0;
      ParseMode = ModeCSI;
      WriteToPrnFile(0,TRUE); // flush prn buff
      WriteToPrnFile(b,FALSE);
      return;
  }
  /* send the uninterpreted character to printer */
  WriteToPrnFile(b,TRUE);
}

void ParseControl(BYTE b)
{
  if (PrinterMode) { // printer mode
    PrnParseControl(b);
    return;
  }

  if (b>=0x80) /* C1 char */
  {
    /* English mode */
    if (ts.Language==IdEnglish)
    {
      if ((ts.TerminalID<IdVT220J) ||
	  ((ts.TermFlag & TF_ACCEPT8BITCTRL)==0))
      {
	PutChar(b); /* Disp C1 char in VT100 mode */
	return;
      }
    }
    else { /* Japanese mode */
      if ((ts.TermFlag & TF_ACCEPT8BITCTRL)==0)
	return; /* ignore C1 char */
      /* C1 chars are interpreted as C0 chars in VT100 mode */
      if (ts.TerminalID<IdVT220J)
	b = b & 0x7F;
    }
  }
  switch (b) {
    /* C0 group */
    case ENQ:
      CommBinaryOut(&cv,&(ts.Answerback[0]),ts.AnswerbackLen);
      break;
    case BEL:
      if (ts.Beep!=0)
	MessageBeep(0);
      break;
    case BS: BackSpace(); break;
    case HT: Tab(); break;
    case LF:
    case VT: LineFeed(b); break;
    case FF:
      if ((ts.AutoWinSwitch>0) && JustAfterESC)
      {
	CommInsert1Byte(&cv,b);
	CommInsert1Byte(&cv,ESC);
	ChangeEmu = IdTEK;  /* Enter TEK Mode */
      }
      else
	LineFeed(b);
      break;
    case CR:
      CarriageReturn();
      if (ts.CRReceive==IdCRLF)
	CommInsert1Byte(&cv,LF);
      break;
    case SO:
      if ((ts.Language==IdJapanese) &&
	  (ts.KanjiCode==IdJIS) &&
	  (ts.JIS7Katakana==1) &&
	  ((ts.TermFlag & TF_FIXEDJIS)!=0))
	Gn[1] = IdKatakana;

      Glr[0] = 1; /* LS1 */
      break;
    case SI: Glr[0] = 0; break; /* LS0 */
    case DLE:
      if ((ts.FTFlag & FT_BPAUTO)!=0)
	ParseMode = ModeDLE; /* Auto B-Plus activation */
      break;
    case CAN:
      if ((ts.FTFlag & FT_ZAUTO)!=0)
	ParseMode = ModeCAN; /* Auto ZMODEM activation */
//	else if (ts.AutoWinSwitch>0)
//		ChangeEmu = IdTEK;  /* Enter TEK Mode */
      else
	ParseMode = ModeFirst;
      break;
    case SUB: ParseMode = ModeFirst; break;
    case ESC:
      ICount = 0;
      JustAfterESC = TRUE;
      ParseMode = ModeESC;
      break;
    case FS:
    case GS:
    case RS:
    case US:
      if (ts.AutoWinSwitch>0)
      {
	CommInsert1Byte(&cv,b);
	ChangeEmu = IdTEK;  /* Enter TEK Mode */
      }
      break;

    /* C1 char */
    case IND: LineFeed(0); break;
    case NEL:
      LineFeed(0);
      CarriageReturn();
      break;
    case HTS: SetTabStop(); break;
    case RI: CursorUpWithScroll(); break;
    case SS2:
      GLtmp = 2;
      SSflag = TRUE;
      break;
    case SS3:
      GLtmp = 3;
      SSflag = TRUE;
      break;
    case DCS:
      SavedMode = ParseMode;
      ESCFlag = FALSE;
      NParam = 1;
      Param[1] = -1;
      ParseMode = ModeDCS;
      break;
    case SOS:
      SavedMode = ParseMode;
      ESCFlag = FALSE;
      ParseMode = ModeSOS;
      break;
    case CSI:
      ICount = 0;
      FirstPrm = TRUE;
      NParam = 1;
      Param[1] = -1;
      Prv = 0;
      ParseMode = ModeCSI;
      break;
    case OSC:
    case PM:
    case APC:
      SavedMode = ParseMode;
      ESCFlag = FALSE;
      ParseMode = ModeSOS;
      break;
  }
}

void SaveCursor()
{
  int i;
  PStatusBuff Buff;

  if ((StatusLine>0) &&
      (CursorY==NumOfLines-1))
    Buff = &SBuff2; // for status line
  else
    Buff = &SBuff1; // for main screen

  Buff->CursorX = CursorX;
  Buff->CursorY = CursorY;
  Buff->Attr = CharAttr;
  Buff->Attr2 = CharAttr2;
  Buff->Glr[0] = Glr[0];
  Buff->Glr[1] = Glr[1];
  for (i=0 ; i<=3; i++)
    Buff->Gn[i] = Gn[i];
  Buff->AutoWrapMode = AutoWrapMode;
  Buff->RelativeOrgMode = RelativeOrgMode;
}

void  RestoreCursor()
{
  int i;
  PStatusBuff Buff;
  UpdateStr();

  if ((StatusLine>0) &&
      (CursorY==NumOfLines-1))
    Buff = &SBuff2; // for status line
  else
    Buff = &SBuff1; // for main screen

  if (Buff->CursorX > NumOfColumns-1)
    Buff->CursorX = NumOfColumns-1;
  if (Buff->CursorY > NumOfLines-1-StatusLine)
    Buff->CursorY = NumOfLines-1-StatusLine;
  MoveCursor(Buff->CursorX,Buff->CursorY);
  CharAttr = Buff->Attr;
  CharAttr2 = Buff->Attr2;
  Glr[0] = Buff->Glr[0];
  Glr[1] = Buff->Glr[1];
  for (i=0 ; i<=3; i++)
    Gn[i] = Buff->Gn[i];
  AutoWrapMode = Buff->AutoWrapMode;
  RelativeOrgMode = Buff->RelativeOrgMode;
}

void AnswerTerminalType()
{
  char Tmp[31];

  if (ts.TerminalID<IdVT320)
    strcpy(Tmp,"\033[?");
  else
    strcpy(Tmp,"\233?");

  switch (ts.TerminalID) {
    case IdVT100:
      strcat(Tmp,"1;2");
      break;
    case IdVT100J:
      strcat(Tmp,"5;2");
      break;
    case IdVT101:
      strcat(Tmp,"1;0");
      break;
    case IdVT102:
      strcat(Tmp,"6");
      break;
    case IdVT102J:
      strcat(Tmp,"15");
      break;
    case IdVT220J:
      strcat(Tmp,"62;1;2;5;6;7;8");
      break;
    case IdVT282:
      strcat(Tmp,"62;1;2;4;5;6;7;8;10;11");
      break;
    case IdVT320:
      strcat(Tmp,"63;1;2;6;7;8");
      break;
    case IdVT382:
      strcat(Tmp,"63;1;2;4;5;6;7;8;10;15");
      break;
  }
  strcat(Tmp,"c");

  CommBinaryOut(&cv,Tmp,strlen(Tmp)); /* Report terminal ID */
}

void ESCSharp(BYTE b)
{
  switch (b) {
    case '8':  /* Fill screen with "E" */
      BuffUpdateScroll();
      BuffFillWithE();
      MoveCursor(0,0);
      ParseMode = ModeFirst;
      break;
  }
}

/* select double byte code set */
void ESCDBCSSelect(BYTE b)
{
  int Dist;

  if (ts.Language!=IdJapanese) return;

  switch (ICount) {
    case 1:
      if ((b=='@') || (b=='B'))
      {
	Gn[0] = IdKanji; /* Kanji -> G0 */
	if ((ts.TermFlag & TF_AUTOINVOKE)!=0)
	  Glr[0] = 0; /* G0->GL */
      }
      break;
    case 2:
      /* Second intermediate char must be
	 '(' or ')' or '*' or '+'. */
      Dist = (IntChar[2]-'(') & 3; /* G0 - G3 */
      if ((b=='1') || (b=='3') ||
	  (b=='@') || (b=='B'))
      {
	Gn[Dist] = IdKanji; /* Kanji -> G0-3 */
	if (((ts.TermFlag & TF_AUTOINVOKE)!=0) &&
	    (Dist==0))
	  Glr[0] = 0; /* G0->GL */
      }
      break;
  }
}  

void ESCSelectCode(BYTE b)
{
  switch (b) {
    case '0':
      if (ts.AutoWinSwitch>0)
	ChangeEmu = IdTEK; /* enter TEK mode */
      break;
  }
}

  /* select single byte code set */
void ESCSBCSSelect(BYTE b)
{
  int Dist;

  /* Intermediate char must be
     '(' or ')' or '*' or '+'.	*/
  Dist = (IntChar[1]-'(') & 3; /* G0 - G3 */

  switch (b) {
    case '0': Gn[Dist] = IdSpecial; break;
    case '<': Gn[Dist] = IdASCII; break;
    case '>': Gn[Dist] = IdASCII; break;
    case 'B': Gn[Dist] = IdASCII; break;
    case 'H': Gn[Dist] = IdASCII; break;
    case 'I':
      if (ts.Language==IdJapanese)
	Gn[Dist] = IdKatakana;
      break;
    case 'J': Gn[Dist] = IdASCII; break;
  }

  if (((ts.TermFlag & TF_AUTOINVOKE)!=0) &&
      (Dist==0))
    Glr[0] = 0;  /* G0->GL */
}

void PrnParseEscape(BYTE b) // printer mode
{
  int i;

  ParseMode = ModeFirst;
  switch (ICount) {
    /* no intermediate char */
    case 0:
      switch (b) {
	case '[': /* CSI */
	  ICount = 0;
	  FirstPrm = TRUE;
	  NParam = 1;
	  Param[1] = -1;
	  Prv = 0;
	  WriteToPrnFile(ESC,FALSE);
	  WriteToPrnFile('[',FALSE);
	  ParseMode = ModeCSI;
	  return;
      } /* end of case Icount=0 */
      break;
    /* one intermediate char */
    case 1:
      switch (IntChar[1]) {
	case '$':
	  if (! DirectPrn)
	  {
	    ESCDBCSSelect(b);
	    return;
	  }
	  break;
	case '(':
	case ')':
	case '*':
	case '+':
	  if (! DirectPrn)
	  {
	    ESCSBCSSelect(b);
	    return;
	  }
	  break;
      }
      break;
    /* two intermediate char */
    case 2:
      if ((! DirectPrn) &&
	  (IntChar[1]=='$') &&
	  ('('<=IntChar[2]) &&
	  (IntChar[2]<='+'))
      {
	ESCDBCSSelect(b);
	return;
      }
      break;
  }
  // send the uninterpreted sequence to printer
  WriteToPrnFile(ESC,FALSE);
  for (i=1; i<=ICount; i++)
    WriteToPrnFile(IntChar[i],FALSE);
  WriteToPrnFile(b,TRUE);
}

void ParseEscape(BYTE b) /* b is the final char */
{
  if (PrinterMode) { // printer mode
    PrnParseEscape(b);
    return;
  }

  switch (ICount) {
    /* no intermediate char */
    case 0:
      switch (b) {
	case '7': SaveCursor(); break;
	case '8': RestoreCursor(); break;
	case '=': AppliKeyMode = TRUE; break;
	case '>': AppliKeyMode = FALSE; break;
	case 'D': /* IND */
	  LineFeed(0);
	  break;
	case 'E': /* NEL */
	  MoveCursor(0,CursorY);
	  LineFeed(0);
	  break;
	case 'H': /* HTS */
	  SetTabStop();
	  break;
	case 'M': /* RI */
	  CursorUpWithScroll();
	  break;
	case 'N': /* SS2 */
	  GLtmp = 2;
	  SSflag = TRUE;
	  break;
	case 'O': /* SS3 */
	  GLtmp = 3;
	  SSflag = TRUE;
	  break;
	case 'P': /* DCS */
	  SavedMode = ParseMode;
	  ESCFlag = FALSE;
	  NParam = 1;
	  Param[1] = -1;
	  ParseMode = ModeDCS;
	  return;
	case 'X': /* SOS */
	  SavedMode = ParseMode;
	  ESCFlag = FALSE;
	  ParseMode = ModeSOS;
	  return;
	case 'Z': AnswerTerminalType(); break;
	case '[': /* CSI */
	  ICount = 0;
	  FirstPrm = TRUE;
	  NParam = 1;
	  Param[1] = -1;
	  Prv = 0;
	  ParseMode = ModeCSI;
	  return;
	case '\\': break; /* ST */
	case ']': /* XTERM sequence (OSC) */
	  NParam = 1;
	  Param[1] = 0;
	  ParseMode = ModeXS;
	  return;  
	case '^':
	case '_': /* PM, APC */
	  SavedMode = ParseMode;
	  ESCFlag = FALSE;
	  ParseMode = ModeSOS;
	  return;
	case 'c': /* Hardware reset */
	  HideStatusLine();
	  ResetTerminal();
	  ClearUserKey();
	  ClearBuffer();
	  if (ts.PortType==IdSerial) // reset serial port
	    CommResetSerial(&ts,&cv);
	  break;
	case 'n': Glr[0] = 2; break; /* LS2 */
	case 'o': Glr[0] = 3; break; /* LS3 */
	case '|': Glr[1] = 3; break; /* LS3R */
	case '}': Glr[1] = 2; break; /* LS2R */
	case '~': Glr[1] = 1; break; /* LS1R */
      } /* end of case Icount=0 */
      break;
    /* one intermediate char */
    case 1:
      switch (IntChar[1]) {
	case '#': ESCSharp(b); break;
	case '$': ESCDBCSSelect(b); break;
	case '%': break;
	case '(':
	case ')':
	case '*':
	case '+':
	  ESCSBCSSelect(b);
	  break;
      }
      break;
    /* two intermediate char */
    case 2:
      if ((IntChar[1]=='$') &&
	  ('('<=IntChar[2]) &&
	  (IntChar[2]<='+'))
	ESCDBCSSelect(b);
      else if ((IntChar[1]=='%') &&
	       (IntChar[2]=='!'))
	ESCSelectCode(b);
      break;
  }
  ParseMode = ModeFirst;
}

void EscapeSequence(BYTE b)
{
  if (b<=US)
    ParseControl(b);
  else if ((b>=0x20) && (b<=0x2F))
  {
    if (ICount<IntCharMax) ICount++;
    IntChar[ICount] = b;
  }
  else if ((b>=0x30) && (b<=0x7E))
    ParseEscape(b);
  else if ((b>=0x80) && (b<=0x9F))
    ParseControl(b);

  JustAfterESC = FALSE;
}

  void CSInsertCharacter()
  {
  // Insert space characters at cursor
    int Count;

    BuffUpdateScroll();
    if (Param[1]<1) Param[1] = 1;
    Count = Param[1];
    BuffInsertSpace(Count);
  }

  void CSCursorUp()
  {
    if (Param[1]<1) Param[1] = 1;

    if (CursorY >= CursorTop)
    {
      if (CursorY-Param[1] > CursorTop)
	MoveCursor(CursorX,CursorY-Param[1]);
      else
	MoveCursor(CursorX,CursorTop);
    }
    else {
      if (CursorY > 0)
	MoveCursor(CursorX,CursorY-Param[1]);
      else
	MoveCursor(CursorX,0);
    }
  }

  void CSCursorUp1()
  {
    MoveCursor(0,CursorY);
    CSCursorUp();
  }

  void CSCursorDown()
  {
    if (Param[1]<1) Param[1] = 1;

    if (CursorY <= CursorBottom)
    {
      if (CursorY+Param[1] < CursorBottom)
	MoveCursor(CursorX,CursorY+Param[1]);
      else
	MoveCursor(CursorX,CursorBottom);
    }
    else {
      if (CursorY < NumOfLines-StatusLine-1)
	MoveCursor(CursorX,CursorY+Param[1]);
      else
	MoveCursor(CursorX,NumOfLines-StatusLine);
    }
  }

  void CSCursorDown1()
  {
    MoveCursor(0,CursorY);
    CSCursorDown();
  }

  void CSScreenErase()
  {
    if (Param[1] == -1) Param[1] = 0;
    BuffUpdateScroll();
    switch (Param[1]) {
      case 0:
//	Erase characters from cursor to the end of screen
	BuffEraseCurToEnd();
	break;
      case 1:
//	Erase characters from home to cursor
	BuffEraseHomeToCur();
	break;
      case 2:
//	Erase screen (scroll out)
	BuffClearScreen();
	UpdateWindow(HVTWin);
	break;
    }
  }

  void CSInsertLine()
  {
  // Insert lines at current position
    int Count, YEnd;

    if (CursorY < CursorTop) return;
    if (CursorY > CursorBottom) return;
    if (Param[1]<1) Param[1] = 1;
    Count = Param[1];

    YEnd = CursorBottom;
    if (CursorY > YEnd) YEnd = NumOfLines-1-StatusLine;
    if (Count > YEnd+1 - CursorY) Count = YEnd+1 - CursorY;

    BuffInsertLines(Count,YEnd);
  }

  void CSLineErase()
  {
    if (Param[1] == -1) Param[1] = 0;
    BuffUpdateScroll();
    switch (Param[1]) {
      /* erase char from cursor to end of line */
      case 0:
	BuffEraseCharsInLine(CursorX,NumOfColumns-CursorX);
	break;
      /* erase char from start of line to cursor */
      case 1:
	BuffEraseCharsInLine(0,CursorX+1);
	break;
      /* erase entire line */
      case 2:
	BuffEraseCharsInLine(0,NumOfColumns);
	break;
    }
  }

  void CSDeleteNLines()
  // Delete lines from current line
  {
    int Count, YEnd;

    if (CursorY < CursorTop) return;
    if (CursorY > CursorBottom) return;
    Count = Param[1];
    if (Count<1) Count = 1;

    YEnd = CursorBottom;
    if (CursorY > YEnd) YEnd = NumOfLines-1-StatusLine;
    if (Count > YEnd+1-CursorY) Count = YEnd+1-CursorY;
    BuffDeleteLines(Count,YEnd);
  }

  void CSDeleteCharacter()
  {
  // Delete characters in current line from cursor

    if (Param[1]<1) Param[1] = 1;
    BuffUpdateScroll();
    BuffDeleteChars(Param[1]);
  }

  void CSEraseCharacter()
  {
    if (Param[1]<1) Param[1] = 1;
    BuffUpdateScroll();
    BuffEraseChars(Param[1]);
  }

  void CSMoveToColumnN()
  {
    if (Param[1]<1) Param[1] = 1;
    Param[1]--;
    if (Param[1] < 0) Param[1] = 0;
    if (Param[1] > NumOfColumns-1) Param[1] = NumOfColumns-1;
    MoveCursor(Param[1],CursorY);
  }

  void CSCursorRight()
  {
    if (Param[1]<1) Param[1] = 1;
    if (CursorX + Param[1] > NumOfColumns-1)
      MoveCursor(NumOfColumns-1,CursorY);
    else
      MoveCursor(CursorX+Param[1],CursorY);
  }

  void CSCursorLeft()
  {
    if (Param[1]<1) Param[1] = 1;
    if (CursorX-Param[1] < 0)
      MoveCursor(0,CursorY);
    else
      MoveCursor(CursorX-Param[1],CursorY);
  }

  void CSMoveToLineN()
  {
    if (Param[1]<1) Param[1] = 1;
    if (RelativeOrgMode)
    {
      if (CursorTop+Param[1]-1 > CursorBottom)
	MoveCursor(CursorX,CursorBottom);
      else
	MoveCursor(CursorX,CursorTop+Param[1]-1);
    }
    else {
      if (Param[1] > NumOfLines-StatusLine)
	MoveCursor(CursorX,NumOfLines-1-StatusLine);
      else
	MoveCursor(CursorX,Param[1]-1);
    }
  }

  void CSMoveToXY()
  {
    int NewX, NewY;

    if (Param[1]<1) Param[1] = 1;
    if ((NParam < 2) || (Param[2]<1)) Param[2] = 1;
    NewX = Param[2] - 1;
    if (NewX > NumOfColumns-1) NewX = NumOfColumns-1;

    if ((StatusLine>0) && (CursorY==NumOfLines-1))
      NewY = CursorY;
    else if (RelativeOrgMode)
    {
      NewY = CursorTop + Param[1] - 1;
      if (NewY > CursorBottom) NewY = CursorBottom;
    }
    else {
      NewY = Param[1] - 1;
      if (NewY > NumOfLines-1-StatusLine)
	NewY = NumOfLines-1-StatusLine;
    }
    MoveCursor(NewX,NewY);
  }

  void CSDeleteTabStop()
  {
    if (Param[1]==-1) Param[1] = 0;
    ClearTabStop(Param[1]);
  }

  void CS_h_Mode()
  {
    switch (Param[1]) {
      case 4: InsertMode = TRUE; break;
      case 12:
	ts.LocalEcho = 0;
	if (cv.Ready && cv.TelFlag && (ts.TelEcho>0))
	  TelChangeEcho();
	break;
      case 20:
	LFMode = TRUE;
	ts.CRSend = IdCRLF;
	cv.CRSend = IdCRLF;
	break;
    }
  }

  void CS_i_Mode()
  {
    if (Param[1]==-1) Param[1] = 0;
    switch (Param[1]) {
      /* print screen */
	//  PrintEX --	TRUE: print screen
	//		FALSE: scroll region
      case 0: BuffPrint(! PrintEX); break;
      /* printer controller mode off */
      case 4: break; /* See PrnParseCS() */
      /* printer controller mode on */
      case 5:
	if (! AutoPrintMode)
	  OpenPrnFile();
	DirectPrn = (ts.PrnDev[0]!=0);
	PrinterMode = TRUE;
	break;
    }
  }

  void CS_l_Mode()
  {
    switch (Param[1]) {
      case 4: InsertMode = FALSE; break;
      case 12:
	ts.LocalEcho = 1;
	if (cv.Ready && cv.TelFlag && (ts.TelEcho>0))
	  TelChangeEcho();
	break;
      case 20:
	LFMode = FALSE;
	ts.CRSend = IdCR;
	cv.CRSend = IdCR;
	break;
    }
  }

  void CS_n_Mode()
  {
    char Report[16];
    int Y;

    switch (Param[1]) {
      case 5:
	CommBinaryOut(&cv,"\033[0n",4); /* Device Status Report -> Ready */
	break;
      case 6:
	/* Cursor Position Report */
	Y = CursorY+1;
	if ((StatusLine>0) &&
	    (Y==NumOfLines))
	  Y = 1;
	sprintf(Report,"\033[%u;%uR",Y,CursorX+1);
	CommBinaryOut(&cv,Report,strlen(Report));
	break;
    }
  }

  void CSSetAttr()
  {
    int i, P;

    UpdateStr();
    for (i=1 ; i<=NParam ; i++)
    {
      P = Param[i];
      if (P<0) P = 0;
      switch (P) {
	/* Clear */
	case 0:
	  CharAttr = AttrDefault;
	  CharAttr2 = AttrDefault2;
	  break;
	/* Bold */
	case 1:
	  CharAttr = CharAttr | AttrBold;
	  break;
	/* Under line */
	case 4:
	  CharAttr = CharAttr | AttrUnder;
	  break;
	/* Blink */
	case 5:
	  CharAttr = CharAttr | AttrBlink;
	  break;
	/* Reverse */
	case 7:
	  CharAttr = CharAttr | AttrReverse;
	  break;
	/* Bold off */
	case 22:
	  CharAttr = CharAttr & ~ AttrBold;
	  break;
	/* Under line off */
	case 24:
	  CharAttr = CharAttr & ~ AttrUnder;
	  break;
	/* Blink off */
	case 25:
	  CharAttr = CharAttr & ~ AttrBlink;
	  break;
	/* Reverse off */
	case 27:
	  CharAttr = CharAttr & ~ AttrReverse;
	  break;
	default:
	  /* Text color */
	  if ((P>=30) && (P<=37))
	    CharAttr2 = CharAttr2 & (Attr2Back | Attr2BackMask)
	      | (P-30) | Attr2Fore;
	  else if ((P>=40) && (P<=47)) /* Back color */
	    CharAttr2 = CharAttr2 & (Attr2Fore | Attr2ForeMask)
	      | ((P-40) << SftAttrBack) | Attr2Back;
	  else if (P==100) /* Reset color attributes */
	    CharAttr2 = AttrDefault2;
      }
    }
  }

  void CSSetScrollRegion()
  {
    if ((StatusLine>0) &&
	(CursorY==NumOfLines-1))
    {
      MoveCursor(0,CursorY);
      return;
    }
    if (Param[1]<1) Param[1] =1;    
    if ((NParam < 2) | (Param[2]<1))
      Param[2] = NumOfLines-StatusLine;
    Param[1]--;
    Param[2]--;
    if (Param[1] > NumOfLines-1-StatusLine)
      Param[1] = NumOfLines-1-StatusLine;
    if (Param[2] > NumOfLines-1-StatusLine)
      Param[2] = NumOfLines-1-StatusLine;
    if (Param[1] >= Param[2]) return;
    CursorTop = Param[1];
    CursorBottom = Param[2];
    if (RelativeOrgMode) MoveCursor(0,CursorTop);
		    else MoveCursor(0,0);
  }

  void CSSunSequence() /* Sun terminal private sequences */
  {
    char Report[16];

    switch (Param[1]) {
      case 8: /* set terminal size */
	if ((Param[2]<=1) || (NParam<2)) Param[2] = 24;
	if ((Param[3]<=1) || (NParam<3)) Param[3] = 80;
	ChangeTerminalSize(Param[3],Param[2]);
	break;
      case 14: /* get window size??? */
	/* this is not actual window size */
	CommBinaryOut(&cv,"\033[4;640;480t",12);
	break;
      case 18: /* get terminal size */
	sprintf(Report,"\033[8;%u;%u;t",NumOfLines-StatusLine,NumOfColumns);
	CommBinaryOut(&cv,Report,strlen(Report));
	break;
    }
  }

  void CSGT(BYTE b)
  {
    switch (b) {
      case 'c': /* second terminal report */
	CommBinaryOut(&cv,"\033[>32;10;2c",11); /* VT382 */
	break;
      case 'J':
	if (Param[1]==3) // IO-8256 terminal
	{
	  if (Param[2]<1) Param[2]=1;
	  if (Param[3]<1) Param[3]=1;
	  if (Param[4]<1) Param[4]=1;
	  if (Param[5]<1) Param[5]=1;
	  BuffEraseBox(Param[3]-1,Param[2]-1,
		       Param[5]-1,Param[4]-1);
	}
	break;
      case 'K':
	if ((NParam>=2) && (Param[1]==5))
	{	// IO-8256 terminal
	  switch (Param[2]) {
	    case 3:
	    case 4:
	    case 5:
	    case 6:
	      BuffDrawLine(CharAttr,CharAttr2,
			   Param[2],Param[3]);
	      break;
	    case 12:
	      /* Text color */
	      if ((Param[3]>=0) && (Param[3]<=7))
	      {
		if (Param[3]==3) Param[3]=IdBlue;
		else if (Param[3]==4) Param[3]=IdCyan;
		else if (Param[3]==5) Param[3]=IdYellow;
		else if (Param[3]==6) Param[3]=IdMagenta;
		CharAttr2 = CharAttr2 & (Attr2Back | Attr2BackMask)
		  | Param[3] | Attr2Fore;
	      }
	      break;
	  }
	}
	else if (Param[1]==3)
	{// IO-8256 terminal
	  if (Param[2]<1) Param[2] = 1;
	  if (Param[3]<1) Param[2] = 1;
	  BuffEraseCharsInLine(Param[2]-1,Param[3]-Param[2]+1);
	}
	break;
    }
  }

    void CSQExchangeColor()
    {
      COLORREF ColorRef;

      BuffUpdateScroll();

      ColorRef = ts.VTColor[0];
      ts.VTColor[0] = ts.VTColor[1];
      ts.VTColor[1] = ColorRef;
      DispChangeBackground();
    }

    void CSQ_h_Mode()
    {
      int i;

      for (i = 1 ; i<=NParam ; i++)
	switch (Param[i]) {
	  case 1: AppliCursorMode = TRUE; break;
	  case 3:
	    ChangeTerminalSize(132,NumOfLines-StatusLine);
	    break;
	  case 5:
	    if (ReverseColor) return;
	    ReverseColor = TRUE;
	      /* Exchange text/back color */
	    CSQExchangeColor();
	    break;
	  case 6:
	    if ((StatusLine>0) &&
		(CursorY==NumOfLines-1))
	      MoveCursor(0,CursorY);
	    else {
	      RelativeOrgMode = TRUE;
	      MoveCursor(0,CursorTop);
	    }
	    break;
	  case 7: AutoWrapMode = TRUE; break;
	  case 8: AutoRepeatMode = TRUE; break;
	  case 19: PrintEX = TRUE; break;
	  case 25: DispEnableCaret(TRUE); break; // cursor on
	  case 38:
	    if (ts.AutoWinSwitch>0)
	      ChangeEmu = IdTEK; /* Enter TEK Mode */
	    break;
	  case 59:
	    if (ts.Language==IdJapanese)
	    { /* kanji terminal */
	      Gn[0] = IdASCII;
	      Gn[1] = IdKatakana;
	      Gn[2] = IdKatakana;
	      Gn[3] = IdKanji;
	      Glr[0] = 0;
	      if ((ts.KanjiCode==IdJIS) &&
		  (ts.JIS7Katakana==0))
		Glr[1] = 2;  // 8-bit katakana
	      else
		Glr[1] = 3;
	    }
	    break;
	  case 67: ts.BSKey = IdBS; break;
      }
    }

    void CSQ_i_Mode()
    {
      if (Param[1]==-1) Param[1] = 0;
      switch (Param[1]) {
	case 1:
	  OpenPrnFile();
	  BuffDumpCurrentLine(LF);
	  if (! AutoPrintMode)
	    ClosePrnFile();
	  break;
	/* auto print mode off */
	case 4:
	  if (AutoPrintMode)
	  {
	    ClosePrnFile();
	    AutoPrintMode = FALSE;
	  }
	  break;
	/* auto print mode on */
	case 5:
	  if (! AutoPrintMode)
	  {
	    OpenPrnFile();
	    AutoPrintMode = TRUE;
	  }
	  break;
      }
    }

    void CSQ_l_Mode()
    {
      int i;

      for (i = 1 ; i <= NParam ; i++)
	switch (Param[i]) {
	  case 1: AppliCursorMode = FALSE; break;
	  case 3:
	    ChangeTerminalSize(80,NumOfLines-StatusLine);
	    break;
	  case 5:
	    if (! ReverseColor) return;
	    ReverseColor = FALSE;
	    /* Exchange text/back color */
	    CSQExchangeColor();
	    break;
	  case 6:
	    if ((StatusLine>0) &&
		(CursorY==NumOfLines-1))
	      MoveCursor(0,CursorY);
	    else {
	      RelativeOrgMode = FALSE;
	      MoveCursor(0,0);
	    }
	    break;
	  case 7: AutoWrapMode = FALSE; break;
	  case 8: AutoRepeatMode = FALSE; break;
	  case 19: PrintEX = FALSE; break;
	  case 25: DispEnableCaret(FALSE); break; // cursor off
	  case 59:
	    if (ts.Language==IdJapanese)
	    { /* katakana terminal */
	      Gn[0] = IdASCII;
	      Gn[1] = IdKatakana;
	      Gn[2] = IdKatakana;
	      Gn[3] = IdKanji;
	      Glr[0] = 0;
	      if ((ts.KanjiCode==IdJIS) &&
		  (ts.JIS7Katakana==0))
		Glr[1] = 2;  // 8-bit katakana
	      else
		Glr[1] = 3;
	    }
	    break;
	  case 67: ts.BSKey = IdDEL; break;
	}
    }

    void CSQ_n_Mode()
    {
    }

  void CSQuest(BYTE b)
  {
    switch (b) {
      case 'K': CSLineErase(); break; 
      case 'h': CSQ_h_Mode(); break;
      case 'i': CSQ_i_Mode(); break;
      case 'l': CSQ_l_Mode(); break;
      case 'n': CSQ_n_Mode(); break;
    }
  }

  void SoftReset()
  // called by software-reset escape sequence handler
  {
    UpdateStr();
    AutoRepeatMode = TRUE;
    DispEnableCaret(TRUE); // cursor on
    InsertMode = FALSE;
    RelativeOrgMode = FALSE;
    AppliKeyMode = FALSE;
    AppliCursorMode = FALSE;
    if ((StatusLine>0) &&
	(CursorY == NumOfLines-1))
      MoveToMainScreen();
    CursorTop = 0;
    CursorBottom = NumOfLines-1-StatusLine;
    ResetCharSet();

    /* Attribute */
    CharAttr = AttrDefault;
    CharAttr2 = AttrDefault2;
    Special = FALSE;

    // status buffers
    ResetSBuffers();
  }

  void CSExc(BYTE b)
  {
    switch (b) {
      case 'p':
	/* Software reset */
	SoftReset();
	break;
    }
  }

  void CSDouble(BYTE b)
  {
    switch (b) {
      case 'p':
	/* Select terminal mode (software reset) */
	SoftReset();
	break;
    }
  }

  void CSDol(BYTE b)
  {
    switch (b) {
      case '}':
	if ((ts.TermFlag & TF_ENABLESLINE)==0) return;
	if (StatusLine==0) return;
	if ((Param[1]<1) && (CursorY==NumOfLines-1))
	  MoveToMainScreen();
	else if ((Param[1]==1) && (CursorY<NumOfLines-1))
	  MoveToStatusLine();
	break;
      case '~':
	if ((ts.TermFlag & TF_ENABLESLINE)==0) return;
	if (Param[1]<=1)
	  HideStatusLine();
	else if ((StatusLine==0) && (Param[1]==2))
	  ShowStatusLine(1); // show
	break;
    }
  }

void PrnParseCS(BYTE b) // printer mode
{
  ParseMode = ModeFirst;
  switch (ICount) {
    /* no intermediate char */
    case 0:
      switch (Prv) {
	/* no private parameter */
	case 0:
	  switch (b) {
	    case 'i':
	      if (Param[1]==4)
	      {
		PrinterMode = FALSE;
		// clear prn buff
		WriteToPrnFile(0,FALSE);
		if (! AutoPrintMode)
		  ClosePrnFile();
		return;
	      }
	      break;
	  } /* of case Prv=0 */
	  break;
      }
      break;
    /* one intermediate char */
    case 1: break;
  } /* of case Icount */

  WriteToPrnFile(b,TRUE);
}

void ParseCS(BYTE b) /* b is the final char */
{
  if (PrinterMode) { // printer mode
    PrnParseCS(b);
    return;
  }

  switch (ICount) {
    /* no intermediate char */
    case 0:
      switch (Prv) {
	/* no private parameter */
	case 0:
	  switch (b) {
	    case '@': CSInsertCharacter(); break;
	    case 'A': CSCursorUp(); break;
	    case 'B': CSCursorDown(); break;
	    case 'C': CSCursorRight(); break;
	    case 'D': CSCursorLeft(); break;
	    case 'E': CSCursorDown1(); break;
	    case 'F': CSCursorUp1(); break;
	    case 'G': CSMoveToColumnN(); break;
	    case 'H': CSMoveToXY(); break;
	    case 'J': CSScreenErase(); break;
	    case 'K': CSLineErase(); break;
	    case 'L': CSInsertLine(); break;
	    case 'M': CSDeleteNLines(); break;
	    case 'P': CSDeleteCharacter(); break;
	    case 'X': CSEraseCharacter(); break;
	    case '`': CSMoveToColumnN(); break;
	    case 'a': CSCursorRight(); break;
	    case 'c': AnswerTerminalType(); break;
	    case 'd': CSMoveToLineN(); break;
	    case 'e': CSCursorUp(); break;
	    case 'f': CSMoveToXY(); break;
	    case 'g': CSDeleteTabStop(); break;
	    case 'h': CS_h_Mode(); break;
	    case 'i': CS_i_Mode(); break;
	    case 'l': CS_l_Mode(); break;
	    case 'm': CSSetAttr(); break;
	    case 'n': CS_n_Mode(); break;
	    case 'r': CSSetScrollRegion(); break;
	    case 's': SaveCursor(); break;
	    case 't': CSSunSequence(); break;
	    case 'u': RestoreCursor(); break;
	  } /* of case Prv=0 */
	  break;
	/* private parameter = '>' */
	case '>': CSGT(b); break;
	/* private parameter = '?' */
	case '?': CSQuest(b); break;
      }
      break;
    /* one intermediate char */
    case 1:
      switch (IntChar[1]) {
	/* intermediate char = '!' */
	case '!': CSExc(b); break;
	/* intermediate char = '"' */
	case '"': CSDouble(b); break;
	/* intermediate char = '$' */
	case '$': CSDol(b); break;
      }
      break;
  } /* of case Icount */

  ParseMode = ModeFirst;
}

void ControlSequence(BYTE b)
{
  if ((b<=US) || (b>=0x80) && (b<=0x9F))
    ParseControl(b); /* ctrl char */
  else if ((b>=0x40) && (b<=0x7E))
    ParseCS(b); /* terminate char */
  else {
    if (PrinterMode)
      WriteToPrnFile(b,FALSE);

    if ((b>=0x20) && (b<=0x2F))
    { /* intermediate char */
      if (ICount<IntCharMax) ICount++;
      IntChar[ICount] = b;
    }
    else if ((b>=0x30) && (b<=0x39))
    {
      if (Param[NParam] < 0)
	Param[NParam] = 0; 
      if (Param[NParam]<1000)
       Param[NParam] = Param[NParam]*10 + b - 0x30;
    }
    else if (b==0x3B)
    {
      if (NParam < NParamMax)
      {
	NParam++;
	Param[NParam] = -1;
      }
    }
    else if ((b>=0x3C) && (b<=0x3F))
    { /* private char */
      if (FirstPrm) Prv = b;
    }
  }
  FirstPrm = FALSE;
}

void DeviceControl(BYTE b)
{
  if (ESCFlag && (b=='\\') || (b==ST))
  {
    ESCFlag = FALSE;
    ParseMode = SavedMode;
    return;
  }

  if (b==ESC)
  {
    ESCFlag = TRUE;
    return;
  }
  else ESCFlag = FALSE;

  if (b<US)
    ParseControl(b);
  else if ((b>=0x30) && (b<=0x39))
  {
    if (Param[NParam] < 0) Param[NParam] = 0; 
    if (Param[NParam]<1000)
      Param[NParam] = Param[NParam]*10 + b - 0x30;
  }
  else if (b==0x3B)
  {
    if (NParam < NParamMax)
    {
      NParam++;
      Param[NParam] = -1;
    }
  }
  else if ((b>=0x40) && (b<=0x7E))
  {
    if (b=='|')
    {
      ParseMode = ModeDCUserKey;
      if (Param[1] < 1) ClearUserKey();
      WaitKeyId = TRUE;
      NewKeyId = 0;
    }
    else ParseMode = ModeSOS;
  }
}

void DCUserKey(BYTE b)
{
  if (ESCFlag && (b=='\\') || (b==ST))
  {
    if (! WaitKeyId) DefineUserKey(NewKeyId,NewKeyStr,NewKeyLen);
    ESCFlag = FALSE;
    ParseMode = SavedMode;
    return;
  }

  if (b==ESC)
  {
    ESCFlag = TRUE;
    return;
  }
  else ESCFlag = FALSE;

  if (WaitKeyId)
  {
    if ((b>=0x30) && (b<=0x39))
    {
      if (NewKeyId<1000)
	NewKeyId = NewKeyId*10 + b - 0x30;
    }
    else if (b==0x2F)
    {
      WaitKeyId = FALSE;
      WaitHi = TRUE;
      NewKeyLen = 0;
    }
  }
  else {
    if (b==0x3B)
    {
      DefineUserKey(NewKeyId,NewKeyStr,NewKeyLen);
      WaitKeyId = TRUE;
      NewKeyId = 0;
    }
    else {
      if (NewKeyLen < FuncKeyStrMax)
      {
	if (WaitHi)
	{
	  NewKeyStr[NewKeyLen] = ConvHexChar(b) << 4;
	  WaitHi = FALSE;
	}
	else {
	  NewKeyStr[NewKeyLen] = NewKeyStr[NewKeyLen] +
				 ConvHexChar(b);
	  WaitHi = TRUE;
	  NewKeyLen++;
	}
      }
    }
  }
}

void IgnoreString(BYTE b)
{
  if (ESCFlag && (b=='\\') || (b==ST))
    ParseMode = SavedMode;

  if (b==ESC) ESCFlag = TRUE;
	 else ESCFlag = FALSE;
}

void XSequence(BYTE b)
{
  if (NParam==1)
  {
    if ((b>=0x30) && (b<=0x39))
    {
      if (Param[1]<1000)
	Param[1] = Param[1]*10 + b - 0x30;
    }
    else
      NParam = 2;
  }
  else {
    if (b<US) {
      if (Param[1]<=2)
      {
	ts.Title[NParam-2] = 0;
	ChangeTitle();
      }
      ParseMode = ModeFirst;
    }
    else {
      if ((Param[1]<=2) &&
	  (NParam-2<sizeof(ts.Title)-1))
      {
	ts.Title[NParam-2] = b;
	NParam++;
      }
    }
  }
}

void DLESeen(BYTE b)
{
  ParseMode = ModeFirst;
  if (((ts.FTFlag & FT_BPAUTO)!=0) && (b=='B'))
    BPStart(IdBPAuto); /* Auto B-Plus activation */
  ChangeEmu = -1;
}

void CANSeen(BYTE b)
{
  ParseMode = ModeFirst;
  if (((ts.FTFlag & FT_ZAUTO)!=0) && (b=='B'))
    ZMODEMStart(IdZAuto); /* Auto ZMODEM activation */
  ChangeEmu = -1;
}

BOOL CheckKanji(BYTE b)
{
  BOOL Check;

  if (ts.Language!=IdJapanese) return FALSE;

  ConvJIS = FALSE;

  if (ts.KanjiCode==IdSJIS)
  {
    if ((0x80<b) && (b<0xa0) || (0xdf<b) && (b<0xfd))
      return TRUE; // SJIS kanji
    if ((0xa1<=b) && (b<=0xdf))
      return FALSE; // SJIS katakana
  }

  if ((b>=0x21) && (b<=0x7e))
  {
    Check = (Gn[Glr[0]]==IdKanji);
    ConvJIS = Check;
  }
  else if ((b>=0xA1) && (b<=0xFE))
  {
    Check = (Gn[Glr[1]]==IdKanji);
    if (ts.KanjiCode==IdEUC)
      Check = TRUE;
    else if (ts.KanjiCode==IdJIS)
    {
      if (((ts.TermFlag & TF_FIXEDJIS)!=0) &&
	  (ts.JIS7Katakana==0))
	Check = FALSE; // 8-bit katakana
    }
    ConvJIS = Check;
  }
  else
    Check = FALSE;

  return Check;
}

BOOL ParseFirstJP(BYTE b)
// returns TRUE if b is processed
//  (actually allways returns TRUE)
{
  if (KanjiIn)
  {
    if ((! ConvJIS) && (0x3F<b) && (b<0xFD) ||
	ConvJIS && ( (0x20<b) && (b<0x7f) ||
		     (0xa0<b) && (b<0xff) ))
    {
      PutKanji(b);
      KanjiIn = FALSE;
      return TRUE;
    }
    else if ((ts.TermFlag & TF_CTRLINKANJI)==0)
      KanjiIn = FALSE;
  }
	
  if (SSflag)
  {
    if (Gn[GLtmp] == IdKanji)
    {
      Kanji = b << 8;
      KanjiIn = TRUE;
      SSflag = FALSE;
      return TRUE;
    }
    else if (Gn[GLtmp] == IdKatakana) b = b | 0x80;

    PutChar(b);
    SSflag = FALSE;
    return TRUE;
  }

  if ((! EUCsupIn) && (! EUCkanaIn) &&
      (! KanjiIn) && CheckKanji(b))
  {
    Kanji = b << 8;
    KanjiIn = TRUE;
    return TRUE;
  }

  if (b<=US)
    ParseControl(b);
  else if (b==0x20)
    PutChar(b);
  else if ((b>=0x21) && (b<=0x7E))
  {
    if (EUCsupIn)
    {
      EUCcount--;
      EUCsupIn = (EUCcount==0);
      return TRUE;
    }

    if ((Gn[Glr[0]] == IdKatakana) || EUCkanaIn)
    {
      b = b | 0x80;
      EUCkanaIn = FALSE;
    }
    PutChar(b);
  }
  else if (b==0x7f)
    return TRUE;
  else if ((b>=0x80) && (b<=0x8D))
    ParseControl(b);
  else if (b==0x8E)
  {
    if (ts.KanjiCode==IdEUC)
      EUCkanaIn = TRUE;
    else
      ParseControl(b);
  }
  else if (b==0x8F)
  {
    if (ts.KanjiCode==IdEUC)
    {
      EUCcount = 2;
      EUCsupIn = TRUE;
    } else
      ParseControl(b);
  }
  else if ((b>=0x90) && (b<=0x9F))
    ParseControl(b);
  else if (b==0xA0)
    PutChar(0x20);
  else if ((b>=0xA1) && (b<=0xFE))
  {
    if (EUCsupIn)
    {
      EUCcount--;
      EUCsupIn = (EUCcount==0);
      return TRUE;
    }

    if ((Gn[Glr[1]] != IdASCII) ||
	(ts.KanjiCode==IdEUC) && EUCkanaIn ||
	(ts.KanjiCode==IdSJIS) ||
	(ts.KanjiCode==IdJIS) &&
	(ts.JIS7Katakana==0) &&
	((ts.TermFlag & TF_FIXEDJIS)!=0))
      PutChar(b);  // katakana
    else {
      if (Gn[Glr[1]] == IdASCII)	  
	b = b & 0x7f;
      PutChar(b);
    }
    EUCkanaIn = FALSE;
  }
  else
    PutChar(b);

  return TRUE;
}

BOOL ParseFirstRus(BYTE b)
// returns if b is processed
{
  if (b>=128)
  {
    b = RussConv(ts.RussHost,ts.RussClient,b);
    PutChar(b);
    return TRUE;
  }
  return FALSE;
}

void ParseFirst(BYTE b)
{
  if ((ts.Language==IdJapanese) &&
    ParseFirstJP(b)) return;
  else if ((ts.Language==IdRussian) &&
    ParseFirstRus(b)) return;
	
  if (SSflag)
  {
    PutChar(b);
    SSflag = FALSE;
    return;
  }

  if (b<=US)
    ParseControl(b);
  else if ((b>=0x20) && (b<=0x7E))
    PutChar(b);
  else if ((b>=0x80) && (b<=0x9F))
    ParseControl(b);
  else if (b>=0xA0)
    PutChar(b);
}

int VTParse()
{
  BYTE b;
  int c;

  c = CommRead1Byte(&cv,&b);

  if (c==0) return 0;

  CaretOff();

  ChangeEmu = 0;

  /* Get Device Context */
  DispInitDC();

  LockBuffer();

  while ((c>0) && (ChangeEmu==0))
  {
    if (DebugFlag)
      PutDebugChar(b);
    else {
      switch (ParseMode) {
	case ModeFirst: ParseFirst(b); break;
	case ModeESC: EscapeSequence(b); break;
	case ModeDCS: DeviceControl(b); break;
	case ModeDCUserKey: DCUserKey(b); break;
	case ModeSOS: IgnoreString(b); break;
	case ModeCSI: ControlSequence(b); break;
	case ModeXS:  XSequence(b); break;
	case ModeDLE: DLESeen(b); break;
	case ModeCAN: CANSeen(b); break;
	default:
	  ParseMode = ModeFirst;
	  ParseFirst(b);
      }
    }

    if (ChangeEmu==0)
      c = CommRead1Byte(&cv,&b);
  }

  BuffUpdateScroll();

  BuffSetCaretWidth();
  UnlockBuffer();

  /* release device context */
  DispReleaseDC();

  CaretOn();

  if (ChangeEmu > 0) ParseMode = ModeFirst;
  return ChangeEmu;
}
