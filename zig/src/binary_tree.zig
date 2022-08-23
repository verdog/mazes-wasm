/// ...
const std = @import("std");

const Grid = @import("grid.zig").Grid;
const Cell = @import("grid.zig").Cell;

const expect = std.testing.expect;
const expectEq = std.testing.expectEqual;

pub const BinaryTree = struct {
    pub fn on(grid: *Grid, seed: i64) !void {
        var it = grid.cells();
        var prng = std.rand.DefaultPrng.init(@bitCast(u64, seed));
        const random = prng.random();
        _ = random;

        while (it.next()) |*cell| {
            // Of the cell's north and east neighbors, if it has them at all,
            // pick a random cell from the two and link it.
            var candidates: [2]?*Cell = .{ cell.*.north, cell.*.east };
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
                    try cell.*.bLink(candidates[0] orelse candidates[1].?);
                },
                2 => {
                    // pick a random neighbor
                    var pick: usize = random.intRangeLessThan(usize, 0, 2);
                    try cell.*.bLink(candidates[pick].?);
                },
                else => unreachable,
            }
        }
    }
};

test "Apply BinaryTree" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 10, 10);
    defer grid.deinit();

    _ = try BinaryTree.on(&grid, 0);
}

test "Binary tree works as expected" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 12, 12);
    defer grid.deinit();

    try BinaryTree.on(&grid, 777);

    var s = try grid.makeString();
    defer alloc.free(s);

    const m: []const u8 =
        \\+---+---+---+---+---+---+---+---+---+---+---+---+
        \\|                                               |
        \\+   +   +---+---+   +   +---+---+---+   +---+   +
        \\|   |   |           |   |               |       |
        \\+   +   +---+---+   +---+---+   +---+---+---+   +
        \\|   |   |           |           |               |
        \\+---+---+   +---+   +   +   +   +   +   +---+   +
        \\|           |       |   |   |   |   |   |       |
        \\+   +---+---+   +   +---+   +   +   +---+---+   +
        \\|   |           |   |       |   |   |           |
        \\+---+   +---+---+   +---+---+---+   +   +   +   +
        \\|       |           |               |   |   |   |
        \\+   +   +   +---+   +   +---+   +   +   +   +   +
        \\|   |   |   |       |   |       |   |   |   |   |
        \\+---+   +---+---+---+   +   +---+---+---+   +   +
        \\|       |               |   |               |   |
        \\+---+---+   +   +---+---+---+---+---+---+---+   +
        \\|           |   |                               |
        \\+---+---+   +---+---+   +---+   +   +---+   +   +
        \\|           |           |       |   |       |   |
        \\+   +   +   +---+   +   +   +---+   +   +---+   +
        \\|   |   |   |       |   |   |       |   |       |
        \\+   +   +   +   +   +---+   +   +   +   +---+   +
        \\|   |   |   |   |   |       |   |   |   |       |
        \\+---+---+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try expectEq(true, std.mem.eql(u8, s, m));
}
