//! hunt and kill maze algorithm

const std = @import("std");

const Grid = @import("grid.zig").Grid;
const Cell = @import("grid.zig").Cell;

pub const HuntAndKill = struct {
    pub fn on(grid: *Grid) !void {
        var cell = grid.at(0, 0).?;
        var search: usize = 0;
        var todo = grid.size() - 1;

        outer: while (todo > 0) {
            if (cell.randomNeighborUnlinked()) |nei| {
                // wander
                todo -= 1;
                try cell.bLink(nei);
                cell = nei;
            } else {
                // no available neighbors, find new start
                for (grid.cells_buf[search..]) |*unlinked, i| {
                    if (unlinked.numLinks() == 0) {
                        if (unlinked.randomNeighborLinked()) |nei| {
                            todo -= 1;
                            cell = unlinked;
                            try cell.bLink(nei);
                            search = i;
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
        \\|   |           |           |           |
        \\+   +   +   +   +   +   +   +---+   +   +
        \\|   |   |   |       |   |   |       |   |
        \\+   +   +   +   +---+   +   +   +---+   +
        \\|   |   |   |       |   |   |       |   |
        \\+   +   +   +---+   +   +   +---+   +   +
        \\|   |   |   |       |   |   |       |   |
        \\+   +   +   +   +---+   +   +   +---+---+
        \\|   |   |   |   |       |   |           |
        \\+   +   +   +   +---+   +---+---+---+   +
        \\|   |   |   |       |           |       |
        \\+   +---+   +---+   +---+   +   +   +---+
        \\|           |   |       |   |   |       |
        \\+---+---+---+   +---+   +   +---+   +   +
        \\|       |               |           |   |
        \\+   +---+   +---+---+---+---+---+---+   +
        \\|   |       |           |               |
        \\+   +   +---+   +---+---+   +   +---+---+
        \\|           |               |           |
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

    grid.distances = try grid.at(0, 0).?.distances();

    const s = try grid.makeString();
    defer alloc.free(s);

    const m =
        \\+---+---+---+---+---+---+---+---+---+---+
        \\| 0 | F   E   F | 2   3   4 | B   A   B |
        \\+   +   +   +   +   +   +   +---+   +   +
        \\| 1 | 0 | D | 0   1 | 4 | 5 | 8   9 | C |
        \\+   +   +   +   +---+   +   +   +---+   +
        \\| 2 | 1 | C | 1   2 | 5 | 6 | 7   6 | D |
        \\+   +   +   +---+   +   +   +---+   +   +
        \\| 3 | 2 | B | 4   3 | 6 | 7 | 4   5 | E |
        \\+   +   +   +   +---+   +   +   +---+---+
        \\| 4 | 3 | A | 5 | 8   7 | 8 | 3   2   1 |
        \\+   +   +   +   +---+   +---+---+---+   +
        \\| 5 | 4 | 9 | 6   7 | 8   9   A | F   0 |
        \\+   +---+   +---+   +---+   +   +   +---+
        \\| 6   7   8 | D | 8   9 | A | B | E   F |
        \\+---+---+---+   +---+   +   +---+   +   +
        \\| 3   4 | D   C   B   A | B   C   D | 0 |
        \\+   +---+   +---+---+---+---+---+---+   +
        \\| 2 | F   E | 9   A   B | 4   3   2   1 |
        \\+   +   +---+   +---+---+   +   +---+---+
        \\| 1   0   1 | 8   7   6   5 | 4   5   6 |
        \\+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try std.testing.expectEqualStrings(m, s);
}

test "Aldous broder path" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 0, 10, 10);
    defer grid.deinit();

    try HuntAndKill.on(&grid);

    grid.distances = try grid.at(0, 0).?.distances();
    var path = try grid.distances.?.pathTo(grid.at(9, 9).?);
    grid.distances.?.deinit();
    grid.distances = path;

    const s = try grid.makeString();
    defer alloc.free(s);

    const m =
        \\+---+---+---+---+---+---+---+---+---+---+
        \\| 0 |     E   F | 2   3     |           |
        \\+   +   +   +   +   +   +   +---+   +   +
        \\| 1 |   | D | 0   1 | 4 |   |       |   |
        \\+   +   +   +   +---+   +   +   +---+   +
        \\| 2 |   | C |       | 5 |   |       |   |
        \\+   +   +   +---+   +   +   +---+   +   +
        \\| 3 |   | B |       | 6 |   |       |   |
        \\+   +   +   +   +---+   +   +   +---+---+
        \\| 4 |   | A |   |     7 |   |           |
        \\+   +   +   +   +---+   +---+---+---+   +
        \\| 5 |   | 9 |       | 8   9     |       |
        \\+   +---+   +---+   +---+   +   +   +---+
        \\| 6   7   8 |   |       | A |   | E   F |
        \\+---+---+---+   +---+   +   +---+   +   +
        \\|       |               | B   C   D | 0 |
        \\+   +---+   +---+---+---+---+---+---+   +
        \\|   |       |           |     3   2   1 |
        \\+   +   +---+   +---+---+   +   +---+---+
        \\|           |               | 4   5   6 |
        \\+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try std.testing.expectEqualStrings(m, s);
}
