/* Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved. */

/* TTMACRO.EXE, Macro file buffer */

#ifdef __cplusplus
extern "C" {
#endif

BOOL InitBuff(PCHAR FileName);
void CloseBuff(int IBuff);
BOOL GetNewLine();
// goto
void JumpToLabel(int ILabel);
// call .. return
WORD CallToLabel(int ILabel);
WORD ReturnFromSub();
// include file
BOOL BuffInclude(PCHAR FileName);
BOOL ExitBuffer();
// for ... next
int SetForLoop();
void LastForLoop();
BOOL CheckNext();
int NextLoop();
// while ... endwhile
int SetWhileLoop();
void EndWhileLoop();
int BackToWhile();

extern int EndWhileFlag;

#ifdef __cplusplus
}
#endif
