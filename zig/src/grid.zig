//! Grid and Cell types for constructing mazes

const std = @import("std");
const qoi = @import("qoi.zig");
const qan = @import("qanvas.zig");

const Allocator = std.mem.Allocator;
const expect = std.testing.expect;
const expectEq = std.testing.expectEqual;

/// base unit for maze dimensions
pub const Unit = u32;

/// a single maze Cell
pub const Cell = struct {
    /// iterator over the cells a cell is linked to
    const LinksI = std.AutoHashMap(*Cell, void).KeyIterator;

    /// iterator over the cells a cell is an orthogonal neighbor to,
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

    pub fn distances(self: *Cell) !Distances {
        var dists = Distances.init(self.mem, self);
        try dists.dists.put(self, 0);

        var frontier1 = std.ArrayList(*Cell).init(self.mem);
        defer frontier1.deinit();
        var frontier2 = std.ArrayList(*Cell).init(self.mem);
        defer frontier2.deinit();

        var current_frontier = &frontier1;
        var next_frontier = &frontier2;

        try current_frontier.append(self);

        while (current_frontier.items.len > 0) {
            next_frontier.clearAndFree();

            for (current_frontier.items) |cellptr| {
                var it = cellptr.links();
                while (it.next()) |linked| {
                    if (dists.get(linked.*)) |_| continue;
                    try dists.put(linked.*, dists.get(cellptr).? + 1);
                    try next_frontier.append(linked.*);
                }
            }

            std.mem.swap(*std.ArrayList(*Cell), &current_frontier, &next_frontier);
        }

        return dists;
    }

    pub fn init(mem: Allocator, prng: *std.rand.DefaultPrng, row: Unit, col: Unit) Cell {
        return Cell{
            .row = row,
            .col = col,
            .mem = mem,
            .prng = prng,
            .links_set = std.AutoHashMap(*Cell, void).init(mem),
        };
    }

    pub fn deinit(self: *Cell) void {
        self.links_set.deinit();
    }

    /// bidirectional link
    /// self <---> other
    pub fn bLink(self: *Cell, other: *Cell) !void {
        try self.links_set.put(other, {});
        try other.mLink(self);
    }

    /// monodirectional link
    /// self ----> other
    pub fn mLink(self: *Cell, other: *Cell) !void {
        try self.links_set.put(other, {});
    }

    /// unlink `self` from `other` in both directions
    pub fn unLink(self: *Cell, other: *Cell) void {
        self.mUnLink(other);
        other.mUnLink(self);
    }

    // monodirectional unlink
    fn mUnLink(self: *Cell, other: *Cell) void {
        // no-ops are fine
        _ = self.links_set.remove(other);
    }

    /// return true if `self` is linked to `other`
    pub fn isLinked(self: Cell, other: *Cell) bool {
        return self.links_set.contains(other);
    }

    /// return the number of cells this cell is linked to
    pub fn numLinks(self: Cell) u32 {
        return self.links_set.count();
    }

    /// return an iterator over cells that `self` is linked to.
    pub fn links(self: Cell) Cell.LinksI {
        return self.links_set.keyIterator();
    }

    /// return a random cell from the cells that are linked to this cell
    pub fn randomLink(self: Cell) ?*Cell {
        // XXX: Assumes the maximum amount of links a cell can have is 4
        const max_links = 4;
        var actual_links: u8 = 0;
        var potential_links = [_]?*Cell{null} ** max_links;

        var iter = self.links();
        while (iter.next()) |nei| {
            potential_links[actual_links] = nei.*;
            actual_links += 1;
        }

        if (actual_links != 0) {
            var random = self.prng.random();
            const choice = random.intRangeLessThan(usize, 0, actual_links);
            return potential_links[choice];
        } else {
            return null;
        }
    }

    /// return an iterator over cells that are orthogonal to `self`.
    /// returned cells need not be actually linked to `self`.
    pub fn neighbors(self: *Cell) Cell.NeighborI {
        return Cell.NeighborI.init(self);
    }

    /// return a random cell from the cells that are orthogonal to this cell
    pub fn randomNeighbor(self: *Cell) ?*Cell {
        // XXX: Assumes the maximum amount of neighbors a cell can have is 4
        const max_neighbors = 4;
        var actual_neighbors: u8 = 0;
        var potential_neighbors = [_]?*Cell{null} ** max_neighbors;

        var iter = self.neighbors();
        while (iter.next()) |nei| {
            potential_neighbors[actual_neighbors] = nei;
            actual_neighbors += 1;
        }

        if (actual_neighbors != 0) {
            var choice = self.prng.random().intRangeLessThan(usize, 0, actual_neighbors);
            return potential_neighbors[choice];
        } else {
            return null;
        }
    }

    /// return a random cell from the cells that are orthogonal to this cell
    /// and don't have a link to any other cell
    pub fn randomNeighborUnlinked(self: *Cell) ?*Cell {
        // XXX: Assumes the maximum amount of neighbors a cell can have is 4
        const max_neighbors = 4;
        var actual_neighbors: u8 = 0;
        var potential_neighbors = [_]?*Cell{null} ** max_neighbors;

        var iter = self.neighbors();
        while (iter.next()) |nei| {
            if (nei.numLinks() == 0) {
                potential_neighbors[actual_neighbors] = nei;
                actual_neighbors += 1;
            }
        }

        if (actual_neighbors != 0) {
            var choice = self.prng.random().intRangeLessThan(usize, 0, actual_neighbors);
            return potential_neighbors[choice];
        } else {
            return null;
        }
    }

    /// return a random cell from the cells that are orthogonal to this cell
    /// and do have a link to any other cell
    pub fn randomNeighborLinked(self: *Cell) ?*Cell {
        // XXX: Assumes the maximum amount of neighbors a cell can have is 4
        const max_neighbors = 4;
        var actual_neighbors: u8 = 0;
        var potential_neighbors = [_]?*Cell{null} ** max_neighbors;

        var iter = self.neighbors();
        while (iter.next()) |nei| {
            if (nei.numLinks() > 0) {
                potential_neighbors[actual_neighbors] = nei;
                actual_neighbors += 1;
            }
        }

        if (actual_neighbors != 0) {
            var choice = self.prng.random().intRangeLessThan(usize, 0, actual_neighbors);
            return potential_neighbors[choice];
        } else {
            return null;
        }
    }

    row: Unit = 0,
    col: Unit = 0,

    mem: Allocator,
    prng: *std.rand.DefaultPrng,
    links_set: std.AutoHashMap(*Cell, void),

    north: ?*Cell = null,
    south: ?*Cell = null,
    east: ?*Cell = null,
    west: ?*Cell = null,
};

