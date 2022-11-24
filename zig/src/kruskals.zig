//! build a maze with a version of kruskals algorithm

const std = @import("std");

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
        cell_setinfo_buf: []CellSetInfo,
        alctr: std.mem.Allocator,
        row_width: usize,

        pub fn init(grid: *GridT) !This {
            var s = .{
                .neighbor_pairs_buf = try grid.alctr.alloc(NeighborPair, (grid.width - 1) * (grid.height) + (grid.height - 1) * (grid.width)),
                .cell_setinfo_buf = try grid.alctr.alloc(CellSetInfo, grid.size()),
                .alctr = grid.alctr,
                .row_width = grid.width,
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
            }

            for (s.cell_setinfo_buf) |*info, i| {
                const x = @intCast(u32, i % grid.width);
                const y = @intCast(u32, @divTrunc(i, grid.width));
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

            var info: *CellSetInfo = &self.cell_setinfo_buf[self.row_width * cell.y() + cell.x()];
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

        for (state.neighbor_pairs_buf) |pair| {
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

    for (s.neighbor_pairs_buf) |pair, i| {
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

test "end2end" {
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
