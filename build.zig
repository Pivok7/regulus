const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void{
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "regulus",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = optimize != .Debug,
    });
    

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);

    const zclay_dep = b.dependency("zclay", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zclay", zclay_dep.module("zclay"));

    const truetype_dep = b.dependency("TrueType", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("truetype", truetype_dep.module("TrueType"));

    b.installArtifact(exe);

    // Run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);
}
