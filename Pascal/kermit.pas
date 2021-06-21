{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTFILE.DLL, Kermit protocol}
unit Kermit;

interface

uses WinTypes, WinProcs, Strings, TTTypes, TTFTypes,
     TTCommon, DlgLib, FTLib, TTLib;

procedure KmtInit(fv: PFileVar; kv: PKmtVar; cv: PComVar; ts: PTTSet);
procedure KmtTimeOutProc(fv: PFileVar; kv: PKmtVar; cv: PComVar);
function KmtReadPacket(fv: PFileVar; kv: PKmtVar; cv: PComVar): BOOL;
procedure KmtCancel(fv: PFileVar; kv: PKmtVar; cv: PComVar);

implementation

{$i tt_res.inc}
const
  {kermit parameters}
  MaxNum = 94;

  MinMAXL = 10;
  MaxMAXL = 94; 
  DefMAXL = 90;
  MinTIME = 1;
  DefTIME = 10;
  DefNPAD = 0;
  DefPADC = 0;
  DefEOL  = $0D;
  DefQCTL = ord('#');
  MyQBIN = ord('Y');
  DefCHKT = 1;
  MyREPT = ord('~');

function KmtNum(b: byte): byte;
begin
  KmtNum := b - 32;
end;

function KmtChar(b: byte): byte;
begin
  KmtChar := b + 32;
end;

procedure KmtCalcCheck(Sum: word; CHKT:byte; Check: PChar);
begin
  case CHKT of
    1: Check[0] := char(KmtChar((Sum + (Sum and $C0) div $40) and $3F));
    2: begin
      Check[0] := char(KmtChar((Sum div $40) and $3F));
      Check[1] := char(KmtChar(Sum and $03F));
    end;
    3: ;
  end;
end;  

procedure KmtSendPacket(fv: PFileVar; kv: PKmtVar; cv: PComVar);
var
  C: integer;
