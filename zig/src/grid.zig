//! Grid and cell types for constructing mazes

const std = @import("std");
const Allocator = std.mem.Allocator;
const expect = std.testing.expect;
const expectEq = std.testing.expectEqual;

/// Base unit for maze dimensions
pub const Unit = u32;

/// A single maze Cell
pub const Cell = struct {
    /// Iterator over the cells this cell is connected to.
    const LinksI = std.AutoHashMap(*Cell, void).KeyIterator;

    /// Iterator over the cells this cell is an orthogonal neighbor to,
    /// even if the cell isn't actually linked to it.
    pub const NeighborI = struct {
        i: usize = 0,
        parent: *Cell,

        fn init(parent: *Cell) NeighborI {
            return NeighborI{
                .parent = parent,
            };
        }

        pub fn next(self: *NeighborI) ?*Cell {
            if (self.i >= 4) return null;

            if (self.i == 0 and self.parent.north != null) {
                self.i = 1;
                return self.parent.north;
            }
            if (self.i <= 1 and self.parent.south != null) {
                self.i = 2;
                return self.parent.south;
            }
            if (self.i <= 2 and self.parent.east != null) {
                self.i = 3;
                return self.parent.east;
            }
            if (self.i <= 3 and self.parent.west != null) {
                self.i = 4;
                return self.parent.west;
            }

            return null;
        }
    };

    pub fn init(mem: Allocator, row: Unit, col: Unit) Cell {
        return Cell{
            .row = row,
            .col = col,
            .mem = mem,
            .links_set = std.AutoHashMap(*Cell, void).init(mem),
        };
    }

    pub fn deinit(self: *Cell) void {
        self.links_set.deinit();
    }

    /// Bidirectional link.
    /// self <---> other
    pub fn bLink(self: *Cell, other: *Cell) !void {
        try self.links_set.put(other, {});
        try other.mLink(self);
    }

    /// Monodirectional link.
    /// self ----> other
    pub fn mLink(self: *Cell, other: *Cell) !void {
        try self.links_set.put(other, {});
    }

    pub fn unLink(self: *Cell, other: *Cell) void {
        self.mUnLink(other);
        other.mUnLink(self);
    }

    // monedirectional unlink
    fn mUnLink(self: *Cell, other: *Cell) void {
        // no-ops are fine
        _ = self.links_set.remove(other);
    }

    /// Return true if `self` is linked to `other`
    pub fn isLinked(self: Cell, other: *Cell) bool {
        return self.links_set.contains(other);
    }

    /// Return an iterator over cells that `self` is linked to.
    pub fn links(self: Cell) Cell.LinksI {
        return self.links_set.keyIterator();
    }

    /// Return an iterator over cells that are orthogonal to `self`.
    /// Returned cells need not be actually linked to `self`.
    pub fn neighbors(self: *Cell) Cell.NeighborI {
        return Cell.NeighborI.init(self);
    }

    row: Unit = 0,
    col: Unit = 0,

    mem: Allocator,
    links_set: std.AutoHashMap(*Cell, void),

    north: ?*Cell = null,
    south: ?*Cell = null,
    east: ?*Cell = null,
    west: ?*Cell = null,
};

