//! upsilon grid/cell for constructing mazes. upsilon mazes have an octogon/square tiling.

const std = @import("std");
const qoi = @import("qoi.zig");
const qan = @import("qanvas.zig");
const u = @import("u.zig");

pub const Distances = @import("distances.zig").Distances(UpsilonGrid);

pub const Error = error{
    UpsilonMazeError,
};

pub const UpsilonCell = struct {
    pub fn init(grid: *UpsilonGrid, xx: u32, yy: u32) UpsilonCell {
        return UpsilonCell{
            .alctr = grid.alctr,
            ._prng = grid.prng,
            ._x = xx,
            ._y = yy,
        };
    }

    pub fn deinit(self: UpsilonCell) void {
        _ = self;
    }

    fn isOctogon(self: UpsilonCell) bool {
        return (self.x() +% self.y()) & 1 == 0;
    }

    pub fn north(self: UpsilonCell) ?*UpsilonCell {
        return self.neighbors_buf[0];
    }
    pub fn northEast(self: UpsilonCell) ?*UpsilonCell {
        return self.neighbors_buf[1];
    }
    pub fn east(self: UpsilonCell) ?*UpsilonCell {
        return self.neighbors_buf[2];
    }
    pub fn southEast(self: UpsilonCell) ?*UpsilonCell {
        return self.neighbors_buf[3];
    }
    pub fn south(self: UpsilonCell) ?*UpsilonCell {
        return self.neighbors_buf[4];
    }
    pub fn southWest(self: UpsilonCell) ?*UpsilonCell {
        return self.neighbors_buf[5];
    }
    pub fn west(self: UpsilonCell) ?*UpsilonCell {
        return self.neighbors_buf[6];
    }
    pub fn northWest(self: UpsilonCell) ?*UpsilonCell {
        return self.neighbors_buf[7];
    }

    fn getNeighbors(self: UpsilonCell, require_linked: bool) [8]?*UpsilonCell {
        var result = [_]?*UpsilonCell{null} ** 8;
        var i: usize = 0;
        for (self.neighbors_buf) |maybe_nei| {
            if (maybe_nei) |nei| {
                if (!require_linked or self.isLinked(nei)) {
                    result[i] = nei;
                    i += 1;
                }
            }
        }
        return result;
    }

    pub fn neighbors(self: UpsilonCell) [8]?*UpsilonCell {
        return self.getNeighbors(false);
    }

    pub fn randomNeighbor(self: UpsilonCell) ?*UpsilonCell {
        const my_neighbors = self.neighbors();
        const count = blk: {
            var c: usize = 0;
            for (my_neighbors) |maybe_nei| {
                if (maybe_nei != null) c += 1;
            }
            break :blk c;
        };
        const choice = self.prng().random().intRangeLessThan(usize, 0, count);
        return my_neighbors[choice];
    }

    pub fn randomNeighborLinked(self: UpsilonCell) ?*UpsilonCell {
        var my_neighbors = self.neighbors();

        // reduce to only those that are linked
        var write: usize = 0;
        var read: usize = 0;
        while (read < my_neighbors.len and my_neighbors[read] != null) : (read += 1) {
            if (my_neighbors[read].?.numLinks() > 0) {
                my_neighbors[write] = my_neighbors[read];
                write += 1;
            }
        }

        return blk: {
            if (write == 0) break :blk null;
            const choice = self.prng().random().intRangeLessThan(usize, 0, write);
            break :blk my_neighbors[choice];
        };
    }

    /// return a random cell from this cell's neighbors that hasn't been linked yet
    pub fn randomNeighborUnlinked(self: UpsilonCell) ?*UpsilonCell {
        var my_neighbors = self.neighbors();

        // reduce to only those that are not linked
        var write: usize = 0;
        var read: usize = 0;
        while (read < my_neighbors.len and my_neighbors[read] != null) : (read += 1) {
            if (my_neighbors[read].?.numLinks() == 0) {
                my_neighbors[write] = my_neighbors[read];
                write += 1;
            }
        }

        return blk: {
            if (write == 0) break :blk null;
            const choice = self.prng().random().intRangeLessThan(usize, 0, write);
            break :blk my_neighbors[choice];
        };
    }

    fn whichNeighbor(self: UpsilonCell, other: UpsilonCell) ?u8 {
        const vec = .{
            .x = @as(i64, other.x()) - @as(i64, self.x()),
            .y = @as(i64, other.y()) - @as(i64, self.y()),
        };
        const V = @TypeOf(vec);

        if (std.meta.eql(vec, V{ .x = 0, .y = -1 })) return 0; // north
        if (std.meta.eql(vec, V{ .x = 1, .y = -1 })) return 1; // northeast
        if (std.meta.eql(vec, V{ .x = 1, .y = 0 })) return 2; // east
        if (std.meta.eql(vec, V{ .x = 1, .y = 1 })) return 3; // southeast
        if (std.meta.eql(vec, V{ .x = 0, .y = 1 })) return 4; // south
        if (std.meta.eql(vec, V{ .x = -1, .y = 1 })) return 5; // southwest
        if (std.meta.eql(vec, V{ .x = -1, .y = 0 })) return 6; // west
        if (std.meta.eql(vec, V{ .x = -1, .y = -1 })) return 7; // northwest
        return null;
    }

    /// return list of this cell's neighbors. they *do* need to be linked.
    /// the returned neighbors will be packed into the front of the array.
    pub fn links(self: UpsilonCell) [8]?*UpsilonCell {
        return self.getNeighbors(true);
    }

    pub fn randomLink(self: UpsilonCell) ?*UpsilonCell {
        // XXX: Assumes the maximum amount of links a cell can have is 8
        const max_links = 8;
        var actual_links: u8 = 0;
        var potential_links = [_]?*UpsilonCell{null} ** max_links;

        for (self.links()) |mlink| {
            if (mlink) |nei| {
                potential_links[actual_links] = nei;
                actual_links += 1;
            }
        }

        if (actual_links != 0) {
            var random = self.prng().random();
            const choice = random.intRangeLessThan(usize, 0, actual_links);
            return potential_links[choice];
        } else {
            return null;
        }
    }

    pub fn numLinks(self: UpsilonCell) usize {
        var count: usize = 0;
        for (self.linked) |b| {
            if (b) count += 1;
        }
        return count;
    }

    /// bidirectional link.
    /// self <---> other.
    pub fn bLink(self: *UpsilonCell, other: *UpsilonCell) !void {
        try self.mLink(other);
        try other.mLink(self);
    }

    // monodirectional link.
    // self ----> other.
    // self and other must be adjacent.
    pub fn mLink(self: *UpsilonCell, other: *UpsilonCell) !void {
        if (self.whichNeighbor(other.*)) |idx| {
            self.neighbors_buf[idx] = other;
            self.linked[idx] = true;
            return;
        }
        return Error.UpsilonMazeError;
    }

    /// bidirectional unlink.
    pub fn unLink(self: *UpsilonCell, other: *UpsilonCell) void {
        self.mUnLink(other);
        other.mUnLink(self);
    }

    fn mUnLink(self: *UpsilonCell, other: *UpsilonCell) void {
        if (self.whichNeighbor(other.*)) |idx| {
            // unLink doesn't change neighbors
            self.linked[idx] = false;
        }
        // no-ops are fine
    }

    /// return true is `self` is linked to `other`
    pub fn isLinked(self: UpsilonCell, other: *UpsilonCell) bool {
        if (self.whichNeighbor(other.*)) |idx| {
            return self.linked[idx];
        }
        return false;
    }

    pub fn x(self: UpsilonCell) u32 {
        return self._x;
    }

    pub fn y(self: UpsilonCell) u32 {
        return self._y;
    }

    pub fn weight(self: UpsilonCell) u32 {
        return self._weight;
    }

    pub fn prng(self: @This()) *std.rand.DefaultPrng {
        return self._prng;
    }

    neighbors_buf: [neighbors_len]?*UpsilonCell = [_]?*UpsilonCell{null} ** neighbors_len,
    linked: [neighbors_len]bool = [_]bool{false} ** neighbors_len,

    alctr: std.mem.Allocator,
    _prng: *std.rand.DefaultPrng,
    _x: u32,
    _y: u32,
    _weight: u32 = 1,

    pub const neighbors_len = 8;
};

