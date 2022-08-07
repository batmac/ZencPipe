const std = @import("std");
const deps = @import("deps.zig");
const libhydrogenDir = "libhydrogen";

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("ZencPipe", "src/main.zig");
    deps.addAllTo(exe);
    addLib(exe);
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.linkLibC();

    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const lib_tests = b.addSystemCommand(&.{ "make", "-C", libhydrogenDir, "test" });
    const exe_tests = b.addTest("src/main.zig");
    deps.addAllTo(exe_tests);
    addLib(exe_tests);
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&lib_tests.step);
    test_step.dependOn(&exe_tests.step);
}

fn addLib(exe: *std.build.LibExeObjStep) void {
    exe.linkLibC();
    exe.addCSourceFile(libhydrogenDir ++ "/" ++ "hydrogen.c", &.{
        "-pedantic",
        "-Wall",
        "-Wextra",
    });
    exe.addIncludeDir(libhydrogenDir);
}
