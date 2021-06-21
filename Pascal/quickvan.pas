{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTFILE.DLL, Quick-VAN protocol}
unit QuickVAN;

interface

uses WinTypes, WinProcs, WinDos, Strings, TTTypes, TTFTypes,
     TTCommon, FTLib, DlgLib, TTLib;

procedure QVInit(fv: PFileVar; qv: PQVVar; cv: PComVar; ts: PTTSet);
procedure QVCancel(fv: PFileVar; qv: PQVVar; cv: PComVar);
procedure QVTimeOutProc(fv: PFileVar; qv: PQVVar; cv: PComVar);
function QVReadPacket(fv: PFileVar; qv: PQVVar; cv: PComVar): bool;
function QVSendPacket(fv: PFileVar; qv: PQVVar; cv: PComVar): bool;

implementation
{$i tt_res.inc}

const
  TimeOutCAN = 1;
  TimeOutCANSend = 2;
  TimeOutRecv  = 20;
  TimeOutSend  = 60;
  TimeOutEOT = 5;

  EOT = $04;
  ACK = $06;
  NAK = $15;
  CAN = $18;


function QVRead1Byte(fv: PFileVar; qv: PQVVar; cv: PComVar; var b: byte): integer;
begin
with qv^ do begin
  if CommRead1Byte(cv,@b) = 0 then
  begin
    QVRead1Byte := 0;
    exit;
  end;
  QVRead1Byte := 1;
  if fv^.LogFlag then
  begin
    if fv^.LogState<>1 then
    begin
      fv^.LogState := 1;
      fv^.LogCount := 0;
      _lwrite(fv^.LogFile,#$0D#$0A'<<<'#$0D#$0A,7);
    end;
    FTLog1Byte(fv,b);
  end;
end;
end;

function QVWrite(fv: PFileVar; qv: PQVVar; cv: PComVar; B: PChar; C: integer): integer;
var
  i, j: integer;
begin
with qv^ do begin
  i := CommBinaryOut(cv,B,C);
  QVWrite := i;
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

procedure QVSendNAK(fv: PFileVar; qv: PQVVar; cv: PComVar);
var
  b: byte;
begin
with qv^ do begin
  b := NAK;
  QVWrite(fv,qv,cv,@b, 1);
  FTSetTimeOut(fv,TimeOutRecv);
end;
end;

procedure QVSendACK(fv: PFileVar; qv: PQVVar; cv: PComVar);
var
  b: byte;
begin
with qv^ do begin
  FTSetTimeOut(fv,0);
  b := ACK;
  QVWrite(fv,qv,cv,@b, 1);
  QVState := QV_Close;
end;
end;

procedure QVInit(fv: PFileVar; qv: PQVVar; cv: PComVar; ts: PTTSet);
begin
with qv^ do begin
  WinSize := ts^.QVWinSize;
  fv^.LogFlag := ts^.LogFlag and LOG_QV <> 0;

  if fv^.LogFlag then
    fv^.LogFile := _lcreat('QUICKVAN.LOG',0);
  fv^.LogState := 2;
  fv^.LogCount := 0;

  fv^.FileOpen := FALSE;
  fv^.ByteCount := 0;

  if QVMode=IdQVReceive then
    StrCat(fv^.DlgCaption,'Tera Term: Quick-VAN Receive');
  SetWindowText(fv^.HWin, fv^.DlgCaption);
  SetDlgItemText(fv^.HWin, IDC_PROTOPROT, 'Quick-VAN');

  SeqNum := 0;
  FileNum := 0;
  CanFlag := FALSE;
  PktOutCount := 0;
  PktOutPtr := 0;

  Ver := 1; {version}

  case QVMode of
    IdQVSend: begin
        QVState := QV_SendInit1;
        PktState := QVpktSTX;
        FTSetTimeOut(fv,TimeOutSend);
      end;
    IdQVReceive: begin
        QVState := QV_RecvInit1;
        PktState := QVpktSOH;
        RetryCount := 10;
        QVSendNAK(fv,qv,cv);
      end;
  end;

end;
end;

procedure QVCancel(fv: PFileVar; qv: PQVVar; cv: PComVar);
var
  b: byte;
begin
with qv^ do begin
  if (QVState=QV_Close) or
     (QVState=QV_RecvEOT) or
     (QVState=QV_Cancel) then
    exit;

  {flush send buffer}
  PktOutCount := 0;
  {send CAN}
  b := CAN;
  QVWrite(fv,qv,cv,@b, 1);

  if (QVMode=IdQVReceive) and
     ((QVState=QV_RecvData) or
      (QVState=QV_RecvDataRetry)) then
  begin
    FTSetTimeOut(fv,TimeOutEOT);
    QVState := QV_RecvEOT;
    exit;
  end;
  FTSetTimeOut(fv,TimeOutCANSend);
  QVState := QV_Cancel;
end;
end;

function QVCountRetry(fv: PFileVar; qv: PQVVar; cv: PComVar): bool;
begin
with qv^ do begin
  dec(RetryCount);
  if RetryCount<=0 then
  begin
    QVCancel(fv,qv,cv);
    QVCountRetry := TRUE;
  end
  else
    QVCountRetry := FALSE;
end;
end;

procedure QVResendPacket(fv: PFileVar; qv: PQVVar);
begin
with qv^ do
begin
  PktOutCount := PktOutLen;
  PktOutPtr := 0;
  if QVMode=IdQVReceive then
    FTSetTimeOut(fv,TimeOutRecv)
  else
    FTSetTimeOut(fv,TimeOutSend);
end;
end;

procedure QVSetResPacket(qv: PQVVar; Typ, Num: byte; DataLen: integer);
var
  i: integer;
  Sum: byte;
begin
with qv^ do begin
  PktOut[0] := STX;
  PktOut[1] := Typ;
  PktOut[2] := Num or $80;
  Sum := 0;
  for i := 0 to 2 + DataLen do
    Sum := Sum + PktOut[i];
  PktOut[3+DataLen] := Sum or $80;  
  PktOut[4+DataLen] := $0D;
  PktOutCount := 5 + DataLen;
  PktOutLen := PktOutCount;
  PktOutPtr := 0;
end;
end;

procedure QVSendVACK(fv: PFileVar; qv: PQVVar; Seq: byte);
begin
with qv^ do
begin
  FTSetTimeOut(fv,TimeOutRecv);
  RetryCount := 10;
  QVState := QV_RecvData;
  if SeqNum mod AValue = 0 then
    QVSetResPacket(qv,ord('A'),Seq,0);
end;
end;

procedure QVSendVNAK(fv: PFileVar; qv: PQVVar);
begin
with qv^ do
begin
  FTSetTimeOut(fv,TimeOutRecv);
  QVSetResPacket(qv,ord('N'),Lo(SeqNum+1),0);
  if QVState=QV_RecvData then
  begin
    RetryCount := 10;
    QVState := QV_RecvDataRetry;
  end;
end;
end;

procedure QVSendVSTAT(fv: PFileVar; qv: PQVVar);
begin
with qv^ do
begin
  FTSetTimeOut(fv,TimeOutRecv);
  PktOut[3] := $30;
  QVSetResPacket(qv,ord('T'),Lo(SeqNum),1);
  RetryCount := 10;
  QVState := QV_RecvNext;
end;
end;

procedure QVTimeOutProc(fv: PFileVar; qv: PQVVar; cv: PComVar);
begin
with qv^ do
begin
  if (QVState=QV_Cancel) or
     (QVState=QV_RecvEOT) then
  begin
    QVState := QV_Close;
    exit;
  end;

  if (QVMode=IdQVSend) then
  begin
    QVCancel(fv,qv,cv);
    exit;
  end;

  if CanFlag then
  begin                 
    CanFlag := FALSE;
    QVState := QV_Close;
    exit;
  end;

  if (QVState<>QV_RecvData) and
     QVCountRetry(fv,qv,cv) then exit;

  PktState := QVpktSOH;
  case QVState of
    QV_RecvInit1: QVSendNAK(fv,qv,cv);
    QV_RecvInit2: QVResendPacket(fv,qv); {resend RINIT}
    QV_RecvData,
    QV_RecvDataRetry: begin
        if SeqNum=0 then
          QVResendPacket(fv,qv) {resend RPOS}
        else
          QVSendVNAK(fv,qv);
      end;
    QV_RecvNext: QVResendPacket(fv,qv); {resend VSTAT}
  end;

end;
end;

function QVParseSINIT(fv: PFileVar; qv: PQVVar): BOOL;
var
  i: integer;
  b, n: byte;
  WS: word;
begin
with qv^ do begin
  if QVState<>QV_RecvInit1 then
  begin
    QVParseSINIT := TRUE;
    exit;
  end;

  QVParseSINIT := FALSE;
  for i := 0 to 5 do
  begin
    b := PktIN[3+i];
    if (i=5) and (b=0) then
      b := $30;
    if (b<$30) or (b>$39) then exit;
    n := b - $30;
    case i of
      0: if n<Ver then Ver := n;
      2: WS := n;
      3: begin
           WS := WS*10 + word(n);
           if WS<WinSize then
             WinSize := WS;
         end;   
    end;
  end;
  AValue := WinSize div 2;
  if AValue=0 then AValue := 1;

  {Send RINIT}
  PktOut[3] := Ver + $30;
  PktOut[4] := $30;
  PktOut[5] := WinSize div 10 + $30;
  PktOut[6] := WinSize mod 10 + $30;
  PktOut[7] := $30;
  PktOut[8] := 0;
  QVSetResPacket(qv,ord('R'),0,6);
  QVState := QV_RecvInit2;
  RetryCount := 10;
  FTSetTimeOut(fv,TimeOutRecv);

  QVParseSINIT := TRUE;
end;
end;

function QVParseVFILE(fv: PFileVar; qv: PQVVar): BOOL;

  function GetNum2(qv: PQVVar; var i: integer; var w: word): BOOL;
  var
    Ok: BOOL;
    j: integer;
    b: byte;
  begin
  with qv^ do begin
    w := 0;
    Ok := FALSE;
    for j := i to i + 1 do
    begin
      b := PktIn[j];
      case b of
        $30..$39: begin
          w := w*10 + word(b - $30);
          Ok := TRUE;
        end;
      end;
    end;
    i := i + 2;
    GetNum2 := Ok;
  end;
  end;

var
  i, j: integer;
  w: word;
  b: byte;
begin
with qv^ do begin
  if (QVState<>QV_RecvInit2) and
     (QVState<>QV_RecvNext) then
  begin
    QVParseVFILE := TRUE;
    exit;
  end;
  QVParseVFILE := FALSE;

  {file name}
  GetFileNamePos(@PktIn[5],i,j);
  with fv^ do begin
  StrCopy(@FullName[DirLen],@PktIn[5+j]);
  end;
  {file open}
  if not FTCreateFile(fv) then exit;
  {file size}
  i := StrLen(@PktIn[5]) + 6;
  repeat
    b := PktIn[i];
    case b of
      $30..$39: fv^.FileSize :=
        fv^.FileSize * 10 + b - $30;
    end;
    inc(i);
  until (b<$30) or (b>$39);
  {year}
  if GetNum2(qv,i,w) then
  begin
    Year := w * 100; 
    if GetNum2(qv,i,w) then
      Year := Year + w
    else
      Year := 0;
  end
  else Year := 0;
  {month}
  GetNum2(qv,i,Month);
  {date}
  GetNum2(qv,i,Day);
  {hour}
  if not GetNum2(qv,i,Hour) then
    Hour := 24;
  {min}
  GetNum2(qv,i,Min);
  {sec}
  GetNum2(qv,i,Sec);

  SetDlgNum(fv^.HWin, IDC_PROTOBYTECOUNT, 0);
  if fv^.FileSize>0 then
    SetDlgPercent(fv^.HWin, IDC_PROTOPERCENT,0,fv^.FileSize);

  {Send VRPOS}
  QVSetResPacket(qv,ord('P'),0,0);
  QVState := QV_RecvData;
  SeqNum := 0;
  RetryCount := 10;
  FTSetTimeOut(fv,TimeOutRecv);

  QVParseVFILE := TRUE;
end;
end;

function QVParseVENQ(fv: PFileVar; qv: PQVVar): BOOL;
var
  f: text;
  ftime : Longint;
  dt : TDateTime;
  FN: string[80];
begin
with qv^ do begin
  if (QVState<>QV_RecvData) and
     (QVState<>QV_RecvDataRetry) then
  begin
    QVParseVENQ := TRUE;
    exit;
  end;
  QVParseVENQ := FALSE;

  if PktIn[3]=Lo(SeqNum) then
  begin
    if PktIn[4]=$30 then
    begin
      if fv^.FileOpen then
      begin
        _lclose(fv^.FileHandle);
        fv^.FileOpen := FALSE;
        {set file date & time}
        if (Year<>0) or (Hour<24) then
        begin 
          FN := StrPas(fv^.FullName);
          Assign(f,FN);
          Reset(f);
          GetFTime(f,ftime);
          UnpackTime(ftime,dt);
          if Year<>0 then
          begin
            dt.year := Year;
            dt.month := Month;
            dt.day := Day;
          end;
          if (Hour<24) then
          begin
            dt.hour := Hour;
            dt.min := Min;
            dt.sec := Sec;
          end;
          PackTime(dt,ftime);
          SetFTime(f,ftime);
          Close(f);
        end;
      end;
      QVSendVSTAT(fv,qv);
    end
    else
      exit; {exit and cancel}
  end
  else begin
    if QVState=QV_RecvDataRetry then
    begin
      dec(RetryCount);
      if RetryCount<0 then
        exit; {exit and cancel}
    end;
    QVSendVNAK(fv,qv);
  end;

  QVParseVENQ := TRUE;
end;
end;

procedure QVWriteToFile(fv: PFileVar; qv: PQVVar);
var
  C: integer;
begin
with qv^ do begin
  if fv^.FileSize - fv^.ByteCount < 128 then
    C := fv^.FileSize-fv^.ByteCount
  else
    C := 128;
  _lwrite(fv^.FileHandle,@PktIn[3],C);
  fv^.ByteCount := fv^.ByteCount + C;

  SetDlgNum(fv^.HWin, IDC_PROTOPKTNUM, SeqNum);
  SetDlgNum(fv^.HWin, IDC_PROTOBYTECOUNT, fv^.ByteCount);
  if fv^.FileSize>0 then
    SetDlgPercent(fv^.HWin, IDC_PROTOPERCENT,fv^.ByteCount,fv^.FileSize);
end;
end;

function QVCheckWindow8(qv: PQVVar; w0, w1: word; b: byte; var w: word): bool;
var
  i: word;
begin
  QVCheckWindow8 := TRUE;
  for i := w0 to w1 do
    if Lo(i)=b then
    begin
      w := i;
      exit;
    end;
  QVCheckWindow8 := FALSE;
end;

function QVReadPacket(fv: PFileVar; qv: PQVVar; cv: PComVar): bool;
var
  b: byte;
  w0, w1, w: word;
  i, c: integer;
  GetPkt, EOTFlag, Ok: BOOL;
begin
with qv^ do begin
  if QVState = QV_Close then
  begin
    QVReadPacket := FALSE;
    exit;
  end
  else
    QVReadPacket := TRUE;

  c := 1;
  while (c>0) and (PktOutCount>0) do
  begin
    c := QVWrite(fv,qv,cv,@PktOut[PktOutPtr],PktOutCount);
    PktOutPtr := PktOutPtr + c;
    PktOutCount := PktOutCount - c;
  end;

  c := QVRead1Byte(fv,qv,cv,b);
  if (c>0) and CanFlag then
  begin
    CanFlag := FALSE;
    FTSetTimeOut(fv,TimeOutRecv);
  end;

  EOTFlag := FALSE;
  GetPkt := FALSE;
  while (c>0) and (not GetPkt) do
  begin
    CanFlag := (b=CAN) and (PktState<>QVpktDATA);
    EOTFlag := (b=EOT) and (PktState<>QVpktDATA);

    case PktState of
      QVpktSOH: if b=SOH then
                begin
                  PktIn[0] := b;
                  PktState := QVpktBLK;
                end;
      QVpktBLK: begin
                  PktIn[1] := b;
                  PktState := QVpktBLK2;
                end;
      QVpktBLK2: begin
                  PktIn[2] := b;
                  if (PktIn[1]=0) and
                     (b>=$30) and (b<=$32) then {function block}
                  begin
                    CheckSum := SOH + b;
                    PktInPtr := 3;
                    PktInCount := 129;
                    PktState := QVpktData;
                  end   
                  else if (QVState=QV_RecvData) and
                          (b xor PktIn[1] = $ff) then
                  begin
                    if SeqNum+1<WinSize then
                      w0 := 0
                    else
                      w0 := SeqNum+1-WinSize;
                    w1 := SeqNum+1;
                    if (SeqNum=0) and (PktIn[1]=1) or
                       (SeqNum>0) and
                       QVCheckWindow8(qv,w0,w1,PktIn[1],w)
                    then begin
                      CheckSum := 0;
                      PktInPtr := 3;
                      PktInCount := 129;
                      PktState := QVpktData;
                    end
                    else begin
                      PktState :=QVpktSOH;
                      QVSendVNAK(fv,qv);
                    end;  
                  end
                  else if (QVState=QV_RecvDataRetry) and
                          (b xor PktIn[1] = $ff) then
                  begin
                    if PktIn[1]=Lo(SeqNum+1) then
                    begin
                      CheckSum := 0;
                      PktInPtr := 3;
                      PktInCount := 129;
                      PktState := QVpktData;
                    end
                    else begin
                      PktState :=QVpktSOH;
                      FTSetTimeOut(fv,TimeOutRecv);
                    end;  
                  end
                  else
                    PktState :=QVpktSOH;
                end;
      QVpktDATA: begin
                  PktIn[PktInPtr] := b;
                  inc(PktInPtr);
                  dec(PktInCount);
                  GetPkt := PktInCount=0;
                  if GetPkt then
                    PktState := QVpktSOH
                  else
                    CheckSum := CheckSum + b;
                end;
    else
      PktState := QVpktSOH;
    end;

    if not GetPkt then c := QVRead1Byte(fv,qv,cv,b);
  end;

  if not GetPkt then
  begin
    if CanFlag then
      FTSetTimeOut(fv,TimeOutCan);

    if EOTFlag then
      case QVState of
        QV_RecvInit2,
        QV_RecvNext: begin
            QVSendACK(fv,qv,cv);
            fv^.Success := TRUE;
            exit;
          end;
        QV_RecvEOT: QVState := QV_Close;
      end;
    exit;
  end;

  if (PktIn[1]=0) and
     (PktIn[2]>=$30) and (PktIn[2]<=$32) then
  begin {function block}
    if CheckSum<>PktIn[PktInPtr-1] then
    begin {bad checksum}
      case QVState of
        QV_RecvInit1:
          if (PktIn[2]=$30) and {SINIT}
             not QVCountRetry(fv,qv,cv) then
            QVSendNAK(fv,qv,cv);
        QV_RecvInit2,
        QV_RecvNext:
          if (PktIn[2]=$31) and {VFILE}
             not QVCountRetry(fv,qv,cv) then
            QVResendPacket(fv,qv);
        QV_RecvData:
          if PktIn[2]=$32 then {VENQ}
            QVSendVNAK(fv,qv);
        QV_RecvDataRetry:
          if (PktIn[2]=$32) and {VENQ}
             not QVCountRetry(fv,qv,cv) then
            QVSendVNAK(fv,qv);
      end;
      exit;
    end;
    Ok := FALSE;
    case PktIn[2] of {function type}
      $30: Ok := QVParseSINIT(fv,qv);
      $31: Ok := QVParseVFILE(fv,qv);
      $32: Ok := QVParseVENQ(fv,qv);
    end;
    if not Ok then
      QVCancel(fv,qv,cv);
  end
  else begin {VDAT block}
    if (QVState<>QV_RecvData) and
       (QVState<>QV_RecvDataRetry) then
      exit;
    if PktIn[1]<>Lo(SeqNum+1) then
      QVSendVACK(fv,qv,PktIn[1])
    else if CheckSum=PktIn[PktInPtr-1] then
    begin
      QVSendVACK(fv,qv,PktIn[1]);
      inc(SeqNum);
      QVWriteToFile(fv,qv);
    end
    else {bad checksum}
      QVSendVNAK(fv,qv);
  end;

end;
end;

procedure QVSetPacket(qv: PQVVAr; Num, Typ: byte);
var
  i: integer;
begin
with qv^ do begin
  PktOut[0] := SOH;
  PktOut[1] := Num;
  PktOut[2] := Typ;
  if Num xor Typ = $FF then
    CheckSum := 0
  else
    CheckSum := SOH + Num + Typ;
  for i := 3 to 130 do
    CheckSum := CheckSum + PktOut[i];
  PktOut[131] := CheckSum;
  PktOutLen := 132;
  PktOutCount := 132;
  PktOutPtr := 0;   
end;
end;

procedure QVSendSINIT(fv: PFileVar; qv: PQVVar);
var
  i: integer;
begin
with qv^ do begin
  PktOut[3] := Ver + $30;
  PktOut[4] := $30;
  PktOut[5] := WinSize div 10 + $30;
  PktOut[6] := WinSize mod 10 + $30;
  PktOut[7] := $30;
  PktOut[8] := 0;
  for i := 6 to 127 do
    PktOut[3+i] := 0;
  {send SINIT}
  QVSetPacket(qv,0,$30);
  QVState := QV_SendInit2;
  PktState := QVpktSTX;
  FTSetTimeOut(fv,TimeOutSend);
end;
end;

procedure QVSendEOT(fv: PFileVar; qv: PQVVar; cv: PComVar);
var
  b: byte;
begin
with qv^ do begin
  if QVState=QV_SendEnd then
  begin
    if QVCountRetry(fv,qv,cv) then
      exit;
  end
  else begin
    RetryCount := 10;
    QVState := QV_SendEnd;
  end;

  b := EOT;
  QVWrite(fv,qv,cv,@b, 1);
  FTSetTimeOut(fv,TimeOutSend);
end;
end;

procedure QVSendVFILE(fv: PFileVar; qv: PQVVar; cv: PComVar);

  procedure PutNum2(qv: PQVVar; Num: word; var i: integer);
  begin
  with qv^ do begin
    PktOut[i] := Num div 10 + $30;
    inc(i);
    PktOut[i] := Num mod 10 + $30;
    inc(i);
  end;
  end;

var
  i, j: integer;
  f: text;
  ftime : Longint;
  dt : TDateTime;
  FN: string[80];
  NumPStr: string[10];
begin
with qv^ do begin
  if not GetNextFname(fv) then
  begin 
    QVSendEOT(fv,qv,cv);
    exit;
  end;

  {find file and get file info}
  fv^.FileSize := GetFSize(fv^.FullName);
  if fv^.FileSize>0 then
  begin
    FileEnd := fv^.FileSize shr 7;
    if fv^.FileSize and $7F <> 0 then
      inc(FileEnd);
    {file date}
    FN := StrPas(fv^.FullName);
    Assign(f,FN);
    Reset(f);
    GetFTime(f,ftime);
    UnpackTime(ftime,dt);
    Close(f);
  end
  else begin
    QVCancel(fv,qv,cv);
    exit;
  end;

  {file open}
  fv^.FileHandle := _lopen(fv^.FullName,of_Read);
  fv^.FileOpen := fv^.FileHandle>0;
  if not fv^.FileOpen then
  begin
    QVCancel(fv,qv,cv);
    exit;
  end;
  {file num}
  inc(FileNum);
  i := 3;
  PutNum2(qv,FileNum,i);
  {file name}
  SetDlgItemText(fv^.HWin, IDC_PROTOFNAME, @fv^.FullName[fv^.DirLen]);
  StrCopy(@PktOut[i],StrUpper(@fv^.FullName[fv^.DirLen]));
  FTConvFName(@PktOut[i]); {replace ' ' by '_' in FName}
  i := StrLen(@PktOut[i]) + i;
  PktOut[i] := 0;
  inc(i);
  {file size}
  Str(fv^.FileSize,NumPStr);
  StrPCopy(@PktOut[i],NumPStr);
  i := StrLen(@PktOut[i]) + i;
  PktOut[i] := 0;
  inc(i);
  {date}
  PutNum2(qv,dt.Year div 100,i);
  PutNum2(qv,dt.Year mod 100,i);
  PutNum2(qv,dt.Month,i);
  PutNum2(qv,dt.Day,i);
  {time}
  PutNum2(qv,dt.Hour,i);
  PutNum2(qv,dt.Min,i);
  PutNum2(qv,dt.Sec,i);
  for j := i to 130 do
    PktOut[j] := 0;

  {send VFILE}
  QVSetPacket(qv,0,$31);
  if FileNum=1 then
    QVState := QV_SendInit3
  else
    QVState := QV_SendNext;
  PktState := QVpktSTX;
  FTSetTimeOut(fv,TimeOutSend);
end;
end;

procedure QVSendVDATA(fv: PFileVar; qv: PQVVar);
var
  i, C: integer;
  Pos: longint;
begin
with qv^ do begin
  if (QVState<>QV_SendData) and
     (QVState<>QV_SendDataRetry) then
    exit;

  if (SeqSent<WinEnd) and
     (SeqSent<FileEnd) and
     not EnqFlag then
  begin
    inc(SeqSent);
    Pos := longint(SeqSent-1) shl 7;
    if SeqSent=FileEnd then
      C := fv^.FileSize - Pos
    else
      C := 128;
    {read data from file}   
    _llseek(fv^.FileHandle,Pos,0);
    _lread(fv^.FileHandle,@PktOut[3],C);
    fv^.ByteCount := Pos + longint(C);
    SetDlgNum(fv^.HWin, IDC_PROTOPKTNUM, SeqSent);
    SetDlgNum(fv^.HWin, IDC_PROTOBYTECOUNT, fv^.ByteCount);
    SetDlgPercent(fv^.HWin, IDC_PROTOPERCENT,
                  fv^.ByteCount, fv^.FileSize);
    for i := C to 127 do
      PktOut[3+i] := 0;
    {send VDAT}
    QVSetPacket(qv,Lo(SeqSent),Lo(not SeqSent));
    if SeqSent=WinEnd then {window close}
      FTSetTimeOut(fv,TimeOutSend);
  end
  else if (SeqSent=FileEnd) and
          not EnqFlag then
  begin
    PktOut[3] := Lo(FileEnd);
    PktOut[4] := $30;
    for i := 2 to 127 do
      PktOut[3+i] := 0;
    {send VENQ}
    QVSetPacket(qv,0,$32);
    FTSetTimeOut(fv,TimeOutSend);
    EnqFlag := TRUE;
  end;

end;
end;

procedure QVParseRINIT(fv: PFileVar; qv: PQVVar; cv: PComVar);
var
  i: integer;
  b, n: byte;
  WS: word;
  Ok: BOOL;
begin
with qv^ do begin
  if PktIn[2]<>$80 then exit;

  Ok := TRUE;
  for i := 0 to 3 do
  begin
    b := PktIN[3+i];
    if (b<$30) or (b>$39) then
      Ok := FALSE;
    n := b - $30;
    case i of
      0: if n<Ver then Ver := n;
      2: WS := n;
      3: begin
           WS := WS*10 + word(n);
           if WS<WinSize then
             WinSize := WS;
         end;   
    end;
  end;
  if not Ok then
  begin
    QVCancel(fv,qv,cv);
    exit;
  end;

  {Send VFILE}
  RetryCount := 10;
  QVSendVFILE(fv,qv,cv);
end;
end;

procedure QVParseVRPOS(fv: PFileVar; qv: PQVVar; cv: PComVar);
var
  i: integer;
  b: byte;
begin
with qv^ do begin
  SeqNum := 0;
  if PktInPtr-3 >= 3 then
    for i := 3 to PktInPtr-3 do
    begin
      b := PktIn[i];
      if (b<$30) or (b>$39) then
      begin
        QVCancel(fv,qv,cv);
        exit;
      end;
      SeqNum := SeqNum * 10 + word(b - $30);
    end;

  if SeqNum >= FileEnd then
  begin
    QVCancel(fv,qv,cv);
    exit;
  end;

  SeqSent := SeqNum;
  WinEnd := SeqNum + WinSize;
  if WinEnd>FileEnd then
    WinEnd := FileEnd;
  EnqFlag := FALSE;
  QVState := QV_SendData;
  FTSetTimeOut(fv,0);

end;
end;

function QVCheckWindow7(qv: PQVVar; w0, w1: word; b: byte; var w: word): bool;
var
  i: word;
begin
  QVCheckWindow7 := TRUE;
  for i := w0 to w1 do
    if (i and $7F)=(b and $7F) then
    begin
      w := i;
      exit;
    end;
  QVCheckWindow7 := FALSE;
end;


procedure QVParseVACK(fv: PFileVar; qv: PQVVar);
var
  w: word;
begin
with qv^ do begin
  if QVCheckWindow7(qv,SeqNum+1,SeqSent,PktIn[2],w) then
  begin
    FTSetTimeOut(fv,0);
    SeqNum := w;
    WinEnd := SeqNum + WinSize;
    if WinEnd>FileEnd then
      WinEnd := FileEnd;
    if QVState=QV_SendDataRetry then
    begin
      RetryCount := 10;
      QVState := QV_SendData;
    end;
  end;
end;
end;

procedure QVParseVNAK(fv: PFileVar; qv: PQVVar; cv: PComVar);
var
  w: word;
begin
with qv^ do begin
  if (QVState=QV_SendDataRetry) and
     (PktIn[1]=Lo(SeqNum+1)) then
  begin
    FTSetTimeOut(fv,0);
    if QVCountRetry(fv,qv,cv) then
      exit;
    SeqSent := SeqNum;
    WinEnd := SeqNum + WinSize;
    if WinEnd>FileEnd then
      WinEnd := FileEnd;
    EnqFlag := FALSE;
    exit;
  end;

  if QVCheckWindow7(qv,SeqNum+1,SeqSent+1,PktIn[2],w) then
  begin
    FTSetTimeOut(fv,0);
    SeqNum := w-1;
    SeqSent := SeqNum;
    WinEnd := SeqNum + WinSize;
    if WinEnd>FileEnd then
      WinEnd := FileEnd;
    EnqFlag := FALSE;
    RetryCount := 10;
    QVState := QV_SendDataRetry;
  end;
end;
end;

procedure QVParseVSTAT(fv: PFileVar; qv: PQVVar; cv: PComVar);
begin
with qv^ do begin
  if EnqFlag and (PktIn[3]=$30) then
  begin
    if fv^.FileOpen then
      _lclose(fv^.FileHandle);
    fv^.FileOpen := FALSE;
    EnqFlag := FALSE;
    RetryCount := 10;
    QVSendVFILE(fv,qv,cv);
  end
  else
    QVCancel(fv,qv,cv);
end;
end;

function QVSendPacket(fv: PFileVar; qv: PQVVar; cv: PComVar): bool;
var
  b: byte;
  c, i: integer;
  GetPkt: BOOL;
begin
with qv^ do begin
  if QVState = QV_Close then
  begin
    QVSendPacket := FALSE;
    exit;
  end
  else
    QVSendPacket := TRUE;

  c := QVRead1Byte(fv,qv,cv,b);
  if (c=0) and CanFlag then
  begin
    if (QVState=QV_SendData) or
       (QVState=QV_SendDataRetry) then
    begin
      b := EOT;
      QVWrite(fv,qv,cv,@b, 1);
    end;
    QVState := QV_Close;
    QVSendPacket := FALSE;
    exit;
  end;
  CanFlag := FALSE;

  GetPkt := FALSE;
  while (c>0) and (not GetPkt) do
  begin
    CanFlag := (b=CAN) and (PktState<>QVpktCR);

    if b=NAK then
      case QVState of
        QV_SendInit1: begin
            RetryCount := 10;
            QVSendSINIT(fv,qv);
          end;
        QV_SendInit2: begin
            if QVCountRetry(fv,qv,cv) then
              exit;
            QVSendSINIT(fv,qv);
          end;
      end;

    if QVState=QV_SendEnd then
    begin
      if b=ACK then
      begin
        fv^.Success := TRUE;
        QVSendPacket := FALSE;
        exit;
      end;
      QVSendEOT(fv,qv,cv);
    end;

    case PktState of
      QVpktSTX:
        if b=STX then
        begin
          PktIn[0] := b;
          PktInPtr := 1;
          PktState := QVpktCR;
        end;
      QVpktCR:
        begin
          PktIn[PktInPtr] := b;
          inc(PktInPtr);
          GetPkt := b=CR;
          if GetPkt or (PktInPtr>=128) then
            PktState := QVpktSTX;
        end;
    else
      PktState := QVpktSTX;
    end;
    if not GetPkt then c := QVRead1Byte(fv,qv,cv,b);
  end;

  if GetPkt then
  begin
    CheckSum := 0;
    for i := 0 to PktInPtr-3 do
      CheckSum := CheckSum + PktIn[i];
    GetPkt := (CheckSum or $80) = PktIn[PktInPtr-2];
  end;
  if GetPkt then
    case QVState of
      QV_SendInit2:
        if PktIn[1]=ord('R') then {RINIT}
          QVParseRInit(fv,qv,cv);
      QV_SendInit3:
        case PktIn[1] of
          ord('P'): QVParseVRPOS(fv,qv,cv);
          ord('R'): begin {RINIT}
              if QVCountRetry(fv,qv,cv) then
                exit;
              QVResendPacket(fv,qv); {resend VFILE}
            end;
        end;
      QV_SendData:
        case PktIn[1] of
          ord('A'): QVParseVACK(fv,qv);
          ord('N'): QVParseVNAK(fv,qv,cv);
          ord('T'): QVParseVSTAT(fv,qv,cv);
          ord('P'): {VRPOS}
            if SeqNum=0 then
            begin
              FTSetTimeOut(fv,0);
              SeqSent := 0;
              WinEnd := WinSize;
              if WinEnd>FileEnd then
                WinEnd := FileEnd;
              EnqFlag := FALSE;
              RetryCount := 10;
              QVState := QV_SendDataRetry;              
            end;
        end;
      QV_SendDataRetry:
        case PktIn[1] of
          ord('A'): QVParseVACK(fv,qv);
          ord('N'): QVParseVNAK(fv,qv,cv);
          ord('T'): QVParseVSTAT(fv,qv,cv);
          ord('P'): {VRPOS}
            if SeqNum=0 then
            begin
              FTSetTimeOut(fv,0);
              if QVCountRetry(fv,qv,cv) then
                exit;
              SeqSent := 0;
              WinEnd := WinSize;
              if WinEnd>FileEnd then
                WinEnd := FileEnd;
              EnqFlag := FALSE;
            end;
        end;
      QV_SendNext:
        case PktIn[1] of
          ord('P'): QVParseVRPOS(fv,qv,cv);
          ord('T'): begin
              if QVCountRetry(fv,qv,cv) then
                exit;
              QVResendPacket(fv,qv); {resend VFILE}
            end;
        end;
    end;

  {create packet}
  if PktOutCount=0 then
    QVSendVDATA(fv,qv);

  {send packet}
  c := 1;
  while (c>0) and (PktOutCount>0) do
  begin
    c := QVWrite(fv,qv,cv,@PktOut[PktOutPtr],PktOutCount);
    PktOutPtr := PktOutPtr + c;
    PktOutCount := PktOutCount - c;
  end;

end;
end;

end.
