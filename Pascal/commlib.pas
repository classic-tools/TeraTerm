{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, Communication routines}
unit COMMLIB;

interface
{$I teraterm.inc}

{$IFDEF Delphi}
uses Messages, WinTypes, WinProcs, OWindows, Strings,
     TTTypes, Types, TTCommon, TTWsk, WskTypes, TTLib, TTPlug;
{$ELSE}
uses Win31, WinTypes, WinProcs, WObjects, Strings,
     TTTypes, Types, TTCommon, TTWsk, WskTypes, TTLib, TTPlug;
{$ENDIF}

procedure CommInit(cv: PComVar);
procedure CommOpen(HW: HWnd; ts: PTTSet; cv: PComVar);
procedure CommStart(cv: PComVar; lParam: longint);
function  CommCanClose(cv: PComVar): BOOL;
procedure CommClose(cv: PComVar);
procedure CommProcRRQ(cv: PComVar);
procedure CommReceive(cv: PComVar);
procedure CommSend(cv: PComVar);
procedure CommSendBreak(cv: PComVar);
procedure CommResetSerial(ts: PTTSet; cv: PComVar);
procedure CommLock(ts: PTTSet; cv: PComVar; Lock: BOOL);
function PrnOpen(DevName: PChar): BOOL;
function PrnWrite(b: PCHAR; c: integer): integer;
procedure PrnCancel;
procedure PrnClose;

var
  TCPIPClosed: bool;

{ Printer port handle for
  direct pass-thru printing }
{$ifdef TERATERM32}
PrnID: THANDLE;
{$else}
PrnID: integer;
{$endif}
LPTFlag: bool;

implementation
{$i tt_res.inc}

const
  ErrorCaption = 'Tera Term: Error';
  ErrorCantConn = 'Cannot connect the host';
  CommInQueSize = 8192;
  CommOutQueSize = 2048;
  CommXonLim = 2048;
  CommXoffLim = 2048;

{$ifdef TERATERM32}
const
  READENDNAME = 'ReadEnd';
  WRITENAME = 'Write';
  READNAME = 'Read';
  PRNWRITENAME = 'PrnWrite';
var
  ReadEnd: THandle;
  wol, rol: TOVERLAPPED;
{$endif}

var
  {Winsock async operation handle}
  HAsync: THandle;

{Initialize ComVar.
 This routine is called only once
 by the initialization procedure of Tera Term.}
procedure CommInit(cv: PComVar);
begin
with cv^ do begin
  Open := FALSE;
  Ready := FALSE;

  {log-buffer variables}
  HLogBuf := 0;
  HBinBuf := 0;
  LogBuf := nil;
  BinBuf := nil;
  LogPtr := 0;
  LStart := 0;
  LCount := 0;
  BinPtr := 0;
  BStart := 0;
  BCount := 0;
  DStart := 0;
  DCount := 0;
  BinSkip := 0;
  FilePause := 0;
  ProtoFlag := FALSE;
  {message flag}
  NoMsg := 0;
end;
end;

{ reset a serial port which is already open }
procedure CommResetSerial(ts: PTTSet; cv: PComVar);
var
  dcb: TDCB;
{$ifdef TERATERM32}
  DErr: DWORD;
  ctmo: TCOMMTIMEOUTS;
{$else}
  Stat: TComStat;
  b: byte;
{$endif}
begin
with cv^ do begin
  if not Open or
     (PortType <> IdSerial) then exit;

{$ifdef TERATERM32}
  ClearCommError(ComID,DErr,nil);
  SetupComm(ComID,CommInQueSize,CommOutQueSize);
  {flush input and output buffers}
  PurgeComm(ComID, PURGE_TXABORT or PURGE_RXABORT or
    PURGE_TXCLEAR or PURGE_RXCLEAR);

  FillChar(ctmo,sizeof(ctmo),0);
  ctmo.ReadIntervalTimeout := MAXDWORD;
  ctmo.WriteTotalTimeoutConstant := 500;
  SetCommTimeouts(ComID,ctmo);
{$else}
  while GetCommError(ComID, Stat)<>0 do ;
  {flush input & output que}
  FlushComm(ComID,0);
  FlushComm(ComID,1);
{$endif}
  InBuffCount := 0;
  InPtr := 0;
  OutBuffCount := 0;
  OutPtr := 0;

  DelayPerChar := ts^.DelayPerChar;
  DelayPerLine := ts^.DelayPerLine;

