{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTMACRO.EXE, dialog boxes}
unit TTMDLG;

interface
{$I teraterm.inc}

{$IFDEF Delphi}
uses WinTypes, WinProcs, OWindows, Strings, WinDos, CommDlg,
     Types, TTLib, InpDlg, ErrDlg, MsgDlg, StatDlg;
{$ELSE}
uses WinTypes, WinProcs, WObjects, Strings, WinDos, CommDlg,
     Types, TTLib, InpDlg, ErrDlg, MsgDlg, StatDlg;
{$ENDIF}

procedure ParseParam(var IOption, VOption: bool);
function GetFileName(HWin: HWND): bool;
procedure SetDlgPos(x, y: integer);
procedure OpenInpDlg(Buff, Text, Caption: PChar; Paswd: BOOL);
function OpenErrDlg(Msg, Line: PChar): integer;
function OpenMsgDlg(Text, Caption: PChar; YesNo: BOOL): integer;
procedure OpenStatDlg(Text, Caption: PCHAR);
procedure CloseStatDlg;

var
  HomeDir: array[0..MAXPATHLEN-1] of char;
  FileName: array[0..MAXPATHLEN-1] of char;
  TopicName: array[0..10] of char;
  ShortName: array[0..MAXPATHLEN-1] of char;
  Param2: array[0..MAXPATHLEN-1] of char;
  Param3: array[0..MAXPATHLEN-1] of char;
  SleepFlag: bool;

implementation

var
  DlgPosX, DlgPosY: integer;
  StatD: PStatDlg;

function NextParam
  (Param: PChar; var i: integer; Buff: PChar; BuffSize: integer): bool;
var
  j: integer;
  c, q: char;
  Quoted: BOOL;