pub const Distances = struct {
    root: *Cell,
    alloc: Allocator,
    dists: std.AutoHashMap(*Cell, Unit),

    pub fn init(alloc: Allocator, root: *Cell) Self {
        var d: Distances = .{
            .root = root,
            .alloc = alloc,
            .dists = std.AutoHashMap(*Cell, Unit).init(alloc),
        };

        return d;
    }

    pub fn deinit(this: *Self) void {
        this.dists.deinit();
    }

    pub fn get(this: Self, cell: *Cell) ?Unit {
        return if (this.dists.contains(cell))
            this.dists.get(cell).?
        else
            return null;
    }

    pub fn put(this: *Self, cell: *Cell, dist: Unit) !void {
        try this.dists.put(cell, dist);
    }

    pub fn it(this: Self) this.dists.KeyIterator {
        return this.dists;
    }

    pub fn pathTo(this: Self, goal: *Cell) !Distances {
        var current = goal;

        var breadcrumbs = Distances.init(this.alloc, this.root);
        try breadcrumbs.put(current, this.dists.get(current).?);

        while (current != this.root) {
            var iter = current.links();
            while (iter.next()) |neighbor| {
                if (this.dists.get(neighbor.*).? < this.dists.get(current).?) {
                    try breadcrumbs.put(neighbor.*, this.dists.get(neighbor.*).?);
                    current = neighbor.*;
                    break;
                }
            }
        }

        return breadcrumbs;
    }

    pub fn max(this: Self) struct { cell: *Cell, distance: Unit } {
        var dist: Unit = 0;
        var cell = this.root;

        var iter = this.dists.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.* > dist) {
                dist = entry.value_ptr.*;
                cell = entry.key_ptr.*;
            }
        }

        return .{ .cell = cell, .distance = dist };
    }

    const Self = @This();
};

