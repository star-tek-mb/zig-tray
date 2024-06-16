const std = @import("std");

pub fn build(b: *std.Build) !void {
    // get target
    const target = b.standardTargetOptions(.{});
    // get optimize
    const optimize = b.standardOptimizeOption(.{});

    // export zig-tray module
    const zigTray = switch (target.result.os.tag) {
        .windows => b.addModule("tray", .{
            .root_source_file = b.path("src/tray_windows.zig"),
        }),
        else => @panic("Unsupported platform, now only support windows"),
    };

    // build example
    example(b, target, optimize, zigTray);
}

/// for build example
fn example(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, module: *std.Build.Module) void {
    if (target.result.os.tag != .windows)
        return;

    // build example
    const exe = b.addExecutable(.{
        .name = "zig-tray",
        .root_source_file = b.path("example/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("tray", module);

    // install the icon file
    b.installFile("example/icon.ico", "bin/icon.ico");

    // install artifact
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
