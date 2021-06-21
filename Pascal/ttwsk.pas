{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, winsock interface}

unit TTWsk;

interface
{$i teraterm.inc}

uses WinTypes, WinProcs, Types, WskTypes;

var
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
  {gethostbyname: Tgethostbyname;}
  WSAAsyncSelect: TWSAAsyncSelect;
  WSAAsyncGetHostByName: TWSAAsyncGetHostByName;
  WSACancelAsyncRequest: TWSACancelAsyncRequest;
  WSAGetLastError: TWSAGetLastError;
  WSAStartup: TWSAStartup;
  WSACleanup: TWSACleanup;

function WSAGetAsyncError(lParam: longint): word;

function LoadWinsock: bool;
procedure FreeWinsock;

implementation

var
  HWinsock: THandle;

const
  IdCLOSESOCKET           = 3;
  IdCONNECT               = 4;
  IdHTONL                 = 8;
  IdHTONS                 = 9;
  IdINET_ADDR             = 10;
  IdIOCTLSOCKET           = 12;
  IdRECV                  = 16;
  IdSELECT                = 18;
  IdSEND                  = 19;
  IdSETSOCKOPT            = 21;
  IdSOCKET                = 23;
  {IdGETHOSTBYNAME         = 52;}
  IdWSAASYNCSELECT        = 101;
  IdWSAASYNCGETHOSTBYNAME = 103;
  IdWSACANCELASYNCREQUEST = 108;
  IdWSAGETLASTERROR       = 111;
  IdWSASTARTUP            = 115;
  IdWSACLEANUP            = 116;

procedure CheckWinsock;
var
  wVersionRequired: word;
  WSData: WSADATA;
begin
{$ifdef TERATERM32}
  if HWinsock=0 then exit;
{$else}
  if HWinsock < HINSTANCE_ERROR then exit;
{$endif}
  wVersionRequired := 1*256+1;
  if (WSAStartup(wVersionRequired, @WSData) <> 0) or
     (LO(WSData.wVersion) <> 1) or
     (HI(WSData.wVersion) <> 1) then
  begin
    WSACleanup;
    FreeLibrary(HWinsock);
    HWinsock := 0;
  end;
end;

function LoadWinsock: bool;
var
  Err: bool;
begin
  LoadWinsock := FALSE;
{$ifdef TERATERM32}
  if HWinsock=0 then
  begin
    HWinsock := LoadLibrary('WSOCK32.DLL');
    if HWinsock=0 then exit;
{$else}
  if HWinsock < HINSTANCE_ERROR then
  begin
    HWinsock := LoadLibrary('WINSOCK.DLL');
    if HWinsock < HINSTANCE_ERROR then exit;
{$endif}
    Err := FALSE;

    @closesocket := GetProcAddress(HWinsock, PChar(IdCLOSESOCKET));
    if @closesocket=nil then Err := TRUE;

    @connect := GetProcAddress(HWinsock, PChar(IdCONNECT));
    if @connect=nil then Err := TRUE;

    @htonl := GetProcAddress(HWinsock, PChar(IdHTONL));
    if @htonl=nil then Err := TRUE;

    @htons := GetProcAddress(HWinsock, PChar(IdHTONS));
    if @htons=nil then Err := TRUE;

    @inet_addr := GetProcAddress(HWinsock, PChar(IdINET_ADDR));
    if @inet_addr=nil then Err := TRUE;

    @ioctlsocket := GetProcAddress(HWinsock, PChar(IdIOCTLSOCKET));
    if @ioctlsocket=nil then Err := TRUE;

    @recv := GetProcAddress(HWinsock, PChar(IdRECV));
    if @recv=nil then Err := TRUE;

    @select := GetProcAddress(HWinsock, PChar(IdSELECT));
    if @select=nil then Err := TRUE;

    @send := GetProcAddress(HWinsock, PChar(IdSEND));
    if @send=nil then Err := TRUE;

    @setsockopt := GetProcAddress(HWinsock, PChar(IdSETSOCKOPT));
    if @setsockopt=nil then Err := TRUE;

    @_socket := GetProcAddress(HWinsock, PChar(IdSOCKET));
    if @_socket=nil then Err := TRUE;

    {@gethostbyname := GetProcAddress(HWinsock, PChar(IdGETHOSTBYNAME));
    if @gethostbyname=nil then Err := TRUE;}

    @WSAAsyncSelect := GetProcAddress(HWinsock, PChar(IdWSAASYNCSELECT));
    if @WSAAsyncSelect=nil then Err := TRUE;

    @WSAAsyncGetHostByName := GetProcAddress(HWinsock, PChar(IdWSAASYNCGETHOSTBYNAME));
    if @WSAAsyncGetHostByName=nil then Err := TRUE;

    @WSACancelAsyncRequest := GetProcAddress(HWinsock, PChar(IdWSACANCELASYNCREQUEST));
    if @WSACancelAsyncRequest=nil then Err := TRUE;

    @WSAGetLastError := GetProcAddress(HWinsock, PChar(IdWSAGETLASTERROR));
    if @WSAGetLastError=nil then Err := TRUE;

    @WSAStartup := GetProcAddress(HWinsock, PChar(IdWSASTARTUP));
    if @WSAStartup=nil then Err := TRUE;

    @WSACleanup := GetProcAddress(HWinsock, PChar(IdWSACLEANUP));
    if @WSACleanup=nil then Err := TRUE;

    if Err then
    begin
      FreeLibrary(HWinsock);
      HWinsock := 0;
      exit;
    end;
  end;

  CheckWinsock;

{$ifdef TERATERM32}
  LoadWinsock := HWinsock<>0;
{$else}
  LoadWinsock := HWinsock >= HINSTANCE_ERROR;
{$endif}
end;

procedure FreeWinsock;
var
  HTemp: THandle;
{$ifndef TERATERM32}
  Msg: TMsg;
{$endif}
begin
{$ifdef TERATERM32}
  if HWinsock=0 then exit;
{$else}
  if HWinsock < HINSTANCE_ERROR then exit;
{$endif}
  HTemp := HWinsock;
  HWinsock := 0;
  WSACleanUp;
{$ifdef TERATERM32}
  Sleep(50); {for safety}
{$else}
  PeekMessage(Msg,0,0,0,PM_NOREMOVE);
{$endif}
  FreeLibrary(HTemp);
end;

function WSAGetAsyncError(lParam: longint): word;
begin
  WSAGetAsyncError := HIWORD(lParam);
end;

begin
  HWinsock := 0;
end.
