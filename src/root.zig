const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});
const err = @import("./err.zig");
const iterators = @import("./iterators.zig");

pub const Sqlite3Error = err.Sqlite3Error;
pub const Sqlite3 = @import("./Sqlite3.zig");
pub const Statement = @import("./Statement.zig");
pub const Row = @import("./Row.zig");
pub const StatementIterator = iterators.StatementIterator;
pub const StatementIteratorAlloc = iterators.StatementIteratorAlloc;

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

    try db.exec("CREATE TABLE t_iter (c_text TEXT)");
    try db.exec("INSERT INTO t_iter (c_text) VALUES ('foo'),('bar'),('baz')");

    // Iterator
    {
        const TableRow = struct {
            text: []const u8,
            const Self = @This();

            pub fn init(row: Row) Self {
                const text = row.columnTextPtr(0);
                return Self{ .text = text };
            }
        };
        const TableIterator = StatementIterator(TableRow, TableRow.init, "SELECT c_text FROM t_iter");

        const iter = try TableIterator.prepare(db);
        defer iter.deinit();

        var item = try iter.next();
        try std.testing.expectEqualStrings("foo", item.?.text);
        item = try iter.next();
        try std.testing.expectEqualStrings("bar", item.?.text);
        item = try iter.next();
        try std.testing.expectEqualStrings("baz", item.?.text);
        item = try iter.next();
        try std.testing.expectEqual(null, item);

        try iter.reset();
        item = try iter.next();
        try std.testing.expectEqualStrings("foo", item.?.text);
        item = try iter.next();
        try std.testing.expectEqualStrings("bar", item.?.text);
        item = try iter.next();
        try std.testing.expectEqualStrings("baz", item.?.text);
        item = try iter.next();
        try std.testing.expectEqual(null, item);
    }

    // Iterator Alloc
    {
        const TableRowAlloc = struct {
            text: []const u8,
            const Self = @This();

            pub fn init(alloc: std.mem.Allocator, row: Row) std.mem.Allocator.Error!Self {
                const text = try row.columnText(0, alloc);
                return Self{ .text = text };
            }

            pub fn deinit(self: Self, alloc: std.mem.Allocator) void {
                alloc.free(self.text);
            }
        };
        const TableIterator = StatementIteratorAlloc(TableRowAlloc, TableRowAlloc.init, "SELECT c_text FROM t_iter");

        const iter = try TableIterator.prepare(db);
        defer iter.deinit();

        // Fetch all at once to show that they can allocate memory
        const foo = try iter.next(std.testing.allocator);
        defer foo.?.deinit(std.testing.allocator);

        const bar = try iter.next(std.testing.allocator);
        defer bar.?.deinit(std.testing.allocator);

        const baz = try iter.next(std.testing.allocator);
        defer baz.?.deinit(std.testing.allocator);

        const end = try iter.next(std.testing.failing_allocator);

        try std.testing.expectEqualStrings("foo", foo.?.text);
        try std.testing.expectEqualStrings("bar", bar.?.text);
        try std.testing.expectEqualStrings("baz", baz.?.text);
        try std.testing.expectEqual(null, end);
    }
}
