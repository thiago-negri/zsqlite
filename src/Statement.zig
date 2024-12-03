/// Wrapper of sqlite3_stmt, exposing a subset of functions that are not related to the current
/// row after a call to sqlite3_step.
const Statement = @This();

const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});
const err = @import("./err.zig");
const cmp = @import("./comptime.zig");
const Row = @import("./Row.zig");

stmt: *c.sqlite3_stmt,

/// Wrapper of sqlite3_finalize
pub fn deinit(self: Statement) void {
    _ = c.sqlite3_finalize(self.stmt);
}

pub const ExecError = error{Misuse};

/// Extra, performs a sqlite3_step and err.expects to be SQLITE_DONE.
pub fn exec(self: Statement) (ExecError || err.Sqlite3Error)!void {
    const res = try self.step();
    if (null != res) {
        return ExecError.Misuse;
    }
}

/// Wrapper of sqlite3_step
/// Returns the subset of functions related to row management if SQLITE_ROW
/// Returns null if SQLITE_DONE
/// Error otherwise
pub fn step(self: Statement) err.Sqlite3Error!?Row {
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
            return err.translateError(res);
        },
    }
}

/// Wrapper of sqlite3_reset
pub fn reset(self: Statement) err.Sqlite3Error!void {
    const res = c.sqlite3_reset(self.stmt);
    try err.expect(c.SQLITE_OK, res);
}

/// Wrapper of sqlite3_bind_text with SQLITE_STATIC
/// indicate that the application remains responsible for disposing of the object
pub fn bindText(self: Statement, col: i32, text: []const u8) err.Sqlite3Error!void {
    try self.bindTextDestructor(col, text, c.SQLITE_STATIC);
}

/// Wrapper of sqlite3_bind_text with SQLITE_TRANSIENT
/// indicate that the object is to be copied, SQLite will then manage the lifetime of its copy
pub fn bindTextCopy(self: Statement, col: i32, text: []const u8) err.Sqlite3Error!void {
    try self.bindTextDestructor(col, text, c.SQLITE_TRANSIENT);
}

/// Wrapper of sqlite3_bind_blob with SQLITE_STATIC
/// indicate that the application remains responsible for disposing of the object
pub fn bindBlob(self: Statement, col: i32, data: []const u8) err.Sqlite3Error!void {
    try self.bindBlobDestructor(col, data, c.SQLITE_STATIC);
}

/// Wrapper of sqlite3_bind_blob with SQLITE_TRANSIENT
/// indicate that the object is to be copied, SQLite will then manage the lifetime of its copy
pub fn bindBlobCopy(self: Statement, col: i32, data: []const u8) err.Sqlite3Error!void {
    try self.bindBlobDestructor(col, data, c.SQLITE_TRANSIENT);
}

/// Internal wrapper of sqlite3_bind_text
const Destructor = @TypeOf(c.SQLITE_STATIC);
fn bindTextDestructor(self: Statement, col: i32, text: []const u8, destructor: Destructor) err.Sqlite3Error!void {
    const stmt = self.stmt;
    const res = c.sqlite3_bind_text(stmt, col, text.ptr, @intCast(text.len), destructor);
    try err.expect(c.SQLITE_OK, res);
}

/// Internal wrapper of sqlite3_bind_blob
fn bindBlobDestructor(self: Statement, col: i32, data: []const u8, destructor: Destructor) err.Sqlite3Error!void {
    const stmt = self.stmt;
    const res = c.sqlite3_bind_blob(stmt, col, data.ptr, @intCast(data.len), destructor);
    try err.expect(c.SQLITE_OK, res);
}

/// Wrapper of sqlite3_bind_null
pub fn bindNull(self: Statement, col: i32) err.Sqlite3Error!void {
    const res = c.sqlite3_bind_null(self.stmt, col);
    try err.expect(c.SQLITE_OK, res);
}

/// Wrapper of sqlite3_bind_double, sqlite3_bind_int, and sqlite3_bind_int64
pub fn bind(self: Statement, col: i32, val: anytype) err.Sqlite3Error!void {
    const numeric_type = comptime cmp.getNumericType(@TypeOf(val));
    const stmt = self.stmt;
    const res: c_int = switch (numeric_type) {
        .int => c.sqlite3_bind_int(stmt, col, @as(i32, @intCast(val))),
        .int64 => c.sqlite3_bind_int64(stmt, col, @as(i64, @intCast(val))),
        .double => c.sqlite3_bind_double(stmt, col, @as(f64, @floatCast(val))),
    };
    try err.expect(c.SQLITE_OK, res);
}
