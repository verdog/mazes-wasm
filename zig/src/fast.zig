//! "fast" maze algorithm trying to combine the strengths of aldous-broder and wilson

const std = @import("std");

const Grid = @import("grid.zig").Grid;
const Distances = @import("distances.zig").Distances;
const Cell = @import("grid.zig").Cell;

const AldousBroder = @import("aldous_broder.zig").AldousBroder;
const Wilson = @import("wilson.zig").Wilson;

pub const Fast = struct {
    pub fn on(grid: *Grid) !void {
        // start with AldousBroder
        if (grid.size() > 1) {
            // TODO tune ratio
            try AldousBroder.onUntilNVisited(grid, @divTrunc(grid.size(), 2));
        }
        // finish with Wilson
        try Wilson.on(grid);
    }
};

test "Apply Fast" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 0, 10, 10);
    defer grid.deinit();

    try Fast.on(&grid);
}

test "Fast produces expected maze texture" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 0, 10, 10);
    defer grid.deinit();

    try Fast.on(&grid);

    const s = try grid.makeString();
    defer alloc.free(s);

    const m =
        \\+---+---+---+---+---+---+---+---+---+---+
        \\|   |               |                   |
        \\+   +---+---+---+   +   +---+   +   +---+
        \\|   |   |           |       |   |   |   |
        \\+   +   +---+   +   +   +---+---+   +   +
        \\|       |       |           |           |
        \\+   +   +   +---+   +   +---+---+   +---+
        \\|   |   |   |       |   |       |   |   |
        \\+   +---+   +---+---+   +   +---+   +   +
        \\|               |   |   |       |       |
        \\+---+   +   +---+   +   +   +   +---+   +
        \\|       |   |               |       |   |
        \\+   +---+   +---+   +   +   +   +   +---+
        \\|   |       |       |   |   |   |       |
        \\+---+   +---+---+---+   +---+   +---+   +
        \\|   |   |                   |   |   |   |
        \\+   +   +   +---+---+---+---+---+   +   +
        \\|       |           |                   |
        \\+---+   +   +---+---+   +   +---+   +---+
        \\|       |   |           |   |           |
        \\+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try std.testing.expectEqualStrings(m, s);
}

test "Fast distances" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 0, 10, 10);
    defer grid.deinit();

    try Fast.on(&grid);

    grid.distances = try Distances(Grid).from(&grid, grid.at(0, 0).?);

    const s = try grid.makeString();
    defer alloc.free(s);

    const m =
        \\+---+---+---+---+---+---+---+---+---+---+
        \\| 0 | F   E   D   C | F   0   1   2   3 |
        \\+   +---+---+---+   +   +---+   +   +---+
        \\| 1 | 4 | B   A   B | E   F | 2 | 3 | 6 |
        \\+   +   +---+   +   +   +---+---+   +   +
        \\| 2   3 | 8   9 | C   D   E | 5   4   5 |
        \\+   +   +   +---+   +   +---+---+   +---+
        \\| 3 | 4 | 7 | E   D | E | 3   4 | 5 | 8 |
        \\+   +---+   +---+---+   +   +---+   +   +
        \\| 4   5   6   7 | 2 | F | 2   3 | 6   7 |
        \\+---+   +   +---+   +   +   +   +---+   +
        \\| 7   6 | 7 | 2   1   0   1 | 4   5 | 8 |
        \\+   +---+   +---+   +   +   +   +   +---+
        \\| 8 | 9   8 | 3   2 | 1 | 2 | 5 | 6   7 |
        \\+---+   +---+---+---+   +---+   +---+   +
        \\| D | A | 5   4   3   2   3 | 6 | B | 8 |
        \\+   +   +   +---+---+---+---+---+   +   +
        \\| C   B | 6   7   8 | D   C   B   A   9 |
        \\+---+   +   +---+---+   +   +---+   +---+
        \\| D   C | 7 | 0   F   E | D | C   B   C |
        \\+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try std.testing.expectEqualStrings(m, s);
}

test "Fast path" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 0, 10, 10);
    defer grid.deinit();

    try Fast.on(&grid);

    grid.distances = try Distances(Grid).from(&grid, grid.at(0, 0).?);
    var path = try grid.distances.?.pathTo(grid.at(9, 9).?);
    grid.distances.?.deinit();
    grid.distances = path;

    const s = try grid.makeString();
    defer alloc.free(s);

    const m =
        \\+---+---+---+---+---+---+---+---+---+---+
        \\| 0 |               |                   |
        \\+   +---+---+---+   +   +---+   +   +---+
        \\| 1 |   |     A   B |       |   |   |   |
        \\+   +   +---+   +   +   +---+---+   +   +
        \\| 2     | 8   9 | C   D     |           |
        \\+   +   +   +---+   +   +---+---+   +---+
        \\| 3 |   | 7 |       | E |       |   |   |
        \\+   +---+   +---+---+   +   +---+   +   +
        \\| 4   5   6     |   | F | 2   3 |       |
        \\+---+   +   +---+   +   +   +   +---+   +
        \\|       |   |         0   1 | 4   5 |   |
        \\+   +---+   +---+   +   +   +   +   +---+
        \\|   |       |       |   |   |   | 6   7 |
        \\+---+   +---+---+---+   +---+   +---+   +
        \\|   |   |                   |   |   | 8 |
        \\+   +   +   +---+---+---+---+---+   +   +
        \\|       |           |             A   9 |
        \\+---+   +   +---+---+   +   +---+   +---+
        \\|       |   |           |   |     B   C |
        \\+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try std.testing.expectEqualStrings(m, s);
}
