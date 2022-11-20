//! hexagonal grid and hexagonal cell for constructing mazes

const std = @import("std");
const qoi = @import("qoi.zig");
const qan = @import("qanvas.zig");
const u = @import("u.zig");

const Distances = @import("distances.zig").Distances;

pub const Error = error{
    HexCellError,
};

pub const HexCell = struct {
    pub fn init(grid: *HexGrid, xx: u32, yy: u32) HexCell {
        return HexCell{
            .alctr = grid.alctr,
            .prng = grid.prng,
            ._x = xx,
            ._y = yy,
        };
    }

    pub fn deinit(self: HexCell) void {
        // TODO: is this function needed?
        _ = self;
    }

    // TODO inline these?

    pub fn north(self: HexCell) ?*HexCell {
        return self.neighbors_buf[0];
    }

    pub fn northeast(self: HexCell) ?*HexCell {
        return self.neighbors_buf[1];
    }

    pub fn southeast(self: HexCell) ?*HexCell {
        return self.neighbors_buf[2];
    }

    pub fn south(self: HexCell) ?*HexCell {
        return self.neighbors_buf[3];
    }

    pub fn southwest(self: HexCell) ?*HexCell {
        return self.neighbors_buf[4];
    }

    pub fn northwest(self: HexCell) ?*HexCell {
        return self.neighbors_buf[5];
    }

    fn getNeighbors(self: HexCell, require_linked: bool) [6]?*HexCell {
        var result = [_]?*HexCell{null} ** 6;
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

    /// returns in which index `other` should reside in `self`'s neighbor/linked
    /// arrays, if the cells are adjacent. null otherwise.
    fn whichNeighbor(self: HexCell, other: HexCell) ?u8 {
        if (self.x() == other.x()) {
            // vertical neighbors?
            if (self.y() + 1 == other.y()) {
                // south
                return 3;
            } else if (self.y() == other.y() + 1) {
                // north
                return 0;
            } else {
                // too far apart in y
                return null;
            }
        } else if (self.x() + 1 == other.x()) {
            // easterly neighbors?
            if (self.x() & 1 == 0) {
                // even x coord
                if (self.y() == other.y() + 1) {
                    // north east
                    return 1;
                } else if (self.y() == other.y()) {
                    // south east
                    return 2;
                } else {
                    // too far apart in y
                    return null;
                }
            } else {
                // odd x coord
                if (self.y() == other.y()) {
                    // north east
                    return 1;
                } else if (self.y() + 1 == other.y()) {
                    // south east
                    return 2;
                } else {
                    // too far apart in y
                    return null;
                }
            }
        } else if (self.x() == other.x() + 1) {
            // westerly neighbors?
            if (self.x() & 1 == 0) {
                // even x coord
                if (self.y() == other.y() + 1) {
                    // north west
                    return 5;
                } else if (self.y() == other.y()) {
                    // south west
                    return 4;
                } else {
                    // too far apart in y
                    return null;
                }
            } else {
                // odd x coord
                if (self.y() == other.y()) {
                    // north west
                    return 5;
                } else if (self.y() + 1 == other.y()) { // south west
                    return 4;
                } else {
                    // too far apart in y
                    return null;
                }
            }
        } else {
            // not close enough
            return null;
        }
    }

    /// return list of this cell's neighbors. they don't need to be linked.
    /// the returned neighbors will be packed into the front of the array.
    pub fn neighbors(self: HexCell) [6]?*HexCell {
        return self.getNeighbors(false);
    }

    pub fn randomNeighbor(self: HexCell) ?*HexCell {
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

    pub fn randomNeighborLinked(self: HexCell) ?*HexCell {
        var my_neighbors = self.neighbors();

        // reduce to only those that are not linked
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
            const choice = self.prng.random().intRangeLessThan(usize, 0, write);
            break :blk my_neighbors[choice];
        };
    }

    /// return a random cell from this cell's neighbors that hasn't been linked yet
    pub fn randomNeighborUnlinked(self: HexCell) ?*HexCell {
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

    /// return list of this cell's neighbors. they do need to be linked.
    /// the returned neighbors will be packed into the front of the array.
    pub fn links(self: HexCell) [6]?*HexCell {
        return self.getNeighbors(true);
    }

    pub fn randomLink(self: HexCell) ?*HexCell {
        // XXX: Assumes the maximum amount of links a cell can have is 6
        const max_links = 6;
        var actual_links: u8 = 0;
        var potential_links = [_]?*HexCell{null} ** max_links;

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

    pub fn numLinks(self: HexCell) usize {
        var count: usize = 0;
        for (self.linked) |b| {
            if (b) count += 1;
        }
        return count;
    }

    /// bidirectional link.
    /// self <---> other.
    pub fn bLink(self: *HexCell, other: *HexCell) !void {
        try self.mLink(other);
        try other.mLink(self);
    }

    // monodirectional link.
    // self ----> other.
    // self and other must be adjacent.
    pub fn mLink(self: *HexCell, other: *HexCell) !void {
        if (self.whichNeighbor(other.*)) |idx| {
            self.neighbors_buf[idx] = other;
            self.linked[idx] = true;
            return;
        }
        return Error.HexCellError;
    }

    /// bidirectional unlink.
    pub fn unLink(self: *HexCell, other: *HexCell) void {
        self.mUnLink(other);
        other.mUnLink(self);
    }

    fn mUnLink(self: *HexCell, other: *HexCell) void {
        if (self.whichNeighbor(other.*)) |idx| {
            // unLink doesn't change neighbors
            self.linked[idx] = false;
        }
        // no-ops are fine
    }

    /// return true is `self` is linked to `other`
    pub fn isLinked(self: HexCell, other: *HexCell) bool {
        if (self.whichNeighbor(other.*)) |idx| {
            return self.linked[idx];
        }
        return false;
    }

    pub fn x(self: HexCell) u32 {
        return self._x;
    }

    pub fn y(self: HexCell) u32 {
        return self._y;
    }

    pub fn weight(self: HexCell) u32 {
        return self._weight;
    }

    /// certain indices hold certain neighbors:
    ///                          _________
    /// 0: north                /    0    \
    /// 1: northeast           /5         1\
    /// 2: southeast          /             \
    /// 3: south              \             /
    /// 4: southwest           \4         2/
    /// 5: northwest            \____3____/
    neighbors_buf: [neighbors_len]?*HexCell = [_]?*HexCell{null} ** neighbors_len,
    // `linked[i]` is true if this cell is linked to `neighbors[i]`
    linked: [neighbors_len]bool = [_]bool{false} ** neighbors_len,

    alctr: std.mem.Allocator,
    prng: *std.rand.DefaultPrng,
    _x: u32,
    _y: u32,
    _weight: u32 = 1,

    pub const neighbors_len = 6;
};

pub const HexGrid = struct {
    width: u32,
    height: u32,
    cells_buf: []HexCell = undefined,
    distances: ?Distances(HexGrid) = null,

    alctr: std.mem.Allocator,
    prng: *std.rand.DefaultPrng,

    pub const CellT = HexCell;

    pub fn init(alctr: std.mem.Allocator, seed: u64, w: u32, h: u32) !HexGrid {
        var g = HexGrid{
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

    pub fn deinit(self: *HexGrid) void {
        self.alctr.free(self.cells_buf);
        self.alctr.destroy(self.prng);
        if (self.distances) |*d| d.deinit();
    }

    fn prepareGrid(self: *HexGrid) !void {
        self.cells_buf = try self.alctr.alloc(HexCell, self.width * self.height);
        for (self.cells_buf) |*cell, i| {
            var x = @intCast(u32, i % self.width);
            var y = @intCast(u32, @divTrunc(i, self.width));
            cell.* = HexCell.init(self, x, y);
        }
    }

    fn configureCells(self: *HexGrid) void {
        for (self.cells_buf) |*cell| {
            // underflow on 0 will be handled by .at(...)
            const north_diag_y = if (cell.x() & 1 == 0) cell.y() -% 1 else cell.y();
            const south_diag_y = if (cell.x() & 1 == 0) cell.y() else cell.y() + 1;

            cell.neighbors_buf[0] = self.at(cell.x(), cell.y() -% 1);
            cell.neighbors_buf[1] = self.at(cell.x() + 1, north_diag_y);
            cell.neighbors_buf[2] = self.at(cell.x() + 1, south_diag_y);
            cell.neighbors_buf[3] = self.at(cell.x(), cell.y() + 1);
            cell.neighbors_buf[4] = self.at(cell.x() -% 1, south_diag_y);
            cell.neighbors_buf[5] = self.at(cell.x() -% 1, north_diag_y);
        }
    }

    pub fn size(self: HexGrid) usize {
        return self.width *| self.height;
    }

    /// return cell at given coordinates. null if it doesn't exist.
    pub fn at(self: *HexGrid, x: u32, y: u32) ?*HexCell {
        if (x < 0) return null;
        if (x >= self.width) return null;
        if (y < 0) return null;
        if (y >= self.height) return null;
        return &self.cells_buf[y * self.width + x];
    }

    pub fn pickRandom(self: HexGrid) *HexCell {
        const i = self.prng.random().intRangeLessThan(usize, 0, self.size());
        return &self.cells_buf[i];
    }

    pub fn deadends(self: *HexGrid) ![]*HexCell {
        var list = std.ArrayList(*HexCell).init(self.alctr);
        defer list.deinit();

        for (self.cells_buf) |*cell| {
            if (cell.numLinks() == 1) {
                try list.append(cell);
            }
        }

        return list.toOwnedSlice();
    }

    pub fn braid(self: *HexGrid, p: f64) !void {
        var ddends = try self.deadends();
        defer self.alctr.free(ddends);

        self.prng.random().shuffle(*HexCell, ddends);

        for (ddends) |cell| {
            const pick = self.prng.random().float(f64);
            if (pick > p or cell.numLinks() != 1) continue;

            // filter out already linked
            var unlinked_buf = [_]?*HexCell{null} ** 4;
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
            var best_buf = [_]?*HexCell{null} ** 4;
            var blen: usize = 0;
            for (unlinked) |unei| {
                if (unei.?.numLinks() == 1) {
                    best_buf[blen] = unei;
                    blen += 1;
                }
            }
            var best = best_buf[0..blen];

            var pool: *[]?*HexCell = if (best.len > 0) &best else &unlinked;

            var choice_i = self.prng.random().intRangeLessThan(usize, 0, pool.len);
            var choice = pool.*[choice_i];
            try cell.bLink(choice.?);
        }
    }
};

pub fn makeQanvas(grid: HexGrid, walls: bool, scale: usize) !qan.Qanvas {
    const cell_size = @intCast(u32, scale); // radius
    const fcell_size = @intToFloat(f64, cell_size);
    const b_size = fcell_size * @sqrt(3.0) / 2.0; // height from center
    const ib_size = @floatToInt(u32, b_size);

    const border_size = cell_size;

    const width: u32 = (grid.width * cell_size / 2 * 3) + (cell_size / 2) + (2 * border_size) + 1;
    const height: u32 = (grid.height * 2 * ib_size) + ib_size + (2 * border_size) + 1;

    var qanv = try qan.Qanvas.init(grid.alctr, width, height);

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
            const x_center = border_size + (cell_size) + (3 * cell.x() * cell_size / 2);
            var y_center = border_size + ib_size + (cell.y() * ib_size * 2);
            if (cell.x() & 1 == 1) y_center += ib_size;

            const x_far_west = x_center - cell_size;
            const x_near_west = x_center - cell_size / 2;
            const x_near_east = x_center + cell_size / 2;
            const x_far_east = x_center + cell_size;

            const y_north = @floatToInt(u32, @intToFloat(f64, y_center) - b_size);
            const y_south = @floatToInt(u32, @intToFloat(f64, y_center) + b_size);

            if (dists.get(cell)) |cell_dist| {
                const color = path_low.lerp(path_hi, @intToFloat(f64, cell_dist) / @intToFloat(f64, max_dist)).to(qoi.RGB);

                { // top trapezoid
                    const lines = y_center - y_north - 1;
                    var j: u32 = 0;
                    while (j < lines) : (j += 1) {
                        const t = @intToFloat(f64, j) / @intToFloat(f64, lines);
                        const fx_far_west = @intToFloat(f64, x_far_west);
                        const fx_near_west = @intToFloat(f64, x_near_west);
                        const fx_near_east = @intToFloat(f64, x_near_east);
                        const fx_far_east = @intToFloat(f64, x_far_east);

                        const x1 = @floatToInt(u32, u.lerp(fx_near_west, fx_far_west, t));
                        const x2 = @floatToInt(u32, u.lerp(fx_near_east, fx_far_east, t) + 1);

                        try qanv.line(color, x1, x2, y_north + j + 1, y_north + j + 1);
                    }
                }

                { // bottom trapezoid
                    const lines = y_south - y_center;
                    var j: u32 = 0;
                    while (j < lines) : (j += 1) {
                        const t = @intToFloat(f64, j) / @intToFloat(f64, lines);
                        const fx_far_west = @intToFloat(f64, x_far_west);
                        const fx_near_west = @intToFloat(f64, x_near_west);
                        const fx_near_east = @intToFloat(f64, x_near_east);
                        const fx_far_east = @intToFloat(f64, x_far_east);

                        const x1 = @floatToInt(u32, u.lerp(fx_far_west, fx_near_west, t));
                        const x2 = @floatToInt(u32, u.lerp(fx_far_east, fx_near_east, t) + 1);

                        try qanv.line(color, x1, x2, y_center + j, y_center + j);
                    }
                }
            }
        }
    }

    // walls
    if (walls) {
        for (grid.cells_buf) |cell| {
            const x_center = border_size + (cell_size) + (3 * cell.x() * cell_size / 2);
            var y_center = border_size + ib_size + (cell.y() * ib_size * 2);
            if (cell.x() & 1 == 1) y_center += ib_size;

            const x_far_west = x_center - cell_size;
            const x_near_west = x_center - cell_size / 2;
            const x_near_east = x_center + cell_size / 2;
            const x_far_east = x_center + cell_size;

            const y_north = @floatToInt(u32, @intToFloat(f64, y_center) - b_size);
            const y_south = @floatToInt(u32, @intToFloat(f64, y_center) + b_size);
            if (walls) {
                if (cell.north() == null)
                    try qanv.line(wall_color, x_near_west, x_near_east, y_north, y_north);
                if (cell.northeast() == null)
                    try qanv.line(wall_color, x_near_east, x_far_east, y_north, y_center);
                if (cell.southeast() == null or !cell.isLinked(cell.southeast().?))
                    try qanv.line(wall_color, x_far_east, x_near_east, y_center, y_south);
                if (cell.south() == null or !cell.isLinked(cell.south().?))
                    try qanv.line(wall_color, x_near_east, x_near_west, y_south, y_south);
                if (cell.southwest() == null or !cell.isLinked(cell.southwest().?))
                    try qanv.line(wall_color, x_near_west, x_far_west, y_south, y_center);
                if (cell.northwest() == null)
                    try qanv.line(wall_color, x_far_west, x_near_west, y_center, y_north);
            }
        }
    }

    return qanv;
}

pub fn makeString(grid: *HexGrid) ![]u8 {
    // /   \___/   \___  -
    // \___/   \___/   \ |
    // /   \___/   \___/ -
    // \___/   \___/   \ |
    // /   \___/   \___/ -
    // \___/   \___/   \ |
    //     \___/   \___/ X Each cell is 2 characters tall, + 1 end character
    //
    // |---|---|---|---X Each cell is 4 characters wide, + 1 end character
    const width = grid.width * 4 + 2; // + last character + \n
    const height = grid.height * 2 + 1;
    var result = try grid.alctr.alloc(u8, width * height);

    var cursor: u32 = 0;
    while (cursor < result.len) {
        while (cursor % width < width - 2) {
            // for every 4 characters...

            // find what cell we're in
            const cursor_row = @divTrunc(cursor, width);
            const x = @divTrunc(cursor % width, 4);
            const y = blk: {
                var row = cursor_row;
                if (x & 1 == 1)
                    row += 1;
                var yy = @divTrunc(row, 2);
                if (x & 1 == 1)
                    yy -%= 1;
                break :blk yy;
            };

            const odd = (cursor_row & 1 == 0) != (x & 1 == 0);

            if (!odd) {
                var stamp = "    ".*;
                const mcell = grid.at(x, y);
                if (mcell) |cell| {
                    if (cell.northwest() == null or !cell.isLinked(cell.northwest().?))
                        stamp[0] = '/';
                } else if (cursor_row == height - 1 and x != 0) {
                    stamp[0] = '/';
                }

                {
                    const contents = "0123456789ABCDEF";
                    if (grid.distances) |dists| {
                        if (grid.at(x, y)) |cell| {
                            if (dists.get(cell)) |dist| {
                                stamp[1] = contents[dist % contents.len];
                            }
                        }
                    }
                }

                std.mem.copy(u8, result[cursor .. cursor + 4], &stamp);
            } else {
                var stamp = "    ".*;
                const mcell = grid.at(x, y);
                if (mcell) |cell| {
                    if (cell.southwest() == null or !cell.isLinked(cell.southwest().?))
                        stamp[0] = '\\';
                    if (cell.south() == null or !cell.isLinked(cell.south().?)) {
                        stamp[1] = '_';
                        stamp[2] = '_';
                        stamp[3] = '_';
                    }
                } else if (cursor_row == 0) {
                    stamp[0] = '\\';
                    stamp[1] = '_';
                    stamp[2] = '_';
                    stamp[3] = '_';
                }

                if (grid.at(x, y) != null or cursor_row == 0) {}

                std.mem.copy(u8, result[cursor .. cursor + 4], &stamp);
            }

            cursor += 4;
        }

        // finish row
        const x = @divTrunc(cursor % width, 4);
        const cursor_row = @divTrunc(cursor, width);
        const odd = (cursor_row & 1 == 0) != (x & 1 == 0);

        if (!odd) {
            result[cursor] = ' ';
            if (cursor_row != 0)
                result[cursor] = '/';
        } else {
            result[cursor] = ' ';
            if (cursor_row != height - 1)
                result[cursor] = '\\';
        }
        cursor += 1;
        result[cursor] = '\n';
        cursor += 1;
    }

    return result;
}

test "Construct hex cell" {
    var alloc = std.testing.allocator;
    var g = try HexGrid.init(alloc, 0, 2, 2);
    defer g.deinit();

    var c = HexCell.init(&g, 0, 0);
    defer c.deinit();
}

test "Hex cell link" {
    var alloc = std.testing.allocator;
    var g = try HexGrid.init(alloc, 0, 2, 2);
    defer g.deinit();

    var a = HexCell.init(&g, 1, 0);
    defer a.deinit();
    var b = HexCell.init(&g, 0, 0);
    defer b.deinit();

    try a.bLink(&b);

    try std.testing.expect(a.isLinked(&b) == true);
    try std.testing.expect(b.isLinked(&a) == true);
}

test "Hex cell link" {
    var alloc = std.testing.allocator;
    var gr = try HexGrid.init(alloc, 0, 4, 4);
    defer gr.deinit();

    //    0  1  2  3
    // 0 /  \__/  \__
    //   \__/b \__/  \
    // 1 /g \__/c \__/
    //   \__/a \__/h \
    // 2 /f \__/d \__/
    //   \__/e \__/  \
    //      \__/  \__/

    var a = HexCell.init(&gr, 1, 1);
    defer a.deinit();
    var b = HexCell.init(&gr, 1, 0);
    defer b.deinit();
    var c = HexCell.init(&gr, 2, 1);
    defer c.deinit();
    var d = HexCell.init(&gr, 2, 2);
    defer d.deinit();
    var e = HexCell.init(&gr, 1, 2);
    defer e.deinit();
    var f = HexCell.init(&gr, 0, 2);
    defer f.deinit();
    var g = HexCell.init(&gr, 0, 1);
    defer g.deinit();
    var h = HexCell.init(&gr, 3, 1);
    defer h.deinit();

    try a.bLink(&b);
    try a.bLink(&c);
    try a.bLink(&d);
    try a.bLink(&e);
    try a.bLink(&f);
    try a.bLink(&g);

    // h is not a neighbor
    try std.testing.expectError(Error.HexCellError, a.bLink(&h));

    try std.testing.expect(a.isLinked(&b));
    try std.testing.expect(b.isLinked(&a));
    try std.testing.expect(a.isLinked(&c));
    try std.testing.expect(c.isLinked(&a));
    try std.testing.expect(a.isLinked(&d));
    try std.testing.expect(d.isLinked(&a));
    try std.testing.expect(a.isLinked(&e));
    try std.testing.expect(e.isLinked(&a));
    try std.testing.expect(a.isLinked(&f));
    try std.testing.expect(f.isLinked(&a));
    try std.testing.expect(a.isLinked(&g));
    try std.testing.expect(g.isLinked(&a));

    try std.testing.expect(!a.isLinked(&h));
    try std.testing.expect(!h.isLinked(&a));

    a.unLink(&b);
    a.unLink(&c);
    a.unLink(&d);
    e.unLink(&a);
    f.unLink(&a);
    g.unLink(&a);

    try std.testing.expect(!a.isLinked(&b));
    try std.testing.expect(!b.isLinked(&a));
    try std.testing.expect(!a.isLinked(&c));
    try std.testing.expect(!c.isLinked(&a));
    try std.testing.expect(!a.isLinked(&d));
    try std.testing.expect(!d.isLinked(&a));
    try std.testing.expect(!a.isLinked(&e));
    try std.testing.expect(!e.isLinked(&a));
    try std.testing.expect(!a.isLinked(&f));
    try std.testing.expect(!f.isLinked(&a));
    try std.testing.expect(!a.isLinked(&g));
    try std.testing.expect(!g.isLinked(&a));
}

test "Hex cell neighbors/links" {
    var alloc = std.testing.allocator;
    var gr = try HexGrid.init(alloc, 0, 4, 4);
    defer gr.deinit();

    //    0  1  2  3
    // 0 /  \__/  \__
    //   \__/b \__/  \
    // 1 /g \__/c \__/
    //   \__/a \__/h \
    // 2 /f \__/d \__/
    //   \__/e \__/  \
    //      \__/  \__/

    var a = HexCell.init(&gr, 1, 1);
    defer a.deinit();
    var b = HexCell.init(&gr, 1, 0);
    defer b.deinit();
    var c = HexCell.init(&gr, 2, 1);
    defer c.deinit();
    var d = HexCell.init(&gr, 2, 2);
    defer d.deinit();
    var e = HexCell.init(&gr, 1, 2);
    defer e.deinit();
    var f = HexCell.init(&gr, 0, 2);
    defer f.deinit();
    var g = HexCell.init(&gr, 0, 1);
    defer g.deinit();
    var h = HexCell.init(&gr, 3, 1);
    defer h.deinit();

    try a.bLink(&b);
    try a.bLink(&c);
    try a.bLink(&d);
    try a.bLink(&e);
    try a.bLink(&f);
    try a.bLink(&g);

    const fns = struct {
        pub fn countNeighbors(cell: *HexCell) usize {
            var i: usize = 0;
            var count: usize = 0;
            const neis = cell.neighbors();
            while (i < cell.neighbors_buf.len) : (i += 1) {
                if (neis[i]) |_| count += 1;
            }
            return count;
        }

        pub fn countLinks(cell: *HexCell) usize {
            var i: usize = 0;
            var count: usize = 0;
            const lnks = cell.links();
            while (i < cell.neighbors_buf.len) : (i += 1) {
                if (lnks[i]) |_| count += 1;
            }
            return count;
        }
    };

    try std.testing.expect(fns.countNeighbors(&a) == 6);
    try std.testing.expect(fns.countLinks(&a) == 6);

    a.unLink(&b);
    a.unLink(&c);
    a.unLink(&d);

    try std.testing.expect(fns.countNeighbors(&a) == 6);
    try std.testing.expect(fns.countLinks(&a) == 3);

    a.unLink(&e);
    a.unLink(&f);
    a.unLink(&g);

    try std.testing.expect(fns.countNeighbors(&a) == 6);
    try std.testing.expect(fns.countLinks(&a) == 0);
}

test "Construct hex grid" {
    var alloc = std.testing.allocator;
    var grid = try HexGrid.init(alloc, 0, 8, 8);
    defer grid.deinit();
}

test "Hex grid oob" {
    var alloc = std.testing.allocator;
    var grid = try HexGrid.init(alloc, 0, 8, 8);
    defer grid.deinit();

    try std.testing.expectEqual(@as(?*HexGrid.CellT, null), grid.at(8, 8));
    try std.testing.expectEqual(@as(?*HexGrid.CellT, null), grid.at(0, 8));
    try std.testing.expectEqual(@as(?*HexGrid.CellT, null), grid.at(8, 0));
}

test "Hex grid string" {
    var alloc = std.testing.allocator;

    var grid88 = try HexGrid.init(alloc, 0, 8, 8);
    defer grid88.deinit();
    var grid87 = try HexGrid.init(alloc, 0, 8, 7);
    defer grid87.deinit();
    var grid78 = try HexGrid.init(alloc, 0, 7, 8);
    defer grid78.deinit();
    var grid77 = try HexGrid.init(alloc, 0, 7, 7);
    defer grid77.deinit();

    var string88 = try makeString(&grid88);
    defer alloc.free(string88);

    const g88 =
        \\/   \___/   \___/   \___/   \___ 
        \\\___/   \___/   \___/   \___/   \
        \\/   \___/   \___/   \___/   \___/
        \\\___/   \___/   \___/   \___/   \
        \\/   \___/   \___/   \___/   \___/
        \\\___/   \___/   \___/   \___/   \
        \\/   \___/   \___/   \___/   \___/
        \\\___/   \___/   \___/   \___/   \
        \\/   \___/   \___/   \___/   \___/
        \\\___/   \___/   \___/   \___/   \
        \\/   \___/   \___/   \___/   \___/
        \\\___/   \___/   \___/   \___/   \
        \\/   \___/   \___/   \___/   \___/
        \\\___/   \___/   \___/   \___/   \
        \\/   \___/   \___/   \___/   \___/
        \\\___/   \___/   \___/   \___/   \
        \\    \___/   \___/   \___/   \___/
        \\
    ;
    try std.testing.expectEqualStrings(g88, string88);

    var string87 = try makeString(&grid87);
    defer alloc.free(string87);

    const g87 =
        \\/   \___/   \___/   \___/   \___ 
        \\\___/   \___/   \___/   \___/   \
        \\/   \___/   \___/   \___/   \___/
        \\\___/   \___/   \___/   \___/   \
        \\/   \___/   \___/   \___/   \___/
        \\\___/   \___/   \___/   \___/   \
        \\/   \___/   \___/   \___/   \___/
        \\\___/   \___/   \___/   \___/   \
        \\/   \___/   \___/   \___/   \___/
        \\\___/   \___/   \___/   \___/   \
        \\/   \___/   \___/   \___/   \___/
        \\\___/   \___/   \___/   \___/   \
        \\/   \___/   \___/   \___/   \___/
        \\\___/   \___/   \___/   \___/   \
        \\    \___/   \___/   \___/   \___/
        \\
    ;
    try std.testing.expectEqualStrings(g87, string87);

    var string78 = try makeString(&grid78);
    defer alloc.free(string78);

    const g78 =
        \\/   \___/   \___/   \___/   \
        \\\___/   \___/   \___/   \___/
        \\/   \___/   \___/   \___/   \
        \\\___/   \___/   \___/   \___/
        \\/   \___/   \___/   \___/   \
        \\\___/   \___/   \___/   \___/
        \\/   \___/   \___/   \___/   \
        \\\___/   \___/   \___/   \___/
        \\/   \___/   \___/   \___/   \
        \\\___/   \___/   \___/   \___/
        \\/   \___/   \___/   \___/   \
        \\\___/   \___/   \___/   \___/
        \\/   \___/   \___/   \___/   \
        \\\___/   \___/   \___/   \___/
        \\/   \___/   \___/   \___/   \
        \\\___/   \___/   \___/   \___/
        \\    \___/   \___/   \___/    
        \\
    ;
    try std.testing.expectEqualStrings(g78, string78);

    var string77 = try makeString(&grid77);
    defer alloc.free(string77);

    const g77 =
        \\/   \___/   \___/   \___/   \
        \\\___/   \___/   \___/   \___/
        \\/   \___/   \___/   \___/   \
        \\\___/   \___/   \___/   \___/
        \\/   \___/   \___/   \___/   \
        \\\___/   \___/   \___/   \___/
        \\/   \___/   \___/   \___/   \
        \\\___/   \___/   \___/   \___/
        \\/   \___/   \___/   \___/   \
        \\\___/   \___/   \___/   \___/
        \\/   \___/   \___/   \___/   \
        \\\___/   \___/   \___/   \___/
        \\/   \___/   \___/   \___/   \
        \\\___/   \___/   \___/   \___/
        \\    \___/   \___/   \___/    
        \\
    ;
    try std.testing.expectEqualStrings(g77, string77);
}
