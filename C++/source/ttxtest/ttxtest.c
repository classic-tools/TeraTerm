/* Teraterm extension mechanism
   Robert O'Callahan (roc+tt@cs.cmu.edu)
   
   Teraterm by Takashi Teranishi (teranishi@rikaxp.riken.go.jp)
*/

/* HOW TO WRITE A TERATERM EXTENSION

   First of all, you will need the source code to Teraterm. For that, you
   should visit the Teraterm Web page:
   http://www.vector.co.jp/authors/VA002416/teraterm.html
   You will frequently need to refer to the source code to find out how things
   work and when your functions are called. However, please try to write your
   extension without assuming too much about the behaviour of Teraterm, in
   case it changes in the future!

   You will also need a compiler that can build Teraterm. So far, the
   extension system has only been tested with Visual C++ 4.2. Please report
   any problems to me (roc).

   Then you can compile this sample extension.

   Make sure you set the structure alignment option in the project to
   8 bytes (for Win32) or 2 bytes (for Win16), to be compatible with the
   standard Teraterm binary.
   
   You must add the Teraterm "source\common" directory to your include path
   to find the following 3 include files:
*/

#include "teraterm.h"
#include "tttypes.h"
#include "ttplugin.h"

/* These are the standard libraries used below. The main Teraterm program and
   all its DLLs are each statically linked to the C runtime library --- i.e.
   they do not require any runtime library DLL, and they each have private
   copies of the runtime library functions that they use. Therefore, it's
   probably best if TTXs use the same strategy.
*/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

/* When you build this extension, it should be called TTXTEST.DLL. To try it
   out, copy it into the directory containing Teraterm. Currently, in order to
   use extensions with Teraterm, you have to set the environment variable
   TERATERM_EXTENSIONS to something. So in a command shell, use
   "set TERATERM_EXTENSIONS=1". Then use "ttermpro > dump" to run Teraterm and
   save the debugging output below to the file "dump".

   When TERATERM_EXTENSIONS is set, Teraterm automatically scans the directory
   containing it, looking for files of the form TTX*.DLL. It loads any that it
   finds. For each one that it finds, it calls TTXBind; see below for details.
*/

/* This variable is used for the load order of the extension (see below for
   details). We also print it out in all the diagnostics, to make sure the
   functions are being called according to the correct order. */
#define ORDER 4000

/* This code demonstrates how to maintain separate instance variables for
   each instance of Teraterm that's using the DLL. It's easy in Win32, because
   it happens automatically, but in Win16 there is only one set of global
   data for all Teraterms using the DLL, so we have to jump through some
   hoops.
*/
static HANDLE hInst; /* Instance handle of TTX*.DLL */

typedef struct {
  PTTSet ts;
  PComVar cv;
  HMENU SetupMenu;
} TInstVar;

static TInstVar FAR * pvar;

#ifdef TERATERM32
  /* WIN32 allows multiple instances of a DLL */
  static TInstVar InstVar;
#else
  /* WIN16 does not allow multiple instances of a DLL */

  /* maximum number of Tera Term instances */
  #define MAXNUMINST 32
  /* list of task handles for Tera Term instances */
  static HANDLE FAR TaskList[MAXNUMINST];
  /* variable sets for instances */
  static TInstVar FAR InstVar[MAXNUMINST];

  static BOOL NewVar()
  {
    int i = 0;
    HANDLE Task = GetCurrentTask();

    if (TaskList[0]==NULL)

    if (Task==NULL) return FALSE;
    while ((i<MAXNUMINST) && (TaskList[i]!=NULL)) i++;
    if (i>=MAXNUMINST) return FALSE;
    pvar = &InstVar[i];
    TaskList[i] = Task;
    return TRUE;
  }

  void DelVar()
  {
    int i = 0;
    HANDLE Task = GetCurrentTask();

    if (Task==NULL) return;
    while ((i<MAXNUMINST) && (TaskList[i]!=Task)) i++;
    if (i>=MAXNUMINST) return;
    TaskList[i] = NULL;
  }

  BOOL GetVar()
  {
    int i = 0;
    HANDLE Task = GetCurrentTask();

    if (Task==NULL) return FALSE;
    while ((i<MAXNUMINST) && (TaskList[i]!=Task)) i++;
    if (i>=MAXNUMINST) return FALSE;
    pvar = &InstVar[i];
    return TRUE;
  }
#endif

