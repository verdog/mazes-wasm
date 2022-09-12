//! aldous-broder max algorithm

const std = @import("std");

const Grid = @import("grid.zig").Grid;
const Cell = @import("grid.zig").Cell;
const Distances = @import("grid.zig").Distances;

pub const AldousBroder = struct {
    pub fn on(grid: anytype) !void {
        // TODO force inline?
        try AldousBroder.onUntilNVisited(grid, grid.size() - 1);
    }

    // Run the generation algorithm until n cells have been visited.
    pub fn onUntilNVisited(grid: anytype, n: usize) !void {
        var cell = grid.pickRandom();
        var todo = n;

        while (todo != 0) {
            if (cell.randomNeighbor()) |next| {
                if (next.numLinks() == 0) {
                    todo -= 1;
                    try cell.bLink(next);
                }
                cell = next;
            } else {
                unreachable;
            }
        }
    }
};

test "Apply Aldous-Broder" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 0, 10, 10);
    defer grid.deinit();

    try AldousBroder.on(&grid);
}

test "Aldous-Broder produces expected maze texture" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 0, 10, 10);
    defer grid.deinit();

    try AldousBroder.on(&grid);

    const s = try grid.makeString();
    defer alloc.free(s);

    const m =
        \\+---+---+---+---+---+---+---+---+---+---+
        \\|       |   |       |                   |
        \\+   +---+   +---+   +   +---+   +   +---+
        \\|   |   |   |       |       |   |   |   |
        \\+   +   +   +   +   +   +---+---+   +   +
        \\|       |       |           |           |
        \\+   +   +   +---+   +   +---+---+   +---+
        \\|   |   |   |   |   |   |   |       |   |
        \\+   +---+   +   +---+   +   +---+   +   +
        \\|           |       |   |       |       |
        \\+---+   +   +   +---+   +   +---+---+   +
        \\|       |   |   |               |       |
        \\+---+   +---+   +---+   +   +---+---+   +
        \\|       |           |   |   |   |   |   |
        \\+   +   +---+   +---+   +---+   +   +   +
        \\|   |       |       |   |   |           |
        \\+   +---+   +---+   +---+   +   +   +---+
        \\|   |   |   |                   |   |   |
        \\+   +   +   +   +---+   +   +---+---+   +
        \\|       |   |       |   |               |
        \\+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try std.testing.expectEqualStrings(m, s);
}

test "Aldous-Broder distances" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 0, 10, 10);
    defer grid.deinit();

    try AldousBroder.on(&grid);

    grid.distances = try Distances.from(grid.at(0, 0).?);

    const s = try grid.makeString();
    defer alloc.free(s);

    const m =
        \\+---+---+---+---+---+---+---+---+---+---+
        \\| 0   1 | A | D   C | F   0   1   2   3 |
        \\+   +---+   +---+   +   +---+   +   +---+
        \\| 1 | 4 | 9 | A   B | E   F | 2 | 3 | 6 |
        \\+   +   +   +   +   +   +---+---+   +   +
        \\| 2   3 | 8   9 | C   D   E | 5   4   5 |
        \\+   +   +   +---+   +   +---+---+   +---+
        \\| 3 | 4 | 7 | 6 | D | E | 3 | 6   5 | 8 |
        \\+   +---+   +   +---+   +   +---+   +   +
        \\| 4   5   6 | 5   6 | F | 2   3 | 6   7 |
        \\+---+   +   +   +---+   +   +---+---+   +
        \\| 7   6 | 7 | 4 | 1   0   1   2 | 9   8 |
        \\+---+   +---+   +---+   +   +---+---+   +
        \\| 8   7 | 4   3   4 | 1 | 2 | D | C | 9 |
        \\+   +   +---+   +---+   +---+   +   +   +
        \\| 9 | 8   9 | 2   1 | 2 | F | C   B   A |
        \\+   +---+   +---+   +---+   +   +   +---+
        \\| A | D | A | 1   0   F   E   D | C | 3 |
        \\+   +   +   +   +---+   +   +---+---+   +
        \\| B   C | B | 2   3 | 0 | F   0   1   2 |
        \\+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try std.testing.expectEqualStrings(m, s);
}

test "Aldous broder path" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 0, 10, 10);
    defer grid.deinit();

    try AldousBroder.on(&grid);

    grid.distances = try Distances.from(grid.at(0, 0).?);
    var path = try grid.distances.?.pathTo(grid.at(9, 9).?);
    grid.distances.?.deinit();
    grid.distances = path;

    const s = try grid.makeString();
    defer alloc.free(s);

    const m =
        \\+---+---+---+---+---+---+---+---+---+---+
        \\| 0     |   |       | F   0   1   2     |
        \\+   +---+   +---+   +   +---+   +   +---+
        \\| 1 |   |   | A   B | E     |   | 3 |   |
        \\+   +   +   +   +   +   +---+---+   +   +
        \\| 2     | 8   9 | C   D     |     4     |
        \\+   +   +   +---+   +   +---+---+   +---+
        \\| 3 |   | 7 |   |   |   |   |     5 |   |
        \\+   +---+   +   +---+   +   +---+   +   +
        \\| 4   5   6 |       |   |       | 6   7 |
        \\+---+   +   +   +---+   +   +---+---+   +
        \\|       |   |   |               |     8 |
        \\+---+   +---+   +---+   +   +---+---+   +
        \\|       |           |   |   |   |   | 9 |
        \\+   +   +---+   +---+   +---+   +   +   +
        \\|   |       |       |   |   | C   B   A |
        \\+   +---+   +---+   +---+   +   +   +---+
        \\|   |   |   |             E   D |   |   |
        \\+   +   +   +   +---+   +   +---+---+   +
        \\|       |   |       |   | F   0   1   2 |
        \\+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try std.testing.expectEqualStrings(m, s);
}
