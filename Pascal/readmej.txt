	Source code of Tera Term version 1.4
	T. Teranishi Mar 10, 1998

	Copyright (C) 1994-1998 T. Teranishi
	All Rights Reserved.

-------------------------------------------------------------------------------
1. �T�v

Tera Term �� MS-Windows �p�^�[�~�i���G�~�����[�^�[ (telnet �N���C�A���g)�ł��B
MS-Windows 95/NT �p�ɂ� Tera Term Pro ���g�p���Ă��������B

���̃p�b�P�[�W�ɂ� Tera Term version 1.4 �̃\�[�X�R�[�h
(Turbo Pascal for Windows 1.5 �ɑΉ�)���܂܂�Ă��܂��B
�܂��ATera Term 1.4 �� Tera Term Pro 2.3 �� C/C++ �R�[�h��
�ʂ̃p�b�P�[�W TTSRCP23.ZIP �ɂ���܂��B
�������A16-bit Watcom C/C++ �R���p�C���[�ɂ���ăR���p�C�����ꂽ
���s�t�@�C�� TERATERM.EXE �͕����̃A�v���P�[�V�����C���X�^���X��
�Ή����Ă��܂���B�܂�A�����ɕ����� Tera Term�C���X�^���X��
���s���邱�Ƃ��ł��܂���B�����炭 Microsoft ��16-bit �R���p�C���[
���g���΂��̖��������邱�Ƃ��ł��邩������܂��񂪁A
�m�F�͂���Ă��܂���B
���̖��̂��߁A���ۂɌ��J����Ă��� Tera Term 1.4 �͂��̃p�b�P�[�W��
�܂܂�� Turbo Pascal �\�[�X�R�[�h�ɂ���Đ�������܂����B
Turbo Pascal for Windows �ɂ͂��̕����C���X�^���X�̖�肪����܂���B

���̃p�b�P�[�W�ɂ́ATera Term �̂��߂� add-on ���W���[���̗��
�܂܂�Ă��܂��BAdd-on ���W���[���� DLL �̌`�ō쐬����ATera Term
�̃��[�U�[�C���^�[�t�F�C�X�֐��A�ݒ�֐��AWinsock �֐����t�b�N
���邱�Ƃ��ł��܂��BTera Term �� add-on ���W���[���̊Ԃ�
Tera Term extension interface (TTX) �� Robert O'Callahan ��
Tera Term ���(���� ��)�ɂ��J������܂����B
Tera Term �������������ꍇ�́ATera Term �𒼐ډ������邱�Ƃ�
�l����O�ɁAadd-on ���W���[�������邩�ǂ������l���Ă݂Ă��������B
Add-on ���W���[������邱�ƂŁA���쌠�̖����ȒP�Ɏ�舵������
���ł��܂����A�݂��Ɍ݊����̂Ȃ������� Tera Term �������������
��h�����ƂɂȂ�܂��BAdd-on ���W���[���̊J���A�z�z�ɂ��Ă�
���́u2. ���ӎ����v���ǂ�ł��������B

-------------------------------------------------------------------------------
2. ���ӎ���

���쌠�́A���(���� ��)���ێ����܂��B���̃\�[�X�R�[�h�̎g�p�ɂ��A
�����Ȃ鑹�Q�ɂ������Ă���҂͐ӔC�𕉂��܂���B

���̃p�b�P�[�W�̓I���W�i���̌`�̂܂܂Ȃ�΁A�Ĕz�z���R�ł��B
�������A���K�I���v�𓾂邽�߂̔z�z�ɂ͍�҂̋����K�v�ł��B

���̃p�b�P�[�W�Ɋ܂܂��A�t�@�C���A���W���[���A�T�u���[�`���A���\�[�X����
�S���܂��́A�ꕔ���R�s�[���č쐬�����v���O�������A���K�I���v�𓾂邽�߂ɔz�z
����ꍇ�͍�҂̋����K�v�ł��B

������ Tera Term ��s���葽���̐l�ɔz�z����ꍇ�ɂ���҂̋����K�v�ł��B

�������A�ȉ��̃t�@�C�����g�p���� Tera Term �̂��߂� add-on ���W���[��
���쐬���A�z�z���邱�Ƃ́A��҂̋��Ȃ��ŉ\�ł��B

	ttxtest.pas
	teraterm.inc
	tttypes.pas
	ttxtypes.pas
	ttstypes.pas
	ttdtypes.pas
	wsktypes.pas
	types.pas

�����̃t�@�C���̓p�b�P�[�W TTSRCP23.ZIP �� C �t�@�C������ϊ�
����܂����B Tera Term extension �̐����� TTSRCP23.ZIP �Ɋ܂܂��
ttxtest.c �̃R�����g��ǂ�ł��������B
Add-on ���W���[�����J�������ŁAttxtest.pas �����������邱�Ƃ�
�\�ł����A���̃t�@�C���͏��������Ȃ��ł��������B
Add-on ���W���[�����쐬�����ꍇ�ATera Term ��҂ɘA�����邱�Ƃ�
�����߂��܂��B�܂��Aadd-on ���W���[����z�z����ꍇ�́ATera Term
���s�t�@�C����t������ add-on ���W���[��������z�z���邱�Ƃ�
�����߂��܂��B�����łȂ���΁A������ Tera Term ��z�z���邽�߂�
������҂ɐ\������K�v������܂��B

-------------------------------------------------------------------------------
3. ��҂���̃R�����g

�\�[�X���R���p�C������ɂ́ATurbo Pascal for Windows (TPW) 1.5(�p���)��
�K�v�ł��B���{��(PC98)�łł��R���p�C���\���Ƃ͎v���܂����A
��҂͊m�F���Ă��܂���B�܂��ATERATERM.INC �̃I�v�V������ύX���邱�Ƃɂ����
16-bit Borland Delphi �R���p�C���[�ŃR���p�C�����邱�Ƃ��ł��܂����A
�����߂ł��܂���B�����A������ Delphi ���T�|�[�g����\��͂���܂���B

�\�[�X�t�@�C������ {$IF(N)DEF TERATERM32} �I�v�V�������g�p����������
��������܂����A�\�[�X�R�[�h�� 32-bit �� Tera Term ���T�|�[�g���Ă��܂���B
TERATERM32 �I�v�V�������w�肵�Ă���΂ɐ������R���p�C���ł��܂���
(���Ƃ� 32-bit Delphi �R���p�C���[���g�p���Ă�)�B
TERATERM32 �I�v�V�����͒P�ɏ��� 32-bit �ł��T�|�[�g����\����
���߂����ɗp�ӂ���Ă��܂��B

�C���X�g�[���[�ƃA���C���X�g�[���[�̃\�[�X�͌��J���܂���B
��҂ɗv�����Ȃ��ł��������B

���̃p�b�P�[�W�ɂ͐ݒ�t�@�C���A�w���v�t�@�C���A"Tera Special" �t�H���g
���܂܂�Ă��܂���B�����K�v�Ȃ�z�z�p�b�P�[�W TTERMV14.ZIP
����R�s�[���Ă��������B

����̃o�[�W�����A�b�v�ŁA�\�[�X�̑啔����������������\��������܂��B
�ύX�����ɂ��ăR�����g�����肷�邱�Ƃ͂���܂���B�o�[�W�����A�b�v����
�\�[�X����肵�āA�ǂ����ύX���ꂽ�̂��m�肽���ꍇ�́A�����Ńt�@�C�����e��
��r���Ă��������B

��҂ɁA�v���O���~���O�ATera Term �\�[�X�̍\���ɂ��āA�R���p�C�����@
���̎�������Ȃ��ł��������B

��҂ւ̘A����́A teranishi@rikaxp.riken.go.jp �ł��B

Tera Term �̍ŐV���ɂ��Ă� Tera Term home page ���������������B
	http://www.vector.co.jp/authors/VA002416/

-------------------------------------------------------------------------------
4. �R���p�C���̂�����

1) Turbo Pascal for Windows 1.5 ���N��

2) [Compile] primary file �� 'TERATERM.PAS' ���w��

3) [Compile] Make

4) 2-3�Ɠ������@�ŁA'TTCMN', 'TTDLG', 'TTFILE', 'TTSET',
   'TTTEK', 'TTMACRO\TTMACRO', 'KEYCODE' �� make ����B

5) �ȉ��̎��s�t�@�C�����ł��Ă���͂�
	TERATERM.EXE
	TTCMN.DLL
	TTDLG.DLL
	TTFILE.DLL
	TTSET.DLL
	TTTEK.DLL
	TTMACRO\TTMACRO.EXE
	KEYCODE.EXE

-------------------------------------------------------------------------------
5. �t�@�C�����X�g

README.TXT	���̕����̉p���
READMEJP.TXT	���̕���

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
