{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, TTTEK interface}
unit TEKLib;

interface
{$i teraterm.inc}

uses WinTypes, WinProcs, TTTypes, Types, TEKTypes;

type
  TTEKInit = procedure(tk: PTEKVar; ts: PTTSet);
  TTEKResizeWindow = procedure(tk: PTEKVar; ts: PTTSet; W, H: Integer);
  TTEKChangeCaret = procedure(tk: PTEKVar; ts: PTTSet);
  TTEKDestroyCaret = procedure(tk: PTEKVar; ts: PTTSet);
  TTEKParse = function(tk: PTEKVar; ts: PTTSet; cv: PComVar): integer;
  TTEKReportGIN = procedure(tk: PTEKVar; ts: PTTSet; cv: PComVar; KeyCode: byte);
  TTEKPaint = procedure(tk: PTEKVar; ts: PTTSet; PaintDC: HDC; PaintInfo: PPaintStruct);
  TTEKWMLButtonDown = procedure(tk: PTEKVar; ts: PTTSet; cv: PComVar; pos: TPoint);
  TTEKWMLButtonUp = procedure(tk: PTEKVar; ts: PTTSet);
  TTEKWMMouseMove = procedure(tk: PTEKVar; ts: PTTSet; p: TPoint);
  TTEKWMSize = procedure(tk: PTEKVar; ts: PTTSet; W, H, cx, cy: Integer);
  TTEKCMCopy = procedure(tk: PTEKVar; ts: PTTSet);
  TTEKCMCopyScreen = procedure(tk: PTEKVar; ts: PTTSet);
  TTEKPrint = procedure(tk: PTEKVar; ts: PTTSet; PrintDC: HDC; SelFlag: bool);
  TTEKClearScreen = procedure(tk: PTEKVar; ts: PTTSet);
  TTEKSetupFont = procedure(tk: PTEKVar; ts: PTTSet);
  TTEKResetWin = procedure(tk: PTEKVar; ts: PTTSet; EmuOld: word);
  TTEKRestoreSetup = procedure(tk: PTEKVar; ts: PTTSet);
  TTEKEnd = procedure(tk: PTEKVar);

var
  TEKInit: TTEKInit;
  TEKResizeWindow: TTEKResizeWindow;
  TEKChangeCaret: TTEKChangeCaret;
  TEKDestroyCaret: TTEKDestroyCaret;
  TEKParse: TTEKParse;
  TEKReportGIN: TTEKReportGIN;
  TEKPaint: TTEKPaint;
  TEKWMLButtonDown: TTEKWMLButtonDown;
  TEKWMLButtonUp: TTEKWMLButtonUp;
  TEKWMMouseMove: TTEKWMMouseMove;
  TEKWMSize: TTEKWMSize;
  TEKCMCopy: TTEKCMCopy;
  TEKCMCopyScreen :TTEKCMCopyScreen;
  TEKPrint: TTEKPrint;
  TEKClearScreen: TTEKClearScreen;
  TEKSetupFont: TTEKSetupFont;
  TEKResetWin: TTEKResetWin;
  TEKRestoreSetup: TTEKRestoreSetup;
  TEKEnd: TTEKEnd;

function LoadTTTEK: bool;
procedure FreeTTTEK;

implementation

var
  HTTTEK: THandle;

const
  IdTEKInit          = 1;
  IdTEKResizeWindow  = 2;
  IdTEKChangeCaret   = 3;
  IdTEKDestroyCaret  = 4;
  IdTEKParse         = 5;
  IdTEKReportGIN     = 6;
  IdTEKPaint         = 7;
  IdTEKWMLButtonDown = 8;
  IdTEKWMLButtonUp   = 9;
  IdTEKWMMouseMove   = 10;
  IdTEKWMSize        = 11;
  IdTEKCMCopy        = 12;
  IdTEKCMCopyScreen  = 13;
  IdTEKPrint         = 14;
  IdTEKClearScreen   = 15;
  IdTEKSetupFont     = 16;
  IdTEKResetWin      = 17;
  IdTEKRestoreSetup  = 18;
  IdTEKEnd           = 19;

function LoadTTTEK: bool;
var
  Err: bool;
