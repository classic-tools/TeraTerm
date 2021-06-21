{ Teraterm extension mechanism
   Robert O'Callahan (roc+tt@cs.cmu.edu)
   
   Teraterm by Takashi Teranishi (teranishi@rikaxp.riken.go.jp)
}
unit TTXTypes; {translated from ttplugin.h}

interface
{$I teraterm.inc}

uses WinTypes, TTTypes, TTDTypes, WskTypes, TTSTypes;

type
  PTTXSockHooks = ^TTXSockHooks;
  TTXSockHooks = record
    closesocket: Tclosesocket;
    connect: Tconnect;
    htonl: Thtonl;
    htons: Thtons;
    inet_addr: Tinet_addr;
    ioctlsocket: Tioctlsocket;
    recv: Trecv;
    select: Tselect;
    send: Tsend;
    setsockopt: Tsetsockopt;
    _socket: T_socket;
    WSAAsyncSelect: TWSAAsyncSelect;
    WSAAsyncGetHostByName: TWSAAsyncGetHostByName;
    WSACancelAsyncRequest: TWSACancelAsyncRequest;
    WSAGetLastError: TWSAGetLastError;
  end;

  PTTXSetupHooks = ^TTXSetupHooks;
  TTXSetupHooks = record
    ReadIniFile: TReadIniFile;
    WriteIniFile: TWriteIniFile;
    ReadKeyboardCnf: TReadKeyboardCnf;
    CopyHostList: TCopyHostList;
    AddHostToList: TAddHostToList;
    ParseParam: TParseParam;
  end;

  PTTXUIHooks = ^TTXUIHooks;
  TTXUIHooks = record
    SetupTerminal: TSetupTerminal;
    SetupWin: TSetupWin;     
    SetupKeyboard: TSetupKeyboard;
    SetupSerialPort: TSetupSerialPort;
    SetupTCPIP: TSetupTCPIP;
    GetHostName: TGetHostName;    
    ChangeDirectory: TChangeDirectory;
    AboutDialog: TAboutDialog;
    ChooseFontDlg: TChooseFontDlg;
    SetupGeneral: TSetupGeneral;
    WindowWindow: TWindowWindow;
  end;

  TTTXInit = procedure(ts: PTTSet; cv: PComVar);
  TTTXGetUIHooks = procedure(UIHooks: PTTXUIHooks);
  TTTXGetSetupHooks = procedure(setupHooks: PTTXSetupHooks);
  TTTXOpenTCP = procedure(hooks: PTTXSockHooks);
  TTTXCloseTCP = procedure(hooks: PTTXSockHooks);
  TTTXSetWinSize = procedure(rows, cols: integer);
  TTTXModifyMenu = procedure(menu: HMENU);
  TTTXModifyPopupMenu = procedure(menu: HMENU);
  TTTXProcessCommand = function(hWin: HWND; cmd: WORD): integer;
  TTTXEnd = procedure;
  TTTXSetCommandLine = procedure(cmd: PCHAR; cmdlen: integer; rec: PGetHNRec);

  PTTXExports = ^TTXExports;
  TTXExports = record
    size: integer;
    loadOrder: integer; {smaller numbers get loaded first}
    TTXInit: TTTXInit; {called first to last}
    TTXGetUIHooks: TTTXGetUIHooks; {called first to last}
    TTXGetSetupHooks: TTTXGetSetupHooks; {called first to last}
    TTXOpenTCP: TTTXOpenTCP; {called first to last}
    TTXCloseTCP: TTTXCloseTCP; {called last to first}
    TTXSetWinSize: TTTXSetWinSize; {called first to last}
    TTXModifyMenu: TTTXModifyMenu; {called first to last}
    TTXModifyPopupMenu: TTTXModifyPopupMenu; {called first to last}
    TTXProcessCommand: TTTXProcessCommand; {returns TRUE if handled, called last to first}
    TTXEnd: TTTXEnd; {called last to first}
    TTXSetCommandLine: TTTXSetCommandLine; {called first to last}
  end;

{ On entry, 'size' is set to the size of the structure and the rest of
   the fields are set to 0 or NULL. Any fields not understood by the extension DLL
   should be left untouched, i.e. NULL. Any NULL functions are assumed to have
   default behaviour, i.e. do nothing.
   This is all for binary compatibility across releases; if the record gets bigger,
   then the extra functions will be NULL for DLLs that don't understand them. }

implementation

end.
