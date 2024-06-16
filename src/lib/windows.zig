const std = @import("std");

pub const WNDPROC = *const fn (
    hwnd: std.os.windows.HWND,
    uMsg: std.os.windows.UINT,
    wParam: std.os.windows.WPARAM,
    lParam: std.os.windows.LPARAM,
) callconv(std.os.windows.WINAPI) std.os.windows.LRESULT;

pub const MSG = extern struct {
    hWnd: ?std.os.windows.HWND,
    message: std.os.windows.UINT,
    wParam: std.os.windows.WPARAM,
    lParam: std.os.windows.LPARAM,
    time: std.os.windows.DWORD,
    pt: std.os.windows.POINT,
    lPrivate: std.os.windows.DWORD,
};

pub const WNDCLASSEXA = extern struct {
    cbSize: std.os.windows.UINT = @sizeOf(WNDCLASSEXA),
    style: std.os.windows.UINT,
    lpfnWndProc: WNDPROC,
    cbClsExtra: i32 = 0,
    cbWndExtra: i32 = 0,
    hInstance: std.os.windows.HINSTANCE,
    hIcon: ?std.os.windows.HICON,
    hCursor: ?std.os.windows.HCURSOR,
    hbrBackground: ?std.os.windows.HBRUSH,
    lpszMenuName: ?[*:0]const u8,
    lpszClassName: [*:0]const u8,
    hIconSm: ?std.os.windows.HICON,
};

pub extern "user32" fn CreateWindowExA(
    dwExStyle: std.os.windows.DWORD,
    lpClassName: [*:0]const u8,
    lpWindowName: [*:0]const u8,
    dwStyle: std.os.windows.DWORD,
    X: i32,
    Y: i32,
    nWidth: i32,
    nHeight: i32,
    hWindParent: ?std.os.windows.HWND,
    hMenu: ?std.os.windows.HMENU,
    hInstance: std.os.windows.HINSTANCE,
    lpParam: ?std.os.windows.LPVOID,
) callconv(std.os.windows.WINAPI) ?std.os.windows.HWND;

pub extern "user32" fn RegisterClassExA(
    *const WNDCLASSEXA,
) callconv(std.os.windows.WINAPI) std.os.windows.ATOM;

pub extern "user32" fn SetWindowLongPtrA(
    hWnd: std.os.windows.HWND,
    nIndex: i32,
    dwNewLong: std.os.windows.LONG_PTR,
) callconv(std.os.windows.WINAPI) std.os.windows.LONG_PTR;

pub extern "user32" fn PeekMessageA(
    lpMsg: *MSG,
    hWnd: ?std.os.windows.HWND,
    wMsgFilterMin: std.os.windows.UINT,
    wMsgFilterMax: std.os.windows.UINT,
    wRemoveMsg: std.os.windows.UINT,
) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;

pub extern "user32" fn TranslateMessage(
    lpMsg: *const MSG,
) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;

pub extern "user32" fn DispatchMessageA(
    lpMsg: *const MSG,
) callconv(std.os.windows.WINAPI) std.os.windows.LRESULT;

pub extern "user32" fn UpdateWindow(
    hWnd: std.os.windows.HWND,
) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;

pub extern "user32" fn PostQuitMessage(
    nExitCode: i32,
) callconv(std.os.windows.WINAPI) void;

pub extern "user32" fn UnregisterClassA(
    lpClassName: [*:0]const u8,
    hInstance: std.os.windows.HINSTANCE,
) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;

pub extern "user32" fn GetWindowLongPtrA(
    hWnd: std.os.windows.HWND,
    nIndex: i32,
) callconv(std.os.windows.WINAPI) std.os.windows.LONG_PTR;

pub extern "user32" fn DefWindowProcA(
    hWnd: std.os.windows.HWND,
    Msg: std.os.windows.UINT,
    wParam: std.os.windows.WPARAM,
    lParam: std.os.windows.LPARAM,
) callconv(std.os.windows.WINAPI) std.os.windows.LRESULT;

pub extern "user32" fn DestroyWindow(
    hWnd: std.os.windows.HWND,
) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;

pub extern "user32" fn GetDC(
    hWnd: ?std.os.windows.HWND,
) callconv(std.os.windows.WINAPI) ?std.os.windows.HDC;

pub extern "user32" fn ReleaseDC(
    hWnd: ?std.os.windows.HWND,
    hDC: std.os.windows.HDC,
) callconv(std.os.windows.WINAPI) i32;

