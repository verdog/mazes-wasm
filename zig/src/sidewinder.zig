/// ...
const std = @import("std");

const Grid = @import("grid.zig").Grid;
const Cell = @import("grid.zig").Cell;
const expect = std.testing.expect;
const expectEq = std.testing.expectEqual;

pub const Sidewinder = struct {
    pub fn on(grid: *Grid, seed: i64) !void {
        var prng = std.rand.DefaultPrng.init(@bitCast(u64, seed));
        const random = prng.random();

        // XXX: should this use the grids allocator?
        var run = try grid.mem.alloc(?*Cell, grid.width);
        defer grid.mem.free(run);

        var run_len: usize = 0;

        var it = grid.cells();
        while (it.next()) |cell| {
            var coin = random.intRangeAtMost(u1, 0, 1);

            run[run_len] = cell;
            run_len += 1;

            if ((coin == 0 or cell.north == null) and cell.east != null) {
                // east case
                try cell.bLink(cell.east.?);
            } else if (coin == 1 or cell.east == null) {
                // north/close run case
                var choice = random.intRangeLessThan(usize, 0, run_len);
                var choice_cell = run[choice];
                if (choice_cell.?.north != null) {
                    try choice_cell.?.bLink(choice_cell.?.north.?);
                }
                run_len = 0;
            }
        }
    }
};

test "Construct and desruct sidewinder" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 10, 10);
    defer grid.deinit();

    _ = try Sidewinder.on(&grid, 0);
}

test "Sidewinder works" {
    var alloc = std.testing.allocator;
    var grid = try Grid.init(alloc, 12, 12);
    defer grid.deinit();

    try Sidewinder.on(&grid, 777);

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
