//! Wrapper of sqlite3
const Sqlite3 = @This();

const build_options = @import("build_options");
const cmp = @import("comptime.zig");
const err = @import("err.zig");
const Statement = @import("Statement.zig");
const std = @import("std");

const c = @cImport({
    @cInclude("sqlite3.h");
});

const stack_n = 6;
const track = build_options.track_open_statements;

const OpenStatement = struct {
    statement: Statement,
    stack_trace: std.builtin.StackTrace,
};

sqlite3: *c.sqlite3,
open_statements: cmp.OptType(track, std.ArrayList(OpenStatement)) = cmp.optValue(track, undefined),
alloc: cmp.OptType(track, std.mem.Allocator) = cmp.optValue(track, undefined),

pub const Sqlite3Options = struct {
    /// Required if track_open_statements is set to true, not used otherwise
    alloc: ?std.mem.Allocator,
};

/// Wrapper of sqlite3_open
pub fn init(filename: []const u8, opts: Sqlite3Options) err.Sqlite3Error!Sqlite3 {
    var opt_sqlite3: ?*c.sqlite3 = null;

    // SQLite may assign the pointer even when sqlite3_open returns an error code.
    errdefer if (opt_sqlite3) |sqlite3| {
        _ = c.sqlite3_close(sqlite3);
    };

    const res = c.sqlite3_open(filename.ptr, &opt_sqlite3);
    try err.expect(c.SQLITE_OK, res);

    if (opt_sqlite3) |sqlite3| {
        if (track) {
            const alloc = opts.alloc orelse @panic("Tracking open statements requires an allocator");
            const open_statements = std.ArrayList(OpenStatement).init(alloc);
            return Sqlite3{ .sqlite3 = sqlite3, .open_statements = open_statements, .alloc = alloc };
        }
        return Sqlite3{ .sqlite3 = sqlite3 };
    } else {
        return err.Sqlite3Error.Unknown;
    }
}

/// Wrapper of sqlite3_close
pub fn deinit(self: Sqlite3) void {
    if (track) {
        const leak = self.open_statements.items.len > 0;
        if (leak) {
            std.debug.print("ZSQLite Statement leak detected. Count = {d}\n", .{self.open_statements.items.len});
        }
        for (self.open_statements.items, 0..) |item, index| {
            std.debug.print("ZSQLite Statement leak #{d}:\n", .{index + 1});
            std.debug.dumpStackTrace(item.stack_trace);
            self.alloc.free(item.stack_trace.instruction_addresses);
        }
        self.open_statements.deinit();
        if (leak) {
            @panic("ZSQLite leak");
        }
    }
    const res = c.sqlite3_close(self.sqlite3);
    err.expect(c.SQLITE_OK, res) catch @panic("ZSQLite close");
}

/// Extra, kind of similar to sqlite3_exec, but it doesn't process rows. It expects the SQL to
/// not return anything.
pub fn exec(self: *Sqlite3, sql: [:0]const u8) (std.mem.Allocator.Error || err.Sqlite3Error)!void {
    const stmt = try self.prepare(sql);
    defer stmt.deinit();
    try stmt.exec();
}

/// Wrapper of sqlite3_prepare_v2
pub fn prepare(self: *Sqlite3, sql: [:0]const u8) (std.mem.Allocator.Error || err.Sqlite3Error)!Statement {
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
        if (track) {
            const addresses = try self.alloc.alloc(usize, stack_n);
            errdefer self.alloc.free(addresses);
            var stack_trace: std.builtin.StackTrace = .{ .index = 0, .instruction_addresses = addresses };
            std.debug.captureStackTrace(@returnAddress(), &stack_trace);
            const statement = Statement{ .stmt = stmt, .sqlite3 = self };
            try self.open_statements.append(.{ .statement = statement, .stack_trace = stack_trace });
            return statement;
        }
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
