{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTFILE.DLL, routines for file transfer protocol}
unit FTLib;

interface
{$I teraterm.inc}

{$IFDEF Delphi}
uses Messages, WinTypes, WinProcs, Strings, CommDlg, WinDos,
  TTTypes, TTFTypes, Types, TTLib, DlgLib;
{$ELSE}
uses WinTypes, WinProcs, Strings, CommDlg, Win31, WinDos,
  TTTypes, TTFTypes, Types, TTLib, DlgLib;
{$ENDIF}

{$ifdef TERATERM32}
procedure GetLongFName(FullName, LongName: PChar);
{$endif}

procedure FTConvFName(FName: PChar);
function GetNextFname(fv: PFileVar): bool;
function UpdateCRC(b: byte; CRC: word): word;
function UpdateCRC32(b: byte; CRC: longint): longint;
procedure FTLog1Byte(fv: PFileVar; b: byte);
procedure FTSetTimeOut(fv: PFileVar; T: integer);
function FTCreateFile(fv: PFileVar): BOOL;

function GetTransFname
  (fv: PFileVar; CurDir: PChar; FuncId: word; Option: Plongint): bool; export;

implementation
{$i tt_res.inc}
{$i file_res.inc}

{$ifdef TERATERM32}
procedure GetLongFName(FullName, LongName: PChar);
var {for Win NT 3.51: convert short file name to long file name}
  hFind: THandle;
  data: TWIN32_FIND_DATA;

  hFind := FindFirstFile(FullName,data);
  if hFind<>INVALID_HANDLE_VALUE then
  begin
    strcopy(LongName,data.cFileName);
    FindClose(hFind);
  end;
end;
{$endif}

procedure FTConvFName(FName: PChar);
var {replace ' ' by '_' in FName}
  i: integer;
begin
  i := 0;
  while FName[i]<>#0 do
  begin
    if FName[i]=' ' then
      FName[i] := '_';
    inc(i);
  end;
end;

function GetNextFname(fv: PFileVar): bool;
var
  i: integer;
begin
with fv^ do begin
  {next file name exists?}
  GetNextFname := FNcount < NumFname;
  if FNcount >= NumFname then exit; {no more file name}

  inc(FNcount);
  if NumFname=1 then exit;

  i := DirLen;

  GlobalLock(FnStrMemHandle);

  strcopy(@FullName[DirLen],@FnStrMem[FnPtr]);
  FnPtr := FnPtr + strlen(@FnStrMem[FnPtr]) + 1;

  GlobalUnlock(FnStrMemHandle);

{$ifdef TERATERM32}
  {for Win NT 3.5: short name -> long name}
  GetLongFName(FullName,@FullName[DirLen]);
{$endif}
  exit;
end;
end;

function UpdateCRC(b: byte; CRC: word): word;
var
  i: integer;
begin
  CRC := CRC xor word(word(b) shl 8);
  for i := 1 to 8 do
    if (CRC and $8000)<>0 then
      CRC := (CRC shl 1) xor $1021
    else
      CRC := CRC shl 1;
  UpdateCRC := CRC;
end;

function UpdateCRC32(b: byte; CRC: longint): longint;
var
  i: integer;
begin
  CRC := CRC xor longint(b);
  for i := 1 to 8 do
    if (CRC and $00000001)<>0 then
      CRC := (CRC shr 1) xor $edb88320
    else
      CRC := CRC shr 1;
  UpdateCRC32 := CRC;
end;

procedure FTLog1Byte(fv: PFileVar; b: byte);
var
  d: array[0..2] of char;