{$ifdef TERATERM32}
  FillChar(dcb,sizeof(DCB),0);
  dcb.DCBlength := sizeof(DCB);
{$else}
  GetCommState(ComID,dcb);
  b := dcb.Id;
  fillchar(dcb,sizeof(dcb),0);
  dcb.Id := b;
{$endif}
  case  ts^.Baud of
    IdBaud110: dcb.BaudRate := 110;
    IdBaud300: dcb.BaudRate := 300;
    IdBaud600: dcb.BaudRate := 600;
    IdBaud1200: dcb.BaudRate := 1200;
    IdBaud2400: dcb.BaudRate := 2400;
    IdBaud4800: dcb.BaudRate := 4800;
    IdBaud9600: dcb.BaudRate := 9600;
    IdBaud14400: dcb.BaudRate := 14400;
    IdBaud19200: dcb.BaudRate := 19200;
    IdBaud38400: dcb.BaudRate := 38400;
    IdBaud57600: dcb.BaudRate := 57600;
{$ifdef TERATERM32}
    IdBaud115200: dcb.BaudRate := 115200;
{$endif}
  end;
  dcb.Flags := dcb.Flags or dcb_Binary;
  case ts^.Parity of
    IdParityEven: begin
        dcb.Flags := dcb.Flags or dcb_Parity;
        dcb.Parity := EVENPARITY;
      end;
    IdParityOdd: begin
        dcb.Flags := dcb.Flags or dcb_Parity;
        dcb.Parity := ODDPARITY;
      end;
    IdParityNone:
      dcb.Parity := NOPARITY;
  end;

{$ifdef TERATERM32}
  dcb.fDtrControl := DTR_CONTROL_ENABLE;
  dcb.fRtsControl := RTS_CONTROL_ENABLE;
{$endif}
  case ts^.Flow of
    IdFlowX: begin
        dcb.Flags := dcb.Flags or dcb_OutX;
        dcb.Flags := dcb.Flags or dcb_InX;
        dcb.XonLim := CommXonLim;
        dcb.XoffLim := CommXoffLim;
        dcb.XonChar := char(XON);
        dcb.XoffChar := char(XOFF);
      end;
    IdFlowHard: begin
        dcb.Flags := dcb.Flags or dcb_OutxCtsFlow;
{$ifdef TERATERM32}
        dcb.fRtsControl := RTS_CONTROL_HANDSHAKE;
{$else}
        dcb.CtsTimeOut := 30;
        dcb.Flags := dcb.Flags or dcb_RtsFlow;
{$endif}
      end;
  end;

  case ts^.DataBit of
    IdDataBit7: dcb.ByteSize := 7;
    IdDataBit8: dcb.ByteSize := 8;
  end;
  case ts^.StopBit of
    IdStopBit1: dcb.StopBits := ONESTOPBIT;
    IdStopBit2: dcb.StopBits := TWOSTOPBITS;
  end;
{$ifdef TERATERM32}
  SetCommState(ComID,dcb);
  {enable receive request}
  SetCommMask(ComID,0);
  SetCommMask(ComID,EV_RXCHAR);
{$else}
  SetCommState(dcb);
  {enable receive request}
  SetCommEventMask(ComID,0);
  SetCommEventMask(ComID,EV_RXCHAR);
{$endif}
end;
end;

procedure CommOpen(HW: HWnd; ts: PTTSet; cv: PComVar);
var
  COMFlag: word;
  Err: integer;
  ErrMsg: array[0..20] of Char;
  P: array[0..49] of Char;

  Msg: TMsg;
  HEntBuff: array[0..MAXGETHOSTSTRUCT-1] of char;
  addr: u_long;
  saddr: sockaddr_in;

  InvalidHost: bool;
  BBuf: bool;
