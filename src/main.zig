const std = @import("std");
const tray = @import("tray");

pub fn onAction(menu: *tray.Menu) void {
    menu.tray.showNotification("zig-tray", "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book.", 5000);
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
                .text = "Привет",
                .onClick = onAction,
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
