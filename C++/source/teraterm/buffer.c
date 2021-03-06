/* Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved. */

/* TERATERM.EXE, scroll buffer routines */

#include "teraterm.h"
#include "tttypes.h"
#include <string.h>

#include "ttwinman.h"
#include "teraprn.h"
#include "vtdisp.h"
#include "clipboar.h"
#include "telnet.h"
#include "ttplug.h" /* TTPLUG */

#include "buffer.h"

#define BuffXMax 300
#ifdef TERATERM32
#define BuffYMax 100000
#define BuffSizeMax 8000000
#else
#define BuffYMax 800
#define BuffSizeMax 65535
#endif

// status line
int StatusLine;	//0: none 1: shown 
/* top & bottom margin */
int CursorTop, CursorBottom;
BOOL Selected;
BOOL Wrap;

static WORD TabStops[256];
static int NTabStops;

static WORD BuffLock = 0;
static HANDLE HCodeBuff = 0;
static HANDLE HAttrBuff = 0;
static HANDLE HAttrBuff2 = 0;

static PCHAR CodeBuff;  /* Character code buffer */
static PCHAR AttrBuff;  /* Attribute buffer */
static PCHAR AttrBuff2; /* Color attr buffer */
static PCHAR CodeLine;
static PCHAR AttrLine;
static PCHAR AttrLine2;
static LONG LinePtr;
static LONG BufferSize;
static int NumOfLinesInBuff;
static int BuffStartAbs, BuffEndAbs;
static POINT SelectStart, SelectEnd, SelectEndOld;
static BOOL BoxSelect;
static POINT DblClkStart, DblClkEnd;

static int StrChangeStart, StrChangeCount;

LONG GetLinePtr(int Line)
{
  LONG Ptr;

  Ptr = (LONG)(BuffStartAbs + Line) *
	(LONG)(NumOfColumns);
  while (Ptr>=BufferSize)
    Ptr = Ptr - BufferSize;
  return Ptr;
}

LONG NextLinePtr(LONG Ptr)
{
  Ptr = Ptr + (LONG)NumOfColumns;
  if (Ptr >= BufferSize)
    Ptr = Ptr - BufferSize;
  return Ptr;
}

LONG PrevLinePtr(LONG Ptr)
{
  Ptr = Ptr - (LONG)NumOfColumns;
  if (Ptr < 0) Ptr = Ptr + BufferSize;
  return Ptr;
}

BOOL ChangeBuffer(int Nx, int Ny)
{
  HANDLE HCodeNew, HAttrNew, HAttr2New;
  LONG NewSize;
  int NxCopy, NyCopy, i;
  PCHAR CodeDest, AttrDest, AttrDest2;
  PCHAR Ptr;
  LONG SrcPtr, DestPtr;
  WORD LockOld;

  if (Nx > BuffXMax) Nx = BuffXMax;
  if (ts.ScrollBuffMax > BuffYMax)
    ts.ScrollBuffMax = BuffYMax;
  if (Ny > ts.ScrollBuffMax) Ny = ts.ScrollBuffMax;
 
  if ( (LONG)Nx * (LONG)Ny > BuffSizeMax )
    Ny = BuffSizeMax / Nx;

  NewSize = (LONG)Nx * (LONG)Ny;

  HCodeNew = GlobalAlloc(GMEM_MOVEABLE, NewSize);
  if ( HCodeNew==0 ) return FALSE;
  Ptr = GlobalLock(HCodeNew);
  if ( Ptr==NULL )
  {
    GlobalFree(HCodeNew);
    return FALSE;
  }
  CodeDest = Ptr;

  HAttrNew = GlobalAlloc(GMEM_MOVEABLE, NewSize);
  if ( HAttrNew==0 )
  {
    GlobalFree(HCodeNew);
    return FALSE;
  }
  Ptr = GlobalLock(HAttrNew);
  if ( Ptr==NULL )
  {
    GlobalFree(HCodeNew);
    GlobalFree(HAttrNew);
    return FALSE;
  }
  AttrDest = Ptr;

  HAttr2New = GlobalAlloc(GMEM_MOVEABLE, NewSize);
  if ( HAttr2New==0 )
  {
    GlobalFree(HCodeNew);
    GlobalFree(HAttrNew);
    return FALSE;
  }
  Ptr = GlobalLock(HAttr2New);
  if ( Ptr==NULL )
  {
    GlobalFree(HCodeNew);
    GlobalFree(HAttrNew);
    GlobalFree(HAttr2New);
    return FALSE;
  }
  AttrDest2 = Ptr;

  memset(&CodeDest[0], 0x20, NewSize);
  memset(&AttrDest[0], AttrDefault, NewSize);
  memset(&AttrDest2[0], AttrDefault2, NewSize);
  if ( HCodeBuff!=0 )
  {
    if ( NumOfColumns > Nx )
      NxCopy = Nx;
    else NxCopy = NumOfColumns;
    if ( BuffEnd > Ny )
      NyCopy = Ny;
    else NyCopy = BuffEnd;
    LockOld = BuffLock;
    LockBuffer();
    SrcPtr = GetLinePtr(BuffEnd-NyCopy);
    DestPtr = 0;
    for (i = 1 ; i <= NyCopy ; i++)
    {
      memcpy(&CodeDest[DestPtr],&CodeBuff[SrcPtr],NxCopy);
      memcpy(&AttrDest[DestPtr],&AttrBuff[SrcPtr],NxCopy);
      memcpy(&AttrDest2[DestPtr],&AttrBuff2[SrcPtr],NxCopy);
      SrcPtr = NextLinePtr(SrcPtr);
      DestPtr = DestPtr + (LONG)Nx;
    }
    FreeBuffer();
  }
  else {
    LockOld = 0;
    NyCopy = NumOfLines;
    Selected = FALSE;
  }

  if (Selected)
  {
    SelectStart.y =
      SelectStart.y - BuffEnd + NyCopy;
    SelectEnd.y =
      SelectEnd.y - BuffEnd + NyCopy;
    if (SelectStart.y < 0)
    {
      SelectStart.y = 0;
      SelectStart.x = 0;
    }
    if (SelectEnd.y<0)
    {
      SelectEnd.x = 0;
      SelectEnd.y = 0;
    }

    Selected = (SelectEnd.y > SelectStart.y) ||
		((SelectEnd.y=SelectStart.y) &&
		 (SelectEnd.x > SelectStart.x));
  }

  HCodeBuff = HCodeNew;
  HAttrBuff = HAttrNew;
  HAttrBuff2 = HAttr2New;
  BufferSize = NewSize;
  NumOfLinesInBuff = Ny;
  BuffStartAbs = 0;
  BuffEnd = NyCopy;

  if (BuffEnd==NumOfLinesInBuff)
    BuffEndAbs = 0;
  else
    BuffEndAbs = BuffEnd;

  PageStart = BuffEnd - NumOfLines;

  LinePtr = 0;
  if (LockOld>0)
  {
    CodeBuff = (PCHAR)GlobalLock(HCodeBuff);
    AttrBuff = (PCHAR)GlobalLock(HAttrBuff);
    AttrBuff2 = (PCHAR)GlobalLock(HAttrBuff2);
    CodeLine = CodeBuff;
    AttrLine = AttrBuff;
    AttrLine2 = AttrBuff2;
  }
  else {
    GlobalUnlock(HCodeNew);
    GlobalUnlock(HAttrNew);
  }
  BuffLock = LockOld;

  return TRUE;
}

void InitBuffer()
{
  int Ny;

  /* setup terminal */
  NumOfColumns = ts.TerminalWidth;
  NumOfLines = ts.TerminalHeight;

  /* setup window */
  if (ts.EnableScrollBuff>0)
  {
    if (ts.ScrollBuffSize < NumOfLines)
      ts.ScrollBuffSize = NumOfLines;
    Ny = ts.ScrollBuffSize;
  }
  else
    Ny = NumOfLines;

  if (! ChangeBuffer(NumOfColumns,Ny))
    PostQuitMessage(0);

  if (ts.EnableScrollBuff>0)
    ts.ScrollBuffSize = NumOfLinesInBuff;

  StatusLine = 0;
}

void NewLine(int Line)
{
  LinePtr = GetLinePtr(Line);
  CodeLine = &CodeBuff[LinePtr];
  AttrLine = &AttrBuff[LinePtr];
  AttrLine2 = &AttrBuff2[LinePtr];
}

void LockBuffer()
{
  BuffLock++;
  if (BuffLock>1) return;
  CodeBuff = (PCHAR)GlobalLock(HCodeBuff);
  AttrBuff = (PCHAR)GlobalLock(HAttrBuff);
  AttrBuff2 = (PCHAR)GlobalLock(HAttrBuff2);
  NewLine(PageStart+CursorY);
}

void UnlockBuffer()
{
  if (BuffLock==0) return;
  BuffLock--;
  if (BuffLock>0) return;
  if (HCodeBuff!=NULL)
    GlobalUnlock(HCodeBuff);
  if (HAttrBuff!=NULL)
    GlobalUnlock(HAttrBuff);
  if (HAttrBuff2!=NULL)
    GlobalUnlock(HAttrBuff2);
}

