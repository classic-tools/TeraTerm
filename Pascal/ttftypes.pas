{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{Constants, types for file transfer}
unit TTFTypes;

interface

uses WinTypes, TTTypes, Types;

{GetSetupFname function id}
const
  GSF_SAVE    = 0; {Save setup}
  GSF_RESTORE = 1; {Restore setup}
  GSF_LOADKEY = 2; {Load key map}

{GetTransFname function id}
const
  GTF_SEND = 0; {Send file}
  GTF_LOG  = 1; {Log}
  GTF_BP   = 2; {B-Plus Send}

{GetMultiFname function id}
  GMF_KERMIT = 0; {Kermit Send}
  GMF_Z = 1;      {ZMODEM Send}
  GMF_QV = 2;     {Quick-VAN Send}

const
  FnStrMemSize = 4096;

const
  PROTO_KMT = 1;
  PROTO_XM  = 2;
  PROTO_ZM  = 3;
  PROTO_BP  = 4;
  PROTO_QV  = 5;

const
  OpLog      = 1;
  OpSendFile = 2;
  OpKmtRcv   = 3;
  OpKmtGet   = 4;
  OpKmtSend  = 5;
  OpKmtFin   = 6;
  OpXRcv     = 7;
  OpXSend    = 8;
  OpZRcv     = 9;
  OpZSend    = 10;
  OpBPRcv    = 11;
  OpBPSend   = 12;
  OpQVRcv    = 13;
  OpQVSend   = 14;

  TitLog      = 'Log';
  TitSendFile = 'Send file';
  TitKmtRcv   = 'Kermit Receive';
  TitKmtGet   = 'Kermit Get';
  TitKmtSend  = 'Kermit Send';
  TitKmtFin   = 'Kermit Finish';
  TitXRcv     = 'XMODEM Receive';
  TitXSend    = 'XMODEM Send';
  TitZRcv     = 'ZMODEM Receive';
  TitZSend    = 'ZMODEM Send';
  TitBPRcv    = 'B-Plus Receive';
  TitBPSend   = 'B Plus Send';
  TitQVRcv    = 'Quick-VAN Receive';
  TitQVSend   = 'Quick-VAN Send';

type
  PFileVar = ^TFileVar;
  TFileVar = record
    HMainWin: HWnd;
    HWin: HWnd;
    OpId: WORD;
    DlgCaption: array[0..39] of char;

    FullName: array[0..MAXPATHLEN-1] of char;
    DirLen: integer;

    NumFname, FNCount: integer;

    FnStrMemHandle: THandle;
    FnStrMem: PChar;
    FnPtr: integer;

    FileOpen: BOOL;
    FileHandle: integer;
    FileSize, ByteCount: longint;
    OverWrite: BOOL;

    LogFlag: BOOL;
    LogFile: integer;
    LogState: word;
    LogCount: word;

    Success: BOOL;
    NoMsg: BOOL;
  end;

  KermitParam = record
    MAXL,TIME,NPAD,PADC,EOL,QCTL,QBIN,CHKT,REPT: byte;
  end; 

  PKmtVar = ^TKmtVar;
  TKmtVar = record
    PktIn, PktOut: array[0..95] of byte;
    PktInPtr: integer;
    PktInLen, PktInCount: integer;
    PktNum, PktNumOffset: integer;
    PktReadMode: integer;
    KmtMode, KmtState: integer;
    Quote8, RepeatFlag: BOOL;
    ByteStr: array[0..5] of char;
    NextByteFlag: BOOL;
    RepeatCount: integer;
    NextSeq: byte;
    NextByte: byte;
    KmtMy, KmtYour: KermitParam;
  end;

const
  {Kermit states}
  WaitMark  = 0;
  WaitLen   = 1;
  WaitCheck = 2;

  UnKnown = 0;
  SendInit = 1;
  SendFile = 2;
  SendData = 3;
  SendEOF = 4;
  SendEOT = 5;

  ReceiveInit = 6;
  ReceiveFile = 7;
  ReceiveData = 8;

  ServerInit = 9;
  GetInit = 10;
  Finish = 11;

{XMODEM}
type
  PXVar = ^TXVar;
  TXVar = record
    PktIn, PktOut: array[0..1029] of byte;
    PktBufCount, PktBufPtr: integer;
    PktNum, PktNumSent: byte;
    PktNumOffset: integer;
    PktReadMode: integer;
    XMode, XOpt, TextFlag: word;
    NAKMode: word;
    NAKCount: integer;
    DataLen, CheckLen: word;
    CRRecv: BOOL;
    TOutShort: integer;
    TOutLong: integer;
  end;

  {XMODEM states}
const
  XpktSOH = 1;
  XpktBLK = 2;
  XpktBLK2 = 3;
  XpktDATA = 4;

  XnakNAK = 1;
  XnakC = 2;

{ZMODEM}
type
  PZVar = ^TZVar;
  TZVar = record
    RxHdr, TxHdr: array[0..3] of byte;
    RxType, TERM: byte;
    PktIn, PktOut: array[0..1031] of byte;
    PktInPtr, PktOutPtr: integer;
    PktInCount, PktOutCount: integer;
    PktInLen: integer;
    BinFlag: BOOL;
    Sending: BOOL;
    ZMode, ZState, ZPktState: integer;
    MaxDataLen, TimeOut, CanCount: integer;
    CtlEsc, CRC32, HexLo, Quoted, CRRecv: BOOL;
    CRC: word;
    CRC3, Pos, LastPos, WinSize: longint;
    LastSent: byte;
  end;

const
  Z_RecvInit = 1;
  Z_RecvInit2 = 2;
  Z_RecvData = 3;
  Z_RecvFin  = 4;
  Z_SendInit = 5;
  Z_SendInitHdr = 6;
  Z_SendInitDat = 7;
  Z_SendFileHdr = 8;
  Z_SendFileDat = 9;
  Z_SendDataHdr = 10;
  Z_SendDataDat = 11;
  Z_SendDataDat2 = 12;
  Z_SendEOF  = 13;
  Z_SendFIN  = 14;
  Z_Cancel   = 15;
  Z_End      = 16;

  Z_PktGetPAD = 1;
  Z_PktGetDLE = 2;
  Z_PktHdrFrm = 3;
  Z_PktGetBin = 4;
  Z_PktGetHex = 5;
  Z_PktGetHexEOL = 6;
  Z_PktGetData = 7;
  Z_PktGetCRC = 8;

{B Plus}
type
  TBPParam = record
    WS: byte;
    WR: byte;
    B_S: byte;
    CM: byte;
    DQ: byte;
    TL: byte;
    Q: array[0..7] of byte;
    DR: byte;
    UR: byte;
    FI: byte;
  end;

  PBPVar = ^TBPVar;
  TBPVar = record
    PktIn, PktOut: array[0..2065] of byte;
    PktInCount, CheckCount: integer;
    PktOutLen, PktOutCount, PktOutPtr: integer;
    Check, CheckCalc: longint;
    PktNum, PktNumSent: byte;
    PktNumOffset: integer;
    PktSize: integer;
    BPMode, BPState, BPPktState: word;
    GetPacket, EnqSent: BOOL;
    MaxBS, CM: byte;
    Quoted: BOOL;
    TimeOut: integer;
    CtlEsc: BOOL;
    Q: array[0..7] of byte;
  end;

const
  {B Plus states}
  BP_Init      = 1;
  BP_RecvFile  = 2;
  BP_RecvData  = 3;
  BP_SendFile  = 4;
  BP_SendData  = 5;
  BP_SendClose = 6;
  BP_Failure   = 7;
  BP_Close     = 8;
  BP_AutoFile  = 9;

  {B Plus packet states}
  BP_PktGetDLE   = 1;
  BP_PktDLESeen  = 2;
  BP_PktGetData  = 3;
  BP_PktGetCheck = 4;
  BP_PktSending  = 5;

{Quick-VAN}
type
  PQVVar = ^TQVVar;
  TQVVar = record
    PktIn, PktOut: array[0..141] of byte;
    PktInCount, PktInPtr: integer;
    PktOutCount, PktOutPtr, PktOutLen: integer;
    Ver, WinSize: word;
    QVMode, QVState, PktState: word;
    AValue: word;
    SeqNum: word;
    FileNum: word;
    RetryCount: integer;
    CanFlag: BOOL;
    Year,Month,Day,Hour,Min,Sec: word;
    SeqSent, WinEnd, FileEnd: word;
    EnqFlag: BOOL;
    CheckSum: byte;
  end;

  {Quick-VAN states}
const
  QV_RecvInit1 = 1;
  QV_RecvInit2 = 2;
  QV_RecvData = 3;
  QV_RecvDataRetry = 4;
  QV_RecvNext = 5;
  QV_RecvEOT = 6;
  QV_Cancel = 7;
  QV_Close = 8;

  QV_SendInit1 = 11;
  QV_SendInit2 = 12;
  QV_SendInit3 = 13;
  QV_SendData = 14;
  QV_SendDataRetry = 15;
  QV_SendNext = 16;
  QV_SendEnd = 17;

  QVpktSOH = 1;
  QVpktBLK = 2;
  QVpktBLK2 = 3;
  QVpktDATA = 4;

  QVpktSTX = 5;
  QVpktCR = 6;

implementation
end.
