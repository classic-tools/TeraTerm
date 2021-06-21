{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, winsock interface}

unit WskTypes;

interface
{$i teraterm.inc}

uses WinTypes, Types;

type
  u_char = char;
  u_short = word;
  u_int = integer;
  u_long = longint;
  SOCKET = u_int;

const
  FD_SETSIZE = 64;
type
  Pfd_set = ^Tfd_set;
  Tfd_set = record
    fd_count : u_int;
    fd_array : array[0..FD_SETSIZE-1] of SOCKET;
  end;

  Ptimeval = ^timeval;
  timeval = record
    tv_sec, tv_usec : longint;
  end;

  phostent = ^hostent;
  hostent = record
    h_name: PChar;
    h_aliases: ^PChar;
    h_addrtype: u_short;
    h_length: u_short;
    h_addr_list: ^PChar;
  end;

const
  WSADESCRIPTION_LEN = 256;
  WSASYS_STATUS_LEN = 128;

type
  LPWSADATA = ^WSAData;
  WSAData = record
    wVersion: word;
    wHighVersion: word;
    szDescription: array[0..WSADESCRIPTION_LEN] of char;
    szSystemStatus: array[0..WSASYS_STATUS_LEN] of char;
    iMaxSockets: word;
    iMaxUdpDg: word;
    lpVendorInfo: PChar;
  end;

const
  INVALID_SOCKET = SOCKET(-1);
  SOCKET_ERROR = -1;

  SOCK_STREAM = 1;

  SO_OOBINLINE = $0100;

  IPPROTO_IP  = 0;
  IPPROTO_TCP = 6;

type
  in_addr = record
    S_addr : u_long;
  end;

  sockaddr_in = record
    sin_family: word;
    sin_port: u_short;
    sin_addr: in_addr;
    sin_zero: array[0..7] of char;
  end;

const
  AF_INET = 2;

type
  sockaddr = record
    sa_family: u_short;
    sa_data: array[0..13] of char;
  end;

const
{$ifdef TERATERM32}
  SOL_SOCKET = $ffff;
{$else}
  SOL_SOCKET = -1;
{$endif}

  MAXGETHOSTSTRUCT = 1024;

  FD_READ = $01;
  FD_OOB  = $04;
  FD_CONNECT = $10;
  FD_CLOSE = $20;

  WSAEWOULDBLOCK  = 10035;
  WSAENETUNREACH  = 10051;
  WSAETIMEDOUT    = 10060;
  WSAECONNREFUSED = 10061;

type
  Tclosesocket = function(s: SOCKET): integer;
  Tconnect = function(s: SOCKET; name: sockaddr; namelen: integer): integer;
  Thtonl = function(hostlong: u_long): u_long;
  Thtons = function(hostshort: u_short): u_short;
  Tinet_addr = function(cp: PChar): u_long;  
  Tioctlsocket = function(s: SOCKET; cmd: longint; argp: PLongint): integer;
  Trecv = function(s: SOCKET; buf: PChar; len, flags: integer): integer;
  Tselect = function(nfds: integer; readfds, writefds, exceptfds: Pfd_set; timeout: Ptimeval): longint;
  Tsend = function(s: SOCKET; buf: PChar; len, flags: integer): integer;
  Tsetsockopt = function(s: SOCKET; level, optname: integer; optval: PChar; optlen: integer): integer;
  T_socket = function(af, struct, protocol: integer): SOCKET;
  {Tgethostbyname = function(name : PChar): PHostEnt;}
  TWSAStartup = function(wVersionRequired: word; lpWSData: LPWSADATA): integer;
  TWSACleanup = function: integer;
  TWSAAsyncSelect = function(s: SOCKET; HWin: HWND; wMsg: word; lEvent: longint): integer;
  TWSAAsyncGetHostByName = function(HWin: HWND; wMsg: word; name, buf: PChar; buflen: integer): THandle;
  TWSACancelAsyncRequest = function(hAsyncTaskHandle: THandle): integer;
  TWSAGetLastError = function: integer;

implementation

end.
