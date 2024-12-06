const cmp = @import("comptime.zig");
const build_options = @import("build_options");
const std = @import("std");

const c = @cImport({
    @cInclude("sqlite3.h");
});

const track = build_options.track_open_statements;

/// List of SQLite 3 errors
pub const Sqlite3Error = error{
    Error,
    Internal,
    Perm,
    Abort,
    Busy,
    Locked,
    NoMem,
    ReadOnly,
    Interrupt,
    IoErr,
    Corrupt,
    NotFound,
    Full,
    CantOpen,
    Protocol,
    Empty,
    Schema,
    TooBig,
    Constraint,
    Mismatch,
    Misuse,
    NoLfs,
    Auth,
    Format,
    Range,
    NotADb,
    Notice,
    Warning,
    Unknown,
};

pub inline fn expect(comptime expected: c_int, res: c_int) Sqlite3Error!void {
    return switch (res) {
        expected => {},
        c.SQLITE_ERROR => Sqlite3Error.Error,
        c.SQLITE_INTERNAL => Sqlite3Error.Internal,
        c.SQLITE_PERM => Sqlite3Error.Perm,
        c.SQLITE_ABORT => Sqlite3Error.Abort,
        c.SQLITE_BUSY => Sqlite3Error.Busy,
        c.SQLITE_LOCKED => Sqlite3Error.Locked,
        c.SQLITE_NOMEM => Sqlite3Error.NoMem,
        c.SQLITE_READONLY => Sqlite3Error.ReadOnly,
        c.SQLITE_INTERRUPT => Sqlite3Error.Interrupt,
        c.SQLITE_IOERR => Sqlite3Error.IoErr,
        c.SQLITE_CORRUPT => Sqlite3Error.Corrupt,
        c.SQLITE_NOTFOUND => Sqlite3Error.NotFound,
        c.SQLITE_FULL => Sqlite3Error.Full,
        c.SQLITE_CANTOPEN => Sqlite3Error.CantOpen,
        c.SQLITE_PROTOCOL => Sqlite3Error.Protocol,
        c.SQLITE_EMPTY => Sqlite3Error.Empty,
        c.SQLITE_SCHEMA => Sqlite3Error.Schema,
        c.SQLITE_TOOBIG => Sqlite3Error.TooBig,
        c.SQLITE_CONSTRAINT => Sqlite3Error.Constraint,
        c.SQLITE_MISMATCH => Sqlite3Error.Mismatch,
        c.SQLITE_MISUSE => Sqlite3Error.Misuse,
        c.SQLITE_NOLFS => Sqlite3Error.NoLfs,
        c.SQLITE_AUTH => Sqlite3Error.Auth,
        c.SQLITE_FORMAT => Sqlite3Error.Format,
        c.SQLITE_RANGE => Sqlite3Error.Range,
        c.SQLITE_NOTADB => Sqlite3Error.NotADb,
        c.SQLITE_NOTICE => Sqlite3Error.Notice,
        c.SQLITE_WARNING => Sqlite3Error.Warning,
        else => Sqlite3Error.Unknown,
    };
}

pub inline fn translateError(res: c_int) Sqlite3Error {
    return switch (res) {
        c.SQLITE_ERROR => Sqlite3Error.Error,
        c.SQLITE_INTERNAL => Sqlite3Error.Internal,
        c.SQLITE_PERM => Sqlite3Error.Perm,
        c.SQLITE_ABORT => Sqlite3Error.Abort,
        c.SQLITE_BUSY => Sqlite3Error.Busy,
        c.SQLITE_LOCKED => Sqlite3Error.Locked,
        c.SQLITE_NOMEM => Sqlite3Error.NoMem,
        c.SQLITE_READONLY => Sqlite3Error.ReadOnly,
        c.SQLITE_INTERRUPT => Sqlite3Error.Interrupt,
        c.SQLITE_IOERR => Sqlite3Error.IoErr,
        c.SQLITE_CORRUPT => Sqlite3Error.Corrupt,
        c.SQLITE_NOTFOUND => Sqlite3Error.NotFound,
        c.SQLITE_FULL => Sqlite3Error.Full,
        c.SQLITE_CANTOPEN => Sqlite3Error.CantOpen,
        c.SQLITE_PROTOCOL => Sqlite3Error.Protocol,
        c.SQLITE_EMPTY => Sqlite3Error.Empty,
        c.SQLITE_SCHEMA => Sqlite3Error.Schema,
        c.SQLITE_TOOBIG => Sqlite3Error.TooBig,
        c.SQLITE_CONSTRAINT => Sqlite3Error.Constraint,
        c.SQLITE_MISMATCH => Sqlite3Error.Mismatch,
        c.SQLITE_MISUSE => Sqlite3Error.Misuse,
        c.SQLITE_NOLFS => Sqlite3Error.NoLfs,
        c.SQLITE_AUTH => Sqlite3Error.Auth,
        c.SQLITE_FORMAT => Sqlite3Error.Format,
        c.SQLITE_RANGE => Sqlite3Error.Range,
        c.SQLITE_NOTADB => Sqlite3Error.NotADb,
        c.SQLITE_NOTICE => Sqlite3Error.Notice,
        c.SQLITE_WARNING => Sqlite3Error.Warning,
        else => Sqlite3Error.Unknown,
    };
}
