const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const build_options = .{
        .track_open_statements = b.option(
            bool,
            "track_open_statements",
            "Whether ZSQLite will track open Statements and report any leaks during database close",
        ) orelse true,
    };

    const options = b.addOptions();
    options.addOption(bool, "track_open_statements", build_options.track_open_statements);

    const zsqlite_mod = b.addModule("zsqlite", .{
        .root_source_file = b.path("src/root.zig"),
    });
    zsqlite_mod.addOptions("build_options", options);

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
    zsqlite_lib_test.root_module.addOptions("build_options", options);
    const zsqlite_lib_test_run = b.addRunArtifact(zsqlite_lib_test);

    const step_test = b.step("test", "Run unit tests");
    step_test.dependOn(&zsqlite_lib_test_run.step);
}
