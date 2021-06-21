{Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved.}

{TERATERM.EXE, TTSET interface}
unit TTSTypes;

interface

uses WinTypes, TTTypes;

type

TReadIniFile = procedure(FName: PChar; ts: PTTSet);
TWriteIniFile = procedure(FName: PChar; ts: PTTSet);
TReadKeyboardCnf =
  procedure(FName: PChar; KeyMap: PKeyMap; ShowWarning: BOOL);
TCopyHostList = procedure(IniSrc, IniDest: PChar);
TAddHostToList = procedure(FName, Host: PChar);
TParseParam = procedure(Param: PChar; ts: PTTSet; DDETopic: PChar);

implementation

end.
