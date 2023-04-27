//! build a maze with a version of kruskals algorithm

const std = @import("std");

const WeaveGrid = @import("weave_grid.zig").WeaveGrid;

/// Kruskals algorithm internal state
fn State(comptime GridT: type) type {
    return struct {
        const NeighborPair = std.meta.Tuple(&.{ *GridT.CellT, *GridT.CellT });
        const CellSetInfo = struct {
            cell: *GridT.CellT,
            set: u32,
            next: ?*@This() = null,
        };

        neighbor_pairs_buf: []NeighborPair,
        neighbor_pairs: []NeighborPair = undefined,
        cell_setinfo_buf: []CellSetInfo,
        alctr: std.mem.Allocator,
        grid: *GridT,

        pub fn init(grid: *GridT) !This {
            var s = This{
                .neighbor_pairs_buf = try grid.alctr.alloc(NeighborPair, (grid.width - 1) * (grid.height) + (grid.height - 1) * (grid.width)),
                .cell_setinfo_buf = try grid.alctr.alloc(CellSetInfo, grid.size() * 2),
                .alctr = grid.alctr,
                .grid = grid,
            };

            {
                var write_idx: usize = 0;
                var y: u32 = 0;
                while (y < grid.height) : (y += 1) {
                    var x: u32 = 0;
                    while (x < grid.width) : (x += 1) {
                        var i: usize = 0;
                        while (i < 2) : (i += 1) {
                            const cell = grid.at(x, y).?;
                            if (i & 1 == 0 and cell.east() != null) {
                                var pair = &s.neighbor_pairs_buf[write_idx];
                                pair.* = .{ cell, cell.east().? };
                                write_idx += 1;
                            } else if (i & 1 == 1 and cell.south() != null) {
                                var pair = &s.neighbor_pairs_buf[write_idx];
                                pair.* = .{ cell, cell.south().? };
                                write_idx += 1;
                            }
                        }
                    }
                }

                grid.prng.random().shuffle(NeighborPair, s.neighbor_pairs_buf);
                s.neighbor_pairs = s.neighbor_pairs_buf;
            }

            for (s.cell_setinfo_buf, 0..) |*info, i| {
                const x = @intCast(u32, (i % s.grid.size()) % grid.width);
                const y = @intCast(u32, @divTrunc(i % s.grid.size(), grid.width));
                const cell = grid.at(x, y).?;

                info.* = .{ .cell = cell, .set = @intCast(u32, i) };
            }

            return s;
        }

        pub fn deinit(self: *This) void {
            self.alctr.free(self.neighbor_pairs_buf);
            self.alctr.free(self.cell_setinfo_buf);
        }

        fn headSetOfCell(self: *This, cell: *GridT.CellT) *CellSetInfo {
            var fixup_buf = [_]?*CellSetInfo{null} ** 64;
            var fixup_i: usize = 0;

            const idx = blk: {
                var i = self.grid.width * cell.y() + cell.x();
                if (GridT == WeaveGrid and std.meta.activeTag(cell.*) == .under)
                    i += @intCast(u32, self.grid.size());
                break :blk i;
            };

            var info: *CellSetInfo = &self.cell_setinfo_buf[idx];
            while (info.next != null) {
                fixup_buf[fixup_i] = info;
                info = info.next.?;
            }

            for (std.mem.sliceTo(&fixup_buf, null)) |tofix| {
                tofix.?.next = info;
            }

            return info;
        }

        pub fn merge(self: *This, pair: NeighborPair) !void {
            var left_info = self.headSetOfCell(pair.@"0");
            var right_info = self.headSetOfCell(pair.@"1");

            if (left_info.set == right_info.set) return error.CantMerge;
            try pair.@"0".bLink(pair.@"1");

            right_info.next = left_info;
        }

        pub fn addCrossing(self: *This, cell: *GridT.CellT) !void {
            if (GridT != WeaveGrid) {
                @compileError("Oops");
            }

            // validate that we can cross this cell
            var north = cell.north() orelse return error.CantCross;
            var south = cell.south() orelse return error.CantCross;
            var east = cell.east() orelse return error.CantCross;
            var west = cell.west() orelse return error.CantCross;

            // zig fmt: off
            if (cell.numLinks() > 0
            or (self.setOfCell(north) == self.setOfCell(south))
            or (self.setOfCell(west) == self.setOfCell(east)))
            {
                return error.CantCross;
                // zig fmt: on
            }

            { // filter out cells from consideration in kruskals later
                var len = self.neighbor_pairs.len;
                var read: usize = 0;
                var write: usize = 0;
                while (read < len) : (read += 1) {
                    var read_cell = self.neighbor_pairs_buf[read];
                    if (read_cell.@"0" == cell or read_cell.@"1" == cell) {
                        continue;
                    }

                    self.neighbor_pairs_buf[write] = self.neighbor_pairs_buf[read];
                    write += 1;
                }

                self.neighbor_pairs.len = write;
            }

            // cross
            if (self.grid.prng.random().intRangeLessThan(usize, 0, 2) == 0) {
                // west/east on top
                try self.merge(.{ west, cell });
                try self.merge(.{ cell, east });

                self.grid.tunnelUnder(cell);
                try self.merge(.{ north.over.neighbors_buf[9].?, north });
                try self.merge(.{ south.over.neighbors_buf[8].?, south });
            } else {
                // north/south on top
                try self.merge(.{ north, cell });
                try self.merge(.{ cell, south });

                self.grid.tunnelUnder(cell);
                try self.merge(.{ west.over.neighbors_buf[10].?, west });
                try self.merge(.{ east.over.neighbors_buf[11].?, east });
            }
        }

        pub fn setOfCell(self: *This, cell: *GridT.CellT) u32 {
            return self.headSetOfCell(cell).set;
        }

        const This = @This();
    };
}