pub const Grid = struct {
    width: Unit,
    height: Unit,
    cells_buf: []Cell = undefined,

    mem: Allocator,

    pub const CellI = struct {
        i: Unit = 0,
        parent: *Grid,

        fn init(parent: *Grid) CellI {
            return CellI{
                .parent = parent,
            };
        }

        pub fn next(self: *CellI) ?*Cell {
            if (self.i < self.parent.size()) {
                defer self.i += 1;
                var x = @intCast(Unit, self.i % self.parent.width);
                var y = @intCast(Unit, @divTrunc(self.i, self.parent.width));
                return self.parent.at(x, y);
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
        for (self.cells_buf) |*cell| {
            cell.*.deinit();
        }
        self.mem.free(self.cells_buf);
    }

    pub fn at(self: *Grid, x: Unit, y: Unit) ?*Cell {
        if (x < 0) return null;
        if (x >= self.width) return null;
        if (y < 0) return null;
        if (y >= self.height) return null;
        return &self.cells_buf[y * self.width + x];
    }

    pub fn pickRandom(self: *Grid) *Cell {
        var i = std.rand.Random.intRangeAtMost(Unit, 0, self.size() - 1);
        return &self.cells_buf[i];
    }

    pub fn cells(self: *Grid) CellI {
        return Grid.CellI.init(self);
    }

    pub fn size(self: Grid) usize {
        return self.width *| self.height;
    }

    fn prepareGrid(self: *Grid) !void {
        self.cells_buf = try self.mem.alloc(Cell, self.width * self.height);
        for (self.cells_buf) |*cell, i| {
            var x = @intCast(Unit, i % self.width);
            var y = @intCast(Unit, @divTrunc(i, self.width));
            cell.* = Cell.init(self.mem, x, y);
        }
    }

    fn configureCells(self: *Grid) void {
        for (self.cells_buf) |*cell, i| {
            var x = @intCast(Unit, i % self.width);
            var y = @intCast(Unit, @divTrunc(i, self.width));
            if (y > 0) cell.*.north = self.at(x, y -| 1);
            if (y < self.height - 1) cell.*.south = self.at(x, y +| 1);
            if (x < self.width - 1) cell.*.east = self.at(x +| 1, y);
            if (x > 0) cell.*.west = self.at(x -| 1, y);
        }
    }

    fn writeAndAdvance(buf: *[]u8, i: *usize, word: []const u8) !void {
        var inner_slice = buf.*[i.* .. i.* + word.len];
        std.mem.copy(u8, inner_slice, word);
        i.* += word.len;
    }

    // TODO change this to accept a buffer or and allocator instead of using its own
    pub fn makeString(self: Grid) ![]u8 {
        // the output will have a top row of +---+,
        // followed by a grid that takes up 2 rows
        // per grid row.

        //                  +   ---+            \n
        var row_len: Unit = 1 + 4 * self.width + 1;
        //                    top row   rest of maze
        var total_len: Unit = row_len + row_len * self.height * 2;
        var ret = try self.mem.alloc(u8, total_len);

        var i: usize = 0;
        const w = writeAndAdvance;

        // top row
        try w(&ret, &i, "+");
        {
            var j: usize = 0;
            while (j < self.width) : (j += 1) {
                try w(&ret, &i, "---+");
            }
        }
        try w(&ret, &i, "\n");

        // rest
        {
            // for each row
            var j: usize = 0;
            while (j < self.height) : (j += 1) {
                var row_slice = self.cells_buf[j * self.width .. j * self.width + self.width];

                // row 1
                try w(&ret, &i, "|");
                for (row_slice) |cell| {
                    try w(&ret, &i, if (cell.east != null and cell.isLinked(cell.east.?) == true) "    " else "   |");
                }
                try w(&ret, &i, "\n");

                // row 2
                try w(&ret, &i, "+");
                for (row_slice) |cell| {
                    try w(&ret, &i, if (cell.south != null and cell.isLinked(cell.south.?) == true) "   +" else "---+");
                }
                try w(&ret, &i, "\n");
            }
        }

        return ret;
    }
};

test "Construct and destruct a Cell" {
    var alloc = std.testing.allocator;
    var c = Cell.init(alloc, 0, 0);
    defer c.deinit();
}

test "Cell can link to another Cell" {
    var alloc = std.testing.allocator;

    var a = Cell.init(alloc, 0, 0);
    defer a.deinit();
    var b = Cell.init(alloc, 0, 0);
    defer b.deinit();

    try a.bLink(&b);

    try expect(a.isLinked(&b) == true);
    try expect(b.isLinked(&a) == true);
}

test "Cell can unlink after linking another Cell" {
    var alloc = std.testing.allocator;

    var a = Cell.init(alloc, 0, 0);
    defer a.deinit();
    var b = Cell.init(alloc, 0, 0);
    defer b.deinit();

    try a.bLink(&b);

    try expect(a.isLinked(&b) == true);
    try expect(b.isLinked(&a) == true);

    a.unLink(&b);

    try expect(a.isLinked(&b) == false);
    try expect(b.isLinked(&a) == false);
}

test "Cell provides an iterator over its links" {
    var alloc = std.testing.allocator;

    var a = Cell.init(alloc, 0, 0);
    defer a.deinit();
    var b = Cell.init(alloc, 1, 0);
    defer b.deinit();
    var c = Cell.init(alloc, 2, 0);
    defer c.deinit();
    var d = Cell.init(alloc, 3, 0);
    defer d.deinit();

    try a.bLink(&b);
    try a.bLink(&c);
    try a.bLink(&d);

    {
        var it = a.links();
        var count: u32 = 0;
        while (it.next()) |link| {
            _ = link;
            count += 1;
        }

        try expectEq(@as(@TypeOf(count), 3), count);
    }
}

test "Cell provides a list of its neighbors" {
    var alloc = std.testing.allocator;

    var a = Cell.init(alloc, 0, 0);
    defer a.deinit();
    var b = Cell.init(alloc, 1, 0);
    defer b.deinit();
    var c = Cell.init(alloc, 2, 0);
    defer c.deinit();

    b.west = &a;
    b.east = &c;

    {
        var it = b.neighbors();
        var count: u32 = 0;
        while (it.next()) |nei| {
            _ = nei;
            count += 1;
        }

        try expectEq(@as(@TypeOf(count), 2), count);
    }
}
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

test "Grid.makeString() returns a perfect, closed grid before modification" {
    var alloc = std.testing.allocator;
    var g = try Grid.init(alloc, 5, 5);
    defer g.deinit();

    var s = try g.makeString();
    defer alloc.free(s);
    const m: []const u8 =
        \\+---+---+---+---+---+
        \\|   |   |   |   |   |
        \\+---+---+---+---+---+
        \\|   |   |   |   |   |
        \\+---+---+---+---+---+
        \\|   |   |   |   |   |
        \\+---+---+---+---+---+
        \\|   |   |   |   |   |
        \\+---+---+---+---+---+
        \\|   |   |   |   |   |
        \\+---+---+---+---+---+
        \\
    ;
    try expectEq(true, std.mem.eql(u8, s, m));
}
