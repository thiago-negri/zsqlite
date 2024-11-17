const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});

/// Wrapper of sqlite3
pub const Sqlite3 = struct {
    ptr: ?*c.sqlite3,

    const Self = @This();

    /// Wrapper of sqlite3_open
    pub fn init(filename: []const u8) SqliteError!Sqlite3 {
        var db: ?*c.sqlite3 = null;

        // SQLite may assign the pointer even if sqlite3_open returns an error code.
        errdefer if (db != null) {
            _ = c.sqlite3_close(db);
        };

        const err = c.sqlite3_open(filename.ptr, &db);
        try checkError(err);

        return Sqlite3{ .ptr = db };
    }

    /// Wrapper of sqlite3_close
    pub fn deinit(self: Self) void {
        _ = c.sqlite3_close(self.ptr);
    }

    /// Extra, kind of similar to sqlite3_exec, but it doesn't process rows. It expects the SQL to
    /// not return anything.
    pub fn exec(self: Self, sql: []const u8) SqliteError!void {
        const stmt = try self.prepare(sql);
        defer stmt.deinit();
        try stmt.exec();
    }

    /// Short for calling Sqlite3Statement.init
    pub fn prepare(self: Self, sql: []const u8) SqliteError!Sqlite3Statement {
        return Sqlite3Statement.init(self, sql);
    }

    /// Extra, prints the last error related to this database
    pub fn printError(self: Self, msg: []const u8) void {
        const db = self.ptr;
        const sqlite_errcode = c.sqlite3_extended_errcode(db);
        const sqlite_errmsg = c.sqlite3_errmsg(db);
        std.debug.print("{s}.\n  {d}: {s}\n", .{ msg, sqlite_errcode, sqlite_errmsg });
    }
};

/// Wrapper of sqlite3_stmt, exposing a subset of functions that are not related to the current
/// row after a call to sqlite3_step.
pub const Sqlite3Statement = struct {
    ptr: ?*c.sqlite3_stmt,

    const Self = @This();

    /// Wrapper of sqlite3_prepare_v2
    pub fn init(db: Sqlite3, sql: []const u8) SqliteError!Sqlite3Statement {
        var stmt: ?*c.sqlite3_stmt = null;
        errdefer if (stmt != null) {
            _ = c.sqlite3_finalize(stmt);
        };

        const err = c.sqlite3_prepare_v2(db.ptr, sql.ptr, @intCast(sql.len + 1), &stmt, null);
        try checkError(err);

        return Sqlite3Statement{ .ptr = stmt };
    }

    /// Wrapper of sqlite3_finalize
    pub fn deinit(self: Self) void {
        _ = c.sqlite3_finalize(self.ptr);
    }

    /// Extra, performs a sqlite3_step and expects to be SQLITE_DONE.
    pub fn exec(self: Self) SqliteError!void {
        const res = try self.step();
        if (null != res) {
            return SqliteError.Misuse;
        }
    }

    /// Wrapper of sqlite3_step
    /// Returns the subset of functions related to row management if SQLITE_ROW
    /// Returns null if SQLITE_DONE
    /// Error otherwise
    pub fn step(self: Self) SqliteError!?Sqlite3StatementRow {
        const stmt = self.ptr;
        const err = c.sqlite3_step(stmt);
        switch (err) {
            c.SQLITE_ROW => {
                return Sqlite3StatementRow{ .ptr = self.ptr };
            },
            c.SQLITE_DONE => {
                return null;
            },
            else => {
                return SqliteError.Error;
            },
        }
    }

    /// Wrapper of sqlite3_reset
    pub fn reset(self: Self) !void {
        const err = c.sqlite3_reset(self.ptr);
        try checkError(err);
    }

    /// Wrapper of sqlite3_bind_text
    pub fn bindText(self: Self, col: i32, text: []const u8) !void {
        const stmt = self.ptr;
        const err = c.sqlite3_bind_text(stmt, col, text.ptr, @intCast(text.len), c.SQLITE_STATIC);
        try checkError(err);
    }
};

/// Wrapper of sqlite3_stmt, exposing subset of functions related to the current row after a call
/// to sqlite3_step.
pub const Sqlite3StatementRow = struct {
    ptr: ?*c.sqlite3_stmt,

    const Self = @This();

    /// Extra, duplicates the memory returned by sqlite3_column_text
    pub fn columnText(self: Self, col: i32, alloc: std.mem.Allocator) ![]const u8 {
        const data = self.columnTextPtr(col);
        return try alloc.dupe(u8, data);
    }

    /// Wrapper of sqlite3_column_text
    /// The returned pointer is managed by SQLite and is invalidated on next step or reset
    pub fn columnTextPtr(self: Self, col: i32) []const u8 {
        const stmt = self.ptr;
        const c_ptr = c.sqlite3_column_text(stmt, col);
        const size: usize = @intCast(c.sqlite3_column_bytes(stmt, col));
        const data = c_ptr[0..size];
        return data;
    }
};

pub const SqliteError = error{ Misuse, Error };

fn checkError(err: c_int) SqliteError!void {
    if (c.SQLITE_OK != err) {
        return SqliteError.Error;
    }
}

test "all" {
    const db = try Sqlite3.init(":memory:");
    defer db.deinit();

    // Create table
    try db.exec(
        \\CREATE TABLE codebases (
        \\ id INT PRIMARY KEY,
        \\ name CHAR NOT NULL,
        \\ belong_to CHAR(2) NOT NULL
        \\);
    );

    // Insert
    {
        const insert = try db.prepare("INSERT INTO codebases (name, belong_to) VALUES (?, ?);");
        defer insert.deinit();

        try insert.bindText(2, "us");

        try insert.bindText(1, "a");
        try insert.exec();
        try insert.reset();

        try insert.bindText(1, "r");
        try insert.exec();
        try insert.reset();

        try insert.bindText(1, "e");
        try insert.exec();
    }

    // Select
    {
        const select = try db.prepare("SELECT name FROM codebases WHERE belong_to = ?;");
        defer select.deinit();

        try select.bindText(1, "us");

        const expect = std.testing.expect;
        var row = try select.step();
        try expect(null != row);
        const name_a = row.?.columnTextPtr(0);
        try expect(std.mem.eql(u8, "a", name_a));

        row = try select.step();
        try expect(null != row);
        const name_r = row.?.columnTextPtr(0);
        try expect(std.mem.eql(u8, "r", name_r));

        row = try select.step();
        try expect(null != row);
        const name_e = row.?.columnTextPtr(0);
        try expect(std.mem.eql(u8, "e", name_e));

        try expect(null == try select.step());
    }
}
