const std = @import("std");
const lib_win = @import("lib/windows.zig");

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
        self.wc.lpszClassName = lib_win.WC_TRAY_CLASS_NAME;
        _ = try registerClassExA(&self.wc);
        self.hwnd = try createWindowExA(0, lib_win.WC_TRAY_CLASS_NAME, lib_win.WC_TRAY_CLASS_NAME, 0, 0, 0, 0, 0, null, null, self.wc.hInstance, null);
        _ = lib_win.SetWindowLongPtrA(self.hwnd, 0, @as(std.os.windows.LONG_PTR, @intCast(@intFromPtr(self))));
        _ = lib_win.UpdateWindow(self.hwnd);
        self.nid = std.mem.zeroes(NOTIFYICONDATAW);
        self.nid.cbSize = @sizeOf(NOTIFYICONDATAW);
        self.nid.hWnd = self.hwnd;
        self.nid.uID = 0;
        self.nid.uFlags = lib_win.NIF_ICON | lib_win.NIF_MESSAGE;
        self.nid.uCallbackMessage = lib_win.WM_TRAY_CALLBACK_MESSAGE;
        _ = lib_win.Shell_NotifyIconW(lib_win.NIM_ADD, &self.nid);
        self.update();
    }

    fn update(self: *Tray) void {
        const prevmenu = self.hmenu;
        var id: std.os.windows.UINT = lib_win.ID_TRAY_FIRST;
        self.hmenu = Tray.convertMenu(self.mutable_menu.?, &id);
        _ = lib_win.SendMessageA(self.hwnd, lib_win.WM_INITMENUPOPUP, @intFromPtr(self.hmenu), 0);
        self.nid.hIcon = self.icon;
        _ = lib_win.Shell_NotifyIconW(lib_win.NIM_MODIFY, &self.nid);
        _ = lib_win.DestroyMenu(prevmenu);
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
        _ = lib_win.PeekMessageA(&msg, self.hwnd, 0, 0, lib_win.PM_REMOVE);
        if (msg.message == lib_win.WM_QUIT) {
            return false;
        }
        _ = lib_win.TranslateMessage(&msg);
        _ = lib_win.DispatchMessageA(&msg);
        return true;
    }

    pub fn exit(self: *Tray) void {
        self.running = false;
    }

    pub fn showNotification(self: *Tray, title: []const u8, text: []const u8, timeout_ms: u32) std.os.windows.BOOL {
        const old_flags = self.nid.uFlags;
        self.nid.uFlags |= lib_win.NIF_INFO;
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

        const res = lib_win.Shell_NotifyIconW(lib_win.NIM_MODIFY, &self.nid);
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
        const hmenu = lib_win.CreatePopupMenu();
        for (menu) |*item| {
            if (item.text.len > 0 and item.text[0] == '-') {
                _ = lib_win.InsertMenuW(hmenu, id.*, lib_win.MF_SEPARATOR, 1, std.unicode.utf8ToUtf16LeStringLiteral(""));
            } else {
                var mitem = std.mem.zeroes(MENUITEMINFOW);
                mitem.cbSize = @sizeOf(MENUITEMINFOW);
                mitem.fMask = lib_win.MIIM_ID | lib_win.MIIM_TYPE | lib_win.MIIM_STATE | lib_win.MIIM_DATA;
                mitem.fType = 0;
                mitem.fState = 0;
                if (item.submenu) |submenu| {
                    mitem.fMask = mitem.fMask | lib_win.MIIM_SUBMENU;
                    mitem.hSubMenu = Tray.convertMenu(submenu, id);
                }
                if (item.disabled) {
                    mitem.fState |= lib_win.MFS_DISABLED;
                }
                if (item.checked) {
                    mitem.fState |= lib_win.MFS_CHECKED;
                }
                mitem.wID = id.*;
                mitem.fMask = mitem.fMask | lib_win.MIIM_STRING;
                mitem.dwTypeData = item.text;
                mitem.dwItemData = @intFromPtr(item);
                _ = lib_win.InsertMenuItemW(hmenu, id.*, 1, &mitem);
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
        _ = lib_win.Shell_NotifyIconW(lib_win.NIM_DELETE, &self.nid);
        _ = lib_win.DestroyIcon(self.icon);
        _ = lib_win.DestroyMenu(self.hmenu); // DestroyMenu is recursive, that is, it will destroy the menu and all its submenus.
        _ = lib_win.PostQuitMessage(0);
        _ = lib_win.UnregisterClassA(lib_win.WC_TRAY_CLASS_NAME, self.wc.hInstance);
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

const WNDPROC = lib_win.WNDPROC;

const MSG = lib_win.MSG;

const WNDCLASSEXA = lib_win.WNDCLASSEXA;

fn createWindowExA(dwExStyle: u32, lpClassName: [*:0]const u8, lpWindowName: [*:0]const u8, dwStyle: u32, X: i32, Y: i32, nWidth: i32, nHeight: i32, hWindParent: ?std.os.windows.HWND, hMenu: ?std.os.windows.HMENU, hInstance: std.os.windows.HINSTANCE, lpParam: ?*anyopaque) !std.os.windows.HWND {
    const window = lib_win.CreateWindowExA(dwExStyle, lpClassName, lpWindowName, dwStyle, X, Y, nWidth, nHeight, hWindParent, hMenu, hInstance, lpParam);
    if (window) |win| return win;

    switch (std.os.windows.kernel32.GetLastError()) {
        .CLASS_DOES_NOT_EXIST => return error.ClassDoesNotExist,
        .INVALID_PARAMETER => unreachable,
        else => |err| return std.os.windows.unexpectedError(err),
    }
}

fn registerClassExA(window_class: *const WNDCLASSEXA) !std.os.windows.ATOM {
    const atom = lib_win.RegisterClassExA(window_class);
    if (atom != 0) return atom;
    switch (std.os.windows.kernel32.GetLastError()) {
        .CLASS_ALREADY_EXISTS => return error.AlreadyExists,
        .INVALID_PARAMETER => unreachable,
        else => |err| return std.os.windows.unexpectedError(err),
    }
}

const NOTIFYICONDATAW = lib_win.NOTIFYICONDATAW;

const HBITMAP = lib_win.HBITMAP;

const MENUITEMINFOW = lib_win.MENUITEMINFOW;

const CIEXYZ = lib_win.CIEXYZ;

const BITMAPV5HEADER = lib_win.BITMAPV5HEADER;

const ICONINFO = lib_win.ICONINFO;

fn WndProc(hwnd: std.os.windows.HWND, uMsg: std.os.windows.UINT, wParam: std.os.windows.WPARAM, lParam: std.os.windows.LPARAM) callconv(std.os.windows.WINAPI) std.os.windows.LRESULT {
    const tray_pointer = lib_win.GetWindowLongPtrA(hwnd, 0);
    if (tray_pointer == 0) {
        return lib_win.DefWindowProcA(hwnd, uMsg, wParam, lParam);
    }
    var tray = @as(*Tray, @ptrFromInt(@as(usize, @intCast(tray_pointer))));

    switch (uMsg) {
        lib_win.WM_CLOSE => {
            _ = lib_win.DestroyWindow(hwnd);
        },
        lib_win.WM_DESTROY => {
            _ = lib_win.PostQuitMessage(0);
        },
        lib_win.WM_TRAY_CALLBACK_MESSAGE => {
            if (lParam == lib_win.NIN_BALLOONUSERCLICK) {
                if (tray.onPopupClick) |onPopupClick| {
                    onPopupClick(tray);
                    tray.update();
                }
            }

            if (lParam == lib_win.WM_LBUTTONUP or lParam == lib_win.WM_RBUTTONUP) {
                var point: std.os.windows.POINT = undefined;
                _ = lib_win.GetCursorPos(&point);
                _ = lib_win.SetForegroundWindow(tray.hwnd);
                const cmd = lib_win.TrackPopupMenu(tray.hmenu, lib_win.TPM_LEFTALIGN | lib_win.TPM_RIGHTBUTTON | lib_win.TPM_RETURNCMD | lib_win.TPM_NONOTIFY, point.x, point.y, 0, hwnd, null);
                _ = lib_win.SendMessageA(hwnd, lib_win.WM_COMMAND, @as(usize, @intCast(cmd)), 0);
            }
        },
        lib_win.WM_COMMAND => {
            if (wParam >= lib_win.ID_TRAY_FIRST) {
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
        else => return lib_win.DefWindowProcA(hwnd, uMsg, wParam, lParam),
    }
    return 0;
}

fn getMenuItemFromWParam(item: *MENUITEMINFOW, hMenu: std.os.windows.HMENU, wParam: std.os.windows.WPARAM) ?*Menu {
    item.cbSize = @sizeOf(MENUITEMINFOW);
    item.fMask = lib_win.MIIM_ID | lib_win.MIIM_DATA;
    if (lib_win.GetMenuItemInfoW(hMenu, @as(c_uint, @intCast(wParam)), 0, item) != 0) {
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
    const ret = lib_win.ExtractIconExA(path, 0, null, &icon, 1);
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
    bi.bV5Compression = lib_win.BI_BITFIELDS;
    bi.bV5RedMask = 0x00ff0000;
    bi.bV5GreenMask = 0x0000ff00;
    bi.bV5BlueMask = 0x000000ff;
    bi.bV5AlphaMask = 0xff000000;
    var target: [*c]u8 = undefined;

    const dc = lib_win.GetDC(null);
    const color = lib_win.CreateDIBSection(dc, &bi, lib_win.DIB_RGB_COLORS, &target, null, 0);
    _ = lib_win.ReleaseDC(null, dc.?);
    if (color == null) {
        return error.CreateBitmapFailed;
    }
    defer _ = lib_win.DeleteObject(color.?);

    const mask = lib_win.CreateBitmap(@as(i32, @intCast(width)), @as(i32, @intCast(height)), 1, 1, null);
    if (mask == null) {
        return error.CreateMaskFailed;
    }
    defer _ = lib_win.DeleteObject(mask.?);

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

    const handle = lib_win.CreateIconIndirect(&ii);
    return handle;
}
