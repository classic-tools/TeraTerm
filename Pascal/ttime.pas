{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, IME interface}
unit TTIME;

interface
{$i teraterm.inc}

uses WinTypes, WinProcs, Types, TTTypes, TTWinMan, TTCommon;

function LoadIME: bool;
procedure FreeIME;
function CanUseIME: bool;
procedure SetConversionWindow(HWin: HWnd; X, Y: integer);
procedure SetConversionLogFont(lf: PLOGFONT);

{$ifdef TERATERM32}
function GetConvString(lParam: DWORD): HGLOBAL;
const
  WM_IME_COMPOSITION = $010F;
{$endif}

implementation

{$ifdef TERATERM32}
type
  PCOMPOSITIONFORM = ^COMPOSITIONFORM;
  COMPOSITIONFORM = record
    dwStyle: DWORD;
    ptCurrentPos: TPoint;
    rcArea: TRect;
  end;

const
  GCS_RESULTSTR = $0800;

type
  TImmGetCompositionString =
    function(hI: HIMC; dwIndex: DWORD; lpBuf: pointer; dwBufLen: DWORD): longint; 
  TImmGetContext = function(HWin: HWnd): HIMC;
  TImmReleaseContext = function(HWin: HWnd; hI: HIMC): bool;
  TImmSetCompositionFont = function(hI: HIMC; lplf: PLOGFONT): bool;
  TImmSetCompositionWindow = function(hI: HIMC; lpCompForm: PCOMPOSITIONFORM): bool;

var
  ImmGetCompositionString: TImmGetCompositionString;
  ImmGetContext: TImmGetContext;
  ImmReleaseContext: TImmReleaseContext;
  ImmSetCompositionFont: TImmSetCompositionFont;
  ImmSetCompositionWindow: TImmSetCompositionWindow;
{$else}
type
  PIMEStruct = ^IMEStruct;
  IMEStruct = record
    fnc: word;
    wParam:    word;
    wCount:    word;
    dchSource: word;
    dchDest:   word;
    lParam1:   longint;
    lParam2:   longint;
    lParam3:   longint;
  end;

const
  MCW_DEFAULT = $00;
  MCW_WINDOW  = $02;
  IME_SETCONVERSIONWINDOW = $08;
  IME_SETCONVERSIONFONTEX = $19;

type
  TSendIMEMessageEx = function(HWin: HWnd; lParam: longint): word;
  TWINNLSEnableIME = function(HWin: HWnd; bEnable: bool): bool;

var
  SendIMEMessageEx: TSendIMEMessageEx;
  WINNLSEnableIME: TWINNLSEnableIME;
{$endif}

var
  HIMEDLL: THandle;
  lfIME: TLOGFONT;

function LoadIME: bool;
var
  Err: boolean;
  tempts: PTTSet;
begin
{$ifdef TERATERM32}
  if HIMEDLL <> 0 then
{$else}
  if HIMEDLL >= HINSTANCE_ERROR then
{$endif}
  begin
    LoadIME := TRUE;
    exit;
  end
  else
    LoadIME := FALSE;

{$ifdef TERATERM32}
  HIMEDLL := LoadLibrary('IMM32.DLL');
  if HIMEDLL=0 then
{$else}
  HIMEDLL := LoadLibrary('WINNLS.DLL');
  if HIMEDLL < HINSTANCE_ERROR then
{$endif}
  begin
    MessageBox(0,'Can''t use IME',
               'Tera Term: Error',MB_ICONEXCLAMATION);
    WritePrivateProfileString('Tera Term','IME','off',ts.SetupFName);
    ts.UseIME := 0;
    New(tempts);
    if tempts<>nil then
    begin
      GetDefaultSet(tempts);
      tempts^.UseIME := 0;
      ChangeDefaultSet(tempts,nil);
      Dispose(tempts);
    end;
    exit;
  end;

  Err := FALSE;
{$ifdef TERATERM32}
  @ImmGetCompositionString :=
    GetProcAddress(HIMEDLL,'ImmGetCompositionStringA');
  if @ImmGetCompositionString=nil then Err := TRUE;

  @ImmGetContext :=
    GetProcAddress(HIMEDLL,'ImmGetContext');
  if @ImmGetContext=nil then Err := TRUE;

  @ImmReleaseContext :=
    GetProcAddress(HIMEDLL,'ImmReleaseContext');
  if @ImmReleaseContext=nil then Err := TRUE;

  @ImmSetCompositionFont :=
    GetProcAddress(HIMEDLL,'ImmSetCompositionFontA');
  if @ImmSetCompositionFont=nil then Err := TRUE;

  @ImmSetCompositionWindow :=
    GetProcAddress(HIMEDLL,'ImmSetCompositionWindow');
  if @ImmSetCompositionWindow=nil then Err := TRUE;
{$else}
  @SendIMEMessageEx := GetProcAddress(HIMEDLL, 'SendIMEMessageEx');
  if @SendIMEMessageEx=nil then Err := TRUE;
  
  @WINNLSEnableIME := GetProcAddress(HIMEDLL, 'WINNLSEnableIME');
  if @WINNLSEnableIME=nil then Err := TRUE;
{$endif}
  if Err then
  begin
    FreeLibrary(HIMEDLL);
    HIMEDLL := 0;
  end
  else LoadIME := TRUE;

