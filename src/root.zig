const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});

/// Wrapper of sqlite3
pub const Sqlite3 = struct {
    sqlite3: *c.sqlite3,

    /// Wrapper of sqlite3_open
    pub fn init(filename: []const u8) Err!Sqlite3 {
        var opt_sqlite3: ?*c.sqlite3 = null;

        // SQLite may assign the pointer even if sqlite3_open returns an error code.
        errdefer if (opt_sqlite3 != null) {
            _ = c.sqlite3_close(opt_sqlite3);
        };

        const res = c.sqlite3_open(filename.ptr, &opt_sqlite3);
        try expectSqliteOk(res);

        if (opt_sqlite3) |sqlite3| {
            return Sqlite3{ .sqlite3 = sqlite3 };
        } else {
            return Err.Error;
        }
    }

    /// Wrapper of sqlite3_close
    pub fn deinit(self: Sqlite3) void {
        _ = c.sqlite3_close(self.sqlite3);
    }

    /// Extra, kind of similar to sqlite3_exec, but it doesn't process rows. It expects the SQL to
    /// not return anything.
    pub fn exec(self: Sqlite3, sql: []const u8) Err!void {
        const stmt = try self.prepare(sql);
        defer stmt.deinit();
        try stmt.exec();
    }

    /// Wrapper of sqlite3_prepare_v2
    pub fn prepare(self: Sqlite3, sql: []const u8) Err!Statement {
        var opt_stmt: ?*c.sqlite3_stmt = null;
        errdefer if (opt_stmt != null) {
            _ = c.sqlite3_finalize(opt_stmt);
        };

        // If the caller knows that the supplied string is nul-terminated, then there is a
        // small performance advantage to passing an nByte parameter that is the number of bytes
        // in the input string including the nul-terminator.
        // See https://www3.sqlite.org/c3ref/prepare.html
        const len = sql.len + 1;
        const res = c.sqlite3_prepare_v2(self.sqlite3, sql.ptr, @intCast(len), &opt_stmt, null);
        try expectSqliteOk(res);

        if (opt_stmt) |stmt| {
            return Statement{ .stmt = stmt };
        } else {
            return Err.Error;
        }
    }

    /// Extra, prints the last error related to this database
    pub fn printError(self: Sqlite3, tag: []const u8) void {
        const sqlite3 = self.sqlite3;
        const sqlite_errcode = c.sqlite3_extended_errcode(sqlite3);
        const sqlite_errmsg = c.sqlite3_errmsg(sqlite3);
        std.debug.print("{s} {d}: {s}\n", .{ tag, sqlite_errcode, sqlite_errmsg });
    }
};

/// Wrapper of sqlite3_stmt, exposing a subset of functions that are not related to the current
/// row after a call to sqlite3_step.
pub const Statement = struct {
    stmt: *c.sqlite3_stmt,

    /// Wrapper of sqlite3_finalize
    pub fn deinit(self: Statement) void {
        _ = c.sqlite3_finalize(self.stmt);
    }

    /// Extra, performs a sqlite3_step and expects to be SQLITE_DONE.
    pub fn exec(self: Statement) Err!void {
        const res = try self.step();
        if (null != res) {
            return Err.Misuse;
        }
    }

    /// Wrapper of sqlite3_step
    /// Returns the subset of functions related to row management if SQLITE_ROW
    /// Returns null if SQLITE_DONE
    /// Error otherwise
    pub fn step(self: Statement) Err!?Row {
        const stmt = self.stmt;
        const res = c.sqlite3_step(stmt);
        switch (res) {
            c.SQLITE_ROW => {
                return Row{ .stmt = stmt };
            },
            c.SQLITE_DONE => {
                return null;
            },
            else => {
                return Err.Error;
            },
        }
    }

    /// Wrapper of sqlite3_reset
    pub fn reset(self: Statement) !void {
        const res = c.sqlite3_reset(self.stmt);
        try expectSqliteOk(res);
    }

    /// Wrapper of sqlite3_bind_text with SQLITE_STATIC
    /// indicate that the application remains responsible for disposing of the object
    pub fn bindText(self: Statement, col: i32, text: []const u8) !void {
        try self.bindTextDestructor(col, text, c.SQLITE_STATIC);
    }

    /// Wrapper of sqlite3_bind_text with SQLITE_TRANSIENT
    /// indicate that the object is to be copied, SQLite will then manage the lifetime of its copy
    pub fn bindTextCopy(self: Statement, col: i32, text: []const u8) !void {
        try self.bindTextDestructor(col, text, c.SQLITE_TRANSIENT);
    }

    /// Wrapper of sqlite3_bind_blob with SQLITE_STATIC
    /// indicate that the application remains responsible for disposing of the object
    pub fn bindBlob(self: Statement, col: i32, data: []const u8) !void {
        try self.bindBlobDestructor(col, data, c.SQLITE_STATIC);
    }

    /// Wrapper of sqlite3_bind_blob with SQLITE_TRANSIENT
    /// indicate that the object is to be copied, SQLite will then manage the lifetime of its copy
    pub fn bindBlobCopy(self: Statement, col: i32, data: []const u8) !void {
        try self.bindBlobDestructor(col, data, c.SQLITE_TRANSIENT);
    }

    /// Internal wrapper of sqlite3_bind_text
    const Destructor = @TypeOf(c.SQLITE_STATIC);
    fn bindTextDestructor(self: Statement, col: i32, text: []const u8, destructor: Destructor) !void {
        const stmt = self.stmt;
        const res = c.sqlite3_bind_text(stmt, col, text.ptr, @intCast(text.len), destructor);
        try expectSqliteOk(res);
    }

    /// Internal wrapper of sqlite3_bind_blob
    fn bindBlobDestructor(self: Statement, col: i32, data: []const u8, destructor: Destructor) !void {
        const stmt = self.stmt;
        const res = c.sqlite3_bind_blob(stmt, col, data.ptr, @intCast(data.len), destructor);
        try expectSqliteOk(res);
    }

    /// Wrapper of sqlite3_bind_null
    pub fn bindNull(self: Statement, col: i32) !void {
        const res = c.sqlite3_bind_null(self.stmt, col);
        try expectSqliteOk(res);
    }

    /// Wrapper of sqlite3_bind_double, sqlite3_bind_int, and sqlite3_bind_int64
    pub fn bind(self: Statement, col: i32, val: anytype) !void {
        const numeric_type = comptime getNumericType(@TypeOf(val));
        const stmt = self.stmt;
        var res: c_int = undefined;
        switch (numeric_type) {
            .int => {
                res = c.sqlite3_bind_int(stmt, col, @as(i32, @intCast(val)));
            },
            .int64 => {
                res = c.sqlite3_bind_int64(stmt, col, @as(i64, @intCast(val)));
            },
            .double => {
                res = c.sqlite3_bind_double(stmt, col, @as(f64, @floatCast(val)));
            },
        }
        try expectSqliteOk(res);
    }
};

