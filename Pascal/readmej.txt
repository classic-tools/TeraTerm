	Source code of Tera Term version 1.4
	T. Teranishi Mar 10, 1998

	Copyright (C) 1994-1998 T. Teranishi
	All Rights Reserved.

-------------------------------------------------------------------------------
1. 概要

Tera Term は MS-Windows 用ターミナルエミュレーター (telnet クライアント)です。
MS-Windows 95/NT 用には Tera Term Pro を使用してください。

このパッケージには Tera Term version 1.4 のソースコード
(Turbo Pascal for Windows 1.5 に対応)が含まれています。
また、Tera Term 1.4 と Tera Term Pro 2.3 の C/C++ コードは
別のパッケージ TTSRCP23.ZIP にあります。
ただし、16-bit Watcom C/C++ コンパイラーによってコンパイルされた
実行ファイル TERATERM.EXE は複数のアプリケーションインスタンスに
対応していません。つまり、同時に複数の Tera Termインスタンスを
実行することができません。おそらく Microsoft の16-bit コンパイラー
を使えばこの問題をさけることができるかもしれませんが、
確認はされていません。
この問題のため、実際に公開されている Tera Term 1.4 はこのパッケージに
含まれる Turbo Pascal ソースコードによって生成されました。
Turbo Pascal for Windows にはこの複数インスタンスの問題がありません。

このパッケージには、Tera Term のための add-on モジュールの例も
含まれています。Add-on モジュールは DLL の形で作成され、Tera Term
のユーザーインターフェイス関数、設定関数、Winsock 関数をフック
することができます。Tera Term と add-on モジュールの間の
Tera Term extension interface (TTX) は Robert O'Callahan と
Tera Term 作者(寺西 高)により開発されました。
Tera Term を改造したい場合は、Tera Term を直接改造することを
考える前に、add-on モジュールが作れるかどうかを考えてみてください。
Add-on モジュールを作ることで、著作権の問題を簡単に取り扱うこと
ができますし、互いに互換性のない改造版 Tera Term が多数つくられるの
を防ぐことになります。Add-on モジュールの開発、配布については
次の「2. 注意事項」も読んでください。

-------------------------------------------------------------------------------
2. 注意事項

著作権は、作者(寺西 高)が保持します。このソースコードの使用による、
いかなる損害にたいしても作者は責任を負いません。

このパッケージはオリジナルの形のままならば、再配布自由です。
ただし、金銭的利益を得るための配布には作者の許可が必要です。

このパッケージに含まれる、ファイル、モジュール、サブルーチン、リソース等の
全部または、一部をコピーして作成したプログラムを、金銭的利益を得るために配布
する場合は作者の許可が必要です。

改造版 Tera Term を不特定多数の人に配布する場合にも作者の許可が必要です。

ただし、以下のファイルを使用して Tera Term のための add-on モジュール
を作成し、配布することは、作者の許可なしで可能です。

	ttxtest.pas
	teraterm.inc
	tttypes.pas
	ttxtypes.pas
	ttstypes.pas
	ttdtypes.pas
	wsktypes.pas
	types.pas

これらのファイルはパッケージ TTSRCP23.ZIP の C ファイルから変換
されました。 Tera Term extension の説明は TTSRCP23.ZIP に含まれる
ttxtest.c のコメントを読んでください。
Add-on モジュールを開発する上で、ttxtest.pas を書き換えることは
可能ですが、他のファイルは書き換えないでください。
Add-on モジュールを作成した場合、Tera Term 作者に連絡することを
お勧めします。また、add-on モジュールを配布する場合は、Tera Term
実行ファイルを付けずに add-on モジュールだけを配布することを
お勧めします。そうでなければ、改造版 Tera Term を配布するための
許可を作者に申請する必要があります。

-------------------------------------------------------------------------------
3. 作者からのコメント

ソースをコンパイルするには、Turbo Pascal for Windows (TPW) 1.5(英語版)が
必要です。日本語(PC98)版でもコンパイル可能だとは思いますが、
作者は確認していません。また、TERATERM.INC のオプションを変更することによって
16-bit Borland Delphi コンパイラーでコンパイルすることもできますが、
お勧めできません。将来、正式に Delphi をサポートする予定はありません。

ソースファイル中に {$IF(N)DEF TERATERM32} オプションを使用した部分が
多数ありますが、ソースコードは 32-bit 版 Tera Term をサポートしていません。
TERATERM32 オプションを指定しても絶対に正しくコンパイルできません
(たとえ 32-bit Delphi コンパイラーを使用しても)。
TERATERM32 オプションは単に将来 32-bit 版をサポートする可能性の
ためだけに用意されています。

インストーラーとアンインストーラーのソースは公開しません。
作者に要求しないでください。

このパッケージには設定ファイル、ヘルプファイル、"Tera Special" フォント
が含まれていません。もし必要なら配布パッケージ TTERMV14.ZIP
からコピーしてください。

今後のバージョンアップで、ソースの大部分が書き換えられる可能性があります。
変更部分についてコメントしたりすることはありません。バージョンアップした
ソースを入手して、どこが変更されたのか知りたい場合は、自分でファイル内容を
比較してください。

作者に、プログラミング、Tera Term ソースの構造について、コンパイル方法
等の質問をしないでください。

作者への連絡先は、 teranishi@rikaxp.riken.go.jp です。

Tera Term の最新情報については Tera Term home page をご覧ください。
	http://www.vector.co.jp/authors/VA002416/

-------------------------------------------------------------------------------
4. コンパイルのしかた

1) Turbo Pascal for Windows 1.5 を起動

2) [Compile] primary file で 'TERATERM.PAS' を指定

3) [Compile] Make

4) 2-3と同じ方法で、'TTCMN', 'TTDLG', 'TTFILE', 'TTSET',
   'TTTEK', 'TTMACRO\TTMACRO', 'KEYCODE' を make する。

5) 以下の実行ファイルができているはず
	TERATERM.EXE
	TTCMN.DLL
	TTDLG.DLL
	TTFILE.DLL
	TTSET.DLL
	TTTEK.DLL
	TTMACRO\TTMACRO.EXE
	KEYCODE.EXE

-------------------------------------------------------------------------------
5. ファイルリスト

README.TXT	この文書の英語版
READMEJP.TXT	この文書

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
