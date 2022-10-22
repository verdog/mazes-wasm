//! triangular grid and triangular cell for constructing mazes

const std = @import("std");
const qoi = @import("qoi.zig");
const qan = @import("qanvas.zig");
const u = @import("u.zig");

pub const Distances = @import("distances.zig").Distances(TriGrid);

pub const Error = error{
    TriGridError,
};

pub const TriCell = struct {
    pub fn init(alctr: std.mem.Allocator, prng: *std.rand.DefaultPrng, x: u32, y: u32) TriCell {
        return TriCell{
            .alctr = alctr,
            .prng = prng,
            .x = x,
            .y = y,
        };
    }

    pub fn deinit(self: TriCell) void {
        _ = self;
    }

    fn isUpright(self: TriCell) bool {
        return (self.x + self.y) & 1 == 0;
    }

    pub fn north(self: TriCell) ?*TriCell {
        return if (!self.isUpright()) self.neighbors_buf[0] else null;
    }

    pub fn south(self: TriCell) ?*TriCell {
        return if (self.isUpright()) self.neighbors_buf[0] else null;
    }

    pub fn east(self: TriCell) ?*TriCell {
        return self.neighbors_buf[1];
    }

    pub fn west(self: TriCell) ?*TriCell {
        return self.neighbors_buf[2];
    }

    fn getNeighbors(self: TriCell, require_linked: bool) [3]?*TriCell {
        var result = [_]?*TriCell{null} ** 3;
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

    pub fn neighbors(self: TriCell) [3]?*TriCell {
        return self.getNeighbors(false);
    }

    pub fn randomNeighbor(self: TriCell) ?*TriCell {
        const my_neighbors = self.neighbors();
        const count = blk: {
            var c: usize = 0;
            for (my_neighbors) |maybe_nei| {
                if (maybe_nei != null) c += 1;
            }
            break :blk c;
        };
        const choice = self.prng.random().intRangeLessThan(usize, 0, count);
        return my_neighbors[choice];
    }

    /// return a random cell from this cell's neighbors that hasn't been linked yet
    pub fn randomNeighborUnlinked(self: TriCell) ?*TriCell {
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
            const choice = self.prng.random().intRangeLessThan(usize, 0, write);
            break :blk my_neighbors[choice];
        };
    }

    fn whichNeighbor(self: TriCell, other: TriCell) ?u8 {
        if (self.y == other.y) {
            switch (@intCast(i64, other.x) - @intCast(i64, self.x)) {
                1 => return 1,
                -1 => return 2,
                else => return null,
            }
        } else if (self.x == other.x) {
            switch (@intCast(i64, other.y) - @intCast(i64, self.y)) {
                1 => return if (self.isUpright()) 0 else null,
                -1 => return if (!self.isUpright()) 0 else null,
                else => return null,
            }
        }
        return null;
    }

    /// return list of this cell's neighbors. they *do* need to be linked.
    /// the returned neighbors will be packed into the front of the array.
    pub fn links(self: TriCell) [3]?*TriCell {
        return self.getNeighbors(true);
    }

    pub fn randomLink(self: TriCell) ?*TriCell {
        // XXX: Assumes the maximum amount of links a cell can have is 3
        const max_links = 3;
        var actual_links: u8 = 0;
        var potential_links = [_]?*TriCell{null} ** max_links;

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

    pub fn numLinks(self: TriCell) usize {
        var count: usize = 0;
        for (self.linked) |b| {
            if (b) count += 1;
        }
        return count;
    }

    /// bidirectional link.
    /// self <---> other.
    pub fn bLink(self: *TriCell, other: *TriCell) !void {
        try self.mLink(other);
        try other.mLink(self);
    }

    // monodirectional link.
    // self ----> other.
    // self and other must be adjacent.
    pub fn mLink(self: *TriCell, other: *TriCell) !void {
        if (self.whichNeighbor(other.*)) |idx| {
            self.neighbors_buf[idx] = other;
            self.linked[idx] = true;
            return;
        }
        return Error.TriGridError;
    }

    /// bidirectional unlink.
    pub fn unLink(self: *TriCell, other: *TriCell) void {
        self.mUnLink(other);
        other.mUnLink(self);
    }

    fn mUnLink(self: *TriCell, other: *TriCell) void {
        if (self.whichNeighbor(other.*)) |idx| {
            // unLink doesn't change neighbors
            self.linked[idx] = false;
        }
        // no-ops are fine
    }

    /// return true is `self` is linked to `other`
    pub fn isLinked(self: TriCell, other: *TriCell) bool {
        if (self.whichNeighbor(other.*)) |idx| {
            return self.linked[idx];
        }
        return false;
    }

    /// certain indices hold certain neighbors:
    ///
    /// 0: north or south   / \   \--0--/
    /// 1: east            /2 1\   \2 1/
    /// 2: west           /__0__\   \ /
    neighbors_buf: [3]?*TriCell = [_]?*TriCell{null} ** 3,
    /// maps to neighbors in neighbors_buf
    linked: [3]bool = [_]bool{false} ** 3,

    alctr: std.mem.Allocator,
    prng: *std.rand.DefaultPrng,
    x: u32,
    y: u32,
    weight: u32 = 1,
};

pub const TriGrid = struct {
    width: u32,
    height: u32,
    cells_buf: []TriCell = undefined,
    distances: ?Distances = null,

    alctr: std.mem.Allocator,
    prng: *std.rand.DefaultPrng,

    pub const CellT = TriCell;

    pub fn init(alctr: std.mem.Allocator, seed: u64, w: u32, h: u32) !TriGrid {
        var g = TriGrid{
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

    pub fn deinit(self: *TriGrid) void {
        self.alctr.free(self.cells_buf);
        self.alctr.destroy(self.prng);
        if (self.distances) |*d| d.deinit();
    }

    fn prepareGrid(self: *TriGrid) !void {
        self.cells_buf = try self.alctr.alloc(TriCell, self.width * self.height);
        for (self.cells_buf) |*cell, i| {
            var x = @intCast(u32, i % self.width);
            var y = @intCast(u32, @divTrunc(i, self.width));
            cell.* = TriCell.init(self.alctr, self.prng, x, y);
        }
    }

    fn configureCells(self: *TriGrid) void {
        for (self.cells_buf) |*cell| {
            // underflow on 0 will be handled by .at(...)
            if (cell.isUpright()) {
                cell.neighbors_buf[0] = self.at(cell.x, cell.y + 1);
            } else {
                cell.neighbors_buf[0] = self.at(cell.x, cell.y -% 1);
            }

            cell.neighbors_buf[1] = self.at(cell.x + 1, cell.y);
            cell.neighbors_buf[2] = self.at(cell.x -% 1, cell.y);
        }
    }

    /// return cell at given coordinates. null if it doesn't exist.
    pub fn at(self: *TriGrid, x: u32, y: u32) ?*TriCell {
        if (x < 0) return null;
        if (x >= self.width) return null;
        if (y < 0) return null;
        if (y >= self.height) return null;
        return &self.cells_buf[y * self.width + x];
    }

    pub fn pickRandom(self: TriGrid) *TriCell {
        const i = self.prng.random().intRangeLessThan(usize, 0, self.size());
        return &self.cells_buf[i];
    }

    pub fn deadends(self: *TriGrid) ![]*TriCell {
        var list = std.ArrayList(*TriCell).init(self.alctr);
        defer list.deinit();

        for (self.cells_buf) |*cell| {
            if (cell.numLinks() == 1) {
                try list.append(cell);
            }
        }

        return list.toOwnedSlice();
    }

    pub fn braid(self: *TriGrid, p: f64) !void {
        var ddends = try self.deadends();
        defer self.alctr.free(ddends);

        self.prng.random().shuffle(*TriCell, ddends);

        for (ddends) |cell| {
            const pick = self.prng.random().float(f64);
            if (pick > p or cell.numLinks() != 1) continue;

            // filter out already linked
            var unlinked_buf = [_]?*TriCell{null} ** 4;
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

            // tricells can end up with only one neighbor in corners.
            // when it's linked and filtered out above, unlinked has no cells
            if (ulen == 0) continue;

            // prefer linked two dead ends together. it looks nice
            var best_buf = [_]?*TriCell{null} ** 4;
            var blen: usize = 0;
            for (unlinked) |unei| {
                if (unei.?.numLinks() == 1) {
                    best_buf[blen] = unei;
                    blen += 1;
                }
            }
            var best = best_buf[0..blen];

            var pool: *[]?*TriCell = if (best.len > 0) &best else &unlinked;

            var choice_i = self.prng.random().intRangeLessThan(usize, 0, pool.len);
            var choice = pool.*[choice_i];
            try cell.bLink(choice.?);
        }
    }

    pub fn size(self: TriGrid) usize {
        return self.width *| self.height;
    }
};

fn getCoords(cell: TriCell, border_size: u32, tri_width: f64, tri_height: f64) struct { x_center: u32, y_center: u32, x_west: u32, x_east: u32, y_apex: u32, y_base: u32 } {
    const x_center = border_size + @floatToInt(u32, tri_width / 2.0) + cell.x * @floatToInt(u32, tri_width / 2.0);
    const y_center = border_size + @floatToInt(u32, tri_height / 2.0) + cell.y * @floatToInt(u32, tri_height);
    const x_west = x_center - @floatToInt(u32, tri_width / 2.0);
    const x_east = x_center + @floatToInt(u32, tri_width / 2.0);
    return .{
        .x_center = x_center,
        .y_center = y_center,
        .x_west = x_west,
        .x_east = x_east,

        .y_apex = if (cell.isUpright())
            y_center - @floatToInt(u32, tri_height / 2.0)
        else
            y_center + @floatToInt(u32, tri_height / 2.0),

        .y_base = if (cell.isUpright())
            y_center + @floatToInt(u32, tri_height / 2.0)
        else
            y_center - @floatToInt(u32, tri_height / 2.0),
    };
}

pub fn makeQanvas(grid: TriGrid, walls: bool, scale: usize) !qan.Qanvas {
    const tri_width = @intToFloat(f64, scale); // length of side
    const tri_height = tri_width * @sqrt(3.0) / 2.0;

    const border_size = @floatToInt(u32, tri_width / 2);
    const img_width: u32 = @floatToInt(u32, tri_width / 2.0) * (1 + grid.width) + border_size * 2;
    const img_height: u32 = @floatToInt(u32, tri_height) * grid.height + border_size * 2;

    var qanv = try qan.Qanvas.init(grid.alctr, img_width, img_height);

    // colors
    const background_color: qoi.Qixel(qoi.RGB) = .{ .colors = .{ .red = 10, .green = 10, .blue = 15 } }; // black
    const wall_color: qoi.Qixel(qoi.RGB) = .{ .colors = .{ .red = 45, .green = 40, .blue = 40 } }; // grey

    qanv.clear(background_color);

    // backgrounds
    if (grid.distances) |dists| {
        const max_dist = dists.max().distance;

        const hue = @intToFloat(f32, grid.prng.random().intRangeLessThan(u16, 0, 360));
        const path_low = qoi.Qixel(qoi.HSV){ .colors = .{ .hue = hue, .saturation = 0.55, .value = 0.65 }, .alpha = 255 };
        const path_hi = qoi.Qixel(qoi.HSV){ .colors = .{ .hue = @mod(hue + @intToFloat(f32, grid.prng.random().intRangeLessThan(u16, 60, 180)), 360), .saturation = 0.65, .value = 0.20 }, .alpha = 255 };

        for (grid.cells_buf) |*cell| {
            const xy = getCoords(cell.*, border_size, tri_width, tri_height);

            if (dists.get(cell)) |cell_dist| {
                const non_eased_color_t = @intToFloat(f64, cell_dist) / @intToFloat(f64, max_dist);
                const color_t = -(std.math.cos(std.math.pi * non_eased_color_t) - 1) / 2;
                const color = path_low.lerp(path_hi, color_t).to(qoi.RGB);
                var line: u32 = 0;
                while (line < @floatToInt(u32, tri_height)) : (line += 1) {
                    const line_t = @intToFloat(f64, line) / tri_height;
                    const fx_west = @intToFloat(f64, xy.x_west);
                    const fx_center = @intToFloat(f64, xy.x_center);
                    const fx_east = @intToFloat(f64, xy.x_east);

                    const x1 = if (cell.isUpright())
                        @floatToInt(u32, u.lerp(fx_center, fx_west, line_t) + 0.5)
                    else
                        @floatToInt(u32, u.lerp(fx_west, fx_center, line_t) + 0.5);

                    const x2 = if (cell.isUpright())
                        @floatToInt(u32, u.lerp(fx_center, fx_east, line_t) + 0.5)
                    else
                        @floatToInt(u32, u.lerp(fx_east, fx_center, line_t) + 0.5);

                    const y = std.math.min(xy.y_apex, xy.y_base) + line;

                    try qanv.line(color, x1, x2, y, y);
                }
            }
        }
    }

    // walls
    if (walls) {
        for (grid.cells_buf) |*cell| {
            const xy = getCoords(cell.*, border_size, tri_width, tri_height);

            if (cell.west() == null)
                try qanv.line(wall_color, xy.x_west, xy.x_center, xy.y_base, xy.y_apex);

            if (cell.east() == null or !cell.isLinked(cell.east().?))
                try qanv.line(wall_color, xy.x_center, xy.x_east, xy.y_apex, xy.y_base);

            if ((cell.isUpright() and (cell.south() == null or !cell.isLinked(cell.south().?))) or (!cell.isUpright() and (cell.north() == null or !cell.isLinked(cell.north().?))))
                try qanv.line(wall_color, xy.x_west, xy.x_east, xy.y_base, xy.y_base);
        }
    }

    return qanv;
}