/* When this function is called, you should save copies of the ts and cv
   pointers if you need to access them later. All sorts of global session data
   is stored in these variables, and you can do all sorts of tricks by reading
   and modifying their fields in some of the functions below. You'll have to
   look at the Teraterm source code to see what the fields do and how and when
   they're used.
   
   This is called when Teraterm starts up, so don't do too much work in here
   or you will slow down the startup process even if your extension is not
   going to be used.
*/
static void PASCAL FAR TTXInit(PTTSet ts, PComVar cv) {
#ifndef TERATERM32
  if (! NewVar()) return; /* should be called first */
#endif
  pvar->ts = ts;
  pvar->cv = cv;
#ifdef TERATERM32
  printf("TTXInit %d\n", ORDER);
#endif
}

/* This function is called when Teraterm is opening a TCP connection, before
   any Winsock functions have actually been called.

   You receive a 'hooks' structure containing pointers to pointers to all the
   Winsock functions that Teraterm will use. You can replace any of these
   function pointers to point to your own routines. However, if you replace a
   function pointer, you should save the old pointer somewhere and use that
   instead of calling Winsock directly. Some other extension might have put
   something there for you to use!

   For example:
   
   [in TTXOpenTCP]
   ... saved_connect = hooks->Pconnect; hooks->Pconnect = my_connect; ...
   
   [in my_connect]
   ... saved_connect(...); ...
   [don't call the real connect!]

   Extensions that don't apply to all sessions (e.g. any extension that can be
   disabled by the user) will check to see if they apply to the current
   session, and if they don't, then no functions are be changed.

   This function is called for each extension, in load order (see below).
   Thus, the extension with highest load order puts its hooks in last.
*/
static void PASCAL FAR TTXOpenTCP(TTXSockHooks FAR * hooks) {
#ifndef TERATERM32
  if (! GetVar()) return; /* should be called first */
#endif
#ifdef TERATERM32
  printf("TTXOpenTCP %d\n", ORDER);
#endif
}

/* This function is called when Teraterm is closing a TCP connection, after
   all Winsock functions have been called.

   Here you should restore any hooked pointers that you saved away. For
   example:
   ... hooks->Pconnect = saved_connect; ...

   This function is called for each extension, in reverse load order (see
   below).
*/
static void PASCAL FAR TTXCloseTCP(TTXSockHooks FAR * hooks) {
#ifndef TERATERM32
  if (! GetVar()) return; /* should be called first */
#endif
#ifdef TERATERM32
  printf("TTXCloseTCP %d\n", ORDER);
#endif
}

/* This function is called when Teraterm has loaded the TTDLG library. It
   gives the extension an opportunity to modify the function pointers that are
   used to create dialog boxes.

   Unlike the TCP functions, there's no reason to call the previous version of
   a hooked function. When you replace a dialog box, the new dialog box should
   do everything that the original dialog box did, plus any extra controls
   that you want. You'll probably have to copy the code from TTDLG to do this.
   
   If multiple extensions want to replace the same dialog box, the one with
   the highest load order number (see below) wins. For this reason, when
   writing an extension, you should look at the extensions that already exist
   and try to figure out how to make your extension work nicely with the
   others that modify the same dialog box as you do. I suggest that anyone who
   modifies a dialog box should export functions from their extension DLL so
   that other code can change the extra settings without going through that
   dialog box. Then, if there is an extension with a lower load order number
   that changes a dialog box that you also want to change, you can create a
   new dialog box that has all their changes plus your own, and call the
   exported functions in the other DLL when the user sets options for that
   other DLL. If that didn't make sense, send me email :-).

   A typical use for this function is to hook the GetHostName function so that
   extra options can be added to the connection dialog box. Whenever possible
   (without making the user interface clumsy), an extension should introduce
   new dialog boxes reachable by adding menu items (see below), rather than
   overriding an existing dialog box. Any UI for setup options should probably
   be handled this way.

   This function is called for each extension, in load order (see below).
   Thus, the extension with highest load order puts its hooks in last.
*/
static void PASCAL FAR TTXGetUIHooks(TTXUIHooks FAR * hooks) {
#ifndef TERATERM32
  if (! GetVar()) return; /* should be called first */
#endif
#ifdef TERATERM32
  printf("TTXSetUIHooks %d\n", ORDER);
#endif
}

