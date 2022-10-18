# Overview

zig-tray is a library for creating tray applications.

# Supported platforms

 - [x] Windows
 - [ ] Linux
 - [ ] MacOS

# Installation

```
zig build
```

# Usage

```rust
const std = @import("std");
const tray = @import("tray.zig");
const qoi = @import("qoi.zig");

var tray_instance: *tray.Tray = undefined;

pub fn onQuit(_: *tray.Menu) void {
    tray_instance.exit();
}

pub fn main() !void {
    tray_instance = try tray.Tray.create(
        std.heap.page_allocator,
        try tray.createIconFromFile("icon.ico"),
        &[_]tray.ConstMenu{
            .{
                .text = "Hello",
                .submenu = &[_]tray.ConstMenu{
                    .{
                        .text = "Submenu",
                    },
                },
            },
            .{
                .text = "Quit",
                .onClick = onQuit,
            },
        },
    );
    defer tray_instance.deinit(std.heap.page_allocator);
    while (tray_instance.loop()) {}
    tray_instance.exit();
}
```

see **main.zig** for another example

# Credits

https://github.com/zserge/tray - for initial C library
https://github.com/glfw/glfw/blob/master/src/win32_window.c#L102 - for icon creating from rgba
https://github.com/MasterQ32/zig-qoi - loading qoi icon for main example
