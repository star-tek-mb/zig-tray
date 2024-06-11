const std = @import("std");

pub const Tray = struct {
    allocator: std.mem.Allocator,
    icon: std.os.windows.HICON,
    menu: []const ConstMenu,

    onPopupClick: ?*const fn (*Tray) void = null,
    mutable_menu: ?[]Menu = null,
    running: bool = true,
    wc: WNDCLASSEXA = undefined,
    hwnd: std.os.windows.HWND = undefined,
    hmenu: std.os.windows.HMENU = undefined,
    nid: NOTIFYICONDATAW = undefined,

    pub fn init(self: *Tray) !void {
        self.mutable_menu = try Tray.allocateMenu(self, self.menu);

        self.wc = std.mem.zeroes(WNDCLASSEXA);
        self.wc.cbSize = @sizeOf(WNDCLASSEXA);
        self.wc.lpfnWndProc = WndProc;
        self.wc.cbWndExtra = @sizeOf(*Tray);
        self.wc.hInstance = @as(std.os.windows.HINSTANCE, @ptrCast(std.os.windows.kernel32.GetModuleHandleW(null)));
        self.wc.lpszClassName = WC_TRAY_CLASS_NAME;
        _ = try registerClassExA(&self.wc);
        self.hwnd = try createWindowExA(0, WC_TRAY_CLASS_NAME, WC_TRAY_CLASS_NAME, 0, 0, 0, 0, 0, null, null, self.wc.hInstance, null);
        _ = SetWindowLongPtrA(self.hwnd, 0, @as(std.os.windows.LONG_PTR, @intCast(@intFromPtr(self))));
        _ = UpdateWindow(self.hwnd);
        self.nid = std.mem.zeroes(NOTIFYICONDATAW);
        self.nid.cbSize = @sizeOf(NOTIFYICONDATAW);
        self.nid.hWnd = self.hwnd;
        self.nid.uID = 0;
        self.nid.uFlags = NIF_ICON | NIF_MESSAGE;
        self.nid.uCallbackMessage = WM_TRAY_CALLBACK_MESSAGE;
        _ = Shell_NotifyIconW(NIM_ADD, &self.nid);
        self.update();
    }

    fn update(self: *Tray) void {
        const prevmenu = self.hmenu;
        var id: std.os.windows.UINT = ID_TRAY_FIRST;
        self.hmenu = Tray.convertMenu(self.mutable_menu.?, &id);
        _ = SendMessageA(self.hwnd, WM_INITMENUPOPUP, @intFromPtr(self.hmenu), 0);
        self.nid.hIcon = self.icon;
        _ = Shell_NotifyIconW(NIM_MODIFY, &self.nid);
        _ = DestroyMenu(prevmenu);
    }

    pub fn run(self: *Tray) void {
        self.running = true;
        while (self.running) {
            if (!self.loop()) {
                self.running = false;
            }
        }
    }

    pub fn loop(self: *Tray) bool {
        var msg: MSG = undefined;
        _ = PeekMessageA(&msg, self.hwnd, 0, 0, PM_REMOVE);
        if (msg.message == WM_QUIT) {
            return false;
        }
        _ = TranslateMessage(&msg);
        _ = DispatchMessageA(&msg);
        return true;
    }

    pub fn exit(self: *Tray) void {
        self.running = false;
    }

    pub fn showNotification(self: *Tray, title: []const u8, text: []const u8, timeout_ms: u32) std.os.windows.BOOL {
        const old_flags = self.nid.uFlags;
        self.nid.uFlags |= NIF_INFO;
        self.nid.DUMMYUNIONNAME.uTimeout = timeout_ms;
        self.nid.dwInfoFlags = 0;

        const title_utf16 = std.unicode.utf8ToUtf16LeWithNull(self.allocator, title) catch return 0;
        defer self.allocator.free(title_utf16);
        const text_utf16 = std.unicode.utf8ToUtf16LeWithNull(self.allocator, text) catch return 0;
        defer self.allocator.free(text_utf16);

        var i: usize = 0;
        while (i < self.nid.szInfoTitle.len - 1 and i < title_utf16.len) : (i += 1) {
            self.nid.szInfoTitle[i] = title_utf16[i];
        }
        self.nid.szInfoTitle[i] = 0;

        i = 0;
        while (i < self.nid.szInfo.len - 1 and i < text_utf16.len) : (i += 1) {
            self.nid.szInfo[i] = text_utf16[i];
        }
        self.nid.szInfo[i] = 0;

        const res = Shell_NotifyIconW(NIM_MODIFY, &self.nid);
        self.nid.uFlags = old_flags;

        return res;
    }

    // recursive function
    fn allocateMenu(tray: *Tray, maybe_menu: ?[]const ConstMenu) !?[]Menu {
        if (maybe_menu) |menu| {
            const result = try tray.allocator.alloc(Menu, menu.len);
            for (result, 0..) |*item, i| {
                item.tray = tray;
                item.text = try std.unicode.utf8ToUtf16LeWithNull(tray.allocator, menu[i].text);
                item.disabled = menu[i].disabled;
                item.checked = menu[i].checked;
                item.onClick = menu[i].onClick;
                item.submenu = try Tray.allocateMenu(tray, menu[i].submenu);
            }
            return result;
        } else {
            return null;
        }
    }

    fn convertMenu(menu: []Menu, id: *std.os.windows.UINT) std.os.windows.HMENU {
        const hmenu = CreatePopupMenu();
        for (menu) |*item| {
            if (item.text.len > 0 and item.text[0] == '-') {
                _ = InsertMenuW(hmenu, id.*, MF_SEPARATOR, 1, std.unicode.utf8ToUtf16LeStringLiteral(""));
            } else {
                var mitem = std.mem.zeroes(MENUITEMINFOW);
                mitem.cbSize = @sizeOf(MENUITEMINFOW);
                mitem.fMask = MIIM_ID | MIIM_TYPE | MIIM_STATE | MIIM_DATA;
                mitem.fType = 0;
                mitem.fState = 0;
                if (item.submenu) |submenu| {
                    mitem.fMask = mitem.fMask | MIIM_SUBMENU;
                    mitem.hSubMenu = Tray.convertMenu(submenu, id);
                }
                if (item.disabled) {
                    mitem.fState |= MFS_DISABLED;
                }
                if (item.checked) {
                    mitem.fState |= MFS_CHECKED;
                }
                mitem.wID = id.*;
                mitem.fMask = mitem.fMask | MIIM_STRING;
                mitem.dwTypeData = item.text;
                mitem.dwItemData = @intFromPtr(item);
                _ = InsertMenuItemW(hmenu, id.*, 1, &mitem);
            }
            id.* = id.* + 1;
        }
        return hmenu;
    }

    fn freeMenu(allocator: std.mem.Allocator, menu: []Menu) void {
        for (menu) |item| {
            if (item.submenu) |submenu| {
                freeMenu(allocator, submenu);
            }
            allocator.free(item.text);
        }
        allocator.free(menu);
    }

    pub fn deinit(self: *Tray) void {
        _ = Shell_NotifyIconW(NIM_DELETE, &self.nid);
        _ = DestroyIcon(self.icon);
        _ = DestroyMenu(self.hmenu); // DestroyMenu is recursive, that is, it will destroy the menu and all its submenus.
        _ = PostQuitMessage(0);
        _ = UnregisterClassA(WC_TRAY_CLASS_NAME, self.wc.hInstance);
        freeMenu(self.allocator, self.mutable_menu.?);
    }
};