begin
  NextParam := FALSE;
  if i >= StrLen(Param) then exit;
  j := 0;

  while Param[i]=' ' do
    inc(i);

  c := Param[i];
  Quoted := (c='"') or (c='''');
  q := #0;
  if Quoted then
  begin
    q := c;
    inc(i);
    c := Param[i];
  end;
  inc(i);
  while (c<>#0) and (c<>q) and (Quoted or (c<>' ')) and
        (Quoted or (c<>';')) and (j<BuffSize-1) do
  begin
    Buff[j] := c;
    inc(j);
    c := Param[i];
    inc(i);
  end;
  if not Quoted and (c=';') then
    dec(i);

  Buff[j] := #0;
  NextParam := strlen(Buff)>0;
end;

procedure ParseParam(var IOption, VOption: bool);
var
  i, j, k: integer;
  Param: array[0..MAXPATHLEN-1] of char;
  Temp: array[0..MAXPATHLEN-1] of char;
begin
  {Get home directory}
  GetModuleFileName(hInstance,FileName,sizeof(FileName));
  ExtractDirName(FileName,HomeDir);
  SetCurDir(HomeDir);

  {Get command line parameters}
  FileName[0] := #0;
  TopicName[0] := #0;
  Param2[0] := #0;
  Param3[0] := #0;
  SleepFlag := FALSE;
  IOption := FALSE;
  VOption := FALSE;
{$ifdef TERATERM32}
  strcopy(Param,GetCommandLine);
  i := 0;
  {the first term shuld be executable filename of TTMACRO}
  NextParam(Param, i, Temp, sizeof(Temp));
{$else}
  i := PByte(Ptr(GetCurrentPDB,$80))^;
  Move(PChar(Ptr(GetCurrentPDB,$81))[0],Param[0],i);
  Param[i] := #0;
  i := 0;
{$endif}
  j := 0;

  while NextParam(Param, i, Temp, sizeof(Temp)) do
  begin
    if strlicomp(Temp,'/D=',3)=0 then {DDE option}
      strcopy(TopicName,@Temp[3])
    else if strlicomp(Temp,'/I',2)=0 then
      IOption := TRUE
    else if strlicomp(Temp,'/S',2)=0 then
      SleepFlag := TRUE
    else if strlicomp(Temp,'/V',2)=0 then
      VOption := TRUE
    else begin
      inc(j);
      if j=1 then
        strcopy(FileName,Temp)
      else if j=2 then
        strcopy(Param2,Temp)
      else if j=3 then
        strcopy(Param3,Temp);
    end;
  end;

  if FileName[0]='*' then
    FileName[0] := #0
  else if FileName[0]<>#0 then
  begin
    if GetFileNamePos(FileName,j,k) then
    begin
      FitFileName(@FileName[k],'.TTL');
      strcopy(ShortName,@FileName[k]);
      if j=0 then
      begin
        strcopy(FileName,HomeDir);
        AppendSlash(FileName);
        strcat(FileName,ShortName);
      end;
    end
    else
      FileName[0] := #0;
  end;
end;

function GetFileName(HWin: HWnd): BOOL;
var
  FNFilter: array [0..30] of Char;
  FNameRec: TOpenFileName;
begin
  GetFileName := FALSE;
  if FileName[0]<>#0 then exit;

  FillChar(FNFilter, SizeOf(FNFilter), #0);
  FillChar(FNameRec, SizeOf(TOpenFileName), #0);
  StrCopy(FNFilter, 'Macro files (*.ttl)');
  StrCopy(@FNFilter[StrLen(FNFilter)+1], '*.ttl');

  with FNameRec do
  begin
    lStructSize   := sizeof(TOpenFileName);
    hwndOwner     := HWin;
    lpstrFilter   := FNFilter;
    nFilterIndex := 1;
    lpstrFile := FileName;
    nMaxFile := SizeOf(FileName);
    lpstrInitialDir := HomeDir;
    Flags := OFN_FILEMUSTEXIST or OFN_HIDEREADONLY;
    lpstrDefExt := 'TTL';
    lpstrTitle := 'MACRO: Open macro';
  end;

  if GetOpenFileName(FNameRec) then
    StrCopy(ShortName,@FileName[FNameRec.nFileOffset])
  else
    FileName[0] := #0;

  if FileName[0]=#0 then
  begin
    ShortName[0] := #0;
    GetFileName := FALSE;
  end
  else
    GetFileName := TRUE;
end;

procedure SetDlgPos(x, y: integer);
begin
  DlgPosX := x;
  DlgPosY := y;
  if StatD<>nil then
    StatD^.Update(nil,nil,x,y);
end;

procedure OpenInpDlg(Buff, Text, Caption: PChar;
                     Paswd: BOOL);
begin
  Application^.ExecDialog(New(PInpDlg,
    Init(Buff,Text,Caption,Paswd,DlgPosX,DlgPosY) ) );
end;

function OpenErrDlg(Msg, Line: PChar): integer;
begin
  OpenErrDlg :=
    Application^.ExecDialog(New(PErrDlg,
    Init(Msg,Line,DlgPosX,DlgPosY) ) );
end;

function OpenMsgDlg(Text, Caption: PChar; YesNo: BOOL): integer;
begin
  OpenMsgDlg := Application^.ExecDialog(New(PMsgDlg,
    Init(Text,Caption,YesNo,DlgPosX,DlgPosY) ) );
end;

procedure OpenStatDlg(Text, Caption: PCHAR);
begin
  if StatD=nil then
  begin
    StatD := PStatDlg(Application^.MakeWindow(
      New(PStatDlg, Init(Text,Caption,DlgPosX,DlgPosY)) ) );
  end
  else
    StatD^.Update(Text,Caption,32767,0);
end;

procedure CloseStatDlg;
begin
  if StatD<>nil then
  begin
    StatD^.CloseWindow;
    StatD := nil;
  end;
end;

begin
  DlgPosX := -100;
  DlgPosY := 0;
  StatD := nil;
end.
