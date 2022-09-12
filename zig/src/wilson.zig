//! wilson's maze algorithm

const std = @import("std");

const Grid = @import("grid.zig").Grid;
const Cell = @import("grid.zig").Cell;
const Distances = @import("grid.zig").Distances;

pub const Wilson = struct {
    pub fn on(grid: *Grid) !void {
        var visited = try grid.alctr.alloc(bool, grid.size());
        defer grid.alctr.free(visited);

        // init
        for (grid.cells_buf) |cell, i| {
            visited[i] = cell.numLinks() > 0;
        }
        if (std.mem.indexOfScalar(bool, visited, true) == null) {
            visited[visited.len - 1] = true;
        }

        // generate
        var path = std.ArrayList(*Cell).init(grid.alctr);
        defer path.deinit();
        var search: usize = 0;

        while (std.mem.indexOfScalarPos(bool, visited, search, false)) |idx| {
            search = idx;

            path.clearRetainingCapacity();
            var cell = &grid.cells_buf[idx];
            try path.append(cell);

            // wander until we find an unvisited cell
            while (visited[cell.row * grid.width + cell.col] == false) {
                cell = cell.randomNeighbor().?;
                if (std.mem.indexOfScalar(*Cell, path.items, cell)) |visited_idx| {
                    path.shrinkRetainingCapacity(visited_idx + 1);
                } else {
                    try path.append(cell);
                }
            }

            // link em
            var i: usize = 0;
            visited[path.items[i].row * grid.width + path.items[i].col] = true;
            while (i < path.items.len - 1) : (i += 1) {
                try path.items[i].bLink(path.items[i + 1]);
                visited[path.items[i + 1].row * grid.width + path.items[i + 1].col] = true;
            }
        }
    }
};

test "Apply Wilson" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 0, 10, 10);
    defer grid.deinit();

    try Wilson.on(&grid);
}

test "Wilson produces expected maze texture" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 0, 10, 10);
    defer grid.deinit();

    try Wilson.on(&grid);

    const s = try grid.makeString();
    defer alloc.free(s);

    const m =
        \\+---+---+---+---+---+---+---+---+---+---+
        \\|   |   |           |       |       |   |
        \\+   +   +   +---+---+---+   +   +   +   +
        \\|   |                           |   |   |
        \\+   +---+---+   +---+---+---+---+   +   +
        \\|       |       |           |           |
        \\+---+   +   +   +---+---+   +---+---+   +
        \\|   |       |           |       |       |
        \\+   +---+   +---+---+---+   +---+   +---+
        \\|           |   |       |   |       |   |
        \\+   +---+---+   +---+   +   +---+   +   +
        \\|       |       |           |           |
        \\+   +---+---+   +   +   +---+   +---+   +
        \\|       |       |   |   |   |       |   |
        \\+   +   +---+   +   +---+   +   +---+   +
        \\|   |   |                   |       |   |
        \\+   +   +   +---+---+   +---+   +---+---+
        \\|   |       |           |           |   |
        \\+   +---+---+---+   +   +   +---+---+   +
        \\|               |   |   |               |
        \\+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try std.testing.expectEqualStrings(m, s);
}

test "Wilson distances" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 0, 10, 10);
    defer grid.deinit();

    try Wilson.on(&grid);

    grid.distances = try Distances(Cell).from(grid.at(0, 0).?);

    const s = try grid.makeString();
    defer alloc.free(s);

    const m =
        \\+---+---+---+---+---+---+---+---+---+---+
        \\| 0 | B | A   B   C | D   C | D   E | 3 |
        \\+   +   +   +---+---+---+   +   +   +   +
        \\| 1 | A   9   8   9   A   B   C | F | 2 |
        \\+   +---+---+   +---+---+---+---+   +   +
        \\| 2   3 | 6   7 | A   9   8 | 1   0   1 |
        \\+---+   +   +   +---+---+   +---+---+   +
        \\| 9 | 4   5 | 8   9   A | 7   8 | 3   2 |
        \\+   +---+   +---+---+---+   +---+   +---+
        \\| 8   7   6 | 3 | 6   5 | 6 | 5   4 | 7 |
        \\+   +---+---+   +---+   +   +---+   +   +
        \\| 9   A | 3   2 | 3   4   5 | 6   5   6 |
        \\+   +---+---+   +   +   +---+   +---+   +
        \\| A   B | 2   1 | 2 | 5 | 4 | 7   8 | 7 |
        \\+   +   +---+   +   +---+   +   +---+   +
        \\| B | C | F   0   1   2   3 | 8   9 | 8 |
        \\+   +   +   +---+---+   +---+   +---+---+
        \\| C | D   E | 5   4   3 | A   9   A | F |
        \\+   +---+---+---+   +   +   +---+---+   +
        \\| D   E   F   0 | 5 | 4 | B   C   D   E |
        \\+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try std.testing.expectEqualStrings(m, s);
}

test "Aldous broder path" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 0, 10, 10);
    defer grid.deinit();

    try Wilson.on(&grid);

    grid.distances = try Distances(Cell).from(grid.at(0, 0).?);
    var path = try grid.distances.?.pathTo(grid.at(9, 9).?);
    grid.distances.?.deinit();
    grid.distances = path;

    const s = try grid.makeString();
    defer alloc.free(s);

    const m =
        \\+---+---+---+---+---+---+---+---+---+---+
        \\| 0 |   |           |       | D   E |   |
        \\+   +   +   +---+---+---+   +   +   +   +
        \\| 1 |         8   9   A   B   C | F |   |
        \\+   +---+---+   +---+---+---+---+   +   +
        \\| 2   3 | 6   7 |           |     0   1 |
        \\+---+   +   +   +---+---+   +---+---+   +
        \\|   | 4   5 |           |       | 3   2 |
        \\+   +---+   +---+---+---+   +---+   +---+
        \\|           |   |       |   |     4 |   |
        \\+   +---+---+   +---+   +   +---+   +   +
        \\|       |       |           | 6   5     |
        \\+   +---+---+   +   +   +---+   +---+   +
        \\|       |       |   |   |   | 7     |   |
        \\+   +   +---+   +   +---+   +   +---+   +
        \\|   |   |                   | 8     |   |
        \\+   +   +   +---+---+   +---+   +---+---+
        \\|   |       |           | A   9     |   |
        \\+   +---+---+---+   +   +   +---+---+   +
        \\|               |   |   | B   C   D   E |
        \\+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try std.testing.expectEqualStrings(m, s);
}
