{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTFILE.DLL, XMODEM protocol}
unit XMODEM;

interface

uses WinTypes, WinProcs, Strings, TTTypes, TTFTypes,
     TTCommon, FTLib, DlgLib, TTLib;

procedure XInit(fv: PFileVar; xv: PXVar; cv: PComVar; ts: PTTSet);
procedure XCancel(fv: PFileVar; xv: PXVar; cv: PComVar);
procedure XTimeOutProc(fv: PFileVar; xv: PXVar; cv: PComVar);
function XReadPacket(fv: PFileVar; xv: PXVar; cv: PComVar): bool;
function XSendPacket(fv: PFileVar; xv: PXVar; cv: PComVar): bool;

implementation
{$i tt_res.inc}

const
  TimeOutInit  = 10;
  TimeOutC     =  3;
  TimeOutShort = 10;
  TimeOutLong  = 20;
  TimeOutVeryLong = 60;


function XRead1Byte(fv: PFileVar; xv: PXVar; cv: PComVar; var b: byte): integer;
begin
with xv^ do begin
  if CommRead1Byte(cv,@b) = 0 then
  begin
    XRead1Byte := 0;
    exit;
  end;
  XRead1Byte := 1;
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
end;
end;

function XWrite(fv: PFileVar; xv: PXVar; cv: PComVar; B: PChar; C: integer): integer;
var
  i, j: integer;
begin
with xv^ do begin
  i := CommBinaryOut(cv,B,C);
  XWrite := i;
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

procedure XSetOpt(fv: PFileVar; xv: PXVar; Opt: Word);
var             
  Tmp: array[0..20] of char;
begin
with xv^ do begin
  XOpt := Opt;

  strcopy(Tmp,'XMODEM (');
  case XOpt of
    XoptCheck: begin {Checksum}
        StrCat(Tmp,'checksum)');
        DataLen := 128;
        CheckLen := 1;
       end;
    XoptCRC: begin {CRC}
        StrCat(Tmp,'CRC)');
        DataLen := 128;
        CheckLen := 2;
       end;
    Xopt1K: begin {1K}
        StrCat(Tmp,'1K)');
        DataLen := 1024;
        CheckLen := 2;
       end;
  end;
  SetDlgItemText(fv^.HWin, IDC_PROTOPROT, Tmp);
end;
end;

procedure XSendNAK(fv: PFileVar; xv: PXVar; cv: PComVar);
var
  b: byte;
  t: integer;
begin
with xv^ do begin
  {flush comm buffer}
  cv^.InBuffCount := 0;
  cv^.InPtr := 0;

  dec(NAKCount);
  if NAKCount<0 then
  begin
    if NAKMode=XnakC then
    begin
      XSetOpt(fv,xv,1);
      NAKMode := XnakNAK;
      NAKCount := 9;
    end
    else begin
      XCancel(fv,xv,cv);
      exit;
    end;
  end;

  if NAKMode=XnakNAK then
  begin
    b := NAK;
    if (PktNum=0) and (PktNumOffset=0) then
      t := TimeOutInit
    else
      t := TOutLong;
  end
  else begin
    b := Ord('C');
    t := TimeOutC;
  end;
  XWrite(fv,xv,cv,@b, 1);
  PktReadMode := XpktSOH;
  FTSetTimeOut(fv,t);
end;
end;

function XCalcCheck(xv: PXVar; PktBuf: PChar): word;
var
  i: integer;
  Check: word;
begin
with xv^ do begin
  if CheckLen=1 then  {CheckSum}
  begin
    {Calc sum}
    Check := 0;
    for i := 0 to DataLen-1 do
      Check := Check + byte(PktBuf[3+i]);
    XCalcCheck := Check and $ff;
  end
  else begin {CRC}
    Check := 0;
    for i := 0 to DataLen-1 do
      Check := UpdateCRC(byte(PktBuf[3+i]),Check);
    XCalcCheck := Check;
  end
end;
end;

function XCheckPacket(xv: PXVar): boolean;
var
  Check: word;
begin
with xv^ do begin
  Check := XCalcCheck(xv,@PktIn[0]);
  if CheckLen=1 then {Checksum}
    XCheckPacket := byte(Check)=PktIn[DataLen+3]
  else
    XCheckPacket := (Hi(Check)=PktIn[DataLen+3]) and
                    (Lo(Check)=PktIn[DataLen+4]);  
end;
end;