begin
with cv^ do begin
  {initialize ComVar}
  InBuffCount := 0;
  InPtr := 0;
  OutBuffCount := 0;
  OutPtr := 0;
  HWin := HW;
  Ready := FALSE;
  Open := FALSE;
  PortType := ts^.PortType;
  ComPort := 0;
  RetryCount := 0;
  s := INVALID_SOCKET;
{$ifdef TERATERM32}
  ComID := INVALID_HANDLE_VALUE;
{$else}
  ComID := -1;
{$endif}
  CanSend := TRUE;
  RRQ := FALSE;
  SendKanjiFlag := FALSE;
  SendCode := IdASCII;
  EchoKanjiFlag := FALSE;
  EchoCode := IdASCII;
  Language := ts^.Language;
  CRSend := ts^.CRSend;
  KanjiCodeEcho := ts^.KanjiCode;
  JIS7KatakanaEcho := ts^.JIS7Katakana;
  KanjiCodeSend := ts^.KanjiCodeSend;
  JIS7KatakanaSend := ts^.JIS7KatakanaSend;
  KanjiIn := ts^.KanjiIn;
  KanjiOut := ts^.KanjiOut;
  RussHost := RussHost;
  RussClient := RussClient;
  DelayFlag := TRUE;
  DelayPerChar := ts^.DelayPerChar;
  DelayPerLine := ts^.DelayPerLine;
  TelBinRecv := FALSE;
  TelBinSend := FALSE;
  TelFlag := FALSE;
  TelMode := FALSE;
  IACFlag := FALSE;
  TelCRFlag := FALSE;
  TelCRSend := FALSE;
  TelCRSendEcho := FALSE;
  TelAutoDetect := TRUE; {TTPLUG}

  if (ts^.PortType<>IdSerial) and (StrLen(ts^.HostName)=0) then
  begin
    PostMessage(HWin, WM_USER_COMMNOTIFY, 0, FD_CLOSE);
    exit;
  end;

  case ts^.PortType of
    IdTCPIP:
    begin
      TelFlag := ts^.Telnet>0;
      if not LoadWinsock then
      begin
        if cv^.NoMsg=0 then
          MessageBox(HWin,'Cannot use winsock',ErrorCaption,
            MB_TASKMODAL or MB_ICONEXCLAMATION);
        InvalidHost := TRUE;
      end
      else begin
        TTXOpenTCP; {TTPLUG}
        Open := TRUE;
        if (ts^.HostName[0] >= #$30) and (ts^.HostName[0] <= #$39)
        then begin
          addr := inet_addr(ts^.HostName);
          InvalidHost := addr = $ffffffff;
        end
        else begin
          HAsync := WSAAsyncGetHostByName(HWin,WM_USER_GETHOST,
            ts^.HostName,HEntBuff,sizeof(HEntBuff));
          if HAsync=0 then
            InvalidHost := TRUE
          else begin
            ComPort := 1; {set "getting host" flag}
                          {see vtwin.pas}
            repeat {loop until the host address is retrieved}
             if GetMessage(Msg,0,0,0) then
              begin
                if (Msg.hwnd = HW) and
                   ((Msg.message = WM_SYSCOMMAND) and
                    ((Msg.wParam and $fff0) = SC_CLOSE) or
		    (Msg.message = WM_COMMAND) and
		    (LOWORD(Msg.wParam) = ID_FILE_EXIT) or
		    (Msg.message = WM_CLOSE)) then
                begin {Exit when the user closes Tera Term}
		  WSACancelAsyncRequest(HAsync);
                  HAsync := 0;
                  ComPort := 0; {clear "getting host" flag}
                  PostMessage(HWin,Msg.message,Msg.wParam,Msg.lParam);
                  exit;
                end;
                if Msg.message<>WM_USER_GETHOST then
                begin {Prosess messages}
                  TranslateMessage(Msg);
                  DispatchMessage(Msg);
                end;
              end
              else begin
                exit;
              end;
            until Msg.message=WM_USER_GETHOST;
            ComPort := 0; {clear "getting host" flag}
            HAsync := 0;
            InvalidHost := WSAGETASYNCERROR(Msg.lParam) <> 0;
            if not InvalidHost then
            begin
              if PHostEnt(@HEntBuff[0])^.h_addr_list <> nil then
                move(PHostEnt(@HEntBuff[0])^.h_addr_list^[0],addr,SizeOf(addr))
              else
                InvalidHost := TRUE;
            end;
          end;
        end;

        if InvalidHost then
        begin
          if cv^.NoMsg=0 then
            MessageBox(HWin,'Invalid host',ErrorCaption,
              MB_TASKMODAL or MB_ICONEXCLAMATION)
        end
        else begin
          s:= _socket(AF_INET,SOCK_STREAM,IPPROTO_TCP);
          if s=INVALID_SOCKET then
          begin
            InvalidHost := TRUE;
            if cv^.NoMsg=0 then
              MessageBox(HWin,ErrorCantConn,ErrorCaption,
                MB_TASKMODAL or MB_ICONEXCLAMATION)
          end
          else begin
            BBuf := TRUE;
            setsockopt(s,SOL_SOCKET,SO_OOBINLINE,@BBuf,sizeof(BBuf));

            WSAAsyncSelect(s,HWin,WM_USER_COMMOPEN,FD_CONNECT);
            saddr.sin_family := AF_INET;
            saddr.sin_port := htons(ts^.TCPPort);
            saddr.sin_addr.s_addr := addr;
            fillchar(saddr.sin_zero[0],8,#0);

            Err := connect(s,SockAddr(saddr),SizeOf(saddr));
            if Err<>0 then Err := WSAGetLastError;
            if Err=WSAEWOULDBLOCK then
            begin
              {Do nothing}
            end
            else if Err<>0 then
              PostMessage(HWin, WM_USER_COMMOPEN,0,
                          MAKELONG(FD_CONNECT,Err));
          end;
        end;
      end;
    end;

    IdSerial:
    begin
      StrCopy(P,'COM');
      uint2str(ts^.ComPort,@P[3],2);
{$ifdef TERATERM32}
      strcpy(ErrMsg,P);
      strcpy(P,'\\.\');
      strcat(P,ErrMsg);
      ComID := CreateFile(P,GENERIC_READ or GENERIC_WRITE,
        0,nil,OPEN_EXISTING,
        FILE_FLAG_OVERLAPPED,0);
      if ComID=INVALID_HANDLE_VALUE then
{$else}
      ComID := OpenComm(P,CommInQueSize,CommOutQueSize);
      if ComID < 0 then
{$endif}
      begin
        StrCopy(ErrMsg,'Cannot open ');
{$ifdef TERATERM32}
        StrCat(ErrMsg,@P[4]);
{$else}
        StrCat(ErrMsg,P);
{$endif}
        if cv^.NoMsg=0 then
          MessageBox(HWin,ErrMsg,ErrorCaption,
            MB_TASKMODAL or MB_ICONEXCLAMATION);
        InvalidHost := TRUE;
      end
      else begin
        Open := TRUE;
        ComPort := ts^.ComPort;
        CommResetSerial(ts,cv);

        {notify to VT window that Comm Port is open}
        PostMessage(HWin, WM_USER_COMMOPEN, 0, 0);
{$ifndef TERATERM32}
        {disable comm notification}
        EnableCommNotification(ComID,0,-1,-1);
{$endif}
        InvalidHost := FALSE;

        COMFlag := GetCOMFlag;
        COMFlag := COMFlag or (1 shl (ts^.ComPort-1));
        SetComFlag(ComFlag);
      end;
    end;

    IdFile:
    begin
{$ifdef TERATERM32}
      ComID := CreateFile(ts^.HostName,GENERIC_READ,0,nil,
        OPEN_EXISTING,0,0);
      InvalidHost := ComID=INVALID_HANDLE_VALUE;
{$else}
      ComID := _lopen(ts^.HostName,0);
      InvalidHost := ComID<=0;
{$endif}
      if InvalidHost then
      begin
        if cv^.NoMsg=0 then
          MessageBox(HWin,'Cannot open file',ErrorCaption,
            MB_TASKMODAL or MB_ICONEXCLAMATION)
      end
      else begin
        Open := TRUE;
        PostMessage(HWin, WM_USER_COMMOPEN, 0, 0);
      end;
    end;

  end;

  if InvalidHost then
  begin
    PostMessage(HWin, WM_USER_COMMNOTIFY, 0, FD_CLOSE);
    if (ts^.PortType=IdTCPIP) and Open then
    begin
      if s<>INVALID_SOCKET then closesocket(s);
      FreeWinsock;
    end;
    exit;
  end;
end;
end;

{$ifdef TERATERM32}
procedure CommThread(arg: pointer);
var
  Evt: DWORD;
  cv: PComVar;
  DErr: DWORD;
  REnd: THANDLE;
  Temp: array[0..19] of char;
begin
  cv := PComVar(arg);

  strcopy(Temp,READENDNAME);
  int2str(cv^.ComPort,@Temp[strlen[Temp]],2);
  REnd := OpenEvent(EVENT_ALL_ACCESS,FALSE, Temp);
  while TRUE do
  begin
    if WaitCommEvent(cv^.ComID,Evt,nil) then
    begin
      if not cv^.Ready then _endthread();
      if not cv^.RRQ then
        PostMessage(cv^.HWin, WM_USER_COMMNOTIFY, 0, FD_READ);
      WaitForSingleObject(REnd,INFINITE);
    end
    else begin
      if not cv^.Ready then _endthread();
      ClearCommError(cv^.ComID,DErr,nil);
    end;
  end;
end;
{$endif}

procedure CommStart(cv: PComVar; lParam: longint);
var
  ErrMsg: array[0..30] of char;
{$ifdef TERATERM32}
  Temp: array[0..19] of char;
{$else}
  Stat: TComStat;
{$endif}
begin
with cv^ do begin
  if not Open then exit;
  if Ready then exit;
  case PortType of
    IdTCPIP:
      begin
        ErrMsg[0] := #0;
        case HIWORD(lParam) of
          WSAECONNREFUSED: StrCopy(ErrMsg,'Connection refused');
          WSAENETUNREACH: StrCopy(ErrMsg,'Network cannot be reached');
          WSAETIMEDOUT: StrCopy(ErrMsg,'Connection timed out');
        else
          StrCopy(ErrMsg,ErrorCantConn);
        end;
        if HIWORD(lParam)>0 then
        begin
          if cv^.NoMsg=0 then
            MessageBox(HWin,ErrMsg,ErrorCaption,
              MB_TASKMODAL or MB_ICONEXCLAMATION);
          PostMessage(HWin, WM_USER_COMMNOTIFY, 0, FD_CLOSE);
          exit;
        end;
        WSAAsyncSelect(s,HWin,WM_USER_COMMNOTIFY, FD_READ or FD_OOB or FD_CLOSE);
        TCPIPClosed := FALSE;
      end;
    IdSerial:
      begin
{$ifdef TERATERM32}
        int2str(cv->ComPort,Temp2,2);
        strcopy(Temp,READENDNAME);
        strcat(Temp,Temp2);
        REnd := CreateEvent(0,FALSE,FALSE,Temp);
        strcopy(Temp,WRITENAME);
        strcat(Temp,Temp2);
        fillchar(wol,sizeof(wol),0);
        wol.hEvent := CreateEvent(0,TRUE,TRUE,Temp);
        strcopy(Temp,READNAME);
        strcat(Temp,Temp2);
        fillchar(rol,sizeof(rol),0);
        rol.hEvent := CreateEvent(0,TRUE,FALSE,Temp);

        {create the receiver thread}
        if beginthread(CommThread,0,cv)=-1 then {?????}
          MessageBox(HWin,'Can''t create thread',ErrorCaption,
            MB_TASKMODAL or MB_ICONEXCLAMATION);
{$else}
        {flush input que}
        while GetCommError(ComID, Stat)<>0 do ;
        FlushComm(ComID,1);
        {enable receive request}
        SetCommEventMask(ComID,EV_RXCHAR);
        EnableCommNotification(ComID,HWin,-1,-1);
        GetCommEventMask(ComID,EV_RXCHAR);
{$endif}
      end;
    IdFile: RRQ := TRUE;
  end;
  Ready := TRUE;
end;
end;

function CommCanClose(cv: PComVar): BOOL;
{check if data remains in buffer}
begin
with cv^ do begin 
  if not Open then
  begin
    CommCanClose := TRUE;
    exit;
  end;
  CommCanClose := FALSE;
  if InBuffCount>0 then exit;
  if (HLogBuf<>0) and
     ((LCount>0) or (DCount>0)) then exit;
  if (HBinBuf<>0) and
     (BCount>0) then exit;
  CommCanClose := TRUE;
end;
end;

procedure CommClose(cv: PComVar);
var
  COMFlag: word;
begin
with cv^ do begin
  if not Open then exit;
  Open := FALSE;

  {disable event message posting & flush buffer}
  RRQ := FALSE;
  Ready := FALSE;
  InPtr := 0;
  InBuffCount := 0;
  OutPtr := 0;
  OutBuffCount := 0;

  {close port & release resources}
  case PortType of
    IdTCPIP:
      begin
        if HAsync<>0 then
          WSACancelAsyncRequest(HAsync);
        HAsync := 0;
        if s<>INVALID_SOCKET then
          closesocket(s);
        s := INVALID_SOCKET;
        TTXCloseTCP; {TTPLUG}
        FreeWinsock;
      end;
    IdSerial:
{$ifdef TERATERM32}
      if ComID<>INVALID_HANDLE_VALUE then
      begin
        CloseHandle(ReadEnd);
        CloseHandle(wol.hEvent);
        CloseHandle(rol.hEvent);
        PurgeComm(ComID,
          PURGE_TXABORT or PURGE_RXABORT or
          PURGE_TXCLEAR or PURGE_RXCLEAR);
        EscapeCommFunction(ComID,CLRDTR);
        SetCommMask(ComID,0);
        CloseHandle(ComID);
{$else}           
      if ComID >= 0 then
      begin
        FlushComm(ComID,0);
        FlushComm(ComID,1);
        EscapeCommFunction(ComID,CLRDTR);
        EnableCommNotification(ComID,0,-1,-1) ;
        CloseComm(ComID);
{$endif}
        COMFlag := GetCOMFlag;
        COMFlag := ComFlag and not (1 shl (cv^.ComPort-1));
        SetCOMFlag(COMFlag);
      end;
    IdFile:
{$ifdef TERATERM32}
      if ComID<>INVALID_HANDLE_VALUE then
        CloseHandle(ComID);
{$else}
      if ComID > 0 then
        _lclose(ComID);
{$endif}
  end;
  ComID := -1;
  PortType := 0;
end;
end;

procedure CommProcRRQ(cv: PComVar);
var
{$ifndef TERATERM32}
  Stat: TComStat;
{$endif}
begin
with cv^ do begin
  if not Ready then exit;
  {disable receive request}
  case PortType of
    IdTCPIP:
      if not TCPIPClosed then
      WSAAsyncSelect(s,HWin,WM_USER_COMMNOTIFY, FD_OOB or FD_CLOSE);
    IdSerial:
      begin
{$ifndef TERATERM32}
        EnableCommNotification(ComID,0,-1,-1);
        while GetCommError(ComID, Stat)<>0 do ;
{$endif}
      end;
  end;
  RRQ := TRUE;
  CommReceive(cv);
end;
end;

procedure CommReceive(cv: PComVar);
var
{$ifdef TERATERM32}
  C: DWORD;
  DErr: DWORD;
{$else}
  C: integer;
  Stat: TComStat;
{$endif}
begin
with cv^ do begin
  if not Ready or not RRQ or
     (InBuffCount>=InBuffSize) then exit;

  {Compact buffer}
  if (InBuffCount>0) and (InPtr>0) then
  begin
    Move(InBuff[InPtr],InBuff[0],InBuffCount);
    InPtr := 0;
  end;

  if InBuffCount<InBuffSize then
  begin
    case PortType of
      IdTCPIP:
        begin
          C := recv(s, @InBuff[InBuffCount], InBuffSize-InBuffCount, 0);
          if C=SOCKET_ERROR then
          begin
            C := 0;
            WSAGetLastError;
          end;
          InBuffCount := InBuffCount + C;
        end;
      IdSerial:
{$ifdef TERATERM32}
        begin
          repeat
            ClearCommError(ComID,DErr,nil);
            if not ReadFile(ComID,@InBuff[InBuffCount]),
              InBuffSize,-InBuffCount,C,rol) then
            begin
              if GetLastError=ERROR_IO_PENDING then
              begin
                if WaitForSingleObject(rol.hEvent, 1000) <> WAIT_OBJECT_0) then
                  C := 0
                else
                  GetOverlappedResult(ComID,rol,C,FALSE);
              end
              else
                C := 0;
            end;
            InBuffCount := InBuffCount + C;
          until (C=0) or (InBuffCount>=InBuffSize);
          ClearCommError(ComID,DErr,nil);
        end;
{$else}                
        repeat
          C := ReadComm(ComID, @InBuff[InBuffCount], InBuffSize-InBuffCount);
          C := abs(C);
          while GetCommError(ComID, Stat)<>0 do ;
          InBuffCount := InBuffCount + C;
        until (C=0) or (InBuffCount>=InBuffSize);
{$endif}
      IdFile:
        begin
{$ifdef TERATERM32}
          ReadFile(ComID,@InBuff[InBuffCount],
            InBuffSize-InBuffCount,C,nil);
{$else}
          C := _lread(ComID, @InBuff[InBuffCount], InBuffSize-InBuffCount);
{$endif}
          InBuffCount := InBuffCount + C;
        end;
    end;
  end;

  if InBuffCount=0 then
  begin
    case PortType of
      IdTCPIP:
        if not TCPIPClosed then
        WSAAsyncSelect(s,HWin,WM_USER_COMMNOTIFY, FD_READ or FD_OOB or FD_CLOSE);
      IdSerial:
        begin
{$ifdef TERATERM32}
          RRQ := FALSE;
          SetEvent(ReadEnd);
{$else}
          while GetCommError(ComID, Stat)<>0 do ;
          EnableCommNotification(ComID,HWin,-1,-1);
          GetCommEventMask(ComID,EV_RXCHAR);
{$endif}
        end;
      IdFile: PostMessage(HWin, WM_USER_COMMNOTIFY, 0, FD_CLOSE);
    end;
    RRQ := FALSE;
  end;

end;
end;

procedure CommSend(cv: PComVar);
var
  C, D, Max, delay: integer;
  Stat: TComStat;
  LineEnd: byte;
{$ifdef TERATERM32}
  DErr: DWORD;
{$endif}
begin
with cv^ do begin
  if not Open or not Ready then
  begin
    OutBuffCount := 0;
    exit;
  end;

  if (OutBuffCount=0) or not CanSend then exit;

  {Max num of bytes to be written}
  case PortType of
    IdTCPIP: begin
        if TCPIPClosed then OutBuffCount := 0;
        Max := OutBuffCount; {winsock}
      end;
    IdSerial: begin
{$ifdef TERATERM32}
        ClearCommError(ComID,DErr,Stat);
{$else}
        GetCommError(ComID,Stat);
{$endif}
        Max := OutBuffSize - Stat.cbOutQue;
      end;
    IdFile: Max := OutBuffCount;
  end;

  if Max=0 then exit;
  if Max > OutBuffCount then Max := OutBuffCount;

  C := Max;
  delay := 0;

  if DelayFlag and (PortType=IdSerial) then
  begin
    if DelayPerLine > 0 then
    begin
      if CRSend=IdCR then LineEnd := $0d
                     else LineEnd := $0a;
      C := 1;
      if DelayPerChar=0 then
        while (C<Max) and (OutBuff[OutPtr+C-1]<>LineEnd) do
          inc(C);
      if OutBuff[OutPtr+C-1]=LineEnd then delay := DelayPerLine
                                     else delay := DelayPerChar;
    end
    else if DelayPerChar > 0 then
    begin
      C := 1;
      delay := DelayPerChar;
    end;
  end;

  {Write to comm driver/Winsock}
  case PortType of
    IdTCPIP:
      begin
        D := send(s, @OutBuff[OutPtr], C, 0);
        if D=SOCKET_ERROR then {if error occurs}
        begin
          WSAGetLastError; {Clear error}
          D := 0;
        end;
      end;
    IdSerial: begin
{$ifdef TERATERM32}
        if not WriteFile(ComID,@OutBuff[OutPtr],C,D,wol) then
        begin
          if GetLastError=ERROR_IO_PENDING then
          begin
            if WaitForSingleObject(wol.hEvent,1000)<>WAIT_OBJECT_0) then
              D := C {Time out, ignore data}
            else
              GetOberlappedResult(ComID,wol,D,FALSE);
          end
          else {I/O error}
            D := C; {ignore error}
        end;
        ClearCommError(ComID,DErr,Stat);
{$else}
        D := WriteComm(ComID, @OutBuff[OutPtr], C);
        D := abs(D);
        while GetCommError(ComID, Stat)<>0 do ;
{$endif}
      end;
    IdFile: D := C;
  end;

  OutBuffCount := OutBuffCount - D;
  if OutBuffCount=0 then
    OutPtr := 0
  else
    OutPtr := OutPtr + D;

  if (C=D) and (delay>0) then
  begin
    CanSend := FALSE;
    SetTimer(HWin, IdDelayTimer, delay, nil);
  end

