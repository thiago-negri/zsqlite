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
        try expectSqliteOk(err);

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
        try expectSqliteOk(err);

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
        try expectSqliteOk(err);
    }

    /// Wrapper of sqlite3_bind_text with SQLITE_STATIC
    pub fn bindText(self: Self, col: i32, text: []const u8) !void {
        try self.bindTextDestructor(col, text, c.SQLITE_STATIC);
    }

    /// Wrapper of sqlite3_bind_text with SQLITE_TRANSIENT
    pub fn bindTextCopy(self: Self, col: i32, text: []const u8) !void {
        try self.bindTextDestructor(col, text, c.SQLITE_TRANSIENT);
    }

    /// Wrapper of sqlite3_bind_blob with SQLITE_STATIC
    pub fn bindBlob(self: Self, col: i32, data: []const u8) !void {
        try self.bindBlobDestructor(col, data, c.SQLITE_STATIC);
    }

    /// Wrapper of sqlite3_bind_blob with SQLITE_TRANSIENT
    pub fn bindBlobCopy(self: Self, col: i32, data: []const u8) !void {
        try self.bindBlobDestructor(col, data, c.SQLITE_TRANSIENT);
    }

    /// Internal wrapper of sqlite3_bind_text
    const Destructor = @TypeOf(c.SQLITE_STATIC);
    fn bindTextDestructor(self: Self, col: i32, text: []const u8, destructor: Destructor) !void {
        const stmt = self.ptr;
        const err = c.sqlite3_bind_text(stmt, col, text.ptr, @intCast(text.len), destructor);
        try expectSqliteOk(err);
    }

    /// Internal wrapper of sqlite3_bind_blob
    fn bindBlobDestructor(self: Self, col: i32, data: []const u8, destructor: Destructor) !void {
        const stmt = self.ptr;
        const err = c.sqlite3_bind_blob(stmt, col, data.ptr, @intCast(data.len), destructor);
        try expectSqliteOk(err);
    }

    /// Wrapper of sqlite3_bind_null
    fn bindNull(self: Self, col: i32) !void {
        const err = c.sqlite3_bind_null(self.ptr, col);
        try expectSqliteOk(err);
    }

    /// Wrapper of sqlite3_bind_double, sqlite3_bind_int, and sqlite3_bind_int64
    pub fn bind(self: Self, col: i32, comptime T: type, val: T) !void {
        const numeric_type = comptime getNumericType(T);
        const stmt = self.ptr;
        var err: c_int = undefined;
        switch (numeric_type) {
            .int => {
                err = c.sqlite3_bind_int(stmt, col, @as(i32, @intCast(val)));
            },
            .int64 => {
                err = c.sqlite3_bind_int64(stmt, col, @as(i64, @intCast(val)));
            },
            .double => {
                err = c.sqlite3_bind_double(stmt, col, @as(f64, @floatCast(val)));
            },
        }
        try expectSqliteOk(err);
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

    /// Extra, duplicates the memory returned by sqlite3_column_text
    pub fn columnBlob(self: Self, col: i32, alloc: std.mem.Allocator) ![]const u8 {
        const data = self.columnBlobPtr(col);
        return try alloc.dupe(u8, data);
    }

    /// Wrapper of sqlite3_column_blob
    /// The returned pointer is managed by SQLite and is invalidated on next step or reset
    pub fn columnBlobPtr(self: Self, col: i32) []const u8 {
        const stmt = self.ptr;
        const c_ptr = @as([*c]const u8, @ptrCast(c.sqlite3_column_blob(stmt, col)));
        const size: usize = @intCast(c.sqlite3_column_bytes(stmt, col));
        const data = c_ptr[0..size];
        return data;
    }

    /// Wrapper of sqlite3_column_int, sqlite_column_int64, and sqlite3_column_double
    pub fn column(self: Self, col: i32, comptime T: type) T {
        const numeric_type = comptime getNumericType(T);
        const stmt = self.ptr;
        switch (numeric_type) {
            .int => {
                return @as(T, @intCast(c.sqlite3_column_int(stmt, col)));
            },
            .int64 => {
                return @as(T, @intCast(c.sqlite3_column_int64(stmt, col)));
            },
            .double => {
                return @as(T, @floatCast(c.sqlite3_column_double(stmt, col)));
            },
        }
    }

    /// Wrapper for sqlite3_column_type
    pub fn columnType(self: Self, col: i32) !SqliteColumnType {
        const sqlite_type = c.sqlite3_column_type(self.ptr, col);
        switch (sqlite_type) {
            c.SQLITE_INTEGER => {
                return .integer;
            },
            c.SQLITE_FLOAT => {
                return .float;
            },
            c.SQLITE_TEXT => {
                return .text;
            },
            c.SQLITE_BLOB => {
                return .blob;
            },
            c.SQLITE_NULL => {
                return .null;
            },
            else => {
                return error.SqliteError;
            },
        }
    }
};

