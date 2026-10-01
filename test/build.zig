const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mariadb_dep = b.dependency("mariadb_connector", .{
        .target = target,
        .optimize = optimize,
    });

    const c_h = b.addWriteFiles().add("c.h",
        \\#include <mysql.h>
        \\#include <errmsg.h>
        \\#include <mariadb_version.h>
    );

    const translate_c = b.addTranslateC(.{
        .root_source_file = c_h,
        .target = target,
        .optimize = optimize,
    });
    translate_c.addIncludePath(mariadb_dep.namedLazyPath("include"));
    const c_mod = translate_c.createModule();

    const exe = b.addExecutable(.{
        .name = "mariadb-test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "c", .module = c_mod },
            },
        }),
    });
    exe.root_module.linkLibrary(mariadb_dep.artifact("mariadbclient"));
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run test application");
    run_step.dependOn(&run_cmd.step);
}
