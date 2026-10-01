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
    const ptr_size: usize = @divExact(target.result.ptrBitWidth(), 8);
    const long_size: usize = if (target.result.os.tag == .windows or ptr_size == 4) 4 else 8;
    const is_windows = target.result.os.tag == .windows;
    const is_darwin = target.result.os.tag.isDarwin();
    const is_linux = target.result.os.tag == .linux;

    // Generated files
    const wf = b.addWriteFiles();

    // 1. ma_config.h
    const os_defines = if (is_windows)
        \\#define SOCKET_SIZE_TYPE int
        \\#define HAVE_DLOPEN 1
        \\#define _CRT_SECURE_NO_WARNINGS 1
        \\#define _CRT_NONSTDC_NO_DEPRECATE 1
        \\#define HAVE_FLOAT_H 1
        \\#define HAVE_LIMITS_H 1
        \\#define HAVE_STDDEF_H 1
        \\#define HAVE_STDINT_H 1
        \\#define HAVE_STDLIB_H 1
        \\#define HAVE_STRING_H 1
        \\#define HAVE_SYS_STAT_H 1
        \\#define HAVE_SYS_TYPES_H 1
        \\#define HAVE_FCNTL_H 1
        \\#define HAVE_MEMCPY 1
        \\#define HAVE_MEMMOVE 1
        \\#define HAVE_SETLOCALE 1
    else if (is_linux)
        \\#define SOCKET_SIZE_TYPE socklen_t
        \\#define HAVE_ALLOCA_H 1
        \\#define HAVE_DLFCN_H 1
        \\#define HAVE_FCNTL_H 1
        \\#define HAVE_FLOAT_H 1
        \\#define HAVE_LIMITS_H 1
        \\#define HAVE_LINUX_LIMITS_H 1
        \\#define HAVE_PWD_H 1
        \\#define HAVE_STDDEF_H 1
        \\#define HAVE_STDINT_H 1
        \\#define HAVE_STDLIB_H 1
        \\#define HAVE_STRING_H 1
        \\#define HAVE_SYS_IOCTL_H 1
        \\#define HAVE_SYS_SELECT_H 1
        \\#define HAVE_SYS_SOCKET_H 1
        \\#define HAVE_SYS_STAT_H 1
        \\#define HAVE_SYS_TYPES_H 1
        \\#define HAVE_SYS_UN_H 1
        \\#define HAVE_UNISTD_H 1
        \\#define HAVE_DLERROR 1
        \\#define HAVE_DLOPEN 1
        \\#define HAVE_GETPWUID 1
        \\#define HAVE_MEMCPY 1
        \\#define HAVE_POLL 1
        \\#define HAVE_SETLOCALE 1
        \\#define HAVE_NL_LANGINFO 1
    else
        \\#define SOCKET_SIZE_TYPE socklen_t
        \\#define HAVE_ALLOCA_H 1
        \\#define HAVE_DLFCN_H 1
        \\#define HAVE_FCNTL_H 1
        \\#define HAVE_FLOAT_H 1
        \\#define HAVE_LIMITS_H 1
        \\#define HAVE_PWD_H 1
        \\#define HAVE_STDDEF_H 1
        \\#define HAVE_STDINT_H 1
        \\#define HAVE_STDLIB_H 1
        \\#define HAVE_STRING_H 1
        \\#define HAVE_SYS_IOCTL_H 1
        \\#define HAVE_SYS_SELECT_H 1
        \\#define HAVE_SYS_SOCKET_H 1
        \\#define HAVE_SYS_STAT_H 1
        \\#define HAVE_SYS_TYPES_H 1
        \\#define HAVE_SYS_UN_H 1
        \\#define HAVE_UNISTD_H 1
        \\#define HAVE_DLERROR 1
        \\#define HAVE_DLOPEN 1
        \\#define HAVE_GETPWUID 1
        \\#define HAVE_MEMCPY 1
        \\#define HAVE_POLL 1
        \\#define HAVE_SETLOCALE 1
        \\#define HAVE_NL_LANGINFO 1
    ;

    const ssl_defines = switch (ssl_backend) {
        .openssl =>
        \\#define HAVE_OPENSSL 1
        \\#define HAVE_TLS 1
        \\#define HAVE_evp_pkey 1
        ,
        .schannel =>
        \\#define HAVE_SCHANNEL 1
        \\#define HAVE_TLS 1
        \\#define HAVE_WINCRYPT 1
        ,
        .none => "",
    };

    const config_h = std.fmt.allocPrint(
        b.allocator,
        \\#ifndef _ma_config_h
        \\#define _ma_config_h
        \\
        \\#define SIZEOF_CHARP {d}
        \\#define HAVE_CHARP 1
        \\#define SIZEOF_INT 4
        \\#define HAVE_INT 1
        \\#define SIZEOF_LONG {d}
        \\#define HAVE_LONG 1
        \\#define SIZEOF_LONG_LONG 8
        \\#define HAVE_LONG_LONG 1
        \\#define SIZEOF_SIZE_T {d}
        \\#define HAVE_SIZE_T 1
        \\
        \\{s}
        \\{s}
        \\
        \\#define LOCAL_INFILE_MODE_OFF  0
        \\#define LOCAL_INFILE_MODE_ON   1
        \\#define LOCAL_INFILE_MODE_AUTO 2
        \\#define ENABLED_LOCAL_INFILE LOCAL_INFILE_MODE_AUTO
        \\#define MARIADB_DEFAULT_CHARSET "utf8mb4"
        \\#define DEFAULT_SSL_VERIFY_SERVER_CERT 1
        \\
        \\#endif /* _ma_config_h */
        \\
    , .{
        ptr_size,
        long_size,
        ptr_size,
        os_defines,
        ssl_defines,
    }) catch @panic("OOM");

    _ = wf.add("include/ma_config.h", config_h);
    _ = wf.add("include/config.h", config_h);

    // 2. mariadb_version.h
    const system_name = @tagName(target.result.os.tag);
    const machine_name = @tagName(target.result.cpu.arch);

    const version_h = std.fmt.allocPrint(
        b.allocator,
        \\#ifndef _mariadb_version_h_
        \\#define _mariadb_version_h_
        \\
        \\#define PROTOCOL_VERSION 10
        \\#define MARIADB_CLIENT_VERSION_STR "10.8.8"
        \\#define MARIADB_BASE_VERSION "mariadb-10.8"
        \\#define MARIADB_VERSION_ID 100808
        \\#define MARIADB_PORT 3306
        \\#define MARIADB_UNIX_ADDR "/tmp/mysql.sock"
        \\#ifndef MYSQL_UNIX_ADDR
        \\#define MYSQL_UNIX_ADDR MARIADB_UNIX_ADDR
        \\#endif
        \\#ifndef MYSQL_PORT
        \\#define MYSQL_PORT MARIADB_PORT
        \\#endif
        \\
        \\#define MYSQL_CONFIG_NAME "my"
        \\#define MYSQL_VERSION_ID 100808
        \\#define MYSQL_SERVER_VERSION "10.8.8-MariaDB"
        \\
        \\#define MARIADB_PACKAGE_VERSION "3.4.11"
        \\#define MARIADB_PACKAGE_VERSION_ID 30411
        \\#define MARIADB_SYSTEM_TYPE "{s}"
        \\#define MARIADB_MACHINE_TYPE "{s}"
        \\#define MARIADB_PLUGINDIR "/usr/local/lib/mariadb/plugin"
        \\
        \\#ifndef MYSQL_CHARSET
        \\#define MYSQL_CHARSET ""
        \\#endif
        \\
        \\#define CC_SOURCE_REVISION "3.4.11"
        \\
        \\#endif /* _mariadb_version_h_ */
        \\
    , .{ system_name, machine_name }) catch @panic("OOM");

    _ = wf.add("include/mariadb_version.h", version_h);

    // 3. ma_client_plugin.c
    const ssl_plugin_decl = if (ssl_backend != .none)
        \\extern struct st_mysql_client_plugin_AUTHENTICATION caching_sha2_password_client_plugin;
        \\extern struct st_mysql_client_plugin_AUTH sha256_password_client_plugin;
        \\extern struct st_mysql_client_plugin_AUTH client_ed25519_client_plugin;
    else
        "";

    const ssl_plugin_builtin = if (ssl_backend != .none)
        \\  (struct st_mysql_client_plugin *)&caching_sha2_password_client_plugin,
        \\  (struct st_mysql_client_plugin *)&sha256_password_client_plugin,
        \\  (struct st_mysql_client_plugin *)&client_ed25519_client_plugin,
    else
        "";

    const template_path = upstream.path("libmariadb/ma_client_plugin.c.in").getPath(b);
    const template_content = std.Io.Dir.cwd().readFileAlloc(b.graph.io, template_path, b.allocator, .limited(2 * 1024 * 1024)) catch @panic("Failed to read ma_client_plugin.c.in");
    const marker = "static int is_not_initialized(MYSQL *mysql, const char *name)";
    const marker_idx = std.mem.indexOf(u8, template_content, marker) orelse @panic("Could not find marker in ma_client_plugin.c.in");
    const rest_content = template_content[marker_idx..];

    const client_plugin_c = std.fmt.allocPrint(
        b.allocator,
        \\#define FORCE_INIT_OF_VARS 1
        \\#include <ma_global.h>
        \\#include <ma_sys.h>
        \\#include <ma_common.h>
        \\#include <ma_string.h>
        \\#include <ma_pthread.h>
        \\#include "errmsg.h"
        \\#include <mysql/client_plugin.h>
        \\
        \\#ifndef WIN32
        \\#include <dlfcn.h>
        \\#endif
        \\
        \\const char *disabled_plugins = "mysql_old_password";
        \\
        \\struct st_client_plugin_int {{
        \\  struct st_client_plugin_int *next;
        \\  void   *dlhandle;
        \\  struct st_mysql_client_plugin *plugin;
        \\}};
        \\
        \\static my_bool initialized = 0;
        \\static MA_MEM_ROOT mem_root;
        \\
        \\static uint valid_plugins[][2] = {{
        \\  {{MYSQL_CLIENT_AUTHENTICATION_PLUGIN, MYSQL_CLIENT_AUTHENTICATION_PLUGIN_INTERFACE_VERSION}},
        \\  {{MARIADB_CLIENT_PVIO_PLUGIN, MARIADB_CLIENT_PVIO_PLUGIN_INTERFACE_VERSION}},
        \\  {{MARIADB_CLIENT_TRACE_PLUGIN, MARIADB_CLIENT_TRACE_PLUGIN_INTERFACE_VERSION}},
        \\  {{MARIADB_CLIENT_REMOTEIO_PLUGIN, MARIADB_CLIENT_REMOTEIO_PLUGIN_INTERFACE_VERSION}},
        \\  {{MARIADB_CLIENT_CONNECTION_PLUGIN, MARIADB_CLIENT_CONNECTION_PLUGIN_INTERFACE_VERSION}},
        \\  {{MARIADB_CLIENT_COMPRESSION_PLUGIN, MARIADB_CLIENT_COMPRESSION_PLUGIN_INTERFACE_VERSION}},
        \\  {{0, 0}}
        \\}};
        \\
        \\struct st_client_plugin_int *plugin_list[MYSQL_CLIENT_MAX_PLUGINS + MARIADB_CLIENT_MAX_PLUGINS];
        \\#ifdef THREAD
        \\static pthread_mutex_t LOCK_load_client_plugin;
        \\#endif
        \\
        \\extern struct st_mysql_client_plugin_AUTH mysql_native_password_client_plugin;
        \\extern struct st_mysql_client_plugin_COMPRESSION zlib_client_plugin;
        \\extern struct st_mysql_client_plugin_PVIO pvio_socket_client_plugin;
        \\extern struct st_mysql_client_plugin_AUTH mysql_clear_password_client_plugin;
        \\extern struct st_mysql_client_plugin_AUTH dialog_client_plugin;
        \\{s}
        \\
        \\struct st_mysql_client_plugin *mysql_client_builtins[] = {{
        \\  (struct st_mysql_client_plugin *)&mysql_native_password_client_plugin,
        \\  (struct st_mysql_client_plugin *)&zlib_client_plugin,
        \\  (struct st_mysql_client_plugin *)&pvio_socket_client_plugin,
        \\  (struct st_mysql_client_plugin *)&mysql_clear_password_client_plugin,
        \\  (struct st_mysql_client_plugin *)&dialog_client_plugin,
        \\{s}
        \\  0
        \\}};
        \\
        \\{s}
    , .{
        ssl_plugin_decl,
        ssl_plugin_builtin,
        rest_content,
    }) catch @panic("OOM");

    _ = wf.add("libmariadb/ma_client_plugin.c", client_plugin_c);

    // 4. zconf.h for bundled zlib
    if (zlib_mode == .bundled) {
        const zconf_in_path = upstream.path("external/zlib/zconf.h.cmakein").getPath(b);
        const zconf_raw = std.Io.Dir.cwd().readFileAlloc(b.graph.io, zconf_in_path, b.allocator, .limited(1024 * 1024)) catch @panic("Failed to read zconf.h.cmakein");
        const zconf_s1 = std.mem.replaceOwned(u8, b.allocator, zconf_raw, "#cmakedefine Z_PREFIX", "/* #undef Z_PREFIX */") catch @panic("OOM");
        const zconf_s2 = std.mem.replaceOwned(u8, b.allocator, zconf_s1, "#cmakedefine Z_HAVE_UNISTD_H", "#define Z_HAVE_UNISTD_H 1") catch @panic("OOM");
        _ = wf.add("include/zconf.h", zconf_s2);
        _ = wf.add("external/zlib/zconf.h", zconf_s2);
    }

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

    const gen_dir = wf.getDirectory();
    const inc_dir = gen_dir.path(b, "include");

    // Configure function
    const configureTarget = struct {
        fn run(
            step: *std.Build.Step.Compile,
            b_ctx: *std.Build,
            sources_list: []const []const u8,
            cflags_list: []const []const u8,
            upstream_dep: *std.Build.Dependency,
            gen: std.Build.LazyPath,
            inc: std.Build.LazyPath,
            ssl: SslBackend,
            zlib: ZlibMode,
            darwin: bool,
            win: bool,
            linux: bool,
            custom_openssl_inc: ?[]const u8,
            custom_openssl_lib: ?[]const u8,
        ) void {
            step.root_module.link_libc = true;

            // Include paths
            step.root_module.addIncludePath(inc);
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
                .file = gen.path(b_ctx, "libmariadb/ma_client_plugin.c"),
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

                if (darwin) {
                    step.root_module.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
                    step.root_module.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
                    step.root_module.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/openssl/include" });
                    step.root_module.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/openssl/lib" });
                    step.root_module.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/openssl@3/include" });
                    step.root_module.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/openssl@3/lib" });
                    step.root_module.addIncludePath(.{ .cwd_relative = "/usr/local/include" });
                    step.root_module.addLibraryPath(.{ .cwd_relative = "/usr/local/lib" });
                    step.root_module.addIncludePath(.{ .cwd_relative = "/usr/local/opt/openssl/include" });
                    step.root_module.addLibraryPath(.{ .cwd_relative = "/usr/local/opt/openssl/lib" });
                    step.root_module.addIncludePath(.{ .cwd_relative = "/usr/local/opt/openssl@3/include" });
                    step.root_module.addLibraryPath(.{ .cwd_relative = "/usr/local/opt/openssl@3/lib" });
                } else if (linux) {
                    step.root_module.addIncludePath(.{ .cwd_relative = "/usr/include" });
                    step.root_module.addLibraryPath(.{ .cwd_relative = "/usr/lib" });
                    step.root_module.addLibraryPath(.{ .cwd_relative = "/usr/lib/x86_64-linux-gnu" });
                    step.root_module.addLibraryPath(.{ .cwd_relative = "/usr/lib/aarch64-linux-gnu" });
                    step.root_module.addLibraryPath(.{ .cwd_relative = "/usr/lib64" });
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

            // Header installations
            step.installHeader(upstream_dep.path("include/mariadb_com.h"), "mariadb/mariadb_com.h");
            step.installHeader(upstream_dep.path("include/mysql.h"), "mariadb/mysql.h");
            step.installHeader(upstream_dep.path("include/mariadb_stmt.h"), "mariadb/mariadb_stmt.h");
            step.installHeader(upstream_dep.path("include/ma_pvio.h"), "mariadb/ma_pvio.h");
            step.installHeader(upstream_dep.path("include/ma_tls.h"), "mariadb/ma_tls.h");
            step.installHeader(inc.path(b_ctx, "mariadb_version.h"), "mariadb/mariadb_version.h");
            step.installHeader(upstream_dep.path("include/ma_list.h"), "mariadb/ma_list.h");
            step.installHeader(upstream_dep.path("include/errmsg.h"), "mariadb/errmsg.h");
            step.installHeader(upstream_dep.path("include/mariadb_dyncol.h"), "mariadb/mariadb_dyncol.h");
            step.installHeader(upstream_dep.path("include/mariadb_ctype.h"), "mariadb/mariadb_ctype.h");
            step.installHeader(upstream_dep.path("include/mariadb_rpl.h"), "mariadb/mariadb_rpl.h");
            step.installHeader(upstream_dep.path("include/mysqld_error.h"), "mariadb/mysqld_error.h");

            step.installHeader(upstream_dep.path("include/mysql.h"), "mysql.h");
            step.installHeader(upstream_dep.path("include/errmsg.h"), "errmsg.h");
            step.installHeader(inc.path(b_ctx, "mariadb_version.h"), "mariadb_version.h");
            step.installHeader(upstream_dep.path("include/mysql/client_plugin.h"), "mysql/client_plugin.h");
            step.installHeader(upstream_dep.path("include/mysql/plugin_auth.h"), "mysql/plugin_auth.h");
            step.installHeader(upstream_dep.path("include/mariadb/ma_io.h"), "mariadb/ma_io.h");
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
            b,
            all_sources,
            cflags,
            upstream,
            gen_dir,
            inc_dir,
            ssl_backend,
            zlib_mode,
            is_darwin,
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
            b,
            all_sources,
            cflags,
            upstream,
            gen_dir,
            inc_dir,
            ssl_backend,
            zlib_mode,
            is_darwin,
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
    mod.addIncludePath(inc_dir);
    mod.addIncludePath(upstream.path("include"));
    mod.linkLibrary(primary_lib);

    // Test executable
    const exe = b.addExecutable(.{
        .name = "mariadb-test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "mariadb", .module = mod },
            },
        }),
    });
    exe.root_module.linkLibrary(primary_lib);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run test application");
    run_step.dependOn(&run_cmd.step);

    // Unit tests
    const unit_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_unit_tests.step);
}