procedure XInit(fv: PFileVar; xv: PXVar; cv: PComVar; ts: PTTSet);
begin
with xv^ do begin
  fv^.LogFlag := ts^.LogFlag and LOG_X <> 0;
  if fv^.LogFlag then
    fv^.LogFile := _lcreat('XMODEM.LOG',0);
  fv^.LogState := 0;
  fv^.LogCount := 0;

  fv^.FileSize := 0;
  if (XMode=IdXSend) and fv^.FileOpen then
    fv^.FileSize := GetFSize(fv^.FullName);

  SetWindowText(fv^.HWin, fv^.DlgCaption);
  SetDlgItemText(fv^.HWin, IDC_PROTOFNAME, @fv^.FullName[fv^.DirLen]);

  PktNumOffset := 0;
  PktNum := 0;
  PktNumSent := 0;
  PktBufCount := 0;
  CRRecv := FALSE;

  fv^.ByteCount := 0;

  if cv^.PortType=IdTCPIP then
  begin
    TOutShort := TimeOutVeryLong;
    TOutLong  := TimeOutVeryLong;
  end
  else begin
    TOutShort := TimeOutShort;
    TOutLong  := TimeOutLong;
  end;    

  XSetOpt(fv,xv,XOpt);

  if XOpt=XoptCheck then
  begin
    NAKMode := XnakNAK;
    NAKCount := 10;
  end
  else begin
    NAKMode := XnakC;
    NAKCount := 3;
  end;

  case XMode of
    IdXSend: begin
        TextFlag := 0;
        FTSetTimeOut(fv,TimeOutVeryLong);
      end;
    IdXReceive: XSendNAK(fv,xv,cv);
  end;

end;
end;

procedure XCancel(fv: PFileVar; xv: PXVar; cv: PComVar);
var
  b: byte;
begin
with xv^ do begin
  b := CAN;
  XWrite(fv,xv,cv,@b, 1);
  XMode := 0; {quit}
end;
end;

procedure XTimeOutProc(fv: PFileVar; xv: PXVar; cv: PComVar);
begin
with xv^ do
  case XMode of
    IdXSend: XMode := 0; {quit}
    IdXReceive: XSendNAK(fv,xv,cv);
  end;
end;

function XReadPacket(fv: PFileVar; xv: PXVar; cv: PComVar): bool;
var
  b, d: byte;
  i, c: integer;
  GetPkt: boolean;
