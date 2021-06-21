{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, variables, flags related to VT win and TEK win}
unit TTWinMan;

interface
{$I teraterm.inc}

{$IFDEF Delphi}
uses Messages, WinTypes, WinProcs, WinDos, Strings, TTTypes, Types, TTLib, TTCommon;
{$ELSE}
uses WinTypes, WinProcs, WinDos, Strings, TTTypes, Types, TTLib, TTCommon;
{$ENDIF}

var
  HVTWin: HWnd;
  HTEKWin: HWnd;

  ActiveWin: integer; {IdVT, IdTEK}
  TalkStatus: integer; {IdTalkKeyb, IdTalkCB, IdTalkTextFile}
  KeybEnabled: bool; {keyboard switch}
  Connecting: bool;

  {'help' button on dialog box}
  MsgDlgHelp: word;
  HelpId: longint;

  ts: TTTSet;
  cv: TComVar;

  {pointers to window objects}
  pVTWin, pTEKWin: pointer;

  SerialNo: integer;

procedure VTActivate;
procedure ChangeTitle;
procedure SwitchMenu;
procedure SwitchTitleBar;
procedure OpenHelp(HWin: HWND; Command: integer; Data: longint);

implementation
{$i helpid.inc}

procedure VTActivate;
begin
  ActiveWin := IdVT;
  ShowWindow(HVTWin, SW_SHOWNORMAL);
  SetFocus(HVTWin);
end;

procedure ChangeTitle;
var
  i: integer;
  TempTitle: array[0..80] of char;
  NumStr: string[10];
  Num: array[0..10] of char;
begin
  StrCopy(TempTitle, ts.Title);
  i := sizeof(TempTitle)-1;

  if ts.TitleFormat and 1 <> 0 then
  begin {host name}
    StrLCat(TempTitle,' - ',i);
    if Connecting then
      StrLCat(TempTitle,'[connecting...]',i)
    else if not cv.Ready then
      StrLCat(TempTitle,'[disconnected]',i)
    else if ts.PortType=IdSerial then
      case ts.ComPort of
        1: StrLCat(TempTitle,'COM1',i);
        2: StrLCat(TempTitle,'COM2',i);
        3: StrLCat(TempTitle,'COM3',i);
        4: StrLCat(TempTitle,'COM4',i);
      end
    else
      StrLCat(TempTitle,ts.HostName,i);
  end;

  if ts.TitleFormat and 2 <> 0 then
  begin {serial no.}
    Str(SerialNo,NumStr);
    StrPCopy(Num,NumStr);
    StrLCat(TempTitle,' (',i);
    StrLCat(TempTitle,Num,i);
    StrLCat(TempTitle,')',i);
  end;

  if ts.TitleFormat and 4 <> 0 then {VT}
    StrLCat(TempTitle,' VT',i);
  SetWindowText(HVTWin,TempTitle);

  if HTEKWin<>0 then
  begin
    if ts.TitleFormat and 4 <> 0 then {TEK}
    begin
      TempTitle[StrLen(TempTitle)-2] := #0;
      StrLCat(TempTitle,'TEK',i);
    end;
    SetWindowText(HTEKWin,TempTitle);
  end;
end;

procedure SwitchMenu;
var
  H1, H2: HWnd;
begin
  if ActiveWin=IdVT then
  begin
    H1 := HTEKWin;
    H2 := HVTWin;
  end
  else begin
    H1 := HVTWin;
    H2 := HTEKWin;
  end;

  if H1<>0 then
    PostMessage(H1,WM_USER_CHANGEMENU,0,0);
  if H2<>0 then
    PostMessage(H2,WM_USER_CHANGEMENU,0,0);
end;

procedure SwitchTitleBar;
var
  H1, H2: HWND;
begin
  if ActiveWin=IdVT then
  begin
    H1 := HTEKWin;
    H2 := HVTWin;
  end
  else begin
    H1 := HVTWin;
    H2 := HTEKWin;
  end;

  if H1<>0 then
    PostMessage(H1,WM_USER_CHANGETBAR,0,0);
  if H2<>0 then
    PostMessage(H2,WM_USER_CHANGETBAR,0,0);
end;

procedure OpenHelp(HWin: HWND; Command: integer; Data: longint);
var
  HelpFN: array[0..MAXPATHLEN-1] of char;
begin
  strcopy(HelpFN,ts.HomeDir);
  AppendSlash(HelpFN);
  if ts.Language=IdJapanese then
    strcat(HelpFN,HelpJpn)
  else
    strcat(HelpFN,HelpEng);
  WinHelp(HWin, HelpFN, Command, Data);
end;

begin
  HVTWin := 0;
  HTEKWin := 0;
  ActiveWin := IdVT;
  TalkStatus := IdTalkKeyb;
  KeybEnabled := TRUE;
  Connecting := FALSE;
  cv.Open := FALSE;
  cv.Ready := FALSE;
  pVTWin := nil;
  pTEKWin := nil;
end.
