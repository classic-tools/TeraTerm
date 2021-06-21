{ Teraterm extension mechanism
   Robert O'Callahan (roc+tt@cs.cmu.edu)
   
   Teraterm by Takashi Teranishi (teranishi@rikaxp.riken.go.jp)
}
unit TTPlug;

interface

uses WinTypes, WinProcs, Strings, WinDos,
     Types, TTTypes, TTLib;

procedure TTXInit(ts: PTTSet; cv: PComVar);
procedure TTXOpenTCP;
procedure TTXCloseTCP;
procedure TTXGetUIHooks;
procedure TTXGetSetupHooks;
procedure TTXSetWinSize(rows, cols: integer);
procedure TTXModifyMenu(menu: HMENU);
procedure TTXModifyPopupMenu(menu: HMENU);
function  TTXProcessCommand(hWin: HWND; cmd: WORD): BOOL;
procedure TTXEnd;
procedure TTXSetCommandLine(cmd: PCHAR; cmdlen: integer; rec: PGetHNRec);

implementation

uses TTXTypes, TTWsk, TTSetup, TTDialog;
{$I teraterm.inc}

type
  PArrayTTXExports = ^ArrayTTXExports;
  ArrayTTXExports = array[0..255] of TTXExports; {array size is dummy}

  TTTXBindProc = function(Version: WORD; _exports: PTTXExports): BOOL;

const
  MAXNUMEXTENSIONS = 16;
var
  LibHandle: array[0..MAXNUMEXTENSIONS-1] of THandle;
  NumExtensions: integer;
  Extensions: PArrayTTXExports;

type
  PExtensionList = ^ExtensionList;
  ExtensionList = record
    _exports: PTTXExports;
    next: PExtensionList;
  end;

procedure SortExtensions;

  function Value(i: integer): integer;
  begin
    Value := Extensions^[i].loadOrder;
  end;

  procedure QSort(l,r: integer);
  var
    il,ir,v,t: integer;
    Tmp: TTXExports;
  begin
    il:=l;
    ir:=r;
    v := Value((l+r) div 2);
    repeat
      while Value(il)<v do inc(il);
      while v<Value(ir) do dec(ir);
      if il<=ir then
      begin
        Tmp := Extensions^[il];
        Extensions^[il] := Extensions^[ir];
        Extensions^[ir] := Tmp;
        inc(il);
        dec(ir);
      end;
    until il>ir;
    if l<ir then QSort(l,ir);
    if il<r then QSort(il,r);  
  end;

begin
  if NumExtensions<2 then exit;
  QSort(0,NumExtensions-1);
end;

procedure loadExtension(var extlist: PExtensionList; fileName: PCHAR);
var
  buf: array[0..1023] of char;
  bind: TTTXBindProc;
  newExtension: PExtensionList;
begin
  if NumExtensions>=MAXNUMEXTENSIONS then exit;
  LibHandle[NumExtensions] := LoadLibrary(fileName);

{$ifdef TERATERM32}
  if LibHandle[NumExtensions] <> nil then
  begin
    @bind := GetProcAddress(LibHandle[NumExtensions], '_TTXBind@4');
    if @bind=nil then
      @bind := GetProcAddress(LibHandle[NumExtensions],'TTXBind');
{$else}
  if LibHandle[NumExtensions] >=HINSTANCE_ERROR then
  begin
    @bind := GetProcAddress(LibHandle[NumExtensions], 'TTXBIND');
{$endif}
    if @bind <> nil then
    begin
      GetMem(newExtension,sizeof(ExtensionList));

      GetMem(newExtension^._exports,sizeof(TTXExports));
      fillchar(newExtension^._exports^,sizeof(TTXExports),0);
      newExtension^._exports^.size := sizeof(TTXExports);
      if bind(TTVERSION,newExtension^._exports) then
      begin
        newExtension^.next := extlist;
        extlist := newExtension;
        inc(NumExtensions);
        exit;
      end
      else begin
        FreeMem(newExtension^._exports,sizeof(TTXExports));
        FreeMem(newExtension,sizeof(ExtensionList));
      end;
    end;
    FreeLibrary(LibHandle[NumExtensions]);
  end;

  strcopy(buf,'Cannot load extension ');
  strcat(buf,filename);
  MessageBox(0, buf, 'Teraterm Error', MB_OK or MB_ICONEXCLAMATION);
