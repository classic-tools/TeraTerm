unit TTMMsg;

interface
{$i teraterm.inc}

{$IFDEF Delphi}
uses
  Messages;
{$ELSE}
uses
  WinTypes;
{$ENDIF}

const
  WM_USER_DDEREADY = WM_USER + 21;
  WM_USER_DDECMNDEND = WM_USER + 22;
  WM_USER_DDECOMREADY = WM_USER + 23;
  WM_USER_DDEEND = WM_USER + 24;

implementation

end.