begin
with fv^ do begin
  if LogCount= 16 then
  begin
    LogCount := 0;
    _lwrite(LogFile,#$0D#$0A,2);
  end;

  case b of
    $00..$9F: d[0] := char(b shr 4 + $30);
    $A0..$FF: d[0] := char(b shr 4 + $37);
  end;
  case b and $0F of
    $0..$9: d[1] := char(b and $0F + $30);
    $A..$F: d[1] := char(b and $0F + $37);
  end;
  d[2] := #$20;
  _lwrite(LogFile,d,3);
  inc(LogCount);
end;
end;

procedure FTSetTimeOut(fv: PFileVar; T: integer);
begin
  KillTimer(fv^.HMainWin, IdProtoTimer);
  if T=0 then exit;
  SetTimer(fv^.HMainWin, IdProtoTimer, T*1000, nil);
end;

{Hook function for file name dialog box}
function TFnHook(Dialog: HWnd; Message: integer; WParam: Word; LParam: Longint): Bool; export;
var
  ofn: POpenFileName;
  L, H: word;
  pl: PLongint;
{$ifdef TERATERM32}
  notify: POFNotify;
{$endif}
begin
  case Message of
    WM_INITDIALOG:
      begin
        ofn := POpenFileName(lParam);
        pl := PLongint(ofn^.lCustData);
        SetWindowLong(Dialog, DWL_USER, longint(pl));
        L := LoWord(pl^) and 1;
        H := HiWord(pl^);
        SetRB(Dialog,L,IDC_FOPTBIN,IDC_FOPTBIN);
        if H<>$FFFF then
        begin
          ShowDlgItem(Dialog,IDC_FOPTAPPEND,IDC_FOPTAPPEND);
          SetRB(Dialog,H and 1,IDC_FOPTAPPEND,IDC_FOPTAPPEND);
        end;
        TFnHook := TRUE;
        exit;
      end;
    WM_COMMAND: {for old style dialog}
      case LOWORD(wParam) of
        IDOK: begin
          pl := PLongint(GetWindowLong(Dialog, DWL_USER));
          if pl<>nil then
          begin
            GetRB(Dialog,L,IDC_FOPTBIN,IDC_FOPTBIN);
            H := HiWord(pl^);
            if H<>$FFFF then
              GetRB(Dialog,H,IDC_FOPTAPPEND,IDC_FOPTAPPEND);
            pl^ := MakeLong(L,H);
          end;
        end;
        IDCANCEL: ;
      end;
{$ifdef TERATERM32}
    WM_NOTIFY: {for Explorer-style dialog}
    begin
      notify := POFNotify(lParam);
      case notify^.hdr.code of
        CDN_FILEOK: begin
          pl := PLongint(GetWindowLong(Dialog,DWL_USER));
          if pl<>nil then
          begin
            GetRB(Dialog,L,IDC_FOPTBIN,IDC_FOPTBIN);
            H := HiWord(pl^);
            if H<>$FFFF then
              GetRB(Dialog,H,IDC_FOPTAPPEND,IDC_FOPTAPPEND);
            pl^ := MakeLong(L,H);
          end;
        end;
      end;
{$endif}
  end;
  TFnHook := FALSE;
end;

function GetTransFname(fv: PFileVar; CurDir: PChar; FuncId: word; Option: Plongint): bool;
var
  FNFilter: array [0..10] of char;
  ofn: TOpenFileName;
  opt: longint;
  TempDir: array[0..MAXPATHLEN-1] of char;
  Ok: BOOL;
begin
  GetTransFname := FALSE;
  {save current dir}
  GetCurDir(TempDir,0);

  fv^.FullName[0] := #0;
  FillChar(FNFilter, SizeOf(FNFilter), #0);  { Set up for double null at end }
  FillChar(ofn, SizeOf(TOpenFileName), #0);

  StrCopy(fv^.DlgCaption,'Tera Term: ');
  case FuncId of
    GTF_SEND: StrCat(fv^.DlgCaption,'Send file');
    GTF_LOG: StrCat(fv^.DlgCaption,'Log');
    GTF_BP: StrCat(fv^.DlgCaption,'B-Plus Send');
  else
    exit;
  end;

  StrCopy(FNFilter, 'all');
  StrCopy(@FNFilter[StrLen(FNFilter)+1], '*.*');      

  with ofn do
  begin
    lStructSize   := sizeof(TOpenFileName);
    hwndOwner     := fv^.HMainWin;
    lpstrFilter   := FNFilter;
    nFilterIndex := 1;
    lpstrFile := fv^.FullName;
    nMaxFile := SizeOf(fv^.FullName);
    lpstrInitialDir := CurDir;
    Flags := OFN_SHOWHELP or OFN_HIDEREADONLY;
    if FuncId<>GTF_BP then
    begin
      Flags := Flags or OFN_ENABLETEMPLATE or OFN_ENABLEHOOK;
{$ifdef TERATERM32}
      if IS_WIN4 then
      begin
        Flags := Flags or OFN_EXPLORER;
        lpTemplateName := PChar(IDD_FOPT);
      end
      else
        lpTemplateName := PChar(IDD_FOPTOLD);
{$else}
      lpTemplateName := PChar(IDD_FOPTOLD);
      @lpfnHook := MakeProcInstance(@TFnHook, HInstance);
{$endif}
    end;
    opt := Option^;
    if FuncId<>GTF_LOG then
    begin
      Flags := Flags or OFN_FILEMUSTEXIST;
      opt := MAKELONG(LOWORD(Option^),$FFFF);
    end;
    lCustData := Longint(@opt);
    lpstrTitle := fv^.DlgCaption;
  end;
  ofn.hInstance := hinstance;

  Ok := GetOpenFileName(ofn);
{$ifndef TERATERM32}
  FreeProcInstance(@ofn.lpfnHook);
{$endif}

  if Ok then
  begin
    if FuncId=GTF_LOG then
      Option^ := opt
    else
      Option^ := MAKELONG(LOWORD(opt),HIWORD(Option^));

    fv^.DirLen := ofn.nFileOffset;

{$ifdef TERATERM32}
    {for Win NT 3.5: short name -> long name}
    GetLongFName(fv^.FullName,@fv^.FullName[fv^.DirLen]);
{$endif}

    if CurDir<>nil then
    begin
      Move(fv^.FullName[0],CurDir[0],fv^.DirLen-1);
      CurDir[fv^.DirLen-1] := #0;
    end;
  end;

  {restore dir}
  SetCurDir(TempDir);

  GetTransFname := Ok;
end;

procedure AddNum(FName: PChar; n: integer);
var
  NumStr: string[10];
  Num: array[0..10] of char;
  i, j, k, dLen: integer;
begin
  Str(n,NumStr);
  StrPCopy(Num,NumStr);
  GetFileNamePos(FName,i,j);
  k := strlen(FName);
  while (k>j) and (FName[k]<>'.') do
    dec(k);
  if FName[k]<>'.' then k := strlen(FName);
  dLen := strlen(Num);

  if strlen(FName)+dLen > MAXPATHLEN - 1 then
    dLen := MAXPATHLEN - 1 - strlen(FName);
{$ifndef TERATERM32}
  if k - j + dLen > 8 then
    dLen := 8 - k + j;
{$endif}
  Move(FName[k],FName[k+dLen],strlen(FName)-k+1);
  Move(Num[0],FName[k+dLen-strlen(Num)],strlen(Num));
end;

function FTCreateFile(fv: PFileVar): BOOL;
var
  i: integer;
  Temp: array[0..MAXPATHLEN-1] of char;
begin
with fv^ do begin
  FitFileName(@FullName[DirLen],nil);
  if not OverWrite then
  begin
    i := 0;
    strcopy(Temp,FullName);
    while DoesFileExist(Temp) do
    begin
      inc(i);
      strcopy(Temp,FullName);
      AddNum(Temp,i);
    end;
    strcopy(FullName,Temp);
  end;
  FileHandle := _lcreat(FullName,0);
  FileOpen := FileHandle>0;
  if not FileOpen and not NoMsg then
    MessageBox(HMainWin,'Cannot create file','Tera Term: Error',
               MB_ICONEXCLAMATION);
  FTCreateFile := FileOpen;
  SetDlgItemText(HWin, IDC_PROTOFNAME, @FullName[DirLen]);
  ByteCount := 0;
  FileSize := 0;
end;
end;

end.