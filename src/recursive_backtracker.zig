//! recursive backtracker maze algorithm

const std = @import("std");

const SquareGrid = @import("square_grid.zig").SquareGrid;
const SquareCell = @import("square_grid.zig").SquareCell;
const Distances = @import("distances.zig").Distances;
const HexGrid = @import("hex_grid.zig").HexGrid;
const HexCell = @import("hex_grid.zig").HexCell;
const TriGrid = @import("tri_grid.zig").TriGrid;
const TriCell = @import("tri_grid.zig").TriCell;
const UpsilonGrid = @import("upsilon_grid.zig").UpsilonGrid;
const UpsilonCell = @import("upsilon_grid.zig").UpsilonCell;
const WeaveGrid = @import("weave_grid.zig").WeaveGrid;

pub const RecursiveBacktracker = struct {
    pub fn on(grid: anytype) !void {
        switch (@TypeOf(grid)) {
            *SquareGrid => return try RecursiveBacktracker.on_Grid(grid),
            *HexGrid => return try RecursiveBacktracker.on_Generic(HexGrid, HexCell, grid),
            *TriGrid => return try RecursiveBacktracker.on_Generic(TriGrid, TriCell, grid),
            *UpsilonGrid => return try RecursiveBacktracker.on_Generic(UpsilonGrid, UpsilonCell, grid),
            *WeaveGrid => return try RecursiveBacktracker.on_Generic(WeaveGrid, WeaveGrid.CellT, grid),
            else => std.debug.panic("", .{}),
        }
    }

    fn on_Grid(grid: *SquareGrid) !void {
        var stack = std.ArrayList(*SquareCell).init(grid.alctr);
        defer stack.deinit();

        try stack.append(grid.pickRandom());

        while (stack.items.len > 0) {
            if (stack.items[stack.items.len - 1].randomNeighborUnlinked()) |nei| {
                var cell = stack.items[stack.items.len - 1];
                try stack.append(nei);
                try cell.bLink(nei);
            } else {
                stack.shrinkRetainingCapacity(stack.items.len - 1);
            }
        }
    }

    fn on_Generic(comptime GridT: type, comptime CellT: type, grid: *GridT) !void {
        var stack = std.ArrayList(*CellT).init(grid.alctr);
        defer stack.deinit();

        try stack.append(grid.pickRandom());

        while (stack.items.len > 0) {
            if (stack.items.len > grid.size()) {
                unreachable;
            }
            if (stack.items[stack.items.len - 1].randomNeighborUnlinked()) |nei| {
                var cell = stack.items[stack.items.len - 1];
                try stack.append(nei);
                try cell.bLink(nei);
            } else {
                stack.shrinkRetainingCapacity(stack.items.len - 1);
            }
        }
    }
};

test "Apply RecursiveBacktracker to all types" {
    const tst = struct {
        fn tst(comptime T: type) !void {
            var alloc = std.testing.allocator;
            var grid = try T.init(alloc, 0, 10, 10);
            defer grid.deinit();
            try RecursiveBacktracker.on(&grid);
        }
    }.tst;

    inline for (@import("mazes.zig").AllMazes) |t| try tst(t);
}

test "RecursiveBacktracker produces expected maze texture" {
    var alloc = std.testing.allocator;
    var grid = try SquareGrid.init(alloc, 0, 10, 10);
    defer grid.deinit();

    try RecursiveBacktracker.on(&grid);

    const s = try grid.makeString();
    defer alloc.free(s);

    const m =
        \\+---+---+---+---+---+---+---+---+---+---+
        \\|   |               |       |           |
        \\+   +   +---+---+   +   +   +---+   +   +
        \\|   |           |   |   |   |       |   |
        \\+   +---+---+   +   +   +   +   +---+---+
        \\|           |   |   |   |   |           |
        \\+   +   +---+   +   +   +   +   +---+   +
        \\|   |   |   |   |   |   |   |   |       |
        \\+---+   +   +   +   +   +   +   +   +   +
        \\|       |       |       |   |   |   |   |
        \\+   +---+---+---+---+---+   +---+   +   +
        \\|                   |   |           |   |
        \\+   +---+   +---+   +   +---+---+---+   +
        \\|       |   |                       |   |
        \\+---+---+   +---+---+---+---+---+   +   +
        \\|           |           |           |   |
        \\+   +---+   +   +---+   +   +---+---+   +
        \\|   |       |   |   |   |           |   |
        \\+   +---+---+   +   +   +---+---+---+   +
        \\|                   |                   |
        \\+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try std.testing.expectEqualStrings(m, s);
}