end;

procedure TTXInit(ts: PTTSet; cv: PComVar);
var
  extList, old: PExtensionList;
  i: integer;
  buf: array[0..1023] of char;
  index: integer;
  searchData: TSearchRec;
begin
  extList := nil;

  if GetEnvVar('TERATERM_EXTENSIONS')<>nil then
  begin
    GetModuleFileName(hinstance, buf, sizeof(buf));
    GetFileNamePos(buf,index,i);
    buf[index] := #0;
    AppendSlash(buf);
    strcat(buf,'TTX*.DLL');
    FindFirst(buf,faArchive,searchData);
    while DosError=0 do
    begin
      loadExtension(extList,searchData.Name);
      FindNext(searchData);
    end;

    if NumExtensions=0 then exit;

    GetMem(Extensions,sizeof(TTXExports)*NumExtensions);
    for i := 0 to NumExtensions-1 do
    begin
      Move(extList^._exports^,Extensions^[i],sizeof(TTXExports));
      old := extList;
      extList := extList^.next;
      FreeMem(old,sizeof(ExtensionList));
    end;

    SortExtensions;

    for i := 0 to NumExtensions-1 do
    begin
      if @Extensions^[i].TTXInit <> nil then
        Extensions^[i].TTXInit(ts, cv);
    end;
  end;
end;

procedure TTXInternalOpenTCP(hooks: PTTXSockHooks);
var
  i: integer;
begin
  for i := 0 to NumExtensions-1 do
  begin
    if @Extensions^[i].TTXOpenTCP <> nil then
      Extensions^[i].TTXOpenTCP(hooks);
  end;
end;

procedure TTXOpenTCP;
var
  h: TTXSockHooks;
begin
  @h.closesocket := @closesocket;
  @h.connect := @connect;
  @h.htonl := @htonl;
  @h.htons := @htons;
  @h.inet_addr := @inet_addr;
  @h.ioctlsocket := @ioctlsocket;
  @h.recv := @recv;
  @h.select := @select;
  @h.send := @send;
  @h.setsockopt := @setsockopt;
  @h._socket := @_socket;
  @h.WSAAsyncSelect := @WSAAsyncSelect;
  @h.WSAAsyncGetHostByName := @WSAAsyncGetHostByName;
  @h.WSACancelAsyncRequest := @WSACancelAsyncRequest;
  @h.WSAGetLastError := @WSAGetLastError;
  TTXInternalOpenTCP(@h);
end;

procedure TTXInternalCloseTCP(hooks: PTTXSockHooks);
var
  i: integer;
begin
  for i := NumExtensions-1 downto 0 do
  begin
    if @Extensions^[i].TTXCloseTCP <> nil then
      Extensions^[i].TTXCloseTCP(hooks);
  end;
end;

procedure TTXCloseTCP;
var
  h: TTXSockHooks;
begin
  @h.closesocket := @closesocket;
  @h.connect := @connect;
  @h.htonl := @htonl;
  @h.htons := @htons;
  @h.inet_addr := @inet_addr;
  @h.ioctlsocket := @ioctlsocket;
  @h.recv := @recv;
  @h.select := @select;
  @h.send := @send;
  @h.setsockopt := @setsockopt;
  @h._socket := @_socket;
  @h.WSAAsyncSelect := @WSAAsyncSelect;
  @h.WSAAsyncGetHostByName := @WSAAsyncGetHostByName;
  @h.WSACancelAsyncRequest := @WSACancelAsyncRequest;
  @h.WSAGetLastError := @WSAGetLastError;
  TTXInternalCloseTCP(@h);
end;

procedure TTXInternalGetUIHooks(hooks: PTTXUIHooks);
var
  i: integer;
