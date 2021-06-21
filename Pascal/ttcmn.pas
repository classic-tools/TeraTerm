{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTCMN.DLL, main}
library TTCMN;
{$R teraterm.res}
{$I teraterm.inc}

{$IFDEF Delphi}
uses
  Messages, WinTypes, WinProcs, WinDos, OWindows, Strings,
  TTTypes, Types, TTFTypes, TTLib, Language;
{$ELSE}
uses
  Win31, WinTypes, WinProcs, WinDos, WObjects, Strings,
  TTTypes, Types, TTFTypes, TTLib, Language;
{$ENDIF}

var
  {first instance flag}
  FirstInstance: bool;

const
  MAXNWIN = 50;

type
  PMap = ^TMap;
  TMap = record
    {Setup information from 'teraterm.ini'}
    ts: TTTSet;
    {Key code map from 'keyboard.cnf'}
    km: TKeyMap;
    {Window list}
    NWin: integer;
    WinList: array[0..MAXNWIN-1] of HWnd;
    {COM port use flag - bit0-15 : COM1-16}
    ComFlag: word;
  end;

var
  pm: PMap;

{$ifdef TERATERM32}
var
  HMap: THandle;
const
  VTCLASSNAME = 'VTWin32';
  TEKCLASSNAME = 'TEKWin32';
{$else}
var
  map: TMap;
const
  VTCLASSNAME = 'VTWin';
  TEKCLASSNAME = 'TEKWin';
{$endif}

function StartTeraTerm(ts: PTTSet): bool; export;
var
  Temp: array[0..MAXPATHLEN-1] of char;
begin
  if FirstInstance then
  begin
    {FirstInstance := FALSE;}

    {init window list}
    pm^.NWin := 0;
    {Get home directory}
    GetModuleFileName(HInstance,Temp,sizeof(Temp));
    ExtractDirName(Temp,pm^.ts.HomeDir);
    SetCurDir(pm^.ts.HomeDir);
    strcopy(pm^.ts.SetupFName,pm^.ts.HomeDir);
    AppendSlash(pm^.ts.SetupFName);
    strcat(pm^.ts.SetupFName,'TERATERM.INI');
{    strcopy(Temp,pm^.ts.HomeDir);
    AppendSlash(Temp);
    strcat(Temp,'KEYBOARD.CNF');
    if LoadTTSET then
    begin }
      {read setup info from 'teraterm.ini'}
{      ReadIniFile(pm^.ts.SetupFName, @pm^.ts);}
      {read keycode map from 'keyboard.cnf'}
{      ReadKeyboardCnf(Temp,@pm^.km,TRUE);
      FreeTTSET;
    end;        }
  end
  else begin
    {only the first instance uses saved position}
    pm^.ts.VTPos.x := CW_USEDEFAULT;
    pm^.ts.VTPos.y := CW_USEDEFAULT;
    pm^.ts.TEKPos.x := CW_USEDEFAULT;
    pm^.ts.TEKPos.y := CW_USEDEFAULT;
  end;

  ts^ := pm^.ts;
  StartTeraTerm := FirstInstance;
  if FirstInstance then
    FirstInstance := FALSE;
end;

procedure ChangeDefaultSet(ts: PTTSet; km: PKeyMap); export;
begin
  if (ts<>nil) and
     (stricomp(ts^.SetupFName,pm^.ts.SetupFName)=0) then
    pm^.ts := ts^;
  if km<>nil then pm^.km := km^;
end;

procedure GetDefaultSet(ts: PTTSet); export;
begin
  ts^ := pm^.ts;
end;

{procedure LoadDefaultSet(SetupFName: PChar); export;
begin
  if stricomp(SetupFName,pm^.ts.SetupFName)<>0 then
    exit;

  if LoadTTSET then
  begin }
    {read setup info from 'teraterm.ini'}
{    ReadIniFile(pm^.ts.SetupFName,@pm^.ts);
    FreeTTSET;
  end;
end;}

{Key scan code -> Tera Term key code}
function GetKeyCode(KeyMap: PKeyMap; Scan: word): word; export;
var
  Key: word;
begin                                                   
  if KeyMap=nil then
    KeyMap := @pm^.km;
  Key := IdKeyMax;
  while (Key>0) and (KeyMap^.Map[Key-1]<>Scan) do
    Dec(Key);
  GetKeyCode := Key;
end;

procedure GetKeyStr(HWin: HWnd; KeyMap: PKeyMap; KeyCode: word; AppliKeyMode, AppliCursorMode: BOOL;
                    KeyStr: PChar; Len: PInteger; KeyType: PWORD); export;
var
  Msg: TMsg;
  Temp: array[0..200] of char;
