//! hunt and kill maze algorithm

const std = @import("std");

const Grid = @import("grid.zig").Grid;
const Distances = @import("grid.zig").Distances;
const Cell = @import("grid.zig").Cell;

pub const HuntAndKill = struct {
    pub fn on(grid: *Grid) !void {
        var cell = grid.at(0, 0).?;
        var todo = grid.size() - 1;

        outer: while (todo > 0) {
            if (cell.randomNeighborUnlinked()) |nei| {
                // wander
                todo -= 1;
                try cell.bLink(nei);
                cell = nei;
            } else {
                // no available neighbors, find new start
                var r = grid.pickRandom();
                var start = r.row * grid.width + r.col;
                var i = if (start + 1 < grid.size()) start + 1 else 0;

                while (i != start) : (i = if (i + 1 < grid.size()) i + 1 else 0) {
                    var unlinked = &grid.cells_buf[i];
                    if (unlinked.numLinks() == 0) {
                        if (unlinked.randomNeighborLinked()) |nei| {
                            todo -= 1;
                            cell = unlinked;
                            try cell.bLink(nei);
                            continue :outer;
                        }
                    }
                }
                unreachable;
            }
        }
    }
};

test "Hunt and Kill" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 0, 10, 10);
    defer grid.deinit();

    _ = try HuntAndKill.on(&grid);
}

test "HuntAndKill produces expected maze texture" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 0, 10, 10);
    defer grid.deinit();

    try HuntAndKill.on(&grid);

    const s = try grid.makeString();
    defer alloc.free(s);

    const m =
        \\+---+---+---+---+---+---+---+---+---+---+
        \\|   |           |               |       |
        \\+   +   +   +   +   +   +---+---+   +   +
        \\|   |   |   |       |   |   |       |   |
        \\+   +   +   +   +---+   +   +   +---+   +
        \\|   |   |   |   |       |   |       |   |
        \\+   +   +   +   +   +   +   +---+   +   +
        \\|   |   |   |   |   |   |   |       |   |
        \\+   +   +   +   +---+   +   +   +---+---+
        \\|   |   |   |       |   |   |           |
        \\+   +   +   +---+   +   +   +---+---+   +
        \\|   |   |   |       |       |   |       |
        \\+   +---+   +   +---+---+   +   +   +---+
        \\|           |   |       |       |   |   |
        \\+---+---+---+   +---+   +   +---+   +   +
        \\|   |                   |               |
        \\+   +   +---+---+---+---+---+---+---+---+
        \\|   |                   |           |   |
        \\+   +   +---+---+---+   +---+   +   +   +
        \\|       |                       |       |
        \\+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try std.testing.expectEqualStrings(m, s);
}

test "HuntAndKill distances" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 0, 10, 10);
    defer grid.deinit();

    try HuntAndKill.on(&grid);

    grid.distances = try Distances(Cell).from(grid.at(0, 0).?);

    const s = try grid.makeString();
    defer alloc.free(s);

    const m =
        \\+---+---+---+---+---+---+---+---+---+---+
        \\| 0 | F   E   F | 2   3   4   5 | A   B |
        \\+   +   +   +   +   +   +---+---+   +   +
        \\| 1 | 0 | D | 0   1 | 4 | D | 8   9 | C |
        \\+   +   +   +   +---+   +   +   +---+   +
        \\| 2 | 1 | C | 1 | 6   5 | C | 7   6 | D |
        \\+   +   +   +   +   +   +   +---+   +   +
        \\| 3 | 2 | B | 2 | 7 | 6 | B | 4   5 | E |
        \\+   +   +   +   +---+   +   +   +---+---+
        \\| 4 | 3 | A | 3   4 | 7 | A | 3   2   1 |
        \\+   +   +   +---+   +   +   +---+---+   +
        \\| 5 | 4 | 9 | 6   5 | 8   9 | C | F   0 |
        \\+   +---+   +   +---+---+   +   +   +---+
        \\| 6   7   8 | 7 | C   B | A   B | E | F |
        \\+---+---+---+   +---+   +   +---+   +   +
        \\| F | A   9   8   9   A | B   C   D   E |
        \\+   +   +---+---+---+---+---+---+---+---+
        \\| E | B   C   D   E   F | 4   3   4 | 7 |
        \\+   +   +---+---+---+   +---+   +   +   +
        \\| D   C | 3   2   1   0   1   2 | 5   6 |
        \\+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try std.testing.expectEqualStrings(m, s);
}

test "HuntAndKill path" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 0, 10, 10);
    defer grid.deinit();

    try HuntAndKill.on(&grid);

    grid.distances = try Distances(Cell).from(grid.at(0, 0).?);
    var path = try grid.distances.?.pathTo(grid.at(9, 9).?);
    grid.distances.?.deinit();
    grid.distances = path;

    const s = try grid.makeString();
    defer alloc.free(s);

    const m =
        \\+---+---+---+---+---+---+---+---+---+---+
        \\| 0 |     E   F |               |       |
        \\+   +   +   +   +   +   +---+---+   +   +
        \\| 1 |   | D | 0     |   |   |       |   |
        \\+   +   +   +   +---+   +   +   +---+   +
        \\| 2 |   | C | 1 |       |   |       |   |
        \\+   +   +   +   +   +   +   +---+   +   +
        \\| 3 |   | B | 2 |   |   |   |       |   |
        \\+   +   +   +   +---+   +   +   +---+---+
        \\| 4 |   | A | 3   4 |   |   |           |
        \\+   +   +   +---+   +   +   +---+---+   +
        \\| 5 |   | 9 | 6   5 |       |   |       |
        \\+   +---+   +   +---+---+   +   +   +---+
        \\| 6   7   8 | 7 |       |       |   |   |
        \\+---+---+---+   +---+   +   +---+   +   +
        \\|   | A   9   8         |               |
        \\+   +   +---+---+---+---+---+---+---+---+
        \\|   | B   C   D   E   F |     3   4 |   |
        \\+   +   +---+---+---+   +---+   +   +   +
        \\|       |             0   1   2 | 5   6 |
        \\+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try std.testing.expectEqualStrings(m, s);
}
