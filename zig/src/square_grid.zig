//! Grid and Cell types for constructing mazes

const std = @import("std");
const qoi = @import("qoi.zig");
const qan = @import("qanvas.zig");

const Distances = @import("distances.zig").Distances;

const Allocator = std.mem.Allocator;
const expect = std.testing.expect;
const expectEq = std.testing.expectEqual;

/// a single maze Cell
pub const SquareCell = struct {
    pub fn init(alctr: std.mem.Allocator, prng: *std.rand.DefaultPrng, y: u32, x: u32) SquareCell {
        return SquareCell{
            .y = y,
            .x = x,
            .prng = prng,
            .alctr = alctr,
        };
    }

    pub fn deinit(self: *SquareCell) void {
        _ = self;
    }

    /// bidirectional link
    /// self <---> other
    pub fn bLink(self: *SquareCell, other: *SquareCell) !void {
        try self.mLink(other);
        try other.mLink(self);
    }

    /// monodirectional link
    /// self ----> other
    pub fn mLink(self: *SquareCell, other: *SquareCell) !void {
        if (self.whichNeighbor(other.*)) |i| {
            self.linked[i] = true;
            return;
        }
        unreachable;
    }

    /// unlink `self` from `other` in both directions
    pub fn unLink(self: *SquareCell, other: *SquareCell) void {
        self.mUnLink(other);
        other.mUnLink(self);
    }

    // monodirectional unlink
    fn mUnLink(self: *SquareCell, other: *SquareCell) void {
        // no-ops are fine
        if (self.whichNeighbor(other.*)) |i| self.linked[i] = false;
    }

    fn whichNeighbor(self: SquareCell, other: SquareCell) ?u8 {
        if (self.x == other.x and self.y -% other.y == 1) return 0; // north
        if (self.x == other.x and other.y -% self.y == 1) return 1; // south
        if (self.y == other.y and other.x -% self.x == 1) return 2; // east
        if (self.y == other.y and self.x -% other.x == 1) return 3; // west
        return null;
    }

    /// return true if `self` is linked to `other`
    pub fn isLinked(self: SquareCell, other: *SquareCell) bool {
        if (self.whichNeighbor(other.*)) |i| return self.linked[i];
        return false;
    }

    /// return the number of cells this cell is linked to
    pub fn numLinks(self: SquareCell) u32 {
        return @intCast(u32, std.mem.count(bool, &self.linked, &.{true}));
    }

    /// return an iterator over cells that `self` is linked to.
    pub fn links(self: SquareCell) [4]?*SquareCell {
        return self.getNeighbors(true);
    }

    /// return a random cell from the cells that are linked to this cell
    pub fn randomLink(self: SquareCell) ?*SquareCell {
        // XXX: Assumes the maximum amount of links a cell can have is 4
        const max_links = 4;
        var actual_links: u8 = 0;
        var potential_links = [_]?*SquareCell{null} ** max_links;

        for (self.links()) |mlink| {
            if (mlink) |nei| {
                potential_links[actual_links] = nei;
                actual_links += 1;
            }
        }

        if (actual_links != 0) {
            var random = self.prng.random();
            const choice = random.intRangeLessThan(usize, 0, actual_links);
            return potential_links[choice];
        } else {
            return null;
        }
    }

    fn getNeighbors(self: SquareCell, require_linked: bool) [4]?*SquareCell {
        var result = [_]?*SquareCell{null} ** 4;
        var i: usize = 0;
        for (self.neighbors_buf) |mnei| {
            if (mnei) |nei| {
                if (!require_linked or self.isLinked(nei)) {
                    result[i] = nei;
                    i += 1;
                }
            }
        }
        return result;
    }

    /// return an iterator over cells that are orthogonal to `self`.
    /// returned cells need not be actually linked to `self`.
    pub fn neighbors(self: *SquareCell) [4]?*SquareCell {
        return self.getNeighbors(false);
    }

    /// return a random cell from the cells that are orthogonal to this cell
    pub fn randomNeighbor(self: *SquareCell) ?*SquareCell {
        var neis_buf = self.neighbors();

        var neis = std.mem.sliceTo(&neis_buf, null);

        if (neis[0] != null) {
            var choice = self.prng.random().intRangeLessThan(usize, 0, neis.len);
            return neis[choice];
        } else {
            return null;
        }
    }

    /// return a random cell from the cells that are orthogonal to this cell
    /// and don't have a link to any other cell
    pub fn randomNeighborUnlinked(self: *SquareCell) ?*SquareCell {
        // XXX: Assumes the maximum amount of neighbors a cell can have is 4
        var potential_neighbors_buf = [_]*SquareCell{undefined} ** 32;
        var actual_neighbors: usize = 0;

        var neis = self.neighbors();
        for (neis) |mnei| {
            if (mnei) |nei| {
                if (nei.numLinks() == 0) {
                    potential_neighbors_buf[actual_neighbors] = nei;
                    actual_neighbors += 1;
                }
            }
        }

        const potential_neighbors = potential_neighbors_buf[0..actual_neighbors];

        if (actual_neighbors != 0) {
            var choice = self.prng.random().intRangeLessThan(usize, 0, actual_neighbors);
            return potential_neighbors[choice];
        } else {
            return null;
        }
    }

    /// return a random cell from the cells that are orthogonal to this cell
    /// and do have a link to any other cell
    pub fn randomNeighborLinked(self: *SquareCell) ?*SquareCell {
        // XXX: Assumes the maximum amount of neighbors a cell can have is 4
        var potential_neighbors_buf = [_]*SquareCell{undefined} ** 32;
        var actual_neighbors: usize = 0;

        var neis = self.neighbors();
        for (neis) |mnei| {
            if (mnei) |nei| {
                if (nei.numLinks() > 0) {
                    potential_neighbors_buf[actual_neighbors] = nei;
                    actual_neighbors += 1;
                }
            }
        }

        const potential_neighbors = potential_neighbors_buf[0..actual_neighbors];

        if (actual_neighbors != 0) {
            var choice = self.prng.random().intRangeLessThan(usize, 0, actual_neighbors);
            return potential_neighbors[choice];
        } else {
            return null;
        }
    }

    pub fn north(self: SquareCell) ?*SquareCell {
        return self.neighbors_buf[0];
    }

    pub fn south(self: SquareCell) ?*SquareCell {
        return self.neighbors_buf[1];
    }

    pub fn east(self: SquareCell) ?*SquareCell {
        return self.neighbors_buf[2];
    }

    pub fn west(self: SquareCell) ?*SquareCell {
        return self.neighbors_buf[3];
    }

    y: u32 = 0,
    x: u32 = 0,
    weight: u32 = 1,
    alctr: std.mem.Allocator,

    prng: *std.rand.DefaultPrng,

    // north, south, east, west
    neighbors_buf: [neighbors_len]?*SquareCell = [_]?*SquareCell{null} ** neighbors_len,
    // linked[i] is true is this cell is linked to neighbors_buf[i]
    linked: [neighbors_len]bool = [_]bool{false} ** neighbors_len,
    pub const neighbors_len = 4;
};

