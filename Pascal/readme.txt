	Source code of Tera Term version 1.4
	T. Teranishi Mar 10, 1998

	Copyright (C) 1994-1998 T. Teranishi
	All Rights Reserved.

DESCRIPTION
~~~~~~~~~~~
Tera Term version 1.4 is a terminal emulator (telnet client)
for MS-Windows 3.1. For Windows 95/NT, use Tera Term Pro.

This package contains the source code of Tera Term version 1.4,
written in Turbo Pascal for Windows 1.5. You can find the C/C++
source of Tera Term 1.4 and Tera Term Pro 2.3 in the package
TTSRCP23.ZIP.
However, the executable file TERATERM.EXE compiled by the 16-bit
Watcom C/C++ compiler does not support multiple application instances.
Namely, you can not run multiple Tera Term instances at the same time.
Probably, the problem is solved by using the Microsoft 16-bit compiler,
but it has never been tested.
Because of this problem, the released package of Tera Term 1.4 was
actually produced by the Turbo Pascal source code included in this
package. The Turbo Pascal for Windows does not have the
multiple instance problem.

This package also contains a demonstration of the add-on module for
Tera Term. An add-on module is provided as a DLL which can hook
Tera Term user interface functions, setup functions and Winsock
functions. The Tera Term extension interface (TTX) between
Tera Term and add-on modules was developed by Robert O'Callahan
and the Tera Term author, Takashi Teranishi.
If you want to modify Tera Term, please consider a possibility of
making an add-on module instead of modifying Tera Term directly.
Making add-on module simplifies the treatment of copyrights problem
and avoids producing Tera Term variants which does not
compatible with each other. See also the next section for making
and distributing add-on modules.

NOTICE
~~~~~~
There is no warranty for damages caused by using this package.

Without written permission by the author (Takashi Teranishi), you may
not distribute modified versions of this package, and may not distribute
this package for profit.

You may not copy any file, module, subroutine and resource
in this package to create commercial products (including sharewares),
without written permission by the author.

If you want to distribute modified versions of Tera Term widely,
you need also the permission.

There is only one exception to these copyrights rules.
You can make and distribute add-on modules for Tera Term
by using the following files without any permission by the author:

	ttxtest.pas
	teraterm.inc
	tttypes.pas
	ttxtypes.pas
	ttstypes.pas
	ttdtypes.pas
	wsktypes.pas
	types.pas

These files are translated from C files in the package TTSRCP23.ZIP.
For the basic idea of Tera Term extension, see comments in ttxtest.c
included in the package TTSRCP23.ZIP
In developing your module, you can modify the file ttxtest.pas
while other files should not be modified.
It is recommended that you inform the author of the development of
your add-on module. It is also recommended that you distribute
only the add-on module without Tera Term executable files. Otherwise,
you need a permission by the author to distribute a modified package
of Tera Term.

COMMENT FROM THE AUTHOR
~~~~~~~~~~~~~~~~~~~~~~~
To compile the source code, you need Turbo Pascal for Windows 1.5 (TPW).
You can also compile the source with the 16-bit Borland Delphi compiler
by changing an option in the file "TERATERM.INC", but the compilation
with Delphi is not recommended.
I have NO plan to support Delphi in future.

In source files, you can find many parts using the {$IF(N)DEF TERATERM32}
option. However, the source code DOES NOT support the 32-bit Tera Term.
I am sure that specifying TERATERM32 option definitely does not work
even with the 32-bit Delphi compiler.
This option is provided just for the future possibility of supporting
32-bit Tera Term.

The source code files of installer and uninstaller are not
included in this package. I can not distribute them to you.
So, please do not ask me to give them.

This package does not contain setup files, help files and
"Tera Special" font. If you need them, copy them from the
Tera Term distribution package "TTERMV14.ZIP".

Please do not ask the author questions about programming,
structure of the Tera Term source code, how to compile
the source code and so on.

You can contact the author by e-mail at the following address:

	teranishi@rikaxp.riken.go.jp

You may see the current status of Tera Term at Tera Term home page:
	http://www.vector.co.jp/authors/VA002416/teraterm.html

INSTALLATION
~~~~~~~~~~~~
Extract the distribution file TTSRCV14.ZIP onto your hard disk
with keeping the directory structure recorded in the file.
The directory structure should be like the following:

[Base directory] (for example C:\DEV\TERATERM)
	TTMACRO (sub directory)

HOW TO MAKE TERA TERM
~~~~~~~~~~~~~~~~~~~~~
1. Run TPW.

2. Specify the primary file "TERATERM.PAS" by
   the "[Compile] primary file" command.