void FreeBuffer()
{
  BuffLock = 1;
  UnlockBuffer();
  if (HCodeBuff!=NULL)
  {
    GlobalFree(HCodeBuff);
    HCodeBuff = NULL;
  }
  if (HAttrBuff!=NULL)
  {
    GlobalFree(HAttrBuff);
    HAttrBuff = NULL;
  }
  if (HAttrBuff2!=NULL)
  {
    GlobalFree(HAttrBuff2);
    HAttrBuff2 = NULL;
  }
}

void BuffReset()
// Reset buffer status. don't update real display
//   called by ResetTerminal()
{
  int i;

  /* Cursor */
  NewLine(PageStart);
  WinOrgX = 0;
  WinOrgY = 0;
  NewOrgX = 0;
  NewOrgY = 0;

  /* Top/bottom margin */
  CursorTop = 0;
  CursorBottom = NumOfLines-1;

  /* Tab stops */
  NTabStops = (NumOfColumns-1) >> 3;
  for (i=1 ; i<=NTabStops ; i++)
    TabStops[i-1] = i*8;

  /* Initialize text selection region */
  SelectStart.x = 0;
  SelectStart.y = 0;
  SelectEnd = SelectStart;
  SelectEndOld = SelectStart;
  Selected = FALSE;

  StrChangeCount = 0;
  Wrap = FALSE;
  StatusLine = 0;
}

void BuffScroll(int Count, int Bottom)
{
  int i, n;
  LONG SrcPtr, DestPtr;
  int BuffEndOld;

  if (Count>NumOfLinesInBuff)
    Count = NumOfLinesInBuff;

  DestPtr = GetLinePtr(PageStart+NumOfLines-1+Count);
  n = Count;
  if (Bottom<NumOfLines-1)
  {
    SrcPtr = GetLinePtr(PageStart+NumOfLines-1);
    for (i=NumOfLines-1; i>=Bottom+1; i--)
    {
      memcpy(&(CodeBuff[DestPtr]),&(CodeBuff[SrcPtr]),NumOfColumns);
      memcpy(&(AttrBuff[DestPtr]),&(AttrBuff[SrcPtr]),NumOfColumns);
      memcpy(&(AttrBuff2[DestPtr]),&(AttrBuff2[SrcPtr]),NumOfColumns);
      memset(&(CodeBuff[SrcPtr]),0x20,NumOfColumns);
      memset(&(AttrBuff[SrcPtr]),AttrDefault,NumOfColumns);
      memset(&(AttrBuff2[SrcPtr]),AttrDefault2,NumOfColumns);
      SrcPtr = PrevLinePtr(SrcPtr);
      DestPtr = PrevLinePtr(DestPtr);
      n--;
    }
  }
  for (i = 1 ; i <= n ; i++)
  {
    memset(&CodeBuff[DestPtr],0x20,NumOfColumns);
    memset(&AttrBuff[DestPtr],AttrDefault,NumOfColumns);
    memset(&AttrBuff2[DestPtr],AttrDefault2,NumOfColumns);
    DestPtr = PrevLinePtr(DestPtr);
  }

  BuffEndAbs = BuffEndAbs + Count;
  if (BuffEndAbs >= NumOfLinesInBuff)
    BuffEndAbs = BuffEndAbs - NumOfLinesInBuff;
  BuffEndOld = BuffEnd;
  BuffEnd = BuffEnd + Count;
  if (BuffEnd >= NumOfLinesInBuff)
  {
    BuffEnd = NumOfLinesInBuff;
    BuffStartAbs = BuffEndAbs;
  }
  PageStart = BuffEnd-NumOfLines;

  if (Selected)
  {
    SelectStart.y = SelectStart.y - Count + BuffEnd - BuffEndOld;
    SelectEnd.y = SelectEnd.y - Count + BuffEnd - BuffEndOld;
    if ( SelectStart.y<0 )
    {
      SelectStart.x = 0;
      SelectStart.y = 0;
    }
    if ( SelectEnd.y<0 )
    {
      SelectEnd.x = 0;
      SelectEnd.y = 0;
    }
    Selected =
      (SelectEnd.y > SelectStart.y) ||
       ((SelectEnd.y==SelectStart.y) &&
	(SelectEnd.x > SelectStart.x));
  }

  NewLine(PageStart+CursorY);
}

void NextLine()
{
  LinePtr = NextLinePtr(LinePtr);
  CodeLine = &CodeBuff[LinePtr];
  AttrLine = &AttrBuff[LinePtr];
  AttrLine2 = &AttrBuff2[LinePtr];
}

void PrevLine()
{
  LinePtr = PrevLinePtr(LinePtr);
  CodeLine = &CodeBuff[LinePtr];
  AttrLine = &AttrBuff[LinePtr];
  AttrLine2 = &AttrBuff2[LinePtr];
}

void EraseKanji(int LR)
{
// If cursor is on left/right half of a Kanji, erase it.
//   LR: left(0)/right(1) flag

  if ((CursorX-LR>=0) &&
      ((AttrLine[CursorX-LR] & AttrKanji) != 0))
  {
    CodeLine[CursorX-LR] = 0x20;
    AttrLine[CursorX-LR] = AttrDefault;
    AttrLine2[CursorX-LR] = AttrDefault2;
    if (CursorX-LR+1 < NumOfColumns)
    {
      CodeLine[CursorX-LR+1] = 0x20;
      AttrLine[CursorX-LR+1] = AttrDefault;
      AttrLine2[CursorX-LR+1] = AttrDefault2;
    }
  }
}

void BuffInsertSpace(int Count)
// Insert space characters at the current position
//   Count: Number of characters to be inserted
{
  NewLine(PageStart+CursorY);

  if (ts.Language==IdJapanese)
    EraseKanji(1); /* if cursor is on right half of a kanji, erase the kanji */

  if (Count > NumOfColumns - CursorX)
    Count = NumOfColumns - CursorX;

  memmove(&(CodeLine[CursorX+Count]),&(CodeLine[CursorX]),
	  NumOfColumns-Count-CursorX);
  memmove(&(AttrLine[CursorX+Count]),&(AttrLine[CursorX]),
	  NumOfColumns-Count-CursorX);
  memmove(&(AttrLine2[CursorX+Count]),&(AttrLine2[CursorX]),
	  NumOfColumns-Count-CursorX);
  memset(&(CodeLine[CursorX]),0x20,Count);
  memset(&(AttrLine[CursorX]),AttrDefault,Count);
  memset(&(AttrLine2[CursorX]),AttrDefault2,Count);
  /* last char in current line is kanji first? */
  if ((AttrLine[NumOfColumns-1] & AttrKanji) != 0)
  {
    /* then delete it */
    CodeLine[NumOfColumns-1] = 0x20;
    AttrLine[NumOfColumns-1] = AttrDefault;
    AttrLine2[NumOfColumns-1] = AttrDefault2;
  }
  BuffUpdateRect(CursorX,CursorY,NumOfColumns-1,CursorY);
}

void BuffEraseCurToEnd()
// Erase characters from cursor to the end of screen
{
  LONG TmpPtr;
  int offset;
  int i, YEnd;

  NewLine(PageStart+CursorY);
  if (ts.Language==IdJapanese)
    EraseKanji(1); /* if cursor is on right half of a kanji, erase the kanji */
  offset = CursorX;
  TmpPtr = GetLinePtr(PageStart+CursorY);
  YEnd = NumOfLines-1;
  if ((StatusLine>0) &&
      (CursorY<NumOfLines-1))
    YEnd--;
  for (i = CursorY ; i <= YEnd ; i++)
  {
    memset(&(CodeBuff[TmpPtr+offset]),0x20,NumOfColumns-offset);
    memset(&(AttrBuff[TmpPtr+offset]),AttrDefault,NumOfColumns-offset);
    memset(&(AttrBuff2[TmpPtr+offset]),AttrDefault2,NumOfColumns-offset);
    offset = 0;
    TmpPtr = NextLinePtr(TmpPtr);
  }
  /* update window */
  DispEraseCurToEnd(YEnd);
}

void BuffEraseHomeToCur()
// Erase characters from home to cursor
{
  LONG TmpPtr;
  int offset;
  int i, YHome;

  NewLine(PageStart+CursorY);
  if (ts.Language==IdJapanese)
    EraseKanji(0); /* if cursor is on left half of a kanji, erase the kanji */
  offset = NumOfColumns;
  if ((StatusLine>0) && (CursorY==NumOfLines-1))
    YHome = CursorY;
  else
    YHome = 0;
  TmpPtr = GetLinePtr(PageStart+YHome);
  for (i = YHome ; i <= CursorY ; i++)
  {
    if (i==CursorY) offset = CursorX+1;
    memset(&(CodeBuff[TmpPtr]),0x20,offset);
    memset(&(AttrBuff[TmpPtr]),AttrDefault,offset);
    memset(&(AttrBuff2[TmpPtr]),AttrDefault2,offset);
    TmpPtr = NextLinePtr(TmpPtr);
  }

  /* update window */
  DispEraseHomeToCur(YHome);
}

