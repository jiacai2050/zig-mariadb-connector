const std = @import("std");
const mariadb = @import("mariadb");

pub fn main() !void {
    std.debug.print("MariaDB Connector/C version ID: {d}\n", .{mariadb.getClientVersion()});
    std.debug.print("MariaDB Connector/C client info: {s}\n", .{mariadb.getClientInfo()});

    const mysql = mariadb.c.mysql_init(null);
    if (mysql == null) {
        std.debug.print("Failed to initialize MySQL handle\n", .{});
        return error.InitFailed;
    }
    defer mariadb.c.mysql_close(mysql);

    std.debug.print("Successfully initialized and closed MySQL handle!\n", .{});
}
