const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});
const print = std.debug.print;
const GPA = std.heap.GeneralPurposeAllocator(.{});

pub fn main() !void {
    var gpa = GPA{};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    // Database connection handle.
    var db: ?*c.sqlite3 = null;
    // SQLite may initialize the pointer even if it returns an error, make sure
    // we clean that up.
    defer if (db != null) {
        _ = c.sqlite3_close(db);
    };

    // Connect to an in-memory database.
    if (c.SQLITE_OK != c.sqlite3_open(":memory:", &db)) {
        printSqliteError(db, "Failed to connect SQLite");
        return error.SqliteError;
    }

    // Create a table.
    try createTable(db);

    // Insert some.
    try insert(db);

    // Select some.
    const names = try select(db, arena.allocator());

    // Print results.
    print("All your codebases ", .{});
    for (names.items) |name| {
        print("{s}", .{name});
    }
    print(" belong to us!\n", .{});
}

fn createTable(db: ?*c.sqlite3) !void {
    const sql =
        \\CREATE TABLE codebases (
        \\  id INT PRIMARY KEY,
        \\  name CHAR NOT NULL,
        \\  belong_to CHAR(2) NOT NULL
        \\);
    ;
    try executeSql(db, sql);
}

fn insert(db: ?*c.sqlite3) !void {
    const sql =
        \\INSERT INTO codebases (name, belong_to) VALUES
        \\ ('a', 'us'),
        \\ ('r', 'us'),
        \\ ('e', 'us');
    ;
    try executeSql(db, sql);
}

fn select(db: ?*c.sqlite3, alloc: std.mem.Allocator) !std.ArrayList([]const u8) {
    const sql =
        \\SELECT name
        \\ FROM codebases
        \\ WHERE belong_to = 'us';
    ;

    var stmt: ?*c.sqlite3_stmt = null;
    defer if (stmt != null) {
        _ = c.sqlite3_finalize(stmt);
    };

    if (c.SQLITE_OK != c.sqlite3_prepare_v2(db, sql.ptr, @intCast(sql.len + 1), &stmt, null)) {
        printSqliteError(db, "Failed to prepare statement");
        return error.SqliteError;
    }

    var names = std.ArrayList([]const u8).init(alloc);
    errdefer {
        for (names.items) |name| {
            alloc.free(name);
        }
        names.deinit();
    }

    var step = c.sqlite3_step(stmt);
    while (step == c.SQLITE_ROW) : (step = c.sqlite3_step(stmt)) {
        // The pointer returned by SQLite is invalidated on next 'step' call,
        // we need to copy the memory.
        const c_ptr = c.sqlite3_column_text(stmt, 0);
        const size: usize = @intCast(c.sqlite3_column_bytes(stmt, 0));
        const data = c_ptr[0..size];
        const name = try alloc.dupe(u8, data);
        errdefer alloc.free(name);
        try names.append(name);
    }
    if (step != c.SQLITE_DONE) {
        printSqliteError(db, "Failed to fetch rows");
        return error.SqliteError;
    }

    return names;
}

fn executeSql(db: ?*c.sqlite3, sql: []const u8) !void {
    var stmt: ?*c.sqlite3_stmt = null;
    defer if (stmt != null) {
        _ = c.sqlite3_finalize(stmt);
    };

    if (c.SQLITE_OK != c.sqlite3_prepare_v2(db, sql.ptr, @intCast(sql.len + 1), &stmt, null)) {
        printSqliteError(db, "Failed to prepare statement");
        return error.SqliteError;
    }

    if (c.SQLITE_DONE != c.sqlite3_step(stmt)) {
        printSqliteError(db, "Failed to execute SQL");
        return error.SqliteError;
    }
}

fn printSqliteError(db: ?*c.sqlite3, msg: []const u8) void {
    const sqlite_errcode = c.sqlite3_extended_errcode(db);
    const sqlite_errmsg = c.sqlite3_errmsg(db);
    print("{s}.\n  {d}: {s}\n", .{ msg, sqlite_errcode, sqlite_errmsg });
}
