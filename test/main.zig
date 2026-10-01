const std = @import("std");
const c = @import("c");

pub fn main() !void {
    const version = c.mysql_get_client_version();
    std.debug.print("MariaDB Connector/C version ID: {d}\n", .{version});
    try std.testing.expectEqual(@as(u64, 30411), version);

    const info = std.mem.span(c.mysql_get_client_info());
    std.debug.print("MariaDB Connector/C client info: {s}\n", .{info});
    try std.testing.expect(std.mem.startsWith(u8, info, "3.4.11"));

    const mysql = c.mysql_init(null);
    if (mysql == null) {
        std.debug.print("Failed to initialize MySQL handle\n", .{});
        return error.InitFailed;
    }
    defer c.mysql_close(mysql);

    std.debug.print("Successfully initialized and closed MySQL handle!\n", .{});
}