/// Wrapper of sqlite3_stmt, exposing subset of functions related to the current row after a call
/// to sqlite3_step.
pub const Row = struct {
    stmt: *c.sqlite3_stmt,

    /// Extra, duplicates the memory returned by sqlite3_column_text
    pub fn columnText(self: Row, col: i32, alloc: std.mem.Allocator) ![]const u8 {
        const data = self.columnTextPtr(col);
        return try alloc.dupe(u8, data);
    }

    /// Wrapper of sqlite3_column_text
    /// The returned pointer is managed by SQLite and is invalidated on next step or reset
    pub fn columnTextPtr(self: Row, col: i32) []const u8 {
        const stmt = self.stmt;
        const c_ptr = c.sqlite3_column_text(stmt, col);
        const size: usize = @intCast(c.sqlite3_column_bytes(stmt, col));
        const data = c_ptr[0..size];
        return data;
    }

    /// Extra, duplicates the memory returned by sqlite3_column_text
    pub fn columnBlob(self: Row, col: i32, alloc: std.mem.Allocator) ![]const u8 {
        const data = self.columnBlobPtr(col);
        return try alloc.dupe(u8, data);
    }

    /// Wrapper of sqlite3_column_blob
    /// The returned pointer is managed by SQLite and is invalidated on next step or reset
    pub fn columnBlobPtr(self: Row, col: i32) []const u8 {
        const stmt = self.stmt;
        const c_ptr = @as([*c]const u8, @ptrCast(c.sqlite3_column_blob(stmt, col)));
        const size: usize = @intCast(c.sqlite3_column_bytes(stmt, col));
        const data = c_ptr[0..size];
        return data;
    }

    /// Wrapper of sqlite3_column_int, sqlite_column_int64, and sqlite3_column_double
    pub fn column(self: Row, col: i32, comptime T: type) T {
        const numeric_type = comptime getNumericType(T);
        const stmt = self.stmt;
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
    pub fn columnType(self: Row, col: i32) !ColumnType {
        const sqlite_type = c.sqlite3_column_type(self.stmt, col);
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

/// https://www3.sqlite.org/c3ref/c_blob.html
pub const ColumnType = enum { integer, float, text, blob, null };

pub const Err = error{ Misuse, Error };

fn expectSqliteOk(res: c_int) Err!void {
    if (c.SQLITE_OK != res) {
        return Err.Error;
    }
}

/// Numeric types available in SQLite C API
const NumericType = enum { int, int64, double };

fn getNumericType(comptime T: type) NumericType {
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

        const answer: i32 = 42;
        const pi: f32 = 3.14;
        const drink: i17 = 0xCAFE;
        const blob = &[_]u8{ 0xBA, 0xBE };
        const text = "All your codebases are belong to us!";

        try insert.bind(1, answer);
        try insert.bind(2, pi);
        try insert.bind(3, drink);
        try insert.bindBlob(4, blob);
        try insert.bindText(5, text);
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

        try select.bind(1, 1);

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
