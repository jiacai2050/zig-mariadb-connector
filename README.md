# zig-mariadb-connector

This is [MariaDB Connector/C](https://github.com/mariadb-corporation/mariadb-connector-c), packaged for Zig. Zero CMake required.

## Prerequisites

- **Windows**: No dependencies needed (uses native Schannel & WinCrypt).
- **macOS**: `brew install openssl pkg-config`
- **Linux (Debian/Ubuntu)**: `sudo apt install libssl-dev pkg-config`
- **Linux (RHEL/Fedora)**: `sudo dnf install openssl-devel pkgconf`

> Note: If OpenSSL is installed in a non-standard path, pass `-Dopenssl-include-dir=<path>` and `-Dopenssl-lib-dir=<path>`.

## Quick Start

```bash
# Build static library
zig build

# Run test application (in separate test/ project)
cd test && zig build run

# Cross-compile for Windows (uses native Schannel/WinCrypt, zero external deps)
zig build -Dtarget=x86_64-windows
```

## Adding to Your Project

Run in your project directory:

```bash
# Latest version
zig fetch --save=mariadb-connector git+https://github.com/jiacai2050/zig-mariadb-connector.git

# Replace <refname> with the version you want to use, e.g. v0.1.0
zig fetch --save=mariadb-connector git+https://github.com/jiacai2050/zig-mariadb-connector.git#<refname>
```

### Usage

In your `build.zig`:

```zig
const mariadb_dep = b.dependency("mariadb_connector", .{
    .target = target,
    .optimize = optimize,
});

// Translate C headers into a Zig module
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

// Pass to your executable/library
const exe = b.addExecutable(.{
    .name = "my-app",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "c", .module = c_mod },
        },
    }),
});
exe.root_module.linkLibrary(mariadb_dep.artifact("mariadbclient"));
```

Then in your Zig source (`src/main.zig`):

```zig
const std = @import("std");
const c = @import("c");

pub fn main() !void {
    std.debug.print("Version: {s}\n", .{c.mysql_get_client_info()});
    const conn = c.mysql_init(null) orelse return error.InitFailed;
    defer c.mysql_close(conn);
}
```

#### Headers Only (Without linking)

If a build step only needs the complete header directory (e.g. for custom steps, binding generation, or probing):

```zig
exe.addIncludePath(mariadb_dep.namedLazyPath("include"));
```

## Build Options

| Option | Default | Description |
|---|---|---|
| `-Dzlib` | `bundled` | `bundled` or `system` |
| `-Ddyncol` | `true` | Enable dynamic columns |
| `-Dopenssl-include-dir` | null | Custom OpenSSL include dir |
| `-Dopenssl-lib-dir` | null | Custom OpenSSL lib dir |

## License

MIT (Build files & Zig bindings) / LGPL v2.1 (MariaDB Connector/C).
