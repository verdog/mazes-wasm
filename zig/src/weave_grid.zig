//! weave grid/cell for constructing mazes. weave grids have "over" and "under" cells that
//! can tunnel underneath one another.

const std = @import("std");
const qoi = @import("qoi.zig");
const qan = @import("qanvas.zig");

pub const Distances = @import("distances.zig").Distances(WeaveGrid);

pub const WeaveGrid = struct {
    width: u32,
    height: u32,
    /// these will always have .over active
    cells_buf: []WeaveCell = undefined,
    /// these will always have .under active
    under_cells_buf: []WeaveCell = undefined,
    next_under_cell_idx: *usize = undefined,
    distances: ?Distances = null,

    alctr: std.mem.Allocator,
    prng: *std.rand.DefaultPrng,

    pub const CellT = WeaveCell;

    pub fn init(alctr: std.mem.Allocator, seed: u64, w: u32, h: u32) !This {
        var g = This{
            .width = w,
            .height = h,
            .alctr = alctr,
            .prng = try alctr.create(std.rand.DefaultPrng),
        };

        g.prng.* = std.rand.DefaultPrng.init(seed);
        g.next_under_cell_idx = try alctr.create(usize);
        g.next_under_cell_idx.* = 0;

        try g.prepareGrid();
        g.configureCells();

        return g;
    }

    fn prepareGrid(self: *This) !void {
        self.cells_buf = try self.alctr.alloc(CellT, self.width * self.height);
        self.under_cells_buf = try self.alctr.alloc(CellT, self.width * self.height);
        for (self.under_cells_buf) |*cell| {
            cell.* = undefined;
        }
        for (self.cells_buf) |*cell, i| {
            var x = @intCast(u32, i % self.width);
            var y = @intCast(u32, @divTrunc(i, self.width));
            cell.* = WeaveCell{ .over = WeaveOverCell.init(self, y, x) };
        }
    }

    fn configureCells(self: *This) void {
        for (self.cells_buf) |*cell, i| {
            var x = @intCast(u32, i % self.width);
            var y = @intCast(u32, @divTrunc(i, self.width));
            if (y > 0) cell.over.neighbors_buf[0] = self.at(x, y -| 1);
            if (y < self.height - 1) cell.over.neighbors_buf[1] = self.at(x, y +| 1);
            if (x < self.width - 1) cell.over.neighbors_buf[2] = self.at(x +| 1, y);
            if (x > 0) cell.over.neighbors_buf[3] = self.at(x -| 1, y);
            if (y > 1) cell.over.neighbors_buf[4] = self.at(x, y -| 2);
            if (y < self.height - 2) cell.over.neighbors_buf[5] = self.at(x, y +| 2);
            if (x < self.width - 2) cell.over.neighbors_buf[6] = self.at(x +| 2, y);
            if (x > 1) cell.over.neighbors_buf[7] = self.at(x -| 2, y);
        }
    }

    pub fn deinit(self: *This) void {
        for (self.cells_buf) |*cell| {
            cell.deinit();
        }
        self.alctr.free(self.cells_buf);

        {
            var i: usize = 0;
            while (i < self.next_under_cell_idx.*) : (i += 1) {
                self.under_cells_buf[i].deinit();
            }
            self.alctr.free(self.under_cells_buf);
        }

        if (self.distances) |*distances| distances.deinit();

        self.alctr.destroy(self.prng);
        self.alctr.destroy(self.next_under_cell_idx);
    }

    /// return cell at given coordinates. null if it doesn't exist.
    pub fn at(self: *This, x: u32, y: u32) ?*CellT {
        if (x < 0) return null;
        if (x >= self.width) return null;
        if (y < 0) return null;
        if (y >= self.height) return null;
        return &self.cells_buf[y * self.width + x];
    }

    /// return a random cell in the grid
    pub fn pickRandom(self: *This) *CellT {
        // for now only pick from over cells
        var i = self.prng.random().intRangeAtMost(usize, 0, self.size() - 1);
        return &self.cells_buf[i];
    }

    /// return a list of every cell that is only connected to one other cell.
    /// caller should free the returned list.
    pub fn deadends(self: *This) ![]*CellT {
        // it is impossible for an undercell to be a deadend
        var list = std.ArrayList(*CellT).init(self.alctr);
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
    pub fn braid(self: *This, p: f64) !void {
        var ddends = try self.deadends();
        defer self.alctr.free(ddends);

        self.prng.random().shuffle(*CellT, ddends);

        for (ddends) |cell| {
            const pick = self.prng.random().float(f64);
            if (pick > p or cell.numLinks() != 1) continue;

            // filter out already linked
            var unlinked_buf = [_]?*CellT{null} ** 4;
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
            var best_buf = [_]?*CellT{null} ** 4;
            var blen: usize = 0;
            for (unlinked) |unei| {
                if (unei.?.numLinks() == 1) {
                    best_buf[blen] = unei;
                    blen += 1;
                }
            }
            var best = best_buf[0..blen];

            var pool: *[]?*CellT = if (best.len > 0) &best else &unlinked;

            var choice_i = self.prng.random().intRangeLessThan(usize, 0, pool.len);
            var choice = pool.*[choice_i];
            try cell.bLink(choice.?);
        }
    }

    /// return the amount of cells in the grid
    pub fn size(self: This) usize {
        return self.width *| self.height;
    }

    pub fn tunnelUnder(self: *This, cell: *CellT) void {
        self.under_cells_buf[self.next_under_cell_idx.*] = WeaveCell{ .under = WeaveUnderCell.init(&cell.over) };
        var new_under_cell = &self.under_cells_buf[self.next_under_cell_idx.*];
        self.next_under_cell_idx.* += 1;

        if (cell.isHorizontalPassage()) {
            // tunnel under horizontal passage, so our tunnel is vertical passage.
            new_under_cell.under.neighbors_buf[0] = cell.north().?;
            new_under_cell.under.neighbors_buf[1] = cell.south().?;

            new_under_cell.bLink(cell.north().?) catch unreachable;
            new_under_cell.bLink(cell.south().?) catch unreachable;
        } else if (cell.isVerticalPassage()) {
            new_under_cell.under.neighbors_buf[0] = cell.east().?;
            new_under_cell.under.neighbors_buf[1] = cell.west().?;

            new_under_cell.bLink(cell.east().?) catch unreachable;
            new_under_cell.bLink(cell.west().?) catch unreachable;
        } else {
            unreachable;
        }
    }

    const This = @This();
};

pub const WeaveCell = union(enum) {
    over: WeaveOverCell,
    under: WeaveUnderCell,

    pub fn init(grid: *WeaveGrid, yy: u32, xx: u32) This {
        // initialize an overcell
        return WeaveCell{ .over = WeaveOverCell.init(grid, yy, xx) };
    }

    pub fn deinit(self: *This) void {
        _ = self;
    }

    /// bidirectional link
    /// self <---> other
    pub fn bLink(self: *This, other: *This) !void {
        // other is always an overcell
        std.debug.assert(std.meta.activeTag(other.*) == .over);

        switch (self.*) {
            .over => {
                var mnei: ?*WeaveCell = null;

                if (self.north() != null and self.north() == other.south()) {
                    mnei = self.north();
                } else if (self.south() != null and self.south() == other.north()) {
                    mnei = self.south();
                } else if (self.east() != null and self.east() == other.west()) {
                    mnei = self.east();
                } else if (self.west() != null and self.west() == other.east()) {
                    mnei = self.west();
                }

                if (mnei) |nei| {
                    self.over.grid.tunnelUnder(nei);
                } else {
                    try self.mLink(other);
                    try other.mLink(self);
                }
            },
            .under => {
                // under cells can only be linked to over cells

                // fix up under cell. whichNeighbor is only implemented for overcells, so
                // the switch logic here is inverted. if self is other's north underneighbor
                // (returning 8), then other is our south neighbor, etc.
                if (other.whichNeighbor(self.*)) |i| switch (i) {
                    // other is our north or east neighbor if whichNeighbor returns south or west.
                    9, 11 => self.under.neighbors_buf[0] = other,
                    // other is our south or west neighbor if whichNeighbor returns north or east.
                    8, 10 => self.under.neighbors_buf[1] = other,
                    else => unreachable,
                } else {
                    unreachable;
                }

                // fix up over cell
                if (other.whichNeighbor(self.*)) |i| {
                    other.over.neighbors_buf[i] = self;
                    other.over.linked[i] = true;
                } else {
                    unreachable;
                }
            },
        }
    }

    /// monodirectional link
    /// self ----> other
    pub fn mLink(self: *This, other: *This) !void {
        switch (self.*) {
            .over => {
                if (self.whichNeighbor(other.*)) |i| {
                    self.over.linked[i] = true;
                    return;
                }
                unreachable;
            },
            .under => {
                unreachable;
            },
        }
    }

    /// unlink `self` from `other` in both directions
    pub fn unLink(self: *This, other: *This) void {
        self.mUnLink(other);
        other.mUnLink(self);
    }

    // monodirectional unlink
    fn mUnLink(self: *This, other: *This) void {
        switch (self.*) {
            // no-ops are fine
            .over => {
                if (self.whichNeighbor(other.*)) |i|
                    self.over.linked[i] = false;
            },
            .under => unreachable,
        }
    }

    fn whichNeighbor(self: This, other: This) ?u8 {
        // self should always be an over cell
        std.debug.assert(std.meta.activeTag(self) == .over);

        switch (other) {
            .over => {
                if (self.x() == other.x() and self.y() -% other.y() == 1) return 0; // north
                if (self.x() == other.x() and other.y() -% self.y() == 1) return 1; // south
                if (self.y() == other.y() and other.x() -% self.x() == 1) return 2; // east
                if (self.y() == other.y() and self.x() -% other.x() == 1) return 3; // west
                if (self.x() == other.x() and self.y() -% other.y() == 2) return 4; // northnorth
                if (self.x() == other.x() and other.y() -% self.y() == 2) return 5; // southsouth
                if (self.y() == other.y() and other.x() -% self.x() == 2) return 6; // easteast
                if (self.y() == other.y() and self.x() -% other.x() == 2) return 7; // westwest
            },
            .under => {
                if (self.x() == other.x() and self.y() -% other.y() == 1) return 8; // undernorth
                if (self.x() == other.x() and other.y() -% self.y() == 1) return 9; // undersouth
                if (self.y() == other.y() and other.x() -% self.x() == 1) return 10; // undereast
                if (self.y() == other.y() and self.x() -% other.x() == 1) return 11; // underwest
            },
        }
        return null;
    }

    /// return true if `self` is linked to `other`
    pub fn isLinked(self: This, other: *WeaveCell) bool {
        switch (self) {
            .over => {
                if (self.whichNeighbor(other.*)) |i| return self.over.linked[i];
                return false;
            },
            .under => {
                // zig fmt: off
                return self.under.neighbors_buf[0] == other
                    or self.under.neighbors_buf[1] == other;
                // zig fmt: on
            },
        }
    }

    /// return the number of cells this cell is linked to
    pub fn numLinks(self: This) u32 {
        return switch (self) {
            .over => @intCast(u32, std.mem.count(bool, &self.over.linked, &.{true})),
            .under => 2,
        };
    }

    /// return an iterator over cells that `self` is linked to.
    pub fn links(self: This) [12]?*This {
        return self.getNeighbors(true);
    }

    /// return a random cell from the cells that are linked to this cell
    pub fn randomLink(self: This) ?*This {
        switch (self) {
            .over => {
                // XXX: Assumes the maximum amount of links a cell can have is 4
                const max_links = 4;
                var actual_links: u8 = 0;
                var potential_links = [_]?*This{null} ** max_links;

                for (self.links()) |mlink| {
                    if (mlink) |nei| {
                        potential_links[actual_links] = nei;
                        actual_links += 1;
                    }
                }

                if (actual_links != 0) {
                    var random = self.over.prng.random();
                    const choice = random.intRangeLessThan(usize, 0, actual_links);
                    return potential_links[choice];
                } else {
                    return null;
                }
            },
            .under => {
                var random = self.under.prng.random();
                const choice = random.intRangeLessThan(usize, 0, 2);
                return self.under.neighbors_buf[choice];
            },
        }
    }

    /// Returns true if this cell is part of a vertical passage.
    fn isHorizontalPassage(self: This) bool {
        // zig fmt: off
        return self.east() != null and self.isLinked(self.east().?)
           and self.west() != null and self.isLinked(self.west().?);
        // zig fmt: on
    }

    /// Returns true if this cell is part of a horizontal passage.
    fn isVerticalPassage(self: This) bool {
        // zig fmt: off
        return self.north() != null and self.isLinked(self.north().?)
           and self.south() != null and self.isLinked(self.south().?);
        // zig fmt: on
    }

    fn canTunnel(self: This, i: usize) bool {
        // i corresponds the the index of the cell in neighbors_buf
        switch (i) {
            4 => return self.north() != null and self.north().?.north() != null and self.north().?.isHorizontalPassage(),
            5 => return self.south() != null and self.south().?.south() != null and self.south().?.isHorizontalPassage(),
            6 => return self.east() != null and self.east().?.east() != null and self.east().?.isVerticalPassage(),
            7 => return self.west() != null and self.west().?.west() != null and self.west().?.isVerticalPassage(),
            else => unreachable,
        }
    }

    fn getNeighbors(self: This, require_linked: bool) [12]?*WeaveCell {
        var result = [_]?*This{null} ** 12;
        switch (self) {
            .over => {
                var i: usize = 0;
                for (self.over.neighbors_buf) |mnei, j| {
                    if (mnei) |nei| {
                        if (j < 4 or j >= 8) {
                            // cells one unit away
                            if (!require_linked or self.isLinked(nei)) {
                                result[i] = nei;
                                i += 1;
                            }
                        } else {
                            // cells two units away
                            if ((!require_linked or self.isLinked(nei)) and self.canTunnel(j)) {
                                result[i] = nei;
                                i += 1;
                            }
                        }
                    }
                }
            },
            .under => {
                var i: usize = 0;
                for (self.under.neighbors_buf) |mnei| {
                    result[i] = mnei;
                    i += 1;
                }
            },
        }
        return result;
    }

    /// return an iterator over cells that are orthogonal or tunnelable to `self`.
    /// returned cells need not be actually linked to `self`.
    pub fn neighbors(self: *This) [12]?*WeaveCell {
        return self.getNeighbors(false);
    }

    /// return a random cell from the cells that are orthogonal to this cell
    pub fn randomNeighbor(self: *This) ?*This {
        var neis_buf = self.neighbors();

        var neis = std.mem.sliceTo(&neis_buf, null);

        if (neis[0] != null) {
            var choice = self.prng().random().intRangeLessThan(usize, 0, neis.len);
            return neis[choice];
        } else {
            return null;
        }
    }

    /// return a random cell from the cells that are orthogonal to this cell
    /// and don't have a link to any other cell
    pub fn randomNeighborUnlinked(self: *This) ?*This {
        var potential_neighbors_buf = [_]*This{undefined} ** 12;
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
            var choice = self.prng().random().intRangeLessThan(usize, 0, actual_neighbors);
            return potential_neighbors[choice];
        } else {
            return null;
        }
    }

    /// return a random cell from the cells that are orthogonal to this cell
    /// and do have a link to any other cell
    pub fn randomNeighborLinked(self: *This) ?*This {
        // XXX: Assumes the maximum amount of neighbors a cell can have is 4
        var potential_neighbors_buf = [_]*This{undefined} ** 12;
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
            var choice = self.prng().random().intRangeLessThan(usize, 0, actual_neighbors);
            return potential_neighbors[choice];
        } else {
            return null;
        }
    }

    pub fn x(self: This) u32 {
        return switch (self) {
            .over => self.over.x,
            .under => self.under.x,
        };
    }

    pub fn y(self: This) u32 {
        return switch (self) {
            .over => self.over.y,
            .under => self.under.y,
        };
    }

    pub fn weight(self: This) u32 {
        return switch (self) {
            inline else => |cell| return cell.weight,
        };
    }

    pub fn north(self: This) ?*This {
        return switch (self) {
            .over => self.over.neighbors_buf[0],
            .under => self.under.neighbors_buf[0],
        };
    }

    pub fn south(self: This) ?*This {
        return switch (self) {
            .over => self.over.neighbors_buf[1],
            .under => self.under.neighbors_buf[1],
        };
    }

    pub fn east(self: This) ?*This {
        return switch (self) {
            .over => self.over.neighbors_buf[2],
            .under => self.under.neighbors_buf[1],
        };
    }

    pub fn west(self: This) ?*This {
        return switch (self) {
            .over => self.over.neighbors_buf[3],
            .under => self.under.neighbors_buf[0],
        };
    }

    pub fn prng(self: *This) *std.rand.DefaultPrng {
        return switch (self.*) {
            .over => self.over.prng,
            .under => self.under.prng,
        };
    }

    const This = @This();
};

