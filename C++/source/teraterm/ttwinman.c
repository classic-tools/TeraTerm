/* Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved. */

/* TERATERM.EXE, variables, flags related to VT win and TEK win */

#include "teraterm.h"
#include "tttypes.h"
#include <stdio.h>
#include <string.h>
#include "ttlib.h"
#include "helpid.h"

HWND HVTWin = NULL;
HWND HTEKWin = NULL;
  
int ActiveWin = IdVT; /* IdVT, IdTEK */
int TalkStatus = IdTalkKeyb; /* IdTalkKeyb, IdTalkCB, IdTalkTextFile */
BOOL KeybEnabled = TRUE; /* keyboard switch */
BOOL Connecting = FALSE;

/* 'help' button on dialog box */
WORD MsgDlgHelp;
LONG HelpId;

TTTSet ts;
TComVar cv;

/* pointers to window objects */
void* pVTWin = NULL;
void* pTEKWin = NULL;
/* instance handle */
HINSTANCE hInst;

int SerialNo;

void VTActivate()
{
  ActiveWin = IdVT;
  ShowWindow(HVTWin, SW_SHOWNORMAL);
  SetFocus(HVTWin);
}

void ChangeTitle()
{
  int i;
  char TempTitle[81];
  char Num[11];

  strcpy(TempTitle, ts.Title);

  if ((ts.TitleFormat & 1)!=0)
  { // host name
    strncat(TempTitle," - ",sizeof(TempTitle)-1-strlen(TempTitle));
    i = sizeof(TempTitle)-1-strlen(TempTitle);
    if (Connecting)
      strncat(TempTitle,"[connecting...]",i);
    else if (! cv.Ready)
      strncat(TempTitle,"[disconnected]",i);
    else if (cv.PortType==IdSerial)
    {
      switch (ts.ComPort) {
	case 1: strncat(TempTitle,"COM1",i); break;
	case 2: strncat(TempTitle,"COM2",i); break;
	case 3: strncat(TempTitle,"COM3",i); break;
	case 4: strncat(TempTitle,"COM4",i); break;
      }
    }
    else
      strncat(TempTitle,ts.HostName,i);
  }

  if ((ts.TitleFormat & 2)!=0)
  { // serial no.
    strncat(TempTitle," (",sizeof(TempTitle)-1-strlen(TempTitle));
    sprintf(Num,"%u",SerialNo);
    strncat(TempTitle,Num,sizeof(TempTitle)-1-strlen(TempTitle));
    strncat(TempTitle,")",sizeof(TempTitle)-1-strlen(TempTitle));
  }

  if ((ts.TitleFormat & 4)!=0) // VT
    strncat(TempTitle," VT",sizeof(TempTitle)-1-strlen(TempTitle));
  SetWindowText(HVTWin,TempTitle);

  if (HTEKWin!=0)
  {
    if ((ts.TitleFormat & 4)!=0) // TEK
    {
      TempTitle[strlen(TempTitle)-2] = 0;
      strncat(TempTitle,"TEK",
	sizeof(TempTitle)-1-strlen(TempTitle));
    }
    SetWindowText(HTEKWin,TempTitle);
  }
}

void SwitchMenu()
{
  HWND H1, H2;

  if (ActiveWin==IdVT)
  {
    H1 = HTEKWin;
    H2 = HVTWin;
  }
  else {
    H1 = HVTWin;
    H2 = HTEKWin;
  }

  if (H1!=0)
    PostMessage(H1,WM_USER_CHANGEMENU,0,0);
  if (H2!=0)
    PostMessage(H2,WM_USER_CHANGEMENU,0,0);
}

void SwitchTitleBar()
{
  HWND H1, H2;

  if (ActiveWin==IdVT)
  {
    H1 = HTEKWin;
    H2 = HVTWin;
  }
  else {
    H1 = HVTWin;
    H2 = HTEKWin;
  }

  if (H1!=0)
    PostMessage(H1,WM_USER_CHANGETBAR,0,0);
  if (H2!=0)
    PostMessage(H2,WM_USER_CHANGETBAR,0,0);
}

void OpenHelp(HWND HWin, UINT Command, DWORD Data)
{
  char HelpFN[MAXPATHLEN];

  strcpy(HelpFN,ts.HomeDir);
  AppendSlash(HelpFN);
  if (ts.Language==IdJapanese)
    strcat(HelpFN,HelpJpn);
  else
    strcat(HelpFN,HelpEng);
  WinHelp(HWin, HelpFN, Command, Data);
}
