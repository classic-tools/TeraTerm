/* Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved. */

/* TERATERM.EXE, main */

#include "stdafx.h"
#include "teraterm.h"
#include "tttypes.h"
#include "commlib.h"
#include "ttwinman.h"
#include "buffer.h"
#include "vtterm.h"
#include "vtwin.h"
#include "clipboar.h"
#include "ttftypes.h"
#include "filesys.h"
#include "telnet.h"
#include "tektypes.h"
#include "tekwin.h"
#include "ttdde.h"
#ifndef TERATERM32
  #include "ttctl3d.h"
#endif

#include "teraapp.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

BEGIN_MESSAGE_MAP(CTeraApp, CWinApp)
	//{{AFX_MSG_MAP(CTeraApp)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

CTeraApp::CTeraApp()
{
}

// CTeraApp instance
CTeraApp theApp;

// CTeraApp initialization
BOOL CTeraApp::InitInstance()
{
  hInst = m_hInstance;
#ifndef TERATERM32
  LoadCtl3d(m_hInstance);
#endif
  m_pMainWnd = new CVTWindow();
  pVTWin = m_pMainWnd;
  return TRUE;
}

int CTeraApp::ExitInstance()
{
#ifdef TERATERM32
  return CWinApp::ExitInstance();
#else
  FreeCtl3d();
  return 0;
#endif
}

// Tera Term main engine
BOOL CTeraApp::OnIdle(LONG lCount)
{
  static int Busy = 2;
  int Change, nx, ny;
  BOOL Size;

  if (lCount==0) Busy = 2;

  if (cv.Ready)
  {
    /* Sender */
    CommSend(&cv);

    /* Parser */
    if ((cv.HLogBuf!=NULL) && (cv.LogBuf==NULL))
      cv.LogBuf = (PCHAR)GlobalLock(cv.HLogBuf);

    if ((cv.HBinBuf!=NULL) && (cv.BinBuf==NULL))
      cv.BinBuf = (PCHAR)GlobalLock(cv.HBinBuf);

    if ((TelStatus==TelIdle) && cv.TelMode)
      TelStatus = TelIAC;

    if (TelStatus != TelIdle)
    {
      ParseTel(&Size,&nx,&ny);
      if (Size) {
	LockBuffer();
	ChangeTerminalSize(nx,ny);
	UnlockBuffer();
      }
    }
    else {
      if (cv.ProtoFlag) Change = ProtoDlgParse();
      else {
	switch (ActiveWin) {
	  case IdVT: Change =  ((CVTWindow*)pVTWin)->Parse(); break;
	  case IdTEK:
	    if (pTEKWin != NULL)
	      Change = ((CTEKWindow*)pTEKWin)->Parse();
	    else
	      Change = IdVT;
	    break;
	  default:
	    Change = 0;
	}

	switch (Change) {
	  case IdVT: VTActivate(); break;
	  case IdTEK: ((CVTWindow*)pVTWin)->OpenTEK(); break;
	}
      }
    }

    if (cv.LogBuf!=NULL)
    {
      if (FileLog) LogToFile();
      if (DDELog && AdvFlag) DDEAdv();
      GlobalUnlock(cv.HLogBuf);
      cv.LogBuf = NULL;
    }

    if (cv.BinBuf!=NULL)
    {
      if (BinLog) LogToFile();
      GlobalUnlock(cv.HBinBuf);
      cv.BinBuf = NULL;
    }

    /* Talker */
    switch (TalkStatus) {
      case IdTalkCB: CBSend(); break; /* clip board */
      case IdTalkFile: FileSend(); break; /* file */
    }

    /* Receiver */
    CommReceive(&cv);

  }

  if (cv.Ready &&
      (cv.RRQ || (cv.OutBuffCount>0) || (cv.InBuffCount>0) ||
       (cv.LCount>0) || (cv.BCount>0) || (cv.DCount>0)) )
    Busy = 2;
  else
    Busy--;

  return (Busy>0);
}

BOOL CTeraApp::PreTranslateMessage(MSG* pMsg)
{
  if (ts.MetaKey>0)
    return FALSE; /* ignore accelerator keys */
  else
    return CWinApp::PreTranslateMessage(pMsg);
}
