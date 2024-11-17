const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sqlite = b.dependency("sqlite", .{ .target = target, .optimize = optimize });

    const lib = b.addStaticLibrary(.{
        .name = "zsqlite",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(sqlite.path(""));
    lib.installHeader(sqlite.path("sqlite3.h"), "sqlite3.h");
    lib.installHeader(sqlite.path("sqlite3ext.h"), "sqlite3ext.h");
    lib.addCSourceFiles(.{
        .root = sqlite.path(""),
        .files = &.{"sqlite3.c"},
    });
    lib.linkLibC();
    b.installArtifact(lib);

    const module = b.addModule("zsqlite", .{
        .root_source_file = b.path("src/root.zig"),
    });
    module.addIncludePath(sqlite.path(""));

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
