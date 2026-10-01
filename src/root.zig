//! MariaDB Connector/C Zig bindings and wrapper
const std = @import("std");

pub const c = @cImport({
    @cInclude("mysql.h");
    @cInclude("errmsg.h");
    @cInclude("mariadb_version.h");
});

pub fn getClientVersion() u64 {
    return c.mysql_get_client_version();
}

pub fn getClientInfo() [:0]const u8 {
    return std.mem.span(c.mysql_get_client_info());
}

test "client version and info" {
    const version = getClientVersion();
    try std.testing.expectEqual(@as(u64, 30411), version);

    const info = getClientInfo();
    try std.testing.expect(std.mem.startsWith(u8, info, "3.4.11"));
}

test "mysql init and close" {
    const mysql = c.mysql_init(null);
    try std.testing.expect(mysql != null);
    c.mysql_close(mysql);
}
