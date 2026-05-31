const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const main_module = b.addModule("telegramz", .{
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    main_module.linkSystemLibrary("tdjson", .{});

    const exe = b.addExecutable(.{
        .name = "telegramz",
        .root_module = main_module,
    });

    b.installArtifact(exe);
}