void BuffInsertLines(int Count, int YEnd)
// Insert lines at current position
//   Count: number of lines to be inserted
//   YEnd: bottom line number of scroll region (screen coordinate)
{
  int i;
  LONG SrcPtr, DestPtr;

  BuffUpdateScroll();

  SrcPtr = GetLinePtr(PageStart+YEnd-Count);
  DestPtr = GetLinePtr(PageStart+YEnd);
  for (i= YEnd-Count ; i>=CursorY ; i--)
  {
    memcpy(&(CodeBuff[DestPtr]),&(CodeBuff[SrcPtr]),NumOfColumns);
    memcpy(&(AttrBuff[DestPtr]),&(AttrBuff[SrcPtr]),NumOfColumns);
    memcpy(&(AttrBuff2[DestPtr]),&(AttrBuff2[SrcPtr]),NumOfColumns);
    SrcPtr = PrevLinePtr(SrcPtr);
    DestPtr = PrevLinePtr(DestPtr);
  }
  for (i = 1 ; i <= Count ; i++)
  {
    memset(&(CodeBuff[DestPtr]),0x20,NumOfColumns);
    memset(&(AttrBuff[DestPtr]),AttrDefault,NumOfColumns);
    memset(&(AttrBuff2[DestPtr]),AttrDefault2,NumOfColumns);
    DestPtr = PrevLinePtr(DestPtr);
  }

  if (! DispInsertLines(Count,YEnd))
    BuffUpdateRect(WinOrgX,CursorY,WinOrgX+WinWidth-1,YEnd);
}

void BuffEraseCharsInLine(int XStart, int Count)
// erase characters in the current line
//  XStart: start position of erasing
//  Count: number of characters to be erased
{
  if (ts.Language==IdJapanese)
    EraseKanji(1); /* if cursor is on right half of a kanji, erase the kanji */

  NewLine(PageStart+CursorY);
  memset(&(CodeLine[XStart]),0x20,Count);
  memset(&(AttrLine[XStart]),AttrDefault,Count);
  memset(&(AttrLine2[XStart]),AttrDefault2,Count);

  DispEraseCharsInLine(XStart, Count);
}

void BuffDeleteLines(int Count, int YEnd)
// Delete lines from current line
//   Count: number of lines to be deleted
//   YEnd: bottom line number of scroll region (screen coordinate)
{
  int i;
  LONG SrcPtr, DestPtr;

  BuffUpdateScroll();

  SrcPtr = GetLinePtr(PageStart+CursorY+Count);
  DestPtr = GetLinePtr(PageStart+CursorY);
  for (i=CursorY ; i<= YEnd-Count ; i++)
  {
    memcpy(&(CodeBuff[DestPtr]),&(CodeBuff[SrcPtr]),NumOfColumns);
    memcpy(&(AttrBuff[DestPtr]),&(AttrBuff[SrcPtr]),NumOfColumns);
    memcpy(&(AttrBuff2[DestPtr]),&(AttrBuff2[SrcPtr]),NumOfColumns);
    SrcPtr = NextLinePtr(SrcPtr);
    DestPtr = NextLinePtr(DestPtr);
  }
  for (i = YEnd+1-Count ; i<=YEnd ; i++)
  {
    memset(&(CodeBuff[DestPtr]),0x20,NumOfColumns);
    memset(&(AttrBuff[DestPtr]),AttrDefault,NumOfColumns);
    memset(&(AttrBuff2[DestPtr]),AttrDefault2,NumOfColumns);
    DestPtr = NextLinePtr(DestPtr);
  }

  if (! DispDeleteLines(Count,YEnd))
    BuffUpdateRect(WinOrgX,CursorY,WinOrgX+WinWidth-1,YEnd);
}

void BuffDeleteChars(int Count)
// Delete characters in current line from cursor
//   Count: number of characters to be deleted
{
  NewLine(PageStart+CursorY);

  if (ts.Language==IdJapanese)
  {
    EraseKanji(0); /* if cursor is on left harf of a kanji, erase the kanji */
    EraseKanji(1); /* if cursor on right half... */
  }

  if (Count > NumOfColumns-CursorX) Count = NumOfColumns-CursorX;
  memmove(&(CodeLine[CursorX]),&(CodeLine[CursorX+Count]),
	  NumOfColumns-Count-CursorX);
  memmove(&(AttrLine[CursorX]),&(AttrLine[CursorX+Count]),
	  NumOfColumns-Count-CursorX);
  memmove(&(AttrLine2[CursorX]),&(AttrLine2[CursorX+Count]),
	  NumOfColumns-Count-CursorX);
  memset(&(CodeLine[NumOfColumns-Count]),0x20,Count);
  memset(&(AttrLine[NumOfColumns-Count]),AttrDefault,Count);
  memset(&(AttrLine2[NumOfColumns-Count]),AttrDefault2,Count);

  BuffUpdateRect(CursorX,CursorY,WinOrgX+WinWidth-1,CursorY);
}

void BuffEraseChars(int Count)
// Erase characters in current line from cursor
//   Count: number of characters to be deleted
{
  NewLine(PageStart+CursorY);

  if (ts.Language==IdJapanese)
  {
    EraseKanji(0); /* if cursor is on left harf of a kanji, erase the kanji */
    EraseKanji(1); /* if cursor on right half... */
  }

  if (Count > NumOfColumns-CursorX) Count = NumOfColumns-CursorX;
  memset(&(CodeLine[CursorX]),0x20,Count);
  memset(&(AttrLine[CursorX]),AttrDefault,Count);
  memset(&(AttrLine2[CursorX]),AttrDefault2,Count);

  /* update window */
  DispEraseCharsInLine(CursorX,Count);
}

void BuffFillWithE()
// Fill screen with 'E' characters
{
  LONG TmpPtr;
  int i;

  TmpPtr = GetLinePtr(PageStart);
  for (i = 0 ; i <= NumOfLines-1-StatusLine ; i++)
  {
    memset(&(CodeBuff[TmpPtr]),'E',NumOfColumns);
    memset(&(AttrBuff[TmpPtr]),AttrDefault,NumOfColumns);
    memset(&(AttrBuff2[TmpPtr]),AttrDefault2,NumOfColumns);
    TmpPtr = NextLinePtr(TmpPtr);
  }
  BuffUpdateRect(WinOrgX,WinOrgY,WinOrgX+WinWidth-1,WinOrgY+WinHeight-1);
}

void BuffDrawLine(BYTE Attr, BYTE Attr2, int Direction, int C)
{ // IO-8256 terminal
  LONG Ptr;
  int i, X, Y;

  if (C==0) return;
  Attr = Attr | AttrSpecial;

  switch (Direction) {
    case 3:
    case 4:
      if (Direction==3)
      {
	if (CursorY==0) return;
	Y = CursorY-1;
      }
      else {
	if (CursorY==NumOfLines-1-StatusLine) return;
	Y = CursorY+1;
      }
      if (CursorX+C > NumOfColumns)
	C = NumOfColumns-CursorX;
      Ptr = GetLinePtr(PageStart+Y);
      memset(&(CodeBuff[Ptr+CursorX]),'q',C);
      memset(&(AttrBuff[Ptr+CursorX]),Attr,C);
      memset(&(AttrBuff2[Ptr+CursorX]),Attr2,C);
      BuffUpdateRect(CursorX,Y,CursorX+C-1,Y);
      break;
    case 5:
    case 6:
      if (Direction==5)
      {
	if (CursorX==0) return;
	X = CursorX - 1;
      }
      else {
	if (CursorX==NumOfColumns-1)
	  X = CursorX-1;
	else
	  X = CursorX+1;
      }
      Ptr = GetLinePtr(PageStart+CursorY);
      if (CursorY+C > NumOfLines-StatusLine)
	C = NumOfLines-StatusLine-CursorY;
      for (i=1; i<=C; i++)
      {
	CodeBuff[Ptr+X] = 'x';
	AttrBuff[Ptr+X] = Attr;
	AttrBuff2[Ptr+X] = Attr2;
	Ptr = NextLinePtr(Ptr);
      }
      BuffUpdateRect(X,CursorY,X,CursorY+C-1);
      break;
  }
}

void BuffEraseBox
  (int XStart, int YStart, int XEnd, int YEnd)
// IO-8256 terminal
{
  int C, i;
  LONG Ptr;

  if (XEnd>NumOfColumns-1)
    XEnd = NumOfColumns-1;
  if (YEnd>NumOfLines-1-StatusLine)
    YEnd = NumOfLines-1-StatusLine;
  if (XStart>XEnd) return;
  if (YStart>YEnd) return;
  C = XEnd-XStart+1;
  Ptr = GetLinePtr(PageStart+YStart);
  for (i=YStart; i<=YEnd; i++)
  {
    if ((XStart>0) &&
	((AttrBuff[Ptr+XStart-1] & AttrKanji) != 0))
    {
      CodeBuff[Ptr+XStart-1] = 0x20;
      AttrBuff[Ptr+XStart-1] = AttrDefault;
      AttrBuff2[Ptr+XStart-1] = AttrDefault2;
    }
    if ((XStart+C<NumOfColumns) &&
	((AttrBuff[Ptr+XStart+C-1] & AttrKanji) != 0))
    {
      CodeBuff[Ptr+XStart+C] = 0x20;
      AttrBuff[Ptr+XStart+C] = AttrDefault;
      AttrBuff2[Ptr+XStart+C] = AttrDefault2;
    }
    memset(&(CodeBuff[Ptr+XStart]),0x20,C);
    memset(&(AttrBuff[Ptr+XStart]),AttrDefault,C);
    memset(&(AttrBuff2[Ptr+XStart]),AttrDefault2,C);
    Ptr = NextLinePtr(Ptr);
  }
  BuffUpdateRect(XStart,YStart,XEnd,YEnd);
}

