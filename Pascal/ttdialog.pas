{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, TTDLG interface}
unit TTDialog;

interface
{$i teraterm.inc}

uses WinTypes, WinProcs, TTTypes, Types, TTDTypes;

var
  SetupTerminal: TSetupTerminal;
  SetupWin: TSetupWin;     
  SetupKeyboard: TSetupKeyboard;
  SetupSerialPort: TSetupSerialPort;
  SetupTCPIP: TSetupTCPIP;
  GetHostName: TGetHostName;    
  ChangeDirectory: TChangeDirectory;
  AboutDialog: TAboutDialog;
  ChooseFontDlg: TChooseFontDlg;
  SetupGeneral: TSetupGeneral;
  WindowWindow: TWindowWindow;

function LoadTTDLG: bool;
function FreeTTDLG: bool;

implementation

uses TTPlug; {TTPLUG}

var
  HTTDLG: THandle;
  TTDLGUseCount: integer;

const
  IdSetupTerminal   = 1;
  IdSetupWin        = 2;
  IdSetupKeyboard   = 3;
  IdSetupSerialPort = 4;
  IdSetupTCPIP      = 5;
  IdGetHostName     = 6;
  IdChangeDirectory = 7;
  IdAboutDialog     = 8;
  IdChooseFontDlg   = 9;
  IdSetupGeneral    = 10;
  IdWindowWindow    = 11;

function LoadTTDLG: bool;
var
  Err: Bool;
begin
  LoadTTDLG := FALSE;

{$ifdef TERATERM32}
  if HTTDLG=0 then
{$else}
  if HTTDLG < HINSTANCE_ERROR then
{$endif}
  begin
    TTDLGUseCount := 0;

{$ifdef TERATERM32}
    HTTDLG := LoadLibrary('TTPDLG.DLL');
    if HTTDLG = 0 then exit;
{$else}
    HTTDLG := LoadLibrary('TTDLG.DLL');
    if HTTDLG < HINSTANCE_ERROR then exit;
{$endif}

    Err := FALSE;
    @SetupTerminal := GetProcAddress(HTTDLG, PChar(IdSetupTerminal));
    if @SetupTerminal=nil then Err := TRUE;

    @SetupWin := GetProcAddress(HTTDLG, PChar(IdSetupWin));
    if @SetupWin=nil then Err := TRUE;

    @SetupKeyboard := GetProcAddress(HTTDLG, PChar(IdSetupKeyboard));
    if @SetupKeyboard=nil then Err := TRUE;

    @SetupSerialPort := GetProcAddress(HTTDLG, PChar(IdSetupSerialPort));
    if @SetupSerialPort=nil then Err := TRUE;

    @SetupTCPIP := GetProcAddress(HTTDLG, PChar(IdSetupTCPIP));
    if @SetupTCPIP=nil then Err := TRUE;

    @GetHostName := GetProcAddress(HTTDLG, PChar(IdGetHostName));
    if @GetHostName=nil then Err := TRUE;

    @ChangeDirectory := GetProcAddress(HTTDLG, PChar(IdChangeDirectory));
    if @ChangeDirectory=nil then Err := TRUE;

    @AboutDialog := GetProcAddress(HTTDLG, PChar(IdAboutDialog));
    if @AboutDialog=nil then Err := TRUE;

    @ChooseFontDlg := GetProcAddress(HTTDLG, PChar(IdChooseFontDlg));
    if @ChooseFontDlg=nil then Err := TRUE;

    @SetupGeneral := GetProcAddress(HTTDLG, PChar(IdSetupGeneral));
    if @SetupGeneral=nil then Err := TRUE;

    @WindowWindow := GetProcAddress(HTTDLG, PChar(IdWindowWindow));
    if @WindowWindow=nil then Err := TRUE;

    if Err then
    begin
      FreeLibrary(HTTDLG);
      HTTDLG := 0;
      exit;
    end;

    TTXGetUIHooks; {TTPLUG}
  end;
  inc(TTDLGUseCount);
  LoadTTDLG := TRUE;
end;

function FreeTTDLG: bool;
begin
  FreeTTDLG := FALSE;
  if TTDLGUseCount=0 then exit;
  dec(TTDLGUseCount);
  if TTDLGUseCount>0 then
  begin
    FreeTTDLG := TRUE;
    exit;
  end;
{$ifdef TERATERM32}
  if HTTDLG <> 0 then
{$else}
  if HTTDLG >= HINSTANCE_ERROR then
{$endif}
  begin
    FreeLibrary(HTTDLG);
    HTTDLG := 0;
  end;
end;


begin
  HTTDLG := 0;
  TTDLGUseCount := 0;
end.