begin
  for i := 0 to NumExtensions-1 do
  begin
    if @Extensions^[i].TTXGetUIHooks <> nil then
      Extensions^[i].TTXGetUIHooks(hooks);
  end;
end;

procedure TTXGetUIHooks;
var
  h: TTXUIHooks;
begin
  @h.SetupTerminal := @SetupTerminal;
  @h.SetupWin := @SetupWin;
  @h.SetupKeyboard := @SetupKeyboard;
  @h.SetupSerialPort := @SetupSerialPort;
  @h.SetupTCPIP := @SetupTCPIP;
  @h.GetHostName := @GetHostName;
  @h.ChangeDirectory := @ChangeDirectory;
  @h.AboutDialog := @AboutDialog;
  @h.ChooseFontDlg := @ChooseFontDlg;
  @h.SetupGeneral := @SetupGeneral;
  @h.WindowWindow := @WindowWindow;
  TTXInternalGetUIHooks(@h);
end;

procedure TTXInternalGetSetupHooks(hooks: PTTXSetupHooks);
var
  i: integer;
begin
  for i := NumExtensions-1 downto 0 do
  begin
    if @Extensions^[i].TTXGetSetupHooks <> nil then
      Extensions^[i].TTXGetSetupHooks(hooks);
  end;
end;

procedure TTXGetSetupHooks;
var
  h: TTXSetupHooks;
begin
  @h.ReadIniFile := @ReadIniFile;
  @h.WriteIniFile := @WriteIniFile;
  @h.ReadKeyboardCnf := @ReadKeyboardCnf;
  @h.CopyHostList := @CopyHostList;
  @h.AddHostToList := @AddHostToList;
  @h.ParseParam := @ParseParam;
  TTXInternalGetSetupHooks(@h);
end;

procedure TTXSetWinSize(rows, cols: integer);
var
  i: integer;
begin
  for i := 0 to NumExtensions-1 do
  begin
    if @Extensions^[i].TTXSetWinSize <> nil then
      Extensions^[i].TTXSetWinSize(rows, cols);
  end;
end;

procedure TTXModifyMenu(menu: HMENU);
var
  i: integer;
begin
  for i := 0 to NumExtensions-1 do
  begin
    if @Extensions^[i].TTXModifyMenu <> nil then
      Extensions^[i].TTXModifyMenu(menu);
  end;
end;

procedure TTXModifyPopupMenu(menu: HMENU);
var
  i: integer;
begin
  for i := 0 to NumExtensions-1 do
  begin
    if @Extensions^[i].TTXModifyPopupMenu <> nil then
      Extensions^[i].TTXModifyPopupMenu(menu);
  end;
end;

function TTXProcessCommand(hWin: HWND; cmd: WORD): BOOL;
var
  i: integer;
begin
  for i := NumExtensions-1 downto 0 do
  begin
    if @Extensions^[i].TTXProcessCommand <> nil then
    begin
      if Extensions^[i].TTXProcessCommand(hWin,cmd)<>0 then
      begin
        TTXProcessCommand := TRUE;
        exit;
      end;
    end;
  end;
  TTXProcessCommand := FALSE;
end;

procedure TTXEnd;
var
  i: integer;
begin
  if NumExtensions=0 then exit;

  for i := NumExtensions-1 downto 0 do
  begin
    if @Extensions^[i].TTXEnd <> nil then
      Extensions^[i].TTXEnd;
  end;
  for i := 0 to NumExtensions-1 do
    FreeLibrary(LibHandle[i]);

  FreeMem(Extensions,sizeof(TTXExports)*NumExtensions);
  NumExtensions := 0;
end;

procedure TTXSetCommandLine(cmd: PCHAR; cmdlen: integer; rec: PGetHNRec);
var
  i: integer;
begin
  for i := 0 to NumExtensions-1 do
  begin
    if @Extensions^[i].TTXSetCommandLine <> nil then
      Extensions^[i].TTXSetCommandLine(cmd,cmdlen,rec);
  end;
end;

begin
  NumExtensions := 0;
end.