begin
with xv^ do begin

  XReadPacket := TRUE;
  c := XRead1Byte(fv,xv,cv,b);

  GetPkt := FALSE;

  while (c>0) and (not GetPkt) do
  begin
    case PktReadMode of
      XpktSOH: if b=SOH then
               begin
                 PktIn[0] := b;
                 PktReadMode := XpktBLK;
                 if XOpt=Xopt1K then
                   XSetOpt(fv,xv,XoptCRC);
                 FTSetTimeOut(fv,TOutShort);
               end
               else if b=STX then
               begin
                 PktIn[0] := b;
                 PktReadMode := XpktBLK;
                 XSetOpt(fv,xv,Xopt1K);
                 FTSetTimeOut(fv,TOutShort);
               end
               else if b=EOT then
               begin
                 b := ACK;
                 fv^.Success := TRUE;
                 XWrite(fv,xv,cv,@b, 1);
                 XReadPacket := FALSE;
                 exit;
               end
               else begin
                 {flush comm buffer}
                 cv^.InBuffCount := 0;
                 cv^.InPtr := 0;
                 exit;
               end;
      XpktBLK: begin
                 PktIn[1] := b;
                 PktReadMode := XpktBLK2;
                 FTSetTimeOut(fv,TOutShort);
               end;
      XpktBLK2: begin
                  PktIn[2] := b;
                  if b xor PktIn[1] = $ff then
                  begin
                    PktBufPtr := 3;
                    PktBufCount := DataLen + CheckLen;
                    PktReadMode := XpktDATA;
                    FTSetTimeOut(fv,TOutShort);
                  end
                  else
                    XSendNAK(fv,xv,cv);
                end;
      XpktDATA: begin
                  PktIn[PktBufPtr] := b;
                  inc(PktBufPtr);
                  dec(PktBufCount);
                  GetPkt := PktBufCount=0;
                  if GetPkt then
                  begin
                    FTSetTimeOut(fv,TOutLong);
                    PktReadMode := XpktSOH;
                  end
                  else
                    FTSetTimeOut(fv,TOutShort);               
                end;
    end;

    if not GetPkt then c := XRead1Byte(fv,xv,cv,b);
  end;

  if not GetPkt then exit;

  if (PktIn[1]=0) and (PktNum=0) and (PktNumOffset=0) then
  begin
    if NAKMode=XnakNAK then
      NAKCount := 10
    else
      NAKCount := 3;
    XSendNAK(fv,xv,cv);
    exit;
  end;

  GetPkt := XCheckPacket(xv);
  if not GetPkt then
  begin
    XSendNAK(fv,xv,cv);
    exit;
  end;

  d := PktIn[1] - PktNum;
  if d>1 then
  begin
    XCancel(fv,xv,cv);
    XReadPacket := FALSE;
    exit;
  end;

  {send ACK}
  b := ACK;
  XWrite(fv,xv,cv,@b, 1);
  NAKMode := XnakNAK;
  NAKCount := 10;

  if d=0 then exit;
  PktNum := PktIn[1];
  if PktNum=0 then PktNumOffset := PktNumOffset + 256;

  c := DataLen;
  if TextFlag>0 then
    while (c>0) and (PktIn[2+c]=$1A) do
      dec(c);

  if TextFlag>0 then
     for i := 0 to c-1 do
     begin
       b := byte(PktIn[3+i]);
       if (b=LF) and not CRRecv then
         _lwrite(fv^.FileHandle,#$0D,1);
       if CRRecv and (b<>LF) then
         _lwrite(fv^.FileHandle,#$0A,1);
       CRRecv := b=CR;
       _lwrite(fv^.FileHandle,@b,1);
     end
  else
    _lwrite(fv^.FileHandle, @PktIn[3], c);

  fv^.ByteCount := fv^.ByteCount + c;

  SetDlgNum(fv^.HWin, IDC_PROTOPKTNUM, PktNumOffset+PktNum);
  SetDlgNum(fv^.HWin, IDC_PROTOBYTECOUNT, fv^.ByteCount);

  FTSetTimeOut(fv,TOutLong);
end;
end;

function XSendPacket(fv: PFileVar; xv: PXVar; cv: PComVar): bool;
var
  b: byte;
  i: integer;
  SendFlag: boolean;
  Check: word;
begin
with xv^ do begin
  XSendPacket := TRUE;

  SendFlag := FALSE;
  if PktBufCount=0 then
  begin
    i := XRead1Byte(fv,xv,cv,b);
    repeat
      if i=0 then exit;
      case b of
        ACK: if not fv^.FileOpen then
             begin
               fv^.Success := TRUE;
               XSendPacket := FALSE;
               exit;
             end
             else if PktNumSent=byte(PktNum+1) then
             begin
               PktNum := PktNumSent;
               if PktNum=0 then PktNumOffset := PktNumOffset + 256;
               SendFlag := TRUE;
             end;    
        NAK: SendFlag := TRUE;
        CAN: ;
        $43: if (PktNum=0) and (PktNumOffset=0) then
             begin
               if (XOpt=XoptCheck) and (PktNumSent=0) then XSetOpt(fv,xv,XoptCRC);
               if XOpt<>XoptCheck then SendFlag := TRUE;
             end;
      end;
      if not SendFlag then i := XRead1Byte(fv,xv,cv,b);
    until SendFlag;
    {reset timeout timer}
    FTSetTimeOut(fv,TimeOutVeryLong);

    repeat
      i := XRead1Byte(fv,xv,cv,b)
    until i=0;

    if PktNumSent=PktNum then {make a new packet}
    begin
      inc(PktNumSent);
      if DataLen=128 then
        PktOut[0] := SOH
      else
        PktOut[0] := STX;
      PktOut[1] := PktNumSent;
      PktOut[2] := not PktNumSent; 

      i := 1;
      while (i<=DataLen) and fv^.FileOpen and
            (_lread(fv^.FileHandle,@b,1)=1) do
      begin
        PktOut[2+i] := b;
        inc(i);
        inc(fv^.ByteCount);
      end;

      if i>1 then
      begin  
        while (i<=DataLen) do
        begin
          PktOut[2+i] := $1A;
          inc(i);
        end;

        Check := XCalcCheck(xv,@PktOut[0]);
        if CheckLen=1 then {Checksum}
          PktOut[DataLen+3] := byte(Check)
        else begin
          PktOut[DataLen+3] := Hi(Check);
          PktOut[DataLen+4] := Lo(Check);
        end;
        PktBufCount := 3 + DataLen + CheckLen;
      end
      else begin {send EOT}
        if fv^.FileOpen then
        begin
          _lclose(fv^.FileHandle);
          fv^.FileHandle := 0;
          fv^.FileOpen := FALSE;
        end;
        PktOut[0] := EOT;
        PktBufCount := 1;
      end;

      PktBufPtr := 0;
    end
    else begin {resend packet}
      PktBufCount := 3 + DataLen + CheckLen;
      PktBufPtr := 0;
    end;
  end;

  i := 1;
  while (PktBufCount>0) and (i>0) do
  begin
    b := PktOut[PktBufPtr];
    i := XWrite(fv,xv,cv,@b, 1);
    if i>0 then
    begin
      dec(PktBufCount);
      inc(PktBufPtr);
    end;
  end;

  if PktBufCount=0 then
  begin
    SetDlgNum(fv^.HWin, IDC_PROTOPKTNUM, PktNumOffset+PktNumSent);
    SetDlgNum(fv^.HWin, IDC_PROTOBYTECOUNT, fv^.ByteCount);
    SetDlgPercent(fv^.HWin, IDC_PROTOPERCENT,
                  fv^.ByteCount, fv^.FileSize);
  end;
end;
end;

end.