pub const WeaveOverCell = struct {
    pub fn init(grid: *GridT, y: u32, x: u32) This {
        return This{
            .y = y,
            .x = x,
            .grid = grid.*,
            .prng = grid.prng,
            .alctr = grid.alctr,
        };
    }

    pub fn deinit(self: *This) void {
        _ = self;
    }

    y: u32 = 0,
    x: u32 = 0,
    weight: u32 = 1,
    alctr: std.mem.Allocator,
    grid: GridT,
    prng: *std.rand.DefaultPrng,

    // north, south, east, west,
    // northnorth, southsouth, easteast, westwest,
    // undernorth, undersouth, undereast, underwest
    neighbors_buf: [neighbors_len]?*WeaveCell = [_]?*WeaveCell{null} ** neighbors_len,
    // linked[i] is true is this cell is linked to neighbors_buf[i]
    linked: [neighbors_len]bool = [_]bool{false} ** neighbors_len,
    pub const neighbors_len = 12;
    pub const GridT = WeaveGrid;
    const This = @This();
};

const WeaveUnderCell = struct {
    pub fn init(superior: *WeaveOverCell) This {
        return .{
            .x = superior.x,
            .y = superior.y,
            .prng = superior.prng,
        };
    }

    pub fn deinit(self: *This) void {
        _ = self;
    }

    x: u32,
    y: u32,
    prng: *std.rand.DefaultPrng,
    weight: u32 = 1,

    /// north/south or west/east
    /// these should all have .over active
    neighbors_buf: [neighbors_len]*WeaveCell = [_]*WeaveCell{undefined} ** neighbors_len,
    pub const neighbors_len = 2;
    const This = @This();
};

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

