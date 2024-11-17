const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});

pub const Sqlite3 = struct {
    db: ?*c.sqlite3,

    pub fn init(filename: []const u8) SqliteError!Sqlite3 {
        var db: ?*c.sqlite3 = null;

        // SQLite may assign the pointer even if sqlite3_open returns an error code.
        errdefer if (db != null) {
            _ = c.sqlite3_close(db);
        };

        const err = c.sqlite3_open(filename.ptr, &db);
        try checkError(err);

        return Sqlite3{ .db = db };
    }

    pub fn deinit(self: @This()) void {
        _ = c.sqlite3_close(self.db);
    }

    pub fn exec(self: @This(), sql: []const u8) SqliteError!void {
        const stmt = try Statement.init(self, sql);
        defer stmt.deinit();
        const res = try stmt.step();
        if (.done != res) {
            return SqliteError.Misuse;
        }
    }

    pub fn printError(self: @This(), msg: []const u8) void {
        const db = self.db;
        const sqlite_errcode = c.sqlite3_extended_errcode(db);
        const sqlite_errmsg = c.sqlite3_errmsg(db);
        std.debug.print("{s}.\n  {d}: {s}\n", .{ msg, sqlite_errcode, sqlite_errmsg });
    }
};

pub const Statement = struct {
    stmt: ?*c.sqlite3_stmt,

    pub fn init(db: Sqlite3, sql: []const u8) SqliteError!Statement {
        var stmt: ?*c.sqlite3_stmt = null;
        errdefer if (stmt != null) {
            _ = c.sqlite3_finalize(stmt);
        };

        const err = c.sqlite3_prepare_v2(db.db, sql.ptr, @intCast(sql.len + 1), &stmt, null);
        try checkError(err);

        return Statement{ .stmt = stmt };
    }

    pub fn deinit(self: @This()) void {
        _ = c.sqlite3_finalize(self.stmt);
    }

    pub fn step(self: @This()) SqliteError!SqliteStep {
        const stmt = self.stmt;
        const err = c.sqlite3_step(stmt);
        switch (err) {
            c.SQLITE_ROW => {
                return .row;
            },
            c.SQLITE_DONE => {
                return .done;
            },
            else => {
                return SqliteError.Error;
            },
        }
    }

    pub fn columnText(self: @This(), col: i32, alloc: std.mem.Allocator) ![]const u8 {
        const data = self.columnTextPtr(col);
        return try alloc.dupe(u8, data);
    }

    pub fn columnTextPtr(self: @This(), col: i32) []const u8 {
        const stmt = self.stmt;
        const c_ptr = c.sqlite3_column_text(stmt, col);
        const size: usize = @intCast(c.sqlite3_column_bytes(stmt, col));
        const data = c_ptr[0..size];
        return data;
    }
};

pub const SqliteStep = enum { row, done };

const SqliteError = error{ Misuse, Error };

fn checkError(err: c_int) SqliteError!void {
    if (c.SQLITE_OK != err) {
        return SqliteError.Error;
    }
}