int LeftHalfOfDBCS(LONG Line, int CharPtr)
// If CharPtr is on the right half of a DBCS character,
// return pointer to the left half
//   Line: points to a line in CodeBuff
//   CharPtr: points to a char
//   return: points to the left half of the DBCS
{
  if ((CharPtr>0) &&
      ((AttrBuff[Line+CharPtr-1] & AttrKanji) != 0))
    CharPtr--;
  return CharPtr;
}

int MoveCharPtr(LONG Line, int *x, int dx)
// move character pointer x by dx character unit
//   in the line specified by Line
//   Line: points to a line in CodeBuff
//   x: points to a character in the line
//   dx: moving distance in character unit (-: left, +: right)
//		One DBCS character is counted as one character.
//      The pointer stops at the beginning or the end of line.
// Output
//   x: new pointer. x points to a SBCS character or
//      the left half of a DBCS character.
//   return: actual moving distance in character unit
{
  int i;

  *x = LeftHalfOfDBCS(Line,*x);
  i = 0;
  while (dx!=0)
  {
    if (dx>0) // move right
    {
      if ((AttrBuff[Line+*x] & AttrKanji) != 0)
      {
	if (*x<NumOfColumns-2)
	{
	  i++;
	  *x = *x + 2;
	}
      }
      else if (*x<NumOfColumns-1)
      {
	i++;
	(*x)++;
      }
      dx--;
    }
    else { // move left
      if (*x>0)
      {
	i--;
	(*x)--;
      }
      *x = LeftHalfOfDBCS(Line,*x);
      dx++;
    }
  }
  return i;
}

void BuffCBCopy(BOOL Table)
// copy selected text to clipboard
{
  LONG MemSize;
  PCHAR CBPtr;
  LONG TmpPtr;
  int i, j, k, IStart, IEnd;
  BOOL Sp, FirstChar;
  BYTE b;

  if (TalkStatus==IdTalkCB) return;
  if (! Selected) return;

// --- open clipboard and get CB memory
  if (BoxSelect)
    MemSize = (SelectEnd.x-SelectStart.x+3)*
	      (SelectEnd.y-SelectStart.y+1) + 1;
  else 
    MemSize = (SelectEnd.y-SelectStart.y)*
	      (NumOfColumns+2) +
	      SelectEnd.x - SelectStart.x + 1;
  CBPtr = CBOpen(MemSize);
  if (CBPtr==NULL) return;

// --- copy selected text to CB memory
  LockBuffer();

  CBPtr[0] = 0;
  TmpPtr = GetLinePtr(SelectStart.y);
  k = 0;
  for (j = SelectStart.y ; j<=SelectEnd.y ; j++)
  {
    if (BoxSelect)
    {
      IStart = SelectStart.x;
      IEnd = SelectEnd.x-1;
    }
    else {
      IStart = 0;
      IEnd = NumOfColumns-1;
      if (j==SelectStart.y) IStart = SelectStart.x;
      if (j==SelectEnd.y) IEnd = SelectEnd.x-1;
    }
    i = LeftHalfOfDBCS(TmpPtr,IStart);
    if (i!=IStart)
    {
      if (j==SelectStart.y)
	IStart = i;
      else
	IStart = i + 2;
    }

    // exclude right-side space characters
    IEnd = LeftHalfOfDBCS(TmpPtr,IEnd);
    while ((IEnd>0) && (CodeBuff[TmpPtr+IEnd]==0x20))
      MoveCharPtr(TmpPtr,&IEnd,-1);
    if ((IEnd==0) && (CodeBuff[TmpPtr]==0x20))
      IEnd = -1;
    else if ((AttrBuff[TmpPtr+IEnd] & AttrKanji) != 0) /* DBCS first byte? */
      IEnd++;

    Sp = FALSE;
    FirstChar = TRUE;
    i = IStart;
    while (i <= IEnd)
    {
      b = CodeBuff[TmpPtr+i];
      i++;
      if (! Sp)
      {
	if ((Table) && (b<=0x20))
	{
	  Sp = TRUE;
	  b = 0x09;
	}
	if ((b!=0x09) || (! FirstChar))
	{
	  FirstChar = FALSE;
	  CBPtr[k] = b;
	  k++;
	}
      }
      else {
	if (b>0x20)
	{
	  Sp = FALSE;
	  FirstChar = FALSE;
	  CBPtr[k] = b;
	  k++;
	}
      }
    }

    if (j < SelectEnd.y)
    {
      CBPtr[k] = 0x0d;
      k++;
      CBPtr[k] = 0x0a;
      k++;
    }

    TmpPtr = NextLinePtr(TmpPtr);
  }
  CBPtr[k] = 0;

  UnlockBuffer();

// --- send CB memory to clipboard
  CBClose();
  return;
}

void BuffPrint(BOOL ScrollRegion)
// Print screen or selected text
{
  int Id;
  POINT PrintStart, PrintEnd;
  BYTE TempAttr, TempAttr2, CurAttr, CurAttr2;
  int i, j, count;
  int IStart, IEnd;
  LONG TmpPtr;

  if (ScrollRegion)
    Id = VTPrintInit(IdPrnScrollRegion);
  else if (Selected)
    Id = VTPrintInit(IdPrnScreen | IdPrnSelectedText);
  else
    Id = VTPrintInit(IdPrnScreen);
  if (Id==IdPrnCancel) return;

  /* set print region */
  if (Id==IdPrnSelectedText)
  {
    /* print selected region */
    PrintStart = SelectStart;
    PrintEnd = SelectEnd;
  }
  else if (Id==IdPrnScrollRegion)
  {
    /* print scroll region */
    PrintStart.x = 0;
    PrintStart.y = PageStart + CursorTop;
    PrintEnd.x = NumOfColumns;
    PrintEnd.y = PageStart + CursorBottom;
  }
  else {
    /* print current screen */
    PrintStart.x = 0;
    PrintStart.y = PageStart;
    PrintEnd.x = NumOfColumns;
    PrintEnd.y = PageStart + NumOfLines - 1;
  }
  if (PrintEnd.y > BuffEnd-1)
    PrintEnd.y = BuffEnd-1;

  TempAttr = AttrDefault;
  TempAttr2 = AttrDefault2;

  LockBuffer();

  TmpPtr = GetLinePtr(PrintStart.y);
  for (j = PrintStart.y ; j <= PrintEnd.y ; j++)
  {
    if (j==PrintStart.y)
      IStart = PrintStart.x;
    else IStart = 0;
    if (j == PrintEnd.y)
      IEnd = PrintEnd.x - 1;
    else
      IEnd = NumOfColumns - 1;

    while ((IEnd>=IStart) &&
	   (CodeBuff[TmpPtr+IEnd]==0x20) &&
	   (AttrBuff[TmpPtr+IEnd]==AttrDefault) &&
	   (AttrBuff2[TmpPtr+IEnd]==AttrDefault2))
 	IEnd--;

    i = IStart;
    while (i <= IEnd) {
      CurAttr = AttrBuff[TmpPtr+i] & ~ AttrKanji;
      CurAttr2 = AttrBuff2[TmpPtr+i];

      count = 1;
      while ((i+count <= IEnd) &&
	     (CurAttr == (AttrBuff[TmpPtr+i+count] & ~ AttrKanji)) &&
	     (CurAttr2 == AttrBuff2[TmpPtr+i+count]) ||
	     (i+count<NumOfColumns) &&
	     ((AttrBuff[TmpPtr+i+count-1] & AttrKanji) != 0))
	count++;

      if ((CurAttr != TempAttr) ||
	  (CurAttr2 != TempAttr2))
      {
	PrnSetAttr(CurAttr,CurAttr2);
	TempAttr = CurAttr;
	TempAttr2 = CurAttr2;
      }
      PrnOutText(&(CodeBuff[TmpPtr+i]),count);	
      i = i+count;
    }
    PrnNewLine();
    TmpPtr = NextLinePtr(TmpPtr);
  }

  UnlockBuffer();
  VTPrintEnd();
}

void BuffDumpCurrentLine(BYTE TERM)
// Dumps current line to the file (for path through printing)
//   HFile: file handle
//   TERM: terminator character
//	= LF or VT or FF
{
  int i, j;

  i = NumOfColumns;
  while ((i>0) && (CodeLine[i-1]==0x20))
    i--;
  for (j=0; j<i; j++)
    WriteToPrnFile(CodeLine[j],FALSE);
  WriteToPrnFile(0,TRUE);
  if ((TERM>=LF) && (TERM<=FF))
  {
    WriteToPrnFile(0x0d,FALSE);
    WriteToPrnFile(TERM,TRUE);
  }
}

