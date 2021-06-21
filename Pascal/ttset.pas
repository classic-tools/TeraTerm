{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTSET.DLL, setup file routines}
library TTSet;
{$i teraterm.inc}

uses WinTypes, WinProcs, WinDos, Strings, TTTypes, Types, TTLib;

const
  Section='Tera Term';

type
  TList = array[0..20] of PChar;
  PList = ^TList;
const
  TermList: array[0..9] of PChar = (
    'VT100','VT100J','VT101','VT102','VT102J','VT220J','VT282','VT320','VT382',nil);

{$ifdef TERATERM32}
  BaudList: array[0..12] of PChar = (
    '110','300','600','1200','2400','4800','9600',
    '14400','19200','38400','57600','115200',nil);
{$else}
  BaudList: array[0..11] of PChar = (
    '110','300','600','1200','2400','4800','9600',
    '14400','19200','38400','57600',nil);
{$endif}

  RussList: array[0..4] of PChar =
    ('Windows','KOI8-R','CP-866','ISO-8859-5',nil);
  RussList2: array[0..2] of PChar =
    ('Windows','KOI8-R',nil);

function str2id(List: PList; str: PCHAR; DefId: WORD): WORD;
var
  i: WORD;
begin
  i := 0;
  while ((List^[i] <> nil) and (stricomp(List^[i],str) <> 0)) do
    inc(i);

  if List^[i] = nil then
    i := DefId
  else
    inc(i);

  str2id := i;
end;

procedure id2str(List: PList; Id, DefId: WORD; str: PCHAR);
var
  i: integer;
begin
  if Id=0 then
    i := DefId - 1
  else begin
    i := 0;
    while ((List^[i] <> nil) and (i < Id-1)) do
      inc(i);
    if List^[i] = nil then
      i := DefId - 1;
  end; 
  strcopy(str,List^[i]);
end;


procedure GetNthString(Source: PChar; Nth, Size: integer; Dest: Pchar);
var
  i, j, k: integer;
  c: Char;
