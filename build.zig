const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const strip_debugging = b.option(
        bool,
        "strip",
        "strip debugging symbols",
    ) orelse false;

    // const lib = b.addStaticLibrary(.{
    //     .name = "zixel",
    //     // In this case the main source file is merely a path, however, in more
    //     // complicated build scripts, this could be a generated file.
    //     .root_source_file = b.path("src/RawImage.zig"),
    //     .target = target,
    //     .optimize = optimize,
    //     .strip = strip_debugging,
    // });
    //
    // // This declares intent for the library to be installed into the standard
    // // location when the user invokes the "install" step (the default step when
    // // running `zig build`).
    // lib.linkLibC();
    // b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "zixel",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip_debugging,
        // .linkage = .static,
    });

    const zigimg_dependency = b.dependency("zigimg", .{
        .target = target,
        .optimize = optimize,
        // .strip = strip_debugging,
    });

    exe.root_module.addImport(
        "zigimg",
        zigimg_dependency.module("zigimg"),
    );

    _ = b.addModule("zixel", .{
        .root_source_file = b.path("src/zixel.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip_debugging,
    });

    const obj_tui = b.addObject(.{
        .name = "zixel",
        .root_source_file = b.path("src/zixel.zig"),
        .target = target,
        .optimize = optimize,
    });

    const install_docs = b.addInstallDirectory(.{
        .source_dir = obj_tui.getEmittedDocs(),
        .install_dir = .{
            .custom = "../",
        },
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Generate documentation");
    docs_step.dependOn(&install_docs.step);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    // const lib_unit_tests = b.addTest(.{
    //     .root_source_file = b.path("src/root.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    //
    // const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    //
    // const exe_unit_tests = b.addTest(.{
    //     .root_source_file = b.path("src/main.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    //
    // const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    //
    // // Similar to creating the run step earlier, this exposes a `test` step to
    // // the `zig build --help` menu, providing a way for the user to request
    // // running the unit tests.
    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_lib_unit_tests.step);
    // test_step.dependOn(&run_exe_unit_tests.step);
}