begin
{$ifdef TERATERM32}
  if HTTTEK <> 0 then
{$else}
  if HTTTEK >= HINSTANCE_ERROR then
{$endif}
  begin
    LoadTTTEK := TRUE;
    exit;
  end
  else
    LoadTTTEK := FALSE;

{$ifdef TERATERM32}
  HTTTEK := LoadLibrary('TTPTEK.DLL');
  if HTTTEK = 0 then exit;
{$else}
  HTTTEK := LoadLibrary('TTTEK.DLL');
  if HTTTEK < HINSTANCE_ERROR then exit;
{$endif}

  Err := FALSE;
  @TEKInit := GetProcAddress(HTTTEK, PChar(IdTEKInit));
  if @TEKInit=nil then Err := TRUE;
  
  @TEKResizeWindow := GetProcAddress(HTTTEK, PChar(IdTEKResizeWindow));
  if @TEKResizeWindow=nil then Err := TRUE;

  @TEKChangeCaret := GetProcAddress(HTTTEK, PChar(IdTEKChangeCaret));
  if @TEKChangeCaret=nil then Err := TRUE;

  @TEKDestroyCaret := GetProcAddress(HTTTEK, PChar(IdTEKDestroyCaret));
  if @TEKDestroyCaret=nil then Err := TRUE;

  @TEKParse := GetProcAddress(HTTTEK, PChar(IdTEKParse));
  if @TEKParse=nil then Err := TRUE;

  @TEKReportGIN := GetProcAddress(HTTTEK, PChar(IdTEKReportGIN));
  if @TEKReportGIN=nil then Err := TRUE;

  @TEKPaint := GetProcAddress(HTTTEK, PChar(IdTEKPaint));
  if @TEKPaint=nil then Err := TRUE;

  @TEKWMLButtonDown := GetProcAddress(HTTTEK, PChar(IdTEKWMLButtonDown));
  if @TEKWMLButtonDown=nil then Err := TRUE;

  @TEKWMLButtonUp := GetProcAddress(HTTTEK, PChar(IdTEKWMLButtonUp));
  if @TEKWMLButtonUp=nil then Err := TRUE;

  @TEKWMMouseMove := GetProcAddress(HTTTEK, PChar(IdTEKWMMouseMove));
  if @TEKWMMouseMove=nil then Err := TRUE;

  @TEKWMSize := GetProcAddress(HTTTEK, PChar(IdTEKWMSize));
  if @TEKWMSize=nil then Err := TRUE;

  @TEKCMCopy := GetProcAddress(HTTTEK, PChar(IdTEKCMCopy));
  if @TEKCMCopy=nil then Err := TRUE;

  @TEKCMCopyScreen := GetProcAddress(HTTTEK, PChar(IdTEKCMCopyScreen));
  if @TEKCMCopyScreen=nil then Err := TRUE;

  @TEKPrint := GetProcAddress(HTTTEK, PChar(IdTEKPrint));
  if @TEKPrint=nil then Err := TRUE;

  @TEKClearScreen := GetProcAddress(HTTTEK, PChar(IdTEKClearScreen));
  if @TEKClearScreen=nil then Err := TRUE;

  @TEKSetupFont := GetProcAddress(HTTTEK, PChar(IdTEKSetupFont));
  if @TEKSetupFont=nil then Err := TRUE;

  @TEKResetWin := GetProcAddress(HTTTEK, PChar(IdTEKResetWin));
  if @TEKResetWin=nil then Err := TRUE;

  @TEKRestoreSetup := GetProcAddress(HTTTEK, PChar(IdTEKRestoreSetup));
  if @TEKRestoreSetup=nil then Err := TRUE;

  @TEKEnd := GetProcAddress(HTTTEK, PChar(IdTEKEnd));
  if @TEKEnd=nil then Err := TRUE;

  if Err then
  begin
    FreeLibrary(HTTTEK);
    HTTTEK := 0;
  end
  else LoadTTTEK := TRUE;
end;

procedure FreeTTTEK;
begin
{$ifdef TERATERM32}
  if HTTEK <> 0 then
{$else}
  if HTTTEK >= HINSTANCE_ERROR then
{$endif}
  begin
    FreeLibrary(HTTTEK);
    HTTTEK := 0;
  end;
end;

begin
  HTTTEK := 0;
end.
