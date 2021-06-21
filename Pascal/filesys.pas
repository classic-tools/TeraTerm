{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, file transfer routines}
unit FileSys;

interface
{$I teraterm.inc}

{$IFDEF Delphi}
uses
  Messages, WinTypes, WinProcs, OWindows, ODialogs, Strings,
  TTTypes, TTFTypes, TTWinMan, TTCommon, CommLib, TTLib, FTDlg, ProtoDlg;
{$ELSE}
uses
  WinTypes, WinProcs, WObjects, Win31, Strings,
  TTTypes, TTFTypes, TTWinMan, TTCommon, CommLib, TTLib, FTDlg, ProtoDlg;
{$ENDIF}


{TTFILE.DLL routines}
type
  TGetSetupFname = function(HWin: HWnd; FuncId: word; ts: PTTSet): BOOL;
  TGetTransFname = function(fv: PFileVar; CurDir: PChar; FuncId: word; Option: Plongint): BOOL;
  TGetMultiFname = function(fv: PFileVar; CurDir: PChar; FuncId: word; Option: PWord): BOOL;
  TGetGetFname = function(HWin: HWnd; fv: PFileVar): BOOL;
  TSetFileVar = procedure(fv: PFileVar);
  TGetXFname = function(HWin: HWnd; Receive: bool; Option: Plongint; fv: PFileVar; CurDir: PChar): BOOL;
  TProtoInit = procedure(Proto: integer; fv: PFileVar; pv: pointer; cv: PComVar; ts: PTTSet);
  TProtoParse = function(Proto: integer; fv: PFileVar; pv: pointer; cv: PComVar): BOOL;
  TProtoTimeOutProc = procedure(Proto: integer; fv: PFileVar; pv: pointer; cv: PComVar);
  TProtoCancel = function(Proto: integer; fv: PFileVar; pv: pointer; cv: PComVar): BOOL;

var
  {TTFILE.DLL}
  GetSetupFname: TGetSetupFname;
  GetTransFname: TGetTransFname;
  GetMultiFname: TGetMultiFname;
  GetGetFname: TGetGetFname;
  SetFileVar: TSetFileVar;
  GetXFname: TGetXFname;
  ProtoInit: TProtoInit;
  ProtoParse: TProtoParse;
  ProtoTimeOutProc: TProtoTimeOutProc;
  ProtoCancel: TProtoCancel;

function LoadTTFILE: bool;
function FreeTTFILE: bool;
function NewFileVar(var FV: PFileVar): bool;
procedure FreeFileVar(var FV: PFileVar);

{Log & DDE buffer}
procedure LogStart;
procedure Log1Byte(b: byte);
procedure LogToFile;
function CreateLogBuf: bool;
procedure FreeLogBuf;
function CreateBinBuf: bool;
procedure FreeBinBuf;

{File send}
procedure FileSendStart;
procedure FileSend;
procedure FLogChangeButton(Pause: bool);
procedure FLogRefreshNum;
procedure FileTransEnd(OpId: WORD);

{File transfer protcols}
procedure ProtoEnd;
function ProtoDlgParse: integer;
procedure ProtoDlgTimeOut;
procedure ProtoDlgCancel;
procedure KermitStart(mode: integer);
procedure XMODEMStart(mode: integer);
procedure ZMODEMStart(mode: integer);
procedure BPStart(mode: integer);
procedure QVStart(mode: integer);

var
  LogVar, SendVar, FileVar: PFileVar;
  FileLog, BinLog, DDELog: bool;

implementation

uses TTDDE;
{$i helpid.inc}

var
  ProtoVar: pointer;
  ProtoId: integer;

  LogLast: byte;

  FileRetrySend, FileRetryEcho, FileCRSend: bool;
  FileByte: byte;

  FSend: bool;

  HTTFILE: THandle;
  TTFILECount: integer;

const
  IdGetSetupFname  = 1;
  IdGetTransFname  = 2;
  IdGetMultiFname  = 3;
  IdGetGetFname    = 4;
  IdSetFileVar     = 5;
  IdGetXFname      = 6;

  IdProtoInit      = 7;
  IdProtoParse     = 8;
  IdProtoTimeOutProc = 9;
  IdProtoCancel    = 10;

function LoadTTFILE: bool;
var
  Err: boolean;
