// TODO doc

const std = @import("std");
const Allocator = std.mem.Allocator;
const expect = std.testing.expect;
const expectEq = std.testing.expectEqual;

const Cell = @import("cell.zig").Cell;
const Unit = @import("cell.zig").Unit;

const Grid = struct {
    width: Unit,
    height: Unit,
    cellsBuf: [][]Cell = undefined,

    mem: Allocator,

    pub const CellI = struct {
        i: Unit = 0,
        parent: *Grid,

        fn init(parent_: *Grid) CellI {
            return CellI{
                .parent = parent_,
            };
        }

        pub fn next(self: *CellI) ?*Cell {
            if (self.i < self.parent.size()) {
                defer self.i += 1;
                return self.parent.at(self.i % self.parent.width, @divTrunc(self.i, self.parent.height));
            } else {
                return null;
            }
        }
    };

    pub fn init(mem: Allocator, w: Unit, h: Unit) !Grid {
        var g = Grid{
            .width = w,
            .height = h,
            .mem = mem,
        };

        try g.prepareGrid();
        g.configureCells();

        return g;
    }

    pub fn deinit(self: *Grid) void {
        for (self.cellsBuf) |*row| {
            for (row.*) |*cell| {
                cell.*.deinit();
            }
            self.mem.free(row.*);
        }
        self.mem.free(self.cellsBuf);
    }

    pub fn at(self: *Grid, x: Unit, y: Unit) ?*Cell {
        if (x < 0) return null;
        if (x >= self.width) return null;
        if (y < 0) return null;
        if (y >= self.height) return null;
        return &self.cellsBuf[y][x];
    }

    pub fn pickRandom(self: *Grid) *Cell {
        var randX = std.rand.Random.intRangeAtMost(Unit, 0, self.width - 1);
        var randY = std.rand.Random.intRangeAtMost(Unit, 0, self.height - 1);
        return self.at(randX, randY).*;
    }

    pub fn cells(self: *Grid) CellI {
        return Grid.CellI.init(self);
    }

    pub fn size(self: Grid) usize {
        var w: usize = self.width;
        var h: usize = self.height;
        return w *| h;
    }

    fn prepareGrid(self: *Grid) !void {
        self.cellsBuf = try self.mem.alloc([]Cell, self.height);
        for (self.cellsBuf) |*row, y| {
            row.* = try self.mem.alloc(Cell, self.width);
            for (row.*) |*cell, x| {
                cell.* = Cell.init(self.mem, @intCast(Unit, x), @intCast(Unit, y));
            }
        }
    }

    fn configureCells(self: *Grid) void {
        for (self.cellsBuf) |*row, y| {
            for (row.*) |*cell, x| {
                cell.*.north = self.at(@intCast(Unit, x), @intCast(Unit, y -| 1));
                cell.*.south = self.at(@intCast(Unit, x), @intCast(Unit, y +| 1));
                cell.*.east = self.at(@intCast(Unit, x +| 1), @intCast(Unit, y));
                cell.*.west = self.at(@intCast(Unit, x -| 1), @intCast(Unit, y));
            }
        }
    }
};

test "Construct and destruct a Grid" {
    var alloc = std.testing.allocator;
    var g = try Grid.init(alloc, 4, 4);
    defer g.deinit();
    try expectEq(@as(@TypeOf(g.size()), 16), g.size());
}

test "Grid.at(...) out of bounds returns null" {
    var alloc = std.testing.allocator;
    var g = try Grid.init(alloc, 4, 4);
    defer g.deinit();

    try expectEq(null, g.at(4, 4));
    try expectEq(null, g.at(0, 4));
    try expectEq(null, g.at(4, 0));
}

test "Grid.cells(...) returns an iterator" {
    var alloc = std.testing.allocator;
    var g = try Grid.init(alloc, 4, 4);
    defer g.deinit();

    {
        var count: usize = 0;
        var it = g.cells();
        while (it.next()) |cell| {
            _ = cell;
            count += 1;
        }

        try expectEq(@as(@TypeOf(count), 16), count);
    }
}

test "Grid.cells(...) iterates over each cell exactly once" {
    var alloc = std.testing.allocator;
    var g = try Grid.init(alloc, 32, 32);
    defer g.deinit();

    {
        var seen = std.AutoHashMap(*Cell, void).init(alloc);
        defer seen.deinit();

        var it = g.cells();
        while (it.next()) |cell| {
            try expect(seen.contains(cell) == false);
            try seen.put(cell, {});
        }
    }
}