pub const Kruskals = struct {
    pub fn on(grid: anytype) !void {
        var state = try State(@TypeOf(grid.*)).init(grid);
        defer state.deinit();

        if (@TypeOf(grid.*) == WeaveGrid) {
            var i: usize = 0;
            while (i < grid.size()) : (i += 1) {
                state.addCrossing(grid.pickRandom()) catch |e| switch (e) {
                    error.CantCross => {}, // ok
                    else => return e,
                };
            }
        }

        for (state.neighbor_pairs) |pair| {
            state.merge(pair) catch |e| switch (e) {
                error.CantMerge => {}, // ok
                else => return e,
            };
        }
    }
};

const SquareGrid = @import("square_grid.zig").SquareGrid;

fn testGrid() !SquareGrid {
    var alloc = std.testing.allocator;
    return SquareGrid.init(alloc, 0, 10, 10);
}

test "state: init/deinit" {
    var g = try testGrid();
    defer g.deinit();

    var s = try State(@TypeOf(g)).init(&g);
    defer s.deinit();

    for (s.neighbor_pairs_buf, 0..) |pair, i| {
        errdefer std.debug.print("Failing index: {}\n", .{i});
        try std.testing.expect(g.at(pair.@"0".x(), pair.@"1".y()) != null);
    }
}

test "state: setOfCell" {
    var g = try testGrid();
    defer g.deinit();

    var s = try State(@TypeOf(g)).init(&g);
    defer s.deinit();

    var l = g.at(0, 0).?;
    var r = g.at(0, 1).?;

    try s.merge(.{ l, r });

    try std.testing.expect(s.setOfCell(l) == s.setOfCell(r));
    try std.testing.expectError(error.CantMerge, s.merge(.{ l, r }));

    var d = g.at(1, 0).?;

    try s.merge(.{ l, d });

    try std.testing.expect(s.setOfCell(l) == s.setOfCell(d));
    try std.testing.expect(s.setOfCell(d) == s.setOfCell(r));
    try std.testing.expect(s.setOfCell(l) == s.setOfCell(r));
}

test "end to end: square grid" {
    var g = try testGrid();
    defer g.deinit();

    try Kruskals.on(&g);

    const s = try g.makeString();
    defer g.alctr.free(s);

    const m =
        \\+---+---+---+---+---+---+---+---+---+---+
        \\|       |       |               |       |
        \\+   +---+   +   +---+---+   +---+   +---+
        \\|           |   |           |           |
        \\+   +   +   +   +   +---+---+---+---+   +
        \\|   |   |   |   |                       |
        \\+---+   +---+   +---+---+---+   +---+   +
        \\|           |                   |   |   |
        \\+   +   +---+   +   +---+   +---+   +   +
        \\|   |   |       |       |           |   |
        \\+---+---+   +   +   +---+   +   +---+---+
        \\|           |   |   |       |           |
        \\+---+   +---+---+---+   +---+   +   +   +
        \\|   |   |       |       |       |   |   |
        \\+   +   +   +---+---+---+   +---+---+---+
        \\|       |           |       |   |       |
        \\+---+   +---+   +---+   +   +   +   +   +
        \\|   |       |       |   |           |   |
        \\+   +   +---+   +   +   +   +   +   +   +
        \\|       |       |       |   |   |   |   |
        \\+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try std.testing.expectEqualStrings(m, s);
}

test "end to end: weave grid" {
    // just make sure it doesn't panic

    var alloc = std.testing.allocator;
    var g = try WeaveGrid.init(alloc, 0, 10, 10);
    defer g.deinit();

    try Kruskals.on(&g);
}
