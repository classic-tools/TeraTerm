/* Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved. */

/* TERATERM.EXE, VT terminal display routines */
#ifdef __cplusplus
extern "C" {
#endif

/* prototypes */
void InitDisp();
void EndDisp();
void DispReset();
void DispConvWinToScreen
  (int Xw, int Yw, int *Xs, int *Ys, PBOOL Right);
void SetLogFont();
void ChangeFont();
void ResetIME();
void ChangeCaret();
void CaretOn();
void CaretOff();
void DispDestroyCaret();
BOOL IsCaretOn();
void DispEnableCaret(BOOL On);
BOOL IsCaretEnabled();
void DispSetCaretWidth(BOOL DW);
void DispChangeWinSize(int Nx, int Ny);
void ResizeWindow(int x, int y, int w, int h, int cw, int ch);
void PaintWindow(HDC PaintDC, RECT PaintRect, BOOL fBkGnd,
		 int* Xs, int* Ys, int* Xe, int* Ye);
void DispEndPaint();
void DispClearWin();
void DispChangeBackground();
void DispChangeWin();
void DispInitDC();
void DispReleaseDC();
void DispSetupDC(BYTE Attr, BYTE Attr2, BOOL Reverse);
void DispStr(PCHAR Buff, int Count, int Y, int* X);
void DispEraseCurToEnd(int YEnd);
void DispEraseHomeToCur(int YHome);
void DispEraseCharsInLine(int XStart, int Count);
BOOL DispDeleteLines(int Count, int YEnd);
BOOL DispInsertLines(int Count, int YEnd);
BOOL IsLineVisible(int* X, int* Y);
void AdjustScrollBar();
void DispScrollToCursor(int CurX, int CurY);
void DispScrollNLines(int Top, int Bottom, int Direction);
void DispCountScroll();
void DispUpdateScroll();
void DispScrollHomePos();
void DispAutoScroll(POINT p);
void DispHScroll(int Func, int Pos);
void DispVScroll(int Func, int Pos);
void DispSetupFontDlg();
void DispRestoreWinSize();
void DispSetWinPos();
void DispSetActive(BOOL ActiveFlag);

extern int WinWidth, WinHeight;
extern HFONT VTFont[AttrFontMask+1];
extern int FontHeight, FontWidth, ScreenWidth, ScreenHeight;
extern BOOL AdjustSize, DontChangeSize;
extern int CursorX, CursorY;
extern int WinOrgX, WinOrgY, NewOrgX, NewOrgY;
extern int NumOfLines, NumOfColumns;
extern int PageStart, BuffEnd;

#define SCROLL_BOTTOM	1
#define SCROLL_LINEDOWN	2
#define SCROLL_LINEUP	3
#define SCROLL_PAGEDOWN	4
#define SCROLL_PAGEUP	5
#define SCROLL_POS	6
#define SCROLL_TOP	7

#ifdef __cplusplus
}
#endif
