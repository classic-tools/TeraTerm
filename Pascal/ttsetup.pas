{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, TTSET interface}
unit TTSetup;

interface

uses WinTypes, WinProcs, TTTypes, Types, TTSTypes;

var
  ReadIniFile: TReadIniFile;
  WriteIniFile: TWriteIniFile;
  ReadKeyboardCnf: TReadKeyboardCnf;
  CopyHostList: TCopyHostList;
  AddHostToList: TAddHostToList;
  ParseParam: TParseParam;

function LoadTTSET: bool;
procedure FreeTTSET;

implementation

uses TTPlug; {TTPLUG}

var
  HTTSET: THandle;

const
  IdReadIniFile     = 1;
  IdWriteIniFile    = 2;
  IdReadKeyboardCnf = 3;
  IdCopyHostList    = 4;
  IdAddHostToList   = 5;
  IdParseParam      = 6;

function LoadTTSET: bool;
var
  Err: bool;
begin
{$ifdef TERATERM32}
  if HTTSET <> 0 then
  begin
    LoadTTSET := TRUE;
    exit;
  end
  else
    LoadTTSET := FALSE;
  HTTSET := LoadLibrary('TTPSET.DLL');
  if HTTSET = 0 then exit;
{$else}
  if HTTSET >= HINSTANCE_ERROR then
  begin
    LoadTTSET := TRUE;
    exit;
  end
  else
    LoadTTSET := FALSE;
  HTTSET := LoadLibrary('TTSET.DLL');
  if HTTSET < HINSTANCE_ERROR then exit;
{$endif}

  Err := FALSE;
  @ReadIniFile := GetProcAddress(HTTSet, PChar(IdReadIniFile));
  if @ReadIniFile=nil then Err := TRUE;
  
  @WriteIniFile := GetProcAddress(HTTSet, PChar(IdWriteIniFile));
  if @WriteIniFile=nil then Err := TRUE;

  @ReadKeyboardCnf := GetProcAddress(HTTSet, PChar(IdReadKeyboardCnf));
  if @ReadKeyboardCnf=nil then Err := TRUE;

  @CopyHostList := GetProcAddress(HTTSet, PChar(IdCopyHostList));
  if @CopyHostList=nil then Err := TRUE;

  @AddHostToList := GetProcAddress(HTTSet, PChar(IdAddHostToList));
  if @AddHostToList=nil then Err := TRUE;

  @ParseParam := GetProcAddress(HTTSet, PChar(IdParseParam));
  if @ParseParam=nil then Err := TRUE;

  if Err then
  begin
    FreeLibrary(HTTSET);
    HTTSET := 0;
    exit;
  end;

  TTXGetSetupHooks; {TTPLUG}

  LoadTTSET := TRUE;
end;

procedure FreeTTSET;
begin
{$ifdef TERATERM32}
  if HTTSET <> 0 then
{$else}
  if HTTSET >= HINSTANCE_ERROR then
{$endif}
  begin
    FreeLibrary(HTTSET);
    HTTSET := 0;
  end;
end;

begin
  HTTSET := 0;
end.