void BuffPutChar(BYTE b, BYTE Attr, BYTE Attr2, BOOL Insert)
// Put a character in the buffer at the current position
//   b: character
//   Attr: attribute #1
//   Attr2: attribute #2
//   Insert: Insert flag
{
  int XStart;

  if (ts.Language==IdJapanese)
  {
    EraseKanji(1); /* if cursor is on right half of a kanji, erase the kanji */
    if (! Insert) EraseKanji(0); /* if cursor on left half... */
  }

  if (Insert)
  {
    memmove(&CodeLine[CursorX+1],&CodeLine[CursorX],NumOfColumns-1-CursorX);
    memmove(&AttrLine[CursorX+1],&AttrLine[CursorX],NumOfColumns-1-CursorX);
    memmove(&AttrLine2[CursorX+1],&AttrLine2[CursorX],NumOfColumns-1-CursorX);
    CodeLine[CursorX] = b;
    AttrLine[CursorX] = Attr;
    AttrLine2[CursorX] = Attr2;
    /* last char in current line is kanji first? */
    if ((AttrLine[NumOfColumns-1] & AttrKanji) != 0)
    {
      /* then delete it */
      CodeLine[NumOfColumns-1] = 0x20;
      AttrLine[NumOfColumns-1] = AttrDefault;
      AttrLine2[NumOfColumns-1] = AttrDefault2;
    }

    if (StrChangeCount==0) XStart = CursorX;
		      else XStart = StrChangeStart;
    StrChangeCount = 0;
    BuffUpdateRect(XStart,CursorY,NumOfColumns-1,CursorY);
  }
  else {
    CodeLine[CursorX] = b;
    AttrLine[CursorX] = Attr;
    AttrLine2[CursorX] = Attr2;

    if (StrChangeCount==0)
      StrChangeStart = CursorX;
    StrChangeCount++;
  }
}

void BuffPutKanji(WORD w, BYTE Attr, BYTE Attr2, BOOL Insert)
// Put a kanji character in the buffer at the current position
//   b: character
//   Attr: attribute #1
//   Attr2: attribute #2
//   Insert: Insert flag
{
  int XStart;

  EraseKanji(1); /* if cursor is on right half of a kanji, erase the kanji */

  if (Insert)
  {
    memmove(&CodeLine[CursorX+2],&CodeLine[CursorX],NumOfColumns-2-CursorX);
    memmove(&AttrLine[CursorX+2],&AttrLine[CursorX],NumOfColumns-2-CursorX);
    memmove(&AttrLine2[CursorX+2],&AttrLine2[CursorX],NumOfColumns-2-CursorX);

    CodeLine[CursorX] = HIBYTE(w);
    AttrLine[CursorX] = Attr | AttrKanji; /* DBCS first byte */
    AttrLine2[CursorX] = Attr2;
    if (CursorX < NumOfColumns-1)
    {
      CodeLine[CursorX+1] = LOBYTE(w);
      AttrLine[CursorX+1] = Attr;
      AttrLine2[CursorX+1] = Attr2;
    }

    /* last char in current line is kanji first? */
    if ((AttrLine[NumOfColumns-1] & AttrKanji) != 0)
    {
      /* then delete it */
      CodeLine[NumOfColumns-1] = 0x20;
      AttrLine[NumOfColumns-1] = AttrDefault;
      AttrLine2[NumOfColumns-1] = AttrDefault2;
    }

    if (StrChangeCount==0) XStart = CursorX;
		      else XStart = StrChangeStart;
    StrChangeCount = 0;
    BuffUpdateRect(XStart,CursorY,NumOfColumns-1,CursorY);
  }
  else {
    CodeLine[CursorX] = HIBYTE(w);
    AttrLine[CursorX] = Attr | AttrKanji; /* DBCS first byte */
    AttrLine2[CursorX] = Attr2;
    if (CursorX < NumOfColumns-1)
    {
      CodeLine[CursorX+1] = LOBYTE(w);
      AttrLine[CursorX+1] = Attr;
      AttrLine2[CursorX+1] = Attr2;
    }

    if (StrChangeCount==0)
      StrChangeStart = CursorX;
    StrChangeCount = StrChangeCount + 2;
  }
}

BOOL CheckSelect(int x, int y)
//  subroutine called by BuffUpdateRect
{
  LONG L, L1, L2;

  if (BoxSelect)
  {
    return (Selected &&
      ((SelectStart.x<=x) && (x<SelectEnd.x) ||
       (SelectEnd.x<=x) && (x<SelectStart.x)) &&
      ((SelectStart.y<=y) && (y<=SelectEnd.y) ||
       (SelectEnd.y<=y) && (y<=SelectStart.y)));
  }
  else {
    L = MAKELONG(x,y);
    L1 = MAKELONG(SelectStart.x,SelectStart.y);
    L2 = MAKELONG(SelectEnd.x,SelectEnd.y);

    return (Selected &&
      ((L1<=L) && (L<L2) || (L2<=L) && (L<L1)));
  }
}

void BuffUpdateRect
  (int XStart, int YStart, int XEnd, int YEnd)
// Display text in a rectangular region in the screen
//   XStart: x position of the upper-left corner (screen cordinate)
//   YStart: y position
//   XEnd: x position of the lower-right corner (last character)
//   YEnd: y position
{
  int i, j, count;
  int IStart, IEnd;
  int X, Y;
  LONG TmpPtr;
  BYTE CurAttr, TempAttr;
  BYTE CurAttr2, TempAttr2;
  BOOL CurSel, TempSel, Caret;

  if (XStart >= WinOrgX+WinWidth) return;
  if (YStart >= WinOrgY+WinHeight) return;
  if (XEnd < WinOrgX) return;
  if (YEnd < WinOrgY) return;

  if (XStart < WinOrgX) XStart = WinOrgX;
  if (YStart < WinOrgY) YStart = WinOrgY;
  if (XEnd >= WinOrgX+WinWidth) XEnd = WinOrgX+WinWidth-1;
  if (YEnd >= WinOrgY+WinHeight) YEnd = WinOrgY+WinHeight-1;

  TempAttr = AttrDefault;
  TempAttr2 = AttrDefault2;
  TempSel = FALSE;

  Caret = IsCaretOn();
  if (Caret) CaretOff();

  DispSetupDC(TempAttr,TempAttr2,TempSel);

  Y = (YStart-WinOrgY)*FontHeight;
  TmpPtr = GetLinePtr(PageStart+YStart);
  for (j = YStart+PageStart ; j <= YEnd+PageStart ; j++)
  {
    IStart = XStart;
    IEnd = XEnd;

    IStart = LeftHalfOfDBCS(TmpPtr,IStart);

    X = (IStart-WinOrgX)*FontWidth;

    i = IStart;
    do {
      CurAttr = AttrBuff[TmpPtr+i] & ~ AttrKanji;
      CurAttr2 = AttrBuff2[TmpPtr+i];
      CurSel = CheckSelect(i,j);
      count = 1;
      while
	( (i+count <= IEnd) &&
	  (CurAttr==
           (AttrBuff[TmpPtr+i+count] & ~ AttrKanji)) &&
	  (CurAttr2==AttrBuff2[TmpPtr+i+count]) &&
	  (CurSel==CheckSelect(i+count,j)) ||
	  (i+count<NumOfColumns) &&
	  ((AttrBuff[TmpPtr+i+count-1] & AttrKanji) != 0) )
	count++;

      if ((CurAttr != TempAttr) ||
	  (CurAttr2 != TempAttr2) ||
	  (CurSel != TempSel))
      {
	DispSetupDC(CurAttr,CurAttr2,CurSel);
	TempAttr = CurAttr;
	TempAttr2 = CurAttr2;
	TempSel = CurSel;
      }
      DispStr(&CodeBuff[TmpPtr+i],count,Y, &X);
      i = i+count;
    }
    while (i<=IEnd);
    Y = Y + FontHeight;
    TmpPtr = NextLinePtr(TmpPtr);
  }
  if (Caret) CaretOn();
}

void UpdateStr()
// Display not-yet-displayed string
{
  int X, Y;

  if (StrChangeCount==0) return;
  X = StrChangeStart;
  Y = CursorY;
  if (! IsLineVisible(&X, &Y))
  {
    StrChangeCount = 0;
    return;
  }

  DispSetupDC(AttrLine[StrChangeStart],
	      AttrLine2[StrChangeStart],FALSE);
  DispStr(&CodeLine[StrChangeStart],StrChangeCount,Y, &X);
  StrChangeCount = 0;
}

void MoveCursor(int Xnew, int Ynew)
{
  UpdateStr();

  if (CursorY!=Ynew) NewLine(PageStart+Ynew);

  CursorX = Xnew;
  CursorY = Ynew;
  Wrap = FALSE;

  DispScrollToCursor(CursorX, CursorY);
}

void MoveRight()
/* move cursor right, but dont update screen.
  this procedure must be called from DispChar&DispKanji only */
{
  CursorX++;
  DispScrollToCursor(CursorX, CursorY);
}

void BuffSetCaretWidth()
{
  BOOL DW;

  /* check whether cursor on a DBCS character */
  DW = (((BYTE)(AttrLine[CursorX]) & AttrKanji) != 0);
  DispSetCaretWidth(DW);
}