pub const SqliteColumnType = enum { integer, float, text, blob, null };

pub const SqliteError = error{ Misuse, Error };

fn expectSqliteOk(err: c_int) SqliteError!void {
    if (c.SQLITE_OK != err) {
        return SqliteError.Error;
    }
}

const SqliteNumericType = enum { int, int64, double };

fn getNumericType(comptime T: type) SqliteNumericType {
    switch (@typeInfo(T)) {
        .int => |info| {
            if (info.signedness == .unsigned) {
                @compileError("sqlite only supports signed numbers");
            }
            if (info.bits <= 32) {
                return .int;
            }
            if (info.bits > 64) {
                @compileError("sqlite only supports up to i64");
            }
            return .int64;
        },
        .comptime_int => {
            return .int64;
        },
        .float => |info| {
            if (info.bits > 64) {
                @compileError("sqlite only supports up to f64");
            }
            return .double;
        },
        .comptime_float => {
            return .double;
        },
        else => {
            @compileError("expecting a numeric type");
        },
    }
}

test "all" {
    const expect = std.testing.expect;

    const db = try Sqlite3.init(":memory:");
    defer db.deinit();
    errdefer db.printError("last sqlite error");

    // Create table
    try db.exec(
        \\CREATE TABLE t_foo (
        \\ c_integer INTEGER,
        \\ c_real    REAL,
        \\ c_numeric NUMERIC,
        \\ c_blob    BLOB,
        \\ c_text    TEXT,
        \\ c_null    INTEGER
        \\);
    );

    // Insert
    {
        const insert = try db.prepare(
            \\INSERT INTO t_foo (c_integer, c_real, c_numeric, c_blob, c_text, c_null)
            \\           VALUES (        ?,      ?,         ?,      ?,      ?,      ?);
        );
        defer insert.deinit();

        try insert.bind(1, i32, 42);
        try insert.bind(2, f32, 3.14);
        try insert.bind(3, i17, 0xCAFE);
        try insert.bindBlob(4, &[_]u8{ 0xBA, 0xBE });
        try insert.bindText(5, "All your codebases are belong to us!");
        try insert.bindNull(6);
        try insert.exec();
    }

    // Select
    {
        const select = try db.prepare(
            \\SELECT c_integer,
            \\       c_real,
            \\       c_numeric,
            \\       c_blob,
            \\       c_text,
            \\       c_null
            \\ FROM t_foo
            \\ WHERE rowid = ?;
        );
        defer select.deinit();

        try select.bind(1, i32, 1);

        var row = try select.step();
        try expect(null != row);

        const c_integer = row.?.column(0, i32);
        try expect(42 == c_integer);

        const c_real = row.?.column(1, f32);
        try expect(3.14 == c_real);

        const c_numeric = row.?.column(2, i17);
        try expect(0xCAFE == c_numeric);

        const c_blob = row.?.columnBlobPtr(3);
        try expect(std.mem.eql(u8, &[_]u8{ 0xBA, 0xBE }, c_blob));

        const c_text = row.?.columnTextPtr(4);
        try expect(std.mem.eql(u8, "All your codebases are belong to us!", c_text));

        const c_null_type = try row.?.columnType(5);
        try expect(.null == c_null_type);

        row = try select.step();
        try expect(null == row);
    }
}