end;

procedure FreeIME;
var
  HTemp: THandle;
{$ifndef TERATERM32}
  Msg: TMsg;
{$endif}
begin
{$ifdef TERATERM32}
  if HIMEDLL=0 then exit;
{$else}
  if HIMEDLL < HINSTANCE_ERROR then exit;
{$endif}
  HTemp := HIMEDLL;
  HIMEDLL := 0;

  {position of conv. window -> default}
  SetConversionWindow(HVTWin,-1,0);
{$ifdef TERATERM32}
  Sleep(1); {for safety}
{$else}
  PeekMessage(Msg,0,0,0,PM_NOREMOVE);
{$endif}
  FreeLibrary(HTemp);
end;

function CanUseIME: bool;
begin
{$ifdef TERATERM32}
  CanUseIME := HIMEDLL<>0;
{$else}
  CanUseIME := HIMEDLL>=HINSTANCE_ERROR;
{$endif}
end;

procedure SetConversionWindow(HWin: HWnd; X, Y: integer);
var
{$ifdef TERATERM32}
  hI: HIMC;
  cf: COMPOSITIONFORM;
{$else}
  HIME: THandle;
  HIMElf: THandle;
  PIMElf: PLOGFONT;
  PIME: PIMEStruct;
{$endif}
begin
{$ifdef TERATERM32}
  if HIMEDLL = 0 then exit;
  {Adjust the position of conversion window}
  hI := ImmGetContext(HVTWin);
  if X>=0
  begin
    cf.dwStyle = CFS_POINT;
    cf.ptCurrentPos.x = X;
    cf.ptCurrentPos.y = Y;
  end
  else
    cf.dwStyle = CFS_DEFAULT;
  ImmSetCompositionWindow(hI,&cf);

  {Set font for the conversion window}
  ImmSetCompositionFont(hI,&lfIME);
  ImmReleaseContext(HVTWin,hI);
{$else}
  if HIMEDLL < HINSTANCE_ERROR then exit;
  HIME := GlobalAlloc(GMEM_MOVEABLE or GMEM_SHARE,SizeOf(IMEStruct));

  {Set position of conversion window}
  PIME := PIMEStruct(GlobalLock(HIME));
  PIME^.fnc := IME_SETCONVERSIONWINDOW;
  if X<0 then PIME^.wParam := MCW_DEFAULT
         else PIME^.wParam := MCW_WINDOW;
  PIME^.lParam1 := MAKELONG(X,Y);
  GlobalUnlock(HIME);
  SendIMEMessageEx(HWin,longint(HIME));

  {Set font of conversion window}
  HIMElf := GlobalAlloc(GMEM_MOVEABLE or GMEM_SHARE,sizeof(TLOGFONT));
  PIMElf := GlobalLock(HIMElf);
  move(lfIME,PIMElf^,sizeof(TLOGFONT));
  GlobalUnlock(HIMElf);

  PIME := PIMEStruct(GlobalLock(HIME));
  PIME^.fnc := IME_SETCONVERSIONFONTEX;
  if X<0 then
    PIME^.lParam1 := 0
  else
    PIME^.lParam1 := longint(HIMElf);
  GlobalUnlock(HIME);
  SendIMEMessageEx(HWin, longint(HIME));

  GlobalFree(HIME);
  GlobalFree(HIMElf);
{$endif}
end;

procedure SetConversionLogFont(lf: PLOGFONT);
begin
  move(lf^,lfIME,sizeof(TLOGFONT));
end;

{$ifdef TERATERM32}
function GetConvString(lParam: DWORD): HGLOBAL;
var
  hI: HIMC;
  hstr:	HGLOBAL;
  lp: PChar;
  dwSize: DWORD;
begin
  GetConvString := 0;
  if HIMEDLL=0 then exit;
  if (lParam and GCS_RESULTSTR)=0 then exit;
  hI := ImmGetContext(HVTWin);
  if hI=0 then exit;
  {Get the size of the result string.}
  dwSize := ImmGetCompositionString(hI, GCS_RESULTSTR, nil, 0);
  dwSize := dwSize + 2 {sizeof(WCHAR)};
  hstr := GlobalAlloc(GHND,dwSize);
  if hstr <> 0 then
  begin
    lp := GlobalLock(hstr);
    if lp <> nil then
    begin
      {Get the result strings that is generated by IME into lpstr.}
      ImmGetCompositionString
        (hI, GCS_RESULTSTR, lp, dwSize);
      GlobalUnlock(hstr);
    end
    else begin
      GlobalFree(hstr);
      hstr := 0;
    end;
  end;
  ImmReleaseContext(HVTWin, hI);
  GetConvString := hstr;
end;
{$endif}

begin
  HIMEDLL := 0;
end.