pub const Grid = struct {
    width: Unit,
    height: Unit,
    cells_buf: []Cell = undefined,
    distances: ?Distances = null,

    mem: Allocator,
    prng: *std.rand.DefaultPrng,

    /// iterator over all cells in the grid
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

    pub fn init(mem: Allocator, seed: u64, w: Unit, h: Unit) !Grid {
        var g = Grid{
            .width = w,
            .height = h,
            .mem = mem,
            .prng = try mem.create(std.rand.DefaultPrng),
        };

        g.prng.* = std.rand.DefaultPrng.init(seed);

        try g.prepareGrid();
        g.configureCells();

        return g;
    }

    pub fn deinit(self: *Grid) void {
        for (self.cells_buf) |*cell| {
            cell.*.deinit();
        }
        self.mem.free(self.cells_buf);
        if (self.distances) |*distances| distances.deinit();
        self.mem.destroy(self.prng);
    }

    /// return cell at given coordinates. null if it doesn't exist.
    pub fn at(self: *Grid, x: Unit, y: Unit) ?*Cell {
        if (x < 0) return null;
        if (x >= self.width) return null;
        if (y < 0) return null;
        if (y >= self.height) return null;
        return &self.cells_buf[y * self.width + x];
    }

    /// return a random cell in the grid
    pub fn pickRandom(self: *Grid) *Cell {
        var i = self.prng.random().intRangeAtMost(usize, 0, self.size() - 1);
        return &self.cells_buf[i];
    }

    /// return an iterator over all cells in the grid
    pub fn cells(self: *Grid) CellI {
        return Grid.CellI.init(self);
    }

    /// return a list of every cell that is only connected to one other cell.
    /// caller should free the returned list.
    pub fn deadends(self: *Grid) ![]*Cell {
        var list = std.ArrayList(*Cell).init(self.mem);
        defer list.deinit();

        for (self.cells_buf) |*cell| {
            if (cell.numLinks() == 1) {
                try list.append(cell);
            }
        }

        return list.toOwnedSlice();
    }

    /// return the amount of cells in the grid
    pub fn size(self: Grid) usize {
        return self.width *| self.height;
    }

    fn prepareGrid(self: *Grid) !void {
        self.cells_buf = try self.mem.alloc(Cell, self.width * self.height);
        for (self.cells_buf) |*cell, i| {
            var x = @intCast(Unit, i % self.width);
            var y = @intCast(Unit, @divTrunc(i, self.width));
            cell.* = Cell.init(self.mem, self.prng, y, x);
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

    fn contentsOf(self: Grid, cell: *Cell) u8 {
        const contents = "0123456789ABCDEF";
        if (self.distances) |distances| {
            if (distances.get(cell)) |dist| {
                return contents[dist % contents.len];
            }
        }
        return ' ';
    }

    /// return a string representation of the grid.
    /// memory for the string will be allocated with
    /// the allocator that the grid was initialized with.
    /// TODO test performance
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
                for (row_slice) |*cell| {
                    var data: [4]u8 = "   |".*;
                    if (cell.east != null and cell.isLinked(cell.east.?)) data[3] = ' ';
                    data[1] = self.contentsOf(cell);
                    try w(&ret, &i, &data);
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

    /// return a representation of the grid encoded as a qoi image.
    /// memory for the returned buffer is allocated by the allocator
    /// that the grid was initialized with.
    pub fn makeQoi(self: Grid, walls: bool) ![]u8 {
        const cell_size = 4;
        const border_size = cell_size / 2;

        const width = self.width * cell_size;
        const height = self.height * cell_size;

        var qanv = try qan.Qanvas.init(self.mem, width + border_size * 2, height + border_size * 2);
        defer qanv.deinit();

        // white
        // const background: qoi.Qixel = .{ .red = 240, .green = 240, .blue = 240 };

        // black
        const background: qoi.Qixel = .{ .red = 10, .green = 10, .blue = 15 };

        var max = if (self.distances) |dists| dists.max() else null;

        qanv.clear(background);

        for (self.cells_buf) |*cell| {
            const x1 = cell.col * cell_size + border_size;
            const x2 = (cell.col + 1) * cell_size + border_size;
            const y1 = cell.row * cell_size + border_size;
            const y2 = (cell.row + 1) * cell_size + border_size;

            if (self.distances) |dists| {
                if (dists.get(cell)) |thedist| {
                    const path_low: qoi.Qixel = .{ .red = 220, .green = 100, .blue = 100 };
                    const path_hi: qoi.Qixel = .{ .red = 20, .green = 60, .blue = 102 };
                    const color = path_low.lerp(path_hi, @intToFloat(f64, thedist) / @intToFloat(f64, max.?.distance));

                    try qanv.fill(color, x1, x2, y1, y2);
                }
            }
        }

        if (walls) {
            // black
            // const wall: qoi.Qixel = .{ .red = 0, .green = 0, .blue = 0 };

            // white
            const wall: qoi.Qixel = .{ .red = 45, .green = 40, .blue = 40 };

            for (self.cells_buf) |*cell| {
                const x1 = cell.col * cell_size + border_size;
                const x2 = (cell.col + 1) * cell_size + border_size;
                const y1 = cell.row * cell_size + border_size;
                const y2 = (cell.row + 1) * cell_size + border_size;

                if (cell.north == null) try qanv.line(wall, x1, x2, y1, y1);
                if (cell.west == null) try qanv.line(wall, x1, x1, y1, y2);

                if (cell.east == null or !cell.isLinked(cell.east.?)) try qanv.line(wall, x2, x2, y1, y2 + 1);
                if (cell.south == null or !cell.isLinked(cell.south.?)) try qanv.line(wall, x1, x2 + 1, y2, y2);
            }
        }

        return qanv.encode();
    }
};

test "Construct and destruct a Cell" {
    var alloc = std.testing.allocator;
    var prng = std.rand.DefaultPrng.init(0);

    var c = Cell.init(alloc, &prng, 0, 0);
    defer c.deinit();
}

test "Cell can link to another Cell" {
    var alloc = std.testing.allocator;
    var prng = std.rand.DefaultPrng.init(0);

    var a = Cell.init(alloc, &prng, 0, 0);
    defer a.deinit();
    var b = Cell.init(alloc, &prng, 0, 0);
    defer b.deinit();

    try a.bLink(&b);

    try expect(a.isLinked(&b) == true);
    try expect(b.isLinked(&a) == true);
}

test "Cell can unlink after linking another Cell" {
    var alloc = std.testing.allocator;
    var prng = std.rand.DefaultPrng.init(0);

    var a = Cell.init(alloc, &prng, 0, 0);
    defer a.deinit();
    var b = Cell.init(alloc, &prng, 0, 0);
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
    var prng = std.rand.DefaultPrng.init(0);

    var a = Cell.init(alloc, &prng, 0, 0);
    defer a.deinit();
    var b = Cell.init(alloc, &prng, 1, 0);
    defer b.deinit();
    var c = Cell.init(alloc, &prng, 2, 0);
    defer c.deinit();
    var d = Cell.init(alloc, &prng, 3, 0);
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
    var prng = std.rand.DefaultPrng.init(0);

    var a = Cell.init(alloc, &prng, 0, 0);
    defer a.deinit();
    var b = Cell.init(alloc, &prng, 1, 0);
    defer b.deinit();
    var c = Cell.init(alloc, &prng, 2, 0);
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
    var g = try Grid.init(alloc, 0, 4, 4);
    defer g.deinit();
    try expectEq(@as(@TypeOf(g.size()), 16), g.size());
}

test "Grid.at(...) out of bounds returns null" {
    var alloc = std.testing.allocator;
    var g = try Grid.init(alloc, 0, 4, 4);
    defer g.deinit();

    try expectEq(null, g.at(4, 4));
    try expectEq(null, g.at(0, 4));
    try expectEq(null, g.at(4, 0));
}

test "Grid.cells(...) returns an iterator" {
    var alloc = std.testing.allocator;
    var g = try Grid.init(alloc, 0, 4, 4);
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
    var g = try Grid.init(alloc, 0, 32, 32);
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
    var g = try Grid.init(alloc, 0, 5, 5);
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

test "Create/Destroy distances" {
    var alloc = std.testing.allocator;
    var g = try Grid.init(alloc, 0, 5, 5);
    defer g.deinit();

    g.distances = try g.cells_buf[0].distances();
}

test "Grid cells don't blow up when making random choices" {
    var alloc = std.testing.allocator;
    // note that seed one makes the last check succeed
    var g = try Grid.init(alloc, 1, 5, 5);
    defer g.deinit();

    var choice = g.prng.random().intRangeLessThan(usize, 0, 10);
    var choice2 = g.prng.random().intRangeLessThan(usize, 0, 10);

    try std.testing.expect(choice < 10);
    try std.testing.expect(choice != choice2);
}

test "Random link returns null when no link exists" {
    var alloc = std.testing.allocator;
    var g = try Grid.init(alloc, 0, 5, 5);
    defer g.deinit();
    try std.testing.expect(g.at(0, 0).?.randomLink() == null);
}

test "Random link does not return null when a link exists" {
    var alloc = std.testing.allocator;
    var g = try Grid.init(alloc, 0, 5, 5);
    defer g.deinit();
    var first = g.at(0, 0).?;
    var second = g.at(0, 1).?;
    try first.bLink(second);

    try std.testing.expect(first.isLinked(second) == true);
    try std.testing.expect(second.isLinked(first) == true);

    try std.testing.expect(first.randomLink() != null);
}

test "Random neighbor does not return null" {
    var alloc = std.testing.allocator;
    var g = try Grid.init(alloc, 0, 5, 5);
    defer g.deinit();
    try std.testing.expect(g.at(0, 0).?.randomNeighbor() != null);
}
