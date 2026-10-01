const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Options
    const upstream = b.dependency("upstream", .{});

    const build_static = b.option(bool, "static", "Build static library (default: true)") orelse true;
    const build_shared = b.option(bool, "shared", "Build shared library (default: true)") orelse true;
    const with_dyncol = b.option(bool, "dyncol", "Enable dynamic columns support (default: true)") orelse true;

    const SslBackend = enum { none, openssl, schannel };
    const default_ssl: SslBackend = if (target.result.os.tag == .windows)
        .schannel
    else
        .openssl;
    const ssl_backend = b.option(SslBackend, "ssl", "TLS/SSL backend (default: auto)") orelse default_ssl;

    const openssl_include_dir = b.option([]const u8, "openssl-include-dir", "OpenSSL include directory");
    const openssl_lib_dir = b.option([]const u8, "openssl-lib-dir", "OpenSSL library directory");

    const ZlibMode = enum { bundled, system };
    const zlib_mode = b.option(ZlibMode, "zlib", "Zlib implementation (default: bundled)") orelse .bundled;

    // Target properties
    const ptr_size: i64 = @as(i64, @intCast(@divExact(target.result.ptrBitWidth(), 8)));
    const long_size: i64 = if (target.result.os.tag == .windows or ptr_size == 4) 4 else 8;
    const is_windows = target.result.os.tag == .windows;
    const is_darwin = target.result.os.tag.isDarwin();
    const is_linux = target.result.os.tag == .linux;

    // 1. ma_config.h generated from upstream include/ma_config.h.in
    const ma_config_values = .{
        .HAVE_ALLOCA_H = !is_windows,
        .HAVE_BIGENDIAN = (target.result.cpu.arch.endian() == .big),
        .HAVE_SETLOCALE = true,
        .HAVE_NL_LANGINFO = !is_windows,
        .HAVE_DLFCN_H = !is_windows,
        .HAVE_FCNTL_H = !is_windows,
        .HAVE_FLOAT_H = true,
        .HAVE_LIMITS_H = true,
        .HAVE_LINUX_LIMITS_H = is_linux,
        .HAVE_PWD_H = !is_windows,
        .HAVE_SELECT_H = false,
        .HAVE_STDDEF_H = true,
        .HAVE_STDINT_H = true,
        .HAVE_STDLIB_H = true,
        .HAVE_STRING_H = true,
        .HAVE_SYS_IOCTL_H = !is_windows,
        .HAVE_SYS_SELECT_H = !is_windows,
        .HAVE_SYS_SOCKET_H = !is_windows,
        .HAVE_SYS_STAT_H = true,
        .HAVE_SYS_TYPES_H = true,
        .HAVE_SYS_UN_H = !is_windows,
        .HAVE_UNISTD_H = !is_windows,
        .HAVE_DLERROR = !is_windows,
        .HAVE_DLOPEN = true,
        .HAVE_GETPWUID = !is_windows,
        .HAVE_MEMCPY = true,
        .HAVE_POLL = !is_windows,
        .HAVE_STRTOK_R = !is_windows,
        .HAVE_STRTOL = true,
        .HAVE_STRTOLL = true,
        .HAVE_STRTOUL = true,
        .HAVE_STRTOULL = true,
        .HAVE_VSNPRINTF = true,
        .HAVE_OPENSSL_APPLINK_C = false,
        .HAVE_evp_pkey = (ssl_backend == .openssl),
        .DEFAULT_SSL_VERIFY_SERVER_CERT = true,

        .SIZEOF_CHARP = ptr_size,
        .SIZEOF_INT = @as(i64, 4),
        .SIZEOF_LONG = long_size,
        .SIZEOF_LONG_LONG = @as(i64, 8),
        .SIZEOF_SIZE_T = ptr_size,
        .SIZEOF_UINT = null,
        .SIZEOF_USHORT = null,
        .SIZEOF_ULONG = null,
        .SIZEOF_INT8 = null,
        .SIZEOF_UINT8 = null,
        .SIZEOF_INT16 = null,
        .SIZEOF_UINT16 = null,
        .SIZEOF_INT32 = null,
        .SIZEOF_UINT32 = null,
        .SIZEOF_INT64 = null,
        .SIZEOF_UINT64 = null,
        .SIZEOF_SOCKLEN_T = if (is_windows) null else @as(i64, 4),
        .SOCKET_SIZE_TYPE = if (is_windows) "int" else "socklen_t",
        .ENABLED_LOCAL_INFILE = "AUTO",
        .DEFAULT_CHARSET = "utf8mb4",
    };

    const ma_config_header = b.addConfigHeader(
        .{
            .style = .{ .cmake = upstream.path("include/ma_config.h.in") },
            .include_path = "ma_config.h",
        },
        ma_config_values,
    );

    // 2. mariadb_version.h generated from upstream mariadb_version.h.in
    const system_name = @tagName(target.result.os.tag);
    const machine_name = @tagName(target.result.cpu.arch);

    const version_header = b.addConfigHeader(
        .{
            .style = .{ .cmake = upstream.path("include/mariadb_version.h.in") },
            .include_path = "mariadb_version.h",
        },
        .{
            .PROTOCOL_VERSION = @as(i64, 10),
            .MARIADB_CLIENT_VERSION = "3.4.11",
            .MARIADB_BASE_VERSION = "mariadb-3.4",
            .MARIADB_VERSION_ID = @as(i64, 30411),
            .MARIADB_PORT = @as(i64, 3306),
            .MARIADB_UNIX_ADDR = "/tmp/mysql.sock",
            .CPACK_PACKAGE_VERSION = "3.4.11",
            .MARIADB_PACKAGE_VERSION_ID = @as(i64, 30411),
            .CMAKE_SYSTEM_NAME = system_name,
            .CMAKE_SYSTEM_PROCESSOR = machine_name,
            .CMAKE_INSTALL_PREFIX = "/usr/local",
            .INSTALL_PLUGINDIR = "lib/mariadb/plugin",
            .default_charset = "utf8mb4",
            .CC_SOURCE_REVISION = "3.4.11",
        },
    );

    // 3. ma_client_plugin.c generated from upstream libmariadb/ma_client_plugin.c.in
    const ssl_plugin_decl = if (ssl_backend != .none)
        \\extern struct st_mysql_client_plugin_AUTHENTICATION caching_sha2_password_client_plugin;
        \\extern struct st_mysql_client_plugin_AUTH sha256_password_client_plugin;
        \\extern struct st_mysql_client_plugin_AUTH client_ed25519_client_plugin;
        \\
    else
        "";

    const ssl_plugin_builtin = if (ssl_backend != .none)
        \\  (struct st_mysql_client_plugin *)&caching_sha2_password_client_plugin,
        \\  (struct st_mysql_client_plugin *)&sha256_password_client_plugin,
        \\  (struct st_mysql_client_plugin *)&client_ed25519_client_plugin,
        \\
    else
        "";

    const external_plugins = b.fmt(
        \\extern struct st_mysql_client_plugin_AUTH mysql_native_password_client_plugin;
        \\extern struct st_mysql_client_plugin_COMPRESSION zlib_client_plugin;
        \\extern struct st_mysql_client_plugin_PVIO pvio_socket_client_plugin;
        \\extern struct st_mysql_client_plugin_AUTH mysql_clear_password_client_plugin;
        \\extern struct st_mysql_client_plugin_AUTH dialog_client_plugin;
        \\{s}
    , .{ssl_plugin_decl});

    const builtin_plugins = b.fmt(
        \\(struct st_mysql_client_plugin *)&mysql_native_password_client_plugin,
        \\  (struct st_mysql_client_plugin *)&zlib_client_plugin,
        \\  (struct st_mysql_client_plugin *)&pvio_socket_client_plugin,
        \\  (struct st_mysql_client_plugin *)&mysql_clear_password_client_plugin,
        \\  (struct st_mysql_client_plugin *)&dialog_client_plugin,
        \\{s}
    , .{ssl_plugin_builtin});

    const client_plugin_c = b.addConfigHeader(
        .{
            .style = .{ .cmake = upstream.path("libmariadb/ma_client_plugin.c.in") },
            .include_path = "ma_client_plugin.c",
        },
        .{
            .PLUGINS_DISABLED = "mysql_old_password",
            .EXTERNAL_PLUGINS = external_plugins,
            .BUILTIN_PLUGINS = builtin_plugins,
        },
    );

    // 4. zconf.h for bundled zlib generated from external/zlib/zconf.h.cmakein
    const zconf_header = if (zlib_mode == .bundled) b.addConfigHeader(
        .{
            .style = .{ .cmake = upstream.path("external/zlib/zconf.h.cmakein") },
            .include_path = "zconf.h",
        },
        .{
            .Z_PREFIX = null,
            .Z_HAVE_UNISTD_H = if (is_windows) null else @as(i64, 1),
        },
    ) else null;

    // Common compiler flags
    const base_flags: []const []const u8 = &.{
        "-DHAVE_COMPRESS",
        "-DLIBMARIADB",
        "-DTHREAD",
        "-DLOCAL_INFILE_MODE_OFF=0",
        "-DLOCAL_INFILE_MODE_ON=1",
        "-DLOCAL_INFILE_MODE_AUTO=2",
        "-DENABLED_LOCAL_INFILE=LOCAL_INFILE_MODE_AUTO",
        "-DMARIADB_DEFAULT_CHARSET=\"utf8mb4\"",
    };
    const opt_flags: []const []const u8 = if (optimize != .Debug) &.{"-DDBUG_OFF=1"} else &.{};
    const darwin_flags: []const []const u8 = if (is_darwin) &.{
        "-D_DARWIN_C_SOURCE",
        "-D_XOPEN_SOURCE=600",
        "-Wno-deprecated-declarations",
    } else &.{};
    const linux_flags: []const []const u8 = if (is_linux) &.{
        "-D_GNU_SOURCE",
        "-D_LARGEFILE64_SOURCE=1",
    } else &.{};
    const non_win_flags: []const []const u8 = if (!is_windows) &.{"-DLIBICONV_PLUG"} else &.{};
    const win_flags: []const []const u8 = if (is_windows) &.{
        "-DWIN32_LEAN_AND_MEAN",
        "-DNOGDI",
        "-D_CRT_SECURE_NO_WARNINGS",
        "-D_CRT_NONSTDC_NO_DEPRECATE",
        "-DHAVE_DLOPEN",
    } else &.{};

    const ssl_flags: []const []const u8 = switch (ssl_backend) {
        .openssl => &.{
            "-DHAVE_OPENSSL",
            "-DHAVE_TLS",
            "-DHAVE_evp_pkey",
        },
        .schannel => &.{
            "-DHAVE_SCHANNEL",
            "-DHAVE_TLS",
            "-DHAVE_WINCRYPT",
        },
        .none => &.{},
    };

    const cflags = std.mem.concat(b.allocator, []const u8, &.{
        base_flags,
        opt_flags,
        darwin_flags,
        linux_flags,
        non_win_flags,
        win_flags,
        ssl_flags,
    }) catch @panic("OOM");

    // Source files
    const core_sources: []const []const u8 = &.{
        "plugins/auth/my_auth.c",
        "libmariadb/ma_array.c",
        "libmariadb/ma_charset.c",
        "libmariadb/ma_decimal.c",
        "libmariadb/ma_hashtbl.c",
        "libmariadb/ma_net.c",
        "libmariadb/mariadb_charset.c",
        "libmariadb/ma_time.c",
        "libmariadb/ma_default.c",
        "libmariadb/ma_errmsg.c",
        "libmariadb/mariadb_lib.c",
        "libmariadb/ma_list.c",
        "libmariadb/ma_pvio.c",
        "libmariadb/ma_tls.c",
        "libmariadb/ma_alloc.c",
        "libmariadb/ma_compress.c",
        "libmariadb/ma_init.c",
        "libmariadb/ma_password.c",
        "libmariadb/ma_ll2str.c",
        "libmariadb/mariadb_stmt.c",
        "libmariadb/ma_loaddata.c",
        "libmariadb/ma_stmt_codec.c",
        "libmariadb/ma_string.c",
        "libmariadb/ma_dtoa.c",
        "libmariadb/mariadb_rpl.c",
        "libmariadb/ma_io.c",
        "libmariadb/mariadb_async.c",
        "libmariadb/ma_context.c",
        // Builtin plugins
        "plugins/pvio/pvio_socket.c",
        "plugins/compress/c_zlib.c",
        "plugins/auth/dialog.c",
        "libmariadb/get_password.c",
        "plugins/auth/mariadb_cleartext.c",
    };

    const dyncol_sources: []const []const u8 = &.{"libmariadb/mariadb_dyncol.c"};

    const zlib_sources: []const []const u8 = &.{
        "external/zlib/adler32.c",
        "external/zlib/compress.c",
        "external/zlib/crc32.c",
        "external/zlib/deflate.c",
        "external/zlib/gzclose.c",
        "external/zlib/gzlib.c",
        "external/zlib/gzread.c",
        "external/zlib/gzwrite.c",
        "external/zlib/infback.c",
        "external/zlib/inffast.c",
        "external/zlib/inflate.c",
        "external/zlib/inftrees.c",
        "external/zlib/trees.c",
        "external/zlib/uncompr.c",
        "external/zlib/zutil.c",
    };

    const crypto_auth_sources: []const []const u8 = &.{
        "plugins/auth/caching_sha2_pw.c",
        "plugins/auth/sha256_pw.c",
        "plugins/auth/ed25519.c",
        "plugins/auth/ref10/fe_0.c",
        "plugins/auth/ref10/fe_1.c",
        "plugins/auth/ref10/fe_add.c",
        "plugins/auth/ref10/fe_cmov.c",
        "plugins/auth/ref10/fe_copy.c",
        "plugins/auth/ref10/fe_frombytes.c",
        "plugins/auth/ref10/fe_invert.c",
        "plugins/auth/ref10/fe_isnegative.c",
        "plugins/auth/ref10/fe_isnonzero.c",
        "plugins/auth/ref10/fe_mul.c",
        "plugins/auth/ref10/fe_neg.c",
        "plugins/auth/ref10/fe_pow22523.c",
        "plugins/auth/ref10/fe_sq.c",
        "plugins/auth/ref10/fe_sq2.c",
        "plugins/auth/ref10/fe_sub.c",
        "plugins/auth/ref10/fe_tobytes.c",
        "plugins/auth/ref10/ge_add.c",
        "plugins/auth/ref10/ge_double_scalarmult.c",
        "plugins/auth/ref10/ge_frombytes.c",
        "plugins/auth/ref10/ge_madd.c",
        "plugins/auth/ref10/ge_msub.c",
        "plugins/auth/ref10/ge_p1p1_to_p2.c",
        "plugins/auth/ref10/ge_p1p1_to_p3.c",
        "plugins/auth/ref10/ge_p2_0.c",
        "plugins/auth/ref10/ge_p2_dbl.c",
        "plugins/auth/ref10/ge_p3_0.c",
        "plugins/auth/ref10/ge_p3_dbl.c",
        "plugins/auth/ref10/ge_p3_to_cached.c",
        "plugins/auth/ref10/ge_p3_to_p2.c",
        "plugins/auth/ref10/ge_p3_tobytes.c",
        "plugins/auth/ref10/ge_tobytes.c",
        "plugins/auth/ref10/ge_precomp_0.c",
        "plugins/auth/ref10/ge_scalarmult_base.c",
        "plugins/auth/ref10/ge_sub.c",
        "plugins/auth/ref10/keypair.c",
        "plugins/auth/ref10/open.c",
        "plugins/auth/ref10/sc_muladd.c",
        "plugins/auth/ref10/sc_reduce.c",
        "plugins/auth/ref10/sign.c",
        "plugins/auth/ref10/verify.c",
    };

    const openssl_sources: []const []const u8 = &.{
        "libmariadb/secure/openssl.c",
        "libmariadb/secure/openssl_crypt.c",
    };

    const schannel_sources: []const []const u8 = &.{
        "libmariadb/secure/schannel.c",
        "libmariadb/secure/win_crypt.c",
        "libmariadb/secure/ma_schannel.c",
        "libmariadb/secure/schannel_certs.c",
    };

    const win_sources: []const []const u8 = &.{
        "win-iconv/win_iconv.c",
        "libmariadb/win32_errmsg.c",
        "plugins/pvio/pvio_npipe.c",
        "plugins/pvio/pvio_shmem.c",
    };

    const all_sources = std.mem.concat(b.allocator, []const u8, &.{
        core_sources,
        if (with_dyncol) dyncol_sources else &.{},
        if (zlib_mode == .bundled) zlib_sources else &.{},
        if (ssl_backend != .none) crypto_auth_sources else &.{},
        switch (ssl_backend) {
            .openssl => openssl_sources,
            .schannel => schannel_sources,
            .none => &.{},
        },
        if (is_windows) win_sources else &.{},
    }) catch @panic("OOM");

    // Configure function
    const configureTarget = struct {
        fn run(
            step: *std.Build.Step.Compile,
            sources_list: []const []const u8,
            cflags_list: []const []const u8,
            upstream_dep: *std.Build.Dependency,
            version_h: *std.Build.Step.ConfigHeader,
            ma_config_h: *std.Build.Step.ConfigHeader,
            zconf_h: ?*std.Build.Step.ConfigHeader,
            client_plugin_file: std.Build.LazyPath,
            ssl: SslBackend,
            zlib: ZlibMode,
            win: bool,
            linux: bool,
            custom_openssl_inc: ?[]const u8,
            custom_openssl_lib: ?[]const u8,
        ) void {
            step.root_module.link_libc = true;

            // Config headers
            step.root_module.addConfigHeader(version_h);
            step.root_module.addConfigHeader(ma_config_h);
            if (zconf_h) |zh| {
                step.root_module.addConfigHeader(zh);
            }

            // Include paths
            step.root_module.addIncludePath(upstream_dep.path("include"));
            step.root_module.addIncludePath(upstream_dep.path("libmariadb"));
            step.root_module.addIncludePath(upstream_dep.path("plugins/pvio"));
            step.root_module.addIncludePath(upstream_dep.path("plugins/auth"));
            step.root_module.addIncludePath(upstream_dep.path("plugins/auth/ref10"));
            step.root_module.addIncludePath(upstream_dep.path("plugins/compress"));
            if (zlib == .bundled) {
                step.root_module.addIncludePath(upstream_dep.path("external/zlib"));
            }

            // Upstream sources
            step.root_module.addCSourceFiles(.{
                .root = upstream_dep.path(""),
                .files = sources_list,
                .flags = cflags_list,
            });

            // Generated ma_client_plugin.c
            step.root_module.addCSourceFile(.{
                .file = client_plugin_file,
                .flags = cflags_list,
            });

            // SSL linking
            if (ssl == .openssl) {
                if (custom_openssl_inc) |p| {
                    step.root_module.addIncludePath(.{ .cwd_relative = p });
                }
                if (custom_openssl_lib) |p| {
                    step.root_module.addLibraryPath(.{ .cwd_relative = p });
                }

                step.root_module.linkSystemLibrary("ssl", .{});
                step.root_module.linkSystemLibrary("crypto", .{});
            } else if (ssl == .schannel) {
                step.root_module.linkSystemLibrary("secur32", .{});
                step.root_module.linkSystemLibrary("crypt32", .{});
                step.root_module.linkSystemLibrary("bcrypt", .{});
            }

            // System libraries
            if (win) {
                step.root_module.linkSystemLibrary("ws2_32", .{});
                step.root_module.linkSystemLibrary("advapi32", .{});
                step.root_module.linkSystemLibrary("kernel32", .{});
                step.root_module.linkSystemLibrary("shlwapi", .{});
            } else if (linux) {
                step.root_module.linkSystemLibrary("m", .{});
                step.root_module.linkSystemLibrary("pthread", .{});
            }

            if (zlib == .system) {
                step.root_module.linkSystemLibrary("z", .{});
            }
        }
    };

    var static_lib: ?*std.Build.Step.Compile = null;
    var shared_lib: ?*std.Build.Step.Compile = null;

    if (build_static) {
        const lib = b.addLibrary(.{
            .name = "mariadbclient",
            .linkage = .static,
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
            }),
        });
        configureTarget.run(
            lib,
            all_sources,
            cflags,
            upstream,
            version_header,
            ma_config_header,
            zconf_header,
            client_plugin_c.getOutputFile(),
            ssl_backend,
            zlib_mode,
            is_windows,
            is_linux,
            openssl_include_dir,
            openssl_lib_dir,
        );
        b.installArtifact(lib);
        static_lib = lib;
    }

    if (build_shared) {
        const lib = b.addLibrary(.{
            .name = "mariadb",
            .linkage = .dynamic,
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
            }),
        });
        configureTarget.run(
            lib,
            all_sources,
            cflags,
            upstream,
            version_header,
            ma_config_header,
            zconf_header,
            client_plugin_c.getOutputFile(),
            ssl_backend,
            zlib_mode,
            is_windows,
            is_linux,
            openssl_include_dir,
            openssl_lib_dir,
        );
        b.installArtifact(lib);
        shared_lib = lib;
    }

    // Default primary artifact for linking
    const primary_lib = static_lib orelse shared_lib.?;

    // Header installations (installed on both so either artifact provides headers when linked)
    for (&[_]?*std.Build.Step.Compile{ static_lib, shared_lib }) |maybe_lib| {
        if (maybe_lib) |lib| {
            lib.installHeadersDirectory(upstream.path("include"), "", .{});
            lib.installConfigHeader(version_header);
            lib.installConfigHeader(ma_config_header);
            if (zconf_header) |zh| {
                lib.installConfigHeader(zh);
            }
        }
    }

    b.addNamedLazyPath("include", primary_lib.getEmittedIncludeTree());

    // Expose as a Zig module for consumers
    const mod = b.addModule("mariadb", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });
    mod.link_libc = true;
    if (is_darwin) {
        mod.addCMacro("_DARWIN_C_SOURCE", "");
    } else if (is_linux) {
        mod.addCMacro("_GNU_SOURCE", "");
    }
    mod.addConfigHeader(version_header);
    mod.addConfigHeader(ma_config_header);
    if (zconf_header) |zh| {
        mod.addConfigHeader(zh);
    }
    mod.addIncludePath(upstream.path("include"));
    mod.linkLibrary(primary_lib);

    // Unit tests
    const unit_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
