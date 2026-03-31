const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("znow", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // simple tests
    const znow_test = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    }) });

    const run_test = b.addRunArtifact(znow_test);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_test.step);
}