void ScrollUp1Line()
{
  int i;
  LONG SrcPtr, DestPtr;

  if ((CursorTop<=CursorY) && (CursorY<=CursorBottom))
  {
    UpdateStr();

    DestPtr = GetLinePtr(PageStart+CursorBottom);
    for (i = CursorBottom-1 ; i >= CursorTop ; i--)
    {
      SrcPtr = PrevLinePtr(DestPtr);
      memcpy(&(CodeBuff[DestPtr]),&(CodeBuff[SrcPtr]),NumOfColumns);
      memcpy(&(AttrBuff[DestPtr]),&(AttrBuff[SrcPtr]),NumOfColumns);
      memcpy(&(AttrBuff2[DestPtr]),&(AttrBuff2[SrcPtr]),NumOfColumns);
      DestPtr = SrcPtr;
    }
    memset(&(CodeBuff[SrcPtr]),0x20,NumOfColumns);
    memset(&(AttrBuff[SrcPtr]),AttrDefault,NumOfColumns);
    memset(&(AttrBuff2[SrcPtr]),AttrDefault2,NumOfColumns);

    DispScrollNLines(CursorTop,CursorBottom,-1);
  }
}

void BuffScrollNLines(int n)
{
  int i;
  LONG SrcPtr, DestPtr;

  if (n<1) return;
  UpdateStr();

  if ((CursorTop == 0) && (CursorBottom == NumOfLines-1))
  {
    WinOrgY = WinOrgY-n;
    BuffScroll(n,CursorBottom);
    DispCountScroll(n);
  }
  else if ((CursorTop==0) && (CursorY<=CursorBottom))
  {
    BuffScroll(n,CursorBottom);
    DispScrollNLines(WinOrgY,CursorBottom,n);
  }
  else if ((CursorTop<=CursorY) && (CursorY<=CursorBottom))
  {
    DestPtr = GetLinePtr(PageStart+CursorTop);
    if (n<CursorBottom-CursorTop+1)
    {
      SrcPtr = GetLinePtr(PageStart+CursorTop+n);
      for (i = CursorTop+n ; i<=CursorBottom ; i++)
      {
	memmove(&(CodeBuff[DestPtr]),&(CodeBuff[SrcPtr]),NumOfColumns);
	memmove(&(AttrBuff[DestPtr]),&(AttrBuff[SrcPtr]),NumOfColumns);
	memmove(&(AttrBuff2[DestPtr]),&(AttrBuff2[SrcPtr]),NumOfColumns);
	SrcPtr = NextLinePtr(SrcPtr);
	DestPtr = NextLinePtr(DestPtr);
      }
    }
    else
      n = CursorBottom-CursorTop+1;
    for (i = CursorBottom+1-n ; i<=CursorBottom; i++)
    {
      memset(&(CodeBuff[DestPtr]),0x20,NumOfColumns);
      memset(&(AttrBuff[DestPtr]),AttrDefault,NumOfColumns);
      memset(&(AttrBuff2[DestPtr]),AttrDefault2,NumOfColumns);
      DestPtr = NextLinePtr(DestPtr);
    }
    DispScrollNLines(CursorTop,CursorBottom,n);
  }
}

void BuffClearScreen()
{ // clear screen
  if ((StatusLine>0) && (CursorY==NumOfLines-1))
    BuffScrollNLines(1); /* clear status line */
  else { /* clear main screen */
    UpdateStr();
    BuffScroll(NumOfLines-StatusLine,NumOfLines-1-StatusLine);
    DispScrollNLines(WinOrgY,NumOfLines-1-StatusLine,NumOfLines-StatusLine);
  }
}

void BuffUpdateScroll()
// Updates scrolling
{
  UpdateStr();
  DispUpdateScroll();
}

void CursorUpWithScroll()
{
  if ((0<CursorY) && (CursorY<CursorTop) ||
      (CursorTop<CursorY))
    MoveCursor(CursorX,CursorY-1);
  else if (CursorY==CursorTop)
    ScrollUp1Line();
}

// called by BuffDblClk
//   check if a character is the word delimiter
BOOL IsDelimiter(LONG Line, int CharPtr)
{
  if ((AttrBuff[Line+CharPtr] & AttrKanji) !=0)
    return (ts.DelimDBCS!=0);
  return
    (strchr(ts.DelimList,CodeBuff[Line+CharPtr])!=NULL);
}

void GetMinMax(int i1, int i2, int i3,
	       int *min, int *max)
{
  if (i1<i2)
  {
    *min = i1;
    *max = i2;
  }
  else {
    *min = i2;
    *max = i1;
  }
  if (i3<*min)
    *min = i3;
  if (i3>*max)
    *max = i3;
}

void ChangeSelectRegion()
{
  POINT TempStart, TempEnd;
  int j, IStart, IEnd;
  BOOL Caret;

  if ((SelectEndOld.x==SelectEnd.x) &&
      (SelectEndOld.y==SelectEnd.y)) return;

  if (BoxSelect)
  {
    GetMinMax(SelectStart.x,SelectEndOld.x,SelectEnd.x,
	      (int *)&TempStart.x,(int *)&TempEnd.x);
    GetMinMax(SelectStart.y,SelectEndOld.y,SelectEnd.y,
	      (int *)&TempStart.y,(int *)&TempEnd.y);
    TempEnd.x--;
    Caret = IsCaretOn();
    if (Caret) CaretOff();
    DispInitDC();
    BuffUpdateRect(TempStart.x,TempStart.y-PageStart,
		   TempEnd.x,TempEnd.y-PageStart);
    DispReleaseDC();
    if (Caret) CaretOn();
    SelectEndOld = SelectEnd;
    return;
  }

  if ((SelectEndOld.y < SelectEnd.y) ||
      (SelectEndOld.y==SelectEnd.y) &&
      (SelectEndOld.x<=SelectEnd.x))
  {
    TempStart = SelectEndOld;
    TempEnd.x = SelectEnd.x-1;
    TempEnd.y = SelectEnd.y;
  }
  else {
    TempStart = SelectEnd;
    TempEnd.x = SelectEndOld.x-1;
    TempEnd.y = SelectEndOld.y;
  }
  if (TempEnd.x < 0)
  {
    TempEnd.x = NumOfColumns - 1;
    TempEnd.y--;
  }

  Caret = IsCaretOn();
  if (Caret) CaretOff();
  for (j = TempStart.y ; j <= TempEnd.y ; j++)
  {
    IStart = 0;
    IEnd = NumOfColumns-1;
    if (j==TempStart.y) IStart = TempStart.x;
    if (j==TempEnd.y) IEnd = TempEnd.x;

    if ((IEnd>=IStart) && (j >= PageStart+WinOrgY) &&
	(j < PageStart+WinOrgY+WinHeight))
    {
      DispInitDC();
      BuffUpdateRect(IStart,j-PageStart,IEnd,j-PageStart);
      DispReleaseDC();
    }
  }
  if (Caret) CaretOn();

  SelectEndOld = SelectEnd;
}

void BuffDblClk(int Xw, int Yw)
//  Select a word at (Xw, Yw) by mouse double click
//    Xw: horizontal position in window coordinate (pixels)
//    Yw: vertical
{
  int X, Y;
  int IStart, IEnd, i;
  LONG TmpPtr;
  BYTE b;
  BOOL DBCS;

  CaretOff();

  DispConvWinToScreen(Xw,Yw,&X,&Y,NULL);
  Y = Y + PageStart;
  if ((Y<0) || (Y>=BuffEnd)) return;
  if (X<0) X = 0;
  if (X>=NumOfColumns) X = NumOfColumns-1;

  BoxSelect = FALSE;
  LockBuffer();
  SelectEnd = SelectStart;
  ChangeSelectRegion();

  if ((Y>=0) && (Y<BuffEnd))
  {
    TmpPtr = GetLinePtr(Y);

    IStart = X;
    IStart = LeftHalfOfDBCS(TmpPtr,IStart);
    IEnd = IStart;

    if (IsDelimiter(TmpPtr,IStart))
    {
      b = CodeBuff[TmpPtr+IStart];
      DBCS = (AttrBuff[TmpPtr+IStart] & AttrKanji) != 0;
      while ((IStart>0) &&
	     ((b==CodeBuff[TmpPtr+IStart]) ||
	      DBCS &&
	      ((AttrBuff[TmpPtr+IStart] & AttrKanji)!=0)))
	MoveCharPtr(TmpPtr,&IStart,-1); // move left
      if ((b!=CodeBuff[TmpPtr+IStart]) &&
	  ! (DBCS &&
	     ((AttrBuff[TmpPtr+IStart] & AttrKanji)!=0)))
	MoveCharPtr(TmpPtr,&IStart,1);

      i = 1;
      while ((i!=0) &&
	     ((b==CodeBuff[TmpPtr+IEnd]) ||
	      DBCS &&
	      ((AttrBuff[TmpPtr+IEnd] & AttrKanji)!=0)))
	i = MoveCharPtr(TmpPtr,&IEnd,1); // move right
    }
    else {
      while ((IStart>0) &&
	     ! IsDelimiter(TmpPtr,IStart))
	MoveCharPtr(TmpPtr,&IStart,-1); // move left
      if (IsDelimiter(TmpPtr,IStart))
        MoveCharPtr(TmpPtr,&IStart,1);

      i = 1;
      while ((i!=0) &&
	     ! IsDelimiter(TmpPtr,IEnd))
	i = MoveCharPtr(TmpPtr,&IEnd,1); // move right
    }
    if (i==0)
      IEnd = NumOfColumns;

    if (IStart<=X)
    {
      SelectStart.x = IStart;
      SelectStart.y = Y;
      SelectEnd.x = IEnd;
      SelectEnd.y = Y;
      SelectEndOld = SelectStart;
      DblClkStart = SelectStart;
      DblClkEnd = SelectEnd;
      Selected = TRUE;
      ChangeSelectRegion();
    }
  }
  UnlockBuffer();
}