end;
end;

procedure CommSendBreak(cv: PComVar);
{for only serial ports}
var
  DummyMsg: TMsg;
begin
with cv^ do begin
  if not Ready then exit;

  case PortType of
    IdSerial: begin
      {Set com port into a break state}
      SetCommBreak(ComID);

      {pause for 1sec}
      if SetTimer(HWin, IdBreakTimer, 1000, nil) <> 0 then
        GetMessage(DummyMsg,HWin,WM_TIMER,WM_TIMER);

      {Set com port into a nonbreak state}
      ClearCommBreak(ComID);
    end;
  end;
end;
end;

procedure CommLock(ts: PTTSet; cv: PComVar; Lock: BOOL);
var
  b: BYTE;
  Func: integer;
begin
with cv^ do begin
  if not Ready then exit;
  if (PortType=IdTCPIP) or
      (PortType=IdSerial) and
      (ts^.Flow<>IdFlowHard) then
  begin
    if Lock then
      b := XOFF
    else
      b := XON;
    CommBinaryOut(cv,@b,1);
  end
  else if (PortType=IdSerial) and
          (ts^.Flow=IdFlowHard) then
  begin
    if Lock then
      Func := CLRRTS
    else
      Func := SETRTS;
    EscapeCommFunction(ComID,Func);
  end;
