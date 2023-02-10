const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .x86_64,
            .os_tag = .windows,
            .abi = .gnu,
        },
    });
    const optimize = b.standardOptimizeOption(.{});

    b.addModule(.{
        .name = "tray",
        .source_file = .{ .path = "src/tray.zig" },
    });

    const exe = b.addExecutable(.{
        .name = "zig-tray",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.addModule("tray", b.modules.get("tray").?);
    exe.install();

    const icon_step = b.addInstallFile(.{ .path = "src/icon.ico" }, "bin/icon.ico");
    try icon_step.step.make();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
