{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, CTL3D interface}
unit TTCtl3D;

interface

uses WinTypes, WinProcs, Strings, WinDos, Types, TTLib;


function LoadCtl3d: bool;
procedure FreeCtl3d;
procedure SysColorChange;
procedure SubClassDlg(hDlg: HWND);

implementation

var
  HCtl3d: THandle;

type
  TCtl3dColorChange = function: bool;
  TCtl3dAutoSubclass = function(hinstApp: THandle): bool;
  TCtl3dRegister = function(hinstApp: THandle): bool;
  TCtl3dUnregister = function(hinstApp: THandle): bool;
  TCtl3dSubclassDlgEx = function(hwndDlg: HWND; grbit: longint): bool;
var
  Ctl3dColorChange: TCtl3dColorChange;
  Ctl3dAutoSubclass: TCtl3dAutoSubclass;
  Ctl3dRegister: TCtl3dRegister;
  Ctl3dUnregister: TCtl3dUnregister;
  Ctl3dSubclassDlgEx: TCtl3dSubclassDlgEx;

function LoadCtl3d: bool;
var
  FN: array[0..MAXPATHLEN-1] of char;
  SearchRec: TSearchRec;
  Err: boolean;
begin
  if HCtl3d >= HINSTANCE_ERROR then
  begin
    LoadCtl3d := TRUE;
    exit;
  end
  else
    LoadCtl3d := FALSE;

  GetSystemDirectory(FN,SizeOf(FN));
  StrCat(FN,'\CTL3DV2.DLL');
  if not DoesFileExist(FN) then
  begin
    GetSystemDirectory(FN,SizeOf(FN));
    StrCat(FN,'\CTL3D.DLL');
    if not DoesFileExist(FN) then exit;
  end;

  HCtl3d := LoadLibrary(FN);
  if HCtl3d < HINSTANCE_ERROR then exit;

  Err := FALSE;
  @Ctl3dColorChange := GetProcAddress(HCtl3d, 'CTL3DCOLORCHANGE');
  if @Ctl3dColorChange=nil then Err := TRUE;

  @Ctl3dAutoSubclass := GetProcAddress(HCtl3d, 'CTL3DAUTOSUBCLASS');
  if @Ctl3dAutoSubclass=nil then Err := TRUE;

  @Ctl3dRegister := GetProcAddress(HCtl3d, 'CTL3DREGISTER');
  if @Ctl3dRegister=nil then Err := TRUE;

  @Ctl3dUnregister := GetProcAddress(HCtl3d, 'CTL3DUNREGISTER');
  if @Ctl3dUnregister=nil then Err := TRUE;

  {This may not exist in an old version of CTL3D}
  @Ctl3dSubclassDlgEx := GetProcAddress(HCtl3d, 'CTL3DSUBCLASSDLGEX');

  if Err then
  begin
    FreeLibrary(HCtl3d);
    HCtl3d := 0;
  end
  else begin
    LoadCtl3d := TRUE;
    Ctl3dRegister(HInstance);
    Ctl3dAutoSubclass(HInstance);
  end;
end;

procedure FreeCtl3d;
begin
  if HCtl3d >= HINSTANCE_ERROR then
  begin
    Ctl3dUnregister(HInstance);
    FreeLibrary(HCtl3d);
    HCtl3d := 0;
  end;
end;

procedure SysColorChange;
begin
  if HCtl3d < HINSTANCE_ERROR then exit;
  Ctl3dColorChange;
end;

procedure SubclassDlg(hDlg: HWND);
begin
  if (HCtl3d>=HINSTANCE_ERROR) and
     (@Ctl3dSubclassDlgEx<>nil) then
    Ctl3dSubclassDlgEx(hDlg,$0000ffff);
end;

begin
  HCtl3d := 0;
end.