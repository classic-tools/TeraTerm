{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, TELNET routines}
unit Telnet;

interface

uses WinTypes, WinProcs, Strings, TTTypes, TTCommon, TTWinMan, CommLib;

const
  TEL_EOF    = 236;
  SUSP       = 237;
  ABORT      = 238;

  SE	     = 240;
  NOP	     = 241;
  DM	     = 242;
  BREAK	     = 243;
  IP	     = 244;
  AO	     = 245;
  AYT	     = 246;
  EC	     = 247;
  EL	     = 248;
  GOAHEAD    = 249;
  SB	     = 250;
  WILLTEL    = 251;
  WONTTEL    = 252;
  DOTEL	     = 253;
  DONTTEL    = 254;
  IAC	     = 255;

  BINARY     = 0;
  ECHO	     = 1;
  RECONNECT  = 2;
  SGA 	     = 3;
  AMSN	     = 4;
  STATUS     = 5;
  TIMING     = 6;
  RCTAN	     = 7;
  OLW	     = 8;
  OPS	     = 9;
  OCRD	     = 10;
  OHTS	     = 11;
  OHTD	     = 12;
  OFFD	     = 13;
  OVTS	     = 14;
  OVTD	     = 15;
  OLFD	     = 16;
  XASCII     = 17;
  LOGOUT     = 18;
  BYTEM	     = 19;
  DET	     = 20;
  SUPDUP     = 21;
  SUPDUPOUT  = 22;
  SENDLOC    = 23;
  TERMTYPE   = 24;
  EOR	     = 25;
  TACACSUID  = 26;
  OUTPUTMARK = 27;
  TERMLOCNUM = 28;
  REGIME3270 = 29;
  X3PAD	     = 30;
  NAWS	     = 31;
  TERMSPEED  = 32;
  TFLOWCNTRL = 33;
  LINEMODE   = 34;
  MaxTelOpt  = 34;

  {Telnet status}
  TelIdle    = 0;
  TelIAC     = 1;
  TelSB      = 2;
  TelWill    = 3;
  TelWont    = 4;
  TelDo      = 5;
  TelDont    = 6;
  TelNop     = 7;

  procedure InitTelnet;
  procedure EndTelnet;
  procedure ParseTel(var Size: BOOL; var Nx, Ny: integer);
  procedure TelEnableHisOpt(b: byte);
  procedure TelEnableMyOpt(b: byte);
  procedure TelInformWinSize(nx, ny: integer);
  procedure TelSendAYT;
  procedure TelSendBreak;
  procedure TelChangeEcho;

var
  TelStatus: integer;

implementation

type
  OptStatus = (No, Yes, WantNo, WantYes);
  OptQue = (Empty, Opposite);

  PTelOpt = ^TelOpt;
  TelOpt = record
    Accept: boolean;
    Status: OptStatus;
    Que: OptQue;
  end;

  PTelRec = ^TelRec;
  TelRec = record
    MyOpt: array[0..MaxTelOpt] of TelOpt;
    HisOpt: array[0..MaxTelOpt] of TelOpt;
    SubOptBuff: array[0..50] of byte;
    SubOptCount: integer;
    SubOptIAC: boolean;
    ChangeWinSize: boolean;
    WinSize: TPoint;
    LogFile: integer;
  end;

var
  tr: TelRec;

procedure DefaultTelRec;
var
  i: integer;
begin
with tr do begin

  for i:=0 to MaxTelOpt do
  begin
    MyOpt[i].Accept := FALSE;
    MyOpt[i].Status := No;
    MyOpt[i].Que := Empty;
    HisOpt[i].Accept := FALSE;
    HisOpt[i].Status := No;
    HisOpt[i].Que := Empty;
  end;

  SubOptCount := 0;
  SubOptIAC := FALSE;
  ChangeWinSize := FALSE;
end;
end;