pub fn makeQanvas(self: WeaveGrid, walls: bool, scale: usize, inset_percent: f64) !qan.Qanvas {
    const cell_size = @intCast(u32, scale);
    const border_size = cell_size / 2;
    const inset = @floatToInt(u32, @intToFloat(f64, cell_size) * inset_percent);

    const width = self.width * cell_size;
    const height = self.height * cell_size;

    var qanv = try qan.Qanvas.init(self.alctr, width + border_size * 2, height + border_size * 2);

    const background: qoi.Qixel(qoi.RGB) = .{ .colors = .{ .red = 10, .green = 10, .blue = 15 } };
    const hue = @intToFloat(f32, self.prng.random().intRangeLessThan(u16, 0, 360));
    const path_low = qoi.Qixel(qoi.HSV){ .colors = .{ .hue = hue, .saturation = 0.55, .value = 0.65 }, .alpha = 255 };
    const path_hi = qoi.Qixel(qoi.HSV){ .colors = .{ .hue = @mod(hue + @intToFloat(f32, self.prng.random().intRangeLessThan(u16, 60, 180)), 360), .saturation = 0.65, .value = 0.20 }, .alpha = 255 };

    var max = if (self.distances) |dists| dists.max() else null;

    qanv.clear(background);

    var bufs: [2][]WeaveCell = .{ self.under_cells_buf[0..self.next_under_cell_idx.*], self.cells_buf };
    for (bufs) |buf| {
        for (buf) |*cell| {
            const x1 = cell.x() * cell_size + border_size;
            const y1 = cell.y() * cell_size + border_size;
            const coords = cellCoordsWithInset(x1, y1, cell_size, inset);

            // background
            if (self.distances) |dists| {
                if (dists.get(cell)) |thedist| {
                    // zig fmt: off
                    const color = path_low.lerp(path_hi,
                        @intToFloat(f64, thedist) / @intToFloat(f64, max.?.distance)
                                               ).to(qoi.RGB);

                    // center
                    try qanv.fill(color, coords.x2, coords.x3, coords.y2, coords.y3);

                    if (cell.north() != null and cell.isLinked(cell.north().?)
                    or  cell.over.neighbors_buf[8] != null and cell.isLinked(cell.over.neighbors_buf[8].?))
                    {
                        try qanv.fill(color, coords.x2, coords.x3, coords.y1, coords.y2);
                    }

                    if (cell.south() != null and cell.isLinked(cell.south().?)
                    or  cell.over.neighbors_buf[9] != null and cell.isLinked(cell.over.neighbors_buf[9].?))
                    {
                        try qanv.fill(color, coords.x2, coords.x3, coords.y3, coords.y4);
                    }

                    if (cell.east() != null and cell.isLinked(cell.east().?)
                    or  cell.over.neighbors_buf[10] != null and cell.isLinked(cell.over.neighbors_buf[10].?))
                    {
                        try qanv.fill(color, coords.x3, coords.x4, coords.y2, coords.y3);
                    }

                    if (cell.west() != null and cell.isLinked(cell.west().?)
                    or  cell.over.neighbors_buf[11] != null and cell.isLinked(cell.over.neighbors_buf[11].?))
                    {
                        try qanv.fill(color, coords.x1, coords.x2, coords.y2, coords.y3);
                    }
                    // zig fmt: on
                }
            }

            // walls
            if (walls) {
                // const wall: qoi.Qixel(qoi.RGB) = .{ .colors = .{ .red = 127, .green = 115, .blue = 115 } };
                const wall: qoi.Qixel(qoi.RGB) = .{ .colors = .{ .red = 12, .green = 11, .blue = 11 } };

                // zig fmt: off
                if (cell.north() != null and cell.isLinked(cell.north().?)
                or  cell.over.neighbors_buf[8] != null and cell.isLinked(cell.over.neighbors_buf[8].?))
                {
                    try qanv.line(wall, coords.x2, coords.x2, coords.y1, coords.y2);
                    try qanv.line(wall, coords.x3, coords.x3, coords.y1, coords.y2);
                } else {
                    try qanv.line(wall, coords.x2, coords.x3 + 1, coords.y2, coords.y2);
                }

                if (cell.south() != null and cell.isLinked(cell.south().?)
                or  cell.over.neighbors_buf[9] != null and cell.isLinked(cell.over.neighbors_buf[9].?))
                {
                    try qanv.line(wall, coords.x2, coords.x2, coords.y3, coords.y4);
                    try qanv.line(wall, coords.x3, coords.x3, coords.y3, coords.y4);
                } else {
                    try qanv.line(wall, coords.x2, coords.x3 + 1, coords.y3, coords.y3);
                }

                if (cell.east() != null and cell.isLinked(cell.east().?)
                or  cell.over.neighbors_buf[10] != null and cell.isLinked(cell.over.neighbors_buf[10].?))
                {
                    try qanv.line(wall, coords.x3, coords.x4, coords.y2, coords.y2);
                    try qanv.line(wall, coords.x3, coords.x4, coords.y3, coords.y3);
                } else {
                    try qanv.line(wall, coords.x3, coords.x3, coords.y2, coords.y3);
                }

                if (cell.west() != null and cell.isLinked(cell.west().?)
                or  cell.over.neighbors_buf[11] != null and cell.isLinked(cell.over.neighbors_buf[11].?))
                {
                    try qanv.line(wall, coords.x1, coords.x2, coords.y2, coords.y2);
                    try qanv.line(wall, coords.x1, coords.x2, coords.y3, coords.y3);
                } else {
                    try qanv.line(wall, coords.x2, coords.x2, coords.y2, coords.y3);
                }
                // zig fmt: on
            }
        }
    }

    return qanv;
}
