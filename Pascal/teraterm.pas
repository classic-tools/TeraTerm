{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, main}
program TeraTerm;
{$R teraterm.res}
{$I teraterm.inc}

{$IFDEF Delphi}
uses
{$ifndef TERATERM32}
  TTCtl3d,
{$endif}
  Messages, WinTypes, WinProcs, OWindows,
  TTTypes, VTWin, TTWinMan, CommLib, Telnet, Buffer, VTTerm,
  FileSys, TEKWin, TTDDE, Clipboard;
{$ELSE}
uses
{$ifndef TERATERM32}
  TTCtl3d,
{$endif}
  WinTypes, WinProcs, WObjects,
  TTTypes, VTWin, TTWinMan, CommLib, Telnet, Buffer, VTTerm,
  FileSys, TEKWin, TTDDE, Clipboard;
{$ENDIF}

{$i tt_res.inc}

type
  TeraAppli = object(TApplication)
    procedure InitInstance; virtual;
{$ifndef TERATERM32}
    destructor Done; virtual;
{$endif}
    procedure InitMainWindow; virtual;
    procedure MessageLoop; virtual;
    {function CanClose: boolean; virtual;}
    function ProcessAccels(var Message: TMsg): Boolean; virtual;
  end;

procedure TeraAppli.InitInstance;
begin
  TApplication.InitInstance;
{$ifndef TERATERM32}
  LoadCtl3d;
{$endif}
  HAccTable := LoadAccelerators(HInstance, PChar(IDR_ACC));
end;

{$ifndef TEARTERM32}
destructor TeraAppli.Done;
begin
  FreeCtl3d;
  TApplication.Done;
end;
{$endif}

procedure TeraAppli.InitMainWindow;
begin
  MainWindow := New(PVTWindow, Init(nil));
  pVTWin := PVTWindow(MainWindow);
end;

{Tera Term main engine}
procedure TeraAppli.MessageLoop;
var
  Msg: TMsg;
  Busy: integer;
  Change, nx, ny: integer;
  Size: bool;
begin
  while TRUE do
  begin
    if GetMessage(Msg,0,0,0) then
    begin
      if not ProcessAppMsg(Msg) then
      begin
        TranslateMessage(Msg);
        DispatchMessage(Msg);
      end;
    end
    else begin
      Status := Msg.WParam;
      exit;
    end;

    Busy := 2;
    repeat
      if cv.Ready then
      begin

      {Sender}
      CommSend(@cv);

      {Parser}
      if (cv.HLogBuf<>0) and (cv.LogBuf=nil) then
        cv.LogBuf := GlobalLock(cv.HLogBuf);

      if (cv.HBinBuf<>0) and (cv.BinBuf=nil) then
        cv.BinBuf := GlobalLock(cv.HBinBuf);

      if (TelStatus=TelIdle) and cv.TelMode then
        TelStatus := TelIAC;

      if TelStatus<>TelIdle then
      begin
        ParseTel(Size,nx,ny);
        if Size then
        begin
          LockBuffer;
          ChangeTerminalSize(nx,ny);
          UnlockBuffer;
        end;
      end
      else begin
        if cv.ProtoFlag then Change := ProtoDlgParse
        else begin
          case ActiveWin of
            IdVT: Change := PVTWindow(pVTWin)^.Parse;
            IdTEK:
              if pTEKWin<>nil then
                Change := PTEKWindow(pTEKWin)^.Parse
              else
                Change := IdVT;
          else
            Change := 0;
          end;

          case Change of
            IdVT: VTActivate;
            IdTEK: pVTWindow(pVTWin)^.OpenTEK;
          end;
        end;
      end;

      if cv.LogBuf<>nil then
      begin
        if FileLog then LogToFile;
        if DDELog and AdvFlag then DDEAdv;
        GlobalUnlock(cv.HLogBuf);
        cv.LogBuf := nil;
      end;

      if cv.BinBuf<>nil then
      begin
        if BinLog then LogToFile;
        GlobalUnlock(cv.HBinBuf);
        cv.BinBuf := nil;
      end;

      {Talker}
      case TalkStatus of
        IdTalkCB: CBSend;         {clip board}
        IdTalkFile: FileSend;     {file}
      end;

      {Receiver}
      CommReceive(@cv);

      end; {of 'if cv.Ready'}

      if PeekMessage(Msg, 0, 0, 0, PM_REMOVE) then
      begin
        if Msg.Message = WM_QUIT then
        begin
          Status := Msg.WParam;
          exit;
        end;
        if not ProcessAppMsg(Msg) then
        begin
          TranslateMessage(Msg);
          DispatchMessage(Msg);
        end;
      end;

      with cv do
        if Ready and
           (RRQ or (OutBuffCount>0) or (InBuffCount>0) or
            (LCount>0) or (BCount>0) or (DCount>0)) then
          Busy := 2
        else
          dec(Busy);
    until Busy<=0;

  end;
end;

{function TeraAppli.CanClose: boolean;
begin
  CanClose := FALSE;
  if (HTEKWin<>0) and not IsWindowEnabled(HTEKWin)
  then begin
    messagebeep(0);
    exit;
  end;

  if cv.Ready and (cv.PortType=IdTCPIP) and
     (ts.ConfirmDisconn<>0) and
     (messagebox(HMainWin,'Disconnect?','Tera Term',mb_YesNo)=IdNo)
  then exit;

  CanClose := TRUE;
end;}

function TeraAppli.ProcessAccels(var Message: TMsg): Boolean;
begin
  if ts.MetaKey>0 then
    ProcessAccels := FALSE {ignore accelerator keys}
  else
    ProcessAccels := TApplication.ProcessAccels(Message);
end;

var
  Tera: TeraAppli;

begin
  Tera.Init('Tera Term');
  Tera.Run;
  Tera.Done;
end.
