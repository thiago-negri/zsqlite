//! Wrapper of sqlite3_stmt, exposing subset of functions related to the current row after a call
//! to sqlite3_step.
const Row = @This();

const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});
const err = @import("./err.zig");
const cmp = @import("./comptime.zig");

stmt: *c.sqlite3_stmt,

/// Extra, duplicates the memory returned by sqlite3_column_text
pub fn columnText(self: Row, col: i32, alloc: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
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
pub fn columnBlob(self: Row, col: i32, alloc: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
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
    const numeric_type = comptime cmp.getNumericType(T);
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

/// https://www3.sqlite.org/c3ref/c_blob.html
pub const ColumnType = enum { integer, float, text, blob, null };

pub const ColumnTypeError = error{
    /// Returned if SQLite3 returns an unknown column type, should not happen
    Unknown,
};

/// Wrapper for sqlite3_column_type
pub fn columnType(self: Row, col: i32) ColumnTypeError!ColumnType {
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
            return ColumnTypeError.Unknown;
        },
    }
}
