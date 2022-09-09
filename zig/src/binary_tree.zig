//! binary tree maze algorithm

const std = @import("std");

const Grid = @import("grid.zig").Grid;
const Cell = @import("grid.zig").Cell;

const expect = std.testing.expect;
const expectEq = std.testing.expectEqual;

pub const BinaryTree = struct {
    /// apply the binary tree maze algorithm to `grid` using random `seed`.
    pub fn on(grid: *Grid) !void {
        var it = grid.cells();
        const random = grid.prng.random();

        while (it.next()) |cell| {
            // Of the cell's north and east neighbors, if it has them at all,
            // pick a random cell from the two and link it.
            var candidates: [2]?*Cell = .{ cell.north, cell.east };
            var non_null: u2 = 0;
            for (candidates) |ptr| {
                if (ptr != null) non_null += 1;
            }

            switch (non_null) {
                0 => {
                    // no neighbors, do nothing
                },
                1 => {
                    // link the single non-null neighbor
                    try cell.bLink(candidates[0] orelse candidates[1].?);
                },
                2 => {
                    // pick a random neighbor
                    var pick = random.intRangeLessThan(u2, 0, 2);
                    try cell.bLink(candidates[pick].?);
                },
                else => unreachable,
            }
        }
    }
};

test "Apply BinaryTree" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 0, 10, 10);
    defer grid.deinit();

    _ = try BinaryTree.on(&grid);
}

test "Binary tree works as expected" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 777, 12, 12);
    defer grid.deinit();

    try BinaryTree.on(&grid);

    var s = try grid.makeString();
    defer alloc.free(s);

    const m: []const u8 =
        \\+---+---+---+---+---+---+---+---+---+---+---+---+
        \\|                                               |
        \\+---+---+---+   +   +   +   +---+   +---+---+   +
        \\|               |   |   |   |       |           |
        \\+---+   +---+   +---+   +---+   +---+---+---+   +
        \\|       |       |       |       |               |
        \\+   +   +   +---+---+   +   +   +---+---+---+   +
        \\|   |   |   |           |   |   |               |
        \\+---+   +---+   +---+   +---+   +---+   +   +   +
        \\|       |       |       |       |       |   |   |
        \\+   +---+   +   +---+---+   +---+---+---+   +   +
        \\|   |       |   |           |               |   |
        \\+   +   +   +---+   +---+---+---+   +---+   +   +
        \\|   |   |   |       |               |       |   |
        \\+---+---+---+---+   +   +   +   +---+   +---+   +
        \\|                   |   |   |   |       |       |
        \\+---+   +   +   +---+---+---+---+   +---+---+   +
        \\|       |   |   |                   |           |
        \\+---+---+---+   +   +---+---+---+---+   +   +   +
        \\|               |   |                   |   |   |
        \\+---+   +---+---+---+---+---+   +   +   +   +   +
        \\|       |                       |   |   |   |   |
        \\+   +---+   +---+   +   +---+---+   +   +---+   +
        \\|   |       |       |   |           |   |       |
        \\+---+---+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try expectEq(true, std.mem.eql(u8, s, m));
}

test "Distances after binary tree" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 777, 12, 12);
    defer grid.deinit();

    try BinaryTree.on(&grid);

    grid.distances = try grid.at(0, 0).?.distances();

    var s = try grid.makeString();
    defer alloc.free(s);

    const m: []const u8 =
        \\+---+---+---+---+---+---+---+---+---+---+---+---+
        \\| 0   1   2   3   4   5   6   7   8   9   A   B |
        \\+---+---+---+   +   +   +   +---+   +---+---+   +
        \\| 7   6   5   4 | 5 | 6 | 7 | A   9 | E   D   C |
        \\+---+   +---+   +---+   +---+   +---+---+---+   +
        \\| 8   7 | 6   5 | 8   7 | C   B | 0   F   E   D |
        \\+   +   +   +---+---+   +   +   +---+---+---+   +
        \\| 9 | 8 | 7 | A   9   8 | D | C | 1   0   F   E |
        \\+---+   +---+   +---+   +---+   +---+   +   +   +
        \\| A   9 | C   B | A   9 | E   D | 2   1 | 0 | F |
        \\+   +---+   +   +---+---+   +---+---+---+   +   +
        \\| B | E   D | C | 1   0   F | 4   3   2   1 | 0 |
        \\+   +   +   +---+   +---+---+---+   +---+   +   +
        \\| C | F | E | 3   2 | 7   6   5   4 | 3   2 | 1 |
        \\+---+---+---+---+   +   +   +   +---+   +---+   +
        \\| 7   6   5   4   3 | 8 | 7 | 6 | 5   4 | 3   2 |
        \\+---+   +   +   +---+---+---+---+   +---+---+   +
        \\| 8   7 | 6 | 5 | A   9   8   7   6 | 5   4   3 |
        \\+---+---+---+   +   +---+---+---+---+   +   +   +
        \\| 9   8   7   6 | B | A   9   8   7   6 | 5 | 4 |
        \\+---+   +---+---+---+---+---+   +   +   +   +   +
        \\| A   9 | E   D   C   B   A   9 | 8 | 7 | 6 | 5 |
        \\+   +---+   +---+   +   +---+---+   +   +---+   +
        \\| B | 0   F | E   D | C | B   A   9 | 8 | 7   6 |
        \\+---+---+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try expectEq(true, std.mem.eql(u8, s, m));
}

test "Path after binary tree" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 777, 12, 12);
    defer grid.deinit();

    try BinaryTree.on(&grid);

    grid.distances = try grid.at(0, 0).?.distances();
    var path = try grid.distances.?.pathTo(grid.at(0, 11).?);
    grid.distances.?.deinit();
    grid.distances = path;

    var s = try grid.makeString();
    defer alloc.free(s);

    const m: []const u8 =
        \\+---+---+---+---+---+---+---+---+---+---+---+---+
        \\| 0   1   2   3   4   5   6   7   8             |
        \\+---+---+---+   +   +   +   +---+   +---+---+   +
        \\|               |   |   |   | A   9 |           |
        \\+---+   +---+   +---+   +---+   +---+---+---+   +
        \\|       |       |       |     B |               |
        \\+   +   +   +---+---+   +   +   +---+---+---+   +
        \\|   |   |   |           |   | C |               |
        \\+---+   +---+   +---+   +---+   +---+   +   +   +
        \\|       |       |       | E   D |       |   |   |
        \\+   +---+   +   +---+---+   +---+---+---+   +   +
        \\|   |       |   | 1   0   F |               |   |
        \\+   +   +   +---+   +---+---+---+   +---+   +   +
        \\|   |   |   |     2 |               |       |   |
        \\+---+---+---+---+   +   +   +   +---+   +---+   +
        \\|             4   3 |   |   |   |       |       |
        \\+---+   +   +   +---+---+---+---+   +---+---+   +
        \\|       |   | 5 |                   |           |
        \\+---+---+---+   +   +---+---+---+---+   +   +   +
        \\|     8   7   6 |   |                   |   |   |
        \\+---+   +---+---+---+---+---+   +   +   +   +   +
        \\| A   9 |                       |   |   |   |   |
        \\+   +---+   +---+   +   +---+---+   +   +---+   +
        \\| B |       |       |   |           |   |       |
        \\+---+---+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try expectEq(true, std.mem.eql(u8, s, m));
}
