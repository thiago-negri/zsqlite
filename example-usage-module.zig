const std = @import("std");
const zsql = @import("zsqlite");

const print = std.debug.print;
const GPA = std.heap.GeneralPurposeAllocator(.{});

pub fn main() !void {
    var gpa = GPA{};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const db = zsql.Sqlite3.init(":memory:") catch |err| {
        print("Failed to connect to SQLite", .{});
        return err;
    };
    defer db.deinit();

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

fn createTable(db: zsql.Sqlite3) !void {
    const sql =
        \\CREATE TABLE codebases (
        \\  id INT PRIMARY KEY,
        \\  name CHAR NOT NULL,
        \\  belong_to CHAR(2) NOT NULL
        \\);
    ;
    errdefer db.printError("Failed to create table");
    try db.exec(sql);
}

fn insert(db: zsql.Sqlite3) !void {
    const sql =
        \\INSERT INTO codebases (name, belong_to) VALUES
        \\ ('a', 'us'),
        \\ ('r', 'us'),
        \\ ('e', 'us');
    ;
    errdefer db.printError("Failed to insert rows");
    try db.exec(sql);
}

fn select(db: zsql.Sqlite3, alloc: std.mem.Allocator) !std.ArrayList([]const u8) {
    const sql =
        \\SELECT name
        \\ FROM codebases
        \\ WHERE belong_to = 'us';
    ;

    const stmt = stmt: {
        errdefer db.printError("Failed to prepare select statement");
        break :stmt try zsql.Statement.init(db, sql);
    };
    defer stmt.deinit();

    var names = std.ArrayList([]const u8).init(alloc);
    errdefer {
        for (names.items) |name| {
            alloc.free(name);
        }
        names.deinit();
    }

    var step = try stmt.step();
    while (step == .row) : (step = try stmt.step()) {
        const name = try stmt.columnText(0, alloc);
        errdefer alloc.free(name);
        try names.append(name);
    }

    return names;
}