begin
  if KeyMap=nil then
    KeyMap := @pm^.km;

  KeyType^ := IdText; {key type}
  Len^ := 0;
  case KeyCode of
    IdUp:
      begin
        Len^ := 3;
        if AppliCursorMode then StrCopy(KeyStr,#$1B'OA')
                           else StrCopy(KeyStr,#$1B'[A');
      end;
    IdDown:
      begin
        Len^ := 3;
        if AppliCursorMode then StrCopy(KeyStr,#$1B'OB')
                           else StrCopy(KeyStr,#$1B'[B');
      end;
    IdRight:
      begin
        Len^ := 3;
        if AppliCursorMode then StrCopy(KeyStr,#$1B'OC')
                           else StrCopy(KeyStr,#$1B'[C');
      end;
    IdLeft:
      begin
        Len^ := 3;
        if AppliCursorMode then StrCopy(KeyStr,#$1B'OD')
                           else StrCopy(KeyStr,#$1B'[D');
      end;
    Id0:
      begin
        if AppliKeyMode
        then begin
          Len^ := 3;
          StrCopy(KeyStr,#$1B'Op');
        end
        else begin
          Len^ := 1;
          KeyStr[0] := '0';
        end;
      end;
    Id1:
      begin
        if AppliKeyMode
        then begin
          Len^ := 3;
          StrCopy(KeyStr,#$1B'Oq');
        end
        else begin
          Len^ := 1;
          KeyStr[0] := '1';
        end;
      end;
    Id2:
      begin
        if AppliKeyMode
        then begin
          Len^ := 3;
          StrCopy(KeyStr,#$1B'Or');
        end
        else begin
          Len^ := 1;
          KeyStr[0] := '2';
        end;
      end;
    Id3:
      begin
        if AppliKeyMode
        then begin
          Len^ := 3;
          StrCopy(KeyStr,#$1B'Os');
        end
        else begin
          Len^ := 1;
          KeyStr[0] := '3';
        end;
      end;
    Id4:
      begin
        if AppliKeyMode
        then begin
          Len^ := 3;
          StrCopy(KeyStr,#$1B'Ot');
        end
        else begin
          Len^ := 1;
          KeyStr[0] := '4';
        end;
      end;
    Id5:
      begin
        if AppliKeyMode
        then begin
          Len^ := 3;
          StrCopy(KeyStr,#$1B'Ou');
        end
        else begin
          Len^ := 1;
          KeyStr[0] := '5';
        end;
      end;
    Id6:
      begin
        if AppliKeyMode
        then begin
          Len^ := 3;
          StrCopy(KeyStr,#$1B'Ov');
        end
        else begin
          Len^ := 1;
          KeyStr[0] := '6';
        end;
      end;
    Id7:
      begin
        if AppliKeyMode
        then begin
          Len^ := 3;
          StrCopy(KeyStr,#$1B'Ow');
        end
        else begin
          Len^ := 1;
          KeyStr[0] := '7';
        end;
      end;
    Id8:
      begin
        if AppliKeyMode
        then begin
          Len^ := 3;
          StrCopy(KeyStr,#$1B'Ox');
        end
        else begin
          Len^ := 1;
          KeyStr[0] := '8';
        end;
      end;
    Id9:
      begin
        if AppliKeyMode
        then begin
          Len^ := 3;
          StrCopy(KeyStr,#$1B'Oy');
        end
        else begin
          Len^ := 1;
          KeyStr[0] := '9';
        end;
      end;
    IdMinus: {numaric pad - key (DEC)}
      begin
        if AppliKeyMode
        then begin
          Len^ := 3;
          StrCopy(KeyStr,#$1B'Om');
        end
        else begin
          Len^ := 1;
          KeyStr[0] := '-';
        end;
      end;
    IdComma: {numaric pad , key (DEC)}
      begin
        if AppliKeyMode
        then begin
          Len^ := 3;
          StrCopy(KeyStr,#$1B'Ol');
        end
        else begin
          Len^ := 1;
          KeyStr[0] := ',';
        end;
      end;
    IdPeriod: {numaric pad . key}
      begin
        if AppliKeyMode
        then begin
          Len^ := 3;
          StrCopy(KeyStr,#$1B'On');
        end
        else begin
          Len^ := 1;
          KeyStr[0] := '.';
        end;
      end;
    IdEnter: {numaric pad enter key}
      begin
        if AppliKeyMode
        then begin
          Len^ := 3;
          StrCopy(KeyStr,#$1B'OM');
        end
        else begin
          Len^ := 1;
          KeyStr[0] := #$0D;
        end;
      end;
    IdPF1: {DEC Key: PF1}
      begin
        Len^ := 3;
        StrCopy(KeyStr,#$1B'OP');
      end;
    IdPF2: {DEC Key: PF2}
      begin
        Len^ := 3;
        StrCopy(KeyStr,#$1B'OQ');
      end;
    IdPF3: {DEC Key: PF3}
      begin
        Len^ := 3;
        StrCopy(KeyStr,#$1B'OR');
      end;
    IdPF4: {DEC Key: PF4}
      begin
        Len^ := 3;
        StrCopy(KeyStr,#$1B'OS');
      end;
    IdFind: {DEC Key: Find}
      begin
        Len^ := 4;
        StrCopy(KeyStr,#$1B'[1~');
      end;
    IdInsert: {DEC Key: Insert Here}
      begin
        Len^ := 4;
        StrCopy(KeyStr,#$1B'[2~');
      end;
    IdRemove: {DEC Key: Remove}
      begin
        Len^ := 4;
        StrCopy(KeyStr,#$1B'[3~');
      end;
    IdSelect: {DEC Key: Select}
      begin
        Len^ := 4;
        StrCopy(KeyStr,#$1B'[4~');
      end;
    IdPrev: {DEC Key: Prev}
      begin
        Len^ := 4;
        StrCopy(KeyStr,#$1B'[5~');
      end;
    IdNext: {DEC Key: Next}
      begin
        Len^ := 4;
        StrCopy(KeyStr,#$1B'[6~');
      end;
    IdHold..
    IdBreak:
      Postmessage(HWin,WM_USER_ACCELCOMMAND,KeyCode,0);
    IdF6: {DEC Key: F6}
      begin
        Len^ := 5;
        StrCopy(KeyStr,#$1B'[17~');
      end;
    IdF7: {DEC Key: F7}
      begin
        Len^ := 5;
        StrCopy(KeyStr,#$1B'[18~');
      end;
    IdF8: {DEC Key: F8}
      begin
        Len^ := 5;
        StrCopy(KeyStr,#$1B'[19~');
      end;
    IdF9: {DEC Key: F9}
      begin
        Len^ := 5;
        StrCopy(KeyStr,#$1B'[20~');
      end;
    IdF10: {DEC Key: F10}
      begin
        Len^ := 5;
        StrCopy(KeyStr,#$1B'[21~');
      end;
    IdF11: {DEC Key: F11}
      begin
        Len^ := 5;
        StrCopy(KeyStr,#$1B'[23~');
      end;
    IdF12: {DEC Key: F12}
      begin
        Len^ := 5;
        StrCopy(KeyStr,#$1B'[24~');
      end;
    IdF13: {DEC Key: F13}
      begin
        Len^ := 5;
        StrCopy(KeyStr,#$1B'[25~');
      end;
    IdF14: {DEC Key: F14}
      begin
        Len^ := 5;
        StrCopy(KeyStr,#$1B'[26~');
      end;
    IdHelp: {DEC Key: Help}
      begin
        Len^ := 5;
        StrCopy(KeyStr,#$1B'[28~');
      end;
    IdDo: {DEC Key: Do}
      begin
        Len^ := 5;
        StrCopy(KeyStr,#$1B'[29~');
      end;
    IdF17: {DEC Key: F17}
      begin
        Len^ := 5;
        StrCopy(KeyStr,#$1B'[31~');
      end;
    IdF18: {DEC Key: F18}
      begin
        Len^ := 5;
        StrCopy(KeyStr,#$1B'[32~');
      end;
    IdF19: {DEC Key: F19}
      begin
        Len^ := 5;
        StrCopy(KeyStr,#$1B'[33~');
      end;
    IdF20: {DEC Key: F20}
      begin
        Len^ := 5;
        StrCopy(KeyStr,#$1B'[34~');
      end;
    IdXF1: {XTERM F1}
      begin
        Len^ := 5;
        StrCopy(KeyStr,#$1B'[11~');
      end;
    IdXF2: {XTERM F2}
      begin
        Len^ := 5;
        StrCopy(KeyStr,#$1B'[12~');
      end;
    IdXF3: {XTERM F3}
      begin
        Len^ := 5;
        StrCopy(KeyStr,#$1B'[13~');
      end;
    IdXF4: {XTERM F4}
      begin
        Len^ := 5;
        StrCopy(KeyStr,#$1B'[14~');
      end;
    IdXF5: {XTERM F5}
      begin
        Len^ := 5;
        StrCopy(KeyStr,#$1B'[15~');
      end;
    IdCmdEditCopy..
    IdCmdLocalEcho:
      Postmessage(HWin,WM_USER_ACCELCOMMAND,KeyCode,0);
    IdUser1..IdKeyMax:
      begin
        with KeyMap^ do begin
          KeyType^ := word(UserKeyType[KeyCode-IdUser1]);
          Len^ := UserKeyLen[KeyCode-IdUser1];
          Move(UserKeyStr[UserKeyPtr[KeyCode-IdUser1]],Temp[0],Len^);
          Temp[Len^] := #0;
          if (KeyType^=IdBinary) or (KeyType^=IdText) then
            Len^ := Hex2Str(Temp,KeyStr,sizeof(Temp))
          else
            strcopy(KeyStr,Temp);
        end;
      end;
  else
    exit;
  end;
  {remove WM_CHAR message for used keycode}
  PeekMessage(Msg,HWin,WM_CHAR,WM_CHAR,PM_REMOVE);
end;

procedure SetCOMFlag(Com: word); export;
begin
  pm^.ComFlag := Com;
end;

function GetCOMFlag: word; export;
begin
  GetComFlag := pm^.ComFlag;
end;

function RegWin(HWinVT, HWinTEK: HWnd): integer; export;
var
  i, j: integer;
begin
  RegWin := 0;
  if pm^.NWin>=MAXNWIN then exit;
  if HWinVT=0 then exit;
  if HWinTEK<>0 then
  begin
    i := 0;
    while (i<pm^.NWin) and (pm^.WinList[i]<>HWinVT) do
      inc(i);
    if i>=pm^.NWin then exit;
    for j := pm^.NWin-1 downto i+1 do
      pm^.WinList[j+1] := pm^.WinList[j];
    pm^.WinList[i+1] := HWinTEK;
    inc(pm^.NWin);
    exit;
  end;
  pm^.WinList[pm^.NWin] := HWinVT;
  inc(pm^.NWin);
  if pm^.NWin=1 then
    RegWin := 1
  else
    RegWin := integer(SendMessage(pm^.WinList[pm^.NWin-2],
      WM_USER_GETSERIALNO,0,0)) + 1;
end;

procedure UnregWin(HWin: HWnd); export;
var
  i, j: integer;
begin
  i := 0;
  while (i<pm^.NWin) and (pm^.WinList[i]<>HWin) do
    inc(i);
  if pm^.WinList[i]<>HWin then exit;
  for j :=i to pm^.NWin-2 do
    pm^.WinList[j] := pm^.WinList[j+1];
  if pm^.NWin>0 then dec(pm^.NWin);
end;

procedure SetWinMenu(menu: HMenu); export;
var
  i: integer;
  Temp: array[0..MAXPATHLEN-1] of char;
  Hw: HWnd;
begin
  {delete all items in Window menu}
  i := GetMenuItemCount(menu);
  if i>0 then
    repeat
      dec(i);
      RemoveMenu(menu,i,MF_BYPOSITION);
    until i<=0;

  i := 0;
  while i<pm^.NWin do
  begin
    Hw := pm^.WinList[i]; {get window handle}
    if (GetClassName(Hw,Temp,sizeof(Temp))>0) and
       ((strcomp(Temp,VTCLASSNAME)=0) or
        (strcomp(Temp,TEKCLASSNAME)=0)) then
    begin
      Temp[0] := '&';
      Temp[1] := char($31 + i);
      Temp[2] := ' ';
      GetWindowText(Hw,@Temp[3],sizeof(Temp)-4);
      AppendMenu(menu,MF_ENABLED or MF_STRING,ID_WINDOW_1+i,Temp);
      inc(i);
      if i>8 then i := pm^.NWin;
    end
    else
      UnregWin(Hw);
  end;
  AppendMenu(menu,MF_ENABLED or MF_STRING,ID_WINDOW_1+9,'&Window...');
end;

procedure SetWinList(HWin, HDlg: HWnd; IList: integer); export;
var
  i: integer;
  Temp: array[0..MAXPATHLEN-1] of char;
  Hw: HWND;
begin
  for i := 0 to pm^.NWin-1 do
  begin
    Hw := pm^.WinList[i]; {get window handle}
    if (GetClassName(Hw,Temp,sizeof(Temp))>0) and
       ((strcomp(Temp,VTCLASSNAME)=0) or
        (strcomp(Temp,TEKCLASSNAME)=0)) then
    begin
      GetWindowText(Hw,Temp,sizeof(Temp)-1);
      SendDlgItemMessage(HDlg, IList, LB_ADDSTRING,
                         0, longint(@Temp[0]));
      if Hw=HWin then 
        SendDlgItemMessage(HDlg, IList, LB_SETCURSEL,
                           i,0);
    end
    else
      UnregWin(Hw);
  end;
end;

procedure SelectWin(WinId: integer); export;
begin
  if (WinId>=0) and (WinId<pm^.NWin) then
  begin
    ShowWindow(pm^.WinList[WinId],SW_SHOWNORMAL);
{$ifdef TERATERM32}
    SetForegroundWindow(pm^.WinList[WinId]);
{$else}
    SetActiveWindow(pm^.WinList[WinId]);
{$endif}
  end;
end;

procedure SelectNextWin(HWin: HWnd; Next: integer); export;
var
  i: integer;
begin
  i := 0;
  while (i<pm^.NWin) and (pm^.WinList[i]<>HWin) do
    inc(i);
  if pm^.WinList[i]<>HWin then exit;
  i := i + Next;
  if i >= pm^.NWin then
    i := 0
  else if i<0 then
    i := pm^.NWin-1;
  SelectWin(i);
end;

function GetNthWin(n: integer): HWnd; export;
begin
  if n<pm^.NWin then
    GetNthWin := pm^.WinList[n]
  else
    GetNthWin := 0;
end;

function CommReadRawByte(cv: PComVar; b: Pbyte): integer; export;
begin
with cv^ do begin
  if not Ready then
  begin
    CommReadRawByte := 0;
    exit;
  end;

  if InBuffCount>0 then
  begin
    b^ := InBuff[InPtr];
    inc(InPtr);
    dec(InBuffCount);
    CommReadRawByte := 1;
  end
  else
    CommReadRawByte := 0;

  if InBuffCount=0 then InPtr := 0;
end;
end;

procedure CommInsert1Byte(cv: PComVar; b:byte); export;
begin
with cv^ do begin
  if not Ready then exit;

  if InPtr = 0
  then
    Move(InBuff[0],InBuff[1],InBuffCount)
  else
    Dec(InPtr);
  InBuff[InPtr] := b;
  Inc(InBuffCount);

  if HBinBuf<>0 then inc(BinSkip);
end;
end;

procedure Log1Bin(cv: PComVar; b: byte);
begin
  with cv^ do begin
    if (FilePause and OpLog <>0) or ProtoFlag then exit;
    if BinSkip > 0 then
    begin
      dec(BinSkip);
      exit;
    end;
    BinBuf[BinPtr] := char(b);
    inc(BinPtr);
    if BinPtr>=InBuffSize then BinPtr := BinPtr-InBuffSize;
    if BCount>=InBuffSize then
    begin
      BCount := InBuffSize;
      BStart := BinPtr;
    end
    else inc(BCount);
  end;
end;

function CommRead1Byte(cv: PComVar; b: Pbyte): integer; export;
var
  c: integer;
begin
with cv^ do begin
  CommRead1Byte := 0;
  if not Ready then exit;
  if (HLogBuf<>0) and
     ((LCount>=InBuffSize-10) or
      (DCount>=InBuffSize-10)) then exit;

  if (HBinBuf<>0) and
     (BCount>=InBuffSize-10) then exit;

  if TelMode then
    c := 0
  else
    c := CommReadRawByte(cv,b);

  if (c=1) and TelCRFlag then
  begin
    TelCRFlag := FALSE;
    if b^=0 then c := 0;
  end;

  if c=1 then
  begin
    if IACFlag then
    begin
      IACFlag := FALSE;
      if b^<>$FF then
      begin
        TelMode := TRUE;
        CommInsert1Byte(cv,b^);
        if HBinBuf<>0 then dec(BinSkip);
        c := 0;
      end;
    end
    else if (PortType=IdTCPIP) and (b^=$FF) then
    begin
      if not TelFlag and TelAutoDetect then {TTPLUG}
        TelFlag := TRUE;
      if TelFlag then
      begin
        IACFlag := TRUE;
        c := 0;
      end;
    end
    else if TelFlag and not TelBinRecv and (b^=$0D) then
      TelCRFlag := TRUE;      
  end;

  if (c=1) and (HBinBuf<>0) then
    Log1Bin(cv, b^);

  CommRead1Byte := c;
end;
end;

function CommRawOut(cv: PComVar; B: PChar; C: integer): integer; export;
var
  a: integer;
begin
with cv^ do begin
  if not Ready then
  begin
    CommRawOut := C;
    exit;
  end;

  if C > OutBuffSize-OutBuffCount then
    a := OutBuffSize-OutBuffCount
  else
    a := C;
  if OutPtr > 0 then
  begin
    Move(OutBuff[OutPtr],OutBuff[0],OutBuffCount);
    OutPtr := 0;
  end;
  Move(B[0],OutBuff[OutBuffCount],a);
  OutBuffCount := OutBuffCount + a;
  CommRawOut := a;

end;
end;

function CommBinaryOut(cv: PComVar; B: PChar; C: integer): integer; export;
var
  a, i, Len: integer;
  d: array[0..2] of byte;
begin
with cv^ do begin
  if not Ready then
  begin
    CommBinaryOut := C;
    exit;
  end;

  i := 0;
  a := 1;
  while (a>0) and (i<C) do
  begin
    Len := 0;

    d[Len] := byte(B[i]);
    inc(Len);

    if TelFlag and (B[i]=#$0D) and
       not TelBinSend then
    begin
      d[Len] := $00;
      inc(Len);
    end;

    if TelFlag and (B[i]=#$ff) then
    begin
      d[Len] := $ff;
      inc(Len);
    end;

    if OutBuffSize-OutBuffCount-Len >=0 then
    begin
      CommRawOut(cv,@d[0],Len);
      a := 1;
    end
    else
      a := 0;

    i := i + a;
  end;
  CommBinaryOut := i;
end;
end;

function TextOutJP(cv: PComVar; B: PChar; C: integer): integer;
var
  i, TempLen: integer;
  K: word;
  TempStr: array[0..10] of char;
  SendCodeNew: integer;
  d: byte;
  Full, KanjiFlagNew: boolean;
begin
with cv^ do begin
  Full := FALSE;
  i := 0;
  while not Full and (i < C) do
  begin
    TempLen := 0;
    d := byte(B[i]);
    SendCodeNew := SendCode;

    if SendKanjiFlag then
    begin
      KanjiFlagNew := FALSE;
      SendCodeNew := IdKanji;

      K := SendKanjiFirst shl 8 + d;
      if KanjiCodeSend = IdEUC then K := SJIS2EUC(K)
      else if KanjiCodeSend <> IdSJIS then K := SJIS2JIS(K);

      if (SendCode=IdKatakana) and
         (KanjiCodeSend=IdJIS) and
         (JIS7KatakanaSend=1) then
      begin
        TempStr[TempLen] := char(SI);
        inc(TempLen);
      end;

      TempStr[TempLen] := char(Hi(K));
      TempStr[TempLen+1] := char(Lo(K));
      TempLen := TempLen + 2;
    end
    else

      if IsDBCSLeadByte(d)
      then begin
        KanjiFlagNew := TRUE;
        SendKanjiFirst := d;
        SendCodeNew := IdKanji;

        if (SendCode<>IdKanji) and
           (KanjiCodeSend=IdJIS) then
        begin
          TempStr[0] := #$1B;
          TempStr[1] := '$';
          if KanjiIN = IdKanjiInB then
            TempStr[2] := 'B'
          else
            TempStr[2] := '@';
          TempLen := 3;
        end
        else TempLen := 0;

      end
      else begin
        KanjiFlagNew := FALSE;

        if (SendCode=IdKanji) and
           (KanjiCodeSend=IdJIS) then
        begin
          TempStr[0] := #$1B;
          TempStr[1] := '(';
          case KanjiOut of
            IdKanjiOutJ: TempStr[2] := 'J';
            IdKanjiOutH: TempStr[2] := 'H';
          else
            TempStr[2] := 'B';
          end;
          TempLen := 3;
        end
        else TempLen := 0;

        if ($A0<d) and (d<$E0) then
        begin
          SendCodeNew := IdKatakana;
          if (SendCode<>IdKatakana) and
             (KanjiCodeSend=IdJIS) and
             (JIS7KatakanaSend=1) then
          begin
            TempStr[TempLen] := char(SO);
            inc(TempLen);
          end;
        end
        else begin
          SendCodeNew := IdASCII;
          if (SendCode=IdKatakana) and
             (KanjiCodeSend=IdJIS) and
             (JIS7KatakanaSend=1) then
          begin
            TempStr[TempLen] := char(SI);
            inc(TempLen);
          end;
        end;

        case d of
          $0d: begin
            TempStr[TempLen] := #$0d;
            inc(TempLen);
            if CRSend=IdCRLF then
            begin
              TempStr[TempLen] := #$0a;
              inc(TempLen);
            end
            else if (CRSend=IdCR) and
              TelFlag and not TelBinSend then
            begin
              TempStr[TempLen] := #0;
              inc(TempLen);
            end;
          end;
          $a1..$e0:
          begin {Katakana}
            if KanjiCodeSend=IdEUC then
            begin
              TempStr[TempLen] := #$8E;
              inc(TempLen);
            end;
            if (KanjiCodeSend=IdJIS) and
               (JIS7KatakanaSend=1) then
              TempStr[TempLen] := char(d and $7f)
            else
              TempStr[TempLen] := char(d);
            inc(TempLen);
          end;
        else
          begin
            TempStr[TempLen] := char(d);
            inc(TempLen);
            if TelFlag and (d=$FF) then
            begin
              TempStr[TempLen] := #$FF;
              inc(TempLen);
            end;
          end;
        end; {end of 'case of'}

      end; {if ISDBCSLeadByte..then ... else ... end}

    if TempLen = 0 then
    begin
      inc(i);
      SendCode := SendCodeNew;
      SendKanjiFlag := KanjiFlagNew;
    end
    else begin
      Full := OutBuffSize-OutBuffCount-TempLen < 0;
      if not Full then
      begin
        inc(i);
        SendCode := SendCodeNew;
        SendKanjiFlag := KanjiFlagNew;
        CommRawOut(cv,TempStr,TempLen);
      end;
    end;

  end; {end of 'while'}

  TextOutJP := i;

end;
end;

function CommTextOut(cv: PComVar; B: PChar; C: integer): integer; export;
var
  i, TempLen: integer;
  TempStr: array[0..10] of char;
  d: byte;
  Full: boolean;
begin
with cv^ do begin
  if not Ready then
  begin
    CommTextOut := C;
    exit;
  end;

  if Language=IdJapanese then
  begin
    CommTextOut := TextOutJP(cv,B,C);
    exit;
  end;

  Full := FALSE;
  i := 0;
  while not Full and (i < C) do
  begin
    TempLen := 0;
    d := byte(B[i]);

    if d=$0d then
    begin
      TempStr[TempLen] := #$0d;
      inc(TempLen);
      if CRSend=IdCRLF then
      begin
        TempStr[TempLen] := #$0a;
        inc(TempLen);
      end
      else if (CRSend=IdCR) and
        TelFlag and not TelBinSend then
      begin
        TempStr[TempLen] := #0;
        inc(TempLen);
      end;
    end
    else begin
      if (Language=IdRussian) and (d>=128) then
        d := RussConv(RussClient,RussHost,d);       
      TempStr[TempLen] := char(d);
      inc(TempLen);
      if TelFlag and (d=$FF) then
      begin
        TempStr[TempLen] := #$FF;
        inc(TempLen);
      end;
    end;

    Full := OutBuffSize-OutBuffCount-TempLen < 0;
    if not Full then
    begin
      inc(i);
      CommRawOut(cv,TempStr,TempLen);
    end;

  end; {end of 'while'}

  CommTextOut := i;

end;
end;

function CommBinaryEcho(cv: PComVar; B: PChar; C: integer): integer; export;
var
  a, i, Len: integer;
  d: array[0..2] of byte;
begin
with cv^ do begin
  if not Ready then
  begin
    CommBinaryEcho := C;
    exit;
  end;

  if (InPtr>0) and (InBuffCount>0) then
  begin
    Move(InBuff[InPtr],InBuff[0],InBuffCount);
    InPtr := 0;
  end;

  i := 0;
  a := 1;
  while (a>0) and (i<C) do
  begin
    Len := 0;

    d[Len] := byte(B[i]);
    inc(Len);

    if TelFlag and (B[i]=#$0D) and
       not TelBinSend then
    begin
      d[Len] := $00;
      inc(Len);
    end;

    if TelFlag and (B[i]=#$ff) then
    begin
      d[Len] := $ff;
      inc(Len);
    end;

    if InBuffSize-InBuffCount-Len >=0 then
    begin
      Move(d[0],InBuff[InBuffCount],Len);
      InBuffCount := InBuffCount + Len;
      a := 1;
    end
    else
      a := 0;
    i := i + a;
  end;
  CommBinaryEcho := i;

end;
end;

function TextEchoJP(cv: PComVar; B: PChar; C: integer): integer;
var
  i, TempLen: integer;
  K: word;
  TempStr: array[0..10] of char;
  EchoCodeNew: integer;
  d: byte;
  Full, KanjiFlagNew: boolean;
begin
with cv^ do begin
  Full := FALSE;
  i := 0;
  while not Full and (i < C) do
  begin
    TempLen := 0;
    d := byte(B[i]);
    EchoCodeNew := EchoCode;

    if EchoKanjiFlag then
    begin
      KanjiFlagNew := FALSE;
      EchoCodeNew := IdKanji;

      K := EchoKanjiFirst shl 8 + d;
      if KanjiCodeEcho = IdEUC then K := SJIS2EUC(K)
      else if KanjiCodeEcho <> IdSJIS then K := SJIS2JIS(K);

      if (EchoCode=IdKatakana) and
         (KanjiCodeEcho=IdJIS) and
         (JIS7KatakanaEcho=1) then
      begin
        TempStr[TempLen] := char(SI);
        inc(TempLen);
      end;

      TempStr[0] := char(Hi(K));
      TempStr[1] := char(Lo(K));
      TempLen := 2;
    end
    else

      if IsDBCSLeadByte(d) then
      begin
        KanjiFlagNew := TRUE;
        EchoKanjiFirst := d;
        EchoCodeNew := IdKanji;

        if (EchoCode<>IdKanji) and
           (KanjiCodeEcho=IdJIS) then
        begin
          TempStr[0] := #$1B;
          TempStr[1] := '$';
          if KanjiIN = IdKanjiInB then
            TempStr[2] := 'B'
          else
            TempStr[2] := '@';
          TempLen := 3;
        end
        else TempLen := 0;

      end
      else begin
        KanjiFlagNew := FALSE;

        if (EchoCode=IdKanji) and
           (KanjiCodeEcho=IdJIS) then
        begin
          TempStr[0] := #$1B;
          TempStr[1] := '(';
          case KanjiOut of
            IdKanjiOutJ: TempStr[2] := 'J';
            IdKanjiOutH: TempStr[2] := 'H';
          else
            TempStr[2] := 'B';
          end;
          TempLen := 3;
        end
        else TempLen := 0;

        if ($A0<d) and (d<$E0) then
        begin
          EchoCodeNew := IdKatakana;
          if (EchoCode<>IdKatakana) and
             (KanjiCodeEcho=IdJIS) and
             (JIS7KatakanaEcho=1) then
          begin
            TempStr[TempLen] := char(SO);
            inc(TempLen);
          end;
        end
        else begin
          EchoCodeNew := IdASCII;
          if (EchoCode=IdKatakana) and
             (KanjiCodeEcho=IdJIS) and
             (JIS7KatakanaEcho=1) then
          begin
            TempStr[TempLen] := char(SI);
            inc(TempLen);
          end;
        end;

        case d of
          $0d: begin
            TempStr[TempLen] := #$0d;
            inc(TempLen);
            if CRSend=IdCRLF then
            begin
              TempStr[TempLen] := #$0a;
              inc(TempLen);
            end
            else if (CRSend=IdCR) and
              TelFlag and not TelBinSend then
            begin
              TempStr[TempLen] := #0;
              inc(TempLen);
            end;

          end;
          $a1..$e0:
          begin {Katakana}
            if KanjiCodeEcho=IdEUC then
            begin
              TempStr[TempLen] := #$8E;
              inc(TempLen);
            end;
            if (KanjiCodeEcho=IdJIS) and
               (JIS7KatakanaEcho=1) then
              TempStr[TempLen] := char(d and $7f)
            else
              TempStr[TempLen] := char(d);
            inc(TempLen);
          end
        else
          begin
            TempStr[TempLen] := char(d);
            inc(TempLen);
            if TelFlag and (d=$FF) then
            begin
              TempStr[TempLen] := #$FF;
              inc(TempLen);
            end;
          end;
        end; {end of 'case of'}

      end; {if ISDBCSLeadByte..then ... else ... end}

    if TempLen = 0 then
    begin
      inc(i);
      EchoCode := EchoCodeNew;
      EchoKanjiFlag := KanjiFlagNew;
    end
    else begin
      Full := InBuffSize-InBuffCount-TempLen < 0;
      if not Full then
      begin
        inc(i);
        EchoCode := EchoCodeNew;
        EchoKanjiFlag := KanjiFlagNew;
        Move(TempStr[0],InBuff[InBuffCount],TempLen);
        InBuffCount := InBuffCount + TempLen;
      end;
    end;

  end; {end of 'while'}

  TextEchoJP := i;
end;
end;

function CommTextEcho(cv: PComVar; B: PChar; C: integer): integer; export;
var
  i, TempLen: integer;
  TempStr: array[0..10] of char;
  d: byte;
  Full: boolean;
begin
with cv^ do begin
  if not Ready then
  begin
    CommTextEcho := C;
    exit;
  end;

  if (InPtr>0) and (InBuffCount>0) then
  begin
    Move(InBuff[InPtr],InBuff[0],InBuffCount);
    InPtr := 0;
  end;

  if Language=IdJapanese then
  begin
    CommTextEcho := TextEchoJP(cv,B,C);
    exit;
  end;

  Full := FALSE;
  i := 0;
  while not Full and (i < C) do
  begin
    TempLen := 0;
    if d=$0d then
    begin
      TempStr[TempLen] := #$0d;
      inc(TempLen);
      if CRSend=IdCRLF then
      begin
        TempStr[TempLen] := #$0a;
        inc(TempLen);
      end
      else if (CRSend=IdCR) and
        TelFlag and not TelBinSend then
      begin
        TempStr[TempLen] := #0;
        inc(TempLen);
      end;
    end
    else begin
      if (Language=IdRussian) and (d>=128) then
        d := RussConv(RussClient,RussHost,d);
      TempStr[TempLen] := char(d);
      inc(TempLen);
      if TelFlag and (d=$FF) then
      begin
        TempStr[TempLen] := #$FF;
        inc(TempLen);
      end;
    end;

    Full := InBuffSize-InBuffCount-TempLen < 0;
    if not Full then
    begin
      inc(i);
      Move(TempStr[0],InBuff[InBuffCount],TempLen);
      InBuffCount := InBuffCount + TempLen;
    end;
  end; {end of while}

  CommTextEcho := i;

end;
end;

exports
  StartTeraTerm    index 1,
  ChangeDefaultSet index 2,
{  LoadDefaultSet   index 3,}
  GetDefaultSet    index 3,
  GetKeyCode       index 4,
  GetKeyStr        index 5,
  
  SetCOMFlag       index 6,
  GetCOMFlag       index 7,

  RegWin           index 10,
  UnregWin         index 11,
  SetWinMenu       index 12,
  SetWinList       index 13,
  SelectWin        index 14,
  SelectNextWin    index 15,
  GetNthWin        index 16,

  CommReadRawByte  index 20,
  CommRead1Byte    index 21,
  CommInsert1Byte  index 22,
  CommRawOut       index 23,
  CommBinaryOut    index 24,
  CommTextOut      index 25,
  CommBinaryEcho   index 26,
  CommTextEcho     index 27,

  SJIS2JIS         index 30,
  SJIS2EUC         index 31,
  JIS2SJIS         index 32,
  RussConv         index 33,
  RussConvStr      index 34;

begin
  FirstInstance := TRUE;
  pm := @map;
end.
