{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TTFILE.DLL, file transfer, VT window printing}
library TTFile;
{$R ttfile.res}
{$I teraterm.inc}

{$IFDEF Delphi}
uses Messages, WinTypes, WinProcs, CommDlg, Strings, WinDos, ShellAPI,
     TTTypes, TTFTypes, Types, DlgLib, Kermit, XMODEM,
     ZMODEM, BPlus, QuickVAN, TTLib, FTLib;
{$ELSE}
uses WinTypes, WinProcs, Win31, CommDlg, Strings, WinDos, ShellAPI,
     TTTypes, Types, TTFTypes, DlgLib, Kermit, XMODEM,
     ZMODEM, BPlus, QuickVAN, TTLib, FTLib;
{$ENDIF}

{$i file_res.inc}

{$ifdef TERATERM32}
function IS_WIN4: BOOL;
var
  verinfo: TOSVERSIONINFO;
begin
  IS_WIN4 := FALSE;
  verinfo.dwOSVersionInfoSize := sizeof(verinfo);
  if not GetVersionEx(verinfo) then exit;
  IS_WIN4 := verinfo.dwMajorVersion>=4;    
end;
{$endif}

function GetSetupFname(HWin: HWnd; FuncId: word; ts: PTTSet): BOOL; export;
var
  i, j: integer;
  ofn: TOpenFileName;
  Ptr: integer;
  FNameFilter: array [0..80] of char;
  TempDir: array[0..MAXPATHLEN-1] of char;
  Dir: array[0..MAXPATHLEN-1] of char;
  Name: array[0..MAXPATHLEN-1] of char;
  Ok: bool;
