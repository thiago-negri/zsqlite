const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sqlite = b.dependency("sqlite", .{ .target = target, .optimize = optimize });

    const lib = b.addStaticLibrary(.{
        .name = "zsqlite",
        .target = target,
        .optimize = optimize,
    });
    lib.installHeader(sqlite.path("sqlite3.h"), "sqlite3.h");
    lib.installHeader(sqlite.path("sqlite3ext.h"), "sqlite3ext.h");
    lib.addCSourceFiles(.{
        .root = sqlite.path(""),
        .files = &.{"sqlite3.c"},
    });
    lib.linkLibC();
    b.installArtifact(lib);
}
