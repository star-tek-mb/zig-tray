const std = @import("std");
const tray = @import("tray.zig");
const qoi = @import("qoi.zig");

var tray_instance: *tray.Tray = undefined;

pub fn onHello(menu: *tray.Menu) void {
    menu.disabled = true;
}

pub fn toggleMenu(menu: *tray.Menu) void {
    menu.checked = !menu.checked;
}

pub fn onQuit(_: *tray.Menu) void {
    tray_instance.exit();
}

pub fn main() !void {
    var icon = try qoi.decodeBuffer(std.heap.page_allocator, @embedFile("icon.qoi"));

    tray_instance = try tray.Tray.create(
        std.heap.page_allocator,
        try tray.createIconFromRGBA(std.mem.sliceAsBytes(icon.pixels), icon.width, icon.height),
        &[_]tray.ConstMenu{
            .{
                .text = "Hello",
                .onClick = onHello,
                .submenu = &[_]tray.ConstMenu{
                    .{
                        .text = "submenu",
                        .onClick = toggleMenu,
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