pub const PM_REMOVE = 0x0001;
pub const WM_DESTROY = 0x0002;
pub const WM_CLOSE = 0x0010;
pub const WM_QUIT = 0x0012;
pub const WM_INITMENUPOPUP = 0x0117;
pub const WM_USER = 0x0400;
pub const WM_TRAY_CALLBACK_MESSAGE = WM_USER + 1;
pub const WM_LBUTTONUP = 0x0202;
pub const WM_RBUTTONUP = 0x0205;
pub const WM_COMMAND = 0x0111;
pub const NIN_BALLOONUSERCLICK = WM_USER + 5;
pub const WC_TRAY_CLASS_NAME = "TRAY";
pub const ID_TRAY_FIRST = 1000;
pub const TPM_LEFTALIGN = 0x0000;
pub const TPM_NONOTIFY = 0x0080;
pub const TPM_RETURNCMD = 0x100;
pub const TPM_RIGHTBUTTON = 0x0002;
pub const MF_SEPARATOR = 0x00000800;
pub const MIIM_ID = 0x00000002;
pub const MIIM_TYPE = 0x00000100;
pub const MIIM_STATE = 0x00000001;
pub const MIIM_DATA = 0x00000020;
pub const MIIM_SUBMENU = 0x00000004;
pub const MIIM_STRING = 0x00000040;
pub const MFS_DISABLED = 0x00000003;
pub const MFS_CHECKED = 0x00000008;
pub const NIF_ICON = 0x00000002;
pub const NIF_MESSAGE = 0x00000001;
pub const NIF_INFO = 0x00000010;
pub const NIM_ADD = 0x00000000;
pub const NIM_MODIFY = 0x00000001;
pub const NIM_DELETE = 0x00000002;
pub const BI_BITFIELDS = 3;
pub const DIB_RGB_COLORS = 0;

pub const NOTIFYICONDATAW = extern struct {
    cbSize: std.os.windows.DWORD = @sizeOf(NOTIFYICONDATAW),
    hWnd: std.os.windows.HWND,
    uID: std.os.windows.UINT,
    uFlags: std.os.windows.UINT,
    uCallbackMessage: std.os.windows.UINT,
    hIcon: std.os.windows.HICON,
    szTip: [128]u16,
    dwState: std.os.windows.DWORD,
    dwStateMask: std.os.windows.DWORD,
    szInfo: [256]u16,
    DUMMYUNIONNAME: extern union {
        uTimeout: std.os.windows.UINT,
        uVersion: std.os.windows.UINT,
    },
    szInfoTitle: [64]u16,
    dwInfoFlags: std.os.windows.DWORD,
    guidItem: std.os.windows.GUID,
    hBalloonIcon: std.os.windows.HICON,
};

pub const HBITMAP = *opaque {};

pub const MENUITEMINFOW = extern struct {
    cbSize: std.os.windows.UINT = @sizeOf(MENUITEMINFOW),
    fMask: std.os.windows.UINT,
    fType: std.os.windows.UINT,
    fState: std.os.windows.UINT,
    wID: std.os.windows.UINT,
    hSubMenu: std.os.windows.HMENU,
    hbmpChecked: HBITMAP,
    hbmpUnchecked: HBITMAP,
    dwItemData: std.os.windows.ULONG_PTR,
    dwTypeData: std.os.windows.LPCWSTR,
    cch: std.os.windows.UINT,
    hbmpItem: HBITMAP,
};

pub const CIEXYZ = extern struct {
    ciexyzX: i32,
    ciexyzY: i32,
    ciexyzZ: i32,
};

pub const BITMAPV5HEADER = extern struct {
    bV5Size: std.os.windows.DWORD,
    bV5Width: std.os.windows.LONG,
    bV5Height: std.os.windows.LONG,
    bV5Planes: std.os.windows.WORD,
    bV5BitCount: std.os.windows.WORD,
    bV5Compression: std.os.windows.DWORD,
    bV5SizeImage: std.os.windows.DWORD,
    bV5XPelsPerMeter: std.os.windows.LONG,
    bV5YPelsPerMeter: std.os.windows.LONG,
    bV5ClrUsed: std.os.windows.DWORD,
    bV5ClrImportant: std.os.windows.DWORD,
    bV5RedMask: std.os.windows.DWORD,
    bV5GreenMask: std.os.windows.DWORD,
    bV5BlueMask: std.os.windows.DWORD,
    bV5AlphaMask: std.os.windows.DWORD,
    bV5CSType: std.os.windows.DWORD,
    bV5Endpoints: extern struct {
        ciexyzRed: CIEXYZ,
        ciexyzGreen: CIEXYZ,
        ciexyzBlue: CIEXYZ,
    },
    bV5GammaRed: std.os.windows.DWORD,
    bV5GammaGreen: std.os.windows.DWORD,
    bV5GammaBlue: std.os.windows.DWORD,
    bV5Intent: std.os.windows.DWORD,
    bV5ProfileData: std.os.windows.DWORD,
    bV5ProfileSize: std.os.windows.DWORD,
    bV5Reserved: std.os.windows.DWORD,
};