pub const ConstMenu = struct {
    text: []const u8,
    disabled: bool = false,
    checked: bool = false,
    onClick: ?*const fn (*Menu) void = null,
    submenu: ?[]const ConstMenu = null,
};

pub const Menu = struct {
    tray: *Tray,
    text: [:0]u16,
    disabled: bool,
    checked: bool,
    onClick: ?*const fn (*Menu) void,
    submenu: ?[]Menu,

    pub fn setText(self: *Menu, text: []const u8) void {
        const text_utf16 = std.unicode.utf8ToUtf16LeWithNull(self.tray.allocator, text) catch return;
        self.tray.allocator.free(self.text);
        self.text = text_utf16;

        self.tray.update();
    }
};

const WNDPROC = *const fn (hwnd: std.os.windows.HWND, uMsg: std.os.windows.UINT, wParam: std.os.windows.WPARAM, lParam: std.os.windows.LPARAM) callconv(std.os.windows.WINAPI) std.os.windows.LRESULT;

const MSG = extern struct {
    hWnd: ?std.os.windows.HWND,
    message: std.os.windows.UINT,
    wParam: std.os.windows.WPARAM,
    lParam: std.os.windows.LPARAM,
    time: std.os.windows.DWORD,
    pt: std.os.windows.POINT,
    lPrivate: std.os.windows.DWORD,
};