begin
{$ifdef TERATERM32}
  if HTTFILE <> 0 then
{$else}
  if HTTFILE >= HINSTANCE_ERROR then
{$endif}
  begin
    inc(TTFILECount);
    LoadTTFILE := TRUE;
    exit;
  end
  else begin
    LoadTTFILE := FALSE;
    TTFILECount := 0;
  end;

{$ifdef TERATERM32}
  HTTFILE := LoadLibrary('TTPFILE.DLL');
  if HTTFILE=0 then exit;
{$else}   
  HTTFILE := LoadLibrary('TTFILE.DLL');
  if HTTFILE < HINSTANCE_ERROR then exit;
{$endif}

  Err := FALSE;
  @GetSetupFname := GetProcAddress(HTTFILE, PChar(IdGetSetupFname));
  if @GetSetupFname=nil then Err := TRUE;

  @GetTransFname := GetProcAddress(HTTFILE, PChar(IdGetTransFname));
  if @GetTransFname=nil then Err := TRUE;

  @GetMultiFname := GetProcAddress(HTTFILE, PChar(IdGetMultiFname));
  if @GetMultiFname=nil then Err := TRUE;

  @GetGetFname := GetProcAddress(HTTFILE, PChar(IdGetGetFname));
  if @GetGetFname=nil then Err := TRUE;

  @SetFileVar := GetProcAddress(HTTFILE, PChar(IdSetFileVar));
  if @SetFileVar=nil then Err := TRUE;

  @GetXFname := GetProcAddress(HTTFILE, PChar(IdGetXFname));
  if @GetXFname=nil then Err := TRUE;

  @ProtoInit := GetProcAddress(HTTFILE, PChar(IdProtoInit));
  if @ProtoInit=nil then Err := TRUE;

  @ProtoParse := GetProcAddress(HTTFILE, PChar(IdProtoParse));
  if @ProtoParse=nil then Err := TRUE;

  @ProtoTimeOutProc := GetProcAddress(HTTFILE, PChar(IdProtoTimeOutProc));
  if @ProtoTimeOutProc=nil then Err := TRUE;

  @ProtoCancel := GetProcAddress(HTTFILE, PChar(IdProtoCancel));
  if @ProtoCancel=nil then Err := TRUE;

  if Err then
  begin
    FreeLibrary(HTTFILE);
    HTTFILE := 0;
  end
  else begin
    TTFILECount := 1;
    LoadTTFILE := TRUE;
  end;
end;

function FreeTTFILE: bool;
begin
  FreeTTFILE := FALSE;
  if TTFILECount=0 then exit;
  FreeTTFILE := TRUE;
  dec(TTFILECount);
  if TTFILECount>0 then exit;
{$ifdef TERATERM32}
  if HTTFILE<>0 then
{$else}
  if HTTFILE>=HINSTANCE_ERROR then
{$endif}
  begin
    FreeLibrary(HTTFile);
    HTTFILE := 0;
  end;
end;

var
  FLogDlg: PFileTransDlg;
  SendDlg: PFileTransDlg;
  PtDlg: PProtoDlg;

function OpenFTDlg(fv: PFileVar): bool;
var
  FTDlg: PFileTransDlg;
begin
  FTDlg := PFileTransDlg(Application^.MakeWindow(
    New(PFileTransDlg,Init(fv,@cv)) ));
  if FTDlg<>nil then
  begin
    FTDlg^.RefreshNum;
    if fv^.OpId=OpLog then
      ShowWindow(FTDlg^.HWindow,SW_MINIMIZE);
  end;

  if fv^.OpId=OpLog then
    FLogDlg := FTDlg {Log}
  else
    SendDlg := FTDlg; {File send}

  OpenFTDlg := FTDlg<>nil;
end;

