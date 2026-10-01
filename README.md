# zig-mariadb-connector

A pure `zig build` package for [MariaDB Connector/C](https://github.com/mariadb-corporation/mariadb-connector-c) (3.4.11) with zero CMake dependency.

## Prerequisites

- **Windows**: No dependencies needed (uses native Schannel & WinCrypt).
- **macOS**: `brew install openssl pkg-config`
- **Linux (Debian/Ubuntu)**: `sudo apt install libssl-dev pkg-config`
- **Linux (RHEL/Fedora)**: `sudo dnf install openssl-devel pkgconf`

> Note: If OpenSSL is installed in a non-standard path, pass `-Dopenssl-include-dir=<path>` and `-Dopenssl-lib-dir=<path>`. Or use `-Dssl=none` to disable TLS.

## Quick Start

```bash
# Build static & shared libraries
zig build

# Run sample CLI & tests
zig build run
zig build test

# Cross-compile for Windows (uses native Schannel/WinCrypt, zero external deps)
zig build -Dtarget=x86_64-windows
```

## Adding to Your Project

Run in your project directory:

```bash
# Latest version
zig fetch --save git+https://github.com/jiacai2050/zig-mariadb-connector.git

# Tagged version
zig fetch --save git+https://github.com/jiacai2050/zig-mariadb-connector.git#v0.1.0
```

In `build.zig`:

```zig
const mariadb = b.dependency("zig_mariadb_connector", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("mariadb", mariadb.module("mariadb"));
exe.root_module.linkLibrary(mariadb.artifact("mariadbclient"));
```

In your Zig code:

```zig
const std = @import("std");
const mariadb = @import("mariadb");

pub fn main() !void {
    std.debug.print("Version: {s}\n", .{mariadb.getClientInfo()});
    const conn = mariadb.c.mysql_init(null) orelse return error.InitFailed;
    defer mariadb.c.mysql_close(conn);
}
```

## Build Options

| Option | Default | Description |
|---|---|---|
| `-Dstatic` | `true` | Build static library (`libmariadbclient.a` / `mariadbclient.lib`) |
| `-Dshared` | `true` | Build shared library (`libmariadb.dylib` / `.so` / `mariadb.dll`) |
| `-Dssl` | `auto` | TLS backend: `openssl` (Linux/macOS), `schannel` (Windows), or `none` |
| `-Dzlib` | `bundled` | `bundled` or `system` |
| `-Ddyncol` | `true` | Enable dynamic columns |
| `-Dopenssl-include-dir` | null | Custom OpenSSL include dir |
| `-Dopenssl-lib-dir` | null | Custom OpenSSL lib dir |

## License

MIT (Build files & Zig bindings) / LGPL v2.1 (MariaDB Connector/C).