pub const UpsilonGrid = struct {
    width: u32,
    height: u32,
    cells_buf: []UpsilonCell = undefined,
    distances: ?Distances = null,

    alctr: std.mem.Allocator,
    prng: *std.rand.DefaultPrng,

    pub const CellT = UpsilonCell;

    pub fn init(alctr: std.mem.Allocator, seed: u64, w: u32, h: u32) !UpsilonGrid {
        var g = UpsilonGrid{
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

    pub fn deinit(self: *UpsilonGrid) void {
        self.alctr.free(self.cells_buf);
        self.alctr.destroy(self.prng);
        if (self.distances) |*d| d.deinit();
    }

    fn prepareGrid(self: *UpsilonGrid) !void {
        self.cells_buf = try self.alctr.alloc(UpsilonCell, self.width * self.height);
        for (self.cells_buf, 0..) |*cell, i| {
            var x = @as(u32, @intCast(i % self.width));
            var y = @as(u32, @intCast(@divTrunc(i, self.width)));
            cell.* = UpsilonCell.init(self, x, y);
        }
    }

    fn configureCells(self: *UpsilonGrid) void {
        for (self.cells_buf) |*cell| {
            // underflow on 0 will be handled by .at(...)
            if (cell.isOctogon()) {
                cell.neighbors_buf[1] = self.at(cell.x() + 1, cell.y() -% 1);
                cell.neighbors_buf[3] = self.at(cell.x() + 1, cell.y() + 1);
                cell.neighbors_buf[5] = self.at(cell.x() -% 1, cell.y() + 1);
                cell.neighbors_buf[7] = self.at(cell.x() -% 1, cell.y() -% 1);
            }

            cell.neighbors_buf[0] = self.at(cell.x(), cell.y() -% 1);
            cell.neighbors_buf[2] = self.at(cell.x() + 1, cell.y());
            cell.neighbors_buf[4] = self.at(cell.x(), cell.y() + 1);
            cell.neighbors_buf[6] = self.at(cell.x() -% 1, cell.y());
        }
    }

    /// return cell at given coordinates. null if it doesn't exist.
    pub fn at(self: *UpsilonGrid, x: u32, y: u32) ?*UpsilonCell {
        if (x < 0) return null;
        if (x >= self.width) return null;
        if (y < 0) return null;
        if (y >= self.height) return null;
        return &self.cells_buf[y * self.width + x];
    }

    pub fn pickRandom(self: UpsilonGrid) *UpsilonCell {
        const i = self.prng.random().intRangeLessThan(usize, 0, self.size());
        return &self.cells_buf[i];
    }

    /// return a list of every cell that is only connected to one other cell.
    /// caller should free the returned list.
    pub fn deadends(self: *UpsilonGrid) ![]*UpsilonCell {
        var list = std.ArrayList(*UpsilonCell).init(self.alctr);
        defer list.deinit();

        for (self.cells_buf) |*cell| {
            if (cell.numLinks() == 1) {
                try list.append(cell);
            }
        }

        return list.toOwnedSlice();
    }

    pub fn braid(self: *UpsilonGrid, p: f64) !void {
        var ddends = try self.deadends();
        defer self.alctr.free(ddends);

        self.prng.random().shuffle(*UpsilonCell, ddends);

        for (ddends) |cell| {
            const pick = self.prng.random().float(f64);
            if (pick > p or cell.numLinks() != 1) continue;

            // filter out already linked
            var unlinked_buf = [_]?*UpsilonCell{null} ** 4;
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
            var best_buf = [_]?*UpsilonCell{null} ** 4;
            var blen: usize = 0;
            for (unlinked) |unei| {
                if (unei.?.numLinks() == 1) {
                    best_buf[blen] = unei;
                    blen += 1;
                }
            }
            var best = best_buf[0..blen];

            var pool: *[]?*UpsilonCell = if (best.len > 0) &best else &unlinked;

            var choice_i = self.prng.random().intRangeLessThan(usize, 0, pool.len);
            var choice = pool.*[choice_i];
            try cell.bLink(choice.?);
        }
    }

    pub fn size(self: UpsilonGrid) usize {
        return self.width *| self.height;
    }
};

fn getCoords(cell: UpsilonCell, border_size: f64, cell_width: f64) struct {
    x: f64,
    x2: f64,
    x3: f64,
    x4: f64,
    y: f64,
    y2: f64,
    y3: f64,
    y4: f64,

    ux: u32,
    ux2: u32,
    ux3: u32,
    ux4: u32,
    uy: u32,
    uy2: u32,
    uy3: u32,
    uy4: u32,
} {
    const x: f64 = @as(f64, @floatFromInt(cell.x())) * cell_width * 2 + border_size;
    const x2 = x + cell_width;
    const x3 = x + cell_width * 2;
    const x4 = x + cell_width * 3;
    const y: f64 = @as(f64, @floatFromInt(cell.y())) * cell_width * 2 + border_size;
    const y2 = y + cell_width;
    const y3 = y + cell_width * 2;
    const y4 = y + cell_width * 3;
    return .{
        .x = x,
        .x2 = x2,
        .x3 = x3,
        .x4 = x4,
        .y = y,
        .y2 = y2,
        .y3 = y3,
        .y4 = y4,

        .ux = @as(u32, @intFromFloat(x)),
        .ux2 = @as(u32, @intFromFloat(x2)),
        .ux3 = @as(u32, @intFromFloat(x3)),
        .ux4 = @as(u32, @intFromFloat(x4)),
        .uy = @as(u32, @intFromFloat(y)),
        .uy2 = @as(u32, @intFromFloat(y2)),
        .uy3 = @as(u32, @intFromFloat(y3)),
        .uy4 = @as(u32, @intFromFloat(y4)),
    };
}

pub fn makeQanvas(grid: UpsilonGrid, walls: bool, scale: usize) !qan.Qanvas {
    // the basic tile is this:
    //   ____
    //  /    \ _
    // │      │_|
    //  \____/
    //
    // cell with is the width of the little sqaure

    const cell_width: f64 = @floatFromInt(scale);
    const border_size: f64 = cell_width;
    const img_width = @as(u32, @intFromFloat((cell_width * 2 * @as(f64, @floatFromInt(grid.width))) + (border_size * 3)));
    const img_height = @as(u32, @intFromFloat((cell_width * 2 * @as(f64, @floatFromInt(grid.height))) + (border_size * 3)));

    var qanv = try qan.Qanvas.init(grid.alctr, img_width, img_height);

    // colors
    const background_color: qoi.Qixel(qoi.RGB) = .{ .colors = .{ .red = 10, .green = 10, .blue = 15 } }; // black
    const wall_color: qoi.Qixel(qoi.RGB) = .{ .colors = .{ .red = 45, .green = 40, .blue = 40 } }; // grey

    qanv.clear(background_color);

    if (grid.distances) |dists| {
        const max_dist = dists.max().distance;

        const hue: f32 = @floatFromInt(grid.prng.random().intRangeLessThan(u16, 0, 360));
        const path_low = qoi.Qixel(qoi.HSV){ .colors = .{ .hue = hue, .saturation = 0.55, .value = 0.65 }, .alpha = 255 };
        const path_hi = qoi.Qixel(qoi.HSV){ .colors = .{ .hue = @mod(hue + @as(f32, @floatFromInt(grid.prng.random().intRangeLessThan(u16, 60, 180))), 360), .saturation = 0.65, .value = 0.20 }, .alpha = 255 };

        for (grid.cells_buf) |*cell| {
            const xy = getCoords(cell.*, border_size, cell_width);
            const cell_dist = dists.get(cell).?;
            const non_eased_color_t = @as(f64, @floatFromInt(cell_dist)) / @as(f64, @floatFromInt(max_dist));
            const color_t = -(std.math.cos(std.math.pi * non_eased_color_t) - 1) / 2;
            const color = path_low.lerp(path_hi, color_t).to(qoi.RGB);

            if (cell.isOctogon()) {
                { // top trapezoid
                    var line: u32 = 0;
                    while (line < @as(u32, @intFromFloat(cell_width))) : (line += 1) {
                        const t = @as(f64, @floatFromInt(line)) / cell_width;
                        const left = @as(u32, @intFromFloat(u.lerp(xy.x2, xy.x, t)));
                        const right = @as(u32, @intFromFloat(u.lerp(xy.x3, xy.x4, t)));
                        const y = xy.uy + line;
                        try qanv.line(color, left, right, y, y);
                    }
                }
                { // middle block
                    try qanv.fill(color, xy.ux, xy.ux4, xy.uy2, xy.uy3);
                }
                { // bottom trapezoid
                    var line: u32 = 0;
                    while (line < @as(u32, @intFromFloat(cell_width))) : (line += 1) {
                        const t = @as(f64, @floatFromInt(line)) / cell_width;
                        const left = @as(u32, @intFromFloat(u.lerp(xy.x, xy.x2, t)));
                        const right = @as(u32, @intFromFloat(u.lerp(xy.x4, xy.x3, t)));
                        const y = xy.uy3 + line;
                        try qanv.line(color, left, right, y, y);
                    }
                }
            } else {
                try qanv.fill(color, xy.ux2, xy.ux3, xy.uy2, xy.uy3);
            }
        }
    }

    // walls
    if (walls) {
        for (grid.cells_buf) |*cell| {
            const cc = getCoords(cell.*, border_size, cell_width);
            const wallBetween = struct {
                fn f(from: *UpsilonCell, to: ?*UpsilonCell) bool {
                    return to == null or !from.isLinked(to.?);
                }
            }.f;

            // XXX this draws every wall twice...

            if (cell.isOctogon()) {
                if (wallBetween(cell, cell.north()))
                    try qanv.line(wall_color, cc.ux2, cc.ux3, cc.uy, cc.uy);
                if (wallBetween(cell, cell.northWest()))
                    try qanv.line(wall_color, cc.ux, cc.ux2, cc.uy2, cc.uy);
                if (wallBetween(cell, cell.west()))
                    try qanv.line(wall_color, cc.ux, cc.ux, cc.uy2, cc.uy3);
                if (wallBetween(cell, cell.southWest()))
                    try qanv.line(wall_color, cc.ux, cc.ux2, cc.uy3, cc.uy4);
                if (wallBetween(cell, cell.south()))
                    try qanv.line(wall_color, cc.ux2, cc.ux3, cc.uy4, cc.uy4);
                if (wallBetween(cell, cell.southEast()))
                    try qanv.line(wall_color, cc.ux3, cc.ux4, cc.uy4, cc.uy3);
                if (wallBetween(cell, cell.east()))
                    try qanv.line(wall_color, cc.ux4, cc.ux4, cc.uy2, cc.uy3);
                if (wallBetween(cell, cell.northEast()))
                    try qanv.line(wall_color, cc.ux3, cc.ux4, cc.uy, cc.uy2);
            } else {
                if (wallBetween(cell, cell.north()))
                    try qanv.line(wall_color, cc.ux2, cc.ux3, cc.uy2, cc.uy2);
                if (wallBetween(cell, cell.south()))
                    try qanv.line(wall_color, cc.ux2, cc.ux3, cc.uy3, cc.uy3);
                if (wallBetween(cell, cell.east()))
                    try qanv.line(wall_color, cc.ux3, cc.ux3, cc.uy2, cc.uy3);
                if (wallBetween(cell, cell.west()))
                    try qanv.line(wall_color, cc.ux2, cc.ux2, cc.uy2, cc.uy3);
            }
        }
    }

    return qanv;
}
