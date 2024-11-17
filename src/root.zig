const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});

pub const Sqlite3 = struct {
    ptr: ?*c.sqlite3,

    const Self = @This();

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

    pub fn deinit(self: Self) void {
        _ = c.sqlite3_close(self.ptr);
    }

    pub fn exec(self: Self, sql: []const u8) SqliteError!void {
        const stmt = try Sqlite3Statement.init(self, sql);
        defer stmt.deinit();
        const res = try stmt.step();
        if (.done != res) {
            return SqliteError.Misuse;
        }
    }

    pub fn prepare(self: Self, sql: []const u8) SqliteError!Sqlite3Statement {
        return Sqlite3Statement.init(self, sql);
    }

    pub fn printError(self: Self, msg: []const u8) void {
        const db = self.ptr;
        const sqlite_errcode = c.sqlite3_extended_errcode(db);
        const sqlite_errmsg = c.sqlite3_errmsg(db);
        std.debug.print("{s}.\n  {d}: {s}\n", .{ msg, sqlite_errcode, sqlite_errmsg });
    }
};

pub const Sqlite3Statement = struct {
    ptr: ?*c.sqlite3_stmt,

    const Self = @This();

    pub fn init(db: Sqlite3, sql: []const u8) SqliteError!Sqlite3Statement {
        var stmt: ?*c.sqlite3_stmt = null;
        errdefer if (stmt != null) {
            _ = c.sqlite3_finalize(stmt);
        };

        const err = c.sqlite3_prepare_v2(db.ptr, sql.ptr, @intCast(sql.len + 1), &stmt, null);
        try checkError(err);

        return Sqlite3Statement{ .ptr = stmt };
    }

    pub fn deinit(self: Self) void {
        _ = c.sqlite3_finalize(self.ptr);
    }

    pub fn exec(self: Self) SqliteError!void {
        const res = try self.step();
        if (.done != res) {
            return SqliteError.Misuse;
        }
    }

    pub fn step(self: Self) SqliteError!SqliteStep {
        const stmt = self.ptr;
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

    pub fn reset(self: Self) !void {
        const err = c.sqlite3_reset(self.ptr);
        try checkError(err);
    }

    pub fn bindText(self: Self, col: i32, text: []const u8) !void {
        const err = c.sqlite3_bind_text(self.ptr, col, text.ptr, @intCast(text.len), c.SQLITE_STATIC);
        try checkError(err);
    }

    pub fn columnText(self: Self, col: i32, alloc: std.mem.Allocator) ![]const u8 {
        const data = self.columnTextPtr(col);
        return try alloc.dupe(u8, data);
    }

    pub fn columnTextPtr(self: Self, col: i32) []const u8 {
        const stmt = self.ptr;
        const c_ptr = c.sqlite3_column_text(stmt, col);
        const size: usize = @intCast(c.sqlite3_column_bytes(stmt, col));
        const data = c_ptr[0..size];
        return data;
    }
};

pub const SqliteStep = enum { row, done };

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
        try insert.bindText(1, "a");
        try insert.bindText(2, "us");
        try insert.exec();
        try insert.reset();
        try insert.bindText(1, "r");
        try insert.bindText(2, "us");
        try insert.exec();
        try insert.reset();
        try insert.bindText(1, "e");
        try insert.bindText(2, "us");
        try insert.exec();
    }

    // Select
    {
        const select = try db.prepare("SELECT name FROM codebases WHERE belong_to = ?;");
        defer select.deinit();

        try select.bindText(1, "us");

        const expect = std.testing.expect;
        try expect(.row == try select.step());
        const name_a = select.columnTextPtr(0);
        try expect(std.mem.eql(u8, "a", name_a));

        try expect(.row == try select.step());
        const name_r = select.columnTextPtr(0);
        try expect(std.mem.eql(u8, "r", name_r));

        try expect(.row == try select.step());
        const name_e = select.columnTextPtr(0);
        try expect(std.mem.eql(u8, "e", name_e));

        try expect(.done == try select.step());
    }
}