end;
end;

function PrnOpen(DevName: PChar): BOOL;
var
  Temp: array[0..MAXPATHLEN-1] of char;
  dcb: TDCB;
{$ifdef TERATERM32}
  DErr: DWORD;
  ctmo: COMMTIMEOUTS;
{$else}
  Stat: TCOMSTAT;
{$endif}
begin
  strcopy(Temp,DevName);
  Temp[4] := #0; {COMn or LPTn}
  LPTFlag := (Temp[0]='L') or
             (Temp[0]='l');
{$ifdef TERATERM32}
  PrnID :=
    CreateFile(Temp,GENERIC_WRITE,
	       0,nil,OPEN_EXISTING,
	       0,0);
  if PrnID=INVALID_HANDLE_VALUE then
  begin
    PrnOpen := FALSE;
    exit;
  end;
  if GetCommState(PrnID,dcb) then
  begin
    BuildCommDCB(DevName,dcb);
    SetCommState(PrnID,dcb);
  end;
  ClearCommError(PrnID,DErr,nil);
  if not LPTFlag then
    SetupComm(PrnID,0,CommOutQueSize);
  {flush output buffer}
  PurgeComm(PrnID, PURGE_TXABORT or
    PURGE_TXCLEAR);
  FillChar(ctmo,sizeof(ctmo),0);
  ctmo.WriteTotalTimeoutConstant := 1000;
  SetCommTimeouts(PrnID,ctmo);
{$else}
  PrnID := OpenComm(Temp,CommInQueSize,CommOutQueSize);
  if PrnID<0 then
  begin
    PrnOpen := FALSE;
    exit;
  end;
  if GetCommState(PrnID,dcb)=0 then
  begin
    BuildCommDCB(DevName,dcb);
    SetCommState(dcb);
  end;
  GetCommError(PrnID, Stat);
  { flush output buffer }
  FlushComm(PrnID,0);
{$endif}
  if not LPTFlag then
    EscapeCommFunction(PrnID,SETDTR);
  PrnOpen := TRUE;
