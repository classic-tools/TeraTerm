{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTFILE.DLL, ZMODEM protocol}
unit ZMODEM;

interface

uses WinTypes, WinProcs, Strings, TTTypes, TTFTypes,
     TTCommon, DlgLib, FTLib, TTLib;

procedure ZInit(fv: PFileVar; zv: PZVar; cv: PComVar; ts: PTTSet);
procedure ZTimeOutProc(fv: PFileVar; zv: PZVar; cv: PComVar);
function ZParse(fv: PFileVar; zv: PZVar; cv: PComVar): bool;
procedure ZCancel(zv: PZVar);

implementation
{$i tt_res.inc}

const
  NormalTimeOut = 10;
  TCPIPTimeOut = 0;
  IniTimeOut = 10;
  FinTimeOut = 3;

const
  ZPAD   = ord('*');
  ZDLE   = $18;
  ZDLEE  = $58;
  ZBIN   = ord('A');
  ZHEX   = ord('B');
  ZBIN32 = ord('C');

  ZRQINIT = 0;
  ZRINIT  = 1;
  ZSINIT  = 2;
  ZACK    = 3;
  ZFILE   = 4;
  ZSKIP   = 5;
  ZNAK    = 6;
  ZABORT  = 7;
  ZFIN    = 8;
  ZRPOS   = 9;
  ZDATA   = 10;
  ZEOF    = 11;
  ZFERR   = 12;
  ZCRC    = 13;
  ZCHALLENGE = 14;
  ZCOMPL  = 15;
  ZCAN    = 16;
  ZFREECNT = 17;
  ZCOMMAND = 18;
  ZSTDERR = 19;

  ZCRCE = ord('h');
  ZCRCG = ord('i');
  ZCRCQ = ord('j');
  ZCRCW = ord('k');
  ZRUB0 = ord('l');
  ZRUB1 = ord('m');

  ZF0 = 3;
  ZF1 = 2;
  ZF2 = 1;
  ZF3 = 0;
  ZP0 = 0;
  ZP1 = 1;
  ZP2 = 2;
  ZP3 = 3;

  CANFDX  = $01;
  CANOVIO = $02;
  CANBRK  = $04;
  CANCRY  = $08;
  CANLZW  = $10;
  CANFC32 = $20;
  ESCCTL  = $40;
  ESC8    = $80;

  ZCBIN   = 1;
  ZCNL    = 2;


