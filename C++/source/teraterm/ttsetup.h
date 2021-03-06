/* Tera Term
 Copyright(C) 1994-1998 T. Teranishi
 All rights reserved. */

/* TERATERM.EXE, TTSET interface */
#ifdef __cplusplus
extern "C" {
#endif

typedef void (PASCAL FAR *PReadIniFile)
  (PCHAR FName, PTTSet ts);
typedef void (PASCAL FAR *PWriteIniFile)
  (PCHAR FName, PTTSet ts);
typedef void (PASCAL FAR *PReadKeyboardCnf)
  (PCHAR FName, PKeyMap KeyMap, BOOL ShowWarning);
typedef void (PASCAL FAR *PCopyHostList)
  (PCHAR IniSrc, PCHAR IniDest);
typedef void (PASCAL FAR *PAddHostToList)
  (PCHAR FName, PCHAR Host);
typedef void (PASCAL FAR *PParseParam)
  (PCHAR Param, PTTSet ts, PCHAR DDETopic);

extern PReadIniFile ReadIniFile;
extern PWriteIniFile WriteIniFile;
extern PReadKeyboardCnf ReadKeyboardCnf;
extern PCopyHostList CopyHostList;
extern PAddHostToList AddHostToList;
extern PParseParam ParseParam;

/* proto types */
BOOL LoadTTSET();
void FreeTTSET();

#ifdef __cplusplus
}
#endif
