const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "example",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = if (optimize != .Debug) true else false,
    });
    
    const regulus_dep = b.dependency("regulus", .{
        .target = target,
        .optimize = std.builtin.OptimizeMode.ReleaseFast,
    });
    
    b.installArtifact(exe);

    // Install regulus
    const regulus_step = b.step("regulus", "Install regulus dialog menu");

    const regulus_exe = regulus_dep.artifact("regulus");
    const regulus_install_step = &b.addInstallArtifact(regulus_exe, .{}).step;
    regulus_step.dependOn(regulus_install_step);

    // Copy zig-out/bin/regulus to project root
    var copy_step: *std.Build.Step = undefined;

    switch (builtin.target.os.tag) {
        .windows => {
            copy_step = &b.addInstallBinFile(b.path("zig-out/bin/regulus.exe"), "../../regulus.exe").step;
        },
        else => {
            copy_step = &b.addInstallBinFile(b.path("zig-out/bin/regulus"), "../../regulus").step;
        }
    }

    copy_step.dependOn(regulus_install_step);
    regulus_step.dependOn(copy_step);

    // Run step
    const run_step = b.step("run", "Run the application");

    const run_cmd = b.addRunArtifact(exe);
    const install_step = b.getInstallStep();

    // Compile regulus only once when running zig build run
    const regulus_path = switch (builtin.os.tag) {
        .windows => "regulus.exe",
        else => "regulus",
    };

    std.fs.cwd().access(regulus_path, .{}) catch {
        install_step.dependOn(regulus_step);
    };
    
    run_cmd.step.dependOn(install_step);
    run_step.dependOn(&run_cmd.step);
}