test "RecursiveBacktracker distances" {
    var alloc = std.testing.allocator;
    var grid = try SquareGrid.init(alloc, 0, 10, 10);
    defer grid.deinit();

    try RecursiveBacktracker.on(&grid);

    grid.distances = try Distances(SquareGrid).from(&grid, grid.at(0, 0).?);

    const s = try grid.makeString();
    defer alloc.free(s);

    const m =
        \\+---+---+---+---+---+---+---+---+---+---+
        \\| 0 | 9   8   7   6 | D   C | 9   8   9 |
        \\+   +   +---+---+   +   +   +---+   +   +
        \\| 1 | A   B   C | 5 | E | B | 6   7 | A |
        \\+   +---+---+   +   +   +   +   +---+---+
        \\| 2   3   4 | D | 4 | F | A | 5   4   3 |
        \\+   +   +---+   +   +   +   +   +---+   +
        \\| 3 | 4 | 1 | E | 3 | 0 | 9 | 6 | 3   2 |
        \\+---+   +   +   +   +   +   +   +   +   +
        \\| 6   5 | 0   F | 2   1 | 8 | 7 | 4 | 1 |
        \\+   +---+---+---+---+---+   +---+   +   +
        \\| 7   8   9   A   B | E | 7   6   5 | 0 |
        \\+   +---+   +---+   +   +---+---+---+   +
        \\| 8   9 | A | D   C   D   E   F   0 | F |
        \\+---+---+   +---+---+---+---+---+   +   +
        \\| D   C   B | 4   5   6 | 3   2   1 | E |
        \\+   +---+   +   +---+   +   +---+---+   +
        \\| E | D   C | 3 | 4 | 7 | 4   5   6 | D |
        \\+   +---+---+   +   +   +---+---+---+   +
        \\| F   0   1   2   3 | 8   9   A   B   C |
        \\+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try std.testing.expectEqualStrings(m, s);
}

test "RecursiveBacktracker path" {
    var alloc = std.testing.allocator;
    var grid = try SquareGrid.init(alloc, 0, 10, 10);
    defer grid.deinit();

    try RecursiveBacktracker.on(&grid);

    grid.distances = try Distances(SquareGrid).from(&grid, grid.at(0, 0).?);
    var path = try grid.distances.?.pathTo(grid.at(9, 9).?);
    grid.distances.?.deinit();
    grid.distances = path;

    const s = try grid.makeString();
    defer alloc.free(s);

    const m =
        \\+---+---+---+---+---+---+---+---+---+---+
        \\| 0 |               |       |           |
        \\+   +   +---+---+   +   +   +---+   +   +
        \\| 1 |           |   |   |   |       |   |
        \\+   +---+---+   +   +   +   +   +---+---+
        \\| 2   3     |   |   |   |   |           |
        \\+   +   +---+   +   +   +   +   +---+   +
        \\|   | 4 |   |   |   |   |   |   |       |
        \\+---+   +   +   +   +   +   +   +   +   +
        \\| 6   5 |       |       |   |   |   |   |
        \\+   +---+---+---+---+---+   +---+   +   +
        \\| 7   8   9         |   |           |   |
        \\+   +---+   +---+   +   +---+---+---+   +
        \\|       | A |                       |   |
        \\+---+---+   +---+---+---+---+---+   +   +
        \\| D   C   B | 4   5   6 |           |   |
        \\+   +---+   +   +---+   +   +---+---+   +
        \\| E |       | 3 |   | 7 |           |   |
        \\+   +---+---+   +   +   +---+---+---+   +
        \\| F   0   1   2     | 8   9   A   B   C |
        \\+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try std.testing.expectEqualStrings(m, s);
}
