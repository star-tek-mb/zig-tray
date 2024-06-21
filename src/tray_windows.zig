const std = @import("std");
const lib_win = @import("lib/windows.zig");

const windows = std.os.windows;
const zeroes = std.mem.zeroes;

pub const ID_TRAY_FIRST = 1000;

const AtomicBool = std.atomic.Value(bool);

pub const OnClick = *const fn (*Tray) void;
pub const OnPopupClick = OnClick;

pub const Tray = struct {
    allocator: std.mem.Allocator = undefined,
    // icon
    icon: windows.HICON = undefined,
    // menus
    menu: ?[]const ConstMenu = null,

    hight_dpi: bool = true,

    /// whether enable high dpi support
    block_time: u32 = 0,

    // callback for clicking on notification message
    onPopupClick: ?OnPopupClick = null,
    // callback for left clicking on icon
    onClick: ?OnClick = null,

    // note: The following types cannot be manually assigned

    mutable_menu: ?[]Menu = null,
    running: AtomicBool = AtomicBool.init(true),

    // follow four attributes is for windows
    wc: WNDCLASSEXA = zeroes(WNDCLASSEXA),
    hwnd: windows.HWND = undefined,
    hmenu: windows.HMENU = undefined,
    nid: NOTIFYICONDATAW = zeroes(NOTIFYICONDATAW),

    /// init the Tray
    /// Note: must create a Tray before call this method
    pub fn init(
        self: *Tray,
        allocator: std.mem.Allocator,
        hight_dpi: ?bool,
        icon: windows.HICON,
        menu: []ConstMenu,
        onPopupClick: ?OnPopupClick,
        onClick: ?OnClick,
        block_time: u32,
    ) !void {
        // TODO: Need to handle errors that may occur during initialization

        // set the basical attribute
        self.allocator = allocator;
        self.icon = icon;
        self.menu = menu;
        self.onPopupClick = onPopupClick;
        self.onClick = onClick;
        self.block_time = block_time;

        if (hight_dpi) |val|
            self.hight_dpi = val;

        if (self.hight_dpi)
            try adaptDpi();

        self.mutable_menu = try Tray.allocateMenu(self, self.menu);

        // init the wc of self
        self.wc.cbSize = @sizeOf(WNDCLASSEXA);
        self.wc.lpfnWndProc = WndProc;

        // the extra memory allocated
        // to store the self ptr
        self.wc.cbWndExtra = @sizeOf(*Tray);
        self.wc.hInstance = @as(windows.HINSTANCE, @ptrCast(windows.kernel32.GetModuleHandleW(null)));
        self.wc.lpszClassName = lib_win.WC_TRAY_CLASS_NAME;

        // try register class
        _ = try registerClassExA(&self.wc);
        // try create window
        self.hwnd = try createWindowExA(0, lib_win.WC_TRAY_CLASS_NAME, lib_win.WC_TRAY_CLASS_NAME, 0, 0, 0, 0, 0, null, null, self.wc.hInstance, null);

        // set the extra memory allocated
        _ = lib_win.SetWindowLongPtrA(self.hwnd, 0, @as(windows.LONG_PTR, @intCast(@intFromPtr(self))));
        // render window immediately
        _ = lib_win.UpdateWindow(self.hwnd);

        // set notify icon data
        self.nid.cbSize = @sizeOf(NOTIFYICONDATAW);
        self.nid.hWnd = self.hwnd;
        self.nid.uID = 0;
        self.nid.uFlags = lib_win.NIF_ICON | lib_win.NIF_MESSAGE;
        self.nid.uCallbackMessage = lib_win.WM_TRAY_CALLBACK_MESSAGE;

        // add notify icon to desk bar
        _ = lib_win.Shell_NotifyIconW(lib_win.NIM_ADD, &self.nid);

        self.update();
    }

    // This will force a refresh of the entire tray information
    fn update(self: *Tray) void {
        // get previous menu
        const prevmenu = self.hmenu;
        var id: windows.UINT = ID_TRAY_FIRST;
        // generate hmenu
        self.hmenu = Tray.convertMenu(self.mutable_menu.?, &id);
        // render notify icon
        _ = lib_win.SendMessageA(self.hwnd, lib_win.WM_INITMENUPOPUP, @intFromPtr(self.hmenu), 0);

        self.nid.hIcon = self.icon;

        // notify icon modified
        _ = lib_win.Shell_NotifyIconW(lib_win.NIM_MODIFY, &self.nid);
        // destory previous menu
        _ = lib_win.DestroyMenu(prevmenu);
    }

    pub fn run(self: *Tray) void {
        self.running.store(true, .monotonic);
        while (self.running.load(.monotonic)) {
            if (!self.loop()) {
                self.running.store(false, .monotonic);
            }
        }
    }

    pub fn loop(self: *Tray) bool {
        var msg: MSG = undefined;
        if (self.block_time > 0) {
            std.time.sleep(self.block_time);
            if (lib_win.PeekMessageA(&msg, self.hwnd, 0, 0, lib_win.PM_REMOVE) == windows.FALSE)
                return true;
        } else {
            if (lib_win.GetMessageA(&msg, self.hwnd, 0, 0) == windows.FALSE)
                return true;
        }

        if (msg.message == lib_win.WM_QUIT)
            return false;

        _ = lib_win.TranslateMessage(&msg);
        _ = lib_win.DispatchMessageA(&msg);
        return true;
    }

    pub fn exit(self: *Tray) void {
        self.running.store(false, .monotonic);
    }

    pub fn showNotification(self: *Tray, title: []const u8, text: []const u8, timeout_ms: u32) windows.BOOL {
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
                item.text = if (menu[i].text == .text) try std.unicode.utf8ToUtf16LeWithNull(tray.allocator, menu[i].text.text) else null;
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

    fn convertMenu(menu: []Menu, id: *windows.UINT) windows.HMENU {
        const hmenu = lib_win.CreatePopupMenu();
        for (menu) |*item| {
            defer id.* += 1;

            if (item.text) |text| {
                var mitem = zeroes(MENUITEMINFOW);
                mitem.cbSize = @sizeOf(MENUITEMINFOW);
                mitem.fMask = lib_win.MIIM_ID | lib_win.MIIM_TYPE | lib_win.MIIM_STATE | lib_win.MIIM_DATA;
                mitem.fType = 0;
                mitem.fState = 0;

                if (item.submenu) |submenu| {
                    mitem.fMask = mitem.fMask | lib_win.MIIM_SUBMENU;
                    mitem.hSubMenu = Tray.convertMenu(submenu, id);
                }

                if (item.disabled)
                    mitem.fState |= lib_win.MFS_DISABLED;

                if (item.checked)
                    mitem.fState |= lib_win.MFS_CHECKED;

                mitem.wID = id.*;
                mitem.fMask = mitem.fMask | lib_win.MIIM_STRING;
                mitem.dwTypeData = text;
                mitem.dwItemData = @intFromPtr(item);
                _ = lib_win.InsertMenuItemW(hmenu, id.*, windows.TRUE, &mitem);
            } else {
                _ = lib_win.InsertMenuW(hmenu, id.*, lib_win.MF_SEPARATOR, 1, std.unicode.utf8ToUtf16LeStringLiteral(""));
            }
        }
        return hmenu;
    }

    fn freeMenu(allocator: std.mem.Allocator, menu: []Menu) void {
        for (menu) |item| {
            if (item.submenu) |submenu| {
                freeMenu(allocator, submenu);
            }
            if (item.text) |text|
                allocator.free(text);
        }
        allocator.free(menu);
    }

    pub fn deinit(self: *Tray) void {
        _ = lib_win.Shell_NotifyIconW(lib_win.NIM_DELETE, &self.nid);
        _ = lib_win.DestroyIcon(self.icon);
        // DestroyMenu is recursive, that is, it will destroy the menu and all its submenus.
        _ = lib_win.DestroyMenu(self.hmenu);
        _ = lib_win.PostQuitMessage(0);
        _ = lib_win.UnregisterClassA(lib_win.WC_TRAY_CLASS_NAME, self.wc.hInstance);
        if (self.mutable_menu) |mutable_menu|
            freeMenu(self.allocator, mutable_menu);
    }
};

pub const ConstMenu = struct {
    /// if this is null, that mean a separator
    text: union(enum) {
        text: []const u8,
        // this can be init with void{}
        separator: void,
    },
    disabled: bool = false,
    checked: bool = false,
    onClick: ?*const fn (*Menu) void = null,
    /// this is only available when text is not null
    submenu: ?[]const ConstMenu = null,
};

pub const Menu = struct {
    tray: *Tray,
    text: ?[:0]const u16,
    disabled: bool,
    checked: bool,
    onClick: ?*const fn (*Menu) void,
    submenu: ?[]Menu,

    pub fn setText(self: *Menu, text: []const u8) void {
        const text_utf16 = std.unicode.utf8ToUtf16LeWithNull(self.tray.allocator, text) catch return;
        if (self.text) |t|
            self.tray.allocator.free(t);

        self.text = text_utf16;

        self.tray.update();
    }
};

const WNDPROC = lib_win.WNDPROC;

const MSG = lib_win.MSG;

const WNDCLASSEXA = lib_win.WNDCLASSEXA;

fn createWindowExA(
    dwExStyle: u32,
    lpClassName: [*:0]const u8,
    lpWindowName: [*:0]const u8,
    dwStyle: u32,
    X: i32,
    Y: i32,
    nWidth: i32,
    nHeight: i32,
    hWindParent: ?windows.HWND,
    hMenu: ?windows.HMENU,
    hInstance: windows.HINSTANCE,
    lpParam: ?*anyopaque,
) !windows.HWND {
    const window = lib_win.CreateWindowExA(dwExStyle, lpClassName, lpWindowName, dwStyle, X, Y, nWidth, nHeight, hWindParent, hMenu, hInstance, lpParam);
    if (window) |win| return win;

    switch (windows.kernel32.GetLastError()) {
        .CLASS_DOES_NOT_EXIST => return error.ClassDoesNotExist,
        .INVALID_PARAMETER => unreachable,
        else => |err| return windows.unexpectedError(err),
    }
}

fn registerClassExA(window_class: *const WNDCLASSEXA) !windows.ATOM {
    const atom = lib_win.RegisterClassExA(window_class);
    if (atom != 0) return atom;
    switch (windows.kernel32.GetLastError()) {
        .CLASS_ALREADY_EXISTS => return error.AlreadyExists,
        .INVALID_PARAMETER => unreachable,
        else => |err| return windows.unexpectedError(err),
    }
}

const NOTIFYICONDATAW = lib_win.NOTIFYICONDATAW;

const HBITMAP = lib_win.HBITMAP;

const MENUITEMINFOW = lib_win.MENUITEMINFOW;

const CIEXYZ = lib_win.CIEXYZ;

const BITMAPV5HEADER = lib_win.BITMAPV5HEADER;

const ICONINFO = lib_win.ICONINFO;

fn WndProc(hwnd: windows.HWND, uMsg: windows.UINT, wParam: windows.WPARAM, lParam: windows.LPARAM) callconv(windows.WINAPI) windows.LRESULT {
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
            // Called when the user clicks on a notification to the system
            if (tray.onPopupClick) |onPopupClick| {
                if (lParam == lib_win.NIN_BALLOONUSERCLICK) {
                    onPopupClick(tray);
                    tray.update();
                    return 0;
                }
            }

            // Triggered when the user clicks the left mouse button
            if (tray.onClick) |onClick| {
                if (lParam == lib_win.WM_LBUTTONUP) {
                    onClick(tray);
                    tray.update();
                    return 0;
                }
            }

            if (lParam == lib_win.WM_RBUTTONUP) {
                var point: windows.POINT = undefined;
                _ = lib_win.GetCursorPos(&point);
                _ = lib_win.SetForegroundWindow(tray.hwnd);
                const cmd = lib_win.TrackPopupMenu(tray.hmenu, lib_win.TPM_LEFTALIGN | lib_win.TPM_RIGHTBUTTON | lib_win.TPM_RETURNCMD | lib_win.TPM_NONOTIFY, point.x, point.y, 0, hwnd, null);
                _ = lib_win.SendMessageA(hwnd, lib_win.WM_COMMAND, @as(usize, @intCast(cmd)), 0);
            }
        },
        lib_win.WM_COMMAND => {
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
        else => return lib_win.DefWindowProcA(hwnd, uMsg, wParam, lParam),
    }
    return 0;
}

fn getMenuItemFromWParam(item: *MENUITEMINFOW, hMenu: windows.HMENU, wParam: windows.WPARAM) ?*Menu {
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

/// this function is for adapt hight dpi
fn adaptDpi() !void {
    if (lib_win.SetProcessDpiAwarenessContext(
        lib_win.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2,
    ) == windows.FALSE)
        return error.setDpiFailed;
}

pub fn createIconFromFile(path: [:0]const u8) !windows.HICON {
    var icon: windows.HICON = undefined;
    const ret = lib_win.ExtractIconExA(
        path,
        0,
        null,
        &icon,
        1,
    );
    if (ret != 1) {
        return error.NotIcon;
    }
    return icon;
}

pub fn createIconFromRGBA(icon_data: []const u8, width: u32, height: u32) !windows.HICON {
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
