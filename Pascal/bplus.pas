{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTFILE.DLL, B-Plus protocol}
unit BPlus;

interface

uses WinTypes, WinProcs, Strings, TTTypes,
     TTFTypes, TTCommon, FTLib, DlgLib, TTLib;

procedure BPInit(fv: PFileVar; bv: PBPVar; cv: PComVar; ts: PTTSet);
procedure BPTimeOutProc(fv: PFileVar; bv: PBPVar; cv: PComVar);
function BPParse(fv: PFileVar; bv: PBPVar; cv: PComVar): bool;
procedure BPCancel(bv: PBPVar);

implementation
{$i tt_res.inc}

const
  BPTimeOut = 10;
  BPTimeOutTCPIP = 0;

function BPOpenFileToBeSent(fv: PFileVar): BOOL;
begin
  BPOpenFileToBeSent := FALSE;
  if fv^.FileOpen then exit;
  if strlen(@fv^.FullName[fv^.DirLen])=0 then exit;

  fv^.FileHandle := _lopen(fv^.FullName,OF_READ);
  fv^.FileOpen := fv^.FileHandle>0;
  if fv^.FileOpen then
  begin
    SetDlgItemText(fv^.HWin, IDC_PROTOFNAME, @fv^.FullName[fv^.DirLen]);
    fv^.FileSize := GetFSize(fv^.FullName);
  end;
  BPOpenFileToBeSent := fv^.FileOpen;
end;

procedure BPDispMode(fv: PFileVar; bv: PBPVar);
begin
  strcopy(fv^.DlgCaption,'Tera Term: B-Plus ');
  case bv^.BPMode of
    IdBPSend:
      strcat(fv^.DlgCaption,'Send');
    IdBPReceive:
      strcat(fv^.DlgCaption,'Receive');
  end;

  SetWindowText(fv^.HWin,fv^.DlgCaption);
end;


procedure BPInit(fv: PFileVar; bv: PBPVar; cv: PComVar; ts: PTTSet);
var
  i: integer;
begin
with bv^ do begin
  if BPMode=IdBPAuto then
  begin
    CommInsert1Byte(cv,ord('B'));
    CommInsert1Byte(cv,DLE);
  end;

  BPDispMode(fv,bv);
  SetDlgItemText(fv^.HWin, IDC_PROTOPROT, 'B-Plus');

  {file name, file size}
  if BPMode=IdBPSend then
    BPOpenFileToBeSent(fv);

  {default parameters}
  for i := 0 to 7 do
    Q[i] := $FF;
  CM := 0;

  PktNumOffset := 0;
  PktNum := 0;
  PktNumSent := 0;
  PktOutLen := 0;
  PktOutCount := 0;
  BPState := BP_Init;
  BPPktState := BP_PktGetDLE;
  GetPacket := FALSE;
  EnqSent := FALSE;
  CtlEsc := ts^.FTFlag and FT_BPESCCTL <> 0;

  {Time out & Max block size}
  if cv^.PortType=IdTCPIP then
  begin
    TimeOut := BPTimeOutTCPIP;
    MaxBS := 16;
  end
  else begin
    TimeOut := BPTimeOut;
    case ts^.Baud of
      IdBaud110: begin
          TimeOut := BPTimeOut*2;
          MaxBS := 1;
        end;
      IdBaud300: MaxBS := 1;
      IdBaud600: MaxBS := 2;
      IdBaud1200: MaxBS := 4;
      IdBaud2400: MaxBS := 8;
      IdBaud4800: MaxBS := 12;
    else
      MaxBS := 16;
    end;
  end;

  fv^.LogFlag := ts^.LogFlag and LOG_BP <> 0;
  if fv^.LogFlag then
    fv^.LogFile := _lcreat('BPLUS.LOG',0);
  fv^.LogState := 0;
  fv^.LogCount := 0;
end;
end;

function BPRead1Byte(fv: PFileVar; bv: PBPVar; cv: PComVar; var b: byte): integer;
begin
with bv^ do begin
  if CommRead1Byte(cv,@b) = 0 then
  begin
    BPRead1Byte := 0;
    exit;
  end;
  BPRead1Byte := 1;
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

