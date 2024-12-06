//! Wrapper of sqlite3
const Sqlite3 = @This();

const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});
const err = @import("./err.zig");
const Statement = @import("./Statement.zig");

sqlite3: *c.sqlite3,

/// Wrapper of sqlite3_open
pub fn init(filename: []const u8) err.Sqlite3Error!Sqlite3 {
    var opt_sqlite3: ?*c.sqlite3 = null;

    // SQLite may assign the pointer even when sqlite3_open returns an error code.
    errdefer if (opt_sqlite3) |sqlite3| {
        _ = c.sqlite3_close(sqlite3);
    };

    const res = c.sqlite3_open(filename.ptr, &opt_sqlite3);
    try err.expect(c.SQLITE_OK, res);

    if (opt_sqlite3) |sqlite3| {
        return Sqlite3{ .sqlite3 = sqlite3 };
    } else {
        return err.Sqlite3Error.Unknown;
    }
}

/// Wrapper of sqlite3_close
pub fn deinit(self: Sqlite3) void {
    _ = c.sqlite3_close(self.sqlite3);
}

/// Extra, kind of similar to sqlite3_exec, but it doesn't process rows. It expects the SQL to
/// not return anything.
pub fn exec(self: Sqlite3, sql: [:0]const u8) err.Sqlite3Error!void {
    const stmt = try self.prepare(sql);
    defer stmt.deinit();
    try stmt.exec();
}

/// Wrapper of sqlite3_prepare_v2
pub fn prepare(self: Sqlite3, sql: [:0]const u8) err.Sqlite3Error!Statement {
    var opt_stmt: ?*c.sqlite3_stmt = null;
    errdefer if (opt_stmt) |stmt| {
        _ = c.sqlite3_finalize(stmt);
    };

    // If the caller knows that the supplied string is nul-terminated, then there is a
    // small performance advantage to passing an nByte parameter that is the number of bytes
    // in the input string including the nul-terminator.
    // See https://www3.sqlite.org/c3ref/prepare.html
    const len = sql.len + 1;
    const res = c.sqlite3_prepare_v2(self.sqlite3, sql.ptr, @intCast(len), &opt_stmt, null);
    try err.expect(c.SQLITE_OK, res);

    if (opt_stmt) |stmt| {
        return Statement{ .stmt = stmt };
    } else {
        return err.Sqlite3Error.Unknown;
    }
}

/// Extra, prints the last error related to this database
pub fn printError(self: Sqlite3, tag: []const u8) void {
    const sqlite3 = self.sqlite3;
    const sqlite_errcode = c.sqlite3_extended_errcode(sqlite3);
    const sqlite_errmsg = c.sqlite3_errmsg(sqlite3);
    std.debug.print("{s} {d}: {s}\n", .{ tag, sqlite_errcode, sqlite_errmsg });
}