procedure InitTelnet;
begin
with tr do begin
  TelStatus := TelIdle;

  DefaultTelRec;
  MyOpt[BINARY].Accept := TRUE;
  HisOpt[BINARY].Accept := TRUE;
  MyOpt[SGA].Accept := TRUE;
  HisOpt[SGA].Accept := TRUE;
  HisOpt[ECHO].Accept := TRUE;
  MyOpt[TermType].Accept := TRUE;
  MyOpt[NAWS].Accept := TRUE;
  HisOpt[NAWS].Accept := TRUE;
  WinSize.x := ts.TerminalWidth;
  WinSize.Y := ts.TerminalHeight;

  if ts.LogFlag and LOG_TEL <> 0 then
    LogFile := _lcreat('TELNET.LOG',0)
  else
    LogFile := 0;
end;
end;

procedure EndTelnet;
begin
  if tr.LogFile<>0 then
  begin
    tr.LogFile := 0;
    _lclose(tr.LogFile);
  end;
end;

procedure TelWriteLog1(b: byte);
var
  Temp: array[0..2] of char;
  Ch: byte;
begin
  Temp[0] := #$20;
  Ch := b div 16;
  case Ch of
    0..9:   Ch := Ch + $30;
    10..15: Ch := Ch + $37;
  end;
  Temp[1] := char(Ch);
  Ch := b and 15;
  case Ch of
    0..9:   Ch := Ch + $30;
    10..15: Ch := Ch + $37;
  end;
  Temp[2] := char(Ch);
  _lwrite(tr.LogFile,Temp,3);
end;

procedure TelWriteLog(Buf: PChar; C: integer);
var
  i: integer;