function NewFileVar(var fv: PFileVar): bool;
begin
  if fv=nil then
  begin
    New(fv);
    if fv<>nil then
    begin
      with fv^ do
      begin        
        FillChar(fv^, SizeOf(TFileVar), #0);        
        StrCopy(FullName,ts.FileDir);
        AppendSlash(FullName);
        DirLen := StrLen(FullName);
        FileOpen := FALSE;
        OverWrite := (ts.FTFlag and FT_RENAME = 0);
        HMainWin := HVTWin;
        Success := FALSE;
        NoMsg := FALSE;
      end;
    end;
  end;

  NewFileVar := fv<>nil;
end;

procedure FreeFileVar(var fv: PFileVar);
begin
  if fv<>nil then
  begin
    with fv^ do begin
      if FileOpen then _lclose(FileHandle);
      if FnStrMemHandle>0 then
      begin
        GlobalUnlock(FnStrMemHandle);
        GlobalFree(FnStrMemHandle);
      end;
    end;
    Dispose(fv);
    fv := nil;
  end;
end;

procedure LogStart;
var
  Option: longint;
begin
  if (FileLog) or (BinLog) then exit;

  if not LoadTTFILE then exit;
  if not NewFileVar(LogVar) then
  begin
    FreeTTFILE;
    exit;
  end;
  LogVar^.OpId := OpLog;

  if (StrLen(@LogVar^.FullName[LogVar^.DirLen])=0) then
  begin
    Option := MakeLong(ts.TransBin,ts.Append);
    if not GetTransFname(LogVar, ts.FileDir, GTF_LOG, @Option) then
    begin
      FreeFileVar(LogVar);
      FreeTTFile;
      exit;
    end;
    ts.TransBin := LOWORD(Option);
    ts.Append := HIWORD(Option);
  end
  else
    SetFileVar(LogVar);

  if ts.TransBin > 0 then
  begin
    BinLog := TRUE;
    FileLog := TRUE;
    if not CreateBinBuf then
    begin
      FileTransEnd(OpLog);
      exit;
    end;
  end
  else begin
    BinLog := FALSE;
    FileLog := TRUE;
    if not CreateLogBuf then
    begin
      FileTransEnd(OpLog);
      exit;
    end;
  end;
  cv.LStart := cv.LogPtr;
  cv.LCount := 0;
  HelpId := HlpFileLog;

  with LogVar^ do
  begin
    if ts.Append > 0 then
    begin
      FileHandle := _lopen(FullName,OF_WRITE);
      if FileHandle>0 then
        _llseek(FileHandle,0,2)
      else
        FileHandle := _lcreat(FullName,0);
    end
    else
      FileHandle := _lcreat(FullName,0);
    FileOpen := FileHandle>0;
    if not FileOpen then
    begin
      FileTransEnd(OpLog);
      exit;
    end;
    ByteCount := 0;
  end;

  if not OpenFTDlg(LogVar) then
    FileTransEnd(OpLog);
end;

procedure LogPut1(b: byte);
begin
with cv do begin
  LogLast := b;
  LogBuf[LogPtr] := char(b);
  inc(LogPtr);
  if LogPtr>=InBuffSize then
    LogPtr := LogPtr-InBuffSize;

  if FileLog then
  begin
    if LCount>=InBuffSize then
    begin
      LCount := InBuffSize;
      LStart := LogPtr;
    end
    else inc(LCount);
  end
  else
    LCount := 0;

  if DDELog then
  begin
    if DCount>=InBuffSize then
    begin
      DCount := InBuffSize;
      DStart := LogPtr;
    end
    else inc(DCount);
  end
  else
    DCount := 0;
end;
end;

procedure Log1Byte(b: byte);
begin
  if b=$0d then
  begin
    LogLast := b;
    exit;
  end;
  if (b=$0a) and (LogLast=$0d) then
    LogPut1($0d);
  LogPut1(b);
end;

procedure LogToFile;

  function Get1(Buf: PChar; var Start, Count: integer; var b: byte): boolean;
  begin
    if Count>0 then
      Get1 := TRUE
    else begin
      Get1 := FALSE;
      exit;
    end;
    b := byte(Buf[Start]);
    inc(Start);
    if Start>=InBuffSize then
      Start := Start-InBuffSize;
    dec(Count);
  end;

var
  Buf: PChar;
  Start, Count: integer;
  b: byte;
begin
with cv do begin
  if not LogVar^.FileOpen then exit;
  if FileLog then
  begin
    Buf := LogBuf;
    Start := LStart;
    Count := LCount;
  end
  else if BinLog then
  begin
    Buf := BinBuf;
    Start := BStart;
    Count := BCount;
  end
  else
    exit;

  if Buf=nil then exit;
  if Count=0 then exit;

  while Get1(Buf,Start,Count,b) do
  begin
    if (FilePause and OpLog = 0) and not ProtoFlag then
    begin
      _lwrite(LogVar^.FileHandle,@b,1);
      inc(LogVar^.ByteCount);
    end;
  end;

  if FileLog then
  begin
    LStart := Start;
    LCount := Count;
  end
  else begin
    BStart := Start;
    BCount := Count;
  end;
  if (FilePause and OpLog <>0) or ProtoFlag then exit;
  if FLogDlg<>nil then
    FLogDlg^.RefreshNum;
end;
end;

function CreateLogBuf: bool;
begin
  with cv do begin
    if HLogBuf=0 then
    begin
      HLogBuf := GlobalAlloc(GMEM_MOVEABLE,InBuffSize);
      LogBuf := nil;
      LogPtr := 0;
      LStart := 0;
      LCount := 0;
      DStart := 0;
      DCount := 0;
    end;
    CreateLogBuf := (HLogBuf<>0);
  end;
end;

procedure FreeLogBuf;
begin
  with cv do begin
    if (HLogBuf=0) or FileLog or DdeLog then exit;
    if LogBuf<>nil then GlobalUnlock(HLogBUf);
    GlobalFree(HLogBuf);
    HLogBuf := 0;
    LogBuf := nil;
    LogPtr := 0;
    LStart := 0;
    LCount := 0;
    DStart := 0;
    DCount := 0;
  end;
end;

function CreateBinBuf: bool;
begin
  with cv do begin
    if HBinBuf=0 then
    begin
      HBinBuf := GlobalAlloc(GMEM_MOVEABLE,InBuffSize);
      BinBuf := nil;
      BinPtr := 0;
      BStart := 0;
      BCount := 0;
    end;
    CreateBinBuf := (HBinBuf<>0);
  end;
end;

procedure FreeBinBuf;
begin
  with cv do begin
    if (HBinBuf=0) or BinLog then exit;
    if BinBuf<>nil then GlobalUnlock(HBinBUf);
    GlobalFree(HBinBuf);
    HBinBuf := 0;
    BinBuf := nil;
    BinPtr := 0;
    BStart := 0;
    BCount := 0;
  end;
end;

procedure FileSendStart;
var
  Option: longint;
begin
  if not cv.Ready or FSend then exit;
  if cv.ProtoFlag then
  begin
    FreeFileVar(SendVar);
    exit;
  end;

  if not LoadTTFILE then exit;
  if not NewFileVar(SendVar) then
  begin
    FreeTTFILE;
    exit;
  end;
  SendVar^.OpId := OpSendFile;

  FSend := TRUE;

  if (StrLen(@SendVar^.FullName[SendVar^.DirLen])=0) then
  begin
    Option := MAKELONG(ts.TransBin,0);
    if not GetTransFname(SendVar, ts.FileDir, GTF_SEND, @Option) then
    begin
      FileTransEnd(OpSendFile);
      exit;
    end;
    ts.TransBin := LOWORD(Option);
  end
  else
    SetFileVar(SendVar);

  with SendVar^ do
  begin
    FileHandle := _lopen(FullName,OF_READ);
    FileOpen := FileHandle>0;
    if not FileOpen then
    begin
      FileTransEnd(OpSendFile);
      exit;
    end;
    ByteCount := 0;
  end;

  TalkStatus := IdTalkFile;
  FileRetrySend := FALSE;
  FileRetryEcho := FALSE;
  FileCRSend := FALSE;

  if not OpenFTDlg(SendVar) then
    FileTransEnd(OpSendFile);
end;

procedure FileTransEnd(OpId: WORD);
{ OpId  = 0: close Log and FileSend
      OpLog: close Log
 OpSendFile: close FileSend }
begin
  if ((OpId=0) or (OpId=OpLog)) and
      (FileLog or BinLog) then
  begin
    FileLog := FALSE;
    BinLog := FALSE;
    if FLogDlg<>nil then
    begin
      FLogDlg^.CloseWindow;
      FlogDlg := nil;
    end;
    FreeFileVar(LogVar);
    FreeLogBuf;
    FreeBinBuf;
    FreeTTFILE;
  end;

  if ((OpId=0) or (OpId=OpSendFile)) and
      FSend then
  begin
    FSend := FALSE;
    TalkStatus := IdTalkKeyb;
    if SendDlg<>nil then
    begin
      SendDlg^.CloseWindow;
      SendDlg := nil;
    end;
    FreeFileVar(SendVar);
    FreeTTFILE;
  end;

  EndDdeCmnd(0);
end;

procedure FileSend;

  function Out1(b: byte): integer;
  begin
    if ts.TransBin > 0 then
      Out1 := CommBinaryOut(@cv,@b,1)
    else if (b>=$20) or (b=$09) or (b=$0A) or (b=$0D) then
      Out1 := CommTextOut(@cv,@b,1)
    else
      Out1 := 1;
  end;

  function Echo1(b: byte): integer;
  begin
    if ts.TransBin > 0 then
      Echo1 := CommBinaryEcho(@cv,@b,1)
    else
      Echo1 := CommTextEcho(@cv,@b,1);
  end;

var
  c, fc: word;
  BCOld: longint;
begin
  if (SendDlg=nil) or
     (cv.FilePause and OpSendFile <>0) then exit;

  BCOld := SendVar^.ByteCount;

  if FileRetrySend then
  begin
    FileRetryEcho := ts.LocalEcho>0;
    c := Out1(FileByte);
    FileRetrySend := c=0;
    if FileRetrySend then exit;
  end;

  if FileRetryEcho then
  begin
    c := Echo1(FileByte);
    FileRetryEcho := c=0;
    if FileRetryEcho then exit;
  end;

  repeat
    fc := _lread(SendVar^.FileHandle,@FileByte,1);
    SendVar^.ByteCount := SendVar^.ByteCount + fc;

    if FileCRSend and (fc=1) and (FileByte=$0A) then
    begin
      fc := _lread(SendVar^.FileHandle,@FileByte,1);
      SendVar^.ByteCount := SendVar^.ByteCount + fc;
    end;

    if fc<>0 then
    begin
      c := Out1(FileByte);
      FileCRSend := (ts.TransBin=0) and (FileByte=$0D);
      FileRetrySend := c=0;
      if FileRetrySend then
      begin
        if SendVar^.ByteCount<>BCOld then
          SendDlg^.RefreshNum;
        exit;
      end;
      if ts.LocalEcho>0 then
      begin
        c := Echo1(FileByte);
        FileRetryEcho := c=0;
        if FileRetryEcho then exit;
      end;
    end;
    if (fc=0) or (SendVar^.ByteCount mod 100 = 0) then
    begin
      SendDlg^.RefreshNum;
      BCOld := SendVar^.ByteCount;
      if fc<>0 then exit;
    end;
  until fc=0;

  FileTransEnd(OpSendFile);
end;

procedure FLogChangeButton(Pause: bool);
begin
  if FLogDlg<>nil then
    FLogDlg^.ChangeButton(Pause);
end;

procedure FLogRefreshNum;
begin
  if FLogDlg<>nil then
    FLogDlg^.RefreshNum;
end;

function OpenProtoDlg(fv: PFileVar; IdProto, Mode: integer; Opt1, Opt2: WORD): BOOL;
var
  vsize: integer;
  pd: PProtoDlg;
begin
  ProtoId := IdProto;

  case ProtoId of
    PROTO_KMT: vsize := sizeof(TKmtVar);
    PROTO_XM:  vsize := sizeof(TXVar);
    PROTO_ZM:  vsize := sizeof(TZVar);
    PROTO_BP:  vsize := sizeof(TBPVar);
    PROTO_QV:  vsize := sizeof(TQVVar);
  end;
  GetMem(ProtoVar, vsize);
  if ProtoVar=nil then exit;

  case ProtoId of
    PROTO_KMT:
      PKmtVar(ProtoVar)^.KmtMode := Mode;
    PROTO_XM: begin
      PXVar(ProtoVar)^.XMode := Mode;
      PXVar(ProtoVar)^.XOpt := Opt1;
      PXVar(ProtoVar)^.TextFlag := 1 - (Opt2 and 1);
    end;
    PROTO_ZM: begin
      PZVar(ProtoVar)^.BinFlag := (Opt1 and 1) <> 0;
      PZVar(ProtoVar)^.ZMode := Mode;
    end;
    PROTO_BP:
      PBPVar(ProtoVar)^.BPMode := Mode;
    PROTO_QV:
      PQVVar(ProtoVar)^.QVMode := Mode;
  end;
  
  pd := PProtoDlg(Application^.MakeWindow(
    New(PProtoDlg,Init(fv)) ));
  if pd=nil then
  begin
    Dispose(ProtoVar);
    ProtoVar := nil;
    exit;
  end;
  ProtoInit(ProtoId,FileVar,ProtoVar,@cv,@ts);

  PtDlg := pd;
  OpenProtoDlg := TRUE;
end;

procedure CloseProtoDlg;
begin
  if PtDlg <> nil then
  begin
    PtDlg^.CloseWindow;
    PtDlg := nil;

    KillTimer(FileVar^.HMainWin,IdProtoTimer);
    if (ProtoId=PROTO_QV) and
       (PQVVar(ProtoVar)^.QVMode=IdQVSend) then
      CommTextOut(@cv,#$0D,1);
    if FileVar^.LogFlag then
      _lclose(FileVar^.LogFile);
    FileVar^.LogFile := 0;
    if ProtoVar<>nil then
    begin
      Dispose(ProtoVar);
      ProtoVar := nil;
    end;
  end;   
end;

function ProtoStart: bool;
begin
  ProtoStart := FALSE;
  if cv.ProtoFlag then exit;
  if FSend then
  begin
    FreeFileVar(FileVar);
    exit;
  end;

  if not LoadTTFILE then exit;
  NewFileVar(FileVar);

  if FileVar=nil then
  begin
    FreeTTFile;
    exit;
  end;
  cv.ProtoFlag := TRUE;
  ProtoStart := TRUE;
end;

procedure ProtoEnd;
begin
  if not cv.ProtoFlag then exit;
  cv.ProtoFlag := FALSE;

  {Enable transmit delay (serial port)}
  cv.DelayFlag := TRUE;
  TalkStatus := IdTalkKeyb;

  CloseProtoDlg;

  if (FileVar<>nil) and
     FileVar^.Success then
    EndDdeCmnd(1)
  else
    EndDdeCmnd(0);

  FreeTTFILE;
  FreeFileVar(FileVar);
end;

function ProtoDlgParse: integer;
begin
  ProtoDlgParse := ActiveWin;
  if PtDlg = nil then exit;

  if ProtoParse(ProtoId,FileVar,ProtoVar,@cv) then
    ProtoDlgParse := 0 {continue}
  else begin
    CommSend(@cv);
    ProtoEnd;
  end;
end;

procedure ProtoDlgTimeOut;
begin
  if PtDlg <> nil then
    ProtoTimeOutProc(ProtoId,FileVar,ProtoVar,@cv);
end;

procedure ProtoDlgCancel;
begin
  if (PtDlg<>nil) and
     ProtoCancel(ProtoId,FileVar,ProtoVar,@cv) then
    ProtoEnd;
end;

procedure KermitStart(mode: integer);
var
  w: word;
begin
  if not ProtoStart then exit;

  case mode of
    IdKmtSend: begin
        FileVar^.OpId := OpKmtSend;
        if (StrLen(@FileVar^.FullName[FileVar^.DirLen])=0) then
        begin
          if not GetMultiFname(FileVar,ts.FileDir,GMF_KERMIT,@W) or
            (FileVar^.NumFname=0) then
          begin
            ProtoEnd;
            exit;
          end;
        end
        else
          SetFileVar(FileVar);
      end;
    IdKmtReceive: FileVar^.OpId := OpKmtRcv;
    IdKmtGet: begin
        FileVar^.OpId := OpKmtGet;
        if (StrLen(@FileVar^.FullName[FileVar^.DirLen])=0) then
        begin
          if not GetGetFname(FileVar^.HMainWin,FileVar) or
            (StrLen(FileVar^.FullName)=0) then
          begin
            ProtoEnd;
            exit;
          end;      
        end
        else
          SetFileVar(FileVar);
      end;
    IdKmtFinish: FileVar^.OpId := OpKmtFin;
  else
    begin
      ProtoEnd;
      exit;
    end;
  end;
  TalkStatus := IdTalkQuiet;

  {disable transmit delay (serial port)}
  cv.DelayFlag := FALSE;

  if not OpenProtoDlg(FileVar,PROTO_KMT,mode,0,0) then
    ProtoEnd;

end;

procedure XMODEMStart(mode: integer);
var
  Option: longint;
begin
  if not ProtoStart then exit;

  if mode=IdXReceive then
    FileVar^.OpId := OpXRcv
  else
    FileVar^.OpId := OpXSend;

  if (StrLen(@FileVar^.FullName[FileVar^.DirLen])=0) then
  begin
    Option := MAKELONG(ts.XmodemBin,ts.XmodemOpt);
    if not GetXFname(FileVar^.HMainWin,
             mode=IdXReceive,@Option,FileVar,ts.FileDir) then
    begin
      ProtoEnd;
      exit;
    end;
    ts.XmodemOpt := HIWORD(Option);
    ts.XmodemBin := LOWORD(Option);
  end
  else
    SetFileVar(FileVar);

  if mode=IdXReceive then
    FileVar^.FileHandle := _lcreat(FileVar^.FullName,0)
  else
    FileVar^.FileHandle := _lopen(FileVar^.FullName,of_Read);

  FileVar^.FileOpen := FileVar^.FileHandle>0;
  if not FileVar^.FileOpen then
  begin
    ProtoEnd;
    exit;
  end;
  TalkStatus := IdTalkQuiet;

  {disable transmit delay (serial port)}
  cv.DelayFlag := FALSE;

  if not OpenProtoDlg(FileVar,PROTO_XM,mode,
                      ts.XmodemOpt,ts.XmodemBin) then
    ProtoEnd;

end;

procedure ZMODEMStart(mode: integer);
var
  Opt: word;
begin
  if not ProtoStart then exit;

  if mode=IdZSend then
  begin
    Opt := ts.XmodemBin;
    FileVar^.OpId := OpZSend;
    if (StrLen(@FileVar^.FullName[FileVar^.DirLen])=0) then
    begin
      if (not GetMultiFname(FileVar,ts.FileDir,GMF_Z,@Opt) or
         (FileVar^.NumFname=0)) then
      begin
        ProtoEnd;
        exit;
      end;
      ts.XmodemBin := Opt;
    end
    else
      SetFileVar(FileVar);
  end
  else {IdZReceive or IdZAuto}
    FileVar^.OpId := OpZRcv;

  TalkStatus := IdTalkQuiet;

  {disable transmit delay (serial port)}
  cv.DelayFlag := FALSE;

  if not OpenProtoDlg(FileVar,PROTO_ZM,mode,Opt,0) then
    ProtoEnd;

end;


procedure BPStart(mode: integer);
var
  Option: longint;
begin
  if not ProtoStart then exit;
  if mode=IdBPSend then
  begin
    FileVar^.OpId := OpBPSend;
    if (StrLen(@FileVar^.FullName[FileVar^.DirLen])=0) then
    begin
      if not GetTransFname(FileVar, ts.FileDir, GTF_BP, @Option) then
      begin
        ProtoEnd;
        exit;
      end;
    end
    else
      SetFileVar(FileVar);

  end
  else {IdBPReceive or IdBPAuto}
    FileVar^.OpId := OpBPRcv;

  TalkStatus := IdTalkQuiet;

  {disable transmit delay (serial port)}
  cv.DelayFlag := FALSE;

  if not OpenProtoDlg(FileVar,PROTO_BP,mode,0,0) then
    ProtoEnd;

end;

procedure QVStart(mode: integer);
var
  W: word;
begin
  if not ProtoStart then exit;

  if mode=IdQVSend then
  begin
    FileVar^.OpId := OpQVSend;
    if (StrLen(@FileVar^.FullName[FileVar^.DirLen])=0) then
    begin
      if not GetMultiFname(FileVar,ts.FileDir,GMF_QV, @W) or
         (FileVar^.NumFname=0) then
      begin
        ProtoEnd;
        exit;
      end;
    end
    else
      SetFileVar(FileVar);
  end
  else
    FileVar^.OpId := OpQVRcv;

  TalkStatus := IdTalkQuiet;

  {disable transmit delay (serial port)}
  cv.DelayFlag := FALSE;

  if not OpenProtoDlg(FileVar,PROTO_QV,mode,0,0) then
    ProtoEnd;

end;

{initialization}
begin
 LogVar := nil;
 SendVar :=nil;
 FileVar := nil;
 ProtoVar := nil;

 LogLast := 0;
 FileLog := FALSE;
 BinLog := FALSE;
 DDELog := FALSE;

 FSend := FALSE;
 HTTFILE := 0;
 TTFILECount := 0;

 FLogDlg := nil;
 SendDlg := nil;
 PtDlg := nil;
end.