begin
  i := 1;
  j := 0;
  k := 0;
  repeat
    c := Source[j];
    if c=',' then inc(i);
    inc(j);
    if (i=Nth) and (c<>',') and (k<Size-1) then
    begin
      Dest[k] := c;
      inc(k);
    end
  until (i>Nth) or (c=#0);
  Dest[k] := #0;
end;

procedure GetNthNum(Source: PChar; Nth: integer; var Num: integer);
var
  T: array[0..14] of char;
  c: integer;
begin
  GetNthString(Source,Nth,SizeOf(T),@T[0]);
  Val(StrPas(@T[0]),Num,c);
  if c <> 0 then Num := 0;
end;

function GetOnOff(Section, Key, FName: PChar; Default: BOOL): Word;
var
  Temp: array[0..3] of char;
begin
  GetPrivateProfileString(Section,Key,'',
                          Temp,SizeOf(Temp),FName);
  if Default then
  begin
    if StrIComp(Temp,'off')=0 then
      GetOnOff := 0
    else
      GetOnOff := 1;
  end
  else begin
    if StrIComp(Temp,'on')=0 then
      GetOnOff := 1
    else
      GetOnOff := 0;
  end;
end;

procedure WriteOnOff(Section, Key, FName: PChar; Flag: word);
var
  Temp: array[0..3] of char;
begin
  if Flag<>0 then StrCopy(Temp,'on')
             else StrCopy(Temp,'off');
  WritePrivateProfileString(Section,Key,Temp,FName);
end;

procedure AddInt(Temp: PChar; i: integer; Comma: bool);
var
  NumStr: string[15];
begin
  Str(i,NumStr);
  StrPCopy(Temp,NumStr);
  if Comma then
    StrCat(Temp,',');
end;

procedure WriteInt(Sect, Key, FName: PChar; i: integer);
var
  Temp: array[0..14] of char;
begin
  AddInt(Temp,i,FALSE);
  WritePrivateProfileString(Sect,Key,Temp,FName);
end;

procedure WriteUint(Sect, Key, FName: PChar; i: uint);
var
  NumStr: string[15];
  Temp: array[0..14] of char;
begin
  Str(i,NumStr);
  StrPCopy(Temp,NumStr);
  WritePrivateProfileString(Sect,Key,Temp,FName);
end;

procedure WriteInt2(Sect, Key, FName: PChar; i1, i2: integer);
var
  Temp: array[0..31] of char;
begin
  AddInt(Temp,i1,TRUE);
  AddInt(@Temp[strlen(Temp)],i2,FALSE);
  WritePrivateProfileString(Sect,Key,Temp,FName);
end;

procedure WriteInt4(Sect, Key, FName: PChar;
  i1, i2, i3, i4: integer);
var
  Temp: array[0..63] of char;
begin
  AddInt(Temp,i1,TRUE);
  AddInt(@Temp[strlen(Temp)],i2,TRUE);
  AddInt(@Temp[strlen(Temp)],i3,TRUE);
  AddInt(@Temp[strlen(Temp)],i4,FALSE);
  WritePrivateProfileString(Sect,Key,Temp,FName);
end;

procedure WriteInt6(Sect, Key, FName: PChar;
  i1, i2, i3, i4, i5, i6: integer);
var
  Temp: array[0..95] of char;
begin
  AddInt(Temp,i1,TRUE);
  AddInt(@Temp[strlen(Temp)],i2,TRUE);
  AddInt(@Temp[strlen(Temp)],i3,TRUE);
  AddInt(@Temp[strlen(Temp)],i4,TRUE);
  AddInt(@Temp[strlen(Temp)],i5,TRUE);
  AddInt(@Temp[strlen(Temp)],i6,FALSE);
  WritePrivateProfileString(Sect,Key,Temp,FName);
end;

procedure WriteFont(Sect, Key, FName, Name: PChar;
  x, y, charset: integer);
var
  Temp: array[0..79] of char;
begin
  if Name[0]<>#0 then
  begin
    strcopy(Temp,Name);
    strcat(Temp,',');
    AddInt(@Temp[strlen(Temp)],x,TRUE);
    AddInt(@Temp[strlen(Temp)],y,TRUE);
    AddInt(@Temp[strlen(Temp)],charset,FALSE);
  end
  else
    Temp[0] := #0;
  WritePrivateProfileString(Sect,Key,Temp,FName);
end;

procedure ReadIniFile(FName: PChar; ts: PTTSet); export;
var
  i: integer;
  TmpDC: HDC;
  Temp: array[0..MAXPATHLEN-1] of char;
begin
  ts^.Minimize := 0;
  ts^.HideWindow := 0;
  ts^.LogFlag := 0; {Log flags}
  ts^.FTFlag := 0;  {File transfer flags}
  ts^.MenuFlag := 0; {Menu flags}
  ts^.TermFlag := 0; {Terminal flag}
  ts^.ColorFlag := 0; {ANSI color flags}
  ts^.PortFlag := 0; {Port flags}
  ts^.TelPort := 23;

  {Version number}
  {GetPrivateProfileString(Section,'Version','',
                          Temp,SizeOf(Temp),FName);}

  {Language}
  GetPrivateProfileString(Section,'Language','',
                          Temp,SizeOf(Temp),FName);
  if StrIComp(Temp,'Japanese')=0 then
    ts^.Language := IdJapanese
  else if StrIComp(Temp,'Russian')=0  then
    ts^.Language := IdRussian
  else if StrIComp(Temp,'English')=0 then
    ts^.Language := IdEnglish
  else begin
{$ifdef TERATERM32}
    case PRIMARYLANGID(GetSystemDefaultLangID) of
      LANG_JAPANESE: ts^.Language := IdJapanese;
      LANG_RUSSIAN: ts^.Language := IdRussian;
    else
      ts^.Language := IdEnglish;
    end;
{$else}
    case GetKBCodePage of
      932: {Japanese}
        ts^.Language := IdJapanese;
      1251: {Windows 3.1 Cyrillic}
        ts^.Language := IdRussian;
    else
      ts^.Language := IdEnglish;
    end;
{$endif}
  end;

  {Port type}
  GetPrivateProfileString(Section,'Port','',
                          Temp,SizeOf(Temp),FName);
  if StrIComp(Temp,'tcpip')=0 then
    ts^.PortType := IdTCPIP
  else if StrIComp(Temp,'serial')=0 then
    ts^.PortType := IdSerial
  else
    ts^.PortType := IdTCPIP;

  {VT win position}
  GetPrivateProfileString(Section,'VTPos','-32768,-32768',
                          Temp,SizeOf(Temp),FName);  {default: random position}
  GetNthNum(Temp,1,ts^.VTPos.x);
  GetNthNum(Temp,2,ts^.VTPos.y);

  if (ts^.VTPos.x < -20) or (ts^.VTPos.y < -20) then
  begin
    ts^.VTPos.x := CW_USEDEFAULT;
    ts^.VTPos.y := CW_USEDEFAULT;
  end
  else begin
    if ts^.VTPos.x < 0 then ts^.VTPos.x := 0;
    if ts^.VTPos.y < 0 then ts^.VTPos.y := 0;
  end;

  {TEK win position}
  GetPrivateProfileString(Section,'TEKPos','-32768,-32768',
                          Temp,SizeOf(Temp),FName);  {default: random position}
  GetNthNum(Temp,1,ts^.TEKPos.x);
  GetNthNum(Temp,2,ts^.TEKPos.y);

  if (ts^.TEKPos.x < -20) or (ts^.TEKPos.y < -20) then
  begin
    ts^.TEKPos.x := CW_USEDEFAULT;
    ts^.TEKPos.y := CW_USEDEFAULT;
  end
  else begin
    if ts^.TEKPos.x < 0 then ts^.TEKPos.x := 0;
    if ts^.TEKPos.y < 0 then ts^.TEKPos.y := 0;
  end;

  {VT terminal size }
  GetPrivateProfileString(Section,'TerminalSize','80,24',
                          Temp,SizeOf(Temp),FName);
  GetNthNum(Temp,1,ts^.TerminalWidth);
  GetNthNum(Temp,2,ts^.TerminalHeight);
  if ts^.TerminalWidth < 0 then ts^.TerminalWidth := 1;
  if ts^.TerminalHeight < 0 then ts^.TerminalHeight := 1;

  {Terminal size = Window size}
  ts^.TermIsWin := GetOnOff(Section,'TermIsWin',FName,FALSE);

  {Auto window resize flag}
  ts^.AutoWinResize := GetOnOff(Section,'AutoWinResize',FName,FALSE);

  {CR Receive}
  GetPrivateProfileString(Section,'CRReceive','',
                          Temp,SizeOf(Temp),FName);
  if StrIComp(Temp,'CRLF')=0 then ts^.CRReceive := IdCRLF
                             else ts^.CRReceive := IDCR;
  {CR Send}
  GetPrivateProfileString(Section,'CRSend','',
                          Temp,SizeOf(Temp),FName);
  if StrIComp(Temp,'CRLF')=0 then ts^.CRSend := IdCRLF
                             else ts^.CRSend := IdCR;

  {Local echo}
  ts^.LocalEcho := GetOnOff(Section,'LocalEcho',FName,FALSE);


  {Answerback}
  GetPrivateProfileString(Section,'Answerback','',Temp,
                          SizeOf(Temp),Fname);
  ts^.AnswerbackLen :=
    Hex2Str(Temp,ts^.Answerback,SizeOf(ts^.Answerback));

  {Kanji Code (receive)}
  GetPrivateProfileString(Section,'KanjiReceive','',
                          Temp,SizeOf(Temp),FName);
  if      StrIComp(Temp,'EUC')=0 then ts^.KanjiCode := IdEUC
  else if StrIComp(Temp,'JIS')=0 then ts^.KanjiCode := IdJIS
  else ts^.KanjiCode := IdSJIS;

  {Katakana (receive)}
  GetPrivateProfileString(Section,'KatakanaReceive','',
                          Temp,SizeOf(Temp),FName);
  if      StrIComp(Temp,'7')=0 then ts^.JIS7Katakana := 1
  else ts^.JIS7Katakana := 0;

  {Kanji Code (transmit)}
  GetPrivateProfileString(Section,'KanjiSend','',
                          Temp,SizeOf(Temp),FName);
  if      StrIComp(Temp,'EUC')=0 then ts^.KanjiCodeSend := IdEUC
  else if StrIComp(Temp,'JIS')=0 then ts^.KanjiCodeSend := IdJIS
  else ts^.KanjiCodeSend := IdSJIS;

  {Katakana (receive)}
  GetPrivateProfileString(Section,'KatakanaSend','',
                          Temp,SizeOf(Temp),FName);
  if      StrIComp(Temp,'7')=0 then ts^.JIS7KatakanaSend := 1
  else ts^.JIS7KatakanaSend := 0;

  {KanjiIn}
  GetPrivateProfileString(Section,'KanjiIn','',
                          Temp,SizeOf(Temp),FName);
  if StrIComp(Temp,'@')=0 then ts^.KanjiIn := IdKanjiInA
  else ts^.KanjiIn := IdKanjiInB;

  {KanjiOut}
  GetPrivateProfileString(Section,'KanjiOut','',
                          Temp,SizeOf(Temp),FName);
  if      StrIComp(Temp,'B')=0 then
    ts^.KanjiOut := IdKanjiOutB
  else if StrIComp(Temp,'H')=0 then
    ts^.KanjiOut := IdKanjiOutH
  else
    ts^.KanjiOut := IdKanjiOutJ;

  {Auto Win Switch VT<->TEK}
  ts^.AutoWinSwitch := GetOnOff(Section,'AutoWinSwitch',FName,FALSE);

  {Terminal ID}
  GetPrivateProfileString(Section,'TerminalID','',
                          Temp,sizeof(Temp),FName);
  ts^.TerminalID := str2id(@TermList,Temp,IdVT100);

  {Russian character set (host)}
  GetPrivateProfileString(Section,'RussHost','',
                          Temp,sizeof(Temp),FName);
  ts^.RussHost := str2id(@RussList,Temp,IdKOI8);

  {Russian character set (client)}
  GetPrivateProfileString(Section,'RussClient','',
                          Temp,sizeof(Temp),FName);
  ts^.RussClient := str2id(@RussList,Temp,IdWindows);

  {Title String}
  GetPrivateProfileString(Section,'Title','Tera Term',
                          ts^.Title,SizeOf(ts^.Title),FName);

  {Cursor shape}
  GetPrivateProfileString(Section,'CursorShape','',
                          Temp,SizeOf(Temp),FName);
       if StrIComp(Temp,'vertical'  )=0 then ts^.CursorShape := IdVCur
  else if StrIComp(Temp,'horizontal')=0 then ts^.CursorShape := IdHCur
  else ts^.CursorShape := IdBlkCur;

  {Hide title}
  ts^.HideTitle := GetOnOff(Section,'HideTitle',FName,FALSE);

  {Popup menu}
  ts^.PopupMenu := GetOnOff(Section,'PopupMenu',FName,FALSE);

  {Full color}
  ts^.ColorFlag := ts^.ColorFlag or 
    CF_FULLCOLOR * GetOnOff(Section,'FullColor',FName,FALSE);

  {Enable scroll buffer}
  ts^.EnableScrollBuff :=
    GetOnOff(Section,'EnableScrollBuff',FName,TRUE);

  {Scroll buffer size}
  ts^.ScrollBuffSize :=
    GetPrivateProfileInt(Section,'ScrollBuffSize',100,FName);

  {VT Color}
  GetPrivateProfileString(Section,'VTColor','0,0,0,255,255,255',
                          Temp,SizeOf(Temp),FName);
  for i := 0 to 5 do
    GetNthNum(Temp,i+1,integer(ts^.TmpColor[0,i]));
  for i := 0 to 1 do
    ts^.VTColor[i] := RGB(ts^.TmpColor[0,i*3],
                              ts^.TmpColor[0,i*3+1],
                              ts^.TmpColor[0,i*3+2]);

  {VT Bold Color}
  GetPrivateProfileString(Section,'VTBoldColor','0,0,255,255,255,255',
                          Temp,SizeOf(Temp),FName);
  for i := 0 to 5 do
    GetNthNum(Temp,i+1,integer(ts^.TmpColor[0,i]));
  for i := 0 to 1 do
    ts^.VTBoldColor[i] := RGB(ts^.TmpColor[0,i*3],
                              ts^.TmpColor[0,i*3+1],
                              ts^.TmpColor[0,i*3+2]);

  {VT Blink Color}
  GetPrivateProfileString(Section,'VTBlinkColor','255,0,0,255,255,255',
                          Temp,SizeOf(Temp),FName);
  for i := 0 to 5 do
    GetNthNum(Temp,i+1,integer(ts^.TmpColor[0,i]));
  for i := 0 to 1 do
    ts^.VTBlinkColor[i] := RGB(ts^.TmpColor[0,i*3],
                              ts^.TmpColor[0,i*3+1],
                              ts^.TmpColor[0,i*3+2]);

  {TEK Color}
  GetPrivateProfileString(Section,'TEKColor','0,0,0,255,255,255',
                          Temp,SizeOf(Temp),FName);
  for i := 0 to 5 do
    GetNthNum(Temp,i+1,integer(ts^.TmpColor[0,i]));
  for i := 0 to 1 do
    ts^.TEKColor[i] := RGB(ts^.TmpColor[0,i*3],
                               ts^.TmpColor[0,i*3+1],
                               ts^.TmpColor[0,i*3+2]);

  TmpDC := GetDC(0); {Get screen device context}
  for i := 0 to 1 do
    ts^.VTColor[i] := GetNearestColor(TmpDC, ts^.VTColor[i]);
  for i := 0 to 1 do
    ts^.VTBoldColor[i] := GetNearestColor(TmpDC, ts^.VTBoldColor[i]);
  for i := 0 to 1 do
    ts^.VTBlinkColor[i] := GetNearestColor(TmpDC, ts^.VTBlinkColor[i]);
  for i := 0 to 1 do
    ts^.TEKColor[i] := GetNearestColor(TmpDC, ts^.TEKColor[i]);
  ReleaseDC(0, TmpDC);

  {TEK color emulation}
  ts^.TEKColorEmu :=
    GetOnOff(Section,'TEKColorEmulation',FName,FALSE);

  {VT Font}
  GetPrivateProfileString(Section,'VTFont','Terminal,0,-13,1',
                          Temp,SizeOf(Temp),FName);
  GetNthString(Temp,1,SizeOf(ts^.VTFont),ts^.VTFont);
  GetNthNum(Temp,2,ts^.VTFontSize.x);
  GetNthNum(Temp,3,ts^.VTFontSize.y);
  GetNthNum(Temp,4,ts^.VTFontCharSet);

  {Bold font flag}
  ts^.EnableBold := GetOnOff(Section,'EnableBold',FName,FALSE);

  {Russian character set (font)}
  GetPrivateProfileString(Section,'RussFont','',
			  Temp,sizeof(Temp),FName);
  ts^.RussFont := str2id(@RussList,Temp,IdWindows);

  {TEK Font}
  GetPrivateProfileString(Section,'TEKFont','Courier,0,-13,0',
                          Temp,SizeOf(Temp),FName);
  GetNthString(Temp,1,SizeOf(ts^.TEKFont),ts^.TEKFont);
  GetNthNum(Temp,2,ts^.TEKFontSize.x);
  GetNthNum(Temp,3,ts^.TEKFontSize.y);
  GetNthNum(Temp,4,ts^.TEKFontCharSet);

  {BS key}
  GetPrivateProfileString(Section,'BSKey','',
                          Temp,SizeOf(Temp),FName);
  if StrIComp(Temp,'DEL')=0 then ts^.BSKey := IdDEL
                            else ts^.BSKey := IdBS;

  {Delete key}
  ts^.DelKey := GetOnOff(Section,'DeleteKey',FName,FALSE);

  {Meta Key}
  ts^.MetaKey := GetOnOff(Section,'MetaKey',FName,FALSE);

  {Russian keyboard type}
  GetPrivateProfileString(Section,'RussKeyb','',
                          Temp,sizeof(Temp),FName);
  ts^.RussKeyb := str2id(@RussList2,Temp,IdWindows);

  {Serial port ID}
  ts^.ComPort :=
    GetPrivateProfileInt(Section,'ComPort',1,FName);

  {Baud rate}
  GetPrivateProfileString(Section,'BaudRate','',
                          Temp,sizeof(Temp),FName);
  ts^.Baud := str2id(@BaudList,Temp,IdBaud9600);

  {Parity}
  GetPrivateProfileString(Section,'Parity','',
                          Temp,SizeOf(Temp),FName);
  if      StrIComp(Temp,'even')=0 then ts^.Parity := IdParityEven
  else if StrIComp(Temp,'odd' )=0 then ts^.Parity := IdParityOdd
  else ts^.Parity := IdParityNone;

  {Data bit}
  GetPrivateProfileString(Section,'DataBit','',
                          Temp,SizeOf(Temp),FName);
  if StrIComp(Temp,'7')=0 then ts^.DataBit := IdDataBit7
  else ts^.DataBit := IdDataBit8;

  {Stop bit}
  GetPrivateProfileString(Section,'StopBit','',
                          Temp,SizeOf(Temp),FName);
  if StrIComp(Temp,'2')=0 then ts^.StopBit := IdStopBit2
  else ts^.StopBit := IdStopBit1;

  {Flow control}
  GetPrivateProfileString(Section,'FlowCtrl','',
                          Temp,SizeOf(Temp),FName);
  if      StrIComp(Temp,'x'   )=0 then ts^.Flow := IdFlowX
  else if StrIComp(Temp,'hard')=0 then ts^.Flow := IdFlowHard
  else ts^.Flow := IdFlowNone;

  {Delay per character}
  ts^.DelayPerChar :=
    GetPrivateProfileInt(Section,'DelayPerChar',0,FName);

  {Delay per line}
  ts^.DelayPerLine :=
    GetPrivateProfileInt(Section,'DelayPerLine',0,FName);

  {Telnet flag}
  ts^.Telnet := GetOnOff(Section,'Telnet',FName,TRUE);

  {Telnet terminal type}
  GetPrivateProfileString(Section,'TermType','vt100',ts^.TermType,
                          SizeOf(ts^.TermType),FName);

  {TCP port num}
  ts^.TCPPort :=
    GetPrivateProfileInt(Section,'TCPPort',ts^.TelPort,FName);

  {Auto window close flag}
  ts^.AutoWinClose := GetOnOff(Section,'AutoWinClose',FName,TRUE);

  {History list}
  ts^.HistoryList := GetOnOff(Section,'HistoryList',FName,FALSE);

  {File transfer binary flag}
  ts^.TransBin := GetOnOff(Section,'TransBin',FName,FALSE);

  {Log append}
  ts^.Append := GetOnOff(Section,'LogAppend',FName,FALSE);

  {XMODEM option}
  GetPrivateProfileString(Section,'XmodemOpt','',
                          Temp,SizeOf(Temp),FName);
  if      StrIComp(Temp,'crc'   )=0 then ts^.XmodemOpt := XoptCRC
  else if StrIComp(Temp,'1k')=0 then ts^.XmodemOpt := Xopt1K
  else ts^.XmodemOpt := XoptCheck;

  {XMODEM binary file}
  ts^.XmodemBin := GetOnOff(Section,'XmodemBin',FName,TRUE);

  {Default directory for file transfer}
  GetPrivateProfileString(Section,'FileDir','',
                          ts^.FileDir,SizeOf(ts^.FileDir),FName);
  StrUpper(ts^.FileDir);
  if StrLen(ts^.FileDir)=0 then
    StrCopy(ts^.FileDir,ts^.HomeDir)
  else begin
    GetCurDir(Temp,0);
    SetCurDir(ts^.FileDir);
    if DosError>0 then
      StrCopy(ts^.FileDir,ts^.HomeDir);
    SetCurDir(Temp);
  end;

  {8 bit control code flag  -- special option}
  ts^.TermFlag := ts^.TermFlag or
    TF_ACCEPT8BITCTRL *
    GetOnOff(Section,'Accept8bitCtrl',FName,TRUE);

  {Wrong sequence flag  -- special option}
  ts^.TermFlag := ts^.TermFlag or
    TF_ALLOWWRONGSEQUENCE *
    GetOnOff(Section,'AllowWrongSequence',FName,FALSE);
  if (ts^.TermFlag and TF_ALLOWWRONGSEQUENCE=0) and
     (ts^.KanjiOut=IdKanjiOutH) then
    ts^.KanjiOut := IdKanjiOutJ;

  {Auto text copy -- special option}
  ts^.FTFlag := ts^.FTFlag or
    FT_RENAME * GetOnOff(Section,'AutoFileRename',FName,FALSE);

  {Auto invoking (character set->G0->GL) -- special option}
  ts^.TermFlag := ts^.TermFlag or
    TF_AUTOINVOKE * GetOnOff(Section,'AutoInvoke',FName,FALSE);

  {Auto text copy -- special option}
  ts^.AutoTextCopy := GetOnOff(Section,'AutoTextCopy',FName,TRUE);

  {Back wrap -- special option}
  ts^.TermFlag := ts^.TermFlag or
    TF_BACKWRAP * GetOnOff(Section,'BackWrap',FName,FALSE);

  {Beep type -- special option}
  ts^.Beep := GetOnOff(Section,'Beep',FName,TRUE);

  {Beep on connection & disconnection -- special option}
  ts^.PortFlag := ts^.PortFlag or
    PF_BEEPONCONNECT * GetOnOff(Section,'BeepOnConnect',FName,FALSE);

  {Auto B-Plus activation -- special option}
  ts^.FTFlag := ts^.FTFlag or
    FT_BPAUTO * GetOnOff(Section,'BPAuto',FName,FALSE);
  if ts^.FTFlag and FT_BPAUTO <> 0 then
  begin {Answerback}
    StrCopy(ts^.Answerback,#$10'++'#$10'0');
    ts^.AnswerbackLen := 5;
  end;

  {B-Plus ESCCTL flag -- special option}
  ts^.FTFlag := ts^.FTFlag or
    FT_BPESCCTL * GetOnOff(Section,'BPEscCtl',FName,FALSE);

  {B-Plus log  -- special option}
  ts^.LogFlag := ts^.LogFlag or
    LOG_BP * GetOnOff(Section,'BPLog',FName,FALSE);

  {Confirm disconnect -- special option}
  ts^.PortFlag := ts^.PortFlag or
    PF_CONFIRMDISCONN * GetOnOff(Section,'ConfirmDisconnect',FName,TRUE);

  {Ctrl code in Kanji -- special option}
  ts^.TermFlag := ts^.TermFlag or
    TF_CTRLINKANJI * GetOnOff(Section,'CtrlInKanji',FName,TRUE);

  {Debug flag  -- special option}
  ts^.Debug := GetOnOff(Section,'Debug',FName,FALSE);

  {Delimiter list -- special option}
  GetPrivateProfileString(Section,'DelimList',
	  '$20!"#$24%&''()*+,-./:;<=>?@[\]^`{|}~',
	  Temp,sizeof(Temp),FName);
  Hex2Str(Temp,ts^.DelimList,sizeof(ts^.DelimList));

  {regard DBCS characters as delimiters -- special option}
  ts^.DelimDBCS := GetOnOff(Section,'DelimDBCS',FName,TRUE);

  {Enable popup menu -- special option}
  if GetOnOff(Section,'EnablePopupMenu',FName,TRUE)=0 then
    ts^.MenuFlag := ts^.MenuFlag or MF_NOPOPUP;

  {Enable "Show menu" -- special option}
  if GetOnOff(Section,'EnableShowMenu',FName,TRUE)=0 then
    ts^.MenuFlag := ts^.MenuFlag or MF_NOSHOWMENU;

  {Enable the status line -- special option}
  ts^.TermFlag := ts^.TermFlag or
    TF_ENABLESLINE * GetOnOff(Section,'EnableStatusLine',FName,TRUE);

  ts^.TermFlag := ts^.TermFlag or
    TF_FIXEDJIS * GetOnOff(Section,'FixedJIS',FName,FALSE);

  {IME Flag -- special option}
  ts^.UseIME := GetOnOff(Section,'IME',FName,TRUE);

  {IME Flag -- special option}
  ts^.IMEInline := GetOnOff(Section,'IMEInline',FName,TRUE);

  {Kermit log  -- special option}
  ts^.LogFlag := ts^.LogFlag or
    LOG_KMT * GetOnOff(Section,'KmtLog',FName,FALSE);

  {Enable language selection -- special option}
  if GetOnOff(Section,'LanguageSelection',FName,TRUE)=0 then
    ts^.MenuFlag := ts^.MenuFlag or MF_NOLANGUAGE;

  {Maximum scroll buffer size -- special option}
{$ifdef TERATERM32}
  ts^.ScrollBuffMax :=
    GetPrivateProfileInt(Section,'MaxBuffSize',10000,FName);
  if ts^.ScrollBuffMax < 24 then
    ts^.ScrollBuffMax := 10000;
{$else}
  ts^.ScrollBuffMax :=
    GetPrivateProfileInt(Section,'MaxBuffSize',800,FName);
  if ts^.ScrollBuffMax < 24 then
    ts^.ScrollBuffMax := 800;
{$endif}

  {Max com port number -- special option}
  ts^.MaxComPort :=
    GetPrivateProfileInt(Section,'MaxComPort',4,FName);
  if ts^.MaxComPort < 4 then ts^.MaxComPort := 4;
  if ts^.MaxComPort > 16 then ts^.MaxComPort := 16;
  if (ts^.ComPort<1) or (ts^.ComPort>ts^.MaxComPort) then
    ts^.ComPort := 1;

  {Non-blinking cursor -- special option}
  ts^.NonblinkingCursor := GetOnOff(Section,'NonblinkingCursor',FName,FALSE);

  { Delay for pass-thru printing activation }
  {   -- special option }
  ts^.PassThruDelay :=
    GetPrivateProfileInt(Section,'PassThruDelay',3,FName);

  { Printer port for pass-thru printing }
  {   -- special option }
  GetPrivateProfileString(Section,'PassThruPort','',
    ts^.PrnDev,sizeof(ts^.PrnDev),FName);

  {Printer Font --- special option}
  GetPrivateProfileString(Section,'PrnFont','',
                          Temp,SizeOf(Temp),FName);
  if StrLen(Temp)=0 then
  begin
    ts^.PrnFont[0] := #0;
    ts^.PrnFontSize.X := 0;
    ts^.PrnFontSize.Y := 0;
    ts^.PrnFontCharSet := 0;
  end
  else begin
    GetNthString(Temp,1,SizeOf(ts^.PrnFont),ts^.PrnFont);
    GetNthNum(Temp,2,ts^.PrnFontSize.x);
    GetNthNum(Temp,3,ts^.PrnFontSize.y);
    GetNthNum(Temp,4,ts^.PrnFontCharSet);
  end;

  {Page margins (left, right, top, bottom) for printing
  	-- special option}
  GetPrivateProfileString(Section,'PrnMargin','50,50,50,50',
                          Temp,sizeof(Temp),FName);
  for i := 0 to 3 do
    GetNthNum(Temp,1+i,ts^.PrnMargin[i]);

  {Quick-VAN log  -- special option}
  ts^.LogFlag := ts^.LogFlag or
    LOG_QV * GetOnOff(Section,'QVLog',FName,FALSE);

  {Quick-VAN window size -- special}
  ts^.QVWinSize :=
    GetPrivateProfileInt(Section,'QVWinSize',8,FName);

  {Russian character set (print) -- special option }
  GetPrivateProfileString(Section,'RussPrint','',
                          Temp,sizeof(Temp),FName);
  ts^.RussPrint := str2id(@RussList,Temp,IdWindows);

  {Scroll threshold -- special option}
  ts^.ScrollThreshold :=
    GetPrivateProfileInt(Section,'ScrollThreshold',12,FName);

  {Select on activate -- special option}
  ts^.SelOnActive := GetOnOff(Section,'SelectOnActivate',FName,TRUE);

  {Startup macro -- special option}
  GetPrivateProfileString(Section,'StartupMacro','',
                          ts^.MacroFN,sizeof(ts^.MacroFN),FName);

  {TEK GIN Mouse keycode -- special option}
  ts^.GINMouseCode :=
    GetPrivateProfileInt(Section,'TEKGINMouseCode',32,FName);

  {Telnet binary flag -- special option}
  ts^.TelBin := GetOnOff(Section,'TelBin',FName,FALSE);

  {Telnet Echo flag -- special option}
  ts^.TelEcho := GetOnOff(Section,'TelEcho',FName,FALSE);

  {Telnet log  -- special option}
  ts^.LogFlag := ts^.LogFlag or
    LOG_TEL * GetOnOff(Section,'TelLog',FName,FALSE);

  {TCP port num for telnet -- special option }
  ts^.TelPort :=
    GetPrivateProfileInt(Section,'TelPort',23,FName);

  {Local echo for non-telnet}
  ts^.TCPLocalEcho := GetOnOff(Section,'TCPLocalEcho',FName,FALSE);

  {"new-line (transmit)" option for non-telnet -- special option }
  GetPrivateProfileString(Section,'TCPCRSend','',
                          Temp,sizeof(Temp),FName);
  if stricomp(Temp,'CR')=0 then
    ts^.TCPCRSend := IdCR
  else if stricomp(Temp,'CRLF')=0 then
    ts^.TCPCRSend := IdCRLF
  else
    ts^.TCPCRSend := 0; {disabled}

  {Use text (background) color for "white (black)"
      --- special option}
  ts^.ColorFlag := ts^.ColorFlag or
    CF_USETEXTCOLOR * GetOnOff(Section,'UseTextColor',FName,FALSE);

  { Title format -- special option }
  ts^.TitleFormat :=
    GetPrivateProfileInt(Section,'TitleFormat',5,FName);

  {VT Font space --- special option}
  GetPrivateProfileString(Section,'VTFontSpace','0,0,0,0',
                          Temp,SizeOf(Temp),FName);
  GetNthNum(Temp,1,ts^.FontDX);
  GetNthNum(Temp,2,ts^.FontDW);
  GetNthNum(Temp,3,ts^.FontDY);
  GetNthNum(Temp,4,ts^.FontDH);
  if ts^.FontDX<0 then
    ts^.FontDX := 0;
  if ts^.FontDW<0 then
    ts^.FontDW := 0;
  ts^.FontDW := ts^.FontDW +
                   ts^.FontDX;
  if ts^.FontDY<0 then
    ts^.FontDY := 0;
  if ts^.FontDH<0 then
    ts^.FontDH := 0;
  ts^.FontDH := ts^.FontDH +
                   ts^.FontDY;

  {VT-print scaling factors (pixels per inch) --- special option}
  GetPrivateProfileString(Section,'VTPPI','0,0',
                          Temp,sizeof(Temp),FName);
  GetNthNum(Temp,1,ts^.VTPPI.x);
  GetNthNum(Temp,2,ts^.VTPPI.y);

  {TEK-print scaling factors (pixels per inch) --- special option}
  GetPrivateProfileString(Section,'TEKPPI','0,0',
                          Temp,sizeof(Temp),FName);
  GetNthNum(Temp,1,ts^.TEKPPI.x);
  GetNthNum(Temp,2,ts^.TEKPPI.y);

  {Show "Window" menu -- special option}
  ts^.MenuFlag := ts^.MenuFlag or
    MF_SHOWWINMENU * GetOnOff(Section,'WindowMenu',FName,TRUE);

  {XMODEM log  -- special option}
  ts^.LogFlag := ts^.LogFlag or
    LOG_X * GetOnOff(Section,'XmodemLog',FName,FALSE);

  {Auto ZMODEM activation -- special option}
  ts^.FTFlag := ts^.FTFlag or
    FT_ZAUTO * GetOnOff(Section,'ZmodemAuto',FName,FALSE);

  {ZMODEM data subpacket length for sending -- special}
  ts^.ZmodemDataLen :=
    GetPrivateProfileInt(Section,'ZmodemDataLen',1024,FName);
  {ZMODEM window size for sending -- special}
  ts^.ZmodemWinSize :=
    GetPrivateProfileInt(Section,'ZmodemWinSize',32767,FName);

  {ZMODEM ESCCTL flag  -- special option}
  ts^.FTFlag := ts^.FTFlag or
    FT_ZESCCTL * GetOnOff(Section,'ZmodemEscCtl',FName,FALSE);

  {ZMODEM log  -- special option}
  ts^.LogFlag := ts^.LogFlag or
    LOG_Z * GetOnOff(Section,'ZmodemLog',FName,FALSE);
end;

procedure WriteIniFile(FName: PChar; ts: PTTSet); export;
var
  i: integer;
  Temp: array[0..80] of char;
begin
  {version}
{$ifdef TERATERM32}
  WritePrivateProfileString(Section,'Version','2.3',FName);
{$else}
  WritePrivateProfileString(Section,'Version','1.4',FName);
{$endif}

  {Language}
  if ts^.Language=IdJapanese then
    strcopy(Temp,'Japanese')
  else if ts^.Language=IdRussian then
    strcopy(Temp,'Russian')
  else
    strcopy(Temp,'English');
  WritePrivateProfileString(Section,'Language',Temp,FName);

  {Port type}
  case ts^.PortType of
    IdSerial: StrCopy(Temp,'serial')
  else {IdFile -> IdTCPIP}
    StrCopy(Temp,'tcpip');
  end;
  WritePrivateProfileString(Section,'Port',Temp,FName);

  {VT win position}
  WriteInt2(Section,'VTPos',FName,
    ts^.VTPos.x,ts^.VTPos.y);

  {TEK win position}
  WriteInt2(Section,'TEKPos',FName,
    ts^.TEKPos.x,ts^.TEKPos.y);

  {VT terminal size }
  WriteInt2(Section,'TerminalSize',FName,
    ts^.TerminalWidth,ts^.TerminalHeight);

  {Terminal size = Window size}
  WriteOnOff(Section,'TermIsWin',FName,ts^.TermIsWin);

  {Auto window resize flag}
  WriteOnOff(Section,'AutoWinResize',FName,ts^.AutoWinResize);

  {CR Receive}
  if ts^.CRReceive = IdCRLF then StrCopy(Temp,'CRLF')
                                 else StrCopy(Temp,'CR');
  WritePrivateProfileString(Section,'CRReceive',Temp,FName);

  {CR Send}
  if ts^.CRSend = IdCRLF then StrCopy(Temp,'CRLF')
                              else StrCopy(Temp,'CR');
  WritePrivateProfileString(Section,'CRSend',Temp,FName);

  {Local echo}
  WriteOnOff(Section,'LocalEcho',FName,ts^.LocalEcho);

  {Answerback}
  if ts^.FTFlag and FT_BPAUTO = 0 then
  begin
    Str2Hex(ts^.Answerback,Temp,ts^.AnswerbackLen,
            SizeOf(Temp)-1,TRUE);
    WritePrivateProfileString(Section,'Answerback',Temp,FName);
  end;

  {Kanji Code (receive) }
  case ts^.KanjiCode of
    IdEUC: StrCopy(Temp,'EUC');
    IdJIS: StrCopy(Temp,'JIS');
  else
    StrCopy(Temp,'SJIS');
  end;
  WritePrivateProfileString(Section,'KanjiReceive',Temp,FName);

  {Katakana (receive) }
  case ts^.JIS7Katakana of
    1: StrCopy(Temp,'7');
  else
    StrCopy(Temp,'8');
  end;
  WritePrivateProfileString(Section,'KatakanaReceive',Temp,FName);

  {Kanji Code (transmit) }
  case ts^.KanjiCodeSend of
    IdEUC: StrCopy(Temp,'EUC');
    IdJIS: StrCopy(Temp,'JIS');
  else
    StrCopy(Temp,'SJIS');
  end;
  WritePrivateProfileString(Section,'KanjiSend',Temp,FName);

  {Katakana (transmit) }
  case ts^.JIS7KatakanaSend of
    1: StrCopy(Temp,'7');
  else
    StrCopy(Temp,'8');
  end;
  WritePrivateProfileString(Section,'KatakanaSend',Temp,FName);

  {KanjiIn}
  case ts^.KanjiIn of
    IdKanjiInA: StrCopy(Temp,'@');
  else
    StrCopy(Temp,'B');
  end;
  WritePrivateProfileString(Section,'KanjiIn',Temp,FName);

  {KanjiOut}
  case ts^.KanjiOut of
    IdKanjiOutB: StrCopy(Temp,'B');
    IdKanjiOutH: StrCopy(Temp,'H');
  else
    StrCopy(Temp,'J');
  end;
  WritePrivateProfileString(Section,'KanjiOut',Temp,FName);

  {AutoWinChange VT<->TEK}
  WriteOnOff(Section,'AutoWinSwitch',FName,ts^.AutoWinSwitch);

  {Terminal ID}
  id2str(@TermList,ts^.TerminalID,IdVT100,Temp);
  WritePrivateProfileString(Section,'TerminalID',Temp,FName);

  {Russian character set (host)}
  id2str(@RussList,ts^.RussHost,IdKOI8,Temp);
  WritePrivateProfileString(Section,'RussHost',Temp,FName);

  {Russian character set (client)}
  id2str(@RussList,ts^.RussClient,IdWindows,Temp);
  WritePrivateProfileString(Section,'RussClient',Temp,FName);

  {Title text}
  WritePrivateProfileString(Section,'Title',ts^.Title,FName);

  {Cursor shape}
  case ts^.CursorShape of
    IdVCur  : StrCopy(Temp,'vertical');
    IdHCur  : StrCopy(Temp,'horizontal');
  else
    StrCopy(Temp,'block');
  end;
  WritePrivateProfileString(Section,'CursorShape',Temp,FName);

  {Hide title}
  WriteOnOff(Section,'HideTitle',FName,ts^.HideTitle);

  {Popup menu}
  WriteOnOff(Section,'PopupMenu',FName,ts^.PopupMenu);

  {ANSI full color}
  WriteOnOff(Section,'FullColor',FName,ts^.ColorFlag and CF_FULLCOLOR);

  {Enable scroll buffer}
  WriteOnOff(Section,'EnableScrollBuff',FName,ts^.EnableScrollBuff);

  {Scroll buffer size}
  WriteInt(Section,'ScrollBuffSize',FName,ts^.ScrollBuffSize);

  {VT Color}
  for i := 0 to 1 do
  begin
    ts^.TmpColor[0,i*3]   := GetRValue(ts^.VTColor[i]);
    ts^.TmpColor[0,i*3+1] := GetGValue(ts^.VTColor[i]);
    ts^.TmpColor[0,i*3+2] := GetBValue(ts^.VTColor[i]);
  end;
  WriteInt6(Section,'VTColor',FName,
    ts^.TmpColor[0,0], ts^.TmpColor[0,1], ts^.TmpColor[0,2],
    ts^.TmpColor[0,3], ts^.TmpColor[0,4], ts^.TmpColor[0,5]);

  {VT bold color}
  for i := 0 to 1 do
  begin
    ts^.TmpColor[0,i*3]   := GetRValue(ts^.VTBoldColor[i]);
    ts^.TmpColor[0,i*3+1] := GetGValue(ts^.VTBoldColor[i]);
    ts^.TmpColor[0,i*3+2] := GetBValue(ts^.VTBoldColor[i]);
  end;
  WriteInt6(Section,'VTBoldColor',FName,
    ts^.TmpColor[0,0], ts^.TmpColor[0,1], ts^.TmpColor[0,2],
    ts^.TmpColor[0,3], ts^.TmpColor[0,4], ts^.TmpColor[0,5]);

  {VT blink color}
  for i := 0 to 1 do
  begin
    ts^.TmpColor[0,i*3]   := GetRValue(ts^.VTBlinkColor[i]);
    ts^.TmpColor[0,i*3+1] := GetGValue(ts^.VTBlinkColor[i]);
    ts^.TmpColor[0,i*3+2] := GetBValue(ts^.VTBlinkColor[i]);
  end;
  WriteInt6(Section,'VTBlinkColor',FName,
    ts^.TmpColor[0,0], ts^.TmpColor[0,1], ts^.TmpColor[0,2],
    ts^.TmpColor[0,3], ts^.TmpColor[0,4], ts^.TmpColor[0,5]);

  {TEK Color}
  for i := 0 to 1 do
  begin
    ts^.TmpColor[0,i*3]   := GetRValue(ts^.TEKColor[i]);
    ts^.TmpColor[0,i*3+1] := GetGValue(ts^.TEKColor[i]);
    ts^.TmpColor[0,i*3+2] := GetBValue(ts^.TEKColor[i]);
  end;
  WriteInt6(Section,'TEKColor',FName,
    ts^.TmpColor[0,0], ts^.TmpColor[0,1], ts^.TmpColor[0,2],
    ts^.TmpColor[0,3], ts^.TmpColor[0,4], ts^.TmpColor[0,5]);

  {TEK color emulation}
  WriteOnOff(Section,'TEKColorEmulation',FName,ts^.TEKColorEmu);

  {VT Font}
  WriteFont(Section,'VTFont',FName,
    ts^.VTFont,ts^.VTFontSize.x,ts^.VTFontSize.y,
    ts^.VTFontCharSet);

  {Enable bold font flag}
  WriteOnOff(Section,'EnableBold',FName,ts^.EnableBold);

  {Russian character set (font)}
  id2str(@RussList,ts^.RussFont,IdWindows,Temp);
  WritePrivateProfileString(Section,'RussFont',Temp,FName);

  {TEK Font}
  WriteFont(Section,'TEKFont',FName,
    ts^.TEKFont,ts^.TEKFontSize.x,ts^.TEKFontSize.y,
    ts^.TEKFontCharSet);

  {BS key}
  if ts^.BSKey = IdDEL then StrCopy(Temp,'DEL')
                            else StrCopy(Temp,'BS');
  WritePrivateProfileString(Section,'BSKey',Temp,FName);

  {Delete key}
  WriteOnOff(Section,'DeleteKey',FName,ts^.DelKey);

  {Meta key}
  WriteOnOff(Section,'MetaKey',FName,ts^.MetaKey);

  {Russian keyboard type}
  id2str(@RussList2,ts^.RussKeyb,IdWindows,Temp);
  WritePrivateProfileString(Section,'RussKeyb',Temp,FName);

  {Serial port ID}
  uint2str(ts^.ComPort,Temp,2);
  WritePrivateProfileString(Section,'ComPort',Temp,FName);

  {Baud rate}
  id2str(@BaudList,ts^.Baud,IdBaud9600,Temp);
  WritePrivateProfileString(Section,'BaudRate',Temp,FName);

  {Parity}
  case ts^.Parity of
    IdParityEven: StrCopy(Temp,'even');
    IdParityOdd:  StrCopy(Temp,'odd');
  else
    StrCopy(Temp,'none');
  end;
  WritePrivateProfileString(Section,'Parity',Temp,FName);

  {Data bit}
  case ts^.DataBit of
    IdDataBit7: StrCopy(Temp,'7');
  else
    StrCopy(Temp,'8');
  end;
  WritePrivateProfileString(Section,'DataBit',Temp,FName);

  {Stop bit}
  case ts^.StopBit of
    IdStopBit2: StrCopy(Temp,'2');
  else
    StrCopy(Temp,'1');
  end;
  WritePrivateProfileString(Section,'StopBit',Temp,FName);

  {Flow control}
  case ts^.Flow of
    IdFlowX:    StrCopy(Temp,'x');
    IdFlowHard: StrCopy(Temp,'hard');
  else
    StrCopy(Temp,'none');
  end;
  WritePrivateProfileString(Section,'FlowCtrl',Temp,FName);

  {Delay per character}
  WriteInt(Section,'DelayPerChar',FName,ts^.DelayPerChar);

  {Delay per line}
  WriteInt(Section,'DelayPerLine',FName,ts^.DelayPerLine);

  {Telnet flag}
  WriteOnOff(Section,'Telnet',FName,ts^.Telnet);

  {Telnet terminal type}
  WritePrivateProfileString(Section,'TermType',ts^.TermType,FName);

  {TCP port num for non-telnet}
  WriteUint(Section,'TCPPort',FName,ts^.TCPPort);

  {Auto close flag}
  WriteOnOff(Section,'AutoWinClose',FName,ts^.AutoWinClose);

  {History list}
  WriteOnOff(Section,'HistoryList',FName,ts^.HistoryList);

  {File transfer binary flag}
  WriteOnOff(Section,'TransBin',FName,ts^.TransBin);

  {Log append}
  WriteOnOff(Section,'LogAppend',FName,ts^.Append);

  {XMODEM option}
  case ts^.XmodemOpt of
    XoptCRC: StrCopy(Temp,'crc');
    Xopt1K:  StrCopy(Temp,'1k');
  else
    StrCopy(Temp,'checksum');
  end;
  WritePrivateProfileString(Section,'XmodemOpt',Temp,FName);

  {XMODEM binary flag}
  WriteOnOff(Section,'XmodemBin',FName,ts^.XmodemBin);

  {Default directory for file transfer}
  WritePrivateProfileString(Section,'FileDir',ts^.FileDir,FName);

{------------------------------------------------------------------}
  { 8 bit control code flag  -- special option }
  WriteOnOff(Section,'Accept8bitCtrl',FName,
    ts^.TermFlag and TF_ACCEPT8BITCTRL);

  { Wrong sequence flag  -- special option }
  WriteOnOff(Section,'AllowWrongSequence',FName,
    ts^.TermFlag and TF_ALLOWWRONGSEQUENCE);

  { Auto file renaming -- special option }
  WriteOnOff(Section,'AutoFileRename',FName,
    ts^.FTFlag and FT_RENAME);

  { Auto text copy --- special option}
  WriteOnOff(Section,'AutoTextCopy',FName,ts^.AutoTextCopy);

  { Back wrap -- special option}
  WriteOnOff(Section,'BackWrap',FName,
    ts^.TermFlag and TF_BACKWRAP);

  { Beep type -- special option }
  WriteOnOff(Section,'Beep',FName,ts^.Beep);

  { Beep on connection & disconnection -- special option }
  WriteOnOff(Section,'BeepOnConnect',FName,ts^.PortFlag and PF_BEEPONCONNECT);

  { Auto B-Plus activation -- special option }
  WriteOnOff(Section,'BPAuto',FName,ts^.FTFlag and FT_BPAUTO);

  { B-Plus ESCCTL flag  -- special option }
  WriteOnOff(Section,'BPEscCtl',FName,ts^.FTFlag and FT_BPESCCTL);

  { B-Plus log  -- special option }
  WriteOnOff(Section,'BPLog',FName,ts^.LogFlag and LOG_BP);

  { Confirm disconnection -- special option }
  WriteOnOff(Section,'ConfirmDisconnect',FName,
    ts^.PortFlag and PF_CONFIRMDISCONN);

  { Ctrl code in Kanji -- special option }
  WriteOnOff(Section,'CtrlInKanji',FName,
    ts^.TermFlag and TF_CTRLINKANJI);

  { Debug flag  -- special option }
  WriteOnOff(Section,'Debug',FName,ts^.Debug);

  { Delimiter list -- special option }
  Str2Hex(ts^.DelimList,Temp,strlen(ts^.DelimList),
          sizeof(Temp)-1,TRUE);
  WritePrivateProfileString(Section,'DelimList',Temp,FName);

  { regard DBCS characters as delimiters -- special option }
  WriteOnOff(Section,'DelimDBCS',FName,ts^.DelimDBCS);

  { Enable popup menu -- special option}
  if (ts^.MenuFlag and MF_NOPOPUP) = 0 then
    WriteOnOff(Section,'EnablePopupMenu',FName,1)
  else
    WriteOnOff(Section,'EnablePopupMenu',FName,0);

  { Enable "Show menu" -- special option}
  if (ts^.MenuFlag and MF_NOSHOWMENU) = 0 then
    WriteOnOff(Section,'EnableShowMenu',FName,1)
  else
    WriteOnOff(Section,'EnableShowMenu',FName,0);

  {Enable the status line -- special option}
  WriteOnOff(Section,'EnableStatusLine',FName,
    ts^.TermFlag and TF_ENABLESLINE);

  { IME Flag  -- special option }
  WriteOnOff(Section,'IME',FName,ts^.UseIME);

  { IME-inline Flag  -- special option }
  WriteOnOff(Section,'IMEInline',FName,ts^.IMEInline);

  { Kermit log  -- special option }
  WriteOnOff(Section,'KmtLog',FName,ts^.LogFlag and LOG_KMT);

  { Enable language selection -- special option}
  if (ts^.MenuFlag and MF_NOLANGUAGE)=0 then
    WriteOnOff(Section,'LanguageSelection',FName,1)
  else
    WriteOnOff(Section,'LanguageSelection',FName,0);

  { Maximum scroll buffer size  -- special option }
  WriteInt(Section,'MaxBuffSize',FName,ts^.ScrollBuffMax);

  { Max com port number -- special option }
  WriteInt(Section,'MaxComPort',FName,ts^.MaxComPort);

  { Non-blinking cursor -- special option }
  WriteOnOff(Section,'NonblinkingCursor',FName,ts^.NonblinkingCursor);

  { Delay for pass-thru printing activation }
  {   -- special option }
  WriteUint(Section,'PassThruDelay',FName,ts^.PassThruDelay);

  { Printer port for pass-thru printing }
  {   -- special option }
  WritePrivateProfileString(Section,'PassThruPort',
    ts^.PrnDev,FName);

  { Printer Font --- special option }
  WriteFont(Section,'PrnFont',FName,
    ts^.PrnFont,ts^.PrnFontSize.x,ts^.PrnFontSize.y,
    ts^.PrnFontCharSet);

  { Page margins (left, right, top, bottom) for printing
  	-- special option }
  WriteInt4(Section,'PrnMargin',FName,
    ts^.PrnMargin[0],ts^.PrnMargin[1],
    ts^.PrnMargin[2],ts^.PrnMargin[3]);

  { Quick-VAN log  -- special option }
  WriteOnOff(Section,'QVLog',FName,ts^.LogFlag and LOG_QV);

  { Quick-VAN window size -- special option}
  WriteInt(Section,'QVWinSize',FName,ts^.QVWinSize);

  {Russian character set (print) -- special option}
  id2str(@RussList,ts^.RussPrint,IdWindows,Temp);
  WritePrivateProfileString(Section,'RussPrint',Temp,FName);

  { Scroll threshold -- special option }
  WriteInt(Section,'ScrollThreshold',FName,ts^.ScrollThreshold);

  { Select on activate -- special option}
  WriteOnOff(Section,'SelectOnActivate',FName,ts^.SelOnActive);

  { Startup macro -- special option }
  WritePrivateProfileString(Section,'StartupMacro',ts^.MacroFN,FName);

  { TEK GIN Mouse keycode -- special option }
  WriteInt(Section,'TEKGINMouseCode',FName,ts^.GINMouseCode);

  { Telnet binary flag -- special option }
  WriteOnOff(Section,'TelBin',FName,ts^.TelBin);

  { Telnet Echo flag -- special option }
  WriteOnOff(Section,'TelEcho',FName,ts^.TelEcho);

  { Telnet log  -- special option }
  WriteOnOff(Section,'TelLog',FName,ts^.LogFlag and LOG_TEL);

  { TCP port num for telnet -- special option}
  WriteUint(Section,'TelPort',FName,ts^.TelPort);

  { Local echo for non-telnet }
  WriteOnOff(Section,'TCPLocalEcho',FName,ts^.TCPLocalEcho);

  { "new-line (transmit)" option for non-telnet -- special option }
  if ts^.TCPCRSend = IdCRLF then
    strcopy(Temp,'CRLF')
  else if ts^.TCPCRSend = IdCR then
    strcopy(Temp,'CR')
  else
    Temp[0] := #0;
  WritePrivateProfileString(Section,'TCPCRSend',Temp,FName);

  { Use text (background) color for "white (black)"
      --- special option }
  WriteOnOff(Section,'UseTextColor',FName,ts^.ColorFlag and CF_USETEXTCOLOR);

  { Title format -- special option }
  WriteUint(Section,'TitleFormat',FName,ts^.TitleFormat);

  { VT Font space --- special option }
  WriteInt4(Section,'VTFontSpace',FName,
    ts^.FontDX,ts^.FontDW-ts^.FontDX,
    ts^.FontDY,ts^.FontDH-ts^.FontDY);

  { VT-print scaling factors (pixels per inch) --- special option}
  WriteInt2(Section,'VTPPI',FName,
    ts^.VTPPI.x,ts^.VTPPI.y);

  { TEK-print scaling factors (pixels per inch) --- special option}
  WriteInt2(Section,'TEKPPI',FName,
    ts^.TEKPPI.x,ts^.TEKPPI.y);

  { Show "Window" menu -- special option}
  WriteOnOff(Section,'WindowMenu',FName,ts^.MenuFlag and MF_SHOWWINMENU);

  { XMODEM log  -- special option }
  WriteOnOff(Section,'XmodemLog',FName,ts^.LogFlag and LOG_X);

  { Auto ZMODEM activation -- special option }
  WriteOnOff(Section,'ZmodemAuto',FName,ts^.FTFlag and FT_ZAUTO);

  { ZMODEM data subpacket length for sending -- special }
  WriteInt(Section,'ZmodemDataLen',FName,ts^.ZmodemDataLen);
  { ZMODEM window size for sending -- special }
  WriteInt(Section,'ZmodemWinSize',FName,ts^.ZmodemWinSize);

  { ZMODEM ESCCTL flag  -- special option }
  WriteOnOff(Section,'ZmodemEscCtl',FName,ts^.FTFlag and FT_ZESCCTL);

  { ZMODEM log  -- special option }
  WriteOnOff(Section,'ZmodemLog',FName,ts^.LogFlag and LOG_Z);

  { update file }
  WritePrivateProfileString(nil,nil,nil,FName);
end;

const
  VTEditor='VT editor keypad';
  VTNumeric='VT numeric keypad';
  VTFunction='VT function keys';
  XFunction = 'X function keys';
  ShortCut='Shortcut keys';

procedure GetInt(KeyMap: PKeyMap; KeyId: integer; Sect, Key, FName: PChar);
var
  Temp: array[0..10] of char;
  c: integer;
  Num: word;
begin
  GetPrivateProfileString(Sect,Key,'',
                          Temp,SizeOf(Temp),FName);
  if Temp[0]=#0 then
    Num := $FFFF
  else if StrIComp(Temp,'off')=0 then
    Num := $FFFF
  else begin
    Val(StrPas(@Temp[0]),Num,c);
    if c <> 0 then Num := $FFFF;
  end;

  KeyMap^.Map[KeyId-1] := Num;
end;

procedure ReadKeyboardCnf
  (FName: PChar; KeyMap: PKeyMap; ShowWarning: BOOL); export;
var
  i, j, Ptr: integer;
  EntName: array[0..6] of char;
  TempStr: array[0..220] of char;
  KStr: array[0..200] of char;
  NumStr: string[10];
  Temp2: array[0..10] of char;
begin
with KeyMap^ do begin
  {clear key map}
  for i := 0 to IdKeyMax-1 do
    Map[i] := $FFFF;
  for i := 0 to NumOfUserKey-1 do
  begin
    UserKeyPtr[i] := 0;
    UserKeyLen[i] := 0;
  end;

  {VT editor keypad}
  GetInt(KeyMap,IdUp,VTEditor,'Up',FName);

  GetInt(KeyMap,IdDown,VTEditor,'Down',FName);

  GetInt(KeyMap,IdRight,VTEditor,'Right',FName);

  GetInt(KeyMap,IdLeft,VTEditor,'Left',FName);

  GetInt(KeyMap,IdFind,VTEditor,'Find',FName);

  GetInt(KeyMap,IdInsert,VTEditor,'Insert',FName);

  GetInt(KeyMap,IdRemove,VTEditor,'Remove',FName);

  GetInt(KeyMap,IdSelect,VTEditor,'Select',FName);

  GetInt(KeyMap,IdPrev,VTEditor,'Prev',FName);

  GetInt(KeyMap,IdNext,VTEditor,'Next',FName);

  {VT numeric keypad}
  GetInt(KeyMap,Id0,VTNumeric,'Num0',FName);

  GetInt(KeyMap,Id1,VTNumeric,'Num1',FName);

  GetInt(KeyMap,Id2,VTNumeric,'Num2',FName);

  GetInt(KeyMap,Id3,VTNumeric,'Num3',FName);

  GetInt(KeyMap,Id4,VTNumeric,'Num4',FName);

  GetInt(KeyMap,Id5,VTNumeric,'Num5',FName);

  GetInt(KeyMap,Id6,VTNumeric,'Num6',FName);

  GetInt(KeyMap,Id7,VTNumeric,'Num7',FName);

  GetInt(KeyMap,Id8,VTNumeric,'Num8',FName);

  GetInt(KeyMap,Id9,VTNumeric,'Num9',FName);

  GetInt(KeyMap,IdMinus,VTNumeric,'NumMinus',FName);

  GetInt(KeyMap,IdComma,VTNumeric,'NumComma',FName);

  GetInt(KeyMap,IdPeriod,VTNumeric,'NumPeriod',FName);

  GetInt(KeyMap,IdEnter,VTNumeric,'NumEnter',FName);

  GetInt(KeyMap,IdPF1,VTNumeric,'PF1',FName);

  GetInt(KeyMap,IdPF2,VTNumeric,'PF2',FName);

  GetInt(KeyMap,IdPF3,VTNumeric,'PF3',FName);

  GetInt(KeyMap,IdPF4,VTNumeric,'PF4',FName);

  {VT function keys}
  GetInt(KeyMap,IdHold,VTFunction,'Hold',FName);

  GetInt(KeyMap,IdPrint,VTFunction,'Print',FName);

  GetInt(KeyMap,IdBreak,VTFunction,'Break',FName);

  GetInt(KeyMap,IdF6,VTFunction,'F6',FName);

  GetInt(KeyMap,IdF7,VTFunction,'F7',FName);

  GetInt(KeyMap,IdF8,VTFunction,'F8',FName);

  GetInt(KeyMap,IdF9,VTFunction,'F9',FName);

  GetInt(KeyMap,IdF10,VTFunction,'F10',FName);

  GetInt(KeyMap,IdF11,VTFunction,'F11',FName);

  GetInt(KeyMap,IdF12,VTFunction,'F12',FName);

  GetInt(KeyMap,IdF13,VTFunction,'F13',FName);

  GetInt(KeyMap,IdF14,VTFunction,'F14',FName);

  GetInt(KeyMap,IdHelp,VTFunction,'Help',FName);

  GetInt(KeyMap,IdDo,VTFunction,'Do',FName);

  GetInt(KeyMap,IdF17,VTFunction,'F17',FName);

  GetInt(KeyMap,IdF18,VTFunction,'F18',FName);

  GetInt(KeyMap,IdF19,VTFunction,'F19',FName);

  GetInt(KeyMap,IdF20,VTFunction,'F20',FName);

  {UDK}
  GetInt(KeyMap,IdUDK6,VTFunction,'UDK6',FName);

  GetInt(KeyMap,IdUDK7,VTFunction,'UDK7',FName);

  GetInt(KeyMap,IdUDK8,VTFunction,'UDK8',FName);

  GetInt(KeyMap,IdUDK9,VTFunction,'UDK9',FName);

  GetInt(KeyMap,IdUDK10,VTFunction,'UDK10',FName);

  GetInt(KeyMap,IdUDK11,VTFunction,'UDK11',FName);

  GetInt(KeyMap,IdUDK12,VTFunction,'UDK12',FName);

  GetInt(KeyMap,IdUDK13,VTFunction,'UDK13',FName);

  GetInt(KeyMap,IdUDK14,VTFunction,'UDK14',FName);

  GetInt(KeyMap,IdUDK15,VTFunction,'UDK15',FName);

  GetInt(KeyMap,IdUDK16,VTFunction,'UDK16',FName);

  GetInt(KeyMap,IdUDK17,VTFunction,'UDK17',FName);

  GetInt(KeyMap,IdUDK18,VTFunction,'UDK18',FName);

  GetInt(KeyMap,IdUDK19,VTFunction,'UDK19',FName);

  GetInt(KeyMap,IdUDK20,VTFunction,'UDK20',FName);

  {XTERM function keys}
  GetInt(KeyMap,IdXF1,XFunction,'XF1',FName);

  GetInt(KeyMap,IdXF2,XFunction,'XF2',FName);

  GetInt(KeyMap,IdXF3,XFunction,'XF3',FName);

  GetInt(KeyMap,IdXF4,XFunction,'XF4',FName);

  GetInt(KeyMap,IdXF5,XFunction,'XF5',FName);

  {accelerator keys}
  GetInt(KeyMap,IdCmdEditCopy,ShortCut,'EditCopy',FName);

  GetInt(KeyMap,IdCmdEditPaste,ShortCut,'EditPaste',FName);

  GetInt(KeyMap,IdCmdEditPasteCR,ShortCut,'EditPasteCR',FName);

  GetInt(KeyMap,IdCmdEditCLS,ShortCut,'EditCLS',FName);

  GetInt(KeyMap,IdCmdEditCLB,ShortCut,'EditCLB',FName);

  GetInt(KeyMap,IdCmdCtrlOpenTEK,ShortCut,'ControlOpenTEK',FName);

  GetInt(KeyMap,IdCmdCtrlCloseTEK,ShortCut,'ControlCloseTEK',FName);

  GetInt(KeyMap,IdCmdLineUp,ShortCut,'LineUp',FName);

  GetInt(KeyMap,IdCmdLineDown,ShortCut,'LineDown',FName);

  GetInt(KeyMap,IdCmdPageUp,ShortCut,'PageUp',FName);

  GetInt(KeyMap,IdCmdPageDown,ShortCut,'PageDown',FName);

  GetInt(KeyMap,IdCmdBuffTop,ShortCut,'BuffTop',FName);

  GetInt(KeyMap,IdCmdBuffBottom,ShortCut,'BuffBottom',FName);

  GetInt(KeyMap,IdCmdNextWin,ShortCut,'NextWin',FName);

  GetInt(KeyMap,IdCmdPrevWin,ShortCut,'PrevWin',FName);

  GetInt(KeyMap,IdCmdLocalEcho,ShortCut,'LocalEcho',FName);

  {user keys}

  Ptr := 0;

  StrCopy(EntName,'User');
  i := IdUser1;
  repeat
    uint2str(i-IdUser1+1,@EntName[4],2);
    GetPrivateProfileString('User keys',EntName,'',
                             TempStr,SizeOf(TempStr),FName);
    if StrLen(TempStr) > 0 then
    begin
      {scan code}
      GetNthString(TempStr,1,sizeof(KStr),KStr);
      if stricomp(KStr,'off')=0 then
        Map[i-1] := $FFFF
      else begin 
        GetNthNum(TempStr,1,j);
        Map[i-1] := word(j);
      end;
      {conversion flag}
      GetNthNum(TempStr,2,j);
      UserKeyType[i-IdUser1] := byte(j);
      {key string}
{      GetNthString(TempStr,3,sizeof(KStr),KStr);}
      UserKeyPtr[i-IdUser1] := Ptr;
{      UserKeyLen[i-IdUser1] :=
        Hex2Str(KStr,@UserKeyStr[Ptr],KeyStrMax-Ptr+1);}
      GetNthString(TempStr,3,KeyStrMax-Ptr+1,@UserKeyStr[Ptr]);
      UserKeyLen[i-IdUser1] := strlen(@UserKeyStr[Ptr]);
      Ptr := Ptr + UserKeyLen[i-IdUser1];
    end;

    inc(i)
  until (i > IdKeyMax) or (StrLen(TempStr)=0) or (Ptr>KeyStrMax);

  for j := 1 to IdKeyMax-1 do
    if KeyMap^.Map[j]<>$FFFF then 
      for i := 0 to j-1 do
       if KeyMap^.Map[i]=KeyMap^.Map[j] then
       begin
         if ShowWarning then
         begin
           strcopy(TempStr,'Keycode ');
           Str(KeyMap^.Map[j],NumStr);
           StrPCopy(Temp2,NumStr);
           strcat(TempStr,Temp2);
           strcat(TempStr,' is used more than once');
           MessageBox(0,TempStr,
            'Tera Term: Error in keyboard setup file',MB_ICONEXCLAMATION);
         end;
         KeyMap^.Map[i] := $FFFF;
       end;

end;
end;

{copy hostlist from source IniFile to dest IniFile}
procedure CopyHostList(IniSrc, IniDest: PChar); export;
var
  i: integer;
  EntName: array[0..6] of char;
  TempHost: array[0..HostNameMaxLength] of char;
begin
  if StrIComp(IniSrc,IniDest)=0 then exit;

  WritePrivateProfileString('Hosts',nil,nil,IniDest);
  StrCopy(EntName,'Host');

  i := 1;
  repeat
    uint2str(i,@EntName[4],2);

    {Get one hostname from file IniSrc}
    GetPrivateProfileString('Hosts',EntName,'',
                            TempHost,SizeOf(TempHost),IniSrc);
    {Copy it to file IniDest}
    if StrLen(TempHost) > 0 then
      WritePrivateProfileString('Hosts',EntName,TempHost,IniDest);
    inc(i)
  until (i > 99) or (StrLen(TempHost)=0);

  { update file }
  WritePrivateProfileString(nil,nil,nil,IniDest);
end;

procedure AddHostToList(FName, Host: PChar); export;
var
  MemH: THandle;
  MemP: PChar;
  EntName: array[0..6] of char;
  i, j, Len: integer;
  Update: BOOL;
begin
  if (FName[0]=#0) or (Host[0]=#0) then exit;
  MemH := GlobalAlloc(GHND, (HostNameMaxLength+1)*99);
  if MemH=0 then exit;
  MemP := GlobalLock(MemH);
  if MemP<>nil then
  begin
    strcopy(MemP,Host);
    j := strlen(Host)+1;
    strcopy(EntName,'Host');
    i := 1;
    Update := TRUE;
    repeat
      uint2str(i,@EntName[4],2);

      {Get a hostname}
      GetPrivateProfileString('Hosts',EntName,'',
                              @MemP[j],HostNameMaxLength+1,FName);
      Len := strlen(@MemP[j]);
      if stricomp(@MemP[j],Host)=0 then
      begin
        if i=1 then Update := FALSE;
      end
      else
        j := j + Len + 1;
      inc(i);
    until (i > 99) or (Len=0) or not Update;

    if Update then
    begin
      WritePrivateProfileString('Hosts',nil,nil,FName);

      j := 0;
      i := 1;
      repeat
        uint2str(i,@EntName[4],2);

        if MemP[j]<> #0 then
          WritePrivateProfileString('Hosts',EntName,@MemP[j],FName);
        j := j + strlen(@MemP[j]) + 1;
        inc(i);
      until (i > 99) or (MemP[j]=#0);
      { update file }
      WritePrivateProfileString(nil,nil,nil,FName);
    end;
    GlobalUnlock(MemH);
  end;
  GlobalFree(MemH);
end;

procedure ParseParam(Param: PChar; ts: PTTSet; DDETopic: PChar); export;

  function NextParam(var i: integer; Temp: PChar; Size: integer): boolean;
  var
    j: integer;
    c: char;
    Quoted: BOOL;
  begin
    NextParam := FALSE;
    if i >= StrLen(Param) then exit;
    j := 0;

    while Param[i]=' ' do
      inc(i);

    Quoted := FALSE;
    c := Param[i];
    inc(i);
    while (c<>#0) and (Quoted or (c<>' ')) and
          (Quoted or (c<>';')) and (j<Size-1) do
    begin
      if c='"' then
        Quoted := not Quoted;
      Temp[j] := c;
      inc(j);
      c := Param[i];
      inc(i);
    end;
    if not Quoted and (c=';') then
      dec(i);

    Temp[j] := #0;
    NextParam := strlen(Temp)>0;
  end;

  procedure DeQuote(Source, Dest: PCHAR);
  var
    i, j: integer;
    q, c: char;
  begin
    Dest[0] := #0;
    if Source[0] = #0 then exit;
    i := 0;
    {quoting char}
    q := Source[i];
    {only " and ' are used as quoting char}
    if ((q<>#$22) and (q<>#$27)) then
      q := #0
    else
      inc(i);

    c := Source[i];
    inc(i);
    j := 0;
    while (c<>#0) and (c<>q) do
    begin
      Dest[j] := c;
      inc(j);
      c := Source[i];
      inc(i);
    end;

    Dest[j] := #0;
  end;

  procedure ConvFName(Temp, DefExt, FName: PChar);
  var
    DirLen, FNPos: integer;
  begin
    FName[0] := #0;
    if not GetFileNamePos(Temp,DirLen,FNPos) then exit;
    FitFileName(@Temp[FNPos],DefExt);
    if DirLen=0 then
    begin
      StrCopy(FName,ts^.HomeDir);
      AppendSlash(FName);
    end;
    StrCat(FName,Temp);
  end;

var
 i, pos, c: integer;
 b: char;
 Temp: array[0..MAXPATHLEN+2] of char;
 Temp2: array[0..MAXPATHLEN-1] of char;
 TempDir: array[0..MAXPATHLEN-1] of char;
 ParamPort: word;
 ParamCom: word;
 ParamTCP: word;
 ParamTel: word;
 ParamBin: word;
 HostNameFlag, JustAfterHost: bool;
begin
  ParamPort := 0;
  ParamCom := 0;
  ParamTCP := 65535;
  ParamTel := 2;
  ParamBin := 2; 
  HostNameFlag := FALSE;
  JustAfterHost := FALSE;

  ts^.HostName[0] := #0;
  ts^.KeyCnfFN[0] := #0;

  {Get command line parameters}
  if DDETopic <> nil then
    DDETopic[0] := #0;
  i := 0;
  {the first term should be executable filename of Tera Term}
  NextParam(i, Temp, sizeof(Temp));
  while NextParam(i, Temp, SizeOf(Temp)) do
  begin
    if HostNameFlag then
    begin
      JustAfterHost := TRUE;
      HostNameFlag := FALSE;
    end;

    if StrLIComp(Temp,'/B',2)=0 then {telnet binary}
    begin
      ParamPort := IdTCPIP;
      ParamBin := 1;
    end
    else if StrLIComp(Temp,'/C=',3)=0 then {COM port num}
    begin
      ParamPort := IdSerial;
      if strlen(@Temp[3])>=1 then
        ParamCom := byte(Temp[3])-$30;
      if strlen(@Temp[3])>=2 then
        ParamCom := ParamCom*10 + byte(Temp[4])-$30;
      if (ParamCom<1) or (ParamCom>ts^.MaxComPort) then
        ParamCom := 0;
    end
    else if StrLIComp(Temp,'/D=',3)=0 then
    begin
      if DDETopic <> nil then
        strcopy(DDETopic,@Temp[3]);
    end
    else if StrLIComp(Temp,'/F=',3)=0 then {setup filename}
    begin
      Dequote(@Temp[3],Temp2);
      if strlen(Temp2) > 0 then
      begin
        ConvFName(Temp2,'.INI',Temp);
        if stricomp(ts^.SetupFName,Temp)<>0 then
        begin
          strcopy(ts^.SetupFName,Temp);
          ReadIniFile(ts^.SetupFName,ts);
        end;
      end;
    end
    else if StrLIComp(Temp,'/FD=',4)=0 then {file transfer directory}
    begin
      Dequote(@Temp[4],Temp2);
      if strlen(Temp2)>0 then
      begin
        GetCurDir(TempDir,0);
        SetCurDir(Temp2);
        if DosError=0 then
          StrCopy(ts^.FileDir,Temp2);
        SetCurDir(TempDir);
      end;
    end
    else if StrLIComp(Temp,'/H',2)=0 then {hide title bar}
    begin
      ts^.HideTitle := 1;
    end
    else if StrLIComp(Temp,'/I',2)=0 then {iconize}
    begin
      ts^.Minimize := 1;
    end
    else if StrLIComp(Temp,'/K=',3)=0 then {Keyboard setup file}
    begin
      Dequote(@Temp[3],Temp2);
      ConvFName(Temp2, '.CNF', ts^.KeyCnfFN)
    end
    else if (StrLIComp(Temp,'/KR=',4)=0) or
            (StrLIComp(Temp,'/KT=',4)=0) then {kanji code}
    begin
      if StrLIComp(@Temp[4],'SJIS',4)=0 then
        c := IdSJIS
      else if StrLIComp(@Temp[4],'EUC',3)=0 then
        c := IdEUC
      else if StrLIComp(@Temp[4],'JIS',3)=0 then
        c := IdJIS
      else
        c := -1;
      if c<>-1 then
      begin
        if StrLIComp(Temp,'/KR=',4)=0 then
          ts^.KanjiCode := c
        else
          ts^.KanjiCodeSend := c;
      end;
    end
    else if StrLIComp(Temp,'/L=',3)=0 then {log file}
    begin
      Dequote(@Temp[3],Temp2);
      ConvFName(Temp2, '', ts^.LogFN)
    end
    else if StrLIComp(Temp,'LA=',4)=0 then {language}
    begin
      if StrLIComp(@Temp[4],'E',1)=0 then
        ts^.Language := IdEnglish
      else if StrLIComp(@Temp[4],'J',1)=0 then
        ts^.Language := IdJapanese
      else if StrLIComp(@Temp[4],'R',1)=0 then
        ts^.Language := IdRussian;
    end
    else if StrLIComp(Temp,'/M=',3)=0 then {macro filename}
    begin
      if (Temp[3]=#0) or (Temp[3]='*') then
        strcopy(ts^.MacroFN,'*')
      else begin
        Dequote(@Temp[3],Temp2);
        ConvFName(Temp2, '.TTL', ts^.MacroFN);
      end
    end
    else if StrLIComp(Temp,'/M',2)=0 then
    begin {macro option without filename}
      strcopy(ts^.MacroFN,'*');
    end
    else if StrLIComp(Temp,'/P=',3)=0 then {TCP port num}
    begin
      ParamPort := IdTCPIP;
      Val(StrPas(@Temp[3]),ParamTCP,c);
      if c <> 0 then ParamTCP := 65535;
    end
    else if StrLIComp(Temp,'/R=',3)=0 then {Replay filename}
    begin
      Dequote(@Temp[3],Temp2);
      ConvFName(Temp2, '', ts^.HostName);
      if StrLen(ts^.HostName)>0 then
        ParamPort := IdFile;
    end
    else if StrLIComp(Temp,'/T=0',4)=0 then {telnet disable}
    begin
      ParamPort := IdTCPIP;
      ParamTel := 0;
    end
    else if StrLIComp(Temp,'/T=1',4)=0 then {telnet enable}
    begin
      ParamPort := IdTCPIP;
      ParamTel := 1;
    end
    else if StrLIComp(Temp,'/V',2)=0 then {invisible}
    begin
      ts^.HideWindow := 1;
    end
    else if StrLIComp(Temp,'/W=',3)=0 then {Window title}
    begin
      Dequote(@Temp[3],ts^.Title);
    end
    else if StrLIComp(Temp,'/X=',3)=0 then {Window pos (X)}
    begin
      Val(StrPas(@Temp[3]),pos,c);
      if c=0 then
      begin
        ts^.VTPos.x := pos;
        if ts^.VTPos.y=CW_USEDEFAULT then
          ts^.VTPos.y := 0;
      end;
    end
    else if StrLIComp(Temp,'/Y=',3)=0 then {Window pos (Y)}
    begin
      Val(StrPas(@Temp[3]),pos,c);
      if c=0 then
      begin
        ts^.VTPos.y := pos;
        if ts^.VTPos.x=CW_USEDEFAULT then
          ts^.VTPos.x := 0;
      end;
    end
    else if (Temp[0]<>'/') and (StrLen(Temp)>0) then
    begin
      if JustAfterHost then
      begin
        Val(StrPas(Temp),pos,c);
        if c=0 then ParamTCP := pos;
      end
      else begin
        ParamPort := IdTCPIP;
        StrCopy(ts^.HostName,Temp); {host name}
        HostNameFlag := TRUE;
      end;
    end;
    JustAfterHost := FALSE;
  end;

  if (DDETopic<>nil) and
     (DDETopic[0]<>#0) then
    ts^.MacroFN[0] := #0;

  if (ts^.HostName[0] <> #0) and
     (ParamPort=IdTCPIP) then
  begin
    if (StrLIComp(ts^.HostName,'telnet://',9)=0) or
       (StrLIComp(ts^.HostName,'tn3270://',9)=0) then
    begin
      Move(ts^.HostName[9],ts^.HostName[0],strlen(ts^.HostName)-8);
      i := strlen(ts^.HostName);
      if (i>0) and (ts^.HostName[i-1]='/') then
        ts^.HostName[i-1] := #0;
    end;
    i := 0;
    repeat
      b := ts^.HostName[i];
      inc(i);
    until (b=#0) or (b=':');
    if b=':' then
    begin
      ts^.HostName[i-1] := #0;
      Val(StrPas(@ts^.HostName[i]),ParamTCP,c);
      if c <> 0 then ParamTCP := 65535;
    end;
  end;

  case ParamPort of
    IdTCPIP: begin
      ts^.PortType := IdTCPIP;
      if ParamTCP<65535 then ts^.TCPPort := ParamTCP;
      if ParamTel<2 then ts^.Telnet := ParamTel;
      if ParamBin<2 then ts^.TelBin := ParamBin;
    end;
    IdSerial: begin
      ts^.PortType := IdSerial;
      if ParamCOM>0 then
        ts^.ComPort := ParamCom;
    end;
    IdFile:
      ts^.PortType := IdFile;
  end;
end;

exports

  ReadIniFile     index 1,
  WriteIniFile    index 2,
  ReadKeyboardCnf index 3,
  CopyHostList    index 4,
  AddHostToList   index 5,
  ParseParam      index 6;

begin
end.
