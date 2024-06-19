const std = @import("std");
const tray = @import("tray");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    const allocator = gpa.allocator();
    defer if (gpa.deinit() == .leak) @panic("TEST FAIL");

    var tray_instance = tray.Tray{};
    try tray_instance.init(
        allocator,
        // enable high dp support, default is true
        null,
        try tray.createIconFromFile("icon.ico"),
        &first_layer_menu,
        onPopupClick,
        onClick,
        10_000_000,
    );
    defer tray_instance.deinit();
    tray_instance.run();
}

var first_layer_menu = [_]tray.ConstMenu{
    .{
        .text = .{ .text = "Hello" },
        .onClick = onHello,
    },
    .{
        .text = .{ .text = "submenus" },
        .submenu = &second_layer_menu,
    },
    .{
        .text = .{ .separator = void{} },
    },
    .{
        .text = .{ .text = "Quit" },
        .onClick = onQuit,
    },
};

var second_layer_menu = [_]tray.ConstMenu{
    .{
        .text = .{ .text = "first" },
        .onClick = subCallback("first"),
    },
    .{
        .text = .{ .text = "second" },
        .onClick = subCallback("second"),
        .submenu = &third_layer_menu,
    },
};

var third_layer_menu = [_]tray.ConstMenu{
    .{
        .text = .{ .text = "fourth" },
        .onClick = subCallback("fourth"),
    },
    .{
        .text = .{ .text = "fifth" },
        .onClick = subCallback("fifth"),
    },
};

pub fn onHello(menu: *tray.Menu) void {
    _ = menu.tray.showNotification("zig-tray",
        \\This is just a notification message.
        \\Now, please click this message!
    , 5000);
}

fn subCallback(comptime message: []const u8) *const fn (*tray.Menu) void {
    return struct {
        fn handle(_: *tray.Menu) void {
            std.log.info("click {s} sub menu", .{message});
        }
    }.handle;
}

pub fn onQuit(menu: *tray.Menu) void {
    menu.tray.exit();
}

pub fn onPopupClick(_: *tray.Tray) void {
    std.log.info("click the system notification", .{});
}

pub fn onClick(_: *tray.Tray) void {
    std.log.info("the mouse left click the tray icon", .{});
}