void BuffTplClk(int Yw)
//  Select a line at Yw by mouse tripple click
//    Yw: vertical clicked position
//			in window coordinate (pixels)
{
  int Y;

  CaretOff();

  DispConvWinToScreen(0,Yw,NULL,&Y,NULL);
  Y = Y + PageStart;
  if ((Y<0) || (Y>=BuffEnd)) return;

  LockBuffer();
  SelectEnd = SelectStart;
  ChangeSelectRegion();
  SelectStart.x = 0;
  SelectStart.y = Y;
  SelectEnd.x = NumOfColumns;
  SelectEnd.y = Y;
  SelectEndOld = SelectStart;
  DblClkStart = SelectStart;
  DblClkEnd = SelectEnd;
  Selected = TRUE;
  ChangeSelectRegion();
  UnlockBuffer();
}

void BuffStartSelect(int Xw, int Yw, BOOL Box)
//  Start text selection by mouse button down
//    Xw: horizontal position in window coordinate (pixels)
//    Yw: vertical
//    Box: Box selection if TRUE
{
  int X, Y;
  BOOL Right;
  LONG TmpPtr;

  DispConvWinToScreen(Xw,Yw, &X,&Y,&Right);
  Y = Y + PageStart;
  if ((Y<0) || (Y>=BuffEnd)) return;
  if (X<0) X = 0;
  if (X>=NumOfColumns) X = NumOfColumns-1;

  SelectEndOld = SelectEnd;
  SelectEnd = SelectStart;

  LockBuffer();
  ChangeSelectRegion();
  UnlockBuffer();

  SelectStart.x = X;
  SelectStart.y = Y;
  if (SelectStart.x<0) SelectStart.x = 0;
  if (SelectStart.x > NumOfColumns)
    SelectStart.x = NumOfColumns;
  if (SelectStart.y < 0) SelectStart.y = 0;
  if (SelectStart.y >= BuffEnd)
    SelectStart.y = BuffEnd - 1;

  TmpPtr = GetLinePtr(SelectStart.y);
  // check if the cursor is on the right half of a character
  if ((SelectStart.x>0) &&
      ((AttrBuff[TmpPtr+SelectStart.x-1] & AttrKanji) != 0) ||
      ((AttrBuff[TmpPtr+SelectStart.x] & AttrKanji) == 0) &&
       Right) SelectStart.x++;

  SelectEnd = SelectStart;
  SelectEndOld = SelectEnd;
  CaretOff();
  Selected = TRUE;
  BoxSelect = Box;
}

void BuffChangeSelect(int Xw, int Yw, int NClick)
//  Change selection region by mouse move
//    Xw: horizontal position of the mouse cursor
//			in window coordinate
//    Yw: vertical
{
  int X, Y;
  BOOL Right;
  LONG TmpPtr;
  int i;
  BYTE b;
  BOOL DBCS;

  DispConvWinToScreen(Xw,Yw,&X,&Y,&Right);
  Y = Y + PageStart;

  if (X<0) X = 0;
  if (X > NumOfColumns)
    X = NumOfColumns;
  if (Y < 0) Y = 0;
  if (Y >= BuffEnd)
    Y = BuffEnd - 1;

  TmpPtr = GetLinePtr(Y);
  LockBuffer();
  // check if the cursor is on the right half of a character
  if ((X>0) &&
      ((AttrBuff[TmpPtr+X-1] & AttrKanji) != 0) ||
      (X<NumOfColumns) &&
      ((AttrBuff[TmpPtr+X] & AttrKanji) == 0) &&
      Right) X++;

  if (X > NumOfColumns)
    X = NumOfColumns;

  SelectEnd.x = X;
  SelectEnd.y = Y;

  if (NClick==2) // drag after double click
  {
    if ((SelectEnd.y>SelectStart.y) ||
	(SelectEnd.y==SelectStart.y) &&
	(SelectEnd.x>=SelectStart.x))
    {
      if (SelectStart.x==DblClkEnd.x)
      {
	SelectEnd = DblClkStart;
	ChangeSelectRegion();
	SelectStart = DblClkStart;
	SelectEnd.x = X;
	SelectEnd.y = Y;
      }
      MoveCharPtr(TmpPtr,&X,-1);
      if (X<SelectStart.x) X = SelectStart.x;

      i = 1;
      if (IsDelimiter(TmpPtr,X))
      {
	b = CodeBuff[TmpPtr+X];
	DBCS = (AttrBuff[TmpPtr+X] & AttrKanji) != 0;
	while ((i!=0) &&
	       ((b==CodeBuff[TmpPtr+SelectEnd.x]) ||
		DBCS &&
		((AttrBuff[TmpPtr+SelectEnd.x] & AttrKanji)!=0)))
	  i = MoveCharPtr(TmpPtr,(int *)&SelectEnd.x,1); // move right
      }
      else {
	while ((i!=0) &&
	       ! IsDelimiter(TmpPtr,SelectEnd.x))
	  i = MoveCharPtr(TmpPtr,(int *)&SelectEnd.x,1); // move right
      }
      if (i==0)
	SelectEnd.x = NumOfColumns;
    }
    else {
      if (SelectStart.x==DblClkStart.x)
      {
	SelectEnd = DblClkEnd;
	ChangeSelectRegion();
	SelectStart = DblClkEnd;
	SelectEnd.x = X;
	SelectEnd.y = Y; 
      }
      if (IsDelimiter(TmpPtr,SelectEnd.x))
      {
	b = CodeBuff[TmpPtr+SelectEnd.x];
	DBCS = (AttrBuff[TmpPtr+SelectEnd.x] & AttrKanji) != 0;
	while ((SelectEnd.x>0) &&
	       ((b==CodeBuff[TmpPtr+SelectEnd.x]) ||
		DBCS &&
		((AttrBuff[TmpPtr+SelectEnd.x] & AttrKanji)!=0)))
	  MoveCharPtr(TmpPtr,(int *)&SelectEnd.x,-1); // move left
	if ((b!=CodeBuff[TmpPtr+SelectEnd.x]) &&
	    ! (DBCS &&
	       ((AttrBuff[TmpPtr+SelectEnd.x] & AttrKanji)!=0)))
	  MoveCharPtr(TmpPtr,(int *)&SelectEnd.x,1);
      }
      else {
	while ((SelectEnd.x>0) &&
	       ! IsDelimiter(TmpPtr,SelectEnd.x))
	  MoveCharPtr(TmpPtr,(int *)&SelectEnd.x,-1); // move left
	if (IsDelimiter(TmpPtr,SelectEnd.x))
	  MoveCharPtr(TmpPtr,(int *)&SelectEnd.x,1); 
      }
    }
  }
  else if (NClick==3) // drag after tripple click
  {
    if ((SelectEnd.y>SelectStart.y) ||
	(SelectEnd.y==SelectStart.y) &&
	(SelectEnd.x>=SelectStart.x))
    {
      if (SelectStart.x==DblClkEnd.x)
      {
	SelectEnd = DblClkStart;
	ChangeSelectRegion();
	SelectStart = DblClkStart;
	SelectEnd.x = X;
	SelectEnd.y = Y;
      }
      SelectEnd.x = NumOfColumns;
    }
    else {
      if (SelectStart.x==DblClkStart.x)
      {
	SelectEnd = DblClkEnd;
	ChangeSelectRegion();
	SelectStart = DblClkEnd;
	SelectEnd.x = X;
	SelectEnd.y = Y;
      }
      SelectEnd.x = 0;
    }
  }

  ChangeSelectRegion();
  UnlockBuffer();
}

void BuffEndSelect()
//  End text selection by mouse button up
{
  Selected = (SelectStart.x!=SelectEnd.x) ||
	     (SelectStart.y!=SelectEnd.y);
  if (Selected)
  {
    if (BoxSelect)
    {
      if (SelectStart.x>SelectEnd.x)
      {
        SelectEndOld.x = SelectStart.x;
        SelectStart.x = SelectEnd.x;
        SelectEnd.x = SelectEndOld.x;
      }
      if (SelectStart.y>SelectEnd.y)
      {
        SelectEndOld.y = SelectStart.y;
        SelectStart.y = SelectEnd.y;
        SelectEnd.y = SelectEndOld.y;
      }
    }
    else if ((SelectEnd.y < SelectStart.y) ||
      (SelectEnd.y == SelectStart.y) &&
      (SelectEnd.x < SelectStart.x))
    {
      SelectEndOld = SelectStart;
      SelectStart = SelectEnd;
      SelectEnd = SelectEndOld;
    }
    /* copy to the clipboard */
    if (ts.AutoTextCopy>0)
    {
      LockBuffer();
      BuffCBCopy(FALSE);
      UnlockBuffer();
    }
  }
}