end;

function PrnWrite(b: PCHAR; c: integer): integer;
var
  d: integer;
{$ifdef TERATERM32}
  DErr: DWORD;
{$endif}
  Stat: TCOMSTAT;
begin
{$ifdef TERATERM32}
  if PrnID = INVALID_HANDLE_VALUE then
{$else}
  if PrnID < 0 then
{$endif}
  begin
    PrnWrite := c;
    exit;
  end;

{$ifdef TERATERM32}
  ClearCommError(PrnID,DErr,nil);
  if not LPTFLag and
     (OutBuffSize - Stat.cbOutQue < c) then
    c := OutBuffSize - Stat.cbOutQue;
  if c<=0 then
  begin
    PrnWrite := 0;
    exit;
  end;
  if not WriteFile(PrnID,b,c,@d,nil) then
    d := 0;
  ClearCommError(PrnID,DErr,nil);
{$else}
  GetCommError(PrnID,Stat);
  if OutBuffSize - Stat.cbOutQue < c then
    c := OutBuffSize - Stat.cbOutQue;
  if c=0 then
  begin
    PrnWrite := 0;
    exit;
  end;
  d := WriteComm(PrnID, b, c);
  d := abs(d);
  GetCommError(PrnID, Stat);
{$endif}
  PrnWrite := d;
end;

procedure PrnCancel;
begin
{$ifdef TERATERM32}
  PurgeComm(PrnID,
    PURGE_TXABORT or PURGE_TXCLEAR);
{$else}
  FlushComm(PrnID,0);
{$endif}
  PrnClose;
end;

procedure PrnClose;
begin
{$ifdef TERATERM32}
  if PrnID <> INVALID_HANDLE_VALUE then
  begin
    if not LPTFlag then
      EscapeCommFunction(PrnID,CLRDTR);
    CloseHandle(PrnID);
  end;
  PrnID := INVALID_HANDLE_VALUE;
{$else}
  if PrnID >= 0 then
  begin
    if not LPTFlag then
      EscapeCommFunction(PrnID,CLRDTR);
    CloseComm(PrnID);
  end;
  PrnID := -1;
{$endif}
end;

begin
  TCPIPClosed := TRUE;
{$ifdef TERATERM32}
  PrnID := INVALID_HANDLE_VALUE;
{$else}
  PrnID := -1;
{$endif}

end.
