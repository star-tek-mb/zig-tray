# Overview

zig-tray is a library for creating tray applications. Supports tray and notifications.

# Supported platforms

 - [x] Windows
 - [ ] Linux
 - [ ] MacOS

# Installation

Zig Package Manager ready. Add dependency to your `build.zig.zon`. And use `tray` module from dependency.

# Usage

```zig
const std = @import("std");
const tray = @import("tray");

pub fn onAction(menu: *tray.Menu) void {
    menu.tray.showNotification("zig-tray", "Hello world", 5000);
}

pub fn onQuit(menu: *tray.Menu) void {
    menu.tray.exit();
}

pub fn main() !void {
    var tray_instance = tray.Tray{
        .allocator = std.heap.page_allocator,
        .icon = try tray.createIconFromFile("icon.ico"),
        .menu = &[_]tray.ConstMenu{
            .{
                .text = "Hello",
                .submenu = &[_]tray.ConstMenu{
                    .{
                        .text = "Submenu",
                        .onClick = onAction,
                    },
                },
            },
            .{
                .text = "Quit",
                .onClick = onQuit,
            },
        },
    };
    try tray_instance.init();
    defer tray_instance.deinit();
    tray_instance.run();
}
```

see **main.zig** for another example

# Credits

https://github.com/zserge/tray - for initial C library
https://github.com/glfw/glfw/blob/master/src/win32_window.c#L102 - for icon creating from rgba
