const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zsqlite_mod = b.addModule("zsqlite", .{
        .root_source_file = b.path("src/root.zig"),
    });

    // Add SQLite C as a static library
    const zsqlite_c = b.dependency("zsqlite-c", .{ .target = target, .optimize = optimize });
    const zsqlite_c_artifact = zsqlite_c.artifact("zsqlite-c");
    zsqlite_mod.linkLibrary(zsqlite_c_artifact);

    const zsqlite_lib_test = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    zsqlite_lib_test.linkLibrary(zsqlite_c_artifact);
    const zsqlite_lib_test_run = b.addRunArtifact(zsqlite_lib_test);

    const step_test = b.step("test", "Run unit tests");
    step_test.dependOn(&zsqlite_lib_test_run.step);
}
