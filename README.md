# Overview

zig-tray is a library for creating tray applications. Supports tray and notifications.

# Supported platforms

 - [x] Windows
 - [ ] Linux
 - [ ] MacOS

# Installation

```
zig build
```

# Usage

```zig
const std = @import("std");
const tray = @import("tray.zig");
const qoi = @import("qoi.zig");

var tray_instance: *tray.Tray = undefined;

pub fn onAction(_: *tray.Menu) void {
    tray_instance.showNotification("zig-tray", "Hello world", 5000);
}

pub fn onQuit(_: *tray.Menu) void {
    tray_instance.exit();
}

pub fn main() !void {
    var icon = try qoi.decodeBuffer(std.heap.page_allocator, @embedFile("icon.qoi"));
    defer icon.deinit(std.heap.page_allocator);

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
https://github.com/MasterQ32/zig-qoi - loading qoi icon for main example
