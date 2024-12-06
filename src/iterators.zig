const std = @import("std");
const err = @import("./err.zig");
const Sqlite3 = @import("./Sqlite3.zig");
const Statement = @import("./Statement.zig");
const Row = @import("./Row.zig");

/// Extra type that provides an easier (typed) way to iterate over rows
pub fn StatementIterator(Item: type, extractor: fn (row: Row) Item, sql: [:0]const u8) type {
    return struct {
        stmt: Statement,

        const Self = @This();

        pub fn prepare(db: *Sqlite3) (std.mem.Allocator.Error || err.Sqlite3Error)!Self {
            const stmt = try db.prepare(sql);
            return Self{ .stmt = stmt };
        }

        pub fn reset(self: Self) err.Sqlite3Error!void {
            try self.stmt.reset();
        }

        pub fn deinit(self: Self) void {
            self.stmt.deinit();
        }

        pub fn next(self: Self) err.Sqlite3Error!?Item {
            if (try self.stmt.step()) |row| {
                const item = extractor(row);
                return item;
            }
            return null;
        }
    };
}

fn StmtIterAllocFn(Item: type) type {
    return fn (alloc: std.mem.Allocator, row: Row) std.mem.Allocator.Error!Item;
}

/// Extra type that provides an easier (typed) way to iterate over rows (with allocation)
pub fn StatementIteratorAlloc(Item: type, extractor: StmtIterAllocFn(Item), sql: [:0]const u8) type {
    return struct {
        stmt: Statement,

        const Self = @This();

        pub fn prepare(db: *Sqlite3) (std.mem.Allocator.Error || err.Sqlite3Error)!Self {
            const stmt = try db.prepare(sql);
            return Self{ .stmt = stmt };
        }

        pub fn reset(self: Self) err.Sqlite3Error!void {
            try self.stmt.reset();
        }

        pub fn deinit(self: Self) void {
            self.stmt.deinit();
        }

        pub fn next(self: Self, alloc: std.mem.Allocator) (err.Sqlite3Error || std.mem.Allocator.Error)!?Item {
            if (try self.stmt.step()) |row| {
                const item = try extractor(alloc, row);
                return item;
            }
            return null;
        }
    };
}