pub const ICONINFO = extern struct {
    fIcon: std.os.windows.BOOL,
    xHotspot: std.os.windows.DWORD,
    yHotspot: std.os.windows.DWORD,
    hbmMask: HBITMAP,
    hbmColor: HBITMAP,
};

pub extern "user32" fn GetCursorPos(
    lpPoint: [*c]std.os.windows.POINT,
) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;

pub extern "user32" fn SetForegroundWindow(
    hWnd: std.os.windows.HWND,
) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;

pub extern "user32" fn TrackPopupMenu(
    hMenu: std.os.windows.HMENU,
    uFlags: std.os.windows.UINT,
    x: i32,
    y: i32,
    nReserved: i32,
    hWnd: std.os.windows.HWND,
    prcRect: [*c]const std.os.windows.RECT,
) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;

pub extern "user32" fn SendMessageA(
    hWnd: std.os.windows.HWND,
    uMsg: std.os.windows.UINT,
    wParam: std.os.windows.WPARAM,
    lParam: std.os.windows.LPARAM,
) callconv(std.os.windows.WINAPI) std.os.windows.LRESULT;

pub extern "user32" fn CreatePopupMenu() callconv(std.os.windows.WINAPI) std.os.windows.HMENU;

pub extern "user32" fn InsertMenuW(
    hMenu: std.os.windows.HMENU,
    uPosition: std.os.windows.UINT,
    uFlags: std.os.windows.UINT,
    uIDNewItem: std.os.windows.ULONGLONG,
    lpNewItem: ?std.os.windows.LPCWSTR,
) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;

pub extern "user32" fn InsertMenuItemW(
    hMenu: std.os.windows.HMENU,
    item: std.os.windows.UINT,
    fByPosition: std.os.windows.BOOL,
    lpmi: [*c]MENUITEMINFOW,
) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;

pub extern "user32" fn DestroyMenu(
    hMenu: std.os.windows.HMENU,
) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;

pub extern "user32" fn DestroyIcon(
    hIcon: std.os.windows.HICON,
) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;

pub extern "user32" fn GetMenuItemInfoW(
    hMenu: std.os.windows.HMENU,
    item: std.os.windows.UINT,
    fByPosition: std.os.windows.BOOL,
    lpmii: [*c]MENUITEMINFOW,
) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;

pub extern "user32" fn CreateIconIndirect(
    piconinfo: [*c]ICONINFO,
) callconv(std.os.windows.WINAPI) std.os.windows.HICON;

pub extern "shell32" fn Shell_NotifyIconW(
    dwMessage: std.os.windows.DWORD,
    lpData: [*c]NOTIFYICONDATAW,
) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;

pub extern "shell32" fn ExtractIconExA(
    lpszFile: std.os.windows.LPCSTR,
    nIconIndex: i32,
    phiconLarge: [*c]std.os.windows.HICON,
    phiconSmall: [*c]std.os.windows.HICON,
    nIcons: std.os.windows.UINT,
) callconv(std.os.windows.WINAPI) std.os.windows.UINT;

// TODO: pbmi is type of const BITMAPINFO*
pub extern "gdi32" fn CreateDIBSection(
    hdc: ?std.os.windows.HDC,
    pbmi: [*c]const BITMAPV5HEADER,
    usage: std.os.windows.UINT,
    ppvBits: [*c][*c]u8,
    hSection: ?std.os.windows.HANDLE,
    offset: std.os.windows.DWORD,
) callconv(std.os.windows.WINAPI) ?HBITMAP;

pub extern "gdi32" fn CreateBitmap(
    nWidth: i32,
    nHeight: i32,
    nPlanes: std.os.windows.UINT,
    nBitCount: std.os.windows.UINT,
    lpBits: ?*const anyopaque,
) callconv(std.os.windows.WINAPI) ?HBITMAP;

pub extern "gdi32" fn DeleteObject(
    ho: HBITMAP,
) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