begin
  _lwrite(tr.LogFile,#$0d#$0a'>',3);
  for i := 0 to C-1 do
    TelWriteLog1(byte(Buf[i]));
end;

procedure SendBack(a, b: byte);
var
  Str3: array[0..2] of char;
begin
  Str3[0] := char(IAC);
  Str3[1] := char(a);
  Str3[2] := char(b);
  CommRawOut(@cv,Str3,3);
  if tr.LogFile<>0 then
    TelWriteLog(Str3,3);
end;

procedure SendWinSize;
var
  i: integer;
  TmpBuff: array[0..20] of char;
begin
with tr do begin
  i := 0;

  TmpBuff[i] := char(IAC);
  Inc(i);
  TmpBuff[i] := char(SB);
  Inc(i);
  TmpBuff[i] := char(NAWS);
  Inc(i);
  TmpBuff[i] := char(Hi(WinSize.x));
  Inc(i);
 { if Lo(WinSize.X) = IAC then
  begin
    SendBackBuff[i] := IAC;
    Inc(i);
  end; }
  TmpBuff[i] := char(Lo(WinSize.x));
  Inc(i);
  TmpBuff[i] := char(Hi(WinSize.y));
  Inc(i);
 { if Lo(WinSize.Y) = IAC then
  begin
    SendBackBuff[i] := IAC;
    Inc(i);
  end; }
  TmpBuff[i] := char(Lo(WinSize.y));
  Inc(i);
  TmpBuff[i] := char(IAC);
  Inc(i);
  TmpBuff[i]:= char(SE);
  Inc(i);

  CommRawOut(@cv,TmpBuff,i);
  if LogFile<>0 then
    TelWriteLog(TmpBuff,i);
end;
end;

procedure ParseTel(var Size: BOOL; var Nx, Ny: integer);

  procedure ParseTelIAC(b: byte);
  begin
  with tr do begin
    case b of
      SE:  ;
      NOP:     TelStatus := TelIdle;
      DM:      TelStatus := TelIdle;
      BREAK:   TelStatus := TelIdle;
      IP:      TelStatus := TelIdle;
      AO:      TelStatus := TelIdle;
      AYT:     TelStatus := TelIdle;
      EC:      TelStatus := TelIdle;
      EL:      TelStatus := TelIdle;
      GOAHEAD: TelStatus := TelIdle;
      SB:      begin
                 TelStatus := TelSB;
                 SubOptCount := 0;
               end;
      WILLTEL: TelStatus := TelWill;
      WONTTEL: TelStatus := TelWont;
      DOTEL:   TelStatus := TelDo;
      DONTTEL: TelStatus := TelDont;
      IAC: begin
             TelStatus := TelIdle;
           end;
    else
      TelStatus := TelIdle;
    end;
  end;
  end;

  procedure ParseTelSB(b: byte);
  var
    TmpStr: array[0..50] of char;
    i: integer;
  begin
  with tr do begin
    if SubOptIAC
    then begin
      SubOptIAC := FALSE;
      case b of
        SE: begin
          if (MyOpt[TermType].Status = Yes) and
             (SubOptCount >= 2) and
             (SubOptBuff[0] = TermType) and
             (SubOptBuff[1] = 1) then
          begin
            TmpStr[0] := char(IAC);
            TmpStr[1] := char(SB);
            TmpStr[2] := char(TermType);
            TmpStr[3] := #0;
            StrCopy(@TmpStr[4],ts.TermType);
            i := 4 + StrLen(ts.TermType);
            TmpStr[i] := char(IAC);
            inc(i);
            TmpStr[i] := char(SE);
            inc(i);
            CommRawOut(@cv,TmpStr,i);

            if LogFile<>0 then
              TelWriteLog(TmpStr,i);
          end
          else if {(HisOpt[NAWS].Status = Yes) and}
                  (SubOptCount >= 5) and
                  (SubOptBuff[0] = NAWS) then
          begin
            WinSize.x := SubOptBuff[1]*256+
                         SubOptBuff[2];
            WinSize.y := SubOptBuff[3]*256+
                         SubOptBuff[4];
            ChangeWinSize := TRUE;
          end;
          SubOptCount := 0;
          TelStatus := TelIdle;
          exit;
        end;
        {IAC: ;}
      else
        if SubOptCount >= SizeOf(SubOptBuff)-1 then
        begin
          SubOptCount := 0;
          TelStatus := TelIdle;
          exit;
        end
        else begin
          SubOptBuff[SubOptCount] := IAC;
          inc(SubOptCount);
          if b=IAC then
          begin
            SubOptIAC := TRUE;
            exit;
          end;
        end;
      end;
    end
    else
      if b=IAC then
      begin
        SubOptIAC := TRUE;
        exit;
      end;
 
    if SubOptCount >= SizeOf(SubOptBuff)-1 then
    begin
      SubOptCount := 0;
      SubOptIAC := FALSE;
      TelStatus := TelIdle;
    end
    else begin
      SubOptBuff[SubOptCount] := b;
      inc(SubOptCount);
    end;
  end;
  end;

  procedure ParseTelWill(b: byte);
  begin
  with tr do begin
    if b <= MaxTelOpt then
      case HisOpt[b].Status of
        No: begin
             if HisOpt[b].Accept
             then begin
               SendBack(DOTEL,b);
               HisOpt[b].Status := Yes;
             end
             else
               SendBack(DONTTEL,b);
            end;
  
        WantNo: case HisOpt[b].Que of
                  Empty: HisOpt[b].Status := No;
                  Opposite: HisOpt[b].Status := Yes;
                end;

        WantYes: case HisOpt[b].Que of
                   Empty: HisOpt[b].Status := Yes;
                   Opposite: begin
                     HisOpt[b].Status := WantNo;
                     HisOpt[b].Que := Empty;
                     SendBack(DONTTEL,b);
                   end;
                 end;
      end
    else
      SendBack(DONTTEL,b);

    case b of
      ECHO:
        if ts.TelEcho>0 then
          case HisOpt[ECHO].Status of
            Yes: ts.LocalEcho := 0;
            No:  ts.LocalEcho := 1;
          end;
      BINARY:
        case HisOpt[BINARY].Status of
          Yes: cv.TelBinRecv := TRUE;
          No:  cv.TelBinRecv := FALSE;
        end;
    end;
    TelStatus := TelIdle;
  end;
  end;

  procedure ParseTelWont(b: byte);
  begin
  with tr do begin
    if b <= MaxTelOpt then
      case HisOpt[b].Status of
        Yes: begin
               HisOpt[b].Status := No;
               SendBack(DONTTEL,b);
             end;

        WantNo: case HisOpt[b].Que of
                  Empty: HisOpt[b].Status := No;
                  Opposite: begin
                    HisOpt[b].Status := WantYes;
                    HisOpt[b].Que := Empty;
                    SendBack(DOTEL,b);
                  end;
                end;

        WantYes: case HisOpt[b].Que of
                   Empty: HisOpt[b].Status := No;
                   Opposite: begin
                     HisOpt[b].Status := No;
                     HisOpt[b].Que := Empty;
                   end;
                 end;
      end
    else
      SendBack(DONTTEL,b);

    case b of
      ECHO:
        if ts.TelEcho>0 then
          case HisOpt[ECHO].Status of
            Yes: ts.LocalEcho := 0;
            No:  ts.LocalEcho := 1;
          end;
      BINARY:
        case HisOpt[BINARY].Status of
          Yes: cv.TelBinRecv := TRUE;
          No:  cv.TelBinRecv := FALSE;
        end;
    end;
    TelStatus := TelIdle;
  end;
  end;

  procedure ParseTelDo(b: byte);
  begin
  with tr do begin
    if b <= MaxTelOpt then
    begin
      case MyOpt[b].Status of
        No: begin
             if MyOpt[b].Accept
             then begin
               MyOpt[b].Status := Yes;
               SendBack(WILLTEL,b);
             end
             else
               SendBack(WONTTEL,b);
            end;

        WantNo: case MyOpt[b].Que of
                  Empty: MyOpt[b].Status := No;
                  Opposite: MyOpt[b].Status := Yes;
                end;

        WantYes: case MyOpt[b].Que of
                   Empty: MyOpt[b].Status := Yes;
                   Opposite: begin
                     MyOpt[b].Status := WantNo;
                     MyOpt[b].Que := Empty;
                     SendBack(WONTTEL,b);
                   end;
                 end;
      end;
    end
    else
      SendBack(WONTTEL,b);

    case b of
      BINARY:
        case MyOpt[BINARY].Status of
          Yes: cv.TelBinSend := TRUE;
          No:  cv.TelBinSend := FALSE;
        end;
      NAWS: if MyOpt[NAWS].Status=Yes then
          SendWinSize;
    end;
    TelStatus := TelIdle;
  end;
  end;

  procedure ParseTelDont(b: byte);
  begin
  with tr do begin
    if b <= MaxTelOpt then
      case MyOpt[b].Status of
        Yes: begin
               MyOpt[b].Status := No;
               SendBack(WONTTEL,b);
             end;
   
        WantNo: case MyOpt[b].Que of
                  Empty: MyOpt[b].Status := No;
                  Opposite: begin
                    MyOpt[b].Status := WantYes;
                    MyOpt[b].Que := Empty;
                    SendBack(WILLTEL,b);
                  end;
                end;  

        WantYes: case MyOpt[b].Que of
                   Empty: MyOpt[b].Status := No;
                   Opposite: begin
                     MyOpt[b].Status := No;
                     MyOpt[b].Que := Empty;
                   end;
                 end;
      end
    else
      SendBack(WONTTEL,b);

    case b of
      BINARY:
        case MyOpt[BINARY].Status of
          Yes: cv.TelBinSend := TRUE;
          No:  cv.TelBinSend := FALSE;
        end;
    end;
    TelStatus := TelIdle;
  end;
  end;


var
  b: byte;
  c: integer;
begin
with tr do begin

  c := CommReadRawByte(@cv,@b);

  while (c>0) and (cv.TelMode) do
  begin
    if LogFile<>0 then
    begin
      if TelStatus=TelIAC then
      begin
        _lwrite(LogFile,#$0d#$0a'<',3);
        TelWriteLog1($ff);
      end;
      TelWriteLog1(b);
    end;

    ChangeWinSize := FALSE;

    case TelStatus of
      TelIAC: ParseTelIAC(b);
      TelSB: ParseTelSB(b);
      TelWill: ParseTelWill(b);
      TelWont: ParseTelWont(b);
      TelDo: ParseTelDo(b);
      TelDont: ParseTelDont(b);
      TelNop: TelStatus := TelIdle;
    end;
    if TelStatus = TelIdle then cv.TelMode := FALSE;

    if cv.TelMode then c := CommReadRawByte(@cv,@b);
  end;

  Size := ChangeWinSize;
  nx := WinSize.x;
  ny := WinSize.y;
end;
end;


procedure TelEnableHisOpt(b: byte);
begin
with tr do begin
  if b <= MaxTelOpt then
  case HisOpt[b].Status of
    No: begin
          HisOpt[b].Status := WantYes;
          SendBack(DOTEL,b);
        end;

    WantNo: if HisOpt[b].Que=Empty then
               HisOpt[b].Que := Opposite;

    WantYes: if HisOpt[b].Que=Opposite then
                HisOpt[b].Que := Empty;
  end;                              
end;
end;

procedure TelDisableHisOpt(b: byte);
begin
with tr do begin
  if b <= MaxTelOpt then
  case HisOpt[b].Status of
    Yes: begin
           HisOpt[b].Status := WantNo;
           SendBack(DONTTEL,b);
         end;

    WantNo: if HisOpt[b].Que=Opposite then
               HisOpt[b].Que := Empty;

    WantYes: if HisOpt[b].Que=Empty then
                HisOpt[b].Que := Opposite;
  end;
end;
end;

procedure TelEnableMyOpt(b: byte);
begin
with tr do begin
  if b <= MaxTelOpt then
  case MyOpt[b].Status of
    No: begin
          MyOpt[b].Status := WantYes;
          SendBack(WILLTEL,b);
        end;

    WantNo: if MyOpt[b].Que=Empty then
               MyOpt[b].Que := Opposite;

    WantYes: if MyOpt[b].Que=Opposite then
                MyOpt[b].Que := Empty;
  end;
end;
end;

procedure TelDisableMyOpt(b: byte);
begin
with tr do begin
  if b <= MaxTelOpt then
  case MyOpt[b].Status of
    Yes: begin
           MyOpt[b].Status := WantNo;
           SendBack(WONTTEL,b);
         end;

    WantNo: if MyOpt[b].Que=Opposite then
               MyOpt[b].Que := Empty;

    WantYes: if MyOpt[b].Que=Empty then
                MyOpt[b].Que := Opposite;
  end;
end;
end;

procedure TelInformWinSize(nx, ny: integer);
begin
with tr do begin
  if (MyOpt[NAWS].Status=Yes) and
     ((nx<>WinSize.x) or
      (ny<>WinSize.y)) then
  begin
    WinSize.x := nx;
    WinSize.y := ny;
    SendWinSize;
  end;
end;
end;

procedure TelSendAYT;
var
  Str: array[0..1] of char;
begin
  Str[0] := char(IAC);
  Str[1] := char(AYT);
  CommRawOut(@cv,Str,2);
  CommSend(@cv);
  if tr.LogFile<>0 then
    TelWriteLog(Str,2);
end;

procedure TelSendBreak;
var
  Str: array[0..1] of char;
begin
  Str[0] := char(IAC);
  Str[1] := char(BREAK);
  CommRawOut(@cv,Str,2);
  CommSend(@cv);
  if tr.LogFile<>0 then
    TelWriteLog(Str,2);
end;

procedure TelChangeEcho;
begin
  if ts.LocalEcho=0 then
    TelEnableHisOpt(ECHO)
  else
    TelDisableHisOpt(ECHO);
end;

end.