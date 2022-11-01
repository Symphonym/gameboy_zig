const std = @import("std");

const zgui = @import("libs/zgui/build.zig");
const nfd = @import("libs/nfd-zig/build.zig");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("Gameboy", "src/main.zig");
    exe.linkLibC();
    exe.linkLibCpp();

    // SDL2
    exe.addIncludePath("libs/sdl2/include");
    exe.addLibraryPath("libs/sdl2/lib/x64");
    exe.linkSystemLibrary("sdl2");

    // Add zgui
    exe.addPackage(zgui.pkg);
    zgui.link(exe);

    // Add NFD
    exe.addPackage(nfd.getPackage("nfd"));
    const nfd_lib = nfd.makeLib(b, mode, target);
    exe.linkLibrary(nfd_lib);

    // Link SDL backend for Imgui
    exe.addIncludePath("libs/zgui/libs/imgui");
    exe.addIncludePath("libs/imgui_sdl_backend");
    exe.addCSourceFile("libs/imgui_sdl_backend/imgui_impl_sdlrenderer.cpp",  &[_][]const u8 {});
    exe.addCSourceFile("libs/imgui_sdl_backend/imgui_impl_sdl.cpp",  &[_][]const u8 {});

    // Link custom Zig bindings for SDL Imgui backend
    exe.addCSourceFile("src/wrappers/imgui_sdl_binding/sdl_imgui_backend.cpp",  &[_][]const u8 {});

    // exe.addIncludePath("libs/csfml/include");
    // exe.addLibraryPath("libs/csfml/lib/msvc/debug");
    // exe.linkSystemLibrary("csfml-graphics-d");
    // exe.linkSystemLibrary("csfml-system-d");
    // exe.linkSystemLibrary("csfml-window-d");
    // exe.linkSystemLibrary("csfml-audio-d");
    // exe.linkSystemLibrary("csfml-network-d");

    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();


    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