begin 
  {save current dir}
  GetCurDir(TempDir,0);

  {File name filter}
  FillChar(FNameFilter, SizeOf(FNameFilter), #0);
  if FuncId=GSF_LOADKEY then
  begin
    StrCopy(FNameFilter, 'keyboard setup files (*.cnf)');
    Ptr := StrLen(FNameFilter) + 1;
    StrCopy(@FNameFilter[Ptr], '*.cnf');
  end
  else begin 
    StrCopy(FNameFilter, 'setup files (*.ini)');
    Ptr := StrLen(FNameFilter) + 1;
    StrCopy(@FNameFilter[Ptr], '*.ini');
  end;

  {TOpenFileName record}
  FillChar(ofn, SizeOf(TOpenFileName), #0);
  with ofn do
  begin
    lStructSize   := sizeof(TOpenFileName);
    hwndOwner     := HWin;
    lpstrFile     := Name;
    nMaxFile      := SizeOf(Name);
    lpstrFilter   := FNameFilter;
    nFilterIndex  := 1;
  end;
  ofn.hInstance := hInstance;

  if FuncId=GSF_LOADKEY then
  begin
    ofn.lpstrDefExt := 'cnf';
    GetFileNamePos(ts^.KeyCnfFN,i,j);
    StrCopy(Name,@ts^.KeyCnfFN[j]);
    Move(ts^.KeyCnfFN[0],Dir[0],i);
    Dir[i] := #0;

    if (StrLen(Name)=0) or (StrIComp(Name,'KEYBOARD.CNF')=0) then
      StrCopy(Name,'KEYBOARD.CNF');
  end
  else begin
    ofn.lpstrDefExt := 'ini';
    GetFileNamePos(ts^.SetupFName,i,j);
    StrCopy(Name,@ts^.SetupFName[j]);
    Move(ts^.SetupFName[0],Dir[0],i);
    Dir[i] := #0;

    if (StrLen(Name)=0) or (StrIComp(Name,'TERATERM.INI')=0) then
      StrCopy(Name,'TERATERM.INI');
  end;

  if StrLen(Dir)=0 then
    StrCopy(Dir,ts^.HomeDir);

  SetCurDir(Dir);

  ofn.Flags := OFN_SHOWHELP or OFN_HIDEREADONLY;
  case FuncId of
    GSF_SAVE: begin
      ofn.lpstrTitle := 'Tera Term: Save setup';
      Ok := GetSaveFileName(ofn);
      if Ok then strcopy(ts^.SetupFName,Name);
    end;
    GSF_RESTORE: begin
      ofn.Flags := ofn.Flags or OFN_FILEMUSTEXIST;
      ofn.lpstrTitle := 'Tera Term: Restore setup';
      Ok := GetOpenFileName(ofn);
      if Ok then strcopy(ts^.SetupFName,Name);
    end;
    GSF_LOADKEY: begin
      ofn.Flags := ofn.Flags or OFN_FILEMUSTEXIST;
      ofn.lpstrTitle := 'Tera Term: Load key map';
      Ok := GetOpenFileName(ofn);
      if Ok then strcopy(ts^.KeyCnfFN,Name);
    end;
  end;

  {restore dir}
  SetCurDir(TempDir);

  GetSetupFname := Ok;
end; 

function TFn2Hook(Dialog: HWnd; Message: integer; wParam: Word; lParam: Longint): Bool; export;
var
  ofn: POpenFileName;
  pw: Pword;
{$ifdef TERATERM32}
  notify: POFNotify;  
{$endif}
begin
  case Message of
    WM_INITDIALOG:
      begin
        ofn := POpenFileName(lParam);
        pw := Pword(ofn^.lCustData);
        SetWindowLong(Dialog, DWL_USER, longint(pw));
        SetRB(Dialog,pw^ and 1,IDC_FOPTBIN,IDC_FOPTBIN);
        TFn2Hook := TRUE;
        exit;
      end;
    WM_COMMAND: {for old style dialog}
      case LOWORD(wParam) of
        IDOK: begin
          pw := Pword(GetWindowLong(Dialog,DWL_USER));
          if pw<>nil then
            GetRB(Dialog,pw^,IDC_FOPTBIN,IDC_FOPTBIN);
        end;
        IDCANCEL: ;
      end;
{$ifdef TERATERM32}
    WM_NOTIFY: begin {for Explorer-style dialog}
      notify := POFNotify(lParam);
      case notify^.hdr.code of
        CDN_FILEOK: begin
          pw := Pword(GetWindowLong(Dialog,DWL_USER));
          if pw<>nil then
            GetRB(Dialog,pw^,IDC_FOPTBIN,IDC_FOPTBIN);
        end;
      end;
    end;
{$endif}
  end;
  TFn2Hook := FALSE;
end;

function GetMultiFname(fv: PFileVar; CurDir: PChar; FuncId: word; Option: PWord): bool; export;
var
  i, len: integer;
  FNFilter: array [0..10] of Char;
  ofn: TOpenFileName;
  TempDir: array[0..MAXPATHLEN-1] of char;
  Ok: BOOL;
begin
  GetMultiFname := FALSE;
  {save current dir}
  GetCurDir(TempDir,0);

  fv^.NumFname := 0;

  StrCopy(fv^.DlgCaption,'Tera Term: ');
  case FuncId of
    GMF_Kermit: StrCat(fv^.DlgCaption,'Kermit Send');
    GMF_Z: StrCat(fv^.DlgCaption,'ZMODEM Send');
    GMF_QV: StrCat(fv^.DlgCaption,'Quick-VAN Send');
  else
    exit;
  end;

  {memory should be zero-initialized}
  fv^.FnStrMemHandle := GlobalAlloc(GHND, FnStrMemSize);
  if fv^.FnStrMemHandle = 0 then
  begin
    MessageBeep(0);
    exit;
  end
  else begin
    fv^.FnStrMem := GlobalLock(fv^.FnStrMemHandle);
    if fv^.FnStrMem = nil
    then begin
      GlobalFree(fv^.FnStrMemHandle);
      fv^.FnStrMemHandle := 0;
      MessageBeep(0);
      exit;
    end
  end;

  FillChar(FNFilter, SizeOf(FNFilter), #0);  { Set up for double null at end }
  StrCopy(FNFilter, 'all');
  StrCopy(@FNFilter[StrLen(FNFilter)+1], '*.*');
  FillChar(ofn, SizeOf(TOpenFileName), #0);
  with ofn do
  begin
    lStructSize   := sizeof(TOpenFileName);
    hwndOwner     := fv^.HMainWin;
    lpstrFilter   := FNFilter;
    nFilterIndex := 1;
    lpstrFile := fv^.FnStrMem;
    nMaxFile := FnStrMemSize;
    lpstrTitle:= fv^.DlgCaption;
    lpstrInitialDir := CurDir;
    Flags := OFN_SHOWHELP or OFN_ALLOWMULTISELECT or
             OFN_FILEMUSTEXIST or OFN_HIDEREADONLY;
{$ifdef TERATERM32}
    if IS_WIN4 then
      Flags := Flags or OFN_EXPLORER;
{$endif}
    lCustData := 0;
  end;

  if FuncId=GMF_Z then
  begin
    ofn.Flags := ofn.Flags or OFN_ENABLETEMPLATE or OFN_ENABLEHOOK;
    ofn.lCustData := longint(Option);
{$ifdef TERATERM32}
    @ofn.lpfnHook := @TFn2Hook;
    if IS_WIN4 then
      ofn.lpTemplateName := PChar(IDD_FOPT)
    else
      ofn.lpTemplateName := PChar(IDD_ZOPTOLD);
{$else}
    @ofn.lpfnHook := MakeProcInstance(@TFn2Hook, HInstance);
    ofn.lpTemplateName := PChar(IDD_ZOPTOLD);
{$endif}
  end;
  ofn.hInstance := hinstance;

  Ok := GetOpenFileName(ofn);
{$ifndef TERATERM32}
  FreeProcInstance(@ofn.lpfnHook);
{$endif}

  if Ok then
  begin
{$ifdef TERATERM32}
    if not IS_WIN4 then
    begin {for old style dialog}
{$endif}
      i := 0;
      repeat {replace space by NULL}
        if fv^.FnStrMem[i]=' ' then
          fv^.FnStrMem[i] := #0;
        inc(i);
      until fv^.FnStrMem[i]=#0;
{$ifdef TERATERM32}
    end;
{$endif}
    {count number of file names}
    len := strlen(fv^.FnStrMem);
    i := 0;
    while len>0 do
    begin
      i := i + len + 1;
      inc(fv^.NumFname);
      len := strlen(@fv^.FnStrMem[i]);
    end;

    dec(fv^.NumFname);

    if fv^.NumFname<1 then
    begin {single selection}
      fv^.NumFname := 1;
      fv^.DirLen := ofn.nFileOffset;
      StrCopy(fv^.FullName,fv^.FnStrMem);
      fv^.FnPtr := 0;
{$ifdef TERATERM32}
      {for Win NT 3.5: short name -> long name}
      GetLongFName(fv^.FullName,@fv^.FullName[fv^.DirLen]);
{$endif}
    end
    else begin {multiple selection}
      strcopy(fv^.FullName,fv^.FnStrMem);
      AppendSlash(fv^.FullName);
      fv^.DirLen := strlen(fv^.FullName);
      fv^.FnPtr := strlen(fv^.FnStrMem) + 1;
    end;

    Move(fv^.FullName[0],CurDir[0],fv^.DirLen);
    CurDir[fv^.DirLen] := #0;
    if (fv^.DirLen>3) and (CurDir[fv^.DirLen-1]='\') then
      CurDir[fv^.DirLen-1] := #0;

    fv^.FNcount := 0;
  end;

  GlobalUnlock(fv^.FnStrMemHandle);
  if not Ok then
  begin
    GlobalFree(fv^.FnStrMemHandle);
    fv^.FnStrMemHandle := 0;
  end;

  {restore dir}
  SetCurDir(TempDir);

  GetMultiFname := Ok;
end;

function GetFnDlg(Dialog: HWnd; Message: integer; wParam: Word;
  lParam: Longint): Bool; export;
var
  fv: PFileVar;
  TempFull: array[0..MAXPATHLEN-1] of char;
  i, j: integer;
begin
  GetFnDlg := TRUE;
  case Message of
    WM_INITDIALOG:
      begin
        fv := PFileVar(lParam);
        SetWindowLong(Dialog, DWL_USER, lParam);
        SendDlgItemMessage(Dialog, IDC_GETFN, EM_LIMITTEXT, SizeOf(TempFull)-1,0);
        exit;
      end;
    WM_COMMAND:
      begin
        fv := PFileVar(GetWindowLong(Dialog,DWL_USER));
        case LOWORD(wParam) of
          IDOK: begin
            if fv<>nil then
            begin
              with fv^ do begin
                GetDlgItemText(Dialog, IDC_GETFN, TempFull, SizeOf(TempFull));
                if StrLen(TempFull)=0 then exit;
                GetFileNamePos(TempFull,i,j);
                FitFileName(@TempFull[j],nil);
                StrCat(FullName,@TempFull[j]);
              end;
            end;
            EndDialog(Dialog, 1);
            exit;
          end;
          IDCANCEL: begin
            EndDialog(Dialog, 0);
            exit;
          end;
          IDC_GETFNHELP:
            if fv<>nil then            
              PostMessage(fv^.HMainWin,WM_USER_DLGHELP2,0,0);
        end;
      end;
  end;
  GetFnDlg := FALSE;
end;

function GetGetFname(HWin: HWnd; fv: PFileVar): Bool; export;
{$ifndef TERATERM32}
var
  GetFnProc: TFarProc;
{$endif}
begin
{$ifdef TERATERM32}
  GetGetFname := Bool(DialogBoxParam(hInstance,
    PChar(IDD_GETFNDLG), HWin, @GetFnDlg, longint(fv));
{$else}
  GetFnProc := MakeProcInstance(@GetFnDlg, hInstance);
  GetGetFname := Bool(DialogBoxParam(hInstance,
    PChar(IDD_GETFNDLG), HWin, GetFnProc, longint(fv)));
  FreeProcInstance(GetFnProc);
{$endif}
end;

procedure SetFileVar(fv: PFileVar); export;
var
  i: integer;
begin
with fv^ do begin
  GetFileNamePos(FullName,DirLen,i);
  if FullName[DirLen]='\' then inc(DirLen);
  StrCopy(DlgCaption,'Tera Term: ');
  case OpId of
    OpLog:      StrCat(DlgCaption,TitLog);
    OpSendFile: StrCat(DlgCaption,TitSendFile);
    OpKmtRcv:   StrCat(DlgCaption,TitKmtRcv);
    OpKmtGet:   StrCat(DlgCaption,TitKmtGet);
    OpKmtSend:  StrCat(DlgCaption,TitKmtSend);
    OpKmtFin:   StrCat(DlgCaption,TitKmtFin);
    OpXRcv:     StrCat(DlgCaption,TitXRcv);
    OpXSend:    StrCat(DlgCaption,TitXSend);
    OpZRcv:     StrCat(DlgCaption,TitZRcv);
    OpZSend:    StrCat(DlgCaption,TitZSend);
    OpBPRcv:     StrCat(DlgCaption,TitBPRcv);
    OpBPSend:    StrCat(DlgCaption,TitBPSend);
    OpQVRcv:     StrCat(DlgCaption,TitQVRcv);
    OpQVSend:    StrCat(DlgCaption,TitQVSend);
  end;
end;
end;

{Hook function for XMODEM file name dialog box}
function XFnHook(Dialog: HWnd; Message: integer; wParam: Word; lParam: Longint): Bool; export;
var
  ofn: POpenFileName;
  H, L: word;
  pl: Plongint;
{$ifdef TERATERM32}
  notify: POFNotify;
{$endif}
begin
  case Message of
    WM_INITDIALOG:
      begin
        ofn := POpenFileName(lParam);
        pl := Plongint(ofn^.lCustData);
        SetWindowLong(Dialog, DWL_USER, longint(pl));
        SetRB(Dialog,HIWORD(pl^),IDC_XOPTCHECK,IDC_XOPT1K);
        if LOWORD(pl^)<>$FFFF then
        begin
          ShowDlgItem(Dialog,IDC_XOPTBIN,IDC_XOPTBIN);
          SetRB(Dialog,LOWORD(pl^),IDC_XOPTBIN,IDC_XOPTBIN);
        end;
        XFnHook := TRUE;
        exit;
      end;
    WM_COMMAND:
      case LOWORD(wParam) of
        IDOK: begin
          pl := Plongint(GetWindowLong(Dialog,DWL_USER));
          if pl<>nil then
          begin
            GetRB(Dialog,H,IDC_XOPTCHECK,IDC_XOPT1K);
            if LOWORD(pl^)=$FFFF then
              L := $FFFF
            else
              GetRB(Dialog,L,IDC_XOPTBIN,IDC_XOPTBIN);
            pl^ := MAKELONG(L,H);
          end;
        end;
        IDCANCEL: ;
      end;
{$ifdef TERATERM32}
    WM_NOTIFY: {for Explorer-style dialog}
      notify := POFNotify(lParam);
      case notify^.hdr.code of
        CDN_FILEOK: begin
          pl := Plongint(GetWindowLong(Dialog,DWL_USER));
          if pl<>nil then
          begin
            GetRB(Dialog,H,IDC_XOPTCHECK,IDC_FOPT1K);
            if LOWORD(pl^)=$FFFF then
              L := $FFFF
            else
              GetRB(Dialog,L,IDC_XOPTBIN,IDC_XOPTBIN);
            pl^ := MAKELONG(L,H);
          end;
        end;
      end;
{$endif}
  end;
  XFnHook := FALSE;
end;

function GetXFname
  (HWin: HWnd; Receive: bool; Option: Plongint; fv: PFileVar; CurDir: PChar): Bool; export;
var
  FNFilter: array [0..10] of Char;
  ofn: TOpenFileName;
  opt: longint;
  TempDir: array[0..MAXPATHLEN-1] of char;
  Ok: BOOL;
begin
  GetXFname := FALSE;
  {save current dir}
  GetCurDir(TempDir,0);

  fv^.FullName[0] := #0;
  FillChar(FNFilter, SizeOf(FNFilter), #0);  { Set up for double null at end }
  FillChar(ofn, SizeOf(TOpenFileName), #0);

  StrCopy(fv^.DlgCaption,'Tera Term: XMODEM ');
  if Receive then
    StrCat(fv^.DlgCaption,'Receive')
  else
    StrCat(fv^.DlgCaption,'Send');

  StrCopy(FNFilter, 'all');
  StrCopy(@FNFilter[StrLen(FNFilter)+1], '*.*');      

  with ofn do
  begin
    lStructSize   := sizeof(TOpenFileName);
    hwndOwner     := HWin;
    lpstrFilter   := FNFilter;
    nFilterIndex := 1;
    lpstrFile := fv^.FullName;
    nMaxFile := SizeOf(fv^.FullName);
    lpstrInitialDir := CurDir;
    flags := OFN_SHOWHELP or OFN_HIDEREADONLY or
             OFN_ENABLETEMPLATE or OFN_ENABLEHOOK;
    opt := Option^;
    if not Receive then
    begin
      Flags := Flags or OFN_FILEMUSTEXIST;
      opt := opt or $FFFF;
    end;
    lCustData := longint(@opt);
    lpstrTitle := fv^.DlgCaption;
{$ifdef TERATERM32}
    @lpfnHook := @XFnHook;
    if IS_WIN4 then
    begin
      Flags := Flags or OFN_EXPLORER;
      lpTemplateName := PChar(IDD_XOPT);
    end
    else
      lpTemplateName := PChar(IDD_XOPTOLD);
{$else}
    @lpfnHook := MakeProcInstance(@XFnHook, HInstance);
    lpTemplateName := PChar(IDD_XOPTOLD);
{$endif}
  end;
  ofn.hInstance := hinstance;

  Ok := GetOpenFileName(ofn);
{$ifndef TERATERM32}
  FreeProcInstance(@ofn.lpfnHook);
{$endif}

  if Ok then
  begin
    fv^.DirLen := ofn.nFileOffset;
    fv^.FnPtr := ofn.nFileOffSet;
    Move(fv^.FullName[0],CurDir[0],fv^.DirLen-1);
    CurDir[fv^.DirLen-1] := #0;

    if Receive then
      Option^ := opt
    else
      Option^ := MAKELONG(LOWORD(Option^),HIWORD(opt));
  end;

  {restore dir}
  SetCurDir(TempDir);

  GetXFname := Ok;
end;

procedure ProtoInit
  (Proto: integer; fv: PFileVar; pv: pointer; cv: PComVar; ts: PTTSet); export;
begin
  case Proto of
    PROTO_KMT:
      KmtInit(fv,pv,cv,ts);
    PROTO_XM:
      XInit(fv,pv,cv,ts);
    PROTO_ZM:
      ZInit(fv,pv,cv,ts);
    PROTO_BP:
      BPInit(fv,pv,cv,ts);
    PROTO_QV:
      QVInit(fv,pv,cv,ts);
  end;
end;

function ProtoParse
  (Proto: integer; fv: PFileVar; pv: pointer; cv: PComVar): BOOL; export;
var
  Ok: BOOL;
begin
  Ok := FALSE;
  case Proto of
    PROTO_KMT:
      Ok := KmtReadPacket(fv,pv,cv);
    PROTO_XM: begin
        case PXVar(pv)^.XMode of
	  IdXReceive:
	    Ok := XReadPacket(fv,pv,cv);
	  IdXSend:
	    Ok := XSendPacket(fv,pv,cv);
        end;
      end;
    PROTO_ZM:
      Ok := ZParse(fv,pv,cv);
    PROTO_BP:
      Ok := BPParse(fv,pv,cv);
    PROTO_QV: begin
        case PQVVar(pv)^.QVMode of
	  IdQVReceive:
	    Ok := QVReadPacket(fv,pv,cv);
	  IdQVSend:
	    Ok := QVSendPacket(fv,pv,cv);
        end;
      end;
  end;
  ProtoParse := Ok;
end;

procedure ProtoTimeOutProc(Proto: integer; fv: PFileVar; pv: pointer; cv: PComVar); export;
begin
  case Proto of
    PROTO_KMT:
      KmtTimeOutProc(fv,pv,cv);
    PROTO_XM:
      XTimeOutProc(fv,pv,cv);
    PROTO_ZM:
      ZTimeOutProc(fv,pv,cv);
    PROTO_BP:
      BPTimeOutProc(fv,pv,cv);
    PROTO_QV:
      QVTimeOutProc(fv,pv,cv);
  end;
end;

function ProtoCancel
  (Proto: integer; fv: PFileVar; pv: pointer; cv: PComVar): BOOL; export;
begin
  case Proto of
    PROTO_KMT:
      KmtCancel(fv,pv,cv);
    PROTO_XM:
      if PXVar(pv)^.XMode=IdXReceive then
        XCancel(fv,pv,cv);
    PROTO_ZM:
      ZCancel(pv);
    PROTO_BP:
      if PBPVar(pv)^.BPState <> BP_Failure then
      begin
	BPCancel(pv);
        ProtoCancel := FALSE;
        exit;
      end;
    PROTO_QV:
      QVCancel(fv,pv,cv);
  end;
  ProtoCancel := TRUE;
end;

exports
  GetSetupFname      index 1, 
  GetTransFname      index 2,
  GetMultiFname      index 3,
  GetGetFname        index 4,
  SetFileVar         index 5,
  GetXFname          index 6,

  ProtoInit          index 7,
  ProtoParse         index 8,
  ProtoTimeOutProc   index 9,
  ProtoCancel        index 10;

begin
end.