begin
with kv^ do begin

  {padding characters}
  for C := 1 to KmtYour.NPAD do
    CommBinaryOut(cv,@KmtYour.PADC, 1);

  {packet}
  C := KmtNum(PktOut[1]) + 2;
  CommBinaryOut(cv,@PktOut[0], C);

  if fv^.LogFlag then
  begin
    _lwrite(fv^.LogFile,'> ',2);
    _lwrite(fv^.LogFile,@PktOut[1],C-1);
    _lwrite(fv^.LogFile,#$0D#$0A,2);
  end;

  {end-of-line character}
  if KmtYour.EOL > 0 then
    CommBinaryOut(cv,@KmtYour.EOL, 1);

  FTSetTimeOut(fv,kv^.KmtYour.TIME);
end;
end;    

procedure KmtMakePacket(kv: PKmtVar; SeqNum: byte; PktType: byte; DataLen: integer);
var
  i: integer;
  Sum: word;
begin
with kv^ do begin
  PktOut[0] := 1; {MARK}
  PktOut[1] := KmtChar(DataLen + KmtMy.CHKT + 2); {LEN}
  PktOut[2] := KmtChar(SeqNum); {SEQ}
  PktOut[3] := PktType; {TYPE}

  {check sum}
  Sum := 0;
  for i := 1 to DataLen+3 do
    Sum := Sum + PktOut[i];
  KmtCalcCheck(Sum, KmtMy.CHKT, @PktOut[DataLen+4]);
end;
end;

procedure KmtSendInitPkt(fv: PFileVar; kv: PKmtVar; cv: PComVar; PktType: byte);
var
  NParam: integer;
begin
with kv^ do begin
  PktNumOffset := 0;
  PktNum := 0;

  NParam := 9; {num of parameters in Send-init packet}

  {parameters}

  PktOut[4] := KmtChar(KmtMy.MAXL);
  PktOut[5] := KmtChar(KmtMy.TIME);
  PktOut[6] := KmtChar(KmtMy.NPAD);
  PktOut[7] := KmtMy.PADC xor $40;
  PktOut[8] := KmtChar(KmtMy.EOL);
  PktOut[9] := KmtMy.QCTL;
  PktOut[10] := KmtMy.QBIN;
  PktOut[11] := KmtMy.CHKT + $30;
  PktOut[12] := KmtMy.REPT;

  KmtMakePacket(kv,PktNum-PktNumOffset,PktType,NParam);
  KmtSendPacket(fv,kv,cv);

  case PktType of
    Ord('S'): KmtState := SendInit;
    Ord('I'): KmtState := ServerInit;
  end;
end;
end;

procedure KmtSendNack(fv: PFileVar; kv: PKmtVar; cv: PComVar; SeqChar: byte);
begin
  KmtMakePacket(kv,KmtNum(SeqChar),ord('N'),0);
  KmtSendPacket(fv,kv,cv);
end;

function KmtCalcPktNum(kv: PKmtVar; b: byte): integer;
var
  n: integer;
begin
with kv^ do begin
  n := KmtNum(b) + PktNumOffset;
  if n>PktNum+31 then n := n - 64
  else if n<PktNum-32 then n := n + 64;
  KmtCalcPktNum := n;
end;
end;

function KmtCheckPacket(kv: PKmtVar): boolean;
var
  i: integer;
  Sum: word;
  Check: array[0..2] of byte;
begin
with kv^ do begin
  {Calc sum}
  Sum := 0;
  for i := 1 to PktInLen+1-KmtMy.CHKT do
    Sum := Sum + PktIn[i];

  {Calc CHECK}
  KmtCalcCheck(Sum, KmtMy.CHKT, @Check[0]);

  KmtCheckPacket := TRUE;
  for i := 1 to KmtMy.CHKT do 
    if Check[i-1]<>PktIn[PktInLen+1-KmtMy.CHKT+i] then
      KmtCheckPacket := FALSE;
end;
end;

procedure KmtParseInit(kv: PKmtVar; AckFlag: boolean);

  function CheckQuote(b: byte): boolean;
  begin
    CheckQuote := ((b>$20)and(b<$3f)) or
                  ((b>$5F)and(b<$7f));
  end;

var
  i, NParam: integer;
  b, n: byte;
begin
with kv^ do begin
  NParam := PktInLen - 2 - KmtMy.CHKT;

  for i:=1 to NParam do
  begin
    b := PktIn[i+3];
    n:= KmtNum(b);
    case i of
      1: if (MinMAXL<n) and (n<MaxMAXL) then
           KmtYour.MAXL := n;

      2: if (MinTime<n) and (n<MaxNum) then
           KmtYour.TIME := n;

      3: if (n<MaxNum) then
           KmtYour.NPAD := n;

      4: KmtYour.PADC := b xor $40;

      5: if (n<$20) then
           KmtYour.EOL := n;

      6: if CheckQuote(b) then
           KmtYour.QCTL := b;

      7: begin
        if AckFlag then {Ack packet from remote host}
        begin
          if (b=ord('Y')) and
             CheckQuote(KmtMy.QBIN) then
            Quote8 := TRUE
          else
            if CheckQuote(b) and
               ((b=KmtMy.QBIN) or
                (KmtMy.QBIN=ord('Y'))) then
            begin
              KmtMy.QBIN := b;
              Quote8 := TRUE;
            end;
        end
        else {S-packet from remote host}
          if (b=ord('Y')) and CheckQuote(KmtMy.QBIN) then
            Quote8 := TRUE
          else if CheckQuote(b) then
          begin
            KmtMy.QBIN := b;
            Quote8 := TRUE;
          end;

        if not Quote8 then KmtMy.QBIN := ord('N');
        KmtYour.QBIN := KmtMy.QBIN;
      end;

      8: begin
        KmtYour.CHKT := b - $30;
        if AckFlag then
        begin
          if KmtYour.CHKT<>KmtMy.CHKT then
            KmtYour.CHKT := DefCHKT;
        end
        else
          if (KmtYour.CHKT<1) or (KmtYour.CHKT>2) then
            KmtYour.CHKT := DefCHKT;

        KmtMy.CHKT := KmtYour.CHKT;
      end;

      9: begin
        KmtYour.REPT := b;
        if not AckFlag and
           (KmtYour.REPT>$20) and
           (KmtYour.REPT<$7F) then
          KmtMy.REPT := KmtYour.REPT;
        RepeatFlag := KmtMy.REPT = KmtYour.REPT;
      end;
    end;
  end;

end;
end;

procedure KmtSendAck(fv: PFileVar; kv: PKmtVar; cv: PComVar);
begin
with kv^ do begin
  if PktIn[3]=ord('S') then
    {Send-Init packet}
  begin
    KmtParseInit(kv,FALSE);
    KmtSendInitPkt(fv,kv,cv,ord('Y'));
  end
  else begin
    KmtMakePacket(kv,KmtNum(PktIN[2]),ord('Y'),0);
    KmtSendPacket(fv,kv,cv);
  end;
end;
end;

procedure KmtDecode(fv: PFileVar; kv: PKmtVar; Buff:PChar; var BuffLen: integer);
var
  i, j, DataLen, BuffPtr: integer;
  b, b2: byte;
  CTLflag,BINflag,REPTflag,OutFlag: boolean;
begin
with kv^ do begin
  BuffPtr := 0;
  DataLen := PktInLen-KmtMy.CHKT-2;

  OutFlag := FALSE;
  RepeatCount := 1;
  CTLflag := FALSE;
  BINflag := FALSE;
  REPTflag := FALSE;
  for i := 1 to DataLen do
  begin
    b := PktIn[3+i];
    b2 := b and $7f;
    if CTLflag then
    begin
      if (b2 <> KmtYour.QCTL) and
         ((not Quote8) or (b2 <> KmtYour.QBIN)) and
         ((not RepeatFlag) or (b2 <> KmtYour.REPT))
        then b := b xor $40;
      CTLflag := FALSE;
      OutFlag := TRUE;
    end
    else if RepeatFlag and REPTflag then
      begin
        RepeatCount := KmtNum(b);
        REPTflag := FALSE;
      end
    else if (b=KmtYour.QCTL) then CTLflag := TRUE
    else if Quote8  and (b=KmtYour.QBIN) then BINflag := TRUE
    else if RepeatFlag and (b=KmtYour.REPT) then REPTflag := TRUE
    else OutFlag := TRUE;

    if OutFlag then
    begin
      if Quote8 and BINflag then b := b or $80;        
      for j := 1 to RepeatCount do
      begin
        if Buff=nil then {write to file}
          _lwrite(fv^.FileHandle,@b,1)
        else {write to buffer}
          if BuffPtr<BuffLen then
          begin
            Buff[BuffPtr] := char(b);
            inc(BuffPtr);
          end;
      end;
      fv^.ByteCount := fv^.ByteCount + RepeatCount;
      OutFlag := FALSE;
      RepeatCount := 1;
      CTLflag := FALSE;
      BINflag := FALSE;
      REPTflag := FALSE;
    end;
  end;

  if Buff=nil then SetDlgNum(fv^.HWin, IDC_PROTOBYTECOUNT, fv^.ByteCount);
  BuffLen := BuffPtr;
end;
end;

function KmtEncode(fv: PFileVar; kv: PKmtVar): boolean;
var
  b, b2, b7: byte;
  Len: integer;
  TempStr: array[0..3] of char;
begin
with kv^ do begin
  if (RepeatCount>0) and (StrLen(ByteStr)>0) then
  begin
    dec(RepeatCount);
    KmtEncode := TRUE;
    exit;
  end;

  if NextByteFlag then
  begin
    b := NextByte;
    NextByteFlag := FALSE;
  end
  else if _lread(fv^.FileHandle,@b,1)=0 then
  begin
    KmtEncode := FALSE;
    exit;
  end
  else inc(fv^.ByteCount);

  Len := 0;

  b7 := b and $7f;

  {8 bit quoting}
  if Quote8 and (b <> b7) then
  begin
    TempStr[Len] := char(KmtMy.QBIN);
    inc(Len);
    b2 := b7;
  end
  else b2 := b;

  if (b7<$20) or (b7=$7F) then
  begin
    TempStr[Len] := char(KmtMy.QCTL);
    inc(Len);
    b2 := b2 xor $40;
  end
  else if (b7=KmtMy.QCTL) or
          (Quote8 and (b7=KmtMy.QBIN)) or
          (RepeatFlag and (b7=KmtMy.REPT)) then
  begin
    TempStr[Len] := char(KmtMy.QCTL);
    inc(Len);
  end;

  TempStr[Len] := char(b2);
  inc(Len);

  TempStr[Len] := #0;

  RepeatCount := 1;
  if _lread(fv^.FileHandle,@NextByte,1)=1 then
  begin
    inc(fv^.ByteCount);
    NextByteFlag := TRUE;
  end;

  while RepeatFlag and NextByteFlag and
        (NextByte=b) and (RepeatCount<94) do
  begin
    inc(RepeatCount);
    if _lread(fv^.FileHandle,@NextByte,1)=0 then
      NextByteFlag := FALSE
    else inc(fv^.ByteCount);
  end;

  if (Len*RepeatCount > Len+2) then
  begin
    ByteStr[0] := char(KmtMy.REPT);
    ByteStr[1] := char(KmtChar(RepeatCount));
    ByteStr[2] := #0;
    StrCat(ByteStr,TempStr);
    RepeatCount := 1;
  end
  else
    StrCopy(ByteStr,TempStr);

  dec(RepeatCount);
  KmtEncode := TRUE;
end;
end;

procedure KmtIncPacketNum(kv: PKmtVar);
begin
with kv^ do begin
  inc(PktNum);
  if PktNum >= PktNumOffset+64 then
    PktNumOffset := PktNumOffset + 64;
end;
end;

procedure KmtSendEOFPacket(fv: PFileVar; kv: PKmtVar; cv: PComVar);
begin
with kv^ do begin
  {close file}
  if fv^.FileOpen then
    _lclose(fv^.FileHandle);
  fv^.FileOpen := FALSE;

  KmtIncPacketNum(kv);

  KmtMakePacket(kv,PktNum-PktNumOffset,ord('Z'),0);
  KmtSendPacket(fv,kv,cv);

  KmtState := SendEOF;
end;
end;

procedure KmtSendNextData(fv: PFileVar; kv: PKmtVar; cv: PComVar);
var
  DataLen, DataLenNew: integer;
  NextFlag: boolean;
begin
with kv^ do begin
  SetDlgNum(fv^.HWin, IDC_PROTOBYTECOUNT,fv^.ByteCount);
  SetDlgPercent(fv^.HWin, IDC_PROTOPERCENT,
                fv^.ByteCount, fv^.FileSize);
  DataLen := 0;
  DataLenNew := 0;

  NextFlag := KmtEncode(fv,kv);
  if NextFlag then DataLenNew := DataLen + StrLen(ByteStr);
  while NextFlag and (DataLenNew < KmtYour.MAXL-KmtMy.CHKT-4) do
  begin
    StrCopy(@PktOut[4+DataLen],ByteStr);
    DataLen := DataLenNew;
    NextFlag := KmtEncode(fv,kv);
    if NextFlag then DataLenNew := DataLen + StrLen(ByteStr);
  end;
  if NextFlag then inc(RepeatCount);     

  if DataLen=0 then
  begin
    SetDlgNum(fv^.HWin, IDC_PROTOBYTECOUNT,fv^.ByteCount);
    SetDlgPercent(fv^.HWin, IDC_PROTOPERCENT,
                  fv^.ByteCount, fv^.FileSize);
    KmtSendEOFPacket(fv,kv,cv);
  end
  else begin
    KmtIncPacketNum(kv);

    KmtMakePacket(kv,PktNum-PktNumOffset,ord('D'),DataLen);
    KmtSendPacket(fv,kv,cv);

    KmtState := SendData;
  end;
end;
end;

procedure KmtSendEOTPacket(fv: PFileVar; kv: PKmtVar; cv: PComVar);
begin
with kv^ do begin
  KmtIncPacketNum(kv);
  KmtMakePacket(kv,PktNum-PktNumOffset,ord('B'),0);
  KmtSendPacket(fv,kv,cv);

  KmtState := SendEOT;
end;
end;

function KmtSendNextFile(fv: PFileVar; kv: PKmtVar; cv: PComVar): bool;
begin
with kv^ do begin
  KmtSendNextFile := TRUE;
  if not GetNextFname(fv) then
  begin
    KmtSendEOTPacket(fv,kv,cv);
    exit;
  end;

  {file open}
  fv^.FileHandle := _lopen(fv^.FullName,OF_READ);
  fv^.FileOpen := fv^.FileHandle>0;
  if not fv^.FileOpen then
  begin
    if not fv^.NoMsg then
      MessageBox(fv^.HWin,'Cannot open file','Tera Term: Error',
                 MB_ICONEXCLAMATION);
    KmtSendNextFile := FALSE;
    exit;
  end
  else
    fv^.FileSize := GetFSize(fv^.FullName);

  fv^.ByteCount := 0;

  SetDlgItemText(fv^.HWin, IDC_PROTOFNAME, @fv^.FullName[fv^.DirLen]);
  fv^.ByteCount := 0;
  SetDlgNum(fv^.Hwin, IDC_PROTOBYTECOUNT, fv^.ByteCount);
  SetDlgPercent(fv^.HWin, IDC_PROTOPERCENT,
                fv^.ByteCount, fv^.FileSize);

  KmtIncPacketNum(kv);
  StrCopy(@PktOut[4],@fv^.FullName[fv^.DirLen]); {put FName}
  FTConvFName(@kv^.PktOut[4]); {replace ' ' by '_' in FName}
  KmtMakePacket(kv,PktNum-PktNumOffset,ord('F'),
                StrLen(@fv^.FullName[fv^.DirLen]));
  KmtSendPacket(fv,kv,cv);

  RepeatCount := 0;
  NextByteFlag := FALSE;
  KmtState := SendFile;

end;
end;

procedure KmtSendReceiveInit(fv: PFileVar; kv: PKmtVar; cv: PComVar);
begin
with kv^ do begin
  PktNum := 0;
  PktNumOffset := 0;

  if StrLen(@fv^.FullName[fv^.DirLen]) >= KmtYour.MAXL-KmtMy.CHKT-4 then
    fv^.FullName[fv^.DirLen+KmtYour.MAXL-KmtMy.CHKT-4] := #0;

  StrCopy(@PktOut[4],@fv^.FullName[fv^.DirLen]);
  KmtMakePacket(kv,PktNum-PktNumOffset,ord('R'),
                StrLen(@fv^.FullName[fv^.DirLen]));
  KmtSendPacket(fv,kv,cv);

  KmtState := GetInit;
end;
end;

procedure KmtSendFinish(fv: PFileVar; kv: PKmtVar; cv: PComVar);
begin
with kv^ do begin
  PktNum := 0;
  PktNumOffset := 0;

  PktOut[4] := ord('F'); {Finish}
  KmtMakePacket(kv,PktNum-PktNumOffset,ord('G'),1);
  KmtSendPacket(fv,kv,cv);

  KmtState := Finish;
end;
end;

procedure KmtInit(fv: PFileVar; kv: PKmtVar; cv: PComVar; ts: PTTSet);
begin
with kv^ do begin
  StrCopy(fv^.DlgCaption,'Tera Term: Kermit ');
  case KmtMode of
    IdKmtSend:    StrCat(fv^.DlgCaption,'Send');
    IdKmtReceive: StrCat(fv^.DlgCaption,'Receive');
    IdKmtGet:     StrCat(fv^.DlgCaption,'Get');
    IdKmtFinish:  StrCat(fv^.DlgCaption,'Finish');
  end;

  SetWindowText(fv^.HWin,fv^.DlgCaption);
  SetDlgItemText(fv^.HWin, IDC_PROTOPROT, 'Kermit');

  fv^.FileOpen := FALSE;

  KmtState := Unknown;

  {default my parameters}
  KmtMy.MAXL := DefMAXL;
  KmtMy.TIME := DefTIME;
  KmtMy.NPAD := DefNPAD;
  KmtMy.PADC := DefPADC;
  KmtMy.EOL  := DefEOL;
  KmtMy.QCTL := DefQCTL;
  if (cv^.PortType=IdSerial) and
    (ts^.DataBit=IdDataBit7) then
    KmtMy.QBIN := ord('&')
  else
    KmtMy.QBIN := MyQBIN;
  KmtMy.CHKT := DefCHKT;
  KmtMy.REPT := MyREPT;

  {default your parameters}
  KmtYour := KmtMy;

  Quote8 := FALSE;
  RepeatFlag := FALSE;

  PktNumOffset := 0;
  PktNum := 0;

  fv^.LogFlag := ts^.LogFlag and LOG_KMT <> 0;
  if fv^.LogFlag then
    fv^.LogFile := _lcreat('KERMIT.LOG',0);

  case KmtMode of
    IdKmtSend: KmtSendInitPkt(fv,kv,cv,ord('S'));
    IdKmtReceive: begin
                 KmtState := ReceiveInit;
                 FTSetTimeOut(fv,kv^.KmtYour.TIME);
               end;  
    IdKmtGet: KmtSendInitPkt(fv,kv,cv,ord('I'));
    IdKmtFinish: KmtSendInitPkt(fv,kv,cv,ord('I'));
  end;

end;
end;

procedure KmtTimeOutProc(fv: PFileVar; kv: PKmtVar; cv: PComVar);
begin
with kv^ do
  case KmtState of
    SendInit: KmtSendPacket(fv,kv,cv);
    SendFile: KmtSendPacket(fv,kv,cv);
    SendData: KmtSendPacket(fv,kv,cv);
    SendEOF: KmtSendPacket(fv,kv,cv);
    SendEOT: KmtSendPacket(fv,kv,cv);
    ReceiveInit: KmtSendNack(fv,kv,cv,KmtChar(0));
    ReceiveFile: KmtSendNack(fv,kv,cv,NextSeq);
    ReceiveData: KmtSendNack(fv,kv,cv,NextSeq);
    ServerInit: KmtSendPacket(fv,kv,cv);
    GetInit: KmtSendPacket(fv,kv,cv);
    Finish: KmtSendPacket(fv,kv,cv);
  end;
end;

function KmtReadPacket(fv: PFileVar; kv: PKmtVar; cv: PComVar): bool;
var
  b: byte;
  c, PktNumNew: integer;
  GetPkt: boolean;
  FNBuff: array[0..49] of char;
  i, j, Len: integer;
begin
with kv^ do begin

  KmtReadPacket := TRUE;
  c := CommRead1Byte(cv,@b);

  GetPkt := FALSE;

  while (c>0) and (not GetPkt) do
  begin
    if b=1 then
    begin
      PktReadMode := WaitLen;
      PktIn[0] := b;
    end
    else
      case PktReadMode of
        WaitLen: begin
                   PktIn[1] := b;
                   PktInLen := KmtNum(b);
                   PktInCount := PktInLen;
                   PktInPtr := 2;
                   PktReadMode := WaitCheck;
                 end;
        WaitCheck: begin
                     PktIn[PktInPtr] := b;
                     inc(PktInPtr);
                     dec(PktInCount);
                     GetPkt := PktInCount=0;
                     if GetPkt then PktReadMode := WaitMark;
                   end;  
      end;

    if not GetPkt then c := CommRead1Byte(cv,@b);
  end;

  if not GetPkt then exit;

  if fv^.LogFlag then
  begin
    _lwrite(fv^.LogFile,'< ',2);
    _lwrite(fv^.LogFile,@PktIn[1],PktInLen+1);
    _lwrite(fv^.LogFile,#$0D#$0A,2);
  end;

  PktNumNew := KmtCalcPktNum(kv,PktIn[2]);

  GetPkt := KmtCheckPacket(kv);

  {Ack or Nack}
  if (PktIn[3]<>ord('Y')) and
     (PktIn[3]<>ord('N')) then
  begin
    if GetPkt then KmtSendAck(fv,kv,cv)
              else KmtSendNack(fv,kv,cv,PktIn[2]);
  end;

  if not GetPkt then exit;

  case PktIn[3] of
    Ord('B'): if KmtState = ReceiveFile then
              begin
                fv^.Success := TRUE;
                KmtReadPacket := FALSE;
                exit;
              end;
    Ord('D'): if (KmtState=ReceiveData) and
                 (PktNumNew>PktNum) then
                KmtDecode(fv,kv,nil,Len);
    Ord('E'): begin
        KmtReadPacket := FALSE;
        exit;
      end;
    Ord('F'): begin
        if (KmtState=ReceiveFile) or (KmtState=GetInit) then
        begin
          KmtMode := IdKmtReceive;

          Len := SizeOf(FNBuff);
          KmtDecode(fv,kv,FNBuff,Len);
          FNBuff[Len] := #0;
          GetFileNamePos(FNBuff,i,j);
          StrCopy(@fv^.FullName[fv^.DirLen],@FNBuff[j]);
          {file open}
          if not FTCreateFile(fv) then
          begin
            KmtReadPacket := FALSE;
            exit;
          end;
          KmtState := ReceiveData;
        end;
      end;

    Ord('S'): if (KmtState = ReceiveInit) or
                 (KmtState = GetInit) then
              begin     
                KmtMode := IdKmtReceive;
                KmtState := ReceiveFile;
              end;

    Ord('N'): case KmtState of
                SendInit:
                  if PktNumNew=PktNum then KmtSendPacket(fv,kv,cv);
                SendFile:
                  if PktNumNew=PktNum then KmtSendPacket(fv,kv,cv)
                  else if PktNumNew=PktNum+1 then
                  begin
                    KmtSendNextData(fv,kv,cv);
                  end;
                SendData:
                  if PktNumNew=PktNum then KmtSendPacket(fv,kv,cv)
                  else if PktNumNew=PktNum+1 then
                  begin
                    KmtSendNextData(fv,kv,cv);
                  end;
                SendEOF:
                  if PktNumNew=PktNum then KmtSendPacket(fv,kv,cv)
                  else if PktNumNew=PktNum+1 then
                  begin
                    if not KmtSendNextFile(fv,kv,cv) then
                    begin
                      KmtReadPacket := FALSE;
                      exit;
                    end;
                  end;
                SendEOT:
                  if PktNumNew=PktNum then KmtSendPacket(fv,kv,cv);
                ServerInit:
                  if PktNumNew=PktNum then KmtSendPacket(fv,kv,cv);
                GetInit:
                  if PktNumNew=PktNum then KmtSendPacket(fv,kv,cv);
                Finish:
                  if PktNumNew=PktNum then KmtSendPacket(fv,kv,cv);
              end;

    Ord('Y'): case KmtState of
                SendInit: if PktNumNew=PktNum then
                  begin
                    KmtParseInit(kv,TRUE);
                    if not KmtSendNextFile(fv,kv,cv) then
                    begin
                      KmtReadPacket := FALSE;
                      exit;
                    end;
                  end;
                SendFile:
                  if PktNumNew=PktNum then
                  begin
                    KmtSendNextData(fv,kv,cv);
                  end;
                SendData:
                  if PktNumNew=PktNum then
                  begin
                    KmtSendNextData(fv,kv,cv);
                  end else if PktNumNew+1=PktNum then                  
                    KmtSendPacket(fv,kv,cv);
                SendEOF:
                  if PktNumNew=PktNum then
                  begin
                    if not KmtSendNextFile(fv,kv,cv) then
                    begin
                      KmtReadPacket := FALSE;
                      exit;
                    end;
                  end;
                SendEOT:
                  if PktNumNew=PktNum then
                  begin
                    fv^.Success := TRUE;
                    KmtReadPacket := FALSE;
                    exit;
                  end;
                ServerInit:
                  if PktNumNew=PktNum then
                  begin
                    KmtParseInit(kv,TRUE);
                    case KmtMode of
                      IdKmtGet: KmtSendReceiveInit(fv,kv,cv);
                      IdKmtFinish: KmtSendFinish(fv,kv,cv);
                    end;
                  end;
                Finish:
                  if PktNumNew=PktNum then
                  begin
                    fv^.Success := TRUE;
                    KmtReadPacket := FALSE;
                    exit;
                  end;
              end;

    Ord('Z'): if KmtState = ReceiveData then
              begin
                if fv^.FileOpen then _lclose(fv^.FileHandle);
                fv^.FileOpen := FALSE;
                KmtState := ReceiveFile;
              end;
  end;

  if KmtMode = IdKmtReceive then
  begin
    NextSeq := KmtChar((KmtNum(PktIn[2])+1) mod 64);
    PktNum := PktNumNew;
    if PktNum > PktNumOffset+63 then PktNumOffset := PktNumOffset + 64;
  end;

  SetDlgNum(fv^.HWin, IDC_PROTOPKTNUM, PktNum);
end;
end;

procedure KmtCancel(fv: PFileVar; kv: PKmtVar; cv: PComVar);
begin
with kv^ do begin
  KmtIncPacketNum(kv);
  StrCopy(@PktOut[4],'Cancel');
  KmtMakePacket(kv,PktNum-PktNumOffset,ord('E'),
                StrLen(@PktOut[4]));
  KmtSendPacket(fv,kv,cv);
end;
end;

end.