pub const SquareGrid = struct {
    width: u32,
    height: u32,
    cells_buf: []SquareCell = undefined,
    distances: ?Distances(SquareGrid) = null,

    alctr: Allocator,
    prng: *std.rand.DefaultPrng,

    pub const CellT = SquareCell;

    pub fn init(alctr: Allocator, seed: u64, w: u32, h: u32) !SquareGrid {
        var g = SquareGrid{
            .width = w,
            .height = h,
            .alctr = alctr,
            .prng = try alctr.create(std.rand.DefaultPrng),
        };

        g.prng.* = std.rand.DefaultPrng.init(seed);

        try g.prepareGrid();
        g.configureCells();

        return g;
    }

    pub fn deinit(self: *SquareGrid) void {
        for (self.cells_buf) |*cell| {
            cell.*.deinit();
        }
        self.alctr.free(self.cells_buf);
        if (self.distances) |*distances| distances.deinit();
        self.alctr.destroy(self.prng);
    }

    /// return cell at given coordinates. null if it doesn't exist.
    pub fn at(self: *SquareGrid, x: u32, y: u32) ?*SquareCell {
        if (x < 0) return null;
        if (x >= self.width) return null;
        if (y < 0) return null;
        if (y >= self.height) return null;
        return &self.cells_buf[y * self.width + x];
    }

    /// return a random cell in the grid
    pub fn pickRandom(self: *SquareGrid) *SquareCell {
        var i = self.prng.random().intRangeAtMost(usize, 0, self.size() - 1);
        return &self.cells_buf[i];
    }

    /// return a list of every cell that is only connected to one other cell.
    /// caller should free the returned list.
    pub fn deadends(self: *SquareGrid) ![]*SquareCell {
        var list = std.ArrayList(*SquareCell).init(self.alctr);
        defer list.deinit();

        for (self.cells_buf) |*cell| {
            if (cell.numLinks() == 1) {
                try list.append(cell);
            }
        }

        return list.toOwnedSlice();
    }

    /// remove dead ends. p is a number betweein 0.0 and 1.0 and is the
    /// probability that a dead end will be removed.
    pub fn braid(self: *SquareGrid, p: f64) !void {
        var ddends = try self.deadends();
        defer self.alctr.free(ddends);

        self.prng.random().shuffle(*SquareCell, ddends);

        for (ddends) |cell| {
            const pick = self.prng.random().float(f64);
            if (pick > p or cell.numLinks() != 1) continue;

            // filter out already linked
            var unlinked_buf = [_]?*SquareCell{null} ** 4;
            var ulen: usize = 0;
            for (cell.neighbors()) |mnei| {
                if (mnei) |nei| {
                    if (!cell.isLinked(nei)) {
                        unlinked_buf[ulen] = nei;
                        ulen += 1;
                    }
                }
            }
            var unlinked = unlinked_buf[0..ulen];

            // prefer linked two dead ends together. it looks nice
            var best_buf = [_]?*SquareCell{null} ** 4;
            var blen: usize = 0;
            for (unlinked) |unei| {
                if (unei.?.numLinks() == 1) {
                    best_buf[blen] = unei;
                    blen += 1;
                }
            }
            var best = best_buf[0..blen];

            var pool: *[]?*SquareCell = if (best.len > 0) &best else &unlinked;

            var choice_i = self.prng.random().intRangeLessThan(usize, 0, pool.len);
            var choice = pool.*[choice_i];
            try cell.bLink(choice.?);
        }
    }

    /// return the amount of cells in the grid
    pub fn size(self: SquareGrid) usize {
        return self.width *| self.height;
    }

    fn prepareGrid(self: *SquareGrid) !void {
        self.cells_buf = try self.alctr.alloc(SquareCell, self.width * self.height);
        for (self.cells_buf) |*cell, i| {
            var x = @intCast(u32, i % self.width);
            var y = @intCast(u32, @divTrunc(i, self.width));
            cell.* = SquareCell.init(self.alctr, self.prng, y, x);
        }
    }

    fn configureCells(self: *SquareGrid) void {
        for (self.cells_buf) |*cell, i| {
            var x = @intCast(u32, i % self.width);
            var y = @intCast(u32, @divTrunc(i, self.width));
            if (y > 0) cell.neighbors_buf[0] = self.at(x, y -| 1);
            if (y < self.height - 1) cell.neighbors_buf[1] = self.at(x, y +| 1);
            if (x < self.width - 1) cell.neighbors_buf[2] = self.at(x +| 1, y);
            if (x > 0) cell.neighbors_buf[3] = self.at(x -| 1, y);
        }
    }

    fn writeAndAdvance(buf: *[]u8, i: *usize, word: []const u8) !void {
        var inner_slice = buf.*[i.* .. i.* + word.len];
        std.mem.copy(u8, inner_slice, word);
        i.* += word.len;
    }

    fn contentsOf(self: SquareGrid, cell: *SquareCell) u8 {
        const contents = "0123456789ABCDEF";
        if (self.distances) |distances| {
            if (distances.get(cell)) |dist| {
                return contents[(dist - 1) % contents.len];
            }
        }
        return ' ';
    }

    /// return a string representation of the grid.
    /// memory for the string will be allocated with
    /// the allocator that the grid was initialized with.
    /// TODO test performance
    pub fn makeString(self: SquareGrid) ![]u8 {
        // the output will have a top row of +---+,
        // followed by a grid that takes up 2 rows
        // per grid row.

        //                  +   ---+            \n
        var row_len: u32 = 1 + 4 * self.width + 1;
        //                    top row   rest of maze
        var total_len: u32 = row_len + row_len * self.height * 2;
        var ret = try self.alctr.alloc(u8, total_len);

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
                    if (cell.east() != null and cell.isLinked(cell.east().?)) data[3] = ' ';
                    data[1] = self.contentsOf(cell);
                    try w(&ret, &i, &data);
                }
                try w(&ret, &i, "\n");

                // row 2
                try w(&ret, &i, "+");
                for (row_slice) |cell| {
                    try w(&ret, &i, if (cell.south() != null and cell.isLinked(cell.south().?) == true) "   +" else "---+");
                }
                try w(&ret, &i, "\n");
            }
        }

        return ret;
    }

    fn makeQanvasNoInset(self: SquareGrid, walls: bool, scale: usize) !qan.Qanvas {
        const cell_size = @intCast(u32, scale);
        const border_size = cell_size / 2;

        const width = self.width * cell_size;
        const height = self.height * cell_size;

        var qanv = try qan.Qanvas.init(self.alctr, width + border_size * 2, height + border_size * 2);

        // black
        const background: qoi.Qixel(qoi.RGB) = .{ .colors = .{ .red = 10, .green = 10, .blue = 15 } };
        const hue = @intToFloat(f32, self.prng.random().intRangeLessThan(u16, 0, 360));
        const path_low = qoi.Qixel(qoi.HSV){ .colors = .{ .hue = hue, .saturation = 0.55, .value = 0.65 }, .alpha = 255 };
        const path_hi = qoi.Qixel(qoi.HSV){ .colors = .{ .hue = @mod(hue + @intToFloat(f32, self.prng.random().intRangeLessThan(u16, 60, 180)), 360), .saturation = 0.65, .value = 0.20 }, .alpha = 255 };

        var max = if (self.distances) |dists| dists.max() else null;

        qanv.clear(background);

        // background
        for (self.cells_buf) |*cell| {
            const x1 = cell.x * cell_size + border_size;
            const x2 = (cell.x + 1) * cell_size + border_size;
            const y1 = cell.y * cell_size + border_size;
            const y2 = (cell.y + 1) * cell_size + border_size;

            if (self.distances) |dists| {
                if (dists.get(cell)) |thedist| {
                    const color = path_low.lerp(path_hi, @intToFloat(f64, thedist) / @intToFloat(f64, max.?.distance)).to(qoi.RGB);

                    try qanv.fill(color, x1, x2, y1, y2);
                }
            }
        }

        // walls
        if (walls) {
            // black
            // const wall: qoi.Qixel = .{ .red = 0, .green = 0, .blue = 0 };

            // white
            const wall: qoi.Qixel(qoi.RGB) = .{ .colors = .{ .red = 15, .green = 10, .blue = 10 } };

            for (self.cells_buf) |*cell| {
                const x1 = cell.x * cell_size + border_size;
                const x2 = (cell.x + 1) * cell_size + border_size;
                const y1 = cell.y * cell_size + border_size;
                const y2 = (cell.y + 1) * cell_size + border_size;

                if (cell.north() == null) try qanv.line(wall, x1, x2, y1, y1);
                if (cell.west() == null) try qanv.line(wall, x1, x1, y1, y2);

                if (cell.east() == null or !cell.isLinked(cell.east().?)) try qanv.line(wall, x2, x2, y1, y2 + 1);
                if (cell.south() == null or !cell.isLinked(cell.south().?)) try qanv.line(wall, x1, x2 + 1, y2, y2);
            }
        }

        return qanv;
    }

    fn cellCoordsWithInset(x: u32, y: u32, cell_size: u32, inset: u32) struct {
        // zig fmt: off
        // y:
        // 1_
        // 2_. |       |_.
        //   . |         .
        //   . |         .
        // 3_. |_________.
        // 4_. .       . .
        // x:1 2       3 4
        //
        // for each axis a, a1 is the first border of the cell space, a2 is the first
        // actual wall drawn, a3 is the other wall drawn, and a4 is the other side of the
        // cell space.
        x1: u32, x2: u32, x3: u32, x4: u32,
        y1: u32, y2: u32, y3: u32, y4: u32,
    } {
        const x1 = x;
        const x2 = x1 + inset;
        const x4 = x + cell_size;
        const x3 = x4 - inset;
        const y1 = y;
        const y2 = y + inset;
        const y4 = y + cell_size;
        const y3 = y4 - inset;
        return .{
            .x1 = x1, .x2 = x2, .x3 = x3, .x4 = x4,
            .y1 = y1, .y2 = y2, .y3 = y3, .y4 = y4,
        };
        // zig fmt: on
    }

    fn makeQanvasInset(self: SquareGrid, walls: bool, scale: usize, inset_percent: f64) !qan.Qanvas {
        const cell_size = @intCast(u32, scale);
        const border_size = cell_size / 2;
        const inset = @floatToInt(u32, @intToFloat(f64, cell_size) * inset_percent);

        const width = self.width * cell_size;
        const height = self.height * cell_size;

        var qanv = try qan.Qanvas.init(self.alctr, width + border_size * 2, height + border_size * 2);

        // black
        const background: qoi.Qixel(qoi.RGB) = .{ .colors = .{ .red = 10, .green = 10, .blue = 15 } };
        const hue = @intToFloat(f32, self.prng.random().intRangeLessThan(u16, 0, 360));
        const path_low = qoi.Qixel(qoi.HSV){ .colors = .{ .hue = hue, .saturation = 0.55, .value = 0.65 }, .alpha = 255 };
        const path_hi = qoi.Qixel(qoi.HSV){ .colors = .{ .hue = @mod(hue + @intToFloat(f32, self.prng.random().intRangeLessThan(u16, 60, 180)), 360), .saturation = 0.65, .value = 0.20 }, .alpha = 255 };

        var max = if (self.distances) |dists| dists.max() else null;

        qanv.clear(background);

        // background
        for (self.cells_buf) |*cell| {
            const x1 = cell.x * cell_size + border_size;
            const y1 = cell.y * cell_size + border_size;
            const coords = cellCoordsWithInset(x1, y1, cell_size, inset);
            if (self.distances) |dists| {
                if (dists.get(cell)) |thedist| {
                    // zig fmt: off
                    const color = path_low.lerp(path_hi,
                        @intToFloat(f64, thedist) / @intToFloat(f64, max.?.distance)
                                               ).to(qoi.RGB);
                    // zig fmt: on

                    // center
                    try qanv.fill(color, coords.x2, coords.x3, coords.y2, coords.y3);

                    if (cell.north() != null and cell.isLinked(cell.north().?)) {
                        try qanv.fill(color, coords.x2, coords.x3, coords.y1, coords.y2);
                    }

                    if (cell.south() != null and cell.isLinked(cell.south().?)) {
                        try qanv.fill(color, coords.x2, coords.x3, coords.y3, coords.y4);
                    }

                    if (cell.east() != null and cell.isLinked(cell.east().?)) {
                        try qanv.fill(color, coords.x3, coords.x4, coords.y2, coords.y3);
                    }

                    if (cell.west() != null and cell.isLinked(cell.west().?)) {
                        try qanv.fill(color, coords.x1, coords.x2, coords.y2, coords.y3);
                    }
                }
            }
        }

        // walls
        if (walls) {
            const wall: qoi.Qixel(qoi.RGB) = .{ .colors = .{ .red = 127, .green = 115, .blue = 115 } };

            for (self.cells_buf) |*cell| {
                const x1 = cell.x * cell_size + border_size;
                const y1 = cell.y * cell_size + border_size;
                const coords = cellCoordsWithInset(x1, y1, cell_size, inset);

                if (cell.north() != null and cell.isLinked(cell.north().?)) {
                    try qanv.line(wall, coords.x2, coords.x2, coords.y1, coords.y2);
                    try qanv.line(wall, coords.x3, coords.x3, coords.y1, coords.y2);
                } else {
                    try qanv.line(wall, coords.x2, coords.x3 + 1, coords.y2, coords.y2);
                }

                if (cell.south() != null and cell.isLinked(cell.south().?)) {
                    try qanv.line(wall, coords.x2, coords.x2, coords.y3, coords.y4);
                    try qanv.line(wall, coords.x3, coords.x3, coords.y3, coords.y4);
                } else {
                    try qanv.line(wall, coords.x2, coords.x3 + 1, coords.y3, coords.y3);
                }

                if (cell.east() != null and cell.isLinked(cell.east().?)) {
                    try qanv.line(wall, coords.x3, coords.x4, coords.y2, coords.y2);
                    try qanv.line(wall, coords.x3, coords.x4, coords.y3, coords.y3);
                } else {
                    try qanv.line(wall, coords.x3, coords.x3, coords.y2, coords.y3);
                }

                if (cell.west() != null and cell.isLinked(cell.west().?)) {
                    try qanv.line(wall, coords.x1, coords.x2, coords.y2, coords.y2);
                    try qanv.line(wall, coords.x1, coords.x2, coords.y3, coords.y3);
                } else {
                    try qanv.line(wall, coords.x2, coords.x2, coords.y2, coords.y3);
                }
            }
        }

        return qanv;
    }

    /// return a representation of the grid encoded as a qoi image.
    /// memory for the returned buffer is allocated by the allocator
    /// that the grid was initialized with.
    pub fn makeQanvas(self: SquareGrid, walls: bool, scale: usize, inset_percent: f64) !qan.Qanvas {
        if (inset_percent > 0) return self.makeQanvasInset(walls, scale, inset_percent);
        return self.makeQanvasNoInset(walls, scale);
    }
};

test "Grid.makeString() returns a perfect, closed grid before modification" {
    var alloc = std.testing.allocator;
    var g = try SquareGrid.init(alloc, 0, 5, 5);
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