function BPWrite(fv: PFileVar; bv: PBPVar; cv: PComVar; B: PChar; C: integer): integer;
var
  i, j: integer;
begin
with bv^ do begin
  i := CommBinaryOut(cv,B,C);
  BPWrite := i;
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

procedure BPTimeOutProc(fv: PFileVar; bv: PBPVar; cv: PComVar);
begin
with bv^ do begin
  BPWrite(fv,bv,cv,#$05#$05,2); {two ENQ}
  FTSetTimeOut(fv,TimeOut);
  EnqSent := TRUE;
end;
end;

procedure BPUpdateCheck(bv: PBPVar; b: byte);
var
  w: word;
begin
with bv^ do begin
  case CM of
    0: begin {Standard checksum}
         w := CheckCalc;
         w := w shl 1;
         if w > $FF then
           w := w and $FF + 1;
         w := w + word(b);
         if w > $FF then
           w := w and $FF + 1;
         CheckCalc := w;
       end;
    1: {Modified XMODEM CRC-16}
      CheckCalc := UpdateCRC(b,word(CheckCalc));
  else
    {CCITT CRC-16/32 are not implemented}
    CheckCalc := 0;
  end;
end;
end;

procedure BPSendACK(fv: PFileVar; bv: PBPVar; cv: PComVar);
var
  Temp: array[0..1] of char;
begin
with bv^ do begin
  if (BPState<>BP_Failure) and (BPState<>BP_Close) then
  begin
    Temp[0] := #$10; {DLE}
    Temp[1] := char(PktNum mod 10 + $30);
    BPWrite(fv,bv,cv,Temp,2);
  end;
  BPPktState := BP_PktGetDLE;
end;
end;

procedure BPSendNAK(fv: PFileVar; bv: PBPVar; cv: PComVar);
begin
with bv^ do begin
  if (BPState<>BP_Failure) and (BPState<>BP_Close) then
    BPWrite(fv,bv,cv,#$15,1); {NAK}
  BPPktState := BP_PktGetDLE;
end;
end;

procedure BPPut1Byte(bv: PBPVar; b: byte; var OutPtr: integer);
var
  Iq: integer;
  Mq: byte;
begin
with bv^ do begin
  Mq := $80 shr (b mod 8);
  case b of
    $00..$1F: Iq := b div 8;
    $80..$9F: Iq := b div 8 - 12;
  else
    begin
      Iq := 0;
      Mq := 0;
    end;
  end;
  if Mq and Q[Iq] > 0 then
  begin
    PktOut[OutPtr] := $10; {DLE}
    inc(OutPtr);
    case b of
      $00..$1F: b := b + $40;
      $80..$9F: b := b - $20;
    end;
  end;
  PktOut[OutPtr] := b;
  inc(OutPtr);
end;
end;

procedure BPMakePacket(bv: PBPVar; PktType: byte; DataLen: integer);
var
  i: integer;
  b: byte;
  Qflag: boolean;
begin
with bv^ do begin
  PktNumSent := (PktNum + 1) mod 10;

  PktOut[0] := $10; {DLE}
  PktOut[1] := ord('B');
  PktOut[2] := PktNumSent + $30; {Sequence number}
  PktOut[3] := PktType;
  PktOut[4+DataLen] := $03; {ETX}

  {Calc checksum}
  case CM of
    1: {modified XMODEM-CRC}
      CheckCalc := $FFFF;
  else {standard checksum}
    {CCITT CRC-16/32 are not supported}
    CheckCalc := 0;
  end;
  Qflag := FALSE;
  for i := 0 to DataLen+2 do
  begin
    b := PktOut[i+2];
    if b=$10 then
      Qflag := TRUE
    else begin
      if Qflag then
        case b of
          $40..$5F: b := b - $40;
          $60..$7F: b := b + $20;
        end;
      Qflag := FALSE;
      BPUpdateCheck(bv,b);
    end;
  end;

  {Put check value}
  PktOutCount := 5 + DataLen;
  case CM of
    1: begin {Modified XMODEM-CRC}
        BPPut1Byte(bv,Hi(word(CheckCalc)),PktOutCount);
        BPPut1Byte(bv,Lo(word(CheckCalc)),PktOutCount);
      end;
  else  {Standard checksum}
    BPPut1Byte(bv,byte(CheckCalc),PktOutCount);
  end;
  PktOutLen := PktOutCount;
  PktOutPtr := 0;
  BPPktState := BP_PktSending;
end;
end;

procedure BPSendFailure(bv: PBPVar; b: byte);
var
  i: integer;
begin
with bv^ do begin
  i := 4;
  BPPut1Byte(bv,b,i);
  i := i - 4;
  BPMakePacket(bv,Ord('F'),i);
  BPState := BP_Failure;
end;
end;

procedure BPSendInit(bv: PBPVar);
var
  b: byte;
  i, Count: integer;
  Param: TBPParam;
begin
with bv^ do begin
  FillChar(Param,SizeOf(Param),#0);
  for i := 1 to PktInCount-2 do
  begin
    b := PktIn[i+1];
    case i of
      1: Param.WS := b;
      2: Param.WR := b;
      3: Param.B_S := b;
      4: Param.CM := b;
      5: Param.DQ := b;
      6: Param.TL := b;
      7..14: Param.Q[i-7] := b;
      15: Param.DR := b;
      16: Param.UR := b;
      17: Param.FI := b;
    end;
  end;

  if Param.B_S=0 then
    Param.B_S := 4;
  if Param.B_S>MaxBS then
    Param.B_S := MaxBS;

  if Param.CM>1 then
    Param.CM := 1;

  if PktInCount<7 then
  begin
    Param.Q[0] := $14;
    Param.Q[2] := $D4;
    case Param.DQ of
      1: ;
      2: Param.Q[6] := $50;
      3: for i := 0 to 7 do
           Param.Q[i] := $FF;
    else
      Param.Q[0] := $94;
    end;
  end;

  if CtlEsc then {escape all ctrl chars}
    for i := 0 to 7 do
      Param.Q[i] := $FF
  else begin
    Param.Q[0] := Param.Q[0] or $14;
    Param.Q[1] := Param.Q[1] or $04;
    Param.Q[2] := Param.Q[2] or $D4;
  end;

  for i := 0 to 7 do
    Q[i] := $FF;

  Count := 4;
  BPPut1Byte(bv,0,Count); {WS}
  BPPut1Byte(bv,Param.WS,Count); {WR}
  BPPut1Byte(bv,Param.B_S,Count); {BS}
  BPPut1Byte(bv,Param.CM,Count); {CM}
  BPPut1Byte(bv,Param.DQ,Count); {DQ}
  BPPut1Byte(bv,0,Count); {TL}
  for i := 0 to 7 do
    BPPut1Byte(bv,Param.Q[i],Count); {Q1-8}
  BPPut1Byte(bv,0,Count); {DR}
  BPPut1Byte(bv,0,Count); {UR}
  BPPut1Byte(bv,Param.FI,Count); {FI}

  Count := Count - 4;
  BPMakePacket(bv,Ord('+'),Count);

  PktSize := Param.B_S*128;
  CM := Param.CM;
  for i := 0 to 7 do
    Q[i] := Param.Q[i];

end;
end;

procedure BPSendTCPacket(bv: PBPVar);
var
  i: integer;
begin
with bv^ do begin
  i := 4;
  BPPut1Byte(bv,ord('C'),i);
  i := i - 4;
  BPMakePacket(bv,Ord('T'),i);
  BPState := BP_SendClose;
end;
end;

procedure BPSendNPacket(fv: PFileVar; bv: PBPVar);
var
  i, c: integer;
  b: byte;
begin
with bv^ do begin
  i := 4;
  c := 1;
  while (i-4 < PktSize-1) and (c>0) do
  begin
    c := _lread(fv^.FileHandle,@b,1);
    if c=1 then
      BPPut1Byte(bv,b,i);
    fv^.ByteCount := fv^.ByteCount + c;
  end;
  if c=0 then
  begin
    _lclose(fv^.FileHandle);
    fv^.FileOpen := FALSE;
  end;
  i := i - 4;
  BPMakePacket(bv,Ord('N'),i);

  SetDlgNum(fv^.HWin, IDC_PROTOBYTECOUNT, fv^.ByteCount);
  if fv^.FileSize>0 then
    SetDlgPercent(fv^.HWin, IDC_PROTOPERCENT,
      fv^.ByteCount, fv^.FileSize);
end;
end;

procedure BPCheckPacket(fv: PFileVar; bv: PBPVar; cv: PComVar);
begin
with bv^ do begin
  if Check<>CheckCalc then
  begin
    BPSendNAK(fv,bv,cv);
    exit;
  end;

  {Sequence number}
  if (PktNum+1) mod 10 + $30 <> PktIn[0] then
  begin
    BPsendNAK(fv,bv,cv);
    exit;
  end;

  inc(PktNum);
  if PktNum=10 then
  begin
    PktNum := 0;
    PktNumOffset := PktNumOffset + 10;
  end;
  SetDlgNum(fv^.HWin, IDC_PROTOPKTNUM, PktNum+PktNumOffset);

  if PktIn[1]<>ord('+') then
    BPSendACK(fv,bv,cv); {Send ack}

  GetPacket := TRUE;
end;
end;

procedure BPParseTPacket(fv: PFileVar; bv: PBPVar);

  function Get1(var i: integer; var b: byte): integer;
  begin
    if i<bv^.PktInCount then
    begin
      b := bv^.PktIn[i];
      inc(i);
      Get1 := 1;
    end
    else
      Get1 := 0;
  end;

var
  i, j, c: integer;
  b: byte;
  Temp: array[0..80] of char;
begin
with bv^ do begin
  case PktIn[2] of
    ord('C'): begin {Close}
        if fv^.FileOpen then
        begin
          _lclose(fv^.FileHandle);
          fv^.FileOpen := FALSE;
        end;
        fv^.Success := TRUE;
        BPState := BP_Close;
      end;
    ord('D'): begin {Download}
        if (BPState<>BP_RecvFile) and
           (BPState<>BP_AutoFile) then
        begin
          BPSendFailure(bv,ord('E'));
          exit;
        end;
        BPMode := IdBPReceive;
        BPState := BP_RecvFile;
        BPDispMode(fv,bv);

        {Get file name}
        j := 0;
        for i := 4 to PktInCount-1 do
        begin
          b := PktIn[i];
          if j < SizeOf(Temp)-1 then
          begin
            Temp[j] := char(b);
            inc(j);
          end;
        end;
        Temp[j] := #0;

        GetFileNamePos(Temp,i,j);
        StrCopy(@fv^.FullName[fv^.DirLen],@Temp[j]);
        {file open}
        if not FTCreateFile(fv) then
        begin
          BPSendFailure(bv,ord('E'));
          exit;
        end;
      end;
    ord('I'): begin {File information}
        i := 5;
        {file size}
        fv^.FileSize := 0;
        repeat
          c := Get1(i,b);
          if c=1 then
            case b of
              $30..$39: fv^.FileSize :=
                  fv^.FileSize * 10 + b - $30;
            end;
        until (c=0) or (b<$30) or (b>$39);
      end;
    ord('U'): begin {Upload}
        if (BPState<>BP_SendFile) and
           (BPState<>BP_AutoFile) then
        begin
          BPSendFailure(bv,ord('E'));
          exit;
        end;
        BPMode := IdBPSend;
        BPDispMode(fv,bv);

        if not fv^.FileOpen then
        begin
          {Get file name}
          j := 0;
          for i := 4 to PktInCount-1 do
          begin
            b := PktIn[i];
            if j < SizeOf(Temp)-1 then
            begin
              Temp[j] := char(b);
              inc(j);
            end;
          end;
          Temp[j] := #0;

          GetFileNamePos(Temp,i,j);
          FitFileName(@Temp[j],nil);
          StrCopy(@fv^.FullName[fv^.DirLen],@Temp[j]);

          { file open }
          if not BPOpenFileToBeSent(fv) then
          begin
	    { if file not found, ask user new file name }
	    fv^.FullName[fv^.DirLen] := #0;
	    if not GetTransFname(fv,nil,GTF_BP, @i) then
	    begin
              BPSendFailure(bv,ord('E'));
              exit;
            end;
	    { open retry }
	    if not BPOpenFileToBeSent(fv) then
	    begin
              BPSendFailure(bv,ord('E'));
              exit;
            end;
          end;
        end;
        fv^.ByteCount := 0;

        BPState := BP_SendData;
        BPSendNPacket(fv,bv);
      end;
  else
  end;
end;
end;

procedure BPParsePacket(fv: PFileVar; bv: PBPVar);
begin
with bv^ do begin
  GetPacket := FALSE;
  {Packet type}

  case PktIn[1] of
    ord('+'): begin {Transport parameters}
        if BPState=BP_Init then
          BPSendInit(bv)
        else
          BPSendFailure(bv,ord('E'));
        exit;
      end;
    ord('F'): begin {Failure}
        if not fv^.NoMsg then
          MessageBox(fv^.HMainWin,'Transfer failure',
            'Tera Term: Error',MB_ICONEXCLAMATION);
        BPState := BP_Close;
      end;
    ord('N'): begin {Data}
        if (BPState=BP_RecvFile) and
           fv^.FileOpen then
          BPState := BP_RecvData
        else if BPState<>BP_RecvData then
        begin
          BPSendFailure(bv,ord('E'));
          exit;
        end;
        _lwrite(fv^.FileHandle,@PktIn[2],PktInCount-2);
        fv^.ByteCount := fv^.ByteCount +
                              PktInCount - 2;
        SetDlgNum(fv^.HWin, IDC_PROTOBYTECOUNT, fv^.ByteCount);
        if fv^.FileSize>0 then
          SetDlgPercent(fv^.HWin, IDC_PROTOPERCENT,
            fv^.ByteCount, fv^.FileSize);
      end;
    ord('T'): BPParseTPacket(fv,bv); {File transfer}
  end;
end;
end;

procedure BPParseAck(fv: PFileVar; bv: PBPVar; b: byte);
begin
with bv^ do begin
  b := (b - $30) mod 10;
  if EnqSent then
  begin
    FTSetTimeOut(fv,0);
    EnqSent := FALSE;
    if (PktOutLen>0) and (b=PktNum) then {Resend packet}
    begin
      PktOutCount := PktOutLen;
      PktOutPtr := 0;
      BPPktState := BP_PktSending;
    end;
    exit;
  end;
  if PktOutLen=0 then exit;

  if b=PktNumSent then
    PktOutLen := 0 {Release packet}
  else
    exit;

  FTSetTimeOut(fv,0);
  PktNum := b;
  if b=0 then
    PktNumOffset := PktNumOffset + 10;

  case BPState of
    BP_Init: begin
        case BPMode of
          IdBPSend: BPState := BP_SendFile;
          IdBPReceive: BPState := BP_RecvFile;
          IdBPAuto: BPState := BP_AutoFile;
        end;
      end;
    BP_SendData: begin
        if b=PktNumSent then
        begin
          if fv^.FileOpen then
            BPSendNPacket(fv,bv)
          else
            BPSendTCPacket(bv);
        end;
      end;
    BP_SendClose: begin
        fv^.Success := TRUE;
        BPState := BP_Close;
     end;
    BP_Failure: BPState := BP_Close;
  end;
  SetDlgNum(fv^.HWin, IDC_PROTOPKTNUM, PktNum+PktNumOffset);
end;
end;

function BPParse(fv: PFileVar; bv: PBPVar; cv: PComVar): bool;

  procedure Dequote(var b: byte);
  begin
    case b of
      $40..$5F: b := b - $40;
      $60..$7F: b := b + $20;
    end;
  end;

var
  c: integer;
  b: byte;
begin
with bv^ do begin
  BPParse := TRUE;

  repeat

    {Send packet}
    if BPPktState=BP_PktSending then
    begin
      c := 1;
      while (c>0) and (PktOutCount>0) do
      begin
        c := BPWrite(fv,bv,cv,@PktOut[PktOutPtr],PktOutCount);
        PktOutPtr := PktOutPtr + c;
        PktOutCount := PktOutCount - c;
      end;
      if PktOutCount>0 then exit;
      if cv^.OutBuffCount=0 then
      begin
        BPPktState := BP_PktGetDLE;
        FTSetTimeOut(fv,TimeOut);
      end
      else
        exit;
    end;

    {Get packet}
    c := BPRead1Byte(fv,bv,cv,b);
    while (c>0) and (BPPktState<>BP_PktSending) and not GetPacket do
    begin
      case BPPktState of
        BP_PktGetDLE:
          case b of
            $03: {ETX}
               BPSendNak(fv,bv,cv);
            $05: begin {ENQ}
                if BPState=BP_Init then
                  BPWrite(fv,bv,cv,#$10'++'#$10'0',5)
                else
                  BPSendAck(fv,bv,cv);
              end;
            $10: {DLE}
                BPPktState := BP_PktDLESeen;
            $15: begin {NAK}
                BPWrite(fv,bv,cv,#$05#$05,2); {two ENQ}
                FTSetTimeOut(fv,TimeOut);
                EnqSent := TRUE;
              end;
          end;
        BP_PktDLESeen:
          case b of
            $05: begin {ENQ}
                BPSendAck(fv,bv,cv);
                BPPktState := BP_PktGetDLE;
              end;
            $30..$39: begin {ACK}
                BPPktState := BP_PktGetDLE;
                BPParseAck(fv,bv,b);
              end;
            $3B: begin {Wait}
                BPPktState := BP_PktGetDLE;
              end;
            $42: begin {B}
                PktInCount := 0;
                Quoted := FALSE;
                BPPktState := BP_PktGetData;
                case CM of
                  1: begin {modified XMODEM-CRC}
                    CheckCalc := $FFFF;
                    CheckCount := 2;
                  end;   
                else {standard checksum}
                  {CCITT CRC-16/32 are not supported}
                  begin
                    CheckCalc := 0;
                    CheckCount := 1;
                  end;   
                end;
              end;
          end;
        BP_PktGetData:
          case b of
            $03: begin {ETX}
                BPUpdateCheck(bv,b);
                Quoted := FALSE;
                Check := 0;
                BPPktState := BP_PktGetCheck;
              end;
            $05: begin {ENQ}
                BPSendAck(fv,bv,cv);
                BPPktState := BP_PktGetDLE;
              end;
            $10: Quoted := TRUE; {DLE}
          else
            begin
              if Quoted then Dequote(b);          
              Quoted := FALSE;
              if PktInCount < SizeOf(PktIn) then
              begin
                BPUpdateCheck(bv,b);
                PktIn[PktInCount] := b;
                inc(PktInCount);
              end;
            end;
          end;
        BP_PktGetCheck:
          case b of
            $10: Quoted := TRUE; {DLE}
          else
            begin
              if Quoted then Dequote(b);
              Quoted := FALSE;
              Check := Check shl 8 + b;
              dec(CheckCount);
              if CheckCount<=0 then
              begin
                BPPktState := BP_PktGetDLE;
                BPCheckPacket(fv,bv,cv);
              end;
            end;
          end;
      end;
      if (BPPktState<>BP_PktSending) and not GetPacket then
        c := BPRead1Byte(fv,bv,cv,b)
      else
        c := 0;
    end;

    {Parse packet}
    if GetPacket then
      BPParsePacket(fv,bv);

  until (c=0) and (BPPktState<>BP_PktSending);

  if BPState=BP_Close then
    BPParse := FALSE;
end;
end;

procedure BPCancel(bv: PBPVar);
begin
with bv^ do begin
  if (BPState<>BP_Failure) and (BPState<>BP_Close) then
    BPSendFailure(bv,ord('A'));
end;
end;

end.