function ZRead1Byte(fv: PFileVar; zv: PZVar; cv: PComVar; var b: byte): integer;
begin
with zv^ do begin
  if CommRead1Byte(cv,@b) = 0 then
  begin
    ZRead1Byte := 0;
    exit;
  end;
  ZRead1Byte := 1;
  if fv^.LogFlag then
  begin
    if fv^.LogState=0 then
    begin
      fv^.LogState := 1;
      fv^.LogCount := 0;
      _lwrite(fv^.LogFile,#$0D#$0A'<<<'#$0D#$0A,7);
    end;
    FTLog1Byte(fv,b);
  end;
  {ignore $11,$13,$81 and $83}
  if (b and $7F = $11) or (b and $7F = $13) then
    ZRead1Byte := 0;
end;
end;

function ZWrite(fv: PFileVar; zv: PZVar; cv: PComVar; B: PChar; C: integer): integer;
var
  i, j: integer;
begin
with zv^ do begin
  i := CommBinaryOut(cv,B,C);
  ZWrite := i;
  if fv^.LogFlag and (i>0) then
  begin
    if fv^.LogState<>0 then
    begin
      fv^.LogState := 0;
      fv^.LogCount := 0;
      _lwrite(fv^.LogFile,#$0D#$0A'>>>'#$0D#$0A,7);
    end;
    for j:=0 to i-1 do
      FTLog1Byte(fv,byte(B[j]));
  end;
end;
end;

procedure ZPutHex(zv: PZVar; var i: integer; b: byte);
begin
with zv^ do begin
  case b of
    $00..$9F: PktOut[i] := b shr 4 + $30;
    $A0..$FF: PktOut[i] := b shr 4 + $57;
  end;
  inc(i);
  case b and $0F of
    $0..$9: PktOut[i] := b and $0F + $30;
    $A..$F: PktOut[i] := b and $0F + $57;
  end;
  inc(i);
end;
end;

procedure ZShHdr(zv: PZVar; HdrType: byte);
var
  i: integer;
begin
with zv^ do begin
  PktOut[0] := ZPAD;
  PktOut[1] := ZPAD;
  PktOut[2] := ZDLE;
  PktOut[3] := ZHEX;
  PktOutCount := 4;
  ZPutHex(zv,PktOutCount,HdrType);
  CRC := UpdateCRC(HdrType, 0);
  for i:=0 to 3 do
  begin
    ZPutHex(zv,PktOutCount,TxHdr[i]);
    CRC := UpdateCRC(TxHdr[i], CRC);
  end;
  ZPutHex(zv,PktOutCount,Hi(CRC));
  ZPutHex(zv,PktOutCount,Lo(CRC));
  PktOut[PktOutCount] := $8D;
  inc(PktOutCount);
  PktOut[PktOutCount] := $8A;
  inc(PktOutCount);

  if (HdrType<>ZFIN) and (HdrType<>ZACK) then
  begin
    PktOut[PktOutCount] := XON;
    inc(PktOutCount);
  end;

  PktOutPtr := 0;
  Sending := TRUE;
end;
end;

procedure ZPutBin(zv: PZVar; var i: integer; b: byte);
begin
with zv^ do begin
  case b of
    $0D,$8D:
      {if CtlEsc or (LastSent and $7f = ord('@')) then}
      begin
        PktOut[i] := ZDLE;
        inc(i);
        b := b xor $40;
      end;
    $10,$11,$13,ZDLE,
    $90,$91,$93: begin
        PktOut[i] := ZDLE;
        inc(i);
        b := b xor $40;
      end;
  else
    if CtlEsc and (b and $60 = 0) then
    begin
      PktOut[i] := ZDLE;
      inc(i);
      b := b xor $40;
    end;
  end;
  LastSent := b;
  PktOut[i] := b;
  inc(i);
end;
end;

procedure ZSbHdr(zv: PZVar; HdrType: byte);
var
  i: integer;
begin
with zv^ do begin
  PktOut[0] := ZPAD;
  PktOut[1] := ZDLE;
  PktOut[2] := ZBIN;
  PktOutCount := 3;
  ZPutBin(zv,PktOutCount,HdrType);
  CRC := UpdateCRC(HdrType, 0);
  for i:=0 to 3 do
  begin
    ZPutBin(zv,PktOutCount,TxHdr[i]);
    CRC := UpdateCRC(TxHdr[i], CRC);
  end;
  ZPutBin(zv,PktOutCount,Hi(CRC));
  ZPutBin(zv,PktOutCount,Lo(CRC));

  PktOutPtr := 0;
  Sending := TRUE;
end;
end;

procedure ZStoHdr(zv: PZVar; Pos: longint);
begin
with zv^ do begin
  TxHdr[ZP0] := Lo(LoWord(Pos));
  TxHdr[ZP1] := Hi(LoWord(Pos));
  TxHdr[ZP2] := Lo(HiWord(Pos));
  TxHdr[ZP3] := Hi(HiWord(Pos));
end;
end;

function ZRclHdr(zv: PZVar): longint;
var
  L: longint;
begin
with zv^ do begin
  L := byte(RxHdr[ZP3]);
  L := L shl 8 + byte(RxHdr[ZP2]);
  L := L shl 8 + byte(RxHdr[ZP1]);
  ZRclHdr := L shl 8 + byte(RxHdr[ZP0]);
end;
end;

procedure ZSendRInit(fv: PFileVar; zv: PZVar);
begin
with zv^ do begin
  Pos := 0;
  ZStoHdr(zv,0);
  TxHdr[ZF0] := {CANFC32 or} CANFDX or CANOVIO;
  if CtlEsc then
    TxHdr[ZF0] := TxHdr[ZF0] or ESCCTL;
  ZShHdr(zv,ZRINIT);
  FTSetTimeOut(fv,IniTimeOut);
end;
end;

procedure ZSendRQInit(fv: PFileVar; zv: PZVar; cv: PComVar);
begin
with zv^ do begin
  ZWrite(fv,zv,cv,'rz'#$0d,3);
  ZStoHdr(zv,0);
  ZShHdr(zv,ZRQINIT);
end;
end;

procedure ZSendRPOS(fv: PFileVar; zv: PZVar);
begin
with zv^ do begin
  ZStoHdr(zv,Pos);
  ZShHdr(zv,ZRPOS);
  FTSetTimeOut(fv,TimeOut);
end;
end;

procedure ZSendACK(fv: PFileVar; zv: PZVar);
begin
with zv^ do begin
  ZStoHdr(zv,0);
  ZShHdr(zv,ZACK);
  FTSetTimeOut(fv,TimeOut);
end;
end;

procedure ZSendNAK(zv: PZVar);
begin
with zv^ do begin
  ZStoHdr(zv,0);
  ZShHdr(zv,ZNAK);
end;
end;

procedure ZSendEOF(zv: PZVar);
begin
with zv^ do begin
  ZStoHdr(zv,Pos);
  ZShHdr(zv,ZEOF);
  ZState := Z_SendEOF;
end;
end;

procedure ZSendFIN(zv: PZVar);
begin
with zv^ do begin
  ZStoHdr(zv,0);
  ZShHdr(zv,ZFIN);
end;
end;

procedure ZSendCancel(zv: PZVar);
var
  i: integer;
begin
with zv^ do begin
  for i := 0 to 7 do
    PktOut[i] := ZDLE;
  for i := 8 to 17 do
    PktOut[i] := $08;
  PktOutCount := 18;
  PktOutPtr := 0;
  Sending := TRUE;
  ZState := Z_Cancel;
end;
end;

procedure ZSendInitHdr(zv: PZVar);
begin
with zv^ do begin
  ZStoHdr(zv,0);
  if CtlEsc then
    TxHdr[ZF0] := ESCCTL; 
  ZShHdr(zv,ZSINIT);
  ZState := Z_SendInitHdr;
end;
end;

procedure ZSendInitDat(zv: PZVar);
begin
with zv^ do begin
  CRC := 0;
  PktOutCount := 0;
  ZPutBin(zv,PktOutCount,0);
  CRC := UpdateCRC(0,CRC);

  PktOut[PktOutCount] := ZDLE;
  inc(PktOutCount);
  PktOut[PktOutCount] := ZCRCW;
  inc(PktOutCount);
  CRC := UpdateCRC(ZCRCW,CRC);

  ZPutBin(zv,PktOutCount,Hi(CRC));
  ZPutBin(zv,PktOutCount,Lo(CRC));

  PktOutPtr := 0;
  Sending := TRUE;
  ZState := Z_SendInitDat;
end;
end;

procedure ZSendFileHdr(zv: PZVar);
begin
with zv^ do begin
  ZStoHdr(zv,0);
  if BinFlag then
    TxHdr[ZF0] := ZCBIN {binary file}
  else
    TxHdr[ZF0] := ZCNL; {text file, convert newline}
  ZSbHdr(zv,ZFILE);
  ZState := Z_SendFileHdr;
end;
end;

procedure ZSendFileDat(fv: PFileVar; zv: PZVar);
var
  i, j: integer;
  NumPStr: string[10];
begin
with zv^ do begin
  if not fv^.FileOpen then
  begin
    ZSendCancel(zv);
    exit;
  end;
  SetDlgItemText(fv^.HWin, IDC_PROTOFNAME, @fv^.FullName[fv^.DirLen]);

  {file name}
  StrCopy(@PktOut[0],StrLower(@fv^.FullName[fv^.DirLen]));
  FTConvFName(@PktOut[0]); {replace ' ' by '_' in FName}
  PktOutCount := StrLen(@PktOut[0]);
  CRC := 0;
  for i := 0 to PktOutCount-1 do
    CRC := UpdateCRC(PktOut[i],CRC);
  ZPutBin(zv,PktOutCount,0);
  CRC := UpdateCRC(0,CRC);
  {file size}
  fv^.FileSize := GetFSize(fv^.FullName);

  Str(fv^.FileSize,NumPStr);
  StrPCopy(@PktOut[PktOutCount],NumPStr);
  j := StrLen(@PktOut[PktOutCount])-1;
  for i := 0 to j do
  begin
    CRC := UpdateCRC(PktOut[PktOutCount],CRC);
    inc(PktOutCount);
  end;

  ZPutBin(zv,PktOutCount,0);
  CRC := UpdateCRC(0,CRC);
  PktOut[PktOutCount] := ZDLE;
  inc(PktOutCount);
  PktOut[PktOutCount] := ZCRCW;
  inc(PktOutCount);
  CRC := UpdateCRC(ZCRCW,CRC);

  ZPutBin(zv,PktOutCount,Hi(CRC));
  ZPutBin(zv,PktOutCount,Lo(CRC));

  PktOutPtr := 0;
  Sending := TRUE;
  ZState := Z_SendFileDat;

  fv^.ByteCount := 0;
  SetDlgNum(fv^.HWin, IDC_PROTOBYTECOUNT, fv^.ByteCount);
  SetDlgPercent(fv^.HWin, IDC_PROTOPERCENT,
    fv^.ByteCount, fv^.FileSize);
end;
end;

procedure ZSendDataHdr(zv: PZVar);
begin
with zv^ do begin
  ZStoHdr(zv,Pos);
  ZSbHdr(zv,ZDATA);
  ZState := Z_SendDataHdr;
end;
end;

procedure ZSendDataDat(fv: PFileVar; zv: PZVar);
var
  c: integer;
  b: byte;
begin
with zv^ do begin
  if Pos >= fv^.FileSize then
  begin
    Pos := fv^.FileSize;
    ZSendEOF(zv);
    exit;
  end;

  fv^.ByteCount := Pos;

  if fv^.FileOpen and (Pos<fv^.FileSize) then
    _llseek(fv^.FileHandle,Pos,0);

  CRC := 0;
  PktOutCount := 0;
  repeat
    c := _lread(fv^.FileHandle,@b,1);
    if c>0 then
    begin
      ZPutBin(zv,PktOutCount,b);
      CRC := UpdateCRC(b,CRC);
      inc(fv^.ByteCount);
    end;
  until (c=0) or (PktOutCount>MaxDataLen-2);
  SetDlgNum(fv^.HWin, IDC_PROTOBYTECOUNT, fv^.ByteCount);
  SetDlgPercent(fv^.HWin, IDC_PROTOPERCENT,
    fv^.ByteCount, fv^.FileSize);
  Pos := fv^.ByteCount;

  PktOut[PktOutCount] := ZDLE;
  inc(PktOutCount);
  if Pos>=fv^.FileSize then
    b := ZCRCE
  else if (WinSize>=0) and (Pos-LastPos>WinSize) then
    b := ZCRCQ
  else
    b := ZCRCG;
  PktOut[PktOutCount] := b;
  inc(PktOutCount);
  CRC := UpdateCRC(b,CRC);

  ZPutBin(zv,PktOutCount,Hi(CRC));
  ZPutBin(zv,PktOutCount,Lo(CRC));

  PktOutPtr := 0;
  Sending := TRUE;
  if b=ZCRCQ then
    ZState := Z_SendDataDat2 {wait response from receiver}
  else
    ZState := Z_SendDataDat;
end;
end;

procedure ZInit(fv: PFileVar; zv: PZVar; cv: PComVar; ts: PTTSet);
var
  Max: integer;
begin
with zv^ do begin
  CtlEsc := ts^.FTFlag and FT_ZESCCTL <> 0;
  MaxDataLen := ts^.ZmodemDataLen;
  WinSize := ts^.ZmodemWinSize;
  fv^.LogFlag := ts^.LogFlag and LOG_Z <> 0;

  if ZMode=IdZAuto then
  begin
    CommInsert1Byte(cv,ord('B'));
    CommInsert1Byte(cv,ZDLE);
    CommInsert1Byte(cv,ZPAD);
    ZMode := IdZReceive;
  end;

  StrCopy(fv^.DlgCaption,'Tera Term: ZMODEM ');
  case ZMode of
    IdZSend:    StrCat(fv^.DlgCaption,'Send');
    IdZReceive: StrCat(fv^.DlgCaption,'Receive');
  end;

  SetWindowText(fv^.HWin,fv^.DlgCaption);
  SetDlgItemText(fv^.HWin, IDC_PROTOPROT, 'ZMODEM');

  fv^.FileSize := 0;

  PktOutCount := 0;
  Pos := 0;
  LastPos := 0;
  ZPktState := Z_PktGetPAD;
  Sending := FALSE;
  LastSent := 0;
  CanCount := 5;

  if MaxDataLen <= 0 then
    MaxDataLen := 1024;
  if MaxDataLen < 64 then
    MaxDataLen := 64;

  {Time out & Max block size}
  if cv^.PortType=IdTCPIP then
  begin
    TimeOut := TCPIPTimeOut;
    Max := 1024;
  end
  else begin
    TimeOut := NormalTimeOut;
    case ts^.Baud of
      IdBaud110:  Max := 64;
      IdBaud300:  Max := 128;
      IdBaud600..
      IdBaud1200: Max := 256;
      IdBaud2400: Max := 512;
    else
      Max := 1024;
    end;
  end;
  if MaxDataLen > Max then
    MaxDataLen := Max;

  if fv^.LogFlag then
    fv^.LogFile := _lcreat('ZMODEM.LOG',0);
  fv^.LogState := 0;
  fv^.LogCount := 0;

  case ZMode of
    idZReceive: begin
        ZState := Z_RecvInit;
        ZSendRInit(fv,zv);
      end;
    idZSend: begin
        ZState := Z_SendInit;
        ZSendRQInit(fv,zv,cv);
      end;
  end;
end;
end;

procedure ZTimeOutProc(fv: PFileVar; zv: PZVar; cv: PComVar);
begin
with zv^ do begin
  case ZState of
    Z_RecvInit: ZSendRInit(fv,zv);
    Z_RecvInit2: ZSendACK(fv,zv); {Ack for ZSINIT}
    Z_RecvData: ZSendRPOS(fv,zv);
    Z_RecvFin: ZState := Z_End;
  end;
end;
end;

function ZCheckHdr(fv: PFileVar; zv: PZVar): boolean;
var
  i: integer;
  Ok: boolean;
begin
with zv^ do begin
  if CRC32 then
  begin
    CRC3 := $FFFFFFFF;
    for i := 0 to 8 do
      CRC3 := UpdateCRC32(PktIn[i],CRC3);
    Ok := CRC3=$DEBB20E3;
  end
  else begin
    CRC := 0;
    for i := 0 to 6 do
      CRC := UpdateCRC(PktIn[i],CRC);
    Ok := CRC=0;
  end;
  ZCheckHdr := Ok;
  if not Ok then
  begin
    case ZState of
      Z_RecvInit: ZSendRInit(fv,zv);
      Z_RecvData: ZSendRPOS(fv,zv);
    end;
  end;
  RxType := PktIn[0];
  for i := 1 to 4 do
    RxHdr[i-1] := PktIn[i];
end;
end;

procedure ZParseRInit(fv: PFileVar; zv: PZVar);
var
  Max: integer;
begin
with zv^ do begin
  if (ZState<>Z_SendInit) and
     (ZState<>Z_SendEOF) then exit;

  if fv^.FileOpen then {close previous file}
  begin
    _lclose(fv^.FileHandle);
    fv^.FileOpen := TRUE;
  end;

  if not GetNextFname(fv) then
  begin
    ZState := Z_SendFIN;
    ZSendFIN(zv);
    exit;
  end;

  {file open}
  fv^.FileHandle := _lopen(fv^.FullName,of_Read);
  fv^.FileOpen := fv^.FileHandle>0;

  if CtlEsc then
  begin
    if RxHdr[ZF0] and ESCCTL = 0 then
    begin
      ZState := Z_SendInitHdr;
      ZSendInitHdr(zv);
      exit;
    end
  end
  else
    CtlEsc := RxHdr[ZF0] and ESCCTL <> 0;

  Max := (RxHdr[ZP1] shl 8) + RxHdr[ZP0];
  if Max<=0 then Max := 1024;
  if MaxDataLen > Max then
    MaxDataLen := Max;

  ZState := Z_SendFileHdr;
  ZSendFileHdr(zv);
end;
end;

function ZParseSInit(zv: PZVar): boolean;
begin
with zv^ do begin
  ZParseSInit := FALSE;
  if (ZState<>Z_RecvInit) then exit;
  ZState := Z_RecvInit2;
  ZParseSInit := TRUE;
  CtlEsc := CtlEsc or (RxHdr[ZF0] and ESCCTL <> 0);
end;
end;

function ZParseHdr(fv: PFileVar; zv: PZVar; cv: PComVar): boolean;
begin
with zv^ do begin
  case RxType of
    ZRQINIT:
      if ZState=Z_RecvInit then
        ZSendRInit(fv,zv);
    ZRINIT: ZParseRInit(fv,zv);
    ZSINIT: begin
        ZPktState := Z_PktGetData;
        if ZState=Z_RecvInit then
          FTSetTimeOut(fv,IniTimeOut);
      end;
    ZACK:
      case ZState of
        Z_SendInitDat: ZSendFileHdr(zv);
        Z_SendDataDat2: begin
            LastPos := ZRclHdr(zv);
            if Pos=LastPos then
              ZSendDataDat(fv,zv)
            else begin
              Pos := LastPos;
              ZSendDataHdr(zv);
            end;
          end;
      end;
    ZFILE: begin
        ZPktState := Z_PktGetData;
        if (ZState=Z_RecvInit) or
           (ZState=Z_RecvInit2) then
        begin
          BinFlag := RxHdr[ZF0]<>ZCNL;            
          FTSetTimeOut(fv,IniTimeOut);
        end;
      end;
    ZSKIP: begin
        if fv^.FileOpen then
          _lclose(fv^.FileHandle);
        ZStoHdr(zv,0);
        if CtlEsc then
          RxHdr[ZF0] := ESCCTL;
        ZState := Z_SendInit;
        ZParseRInit(fv,zv);
      end;
    ZNAK:
      case ZState of
        Z_SendInitHdr,
        Z_SendInitDat: ZSendInitHdr(zv);
        Z_SendFileHdr,
        Z_SendFileDat: ZSendFileHdr(zv);
      end;
    ZABORT,ZFERR:
      if ZMode=IdZSend then
      begin
        ZState := Z_SendFin;
        ZSendFIN(zv);
      end;
    ZFIN: begin
        fv^.Success := TRUE;
        if ZMode=IdZReceive then
        begin
          ZState := Z_RecvFin;
          ZSendFIN(zv);
          CanCount := 2;
          FTSetTimeOut(fv,FinTimeOut);
        end
        else begin
          ZState := Z_End;
          ZWrite(fv,zv,cv,'OO',2);
        end;
      end;
    ZRPOS:
      case ZState of
        Z_SendFileDat,
        Z_SendDataHdr,
        Z_SendDataDat,
        Z_SendDataDat2,
        Z_SendEOF: begin
            Pos := ZRclHdr(zv);
            LastPos := Pos;
            ZSendDataHdr(zv);
          end;
      end;
    ZDATA:
        if Pos<>ZRclHdr(zv) then
        begin
          ZSendRPOS(fv,zv);
          exit;
        end
        else begin
          FTSetTimeOut(fv,TimeOut);
          ZPktState := Z_PktGetData;
        end;
    ZEOF:
        if Pos<>ZRclHdr(zv) then
        begin
          ZSendRPOS(fv,zv);
          exit;
        end
        else begin
          if fv^.FileOpen then
          begin
            if CRRecv then
            begin
              CRRecv := FALSE;
              _lwrite(fv^.FileHandle,#$0A,1);
            end;
            _lclose(fv^.FileHandle);
            fv^.FileOpen := FALSE;
          end;
          ZState := Z_RecvInit;
          ZSendRInit(fv,zv);
        end;
  end;
  Quoted := FALSE;
  CRC := 0;
  CRC3 := $FFFFFFFF;
  PktInPtr := 0;
  PktInCount := 0;
end;
end;

function ZParseFile(fv: PFileVar; zv: PZVar): boolean;
var
  b: byte;
  i, j: integer;
begin
with zv^ do begin
   ZParseFile := FALSE;
   if (ZState<>Z_RecvInit) and
      (ZState<>Z_RecvInit2) then exit;
   {kill timer}
   FTSetTimeOut(fv,0);
   CRRecv := FALSE;

   {file name}
   PktIn[PktInPtr] := 0; {for safety}

   GetFileNamePos(@PktIn[0],i,j);
   with fv^ do
   begin
     StrCopy(@FullName[DirLen],@PktIn[j]);
   end;
   {file open}
   if not FTCreateFile(fv) then exit;

   {file size}
   i := StrLen(@PktIn[0]) + 1;
   repeat
     b := PktIn[i];
     case b of
       $30..$39: fv^.FileSize :=
         fv^.FileSize * 10 + b - $30;
     end;
     inc(i);
   until (b<$30) or (b>$39);

   Pos := 0;
   fv^.ByteCount := 0;
   ZStoHdr(zv,0);
   ZState := Z_RecvData;
   ZParseFile := TRUE;
   SetDlgNum(fv^.HWin, IDC_PROTOBYTECOUNT, 0);
   if fv^.FileSize>0 then
     SetDlgPercent(fv^.HWin, IDC_PROTOPERCENT,0,fv^.FileSize);
   {set timeout for data}
   FTSetTimeOut(fv,TimeOut);
end;
end;

function ZWriteData(fv: PFileVar; zv: PZVar): boolean;
var
  i: integer;
  b: byte;
begin
with zv^ do begin
   ZWriteData := FALSE;
   if ZState<>Z_RecvData then exit;
   {kill timer}
   FTSetTimeOut(fv,0);

   ZWriteData := TRUE;
   if BinFlag then
     _lwrite(fv^.FileHandle,@PktIn[0],PktInPtr)
   else
     for i := 0 to PktInPtr-1 do
     begin
       b := byte(PktIn[i]);
       if (b=$0A) and not CRRecv then
         _lwrite(fv^.FileHandle,#$0D,1);
       if CRRecv and (b<>$0A) then
         _lwrite(fv^.FileHandle,#$0A,1);
       CRRecv := b=$0D;
       _lwrite(fv^.FileHandle,@b,1);
     end;

   fv^.ByteCount := fv^.ByteCount + PktInPtr;
   Pos := Pos + PktInPtr;
   ZStoHdr(zv,Pos);
   SetDlgNum(fv^.HWin, IDC_PROTOBYTECOUNT, fv^.ByteCount);
   if fv^.FileSize>0 then
     SetDlgPercent(fv^.HWin, IDC_PROTOPERCENT,
       fv^.ByteCount, fv^.FileSize);

   {set timeout for data}
   FTSetTimeOut(fv,TimeOut);
end;
end;

procedure ZCheckData(fv: PFileVar; zv: PZVar);
var
  OK: boolean;
begin
with zv^ do begin
  {check CRC}
  if CRC32 and (CRC3<>$DEBB20E3) or
     not CRC32 and (CRC<>0) then {bad CRC}
  begin
    case ZState of
      Z_RecvInit,
      Z_RecvInit2: ZSendNAK(zv);
      Z_RecvData: ZSendRPOS(fv,zv);
    end;
    ZPktState := Z_PktGetPAD;
    exit;
  end;
  {parse data}
  case RxType of
    ZSInit: Ok := ZParseSInit(zv);
    ZFILE: OK := ZParseFile(fv,zv);        
    ZDATA: OK := ZWriteData(fv,zv);
  else
    OK := FALSE;
  end;

  if not OK then
  begin
    ZPktState := Z_PktGetPAD;
    exit;
  end;

  if RxType=ZFILE then
    ZShHdr(zv,ZRPOS);

  {next state}
  case TERM of
    ZCRCE: ZPktState := Z_PktGetPAD;
    ZCRCG: ZPktState := Z_PktGetData;
    ZCRCQ: begin
        ZPktState := Z_PktGetData;
        if RxType<>ZFILE then
          ZShHdr(zv,ZACK);
      end;
    ZCRCW: begin
        ZPktState := Z_PktGetPAD;
        if RxType<>ZFILE then
          ZShHdr(zv,ZACK);
      end;
  else
    ZPktState := Z_PktGetPAD;
  end;

  if ZPktState=Z_PktGetData then
  begin
    Quoted := FALSE;
    CRC := 0;
    CRC3 := $FFFFFFFF;
    PktInPtr := 0;
    PktInCount := 0;
  end;
end;
end;

function ZParse(fv: PFileVar; zv: PZVar; cv: PComVar): bool;
var
  b: byte;
  c: integer;
begin
with zv^ do begin
  ZParse := TRUE;

  repeat
    {Send packet}
    if Sending then
    begin
      c := 1;
      while (c>0) and (PktOutCount>0) do
      begin
        c := ZWrite(fv,zv,cv,@PktOut[PktOutPtr],PktOutCount);
        PktOutPtr := PktOutPtr + c;
        PktOutCount := PktOutCount - c;
      end;
      if PktOutCount<=0 then
        Sending := FALSE;
      if (ZMode=idZReceive) and (PktOutCount>0) then exit;
    end;

    c := ZRead1Byte(fv,zv,cv,b);
    while (c>0) do
    begin
      if ZState=Z_RecvFIN then
      begin
        if b=ord('O') then dec(CanCount);
        if CanCount<=0 then
        begin
          ZState := Z_End;
          ZParse := FALSE;
          exit;
        end;
      end
      else
        case b of
          ZDLE: begin
              dec(CanCount);
              if CanCount<=0 then
              begin
                ZState := Z_End;
                ZParse := FALSE;
                exit;
              end;
            end;
        else
          CanCount := 5;
        end;

      case ZPktState of
        Z_PktGetPAD:
          case b of
            ZPAD: ZPktState := Z_PktGetDLE;
          end;
        Z_PktGetDLE:
          case b of
            ZPAD: ;
            ZDLE: ZPktState := Z_PktHdrFrm;
          else
            ZPktState := Z_PktGetPAD;
          end;
        Z_PktHdrFrm: begin {Get header format type}
          case b of
            ZBIN: begin
                CRC32 := FALSE;
                PktInCount := 7;
                ZPktState := Z_PktGetBin;
              end;
            ZHEX: begin
                HexLo := FALSE;
                CRC32 := FALSE;
                PktInCount := 7;
                ZPktState := Z_PktGetHex;
              end;
            ZBIN32: begin
                CRC32 := TRUE;
                PktInCount := 9;
                ZPktState := Z_PktGetBin;
              end;
          else
            ZPktState := Z_PktGetPAD;
          end;
          Quoted := FALSE;
          PktInPtr := 0;
          end;
        Z_PktGetBin:
          case b of
            ZDLE: Quoted := TRUE;
          else
            begin
              if Quoted then
              begin
                b := b xor $40;
                Quoted := FALSE;
              end;
              PktIn[PktInPtr] := b;
              inc(PktInPtr);
              dec(PktInCount);
              if PktInCount=0 then
              begin
                ZPktState := Z_PktGetPAD;
                if ZCheckHdr(fv,zv) then
                  ZParseHdr(fv,zv,cv);
              end;
            end;
          end;
        Z_PktGetHex: begin
            case b of
              ord('0')..ord('9'): b := b - $30;
              ord('a')..ord('f'): b := b - $57;
            else
              begin
                ZPktState := Z_PktGetPAD;
                exit;
              end;
            end;
            if HexLo then
            begin
              PktIn[PktInPtr] := PktIn[PktInPtr] + b;
              HexLo := FALSE;
              inc(PktInPtr);
              dec(PktInCount);
              if PktInCount<=0 then
              begin
                ZPktState := Z_PktGetHexEOL;
                PktInCount := 2;
              end;
            end
            else begin
              PktIn[PktInPtr] := b shl 4;
              HexLo := TRUE;
            end;
          end;
        Z_PktGetHexEOL: begin
            dec(PktInCount);
            if PktInCount<=0 then
            begin
              ZPktState := Z_PktGetPAD;
              if ZCheckHdr(fv,zv) then
                ZParseHdr(fv,zv,cv);
            end;
          end;
        Z_PktGetData:
          case b of
            ZDLE: Quoted := TRUE;
          else
            begin
              if Quoted then
              begin
                case b of
                  ZCRCE..ZCRCW: begin
                      TERM := b;
                      if CRC32 then
                        PktInCount := 4
                      else
                        PktInCount := 2;
                      ZPktState := Z_PktGetCRC;
                    end;
                  ZRUB0: b := $7F;
                  ZRUB1: b := $FF;
                else            
                  b := b xor $40;
                end;
                Quoted := FALSE;
              end;
              if CRC32 then
                CRC3 := UpdateCRC32(b,CRC3)
              else
                CRC := UpdateCRC(b,CRC);
              if ZPktState=Z_PktGetData then
              begin
                if PktInPtr<1024 then
                begin
                  PktIn[PktInPtr] := b;
                  inc(PktInPtr);
                end
                else
                  ZPktState := Z_PktGetPAD;
              end;
            end;
          end;
        Z_PktGetCRC:
          case b of
            ZDLE: Quoted := TRUE;
          else
            begin
              if Quoted then
              begin
                case b of
                  ZRUB0: b := $7F;
                  ZRUB1: b := $FF;
                else            
                  b := b xor $40;
                end;
                Quoted := FALSE;
              end;
              if CRC32 then
                CRC3 := UpdateCRC32(b,CRC3)
              else
                CRC := UpdateCRC(b,CRC);
              dec(PktInCount);
              if PktInCount<=0 then
                ZCheckData(fv,zv);
            end;
          end;
      end;
      c := ZRead1Byte(fv,zv,cv,b);
    end;

    if not Sending then
      case ZState of
        Z_SendInitHdr: ZSendInitDat(zv);
        Z_SendFileHdr: ZSendFileDat(fv,zv);
        Z_SendDataHdr,
        Z_SendDataDat: ZSendDataDat(fv,zv);
        Z_Cancel: ZState := Z_End;
      end;

    if Sending and (PktOutCount>0) then exit;
  until not Sending;

  if ZState=Z_End then
    ZParse := FALSE;
end;
end;

procedure ZCancel(zv: PZVar);
begin
  ZSendCancel(zv);
end;

end.