const WNDCLASSEXA = extern struct {
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

pub extern "user32" fn CreateWindowExA(dwExStyle: std.os.windows.DWORD, lpClassName: [*:0]const u8, lpWindowName: [*:0]const u8, dwStyle: std.os.windows.DWORD, X: i32, Y: i32, nWidth: i32, nHeight: i32, hWindParent: ?std.os.windows.HWND, hMenu: ?std.os.windows.HMENU, hInstance: std.os.windows.HINSTANCE, lpParam: ?std.os.windows.LPVOID) callconv(std.os.windows.WINAPI) ?std.os.windows.HWND;
fn createWindowExA(dwExStyle: u32, lpClassName: [*:0]const u8, lpWindowName: [*:0]const u8, dwStyle: u32, X: i32, Y: i32, nWidth: i32, nHeight: i32, hWindParent: ?std.os.windows.HWND, hMenu: ?std.os.windows.HMENU, hInstance: std.os.windows.HINSTANCE, lpParam: ?*anyopaque) !std.os.windows.HWND {
    const window = CreateWindowExA(dwExStyle, lpClassName, lpWindowName, dwStyle, X, Y, nWidth, nHeight, hWindParent, hMenu, hInstance, lpParam);
    if (window) |win| return win;

    switch (std.os.windows.kernel32.GetLastError()) {
        .CLASS_DOES_NOT_EXIST => return error.ClassDoesNotExist,
        .INVALID_PARAMETER => unreachable,
        else => |err| return std.os.windows.unexpectedError(err),
    }
}
pub extern "user32" fn RegisterClassExA(*const WNDCLASSEXA) callconv(std.os.windows.WINAPI) std.os.windows.ATOM;
fn registerClassExA(window_class: *const WNDCLASSEXA) !std.os.windows.ATOM {
    const atom = RegisterClassExA(window_class);
    if (atom != 0) return atom;
    switch (std.os.windows.kernel32.GetLastError()) {
        .CLASS_ALREADY_EXISTS => return error.AlreadyExists,
        .INVALID_PARAMETER => unreachable,
        else => |err| return std.os.windows.unexpectedError(err),
    }
}
pub extern "user32" fn SetWindowLongPtrA(hWnd: std.os.windows.HWND, nIndex: i32, dwNewLong: std.os.windows.LONG_PTR) callconv(std.os.windows.WINAPI) std.os.windows.LONG_PTR;
pub extern "user32" fn PeekMessageA(lpMsg: *MSG, hWnd: ?std.os.windows.HWND, wMsgFilterMin: std.os.windows.UINT, wMsgFilterMax: std.os.windows.UINT, wRemoveMsg: std.os.windows.UINT) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
pub extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
pub extern "user32" fn DispatchMessageA(lpMsg: *const MSG) callconv(std.os.windows.WINAPI) std.os.windows.LRESULT;
pub extern "user32" fn UpdateWindow(hWnd: std.os.windows.HWND) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
pub extern "user32" fn PostQuitMessage(nExitCode: i32) callconv(std.os.windows.WINAPI) void;
pub extern "user32" fn UnregisterClassA(lpClassName: [*:0]const u8, hInstance: std.os.windows.HINSTANCE) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
pub extern "user32" fn GetWindowLongPtrA(hWnd: std.os.windows.HWND, nIndex: i32) callconv(std.os.windows.WINAPI) std.os.windows.LONG_PTR;
pub extern "user32" fn DefWindowProcA(hWnd: std.os.windows.HWND, Msg: std.os.windows.UINT, wParam: std.os.windows.WPARAM, lParam: std.os.windows.LPARAM) callconv(std.os.windows.WINAPI) std.os.windows.LRESULT;
pub extern "user32" fn DestroyWindow(hWnd: std.os.windows.HWND) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
pub extern "user32" fn GetDC(hWnd: ?std.os.windows.HWND) callconv(std.os.windows.WINAPI) ?std.os.windows.HDC;
pub extern "user32" fn ReleaseDC(hWnd: ?std.os.windows.HWND, hDC: std.os.windows.HDC) callconv(std.os.windows.WINAPI) i32;

const PM_REMOVE = 0x0001;
const WM_DESTROY = 0x0002;
const WM_CLOSE = 0x0010;
const WM_QUIT = 0x0012;
const WM_INITMENUPOPUP = 0x0117;
const WM_USER = 0x0400;
const WM_TRAY_CALLBACK_MESSAGE = WM_USER + 1;
const WM_LBUTTONUP = 0x0202;
const WM_RBUTTONUP = 0x0205;
const WM_COMMAND = 0x0111;
const NIN_BALLOONUSERCLICK = WM_USER + 5;
const WC_TRAY_CLASS_NAME = "TRAY";
const ID_TRAY_FIRST = 1000;
const TPM_LEFTALIGN = 0x0000;
const TPM_NONOTIFY = 0x0080;
const TPM_RETURNCMD = 0x100;
const TPM_RIGHTBUTTON = 0x0002;
const MF_SEPARATOR = 0x00000800;
const MIIM_ID = 0x00000002;
const MIIM_TYPE = 0x00000100;
const MIIM_STATE = 0x00000001;
const MIIM_DATA = 0x00000020;
const MIIM_SUBMENU = 0x00000004;
const MIIM_STRING = 0x00000040;
const MFS_DISABLED = 0x00000003;
const MFS_CHECKED = 0x00000008;
const NIF_ICON = 0x00000002;
const NIF_MESSAGE = 0x00000001;
const NIF_INFO = 0x00000010;
const NIM_ADD = 0x00000000;
const NIM_MODIFY = 0x00000001;
const NIM_DELETE = 0x00000002;
const BI_BITFIELDS = 3;
const DIB_RGB_COLORS = 0;

const NOTIFYICONDATAW = extern struct {
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

const HBITMAP = *opaque {};

const MENUITEMINFOW = extern struct {
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

const CIEXYZ = extern struct {
    ciexyzX: i32,
    ciexyzY: i32,
    ciexyzZ: i32,
};

const BITMAPV5HEADER = extern struct {
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

const ICONINFO = extern struct {
    fIcon: std.os.windows.BOOL,
    xHotspot: std.os.windows.DWORD,
    yHotspot: std.os.windows.DWORD,
    hbmMask: HBITMAP,
    hbmColor: HBITMAP,
};

extern "user32" fn GetCursorPos(lpPoint: [*c]std.os.windows.POINT) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
extern "user32" fn SetForegroundWindow(hWnd: std.os.windows.HWND) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
extern "user32" fn TrackPopupMenu(hMenu: std.os.windows.HMENU, uFlags: std.os.windows.UINT, x: i32, y: i32, nReserved: i32, hWnd: std.os.windows.HWND, prcRect: [*c]const std.os.windows.RECT) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
extern "user32" fn SendMessageA(hWnd: std.os.windows.HWND, uMsg: std.os.windows.UINT, wParam: std.os.windows.WPARAM, lParam: std.os.windows.LPARAM) callconv(std.os.windows.WINAPI) std.os.windows.LRESULT;
extern "user32" fn CreatePopupMenu() callconv(std.os.windows.WINAPI) std.os.windows.HMENU;
extern "user32" fn InsertMenuW(hMenu: std.os.windows.HMENU, uPosition: std.os.windows.UINT, uFlags: std.os.windows.UINT, uIDNewItem: std.os.windows.ULONGLONG, lpNewItem: ?std.os.windows.LPCWSTR) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
extern "user32" fn InsertMenuItemW(hMenu: std.os.windows.HMENU, item: std.os.windows.UINT, fByPosition: std.os.windows.BOOL, lpmi: [*c]MENUITEMINFOW) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
extern "user32" fn DestroyMenu(hMenu: std.os.windows.HMENU) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
extern "user32" fn DestroyIcon(hIcon: std.os.windows.HICON) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
extern "user32" fn GetMenuItemInfoW(hMenu: std.os.windows.HMENU, item: std.os.windows.UINT, fByPosition: std.os.windows.BOOL, lpmii: [*c]MENUITEMINFOW) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
extern "user32" fn CreateIconIndirect(piconinfo: [*c]ICONINFO) callconv(std.os.windows.WINAPI) std.os.windows.HICON;
extern "shell32" fn Shell_NotifyIconW(dwMessage: std.os.windows.DWORD, lpData: [*c]NOTIFYICONDATAW) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
extern "shell32" fn ExtractIconExA(lpszFile: std.os.windows.LPCSTR, nIconIndex: i32, phiconLarge: [*c]std.os.windows.HICON, phiconSmall: [*c]std.os.windows.HICON, nIcons: std.os.windows.UINT) callconv(std.os.windows.WINAPI) std.os.windows.UINT;
// TODO: pbmi is type of const BITMAPINFO*
extern "gdi32" fn CreateDIBSection(hdc: ?std.os.windows.HDC, pbmi: [*c]const BITMAPV5HEADER, usage: std.os.windows.UINT, ppvBits: [*c][*c]u8, hSection: ?std.os.windows.HANDLE, offset: std.os.windows.DWORD) callconv(std.os.windows.WINAPI) ?HBITMAP;
extern "gdi32" fn CreateBitmap(nWidth: i32, nHeight: i32, nPlanes: std.os.windows.UINT, nBitCount: std.os.windows.UINT, lpBits: ?*const anyopaque) callconv(std.os.windows.WINAPI) ?HBITMAP;
extern "gdi32" fn DeleteObject(ho: HBITMAP) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;

fn WndProc(hwnd: std.os.windows.HWND, uMsg: std.os.windows.UINT, wParam: std.os.windows.WPARAM, lParam: std.os.windows.LPARAM) callconv(std.os.windows.WINAPI) std.os.windows.LRESULT {
    const tray_pointer = GetWindowLongPtrA(hwnd, 0);
    if (tray_pointer == 0) {
        return DefWindowProcA(hwnd, uMsg, wParam, lParam);
    }
    var tray = @as(*Tray, @ptrFromInt(@as(usize, @intCast(tray_pointer))));

    switch (uMsg) {
        WM_CLOSE => {
            _ = DestroyWindow(hwnd);
        },
        WM_DESTROY => {
            _ = PostQuitMessage(0);
        },
        WM_TRAY_CALLBACK_MESSAGE => {
            if (lParam == NIN_BALLOONUSERCLICK) {
                if (tray.onPopupClick) |onPopupClick| {
                    onPopupClick(tray);
                    tray.update();
                }
            }

            if (lParam == WM_LBUTTONUP or lParam == WM_RBUTTONUP) {
                var point: std.os.windows.POINT = undefined;
                _ = GetCursorPos(&point);
                _ = SetForegroundWindow(tray.hwnd);
                const cmd = TrackPopupMenu(tray.hmenu, TPM_LEFTALIGN | TPM_RIGHTBUTTON | TPM_RETURNCMD | TPM_NONOTIFY, point.x, point.y, 0, hwnd, null);
                _ = SendMessageA(hwnd, WM_COMMAND, @as(usize, @intCast(cmd)), 0);
            }
        },
        WM_COMMAND => {
            if (wParam >= ID_TRAY_FIRST) {
                var item: MENUITEMINFOW = undefined;
                const menup = getMenuItemFromWParam(&item, tray.hmenu, wParam);
                if (menup) |menu| {
                    if (menu.onClick) |onClick| {
                        onClick(menu);
                        tray.update();
                    }
                }
            }
        },
        else => return DefWindowProcA(hwnd, uMsg, wParam, lParam),
    }
    return 0;
}

fn getMenuItemFromWParam(item: *MENUITEMINFOW, hMenu: std.os.windows.HMENU, wParam: std.os.windows.WPARAM) ?*Menu {
    item.cbSize = @sizeOf(MENUITEMINFOW);
    item.fMask = MIIM_ID | MIIM_DATA;
    if (GetMenuItemInfoW(hMenu, @as(c_uint, @intCast(wParam)), 0, item) != 0) {
        const menu_pointer = @as(usize, @intCast(item.dwItemData));
        if (menu_pointer != 0) {
            const menu = @as(*Menu, @ptrFromInt(menu_pointer));
            return menu;
        }
    }
    return null;
}

pub fn createIconFromFile(path: [:0]const u8) !std.os.windows.HICON {
    var icon: std.os.windows.HICON = undefined;
    const ret = ExtractIconExA(path, 0, null, &icon, 1);
    if (ret != 1) {
        return error.NotIcon;
    }
    return icon;
}

pub fn createIconFromRGBA(icon_data: []const u8, width: u32, height: u32) !std.os.windows.HICON {
    var bi = std.mem.zeroes(BITMAPV5HEADER);
    bi.bV5Size = @sizeOf(BITMAPV5HEADER);
    bi.bV5Width = @as(i32, @intCast(width));
    bi.bV5Height = -@as(i32, @intCast(height));
    bi.bV5Planes = 1;
    bi.bV5BitCount = 32;
    bi.bV5Compression = BI_BITFIELDS;
    bi.bV5RedMask = 0x00ff0000;
    bi.bV5GreenMask = 0x0000ff00;
    bi.bV5BlueMask = 0x000000ff;
    bi.bV5AlphaMask = 0xff000000;
    var target: [*c]u8 = undefined;

    const dc = GetDC(null);
    const color = CreateDIBSection(dc, &bi, DIB_RGB_COLORS, &target, null, 0);
    _ = ReleaseDC(null, dc.?);
    if (color == null) {
        return error.CreateBitmapFailed;
    }
    defer _ = DeleteObject(color.?);

    const mask = CreateBitmap(@as(i32, @intCast(width)), @as(i32, @intCast(height)), 1, 1, null);
    if (mask == null) {
        return error.CreateMaskFailed;
    }
    defer _ = DeleteObject(mask.?);

    for (0..width * height) |i| {
        target[i * 4 + 0] = icon_data[i * 4 + 2];
        target[i * 4 + 1] = icon_data[i * 4 + 1];
        target[i * 4 + 2] = icon_data[i * 4 + 0];
        target[i * 4 + 3] = icon_data[i * 4 + 3];
    }

    var ii = std.mem.zeroes(ICONINFO);
    ii.fIcon = 1;
    ii.xHotspot = 0;
    ii.yHotspot = 0;
    ii.hbmMask = mask.?;
    ii.hbmColor = color.?;

    const handle = CreateIconIndirect(&ii);
    return handle;
}
