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

    // generate docs
    generateDocs(b, target, optimize);

    // build example
    example(b, target, optimize, zigTray);
}

/// for generate docs
fn generateDocs(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const zig_tray_obj = b.addObject(.{
        .name = "zig-tray-obj",
        .root_source_file = b.path("src/tray_windows.zig"),
        .target = target,
        .optimize = optimize,
    });

    const docs_step = b.step("docs", "Generate docs");

    const docs_install = b.addInstallDirectory(.{
        .source_dir = zig_tray_obj.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    docs_step.dependOn(&docs_install.step);
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

    const installfile = b.addInstallFile(b.path("example/icon.ico"), "bin/icon.ico");

    const artiface = b.addInstallArtifact(exe, .{});

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(&installfile.step);
    run_cmd.step.dependOn(&artiface.step);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("example", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