3. Make TERATERM.EXE by the "[Compile] Make" command.

4. Make "TTCMN", "TTDLG", "TTFILE", "TTSET", "TTTEK", "TTMACRO\TTMACRO",
   and "KEYCODE" by the same procedure as 2-3.

5. Now you have the following executable files:
	TERATERM.EXE
	TTCMN.DLL
	TTDLG.DLL
	TTFILE.DLL
	TTSET.DLL
	TTTEK.DLL
	TTMACRO\TTMACRO.EXE
	KEYCODE.EXE

FILE LIST
~~~~~~~~~
README.TXT	This document
READMEJ.TXT	Document written in Japanese

[Common source files]
DLGLIB.PAS	Dialog box control routines
HELPID.INC	Help context IDs
TEKTYPES.PAS	Type definitions for TEK window
TERATERM.INC	Common include file
TT_RES.INC	Resource IDs for VT window
TTCOMMON.PAS	TTCMN.DLL interface
TTCTL3D.PAS	CTL3D interface
TTFTYPES.PAS	Constants and types for file transfer
TTLIB.PAS	Misc. routines
TTTYPES.PAS	General constants and types
TTXTYPES.PAS	Tera Term extension interface
TYPES.PAS	Misc. types

[Source files of KEYCODE.EXE]
KEYCODE.PAS	Main
KCODEWIN.PAS	Main window

KEYCODE.RES	Resource file

[Source files of TERATERM.EXE]
BUFFER.PAS	Scroll buffer
CLIPBOAR.PAS	Clipboard
COMMLIB.PAS	Communication
FILESYS.PAS	File transfer (TTFILE.DLL interface)
FTDLG.PAS	Log-file/send-file dialog box
KEYBOARD.PAS	Keyboard
PRNABORT.PAS	Print abort dialog box
PROTODLG.PAS	Protocol dialog box
TEKLIB.PAS	TTTEK.DLL interface
TEKWIN.PAS	TEK window
TELNET.PAS	Telnet
TERAPRN.PAS	Print
TERATERM.PAS	Main
TTIME.PAS	Japanese input system
TTDIALOG.PAS	TTDLG.DLL interface
TTDDE.PAS	Communication with TTMACRO.EXE
TTDTYPES.PAS	Definitions of TTDLG functions
TTPLUG.PAS	Tera Term extension interface
TTSETUP.PAS	TTSET.DLL interface
TTSTYPES.PAS	Definitions of TTSET functions
TTWINMAN.PAS	Common routines, variables and flags
		for VT and TEK window
TTWSK.PAS	Winsock interface
VTDISP.PAS	Display
VTTERM.PAS	Escape sequences
VTWIN.PAS	Main window (VT window)
WSKTYPES.PAS	Definitions of Winsock functions

TERATERM.RES	Resource file

[Source files of TTCMN.DLL]
LANGUAGE.PAS	Japanese and Russian routines
TTCMN.PAS	Main

[Source files of TTDLG.DLL]
TTDLG.PAS	Main

TTDLG.RES	Resource file.

[Source files of TTFILE.DLL]
BPLUS.PAS	B-Plus protocol
FTLIB.PAS	Routines for file transfer
KERMIT.PAS	Kermit protocol
QUICKVAN.PAS	Quick-VAN protocol
TTFILE.PAS	Main
XMODEM.PAS	XMODEM protocol
ZMODEM.PAS	ZMODEM protocol
FILE_RES.INC	Resource IDs

TTFILE.RES	Resource file

[Source files of TTMACRO.EXE in the TTMACRO directory]
TTCTL3D.PAS	CTL3D interface
TTLIB.PAS	Misc. routines
TYPES.PAS	Misc. types
TERATERM.INC	Common include file

ERRDLG.PAS	Error dialog box
INPDLG.PAS	Input dialog box
MSGDLG.PAS	Message dialog box
STATDLG.PAS	Status dialog box
TTL.PAS 	Script interpreter
TTMACRO.PAS	Main
TTMBUFF.PAS	Macro file buffer
TTMDDE.PAS	Communication with TERATERM.EXE
TTMDLG.PAS	Dialog boxes
TTMENC.PAS	Password encryption/decryption
TTMLIB.PAS	Misc. routines
TTMMAIN.PAS	Main window
TTMPARSE.PAS	Script parser
TTMMSG.PAS	Message IDs

TTMACRO.RES	Resource file (16-bit)

[Source file of TTSET.DLL]
TTSET.PAS	Main

[Source files of TTTEK.DLL]
TEKESC.PAS	TEK escape sequences
TTTEK.PAS	Main

[Sample add-on module TTXTEST.DLL]
TTXTEST.PAS	Main
