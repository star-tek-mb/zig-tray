const std = @import("std");

pub const Tray = struct {
    allocator: std.mem.Allocator,

    icon: std.os.windows.HICON,
    menu: []const ConstMenu,

    mutable_menu: ?[]Menu = null,

    running: bool = true,
    wc: std.os.windows.user32.WNDCLASSEXA = undefined,
    hwnd: std.os.windows.HWND = undefined,
    hmenu: std.os.windows.HMENU = undefined,
    nid: NOTIFYICONDATAW = undefined,

    pub fn create(allocator: std.mem.Allocator, icon: std.os.windows.HICON, menu: []const ConstMenu) !*Tray {
        var self = try allocator.create(Tray);
        self.allocator = allocator;
        self.icon = icon;
        self.mutable_menu = try Menu.create(allocator, menu);

        self.wc = std.mem.zeroes(std.os.windows.user32.WNDCLASSEXA);
        self.wc.cbSize = @sizeOf(std.os.windows.user32.WNDCLASSEXA);
        self.wc.lpfnWndProc = WndProc;
        self.wc.cbWndExtra = @sizeOf(*Tray);
        self.wc.hInstance = @ptrCast(std.os.windows.HINSTANCE, std.os.windows.kernel32.GetModuleHandleW(null));
        self.wc.lpszClassName = WC_TRAY_CLASS_NAME;
        _ = try std.os.windows.user32.registerClassExA(&self.wc);
        self.hwnd = try std.os.windows.user32.createWindowExA(0, WC_TRAY_CLASS_NAME, WC_TRAY_CLASS_NAME, 0, 0, 0, 0, 0, null, null, self.wc.hInstance, null);
        _ = std.os.windows.user32.SetWindowLongPtrA(self.hwnd, 0, @intCast(std.os.windows.LONG_PTR, @ptrToInt(self)));
        try std.os.windows.user32.updateWindow(self.hwnd);
        self.nid = std.mem.zeroes(NOTIFYICONDATAW);
        self.nid.cbSize = @sizeOf(NOTIFYICONDATAW);
        self.nid.hWnd = self.hwnd;
        self.nid.uID = 0;
        self.nid.uFlags = NIF_ICON | NIF_MESSAGE;
        self.nid.uCallbackMessage = WM_TRAY_CALLBACK_MESSAGE;
        _ = Shell_NotifyIconW(NIM_ADD, &self.nid);
        self.update();

        return self;
    }

    pub fn update(self: *Tray) void {
        var prevmenu = self.hmenu;
        var id: std.os.windows.UINT = ID_TRAY_FIRST;
        self.hmenu = Tray.convertMenu(self.mutable_menu.?, &id);
        _ = SendMessageA(self.hwnd, std.os.windows.user32.WM_INITMENUPOPUP, @ptrToInt(self.hmenu), 0);
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
        var msg: std.os.windows.user32.MSG = undefined;
        _ = std.os.windows.user32.PeekMessageA(&msg, self.hwnd, 0, 0, std.os.windows.user32.PM_REMOVE);
        if (msg.message == std.os.windows.user32.WM_QUIT) {
            return false;
        }
        _ = std.os.windows.user32.TranslateMessage(&msg);
        _ = std.os.windows.user32.DispatchMessageA(&msg);
        return true;
    }

    pub fn exit(self: *Tray) void {
        self.running = false;
    }

    pub fn showNotification(self: *Tray, title: []const u8, text: []const u8, timeout_ms: u32) void {
        var old_flags = self.nid.uFlags;
        self.nid.uFlags |= NIF_INFO;
        self.nid.DUMMYUNIONNAME.uTimeout = timeout_ms;
        self.nid.dwInfoFlags = 0;

        var title_utf16 = std.unicode.utf8ToUtf16LeWithNull(self.allocator, title) catch return;
        defer self.allocator.free(title_utf16);
        var text_utf16 = std.unicode.utf8ToUtf16LeWithNull(self.allocator, text) catch return;
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

        _ = Shell_NotifyIconW(NIM_MODIFY, &self.nid);
        self.nid.uFlags = old_flags;
    }

    fn convertMenu(menu: []Menu, id: *std.os.windows.UINT) std.os.windows.HMENU {
        var hmenu = CreatePopupMenu();
        for (menu) |*item| {
            if (std.mem.len(item.text) > 0 and item.text[0] == '-') {
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
                mitem.dwItemData = @ptrToInt(item);
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
        _ = std.os.windows.user32.PostQuitMessage(0);
        _ = std.os.windows.user32.UnregisterClassA(WC_TRAY_CLASS_NAME, self.wc.hInstance);
        freeMenu(self.allocator, self.mutable_menu.?);
        self.allocator.destroy(self);
    }
};

pub const ConstMenu = struct {
    text: [*:0]const u8,
    disabled: bool = false,
    checked: bool = false,
    onClick: ?*const fn (*Menu) void = null,
    submenu: ?[]const ConstMenu = null,
};

pub const Menu = struct {
    text: [:0]u16,
    disabled: bool,
    checked: bool,
    onClick: ?*const fn (*Menu) void,
    submenu: ?[]Menu,

    pub fn create(allocator: std.mem.Allocator, maybe_menu: ?[]const ConstMenu) !?[]Menu {
        if (maybe_menu) |menu| {
            var result = try allocator.alloc(Menu, menu.len);
            for (result) |*item, i| {
                var text = menu[i].text;
                item.text = try std.unicode.utf8ToUtf16LeWithNull(allocator, text[0..std.mem.len(text)]);
                item.disabled = menu[i].disabled;
                item.checked = menu[i].checked;
                item.onClick = menu[i].onClick;
                item.submenu = try Menu.create(allocator, menu[i].submenu);
            }
            return result;
        } else {
            return null;
        }
    }
};

const WM_TRAY_CALLBACK_MESSAGE = std.os.windows.user32.WM_USER + 1;
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
    var tray_pointer = std.os.windows.user32.GetWindowLongPtrA(hwnd, 0);
    if (tray_pointer == 0) {
        return std.os.windows.user32.DefWindowProcA(hwnd, uMsg, wParam, lParam);
    }
    var tray = @intToPtr(*Tray, @intCast(usize, tray_pointer));

    switch (uMsg) {
        std.os.windows.user32.WM_CLOSE => {
            _ = std.os.windows.user32.DestroyWindow(hwnd);
        },
        std.os.windows.user32.WM_DESTROY => {
            _ = std.os.windows.user32.PostQuitMessage(0);
        },
        WM_TRAY_CALLBACK_MESSAGE => {
            if (lParam == std.os.windows.user32.WM_LBUTTONUP or lParam == std.os.windows.user32.WM_RBUTTONUP) {
                var point: std.os.windows.POINT = undefined;
                _ = GetCursorPos(&point);
                _ = SetForegroundWindow(tray.hwnd);
                var cmd = TrackPopupMenu(tray.hmenu, TPM_LEFTALIGN | TPM_RIGHTBUTTON | TPM_RETURNCMD | TPM_NONOTIFY, point.x, point.y, 0, hwnd, null);
                _ = SendMessageA(hwnd, std.os.windows.user32.WM_COMMAND, @intCast(usize, cmd), 0);
            }
        },
        std.os.windows.user32.WM_COMMAND => {
            if (wParam >= ID_TRAY_FIRST) {
                var item: MENUITEMINFOW = undefined;
                item.cbSize = @sizeOf(MENUITEMINFOW);
                item.fMask = MIIM_ID | MIIM_DATA;
                if (GetMenuItemInfoW(tray.hmenu, @intCast(c_uint, wParam), 0, &item) != 0) {
                    var menu_pointer = @intCast(usize, item.dwItemData);
                    if (menu_pointer != 0) {
                        var menu = @intToPtr(*Menu, menu_pointer);
                        if (menu.onClick) |onClick| {
                            onClick(menu);
                            tray.update();
                        }
                    }
                }
            }
        },
        else => return std.os.windows.user32.DefWindowProcA(hwnd, uMsg, wParam, lParam),
    }
    return 0;
}

pub fn createIconFromFile(path: [:0]const u8) !std.os.windows.HICON {
    var icon: std.os.windows.HICON = undefined;
    var ret = ExtractIconExA(path, 0, null, &icon, 1);
    if (ret != 1) {
        return error.NotIcon;
    }
    return icon;
}

pub fn createIconFromRGBA(icon_data: []const u8, width: u32, height: u32) !std.os.windows.HICON {
    var bi = std.mem.zeroes(BITMAPV5HEADER);
    bi.bV5Size = @sizeOf(BITMAPV5HEADER);
    bi.bV5Width = @intCast(i32, width);
    bi.bV5Height = -@intCast(i32, height);
    bi.bV5Planes = 1;
    bi.bV5BitCount = 32;
    bi.bV5Compression = BI_BITFIELDS;
    bi.bV5RedMask = 0x00ff0000;
    bi.bV5GreenMask = 0x0000ff00;
    bi.bV5BlueMask = 0x000000ff;
    bi.bV5AlphaMask = 0xff000000;
    var target: [*c]u8 = undefined;

    var dc = std.os.windows.user32.GetDC(null);
    var color = CreateDIBSection(dc, &bi, DIB_RGB_COLORS, &target, null, 0);
    _ = std.os.windows.user32.ReleaseDC(null, dc.?);
    if (color == null) {
        return error.CreateBitmapFailed;
    }
    defer _ = DeleteObject(color.?);

    var mask = CreateBitmap(@intCast(i32, width), @intCast(i32, height), 1, 1, null);
    if (mask == null) {
        return error.CreateMaskFailed;
    }
    defer _ = DeleteObject(mask.?);

    var i: usize = 0;
    while (i < width * height) : (i += 1) {
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

    var handle = CreateIconIndirect(&ii);
    return handle;
}