void BuffChangeWinSize(int Nx, int Ny)
// Change window size
//   Nx: new window width (number of characters)
//   Ny: new window hight
{
  if (Nx==0) Nx = 1;
  if (Ny==0) Ny = 1;

  if ((ts.TermIsWin>0) &&
      ((Nx!=NumOfColumns) || (Ny!=NumOfLines)))
  {
    LockBuffer();
    BuffChangeTerminalSize(Nx,Ny-StatusLine);
    UnlockBuffer();
    Nx = NumOfColumns;
    Ny = NumOfLines;
  }
  if (Nx>NumOfColumns) Nx = NumOfColumns;
  if (Ny>BuffEnd) Ny = BuffEnd;
  DispChangeWinSize(Nx,Ny);
}

void BuffChangeTerminalSize(int Nx, int Ny)
{
  int i, Nb, W, H;
  BOOL St;

  Ny = Ny + StatusLine;
  if (Nx < 1) Nx = 1;
  if (Ny < 1) Ny = 1;
  if (Nx > BuffXMax) Nx = BuffXMax;
  if (ts.ScrollBuffMax > BuffYMax)
    ts.ScrollBuffMax = BuffYMax;
  if (Ny > ts.ScrollBuffMax) Ny = ts.ScrollBuffMax;

  St = ((StatusLine>0) && (CursorY==NumOfLines-1));
  if ((Nx!=NumOfColumns) || (Ny!=NumOfLines))
  {
    if ((ts.ScrollBuffSize < Ny) ||
	(ts.EnableScrollBuff==0))
      Nb = Ny;
    else Nb = ts.ScrollBuffSize;

    if (! ChangeBuffer(Nx,Nb)) return;
    if (ts.EnableScrollBuff>0)
      ts.ScrollBuffSize = NumOfLinesInBuff;
    if (Ny > NumOfLinesInBuff) Ny = NumOfLinesInBuff;

    NumOfColumns = Nx;
    NumOfLines = Ny;
    ts.TerminalWidth = Nx;
    ts.TerminalHeight = Ny-StatusLine;

    PageStart = BuffEnd - NumOfLines;
  }
  BuffScroll(NumOfLines,NumOfLines-1);
  /* Set Cursor */
  CursorX = 0;
  if (St)
  {
    CursorY = NumOfLines-1;
    CursorTop = CursorY;
    CursorBottom = CursorY;
  }
  else {
    CursorY = 0;
    CursorTop = 0;
    CursorBottom = NumOfLines-1-StatusLine;
  }

  SelectStart.x = 0;
  SelectStart.y = 0;
  SelectEnd = SelectStart;
  Selected = FALSE;

  /* Tab stops */
  NTabStops = (NumOfColumns-1) >> 3;
  for (i = 1 ; i <= NTabStops ; i++)
    TabStops[i-1] = i*8;

  if (ts.TermIsWin>0)
  {
    W = NumOfColumns;
    H = NumOfLines;
  }
  else {
    W = WinWidth;
    H = WinHeight;
    if ((ts.AutoWinResize>0) ||
        (NumOfColumns < W)) W = NumOfColumns;
    if (ts.AutoWinResize>0) H = NumOfLines;
    else if (BuffEnd < H) H = BuffEnd;
  }

  NewLine(PageStart+CursorY);

  /* Change Window Size */
  BuffChangeWinSize(W,H);
  WinOrgY = -NumOfLines;
  DispScrollHomePos();

  if (cv.Ready && cv.TelFlag)
    TelInformWinSize(NumOfColumns,NumOfLines-StatusLine);

  TTXSetWinSize(NumOfLines-StatusLine, NumOfColumns); /* TTPLUG */
}

void ChangeWin()
{
  int Ny;

  /* Change buffer */
  if (ts.EnableScrollBuff>0)
  {
    if (ts.ScrollBuffSize < NumOfLines)
      ts.ScrollBuffSize = NumOfLines;
    Ny = ts.ScrollBuffSize;
  }
  else
    Ny = NumOfLines;

  if (NumOfLinesInBuff!=Ny)
  {
    ChangeBuffer(NumOfColumns,Ny);
    if (ts.EnableScrollBuff>0)
      ts.ScrollBuffSize = NumOfLinesInBuff;

    if (BuffEnd < WinHeight)
      BuffChangeWinSize(WinWidth,BuffEnd);
    else
      BuffChangeWinSize(WinWidth,WinHeight);
  }

  DispChangeWin();
}

void ClearBuffer()
{
  /* Reset buffer */
  PageStart = 0;
  BuffStartAbs = 0;
  BuffEnd = NumOfLines;
  if (NumOfLines==NumOfLinesInBuff)
    BuffEndAbs = 0;
  else
    BuffEndAbs = NumOfLines;

  SelectStart.x = 0;
  SelectStart.y = 0;
  SelectEnd = SelectStart;
  SelectEndOld = SelectStart;
  Selected = FALSE;

  NewLine(0);
  memset(&CodeBuff[0],0x20,BufferSize);
  memset(&AttrBuff[0],AttrDefault,BufferSize);
  memset(&AttrBuff2[0],AttrDefault2,BufferSize);

  /* Home position */
  CursorX = 0;
  CursorY = 0;
  WinOrgX = 0;
  WinOrgY = 0;
  NewOrgX = 0;
  NewOrgY = 0;

  /* Top/bottom margin */
  CursorTop = 0;
  CursorBottom = NumOfLines-1;

  StrChangeCount = 0;

  DispClearWin();
}

void SetTabStop()
{
  int i,j;

  if (NTabStops<NumOfColumns)
  {
    i = 0;
    while ((TabStops[i]<CursorX) && (i<NTabStops))
      i++;

    if ((i<NTabStops) && (TabStops[i]==CursorX)) return;

    for (j=NTabStops ; j>=i+1 ; j--)
      TabStops[j] = TabStops[j-1];
    TabStops[i] = CursorX;
    NTabStops++;
  }
}

void MoveToNextTab()
{
  int i;

  if (NTabStops>0)
  {
    i = -1;
    do
      i++;
    while ((TabStops[i]<=CursorX) && (i<NTabStops-1));
    if (TabStops[i]>CursorX)
      MoveCursor(TabStops[i],CursorY);
    else
      MoveCursor(NumOfColumns-1,CursorY);
  }
  else
    MoveCursor(NumOfColumns-1,CursorY);
}

void ClearTabStop(int Ps)
// Clear tab stops
//   Ps = 0: clear the tab stop at cursor
//      = 3: clear all tab stops
{
  int i,j;

  if (NTabStops>0)
    switch (Ps) {
      case 0:
	i = 0;
	while ((TabStops[i]!=CursorX) && (i<NTabStops-1))
	  i++;
	if (TabStops[i] == CursorX)
	{
	  NTabStops--;
	  for (j=i ; j<=NTabStops ; j++)
	    TabStops[j] = TabStops[j+1];
	}
	break;
      case 3: NTabStops = 0; break;
    }
}

void ShowStatusLine(int Show)
// show/hide status line
{
  int Ny, Nb, W, H;

  BuffUpdateScroll();
  if (Show==StatusLine) return;
  StatusLine = Show;

  if (StatusLine==0)
  {
    NumOfLines--;
    BuffEnd--;
    BuffEndAbs=PageStart+NumOfLines;
    if (BuffEndAbs >= NumOfLinesInBuff)
      BuffEndAbs = BuffEndAbs-NumOfLinesInBuff;
    Ny = NumOfLines;
  }
  else
    Ny = ts.TerminalHeight+1;

  if ((ts.ScrollBuffSize < Ny) ||
      (ts.EnableScrollBuff==0))
   Nb = Ny;
  else Nb = ts.ScrollBuffSize;

  if (! ChangeBuffer(NumOfColumns,Nb)) return;
  if (ts.EnableScrollBuff>0)
    ts.ScrollBuffSize = NumOfLinesInBuff;
  if (Ny > NumOfLinesInBuff) Ny = NumOfLinesInBuff;

  NumOfLines = Ny;
  ts.TerminalHeight = Ny-StatusLine;

  if (StatusLine==1)
    BuffScroll(1,NumOfLines-1);

  if (ts.TermIsWin>0)
  {
    W = NumOfColumns;
    H = NumOfLines;
  }
  else {
    W = WinWidth;
    H = WinHeight;
    if ((ts.AutoWinResize>0) ||
	(NumOfColumns < W)) W = NumOfColumns;
    if (ts.AutoWinResize>0) H = NumOfLines;
    else if (BuffEnd < H) H = BuffEnd;
  }

  PageStart = BuffEnd-NumOfLines;
  NewLine(PageStart+CursorY);

  /* Change Window Size */
  BuffChangeWinSize(W,H);
  WinOrgY = -NumOfLines;
  DispScrollHomePos();

  MoveCursor(CursorX,CursorY);
}