/* This function is called when Teraterm has loaded the TTSETUP library. It
   gives the extension an opportunity to modify the function pointers that are
   used to read and write the settings file (TERATERM.INI) and to read and
   write the command line.

   An extension will almost always hook these functions. When Teraterm reads
   or writes its setup file, the extension will read or write its own internal
   settings to an appropriate section of the INI file. When Teraterm parses
   its command line, or builds a new command line to spawn a new Teraterm
   session, the extension will check for its own options or write out its own
   options.

   Any hooked functions should pass through to the old functions, just as in
   TTXOpenTCP.

   This function is called for each extension, in load order (see below).
   Thus, the extension with highest load order puts its hooks in last.
*/
static void PASCAL FAR TTXGetSetupHooks(TTXSetupHooks FAR * hooks) {
#ifndef TERATERM32
  if (! GetVar()) return; /* should be called first */
#endif
#ifdef TERATERM32
  printf("TTXSetSetupHooks %d\n", ORDER);
#endif
}

/* This function is called whenever Teraterm changes the window size.

   This function is called for each extension, in load order (see below).
*/
static void PASCAL FAR TTXSetWinSize(int rows, int cols) {
#ifndef TERATERM32
  if (! GetVar()) return; /* should be called first */
#endif
#ifdef TERATERM32
  printf("TTXSetWinSize %d\n", ORDER);
#endif
}

/* This function is called when Teraterm creates a new menu. This can happen
   quite often, especially when the menubar is hidden and Teraterm wants to
   create a popup menu because the user ctrl-clicked in the window.

   The 'menu' parameter is the HMENU for the menu bar. The extension can add
   items to the existing submenus or even add an entirely new submenu. This is
   great for adding menu items that control the extension's options.

   This function is called for each extension, in load order (see below).
   Thus, the extension with highest load order number puts its items in last.
*/
#define ID_MENUITEM 6000
static void PASCAL FAR TTXModifyMenu(HMENU menu) {
  UINT flag = MF_ENABLED;

#ifndef TERATERM32
  if (! GetVar()) return; /* should be called first */
#endif
#ifdef TERATERM32
  printf("TTXModifyMenu %d\n", ORDER);
#endif
  pvar->SetupMenu = GetSubMenu(menu,2);
  AppendMenu(pvar->SetupMenu,MF_SEPARATOR,0,NULL); 
  if (pvar->ts->Debug>0) flag |= MF_CHECKED;
  AppendMenu(pvar->SetupMenu,flag, ID_MENUITEM,"&Debug mode");
}

/* This function is called when Teraterm pops up a submenu menu.

   The 'menu' parameter is the HMENU for the submenu. The extension can change
   the status of any of the menu items, for example graying out some items.
   Extensions should make sure that this is actually the submenu that they
   care about!

   This function is called for each extension, in load order (see below).
*/
static void PASCAL FAR TTXModifyPopupMenu(HMENU menu) {
#ifndef TERATERM32
  if (! GetVar()) return; /* should be called first */
#endif
#ifdef TERATERM32
  printf("TTXModifyPopupMenu %d\n", ORDER);
#endif
  if (menu==pvar->SetupMenu)
  {
    if (pvar->cv->Ready)
      EnableMenuItem(pvar->SetupMenu,ID_MENUITEM,MF_BYCOMMAND | MF_ENABLED);
    else
      EnableMenuItem(pvar->SetupMenu,ID_MENUITEM,MF_BYCOMMAND | MF_GRAYED);
  }
}

/* This function is called when Teraterm receives a command message.

   The extension returns 1 if it processed the message, 0 otherwise. If it
   says it processed the message, then the message will not be processed
   anywhere else. The extensions look at the messages before the main
   Teraterm code, so be careful of overriding existing commands.

   This function is called for each extension, in reverse load order (see
   below). Thus, the extension that has highest load order number gets to
   process the command first.
*/
static int PASCAL FAR TTXProcessCommand(HWND hWin, WORD cmd) {
#ifndef TERATERM32
  if (! GetVar()) return 0; /* should be called first */
#endif
#ifdef TERATERM32
  printf("TTXProcessCommand %d\n", ORDER);
#endif
  if (cmd==ID_MENUITEM)
  {
    if (pvar->ts->Debug==0)
    {
      pvar->ts->Debug=1;
      CheckMenuItem(pvar->SetupMenu,ID_MENUITEM,MF_BYCOMMAND | MF_CHECKED);
    }
    else {
      pvar->ts->Debug=0;
      CheckMenuItem(pvar->SetupMenu,ID_MENUITEM,MF_BYCOMMAND | MF_UNCHECKED);
    } 
    return 1;
  }
  return 0;
}

/* This function is called when Teraterm is quitting. You can use it to clean
   up.

   This function is called for each extension, in reverse load order (see
   below).
*/
static void PASCAL FAR TTXEnd(void) {
#ifdef TERATERM32
  printf("TTXEnd %d\n", ORDER);
#endif
#ifndef TERATERM32
  DelVar(); /* should be called last */
#endif
}

