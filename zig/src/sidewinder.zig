//! sidewinder maze algorithm
const std = @import("std");

const Grid = @import("grid.zig").Grid;
const Cell = @import("grid.zig").Cell;
const expect = std.testing.expect;
const expectEq = std.testing.expectEqual;

pub const Sidewinder = struct {
    pub fn on(grid: *Grid) !void {
        const random = grid.prng.random();

        var run = try grid.alctr.alloc(?*Cell, grid.width);
        defer grid.alctr.free(run);

        var run_len: usize = 0;

        for (grid.cells_buf) |*cell| {
            var coin = random.intRangeAtMost(u1, 0, 1);

            run[run_len] = cell;
            run_len += 1;

            if ((coin == 0 or cell.north() == null) and cell.east() != null) {
                // east case
                try cell.bLink(cell.east().?);
            } else if (coin == 1 or cell.east() == null) {
                // north/close run case
                var choice = random.intRangeLessThan(usize, 0, run_len);
                var choice_cell = run[choice];
                if (choice_cell.?.north() != null) {
                    try choice_cell.?.bLink(choice_cell.?.north().?);
                }
                run_len = 0;
            }
        }
    }
};

test "Construct and desruct sidewinder" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 0, 10, 10);
    defer grid.deinit();

    _ = try Sidewinder.on(&grid);
}

test "Sidewinder works" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 777, 12, 12);
    defer grid.deinit();

    try Sidewinder.on(&grid);

    var s = try grid.makeString();
    defer alloc.free(s);

    const m: []const u8 =
        \\+---+---+---+---+---+---+---+---+---+---+---+---+
        \\|                                               |
        \\+   +---+   +---+   +   +---+---+   +   +   +---+
        \\|   |       |       |           |   |   |       |
        \\+---+   +---+---+---+   +---+   +   +---+   +   +
        \\|                   |       |   |   |       |   |
        \\+   +---+   +   +---+   +---+   +---+---+   +   +
        \\|       |   |       |       |   |           |   |
        \\+   +   +   +   +   +---+---+   +   +   +---+   +
        \\|   |   |   |   |       |       |   |   |       |
        \\+   +   +   +---+   +   +---+   +---+   +---+   +
        \\|   |   |       |   |       |       |       |   |
        \\+   +   +---+   +---+   +   +---+   +   +   +---+
        \\|   |   |           |   |   |       |   |       |
        \\+---+   +   +   +   +   +   +   +---+   +   +   +
        \\|       |   |   |   |   |   |       |   |   |   |
        \\+   +---+   +---+   +---+---+   +---+   +   +---+
        \\|   |       |               |       |   |       |
        \\+   +   +   +---+---+---+---+---+---+   +---+---+
        \\|   |   |           |                           |
        \\+---+---+   +---+---+   +   +   +---+   +---+---+
        \\|                   |   |   |   |               |
        \\+   +---+---+   +---+   +---+---+   +---+   +---+
        \\|   |               |   |           |           |
        \\+---+---+---+---+---+---+---+---+---+---+---+---+
        \\
    ;

    try expectEq(true, std.mem.eql(u8, s, m));
}
