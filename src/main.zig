const std = @import("std");
const tray = @import("tray.zig");
const qoi = @import("qoi.zig");

var tray_instance: *tray.Tray = undefined;

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
    tray_instance.run();
}