/* This record contains all the information that the extension forwards to the
   main Teraterm code. It mostly consists of pointers to the above functions.
   Any of the function pointers can be replaced with NULL, in which case
   Teraterm will just ignore that function and assume default behaviour, which
   means "do nothing".
*/
static TTXExports Exports = {
/* This must contain the size of the structure. See below for its usage. */
  sizeof(TTXExports),

/* This is the load order number of this DLL. It affects which order the above
   functions are called in, as noted for each function. Choose this number
   carefully! Typically the DLLs with higher numbers are layered on top of the
   DLLs with lower numbers. Thus, a DLL that does SOCKS redirection will have
   a lower load order than a DLL that does the SSH protocol, because SOCKS
   redirection must happen "before" SSH processing. Likewise, a DLL that does
   Kerberos authentication must have a higher order number than a DLL that
   does SSL, because the Kerberos protocol uses telnet options that would go
   "on top of" SSL.

   Currently, no order numbers are used because no real extensions have been
   written.
   I suggest the following numbers:
   0-999:     Basic network naming and communication (e.g. SOCKS)
   1000-1999: Transport emulation (e.g. SSL)
   2000-2999: Protocols (e.g. SSH, telnet)
   3000-3999: Protocol extensions (e.g. Kerberos telnet options)
   4000-4999: Application features (e.g. file transfers, UI for hidden setup
              options)

   Try to use numbers in the middle of any available range so that other
   extensions can load before or after you as they wish.
*/
  ORDER,

/* Now we just list the functions that we've implemented. */
  TTXInit,
  TTXGetUIHooks,
  TTXGetSetupHooks,
  TTXOpenTCP,
  TTXCloseTCP,
  TTXSetWinSize,
  TTXModifyMenu,
  TTXModifyPopupMenu,
  TTXProcessCommand,
  TTXEnd
};

/* This is the function that Teraterm calls to retrieve the export
   information. This code is for Visual C++. The name that gets exported is
   "_TTXBind@8" and that is what the Teraterm program looks for. So, whichever
   compiler you use, you must make sure that that name is exported.

   The job of this function is to copy the export data from the structure
   above into the record that Teraterm passed us a pointer to. That record
   contains its size; we make sure we don't copy more than that amount of
   data. In the future, if we add TTX functions to the TTXExports record,
   then we could have new extensions that have a bigger TTXExports record than
   old Teraterm binaries. In this case, the extra functions will simply not be
   called. This means we can write extensions that will work with both old and
   new versions of Teraterm.

   (In a similar way, we can run old extensions with new versions of Teraterm.
   The main program initialises its exports record to zeroes before it calls
   TTXBind. This means that any data we don't copy in there is NULL, so any 
   extra functions that have been added since this extension was compiled
   will automatically be NULL and thus get default behaviour.)
*/
#ifdef TERATERM32
BOOL __declspec(dllexport) PASCAL FAR TTXBind(WORD Version, TTXExports FAR * exports) {
#else
BOOL __export PASCAL FAR TTXBind(WORD Version, TTXExports FAR * exports) {
#endif
  int size = sizeof(Exports) - sizeof(exports->size);
  /* do version checking if necessary */
  /* if (Version!=TTVERSION) return FALSE; */

  if (size > exports->size) {
    size = exports->size;
  }
  memcpy((char FAR *)exports + sizeof(exports->size),
    (char FAR *)&Exports + sizeof(exports->size),
    size);
  return TRUE;
}

#ifdef TERATERM32
BOOL WINAPI DllMain(HANDLE hInstance, 
		    ULONG ul_reason_for_call,
		    LPVOID lpReserved)
{
  switch( ul_reason_for_call ) {
    case DLL_THREAD_ATTACH:
      /* do thread initialization */
      break;
    case DLL_THREAD_DETACH:
      /* do thread cleanup */
      break;
    case DLL_PROCESS_ATTACH:
      /* do process initialization */
      hInst = hInstance;
      pvar = &InstVar;
      break;
    case DLL_PROCESS_DETACH:
      /* do process cleanup */
      break;
  }
  return TRUE;
}
#else
  #ifdef WATCOM
  #pragma off (unreferenced);
  #endif
int CALLBACK LibMain(HANDLE hInstance, WORD wDataSegment,
		     WORD wHeapSize, LPSTR lpszCmdLine )
  #ifdef WATCOM
  #pragma on (unreferenced);
  #endif
{
  int i;
  for (i=0; i<MAXNUMINST; i++)
    TaskList[i]=NULL;
  hInst = hInstance;
  return (1);
}
#endif
